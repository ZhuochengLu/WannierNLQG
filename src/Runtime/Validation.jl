"""
Validate task combinations, geometry, numerical controls, Fourier settings and output options; return normalized task specifications.

Reject unsupported or contradictory settings before numerical computation; the configuration object is not mutated.
"""
function validate_config(cfg::EffectiveTaskConfig)
    specs = normalize_task_specs(cfg)
    normalize_wannier_center_convention(cfg.wannier_center_convention)
    _response_symmetry_policy(cfg.response_symmetry_policy)
    response_symmetry_kmesh_mode = _response_symmetry_kmesh_mode(cfg.response_symmetry_kmesh_mode)
    7 <= cfg.response_output_digits <= 17 || error(
        "Invalid response_output_digits=$(cfg.response_output_digits); expected an integer from 7 through 17.",
    )
    using_operator_bundle =
        cfg.real_space_operator_bundle_file !== nothing &&
        !isempty(strip(something(cfg.real_space_operator_bundle_file, "")))

    validate_fourier_configuration(cfg)

    if any(n -> n <= 0, cfg.k_mesh)
        error("Invalid k_mesh=$(cfg.k_mesh); all entries must be positive.")
    end
    if cfg.spatial_dimension < 1 || cfg.spatial_dimension > 3
        error("Invalid spatial_dimension=$(cfg.spatial_dimension); expected 1, 2, or 3.")
    end
    calculation = specs[1].calculation
    validate_k_mesh_for_calculation(cfg.k_mesh, calculation, cfg.spatial_dimension)
    band_structure = all(
        spec -> begin
            definition = task_definition(spec.quantity, spec.method, spec.calculation)
            definition !== nothing && definition.executor == EXECUTOR_BAND_STRUCTURE
        end,
        specs,
    )
    if calculation == :kpath
        Symbol(_canonical_key(cfg.fourier_backend)) == :direct || error(
            "K-path calculation requires fourier_backend=\"direct\"; arbitrary paths do not support Mixed/Auto FFT.",
        )
        cfg.NKdiv === nothing && cfg.NKFFT === nothing || error(
            "K-path calculation forbids NKdiv/NKFFT because a path is not a uniform FFT mesh.",
        )
        validate_kpath_config(cfg)
    elseif !isempty(cfg.kpath_nodes) ||
           !isempty(cfg.kpoints_per_segment) ||
           cfg.band_hermiticity_tolerance != 1.0e-10
        error(
            "kpath_nodes, kpoints_per_segment, and Band Hermiticity controls " *
            "are valid only for K-path calculation.",
        )
    end
    if band_structure
        isfinite(cfg.fermi_energy) || error("Band energy reference fermi_energy must be finite.")
        isfinite(cfg.band_hermiticity_tolerance) && cfg.band_hermiticity_tolerance >= 0.0 ||
            error("band_hermiticity_tolerance must be finite and nonnegative.")
    end
    isfinite(cfg.wigner_seitz_tolerance) && cfg.wigner_seitz_tolerance > 0.0 ||
        error("wigner_seitz_tolerance must be finite and positive.")
    cfg.wigner_seitz_search_size > 0 || error("wigner_seitz_search_size must be positive.")
    replica_policy = Symbol(_canonical_key(cfg.real_space_replica_policy))
    replica_policy in (:auto, :input, :minimum_distance) || error(
        "real_space_replica_policy=$(repr(cfg.real_space_replica_policy)) is invalid; use \"auto\", \"input\", or \"minimum_distance\".",
    )
    cfg.wsvec_file === nothing ||
        !isempty(strip(something(cfg.wsvec_file))) ||
        error("wsvec_file must be nothing or a non-empty path.")
    cfg.mp_grid === nothing ||
        all(>(0), something(cfg.mp_grid)) ||
        error("mp_grid entries must be positive; got $(cfg.mp_grid).")
    if response_symmetry_kmesh_mode == :full
        if cfg.response_symmetry_report_enabled
            cfg.response_symmetry_file === nothing && error(
                "response_symmetry_kmesh_mode=\"full\" with " *
                "response_symmetry_report_enabled=true requires response_symmetry_file.",
            )
        elseif cfg.response_symmetry_file !== nothing
            error(
                "response_symmetry_kmesh_mode=\"full\" with " *
                "response_symmetry_report_enabled=false requires response_symmetry_file=nothing; " *
                "enable the report tag before supplying a symmetry artifact.",
            )
        end
    end
    if cfg.response_symmetry_file !== nothing
        isempty(strip(something(cfg.response_symmetry_file))) &&
            error("response_symmetry_file must be nothing or a non-empty path.")
        calculation in (:integral, :kslice) || error(
            "response_symmetry_file is supported only for q=0 Integral or K-slice response tasks.",
        )
        nonzero_photon_momentum(cfg.photon_momentum) && error(
            "response_symmetry_file supports only q=0 responses; finite photon_momentum=$(cfg.photon_momentum) is out of scope.",
        )
        for spec in specs
            key = (spec.quantity, spec.method, spec.calculation)
            key in RESPONSE_SYMMETRY_SUPPORTED_TASKS || error(
                "response_symmetry_file does not support task $(spec.label); supported scope is q=0 charge/spin shift and injection response tasks.",
            )
        end
    end
    band_structure || validate_config_cartesian_indices(cfg, specs)
    if cfg.band_window_size != -1 && cfg.band_window_size <= 0
        error(
            "Invalid band_window_size=$(cfg.band_window_size); use a positive value or -1 for all bands.",
        )
    end
    if cfg.finite_difference_step <= 0
        error(
            "Invalid finite_difference_step=$(cfg.finite_difference_step); expected a positive finite-difference step.",
        )
    end
    if cfg.degeneracy_threshold < 0
        error(
            "Invalid degeneracy_threshold=$(cfg.degeneracy_threshold); expected a non-negative threshold.",
        )
    end
    if cfg.spin_enabled
        isempty(cfg.spin_file) && error("spin_enabled=true requires spin_file.")
        isempty(cfg.checkpoint_file) && error("spin_enabled=true requires checkpoint_file.")
    end
    if any(spec -> is_zeeman_interband_quantum_geometry_quantity(spec.quantity), specs) &&
       !cfg.spin_enabled &&
       !using_operator_bundle
        error(
            "Zeeman interband quantum geometry requires either a spin-capable operator bundle or spin_enabled=true with spin_file and checkpoint_file.",
        )
    end
    if any(spec -> spec.quantity == :shift_vector && spec.method == :wilson_loop, specs) &&
       nonzero_photon_momentum(cfg.photon_momentum)
        error(
            "Wilson_Loop Shift_Vector K-slice supports only photon_momentum=(0.0, 0.0, 0.0); got photon_momentum=$(cfg.photon_momentum).",
        )
    end
    if any(
        spec -> spec.quantity == :quantum_hermitian_connection && spec.method == :wilson_loop,
        specs,
    ) && nonzero_photon_momentum(cfg.photon_momentum)
        error(
            "Wilson_Loop Quantum_Hermitian_Connection K-slice supports only photon_momentum=(0.0, 0.0, 0.0); got photon_momentum=$(cfg.photon_momentum).",
        )
    end
    cfg.progress_percent_interval === nothing ||
        1 <= cfg.progress_percent_interval <= 100 ||
        error(
            "Invalid progress_percent_interval=$(cfg.progress_percent_interval); use nothing for environment/default behavior or an integer from 1 through 100.",
        )
    progress_verbosity_symbol(cfg.progress_verbosity)

    if any(spec -> spec.quantity == :shift_spin_current, specs) &&
       cfg.denominator_regularization <= 0.0
        error(
            "Shift_Spin_Current requires denominator_regularization > 0 because its interband energy weight contains (Delta_nm^2 + sc_eta^2)^(-2).",
        )
    end

    if calculation == :kslice
        if any(
            spec -> spec.quantity in (
                :shift_current,
                :photon_drag_shift_current,
                :injection_current,
                :injection_spin_current,
                :shift_spin_current,
                :photon_drag_injection_current,
            ),
            specs,
        ) && length(cfg.photon_energies) != 1
            error(
                "K-slice tasks for current responses expect exactly one optical energy in photon_energies, got length=$(length(cfg.photon_energies)).",
            )
        end
    elseif any(
        spec -> spec.quantity in (
            :shift_current,
            :photon_drag_shift_current,
            :injection_current,
            :injection_spin_current,
            :shift_spin_current,
            :photon_drag_injection_current,
        ),
        specs,
    ) && isempty(cfg.photon_energies)
        error("Integral current-response tasks require a non-empty photon_energies vector.")
    end

    return specs
