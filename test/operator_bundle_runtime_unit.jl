using HDF5
using JSON3
using Test
using WannierNLQG

const OperatorBundleCore = WannierNLQG.Core
const OperatorBundleIO = WannierNLQG.IO
const OperatorBundleRuntime = WannierNLQG.Runtime

isdefined(@__MODULE__, :test_operator_bundle_geometry) ||
    include(joinpath(@__DIR__, "OperatorBundleTestSupport.jl"))

@testset "profile moment frame definitions survive current model storage" begin
    C = OperatorBundleCore
    r_vectors = zeros(Int, 3, 1)
    h = C.RealSpaceOperator(
        C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
        r_vectors,
        reshape(ComplexF64[1.0], 1, 1, 1),
    )
    position = C.RealSpaceOperator(
        C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_POSITION, 1, -1, 1),
        r_vectors,
        reshape(ComplexF64[0.25, 0.0, 0.0], 1, 1, 3, 1),
    )
    operators = Dict(C.REAL_SPACE_HAMILTONIAN => h, C.REAL_SPACE_POSITION => position)
    lattice = Matrix{Float64}(LinearAlgebra.I, 3, 3)
    geometry = test_operator_bundle_geometry(lattice, [1], operators)
    geometry["production_eligible"] = false
    definitions = Dict(
        "derivative_frame" => "uncentered_periodic_wannier",
        "operator_moment_frame_conversion" => "centered-q-to-uncentered-q-once-v1",
    )
    mktempdir() do directory
        path = joinpath(directory, "frame.h5")
        OperatorBundleIO.write_real_space_operator_bundle(
            path,
            lattice,
            [1],
            operators;
            geometry,
            provenance = definitions,
        )
        loaded = OperatorBundleIO.read_real_space_operator_bundle(path)
        stored = loaded.manifest.operator_qualification["mathematical_definitions"]
        @test all(stored[key] == value for (key, value) in definitions)
        @test loaded.operators[C.REAL_SPACE_HAMILTONIAN].data == h.data
        @test loaded.operators[C.REAL_SPACE_POSITION].data == position.data
        @test !loaded.manifest.production_eligible
        legacy = joinpath(directory, "unrecorded.h5")
        OperatorBundleIO.write_real_space_operator_bundle(legacy, lattice, [1], operators; geometry)
        legacy_manifest = OperatorBundleIO.read_real_space_operator_bundle_manifest(legacy)
        @test !haskey(
            legacy_manifest.operator_qualification["mathematical_definitions"],
            "derivative_frame",
        )
        @test_throws ArgumentError OperatorBundleIO.write_real_space_operator_bundle(
            joinpath(directory, "bad.h5"),
            lattice,
            [1],
            operators;
            geometry,
            provenance = Dict("derivative_frame" => "centered"),
        )
        h5open(path, "r+") do file
            HDF5.delete_attribute(file["definitions"], "derivative_frame")
            HDF5.attributes(file["definitions"])["derivative_frame"] = "centered"
        end
        @test_throws ArgumentError OperatorBundleIO.read_real_space_operator_bundle_manifest(path)
    end
end

@testset "matrix capabilities follow the supplied inventory" begin
    C = OperatorBundleCore
    capabilities = OperatorBundleIO.available_matrix_capabilities
    @test isempty(capabilities(()))
    @test capabilities((C.REAL_SPACE_HAMILTONIAN,)) == ["hamiltonian"]
    @test capabilities((C.REAL_SPACE_POSITION,)) == ["position"]
    @test capabilities((C.REAL_SPACE_SPIN,)) == ["spin"]
    @test isempty(
        capabilities((
            C.REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
            C.REAL_SPACE_SPIN_TIMES_POSITION,
            C.REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
        )),
    )
    @test "derivative" in capabilities(OperatorBundleIO.OPERATOR_PROFILE_INVENTORIES[:derivative])
end

