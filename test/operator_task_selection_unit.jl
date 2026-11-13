using Test, WannierNLQG, HDF5, JSON3
include(joinpath(@__DIR__, "OperatorTaskSelectionTestSupport.jl"))
include(joinpath(@__DIR__, "NeighborOrderMarkerTestSupport.jl"))

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
    resolve(tasks; kw...) =
        OTS_C.resolve_operator_requirements(tasks; content_authentication = false, kw...)
    @test OTS_W.WannierizationOutputConfig().profile == :hamiltonian_position
    @test Set(OTS_IO.OPERATOR_SELECTION_PROFILES) == Set((:hamiltonian_position, :full))
    for (profile, count) in ((:hamiltonian_position, 2), (:full, 11))
        selection = OTS_IO.resolve_operator_selection(profile; content_authentication = false)
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
        err = ots_capture(
            () -> OTS_IO.resolve_operator_selection(profile, tasks; content_authentication = false),
        )
        @test err isa OTS_C.OperatorSelectionError
        @test occursin(code, sprint(showerror, err))
    end
    minimal = (OTS_C.REAL_SPACE_HAMILTONIAN, OTS_C.REAL_SPACE_POSITION)
    for quantity in (:band_structure, :berry_curvature, :linear_transport, :linear_optical_response)
        selection = resolve((task(quantity),))
        @test selection.required_operators == minimal
        @test selection.required_sources == (:mmn, :chk, :eig, :authoritative_hamiltonian)
        @test Set(OTS_C.derived_operator_capabilities(selection.required_operators)) ==
              Set((:internal_connection, :gauge_correction, :berry_connection))
    end
    for quantity in (
        :quantum_metric,
        :quantum_metric_dipole,
        :quantum_metric_quadrupole,
        :quantum_christoffel_symbol,
    )
        selection = resolve((task(quantity),))
        @test Set(selection.required_operators) ==
              Set((minimal..., OTS_C.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR))
        @test :uiu in selection.required_sources
        @test :operator_target_contract in selection.required_sources
        @test !(:uhu in selection.required_sources)
        @test !(OTS_C.REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION in selection.required_operators)
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
        @test actual.selection_sha256 === nothing && combined.selection_sha256 === nothing
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
        cfg = ots_runtime_demand_configuration(definition)
        demand = OTS_R.operator_demand_plan([spec], cfg)
        expected = OTS_C.resolve_operator_requirements(
            (OTS_C.OperatorTask(quantity = q, method = m),);
            content_authentication = false,
        )
        @test Tuple(demand.required_operators) == expected.required_operators
        @test Set(keys(demand.required_components)) == Set(expected.required_operators)
        @test all(!isempty(demand.required_components[k]) for k in demand.required_operators)
    end
end

