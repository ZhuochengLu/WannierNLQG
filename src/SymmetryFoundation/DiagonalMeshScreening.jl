"""
A mathematical diagonal uniform mesh, k = D⁻¹n + t modulo integer vectors.

`offset_fractional` is t in reciprocal fractional coordinates. This type does
not assert that a native producer saved wavefunctions at all generated points.
"""
struct DiagonalKMesh
    dimensions::NTuple{3, Int}
    offset_fractional::NTuple{3, Float64}

    function DiagonalKMesh(dimensions, offset_fractional = (0.0, 0.0, 0.0))
        length(dimensions) == 3 && all(n -> n isa Integer && !(n isa Bool) && n > 0, dimensions) ||
            throw(ArgumentError("diagonal k mesh requires three positive integer dimensions"))
        length(offset_fractional) == 3 &&
        all(x -> x isa Real && !(x isa Bool) && isfinite(x), offset_fractional) ||
            throw(ArgumentError("fractional mesh offset requires three finite reals"))
        sizes = Tuple(Int.(dimensions))
        Base.checked_mul(Base.checked_mul(sizes[1], sizes[2]), sizes[3])
        offset = Tuple(Float64.(offset_fractional))
        all(isfinite, offset) || throw(ArgumentError("mesh offset exceeds Float64 range"))
        return new(sizes, offset)
    end
end

"""Classify saved points against an explicit grid, retaining input order.

Incomplete sets are reported, never completed as physical wavefunction data.
Duplicate or off-grid points are rejected before a screening recommendation.
"""
function classify_diagonal_mesh_points(
    mesh::DiagonalKMesh,
    points::AbstractMatrix;
    tolerance = 1.0e-9,
)
    size(points, 1) == 3 && all(isfinite, points) ||
        throw(ArgumentError("actual k points must be finite 3×N"))
    isfinite(tolerance) && 0 < tolerance < 0.5 ||
        throw(ArgumentError("invalid mesh point tolerance"))
    slots = Int[]
    seen = Set{Int}()
    linear = LinearIndices(mesh.dimensions)
    for point in eachcol(points)
        coordinates = [(point[i] - mesh.offset_fractional[i]) * mesh.dimensions[i] for i in 1:3]
        maximum(abs, coordinates .- round.(coordinates)) <= tolerance ||
            throw(ArgumentError("actual k point is outside declared grid"))
        indices = ntuple(i -> mod(round(Int, coordinates[i]), mesh.dimensions[i]) + 1, 3)
        slot = linear[indices...]
        slot in seen && throw(ArgumentError("duplicate actual k point modulo reciprocal lattice"))
        push!(seen, slot)
        push!(slots, slot)
    end
    return (
        complete = length(slots)==prod(mesh.dimensions),
        actual_count = length(slots),
        grid_count = prod(mesh.dimensions),
        slots_in_original_order = slots,
    )
end

# Return the signed reciprocal action; translations affect phases, not k-point images.
function _mesh_reciprocal_action(operation::SymmetryOperation)
    action = transpose(inv(Rational{BigInt}.(operation.rotation_fractional)))
    return operation.antiunitary ? -action : action
end

"""Check D*A*D⁻¹ and D*(A*t-t); the first test uses exact rational arithmetic."""
function diagonal_mesh_closure(
    mesh::DiagonalKMesh,
    operation::SymmetryOperation;
    tolerance = 1.0e-9,
)
    isfinite(tolerance) && 0 < tolerance < 0.5 ||
        throw(ArgumentError("mesh tolerance must lie in (0, 0.5)"))
    action = _mesh_reciprocal_action(operation)
    sizes = mesh.dimensions
    integer_action =
        all(denominator(action[i, j] * sizes[i] / sizes[j]) == 1 for i in 1:3, j in 1:3)
    offset = collect(mesh.offset_fractional)
    shift = collect(sizes) .* (Float64.(action) * offset - offset)
    offset_residual = maximum(abs, shift .- round.(shift))
    return (
        closed = integer_action && offset_residual <= tolerance,
        integer_action,
        offset_residual,
    )
end