function test_operator_bundle_frame_contract(;
    source_band_gauge = "native_dft_eigenstate",
    target_band_gauge = "symmetrized_dft_hamiltonian",
    transform_sha256 = repeat("5", 64),
    contract_sha256 = repeat("6", 64),
    gauge_artifact_sha256 = repeat("4", 64),
)
    return Dict{String, Any}(
        "schema" => "WannierNLQG.band_frame_transform_contract",
        "schema_version" => "1.0",
        "status" => "PASS",
        "legacy" => false,
        "source_band_gauge" => source_band_gauge,
        "target_band_gauge" => target_band_gauge,
        "transform_sha256" => transform_sha256,
        "contract_sha256" => contract_sha256,
        "gauge_artifact_sha256" => gauge_artifact_sha256,
        "metric_kind" => "paw_generalized_overlap",
        "physical_isometry_maximum" => 2.0e-10,
        "physical_isometry_tolerance" => 1.0e-8,
        "replay_maximum" => 3.0e-10,
        "replay_tolerance" => 1.0e-8,
        "euclidean_nonunitarity_maximum" => 2.0e-6,
        "minimum_singular_value" => 0.999999,
        "maximum_condition_number" => 1.000002,
    )
end

function test_pair_wigner_seitz_provenance(names; residuals = nothing)
    values =
        residuals === nothing ?
        Dict(String(name) => 1.0e-12 * index for (index, name) in enumerate(names)) :
        Dict{String, Float64}(String(name) => Float64(value) for (name, value) in residuals)
    return Dict{String, Any}(
        "operator_profile_assembly_algorithm_version" => "focused-pair-wigner-seitz-v1",
        "pair_wigner_seitz_roundtrip_policy" => "PAIR_DEPENDENT_MINIMUM_DISTANCE_UNIT_DEGENERACY",
        "pair_wigner_seitz_roundtrip_tolerance" => 1.0e-8,
        "pair_wigner_seitz_roundtrip_residuals" => values,
    )
end

function write_hamiltonian_position_bundle(directory, model_file; content_authentication = false)
    model = OperatorBundleIO.read_wannier_tb(model_file)
    operators =
        Dict{OperatorBundleCore.RealSpaceOperatorKind, OperatorBundleCore.RealSpaceOperator}(
            OperatorBundleCore.REAL_SPACE_HAMILTONIAN => OperatorBundleCore.RealSpaceOperator(
                OperatorBundleCore.RealSpaceOperatorSymmetrySpec(
                    OperatorBundleCore.REAL_SPACE_HAMILTONIAN,
                    0,
                    1,
                    1,
                ),
                model.r_vectors,
                model.hamiltonian_r,
            ),
            OperatorBundleCore.REAL_SPACE_POSITION => OperatorBundleCore.RealSpaceOperator(
                OperatorBundleCore.RealSpaceOperatorSymmetrySpec(
                    OperatorBundleCore.REAL_SPACE_POSITION,
                    1,
                    -1,
                    1,
                ),
                model.r_vectors,
                model.position_r,
            ),
        )
    bundle_file = joinpath(directory, "wannierNLQG_tb.h5")
    OperatorBundleIO.write_real_space_operator_bundle(
        bundle_file,
        model.lattice,
        model.r_degeneracies,
        operators;
        profile = :hamiltonian_position,
        content_authentication,
        paired_tb_file = model_file,
        geometry = test_operator_bundle_geometry(model.lattice, model.r_degeneracies, operators),
    )
    return bundle_file
end

function run_shift_current_source(directory, model_file, bundle_file, backend)
    mixed = backend == "mixed" ? (NKdiv = (1, 1), NKFFT = (2, 2)) : NamedTuple()
    config = WannierNLQG.Runtime.EffectiveTaskConfig(;
        tasks = [("SC", "Conventional", "Integral")],
        model_file,
        real_space_operator_bundle_file = bundle_file,
        output_root = directory,
        system_name = "operator_bundle_runtime",
        k_mesh = (2, 2),
        fourier_backend = backend,
        mixed...,
        photon_energies = [0.2],
        fermi_energy = -2.5,
        progress_enabled = false,
    )
    return WannierNLQG.run(config)
end

function run_shift_current_kslice_source(directory, model_file, bundle_file)
    config = WannierNLQG.Runtime.EffectiveTaskConfig(
        tasks = [("SCK", "Conventional", "K-slice")],
        model_file = model_file,
        real_space_operator_bundle_file = bundle_file,
        output_root = directory,
        system_name = "operator_bundle_runtime_kslice",
        k_mesh = (2, 2),
        fourier_backend = "direct",
        photon_energies = [0.2],
        fermi_energy = -2.5,
        tensor_indices = (1, 1, 1),
        band_selection = (2, 1),
        kslice_origin = (0.0, 0.0, 0.0),
        kslice_vector_1 = (1.0, 0.0, 0.0),
        kslice_vector_2 = (0.0, 1.0, 0.0),
        progress_enabled = false,
    )
    return WannierNLQG.run(config)
