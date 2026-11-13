"""
Finite unfolded Cartesian region in inverse Angstrom with default midpoint quadrature.

Select `UniformIntegration(region_quadrature=:left_endpoint)` in execution options
for half-open parameter nodes `i/N`, `i=0:N-1`, without translating this domain.

Provide equally sized `lower`, `upper`, and `k_mesh` tuples of length 1:3. Inactive
Cartesian coordinates are zero. The region controls integration only; callbacks
may declare a larger evaluation domain for finite-q and derivative stencils.

Alternatively provide `origin`, `vector_1`, `vector_2` and two `k_mesh` counts.
This is the two-dimensional parallelogram `origin + u*vector_1 + v*vector_2`,
with uniform midpoints in `u,v ∈ [0,1)`. Vectors share two or three Cartesian
components; the physical integration area is `norm(cross(vector_1,vector_2))`.
Add `vector_3` and three mesh counts for a three-dimensional parallelepiped.
All vectors then have three components, and volume is `abs(det([b1 b2 b3]))`.
Orientation reversal does not change the positive measure. Bounds and vector
forms are mutually exclusive; affine regions currently require uniform sampling.
"""
struct KRegion <: AbstractSampling
    lower::NTuple{3, Float64}
    upper::NTuple{3, Float64}
    k_mesh::NTuple{3, Int}
    spatial_dimension::Int
    affine_region::Union{Nothing, CartesianAffineRegion{2}, CartesianAffineRegion{3}}
end

"""Preserve the existing positional Cartesian-box construction."""
KRegion(
    lower::NTuple{3, Float64},
    upper::NTuple{3, Float64},
    k_mesh::NTuple{3, Int},
    spatial_dimension::Int,
) = KRegion(lower, upper, k_mesh, spatial_dimension, nothing)

"""Validate a Cartesian box or affine two- or three-dimensional region, without inferring periodicity."""
function KRegion(;
    lower = nothing,
    upper = nothing,
    origin = nothing,
    vector_1 = nothing,
    vector_2 = nothing,
    vector_3 = nothing,
    k_mesh,
)
    affine = any(x -> x !== nothing, (origin, vector_1, vector_2, vector_3))
    if affine
        lower === nothing && upper === nothing ||
            throw(ArgumentError("choose box bounds or affine vectors, not both"))
        all(x -> x !== nothing, (origin, vector_1, vector_2)) ||
            throw(ArgumentError("affine region requires origin, vector_1 and vector_2"))
        dimension = vector_3 === nothing ? 2 : 3
        length(k_mesh) == dimension ||
            throw(DimensionMismatch("one mesh count per affine basis required"))
        all(n -> n isa Integer && !(n isa Bool) && 0 < n <= 2^52 - 1, k_mesh) ||
            throw(ArgumentError("affine counts must be positive representable midpoint counts"))
        counts = Tuple(Int.(k_mesh))
        foldl(Base.checked_mul, counts)
        region =
            dimension == 2 ? CartesianAffineRegion(origin, vector_1, vector_2) :
            CartesianAffineRegion(origin, vector_1, vector_2, vector_3)
        weight = region.measure/prod(counts)
        isfinite(weight) && weight > 0 ||
            throw(ArgumentError("affine node weight must be finite and positive"))
        lo, hi = cartesian_affine_bounds(region)
        return KRegion(lo, hi, ntuple(a -> a <= dimension ? counts[a] : 1, 3), dimension, region)
    end
    lower !== nothing && upper !== nothing || throw(ArgumentError("box requires lower and upper"))
    d=length(lower)
    1<=d<=3 && length(upper)==length(k_mesh)==d || throw(DimensionMismatch("region axes"))
    all(isfinite, lower) && all(isfinite, upper) && all(lower .< upper) ||
        throw(ArgumentError("invalid region bounds"))
    all(n->n isa Integer && n>0, k_mesh) || throw(ArgumentError("invalid region counts"))
    return KRegion(
        ntuple(i->i<=d ? Float64(lower[i]) : 0.0, 3),
        ntuple(i->i<=d ? Float64(upper[i]) : 0.0, 3),
        ntuple(i->i<=d ? Int(k_mesh[i]) : 1, 3),
        d,
    )
end

"""Classify explicit Cartesian quadrature as an Integral task."""
_sampling_calculation(::KRegion)=:integral

"""Lower the domain without pretending that its cutoff is a reciprocal lattice."""
_sampling_fields(
    s::KRegion,
)=(;
    k_mesh = s.spatial_dimension < 3 ? s.k_mesh[1:2] : s.k_mesh,
    spatial_dimension = s.affine_region === nothing ? s.spatial_dimension :
                        s.affine_region.cartesian_dimension,
    integration_bounds = (s.lower, s.upper),
    integration_affine_region = s.affine_region,
)

"""Compatibility for the two-dimensional spelling; all execution uses affine_region."""
function Base.getproperty(region::KRegion, name::Symbol)
    name === :parallelogram && return getfield(region, :affine_region)
    return getfield(region, name)
end
