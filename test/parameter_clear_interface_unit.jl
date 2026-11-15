module ParameterClearInterfaceTests
using Test, LinearAlgebra, WannierNLQG
const R = WannierNLQG.Runtime
const F = WannierNLQG.IO
const W = WannierNLQG.Wannierization
const RESULTS = NamedTuple[]
# Reuse only the existing binary fixture writer, without executing its test suite.
const LOCALIZED_FIXTURE_SOURCE = joinpath(@__DIR__, "nonorthogonal_io_runtime_unit.jl")
const LOCALIZED_FIXTURE_PREFIX = first(
    split(
        read(LOCALIZED_FIXTURE_SOURCE, String),
        "include(joinpath(@__DIR__, \"NativeDefinitionTestSupport.jl\"))",
    ),
)
Base.include_string(@__MODULE__, LOCALIZED_FIXTURE_PREFIX * "\nend\n", LOCALIZED_FIXTURE_SOURCE)
include(joinpath(@__DIR__, "WannierizationFixtureSupport.jl"))
# Record only the independently clarified parameter boundaries.
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

case!("openmx_existing_threshold_text_forwarding") do
    mktempdir() do directory
        path = joinpath(directory, "tiny.scfout")
        NonorthogonalIORuntimeUnit.write_synthetic_localized_file(path)
        base = Dict{String, Any}(
            "source" => "openmx",
            "model_file" => path,
            "format_version" => "3.8",
            "byte_order" => "little",
        )
        default, effective = R._task_input_openmx(base, Dict(), Any[], directory)
        original = F.read_openmx_localized_input(path; format_version = "3.8", byte_order = :little)
        @test default.model.hamiltonian_r == original.model.hamiltonian_r
        @test default.model.overlap_r == original.model.overlap_r
        @test default.model.position_r == original.model.position_r
        @test effective["metric_relative_floor"] == original.model.metric_relative_floor == 1e-10
        @test effective["hamiltonian_representation_tolerance_ev"] == 1e-8
        options = Dict(
            "metric_relative_floor" => 2e-10,
            "representation_tolerance" => 3e-8,
            "hamiltonian_representation_tolerance_ev" => 4e-8,
            "overlap_representation_tolerance" => 5e-8,
            "position_translation_tolerance_angstrom" => 6e-8,
        )
        table = merge(base, options)
        parsed, effective = R._task_input_openmx(table, Dict(), Any[], directory)
        julia = F.read_openmx_localized_input(
            path;
            format_version = "3.8",
            byte_order = :little,
            (Symbol(key) => value for (key, value) in options)...,
        )
        for field in (
            :hamiltonian_r,
            :overlap_r,
            :position_r,
            :metric_relative_floor,
            :hamiltonian_representation_tolerance_ev,
            :overlap_representation_tolerance,
            :position_translation_tolerance_angstrom,
        )
            @test getfield(parsed.model, field) == getfield(julia.model, field)
        end
        for (key, value) in options
            @test effective[key] == value
        end
        replayed, replay_effective = R._task_input_openmx(effective, Dict(), Any[], directory)
        @test replayed.model.hamiltonian_r == parsed.model.hamiltonian_r
        @test replay_effective == effective
        generic, effective_generic = R._task_input_openmx(
            merge(base, Dict("representation_tolerance" => 7e-8)),
            Dict(),
            Any[],
            directory,
        )
        @test effective_generic["hamiltonian_representation_tolerance_ev"] == 7e-8
        @test effective_generic["overlap_representation_tolerance"] == 7e-8
        @test effective_generic["position_translation_tolerance_angstrom"] == 7e-8
        for key in keys(options), invalid in (true, "1e-8", NaN, Inf, -1.0)
            @test_throws ArgumentError R._task_input_openmx(
                merge(base, Dict(key => invalid)),
                Dict(),
                Any[],
                directory,
            )
        end
        @test_throws ArgumentError R._task_input_openmx(
            merge(base, Dict("metric_relative_floor" => 0.0)),
            Dict(),
            Any[],
            directory,
        )
        @test_throws ArgumentError R._task_input_openmx(
            merge(base, Dict("metric_relative_floor" => 1.0)),
            Dict(),
            Any[],
            directory,
        )
    end
end

case!("unused_solver_audit_hook_rejected") do
    key = :smv_fletcher_reeves_two_stage_audit_manifest
    original = W.WannierizationSolverConfig()
    @test getfield(original, key) === nothing
    @test_throws ArgumentError W.WannierizationSolverConfig(; key => "not-used.json")
    @test_throws ArgumentError R._workflow_stage_solver(Dict(String(key) => "not-used.json"))
    @test_throws ArgumentError R._workflow_input_struct(
        W.WannierizationSolverConfig,
        Dict(String(key) => "not-used.json"),
        "solver",
        pwd(),
    )
    @test_throws ArgumentError W._replace_wannierization_group(
        original,
        NamedTuple{(key,)}(("not-used.json",)),
    )
    effective = R._workflow_input_effective_value(original)
    @test !haskey(effective, String(key))
    @test !haskey(effective, "acceleration")
    @test R._workflow_stage_solver(Dict()).stage_controls == original.stage_controls
    @test isdefined(W, :smv_fletcher_reeves_two_stage_audit)
    # Internal historical records remain structurally readable, but are not new user inputs.
    historical =
        InternalSolverFixture.replace_group(original, NamedTuple{(key,)}(("old-manifest.json",)))
    @test getfield(historical, key) == "old-manifest.json"
    @test !haskey(R._workflow_input_effective_value(historical), String(key))
    fixture = synthetic_wannierization_fixture()
    historical_config = modified_wannierization_config(
        fixture.config;
        smv_fletcher_reeves_two_stage_audit_manifest = "old-manifest.json",
    )
    @test Base.invokelatest(W._restart_config_repr, fixture.config) ==
          Base.invokelatest(W._restart_config_repr, historical_config)
end

case!("invalid_integer_and_internal_step_boundaries") do
    for control in (:initial_divisions, :max_evaluations)
        @test_throws ArgumentError HAdaptiveCubature(; control => true)
        @test_throws ArgumentError HAdaptiveCubature(; control => false)
        @test getfield(HAdaptiveCubature(; control => 2), control) == 2
    end
    @test_throws ArgumentError KRegion(lower = (0.0,), upper = (1.0,), k_mesh = (true,))
    @test KRegion(lower = (0.0,), upper = (1.0,), k_mesh = (2,)).k_mesh == (2, 1, 1)
    fixture = synthetic_wannierization_fixture()
    @test Base.invokelatest(W._validate_wannierization_config, fixture.config) === nothing
    for value in (-Inf, NaN, 0.0, -0.5, 0.5, Inf)
        algorithm = InternalSolverFixture.replace_group(
            fixture.config.solver.acceleration,
            (; u_max_geodesic_step = value),
        )
        config = modified_wannierization_config(fixture.config; acceleration = algorithm)
        if value > 0
            @test Base.invokelatest(W._validate_wannierization_config, config) === nothing
        else
            @test_throws ArgumentError Base.invokelatest(W._validate_wannierization_config, config)
        end
    end
end

case!("updated_reference_constructor_fields") do
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
    @test !occursin("| `smv_fletcher_reeves_two_stage_audit_manifest`", text)
end
end
