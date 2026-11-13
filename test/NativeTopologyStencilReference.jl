module NativeTopologyStencilReference
using LinearAlgebra
using WannierNLQG.IO: WannierCHK
"""
Neighbor weights, integer mesh displacements, Cartesian reciprocal displacements, wrapped neighbors and MMN ordering.

Validate aligned stencil and k-point dimensions; weights satisfy the Cartesian completeness relation when constructed by the stencil builder.
"""
struct FiniteDifferenceStencil
    weights::Vector{Float64}
    displacement_grid::Matrix{Int}
    displacement_cartesian::Matrix{Float64}
    neighbors::Matrix{Int}
    reciprocal_shifts::Array{Int, 3}
    overlap_order::Matrix{Int}

    function FiniteDifferenceStencil(
        weights::Vector{Float64},
        displacement_grid::Matrix{Int},
        displacement_cartesian::Matrix{Float64},
        neighbors::Matrix{Int},
        reciprocal_shifts::Array{Int, 3},
        overlap_order::Matrix{Int},
    )
        stencil_size = length(weights)
        size(displacement_grid) == (stencil_size, 3) ||
            error("displacement_grid has incompatible dimensions")
        size(displacement_cartesian) == (stencil_size, 3) ||
            error("displacement_cartesian has incompatible dimensions")
        size(neighbors, 1) == stencil_size ||
            error("neighbors first dimension must equal stencil size")
        size(reciprocal_shifts) == (3, stencil_size, size(neighbors, 2)) ||
            error("reciprocal_shifts has incompatible dimensions")
        size(overlap_order) == size(neighbors) ||
            error("overlap_order must have the same dimensions as neighbors")
        return new(
            weights,
            displacement_grid,
            displacement_cartesian,
            neighbors,
            reciprocal_shifts,
            overlap_order,
        )
    end
end

# Convert fractional CHK points to integer mesh coordinates.  A complete
# Monkhorst-Pack mesh may carry a uniform fractional offset (for example an
# even, shifted MP mesh has `k*N = integer + 1/2`).  The finite-difference
# topology only depends on differences on that mesh, so remove the common
# offset before forming integer coordinates.  Do not silently snap a distorted
# or incomplete list: every component must share one offset and the resulting
# modulo-mesh keys must cover the product mesh exactly once.
function _spin_velocity_kpt_grid_int(chk::WannierCHK)
    chk.num_kpts == prod(chk.mp_grid) ||
        error("CHK k-point count $(chk.num_kpts) does not cover mp_grid $(chk.mp_grid).")
    grid = Matrix{Int}(undef, chk.num_kpts, 3)
    mp = collect(chk.mp_grid)
    @inbounds for a in 1:3
        scaled_origin = chk.kpt_red[1, a] * mp[a]
        offset = mod(scaled_origin, 1.0)
        offset >= 1.0 - 1.0e-6 && (offset = 0.0)
        for kpoint_index in 1:chk.num_kpts
            scaled = chk.kpt_red[kpoint_index, a] * mp[a]
            value = round(Int, scaled - offset)
            abs(scaled - offset - value) <= 1e-6 || error(
                "CHK k-point $(kpoint_index), component $(a) does not share a uniform " *
                "MP offset on mp_grid $(chk.mp_grid).",
            )
            grid[kpoint_index, a] = value
        end
    end
    keys = Set{NTuple{3, Int}}()
    for kpoint_index in 1:chk.num_kpts
        key = (
            mod(grid[kpoint_index, 1], mp[1]),
            mod(grid[kpoint_index, 2], mp[2]),
            mod(grid[kpoint_index, 3], mp[3]),
        )
        key in keys && error("Duplicate CHK k-point modulo mp_grid at key=$(key).")
        push!(keys, key)
    end
    length(keys) == prod(mp) || error("CHK k-points do not cover mp_grid $(chk.mp_grid).")
    return grid
end

# Convert an integer neighbor step to Cartesian reciprocal displacement using the row reciprocal lattice and MP mesh counts.
function _spin_velocity_bk_cart_from_grid(
    bk_grid::AbstractVector{<:Integer},
    recip_lattice::Matrix{Float64},
    mp_grid::NTuple{3, Int},
)
    cart = zeros(Float64, 3)
    @inbounds for a in 1:3, b in 1:3
        cart[b] += bk_grid[a] * recip_lattice[a, b] / mp_grid[a]
    end
    return cart
