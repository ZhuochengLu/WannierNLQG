using Test, WannierNLQG, HDF5, JSON3
include(joinpath(@__DIR__, "OperatorTaskSelectionTestSupport.jl"))

isdefined(@__MODULE__, :CITestPlan) || include(joinpath(@__DIR__, "CITestPlan.jl"))

@testset "operator task selection registration" begin
    @test CITestPlan.validate_ci_test_plan()
    @test count(==("operator_task_selection_unit.jl"), CITestPlan.FULL_ONLY_TEST_FILES) == 1
    @test count(
        name -> name == "operator_task_selection_unit.jl",
        [
            file for shard in CITestPlan.full_shard_names() for
            file in CITestPlan.full_shard_files(shard)
        ],
    ) == 1
end

@testset "operator task selection and canonical shared requirements" begin
    task(q, m = :all) = OTS_C.OperatorTask(quantity = q, method = m)
    resolve(tasks; kw...) = OTS_C.resolve_operator_requirements(tasks; kw...)
    @test OTS_W.WannierizationOutputConfig().profile == :hamiltonian_position
    @test Set(OTS_IO.OPERATOR_SELECTION_PROFILES) == Set((:hamiltonian_position, :full))
    for (profile, count) in ((:hamiltonian_position, 2), (:full, 11))
        selection = OTS_IO.resolve_operator_selection(profile)
        @test length(OTS_IO.resolved_operator_inventory(selection)) == count
        @test OTS_IO.resolved_operator_inventory(selection) ==
              collect(OTS_IO.OPERATOR_PROFILE_INVENTORIES[profile])
    end
    for (profile, tasks, code) in (
        (:full, (task(:orbital_magnetization),), "AMBIGUOUS_OPERATOR_SELECTION"),
        (nothing, (), "EMPTY_OPERATOR_TASK_SELECTION"),
        (:hamiltonian_position_spin, (), "UNSUPPORTED_OPERATOR_PROFILE"),
        (:task_derived, (), "UNSUPPORTED_OPERATOR_PROFILE"),
        (nothing, (task(:not_registered),), "UNSUPPORTED_OPERATOR_TASK"),
        (
            nothing,
            (task(:orbital_magnetization, :wilson_loop),),
            "UNSUPPORTED_OPERATOR_TASK_METHOD",
        ),
    )
        err = ots_capture(() -> OTS_IO.resolve_operator_selection(profile, tasks))
        @test err isa OTS_C.OperatorSelectionError
        @test occursin(code, sprint(showerror, err))
    end
    minimal = (OTS_C.REAL_SPACE_HAMILTONIAN, OTS_C.REAL_SPACE_POSITION)
    for quantity in (
        :band_structure,
        :berry_curvature,
        :quantum_metric,
        :linear_transport,
        :linear_optical_response,
    )
        selection = resolve((task(quantity),))
        @test selection.required_operators == minimal
        @test selection.required_sources == (:mmn, :chk, :eig, :authoritative_hamiltonian)
        @test Set(OTS_C.derived_operator_capabilities(selection.required_operators)) ==
              Set((:internal_connection, :gauge_correction, :berry_connection))
    end
    expected = Set((
        OTS_C.REAL_SPACE_HAMILTONIAN,
        OTS_C.REAL_SPACE_POSITION,
        OTS_C.REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION,
        OTS_C.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
        OTS_C.REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
    ))
    for method in (:all, :conventional, :projector)
        selection = resolve((task(:orbital_magnetization, method),))
        @test Set(selection.required_operators) == expected
        @test selection.required_sources ==
              (:mmn, :chk, :eig, :uiu, :uhu, :authoritative_hamiltonian, :operator_target_contract)
    end
    tasks = (
        task(:orbital_magnetization),
        task(:shift_current, :projector),
        task(:zeeman_interband_berry_curvature),
        task(:linear_transport, :projector),
    )
    combined = resolve(tasks)
    for reordered in (reverse(tasks), (tasks..., tasks[1]))
        actual = resolve(reordered)
        @test actual.required_operators == combined.required_operators
        @test actual.required_sources == combined.required_sources
        @test actual.selection_sha256 == combined.selection_sha256
    end
    @test Set(combined.required_operators) ==
          union((Set(resolve((t,)).required_operators) for t in tasks)...)
    @test Set(combined.required_sources) ==
          union((Set(resolve((t,)).required_sources) for t in tasks)...)
    @test length(combined.closure) == length(tasks)
    for quantity in OTS_C.registered_operator_task_quantities()
        all_methods = resolve((task(quantity),))
        rows = [
            resolve((task(quantity, method),)) for
            method in OTS_C.registered_operator_task_methods(quantity)
        ]
        @test Set(all_methods.required_operators) ==
              union((Set(row.required_operators) for row in rows)...)
        @test Set(all_methods.required_sources) ==
              union((Set(row.required_sources) for row in rows)...)
    end
    for semantics in (:unspecified, :defined_finite_model), method in ("Conventional", "Projector")
        cfg = OTS_R.EffectiveTaskConfig(
            tasks = [
                ("orbital_magnetization", method, "Integral"),
                ("shift_current", "Projector", "Integral"),
            ],
            k_mesh = (2, 2, 2),
            spatial_dimension = 3,
            orbital_input_semantics = semantics,
            fourier_backend = "direct",
        )
        specs = OTS_R.normalize_task_specs(cfg)
        shared = resolve(
            [task(s.quantity, s.method) for s in specs];
            orbital_input_semantics = semantics,
        )
        demand = OTS_R.operator_demand_plan(specs, cfg)
        @test Tuple(demand.required_operators) == shared.required_operators
        @test Set(keys(demand.required_components)) == Set(shared.required_operators)
        @test OTS_C.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR in demand.required_operators
        @test length(demand.required_operators) == (semantics == :defined_finite_model ? 3 : 5)
    end