@testset "multipole public configuration and demand closure" begin
    for quantity in (:berry_curvature_dipole_conductivity, :berry_curvature_quadrupole_conductivity)
        definition = OTS_R.task_definition(quantity, :conventional, :integral)
        @test definition !== nothing
        rank = quantity == :berry_curvature_dipole_conductivity ? 3 : 4
        axes = ntuple(i -> mod1(i + 1, 3), rank)
        expected = OTS_C.resolve_operator_requirements(
            (OTS_C.OperatorTask(quantity = quantity, method = :conventional),);
            content_authentication = false,
        )
        for form in (:fermi_surface, :fermi_sea), full_tensor in (false, true)
            cfg = ots_runtime_demand_configuration(
                definition;
                tensor_indices = axes,
                integral_form = form,
                full_tensor = full_tensor,
            )
            @test cfg.berry_multipole !== nothing
            @test cfg.berry_multipole.parameters.integral_form == form
            expected_order =
                quantity == :berry_curvature_dipole_conductivity ?
                (form == :fermi_surface ? 0 : 1) : (form == :fermi_surface ? 1 : 2)
            @test cfg.berry_multipole.local_derivative_order == expected_order
            @test cfg.berry_multipole.components == (full_tensor ? () : (axes,))
            demand = OTS_R.operator_demand_plan(OTS_R.normalize_task_specs(cfg), cfg)
            @test Tuple(demand.required_operators) == expected.required_operators
            @test Set(keys(demand.required_components)) == Set(expected.required_operators)
            @test all(!isempty(demand.required_components[k]) for k in demand.required_operators)
        end
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
        @test loaded.manifest.inventory == collect(
            OTS_C.resolve_operator_requirements(fixture.tasks; content_authentication = false).required_operators,
        )
        @test length(loaded.operators) == 5
        @test all(
            loaded.operators[k].data == fixture.operators[k].data for k in keys(fixture.operators)
        )
        @test loaded.manifest.schema_version == "3.0"
        @test loaded.manifest.operator_selection_mode == "inventory"
        @test loaded.manifest.profile == :custom
        definitions = loaded.manifest.operator_qualification["mathematical_definitions"]
        records = loaded.manifest.operator_qualification["operators"]
        format_extension = first(OTS_IO._load_operator_bundle_extension!())
        retained_keys = Set(format_extension.MODEL_DEFINITION_KEYS)
        original_records = fixture.provenance["operator_qualification"]["operators"]
        expected_records = Dict(
            name => Dict(
                key => value for
                (key, value) in original if key in retained_keys && value !== nothing
            ) for (name, original) in original_records
        )
        filter!(pair -> !isempty(last(pair)), expected_records)
        @test records == expected_records
        @test all(
            !haskey(record, "operator_target_contract_sha256") &&
            !haskey(record, "source_status") &&
            !haskey(record, "gauge_status") for record in values(records)
        )
        @test definitions["authoritative_hamiltonian"] ==
              fixture.provenance["authoritative_hamiltonian"]
        HDF5.h5open(fixture.output, "r") do h
            @test !haskey(h, "qualification")
            @test !haskey(HDF5.attributes(h), "operator_selection_sha256")
        end
        @test !isfile(fixture.inputs.spn_file)
        # Current marker math/negative cases use the real source fixture only.
        neighbor_order_marker_tests(fixture, directory)
        # Source-generation contracts still consume actual definitions before
        # mathematical serialization; no removed digest field is reconstructed.
        for (label, mutate) in (
            ("backend", p -> p["authoritative_hamiltonian"] = "invalid_backend"),
            (
                "authority",
                p -> p["authoritative_hamiltonian_definition"] = "invalid-authority-definition",
            ),
            (
                "target",
                p ->
                    p["input_definitions"]["OPERATOR_TARGET_CONTRACT"] = "invalid-target-definition",
            ),
            ("frame", p -> p["band_frame_contract_definition"] = "invalid-frame-definition"),
            (
                "transform",
                p -> p["band_frame_transform_definition"] = "invalid-transform-definition",
            ),
        )
            original = read(fixture.inputs.uhu_provenance)
            try
                payload = JSON3.read(String(copy(original)), Dict{String, Any})
                mutate(payload)
                write(fixture.inputs.uhu_provenance, JSON3.write(payload))
                ots_rejects(
                    fixture.assemble,
                    r"(?i)(HAMILTONIAN|source|target|frame|provenance|definition)",
                )
            finally
                write(fixture.inputs.uhu_provenance, original)
            end
        end
        payload = JSON3.read(read(fixture.inputs.uhu_provenance, String), Dict{String, Any})
        reference_file = String(payload["references_hdf5"])
        reference_original = read(reference_file)
        try
            HDF5.h5open(reference_file, "r+") do h
                dataset = h["native_source_reference"]
                first_byte = dataset[1]
                dataset[1] = xor(first_byte, UInt8(1))
                close(dataset)
            end
            ots_rejects(fixture.assemble, r"(?i)(PHYSICAL_SOURCE|reference|source|definition)")
        finally
            write(reference_file, reference_original)
        end
        hidden_output = fixture.inputs.uhu_file * ".temporarily-missing"
        mv(fixture.inputs.uhu_file, hidden_output)
        try
            ots_rejects(fixture.assemble, r"uhu_file does not exist:")
        finally
            mv(hidden_output, fixture.inputs.uhu_file)
        end
        # Current readback validates mathematical conventions, not retired task
        # or certificate attributes. Test only fields actually consumed in v2.
        for (index, (node_path, attribute, value)) in enumerate((
            ("", "basis_metric", "nonorthogonal"),
            ("", "energy_unit", "Hartree"),
            ("", "length_unit", "bohr"),
            ("", "fourier_convention", "unsupported"),
            ("", "schema_version", "1.0"),
            ("geometry", "wannier_center_policy", "unsupported"),
            ("geometry", "real_space_replica_policy", "unsupported"),
            ("operators/position", "units", "unsupported"),
        ))
            path = joinpath(directory, "tamper-mathematical-$(index).h5")
            cp(fixture.output, path)
            chmod(path, 0o600)
            HDF5.h5open(path, "r+") do h
                node = isempty(node_path) ? h : h[node_path]
                HDF5.delete_attribute(node, attribute)
                HDF5.attributes(node)[attribute] = value
            end
            pattern =
                attribute == "schema_version" ? r"\bMODEL_SCHEMA_UNSUPPORTED\b" :
                r"(?i)(mathematical|definition|migration|replica|center|unit)"
            ots_rejects(() -> OTS_IO.read_real_space_operator_bundle(path), pattern)
        end
        path = joinpath(directory, "tamper-components.h5")
        cp(fixture.output, path)
        chmod(path, 0o600)
        with_republished_bundle_fixture(path) do handle
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
        required = collect(
            OTS_C.resolve_operator_requirements(fixture.tasks; content_authentication = false).required_operators,
        )
        full_demand = OTS_R.OperatorDemandPlan(
            required,
            Dict(
                kind => [
                    entry.component_indices for
                    entry in loaded.manifest.entries if entry.kind == kind
                ] for kind in required
            ),
            false,
        )
        for kind in keys(fixture.operators)
            incomplete = copy(fixture.operators)
            delete!(incomplete, kind)
            path = joinpath(directory, "missing-" * OTS_C.real_space_operator_name(kind) * ".h5")
            writer() = OTS_IO.write_real_space_operator_bundle(
                path,
                fixture.model.lattice,
                fixture.model.r_degeneracies,
                incomplete;
                profile = nothing,
                operator_tasks = fixture.tasks,
                geometry = fixture.geometry,
                provenance = fixture.provenance,
            )
            if kind in (OTS_C.REAL_SPACE_HAMILTONIAN, OTS_C.REAL_SPACE_POSITION)
                ots_rejects(writer, r"(?i)(Hamiltonian|position)")
            else
                # A valid smaller mathematical model is writable. The response
                # consumer, not a retired persisted task identity, rejects it.
                writer()
                smaller = OTS_IO.read_real_space_operator_bundle_manifest(path)
                @test_throws ArgumentError OTS_R.validate_operator_demand(smaller, full_demand)
            end
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
                                fresh_response_command(command),
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
            success(process) || continue
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
# Default full suite retains the numerical Gram fresh-process regression.
# Focused source-protocol batch A excludes it; batch B includes it explicitly.
if !(isdefined(@__MODULE__, :PROFILE_FOCUSED_REAL_SOURCE_ONLY) && PROFILE_FOCUSED_REAL_SOURCE_ONLY)
    include(joinpath(@__DIR__, "frozen_gram_neighbor_order_unit.jl"))