end

# Enumerate nonzero neighbor steps in the search supercell and group by Cartesian length within the mesh tolerance.
function _spin_velocity_shells(
    recip_lattice::Matrix{Float64},
    mp_grid::NTuple{3, Int},
    k_mesh_tolerance::Float64,
    search_supercell::Int,
)
    limits = search_supercell .* collect(mp_grid)
    candidates = Tuple{Float64, NTuple{3, Int}, NTuple{3, Float64}}[]
    for i in (-limits[1]):limits[1], j in (-limits[2]):limits[2], k in (-limits[3]):limits[3]
        (i == 0 && j == 0 && k == 0) && continue
        grid = (i, j, k)
        cart_vec = _spin_velocity_bk_cart_from_grid(collect(grid), recip_lattice, mp_grid)
        len = norm(cart_vec)
        len <= k_mesh_tolerance && continue
        push!(candidates, (len, grid, (cart_vec[1], cart_vec[2], cart_vec[3])))
    end
    sort!(candidates; by = x -> (x[1], x[2]))
    shells_grid = Matrix{Int}[]
    shells_cart = Matrix{Float64}[]
    idx = 1
    while idx <= length(candidates)
        start = idx
        len0 = candidates[idx][1]
        while idx <= length(candidates) && abs(candidates[idx][1] - len0) <= k_mesh_tolerance
            idx += 1
        end
        count = idx - start
        grid_mat = Matrix{Int}(undef, count, 3)
        cart_mat = Matrix{Float64}(undef, count, 3)
        for (row, item) in enumerate(candidates[start:(idx - 1)])
            grid = item[2]
            cart = item[3]
            grid_mat[row, :] .= grid
            cart_mat[row, :] .= cart
        end
        push!(shells_grid, grid_mat)
        push!(shells_cart, cart_mat)
    end
    return shells_grid, shells_cart
end

# Solve shell weights by SVD to reproduce the Cartesian identity; reject singular/incomplete systems or return status symbols when failok.
function _spin_velocity_shell_weights(
    shells_grid::Vector{Matrix{Int}},
    shells_cart::Vector{Matrix{Float64}},
    stencil_completeness_tolerance::Float64;
    failok::Bool,
)
    nshell = length(shells_cart)
    shell_system = Matrix{Float64}(undef, nshell, 9)
    shell_mats = Vector{Matrix{Float64}}(undef, nshell)
    for ishell in 1:nshell
        mat = transpose(shells_cart[ishell]) * shells_cart[ishell]
        shell_mats[ishell] = mat
        shell_system[ishell, :] .= reshape(mat, 9)
    end
    factorization = svd(transpose(shell_system); full = false)
    if isempty(factorization.S) || any(s -> s < 1e-10 || s > 1e10, factorization.S)
        failok && return :singular
        error("finite-difference shell matrix is singular; SVD values=$(factorization.S).")
    end
    target = reshape(Matrix{Float64}(I, 3, 3), 9)
    weight_shell = factorization.Vt' * ((factorization.U' * target) ./ factorization.S)
    check_eye = zeros(Float64, 3, 3)
    for ishell in 1:nshell
        check_eye .+= weight_shell[ishell] .* shell_mats[ishell]
    end
    complete_error = norm(check_eye - Matrix{Float64}(I, 3, 3))
    if complete_error > stencil_completeness_tolerance
        failok && return :incomplete
        error(
            "finite-difference shell completeness error $(complete_error) exceeds $(stencil_completeness_tolerance).",
        )
    end

    num_neighbors = sum(size(shell, 1) for shell in shells_grid)
    wk = Vector{Float64}(undef, num_neighbors)
    bk_grid = Matrix{Int}(undef, num_neighbors, 3)
    bk_cart = Matrix{Float64}(undef, num_neighbors, 3)
    row = 1
    for ishell in 1:nshell
        for ivec in 1:size(shells_grid[ishell], 1)
            wk[row] = weight_shell[ishell]
            bk_grid[row, :] .= shells_grid[ishell][ivec, :]
            bk_cart[row, :] .= shells_cart[ishell][ivec, :]
            row += 1
        end
    end
    return (
        weights = wk,
        displacement_grid = bk_grid,
        displacement_cartesian = bk_cart,
        completeness_error = complete_error,
    )
