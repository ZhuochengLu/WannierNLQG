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

# Convert fractional CHK points to integer mesh coordinates, rejecting residuals above `1e-6`.
function _spin_velocity_kpt_grid_int(chk::WannierCHK)
    grid = Matrix{Int}(undef, chk.num_kpts, 3)
    mp = collect(chk.mp_grid)
    @inbounds for kpoint_index in 1:chk.num_kpts, a in 1:3
        value = round(Int, chk.kpt_red[kpoint_index, a] * mp[a])
        abs(chk.kpt_red[kpoint_index, a] * mp[a] - value) <= 1e-6 ||
            error("CHK k-point $(kpoint_index), component $(a) is not on mp_grid $(chk.mp_grid).")
        grid[kpoint_index, a] = value
    end
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

"""
Match each generated neighbor/G shift to one MMN overlap entry and return an aligned stencil.

Reject dimension mismatches, missing neighbors or inconsistent topology rather than changing the finite-difference weights.
"""
function match_finite_difference_stencil_to_mmn(
    stencil::FiniteDifferenceStencil,
    chk::WannierCHK,
    mmn::WannierMMN,
)
    mmn.num_kpts == chk.num_kpts ||
        error("MMN num_kpts=$(mmn.num_kpts) does not match CHK num_kpts=$(chk.num_kpts).")
    mmn.num_neighbors == length(stencil.weights) || error(
        "MMN num_neighbors=$(mmn.num_neighbors) does not match finite-difference stencil size=$(length(stencil.weights)).",
    )
    k_grid = _spin_velocity_kpt_grid_int(chk)
    mp = collect(chk.mp_grid)
    num_neighbors = length(stencil.weights)
    reorder = Matrix{Int}(undef, num_neighbors, chk.num_kpts)
    for kpoint_index in 1:chk.num_kpts
        mmn_map = Dict{NTuple{3, Int}, Int}()
        for ib_src in 1:mmn.num_neighbors
            iknb = mmn.neighbors[ib_src, kpoint_index]
            1 <= iknb <= chk.num_kpts || error(
                "MMN neighbour $(iknb) output of range at kpoint_index=$(kpoint_index), ib=$(ib_src).",
            )
            b =
                k_grid[iknb, :] .- k_grid[kpoint_index, :] .+
                (mmn.reciprocal_shifts[:, ib_src, kpoint_index] .* mp)
            key = (b[1], b[2], b[3])
            haskey(mmn_map, key) &&
                error("Duplicate MMN bk_grid $(key) at kpoint_index=$(kpoint_index).")
            mmn_map[key] = ib_src
        end
        for ib in 1:num_neighbors
            key = (
                stencil.displacement_grid[ib, 1],
                stencil.displacement_grid[ib, 2],
                stencil.displacement_grid[ib, 3],
            )
            reorder[ib, kpoint_index] = get(mmn_map, key, 0)
            reorder[ib, kpoint_index] == 0 && error(
                "MMN block for finite-difference bk_grid $(key) is missing at kpoint_index=$(kpoint_index).",
            )
        end
    end
    return FiniteDifferenceStencil(
        stencil.weights,
        stencil.displacement_grid,
        stencil.displacement_cartesian,
        stencil.neighbors,
        stencil.reciprocal_shifts,
        reorder,
    )
end

# Reject inconsistent SPN, CHK and EIG band/k-point dimensions before constructing spin-weighted operators.
function _spin_velocity_validate_inputs(
    spn::WannierSPN,
    chk::WannierCHK,
    eig::WannierEIG,
    mmn::WannierMMN,
)
    spn.num_bands == chk.num_bands ||
        error("SPN num_bands=$(spn.num_bands) does not match CHK num_bands=$(chk.num_bands).")
    spn.num_kpts == chk.num_kpts ||
        error("SPN num_kpts=$(spn.num_kpts) does not match CHK num_kpts=$(chk.num_kpts).")
    eig.num_bands == chk.num_bands ||
        error("EIG num_bands=$(eig.num_bands) does not match CHK num_bands=$(chk.num_bands).")
    eig.num_kpts == chk.num_kpts ||
        error("EIG num_kpts=$(eig.num_kpts) does not match CHK num_kpts=$(chk.num_kpts).")
    mmn.num_bands == chk.num_bands ||
        error("MMN num_bands=$(mmn.num_bands) does not match CHK num_bands=$(chk.num_bands).")
    mmn.num_kpts == chk.num_kpts ||
        error("MMN num_kpts=$(mmn.num_kpts) does not match CHK num_kpts=$(chk.num_kpts).")
    return nothing
end

# Rotate a DFT-gauge operator with CHK band-to-Wannier matrices into caller-owned output using temporary multiplication storage.
function _spin_velocity_wannier_gauge!(
    output::AbstractArray{ComplexF64, 3},
    mat::AbstractArray{ComplexF64, 3},
    chk::WannierCHK,
    ik_left::Int,
    ik_right::Int,
    temporary::Matrix{ComplexF64},
)
    size(output) == (chk.num_orbitals, chk.num_orbitals, size(mat, 3)) ||
        error("Wannier-gauge output has incompatible size $(size(output)).")
    size(mat, 1) == chk.num_bands && size(mat, 2) == chk.num_bands ||
        error("Hamiltonian-gauge matrix has incompatible size $(size(mat)).")
    left_gauge = @view chk.v_matrix[:, :, ik_left]
    right_gauge = @view chk.v_matrix[:, :, ik_right]
    @inbounds for comp in 1:size(mat, 3)
        input_matrix = @view mat[:, :, comp]
        output_matrix = @view output[:, :, comp]
        mul!(temporary, input_matrix, right_gauge)
        mul!(output_matrix, left_gauge', temporary)
    end
    return output
end

# Construct Wannier-gauge spin-times-Hamiltonian matrices from SPN, CHK gauges and EIG energies.
function _spin_velocity_build_spin_hamiltonian_q(
    spn::WannierSPN,
    chk::WannierCHK,
    eigenvalues::WannierEIG,
)
    spin_hamiltonian_q = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3, chk.num_kpts)
    spin_hamiltonian_dft = zeros(ComplexF64, chk.num_bands, chk.num_bands, 3)
    temporary = zeros(ComplexF64, chk.num_bands, chk.num_orbitals)
    @inbounds for kpoint_index in 1:chk.num_kpts
        for s in 1:3, n in 1:chk.num_bands, m in 1:chk.num_bands
            spin_hamiltonian_dft[m, n, s] =
                spn.data[m, n, s, kpoint_index] * eigenvalues.data[n, kpoint_index]
        end
        output = @view spin_hamiltonian_q[:, :, :, kpoint_index]
        _spin_velocity_wannier_gauge!(
            output,
            spin_hamiltonian_dft,
            chk,
            kpoint_index,
            kpoint_index,
            temporary,
        )
    end
    return spin_hamiltonian_q
