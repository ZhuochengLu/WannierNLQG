# Test whether a Monkhorst-Pack integer grid closes under one reciprocal operation.
function _mesh_operation_compatible(
    mp_grid::NTuple{3, Int},
    operation::SymmetryOperation;
    tolerance::Float64,
)
    mesh = Diagonal(Float64.(collect(mp_grid)))
    reciprocal_rotation = transpose(inv(Float64.(operation.rotation_fractional)))
    integer_action = mesh * reciprocal_rotation * inv(mesh)
    return maximum(abs, integer_action .- round.(integer_action)) <= tolerance
end

# Choose a density-centered positive mesh for one lattice-vector length.
function _target_mesh_size(length::Float64, density_target::Float64)
    return max(1, floor(Int, density_target / length + 0.5))
end

"""
Screen a WIN `mp_grid` against selected crystal operations and recommend a closed mesh.

The routine uses only the WIN lattice, structure, projections, and `mp_grid`.
It never reads a QE/VASP k mesh. Candidate meshes are searched in deterministic
product/lexicographic order around the density-centered grid; `dimension=2`
fixes the third mesh entry to the input value.
"""
function screen_wannier_mesh(config::MeshScreenConfig)
    _positive_tolerance(config.symmetry_tolerance, "symmetry_tolerance")
    config.dimension in (2, 3) || throw(ArgumentError("dimension must be 2 or 3"))
    _positive_tolerance(config.density_target, "density_target")
    config.search_radius >= 0 || throw(ArgumentError("search_radius must be nonnegative"))
    _validate_configured_operation_indices(config.operation_indices)
    win_path = _required_workflow_path(config.win_file, "win_file")
    input = read_wannier_win(win_path)
    input.mp_grid === nothing && throw(ArgumentError("WIN file must define mp_grid"))
    structure = crystal_structure(input)
    operations = detect_tb_compatibility_symmetry_operations(
        structure;
        include_time_reversal = config.include_time_reversal,
        symmetry_tolerance = config.symmetry_tolerance,
    )
    selected_operation_indices =
        _selected_operation_indices(config.operation_indices, length(operations))
    lengths = [norm(input.lattice[row, :]) for row in 1:3]
    target_grid = ntuple(axis -> _target_mesh_size(lengths[axis], config.density_target), 3)
    if config.dimension == 2
        target_grid = (target_grid[1], target_grid[2], input.mp_grid[3])
    end
    candidates = NTuple{3, Int}[]
    third_lower =
        config.dimension == 2 ? input.mp_grid[3] : max(1, target_grid[3] - config.search_radius)
    third_upper = config.dimension == 2 ? input.mp_grid[3] : target_grid[3] + config.search_radius
    for first in
        max(1, target_grid[1] - config.search_radius):(target_grid[1] + config.search_radius),
        second in
        max(1, target_grid[2] - config.search_radius):(target_grid[2] + config.search_radius),
        third in third_lower:third_upper

        candidate = (first, second, third)
        all(
            index -> _mesh_operation_compatible(
                candidate,
                operations[index];
                tolerance = config.symmetry_tolerance,
            ),
            selected_operation_indices,
        ) && push!(candidates, candidate)
    end
    isempty(candidates) && throw(ArgumentError("no symmetry-closed mp_grid found in search domain"))
    sort!(
        candidates;
        by = mesh -> (prod(mesh), sum(abs.(collect(mesh) .- collect(target_grid))), mesh),
    )
    recommended_grid = first(candidates)
    original_grid_is_symmetry_closed = all(
        index -> _mesh_operation_compatible(
            input.mp_grid,
            operations[index];
            tolerance = config.symmetry_tolerance,
        ),
        selected_operation_indices,
    )
    return (
        original_mp_grid = input.mp_grid,
        recommended_grid = recommended_grid,
        original_grid_is_symmetry_closed = original_grid_is_symmetry_closed,
        operation_indices = selected_operation_indices,
        selected_operation_count = length(selected_operation_indices),
        density_products = ntuple(axis -> lengths[axis] * recommended_grid[axis], 3),
    )
end
