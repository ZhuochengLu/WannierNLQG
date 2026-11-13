"""Return embedding references; a fixed orthonormal basis has inactive center-phase zeros.

The latter are workspace coordinates, not orbital positions. The input retains
`orbital_positions=nothing`, and runtime provenance records that absence.
"""
extract_wannier_centers(
    model::AnalyticKModel,
)=model.input.orbital_positions === nothing ? zeros(3, model.num_orbitals) :
  copy(model.input.orbital_positions)

"""Initialize only center data for a direct analytic model; no R buffers are populated."""
function _initialize_wannier_center_scratch!(
    scratch::MatrixElementScratch,
    model::AnalyticKModel,
    plan::MatrixElementPlan,
)
    scratch.centers_initialized && return scratch
    scratch.wannier_centers_cartesian .=
        plan.wannier_center_convention==CONVENTION_I ? model.input.orbital_positions :
        zeros(3, model.num_orbitals)
    for i in 1:model.num_orbitals
        scratch.wannier_centers_fractional[
            :,
            i,
        ].=real_space_cartesian_to_fractional(
            scratch.wannier_centers_cartesian[:, i],
            model.lattice,
        )
    end
    scratch.centers_initialized=true
    return scratch
end

"""Prepare analytic workspaces without creating a surrogate Fourier model."""
function prepare_real_space!(workspace::MatrixElementWorkspace, model::AnalyticKModel)
    scientific_data_generation(model)
    _initialize_wannier_center_scratch!(workspace.scratch, model, workspace.plan)
    workspace.prepared=true
    return workspace
end

"""Analytic models have no Fourier factors."""
_prepare_fourier_factors!(
    factors::Vector{ComplexF64},
    model::AnalyticKModel,
    k::AbstractVector{<:Real},
)=factors

"""Use immutable model identity for shared analytic matrix caches."""
_shared_source_identity(
    workspace::MatrixElementWorkspace,
    model::AnalyticKModel,
    group::Symbol,
)=objectid(model.input)

