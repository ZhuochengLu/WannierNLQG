using Test
using WannierNLQG
using HDF5
using JSON3
using SHA
using LinearAlgebra
using Spglib
using EzXML

if !isdefined(Main, :QEPAWMatrixElementsTestSupport)
    include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
end

const GSM_W = WannierNLQG.Wannierization
const GSM_F = WannierNLQG.SymmetryFoundation
const GSM_IO = WannierNLQG.IO
const GSM_FIXTURES = joinpath(@__DIR__, "fixtures", "schema_compatibility", "generator_provenance")

gsm_extension() = first(GSM_W._load_wannierization_extension!()).PAWMatrixElements
gsm_sha(path) = bytes2hex(SHA.sha256(read(path)))

# Exercise the real persistence writer with a small explicit spinor state. This is
# a storage fixture, not a WAVECAR/POTCAR reconstruction or a material oracle.
function gsm_write_vasp_spn(directory)
    mkpath(directory)
    extension = gsm_extension()
    lattice = Matrix{Float64}(I, 3, 3)
    coefficients = zeros(ComplexF64, 2, 1, 2)
    coefficients[1, 1, 1] = 1.0
    coefficients[2, 1, 2] = 1.0
    point = GSM_F.PlaneWaveKPoint(
        zeros(3),
        zeros(Int, 1, 3),
        coefficients,
        [-1.0, 1.0];
        normalize_coefficients = false,
    )
    native = GSM_F.NativeWavefunctionData(
        :vasp,
        GSM_F.CrystalStructure(lattice, ["X"], zeros(3, 1)),
        2pi .* lattice,
        (2, 1, 1),
        true,
        [
            point,
            GSM_F.PlaneWaveKPoint(
                [0.5, 0.0, 0.0],
                zeros(Int, 1, 3),
                coefficients,
                [-1.0, 1.0];
                normalize_coefficients = false,
            ),
        ],
        Dict("WAVECAR" => repeat("a", 64)),
        Dict("fixture" => "typed_spinor_state"),
    )
    source = GSM_F.VASPWavefunctionSource(
        "synthetic.POSCAR",
        "synthetic.WAVECAR";
        band_range = 1:2,
        spinor = true,
    )
    header =
        GSM_F.VASPWavecarHeader(128, 1, 45200, 2, 2, 10.0, lattice, 2pi .* lattice, 0.0, ComplexF64)
    data = zeros(ComplexF64, 2, 2, 3, 2)
    for (i, pauli) in
        enumerate((ComplexF64[0 1; 1 0], ComplexF64[0 -im; im 0], ComplexF64[1 0; 0 -1]))
        data[:, :, i, 1] .= pauli
        data[:, :, i, 2] .= pauli
    end
    spn = GSM_IO.WannierSPN(2, 2, data)
    binary = joinpath(directory, "vasp.spn")
    GSM_IO.write_wannier_spn(binary, spn; comment = "generator schema fixture")
    result = GSM_W.VASPPAWSPNResult(
        spn,
        nothing,
        0.0,
        0.0,
        0.0,
        0.0,
        true,
        ["synthetic=true"],
        Dict("total_frobenius" => norm(data)),
        Dict("spn" => binary, "spn_sha256" => gsm_sha(binary)),
        native.input_sha256,
    )
    path = joinpath(directory, "vasp_spn.h5")
    Base.invokelatest(
        extension._write_vasp_paw_spn_provenance,
        path,
        result,
        GSM_W.VASPPAWSPNThresholds(),
        native,
        source,
        header,
    )
    return path
end

