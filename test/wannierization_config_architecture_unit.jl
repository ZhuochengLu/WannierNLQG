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
    @test length(GROUPED_W.WANNIERIZATION_INPUT_CONFIG_FIELDS) == 27
    @test length(GROUPED_W.WANNIERIZATION_SOLVER_CONFIG_FIELDS) == 20
    @test length(GROUPED_W.WANNIERIZATION_CHECKPOINT_CONFIG_FIELDS) == 4
    @test length(GROUPED_W.WANNIERIZATION_RUNTIME_CONFIG_FIELDS) == 2
    @test length(GROUPED_W.WANNIERIZATION_OUTPUT_CONFIG_FIELDS) == 20
    @test length(GROUPED_W.WANNIERIZATION_CONFIG_LEAF_FIELDS) == 73
    @test length(unique(GROUPED_W.WANNIERIZATION_CONFIG_LEAF_FIELDS)) == 73
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
        current = "a9bcfa6cf580bcc42608a657a7e25ecde3b5c00ea4023962a36ea4cdf9d10c68",
        pre_v2_12 = "3c3cf66184240ff665bfa4302f5fa8fe74b4d10158ff81d7e4f77705ed4925e5",
        pre_v2_11 = "555ceb7144cb7fe752a90cb7e3bd6558248949fc12c13f49b031f524a5ca4566",
        pre_v2_10 = "831780264f5aad536bca5592d8978fe62f5ef81ab8527972c72faa95370e5f2b",
        pre_v2_9 = "a4bf286038543bda629bf985cff1bb6a8e8adae333612b877c001fa6c9977732",
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
        current = "a9b39fc754ce3bd4307a9ffc4407aa4d9cac26609b6048254869e15f2c281ba1",
        pre_v2_12 = "67f03092a451d9a5f8a8b8c84efb7e7da766389673aeb06295f66b2ed401973b",
        pre_v2_11 = "faa0b20edd7d6dadc4c806a0f88b805f452c1e8005622f455962f146804dc806",
        pre_v2_10 = "423bf27d40f46486385c79797964b30efb77800c0512a48e6b6042171811e6e2",
        pre_v2_9 = "9b90ce7bc53a82c36cd406606f331d2e1f959d41115ab743ea19e7a69a1f6f41",
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
        current = "49165e9f6693334395a911409a680257778ce797ff23f55cb1fec3ff252ad277",
        pre_v2_12 = "b86a610394344cc2ba6218c1eb19ff277a25eaeabf0955f7ea63574961435923",
        pre_v2_11 = nothing,
        pre_v2_10 = "831780264f5aad536bca5592d8978fe62f5ef81ab8527972c72faa95370e5f2b",
        pre_v2_9 = "a4bf286038543bda629bf985cff1bb6a8e8adae333612b877c001fa6c9977732",
        pre_v2_8 = "4a083b94d976030751ab8338795235b51fc332cbbd0713895b7aae28b0899c35",
        pre_v2_7 = "98f330c0fc03f1ba98fb5dd4f49aba3b6131980f1023f6017157e328def54cad",
        pre_v2_6 = "7667757b789afc08e2fdb99663be0d003117b7c172347f8731b4abc5f0157798",
    )
end
