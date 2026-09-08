# Bind the geometry workspace to its offset-cache slot, or retain current data when no batch cache exists.
function _bind_conventional_offset!(
    workspace::ConventionalQuantumGeometryWorkspace,
    offset::KPointOffset,
)
    workspace.matrix_batch === nothing && return workspace.data
    workspace.data = matrix_data!(workspace.matrix_batch, offset)
    return workspace.data
end

# Evaluate the external-band metric trace at a shifted point after binding its matrix-cache slot.
function _quantum_christoffel_metric_at!(
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::TightBindingModel,
    kpoint::Vector{Float64},
    denominator_regularization::Float64,
    spatial_dimension::Int64,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    num_orbitals::Int64,
    offset::KPointOffset,
)
    _bind_conventional_offset!(ws, offset)
    compute_kpoint!(
        ws.data,
        ws.scratch,
        conventional_model,
        kpoint;
        denominator_regularization = denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    return real(
        interband_quantum_metric_group_sum_component(
            ws.data,
            band_group,
            tensor_indices,
            num_orbitals,
        ),
    )
end

# Evaluate the target-subspace Berry curvature at a shifted point after binding its matrix-cache slot.
function _berry_curvature_dipole_curvature_at!(
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::TightBindingModel,
    kpoint::Vector{Float64},
    denominator_regularization::Float64,
    spatial_dimension::Int64,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    num_orbitals::Int64,
    offset::KPointOffset,
)
    _bind_conventional_offset!(ws, offset)
    compute_kpoint!(
        ws.data,
        ws.scratch,
        conventional_model,
        kpoint;
        denominator_regularization = denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    return real(
        berry_curvature_group_sum_component(ws.data, band_group, tensor_indices, num_orbitals),
    )
end

"""
Return `Gamma_{r;lj}=(partial_j g_lr + partial_l g_rj - partial_r g_lj)/2` using centered Cartesian differences of the target-subspace metric.

`tensor_indices=(r,l,j)`; fractional displacement columns correspond to the supplied Cartesian step. Reuse shifted matrix slots and restore the central binding; no occupation or k-point weights are included.
"""
function quantum_christoffel_symbol_component!(
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::TightBindingModel,
    kpoint::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    finite_difference_step::Float64,
    denominator_regularization::Float64,
    num_orbitals::Int64,
    spatial_dimension::Int64,
)
    r, l, j = tensor_indices
    derivative_cache = Dict{Tuple{Int, Int, Int}, Float64}()

    function metric_derivative(a::Int, b::Int, direction::Int)
        key = (a, b, direction)
        cached = get(derivative_cache, key, nothing)
        cached === nothing || return cached

        k_plus = kpoint .+ finite_difference_vectors[:, direction]
        plus = _quantum_christoffel_metric_at!(
            ws,
            conventional_model,
            k_plus,
            denominator_regularization,
            spatial_dimension,
            band_group,
            Int[a, b],
            num_orbitals,
            KPointOffset(ntuple(axis -> axis == direction ? 1 : 0, 3), 0),
        )
        k_minus = kpoint .- finite_difference_vectors[:, direction]
        minus = _quantum_christoffel_metric_at!(
            ws,
            conventional_model,
            k_minus,
            denominator_regularization,
            spatial_dimension,
            band_group,
            Int[a, b],
            num_orbitals,
            KPointOffset(ntuple(axis -> axis == direction ? -1 : 0, 3), 0),
        )
        value = (plus - minus) / (2.0 * finite_difference_step)
        derivative_cache[key] = value
        return value
    end

    value =
        0.5 * (metric_derivative(l, r, j) + metric_derivative(r, j, l) - metric_derivative(l, j, r))
    _bind_conventional_offset!(ws, KPointOffset())
    return ComplexF64(value, 0.0)
end

"""
Return the centered Cartesian derivative `partial_c g_ab` of the target-subspace metric.

`tensor_indices=(a,b,c)`; fractional displacement columns and Cartesian step must agree. Reuse shifted matrix storage and restore the central slot; no occupation factors are applied.
"""
function quantum_metric_dipole_component!(
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::TightBindingModel,
    kpoint::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    finite_difference_step::Float64,
    denominator_regularization::Float64,
    num_orbitals::Int64,
    spatial_dimension::Int64,
)
    a, b, c = tensor_indices
    plus = _quantum_christoffel_metric_at!(
        ws,
        conventional_model,
        kpoint .+ finite_difference_vectors[:, c],
        denominator_regularization,
        spatial_dimension,
        band_group,
        Int[a, b],
        num_orbitals,
        KPointOffset(ntuple(axis -> axis == c ? 1 : 0, 3), 0),
    )
    minus = _quantum_christoffel_metric_at!(
        ws,
        conventional_model,
        kpoint .- finite_difference_vectors[:, c],
        denominator_regularization,
        spatial_dimension,
        band_group,
        Int[a, b],
        num_orbitals,
        KPointOffset(ntuple(axis -> axis == c ? -1 : 0, 3), 0),
    )
    _bind_conventional_offset!(ws, KPointOffset())
    return ComplexF64((plus - minus) / (2.0 * finite_difference_step), 0.0)
end

"""
Return the centered Cartesian derivative `partial_c Omega_ab` of the target-subspace curvature.

Use `(a,b,c)` axes and a positive step matching the fractional displacement vectors; reuse shifted matrix slots and restore the central binding without occupation factors.
"""
function berry_curvature_dipole_component!(
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::TightBindingModel,
    kpoint::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    finite_difference_step::Float64,
    denominator_regularization::Float64,
    num_orbitals::Int64,
    spatial_dimension::Int64,
)
    a, b, c = tensor_indices
    plus = _berry_curvature_dipole_curvature_at!(
        ws,
        conventional_model,
        kpoint .+ finite_difference_vectors[:, c],
        denominator_regularization,
        spatial_dimension,
        band_group,
        Int[a, b],
        num_orbitals,
        KPointOffset(ntuple(axis -> axis == c ? 1 : 0, 3), 0),
    )
    minus = _berry_curvature_dipole_curvature_at!(
        ws,
        conventional_model,
        kpoint .- finite_difference_vectors[:, c],
        denominator_regularization,
        spatial_dimension,
        band_group,
        Int[a, b],
        num_orbitals,
        KPointOffset(ntuple(axis -> axis == c ? -1 : 0, 3), 0),
    )
    _bind_conventional_offset!(ws, KPointOffset())
    return ComplexF64((plus - minus) / (2.0 * finite_difference_step), 0.0)
end

"""
Return `partial_c partial_d g_ab` using central second differences for equal axes or a four-corner stencil for distinct axes.

Cartesian step and fractional displacement columns must agree. Mutate reusable shifted-point storage and restore the central binding; no occupation or k-space weights are added.
"""
function quantum_metric_quadrupole_component!(
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::TightBindingModel,
    kpoint::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    finite_difference_step::Float64,
    denominator_regularization::Float64,
    num_orbitals::Int64,
    spatial_dimension::Int64,
)
    a, b, c, d = tensor_indices
    if c == d
        plus = _quantum_christoffel_metric_at!(
            ws,
            conventional_model,
            kpoint .+ finite_difference_vectors[:, c],
            denominator_regularization,
            spatial_dimension,
            band_group,
            Int[a, b],
            num_orbitals,
            KPointOffset(ntuple(axis -> axis == c ? 1 : 0, 3), 0),
        )
        center = _quantum_christoffel_metric_at!(
            ws,
            conventional_model,
            kpoint,
            denominator_regularization,
            spatial_dimension,
            band_group,
            Int[a, b],
            num_orbitals,
            KPointOffset(),
        )
        minus = _quantum_christoffel_metric_at!(
            ws,
            conventional_model,
            kpoint .- finite_difference_vectors[:, c],
            denominator_regularization,
            spatial_dimension,
            band_group,
            Int[a, b],
            num_orbitals,
            KPointOffset(ntuple(axis -> axis == c ? -1 : 0, 3), 0),
        )
        _bind_conventional_offset!(ws, KPointOffset())
        return ComplexF64((plus - 2.0 * center + minus) / (finite_difference_step^2), 0.0)
    end

    pp = _quantum_christoffel_metric_at!(
        ws,
        conventional_model,
        kpoint .+ finite_difference_vectors[:, c] .+ finite_difference_vectors[:, d],
        denominator_regularization,
        spatial_dimension,
        band_group,
        Int[a, b],
        num_orbitals,
        KPointOffset(ntuple(axis -> (axis == c) + (axis == d), 3), 0),
    )
    pm = _quantum_christoffel_metric_at!(
        ws,
        conventional_model,
        kpoint .+ finite_difference_vectors[:, c] .- finite_difference_vectors[:, d],
        denominator_regularization,
        spatial_dimension,
        band_group,
        Int[a, b],
        num_orbitals,
        KPointOffset(ntuple(axis -> (axis == c) - (axis == d), 3), 0),
    )
    mp = _quantum_christoffel_metric_at!(
        ws,
        conventional_model,
        kpoint .- finite_difference_vectors[:, c] .+ finite_difference_vectors[:, d],
        denominator_regularization,
        spatial_dimension,
        band_group,
        Int[a, b],
        num_orbitals,
        KPointOffset(ntuple(axis -> -(axis == c) + (axis == d), 3), 0),
    )
    mm = _quantum_christoffel_metric_at!(
        ws,
        conventional_model,
        kpoint .- finite_difference_vectors[:, c] .- finite_difference_vectors[:, d],
        denominator_regularization,
        spatial_dimension,
        band_group,
        Int[a, b],
        num_orbitals,
        KPointOffset(ntuple(axis -> -(axis == c) - (axis == d), 3), 0),
    )
    _bind_conventional_offset!(ws, KPointOffset())
    return ComplexF64((pp - pm - mp + mm) / (4.0 * finite_difference_step^2), 0.0)
end

"""
Return `partial_c partial_d Omega_ab` with a central three-point or mixed four-corner stencil.

Tensor order is `(a,b,c,d)` and the Cartesian step must match the fractional displacements. Reuse shifted-point buffers and restore the central binding without occupation weights.
"""
function berry_curvature_quadrupole_component!(
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::TightBindingModel,
    kpoint::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    finite_difference_step::Float64,
    denominator_regularization::Float64,
    num_orbitals::Int64,
    spatial_dimension::Int64,
)
    a, b, c, d = tensor_indices
    if c == d
        plus = _berry_curvature_dipole_curvature_at!(
            ws,
            conventional_model,
            kpoint .+ finite_difference_vectors[:, c],
            denominator_regularization,
            spatial_dimension,
            band_group,
            Int[a, b],
            num_orbitals,
            KPointOffset(ntuple(axis -> axis == c ? 1 : 0, 3), 0),
        )
        center = _berry_curvature_dipole_curvature_at!(
            ws,
            conventional_model,
            kpoint,
            denominator_regularization,
            spatial_dimension,
            band_group,
            Int[a, b],
            num_orbitals,
            KPointOffset(),
        )
        minus = _berry_curvature_dipole_curvature_at!(
            ws,
            conventional_model,
            kpoint .- finite_difference_vectors[:, c],
            denominator_regularization,
            spatial_dimension,
            band_group,
            Int[a, b],
            num_orbitals,
            KPointOffset(ntuple(axis -> axis == c ? -1 : 0, 3), 0),
        )
        _bind_conventional_offset!(ws, KPointOffset())
        return ComplexF64((plus - 2.0 * center + minus) / (finite_difference_step^2), 0.0)
    end

    pp = _berry_curvature_dipole_curvature_at!(
        ws,
        conventional_model,
        kpoint .+ finite_difference_vectors[:, c] .+ finite_difference_vectors[:, d],
        denominator_regularization,
        spatial_dimension,
        band_group,
        Int[a, b],
        num_orbitals,
        KPointOffset(ntuple(axis -> (axis == c) + (axis == d), 3), 0),
    )
    pm = _berry_curvature_dipole_curvature_at!(
        ws,
        conventional_model,
        kpoint .+ finite_difference_vectors[:, c] .- finite_difference_vectors[:, d],
        denominator_regularization,
        spatial_dimension,
        band_group,
        Int[a, b],
        num_orbitals,
        KPointOffset(ntuple(axis -> (axis == c) - (axis == d), 3), 0),
    )
    mp = _berry_curvature_dipole_curvature_at!(
        ws,
        conventional_model,
        kpoint .- finite_difference_vectors[:, c] .+ finite_difference_vectors[:, d],
        denominator_regularization,
        spatial_dimension,
        band_group,
        Int[a, b],
        num_orbitals,
        KPointOffset(ntuple(axis -> -(axis == c) + (axis == d), 3), 0),
    )
    mm = _berry_curvature_dipole_curvature_at!(
        ws,
        conventional_model,
        kpoint .- finite_difference_vectors[:, c] .- finite_difference_vectors[:, d],
        denominator_regularization,
        spatial_dimension,
        band_group,
        Int[a, b],
        num_orbitals,
        KPointOffset(ntuple(axis -> -(axis == c) - (axis == d), 3), 0),
    )
    _bind_conventional_offset!(ws, KPointOffset())
    return ComplexF64((pp - pm - mp + mm) / (4.0 * finite_difference_step^2), 0.0)
end

"""
Average the ordered cyclic Berry-connection product over triples from the three selected band groups.

For Cartesian indices `(alpha,beta,gamma)`, average `A[ib,ia,alpha]*A[ic,ib,beta]*A[ia,ic,gamma]`. Reject repeated band indices and an empty product set. Hamiltonian-gauge connections supply the length factors; occupation and k-point weights are not applied.
"""
@inline function triple_phase_product_component(
    data::KPointMatrixData,
    band_selection::Tuple{Vector{Int}, Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
)
    alpha, beta, gamma = tensor_indices
    first_group, second_group, third_group = band_selection
    total = COMPLEX_ZERO
    count = 0
    @inbounds for ia in first_group
        for ib in second_group
            for ic in third_group
                if ia == ib || ib == ic || ia == ic
                    error(
                        "Invalid Triple_Phase_Product band_selection=$(band_selection); each band triple must contain three distinct indices.",
                    )
                end
                total +=
                    data.berry_connection[ib, ia, alpha] *
                    data.berry_connection[ic, ib, beta] *
                    data.berry_connection[ia, ic, gamma]
                count += 1
            end
        end
    end
    count > 0 || error(
        "Invalid Triple_Phase_Product band_selection=$(band_selection); band groups must produce at least one triple.",
    )
    return total / count
end