# All generators read the same three-point PAW source. The stored source fixture
# is reused for current writers, so source-file hashes do not drift between runs.
function gsm_write_qe_generators(directory; source_directory = nothing)
    mkpath(directory)
    fixture = if source_directory === nothing
        QEPAWMatrixElementsTestSupport.write_qe_paw_fixture(
            joinpath(directory, "qe_source");
            metric_kind = :paw,
            spinor = true,
            spinorbit = true,
            num_kpoints = 3,
        )
    else
        (
            save_directory = joinpath(source_directory, "fixture.save"),
            nnkp_file = joinpath(source_directory, "fixture.nnkp"),
        )
    end
    source = GSM_F.QuantumEspressoWavefunctionSource(
        fixture.save_directory;
        include_time_reversal = false,
    )
    spn = GSM_W.generate_qe_paw_spn(
        source,
        fixture.nnkp_file;
        output_spn_file = joinpath(directory, "qe.spn"),
        provenance_json = joinpath(directory, "qe_spn.json"),
        max_cached_wavefunction_kpoints = 2,
    )
    eig = joinpath(directory, "fixture.eig")
    GSM_IO.write_wannier_eig(eig, GSM_IO.WannierEIG(1, 3, reshape([1.0, 2.0, 3.0], 1, 3)))
    oracle = joinpath(directory, "oracle.mmn")
    GSM_IO.write_wannier_mmn(
        oracle,
        GSM_IO.WannierMMN(
            1,
            3,
            1,
            ones(ComplexF64, 1, 1, 1, 3),
            reshape(collect(1:3), 1, 3),
            zeros(Int, 3, 1, 3),
        ),
    )
    uiu = GSM_W.generate_wannier_uiu(
        GSM_W.WannierUIUGenerationConfig(
            source = source,
            topology_file = fixture.nnkp_file,
            output_file = joinpath(directory, "fixture.uIu"),
            provenance_json = joinpath(directory, "uiu.json"),
            oracle_mmn_file = oracle,
            max_cached_wavefunction_kpoints = 2,
        ),
    )
    uhu = GSM_W.generate_wannier_uhu(
        GSM_W.WannierHamiltonianOperatorGenerationConfig(
            source = source,
            topology_file = fixture.nnkp_file,
            eig_file = eig,
            output_file = joinpath(directory, "fixture.uHu"),
            provenance_json = joinpath(directory, "hamiltonian.json"),
            max_cached_wavefunction_kpoints = 2,
        ),
    )
    extension = gsm_extension()
    topology = (num_bands = 1, num_kpts = 3, num_neighbors = 1)
    checkpoint = Base.invokelatest(
        extension._uiu_checkpoint_payload,
        repeat("c", 64),
        topology,
        0,
        String[],
        "fixture_execution_contract",
    )
    write(joinpath(directory, "uiu_partial.json"), JSON3.write(checkpoint))
    return (spn = spn, uiu = uiu, uhu = uhu)
end

if !isdefined(Main, :GENERATOR_SCHEMA_FIXTURE_ONLY)
    @testset "generator schema migration fixture integrity" begin
        for line in readlines(joinpath(GSM_FIXTURES, "SHA256SUMS"))
            isempty(strip(line)) && continue
            digest, relative = split(line; limit = 2)
            @test gsm_sha(joinpath(GSM_FIXTURES, strip(relative))) == digest
        end
    end
end

# Compare storage values exactly; allowed paths are explicit metadata changes.
function gsm_compare_values(a, b, allowed, path = ())
    if path in allowed
        return
    end
    @test typeof(a) == typeof(b)
    if a isa AbstractDict
        allowed_keys = Set{String}()
        for allowed_path in allowed
            length(allowed_path) == length(path) + 1 || continue
            Tuple(allowed_path[1:(end - 1)]) == path || continue
            push!(allowed_keys, String(last(allowed_path)))
        end
        keys_a = Set(String.(keys(a)))
        keys_b = Set(String.(keys(b)))
        @test setdiff(keys_a, allowed_keys) == setdiff(keys_b, allowed_keys)
        for key in intersect(keys_a, keys_b)
            gsm_compare_values(a[key], b[key], allowed, (path..., String(key)))
        end
    elseif a isa AbstractArray
        @test size(a) == size(b)
        if isbitstype(eltype(a))
            @test reinterpret(UInt8, vec(a)) == reinterpret(UInt8, vec(b))
        else
            for index in eachindex(a)
                gsm_compare_values(a[index], b[index], allowed, (path..., string(index)))
            end
        end
    elseif a isa AbstractFloat
        @test bitstring(a) == bitstring(b)
    else
        @test isequal(a, b)
    end
