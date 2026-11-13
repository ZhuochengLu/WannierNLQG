"""Validated affine Cartesian geometry; D is physical dimension, not tensor dimension."""
struct CartesianAffineRegion{D}
    origin::NTuple{3, Float64}
    vectors::NTuple{D, NTuple{3, Float64}}
    measure::Float64
    cartesian_dimension::Int

    function CartesianAffineRegion(origin, vectors::Vararg{Any, D}) where {D}
        D in (2, 3) || throw(ArgumentError("affine region requires two or three bases"))
        dimension = length(origin)
        dimension in (2, 3) &&
        (D == 2 || dimension == 3) &&
        all(v -> length(v) == dimension, vectors) || throw(
            DimensionMismatch(
                "affine coordinates must share two or three components; a volume requires three",
            ),
        )
        coordinates = (origin, vectors...)
        all(x -> x isa Real && !(x isa Bool) && isfinite(x), Iterators.flatten(coordinates)) ||
            throw(ArgumentError("affine coordinates must be finite real numbers"))
        padded = map(v -> ntuple(a -> a <= dimension ? Float64(v[a]) : 0.0, 3), coordinates)
        all(isfinite, Iterators.flatten(padded)) ||
            throw(ArgumentError("affine coordinates must be representable in Float64"))
        k0, bases = padded[1], Base.tail(padded)
        measure =
            D == 2 ? norm(cross(collect(bases[1]), collect(bases[2]))) :
            abs(det(hcat(collect.(bases)...)))
        isfinite(measure) && measure > 0 ||
            throw(ArgumentError("affine bases must have nonzero finite area or volume"))
        for selectors in Iterators.product(ntuple(_ -> (0, 1), D)...)
            point = ntuple(
                a -> foldl((value, j) -> value + selectors[j]*bases[j][a], 1:D; init = k0[a]),
                3,
            )
            all(isfinite, point) || throw(ArgumentError("affine corners must be finite"))
        end
        return new{D}(k0, bases, measure, dimension)
    end
end

# Keep the newly introduced two-dimensional expert spelling as a small alias.
const CartesianParallelogram = CartesianAffineRegion{2}
# Construct the two-dimensional alias through the shared finite-area validation.
CartesianAffineRegion{2}(origin, b1, b2) = CartesianAffineRegion(origin, b1, b2)
const CartesianParallelepiped = CartesianAffineRegion{3}
# Construct the three-dimensional alias through the shared finite-volume validation.
CartesianAffineRegion{3}(origin, b1, b2, b3) = CartesianAffineRegion(origin, b1, b2, b3)

"""Physical dimension and measure remain independent of the enclosing Cartesian box."""
affine_dimension(::CartesianAffineRegion{D}) where {D} = D
"""Expose basis vectors and the dimension-specific area or volume without duplicating stored geometry."""
function Base.getproperty(region::CartesianAffineRegion{D}, name::Symbol) where {D}
    name === :vector_1 && return getfield(region, :vectors)[1]
    name === :vector_2 && return getfield(region, :vectors)[2]
    name === :vector_3 && D == 3 && return getfield(region, :vectors)[3]
    name === :area && D == 2 && return getfield(region, :measure)
    name === :volume && D == 3 && return getfield(region, :measure)
    return getfield(region, name)
end

"""Evaluate an unfolded Cartesian point, preserving left-to-right affine arithmetic."""
function cartesian_affine_point(
    region::CartesianAffineRegion{D},
    coordinates::Vararg{Any, D},
) where {D}
    return ntuple(
        a -> foldl(
            (value, j) -> value + coordinates[j]*region.vectors[j][a],
            1:D;
            init = region.origin[a],
        ),
        3,
    )
end
"""Evaluate a two-dimensional point through the shared unfolded affine map."""
cartesian_parallelogram_point(region::CartesianParallelogram, u, v) =
    cartesian_affine_point(region, u, v)

"""Enclosing Cartesian bounds are routing diagnostics, never a quadrature measure."""
function cartesian_affine_bounds(region::CartesianAffineRegion{D}) where {D}
    corners = [
        cartesian_affine_point(region, selectors...) for
        selectors in Iterators.product(ntuple(_ -> (0, 1), D)...)
    ]
    return ntuple(a -> minimum(k[a] for k in corners), 3),
    ntuple(a -> maximum(k[a] for k in corners), 3)
end
"""Return enclosing bounds for the two-dimensional alias; area still comes from its basis vectors."""
cartesian_parallelogram_bounds(region::CartesianParallelogram) = cartesian_affine_bounds(region)

