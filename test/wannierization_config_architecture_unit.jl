using Test
# R16 syntax check: no source evaluation or scientific invocation.
_r16_parse_error(node) =
    node isa Expr && (node.head in (:error, :incomplete) || any(_r16_parse_error, node.args))
@testset "R16 changed test source parses" begin
    for relative in (
        "ext/WannierNLQGWannierizationExt/star_gauge/PreparationExecution.jl",
        "ext/WannierNLQGWannierizationExt/star_gauge/ConstructionWorkflow.jl",
        "test/SolverStageCharacterizationProbe.jl",
        "test/StarGaugeFreshReadProbe.jl",
        "test/StarGaugeThreadProbe.jl",
        "test/SymmetrizedDFTHamiltonianFreshReadProbe.jl",
        "test/VASPPawSPNProvenanceFreshReadProbe.jl",
        "test/WannierStageRestartLifecycleTests.jl",
        "test/WannierStandardExportTestSupport.jl",
        "test/WannierizationFreshProcessProbe.jl",
        "test/WannierizationOrdinaryContracts.jl",
        "test/WannierizationStageAcceptanceContracts.jl",
        "test/WannierizationPersistenceContracts.jl",
        "test/WannierizationRecoveryMathContracts.jl",
        "test/WannierizationSealedPersistenceContracts.jl",
        "test/WannierizationStageAcceptanceContracts.jl",
        "test/WannierizationThreadDeterminismProbe.jl",
        "test/api_snapshot_unit.jl",
        "test/augmentation_aware_sewing_unit.jl",
        "test/checkpoint_definition_unit.jl",
        "test/disk_bounded_gauge_unit.jl",
        "test/generator_schema_migration_unit.jl",
        "src/Runtime/TaskInput.jl",
        "src/Runtime/TaskConfiguration.jl",
        "ext/WannierNLQGOperatorBundleExt/CurrentModelFormat.jl",
        "test/named_task_input_contracts.jl",
        "test/task_input_unit.jl",
        "test/task_input_overrides_unit.jl",
        "test/automatic_band_path_unit.jl",
        "test/paw_scdm_initialization_unit.jl",
        "test/per_task_parallel_unit.jl",
        "test/periodic_checkpoint_metadata_unit.jl",
        "test/preparation_storage_unit.jl",
        "test/projection_representation_materialization_unit.jl",
        "test/projection_representation_models_unit.jl",
        "test/projection_representation_persistence_unit.jl",
        "test/projection_representation_search_unit.jl",
        "test/star_covariant_paw_gauge_thread_determinism_unit.jl",
        "test/star_covariant_paw_gauge_unit.jl",
        "test/star_fixed_schema_unification_unit.jl",
        "test/storage_schema_compatibility_unit.jl",
        "test/support/CurrentScientificValues.jl",
        "test/support/ParallelReferenceSupport.jl",
        "test/support/ProjectionSearchFixtureSupport.jl",
        "test/target_scope_authority_unit.jl",
        "test/target_subspace_persistence_unit.jl",
        "test/vasp_paw_matrix_elements_unit.jl",
        "test/vasp_paw_spn_unit.jl",
        "test/wannier_hamiltonian_operator_generation_unit.jl",
        "test/wannier_uiu_generation_unit.jl",
        "test/wannierization_config_architecture_unit.jl",
        "test/wannierization_construction_solver_unit.jl",
        "test/wannierization_standard_export_unit.jl",
    )
        filename = joinpath(dirname(@__DIR__), relative)
        tree = Meta.parseall(read(filename, String); filename)
        @test !_r16_parse_error(tree)
    end
end

const GROUPED_W = WannierNLQG.Wannierization