end

# Accumulate spin-position overlaps with the matched finite-difference stencil and neighboring CHK gauges.
function _spin_velocity_build_spin_position_q(
    spn::WannierSPN,
    chk::WannierCHK,
    eigenvalues::Union{Nothing, WannierEIG},
    mmn::WannierMMN,
    stencil::FiniteDifferenceStencil,
)
    spin_position_q = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3, 3, chk.num_kpts)
    source_operator_dft = zeros(ComplexF64, chk.num_bands, chk.num_bands, 3)
    source_overlap_dft = similar(source_operator_dft)
    central_operator_wannier = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3)
    neighbor_difference_wannier = similar(central_operator_wannier)
    temporary = zeros(ComplexF64, chk.num_bands, chk.num_orbitals)
    num_neighbors = length(stencil.weights)
    @inbounds for kpoint_index in 1:chk.num_kpts
        for s in 1:3, n in 1:chk.num_bands, m in 1:chk.num_bands
            factor = isnothing(eigenvalues) ? 1.0 : eigenvalues.data[n, kpoint_index]
            source_operator_dft[m, n, s] = spn.data[m, n, s, kpoint_index] * factor
        end
        _spin_velocity_wannier_gauge!(
            central_operator_wannier,
            source_operator_dft,
            chk,
            kpoint_index,
            kpoint_index,
            temporary,
        )
        for ib in 1:num_neighbors
            ib_src = stencil.overlap_order[ib, kpoint_index]
            iknb = mmn.neighbors[ib_src, kpoint_index]
            overlap_matrix = @view mmn.data[:, :, ib_src, kpoint_index]
            for s in 1:3
                @views mul!(
                    source_overlap_dft[:, :, s],
                    source_operator_dft[:, :, s],
                    overlap_matrix,
                )
            end
            _spin_velocity_wannier_gauge!(
                neighbor_difference_wannier,
                source_overlap_dft,
                chk,
                kpoint_index,
                iknb,
                temporary,
            )
            for orbital_column in 1:chk.num_orbitals, orbital_row in 1:chk.num_orbitals, s in 1:3
                neighbor_difference_wannier[orbital_row, orbital_column, s] -=
                    central_operator_wannier[orbital_row, orbital_column, s]
            end
            for s in 1:3,
                a in 1:3,
                orbital_column in 1:chk.num_orbitals,
                orbital_row in 1:chk.num_orbitals

                spin_position_q[orbital_row, orbital_column, a, s, kpoint_index] +=
                    1.0im *
                    neighbor_difference_wannier[orbital_row, orbital_column, s] *
                    stencil.weights[ib] *
                    stencil.displacement_cartesian[ib, a]
            end
        end
    end
    return spin_position_q
end