end

@testset "Current model format, actual capabilities and exact Runtime parity" begin
    mktempdir() do directory
        model_file=TEST_MODEL_FILE
        bundle_file=write_hamiltonian_position_bundle(directory, model_file)
        manifest=OperatorBundleIO.read_real_space_operator_bundle_manifest(bundle_file)
        @test manifest.schema_version=="3.0"
        @test manifest.operator_qualification_sha256===nothing
        @test !manifest.production_eligible
        @test manifest.paired_tb_source_bytes===nothing
        HDF5.h5open(bundle_file, "r") do h
            @test !any(
                k->haskey(h, k),
                (
                    "qualification",
                    "diagnostics",
                    "compatibility",
                    "construction_evidence",
                    "paired_tb_source",
                ),
            )
            @test read(HDF5.attributes(h)["basis_metric"])=="orthonormal"
        end
        for version in ("5.9", "6.0", "6.1", "1.3")
            path=joinpath(directory, "old-$version.h5");
            cp(bundle_file, path)
            with_republished_bundle_fixture(path) do h
                HDF5.delete_attribute(h, "schema_version");
                HDF5.attributes(h)["schema_version"]=version
            end
            error=try
                OperatorBundleIO.read_real_space_operator_bundle_manifest(path);
                nothing
            catch e
                ;
                e
            end
            @test error isa ArgumentError
            @test occursin("MODEL_SCHEMA_UNSUPPORTED:", sprint(showerror, error))
        end
        requested = Dict(
            OperatorBundleCore.REAL_SPACE_HAMILTONIAN => [(Int8(0), Int8(0))],
            OperatorBundleCore.REAL_SPACE_POSITION => [(Int8(1), Int8(0))],
        )
        buffered = OperatorBundleIO.read_operator_bundle_components(
            bundle_file,
            requested;
            prefer_mmap = false,
        )
        @test buffered.read_mode == :buffered
        @test Set(keys(buffered.components)) == Set(keys(requested))

        for backend in ("direct", "mixed", "auto")
            legacy = run_shift_current_source(
                joinpath(directory, "legacy_$(backend)"),
                model_file,
                nothing,
                backend,
            )
            packed = run_shift_current_source(
                joinpath(directory, "packed_$(backend)"),
                model_file,
                bundle_file,
                backend,
            )
            @test length(legacy.outputs) == length(packed.outputs) == 1
            @test read(only(legacy.outputs)) == read(only(packed.outputs))
        end

        legacy_kslice = run_shift_current_kslice_source(
            joinpath(directory, "legacy_kslice"),
            model_file,
            nothing,
        )
        packed_kslice = run_shift_current_kslice_source(
            joinpath(directory, "packed_kslice"),
            model_file,
            bundle_file,
        )
        @test length(legacy_kslice.outputs) == length(packed_kslice.outputs)
        @test read.(legacy_kslice.outputs) == read.(packed_kslice.outputs)

        insufficient = WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("ISC", "Conventional", "Integral")],
            model_file = model_file,
            real_space_operator_bundle_file = bundle_file,
            output_root = joinpath(directory, "insufficient"),
            k_mesh = (2, 2),
            fourier_backend = "direct",
            photon_energies = [0.2],
            tensor_indices = (1, 1, 1, 1),
            progress_enabled = false,
        )
        insufficient_error = try
            WannierNLQG.run(insufficient)
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test insufficient_error !== nothing
        @test occursin("spin_times_hamiltonian", something(insufficient_error, ""))
        @test occursin(
            "Current bundle profile: hamiltonian_position",
            something(insufficient_error, ""),
        )

        mixed_sources = WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("SC", "Conventional", "Integral")],
            model_file = model_file,
            real_space_operator_bundle_file = bundle_file,
            seedname = "forbidden",
            output_root = joinpath(directory, "mixed_sources"),
            k_mesh = (2, 2),
            fourier_backend = "direct",
            progress_enabled = false,
        )
        @test_throws ErrorException WannierNLQG.run(mixed_sources)

        # An unused text alias cannot reject or alter the actual selected H/r data.
        standalone=run_shift_current_source(
            joinpath(directory, "hdf-only"),
            joinpath(directory, "absent.dat"),
            bundle_file,
            "direct",
        )
        reference=run_shift_current_source(
            joinpath(directory, "hdf-reference"),
            model_file,
            bundle_file,
            "direct",
        )
        @test read.(standalone.outputs)==read.(reference.outputs)
    end