end

@testset "live task registry and all runtime demand definitions" begin
    live = Set(
        (OTS_R.quantity_symbol(d.quantity), OTS_R.method_symbol(d.method)) for
        d in OTS_R.TASK_DEFINITIONS
    )
    registered = Set((row.quantity, row.method) for row in OTS_C.OPERATOR_TASK_REQUIREMENTS)
    @test live == registered
    for definition in OTS_R.TASK_DEFINITIONS
        q = OTS_R.quantity_symbol(definition.quantity)
        m = OTS_R.method_symbol(definition.method)
        calculation = OTS_R.calculation_symbol(definition.calculation)
        spec = OTS_R.NormalizedTaskSpec(q, m, calculation, definition.task, (), string(q))
        cfg = OTS_R.EffectiveTaskConfig(
            fourier_backend = "Direct",
            spatial_dimension = 3,
            tensor_indices = ntuple(_ -> 1, Int(definition.tensor_rank)),
        )
        demand = OTS_R.operator_demand_plan([spec], cfg)
        expected =
            OTS_C.resolve_operator_requirements((OTS_C.OperatorTask(quantity = q, method = m),))
        @test Tuple(demand.required_operators) == expected.required_operators
        @test Set(keys(demand.required_components)) == Set(expected.required_operators)
        @test all(!isempty(demand.required_components[k]) for k in demand.required_operators)
    end
end

include(joinpath(@__DIR__, "OperatorTaskConsumerTestSupport.jl"))
@testset "packed demand-only consumer closure" begin
    ots_sparse_consumer_tests()
end