end

"""Validate one normalized reciprocal-space path independently of the task using it."""
function validate_kpath_config(cfg::EffectiveTaskConfig)
    length(cfg.kpath_nodes) >= 2 ||
        error("K-path calculation requires at least two kpath_nodes entries.")
    segment_count = length(cfg.kpath_nodes) - 1
    length(cfg.kpoints_per_segment) == segment_count || error(
        "kpoints_per_segment length=$(length(cfg.kpoints_per_segment)) must equal segment_count=$(segment_count).",
    )
    all(>=(2), cfg.kpoints_per_segment) ||
        error("Every kpoints_per_segment entry must be at least 2; got $(cfg.kpoints_per_segment).")
    isfinite(cfg.wigner_seitz_tolerance) && cfg.wigner_seitz_tolerance > 0.0 ||
        error("wigner_seitz_tolerance must be finite and positive.")
    cfg.wigner_seitz_search_size > 0 || error("wigner_seitz_search_size must be positive.")
    policy = Symbol(_canonical_key(cfg.real_space_replica_policy))
    policy in (:auto, :input, :minimum_distance) || error(
        "real_space_replica_policy=$(repr(cfg.real_space_replica_policy)) is invalid; use \"auto\", \"input\", or \"minimum_distance\".",
    )
    cfg.mp_grid === nothing ||
        all(>(0), something(cfg.mp_grid)) ||
        error("mp_grid entries must be positive; got $(cfg.mp_grid).")
    for (index, (label, coordinate)) in enumerate(cfg.kpath_nodes)
        isempty(strip(label)) && error("kpath_nodes entry $(index) label must not be empty.")
        all(isfinite, coordinate) ||
            error("kpath_nodes entry $(index) contains non-finite fractional coordinates.")
        if index > 1
            previous = cfg.kpath_nodes[index - 1][2]
            maximum(abs(coordinate[axis] - previous[axis]) for axis in 1:3) > 1.0e-14 ||
                error("kpath_nodes entries $(index - 1) and $(index) define a zero-length segment.")
        end
    end
    return nothing