end

@testset "Spin arrays survive removed eligibility and frame audit labels" begin
    mktempdir() do directory
        model=OperatorBundleIO.read_wannier_tb(TEST_MODEL_FILE)
        C=OperatorBundleCore
        operators=Dict(
            C.REAL_SPACE_HAMILTONIAN=>C.RealSpaceOperator(
                C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
                model.r_vectors,
                model.hamiltonian_r,
            ),
            C.REAL_SPACE_POSITION=>C.RealSpaceOperator(
                C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_POSITION, 1, -1, 1),
                model.r_vectors,
                model.position_r,
            ),
            C.REAL_SPACE_SPIN=>C.RealSpaceOperator(
                C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_SPIN, 1, 1, -1),
                model.r_vectors,
                zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3, model.num_r_vectors),
            ),
        )
        geometry=test_operator_bundle_geometry(model.lattice, model.r_degeneracies, operators)
        originals=Dict(k=>copy(v.data) for (k, v) in operators)
        for (i, value) in enumerate((1e-12, 2e-8)) # Original tolerance remains 1e-8.
            path=joinpath(directory, "spin-$i.h5")
            metadata=merge(
                test_pair_wigner_seitz_provenance(("spin",); residuals = Dict("spin"=>value)),
                Dict("production_eligible"=>false, "physics_qualification"=>"PHYSICS_HOLD"),
            )
            OperatorBundleIO.write_real_space_operator_bundle(
                path,
                model.lattice,
                model.r_degeneracies,
                operators;
                profile = :hamiltonian_position_spin,
                geometry,
                provenance = metadata,
                eligibility = metadata,
            )
            restored=OperatorBundleIO.read_real_space_operator_bundle(path)
            for (kind, op) in operators
                @test op.data==originals[kind]
                @test restored.operators[kind].data==originals[kind]
            end
            HDF5.h5open(path, "r") do h
                @test !haskey(h, "qualification")
                @test !haskey(HDF5.attributes(h), "production_eligible")
            end
        end
        # Nonfinite scientific values still fail; labels never waive that error.
        broken=copy(operators);
        p=copy(broken[C.REAL_SPACE_SPIN].data);
        p[1]=NaN
        op=C.RealSpaceOperator(
            C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_SPIN, 1, 1, -1),
            model.r_vectors,
            zeros(ComplexF64, size(p)),
        )
        op.data[1]=NaN;
        broken[C.REAL_SPACE_SPIN]=op
        @test_throws ArgumentError OperatorBundleIO.write_real_space_operator_bundle(
            joinpath(directory, "bad.h5"),
            model.lattice,
            model.r_degeneracies,
            broken;
            profile = :hamiltonian_position_spin,
            geometry,
        )
    end
end

@testset "Full eleven-operator payload, definitions and array IO remain exact" begin
    fixture=joinpath(ROOT, "examples/fixtures/synthetic_runtime/synthetic_operators.h5")
    original=OperatorBundleIO.read_real_space_operator_bundle(fixture)
    mktempdir() do directory
        restored=[]
        for (name, raw) in (
            (
                "dense",
                Dict(
                    "nested"=>Dict(
                        "indices"=>Int64[1, 2, 3],
                        "weights"=>[0.125, -2.5],
                        "valid"=>[true, false],
                    ),
                ),
            ),
            (
                "json",
                JSON3.read(
                    JSON3.write(
                        Dict(
                            "nested"=>Dict(
                                "indices"=>[1, 2, 3],
                                "weights"=>[0.125, -2.5],
                                "valid"=>[true, false],
                            ),
                        ),
                    ),
                ),
            ),
        )
            path=joinpath(directory, name*".h5")
            OperatorBundleIO.write_real_space_operator_bundle(
                path,
                original.lattice,
                original.degeneracies,
                original.operators;
                profile = :full,
                geometry = current_model_geometry(original.manifest),
                provenance = current_model_provenance(original.manifest),
                diagnostics = Dict("raw_metadata"=>raw),
            )
            actual=OperatorBundleIO.read_real_space_operator_bundle(path);
            push!(restored, actual)
            @test length(actual.operators)==11
            @test getfield.(
                actual.manifest.entries,
                :component_reference,
            )==getfield.(original.manifest.entries, :component_reference)
            for (kind, op) in original.operators
                ;
                @test actual.operators[kind].data==op.data;
            end
            HDF5.h5open(path, "r") do h
                ;
                @test !haskey(h, "diagnostics");
            end
        end
        for kind in keys(original.operators)
            ;
            @test restored[1].operators[kind].data==restored[2].operators[kind].data;
        end
        extension=Base.get_extension(WannierNLQG, :WannierNLQGOperatorBundleExt)
        path=joinpath(directory, "array-views.h5");
        matrix=reshape(collect(Int64, 1:12), 3, 4)
        HDF5.h5open(path, "w") do h
            Base.invokelatest(extension._write_metadata_value, h, "view", view(matrix, 1:2, 1:2:4))
            Base.invokelatest(extension._write_metadata_value, h, "range", 1:3)
        end
        HDF5.h5open(path, "r") do h
            @test read(h["view"])==matrix[1:2, 1:2:4]
            @test read(h["range"])==[1, 2, 3]
        end
    end