"""Evaluate the basis connection: point embedding or the declared fixed-basis zero connection.

A k-independent orthonormal basis has i<phi|d_k phi>=0. This is its mathematical
basis contract, not an inferred material position operator or full-F provenance.
"""
function analytic_position(input::AnalyticKInput, k)
    validate_analytic_kpoint(input, k)
    if haskey(input.operators, :position)
        value=input.operators.position(k, input.parameters)
        size(value)==(input.num_orbitals, input.num_orbitals, 3) ||
            throw(DimensionMismatch("position callback shape"))
        all(isfinite, value) || throw(ArgumentError("nonfinite position callback"))
        all(isapprox(value[:, :, a], value[:, :, a]'; atol = 1e-11, rtol = 0) for a in 1:3) ||
            throw(ArgumentError("position callback must be Hermitian"))
        return value
    end
    input.basis in (:point_orbitals, :fixed_orthonormal) ||
        throw(ArgumentError("missing position callback"))
    value=zeros(promote_type(ComplexF64, eltype(k)), input.num_orbitals, input.num_orbitals, 3)
    if input.orbital_positions !== nothing
        for a in 1:3, i in 1:input.num_orbitals
            value[i, i, a]=input.orbital_positions[a, i]
        end
    end
    return value
end

"""Apply derivative product rules before the existing diagonal center similarity."""
function analytic_raw_group(model::AnalyticKModel, plan, group, k)
    input=model.input;
    n=model.num_orbitals;
    tau=input.orbital_positions
    centered=plan.wannier_center_convention==CONVENTION_I
    if group==:H
        return analytic_hamiltonian(input, k)
    elseif group in (:dH, :ddH)
        # Only centered product rules consume H; the spectrum already validates it.
        h=centered ? analytic_hamiltonian(input, k) : nothing
        d=analytic_hamiltonian_derivative(input, k, 1; diagnostics = model.evaluation_diagnostics)
        group==:dH && return centered ?
               [d[i, j, a]+im*(tau[a, j]-tau[a, i])*h[i, j] for i in 1:n, j in 1:n, a in 1:3] :
               d
        dd=analytic_hamiltonian_derivative(input, k, 2; diagnostics = model.evaluation_diagnostics)
        return centered ?
               [
            dd[i, j, a, b]+im*(
                tau[a, j]-tau[a, i]
            )*d[i, j, b]+im*(
                tau[b, j]-tau[b, i]
            )*d[i, j, a]-(tau[a, j]-tau[a, i])*(tau[b, j]-tau[b, i])*h[i, j] for
            i in 1:n, j in 1:n, a in 1:3, b in 1:3
        ] : dd
    elseif group in (:A, :dA)
        # Noncentered dA uses its derivative callback; raw A is prepared separately.
        a=(group==:A || centered) ? analytic_position(input, k) : nothing
        group==:A && return a
        if centered
            a=copy(a)
            for b in 1:3, i in 1:n
                ;
                a[i, i, b]-=tau[b, i];
            end
        end
        derivative = if haskey(input.operators, :position_derivative)
            input.operators.position_derivative(k, input.parameters)
        elseif input.basis in (:point_orbitals, :fixed_orthonormal) &&
               !haskey(input.operators, :position)
            zeros(ComplexF64, n, n, 3, 3)
        elseif input.derivative_method==:automatic
            analytic_automatic_derivative(x->analytic_position(input, x), k, 1)
        elseif input.derivative_method==:finite_difference
            analytic_central_derivative(
                x->analytic_position(input, x),
                k,
                1,
                input.finite_difference_step,
            )
        else
            throw(ArgumentError("missing position derivative"))
        end
        return centered ?
               [
            derivative[i, j, b, c]+im*(tau[c, j]-tau[c, i])*a[i, j, b] for
            i in 1:n, j in 1:n, b in 1:3, c in 1:3
        ] : derivative
    end
    haskey(input.operators, :spin) || throw(ArgumentError("missing local spin matrix"))
    s=input.operators.spin
    size(s)==(n, n, 3) && all(isfinite, s) || throw(ArgumentError("invalid local spin matrix"))
    all(isapprox(s[:, :, a], s[:, :, a]'; atol = 1e-11, rtol = 0) for a in 1:3) ||
        throw(ArgumentError("spin must be Hermitian"))
    group==:SS && return s
    h=analytic_hamiltonian(input, k);
    a=analytic_position(input, k)
    if group==:SH
        return haskey(input.operators, :spin_hamiltonian) ?
               input.operators.spin_hamiltonian(k, input.parameters) :
               cat((s[:, :, b]*h for b in 1:3)...; dims = 3)
    end
    name=group==:SR ? :spin_position : :spin_hamiltonian_position
    if haskey(input.operators, name)
        return getproperty(input.operators, name)(k, input.parameters)
    end
    input.basis==:point_orbitals || throw(ArgumentError("explicit embedding needs $name callback"))
    result=zeros(ComplexF64, n, n, 3, 3)
    for b in 1:3, c in 1:3
        result[:, :, b, c].=group==:SR ? s[:, :, c]*a[:, :, b] : s[:, :, c]*h*a[:, :, b]
    end
    return result
end

"""Fill requested compact Cartesian channels directly from analytic callbacks."""
function _shared_or_mixed_copy!(
    destination,
    workspace::MatrixElementWorkspace,
    model::AnalyticKModel,
    ::Val{G},
    kpoint,
) where {G}
    k=transpose(reciprocal_lattice(model.lattice))*kpoint
    value=analytic_raw_group(model, workspace.plan, G, k)
    if G==:H
        destination.=value
    else
        kind=_mixed_group_kind(G)
        if ndims(value)==3
            for a in 1:size(value, 3)
                channel=_axis_channel(workspace.plan, kind, a)
                iszero(channel) || (@views destination[:, :, channel].=value[:, :, a])
            end
        else
            for a in 1:workspace.plan.spatial_dimension, b in 1:size(value, 4)
                channel=_pair_channel(workspace.plan, kind, a, b)
                iszero(channel) || (@views destination[:, :, channel].=value[:, :, a, b])
            end
        end
    end
    return true
end

"""Construct complete finite-model Projector geometry directly in the analytic basis."""
function prepare_projector_covariant_geometry!(
    data::ProjectorMatrixData,
    workspace::ProjectorMatrixWorkspace,
    model::AnalyticKModel,
)
    input=model.input;
    dimension=workspace.matrix_elements.plan.spatial_dimension
    plan=workspace.matrix_elements.plan
    k=transpose(reciprocal_lattice(model.lattice))*data.common.kpoint
    raw_connection=workspace.raw_wannier_connection
    raw_connection_derivatives=workspace.raw_wannier_connection_derivatives
    derivative_overlap=workspace.derivative_overlap_wannier
    raw=analytic_position(input, k)
    raw_connection .= raw[:, :, 1:dimension]
    raw_connection_derivatives .= 0
    if haskey(input.operators, :position_derivative)
        raw_connection_derivatives .=
            input.operators.position_derivative(k, input.parameters)[:, :, 1:dimension, 1:dimension]
    elseif haskey(input.operators, :position)
        input.derivative_method==:automatic ||
            throw(ArgumentError("explicit position derivatives required for Projector geometry"))
        raw_connection_derivatives .=
            analytic_automatic_derivative(x->analytic_position(input, x), k, 1)[
                :,
                :,
                1:dimension,
                1:dimension,
            ]
    end
    if haskey(input.operators, :derivative_overlap)
        derivative_overlap .=
            input.operators.derivative_overlap(k, input.parameters)[:, :, 1:dimension, 1:dimension]
    else
        input.basis==:point_orbitals || throw(ArgumentError("missing derivative-overlap callback"))
        for mu in 1:dimension, beta in 1:dimension
            derivative_overlap[:, :, mu, beta].=raw[:, :, mu]*raw[:, :, beta]
        end
    end
    all(isfinite, derivative_overlap) || throw(ArgumentError("nonfinite derivative overlap"))
    centers=workspace.wannier_centers_cartesian
    centers_fractional=workspace.wannier_centers_fractional
    centers .= input.orbital_positions
    for orbital in 1:model.num_orbitals
        centers_fractional[
            :,
            orbital,
        ].=real_space_cartesian_to_fractional(centers[:, orbital], model.lattice)
    end
    temporary = workspace.matrix_elements.scratch.matrix_temporary
    for mu in 1:dimension, beta in 1:dimension
        _pair_required(plan, INTERNAL_CONNECTION_DERIVATIVES, mu, beta) || continue
        @views begin
            mul!(temporary, raw_connection[:, :, mu], raw_connection[:, :, beta])
            data.external_geometry[:, :, mu, beta] .=
                derivative_overlap[:, :, mu, beta] .- temporary
            if workspace.matrix_elements.plan.wannier_center_convention == CONVENTION_I
                _apply_wannier_center_similarity!(
                    data.external_geometry[:, :, mu, beta],
                    workspace.matrix_elements.scratch,
                    workspace.matrix_elements.plan,
                )
            end
        end
    end
    data.effective_connection .= raw_connection
    @inbounds for beta in 1:dimension, orbital in 1:model.num_orbitals
        data.effective_connection[orbital, orbital, beta] -= centers[beta, orbital]
    end
    data.effective_connection_derivatives .= raw_connection_derivatives
    for beta in 1:dimension
        effective = @view data.effective_connection[:, :, beta]
        for mu in 1:dimension
            derivative = @view data.effective_connection_derivatives[:, :, beta, mu]
            for column in 1:model.num_orbitals, row in 1:model.num_orbitals
                derivative[row, column] -=
                    1.0im * (centers[mu, row] - centers[mu, column]) * effective[row, column]
            end
            if workspace.matrix_elements.plan.wannier_center_convention == CONVENTION_I
                _apply_wannier_center_similarity!(
                    derivative,
                    workspace.matrix_elements.scratch,
                    workspace.matrix_elements.plan,
                )
            end
        end
        if workspace.matrix_elements.plan.wannier_center_convention == CONVENTION_I
            _apply_wannier_center_similarity!(
                effective,
                workspace.matrix_elements.scratch,
                workspace.matrix_elements.plan,
            )
        end
    end
    return data
end

"""Complete analytic full-overlap metric in the same center convention as H and A.

Metric tasks require an explicit overlap callback at Runtime preflight. The existing
point-orbital identity is retained only for other finite-model projector consumers.
"""
function prepare_quantum_metric_completion!(
    workspace::MatrixElementWorkspace,
    model::AnalyticKModel,
)
    data = workspace.data
    data.metric_external_generation == data.generation && return data.metric_external
    input = model.input
    k = transpose(reciprocal_lattice(model.lattice)) * data.kpoint
    a = analytic_position(input, k)
    f = if haskey(input.operators, :derivative_overlap)
        ComplexF64.(input.operators.derivative_overlap(k, input.parameters))
    else
        input.basis == :point_orbitals || error("QUANTUM_METRIC_FULL_DERIVATIVE_OVERLAP_REQUIRED")
        tensor = zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3, 3)
        for b in 1:3, c in 1:3
            tensor[:, :, c, b] .= a[:, :, c]*a[:, :, b]
        end
        tensor
    end
    size(f) == (model.num_orbitals, model.num_orbitals, 3, 3) ||
        throw(DimensionMismatch("analytic derivative overlap"))
    data.metric_external === nothing && (data.metric_external = similar(f))
    u = Diagonal(workspace.scratch.center_phase_factors) * data.spectrum.eigenvectors
    for b in 1:3, c in 1:3
        data.metric_external[:, :, c, b] .= u'*(f[:, :, c, b]-a[:, :, c]*a[:, :, b])*u
    end
    all(isfinite, data.metric_external) || error("QUANTUM_METRIC_NONFINITE_EXTERNAL")
    data.metric_external_generation = data.generation
    return data.metric_external
end
