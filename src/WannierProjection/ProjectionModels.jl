"""
    ProjectionRadialTransformConfig(; method=:gauss_laguerre_high_precision, gauss_laguerre_order=64)

Select one basis-wide radial Fourier--Bessel transform. The compatibility
backend reproduces the fixed mixed-grid, trapezoidal, not-a-knot numerical
contract used for WannierBerri parity. The high-precision backend evaluates the
same radial integral with a configurable Gauss--Laguerre rule and does not pass
through the compatibility tabulation or spline. A projection basis owns one
such convention, so specs cannot silently mix radial algorithms.
"""
struct ProjectionRadialTransformConfig
    method::Symbol
    gauss_laguerre_order::Int

    function ProjectionRadialTransformConfig(;
        method::Symbol = :gauss_laguerre_high_precision,
        gauss_laguerre_order::Integer = 64,
    )
        method in (:wannierberri_compatible, :gauss_laguerre_high_precision) || throw(
            ArgumentError(
                "projection radial transform method must be " *
                ":wannierberri_compatible or :gauss_laguerre_high_precision",
            ),
        )
        order = Int(gauss_laguerre_order)
        order >= 8 || throw(ArgumentError("gauss_laguerre_order must be at least 8"))
        return new(method, order)
    end
end

# Return the complete selected algorithm contract for hashing and provenance.
function projection_radial_transform_contract(config::ProjectionRadialTransformConfig)
    common = (contract_version = "1.0", method = config.method)
    if config.method == :wannierberri_compatible
        return merge(
            common,
            (
                bohr_radius_angstrom = 0.529177210544,
                momentum_linear_end = 5.0,
                momentum_maximum = 100.0,
                momentum_linear_step = 0.01,
                momentum_logarithmic_step = 0.2,
                radial_linear_end = 20.0,
                radial_maximum = 200.0,
                radial_linear_step = 0.01,
                radial_logarithmic_step = 0.1,
                radial_quadrature = :trapezoidal,
                interpolation = :not_a_knot_cubic,
                low_momentum_cutoff = 1.0e-3,
            ),
        )
    end
    return merge(
        common,
        (
            bohr_radius_angstrom = 0.529177210903,
            quadrature = :gauss_laguerre,
            gauss_laguerre_order = config.gauss_laguerre_order,
            interpolation = :none,
            momentum_maximum = 100.0,
        ),
    )
end

"""
    ProjectionSpec(; selector, orbital_sets, positions=nothing, local_bases=I, indices=nothing)

High-level declaration of one ordered group of Wannier90-style projections.
`positions` is a `3 x num_centers` fractional column matrix. When it is
omitted, the basis expander resolves `selector` against an explicit
`CrystalStructure`. `orbital_sets` accepts one string or an ordered tuple of
strings. A single right-handed Cartesian row basis is broadcast to all centers;
alternatively, pass a `3 x 3 x num_centers` array. Expert `indices` address the
whole local basis of this spec, with rows ordered by orbital-set declaration and
the established orbital/spin ordering.
"""
struct ProjectionSpec
    selector::String
    orbital_sets::Vector{String}
    positions_fractional::Union{Nothing, Matrix{Float64}}
    local_bases::Union{Matrix{Float64}, Array{Float64, 3}}
    indices::Union{Nothing, Matrix{Int}}

    function ProjectionSpec(;
        selector,
        orbital_sets,
        positions = nothing,
        local_bases = I,
        indices = nothing,
    )
        selector_name = strip(String(selector))
        isempty(selector_name) && throw(ArgumentError("selector must not be empty"))
        sets = if orbital_sets isa AbstractString
            [lowercase(strip(String(orbital_sets)))]
        else
            [lowercase(strip(String(value))) for value in orbital_sets]
        end
        isempty(sets) && throw(ArgumentError("orbital_sets must not be empty"))
        all(!isempty, sets) || throw(ArgumentError("orbital_sets contains an empty label"))

        position_values = if positions === nothing
            nothing
        else
            values = Matrix{Float64}(positions)
            size(values, 1) == 3 ||
                throw(ArgumentError("positions must have size (3, num_centers)"))
            size(values, 2) > 0 || throw(ArgumentError("positions must contain a center"))
            all(isfinite, values) ||
                throw(ArgumentError("positions contains non-finite values"))
            mod.(values, 1.0)
        end

        basis_values = if local_bases isa UniformScaling
            Matrix{Float64}(local_bases, 3, 3)
        elseif ndims(local_bases) == 2
            Matrix{Float64}(local_bases)
        elseif ndims(local_bases) == 3
            Array{Float64, 3}(local_bases)
        else
            throw(ArgumentError("local_bases must be 3 x 3 or 3 x 3 x num_centers"))
        end
        size(basis_values, 1) == 3 && size(basis_values, 2) == 3 ||
            throw(ArgumentError("local_bases must be 3 x 3 or 3 x 3 x num_centers"))
        ndims(basis_values) == 3 &&
            size(basis_values, 3) == 0 &&
            throw(ArgumentError("local_bases must contain a center basis"))
        all(isfinite, basis_values) ||
            throw(ArgumentError("local_bases contains non-finite values"))

        index_values = if indices === nothing
            nothing
        else
            values = Matrix{Int}(indices)
            size(values, 1) > 0 && size(values, 2) > 0 ||
                throw(ArgumentError("indices must have positive dimensions"))
            all(>(0), values) || throw(ArgumentError("indices must be positive"))
            values
        end
        return new(selector_name, sets, position_values, basis_values, index_values)
    end
