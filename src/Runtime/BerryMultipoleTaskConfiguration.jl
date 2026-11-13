"""Defaults depend on the selected expression; no meaningless backend is inserted for BCD FS."""
function berry_multipole_numerical_defaults(task, quantity)
    form = hasproperty(task, :physics) ? task.physics.integral_form : :fermi_surface
    order = berry_multipole_derivative_order(quantity, form)
    request = something(task.numerics, Numerics())
    positive =
        get(request.values, :denominator_regularization, 0.0) isa Real &&
        get(request.values, :denominator_regularization, 0.0) > 0
    positive &&
        get(request.values, :derivative_backend, :finite_difference) == :analytic &&
        throw(ArgumentError("positive denominator_regularization conflicts with analytic geometry"))
    backend =
        order == 0 ? :not_applicable :
        get(request.values, :derivative_backend, positive ? :finite_difference : :analytic)
    base = (; denominator_regularization = 0.0, degeneracy_threshold = 0.002)
    order > 0 &&
        (base = merge(base, (; derivative_backend = backend, finite_difference_step = nothing)))
    form == :fermi_surface && (base = merge(base, (; fs_kind = :gaussian, eta_fs_ev = nothing)))
    return base
end

# Validate multipole physics and return owned chemical-potential values with the existing static-axis metadata.
function berry_multipole_task_physics(task)
    physics = task.physics
    physics isa BerryMultipoleParameters ||
        throw(ArgumentError("BCD/BCQ conductivity requires BerryMultipoleParameters"))
    return (;
        fermi_energies = copy(physics.fermi_energies),
        fermi_energy = first(physics.fermi_energies),
        temperature = physics.temperature,
        photon_energies = Float64[],
    )
end

# Expand default Cartesian conductivity components or preserve the explicitly requested component order.
function berry_multipole_tensor_plan(settings::BerryMultipoleSettings{N}) where {N}
    components = NTuple{N, Int}[]
    if isempty(settings.components)
        for index in CartesianIndices(ntuple(_ -> 3, N))
            push!(components, Tuple(index))
        end
    else
        append!(components, settings.components)
    end
    return Responses.BerryMultipoleTensorPlan(components)
end

# Request analytic local geometry channels only when the configured multipole order requires them.
function berry_multipole_geometry_components(cfg)
    settings = something(cfg.berry_multipole)
    settings.local_derivative_order == 0 && return ()
    cfg.derivative_backend == :analytic || return ()
    plan = berry_multipole_tensor_plan(settings)
    return Responses.berry_multipole_local_components(plan, settings.local_derivative_order)
end

"""Resolve physical versus numerical applicability before creating output or evaluating callbacks."""
function berry_multipole_task_numerics(task, quantity; nonorthogonal::Bool)
    nonorthogonal && throw(
        ArgumentError(
            "BCD/BCQ conductivity first scope requires an orthogonal model; existing nonorthogonal tasks are unchanged",
        ),
    )
    physics = task.physics::BerryMultipoleParameters
    request = something(task.numerics, Numerics())
    values = resolved_numerical_values(task, quantity; nonorthogonal)
    order = berry_multipole_derivative_order(quantity, physics.integral_form)
    backend = order == 0 ? :not_applicable : values.derivative_backend
    backend in (:analytic, :finite_difference, :not_applicable) ||
        throw(ArgumentError("invalid derivative_backend"))
    if backend != :finite_difference
        :finite_difference_step in request.supplied && throw(
            ArgumentError(
                "finite_difference_step does not apply to this BCD/BCQ expression/backend",
            ),
        )
        values.denominator_regularization == 0 || throw(
            ArgumentError("analytic BCD/BCQ geometry requires zero denominator_regularization"),
        )
    end
    parameters = Responses.BerryMultipoleDCParameters(
        integral_form = physics.integral_form,
        relaxation_time_fs = physics.relaxation_time_fs,
        temperature_k = physics.temperature,
        fs_kind = get(values, :fs_kind, :gaussian),
        eta_fs_ev = get(values, :eta_fs_ev, nothing),
    )
    rank = quantity == :berry_curvature_dipole_conductivity ? 3 : 4
    components =
        task.observable isa TensorComponents ? task.observable.components :
        task.observable isa KSliceSelection ? (task.observable.component.indices,) : ()
    settings = BerryMultipoleSettings{rank}(parameters, components, order)
    return (;
        berry_multipole = settings,
        derivative_backend = backend,
        denominator_regularization = Float64(values.denominator_regularization),
        degeneracy_threshold = Float64(values.degeneracy_threshold),
        finite_difference_step = Float64(
            something(get(values, :finite_difference_step, nothing), 0.0001),
        ),
        fs_kind = physics.temperature > 0 ? :none : get(values, :fs_kind, :none),
        eta_fs_ev = Float64(something(get(values, :eta_fs_ev, nothing), 0.0)),
    )
end