# Build SR and SHR together while streaming the overlap file exactly once.
function _spin_velocity_build_spin_position_pair_q_streaming(
    spn::WannierSPN,
    chk::WannierCHK,
    eigenvalues::WannierEIG,
    overlap_file::AbstractString,
    stencil::FiniteDifferenceStencil,
    ;
    mmap_output::Bool = false,
)
    output_dimensions = (chk.num_orbitals, chk.num_orbitals, 3, 3, chk.num_kpts)
    spin_position_q =
        mmap_output ? _mmap_complex_zeros(output_dimensions) : zeros(ComplexF64, output_dimensions)
    spin_hamiltonian_position_q =
        mmap_output ? _mmap_complex_zeros(output_dimensions) : zeros(ComplexF64, output_dimensions)
    spin_operator_dft = zeros(ComplexF64, chk.num_bands, chk.num_bands, 3)
    spin_hamiltonian_operator_dft = similar(spin_operator_dft)
    spin_overlap_dft = similar(spin_operator_dft)
    spin_hamiltonian_overlap_dft = similar(spin_operator_dft)
    central_spin_wannier = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3)
    central_spin_hamiltonian_wannier = similar(central_spin_wannier)
    spin_difference_wannier = similar(central_spin_wannier)
    spin_hamiltonian_difference_wannier = similar(central_spin_wannier)
    temporary = zeros(ComplexF64, chk.num_bands, chk.num_orbitals)
    k_grid = _spin_velocity_kpt_grid_int(chk)
    mp = collect(chk.mp_grid)
    displacement_to_stencil = Dict(
        (
            stencil.displacement_grid[ib, 1],
            stencil.displacement_grid[ib, 2],
            stencil.displacement_grid[ib, 3],
        ) => ib for ib in eachindex(stencil.weights)
    )

    prepared_kpoint = Ref(0)
    foreach_wannier_mmn_block(
        overlap_file;
        expected_num_bands = chk.num_bands,
        expected_num_kpoints = chk.num_kpts,
    ) do kpoint_index, iknb, shift, overlap_matrix
        if prepared_kpoint[] != kpoint_index
            prepared_kpoint[] = kpoint_index
            nb = chk.num_bands
            @inbounds begin
                for s in 1:3, n in 1:nb, m in 1:nb
                    spin_value = spn.data[m, n, s, kpoint_index]
                    spin_operator_dft[m, n, s] = spin_value * 1.0
                    spin_hamiltonian_operator_dft[m, n, s] =
                        spin_value * eigenvalues.data[n, kpoint_index]
                end
                _spin_velocity_wannier_gauge!(
                    central_spin_wannier,
                    spin_operator_dft,
                    chk,
                    kpoint_index,
                    kpoint_index,
                    temporary,
                )
                _spin_velocity_wannier_gauge!(
                    central_spin_hamiltonian_wannier,
                    spin_hamiltonian_operator_dft,
                    chk,
                    kpoint_index,
                    kpoint_index,
                    temporary,
                )
            end
        end
        @inbounds begin
            displacement = (
                k_grid[iknb, 1] - k_grid[kpoint_index, 1] + shift[1] * mp[1],
                k_grid[iknb, 2] - k_grid[kpoint_index, 2] + shift[2] * mp[2],
                k_grid[iknb, 3] - k_grid[kpoint_index, 3] + shift[3] * mp[3],
            )
            ib = get(displacement_to_stencil, displacement, 0)
            if ib != 0
                for s in 1:3
                    @views mul!(
                        spin_overlap_dft[:, :, s],
                        spin_operator_dft[:, :, s],
                        overlap_matrix,
                    )
                    @views mul!(
                        spin_hamiltonian_overlap_dft[:, :, s],
                        spin_hamiltonian_operator_dft[:, :, s],
                        overlap_matrix,
                    )
                end
                _spin_velocity_wannier_gauge!(
                    spin_difference_wannier,
                    spin_overlap_dft,
                    chk,
                    kpoint_index,
                    iknb,
                    temporary,
                )
                _spin_velocity_wannier_gauge!(
                    spin_hamiltonian_difference_wannier,
                    spin_hamiltonian_overlap_dft,
                    chk,
                    kpoint_index,
                    iknb,
                    temporary,
                )
                for orbital_column in 1:chk.num_orbitals,
                    orbital_row in 1:chk.num_orbitals,
                    s in 1:3

                    spin_difference_wannier[orbital_row, orbital_column, s] -=
                        central_spin_wannier[orbital_row, orbital_column, s]
                    spin_hamiltonian_difference_wannier[orbital_row, orbital_column, s] -=
                        central_spin_hamiltonian_wannier[orbital_row, orbital_column, s]
                end
                for s in 1:3,
                    a in 1:3,
                    orbital_column in 1:chk.num_orbitals,
                    orbital_row in 1:chk.num_orbitals

                    spin_position_q[orbital_row, orbital_column, a, s, kpoint_index] +=
                        1.0im *
                        spin_difference_wannier[orbital_row, orbital_column, s] *
                        stencil.weights[ib] *
                        stencil.displacement_cartesian[ib, a]
                    spin_hamiltonian_position_q[orbital_row, orbital_column, a, s, kpoint_index] +=
                        1.0im *
                        spin_hamiltonian_difference_wannier[orbital_row, orbital_column, s] *
                        stencil.weights[ib] *
                        stencil.displacement_cartesian[ib, a]
                end
            end
        end
    end
    return spin_position_q, spin_hamiltonian_position_q
end

"""
Transform an operator with trailing k-point axis to R blocks using `exp(-2pi*i*R.k)/Nk`.

Preserve leading orbital/Cartesian axes and units, validate shapes, optionally allocate mapped output, and reject enabled roundtrip errors above `atol`. Return values and diagnostics separately.
"""
function spin_velocity_q_to_r_diagnostics(
    reciprocal_space_values::Array{ComplexF64, N},
    chk::WannierCHK,
    model::TightBindingModel;
    atol::Float64 = 1e-8,
    check_roundtrip::Bool = true,
    label::AbstractString = "input_matrix",
    mmap_output::Bool = false,
) where {N}
    N >= 3 || error("$(label)_q must have at least 3 dimensions with k as the last dimension.")
    size(reciprocal_space_values, N) == chk.num_kpts || error(
        "$(label)_q last dimension $(size(reciprocal_space_values, N)) does not match CHK num_kpts=$(chk.num_kpts).",
    )
    size(reciprocal_space_values, 1) == chk.num_orbitals &&
    size(reciprocal_space_values, 2) == chk.num_orbitals || error(
        "$(label)_q has incompatible leading dimensions $(size(reciprocal_space_values)[1:2]).",
    )
    chk.num_orbitals == model.num_orbitals || error(
        "CHK num_orbitals=$(chk.num_orbitals) does not match TB num_orbitals=$(model.num_orbitals).",
    )

    nrow = div(length(reciprocal_space_values), chk.num_kpts)
    reciprocal_space_matrix = reshape(reciprocal_space_values, nrow, chk.num_kpts)
    flattened_real_space_values =
        mmap_output ? _mmap_complex_zeros((nrow, model.num_r_vectors)) :
        zeros(ComplexF64, nrow, model.num_r_vectors)
    scale = 1.0 / chk.num_kpts
    @inbounds for r_vector_index in 1:model.num_r_vectors
        r_vector = @view model.r_vectors[:, r_vector_index]
        xr = @view flattened_real_space_values[:, r_vector_index]
        for kpoint_index in 1:chk.num_kpts
            kpoint = @view chk.kpt_red[kpoint_index, :]
            weighted_phase = scale * cis(-2.0 * pi * dot(r_vector, kpoint))
            xr .+= weighted_phase .* (@view reciprocal_space_matrix[:, kpoint_index])
        end
    end

    max_roundtrip_error = 0.0
    if check_roundtrip
        back = zeros(ComplexF64, nrow)
        @inbounds for kpoint_index in 1:chk.num_kpts
            fill!(back, COMPLEX_ZERO)
            kpoint = @view chk.kpt_red[kpoint_index, :]
            for r_vector_index in 1:model.num_r_vectors
                r_vector = @view model.r_vectors[:, r_vector_index]
                phase = cis(2.0 * pi * dot(r_vector, kpoint)) / model.r_degeneracies[r_vector_index]
                back .+= phase .* (@view flattened_real_space_values[:, r_vector_index])
            end
            max_roundtrip_error = max(
                max_roundtrip_error,
                maximum(abs, back .- (@view reciprocal_space_matrix[:, kpoint_index])),
            )
        end
        max_roundtrip_error <= atol ||
            error("$(label) q->R->q round-trip error $(max_roundtrip_error) exceeds atol=$(atol).")
    end
    dims_r = (Base.front(size(reciprocal_space_values))..., model.num_r_vectors)
    return (
        real_space_values = reshape(flattened_real_space_values, dims_r),
        diagnostics = SpinVelocityTransformDiagnostics(max_roundtrip_error),
    )
