"""Worker-owned raw and Hamiltonian-frame H/A channels for one central k point.

There is no eigensolver, model cache, FFT provider or k-offset cache here. The
existing matrix worker owns those mechanisms. Preparation always invalidates the
old channels before borrowing its current spectrum, so equal dimensions cannot
accidentally reuse data from a different model or generation.
"""
mutable struct OrthogonalGeometryJets
    plan::OrthogonalGeometryDerivativePlan
    hamiltonian::Array{ComplexF64, 3}
    position::Array{ComplexF64, 3}
    raw::Matrix{ComplexF64}
    temporary::Matrix{ComplexF64}
    prepared::Bool
    generation::UInt64
    source_generation::UInt64
end

"""Checked storage for the physical jet/recurrence arrays, excluding native/AD temporaries.

This is a shape estimate, not an RSS reservation or a promise about compiler,
callback, BLAS or object-header storage. Runtime keeps its independent RSS guard.
"""
function orthogonal_geometry_storage_bytes(n::Int, plan::OrthogonalGeometryDerivativePlan)
    n > 0 || throw(ArgumentError("positive orbital count required"))
    return WorkspacePlanning.checked_sum_bytes((
        WorkspacePlanning.checked_array_bytes(ComplexF64, (n, n, length(plan.hamiltonian_orders))),
        WorkspacePlanning.checked_array_bytes(ComplexF64, (n, n, length(plan.position_orders))),
        WorkspacePlanning.checked_array_bytes(ComplexF64, (n, n, 42)),
        WorkspacePlanning.checked_array_bytes(Float64, (n, 13)),
    ))
end

# Allocate only the Hamiltonian and position derivative channels requested by the supplied geometry plan.
function OrthogonalGeometryJets(num_orbitals::Integer, plan::OrthogonalGeometryDerivativePlan)
    num_orbitals > 0 || throw(ArgumentError("positive orbital count required"))
    n = Int(num_orbitals)
    return OrthogonalGeometryJets(
        plan,
        zeros(ComplexF64, n, n, length(plan.hamiltonian_orders)),
        zeros(ComplexF64, n, n, length(plan.position_orders)),
        zeros(ComplexF64, n, n),
        zeros(ComplexF64, n, n),
        false,
        0,
        0,
    )
end

"""Find a requested channel, rejecting undeclared derivative consumption."""
function geometry_hamiltonian_channel(jets::OrthogonalGeometryJets, order::NTuple{3, Int})
    jets.prepared || throw(ArgumentError("geometry jets are not prepared"))
    channel = findfirst(==(order), jets.plan.hamiltonian_orders)
    channel === nothing && throw(ArgumentError("unrequested H derivative $order"))
    return view(jets.hamiltonian,:,:,channel)
end

# Return the prepared position derivative channel and reject an order absent from the plan.
function geometry_position_channel(
    jets::OrthogonalGeometryJets,
    component::Int,
    order::NTuple{3, Int},
)
    jets.prepared || throw(ArgumentError("geometry jets are not prepared"))
    channel = findfirst(==((component, order)), jets.plan.position_orders)
    channel === nothing && throw(ArgumentError("unrequested A derivative ($component,$order)"))
    return view(jets.position,:,:,channel)
end

"""Direct TB derivative in the existing worker's actual center convention.

Use precisely its weighted R factors, R order, center subtraction and similarity.
In particular the row-lattice Cartesian displacement is supplied by the existing
helper; the donor's lattice multiplication and adjoint convention are not copied.
"""
function _geometry_raw_channel!(
    target,
    worker::MatrixElementWorkspace,
    model::TightBindingModel,
    component::Int,
    order::NTuple{3, Int},
)
    fill!(target, 0)
    scratch, plan = worker.scratch, worker.plan
    for r in 1:model.num_r_vectors
        cartesian = _r_vector_cartesian(model, r)
        phase = worker.data.fourier_factors[r]
        for column in 1:model.num_orbitals, row in 1:model.num_orbitals
            factor = phase
            for axis in 1:3
                displacement =
                    _convention_displacement_component(cartesian, axis, row, column, scratch, plan)
                factor *= (im * displacement)^order[axis]
            end
            value =
                component == 0 ? model.hamiltonian_r[row, column, r] :
                _convention_position_value(
                    model.position_r[row, column, component, r],
                    component,
                    row,
                    column,
                    r,
                    scratch,
                    plan,
                )
            target[row, column] += factor * value
        end
    end
    _apply_wannier_center_similarity!(target, scratch, plan)
    return target