end

const LEGACY_FOURIER_CONFIGURATION_ENV =
    ("WANNIERNLQG_FOURIER_BACKEND", "WANNIERNLQG_MIXED_NKDIV", "WANNIERNLQG_MIXED_NKFFT")

"""
Accept an absent factor or positive mesh-compatible two/three-entry factors; reject incompatible lengths and nonpositive entries.
"""
function validate_fourier_factor(name::AbstractString, value, k_mesh)
    value === nothing && return nothing
    length(value) in (2, 3) || error("$(name) must contain two or three positive integers.")
    all(>(0), value) || error("$(name) entries must be positive; got $(value).")
    length(value) == length(k_mesh) ||
        (length(value) == 3 && length(k_mesh) == 2 && value[3] == 1) ||
        error("$(name)=$(value) is incompatible with k_mesh=$(k_mesh).")
    return nothing
end

"""
Reject retired environment overrides and incompatible explicit Mixed-FFT factors before execution.

Require accepted backend spelling and exact factor divisibility/product against the configured k mesh.
"""
function validate_fourier_configuration(cfg::EffectiveTaskConfig)
    legacy = String[name for name in LEGACY_FOURIER_CONFIGURATION_ENV if haskey(ENV, name)]
    isempty(legacy) || error(
        "Legacy Mixed-FFT environment configuration is no longer supported: " *
        join(legacy, ", ") *
        ". Set EffectiveTaskConfig(fourier_backend=\"direct|mixed|auto\", NKdiv=..., NKFFT=...).",
    )
    backend = Symbol(_canonical_key(cfg.fourier_backend))
    backend in (:mixed, :direct, :auto) || error(
        "fourier_backend=$(repr(cfg.fourier_backend)) is invalid; use \"direct\", \"mixed\", or \"auto\".",
    )
    if backend == :direct && (cfg.NKdiv !== nothing || cfg.NKFFT !== nothing)
        error(
            "fourier_backend=$(repr(cfg.fourier_backend)) forbids NKdiv/NKFFT. " *
            "Use fourier_backend=\"mixed\" for explicit or inferred Mixed-FFT factors.",
        )
    end
    validate_fourier_factor("NKdiv", cfg.NKdiv, cfg.k_mesh)
    validate_fourier_factor("NKFFT", cfg.NKFFT, cfg.k_mesh)
    if backend == :mixed && cfg.NKdiv === nothing && cfg.NKFFT === nothing
        error("fourier_backend=\"mixed\" requires at least one explicit factor: NKdiv or NKFFT.")
    end
    mesh = length(cfg.k_mesh) == 2 ? (cfg.k_mesh[1], cfg.k_mesh[2], 1) : cfg.k_mesh
    nkdiv =
        cfg.NKdiv === nothing ? nothing :
        length(cfg.NKdiv) == 2 ? (cfg.NKdiv[1], cfg.NKdiv[2], 1) : cfg.NKdiv
    nkfft =
        cfg.NKFFT === nothing ? nothing :
        length(cfg.NKFFT) == 2 ? (cfg.NKFFT[1], cfg.NKFFT[2], 1) : cfg.NKFFT
    if nkdiv !== nothing && nkfft !== nothing
        product = ntuple(axis -> nkdiv[axis] * nkfft[axis], 3)
        product == mesh || error("NKdiv*NKFFT=$(product) does not equal k_mesh=$(mesh).")
    elseif nkdiv !== nothing
        all(mesh[axis] % nkdiv[axis] == 0 for axis in 1:3) ||
            error("NKdiv=$(nkdiv) must divide k_mesh=$(mesh) exactly.")
    elseif nkfft !== nothing
        all(mesh[axis] % nkfft[axis] == 0 for axis in 1:3) ||
            error("NKFFT=$(nkfft) must divide k_mesh=$(mesh) exactly.")
    end
    return nothing
