using JSON3
using SHA

const RELEASE_RUNTIME_FIXTURE_ROOT = joinpath(ROOT, "examples", "fixtures", "synthetic_runtime")
const RELEASE_SYMMETRY_FIXTURE_ROOT =
    joinpath(ROOT, "examples", "symmetrization", "fixture", "inputs")
const RELEASE_TB_FILE = joinpath(RELEASE_RUNTIME_FIXTURE_ROOT, "synthetic_tb.dat")
const RELEASE_WSVEC_FILE = joinpath(RELEASE_RUNTIME_FIXTURE_ROOT, "synthetic_wsvec.dat")
const RELEASE_OPERATOR_BUNDLE_FILE =
    joinpath(RELEASE_RUNTIME_FIXTURE_ROOT, "synthetic_operators.h5")

@testset "self-contained public release" begin
    @test Base.pkgversion(WannierNLQG) == v"1.0.0"
    @test all(isfile, (RELEASE_TB_FILE, RELEASE_WSVEC_FILE, RELEASE_OPERATOR_BUNDLE_FILE))

    for line in eachline(joinpath(RELEASE_RUNTIME_FIXTURE_ROOT, "SHA256SUMS"))
        expected, relative = split(strip(line); limit = 2)
        path = joinpath(RELEASE_RUNTIME_FIXTURE_ROOT, strip(relative))
        @test isfile(path)
        @test !islink(path)
        @test bytes2hex(sha256(read(path))) == expected
    end

    model = WannierNLQG.IO.read_wannier_tb(RELEASE_TB_FILE)
    @test model.num_orbitals == 4
    @test model.num_r_vectors == 2
    @test model.r_degeneracies == [2, 4]
    @test all(isfinite, real.(model.hamiltonian_r))
    @test all(isfinite, imag.(model.hamiltonian_r))

    mktempdir() do directory
        config = WannierNLQG.TaskConfig(
            model = ModelInput(
                model_file = RELEASE_TB_FILE,
                real_space_replica_policy = "minimum_distance",
                wsvec_file = RELEASE_WSVEC_FILE,
                mp_grid = (2, 1, 1),
            ),
            sampling = KPath(
                nodes = [("Gamma", (0.0, 0.0, 0.0)), ("X", (0.5, 0.0, 0.0))],
                kpoints_per_segment = [3],
            ),
            execution = ExecutionOptions(fourier_backend = "direct"),
            output = OutputOptions(
                output_root = directory,
                system_name = "synthetic_demo",
                progress_enabled = false,
            ),
            tasks = [
                TaskSpec(
                    id = "band",
                    quantity = "Band",
                    physics = BandParameters(fermi_energy = 0.0),
                ),
            ],
        )
        result = WannierNLQG.run(config)
        @test length(result.outputs) == 2
        @test all(isfile, result.outputs)
        @test isfile(result.metadata_path)

        numeric_rows = [
            parse.(Float64, split(line)) for line in eachline(first(result.outputs)) if
            !isempty(strip(line)) && !startswith(strip(line), '#')
        ]
        values = reduce(vcat, numeric_rows)
        @test !isempty(values)
        @test all(isfinite, values)

        path_payload = JSON3.read(read(result.outputs[2], String))
        @test String(path_payload.schema) == "wanniernlqg.kpath"
        @test Int(path_payload.total_kpoints) == 3

        metadata = read(only(result.task_results).metadata_path, String)
        @test occursin("requested_replica_policy", metadata)
        @test occursin("effective_replica_policy", metadata)
        @test occursin("minimum_distance", metadata)
        @test occursin("wsvec", metadata)
    end

    mktempdir() do directory
        S = WannierNLQG.Symmetrization
        result = S.symmetrize_wannier_operators(
            S.SymmetrizationConfig(
                win_file = joinpath(RELEASE_SYMMETRY_FIXTURE_ROOT, "synthetic.win"),
                tb_file = joinpath(RELEASE_SYMMETRY_FIXTURE_ROOT, "synthetic_tb.dat"),
                output_tb_file = joinpath(directory, "synthetic_sym_tb.dat"),
                output_real_space_operator_bundle_file = joinpath(directory, "wannierNLQG_tb.h5"),
                report_json_file = joinpath(directory, "symmetrization.json"),
                include_time_reversal = true,
                symmetry_tolerance = 1.0e-5,
                projection_tolerance = 1.0e-7,
                representation_tolerance = 1.0e-7,
                covariance_tolerance = 1.0e-8,
                idempotence_tolerance = 1.0e-9,
                check_idempotence = true,
                real_space_replica_policy = :input,
                overwrite = true,
            ),
        )
        @test result.operator_profile == :hamiltonian_position
        @test all(isfile, (result.output_tb, result.real_space_operator_bundle, result.report_json))
        @test all(summary -> all(isfinite, summary), values(result.validation))
        report = JSON3.read(read(result.report_json, String))
        @test String(report.status) == "PASS"
        @test String(report.wanniernlqg_version) == "1.0.0"
        manifest = WannierNLQG.IO.read_real_space_operator_bundle_manifest(
            result.real_space_operator_bundle,
        )
        @test manifest.schema_version == "1.0"
    end

    W = WannierNLQG.Wannierization
    config = W.SymmetryAdaptedWannierizationConfig(
        input = W.WannierizationInputConfig(
            win_file = joinpath(RELEASE_SYMMETRY_FIXTURE_ROOT, "synthetic.win"),
            eig_file = joinpath(RELEASE_SYMMETRY_FIXTURE_ROOT, "synthetic.eig"),
            mmn_file = joinpath(RELEASE_SYMMETRY_FIXTURE_ROOT, "synthetic.mmn"),
        ),
    )
    @test hasproperty(config, :input)
    @test hasproperty(config, :solver)
    @test hasproperty(config, :checkpoint)
    @test hasproperty(config, :runtime)
    @test hasproperty(config, :output)
    @test !hasproperty(config, :max_iterations)
end