@testset "real OAM assembly, tamper rejection, subset and fresh response" begin
    let directory = mktempdir(
            get(ENV, "WANNIERNLQG_OPERATOR_TEST_EVIDENCE", tempdir());
            cleanup = !haskey(ENV, "WANNIERNLQG_OPERATOR_TEST_EVIDENCE"),
        )
        println("OPERATOR_TASK_FIXTURE_DIRECTORY ", directory)
        fixture = ots_fixture(directory)
        loaded = OTS_IO.read_real_space_operator_bundle(fixture.output)
        @test loaded.manifest.inventory ==
              collect(OTS_C.resolve_operator_requirements(fixture.tasks).required_operators)
        @test length(loaded.operators) == 5
        @test all(
            loaded.operators[k].data == fixture.operators[k].data for k in keys(fixture.operators)
        )
        records = loaded.manifest.operator_qualification["operators"]
        @test length(records) == 5
        for record in values(records)
            @test record["operator_target_contract_sha256"] == fixture.target.contract_sha256
            @test record["target_band_gauge"] == "final_wannier_gauge"
        end
        @test !isfile(fixture.inputs.spn_file)
        # Each source mutation is tested independently, restoring the original bytes.
        for (label, mutate) in (
            ("backend", p -> p["authoritative_hamiltonian"] = "symmetrized_dft_hamiltonian"),
            ("digest", p -> p["authoritative_hamiltonian_digest"] = repeat("f", 64)),
            ("source_sha", p -> p["input_sha256"]["SOURCE_WAVEFUNCTIONS"] = repeat("f", 64)),
            ("target", p -> p["input_sha256"]["OPERATOR_TARGET_CONTRACT"] = repeat("f", 64)),
            ("sidecar_output", p -> p["output_sha256"] = repeat("f", 64)),
        )
            original = read(fixture.inputs.uhu_provenance)
            try
                payload = JSON3.read(String(copy(original)), Dict{String, Any})
                mutate(payload)
                write(fixture.inputs.uhu_provenance, JSON3.write(payload))
                ots_rejects(
                    fixture.assemble,
                    r"(?i)(HAMILTONIAN|source hash|target.contract|SHA|output)",
                )
            finally
                write(fixture.inputs.uhu_provenance, original)
            end
        end
        for (attribute, value) in (
            ("requested_tasks", "linear_transport:conventional"),
            ("requested_tasks", "orbital_magnetization:invalid"),
            ("resolved_operator_inventory", "hamiltonian,position"),
            (
                "resolved_operator_inventory",
                join(reverse(OTS_C.real_space_operator_name.(loaded.manifest.inventory)), ","),
            ),
            (
                "resolved_operator_inventory",
                join(OTS_C.real_space_operator_name.(loaded.manifest.inventory), ",") * ",spin",
            ),
            ("resolved_source_inventory", "mmn,chk,eig,spn"),
            ("operator_selection_sha256", repeat("f", 64)),
            ("operator_requirement_registry_version", "999.0"),
            ("operator_target_contract_sha256", repeat("f", 64)),
            ("authoritative_hamiltonian", "invalid_backend"),
            ("authoritative_hamiltonian_sha256", repeat("f", 64)),
        )
            path = joinpath(
                directory,
                "tamper-" * attribute * "-" * bytes2hex(sha256(value))[1:8] * ".h5",
            )
            cp(fixture.output, path; force = true)
            HDF5.h5open(path, "r+") do handle
                HDF5.delete_attribute(handle, attribute)
                HDF5.attributes(handle)[attribute] = value
            end
            ots_rejects(
                () -> OTS_IO.read_real_space_operator_bundle(path),
                r"(?i)(operator|inventory|source|selection|registry|contract|hamiltonian|component|digest|SHA)",
            )
        end
        for (label, group, attribute) in (
            (
                "authority-source",
                "provenance/authoritative_hamiltonian_input_sha256",
                "AUTHORITATIVE_HAMILTONIAN_SHA256",
            ),
            (
                "operator-target",
                "qualification/operators/hamiltonian",
                "operator_target_contract_sha256",
            ),
            (
                "operator-authority",
                "qualification/operators/hamiltonian",
                "authoritative_hamiltonian_digest",
            ),
        )
            path = joinpath(directory, "tamper-" * label * ".h5")
            cp(fixture.output, path)
            HDF5.h5open(path, "r+") do handle
                node = handle[group]
                @test haskey(HDF5.attributes(node), attribute)
                HDF5.delete_attribute(node, attribute)
                HDF5.attributes(node)[attribute] = repeat("f", 64)
            end
            ots_rejects(
                () -> OTS_IO.read_real_space_operator_bundle(path),
                r"(?i)(HAMILTONIAN|qualification|target|digest|SHA)",
            )
        end
        path = joinpath(directory, "tamper-components.h5")
        cp(fixture.output, path)
        HDF5.h5open(path, "r+") do handle
            indices = read(handle["index/component_indices"])
            indices[:, end] .= Int8[9, 9]
            handle["index/component_indices"][:, :] = indices
        end
        ots_rejects(
            () -> OTS_IO.read_real_space_operator_bundle(path),
            r"(?i)(operator|inventory|source|selection|registry|contract|hamiltonian|component|digest|SHA)",
        )
        subset = Dict(
            OTS_C.REAL_SPACE_HAMILTONIAN=>[(Int8(0), Int8(0))],
            OTS_C.REAL_SPACE_POSITION=>[(Int8(i), Int8(0)) for i in 1:3],
        )
        @test OTS_IO.read_operator_bundle_components(fixture.output, subset) !== nothing
        subset_demand = OTS_R.OperatorDemandPlan(collect(keys(subset)), subset, false)
        @test OTS_R.validate_operator_demand(loaded.manifest, subset_demand) === loaded.manifest
        missing_spin = Dict(OTS_C.REAL_SPACE_SPIN=>[(Int8(1), Int8(0))])
        @test_throws ArgumentError OTS_R.validate_operator_demand(
            loaded.manifest,
            OTS_R.OperatorDemandPlan(collect(keys(missing_spin)), missing_spin, false),
        )
        missing_component = Dict(OTS_C.REAL_SPACE_POSITION=>[(Int8(4), Int8(0))])
        @test_throws ArgumentError OTS_R.validate_operator_demand(
            loaded.manifest,
            OTS_R.OperatorDemandPlan(collect(keys(missing_component)), missing_component, false),
        )
        for kind in keys(fixture.operators)
            incomplete = copy(fixture.operators)
            delete!(incomplete, kind)
            ots_rejects(
                () -> OTS_IO.write_real_space_operator_bundle(
                    joinpath(directory, "missing-" * OTS_C.real_space_operator_name(kind) * ".h5"),
                    fixture.model.lattice,
                    fixture.model.r_degeneracies,
                    incomplete;
                    profile = nothing,
                    operator_tasks = fixture.tasks,
                    geometry = fixture.geometry,
                    provenance = fixture.provenance,
                    eligibility = fixture.eligibility,
                ),
                r"(?i)inventory",
            )
        end
        @test_throws ArgumentError OTS_IO.read_operator_bundle_components(
            fixture.output,
            Dict(OTS_C.REAL_SPACE_SPIN=>[(Int8(1), Int8(0))]),
        )
        @test_throws ArgumentError OTS_IO.read_operator_bundle_components(
            fixture.output,
            Dict(OTS_C.REAL_SPACE_POSITION=>[(Int8(4), Int8(0))]),
        )
        reference = nothing
        for threads in (1, 2)
            destination = joinpath(directory, "fresh-" * string(threads))
            probe = joinpath(@__DIR__, "OperatorTaskSelectionProbe.jl")
            command =
                `$(Base.julia_cmd()) --startup-file=no --threads=$threads --project=$(dirname(@__DIR__)) $probe $(fixture.output) $destination $(fixture.geometry_output)`
            log_path = joinpath(directory, "fresh-" * string(threads) * ".log")
            process = open(log_path, "w") do stream
                Base.run(
                    pipeline(
                        ignorestatus(
                            addenv(
                                command,
                                "OPENBLAS_NUM_THREADS"=>"1",
                                "OMP_NUM_THREADS"=>"1",
                                "WANNIERNLQG_USE_MPI"=>"0",
                            ),
                        );
                        stdout = stream,
                        stderr = stream,
                    ),
                )
            end
            output = read(log_path, String)
            @test success(process)
            print(output)
            @test occursin("OPERATOR_TASK_OAM_FRESH_RESPONSE_PASS", output)
            tables = Dict(
                relpath(joinpath(root, file), destination)=>ots_table(joinpath(root, file)) for
                (root, _, files) in walkdir(destination) for
                file in files if endswith(file, ".dat")
            )
            @test !isempty(tables)
            if reference !== nothing
                @test keys(tables) == keys(reference)
                @test all(tables[name] == reference[name] for name in keys(tables))
            end
            reference = tables
        end
    end