end

"""
Require two mesh entries for k slices and compatible two/three-dimensional integral meshes.

Three-entry integration meshes require spatial dimension three; invalid combinations raise errors.
"""
function validate_k_mesh_for_calculation(
    k_mesh::Union{NTuple{2, Int}, NTuple{3, Int}},
    calculation::Symbol,
    spatial_dimension::Int,
)
    if calculation == :kslice
        length(k_mesh) == 2 ||
            error("K-slice requires two-entry k_mesh=(nk1,nk2); got k_mesh=$(k_mesh).")
    elseif calculation == :integral
        length(k_mesh) in (2, 3) || error(
            "Integral requires k_mesh=(nk1,nk2) or k_mesh=(nk1,nk2,nk3); got k_mesh=$(k_mesh).",
        )
        if length(k_mesh) == 3 && spatial_dimension != 3
            error(
                "Integral with three-entry k_mesh=$(k_mesh) requires spatial_dimension=3; got spatial_dimension=$(spatial_dimension).",
            )
        end
    end
    return nothing
end

# Return the public spelling used in short-label scope errors.
short_label_calculation_name(calculation::Symbol) =
    calculation == :kslice ? "K-slice" : calculation == :kpath ? "K-path" : "Integral"

# Require a short label to be used with the calculation registered for that label.
function validate_quantity_short_label_calculation(
    requested_quantity::AbstractString,
    quantity::Symbol,
    calculation::Symbol,
)
    definition = quantity_short_label_definition(requested_quantity)
    definition === nothing && return nothing

    registered_calculation = calculation_symbol(definition.calculation)
    registered_calculation == calculation && return nothing

    replacement = _find_quantity_short_label(quantity, calculation)
    if replacement === nothing
        error(
            "Short label=\"$(requested_quantity)\" is valid only for $(short_label_calculation_name(registered_calculation)); " *
            "$(canonical_quantity_name(quantity)) has no $(short_label_calculation_name(calculation)) task.",
        )
    end
    error(
        "Short label=\"$(requested_quantity)\" is valid only for $(short_label_calculation_name(registered_calculation)); " *
        "use quantity=\"$(replacement)\" for $(short_label_calculation_name(calculation)).",
    )
