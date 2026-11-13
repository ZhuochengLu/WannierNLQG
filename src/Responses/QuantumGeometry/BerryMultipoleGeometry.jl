"""One worker's actually consumed local geometry, with no occupations or BZ weights."""
mutable struct BerryMultipoleGeometryWorkspace{L, W, P}
    conventional::W
    tensor_plan::P
    local_components::Vector{NTuple{L, Int}}
    component_indices::Vector{Vector{Int}}
    local_values::Matrix{Float64}
    energies::Vector{Float64}
    energy_gradient::Union{Nothing, Matrix{Float64}}
    gradient_axes::Vector{Int}
    band_targets::Vector{Vector{Int}}
    finite_difference_vectors::Matrix{Float64}
    derivative_order::Int
    derivative_backend::Symbol
    minimum_gap_ev::Float64
end

# Choose the analytic or finite-difference geometry adapter for the requested tensor order and surface form.
function make_berry_multipole_geometry(
    worker::MatrixElementWorkspace,
    batch,
    plan::BerryMultipoleTensorPlan{N},
    order::Int;
    surface::Bool,
    derivative_backend::Symbol,
    finite_difference_vectors::Matrix{Float64},
    gap_tolerance::Float64,
) where {N}
    n = length(worker.data.spectrum.energies)
    conventional = make_conventional_quantum_geometry_workspace(
        n,
        length(worker.data.fourier_factors),
        3,
        0;
        matrix_elements = worker,
        central_data = worker.data,
        matrix_batch = batch,
    )
    derivative_backend == :finite_difference &&
        (conventional.isolation_threshold_ev = gap_tolerance)
    components = berry_multipole_local_components(plan, order)
    gradient_axes =
        surface ? unique(Int[c[axis] for c in plan.moment_components for axis in 3:N]) : Int[]
    return BerryMultipoleGeometryWorkspace(
        conventional,
        plan,
        components,
        [collect(c) for c in components],
        fill(NaN, n, length(components)),
        zeros(n),
        surface ? fill(NaN, n, 3) : nothing,
        gradient_axes,
        [[n] for n in 1:n],
        finite_difference_vectors,
        order,
        derivative_backend,
        Inf,
    )
end

