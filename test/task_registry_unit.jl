using Test
using WannierNLQG

const RegistryRuntime = WannierNLQG.Runtime

@testset "typed task registry characterization" begin
    expected = Set{Tuple{Symbol, Symbol, Symbol}}()
    push!(expected, (:band_structure, :conventional, :kpath))
    for calculation in (:integral, :kslice)
        for method in (:conventional, :projector, :geometric_loop, :wilson_loop)
            push!(expected, (:shift_current, method, calculation))
        end
    end
    for method in (:conventional, :projector, :geometric_loop, :wilson_loop)
        push!(expected, (:quantum_hermitian_connection, method, :kslice))
    end
    for quantity in (
        :hermitian_curvature_tensor,
        :berry_curvature,
        :berry_curvature_dipole,
        :berry_curvature_quadrupole,
        :quantum_metric,
        :interband_berry_curvature,
        :interband_quantum_metric,
        :zeeman_interband_berry_curvature,
        :zeeman_interband_quantum_metric,
        :quantum_metric_dipole,
        :quantum_metric_quadrupole,
        :quantum_christoffel_symbol,
        :triple_phase_product,
    )
        push!(expected, (quantity, :conventional, :kslice))
    end
    for calculation in (:integral, :kslice)
        push!(expected, (:photon_drag_shift_current, :geometric_loop, calculation))
        push!(expected, (:injection_current, :conventional, calculation))
        push!(expected, (:injection_spin_current, :conventional, calculation))
        push!(expected, (:shift_spin_current, :conventional, calculation))
        push!(expected, (:photon_drag_injection_current, :conventional, calculation))
    end
    for method in (:geometric_loop, :wilson_loop)
        push!(expected, (:shift_vector, method, :kslice))
    end

    actual = Set(
        (
            RegistryRuntime.quantity_symbol(definition.quantity),
            RegistryRuntime.method_symbol(definition.method),
            RegistryRuntime.calculation_symbol(definition.calculation),
        ) for definition in RegistryRuntime.TASK_DEFINITIONS
    )
    @test length(RegistryRuntime.TASK_DEFINITIONS) == 38
    @test actual == expected

    expected_labels = Dict(
        (:band_structure, :kpath) => "BAND",
        (:shift_current, :integral) => "SC",
        (:photon_drag_shift_current, :integral) => "PDSC",
        (:injection_current, :integral) => "IC",
        (:injection_spin_current, :integral) => "ISC",
        (:shift_spin_current, :integral) => "SSC",
        (:photon_drag_injection_current, :integral) => "PDIC",
        (:shift_current, :kslice) => "SCK",
        (:quantum_hermitian_connection, :kslice) => "QHCK",
        (:hermitian_curvature_tensor, :kslice) => "HCTK",
        (:berry_curvature, :kslice) => "BCK",
        (:berry_curvature_dipole, :kslice) => "BCDK",
        (:berry_curvature_quadrupole, :kslice) => "BCQK",
        (:quantum_metric, :kslice) => "QMK",
        (:interband_berry_curvature, :kslice) => "IBCK",
        (:interband_quantum_metric, :kslice) => "IQMK",
        (:zeeman_interband_berry_curvature, :kslice) => "ZIBCK",
        (:zeeman_interband_quantum_metric, :kslice) => "ZIQMK",
        (:quantum_metric_dipole, :kslice) => "QMDK",
        (:quantum_metric_quadrupole, :kslice) => "QMQK",
        (:quantum_christoffel_symbol, :kslice) => "QCSK",
        (:triple_phase_product, :kslice) => "TPPK",
        (:photon_drag_shift_current, :kslice) => "PDSCK",
        (:shift_vector, :kslice) => "SVK",
        (:injection_current, :kslice) => "ICK",
        (:injection_spin_current, :kslice) => "ISCK",
        (:shift_spin_current, :kslice) => "SSCK",
        (:photon_drag_injection_current, :kslice) => "PDICK",
    )
    actual_labels = Dict(
        (
            RegistryRuntime.quantity_symbol(definition.quantity),
            RegistryRuntime.calculation_symbol(definition.calculation),
        ) => definition.label for definition in RegistryRuntime.QUANTITY_SHORT_LABELS
    )
    @test length(RegistryRuntime.QUANTITY_SHORT_LABELS) == 28
    @test actual_labels == expected_labels
    @test length(unique(values(actual_labels))) == 28
    @test count(pair -> pair[1][2] == :integral, collect(actual_labels)) == 6
    @test count(pair -> pair[1][2] == :kslice, collect(actual_labels)) == 21
    @test count(pair -> pair[1][2] == :kpath, collect(actual_labels)) == 1

    band_definition = RegistryRuntime.task_definition(:band_structure, :conventional, :kpath)
    @test band_definition.executor == RegistryRuntime.EXECUTOR_BAND_STRUCTURE
    @test band_definition.output_policy == RegistryRuntime.OUTPUT_BAND_STRUCTURE
    @test RegistryRuntime.task_definition(:shift_current, :conventional, :kpath) === nothing
    @test_throws ErrorException RegistryRuntime.normalize_calculation("Band")
    @test RegistryRuntime.normalize_calculation("K-path") == :kpath
    @test all(
        endswith(label, "K") for
        ((_, calculation), label) in actual_labels if calculation == :kslice
    )
    @test RegistryRuntime.validate_quantity_short_label_registry() === nothing

    for ((quantity, calculation), label) in actual_labels
        @test RegistryRuntime.quantity_short_label(quantity, calculation) == label
        label_definition = RegistryRuntime.quantity_short_label_definition(label)
        @test label_definition !== nothing
        @test RegistryRuntime.quantity_symbol(label_definition.quantity) == quantity
        @test RegistryRuntime.calculation_symbol(label_definition.calculation) == calculation
        @test lowercase(label) == RegistryRuntime.result_observable_suffix(quantity, calculation)
    end

    triple_phase_definition =
        RegistryRuntime.task_definition(:triple_phase_product, :conventional, :kslice)
    @test triple_phase_definition.band_policy == RegistryRuntime.BAND_TRIPLE_GROUPS
    @test triple_phase_definition.fourier_policy == RegistryRuntime.FOURIER_CONVENTIONAL_GEOMETRY

    for definition in RegistryRuntime.TASK_DEFINITIONS
        quantity = RegistryRuntime.quantity_symbol(definition.quantity)
        method = RegistryRuntime.method_symbol(definition.method)
        calculation = RegistryRuntime.calculation_symbol(definition.calculation)
        @test RegistryRuntime.select_task(quantity, method, calculation) == definition.task
        @test RegistryRuntime.result_observable_suffix(quantity, calculation) ==
              definition.observable_suffix
        @test method in RegistryRuntime.supported_methods(quantity, calculation)

        short_label = RegistryRuntime.quantity_short_label(quantity, calculation)
        short_spec = only(
            RegistryRuntime.normalize_task_specs(
                WannierNLQG.Runtime.EffectiveTaskConfig(
                    tasks = [(
                        short_label,
                        RegistryRuntime.canonical_method_name(method),
                        RegistryRuntime.canonical_calculation_name(calculation),
                    )],
                    fourier_backend = "direct",
                ),
            ),
        )
        canonical_spec = only(
            RegistryRuntime.normalize_task_specs(
                WannierNLQG.Runtime.EffectiveTaskConfig(
                    tasks = [(
                        RegistryRuntime.canonical_quantity_name(quantity),
                        RegistryRuntime.canonical_method_name(method),
                        RegistryRuntime.canonical_calculation_name(calculation),
                    )],
                    fourier_backend = "direct",
                ),
            ),
        )
        @test (
            short_spec.quantity,
            short_spec.method,
            short_spec.calculation,
            short_spec.task,
            short_spec.label,
        ) == (
            canonical_spec.quantity,
            canonical_spec.method,
            canonical_spec.calculation,
            canonical_spec.task,
            canonical_spec.label,
        )
    end

    @test RegistryRuntime.normalize_quantity("QHCK") == :quantum_hermitian_connection
    @test RegistryRuntime.normalize_quantity("shift-current") == :shift_current
    for legacy_label in (
        "QHC",
        "HCT",
        "BCD",
        "BCQ",
        "QM",
        "IBC",
        "IQM",
        "ZIBC",
        "ZIQM",
        "QMD",
        "QMQ",
        "QCS",
        "TPP",
        "Christoffel",
        "Triple_Phase",
        "SGK",
    )
        @test_throws Exception RegistryRuntime.normalize_quantity(legacy_label)
    end
    @test RegistryRuntime.normalize_method("Wilson") == :wilson_loop
    @test RegistryRuntime.normalize_calculation("K-space slice") == :kslice
    @test_throws ErrorException RegistryRuntime.normalize_task_specs(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("IC", "K-slice")],
            fourier_backend = "direct",
        ),
    )
    @test_throws ErrorException RegistryRuntime.normalize_task_specs(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("ICK", "Integral")],
            fourier_backend = "direct",
        ),
    )
    @test_throws ErrorException RegistryRuntime.normalize_task_specs(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("BCK", "Integral")],
            fourier_backend = "direct",
        ),
    )
    @test_throws Exception RegistryRuntime.select_task(
        :quantum_hermitian_connection,
        :conventional,
        :integral,
    )
    @test_throws Exception RegistryRuntime.select_task(:berry_curvature, :projector, :kslice)

    @test all(isconcretetype, fieldtypes(RegistryRuntime.TaskDefinition))
    @test all(isconcretetype, fieldtypes(RegistryRuntime.NormalizedTaskPlan))
    spec = RegistryRuntime.NormalizedTaskSpec(
        :shift_current,
        :conventional,
        :integral,
        :shift_current_integral,
        ("SC", "Conventional", "Integral"),
        "shift_current/integral/conventional",
    )
    plan = @inferred RegistryRuntime.normalized_task_plan(spec, Int[1, 2, 2])
    @test plan.tensor_indices == (1, 2, 2, 0)
    @test plan.tensor_rank == 0x03
    @test isconcretetype(typeof(plan))

    response = zeros(ComplexF64, 1, 2, 2, 2)
    accumulator = RegistryRuntime.IntegralTaskAccumulator(
        spec,
        String[],
        [copy(response), copy(response)],
        copy(response),
        copy(response),
    )
    @test accumulator isa RegistryRuntime.IntegralTaskAccumulator{4}
    @test fieldtype(typeof(accumulator), :worker_data) == Vector{Array{ComplexF64, 4}}
    heterogeneous_states = RegistryRuntime.IntegralTaskAccumulator[accumulator]
    lookup_return = Core.Compiler.return_type(
        RegistryRuntime._find_integral_state,
        Tuple{typeof(heterogeneous_states), Symbol, Symbol, Val{4}},
    )
    @test lookup_return == Union{Nothing, typeof(accumulator)}
    @test RegistryRuntime._find_integral_state(
        heterogeneous_states,
        :shift_current,
        :conventional,
        Val(4),
    ) === accumulator

    num_kpoints = 197
    num_lanes = RegistryRuntime._deterministic_integral_lane_count(num_kpoints)
    lane_ranges = [
        RegistryRuntime._deterministic_integral_lane_range(num_kpoints, num_lanes, lane_id) for
        lane_id in 1:num_lanes
    ]
    @test reduce(vcat, collect.(lane_ranges)) == collect(1:num_kpoints)
    @test all(!isempty, lane_ranges)
    for mpi_size in (1, 2, 4, 7)
        rank_lanes = [
            RegistryRuntime._local_deterministic_integral_lanes(num_lanes, rank, mpi_size) for
            rank in 0:(mpi_size - 1)
        ]
        @test sort!(reduce(vcat, rank_lanes)) == collect(1:num_lanes)
        @test sum(length, rank_lanes) == num_lanes
    end

    deterministic_state = RegistryRuntime.IntegralTaskAccumulator(
        spec,
        String[],
        [fill(ComplexF64(lane_id), 1, 1, 1, 1) for lane_id in 1:4],
        zeros(ComplexF64, 1, 1, 1, 1),
        zeros(ComplexF64, 1, 1, 1, 1),
    )
    RegistryRuntime._reduce_integral_states!([deterministic_state], 0, 0, nothing)
    @test only(deterministic_state.global_data) == 10.0 + 0.0im
end