end

"""
Resolve requested task tuples through the registry into ordered `NormalizedTaskSpec` values, validating supported combinations and bundle compatibility.
"""
function normalize_task_specs(cfg::EffectiveTaskConfig)
    isempty(cfg.tasks) && error(
        "EffectiveTaskConfig.tasks must contain at least one (quantity, method, calculation) or (quantity, calculation) tuple.",
    )

    specs = NormalizedTaskSpec[]
    seen = Set{Tuple{Symbol, Symbol, Symbol}}()
    calculation_ref = nothing

    for requested in cfg.tasks
        requested_tuple = normalize_requested_task_tuple(requested)
        calculation = normalize_calculation(requested_tuple[length(requested_tuple) == 2 ? 2 : 3])
        quantity = normalize_quantity(requested_tuple[1])
        validate_quantity_short_label_calculation(requested_tuple[1], quantity, calculation)
        if length(requested_tuple) == 2
            method = infer_single_supported_method(quantity, calculation)
        else
            method = normalize_method(requested_tuple[2])
        end

        if quantity == :photon_drag_shift_current && method == :wilson_loop
            runtime_notice(
                "quantity=\"Photon_Drag_Shift_Current\" uses the finite-q geometric-loop theory; overriding method=\"Wilson_Loop\" to method=\"Geometric_Loop\".",
            )
            method = :geometric_loop
        end
        if quantity == :injection_current && nonzero_photon_momentum(cfg.photon_momentum)
            runtime_notice(
                "quantity=\"Injection_Current\" is a length-gauge q=0 calculation; ignoring requested photon_momentum=$(cfg.photon_momentum).",
            )
        end
        if quantity in (:injection_spin_current, :shift_spin_current) &&
           nonzero_photon_momentum(cfg.photon_momentum)
            runtime_notice(
                "quantity=\"$(canonical_quantity_name(quantity))\" is a length-gauge q=0 calculation; ignoring requested photon_momentum=$(cfg.photon_momentum).",
            )
        end

        if isnothing(calculation_ref)
            calculation_ref = calculation
        elseif calculation != calculation_ref
            mixed_calculations = Set((calculation_ref, calculation))
            if :kpath in mixed_calculations
                error(
                    "K-path tasks cannot be mixed with Integral or K-slice tasks in one EffectiveTaskConfig; got $(calculation_ref) and $(calculation).",
                )
            end
            error(
                "Mixed Integral and K-slice tasks are not supported in one EffectiveTaskConfig; got $(calculation_ref) and $(calculation).",
            )
        end

        task = select_task(quantity, method, calculation)
        key = (quantity, method, calculation)
        if key in seen
            error(
                "Duplicate task after normalization: $(task_label(quantity, method, calculation)).",
            )
        end
        push!(seen, key)
        push!(
            specs,
            NormalizedTaskSpec(
                quantity,
                method,
                calculation,
                task,
                requested_tuple,
                task_label(quantity, method, calculation),
            ),
        )
    end

    return specs