end

"""
One ordered Wannier projection block.

`indices[:, center]` stores the one-based global Wannier indices for a local
orbital basis at one center. Local Cartesian bases are right-handed row bases.
Spinor blocks use interlaced orbital-up/orbital-down ordering.
"""
struct WannierProjectionBlock
    selector::String
    orbital_set::String
    positions_fractional::Matrix{Float64}
    indices::Matrix{Int}
    local_bases::Array{Float64, 3}
    spinor::Bool

    function WannierProjectionBlock(
        selector,
        orbital_set,
        positions_fractional,
        indices,
        local_bases,
        spinor,
    )
        selector_name = strip(String(selector))
        orbital_name = lowercase(strip(String(orbital_set)))
        positions = Matrix{Float64}(positions_fractional)
        index_matrix = Matrix{Int}(indices)
        bases = Array{Float64, 3}(local_bases)
        center_count = size(positions, 2)

        isempty(selector_name) && throw(ArgumentError("selector must not be empty"))
        isempty(orbital_name) && throw(ArgumentError("orbital_set must not be empty"))
        size(positions, 1) == 3 ||
            throw(ArgumentError("projection positions must have size (3, num_centers)"))
        center_count > 0 || throw(ArgumentError("projection block must contain a center"))
        size(index_matrix, 2) == center_count ||
            throw(ArgumentError("projection indices and centers disagree"))
        size(bases) == (3, 3, center_count) ||
            throw(ArgumentError("local_bases must have size (3, 3, num_centers)"))
        all(>(0), index_matrix) || throw(ArgumentError("Wannier indices must be positive"))
        for center_index in 1:center_count
            local_basis = @view bases[:, :, center_index]
            isapprox(
                local_basis * local_basis',
                Matrix{Float64}(I, 3, 3);
                atol = 1.0e-10,
                rtol = 0.0,
            ) || throw(ArgumentError("local basis $(center_index) is not orthonormal"))
            isapprox(det(local_basis), 1.0; atol = 1.0e-10, rtol = 0.0) ||
                throw(ArgumentError("local basis $(center_index) is not right-handed"))
        end

        return new(selector_name, orbital_name, positions, index_matrix, bases, Bool(spinor))
    end
end

"""Complete ordered projection basis for one Wannier model."""
struct WannierProjectionBasis
    blocks::Vector{WannierProjectionBlock}
    num_wannier::Int
    spinor::Bool
    radial_transform::ProjectionRadialTransformConfig

    function WannierProjectionBasis(blocks, num_wannier, spinor, radial_transform)
        block_values = WannierProjectionBlock[blocks...]
        dimension = Int(num_wannier)
        transform = radial_transform::ProjectionRadialTransformConfig
        dimension > 0 || throw(ArgumentError("num_wannier must be positive"))
        isempty(block_values) && throw(ArgumentError("at least one projection block is required"))
        all(block -> block.spinor == Bool(spinor), block_values) ||
            throw(ArgumentError("projection blocks must share one spinor convention"))
        indices = reduce(vcat, vec(block.indices) for block in block_values)
        sort(indices) == collect(1:dimension) ||
            throw(ArgumentError("projection indices must be a permutation of one:num_wannier"))
        return new(block_values, dimension, Bool(spinor), transform)
    end
end

# Preserve the established explicit-block constructor with the high-precision default.
function WannierProjectionBasis(blocks, num_wannier, spinor)
    return WannierProjectionBasis(blocks, num_wannier, spinor, ProjectionRadialTransformConfig())
end

"""
Expand ordered projection specs into the canonical block and index model.

Automatic numbering is spec-major, then center-major, orbital-set-major, with
interlaced spin when `spinor=true`. Explicit indices may only permute the
complete `1:num_wannier` basis.
"""
function WannierProjectionBasis(
    specs::AbstractVector{ProjectionSpec};
    structure = nothing,
    spinor::Bool = false,
    num_wannier = nothing,
    tolerance::Real = 1.0e-8,
    radial_transform::ProjectionRadialTransformConfig = ProjectionRadialTransformConfig(),
)
    return build_wannier_projection_basis(
        specs;
        structure,
        spinor,
        num_wannier,
        tolerance,
        radial_transform,
    )
end