end

# Allocate zeroed ComplexF64 storage backed by a temporary mapped file of the exact requested shape.
function _mmap_complex_zeros(dimensions::NTuple{N, Int}) where {N}
    _, io = mktemp(; cleanup = true)
    truncate(io, sizeof(ComplexF64) * prod(dimensions))
    output = Mmap.mmap(io, Array{ComplexF64, N}, dimensions)
    close(io)
    fill!(output, COMPLEX_ZERO)
    return output
end

"""
Return the real-space operator array from the normalized q-to-R transform, retaining dimension and optional roundtrip checks.

Cartesian axes and operator units pass through unchanged; the last dimension changes from k points to R vectors.
"""
function spin_velocity_q_to_r(
    reciprocal_space_values::Array{ComplexF64, N},
    chk::WannierCHK,
    model::TightBindingModel;
    atol::Float64 = 1e-8,
    check_roundtrip::Bool = true,
    label::AbstractString = "input_matrix",
) where {N}
    return spin_velocity_q_to_r_diagnostics(
        reciprocal_space_values,
        chk,
        model;
        atol = atol,
        check_roundtrip = check_roundtrip,
        label = label,
    ).real_space_values
end

# Store the established TB-block spin q-to-R policy used by public MatrixElements APIs.
struct _TBSpinQToRTransform
    chk::WannierCHK
    model::TightBindingModel
    atol::Float64
    check_roundtrip::Bool
end

# Apply the unchanged public TB-block q-to-R conversion through typed cold-path dispatch.
function _transform_spin_q_to_r(
    transform::_TBSpinQToRTransform,
    reciprocal_space_values::Array{ComplexF64, N},
    label::AbstractString,
) where {N}
    return spin_velocity_q_to_r_diagnostics(
        reciprocal_space_values,
        transform.chk,
        transform.model;
        atol = transform.atol,
        check_roundtrip = transform.check_roundtrip,
        label = label,
    )
end

# Construct all in-memory spin-family q arrays and dispatch each through one typed transform.
function _compute_spin_velocity_real_space_with_transform(
    model::TightBindingModel,
    spn::WannierSPN,
    chk::WannierCHK,
    eig::WannierEIG,
    mmn::WannierMMN,
    transform;
    k_mesh_tolerance::Float64 = 1e-7,
    stencil_completeness_tolerance::Float64 = 1e-5,
    search_supercell::Int = 2,
)
    _spin_velocity_validate_inputs(spn, chk, eig, mmn)
    chk.num_orbitals == model.num_orbitals || error(
        "CHK num_orbitals=$(chk.num_orbitals) does not match TB num_orbitals=$(model.num_orbitals).",
    )
    stencil = build_finite_difference_stencil(
        chk;
        k_mesh_tolerance = k_mesh_tolerance,
        stencil_completeness_tolerance = stencil_completeness_tolerance,
        search_supercell = search_supercell,
    )
    stencil = match_finite_difference_stencil_to_mmn(stencil, chk, mmn)

    # Transform one reciprocal-space operator at a time.  SR and SHR are rank-5
    # arrays, so retaining all four q-space operators until the last transform
    # needlessly doubles peak memory for production meshes.
    spin_q = spn_to_wannier_gauge_q(spn, chk; hermitize = true)
    spin_transform_result = _transform_spin_q_to_r(transform, spin_q, "SS")
    spin_q = nothing
    spin_hamiltonian_q = _spin_velocity_build_spin_hamiltonian_q(spn, chk, eig)
    spin_hamiltonian_transform_result = _transform_spin_q_to_r(transform, spin_hamiltonian_q, "SH")
    spin_hamiltonian_q = nothing
    spin_position_q = _spin_velocity_build_spin_position_q(spn, chk, nothing, mmn, stencil)
    spin_position_transform_result = _transform_spin_q_to_r(transform, spin_position_q, "SR")
    spin_position_q = nothing
    GC.gc(false)
    spin_hamiltonian_position_q = _spin_velocity_build_spin_position_q(spn, chk, eig, mmn, stencil)
    spin_hamiltonian_position_transform_result =
        _transform_spin_q_to_r(transform, spin_hamiltonian_position_q, "SHR")
    diagnostics = SpinVelocityRealSpaceDiagnostics(
        spin_transform_result.diagnostics.max_roundtrip_error,
        spin_hamiltonian_transform_result.diagnostics.max_roundtrip_error,
        spin_position_transform_result.diagnostics.max_roundtrip_error,
        spin_hamiltonian_position_transform_result.diagnostics.max_roundtrip_error,
    )
    return SpinVelocityRealSpaceData(
        SpinRealSpaceData(spin_transform_result.real_space_values; copy_data = false),
        spin_hamiltonian_transform_result.real_space_values,
        spin_position_transform_result.real_space_values,
        spin_hamiltonian_position_transform_result.real_space_values,
        diagnostics,
    )
