module ParameterInputBoundaryTests
using Test, LinearAlgebra, TOML, WannierNLQG
const R = WannierNLQG.Runtime
const M = WannierNLQG.MatrixElements
const G = WannierNLQG.Responses
const F = WannierNLQG.IO
const S = WannierNLQG.SymmetryFoundation
const W = WannierNLQG.Wannierization
const RESULTS = NamedTuple[]
# Record only the six affected small fixture families, without a regression suite.
function case!(f, label)
    result = @testset "$label" begin
        f()
    end
    counts = Test.get_test_counts(result)
    push!(
        RESULTS,
        (;
            label,
            passed = counts.passes + counts.cumulative_passes,
            failed = counts.fails + counts.cumulative_fails,
            errored = counts.errors + counts.cumulative_errors,
        ),
    )
end

case!("legacy_spin_sources_and_format") do
    fixture = joinpath(@__DIR__, "fixtures", "first_use_portable", "assets", "group_22")
    mktempdir() do directory
        for suffix in ("_tb.dat", ".eig", ".mmn")
            cp(joinpath(fixture, "synthetic" * suffix), joinpath(directory, "seed" * suffix))
        end
        cp(joinpath(fixture, "synthetic.chk"), joinpath(directory, "chosen.chk"))
        spn = F.WannierSPN(1, 1, reshape(ComplexF64[0.25, -0.5, 1.0], 1, 1, 3, 1))
        model = F.read_wannier_tb(joinpath(directory, "seed_tb.dat"))
        values = Any[]
        for formatted in (false, true)
            path = joinpath(directory, formatted ? "chosen-text.spn" : "chosen-binary.spn")
            F.write_wannier_spn(path, spn; formatted)
            cfg = R.EffectiveTaskConfig(;
                fourier_backend = "direct",
                case_root = directory,
                tasks = [("ISC", "Conventional", "Integral")],
                seedname = "seed",
                spin_enabled = true,
                spin_file = basename(path),
                checkpoint_file = "chosen.chk",
                spin_file_formatted = formatted,
                output_root = joinpath(directory, "out"),
                progress_enabled = false,
            )
            specs = R.normalize_task_specs(cfg)
            resolved = R.resolve_runtime_model_inputs(cfg, specs)
            @test resolved.seed_inputs.spin_file == path
            @test resolved.seed_inputs.checkpoint_file == joinpath(directory, "chosen.chk")
            @test Set(R.runtime_input_source_paths(cfg, specs)) == Set([
                joinpath(directory, "seed_tb.dat"),
                path,
                joinpath(directory, "chosen.chk"),
                joinpath(directory, "seed.eig"),
                joinpath(directory, "seed.mmn"),
            ])
            ordinary = R.maybe_load_spin_from_config(model, cfg; seed_inputs = resolved.seed_inputs)
            ctx = R.prepare_run_context(cfg, specs)
            weighted = R.maybe_load_spin_velocity_from_context(model, ctx, cfg)
            @test ordinary.spin_r == weighted.spin.spin_r
            @test ordinary.spin_r == reshape(spn.data, 1, 1, 3, 1)
            push!(values, weighted)
        end
        for name in fieldnames(typeof(first(values)))
            left, right = getfield(values[1], name), getfield(values[2], name)
            left isa AbstractArray && @test left == right
        end
        # Default seed-derived paths remain available when no overrides are supplied.
        cp(joinpath(directory, "chosen.chk"), joinpath(directory, "seed.chk"))
        F.write_wannier_spn(joinpath(directory, "seed.spn"), spn)
        cfg = R.EffectiveTaskConfig(;
            fourier_backend = "direct",
            case_root = directory,
            tasks = [("ISC", "Conventional", "Integral")],
            seedname = "seed",
        )
        @test R.resolve_runtime_model_inputs(cfg, R.normalize_task_specs(cfg)).seed_inputs.spin_file ==
              joinpath(directory, "seed.spn")
    end
end

case!("manual_path_input_boundaries") do
    nodes = [("G", (0.0, 0.0, 0.0)), ("X", (0.5, 0.0, 0.0))]
    lattice = Matrix{Float64}(I, 3, 3)
    @test KPath(; nodes, kpoints_per_segment = 4).kpoints_per_segment == [4]
    @test KPath(; nodes, lattice).kpoints_per_segment ==
          KPath(; nodes, lattice, density = 50).kpoints_per_segment
    @test_throws ArgumentError KPath(; nodes, kpoints_per_segment = 4, density = 50)
    @test_throws ArgumentError KPath(; nodes, lattice, density = true)
    table = Dict{String, Any}(
        "kind" => "k_path",
        "nodes" => Dict(
            "label" => ["G", "X"],
            "fractional_coordinates" => [[0.0, 0.0, 0.0], [0.5, 0.0, 0.0]],
        ),
        "kpoints_per_segment" => 4,
    )
    for (key, value) in
        (("periodic_axes", [1, 2, 3]), ("time_reversal", true), ("spglib_symprec_angstrom", 1e-5))
        invalid = merge(table, Dict(key => value))
        @test_throws ArgumentError R._task_input_band_sampling(
            invalid,
            Dict(),
            Any[],
            pwd(),
            nothing,
        )
    end
    path, effective = R._task_input_band_sampling(table, Dict(), Any[], pwd(), nothing)
    @test path.nodes == KPath(; nodes, kpoints_per_segment = 4).nodes
    @test effective["kpoints_per_segment"] == [4]
end

