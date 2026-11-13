include(joinpath(@__DIR__, "WannierizationPersistenceTailContracts.jl"))
include(joinpath(@__DIR__, "WannierizationSealedPersistenceContracts.jl"))

# Decode only wholly numerical progress rows; headers remain separate assertions.
function persistence_progress_rows(text)
    rows=Vector{Float64}[]
    for line in split(text, '\n')
        values=tryparse.(Float64, split(strip(line)))
        isempty(values) || any(isnothing, values) || push!(rows, Float64.(values))
    end
    return rows
end

# Keep the large persistence assertion harness outside the concrete fixture closure.
# No production method, test statement, value, tolerance or failure expectation changes.
# This narrows test-harness inference only; runtime qualification remains pending.
@noinline Base.@nospecializeinfer function test_wannierization_persistence_body(
    @nospecialize(fixture),
    @nospecialize(nonlocalizing_config),
    @nospecialize(result),
    directory::String,
)
    representation_file = joinpath(directory, "representation.h5")
    WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
        representation_file,
        diagnostic_public_band_representation(fixture.representation),
    )
    restored_representation =
        WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(representation_file)
    @test restored_representation.sewing_matrices == fixture.representation.sewing_matrices
    @test restored_representation.kpoint_map == fixture.representation.kpoint_map
    @test restored_representation.input_sha256 == fixture.representation.input_sha256
    HDF5.h5open(representation_file, "r") do handle
        @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
        @test length(String(read(HDF5.attributes(handle)["preparation_digest"]))) == 64
        @test all(
            name -> haskey(handle, name),
            ("inventory", "qualification_scope", "raw_diagnostics", "compatibility_policy"),
        )
        @test Int(read(HDF5.attributes(handle["raw_diagnostics"])["count"])) == 8
    end
    extension, _ = WANNIERIZATION._load_wannierization_extension!()
    periodic_config = modified_wannierization_config(
        fixture.config;
        stage_controls = WANNIERIZATION.WannierizationStageControls(
            dis_num_iter = 8,
            num_iter = 0,
            dis_conv_tol = 1e-8,
            dis_conv_window = 1,
        ),
        frozen_min_ev = Inf,
        frozen_max_ev = -Inf,
        num_dump_cycles = 1,
        num_print_cycles = 1,
    )
    periodic_source = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        periodic_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test periodic_source.restart_state !== nothing
    periodic_snapshot = (
        optimizer_phase = :localization,
        z_seal_class = "NONCONVERGED_RETAINED",
        disentanglement_convergence = "NONCONVERGED_RETAINED",
        localization_convergence = "NOT_APPLICABLE",
        localization_qualification = "NOT_APPLICABLE",
        model_qualification = "NOT_AVAILABLE",
        z_steps = 1500,
        u_steps = 10,
    )
    periodic_result = Base.invokelatest(
        extension.OperatorExport._periodic_result,
        periodic_snapshot,
        something(periodic_source.restart_state),
        periodic_source.history,
        periodic_source.diagnostics,
        fixture.representation,
        periodic_config,
    )
    @test periodic_result.input_summary["algorithm_profile"] == "auto"
    @test periodic_result.input_summary["effective_algorithm_profile"] ==
          "symmetry_projected_smv_fletcher_reeves_two_stage"
    @test periodic_result.input_summary["disentanglement_algorithm"] ==
          "symmetry_projected_smv_fletcher_reeves_two_stage"
    @test periodic_result.input_summary["localization_algorithm"] ==
          "symmetry_projected_smv_fletcher_reeves_two_stage"
    @test periodic_result.input_summary["symmetry_projected_smv_fr_contract"] ==
          WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint.SYMMETRY_PROJECTED_SMV_FR_CONTRACT
    @test periodic_result.input_summary["optimizer_phase"] == "localization"
    @test periodic_result.input_summary["disentanglement_steps"] == "1500"
    @test periodic_result.input_summary["localization_steps"] == "10"
    @test periodic_result.input_summary["disentanglement_convergence"] == "NONCONVERGED_RETAINED"
    @test periodic_result.input_summary["z_seal_class"] == "NONCONVERGED_RETAINED"
    @test periodic_result.input_summary["wannierization_eligibility_strictly_converged_z_seal"] ==
          "false"
    @test periodic_result.input_summary["wannierization_eligibility_execution_eligible"] == "false"
    @test periodic_result.input_summary["localization_convergence"] == "NOT_APPLICABLE"
    @test periodic_result.input_summary["localization_qualification"] == "NOT_APPLICABLE"
    @test periodic_result.input_summary["model_qualification"] == "COMPUTATION_READY"
    @test periodic_result.input_summary["quality_review_recommended"] == "false"
    @test !any(
        diagnostic ->
            get(diagnostic.context, "gate_result", get(diagnostic.context, "result", "")) == "FAIL",
        periodic_result.diagnostics,
    )
    @test periodic_result.input_summary["wannierization_eligibility_export_eligible"] == "false"
    @test periodic_result.input_summary["wannierization_eligibility_production_eligible"] == "false"
    @test periodic_result.input_summary["global_production_eligible"] == "false"
    diagnostic_stage_summary = Base.invokelatest(
        extension.OperatorExport._periodic_stage_summary,
        merge(
            periodic_snapshot,
            (
                localization_convergence = "IN_PROGRESS",
                localization_qualification = "STANDARD",
                model_qualification = "AVAILABLE_WITH_QUALITY_WARNINGS",
            ),
        ),
    )
    @test diagnostic_stage_summary["localization_convergence"] == "IN_PROGRESS"
    @test diagnostic_stage_summary["localization_qualification"] == "STANDARD"
    @test diagnostic_stage_summary["model_qualification"] == "AVAILABLE_WITH_QUALITY_WARNINGS"
    formal_stage_summary = Base.invokelatest(
        extension.OperatorExport._periodic_stage_summary,
        merge(
            periodic_snapshot,
            (
                disentanglement_convergence = "CONVERGED",
                z_seal_class = "CONVERGED",
                localization_convergence = "IN_PROGRESS",
                localization_qualification = "FORMAL_CANDIDATE",
                model_qualification = "FORMAL_CANDIDATE",
            ),
        ),
    )
    @test formal_stage_summary["disentanglement_convergence"] == "CONVERGED"
    @test formal_stage_summary["wannierization_eligibility_strictly_converged_z_seal"] == "true"
    @test formal_stage_summary["wannierization_eligibility_qualification_status"] == "NOT_EVALUATED"
    @test formal_stage_summary["localization_qualification"] == "FORMAL_CANDIDATE"
    @test formal_stage_summary["model_qualification"] == "FORMAL_CANDIDATE"
    @test formal_stage_summary["quality_review_recommended"] == "true"
    @test formal_stage_summary["wannierization_eligibility_export_eligible"] == "false"
    structural_failure_stage_summary = Base.invokelatest(
        extension.OperatorExport._periodic_stage_summary,
        merge(
            periodic_snapshot,
            (
                disentanglement_convergence = "NONCONVERGED_RETAINED_STRUCTURAL_GATE_FAILED",
                localization_convergence = "NOT_RUN",
                localization_qualification = "NOT_RUN",
                model_qualification = "NOT_RUN/Z_STRUCTURAL_GATE_FAILED",
                u_steps = 0,
            ),
        ),
    )
    @test structural_failure_stage_summary["disentanglement_convergence"] ==
          "NONCONVERGED_RETAINED_STRUCTURAL_GATE_FAILED"
    @test structural_failure_stage_summary["localization_convergence"] == "NOT_RUN"
    @test structural_failure_stage_summary["localization_qualification"] == "NOT_RUN"
    @test structural_failure_stage_summary["model_qualification"] ==
          "NOT_RUN/Z_STRUCTURAL_GATE_FAILED"
    @test structural_failure_stage_summary["quality_review_recommended"] == "true"
    @test structural_failure_stage_summary["localization_steps"] == "0"
    @test structural_failure_stage_summary["wannierization_eligibility_export_eligible"] == "false"
    periodic_checkpoint = joinpath(directory, "periodic-profile-checkpoint.h5")
    WANNIERIZATION.write_wannierization_checkpoint_hdf5(periodic_checkpoint, periodic_result)
    restored_periodic = WANNIERIZATION.read_wannierization_checkpoint_hdf5(periodic_checkpoint)
    @test restored_periodic.input_summary["algorithm_profile"] == "auto"
    @test restored_periodic.input_summary["effective_algorithm_profile"] ==
          "symmetry_projected_smv_fletcher_reeves_two_stage"
    @test restored_periodic.input_summary["z_seal_class"] == "NONCONVERGED_RETAINED"
    @test restored_periodic.input_summary["wannierization_eligibility_strictly_converged_z_seal"] ==
          "false"
    @test restored_periodic.input_summary["wannierization_eligibility_execution_eligible"] ==
          "false"
    @test restored_periodic.input_summary["quality_review_recommended"] == "false"
    @test restored_periodic.input_summary["wannierization_eligibility_export_eligible"] == "false"
    @test restored_periodic.input_summary["global_production_eligible"] == "false"
    HDF5.h5open(periodic_checkpoint, "r") do handle
        attributes = HDF5.attributes(handle)
        @test String(read(attributes["algorithm_profile"])) == "auto"
        @test String(read(attributes["effective_algorithm_profile"])) ==
              "symmetry_projected_smv_fletcher_reeves_two_stage"
        @test String(read(attributes["z_seal_class"])) == "NONCONVERGED_RETAINED"
        @test !haskey(attributes, "qualified_z_seal")
        @test !Bool(read(attributes["global_production_eligible"]))
    end
    representation_metadata = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.read_band_representation_preparation_hdf5,
        representation_file,
        restored_representation,
    )
    @test representation_metadata.qualification_scope.diagnostic_status == :AVAILABLE
    @test Set(getfield.(representation_metadata.raw_diagnostics, :scope)) ==
          Set((:full, :outer, :frozen, :outside))
    @test representation_metadata.requested_policy == :strict
    @test representation_metadata.effective_policy == :strict
    @test length(something(representation_metadata.preparation_digest)) == 64

    legacy_representation_file = joinpath(directory, "representation-schema-1.3.h5")
    cp(representation_file, legacy_representation_file)
    chmod(legacy_representation_file, 0o600)
    HDF5.h5open(legacy_representation_file, "r+") do handle
        HDF5.delete_attribute(handle, "schema_version")
        HDF5.attributes(handle)["schema_version"] = "1.3"
    end
    @test_throws ArgumentError WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
        legacy_representation_file,
    )
    @test_throws ArgumentError Base.invokelatest(
        WannierNLQG.SymmetryFoundation.read_band_representation_preparation_hdf5,
        legacy_representation_file,
        restored_representation,
    )

    win_file = joinpath(directory, "preparation.win")
    open(win_file, "w") do io
        println(io, "num_wann = 1")
    end
    eig_file = joinpath(directory, "preparation.eig")
    open(eig_file, "w") do io
        for kpoint in 1:fixture.eig.num_kpts, band in 1:fixture.eig.num_bands
            println(io, "$(band) $(kpoint) $(fixture.eig.data[band, kpoint])")
        end
    end
    prepared_file = joinpath(directory, "prepared-representation.h5")
    prepared = WANNIERIZATION.prepare_band_representation(
        WANNIERIZATION.BandRepresentationPreparationConfig(
            construction_policy = :standard,
            wannierization_mode = :symmetry_adapted,
            win_file = win_file,
            eig_file = eig_file,
            projection_basis = fixture.basis,
            band_representation = fixture.representation,
            output_hdf5 = prepared_file,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = -0.5,
            num_wannier = 1,
            symmetry_tolerance = 2.5e-6,
            compatibility_policy = :off,
        ),
    )
    @test prepared.output_hdf5 == abspath(prepared_file)
    @test prepared.effective_compatibility_policy == :off
    @test prepared.symmetry_tolerance_status == :NOT_APPLICABLE
    @test Set(getfield.(prepared.raw_diagnostics, :scope)) ==
          Set((:full, :outer, :frozen, :outside))
    @test prepared.content_authentication == "NOT_PERFORMED"
    HDF5.h5open(prepared_file, "r") do handle
        policy = HDF5.attributes(handle["compatibility_policy"])
        @test String(read(policy["requested"])) == "off"
        @test String(read(policy["effective"])) == "off"
        @test String(read(policy["symmetry_tolerance_status"])) == "NOT_APPLICABLE"
    end
    nofrozen_prepared_file = joinpath(directory, "prepared-representation-nofrozen.h5")
    @test_throws ArgumentError WANNIERIZATION.prepare_band_representation(
        WANNIERIZATION.BandRepresentationPreparationConfig(
            construction_policy = :standard,
            wannierization_mode = :symmetry_adapted,
            win_file = win_file,
            eig_file = eig_file,
            projection_basis = fixture.basis,
            band_representation_hdf5 = prepared_file,
            output_hdf5 = joinpath(directory, "relabelled-frozen-mask.h5"),
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = 0.0,
            frozen_max_ev = 0.0,
            num_wannier = 1,
            compatibility_policy = :strict,
        ),
    )
    nofrozen_prepared = WANNIERIZATION.prepare_band_representation(
        WANNIERIZATION.BandRepresentationPreparationConfig(
            construction_policy = :standard,
            wannierization_mode = :symmetry_adapted,
            win_file = win_file,
            eig_file = eig_file,
            projection_basis = fixture.basis,
            band_representation = fixture.representation,
            output_hdf5 = nofrozen_prepared_file,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = 0.0,
            frozen_max_ev = 0.0,
            num_wannier = 1,
            compatibility_policy = :strict,
        ),
    )
    @test all(
        diagnostic -> diagnostic.status == :EMPTY_SCOPE,
        filter(diagnostic -> diagnostic.scope == :frozen, nofrozen_prepared.raw_diagnostics),
    )
    @test count(diagnostic -> diagnostic.scope == :frozen, nofrozen_prepared.raw_diagnostics) ==
          length(fixture.representation.operations) * fixture.eig.num_kpts

    identity_win_file = joinpath(directory, "identity-preparation.win")
    open(identity_win_file, "w") do io
        println(io, "num_wann = 1")
        println(io, "mp_grid = 2 1 1")
        println(io, "begin unit_cell_cart")
        println(io, "1.0 0.0 0.0")
        println(io, "0.0 1.0 0.0")
        println(io, "0.0 0.0 1.0")
        println(io, "end unit_cell_cart")
        println(io, "begin kpoints")
        println(io, "0.0 0.0 0.0")
        println(io, "0.5 0.0 0.0")
        println(io, "end kpoints")
    end
    identity_artifact = joinpath(directory, "identity-prepared.schema-1.0.h5")
    generated_identity = WANNIERIZATION.prepare_band_representation(
        WANNIERIZATION.BandRepresentationPreparationConfig(
            construction_policy = :standard,
            wannierization_mode = :ordinary,
            win_file = identity_win_file,
            eig_file = eig_file,
            projection_basis = fixture.basis,
            output_hdf5 = identity_artifact,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = -0.5,
            num_wannier = 1,
            compatibility_policy = :off,
        ),
    )
    shared_identity = WANNIERIZATION.prepare_band_representation(
        WANNIERIZATION.BandRepresentationPreparationConfig(
            construction_policy = :standard,
            wannierization_mode = :ordinary,
            win_file = identity_win_file,
            eig_file = eig_file,
            projection_basis = fixture.basis,
            band_representation_hdf5 = identity_artifact,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = -0.5,
            num_wannier = 1,
            compatibility_policy = :off,
        ),
    )
    @test shared_identity.representation.sewing_matrices ==
          generated_identity.representation.sewing_matrices
    @test shared_identity.representation.kpoint_map == generated_identity.representation.kpoint_map
    @test shared_identity.effective_compatibility_policy == :off
    @test shared_identity.symmetry_tolerance_status == :NOT_APPLICABLE
    @test shared_identity.output_hdf5 === nothing
    @test Base.invokelatest(
        extension.SolverCheckpoint._validate_no_symmetry_identity_representation,
        shared_identity.representation,
        1.0e-10,
    ) === nothing
    @test_throws ArgumentError Base.invokelatest(
        extension.SolverCheckpoint._validate_no_symmetry_identity_representation,
        fixture.representation,
        1.0e-10,
    )

    fixed_frames = copy(result.v_matrix)
    fixed_projectors = zeros(ComplexF64, 2, 2, 2)
    for kpoint in 1:2
        fixed_projectors[:, :, kpoint] .= fixed_frames[:, :, kpoint] * fixed_frames[:, :, kpoint]'
    end
    fixed_mask = BitMatrix([true true; false false])
    fixed = WANNIERIZATION.WannierizationFixedSubspace(
        fixed_projectors,
        fixed_frames,
        [1, 2],
        fixed_mask;
        invariant_residuals = Dict("isometry" => 1.0e-15),
    )
    # The independent persisted fixed-subspace workflow was explicitly retired.
    # Internal fixed-Z tensors remain tested in current checkpoint roundtrips below.
    @test fixed.projectors == fixed_projectors
    @test fixed.frames == fixed_frames
    @test fixed.frozen_mask == fixed_mask
    @test isempty(fixed.source_sha256) # No invented source authentication for this algebra fixture.
    @test !isdefined(WANNIERIZATION, :write_wannierization_fixed_subspace_hdf5)
    @test !isdefined(WANNIERIZATION, :read_wannierization_fixed_subspace_hdf5)

    # Shared representation HDF5 no longer activates the SAWF/EzXML extension.
    extension, _ = WANNIERIZATION._load_wannierization_extension!()
    @test extension !== nothing
    lattice = 2.0 .* Matrix{Float64}(I, 3, 3)
    structure = WannierNLQG.SymmetryFoundation.CrystalStructure(lattice, ["X"], zeros(3, 1))
    plane_wave = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        zeros(Int, 1, 3),
        reshape(ComplexF64[7.0], 1, 1, 1),
        [-1.0],
    )
    source_values = joinpath(directory, "native-amn-storage-values.bin")
    open(source_values, "w") do stream
        WANNIER_IO.write_native_definition_value(
            stream,
            (
                source_code = :synthetic,
                lattice = lattice,
                species = ["X"],
                positions = zeros(3, 1),
                reciprocal_lattice = pi .* Matrix{Float64}(I, 3, 3),
                mp_grid = (1, 1, 1),
                spinor = false,
                k_fractional = plane_wave.k_fractional,
                g_vectors = plane_wave.g_vectors,
                coefficients = plane_wave.coefficients,
                energies_ev = plane_wave.energies_ev,
            ),
        )
    end
    source_definition = WANNIER_IO.scientific_source_collection_definition(
        Dict("STORAGE_FIXTURE_VALUES" => source_values),
    )
    native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :synthetic,
        structure,
        pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [plane_wave],
        Dict{String, String}(),
        Dict("fixture" => "native_amn_storage_values");
        source_definition,
    )
    generated_amn =
        Base.invokelatest(extension.RepresentationPreparation._generate_amn, native, fixture.basis)
    expected_projector =
        WannierNLQG.WannierProjection.projection_orbital_values(
            first(fixture.basis.blocks),
            zeros(3),
        )[1] / sqrt(det(lattice))
    @test generated_amn[1, 1, 1] ≈ expected_projector atol = 1.0e-13 rtol = 0.0
    @test !isapprox(norm(@view(generated_amn[:, 1, 1])), 1.0; atol = 1.0e-6)
    provenance_file = joinpath(directory, "synthetic.amn-provenance.h5")
    synthetic_amn = WANNIER_IO.WannierAMN(1, 1, 1, generated_amn)
    Base.invokelatest(
        extension.RepresentationPreparation._write_amn_provenance_hdf5,
        provenance_file,
        synthetic_amn,
        fixture.basis,
        native,
    )
    HDF5.h5open(provenance_file, "r") do handle
        radial = handle["radial_transform"]
        attributes = HDF5.attributes(radial)
        @test read(attributes["method"]) == "gauss_laguerre_high_precision"
        @test read(attributes["interpolation"]) == "none"
        @test read(attributes["gauss_laguerre_order"]) == 64
        @test !haskey(attributes, "implementation_digest")
        for (key, value) in pairs(
            WannierNLQG.WannierProjection.projection_radial_transform_contract(
                fixture.basis.radial_transform,
            ),
        )
            @test isequal(read(attributes[String(key)]), value isa Symbol ? String(value) : value)
        end
    end
    @test Base.invokelatest(
        extension.WorkflowOrchestration._validate_amn_projection_contract,
        joinpath(directory, "synthetic.amn"),
        fixture.basis,
    ) == provenance_file
    compatibility_basis = WannierNLQG.WannierProjection.WannierProjectionBasis(
        fixture.basis.blocks,
        fixture.basis.num_wannier,
        fixture.basis.spinor,
        WannierNLQG.WannierProjection.ProjectionRadialTransformConfig(; method = :mixed_grid_cubic),
    )
    @test_throws ArgumentError Base.invokelatest(
        extension.WorkflowOrchestration._validate_amn_projection_contract,
        joinpath(directory, "synthetic.amn"),
        compatibility_basis,
    )

    theta_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        true,
    )
    theta_source = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        [0.25, 0.0, 0.0],
        zeros(Int, 1, 3),
        reshape(ComplexF64[1.0], 1, 1, 1),
        [-1.0],
    )
    theta_target = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        [0.75, 0.0, 0.0],
        reshape([-1, 0, 0], 1, 3),
        reshape(ComplexF64[1.0], 1, 1, 1),
        [-1.0],
    )
    theta_sewing = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.canonical_plane_wave_sewing_matrix,
        theta_source,
        theta_target,
        theta_operation,
        [-1, 0, 0],
        0.01,
    )
    @test theta_sewing ≈ ones(ComplexF64, 1, 1) atol = 1.0e-14 rtol = 0.0
    @test_throws ArgumentError Base.invokelatest(
        WannierNLQG.SymmetryFoundation.canonical_plane_wave_sewing_matrix,
        theta_source,
        theta_target,
        theta_operation,
        [0, 0, 0],
        0.01,
    )

    checkpoint_file = joinpath(directory, "checkpoint.h5")
    history = [
        WANNIERIZATION.WannierizationIteration(1, 2.0, 3.0, 4.0),
        WANNIERIZATION.WannierizationIteration(2, 1.0, 0.5, 0.25),
    ]
    persisted_result = WANNIERIZATION.WannierizationResult(
        result.status,
        result.v_matrix,
        result.wannier_centers_cartesian,
        result.spreads_angstrom2,
        history,
        result.diagnostics,
        result.input_summary,
        result.wannier_chk,
        nothing,
        result.restart_state,
        WANNIERIZATION.WannierizationArtifacts(),
    )
    written = WANNIERIZATION.write_wannierization_checkpoint_hdf5(checkpoint_file, persisted_result)
    @test written == abspath(checkpoint_file)
    restored = WANNIERIZATION.read_wannierization_checkpoint_hdf5(written)
    @test restored.status == result.status
    @test restored.v_matrix == result.v_matrix
    @test getfield.(restored.history, :iteration) == [1, 2]
    @test getfield.(restored.history, :spread_total) == [2.0, 1.0]
    @test getfield.(restored.history, :spread_standard_deviation) == [3.0, 0.5]
    @test getfield.(restored.history, :maximum_covariance_error) == [4.0, 0.25]
    @test restored.wannier_chk !== nothing
    @test restored.restart_state !== nothing
    @test restored.restart_state.frames == result.restart_state.frames
    @test restored.restart_state.optimizer_state.phase == result.restart_state.optimizer_state.phase
    @test restored.restart_state.optimizer_state.gradient_steps ==
          result.restart_state.optimizer_state.gradient_steps
    # This retained checkpoint field still has current writer/reader consumers.
    @test restored.restart_state.optimizer_state.best_polar_frames ==
          result.restart_state.optimizer_state.best_polar_frames
    @test restored.restart_state.optimizer_state.disentanglement_objective_history ==
          result.restart_state.optimizer_state.disentanglement_objective_history
    @test restored.restart_state.optimizer_state.localization_objective_history ==
          result.restart_state.optimizer_state.localization_objective_history
    @test restored.restart_state.optimizer_state.localization_trial_step_scales ==
          result.restart_state.optimizer_state.localization_trial_step_scales
    @test restored.restart_state.optimizer_state.localization_trial_objectives ==
          result.restart_state.optimizer_state.localization_trial_objectives
    @test restored.restart_state.optimizer_state.localization_trial_directional_derivatives ==
          result.restart_state.optimizer_state.localization_trial_directional_derivatives
    @test restored.restart_state.optimizer_state.localization_trial_iterations ==
          result.restart_state.optimizer_state.localization_trial_iterations
    @test restored.restart_state.optimizer_state.localization_trial_sweeps ==
          result.restart_state.optimizer_state.localization_trial_sweeps
    @test restored.restart_state.optimizer_state.localization_trial_accepted ==
          result.restart_state.optimizer_state.localization_trial_accepted
    @test restored.restart_state.optimizer_state.localization_projector_drift_history ==
          result.restart_state.optimizer_state.localization_projector_drift_history
    @test restored.restart_state.fixed_subspace_projectors ==
          result.restart_state.fixed_subspace_projectors
    @test restored.restart_state.fixed_subspace_frames == result.restart_state.fixed_subspace_frames
    HDF5.h5open(checkpoint_file, "r") do handle
        checkpoint_attributes = HDF5.attributes(handle)
        @test !haskey(checkpoint_attributes, "checkpoint_sha256")
        @test String(read(checkpoint_attributes["publication_identity"])) ==
              restored.input_summary["checkpoint_publication_identity"]
        @test String(read(checkpoint_attributes["content_authentication"])) == "NOT_PERFORMED"
        @test !haskey(checkpoint_attributes, "input_sha256")
        @test !haskey(checkpoint_attributes, "config_sha256")
        original_definition = something(result.restart_state.input_definition)
        restored_definition = something(restored.restart_state.input_definition)
        @test original_definition.configuration == restored_definition.configuration
        @test original_definition.projection_basis == restored_definition.projection_basis
        for field in (:representation, :overlaps, :initialization)
            @test WANNIER_IO.validate_scientific_input_definitions_equal(
                getfield(original_definition, field),
                getfield(restored_definition, field),
            ) === nothing
        end
        @test !Bool(read(checkpoint_attributes["production_eligible"]))
    end
    test_wannierization_sealed_persistence(fixture, directory)

    failed_trial_values = fill(ComplexF64(NaN), size(result.v_matrix))
    failed_trial = WANNIERIZATION.WannierizationResult(
        WANNIERIZATION.SINGULAR_LOCALIZATION,
        failed_trial_values,
        fill(NaN, size(result.wannier_centers_cartesian)),
        fill(NaN, size(result.spreads_angstrom2)),
        result.history,
        [
            WANNIERIZATION.WannierizationDiagnostic(
                :FAILED_TRIAL,
                :error,
                "non-finite rejected trial",
            ),
        ],
        merge(
            result.input_summary,
            Dict(
                "last_attempted_iteration" => string(result.restart_state.iteration + 1),
                "last_accepted_iteration" => string(result.restart_state.iteration),
            ),
        ),
        result.wannier_chk,
        nothing,
        result.restart_state,
        WANNIERIZATION.WannierizationArtifacts(),
    )
    failed_trial_file = joinpath(directory, "failed-trial-terminal.h5")
    WANNIERIZATION.write_wannierization_checkpoint_hdf5(failed_trial_file, failed_trial)
    retained = WANNIERIZATION.read_wannierization_checkpoint_hdf5(failed_trial_file)
    @test retained.status == WANNIERIZATION.SINGULAR_LOCALIZATION
    @test retained.v_matrix == result.restart_state.frames
    @test all(isfinite, retained.v_matrix)
    @test retained.input_summary["last_attempted_iteration"] ==
          string(result.restart_state.iteration + 1)
    @test retained.input_summary["last_accepted_iteration"] ==
          string(result.restart_state.iteration)
    @test retained.input_summary["last_persisted_iteration"] ==
          string(result.restart_state.iteration)
    for terminal_status in (
        WANNIERIZATION.COMPLETED,
        WANNIERIZATION.COMPLETED_WITH_WARNINGS,
        WANNIERIZATION.MAX_ITERATIONS,
        WANNIERIZATION.SINGULAR_LOCALIZATION,
        WANNIERIZATION.LOCALIZATION_FAILED,
        WANNIERIZATION.IO_FAILURE,
        WANNIERIZATION.INVALID_INPUT,
    )
        terminal = WANNIERIZATION.WannierizationResult(
            terminal_status,
            failed_trial.v_matrix,
            failed_trial.wannier_centers_cartesian,
            failed_trial.spreads_angstrom2,
            failed_trial.history,
            failed_trial.diagnostics,
            failed_trial.input_summary,
            failed_trial.wannier_chk,
            nothing,
            failed_trial.restart_state,
            failed_trial.artifacts,
        )
        terminal_file = joinpath(directory, "terminal-$(terminal_status).h5")
        WANNIERIZATION.write_wannierization_checkpoint_hdf5(terminal_file, terminal)
        restored_terminal = WANNIERIZATION.read_wannierization_checkpoint_hdf5(terminal_file)
        @test restored_terminal.status == terminal_status
        @test restored_terminal.v_matrix == result.restart_state.frames
        @test restored_terminal.input_summary["last_persisted_iteration"] ==
              string(result.restart_state.iteration)
    end

    legacy_checkpoint = joinpath(directory, "checkpoint-schema-1.0-migration-required.h5")
    cp(checkpoint_file, legacy_checkpoint)
    chmod(legacy_checkpoint, 0o600)
    HDF5.h5open(legacy_checkpoint, "r+") do handle
        HDF5.delete_attribute(handle, "schema_version")
        HDF5.attributes(handle)["schema_version"] = "1.0"
    end
    migration_error = try
        WANNIERIZATION.read_wannierization_checkpoint_hdf5(legacy_checkpoint)
        nothing
    catch exception
        exception
    end
    @test migration_error isa ArgumentError
    @test occursin("CHECKPOINT_SCHEMA_UNSUPPORTED", sprint(showerror, migration_error))

    tampered_file = joinpath(directory, "checkpoint-tampered.h5")
    cp(checkpoint_file, tampered_file)
    chmod(tampered_file, 0o600)
    WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(tampered_file)
    HDF5.h5open(tampered_file, "r+") do handle
        group = handle["restart_state/input_definition"]
        values = read(group["configuration_utf8"])
        values[1] = 0x00 # Corrupt the actual definition prefix, not a removed digest.
        write(group["configuration_utf8"], values)
    end
    @test_throws ArgumentError WANNIERIZATION.read_wannierization_checkpoint_hdf5(tampered_file)
    @test_throws ArgumentError WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(tampered_file)

    optimizer_tampered = joinpath(directory, "checkpoint-optimizer-tampered.h5")
    cp(checkpoint_file, optimizer_tampered)
    chmod(optimizer_tampered, 0o600)
    WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(optimizer_tampered)
    HDF5.h5open(optimizer_tampered, "r+") do handle
        optimizer_attributes = HDF5.attributes(handle["restart_state/optimizer"])
        HDF5.delete_attribute(handle["restart_state/optimizer"], "z_mix_ratio")
        # A changed finite parameter is a new artifact; the prior publication must reject.
        optimizer_attributes["z_mix_ratio"] = 0.123
    end
    @test_throws ArgumentError WANNIERIZATION.read_wannierization_checkpoint_hdf5(
        optimizer_tampered,
    )

    failed = WANNIERIZATION.WannierizationResult(
        WANNIERIZATION.MAX_ITERATIONS,
        result.v_matrix,
        result.wannier_centers_cartesian,
        result.spreads_angstrom2,
        result.history,
        [WANNIERIZATION.WannierizationDiagnostic(:TEST_NONCONVERGENCE, :warning, "fixture")],
        result.input_summary,
        result.wannier_chk,
        nothing,
        result.restart_state,
        WANNIERIZATION.WannierizationArtifacts(),
    )
    failed_path = WANNIERIZATION.write_wannierization_checkpoint_hdf5(checkpoint_file, failed)
    @test failed_path == abspath(checkpoint_file)
    @test isfile(checkpoint_file)
    failed_restored = WANNIERIZATION.read_wannierization_checkpoint_hdf5(checkpoint_file)
    @test failed_restored.status == WANNIERIZATION.MAX_ITERATIONS
    @test getfield.(failed_restored.history, :diagnostics) ==
          getfield.(failed.history, :diagnostics)
    HDF5.h5open(checkpoint_file, "r") do handle
        @test String(read(HDF5.attributes(handle)["schema_version"])) == "3.0"
        @test !Bool(read(HDF5.attributes(handle)["converged"]))
        @test Bool(read(HDF5.attributes(handle)["quality_review_recommended"]))
        @test Int(read(HDF5.attributes(handle)["last_accepted_iteration"])) ==
              result.restart_state.iteration
        @test Int(read(HDF5.attributes(handle)["last_persisted_iteration"])) ==
              result.restart_state.iteration
    end
    exact_reference_state = (
        recursive_localization_overlaps = ones(ComplexF64, 1, 1, 1, 1),
        recursive_localization_unitaries = ones(ComplexF64, 1, 1, 1),
        recursive_localization_omega_i = 0.0,
    )
    ordinary_rcg_state = (
        recursive_localization_overlaps = zeros(ComplexF64, 0, 0, 0, 0),
        recursive_localization_unitaries = zeros(ComplexF64, 0, 0, 0),
        recursive_localization_omega_i = NaN,
    )
    incomplete_reference_state = (
        recursive_localization_overlaps = ones(ComplexF64, 1, 1, 1, 1),
        recursive_localization_unitaries = zeros(ComplexF64, 0, 0, 0),
        recursive_localization_omega_i = 0.0,
    )
    @test Base.invokelatest(
        extension.SolverCheckpoint._checkpoint_cg_iteration_is_valid,
        exact_reference_state,
        0,
    )
    @test !Base.invokelatest(
        extension.SolverCheckpoint._checkpoint_cg_iteration_is_valid,
        ordinary_rcg_state,
        0,
    )
    @test Base.invokelatest(
        extension.SolverCheckpoint._checkpoint_cg_iteration_is_valid,
        ordinary_rcg_state,
        1,
    )
    @test_throws ArgumentError Base.invokelatest(
        extension.SolverCheckpoint._checkpoint_cg_iteration_is_valid,
        incomplete_reference_state,
        0,
    )

    construction_diagnostics = Dict{String, Any}()
    model = WANNIERIZATION.build_wannier_tight_binding_model(
        result,
        fixture.eig,
        fixture.mmn;
        construction_diagnostics,
    )
    @test construction_diagnostics["real_space_replica_policy"] == "minimum_distance"
    @test construction_diagnostics["hamiltonian_fourier_roundtrip_residual"] <= 1.0e-10
    @test construction_diagnostics["position_fourier_roundtrip_residual"] <= 1.0e-10
    incomplete_mmn = WANNIER_IO.WannierMMN(
        fixture.mmn.num_bands,
        fixture.mmn.num_kpts,
        2,
        fixture.mmn.data[:, :, 1:2, :],
        fixture.mmn.neighbors[1:2, :],
        fixture.mmn.reciprocal_shifts[:, 1:2, :],
    )
    @test_throws ArgumentError WANNIERIZATION.build_wannier_tight_binding_model(
        result,
        fixture.eig,
        incomplete_mmn,
    )
    accepted_state_model =
        WANNIERIZATION.build_wannier_tight_binding_model(failed, fixture.eig, fixture.mmn)
    @test accepted_state_model.hamiltonian_r == model.hamiltonian_r
    @test_throws MethodError WANNIERIZATION.build_wannier_tight_binding_model(
        result,
        fixture.eig,
        fixture.mmn;
        allow_legacy_diagnostic_export = true,
    )
    @test Base.invokelatest(
        extension.OperatorExport._real_space_hermiticity_error,
        model.position_r,
        model.r_vectors,
    ) <= 1.0e-14
    @test Base.invokelatest(extension.OperatorExport._tb_centers, model) ≈
          result.wannier_centers_cartesian atol = 1.0e-14 rtol = 0.0
    perturbed_mmn_data = copy(fixture.mmn.data)
    perturbed_mmn_data[1, 1, 1, 1] += 0.03 + 0.02im
    perturbed_mmn = WANNIER_IO.WannierMMN(
        fixture.mmn.num_bands,
        fixture.mmn.num_kpts,
        fixture.mmn.num_neighbors,
        perturbed_mmn_data,
        fixture.mmn.neighbors,
        fixture.mmn.reciprocal_shifts,
    )
    perturbed_model =
        WANNIERIZATION.build_wannier_tight_binding_model(result, fixture.eig, perturbed_mmn)
    @test Base.invokelatest(
        extension.OperatorExport._real_space_hermiticity_error,
        perturbed_model.position_r,
        perturbed_model.r_vectors,
    ) <= 1.0e-14
    @test Base.invokelatest(extension.OperatorExport._tb_centers, perturbed_model) ≈
          result.wannier_centers_cartesian atol = 1.0e-14 rtol = 0.0
    output_config = WANNIERIZATION._replace_wannierization_config(
        nonlocalizing_config;
        checkpoint = (checkpoint_hdf5 = joinpath(directory, "synthetic.wannierization.h5"),),
        output = (tb_output_formats = (:packed_hdf5, :model_tb), write_model_tb = true),
    )
    paths = Base.invokelatest(
        extension.OperatorExport._wannierization_output_paths,
        output_config.checkpoint.checkpoint_hdf5,
    )
    @test paths.validated === nothing
    @test paths.log == joinpath(directory, "synthetic.out")
    @test paths.packed == joinpath(directory, "synthetic.h5")
    @test paths.wannier == joinpath(directory, "synthetic_tb.dat")
    @test paths.tb_symmetry_json === nothing
    @test_throws ArgumentError Base.invokelatest(
        extension.OperatorExport._wannierization_output_paths,
        joinpath(directory, "legacy.sawf.h5"),
    )
    @test_throws ArgumentError WANNIERIZATION.write_wannierization_checkpoint_hdf5(
        joinpath(directory, "legacy.sawf.h5"),
        result,
    )
    diagnostic_packed, diagnostic_exchange, diagnostic_metadata = Base.invokelatest(
        extension.OperatorExport._export_wannierization_tb,
        failed,
        fixture.eig,
        fixture.mmn,
        output_config,
        paths,
        nothing,
    )
    @test isfile(diagnostic_packed)
    @test isfile(diagnostic_exchange)
    @test diagnostic_metadata["model_availability"] == "AVAILABLE_WITH_QUALITY_WARNINGS"
    @test parse(Float64, diagnostic_metadata["tb_hamiltonian_fourier_roundtrip_residual"]) <=
          1.0e-10
    @test parse(Float64, diagnostic_metadata["tb_position_fourier_roundtrip_residual"]) <= 1.0e-10
    diagnostic_manifest = WANNIER_IO.read_real_space_operator_bundle_manifest(diagnostic_packed)
    # Warnings stay in the result/metadata; mathematical model fields are not credentials.
    @test !diagnostic_manifest.quality_review_recommended
    @test !something(diagnostic_manifest.production_eligible, true)
    hamiltonian_qualification =
        diagnostic_manifest.operator_qualification["operators"]["hamiltonian"]
    authority_contract_sha256 = Base.invokelatest(
        extension.PAWMatrixElements._star_authoritative_hamiltonian_definition,
        output_config.input.authoritative_hamiltonian,
    )
    raw_authority = Base.invokelatest(
        extension.OperatorExport.authoritative_band_hamiltonian,
        output_config,
        fixture.eig,
    )
    @test !haskey(raw_authority.input_definitions, "AUTHORITATIVE_HAMILTONIAN_SHA256")
    # The actual stored H(R) is the mathematical model. Original EIG reference
    # inventories have no ordinary model-reader consumer and are not credentials.
    @test !haskey(hamiltonian_qualification, "authoritative_hamiltonian_definition")
    @test !haskey(hamiltonian_qualification, "authoritative_hamiltonian_input_definitions")
    loaded_h = WANNIER_IO.read_real_space_operator_bundle(diagnostic_packed)
    @test loaded_h.operators[WannierNLQG.Core.REAL_SPACE_HAMILTONIAN].data == model.hamiltonian_r
    @test hamiltonian_qualification["authoritative_hamiltonian_policy_definition"] ==
          authority_contract_sha256
    @test authority_contract_sha256 != raw_authority.definition
    # Independent accepted-state exports must not overwrite an earlier attempt.
    diagnostic_digest = bytes2hex(open(SHA.sha256, diagnostic_packed))
    @test_throws ArgumentError Base.invokelatest(
        extension.OperatorExport._export_wannierization_tb,
        result,
        fixture.eig,
        fixture.mmn,
        output_config,
        paths,
        nothing,
    )
    accepted_config = WANNIERIZATION._replace_wannierization_config(
        output_config;
        checkpoint = (checkpoint_hdf5 = joinpath(directory, "accepted.wannierization.h5"),),
    )
    accepted_paths = Base.invokelatest(
        extension.OperatorExport._wannierization_output_paths,
        accepted_config.checkpoint.checkpoint_hdf5,
    )
    packed, exchange, _ = Base.invokelatest(
        extension.OperatorExport._export_wannierization_tb,
        result,
        fixture.eig,
        fixture.mmn,
        accepted_config,
        accepted_paths,
        nothing,
    )
    @test bytes2hex(open(SHA.sha256, diagnostic_packed)) == diagnostic_digest
    strict_config = WANNIERIZATION._replace_wannierization_config(
        accepted_config;
        input = (construction_policy = :strict,),
        checkpoint = (checkpoint_hdf5 = joinpath(directory, "strict.wannierization.h5"),),
    )
    strict_paths = Base.invokelatest(
        extension.OperatorExport._wannierization_output_paths,
        strict_config.checkpoint.checkpoint_hdf5,
    )
    @test_throws ArgumentError Base.invokelatest(
        extension.OperatorExport._export_wannierization_tb,
        result,
        fixture.eig,
        fixture.mmn,
        strict_config,
        strict_paths,
        nothing,
    )
    accepted_digest = bytes2hex(open(SHA.sha256, packed))
    @test_throws ArgumentError Base.invokelatest(
        extension.OperatorExport._export_wannierization_tb,
        result,
        fixture.eig,
        fixture.mmn,
        accepted_config,
        accepted_paths,
        nothing,
    )
    @test bytes2hex(open(SHA.sha256, packed)) == accepted_digest
    manifest = WANNIER_IO.read_real_space_operator_bundle_manifest(packed)
    @test !isempty(manifest.publication_identity)
    @test !haskey(result.input_summary, "input_sha256")
    @test manifest.solver_validation_ready === nothing
    @test !manifest.post_validation_present

    source_digest = bytes2hex(open(SHA.sha256, packed))
    validated = joinpath(directory, "legacy-labels.wannierization-tb.h5")
    cp(packed, validated);
    chmod(validated, 0o600)
    # Historical labels are not current model admission or scientific evidence.
    HDF5.h5open(validated, "r+") do handle
        group = HDF5.create_group(handle, "post_export_validation")
        attrs = HDF5.attributes(group)
        attrs["schema"] = "wanniernlqg.post-export-validation"
        attrs["schema_version"] = "1.0"
        attrs["final_tb_usability"] = "PRODUCTION_ELIGIBLE"
        attrs["final_physics_qualification"] = "QUALIFIED"
        attrs["final_production_eligible"] = true
    end
    WANNIER_IO.adopt_real_space_operator_bundle(validated)
    validated_manifest = WANNIER_IO.read_real_space_operator_bundle_manifest(validated)
    @test !validated_manifest.post_validation_present
    @test validated_manifest.final_tb_usability === nothing
    @test validated_manifest.final_physics_qualification === nothing
    @test validated_manifest.final_production_eligible === nothing
    @test validated_manifest.post_validation_source_sha256 === nothing
    @test validated_manifest.post_validation_content_sha256 === nothing
    @test validated_manifest.publication_identity == abspath(validated)
    @test validated_manifest.inventory == manifest.inventory
    @test validated_manifest.lattice == manifest.lattice
    @test validated_manifest.r_vectors == manifest.r_vectors
    HDF5.h5open(packed, "r") do original
        HDF5.h5open(validated, "r") do labelled
            @test isequal(
                read(original["payload/complex128"]),
                read(labelled["payload/complex128"]),
            )
        end
    end
    @test bytes2hex(open(SHA.sha256, packed)) == source_digest

    tampered = joinpath(directory, "tampered.wannierization-tb.h5")
    cp(validated, tampered);
    chmod(tampered, 0o600)
    HDF5.h5open(tampered, "r+") do handle
        group = handle["operators/hamiltonian"]
        HDF5.delete_attribute(group, "units")
        HDF5.attributes(group)["units"] = "WRONG_UNIT"
    end
    @test_throws ArgumentError WANNIER_IO.adopt_real_space_operator_bundle(tampered)
    @test_throws ArgumentError WANNIER_IO.read_real_space_operator_bundle_manifest(tampered)

    converged_packed, converged_exchange = packed, exchange
    eligible_result = WANNIERIZATION.WannierizationResult(
        result.status,
        result.v_matrix,
        result.wannier_centers_cartesian,
        result.spreads_angstrom2,
        result.history,
        result.diagnostics,
        result.input_summary,
        result.wannier_chk,
        checkpoint_file,
        result.restart_state,
        WANNIERIZATION.WannierizationArtifacts(
            checkpoint_hdf5 = checkpoint_file,
            packed_hdf5 = converged_packed,
            model_tb = converged_exchange,
        ),
    )
    WANNIERIZATION.write_wannierization_checkpoint_hdf5(checkpoint_file, eligible_result)
    historical_suffix = joinpath(directory, "historical.sawf.h5")
    cp(checkpoint_file, historical_suffix)
    historical_sha256 = bytes2hex(SHA.sha256(read(historical_suffix)))
    WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(historical_suffix)
    historical_result = WANNIERIZATION.read_wannierization_checkpoint_hdf5(historical_suffix)
    @test historical_result.v_matrix == eligible_result.v_matrix
    @test bytes2hex(SHA.sha256(read(historical_suffix))) == historical_sha256
    HDF5.h5open(checkpoint_file, "r") do handle
        @test !Bool(read(HDF5.attributes(handle)["production_eligible"]))
        @test Bool(read(HDF5.attributes(handle)["quality_review_recommended"]))
    end
    band_qualified = Base.invokelatest(
        extension.WannierizationInternalSupport.updated_wannierization_result,
        eligible_result;
        input_summary = merge(
            eligible_result.input_summary,
            Dict(
                "construction_policy" => "strict",
                "optimizer_schedule" => "two_stage",
                "u_acceptance" => "armijo",
                "representation_compatible" => "true",
                "physics_qualification" => "QUALIFIED",
                "band_validation_pass" => "true",
                "z_seal_class" => "CONVERGED",
                "wannierization_eligibility_strictly_converged_z_seal" => "true",
                "wannierization_eligibility_export_eligible" => "true",
            ),
        ),
        tb_symmetry_qualification = WANNIERIZATION.TBSymmetryQualification(
            "PASS",
            "SYNTHETIC_PRODUCTION_GATE_FIXTURE",
            WANNIERIZATION.TBSymmetryMetric[],
        ),
    )
    @test Base.invokelatest(
        extension.SolverCheckpoint._wannierization_production_eligible,
        band_qualified,
    )
    no_symmetry_qualified = Base.invokelatest(
        extension.WannierizationInternalSupport.updated_wannierization_result,
        band_qualified;
        input_summary = merge(
            band_qualified.input_summary,
            Dict("representation_compatible" => "NOT_APPLICABLE"),
        ),
        tb_symmetry_qualification = Base.invokelatest(
            extension.OperatorExport._tb_symmetry_incomplete,
            "NONTRIVIAL_SYMMETRY_PLAN_NOT_AVAILABLE",
            1.0e-8,
        ),
    )
    @test !Base.invokelatest(
        extension.SolverCheckpoint._wannierization_production_eligible,
        no_symmetry_qualified,
    )
    diagnostic_acceptance = Base.invokelatest(
        extension.WannierizationInternalSupport.updated_wannierization_result,
        band_qualified;
        input_summary = merge(band_qualified.input_summary, Dict("u_acceptance" => "monotone")),
    )
    @test !Base.invokelatest(
        extension.SolverCheckpoint._wannierization_production_eligible,
        diagnostic_acceptance,
    )
    converged_manifest = WANNIER_IO.read_real_space_operator_bundle_manifest(converged_packed)
    @test !converged_manifest.production_eligible
    @test converged_manifest.tb_usability === nothing
    @test converged_manifest.physics_qualification === nothing
    @test model.num_orbitals == 1
    for kpoint in ([0.0, 0.0, 0.0], [0.173, 0.0, 0.0], [0.5, 0.0, 0.0])
        hamiltonian = sum(
            cis(2.0pi * dot(kpoint, model.r_vectors[:, r_index])) *
            model.hamiltonian_r[:, :, r_index] for r_index in 1:model.num_r_vectors
        )
        @test maximum(abs, hamiltonian - hamiltonian') <= 1.0e-12
    end

    report = WANNIERIZATION.validate_band_representation_compatibility(
        fixture.representation,
        fixture.plan;
        tolerance = fixture.config.input.representation_tolerance,
    )
    log_file = joinpath(directory, "synthetic.wannierization.out")
    log_io = Base.invokelatest(
        extension.OperatorExport._open_wannierization_log,
        log_file,
        output_config,
        fixture.representation;
        compatibility = report,
        restart = false,
    )
    snapshot = (
        completed_stage = :localization,
        optimizer_phase = :localization,
        z_steps = 0,
        u_steps = 2,
        omega_i = 0.75,
        iteration = 2,
        spread_total = 1.0,
        convergence_metric = 0.5,
        maximum_covariance_error = 0.25,
        little_group_iterations = 3,
        little_group_residual = 0.125,
        elapsed_seconds = 4.0,
        centers = result.wannier_centers_cartesian,
        spreads = result.spreads_angstrom2,
    )
    Base.invokelatest(
        extension.OperatorExport._write_wannierization_progress,
        log_io,
        snapshot,
        checkpoint_file,
        output_config,
    )
    @test output_config.solver.acceleration.schedule == :two_stage
    disentanglement_snapshot = merge(
        snapshot,
        (
            optimizer_phase = :localization,
            completed_stage = :disentanglement,
            z_steps = 2,
            u_steps = 0,
            omega_i = 0.75,
            delta_omega_i = 0.01,
            z_stability_count = 2,
        ),
    )
    disentanglement_io = IOBuffer()
    Base.invokelatest(
        extension.OperatorExport._write_wannierization_progress,
        disentanglement_io,
        disentanglement_snapshot,
        nothing,
        output_config,
        fixture.representation;
        heading = "DISENTANGLEMENT FINAL",
    )
    disentanglement_text = String(take!(disentanglement_io))
    @test occursin("[DISENTANGLEMENT]", disentanglement_text)
    @test occursin("Omega_I (A^2)", disentanglement_text)
    @test occursin("Z rel.change", disentanglement_text)
    @test persistence_progress_rows(disentanglement_text) == [[2.0, 2.0, 0.75, 0.01, 4.0]]
    @test !occursin("Omega (A^2)", disentanglement_text)
    @test !occursin("Per-Wannier-state spreading", disentanglement_text)

    boundary_io = IOBuffer()
    # Current stage boundaries publish the accepted checkpoint as well as
    # the log. Reuse the complete periodic fixture and real accepted state;
    # a log-only snapshot with `nothing` state is no longer this contract.
    boundary_snapshot = merge(disentanglement_snapshot, periodic_snapshot)
    boundary_paths =
        merge(paths, (checkpoint = joinpath(directory, "stage-boundary.wannierization.h5"),))
    boundary_observer = Base.invokelatest(
        extension.OperatorExport._wannierization_observer,
        periodic_config,
        fixture.representation,
        boundary_paths,
        boundary_io,
    )
    Base.invokelatest(
        boundary_observer,
        boundary_snapshot,
        something(periodic_source.restart_state),
        periodic_source.history,
        periodic_source.diagnostics,
    )
    boundary_saved = WANNIERIZATION.read_wannierization_checkpoint_hdf5(boundary_paths.checkpoint)
    @test boundary_saved.v_matrix == periodic_source.restart_state.frames
    @test boundary_saved.input_summary["disentanglement_steps"] == "1500"
    @test boundary_saved.input_summary["localization_steps"] == "10"
    boundary_text = String(take!(boundary_io))
    @test length(findall("[DISENTANGLEMENT]", boundary_text)) == 1
    @test !occursin("[ITERATION", boundary_text)

    localization_io = IOBuffer()
    localization_snapshot = merge(
        snapshot,
        (
            optimizer_phase = :localization,
            completed_stage = :localization,
            omega_i = 0.75,
            spread_total = 0.75,
            convergence_metric = 0.0,
            spreads = zero.(result.spreads_angstrom2),
            u_stability_count = 3,
        ),
    )
    Base.invokelatest(
        extension.OperatorExport._write_wannierization_progress,
        localization_io,
        localization_snapshot,
        nothing,
        output_config,
        fixture.representation,
    )
    localization_text = String(take!(localization_io))
    @test persistence_progress_rows(localization_text) == [[2.0, 2.0, 0.75, 0.75, 0.0, 4.0]]
    @test !occursin("Per-Wannier-state spreading", localization_text)

    Base.invokelatest(
        extension.OperatorExport._write_wannierization_final,
        log_io,
        failed,
        output_config,
        WANNIERIZATION.WannierizationArtifacts(
            checkpoint_hdf5 = checkpoint_file,
            wannierization_log = log_file,
            packed_hdf5 = packed,
            model_tb = exchange,
        );
        wall_time = 5.0,
        allocated_bytes = 6,
        gc_time = 0.5,
    )
    close(log_io)
    log_text = read(log_file, String)
    @test !occursin(r"source_sha256\s+=\s+", log_text)
    @test occursin("WannierNLQG WANNIERIZATION", log_text)
    @test all(
        section->occursin(section, log_text),
        (
            "[INPUT]",
            "[SOLVER CONFIGURATION]",
            "[PROGRESS]",
            "[FINAL CENTERS AND SPREADS]",
            "[FINAL STATUS AND TIMING]",
            "[VALIDATION]",
        ),
    )
    @test !occursin("[TB SYMMETRY]", log_text)
    @test !occursin("CONSTRUCTION GATE AND QUALITY SUMMARY", log_text)
    @test !occursin(log_file, log_text)
    json_file=replace(log_file, r"\.out$"=>".json")
    @test isfile(json_file)
    @test !isfile(replace(log_file, r"\.out$"=>"-diagnostics.jsonl"))
    report_json=JSON3.read(read(json_file, String))
    @test String(report_json.schema)=="wanniernlqg.model-report"
    @test String(report_json.final.solver_status)==string(failed.status)
    @test collect(report_json.final.spreads_angstrom2)==failed.spreads_angstrom2
    @test report_json.final.sum_spreads_angstrom2==sum(failed.spreads_angstrom2)
    @test report_json.timing.workflow_try_seconds==5.0
    @test report_json.timing.gc_seconds_included==0.5
    @test report_json.timing.allocated_bytes==6
    @test report_json.solver_configuration.stage_controls.num_iter==output_config.solver.stage_controls.num_iter
    @test report_json.solver_configuration.stage_controls.dis_num_iter==output_config.solver.stage_controls.dis_num_iter
    @test !report_json.validation.tb_symmetry.requested
    @test !isempty(report_json.validation.warnings) || !isempty(report_json.validation.errors)

    ordinary_auto = WANNIERIZATION._replace_wannierization_config(
        output_config;
        input = (wannierization_mode = :ordinary, band_representation = nothing),
        output = (final_tb_symmetry_report_enabled = nothing,),
    )
    ordinary_log = joinpath(directory, "ordinary-auto.wannierization.out")
    ordinary_io = open(ordinary_log, "w")
    Base.invokelatest(
        extension.OperatorExport._write_wannierization_final,
        ordinary_io,
        failed,
        ordinary_auto,
        WANNIERIZATION.WannierizationArtifacts(wannierization_log = ordinary_log);
        wall_time = 0.0,
        allocated_bytes = 0,
        gc_time = 0.0,
    )
    close(ordinary_io)
    @test !occursin("[TB SYMMETRY]", read(ordinary_log, String))
    ordinary_forced = WANNIERIZATION._replace_wannierization_config(
        ordinary_auto;
        output = (final_tb_symmetry_report_enabled = true,),
    )
    forced_log = joinpath(directory, "ordinary-forced.wannierization.out")
    forced_io = open(forced_log, "w")
    Base.invokelatest(
        extension.OperatorExport._write_wannierization_final,
        forced_io,
        failed,
        ordinary_forced,
        WANNIERIZATION.WannierizationArtifacts(wannierization_log = forced_log);
        wall_time = 0.0,
        allocated_bytes = 0,
        gc_time = 0.0,
    )
    close(forced_io)
    forced_text = read(forced_log, String)
    @test occursin("[TB SYMMETRY]", forced_text)
    forced_json=JSON3.read(read(replace(forced_log, r"\.out$"=>".json"), String))
    @test forced_json.validation.tb_symmetry.requested
    @test !forced_json.validation.tb_symmetry.performed
    @test !forced_json.validation.tb_symmetry.complete
    @test !isempty(String(forced_json.validation.tb_symmetry.reason))

    no_localization = Base.invokelatest(
        extension.WannierizationInternalSupport.updated_wannierization_result,
        failed;
        input_summary = merge(failed.input_summary, Dict("localization_steps" => "0")),
    )
    no_localization_io = IOBuffer()
    Base.invokelatest(
        extension.OperatorExport._write_wannierization_final,
        no_localization_io,
        no_localization,
        output_config,
        WANNIERIZATION.WannierizationArtifacts();
        wall_time = 0.0,
        allocated_bytes = 0,
        gc_time = 0.0,
    )
    no_localization_text = String(take!(no_localization_io))
    @test occursin("[FINAL CENTERS AND SPREADS]", no_localization_text)
    test_wannierization_persistence_report_tail(
        fixture,
        result,
        failed,
        output_config,
        ordinary_forced,
        paths,
        diagnostic_packed,
        snapshot,
        no_localization,
        extension,
        directory,
    )
end

@testset "Wannierization HDF5 and tight-binding boundaries" begin
    fixture = synthetic_wannierization_fixture()
    # Exercise the current fixed solver accepted-state export boundary with free Z.
    nonlocalizing_config = modified_wannierization_config(
        fixture.config;
        construction_policy = :standard,
        stage_controls = WANNIERIZATION.WannierizationStageControls(
            dis_num_iter = 8,
            num_iter = 0,
            dis_conv_tol = 1e-8,
            dis_conv_window = 1,
        ),
    )
    result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        nonlocalizing_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    mktempdir() do directory
        test_wannierization_persistence_body(fixture, nonlocalizing_config, result, directory)
    end
end
