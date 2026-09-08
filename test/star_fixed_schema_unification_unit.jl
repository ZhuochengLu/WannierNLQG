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
                construction_policy = :strict,
                source = source,
                wavefunction_gauge_backend = wf.StarCovariantPAWGauge(
                    buffer_policy = wf.ClosureDrivenBandBuffer(max_extra_bands = 0),
                ),
                output_hdf5 = filename,
                target_band_count = 1,
            ),
        )
        @test prepared.status == :PASS
        restored = Base.invokelatest(paw._read_star_covariant_paw_gauge_hdf5, filename; source)
        @test restored.schema_version == "1.0"
        @test restored.band_frame_contract !== nothing
        @test keys(restored) ==
              (:payload, :status, :root_cause, :diagnostics, :schema_version, :band_frame_contract)
        HDF5.h5open(filename, "r") do handle
            attributes = HDF5.attributes(handle)
            @test String(read(attributes["schema_version"])) == "1.0"
            @test String(read(attributes["payload_sha256"])) ==
                  Base.invokelatest(paw._star_payload_sha256, restored.payload)
        end
        # A current capsule with a removed companion marker must not use the historical reader.
        for field in ("band_frame_contract_schema", "band_frame_replay_maximum")
            tampered = joinpath(directory, "missing-$(field).h5")
            cp(filename, tampered)
            HDF5.h5open(tampered, "r+") do handle
                HDF5.delete_attribute(handle, field)
            end
            @test_throws ArgumentError Base.invokelatest(
                paw._read_star_covariant_paw_gauge_hdf5,
                tampered;
                source,
            )
        end
        downgraded = joinpath(directory, "legacy-digest-on-current.h5")
        cp(filename, downgraded)
        HDF5.h5open(downgraded, "r+") do handle
            HDF5.delete_attribute(handle, "payload_sha256")
            HDF5.attributes(handle)["payload_sha256"] = Base.invokelatest(
                paw._star_payload_sha256,
                restored.payload;
                schema_version = "1.0",
                contract_version = "1.0",
            )
        end
        @test_throws ArgumentError Base.invokelatest(
            paw._read_star_covariant_paw_gauge_hdf5,
            downgraded;
            source,
        )
        for old_version in ("1.10", "1.11")
            historical = joinpath(directory, "historical-$(old_version).h5")
            Base.invokelatest(
                paw._write_star_covariant_paw_gauge_hdf5,
                historical,
                deepcopy(restored.payload);
                status = :PASS,
                root_cause = restored.root_cause,
                schema_version = old_version,
            )
            old = Base.invokelatest(paw._read_star_covariant_paw_gauge_hdf5, historical; source)
            @test old.schema_version == old_version
            @test (old.band_frame_contract !== nothing) == (old_version == "1.11")
            @test old.payload.rotations == restored.payload.rotations
            @test old.payload.native.kpoints[1].coefficients ==
                  restored.payload.native.kpoints[1].coefficients
        end
        legacy_payload = deepcopy(restored.payload)
        for key in collect(keys(legacy_payload.source_metadata))
            startswith(key, "band_frame_") && delete!(legacy_payload.source_metadata, key)
        end
        for key in collect(keys(legacy_payload.input_sha256))
            startswith(key, "BAND_FRAME_") && delete!(legacy_payload.input_sha256, key)
        end
        historical = joinpath(directory, "historical-1.0.h5")
        Base.invokelatest(
            paw._write_star_covariant_paw_gauge_hdf5,
            historical,
            legacy_payload;
            status = :PASS,
            root_cause = restored.root_cause,
            schema_version = "1.0",
            contract_version = "1.0",
        )
        old = Base.invokelatest(paw._read_star_covariant_paw_gauge_hdf5, historical; source)
        @test old.schema_version == "1.0"
        @test old.band_frame_contract === nothing
        @test old.payload.rotations == restored.payload.rotations
        @test old.payload.native.kpoints[1].coefficients ==
              restored.payload.native.kpoints[1].coefficients

        # Frozen baseline-writer fixtures have their own byte-sealed synthetic source.
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
        for (version, basename) in (("1.0", "star_gauge_1_0.h5"), ("1.11", "star_gauge_1_11.h5"))
            historical_read = Base.invokelatest(
                paw._read_star_covariant_paw_gauge_hdf5,
                joinpath(history_root, basename);
                source = historical_source,
            )
            @test historical_read.schema_version == version
            @test (historical_read.band_frame_contract !== nothing) == (version == "1.11")
            @test historical_read.payload.rotations == restored.payload.rotations
            @test historical_read.payload.native.kpoints[1].coefficients ==
                  restored.payload.native.kpoints[1].coefficients
            generation_contract = Base.invokelatest(
                paw._generation_band_gauge_contract,
                historical_source,
                wf.NativeDFTHamiltonian(),
                joinpath(history_root, basename),
                1,
                1,
            )
            @test generation_contract.legacy == (version == "1.0")
            @test generation_contract.status == (version == "1.0" ? "LEGACY_IDENTITY_ONLY" : "PASS")
            @test (generation_contract.rotations === nothing) == (version == "1.0")
            # A byte-matched legacy artifact remains ineligible for formal operator closure.
            # The valid topology ensures the failure is the frame qualification gate.
            topology = (
                num_bands = 1,
                num_kpts = 1,
                num_neighbors = 1,
                neighbors = ones(Int, 1, 1),
                reciprocal_shifts = zeros(Int, 3, 1, 1),
                source_sha256 = repeat("a", 64),
            )
            operator_export = first(wf._load_wannierization_extension!()).OperatorExport
            failure = try
                Base.invokelatest(
                    operator_export._hamiltonian_operator_closure_scope,
                    joinpath(history_root, basename),
                    generation_contract,
                    topology,
                )
                nothing
            catch exception
                exception
            end
            @test failure isa ArgumentError
            expected_gate =
                version == "1.0" ? "CLOSURE_SCOPE_FRAME_CONTRACT_NOT_FORMALLY_QUALIFIED" :
                "CLOSURE_QUALIFICATION_SCOPE_REQUIRED"
            @test occursin(expected_gate, sprint(showerror, failure))
        end

        fixed = wf.WannierizationFixedSubspace(
            reshape(ComplexF64[1, 0, 0, 0], 2, 2, 1),
            reshape(ComplexF64[1, 0], 2, 1, 1),
            [1],
            reshape(Bool[true, false], 2, 1);
            source_sha256 = Dict("fixture" => repeat("0", 64)),
            invariant_residuals = Dict("projector" => 0.0),
        )
        fixed_file = joinpath(directory, "fixed.h5")
        wf.write_wannierization_fixed_subspace_hdf5(fixed_file, fixed)
        HDF5.h5open(fixed_file, "r") do handle
            @test String(read(HDF5.attributes(handle)["schema"])) ==
                  "wanniernlqg.wannierization-fixed-subspace"
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
        end
        for version in ("1.0", "1.1")
            path = joinpath(directory, "fixed-$(version).h5")
            cp(fixed_file, path)
            HDF5.h5open(path, "r+") do handle
                HDF5.delete_attribute(handle, "schema_version")
                HDF5.attributes(handle)["schema_version"] = version
                version == "1.0" && HDF5.delete_attribute(handle, "z_u_stage_semantics")
            end
            readback = wf.read_wannierization_fixed_subspace_hdf5(path)
            for field in fieldnames(typeof(fixed))
                @test getfield(readback, field) == getfield(fixed, field)
            end
        end
        for basename in ("fixed_subspace_1_0.h5", "fixed_subspace_1_1.h5")
            old_fixed = wf.read_wannierization_fixed_subspace_hdf5(joinpath(history_root, basename))
            for field in fieldnames(typeof(fixed))
                @test getfield(old_fixed, field) == getfield(fixed, field)
            end
        end
        HDF5.h5open(fixed_file, "r+") do handle
            HDF5.delete_attribute(handle, "z_u_stage_semantics")
            HDF5.attributes(handle)["z_u_stage_semantics"] = "invalid"
        end
        @test_throws ArgumentError wf.read_wannierization_fixed_subspace_hdf5(fixed_file)
        diagnostics = joinpath(directory, "u-diagnostics.h5")
        wf.write_wannierization_u_convergence_diagnostics_hdf5(
            diagnostics,
            NamedTuple[],
            Array{ComplexF64, 3}[],
            [1],
        )
        HDF5.h5open(diagnostics, "r") do handle
            @test String(read(HDF5.attributes(handle)["schema"])) ==
                  "wanniernlqg.wannierization-u-convergence-diagnostics"
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
            @test Int(read(HDF5.attributes(handle)["record_count"])) == 0
            @test haskey(handle, "iterations")
            HDF5.h5open(joinpath(history_root, "u_diagnostics_1_5.h5"), "r") do historical
                @test keys(handle) == keys(historical)
                @test read(handle["irreducible_indices"]) == read(historical["irreducible_indices"])
                for key in keys(HDF5.attributes(historical))
                    key in ("schema", "schema_version") && continue
                    @test isequal(
                        read(HDF5.attributes(handle)[key]),
                        read(HDF5.attributes(historical)[key]),
                    )
                end
            end
        end
    end
end