end

# The memory note must be unique and exactly mirror its measured cache field.
# Other diagnostics retain their original order and exact scientific comparison.
function gsm_uiu_memory_note_index(payload)
    prefix = "qe_uiu_cache_peak_resident_bytes="
    indices = findall(note -> startswith(note, prefix), payload["diagnostics"])
    length(indices) == 1 || throw(ArgumentError("expected exactly one QE cache memory note"))
    index = only(indices)
    expected = prefix * string(payload["wavefunction_cache"]["peak_cache_resident_bytes"])
    payload["diagnostics"][index] == expected ||
        throw(ArgumentError("QE cache memory note does not match its measured field"))
    return index
end

# Base.summarysize includes runtime array overhead. Measure the actual fixture
# entries in this process instead of treating an earlier Julia's size as physics.
function gsm_uiu_performance_paths(old, current)
    source = GSM_F.QuantumEspressoWavefunctionSource(
        joinpath(GSM_FIXTURES, "qe_source", "fixture.save");
        include_time_reversal = false,
    )
    state = Base.invokelatest(
        gsm_extension()._uiu_qe_state,
        source,
        joinpath(GSM_FIXTURES, "qe_source", "fixture.nnkp"),
        2,
    )
    cache = state.wavefunction_cache
    component_bytes = map(1:3) do index
        entry = Base.invokelatest(cache.loader, index)
        [
            Base.summarysize(entry.point.k_fractional),
            Base.summarysize(entry.point.g_vectors),
            Base.summarysize(entry.point.coefficients),
            Base.summarysize(entry.point.energies_ev),
            Base.summarysize(entry.beta_overlap),
        ]
    end
    @test all(==(first(component_bytes)), component_bytes)
    @test length(cache.entries) == cache.peak_entries == cache.max_entries == 2
    measured = sum(
        Base.summarysize(entry.point.k_fractional) +
        Base.summarysize(entry.point.g_vectors) +
        Base.summarysize(entry.point.coefficients) +
        Base.summarysize(entry.point.energies_ev) +
        Base.summarysize(entry.beta_overlap) for entry in values(cache.entries)
    )
    @test measured == 2 * sum(first(component_bytes)) == cache.peak_resident_bytes
    @test current["wavefunction_cache"]["peak_cached_kpoints"] == 2
    @test current["wavefunction_cache"]["peak_cache_resident_bytes"] == measured
    @test current["julia_version"] == string(VERSION)
    old_index = gsm_uiu_memory_note_index(old)
    current_index = gsm_uiu_memory_note_index(current)
    @test old_index == current_index
    malformed = deepcopy(current)
    malformed["diagnostics"][current_index] *= "0"
    @test_throws ArgumentError gsm_uiu_memory_note_index(malformed)
    duplicate = deepcopy(current)
    push!(duplicate["diagnostics"], duplicate["diagnostics"][current_index])
    @test_throws ArgumentError gsm_uiu_memory_note_index(duplicate)
    println(
        "GSM_UIU_MEMORY_OBSERVATION ",
        JSON3.write(
            Dict(
                "fixture_sha256" => gsm_sha(joinpath(GSM_FIXTURES, "uiu.json")),
                "former_julia_version" => old["julia_version"],
                "current_julia_version" => current["julia_version"],
                "former_bytes" => old["wavefunction_cache"]["peak_cache_resident_bytes"],
                "current_bytes" => current["wavefunction_cache"]["peak_cache_resident_bytes"],
                "measured_bytes" => measured,
                "component_bytes_per_kpoint" => component_bytes,
                "former_note" => old["diagnostics"][old_index],
                "current_note" => current["diagnostics"][current_index],
            ),
        ),
    )
    return Set([
        ("wavefunction_cache", "peak_cache_resident_bytes"),
        ("diagnostics", string(current_index)),
    ])
