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
gsm_operator_extension() = first(GSM_W._load_wannierization_extension!()).OperatorExport
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
    source_values=joinpath(directory, "storage-fixture-coefficients.bin")
    open(source_values, "w") do io
        GSM_IO.write_native_definition_value(
            io,
            (
                coefficients = coefficients,
                energies = [-1.0, 1.0],
                kpoints = [0.0 0.0 0.0; 0.5 0.0 0.0],
                lattice = lattice,
            ),
        )
    end
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
        Dict{String, String}(),
        Dict("fixture" => "typed_spinor_state"),
        source_definition = GSM_IO.scientific_source_collection_definition(
            Dict("STORAGE_FIXTURE_VALUES"=>source_values),
        ),
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
        Dict("spn" => binary),
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

if !isdefined(Main, :GENERATOR_SCHEMA_FIXTURE_ONLY)
    @testset "generator current writer mathematical and source contracts" begin
        extension=gsm_extension()
        for name in ("vasp_spn_contract_1_0.h5", "vasp_spn_contract_1_1.h5", "vasp_spn.h5")
            @test_throws ArgumentError GSM_W.read_vasp_paw_spn_provenance(
                joinpath(GSM_FIXTURES, name);
                verify_spn = false,
            )
        end
        for name in ("qe_spn_contract_1_1.json", "qe_spn.json")
            @test_throws ArgumentError Base.invokelatest(
                extension.read_qe_paw_spn_provenance,
                joinpath(GSM_FIXTURES, name);
                verify_spn = false,
            )
        end
        mktempdir() do directory
            vasp=gsm_write_vasp_spn(directory)
            generated=gsm_write_qe_generators(
                directory;
                source_directory = joinpath(GSM_FIXTURES, "qe_source"),
            )
            @test generated.spn.passed && generated.uiu.passed && generated.uhu.passed
            records=(
                GSM_W.read_vasp_paw_spn_provenance(vasp),
                Base.invokelatest(
                    extension.read_qe_paw_spn_provenance,
                    joinpath(directory, "qe_spn.json"),
                ),
            )
            for record in records
                @test record.schema_version=="2.0"
                @test !hasproperty(record, :passed)
                @test record.content_authentication=="NOT_PERFORMED"
                identity=Base.invokelatest(
                    extension._identity_band_frame_contract,
                    record.num_bands,
                    record.num_kpoints,
                )
                @test record.transform_definition==identity.transform_definition
                @test record.contract_definition==identity.contract_definition
                @test record.source_reference isa GSM_IO.ScientificInputDefinition
            end
            # Whole actual binary outputs are the original scientific oracle.
            for binary in ("vasp.spn", "qe.spn", "fixture.uIu", "fixture.uHu")
                @test read(joinpath(directory, binary))==read(joinpath(GSM_FIXTURES, binary))
            end
            original=JSON3.read(read(joinpath(directory, "qe_spn.json"), String), Dict{String, Any})
            for key in
                ("band_frame_contract", "source_band_gauge", "input_definitions", "references_hdf5")
                bad=deepcopy(original);
                delete!(bad, key)
                path=joinpath(directory, "missing-"*key*".json");
                write(path, JSON3.write(bad))
                @test_throws ArgumentError Base.invokelatest(
                    extension.read_qe_paw_spn_provenance,
                    path;
                    verify_spn = false,
                )
            end
            for key in (
                "generalized_norm_max_absolute",
                "hermiticity_max_absolute",
                "diagonal_imaginary_max_absolute",
            )
                bad=deepcopy(original);
                bad[key]=bad["thresholds"][key]+1.0
                path=joinpath(directory, "invalid-"*key*".json");
                write(path, JSON3.write(bad))
                @test_throws ArgumentError Base.invokelatest(
                    extension.read_qe_paw_spn_provenance,
                    path,
                )
            end
            # These legacy spellings still reject at the ordinary reader boundary.
            for key in ("band_gauge_rotation_sha256", "band_gauge_rotation_semantics")
                bad=deepcopy(original);
                bad[key]="legacy"
                path=joinpath(directory, "legacy-"*key*".json");
                write(path, JSON3.write(bad))
                @test_throws ArgumentError Base.invokelatest(
                    extension.read_qe_paw_spn_provenance,
                    path;
                    verify_spn = false,
                )
            end
            probe=raw"""
using WannierNLQG
ext=first(WannierNLQG.Wannierization._load_wannierization_extension!()).PAWMatrixElements
for file in ARGS
    record=endswith(file,".h5") ? WannierNLQG.Wannierization.read_vasp_paw_spn_provenance(file) : Base.invokelatest(ext.read_qe_paw_spn_provenance,file)
    @assert record.schema_version=="2.0"
    @assert !hasproperty(record,:passed)
end
println("GENERATOR_SCHEMA_FRESH_READ_PASS")
"""
            command=`$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) -e $probe $vasp $(joinpath(directory,"qe_spn.json"))`
            @test occursin("GENERATOR_SCHEMA_FRESH_READ_PASS", read(command, String))
        end
    end
end

@testset "shared native lifetime uses the declared component port" begin
    parent=first(GSM_W._load_wannierization_extension!())
    paw=parent.PAWMatrixElements
    operator=parent.OperatorExport
    @test paw.with_native_source_lifetime === operator.with_native_source_lifetime
    mktempdir() do directory
        source=joinpath(directory, "native-input.dat")
        write(source, "original")
        @test Base.invokelatest(paw.with_native_source_lifetime, ()->:kept, [source, source]) ===
              :kept
        caught=try
            Base.invokelatest(
                paw.with_native_source_lifetime,
                ()->begin
                    write(source, "different bytes")
                    :must_not_return
                end,
                [source],
            )
            nothing
        catch error
            error
        end
        @test caught isa ArgumentError
        @test occursin("Scientific input changed during use", sprint(showerror, caught))
    end
end
