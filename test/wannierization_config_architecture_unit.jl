using EzXML
using HDF5
using JSON3
using Test

const GROUPED_W = WannierNLQG.Wannierization

function restart_digest_family(config)
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
    contract = Base.invokelatest(extension.WannierizationRestartContract, config)
    return merge((current = contract.current_sha256,), contract.legacy_sha256)
end

@testset "grouped Wannierization configuration architecture" begin
    @test fieldnames(GROUPED_W.SymmetryAdaptedWannierizationConfig) ==
          (:input, :solver, :checkpoint, :runtime, :output)
    @test length(GROUPED_W.WANNIERIZATION_INPUT_CONFIG_FIELDS) == 28
    @test length(GROUPED_W.WANNIERIZATION_SOLVER_CONFIG_FIELDS) == 20
    @test length(GROUPED_W.WANNIERIZATION_CHECKPOINT_CONFIG_FIELDS) == 4
    @test length(GROUPED_W.WANNIERIZATION_RUNTIME_CONFIG_FIELDS) == 2
    @test length(GROUPED_W.WANNIERIZATION_OUTPUT_CONFIG_FIELDS) == 21
    @test length(GROUPED_W.WANNIERIZATION_CONFIG_LEAF_FIELDS) == 75
    @test length(unique(GROUPED_W.WANNIERIZATION_CONFIG_LEAF_FIELDS)) == 75
    artifacts = GROUPED_W.WannierizationArtifacts(wannierization_log = "run.wannierization.out")
    @test artifacts.wannierization_log == "run.wannierization.out"
    @test !hasproperty(artifacts, :sawf_log)
    source = read(joinpath(@__DIR__, "..", "scripts", "ArchitectureContracts.jl"), String)
    @test occursin("typed_sawf_flat_config_reads", source)
    @test_throws UndefKeywordError GROUPED_W.SymmetryAdaptedWannierizationConfig(
        win_file = "removed.win",
        eig_file = "removed.eig",
        mmn_file = "removed.mmn",
    )
    @test Set(names(GROUPED_W; all = false, imported = false)) == Set((
        :Wannierization,
        :SymmetryAdaptedWannierizationConfig,
        :WannierizationResult,
        :construct_symmetry_adapted_wannier_functions,
    ))

    ordinary_default = GROUPED_W.SymmetryAdaptedWannierizationConfig(
        input = GROUPED_W.WannierizationInputConfig(
            construction_policy = :strict,
            wannierization_mode = :ordinary,
            win_file = "golden.win",
            eig_file = "golden.eig",
            mmn_file = "golden.mmn",
        ),
    )
    @test propertynames(ordinary_default) == (:input, :solver, :checkpoint, :runtime, :output)
    @test !hasproperty(ordinary_default, :win_file)
    @test_throws ErrorException ordinary_default.win_file
    @test restart_digest_family(ordinary_default) == (
        current = "740e55436c908b0195427331ed258fedc94b3b2a4b1c6b89a74a92be5e2445ee",
        pre_v2_12 = "450d0a67efc00cb8e8de3828880417dbc394370f6d7b1fe779d863121de0815c",
        pre_v2_11 = "35fcae359a5b650ab1f69796b6e11a40a21fde2cbf524c1af39752c6621d51f3",
        pre_v2_10 = "08ef45cf3f5cbde79b888280aeb262fb31344465beb13349a2780aa2e92e4603",
        pre_v2_9 = "e5e82a3cd7c3ce0c57997e1b3a276f2f9a91a6f60689f5a2c91db8e3ed9498ab",
        pre_v2_8 = "4a083b94d976030751ab8338795235b51fc332cbbd0713895b7aae28b0899c35",
        pre_v2_7 = "98f330c0fc03f1ba98fb5dd4f49aba3b6131980f1023f6017157e328def54cad",
        pre_v2_6 = "7667757b789afc08e2fdb99663be0d003117b7c172347f8731b4abc5f0157798",
    )

    output_only = GROUPED_W._replace_wannierization_config(
        ordinary_default;
        output = (profile = :full,),
        runtime = (progress_interval = 1,),
    )
    trajectory_change =
        GROUPED_W._replace_wannierization_config(ordinary_default; solver = (z_mix_ratio = 0.4,))
    @test restart_digest_family(output_only) == restart_digest_family(ordinary_default)
    symmetry_report_only = GROUPED_W._replace_wannierization_config(
        ordinary_default;
        output = (final_tb_symmetry_report_enabled = true,),
    )
    @test restart_digest_family(symmetry_report_only) == restart_digest_family(ordinary_default)
    @test restart_digest_family(trajectory_change) != restart_digest_family(ordinary_default)

    ordinary_custom = GROUPED_W.SymmetryAdaptedWannierizationConfig(
        input = GROUPED_W.WannierizationInputConfig(
            construction_policy = :strict,
            wannierization_mode = :ordinary,
            win_file = "g.win",
            eig_file = "g.eig",
            mmn_file = "g.mmn",
            outer_min_ev = -3.2,
            outer_max_ev = 4.7,
            frozen_min_ev = -1.1,
            frozen_max_ev = 0.3,
            frozen_states = [(2, 3), (1, 2)],
            num_wannier = 4,
            compatibility_policy = :strict,
        ),
        solver = GROUPED_W.WannierizationSolverConfig(
            z_mix_ratio = 0.4,
            u_mix_ratio = 0.8,
            convergence_tolerance = 2.0e-10,
            localize = false,
            parallel = :threads,
            random_seed = UInt64(17),
        ),
    )
    @test restart_digest_family(ordinary_custom) == (
        current = "b684cb255155bda8c603c0b0ddbb61f67c6af476788b587e3563f6eb61cedf08",
        pre_v2_12 = "ed9ef002d62d83a7d02a28a97eb8dfb206f7fbbc3055bf5ac3d9f52ca077d820",
        pre_v2_11 = "4d085ec548b1fc2bd819cbe7225fb2ae1a871c48f87d4a71affffb0116545289",
        pre_v2_10 = "0a110436023be6b5ca08b25ec5536ea6f73289b974e7033e507bddfb61c96367",
        pre_v2_9 = "469e3412f712b81cb86a3642e1a47f2134989f2acd98c7b9ea7cf3bad16a5369",
        pre_v2_8 = "7c7a8ccb2c08425260fcd52f1096ed728b93f07a9562558b0b1ccfb67444bce0",
        pre_v2_7 = "683c128ce02c7b128afd2d54770537dd7842bd0cb91837f8cc19707d2fe8dde3",
        pre_v2_6 = "5af51b81fb01fed2441472d3f2febf3aa5f570c5dc5bcd8bcfaafe56198cb2ec",
    )

    augmented = GROUPED_W.SymmetryAdaptedWannierizationConfig(
        input = GROUPED_W.WannierizationInputConfig(
            construction_policy = :strict,
            wannierization_mode = :ordinary,
            sewing_backend = GROUPED_W.AugmentationAwareSewing(),
            win_file = "a.win",
            eig_file = "a.eig",
            mmn_file = "a.mmn",
        ),
    )
    @test restart_digest_family(augmented) == (
        current = "cded9e831fcab7b0ff76981687b6eb89e9856db66b75ce9d7ba0cb1122f3b4c1",
        pre_v2_12 = "ffb62830479700920807da90f08464b8f24940fe908ad35a270b7779cdb83ef6",
        pre_v2_11 = nothing,
        pre_v2_10 = "08ef45cf3f5cbde79b888280aeb262fb31344465beb13349a2780aa2e92e4603",
        pre_v2_9 = "e5e82a3cd7c3ce0c57997e1b3a276f2f9a91a6f60689f5a2c91db8e3ed9498ab",
        pre_v2_8 = "4a083b94d976030751ab8338795235b51fc332cbbd0713895b7aae28b0899c35",
        pre_v2_7 = "98f330c0fc03f1ba98fb5dd4f49aba3b6131980f1023f6017157e328def54cad",
        pre_v2_6 = "7667757b789afc08e2fdb99663be0d003117b7c172347f8731b4abc5f0157798",
    )
end