"""
Independently enumerate transformed points, checking permutation and integer G shifts.

The direct floating-point point action is independent of the rational closure test.
Memory is one bit per grid point. No point or wavefunction is added to native input.
"""
function enumerate_diagonal_mesh_closure(
    mesh::DiagonalKMesh,
    operation::SymmetryOperation;
    tolerance = 1.0e-9,
)
    isfinite(tolerance) && 0 < tolerance < 0.5 ||
        throw(ArgumentError("mesh tolerance must lie in (0, 0.5)"))
    sizes = mesh.dimensions
    action = Float64.(_mesh_reciprocal_action(operation))
    offset = collect(mesh.offset_fractional)
    seen = falses(prod(sizes))
    linear = LinearIndices(sizes)
    worst_residual = 0.0
    for index in CartesianIndices(sizes)
        point = [((index[axis] - 1) / sizes[axis]) + offset[axis] for axis in 1:3]
        transformed = action * point
        coordinates = (transformed .- offset) .* collect(sizes)
        residual = maximum(abs, coordinates .- round.(coordinates))
        worst_residual = max(worst_residual, residual)
        residual <= tolerance || return (closed = false, unique = false, worst_residual)
        integer_coordinates = round.(Int, coordinates)
        target = ntuple(axis -> mod(integer_coordinates[axis], sizes[axis]) + 1, 3)
        target_point = [(target[axis] - 1) / sizes[axis] + offset[axis] for axis in 1:3]
        displacement = transformed - target_point
        maximum(abs, displacement .- round.(displacement)) <= tolerance ||
            return (closed = false, unique = false, worst_residual)
        slot = linear[target...]
        seen[slot] && return (closed = false, unique = false, worst_residual)
        seen[slot] = true
    end
    return (closed = all(seen), unique = all(seen), worst_residual)
end

"""
Recommend the smallest closed diagonal mesh meeting lattice-length density targets.

Search is bounded by `search_radius` above the per-axis minimum. The original
grid-step offset n*t modulo one is retained. In 2D, the third size and fractional
offset remain fixed; all operations, including mixed axes, are still checked.
This density metric is not a reciprocal-space convergence criterion.
"""
function recommend_diagonal_mesh(
    structure::CrystalStructure,
    mesh::DiagonalKMesh,
    operations::AbstractVector{SymmetryOperation};
    dimension::Int = 3,
    density_target::Float64 = 55.0,
    search_radius::Int = 10,
    tolerance::Float64 = 1.0e-9,
)
    dimension in (2, 3) || throw(ArgumentError("mesh dimension must be 2 or 3"))
    isfinite(density_target) && density_target > 0 ||
        throw(ArgumentError("density_target must be positive and finite"))
    search_radius >= 0 || throw(ArgumentError("search_radius must be nonnegative"))
    isempty(operations) && throw(ArgumentError("mesh screening requires at least one operation"))
    lengths = ntuple(axis -> norm(@view structure.lattice[axis, :]), 3)
    minimum_grid = ntuple(
        axis ->
            dimension == 2 && axis == 3 ? mesh.dimensions[3] :
            max(1, ceil(Int, density_target / lengths[axis])),
        3,
    )
    upper_grid = ntuple(
        axis ->
            dimension == 2 && axis == 3 ? minimum_grid[3] :
            Base.checked_add(minimum_grid[axis], search_radius),
        3,
    )
    step_offset = ntuple(axis -> mod(mesh.dimensions[axis] * mesh.offset_fractional[axis], 1.0), 3)
    best = nothing
    best_key = nothing
    for sizes in Iterators.product((minimum_grid[axis]:upper_grid[axis] for axis in 1:3)...)
        offset = ntuple(
            axis ->
                dimension == 2 && axis == 3 ? mesh.offset_fractional[3] :
                step_offset[axis] / sizes[axis],
            3,
        )
        candidate = DiagonalKMesh(sizes, offset)
        all(op -> diagonal_mesh_closure(candidate, op; tolerance).closed, operations) || continue
        key = (prod(sizes), sum(sizes .- minimum_grid), sizes)
        if best_key === nothing || key < best_key
            best, best_key = candidate, key
        end
    end
    best === nothing && throw(
        ArgumentError(
            "no symmetry-closed mesh meets density_target in search range $(minimum_grid) to $(upper_grid)",
        ),
    )
    original_checks = [diagonal_mesh_closure(mesh, op; tolerance) for op in operations]
    original_enumeration =
        [enumerate_diagonal_mesh_closure(mesh, op; tolerance) for op in operations]
    recommended_enumeration =
        [enumerate_diagonal_mesh_closure(best, op; tolerance) for op in operations]
    all(result -> result.closed, recommended_enumeration) ||
        error("recommended mesh failed independent point enumeration")
    all(
        first.closed == second.closed for
        (first, second) in zip(original_checks, original_enumeration)
    ) || error("mesh integer and point-enumeration checks disagree")
    return (
        original = mesh,
        recommended = best,
        original_closed = all(result -> result.closed, original_checks),
        original_checks,
        original_enumeration,
        recommended_enumeration,
        search_lower = minimum_grid,
        search_upper = upper_grid,
        grid_step_offset = step_offset,
        density_products = ntuple(axis -> lengths[axis] * best.dimensions[axis], 3),
    )
end