end

"""
    compute_spin_velocity_real_space(model, spn, chk, eig, mmn; kwargs...)

Construct the real-space inputs for Qiao spin velocity in the package's fixed
Convention II (`R_only`) Bloch basis. Neighbor overlap terms in `SR` and `SHR`
do not carry a local Wannier-center phase. Centered/WCC Convention I is not
implemented by this API.
"""
function compute_spin_velocity_real_space(
    model::TightBindingModel,
    spn::WannierSPN,
    chk::WannierCHK,
    eig::WannierEIG,
    mmn::WannierMMN;
    atol::Float64 = 1e-8,
    check_roundtrip::Bool = true,
    k_mesh_tolerance::Float64 = 1e-7,
    stencil_completeness_tolerance::Float64 = 1e-5,
    search_supercell::Int = 2,
)
    transform = _TBSpinQToRTransform(chk, model, atol, check_roundtrip)
    return _compute_spin_velocity_real_space_with_transform(
        model,
        spn,
        chk,
        eig,
        mmn,
        transform;
        k_mesh_tolerance = k_mesh_tolerance,
        stencil_completeness_tolerance = stencil_completeness_tolerance,
        search_supercell = search_supercell,
    )
end

# Construct streaming spin-family q arrays and dispatch each through one typed transform.
function _compute_spin_velocity_real_space_streaming_with_transform(
    model::TightBindingModel,
    spn::WannierSPN,
    chk::WannierCHK,
    eig::WannierEIG,
    overlap_file::AbstractString,
    transform;
    k_mesh_tolerance::Float64 = 1e-7,
    stencil_completeness_tolerance::Float64 = 1e-5,
    search_supercell::Int = 2,
)
    spn.num_bands == chk.num_bands || error("SPN/CHK band counts do not match.")
    spn.num_kpts == chk.num_kpts || error("SPN/CHK k-point counts do not match.")
    eig.num_bands == chk.num_bands || error("EIG/CHK band counts do not match.")
    eig.num_kpts == chk.num_kpts || error("EIG/CHK k-point counts do not match.")
    stencil = build_finite_difference_stencil(
        chk;
        k_mesh_tolerance = k_mesh_tolerance,
        stencil_completeness_tolerance = stencil_completeness_tolerance,
        search_supercell = search_supercell,
    )

    spin_q = spn_to_wannier_gauge_q(spn, chk; hermitize = true)
    spin_result = _transform_spin_q_to_r(transform, spin_q, "SS")
    spin_q = nothing
    GC.gc(false)

    spin_hamiltonian_q = _spin_velocity_build_spin_hamiltonian_q(spn, chk, eig)
    spin_hamiltonian_result = _transform_spin_q_to_r(transform, spin_hamiltonian_q, "SH")
    spin_hamiltonian_q = nothing
    GC.gc(false)

    spin_position_q, spin_hamiltonian_position_q =
        _spin_velocity_build_spin_position_pair_q_streaming(
            spn,
            chk,
            eig,
            overlap_file,
            stencil;
            mmap_output = false,
        )
    spin_position_result = _transform_spin_q_to_r(transform, spin_position_q, "SR")
    spin_position_q = nothing
    GC.gc(true)

    spin_hamiltonian_position_result =
        _transform_spin_q_to_r(transform, spin_hamiltonian_position_q, "SHR")
    diagnostics = SpinVelocityRealSpaceDiagnostics(
        spin_result.diagnostics.max_roundtrip_error,
        spin_hamiltonian_result.diagnostics.max_roundtrip_error,
        spin_position_result.diagnostics.max_roundtrip_error,
        spin_hamiltonian_position_result.diagnostics.max_roundtrip_error,
    )
    return SpinVelocityRealSpaceData(
        SpinRealSpaceData(spin_result.real_space_values; copy_data = false),
        spin_hamiltonian_result.real_space_values,
        spin_position_result.real_space_values,
        spin_hamiltonian_position_result.real_space_values,
        diagnostics,
    )
end

"""
Compute spin velocity real space streaming.
"""
function compute_spin_velocity_real_space_streaming(
    model::TightBindingModel,
    spn::WannierSPN,
    chk::WannierCHK,
    eig::WannierEIG,
    overlap_file::AbstractString;
    atol::Float64 = 1e-8,
    check_roundtrip::Bool = true,
    k_mesh_tolerance::Float64 = 1e-7,
    stencil_completeness_tolerance::Float64 = 1e-5,
    search_supercell::Int = 2,
)
    transform = _TBSpinQToRTransform(chk, model, atol, check_roundtrip)
    return _compute_spin_velocity_real_space_streaming_with_transform(
        model,
        spn,
        chk,
        eig,
        overlap_file,
        transform;
        k_mesh_tolerance = k_mesh_tolerance,
        stencil_completeness_tolerance = stencil_completeness_tolerance,
        search_supercell = search_supercell,
    )
