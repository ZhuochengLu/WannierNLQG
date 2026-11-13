"""Cartesian raw-operator derivative closure for isolated-band curvature jets.

This is a physical channel request subordinate to `MatrixElementPlan`, not a
second interpolation cache. Orders count Cartesian derivatives; component zero
denotes H, while components 1:3 denote the orbital-frame position connection.
Only actually requested response components are closed under differentiation.
"""
struct OrthogonalGeometryDerivativePlan
    hamiltonian_orders::Vector{NTuple{3, Int}}
    position_orders::Vector{Tuple{Int, NTuple{3, Int}}}
    maximum_order::Int
end

# Convert at most three valid Cartesian axes into their three-component derivative multi-index.
@inline function geometry_derivative_order(axes::Vararg{Int})
    length(axes) <= 3 || throw(ArgumentError("geometry derivatives support order at most three"))
    all(axis -> axis in 1:3, axes) || throw(ArgumentError("invalid Cartesian derivative axis"))
    return ntuple(axis -> count(==(axis), axes), 3)
end

"""Add every lower multi-index, including the zero derivative, exactly once."""
function _geometry_close_orders!(orders, order::NTuple{3, Int})
    for x in 0:order[1], y in 0:order[2], z in 0:order[3]
        lower = (x, y, z)
        lower in orders || push!(orders, lower)
    end
    return orders
end

"""Compile H/A orders for curvature (rank two), BCD (three), or BCQ (four).

Curvature contains the curl of the orbital connection. Consequently BCQ needs
third derivatives of A as well as H; a point-orbital zero is a source property,
never an omitted requested channel. All eigenvector-jet intermediate directions
are closed here, before allocating worker storage.
"""
function OrthogonalGeometryDerivativePlan(components)
    hamiltonian = NTuple{3, Int}[(0, 0, 0)]
    position = Tuple{Int, NTuple{3, Int}}[]
    maximum_order = 0
    isempty(components) && throw(ArgumentError("empty geometry derivative request"))
    for component in components
        length(component) in 2:4 || throw(ArgumentError("curvature component rank must be 2:4"))
        all(axis -> axis isa Integer && !(axis isa Bool) && axis in 1:3, component) ||
            throw(ArgumentError("invalid curvature tensor component"))
        axes = Tuple(Int.(component))
        maximum_order = max(maximum_order, length(axes) - 1)
        # The donor's D2 diagonal fixes the normalized connection gauge. It
        # consumes A in each eigenframe differentiation direction and the
        # symmetric first connection derivative, including response axes c/d.
        # These are genuine prerequisites even when c/d are not curl axes.
        for connection_axis in unique(axes)
            channel = (connection_axis, (0, 0, 0))
            channel in position || push!(position, channel)
            if length(axes) >= 3
                for derivative_axis in unique(axes)
                    channel = (connection_axis, geometry_derivative_order(derivative_axis))
                    channel in position || push!(position, channel)
                end
            end
        end
        # Differentiating the two first-order eigenvector factors can place
        # response derivative axes on either factor, but never both curl axes
        # on the same factor.
        for curl_axis in axes[1:2]
            order = geometry_derivative_order(curl_axis, axes[3:end]...)
            _geometry_close_orders!(hamiltonian, order)
        end
        for (connection_axis, curl_axis) in ((axes[1], axes[2]), (axes[2], axes[1]))
            orders = NTuple{3, Int}[]
            _geometry_close_orders!(orders, geometry_derivative_order(curl_axis, axes[3:end]...))
            for order in orders
                channel = (connection_axis, order)
                channel in position || push!(position, channel)
            end
        end
    end
    sort!(hamiltonian; by = order -> (sum(order), order))
    sort!(position; by = channel -> (channel[1], sum(channel[2]), channel[2]))
    return OrthogonalGeometryDerivativePlan(hamiltonian, position, maximum_order)
end

"""Source of an analytic Cartesian raw-H derivative; never silently admit FD."""
function geometry_hamiltonian_derivative_source(input::AnalyticKInput, order::Integer)
    order in 0:3 || throw(ArgumentError("Hamiltonian derivative order must be 0:3"))
    order == 0 && return :raw_callback
    input.derivatives[order] !== nothing && return :explicit
    input.derivative_method == :automatic && return :automatic_raw_operator
    throw(
        ArgumentError(
            "ANALYTIC_GEOMETRY_H_DERIVATIVE_REQUIRED: order=$order; finite differences are not an analytic source",
        ),
    )
end

"""Source of A derivatives, preserving the declared zero/constant basis semantics."""
function geometry_position_derivative_source(input::AnalyticKInput, order::Integer)
    order in 0:3 || throw(ArgumentError("position derivative order must be 0:3"))
    order == 0 &&
        return haskey(input.operators, :position) ? :raw_callback : :declared_basis_connection
    keys = (:position_derivative, :position_second_derivative, :position_third_derivative)
    haskey(input.operators, keys[order]) && return :explicit
    !haskey(input.operators, :position) &&
        input.basis in (:point_orbitals, :fixed_orthonormal) &&
        return :declared_constant_connection
    input.derivative_method == :automatic && return :automatic_raw_operator
    throw(
        ArgumentError(
            "ANALYTIC_GEOMETRY_POSITION_DERIVATIVE_REQUIRED: order=$order; no zero substitution or finite-difference fallback",
        ),
    )
end

"""Evaluate one full raw-A Cartesian derivative tensor, without differentiating eigenvectors."""
function geometry_position_derivative(input::AnalyticKInput, k, order::Integer)
    source = geometry_position_derivative_source(input, order)
    order == 0 && return analytic_position(input, k)
    validate_analytic_kpoint(input, k)
    n = input.num_orbitals
    value = if source == :explicit
        keys = (:position_derivative, :position_second_derivative, :position_third_derivative)
        getproperty(input.operators, keys[order])(k, input.parameters)
    elseif source == :declared_constant_connection
        zeros(ComplexF64, n, n, 3, ntuple(_ -> 3, order)...)
    else
        analytic_automatic_derivative(x -> analytic_position(input, x), k, order)
    end
    size(value) == (n, n, 3, ntuple(_ -> 3, order)...) ||
        throw(DimensionMismatch("analytic position derivative order $order shape"))
    all(isfinite, value) ||
        throw(ArgumentError("nonfinite analytic position derivative order $order"))
    for index in CartesianIndices(ntuple(_ -> 3, order + 1))
        matrix = view(value,:,:,(Tuple(index)...))
        isapprox(matrix, matrix'; atol = 1e-10, rtol = 1e-10) ||
            throw(ArgumentError("non-Hermitian analytic position derivative order $order"))
    end
    return value
end
