if !isdefined(@__MODULE__, :CurrentScientificValues)
    include(joinpath(@__DIR__, "support/CurrentScientificValues.jl"))
end
using HDF5
using LinearAlgebra
using SHA
using Test
using WannierNLQG

isdefined(Main, :QEPAWMatrixElementsTestSupport) ||
    include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
using .QEPAWMatrixElementsTestSupport

@testset "Public 1.0 star-gauge and fixed-subspace wire formats" begin
    wf = WannierNLQG.Wannierization
    paw = first(wf._load_wannierization_extension!()).PAWMatrixElements
    mktempdir() do directory
        fixture = write_qe_paw_fixture(
            directory;
            metric_kind = :norm_conserving,
            spinor = false,
            spinorbit = false,
        )
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            band_range = 1:1,
            include_time_reversal = false,
        )
        filename = joinpath(directory, "public-star.h5")
        prepared = wf.prepare_symmetry_covariant_wavefunctions(
            wf.SymmetryCovariantWavefunctionPreparationConfig(
                construction_policy = :standard,
                source = source,
                wavefunction_gauge_backend = wf.StarCovariantPAWGauge(
                    buffer_policy = wf.ClosureDrivenBandBuffer(max_extra_bands = 0),
                ),
                output_hdf5 = filename,
                target_band_count = 1,
            ),
        )
        @test prepared.status == :STANDARD
        filename = something(prepared.output_hdf5)
        restored = Base.invokelatest(
            paw._read_star_covariant_paw_gauge_hdf5,
            filename;
            source,
            require_pass = false,
        )
        @test restored.schema_version == "2.0"
        @testset "S1 independent plane-wave projector" begin
            # Independent synthetic source: one scalar band, one G=0 coefficient
            # equal to 1+0im in X.UPF norm-conserving metric, Gamma kpoint.
            # The star frame may differ by phase, so test the physical projector and
            # norm rather than asserting an arbitrary writer-generated phase.
            @test length(restored.payload.native.kpoints) == 1
            coefficients = restored.payload.native.kpoints[1].coefficients
            # NativeWavefunctionModels: axes are band,G,spin; this scalar
            # one-band G=0 fixture has one spin component, not a 3D adjoint.
            @test size(coefficients) == (1, 1, 1)
            scalar_coefficients = @view coefficients[:, :, 1]
            @test scalar_coefficients == ones(ComplexF64, 1, 1)
            @test scalar_coefficients * scalar_coefficients' == ones(ComplexF64, 1, 1)
            @test all(isfinite, restored.payload.native.kpoints[1].coefficients)
            @test restored.payload.rotations[:, :, 1]' * restored.payload.rotations[:, :, 1] ≈
                  ones(ComplexF64, 1, 1) atol=1e-12 rtol=0
        end
        @test restored.band_frame_contract !== nothing
        @test keys(restored) ==
              (:payload, :status, :root_cause, :diagnostics, :schema_version, :band_frame_contract)
        HDF5.h5open(filename, "r") do handle
            attributes = HDF5.attributes(handle)
            @test String(HDF5.read_attribute(attributes.parent, "schema_version")) == "2.0"
            @test !haskey(attributes, "payload_sha256")
            @test String(HDF5.read_attribute(attributes.parent, "content_authentication")) ==
                  "NOT_PERFORMED"
        end
        # A current capsule with a removed companion marker must not use the historical reader.
        for field in (
            "band_frame_contract_schema",
            "band_frame_replay_maximum",
            "band_frame_contract_definition",
        )
            tampered = joinpath(directory, "missing-$(field).h5")
            cp(filename, tampered)
            chmod(tampered, 0o600)
            HDF5.h5open(tampered, "r+") do handle
                @test haskey(HDF5.attributes(handle), field)
                HDF5.delete_attribute(handle, field)
                @test !haskey(HDF5.attributes(handle), field)
            end
            @testset "S2 missing frame attribute $(field)" begin
                failure = try
                    Base.invokelatest(
                        paw._read_star_covariant_paw_gauge_hdf5,
                        tampered;
                        source,
                        require_pass = false,
                    )
                    nothing
                catch exception
                    exception
                end
                @test failure isa ArgumentError
                @test occursin(
                    "PAW_GAUGE_ARTIFACT_TAMPERED: $(field) differs from stored complete definition",
                    sprint(showerror, failure),
                )
            end
        end
        downgraded = joinpath(directory, "legacy-digest-on-current.h5")
        cp(filename, downgraded)
        chmod(downgraded, 0o600)
        HDF5.h5open(downgraded, "r+") do handle
            # Test obsolete certification independently of missing frame data.
            @test haskey(HDF5.attributes(handle), "band_frame_contract_definition")
            @test !haskey(HDF5.attributes(handle), "payload_sha256")
            HDF5.attributes(handle)["payload_sha256"] = repeat("0", 64)
            @test String(HDF5.read_attribute(handle, "payload_sha256")) == repeat("0", 64)
        end
        @testset "S3 obsolete certificate alone" begin
            failure = try
                Base.invokelatest(
                    paw._read_star_covariant_paw_gauge_hdf5,
                    downgraded;
                    source,
                    require_pass = false,
                )
                nothing
            catch exception
                exception
            end
            @test failure isa ArgumentError
            @test occursin("STAR_GAUGE_OBSOLETE_CONTENT_CERTIFICATE", sprint(showerror, failure))
        end
        # Current writers do not fabricate archived hash-era wire formats.
        for version in ("1.0", "1.10", "1.11")
            path = joinpath(directory, "unsupported-$(version).h5")
            @test_throws ArgumentError Base.invokelatest(
                paw._write_star_covariant_paw_gauge_hdf5,
                path,
                restored.payload;
                status = :PASS,
                root_cause = restored.root_cause,
                schema_version = version,
            )
            @test !isfile(path)
        end
        history_root = joinpath(@__DIR__, "fixtures", "schema_compatibility", "star_and_fixed")
        for line in eachline(joinpath(history_root, "SHA256SUMS"))
            expected, relative = split(line; limit = 2)
            @test bytes2hex(SHA.sha256(read(joinpath(history_root, strip(relative))))) == expected
        end
        historical_source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            joinpath(history_root, "native_source", "fixture.save");
            band_range = 1:1,
            include_time_reversal = false,
        )
        for basename in ("star_gauge_1_0.h5", "star_gauge_1_11.h5")
            failure = try
                Base.invokelatest(
                    paw._read_star_covariant_paw_gauge_hdf5,
                    joinpath(history_root, basename);
                    source = historical_source,
                )
                nothing
            catch exception
                exception
            end
            @test failure isa ArgumentError
            @test occursin("STAR_GAUGE_EXPLICIT_MIGRATION_REQUIRED", sprint(showerror, failure))
        end

        fixed = wf.WannierizationFixedSubspace(
            reshape(ComplexF64[1, 0, 0, 0], 2, 2, 1),
            reshape(ComplexF64[1, 0], 2, 1, 1),
            [1],
            reshape(Bool[true, false], 2, 1);
            source_sha256 = Dict("fixture" => repeat("0", 64)),
            invariant_residuals = Dict("projector" => 0.0),
        )
        # Standalone fixed-subspace public writer/reader facades were retired.
        # The archived decoder remains in SolverCheckpoint; this test exercises
        # that explicit legacy boundary without restoring ordinary public APIs.
        @test !isdefined(wf, :write_wannierization_fixed_subspace_hdf5)
        @test !isdefined(wf, :read_wannierization_fixed_subspace_hdf5)
        solver = first(wf._load_wannierization_extension!()).SolverCheckpoint
        for basename in ("fixed_subspace_1_0.h5", "fixed_subspace_1_1.h5")
            old_fixed = Base.invokelatest(
                solver.read_wannierization_fixed_subspace_hdf5,
                joinpath(history_root, basename),
            )
            @test old_fixed.projectors == reshape(ComplexF64[1, 0, 0, 0], 2, 2, 1)
            @test old_fixed.frames == reshape(ComplexF64[1, 0], 2, 1, 1)
            @test old_fixed.irreducible_indices == [1]
            @test old_fixed.frozen_mask == reshape(Bool[true, false], 2, 1)
            for field in fieldnames(typeof(fixed))
                @test getfield(old_fixed, field) == getfield(fixed, field)
            end
        end
        invalid_fixed = joinpath(directory, "invalid-fixed-semantics.h5")
        cp(joinpath(history_root, "fixed_subspace_1_1.h5"), invalid_fixed)
        chmod(invalid_fixed, 0o600)
        HDF5.h5open(invalid_fixed, "r+") do handle
            @test String(HDF5.read_attribute(handle, "schema_version")) == "1.1"
            @test String(HDF5.read_attribute(handle, "z_u_stage_semantics")) ==
                  "disentanglement_localization_decoupled_v1"
            HDF5.delete_attribute(handle, "z_u_stage_semantics")
            HDF5.attributes(handle)["z_u_stage_semantics"] = "invalid"
            @test String(HDF5.read_attribute(handle, "z_u_stage_semantics")) == "invalid"
        end
        @testset "S8 archived fixed semantics rejection" begin
            failure = try
                Base.invokelatest(solver.read_wannierization_fixed_subspace_hdf5, invalid_fixed)
                nothing
            catch exception
                exception
            end
            @test failure isa ArgumentError
            @test occursin("fixed-subspace Z/U stage semantics differ", sprint(showerror, failure))
        end
        diagnostics = joinpath(directory, "u-diagnostics.h5")
        wf.write_wannierization_u_convergence_diagnostics_hdf5(
            diagnostics,
            NamedTuple[],
            Array{ComplexF64, 3}[],
            [1],
        )
        HDF5.h5open(diagnostics, "r") do handle
            @test String(HDF5.read_attribute(handle, "schema")) ==
                  "wanniernlqg.wannierization-u-convergence-diagnostics"
            @test String(HDF5.read_attribute(handle, "schema_version")) == "1.1"
            @test Int(HDF5.read_attribute(handle, "record_count")) == 0
            @test haskey(handle, "iterations")
            HDF5.h5open(joinpath(history_root, "u_diagnostics_1_5.h5"), "r") do historical
                @test keys(handle) == keys(historical)
                @test read(handle["irreducible_indices"]) == read(historical["irreducible_indices"])
                for key in keys(HDF5.attributes(historical))
                    key in ("schema", "schema_version") && continue
                    @test isequal(
                        HDF5.read_attribute(handle, key),
                        HDF5.read_attribute(historical, key),
                    )
                end
            end
        end
    end
end