end
# Fill operator components from weighted R-space sums, respecting the plan's active Cartesian channels.
function _fourier_operator!(
    output::Array{ComplexF64, N},
    real_space_values::AbstractArray{ComplexF64, M},
    model::TightBindingModel,
    fourier_factors::Vector{ComplexF64},
    plan::MatrixElementPlan,
    kind::MatrixElementKind,
) where {N, M}
    N == 3 || error("Compact R->k spin output must have rank 3; got $(N).")
    size(output, 1) == size(real_space_values, 1) &&
    size(output, 2) == size(real_space_values, 2) || error(
        "R->k output orbital dimensions $(size(output)[1:2]) are incompatible with input $(size(real_space_values)[1:2]).",
    )
    size(real_space_values, M) == model.num_r_vectors || error(
        "R-space array last dimension $(size(real_space_values, M)) != num_r_vectors=$(model.num_r_vectors).",
    )
    if kind == SPIN_TIMES_HAMILTONIAN
        for direction in 1:3
            _axis_required(plan, kind, direction) || continue
            channel = _axis_channel(plan, kind, direction)
            fill!(@view(output[:, :, channel]), COMPLEX_ZERO)
        end
        @inbounds for r_vector_index in 1:model.num_r_vectors
            fourier_factor = fourier_factors[r_vector_index]
            for direction in 1:3
                _axis_required(plan, kind, direction) || continue
                channel = _axis_channel(plan, kind, direction)
                for orbital_column in axes(output, 2), orbital_row in axes(output, 1)
                    output[orbital_row, orbital_column, channel] +=
                        fourier_factor *
                        real_space_values[orbital_row, orbital_column, direction, r_vector_index]
                end
            end
        end
    elseif kind in (SPIN_TIMES_POSITION, SPIN_TIMES_HAMILTONIAN_POSITION)
        for first_direction in 1:plan.spatial_dimension, second_direction in 1:3
            _pair_required(plan, kind, first_direction, second_direction) || continue
            channel = _pair_channel(plan, kind, first_direction, second_direction)
            fill!(@view(output[:, :, channel]), COMPLEX_ZERO)
        end
        @inbounds for r_vector_index in 1:model.num_r_vectors
            fourier_factor = fourier_factors[r_vector_index]
            for first_direction in 1:plan.spatial_dimension, second_direction in 1:3
                _pair_required(plan, kind, first_direction, second_direction) || continue
                channel = _pair_channel(plan, kind, first_direction, second_direction)
                for orbital_column in axes(output, 2), orbital_row in axes(output, 1)
                    output[orbital_row, orbital_column, channel] +=
                        fourier_factor * real_space_values[
                            orbital_row,
                            orbital_column,
                            first_direction,
                            second_direction,
                            r_vector_index,
                        ]
                end
            end
        end
    else
        error("Unsupported spin-operator kind $(kind).")
    end
    return output
end

# Rotate operator component matrices into the Hamiltonian gauge with supplied eigensystem and reusable scratch.
function _transform_operator!(
    output::Array{ComplexF64, 3},
    input::Array{ComplexF64, 3},
    spectrum::KPointSpectrum,
    temporary::Matrix{ComplexF64},
    plan::MatrixElementPlan,
    kind::MatrixElementKind,
)
    for first_index in 1:3
        _axis_required(plan, kind, first_index) || continue
        channel = _axis_channel(plan, kind, first_index)
        @views transform_to_hamiltonian_gauge!(
            output[:, :, first_index],
            spectrum,
            input[:, :, channel],
            temporary,
        )
    end
    return output
end

# Rotate operator component matrices into the Hamiltonian gauge with supplied eigensystem and reusable scratch.
function _transform_operator!(
    output::Array{ComplexF64, 4},
    input::Array{ComplexF64, 3},
    spectrum::KPointSpectrum,
    temporary::Matrix{ComplexF64},
    plan::MatrixElementPlan,
    kind::MatrixElementKind,
)
    for first_index in 1:plan.spatial_dimension, second_index in 1:3
        _pair_required(plan, kind, first_index, second_index) || continue
        channel = _pair_channel(plan, kind, first_index, second_index)
        @views transform_to_hamiltonian_gauge!(
            output[:, :, first_index, second_index],
            spectrum,
            input[:, :, channel],
            temporary,
        )
    end
    return output
end

# Assemble Hamiltonian-gauge spin velocity from energy/connection and spin-weighted operator terms in the selected Cartesian channels.
function _compute_spin_velocity_gauge!(workspace::MatrixElementWorkspace)
    data = workspace.data
    spin_velocity = data.spin_velocity
    energy_differences = data.hamiltonian.energy_differences
    threshold = workspace.plan.degeneracy_threshold
    @inbounds for orbital_row in axes(energy_differences, 1)
        for orbital_column in axes(energy_differences, 2)
            difference = energy_differences[orbital_row, orbital_column]
            spin_velocity.inverse_energy_differences[orbital_row, orbital_column] =
                abs(difference) < threshold ? 0.0 : 1.0 / difference
        end
    end
    derivatives = data.hamiltonian.derivatives
    for direction in axes(derivatives, 3)
        _axis_required(workspace.plan, HAMILTONIAN_DERIVATIVES, direction) || continue
        @views spin_velocity.gauge_correction[:, :, direction] .=
            -derivatives[:, :, direction] .* spin_velocity.inverse_energy_differences
        @inbounds for band in axes(derivatives, 1)
            spin_velocity.energy_derivatives[band, direction] =
                real(derivatives[band, band, direction])
        end
    end
    return spin_velocity
end

