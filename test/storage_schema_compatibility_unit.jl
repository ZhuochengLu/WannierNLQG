using HDF5
using SHA
using Test
using WannierNLQG

include(joinpath(@__DIR__, "StorageSchemaTestSupport.jl"))

# Change one attribute without leaving an HDF5 attribute handle open.
function storage_replace_attribute!(object, name, value)
    HDF5.delete_attribute(object, name)
    HDF5.attributes(object)[name] = value
end

function storage_replace_restart_stencil(state, stencil)
    return WannierNLQG.Wannierization.WannierizationRestartState(
        state.iteration,
        state.frames,
        state.z_previous,
        state.centers_cartesian,
        state.spreads_angstrom2,
        state.convergence_values,
        state.included_bands,
        state.elapsed_seconds,
        state.config_sha256,
        state.representation_sha256,
        stencil,
        state.projection_basis_sha256,
        state.amn_sha256,
        state.optimizer_state,
        state.fixed_subspace_projectors,
        state.fixed_subspace_frames,
        state.localization_initial_frames,
    )
end

@testset "Public 1.0 storage identity and legacy digest compatibility" begin
    fixture_root = joinpath(@__DIR__, "fixtures", "schema_compatibility")
    for line in eachline(joinpath(fixture_root, "SHA256SUMS"))
        digest, filename = split(line; limit = 2)
        @test bytes2hex(SHA.sha256(read(joinpath(fixture_root, strip(filename))))) == digest
    end
    io = WannierNLQG.IO
    w = WannierNLQG.Wannierization
    solver = first(w._load_wannierization_extension!()).SolverCheckpoint
    old_checkpoint = joinpath(fixture_root, "restart_checkpoint_2_28.h5")
    old_bundle = joinpath(fixture_root, "packed_6_3.h5")
    old_result = w.read_wannierization_checkpoint_hdf5(old_checkpoint)
    @test old_result.restart_state !== nothing
    @test old_result.input_summary["construction_policy"] == "strict"
    @test old_result.status in (w.COMPLETED, w.COMPLETED_WITH_WARNINGS, w.MAX_ITERATIONS)
    abnormal_result =
        w.read_wannierization_checkpoint_hdf5(joinpath(fixture_root, "checkpoint_2_28.h5"))
    @test abnormal_result.restart_state === nothing
    old_operators = io.read_real_space_operator_bundle(old_bundle)
    @test old_result.input_summary["checkpoint_schema_version"] == "2.28"
    @test old_result.input_summary["restart_eligible"] == "true"
    @test old_operators.manifest.schema_version == "6.3"
    mktempdir() do directory
        checkpoint = joinpath(directory, "checkpoint_1_0.h5")
        w.write_wannierization_checkpoint_hdf5(checkpoint, old_result)
        restored = w.read_wannierization_checkpoint_hdf5(checkpoint)
        @test restored.input_summary["checkpoint_schema_version"] == "1.0"
        @test restored.input_summary["construction_policy"] == "strict"
        @test restored.input_summary["restart_eligible"] == "true"
        @test restored.v_matrix == old_result.v_matrix
        @test restored.wannier_centers_cartesian == old_result.wannier_centers_cartesian
        @test restored.spreads_angstrom2 == old_result.spreads_angstrom2
        @test isequal(restored.history, old_result.history)
        @test solver._wannierization_checkpoint_sha256_v2_28(restored) ==
              solver._wannierization_checkpoint_sha256_v2_28(old_result)
        for field in (:v_matrix, :wannier_centers_cartesian, :spreads_angstrom2)
            @test reinterpret(UInt8, vec(getfield(restored, field))) ==
                  reinterpret(UInt8, vec(getfield(old_result, field)))
        end
        @test solver._wannierization_checkpoint_sha256_v1_0(restored) !=
              solver._wannierization_checkpoint_sha256_v2_28(old_result)
        # The frozen legacy fixture has the same two-k-point solver input.
        fixture = storage_schema_restart_fixture()
        diagnostic_config = w._replace_wannierization_config(
            fixture.config;
            input = (construction_policy = :diagnostic,),
        )
        @test solver._restart_config_sha256(diagnostic_config) !=
              solver._restart_config_sha256(fixture.config)
        diagnostic_contract = solver.WannierizationRestartContract(diagnostic_config)
        @test all(isnothing, diagnostic_contract.legacy_sha256)
        continuation_config =
            w._replace_wannierization_config(fixture.config; solver = (max_iterations = 4,))
        current_stencil = solver._finite_difference_weights(fixture.representation, fixture.mmn)
        stored_stencil = something(old_result.restart_state.stencil)
        @test solver._restart_stencils_compatible(stored_stencil, current_stencil)
        rounded_weights = nextfloat.(stored_stencil.weights)
        rounded_stencil = w.WannierizationFiniteDifferenceStencil(
            stored_stencil.vectors_cartesian,
            stored_stencil.shell_ids,
            rounded_weights,
            stored_stencil.target_moment,
            nextfloat(stored_stencil.completeness_residual),
            solver._finite_difference_stencil_sha256(
                stored_stencil.vectors_cartesian,
                stored_stencil.shell_ids,
                rounded_weights,
                stored_stencil.target_moment,
            ),
        )
        @test rounded_stencil.digest != stored_stencil.digest
        @test solver._restart_stencils_compatible(stored_stencil, rounded_stencil)
        bad_digest_stencil = w.WannierizationFiniteDifferenceStencil(
            stored_stencil.vectors_cartesian,
            stored_stencil.shell_ids,
            stored_stencil.weights,
            stored_stencil.target_moment,
            stored_stencil.completeness_residual,
            repeat("0", 64),
        )
        @test !solver._restart_stencils_compatible(bad_digest_stencil, current_stencil)
        perturbed_weights = copy(stored_stencil.weights)
        perturbed_weights[1] += 1.0e-10
        perturbed_stencil = w.WannierizationFiniteDifferenceStencil(
            stored_stencil.vectors_cartesian,
            stored_stencil.shell_ids,
            perturbed_weights,
            stored_stencil.target_moment,
            stored_stencil.completeness_residual,
            solver._finite_difference_stencil_sha256(
                stored_stencil.vectors_cartesian,
                stored_stencil.shell_ids,
                perturbed_weights,
                stored_stencil.target_moment,
            ),
        )
        @test !solver._restart_stencils_compatible(perturbed_stencil, current_stencil)
        for (restart_stencil, expected_status, expected_code) in (
            (
                rounded_stencil,
                (w.COMPLETED, w.COMPLETED_WITH_WARNINGS, w.MAX_ITERATIONS),
                :RESTART_STENCIL_CROSS_PLATFORM_COMPATIBILITY,
            ),
            (bad_digest_stencil, (w.INVALID_INPUT,), :RESTART_STENCIL_MISMATCH),
            (perturbed_stencil, (w.INVALID_INPUT,), :RESTART_STENCIL_MISMATCH),
        )
            restart_state = storage_replace_restart_stencil(
                something(old_result.restart_state),
                restart_stencil,
            )
            result = w._solve_symmetry_adapted_wannierization(
                continuation_config,
                fixture.representation,
                fixture.eig,
                fixture.mmn,
                fixture.plan;
                restart = old_result.v_matrix,
                restart_state,
                restart_history = old_result.history,
            )
            @test result.status in expected_status
            @test any(diagnostic -> diagnostic.code == expected_code, result.diagnostics)
            if result.status == w.INVALID_INPUT
                @test isempty(result.history)
            else
                @test result.input_summary["restart_stencil_compatibility"] ==
                      "CROSS_PLATFORM_ROUNDOFF_EQUIVALENT"
            end
        end
        continued = map((old_result, restored)) do state
            w._solve_symmetry_adapted_wannierization(
                continuation_config,
                fixture.representation,
                fixture.eig,
                fixture.mmn,
                fixture.plan;
                restart = state.v_matrix,
                restart_state = state.restart_state,
                restart_history = state.history,
            )
        end
        for result in continued
            @test result.status in (w.COMPLETED, w.COMPLETED_WITH_WARNINGS, w.MAX_ITERATIONS)
            @test !isempty(result.history)
            @test last(result.history).iteration > old_result.restart_state.iteration
        end
        @test continued[1].v_matrix == continued[2].v_matrix
        @test continued[1].spreads_angstrom2 == continued[2].spreads_angstrom2
        @test isequal(continued[1].history, continued[2].history)
        @test continued[1].status == continued[2].status
        for (name, mutate!) in (
            ("relabel_old", h -> storage_replace_attribute!(h, "schema_version", "1.0")),
            ("unknown_version", h -> storage_replace_attribute!(h, "schema_version", "9.99")),
            (
                "bad_digest",
                h -> storage_replace_attribute!(h, "checkpoint_sha256", repeat("0", 64)),
            ),
        )
            file = joinpath(directory, name * ".h5")
            cp(old_checkpoint, file)
            HDF5.h5open(mutate!, file, "r+")
            @test_throws ArgumentError w.read_wannierization_checkpoint_hdf5(file)
        end
        missing = joinpath(directory, "missing_authority.h5")
        cp(checkpoint, missing)
        HDF5.h5open(missing, "r+") do h
            HDF5.delete_attribute(h["input_summary"], "authoritative_hamiltonian")
        end
        @test_throws ArgumentError w.read_wannierization_checkpoint_hdf5(missing)

        # Decode original metadata and rewrite the numerical operators through the public writer.
        extension, _ = io._load_operator_bundle_extension!()
        metadata = HDF5.h5open(old_bundle, "r") do h
            Dict(
                name => extension._read_metadata_tree(h[name]) for
                name in ("geometry", "provenance", "symmetry", "diagnostics")
            )
        end
        manifest = old_operators.manifest
        bundle = joinpath(directory, "packed_1_0.h5")
        io.write_real_space_operator_bundle(
            bundle,
            old_operators.lattice,
            old_operators.degeneracies,
            old_operators.operators;
            profile = manifest.profile,
            paired_tb_sha256 = manifest.paired_tb_sha256,
            geometry = metadata["geometry"],
            provenance = metadata["provenance"],
            symmetry = metadata["symmetry"],
            diagnostics = metadata["diagnostics"],
            eligibility = Dict(
                "production_eligible" => manifest.production_eligible,
                "authoritative_hamiltonian" => manifest.authoritative_hamiltonian,
                "authoritative_hamiltonian_sha256" => manifest.authoritative_hamiltonian_sha256,
            ),
        )
        upgraded = io.read_real_space_operator_bundle(bundle)
        @test upgraded.manifest.schema_version == "1.0"
        @test upgraded.manifest.scientific_content_sha256 != manifest.scientific_content_sha256
        @test upgraded.manifest.operator_qualification_sha256 ==
              manifest.operator_qualification_sha256
        @test upgraded.manifest.production_eligible == manifest.production_eligible
        @test upgraded.manifest.spin_family_production_eligible ==
              manifest.spin_family_production_eligible
        @test upgraded.manifest.finite_band_galerkin_production_eligible ==
              manifest.finite_band_galerkin_production_eligible
        for kind in manifest.inventory
            @test upgraded.operators[kind].data == old_operators.operators[kind].data
            @test reinterpret(UInt8, vec(upgraded.operators[kind].data)) ==
                  reinterpret(UInt8, vec(old_operators.operators[kind].data))
            @test eltype(upgraded.operators[kind].data) ==
                  eltype(old_operators.operators[kind].data)
        end
        for (name, mutate!) in (
            ("relabel_old_bundle", h -> storage_replace_attribute!(h, "schema_version", "1.0")),
            (
                "unknown_bundle_version",
                h -> storage_replace_attribute!(h, "schema_version", "9.99"),
            ),
            (
                "bad_bundle_digest",
                h -> storage_replace_attribute!(h, "scientific_content_sha256", repeat("0", 64)),
            ),
            (
                "bad_pair_reference",
                h -> storage_replace_attribute!(h, "paired_tb_sha256", repeat("0", 64)),
            ),
        )
            file = joinpath(directory, name * ".h5")
            cp(old_bundle, file)
            HDF5.h5open(mutate!, file, "r+")
            @test_throws ArgumentError io.read_real_space_operator_bundle_manifest(file)
        end
        missing_bundle = joinpath(directory, "missing_qualification.h5")
        cp(bundle, missing_bundle)
        HDF5.h5open(missing_bundle, "r+") do h
            HDF5.delete_object(h, "qualification")
        end
        @test_throws ArgumentError io.read_real_space_operator_bundle_manifest(missing_bundle)
    end
end