case!("actual_sampling_and_observation_summary") do
    table = Dict(
        "kind" => "k_region",
        "k_mesh" => [2, 3],
        "spatial_dimension" => 2,
        "lower" => [0.0, 0.0],
        "upper" => [2.0, 3.0],
    )
    for algorithm in (
        UniformIntegration(),
        UniformIntegration(region_quadrature = :left_endpoint),
        HAdaptiveCubature(),
    )
        records = Dict{String, Any}()
        R._task_input_sampling(table, records, Any[]; integration_algorithm = algorithm)
        @test records["response.sampling.domain_measure"]["value"] == 6.0
        if algorithm isa UniformIntegration
            @test occursin(
                String(algorithm.region_quadrature),
                records["response.sampling.grid"]["value"],
            )
            @test records["response.sampling.nsamples"]["value"] == 6
            @test records["response.sampling.point_weight"]["value"] == 1.0
        else
            @test !haskey(records, "response.sampling.nsamples")
            @test records["response.sampling.reference_nsamples"]["value"] == 6
            @test occursin(
                "no fixed point weight",
                records["response.sampling.point_weight"]["value"],
            )
        end
    end
    for (quantity, physics) in (
        ("JC", JerkParameters(photon_energies = [1.0], fermi_energy = 0.0, temperature = 0.0)),
        ("THG", THGParameters(photon_energies = [1.0], fermi_energy = 0.0, temperature = 0.0)),
    )
        task = TaskSpec(
            id = "selected",
            quantity = quantity,
            method = "Conventional",
            physics = physics,
            observable = TensorComponents(TensorComponent(1, 1, 1, 1)),
        )
        _, _, _, definition = R._public_task_identity(task, BZMesh(k_mesh = (1, 1, 1)))
        summary = R._task_observation_summary(task, definition)
        @test summary.kind == "tensor_components"
        @test summary.components == ((1, 1, 1, 1),)
    end
end

case!("configuration_reference_fields") do
    text = read(joinpath(@__DIR__, "..", "docs", "WANNIERIZATION_CONFIG.md"), String)
    groups = (
        ("input", W.WannierizationInputConfig),
        ("solver", W.WannierizationSolverConfig),
        ("checkpoint", W.WannierizationCheckpointConfig),
        ("runtime", W.WannierizationRuntimeConfig),
        ("output", W.WannierizationOutputConfig),
    )
    documented = [m.captures[1] for m in eachmatch(r"\| `[^`]+` \| `([^`]+)` \|", text)]
    expected = [
        "$group.$field" for (group, type) in groups for field in fieldnames(type) if
        field ∉ (:acceleration, :smv_fletcher_reeves_two_stage_audit_manifest)
    ]
    @test documented == expected
    for old in ("max_iterations", "convergence_tolerance", "convergence_window", "localize")
        @test !("solver.$old" in documented)
    end
    toml = TOML.parse(only([m.captures[1] for m in eachmatch(r"```toml\n(.*?)```"s, text)]))
    @test R._workflow_stage_solver(toml["solver"]).stage_controls == W.WannierizationStageControls()
end

case!("inferred_mesh_validity") do
    for dims in ((1, 1, 1), (2, 3, 1), (10, 10, 10)),
        offset in ((0.0, 0.0, 0.0), (0.031, -0.017, 0.11))

        points = reduce(
            vcat,
            [
                permutedims([i/dims[1]+offset[1], j/dims[2]+offset[2], k/dims[3]+offset[3]]) for
                i in 0:(dims[1] - 1) for j in 0:(dims[2] - 1) for k in 0:(dims[3] - 1)
            ],
        )
        @test S.infer_mp_grid(points) == dims
        @test S.infer_mp_grid(reverse(points; dims = 1) .+ [1.0 -2.0 3.0]) == dims
    end
    @test_throws ArgumentError S.infer_mp_grid([0.0 0 0; 0.2 0 0])
    @test_throws ArgumentError S.infer_mp_grid([0.0 0 0; 0.5 0 0; 0.0 0.5 0; 0.0 0.5 0])
    @test_throws ArgumentError S.infer_mp_grid([0.0 0 0; 0.5 0 0; 0.0 0.5 0])
    @test_throws ArgumentError S.infer_mp_grid([NaN 0 0])
    @test_throws ArgumentError S.infer_mp_grid(zeros(0, 3))
    @test_throws ArgumentError S.infer_mp_grid(zeros(1, 2))
    for tolerance in (0.0, -1.0, NaN, Inf, 0.5)
        @test_throws ArgumentError S.infer_mp_grid(zeros(1, 3); tolerance)
    end
end

case!("standalone_pdic_plan_eta") do
    default = G.make_photon_drag_injection_current_conventional_workspace(2, 1, 2, 1)
    @test default.scratch.plan.denominator_regularization == 0.001
    for eta in (0.0, 0.017)
        workspace = G.make_photon_drag_injection_current_conventional_workspace(
            2,
            1,
            2,
            1;
            denominator_regularization = eta,
        )
        @test workspace.scratch.plan.denominator_regularization == eta
        shared = workspace.scratch
        reused = G.make_photon_drag_injection_current_conventional_workspace(
            2,
            1,
            2,
            1;
            matrix_elements = shared,
        )
        @test reused.scratch === shared
        @test reused.valence_data isa M.KPointMatrixData
        @test G.make_photon_drag_injection_current_conventional_workspace(
            2,
            1,
            2,
            1;
            matrix_elements = shared,
            denominator_regularization = eta,
        ).scratch === shared
        @test_throws ArgumentError G.make_photon_drag_injection_current_conventional_workspace(
            2,
            1,
            2,
            1;
            matrix_elements = shared,
            denominator_regularization = eta + 0.1,
        )
    end
end
end