end

# Wrap displaced CHK mesh points, returning neighbor indices and integer G shifts; reject duplicates and missing neighbors.
function _spin_velocity_find_reciprocal_shifts_and_neighbors(
    chk::WannierCHK,
    displacement_grid::Matrix{Int},
)
    k_grid = _spin_velocity_kpt_grid_int(chk)
    mp = collect(chk.mp_grid)
    key_to_ik = Dict{NTuple{3, Int}, Int}()
    for kpoint_index in 1:chk.num_kpts
        key = (
            mod(k_grid[kpoint_index, 1], mp[1]),
            mod(k_grid[kpoint_index, 2], mp[2]),
            mod(k_grid[kpoint_index, 3], mp[3]),
        )
        haskey(key_to_ik, key) && error("Duplicate CHK k-point modulo mp_grid at key=$(key).")
        key_to_ik[key] = kpoint_index
    end
    num_neighbors = size(displacement_grid, 1)
    neighbors = Matrix{Int}(undef, num_neighbors, chk.num_kpts)
    reciprocal_shifts = Array{Int, 3}(undef, 3, num_neighbors, chk.num_kpts)
    for kpoint_index in 1:chk.num_kpts
        for ib in 1:num_neighbors
            target = k_grid[kpoint_index, :] .+ displacement_grid[ib, :]
            wrapped = (mod(target[1], mp[1]), mod(target[2], mp[2]), mod(target[3], mp[3]))
            iknb = get(key_to_ik, wrapped, 0)
            iknb == 0 && error(
                "Could not find finite-difference neighbour $(wrapped) for kpoint_index=$(kpoint_index), ib=$(ib).",
            )
            neighbors[ib, kpoint_index] = iknb
            for a in 1:3
                diff = target[a] - k_grid[iknb, a]
                mod(diff, mp[a]) == 0 || error(
                    "Internal non-integer G for kpoint_index=$(kpoint_index), ib=$(ib), component=$(a).",
                )
                reciprocal_shifts[a, ib, kpoint_index] = div(diff, mp[a])
            end
        end
    end
    return neighbors, reciprocal_shifts
end

"""
Select reciprocal shells whose weighted Cartesian dyadics reproduce the identity, then build wrapped CHK neighbors.

Cartesian displacements use the reciprocal lattice's inverse-length units; reject singular or incomplete shell systems and off-mesh points.
"""
function build_finite_difference_stencil(
    chk::WannierCHK;
    k_mesh_tolerance::Float64 = 1e-7,
    stencil_completeness_tolerance::Float64 = 1e-5,
    search_supercell::Int = 2,
)
    shells_grid, shells_cart =
        _spin_velocity_shells(chk.recip_lattice, chk.mp_grid, k_mesh_tolerance, search_supercell)
    selected_grid = Matrix{Int}[]
    selected_cart = Matrix{Float64}[]
    for ishell in 1:length(shells_grid)
        trial_grid = vcat(selected_grid, [shells_grid[ishell]])
        trial_cart = vcat(selected_cart, [shells_cart[ishell]])
        result = _spin_velocity_shell_weights(
            trial_grid,
            trial_cart,
            stencil_completeness_tolerance;
            failok = true,
        )
        if result === :singular
            continue
        elseif result === :incomplete
            push!(selected_grid, shells_grid[ishell])
            push!(selected_cart, shells_cart[ishell])
            continue
        else
            neighbors, reciprocal_shifts =
                _spin_velocity_find_reciprocal_shifts_and_neighbors(chk, result.displacement_grid)
            reorder = zeros(Int, length(result.weights), chk.num_kpts)
            return FiniteDifferenceStencil(
                result.weights,
                result.displacement_grid,
                result.displacement_cartesian,
                neighbors,
                reciprocal_shifts,
                reorder,
            )
        end
    end
    error("Could not find a complete finite-difference stencil shell set.")
end

end