"""Evaluate the requested local channels on the shared central spectrum.

The analytic path has no shifted evaluation. The compatibility path reuses the
existing finite-difference kernels and offset cache, adding the new transport
task's explicit singleton-domain check at every consumed shifted spectrum.
"""
function prepare_berry_multipole_geometry!(
    workspace::BerryMultipoleGeometryWorkspace,
    model::AbstractResponseModel,
    kpoint::Vector{Float64};
    denominator_regularization::Float64,
    gap_tolerance::Float64,
    finite_difference_step::Float64,
)
    model isa Union{TightBindingModel, AnalyticKModel} ||
        throw(ArgumentError("orthogonal BCD/BCQ model required"))
    conventional = workspace.conventional
    _bind_conventional_offset!(conventional, KPointOffset())
    worker = conventional.scratch
    spectrum = compute_spectrum!(worker, model, kpoint)
    gap = MatrixElements.geometry_isolated_spectrum_minimum_gap(spectrum.energies, gap_tolerance)
    compute_remaining!(worker, model)
    conventional.data = worker.data
    copyto!(workspace.energies, spectrum.energies)
    workspace.minimum_gap_ev = min(workspace.minimum_gap_ev, gap)
    if workspace.energy_gradient !== nothing
        fill!(workspace.energy_gradient, NaN)
        for axis in workspace.gradient_axes, band in eachindex(workspace.energies)
            workspace.energy_gradient[band, axis] =
                real(conventional.data.hamiltonian_derivatives[band, band, axis])
        end
    end
    derivatives = conventional.analytic_geometry
    if workspace.derivative_order > 0 && workspace.derivative_backend == :analytic
        derivatives === nothing &&
            throw(ArgumentError("analytic transport derivative channels were not planned"))
        MatrixElements.prepare_orthogonal_geometry_jets!(derivatives.jets, worker, model)
        MatrixElements.prepare_orthogonal_band_derivatives!(derivatives, spectrum; gap_tolerance)
    end
    fill!(workspace.local_values, NaN)
    for channel in eachindex(workspace.local_components)
        component = workspace.local_components[channel]
        indices = workspace.component_indices[channel]
        if workspace.derivative_order == 0
            for band in eachindex(workspace.energies)
                workspace.local_values[band, channel] = real(
                    berry_curvature_component(
                        conventional.data,
                        band,
                        indices,
                        length(workspace.energies),
                    ),
                )
            end
        elseif workspace.derivative_backend == :analytic
            partitions =
                workspace.derivative_order == 1 ?
                orthogonal_bcd_partition_matrices!(derivatives, component) :
                orthogonal_bcq_partition_matrices!(derivatives, component)
            for band in eachindex(workspace.energies)
                workspace.local_values[band, channel] =
                    orthogonal_geometry_partition_diagonal(partitions, band).total
            end
        elseif workspace.derivative_backend == :finite_difference
            for band in eachindex(workspace.energies)
                workspace.local_values[band, channel] =
                    workspace.derivative_order == 1 ?
                    berry_curvature_dipole_component!(
                        conventional,
                        model,
                        kpoint,
                        workspace.finite_difference_vectors,
                        workspace.band_targets[band],
                        indices,
                        finite_difference_step,
                        denominator_regularization,
                        length(workspace.energies),
                        3,
                    ) :
                    berry_curvature_quadrupole_component!(
                        conventional,
                        model,
                        kpoint,
                        workspace.finite_difference_vectors,
                        workspace.band_targets[band],
                        indices,
                        finite_difference_step,
                        denominator_regularization,
                        length(workspace.energies),
                        3,
                    )
            end
        else
            throw(ArgumentError("a local derivative backend is required by this expression"))
        end
    end
    workspace.minimum_gap_ev = min(workspace.minimum_gap_ev, conventional.minimum_isolated_gap_ev)
    all(isfinite, workspace.local_values) ||
        throw(ArgumentError("nonfinite consumed BCD/BCQ geometry"))
    return workspace
end

"""Compact moment integrand; only selected channels are computed and returned."""
function berry_multipole_moments!(
    output::Matrix{Float64},
    workspace::BerryMultipoleGeometryWorkspace,
    fermi_energies,
    parameters::BerryMultipoleDCParameters,
)
    plan = workspace.tensor_plan
    size(output) == (length(fermi_energies), length(plan.moment_components)) ||
        throw(DimensionMismatch("compact BCD/BCQ moments"))
    fill!(output, 0)
    for (channel, key) in enumerate(plan.moment_components)
        a, b, c = key[1:3]
        local_keys = if workspace.derivative_order == 0
            ((a, b),)
        elseif length(key) == 4 && workspace.derivative_order == 1
            ((a, b, c), (a, b, key[4]))
        else
            (key,)
        end
        indices = map(local_keys) do component
            index = findfirst(==(component), workspace.local_components)
            index === nothing &&
                throw(ArgumentError("moment consumes an unplanned geometry channel $component"))
            index
        end
        for mu in eachindex(fermi_energies), band in eachindex(workspace.energies)
            weight =
                parameters.integral_form == :fermi_surface ?
                berry_multipole_surface_weight(
                    parameters,
                    workspace.energies[band],
                    fermi_energies[mu],
                ) :
                berry_multipole_sea_weight(parameters, workspace.energies[band], fermi_energies[mu])
            value = if parameters.integral_form == :fermi_sea
                workspace.local_values[band, only(indices)]
            elseif workspace.derivative_order == 0
                workspace.local_values[band, only(indices)] * workspace.energy_gradient[band, c]
            else
                d = key[4]
                berry_quadrupole_surface_estimator(
                    workspace.energy_gradient[band, c],
                    workspace.energy_gradient[band, d],
                    workspace.local_values[band, indices[1]],
                    workspace.local_values[band, indices[2]],
                )
            end
            output[mu, channel] += weight * value
        end
    end
    all(isfinite, output) || throw(ArgumentError("nonfinite BCD/BCQ moment integrand"))
    return output
end