end

@testset "task selection without content authentication retains actual closure checks" begin
    tasks = (OTS_C.OperatorTask(quantity = :orbital_magnetization, method = :conventional),)
    current = OTS_IO.resolve_operator_selection(nothing, tasks; content_authentication = false)
    @test OTS_IO.operator_selection_sha256(current) === nothing
    tokens = OTS_IO.operator_task_token.(tasks)
    inventory = OTS_IO.resolved_operator_inventory(current)
    sources = OTS_IO.resolved_source_inventory(current)
    registry = OTS_IO.operator_selection_registry_version(current)
    validate(inv, src, digest, version) = OTS_IO.validate_task_derived_operator_selection(
        tokens,
        inv,
        src,
        digest,
        version;
        content_authentication = false,
    )
    restored = validate(inventory, sources, nothing, registry)
    @test restored.selection_sha256 === nothing
    @test restored.required_operators == Tuple(inventory)
    @test_throws ArgumentError validate(inventory[1:(end - 1)], sources, nothing, registry)
    @test_throws ArgumentError validate(inventory, sources[1:(end - 1)], nothing, registry)
    @test_throws ArgumentError validate(inventory, sources, "legacy-digest-only-record", registry)
    @test_throws ArgumentError validate(inventory, sources, nothing, "unknown-registry")
end