@testset "Typed frontend and application owner integration preserves grouped values" begin
    input=GROUPED_W.WannierizationInputConfig(
        wannierization_mode = :ordinary,
        eig_file = "owner.eig",
        mmn_file = "owner.mmn",
        num_wannier = 2,
        frozen_states = [(1, 1)],
    )
    changed=GROUPED_W.replace_wannierization_input(input, (num_wannier = 3,))
    @test changed.num_wannier==3 && input.num_wannier==2
    @test all(
        name->name==:num_wannier || isequal(getfield(input, name), getfield(changed, name)),
        fieldnames(typeof(input)),
    )
    @test changed.frozen_states === input.frozen_states
    @test_throws MethodError GROUPED_W.replace_wannierization_input(
        input,
        (nonexistent_input_field = 1,),
    )
    config=GROUPED_W.WannierizationConfig(input = input)
    actual=GROUPED_W.reconfigure_wannierization(config; input = (eig_file = "relocated.eig",))
    @test actual.input.eig_file=="relocated.eig" && config.input.eig_file=="owner.eig"
    @test all(
        name->name==:eig_file || isequal(getfield(input, name), getfield(actual.input, name)),
        fieldnames(typeof(input)),
    )
    @test actual.input.frozen_states === input.frozen_states
    @test actual.solver === config.solver
    @test actual.checkpoint === config.checkpoint
    @test actual.runtime === config.runtime
    @test actual.output === config.output
    @test_throws MethodError GROUPED_W.reconfigure_wannierization(
        config;
        nonexistent_group = (x = 1,),
    )
end
@testset "Current-only grouped restart identity" begin
    ext, _=GROUPED_W._load_wannierization_extension!()
    @test fieldnames(
        GROUPED_W.WannierizationConfig,
    )==(:input, :solver, :checkpoint, :runtime, :output)
    strict_config = GROUPED_W.WannierizationConfig(
        input = GROUPED_W.WannierizationInputConfig(
            construction_policy = :strict,
            # Isolate the removed-policy negative. The default :auto mode
            # requires a native source or supplied SAWF representation first.
            wannierization_mode = :ordinary,
            win_file = "g.win",
            eig_file = "g.eig",
            mmn_file = "g.mmn",
        ),
    )
    strict_error = try
        GROUPED_W._restart_config_repr(strict_config)
        nothing
    catch exception
        exception
    end
    @test strict_error isa ArgumentError
    @test strict_error isa ArgumentError && occursin(
        "construction_policy=:strict is an invalid parameter",
        sprint(showerror, strict_error),
    )
    missing_source = GROUPED_W.WannierizationConfig(
        input = GROUPED_W.WannierizationInputConfig(
            wannierization_mode = :auto,
            win_file = "g.win",
            eig_file = "g.eig",
            mmn_file = "g.mmn",
        ),
    )
    source_error = try
        GROUPED_W._restart_config_repr(missing_source)
        nothing
    catch exception
        exception
    end
    @test source_error isa ArgumentError
    @test source_error isa ArgumentError &&
          occursin("REPRESENTATION_SOURCE_MISSING", sprint(showerror, source_error))
    for policy in (:standard,)
        config=GROUPED_W.WannierizationConfig(
            input = GROUPED_W.WannierizationInputConfig(
                construction_policy = policy,
                wannierization_mode = :ordinary,
                win_file = "g.win",
                eig_file = "g.eig",
                mmn_file = "g.mmn",
            ),
        )
        contract=Base.invokelatest(ext.WannierizationRestartContract, config)
        @test !hasproperty(contract, :legacy_sha256)
        @test contract.canonical_representation==GROUPED_W._restart_config_repr(config)
        @test !hasproperty(contract, :current_sha256)
        @test !isempty(contract.canonical_representation)
        @test !isempty(contract.numerical_values)
        output_only=GROUPED_W._replace_wannierization_config(config; output = (profile = :full,))
        report_only=GROUPED_W._replace_wannierization_config(
            config;
            output = (final_tb_symmetry_report_enabled = true,),
        )
        changed=GROUPED_W._replace_wannierization_config(config; solver = (z_mix_ratio = 0.4,))
        augmented=GROUPED_W._replace_wannierization_config(
            config;
            input = (sewing_backend = GROUPED_W.AugmentationAwareSewing(),),
        )
        @test GROUPED_W._restart_config_repr(output_only)==contract.canonical_representation
        @test GROUPED_W._restart_config_repr(report_only)==contract.canonical_representation
        @test GROUPED_W._restart_config_repr(changed)!=contract.canonical_representation
        @test GROUPED_W._restart_config_repr(augmented)!=contract.canonical_representation
    end
    for name in (
        :_restart_config_sha256_pre_v2_6,
        :_restart_config_sha256_pre_v2_7,
        :_restart_config_sha256_pre_v2_11,
    )
        @test !isdefined(GROUPED_W, name)
        @test !haskey(ext.TEST_ENTRYPOINT_OWNERS, name)
    end
end