end

"""Extract one ordered derivative tensor channel using its Cartesian multi-index."""
@inline function _geometry_tensor_channel(tensor, component, order)
    axes = Tuple(axis for axis in 1:3 for _ in 1:order[axis])
    return component == 0 ? view(tensor,:,:,(axes...)) : view(tensor,:,:,component,(axes...))
end

"""Analytic raw-operator product rule, including all center-phase derivatives."""
function _geometry_raw_channel!(
    target,
    worker::MatrixElementWorkspace,
    model::AnalyticKModel,
    component::Int,
    order::NTuple{3, Int},
)
    input, plan = model.input, worker.plan
    k = transpose(reciprocal_lattice(model.lattice)) * worker.data.kpoint
    fill!(target, 0)
    centered = plan.wannier_center_convention == CONVENTION_I
    # Product rule for exp(i*k*(tau_right-tau_left)) X(k).  Derivatives
    # of the declared basis connection itself remain raw-operator derivatives.
    for x in 0:order[1], y in 0:order[2], z in 0:order[3]
        lower = (x, y, z)
        !centered && lower != order && continue
        derivative_order = sum(lower)
        tensor = if component == 0
            geometry_hamiltonian_derivative_source(input, derivative_order)
            analytic_hamiltonian_derivative(
                input,
                k,
                derivative_order;
                diagnostics = model.evaluation_diagnostics,
            )
        else
            geometry_position_derivative(input, k, derivative_order)
        end
        matrix = _geometry_tensor_channel(tensor, component, lower)
        multiplicity = prod(binomial(order[axis], lower[axis]) for axis in 1:3)
        for column in axes(target, 2), row in axes(target, 1)
            value = matrix[row, column]
            if component != 0 && centered && derivative_order == 0 && row == column
                value -= input.orbital_positions[component, row]
            end
            factor = ComplexF64(multiplicity)
            if centered
                for axis in 1:3
                    displacement =
                        input.orbital_positions[axis, column] - input.orbital_positions[axis, row]
                    factor *= (im * displacement)^(order[axis] - lower[axis])
                end
            end
            target[row, column] += factor * value
        end
    end
    _apply_wannier_center_similarity!(target, worker.scratch, plan)
    return target
end

"""Prepare channels against the worker's already computed central spectrum.

The caller must admit Direct execution before this port. No implicit Mixed or
nonorthogonal fallback exists. This function owns no borrowed result arrays;
each channel is copied through the worker's established U' X U rotation.
"""
function prepare_orthogonal_geometry_jets!(
    jets::OrthogonalGeometryJets,
    worker::MatrixElementWorkspace,
    model::Union{TightBindingModel, AnalyticKModel},
)
    jets.prepared = false
    _has_capability(worker.data.computed_mask, SPECTRUM) ||
        throw(ArgumentError("geometry jets require the current computed spectrum"))
    size(jets.raw) == size(worker.data.spectrum.eigenvectors) ||
        throw(DimensionMismatch("geometry jet / spectrum shape"))
    _prepare_wannier_center_phases!(worker.scratch, model, worker.plan, worker.data.kpoint)
    for (channel, order) in enumerate(jets.plan.hamiltonian_orders)
        _geometry_raw_channel!(jets.raw, worker, model, 0, order)
        all(isfinite, jets.raw) || throw(ArgumentError("nonfinite H geometry jet $order"))
        isapprox(jets.raw, jets.raw'; atol = 1e-10, rtol = 1e-10) ||
            throw(ArgumentError("non-Hermitian H geometry jet $order"))
        transform_to_hamiltonian_gauge!(
            view(jets.hamiltonian,:,:,channel),
            worker.data.spectrum,
            jets.raw,
            jets.temporary,
        )
    end
    for (channel, (component, order)) in enumerate(jets.plan.position_orders)
        _geometry_raw_channel!(jets.raw, worker, model, component, order)
        all(isfinite, jets.raw) ||
            throw(ArgumentError("nonfinite A geometry jet ($component,$order)"))
        isapprox(jets.raw, jets.raw'; atol = 1e-10, rtol = 1e-10) ||
            throw(ArgumentError("non-Hermitian A geometry jet ($component,$order)"))
        transform_to_hamiltonian_gauge!(
            view(jets.position,:,:,channel),
            worker.data.spectrum,
            jets.raw,
            jets.temporary,
        )
    end
    jets.generation += UInt64(1)
    jets.source_generation = worker.data.generation
    jets.prepared = true
    return jets
end