end

"""
Copy a two- or three-entry tuple of strings into concrete String values; reject other shapes or nonstring fields.
"""
function normalize_requested_task_tuple(requested)
    if !(requested isa Tuple)
        error("Invalid task=$(requested); expected a tuple of strings.")
    end
    if length(requested) != 2 && length(requested) != 3
        error(
            "Invalid task=$(requested); expected (quantity, calculation) or (quantity, method, calculation).",
        )
    end
    if any(value -> !(value isa AbstractString), requested)
        error("Invalid task=$(requested); all task fields must be strings.")
    end
    return ntuple(i -> String(requested[i]), length(requested))
end

"""
Return registered methods for a normalized quantity/calculation pair in stable registry order.
"""
function supported_methods(quantity::Symbol, calculation::Symbol)
    return registry_supported_methods(quantity, calculation)
end

"""
Format supported method display names as a quoted comma-separated list for input errors.
"""
function method_list_text(methods::Vector{Symbol})
    return join(["\"" * canonical_method_name(method) * "\"" for method in methods], ", ")
end

"""
Return the sole registered method, or raise an error for unsupported/ambiguous omitted-method requests.
"""
function infer_single_supported_method(quantity::Symbol, calculation::Symbol)
    methods = supported_methods(quantity, calculation)
    if length(methods) == 1
        return methods[1]
    elseif isempty(methods)
        error(
            "Unsupported combination: $(canonical_quantity_name(quantity)) + $(canonical_calculation_name(calculation)) is not defined.",
        )
    end
    error(
        "Method omitted for $(canonical_quantity_name(quantity)) + $(canonical_calculation_name(calculation)); choose one of $(method_list_text(methods)).",
    )
end

"""
Return the public tensor rank required by a task, including four-axis spin-current and curvature cases.
"""
function expected_cidx_rank(spec::NormalizedTaskSpec)
    if is_rank2_real_only_kslice_quantity(spec.quantity)
        return 2
    elseif is_rank4_target_group_real_kslice_quantity(spec.quantity) ||
           spec.quantity == :hermitian_curvature_tensor
        return 4
    elseif spec.quantity in (:injection_spin_current, :shift_spin_current)
        return 4
    end
    return 3
end

"""
Return per-axis Cartesian bounds, retaining three spin components even when spatial dimension is reduced.
"""
function tensor_axis_limits(spec::NormalizedTaskSpec, spatial_dimension::Int)
    if spec.quantity in (:injection_spin_current, :shift_spin_current)
        return Int[spatial_dimension, 3, spatial_dimension, spatial_dimension]
    elseif is_zeeman_interband_quantum_geometry_quantity(spec.quantity)
        return Int[spatial_dimension, 3]
    end
    return fill(spatial_dimension, expected_cidx_rank(spec))
end

"""
Test whether every task is a conventional integrated charge/spin current, the permitted mixed-rank tensor bundle.
"""
function is_mixed_rank_integral_current_bundle(specs::Vector{NormalizedTaskSpec})
    quantities = (:shift_current, :injection_current, :injection_spin_current, :shift_spin_current)
    return all(
        spec ->
            spec.calculation == :integral &&
            spec.method == :conventional &&
            spec.quantity in quantities,
        specs,
    )
end