end
@testset "Packed HDF5 reads retain one observed publication lifetime" begin
    mktempdir() do directory
        bundle_file = write_hamiltonian_position_bundle(directory, TEST_MODEL_FILE)
        demand = Dict(OperatorBundleCore.REAL_SPACE_HAMILTONIAN => [(Int8(0), Int8(0))])
        missing = joinpath(directory, "missing.h5")
        @test_throws ArgumentError OperatorBundleIO.read_real_space_operator_bundle_manifest(
            missing,
        )
        @test_throws ArgumentError OperatorBundleIO.read_operator_bundle_payload(missing)
        @test_throws ArgumentError OperatorBundleIO.read_operator_bundle_components(missing, demand)
        @test_throws ArgumentError OperatorBundleIO.read_real_space_operator_bundle(missing)
        mapped = OperatorBundleIO.read_operator_bundle_components(
            bundle_file,
            demand;
            prefer_mmap = true,
        )
        buffered = OperatorBundleIO.read_operator_bundle_components(
            bundle_file,
            demand;
            prefer_mmap = false,
        )
        @test mapped.manifest.publication_identity == buffered.manifest.publication_identity
        @test mapped.components[OperatorBundleCore.REAL_SPACE_HAMILTONIAN][(Int8(0), Int8(0))] ==
              buffered.components[OperatorBundleCore.REAL_SPACE_HAMILTONIAN][(Int8(0), Int8(0))]
        @test mapped.read_mode == :mmap
        @test buffered.read_mode == :buffered
        linked = joinpath(directory, "linked-bundle.h5")
        symlink(bundle_file, linked)
        @test OperatorBundleIO.read_operator_bundle_components(linked, demand).components[OperatorBundleCore.REAL_SPACE_HAMILTONIAN][(
            Int8(0),
            Int8(0),
        )] == buffered.components[OperatorBundleCore.REAL_SPACE_HAMILTONIAN][(Int8(0), Int8(0))]
        state = OperatorBundleIO.scientific_file_state(bundle_file)
        record = OperatorBundleIO.scientific_file_record(state)
        observed =
            OperatorBundleIO.with_scientific_source(bundle_file; expected_record = record) do path
                OperatorBundleIO.read_real_space_operator_bundle_manifest(path)
            end
        @test observed.value.num_orbitals == mapped.manifest.num_orbitals
        @test_throws ArgumentError OperatorBundleIO.with_scientific_source(
            bundle_file;
            expected_record = record,
        ) do path
            value =
                OperatorBundleIO.read_operator_bundle_components(path, demand; prefer_mmap = false)
            with_republished_bundle_fixture(path) do handle
                HDF5.attributes(handle)["test_observed_change"] = "after complete component read"
            end
            value
        end
        @test_throws ArgumentError OperatorBundleIO.with_scientific_source(
            bundle_file;
            expected_record = record,
        ) do path
            OperatorBundleIO.read_real_space_operator_bundle_manifest(path)
        end
        # Re-adoption observes the actual current file; it does not refresh old credentials.
        @test OperatorBundleIO.read_real_space_operator_bundle_manifest(bundle_file).num_orbitals ==
              mapped.manifest.num_orbitals
    end
end

include("CurrentMathematicalModelChecks.jl")