end

# Append to the existing registered test only after write release.
include(joinpath(@__DIR__, "NeighborOrderRegressionTestSupport.jl"))
@testset "uIu/uHu source-neighbor order and B/spin nonregression" begin
    mktempdir() do directory
        neighbor_order_regression_tests(directory)
    end
end
@testset "nonzero neighbor-order fresh construct/write/read/downstream" begin
    let directory = mktempdir(
            get(ENV, "WANNIERNLQG_OPERATOR_TEST_EVIDENCE", tempdir());
            cleanup = !haskey(ENV, "WANNIERNLQG_OPERATOR_TEST_EVIDENCE"),
        )
        println("NONZERO_NEIGHBOR_FIXTURE_DIRECTORY ", directory)
        baseline_operators = nothing
        baseline_tables = nothing
        permuted_tables = nothing
        for (permutation, threads) in ((:identity, 1), (:per_k, 1), (:per_k, 2))
            output=joinpath(directory, string(permutation)*"-"*string(threads))
            log=output*".log"
            probe=joinpath(@__DIR__, "NeighborOrderFreshProbe.jl")
            project=dirname(Base.active_project())
            cmd=`$(Base.julia_cmd()) --startup-file=no --threads=$threads --project=$project $probe $output $(string(permutation))`
            process=open(log, "w") do stream
                Base.run(
                    pipeline(
                        ignorestatus(
                            addenv(
                                cmd,
                                "OPENBLAS_NUM_THREADS"=>"1",
                                "OMP_NUM_THREADS"=>"1",
                                "WANNIERNLQG_USE_MPI"=>"0",
                            ),
                        );
                        stdout = stream,
                        stderr = stream,
                    ),
                )
            end
            text=read(log, String)
            print(text)
            @test success(process)
            @test occursin("NEIGHBOR_FRESH_CONSTRUCT_WRITE_READ_RESPONSE_PASS", text)
            success(process) || continue
            bundle=OTS_IO.read_real_space_operator_bundle(joinpath(output, "oam.h5"))
            tables=Dict(
                relpath(joinpath(path, file), output)=>ots_table(joinpath(path, file)) for
                (path, _, files) in walkdir(joinpath(output, "responses")) for
                file in files if endswith(file, ".dat")
            )
            @test !isempty(tables)
            if baseline_operators===nothing
                baseline_operators=bundle.operators
                baseline_tables=tables
            else
                @test Set(keys(bundle.operators))==Set(keys(baseline_operators))
                for kind in keys(bundle.operators)
                    @test isapprox(
                        bundle.operators[kind].data,
                        baseline_operators[kind].data;
                        atol = 2e-12,
                        rtol = 2e-12,
                    )
                end
                @test keys(tables)==keys(baseline_tables)
                for name in keys(tables)
                    @test isapprox(tables[name], baseline_tables[name]; atol = 1e-28, rtol = 2e-11)
                end
            end
            if permutation==:per_k
                if permuted_tables!==nothing
                    @test keys(tables)==keys(permuted_tables)
                    @test all(tables[name]==permuted_tables[name] for name in keys(tables))
                end
                permuted_tables=tables
            end
        end
    end
end