"""
Reject incompatible bundle tensor ranks or per-axis limits, except the explicit mixed-rank conventional integral-current case.
"""
function validate_config_cartesian_indices(
    cfg::EffectiveTaskConfig,
    specs::Vector{NormalizedTaskSpec},
)
    ranks = unique(expected_cidx_rank.(specs))
    if length(ranks) != 1
        is_mixed_rank_integral_current_bundle(specs) && return nothing
        error(
            "Mixed tasks require incompatible tensor_indices ranks: got $(ranks). Split rank-2 tasks such as Berry_Curvature/Quantum_Metric/Interband_Berry_Curvature/Interband_Quantum_Metric/Zeeman_Interband_Berry_Curvature/Zeeman_Interband_Quantum_Metric, rank-3 tensor tasks such as Berry_Curvature_Dipole/Quantum_Metric_Dipole/Quantum_Christoffel_Symbol, and rank-4 tensor tasks such as Hermitian_Curvature_Tensor/Berry_Curvature_Quadrupole/Quantum_Metric_Quadrupole into separate EffectiveTaskConfig runs.",
        )
    end
    limits = unique(Tuple(tensor_axis_limits(spec, cfg.spatial_dimension)) for spec in specs)
    length(limits) == 1 ||
        error("Mixed tasks require incompatible tensor_indices axis limits: got $(limits).")
    normalize_cartesian_indices(cfg.tensor_indices, collect(first(limits)), "tensor_indices")
    return nothing
end