"""Uniform half-open parameter nodes; first parameter varies fastest."""
struct CartesianAffineGrid{D}
    region::CartesianAffineRegion{D}
    counts::NTuple{D, Int}
    lattice::Matrix{Float64}
    region_quadrature::Symbol

    function CartesianAffineGrid(
        region::CartesianAffineRegion{D},
        counts,
        lattice,
        region_quadrature,
    ) where {D}
        region_quadrature in (:midpoint, :left_endpoint) ||
            throw(ArgumentError("unsupported finite-region quadrature"))
        return new{D}(region, counts, lattice, region_quadrature)
    end
end
"""Preserve the default midpoint constructor and accept an explicit finite-region rule."""
CartesianAffineGrid(region, counts, lattice; region_quadrature = :midpoint) =
    CartesianAffineGrid(region, counts, lattice, region_quadrature)
"""Preserve dimension-specialized and parallelogram grid construction."""
CartesianAffineGrid{D}(
    region::CartesianAffineRegion{D},
    counts,
    lattice,
    region_quadrature = :midpoint,
) where {D} = CartesianAffineGrid(region, counts, lattice, region_quadrature)
const CartesianParallelogramGrid = CartesianAffineGrid{2}
"""Count midpoint nodes as the product of the validated parameter mesh counts."""
Base.length(grid::CartesianAffineGrid) = prod(grid.counts)

"""Use the common deterministic global index without folding nonperiodic coordinates."""
function integral_kpoint!(dest::Vector{Float64}, grid::CartesianAffineGrid{D}, index::Int) where {D}
    1 <= index <= length(grid) || throw(BoundsError(grid, index))
    indices = ntuple(j -> ((index - 1) ÷ prod(grid.counts[1:(j - 1)])) % grid.counts[j], D)
    # Preserve the existing midpoint arithmetic; explicit endpoints use i/N first.
    k =
        grid.region_quadrature == :left_endpoint ?
        cartesian_affine_point(grid.region, ntuple(j -> indices[j]/grid.counts[j], D)...) :
        ntuple(
            a -> foldl(
                (value, j) ->
                    value + (indices[j] + 0.5)*grid.region.vectors[j][a]/grid.counts[j],
                1:D;
                init = grid.region.origin[a],
            ),
            3,
        )
    dest .= reciprocal_cartesian_to_fractional(collect(k), grid.lattice)
    return dest
end

"""Midpoint quadrature in a Cartesian box, returned in the runtime fractional frame."""
struct CartesianRegionGrid
    lower::NTuple{3, Float64}
    upper::NTuple{3, Float64}
    counts::NTuple{3, Int}
    spatial_dimension::Int
    lattice::Matrix{Float64}
    region_quadrature::Symbol

    function CartesianRegionGrid(
        lower,
        upper,
        counts,
        spatial_dimension,
        lattice,
        region_quadrature,
    )
        region_quadrature in (:midpoint, :left_endpoint) ||
            throw(ArgumentError("unsupported finite-region quadrature"))
        return new(lower, upper, counts, spatial_dimension, lattice, region_quadrature)
    end
end
"""Construct a box grid with the existing midpoint default or explicit left endpoints."""
CartesianRegionGrid(
    lower,
    upper,
    counts,
    spatial_dimension,
    lattice;
    region_quadrature = :midpoint,
) = CartesianRegionGrid(lower, upper, counts, spatial_dimension, lattice, region_quadrature)

"""Number of deterministic quadrature nodes."""
Base.length(grid::CartesianRegionGrid)=prod(grid.counts)

"""Map a global linear index to a Cartesian midpoint without folding the point."""
function integral_kpoint!(dest::Vector{Float64}, grid::CartesianRegionGrid, index::Int)
    1<=index<=length(grid) || throw(BoundsError(grid, index))
    t=index-1;
    k=zeros(3)
    for a in 1:3
        i=t%grid.counts[a];
        t=t÷grid.counts[a]
        k[a]=a<=grid.spatial_dimension ?
             grid.region_quadrature == :left_endpoint ?
             grid.lower[a]+(i/grid.counts[a])*(grid.upper[a]-grid.lower[a]) :
             grid.lower[a]+(i+0.5)*(grid.upper[a]-grid.lower[a])/grid.counts[a] : 0.0
    end
    dest .= reciprocal_cartesian_to_fractional(k, grid.lattice)
    return dest
end
