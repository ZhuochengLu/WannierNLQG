"""Complete a physical square row lattice with canonical one-Angstrom axes.

Only new 1x1/2x2 inputs use completion. Existing 3x3 inputs retain their original
geometry and callback contract. Auxiliary axes supply reference volume, not
physical momentum directions, periodicity or additional sampling nodes.
"""
function complete_native_reference_lattice(lattice)
    physical = Matrix{Float64}(lattice)
    d = size(physical, 1)
    d in 1:3 && size(physical, 2) == d && all(isfinite, physical) && det(physical) > 0 || throw(
        ArgumentError(
            "lattice must be a finite positive-orientation 1x1, 2x2 or 3x3 row matrix in Angstrom; rotated rectangular embeddings are unsupported",
        ),
    )
    d == 3 && return physical, d
    reference = Matrix{Float64}(I, 3, 3)
    reference[1:d, 1:d] .= physical
    return reference, d
end

"""Pad only physical Cartesian rows, preserving the explicit model's band axes."""
function pad_native_physical_rows(values, d::Int, columns::Int, label)
    size(values) == (d, columns) ||
        throw(DimensionMismatch("$label must have $d physical rows and $columns columns"))
    d == 3 && return Matrix(values)
    padded = zeros(eltype(values), 3, columns)
    padded[1:d, :] .= values
    return padded
end

"""Typed low-dimensional callback with an internal three-axis Cartesian result.

The user receives d Cartesian coordinates in inverse Angstrom. The trailing m
Cartesian result indices are independently padded with zeros. Band indices and
the three physical spin components never use this padding rule.
"""
struct PhysicalAnalyticCallback{D, M, F} <: Function
    callback::F
end

# Keep the Hamiltonian result unchanged; only its coordinate argument is reduced.
function (wrapped::PhysicalAnalyticCallback{D, 0})(k, parameters) where {D}
    return wrapped.callback(view(k, 1:D), parameters)
end

# Lift the supplied Cartesian component/derivative axes without changing values.
function (wrapped::PhysicalAnalyticCallback{D, M})(k, parameters) where {D, M}
    value = wrapped.callback(view(k, 1:D), parameters)
    ndims(value) == 2 + M && all(size(value, axis) == D for axis in 3:(2 + M)) || throw(
        DimensionMismatch(
            "low-dimensional callback result requires $M trailing physical Cartesian axes of length $D",
        ),
    )
    padded = zeros(eltype(value), size(value, 1), size(value, 2), ntuple(_ -> 3, M)...)
    view(padded,:,:,(ntuple(_ -> 1:D, M)...)) .= value
    return padded
end

"""Reduce both endpoints of an explicitly supplied cross-point overlap callback."""
struct PhysicalAnalyticOverlap{D, F} <: Function
    callback::F
end

# No overlap or cross-point physics is inferred by the coordinate adapter.
(wrapped::PhysicalAnalyticOverlap{D})(left, right, parameters) where {D} =
    wrapped.callback(view(left, 1:D), view(right, 1:D), parameters)

# Old three-coordinate callbacks retain their exact original object/type.
physical_analytic_callback(callback, ::Val{3}, ::Val{M}) where {M} = callback
"""Wrap a physical coordinate callback while retaining its declared Cartesian rank."""
physical_analytic_callback(callback, ::Val{D}, ::Val{M}) where {D, M} =
    PhysicalAnalyticCallback{D, M, typeof(callback)}(callback)

"""Adapt only declared analytic operator axes; spin remains laboratory Cartesian."""
function physical_analytic_operators(operators, ::Val{D}) where {D}
    D == 3 && return operators
    return (;
        (
            name => if name == :spin
                value
            elseif name == :overlap
                PhysicalAnalyticOverlap{D, typeof(value)}(value)
            else
                axes =
                    name == :position ? 1 :
                    name == :position_derivative ? 2 :
                    name == :position_second_derivative ? 3 :
                    name == :position_third_derivative ? 4 :
                    name == :derivative_overlap ? 2 :
                    throw(ArgumentError("unsupported low-dimensional analytic operator $name"))
                physical_analytic_callback(value, Val(D), Val(axes))
            end for (name, value) in pairs(operators)
        )...
    )
end