"""
Assemble missing spin-weighted operator and spin-velocity channels for the current eigensystem.

Reuse prepared sources and scratch, preserve ordered velocity/spin axes and input spin units, and update capability masks without k-space integration weights.
"""
function compute_spin_velocity_capabilities!(
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
)
    plan = workspace.plan
    needs_component =
        has_capability(plan, SPIN_TIMES_HAMILTONIAN) ||
        has_capability(plan, SPIN_TIMES_POSITION) ||
        has_capability(plan, SPIN_TIMES_HAMILTONIAN_POSITION) ||
        has_capability(plan, SPIN_VELOCITY)
    needs_component || return workspace.data
    data = workspace.data
    spin_velocity = data.spin_velocity
    scratch = workspace.scratch
    spin_velocity_scratch = scratch.spin_velocity
    real_space = workspace.sources.spin_velocity

    if has_capability(plan, SPIN_TIMES_HAMILTONIAN) &&
       !_has_capability(data.computed_mask, SPIN_TIMES_HAMILTONIAN)
        used_mixed = _shared_or_mixed_copy!(
            spin_velocity_scratch.spin_times_hamiltonian_wannier,
            workspace,
            model,
            Val(:SH),
            data.kpoint,
        )
        if !used_mixed
            fourier_t0 = time_ns()
            _fourier_operator!(
                spin_velocity_scratch.spin_times_hamiltonian_wannier,
                real_space.spin_hamiltonian_r,
                model,
                scratch.fourier_factors,
                plan,
                SPIN_TIMES_HAMILTONIAN,
            )
            _record_direct_fourier!(workspace, (time_ns() - fourier_t0) * 1e-9)
        end
        _store_shared_fourier!(
            spin_velocity_scratch.spin_times_hamiltonian_wannier,
            workspace,
            model,
            :SH,
            data.kpoint,
        )
        for channel in axes(spin_velocity_scratch.spin_times_hamiltonian_wannier, 3)
            @views _apply_wannier_center_similarity!(
                spin_velocity_scratch.spin_times_hamiltonian_wannier[:, :, channel],
                scratch,
                plan,
            )
        end
        _transform_operator!(
            spin_velocity.spin_times_hamiltonian,
            spin_velocity_scratch.spin_times_hamiltonian_wannier,
            data.spectrum,
            scratch.matrix_temporary,
            plan,
            SPIN_TIMES_HAMILTONIAN,
        )
        data.computed_mask |= _capability_bit(SPIN_TIMES_HAMILTONIAN)
        workspace.counts.capability_computations[SPIN_TIMES_HAMILTONIAN] += 1
    end

    if has_capability(plan, SPIN_TIMES_POSITION) &&
       !_has_capability(data.computed_mask, SPIN_TIMES_POSITION)
        used_mixed = _shared_or_mixed_copy!(
            spin_velocity_scratch.spin_times_position_wannier,
            workspace,
            model,
            Val(:SR),
            data.kpoint,
        )
        if !used_mixed
            fourier_t0 = time_ns()
            _fourier_operator!(
                spin_velocity_scratch.spin_times_position_wannier,
                real_space.spin_position_r,
                model,
                scratch.fourier_factors,
                plan,
                SPIN_TIMES_POSITION,
            )
            _record_direct_fourier!(workspace, (time_ns() - fourier_t0) * 1e-9)
        end
        _store_shared_fourier!(
            spin_velocity_scratch.spin_times_position_wannier,
            workspace,
            model,
            :SR,
            data.kpoint,
        )
        for velocity_direction in 1:plan.spatial_dimension, spin_direction in 1:3
            _pair_required(plan, SPIN_TIMES_POSITION, velocity_direction, spin_direction) ||
                continue
            channel = _pair_channel(plan, SPIN_TIMES_POSITION, velocity_direction, spin_direction)
            matrix = @view spin_velocity_scratch.spin_times_position_wannier[:, :, channel]
            _apply_wannier_center_similarity!(matrix, scratch, plan)
            _apply_right_position_affine!(
                matrix,
                @view(data.spin.wannier_gauge[:, :, spin_direction]),
                velocity_direction,
                scratch,
                plan,
            )
        end
        _transform_operator!(
            spin_velocity.spin_times_position,
            spin_velocity_scratch.spin_times_position_wannier,
            data.spectrum,
            scratch.matrix_temporary,
            plan,
            SPIN_TIMES_POSITION,
        )
        data.computed_mask |= _capability_bit(SPIN_TIMES_POSITION)
        workspace.counts.capability_computations[SPIN_TIMES_POSITION] += 1
    end

    if has_capability(plan, SPIN_TIMES_HAMILTONIAN_POSITION) &&
       !_has_capability(data.computed_mask, SPIN_TIMES_HAMILTONIAN_POSITION)
        used_mixed = _shared_or_mixed_copy!(
            spin_velocity_scratch.spin_times_hamiltonian_position_wannier,
            workspace,
            model,
            Val(:SHR),
            data.kpoint,
        )
        if !used_mixed
            fourier_t0 = time_ns()
            _fourier_operator!(
                spin_velocity_scratch.spin_times_hamiltonian_position_wannier,
                real_space.spin_hamiltonian_position_r,
                model,
                scratch.fourier_factors,
                plan,
                SPIN_TIMES_HAMILTONIAN_POSITION,
            )
            _record_direct_fourier!(workspace, (time_ns() - fourier_t0) * 1e-9)
        end
        _store_shared_fourier!(
            spin_velocity_scratch.spin_times_hamiltonian_position_wannier,
            workspace,
            model,
            :SHR,
            data.kpoint,
        )
        for velocity_direction in 1:plan.spatial_dimension, spin_direction in 1:3
            _pair_required(
                plan,
                SPIN_TIMES_HAMILTONIAN_POSITION,
                velocity_direction,
                spin_direction,
            ) || continue
            position_channel = _pair_channel(
                plan,
                SPIN_TIMES_HAMILTONIAN_POSITION,
                velocity_direction,
                spin_direction,
            )
            source_channel = _axis_channel(plan, SPIN_TIMES_HAMILTONIAN, spin_direction)
            matrix = @view spin_velocity_scratch.spin_times_hamiltonian_position_wannier[
                :,
                :,
                position_channel,
            ]
            _apply_wannier_center_similarity!(matrix, scratch, plan)
            _apply_right_position_affine!(
                matrix,
                @view(spin_velocity_scratch.spin_times_hamiltonian_wannier[:, :, source_channel]),
                velocity_direction,
                scratch,
                plan,
            )
        end
        _transform_operator!(
            spin_velocity.spin_times_hamiltonian_position,
            spin_velocity_scratch.spin_times_hamiltonian_position_wannier,
            data.spectrum,
            scratch.matrix_temporary,
            plan,
            SPIN_TIMES_HAMILTONIAN_POSITION,
        )
        data.computed_mask |= _capability_bit(SPIN_TIMES_HAMILTONIAN_POSITION)
        workspace.counts.capability_computations[SPIN_TIMES_HAMILTONIAN_POSITION] += 1
    end

    if has_capability(plan, SPIN_VELOCITY) && !_has_capability(data.computed_mask, SPIN_VELOCITY)
        _compute_spin_velocity_gauge!(workspace)
        velocity_directions = axes(data.hamiltonian.derivatives, 3)
        for velocity_direction in velocity_directions, spin_direction in 1:3
            _pair_required(plan, SPIN_VELOCITY, velocity_direction, spin_direction) || continue
            fill!(
                @view(spin_velocity.connection_term[:, :, velocity_direction, spin_direction]),
                COMPLEX_ZERO,
            )
            fill!(
                @view(
                    spin_velocity.hamiltonian_connection_term[
                        :,
                        :,
                        velocity_direction,
                        spin_direction,
                    ]
                ),
                COMPLEX_ZERO,
            )
        end
        @inbounds for spin_direction in 1:3
            for velocity_direction in velocity_directions
                _pair_required(plan, SPIN_VELOCITY, velocity_direction, spin_direction) || continue
                for orbital_column in 1:model.num_orbitals
                    for orbital_row in 1:model.num_orbitals
                        connection_value =
                            -1.0im * spin_velocity.spin_times_position[
                                orbital_row,
                                orbital_column,
                                velocity_direction,
                                spin_direction,
                            ]
                        hamiltonian_connection_value =
                            -1.0im * spin_velocity.spin_times_hamiltonian_position[
                                orbital_row,
                                orbital_column,
                                velocity_direction,
                                spin_direction,
                            ]
                        for intermediate_band in 1:model.num_orbitals
                            connection_value +=
                                data.spin.hamiltonian_gauge[
                                    orbital_row,
                                    intermediate_band,
                                    spin_direction,
                                ] * spin_velocity.gauge_correction[
                                    intermediate_band,
                                    orbital_column,
                                    velocity_direction,
                                ]
                            hamiltonian_connection_value +=
                                spin_velocity.spin_times_hamiltonian[
                                    orbital_row,
                                    intermediate_band,
                                    spin_direction,
                                ] * spin_velocity.gauge_correction[
                                    intermediate_band,
                                    orbital_column,
                                    velocity_direction,
                                ]
                        end
                        spin_velocity.connection_term[
                            orbital_row,
                            orbital_column,
                            velocity_direction,
                            spin_direction,
                        ] = connection_value
                        spin_velocity.hamiltonian_connection_term[
                            orbital_row,
                            orbital_column,
                            velocity_direction,
                            spin_direction,
                        ] = hamiltonian_connection_value
                        spin_velocity.hamiltonian_gauge[
                            orbital_row,
                            orbital_column,
                            velocity_direction,
                            spin_direction,
                        ] =
                            spin_velocity.energy_derivatives[orbital_column, velocity_direction] *
                            data.spin.hamiltonian_gauge[
                                orbital_row,
                                orbital_column,
                                spin_direction,
                            ] + data.spectrum.energies[orbital_column] * connection_value -
                            hamiltonian_connection_value
                    end
                end
            end
        end
        @inbounds for spin_direction in 1:3
            for velocity_direction in velocity_directions
                _pair_required(plan, SPIN_VELOCITY, velocity_direction, spin_direction) || continue
                for orbital_row in 1:model.num_orbitals
                    diagonal_value =
                        0.5 * (
                            spin_velocity.hamiltonian_gauge[
                                orbital_row,
                                orbital_row,
                                velocity_direction,
                                spin_direction,
                            ] + conj(
                                spin_velocity.hamiltonian_gauge[
                                    orbital_row,
                                    orbital_row,
                                    velocity_direction,
                                    spin_direction,
                                ],
                            )
                        )
                    spin_velocity.hamiltonian_gauge[
                        orbital_row,
                        orbital_row,
                        velocity_direction,
                        spin_direction,
                    ] = diagonal_value
                    for orbital_column in (orbital_row + 1):model.num_orbitals
                        value =
                            0.5 * (
                                spin_velocity.hamiltonian_gauge[
                                    orbital_row,
                                    orbital_column,
                                    velocity_direction,
                                    spin_direction,
                                ] + conj(
                                    spin_velocity.hamiltonian_gauge[
                                        orbital_column,
                                        orbital_row,
                                        velocity_direction,
                                        spin_direction,
                                    ],
                                )
                            )
                        spin_velocity.hamiltonian_gauge[
                            orbital_row,
                            orbital_column,
                            velocity_direction,
                            spin_direction,
                        ] = value
                        spin_velocity.hamiltonian_gauge[
                            orbital_column,
                            orbital_row,
                            velocity_direction,
                            spin_direction,
                        ] = conj(value)
                    end
                end
            end
        end
        _hermitize_spin!(data.spin.wannier_gauge, plan)
        _hermitize_spin!(data.spin.hamiltonian_gauge, plan)
        data.computed_mask |= _capability_bit(SPIN_VELOCITY)
        workspace.counts.capability_computations[SPIN_VELOCITY] += 1
    end
    return data
end
