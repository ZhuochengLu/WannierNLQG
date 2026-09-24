using Test, WannierNLQG, HDF5, JSON3
isdefined(@__MODULE__, :ots_response_config) ||
    include(joinpath(@__DIR__, "OperatorTaskSelectionTestSupport.jl"))
bundle, destination, geometry_bundle = ARGS
@testset "fresh non-finite-model five-operator OAM response" begin
    loaded = OTS_IO.read_real_space_operator_bundle(bundle)
    @test loaded.manifest.profile == :task_derived
    @test length(loaded.operators) == 5
    geometry = OTS_IO.read_real_space_operator_bundle(geometry_bundle)
    @test geometry.manifest.profile == :task_derived
    @test geometry.manifest.inventory == [OTS_C.REAL_SPACE_HAMILTONIAN, OTS_C.REAL_SPACE_POSITION]
    @test Set(OTS_C.derived_operator_capabilities(geometry.manifest.inventory)) ==
          Set((:internal_connection, :gauge_correction, :berry_connection))
    for path in readdir(dirname(bundle); join = true)
        startswith(basename(path), "tamper-") && endswith(path, ".h5") || continue
        ots_rejects(
            () -> OTS_IO.read_real_space_operator_bundle(path),
            r"(?i)(operator|inventory|source|selection|registry|contract|hamiltonian|component|digest|SHA)",
        )
    end
    reference = nothing
    for method in ("Conventional", "Projector")
        cfg = ots_response_config(bundle, joinpath(destination, method), method)
        effective = only(OTS_R.compile_task_configs(cfg))
        @test effective.orbital_input_semantics != :defined_finite_model
        demand = OTS_R.operator_demand_plan(OTS_R.normalize_task_specs(effective), effective)
        @test Set(demand.required_operators) == Set(keys(loaded.operators))
        ctx = OTS_R.prepare_run_context(effective, OTS_R.normalize_task_specs(effective))
        sources = OTS_R.load_runtime_model_and_sources(ctx, effective)
        @test sources.orbital !== nothing
        @test sources.orbital.energy_connection !== nothing
        @test sources.orbital.derivative_overlap !== nothing
        @test sources.orbital.axial_energy_overlap !== nothing
        OTS_R.release_runtime_storage!(sources)
        result = WannierNLQG.run(cfg)
        @test result.qualification.execution_eligible
        @test !result.qualification.production_eligible
        tables = Dict(
            basename(path)=>ots_table(path) for path in result.outputs if endswith(path, ".dat")
        )
        @test !isempty(tables)
        @test all(table -> all(isfinite, table), values(tables))
        for suffix in (".dat",)
            total = tables["orbital_magnetization_total" * suffix]
            sr = tables["orbital_magnetization_srocc" * suffix]
            cm = tables["orbital_magnetization_cmocc" * suffix]
            total_path = only(
                path for path in result.outputs if
                basename(path) == "orbital_magnetization_total" * suffix
            )
            columns = ots_response_columns(total_path)
            @test !isempty(columns)
            @test isapprox(
                total[:, columns],
                sr[:, columns] + cm[:, columns];
                atol = 1e-28,
                rtol = 2e-11,
            )
            println(
                "OAM_DECOMPOSITION ",
                method,
                suffix,
                " max_abs=",
                maximum(abs, total[:, columns] - sr[:, columns] - cm[:, columns]),
            )
        end
        if reference !== nothing
            @test keys(tables) == keys(reference)
            for name in keys(tables)
                @test isapprox(tables[name], reference[name]; atol = 1e-28, rtol = 2e-11)
            end
        end
        reference = tables
    end
end
println("OPERATOR_TASK_OAM_FRESH_RESPONSE_PASS threads=", Threads.nthreads())