end

function gsm_hdf5_payload(object)
    values = Dict{String, Any}()
    attributes = HDF5.attributes(object)
    for name in keys(attributes)
        values["@" * String(name)] = read(attributes[name])
    end
    if object isa HDF5.Dataset
        values["data"] = read(object)
    else
        for name in keys(object)
            values[String(name)] = gsm_hdf5_payload(object[name])
        end
    end
    return values
end

function gsm_set_attribute(object, key, value)
    haskey(HDF5.attributes(object), key) && HDF5.delete_attribute(object, key)
    HDF5.attributes(object)[key] = value
end

if !isdefined(Main, :GENERATOR_SCHEMA_FIXTURE_ONLY)
    @testset "generator schema SPN history and current writer contracts" begin
        extension = gsm_extension()
        cd(GSM_FIXTURES) do
            for (name, version) in (
                ("vasp_spn_contract_1_0.h5", "1.0"),
                ("vasp_spn_contract_1_1.h5", "1.1"),
                ("vasp_spn.h5", "1.2"),
            )
                record = GSM_W.read_vasp_paw_spn_provenance(name; verify_spn = false)
                @test record.schema_version == version
                @test record.num_bands == 2 && record.num_kpoints == 2
                @test record.artifacts["spn_sha256"] == gsm_sha("vasp.spn")
                if version != "1.2"
                    @test record.contract_sha256 == "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED"
                    @test_throws ArgumentError Base.invokelatest(
                        extension._validate_generation_spn_provenance,
                        record,
                        "vasp.spn",
                        nothing,
                    )
                end
            end
            for (name, version) in (("qe_spn_contract_1_1.json", "1.1"), ("qe_spn.json", "1.2"))
                record = Base.invokelatest(
                    extension.read_qe_paw_spn_provenance,
                    name;
                    verify_spn = false,
                )
                @test record.schema_version == version
                @test record.artifacts["spn_sha256"] == gsm_sha("qe.spn")
                if version == "1.1"
                    @test record.contract_sha256 == "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED"
                    @test_throws ArgumentError Base.invokelatest(
                        extension._validate_generation_spn_provenance,
                        record,
                        "qe.spn",
                        nothing,
                    )
                end
            end
        end
        mktempdir() do directory
            vasp = gsm_write_vasp_spn(directory)
            generated = gsm_write_qe_generators(
                directory;
                source_directory = joinpath(GSM_FIXTURES, "qe_source"),
            )
            @test generated.spn.passed && generated.uiu.passed && generated.uhu.passed
            new_vasp = GSM_W.read_vasp_paw_spn_provenance(vasp)
            new_qe = Base.invokelatest(
                extension.read_qe_paw_spn_provenance,
                joinpath(directory, "qe_spn.json"),
            )
            @test new_vasp.schema_version == new_qe.schema_version == "1.0"
            @test new_vasp.contract_sha256 != "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED"
            for binary in ("vasp.spn", "qe.spn", "fixture.uIu", "fixture.uHu")
                @test read(joinpath(directory, binary)) == read(joinpath(GSM_FIXTURES, binary))
            end
            old_h5 = HDF5.h5open(gsm_hdf5_payload, joinpath(GSM_FIXTURES, "vasp_spn.h5"), "r")
            new_h5 = HDF5.h5open(gsm_hdf5_payload, vasp, "r")
            gsm_compare_values(
                old_h5,
                new_h5,
                Set([("@schema_version",), ("@payload_sha256",), ("artifacts", "@spn")]),
            )
            allowed = Set([
                ("schema_version",),
                ("payload_sha256",),
                ("contract_sha256",),
                ("artifacts", "spn"),
                ("artifacts", "provenance_json"),
                ("output_file",),
                ("peak_memory_bytes",),
                ("input_fingerprint_sha256",),
                ("julia_version",),
                ("julia_threads",),
                ("construction_policy",),
                ("model_qualification",),
                ("manual_review_required",),
                ("production_eligible",),
            ])
            for name in ("qe_spn.json", "uiu.json", "hamiltonian.json", "uiu_partial.json")
                old = JSON3.read(read(joinpath(GSM_FIXTURES, name), String), Dict{String, Any})
                new = JSON3.read(read(joinpath(directory, name), String), Dict{String, Any})
                @test new["schema_version"] == "1.0"
                if name in ("uiu.json", "hamiltonian.json")
                    @test new["construction_policy"] == "diagnostic"
                    @test new["model_qualification"] == "DIAGNOSTIC_ONLY"
                    @test new["manual_review_required"] === true
                    @test new["production_eligible"] === false
                end
                file_allowed = if name == "uiu.json"
                    @test !haskey(old["input_sha256"], "AUTHORITATIVE_MMN")
                    @test new["input_sha256"]["AUTHORITATIVE_MMN"] ==
                          gsm_sha(joinpath(directory, "oracle.mmn"))
                    @test new["input_sha256"]["AUTHORITATIVE_MMN"] ==
                          new["input_sha256"]["ORACLE_MMN"]
                    union(
                        allowed,
                        gsm_uiu_performance_paths(old, new),
                        Set([("input_sha256", "AUTHORITATIVE_MMN")]),
                    )
                else
                    allowed
                end
                gsm_compare_values(old, new, file_allowed)
            end
            for file in (
                joinpath(GSM_FIXTURES, "uiu_partial.json"),
                joinpath(directory, "uiu_partial.json"),
            )
                @test Base.invokelatest(
                    extension._uiu_validate_checkpoint,
                    file,
                    repeat("c", 64),
                    0,
                    String[],
                    "fixture_execution_contract",
                ) === nothing
                @test_throws ArgumentError Base.invokelatest(
                    extension._uiu_validate_checkpoint,
                    file,
                    repeat("d", 64),
                    0,
                    String[],
                    "fixture_execution_contract",
                )
                @test_throws ArgumentError Base.invokelatest(
                    extension._uiu_validate_checkpoint,
                    file,
                    repeat("c", 64),
                    0,
                    String[],
                    "different_execution_contract",
                )
            end
            operator_export = first(GSM_W._load_wannierization_extension!()).OperatorExport
            uiu_paths = Dict(
                "uiu_provenance_json" => joinpath(directory, "uiu.json"),
                "uiu_file" => joinpath(directory, "fixture.uIu"),
                "mmn_file" => joinpath(directory, "oracle.mmn"),
            )
            @test last(
                Base.invokelatest(operator_export._exact_bundle_uiu_provenance, uiu_paths),
            ) == gsm_sha(uiu_paths["uiu_file"])
            for field in ("band_frame_contract", "source_band_gauge")
                broken =
                    JSON3.read(read(joinpath(directory, "uiu.json"), String), Dict{String, Any})
                delete!(broken, field)
                uiu_paths["uiu_provenance_json"] = joinpath(directory, "uiu-missing.json")
                write(uiu_paths["uiu_provenance_json"], JSON3.write(broken))
                @test_throws ArgumentError Base.invokelatest(
                    operator_export._exact_bundle_uiu_provenance,
                    uiu_paths,
                )
                broken["schema_version"] = "1.2"
                write(uiu_paths["uiu_provenance_json"], JSON3.write(broken))
                @test last(
                    Base.invokelatest(operator_export._exact_bundle_uiu_provenance, uiu_paths),
                ) == gsm_sha(uiu_paths["uiu_file"])
            end
            # Current-marker removal cannot silently select legacy validation.
            broken_h5 = joinpath(directory, "broken.h5")
            cp(vasp, broken_h5)
            HDF5.h5open(broken_h5, "r+") do handle
                HDF5.delete_object(handle, "band_frame_contract")
                gsm_set_attribute(
                    handle,
                    "payload_sha256",
                    Base.invokelatest(extension._vasp_paw_spn_provenance_payload_sha256, handle),
                )
            end
            @test_throws ArgumentError GSM_W.read_vasp_paw_spn_provenance(
                broken_h5;
                verify_spn = false,
            )
            cp(vasp, broken_h5; force = true)
            HDF5.h5open(broken_h5, "r+") do handle
                HDF5.delete_object(handle, "band_frame_contract")
                for key in collect(keys(HDF5.attributes(handle)))
                    startswith(String(key), "band_frame_") &&
                        HDF5.delete_attribute(handle, String(key))
                end
                gsm_set_attribute(
                    handle,
                    "payload_sha256",
                    Base.invokelatest(extension._vasp_paw_spn_provenance_payload_sha256, handle),
                )
            end
            downgraded = GSM_W.read_vasp_paw_spn_provenance(broken_h5)
            @test downgraded.contract_sha256 == "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED"
            @test_throws ArgumentError Base.invokelatest(
                extension._validate_generation_spn_provenance,
                downgraded,
                joinpath(directory, "vasp.spn"),
                nothing,
            )
            cp(vasp, broken_h5; force = true)
            HDF5.h5open(broken_h5, "r+") do handle
                handle["energies_ev"][1, 1] = 99.0
            end
            @test_throws ArgumentError GSM_W.read_vasp_paw_spn_provenance(
                broken_h5;
                verify_spn = false,
            )
            for field in (
                "band_frame_contract",
                "band_frame_contract_sha256",
                "band_frame_transform_sha256",
                "source_code",
                "num_bands",
            )
                broken =
                    JSON3.read(read(joinpath(directory, "qe_spn.json"), String), Dict{String, Any})
                delete!(broken, field)
                path = joinpath(directory, "broken.json")
                write(path, JSON3.write(broken))
                @test_throws ArgumentError Base.invokelatest(
                    extension.read_qe_paw_spn_provenance,
                    path;
                    verify_spn = false,
                )
            end
            for name in ("qe_spn.json", "vasp_spn.h5")
                path = joinpath(directory, name)
                if endswith(name, ".json")
                    broken = JSON3.read(read(path, String), Dict{String, Any})
                    broken["schema_version"] = "1.2"
                    write(joinpath(directory, "wrong-version.json"), JSON3.write(broken))
                    @test_throws ArgumentError Base.invokelatest(
                        extension.read_qe_paw_spn_provenance,
                        joinpath(directory, "wrong-version.json");
                        verify_spn = false,
                    )
                else
                    cp(path, broken_h5; force = true)
                    HDF5.h5open(broken_h5, "r+") do handle
                        gsm_set_attribute(handle, "schema_version", "1.2")
                    end
                    @test_throws ArgumentError GSM_W.read_vasp_paw_spn_provenance(
                        broken_h5;
                        verify_spn = false,
                    )
                end
            end
            probe = "using WannierNLQG, JSON3; e=first(WannierNLQG.Wannierization._load_wannierization_extension!()).PAWMatrixElements; for f in ARGS; r=endswith(f, \".h5\") ? WannierNLQG.Wannierization.read_vasp_paw_spn_provenance(f;verify_spn=false) : Base.invokelatest(e.read_qe_paw_spn_provenance,f;verify_spn=false); @assert r.passed; end; println(\"GENERATOR_SCHEMA_FRESH_READ_PASS\")"
            paths = [
                joinpath(GSM_FIXTURES, name) for name in (
                    "vasp_spn_contract_1_0.h5",
                    "vasp_spn_contract_1_1.h5",
                    "vasp_spn.h5",
                    "qe_spn_contract_1_1.json",
                    "qe_spn.json",
                )
            ]
            append!(paths, [vasp, joinpath(directory, "qe_spn.json")])
            command =
                `$(Base.julia_cmd()) --startup-file=no --compiled-modules=no --project=$(dirname(@__DIR__)) -e $probe $paths`
            @test occursin(
                "GENERATOR_SCHEMA_FRESH_READ_PASS",
                read(Cmd(command; dir = GSM_FIXTURES), String),
            )
        end
    end
end