"""
Return the registry task key for a supported normalized combination; otherwise raise its specific public validation error.
"""
function select_task(quantity::Symbol, method::Symbol, calculation::Symbol)
    definition = task_definition(quantity, method, calculation)
    definition !== nothing && return definition.task

    # These messages predate the registry and are part of the public validation
    # contract. Legal routing above has one source of truth; this cold error path
    # deliberately preserves the exact historical diagnostics.
    if quantity == :quantum_hermitian_connection && calculation == :integral
        error("Unsupported combination: Quantum_Hermitian_Connection + Integral is not defined.")
    elseif quantity == :hermitian_curvature_tensor && calculation == :kslice
        error(
            "Unsupported combination: Hermitian_Curvature_Tensor + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :hermitian_curvature_tensor && calculation == :integral
        error("Unsupported combination: Hermitian_Curvature_Tensor + Integral is not defined.")
    elseif quantity == :berry_curvature && calculation == :kslice
        error(
            "Unsupported combination: Berry_Curvature + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :berry_curvature && calculation == :integral
        error("Unsupported combination: Berry_Curvature + Integral is not defined.")
    elseif quantity == :berry_curvature_dipole && calculation == :kslice
        error(
            "Unsupported combination: Berry_Curvature_Dipole + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :berry_curvature_dipole && calculation == :integral
        error("Unsupported combination: Berry_Curvature_Dipole + Integral is not defined.")
    elseif quantity == :berry_curvature_quadrupole && calculation == :kslice
        error(
            "Unsupported combination: Berry_Curvature_Quadrupole + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :berry_curvature_quadrupole && calculation == :integral
        error("Unsupported combination: Berry_Curvature_Quadrupole + Integral is not defined.")
    elseif quantity == :quantum_metric && calculation == :kslice
        error(
            "Unsupported combination: Quantum_Metric + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :quantum_metric && calculation == :integral
        error("Unsupported combination: Quantum_Metric + Integral is not defined.")
    elseif quantity == :interband_berry_curvature && calculation == :kslice
        error(
            "Unsupported combination: Interband_Berry_Curvature + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :interband_berry_curvature && calculation == :integral
        error("Unsupported combination: Interband_Berry_Curvature + Integral is not defined.")
    elseif quantity == :interband_quantum_metric && calculation == :kslice
        error(
            "Unsupported combination: Interband_Quantum_Metric + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :interband_quantum_metric && calculation == :integral
        error("Unsupported combination: Interband_Quantum_Metric + Integral is not defined.")
    elseif quantity == :zeeman_interband_berry_curvature && calculation == :kslice
        error(
            "Unsupported combination: Zeeman_Interband_Berry_Curvature + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :zeeman_interband_berry_curvature && calculation == :integral
        error(
            "Unsupported combination: Zeeman_Interband_Berry_Curvature + Integral is not defined.",
        )
    elseif quantity == :zeeman_interband_quantum_metric && calculation == :kslice
        error(
            "Unsupported combination: Zeeman_Interband_Quantum_Metric + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :zeeman_interband_quantum_metric && calculation == :integral
        error("Unsupported combination: Zeeman_Interband_Quantum_Metric + Integral is not defined.")
    elseif quantity == :quantum_metric_dipole && calculation == :kslice
        error(
            "Unsupported combination: Quantum_Metric_Dipole + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :quantum_metric_dipole && calculation == :integral
        error("Unsupported combination: Quantum_Metric_Dipole + Integral is not defined.")
    elseif quantity == :quantum_metric_quadrupole && calculation == :kslice
        error(
            "Unsupported combination: Quantum_Metric_Quadrupole + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :quantum_metric_quadrupole && calculation == :integral
        error("Unsupported combination: Quantum_Metric_Quadrupole + Integral is not defined.")
    elseif quantity == :quantum_christoffel_symbol && calculation == :kslice
        error(
            "Unsupported combination: Quantum_Christoffel_Symbol + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :quantum_christoffel_symbol && calculation == :integral
        error("Unsupported combination: Quantum_Christoffel_Symbol + Integral is not defined.")
    elseif quantity == :triple_phase_product && calculation == :kslice
        error(
            "Unsupported combination: Triple_Phase_Product + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :triple_phase_product && calculation == :integral
        error("Unsupported combination: Triple_Phase_Product + Integral is not defined.")
    elseif quantity == :photon_drag_shift_current && calculation == :integral
        error(
            "Unsupported combination: Photon_Drag_Shift_Current + Integral currently supports only method=\"Geometric_Loop\".",
        )
    elseif quantity == :photon_drag_shift_current && calculation == :kslice
        error(
            "Unsupported combination: Photon_Drag_Shift_Current + K-slice currently supports only method=\"Geometric_Loop\".",
        )
    elseif quantity == :shift_vector && calculation == :kslice
        error(
            "Unsupported combination: Shift_Vector + K-slice currently supports only method=\"Geometric_Loop\" or method=\"Wilson_Loop\".",
        )
    elseif quantity == :shift_vector && calculation == :integral
        error("Unsupported combination: Shift_Vector + Integral is not defined.")
    elseif quantity == :injection_current && calculation == :integral
        error(
            "Unsupported combination: Injection_Current + Integral currently supports only method=\"Conventional\".",
        )
    elseif quantity == :injection_current && calculation == :kslice
        error(
            "Unsupported combination: Injection_Current + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :injection_spin_current && calculation == :integral
        error(
            "Unsupported combination: Injection_Spin_Current + Integral currently supports only method=\"Conventional\".",
        )
    elseif quantity == :injection_spin_current && calculation == :kslice
        error(
            "Unsupported combination: Injection_Spin_Current + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :shift_spin_current && calculation == :integral
        error(
            "Unsupported combination: Shift_Spin_Current + Integral currently supports only method=\"Conventional\".",
        )
    elseif quantity == :shift_spin_current && calculation == :kslice
        error(
            "Unsupported combination: Shift_Spin_Current + K-slice currently supports only method=\"Conventional\".",
        )
    elseif quantity == :photon_drag_injection_current && calculation == :integral
        error(
            "Unsupported combination: Photon_Drag_Injection_Current + Integral currently supports only method=\"Conventional\".",
        )
    elseif quantity == :photon_drag_injection_current && calculation == :kslice
        error(
            "Unsupported combination: Photon_Drag_Injection_Current + K-slice currently supports only method=\"Conventional\".",
        )
    end
    error(
        "Unsupported method/task combination: quantity=$(quantity), method=$(method), calculation=$(calculation).",
    )
end

"""
Emit a notice through active progress reporting, otherwise print it only on the MPI root process.
"""
function runtime_notice(message::AbstractString)
    if isdefined(@__MODULE__, :progress_notice!) && progress_notice!(message)
        return nothing
    end
    if !isdefined(@__MODULE__, :mpi_is_root_process) || mpi_is_root_process()
        println("[WannierNLQG] ", message)
        flush(stdout)
    end
    return nothing
end

"""
Test whether any configured photon-momentum component is nonzero for finite-q task validation.
"""
nonzero_photon_momentum(q) = any(x -> abs(x) > 0.0, q)
