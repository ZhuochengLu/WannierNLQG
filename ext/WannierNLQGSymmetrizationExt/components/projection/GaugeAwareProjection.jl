# Apply the exact CHK-gauge group projector to one Hamiltonian field.
function _project_gauge_aware_hamiltonian(
    hamiltonian_q::Array{ComplexF64, 3},
    sewing::Array{ComplexF64, 4},
    operation_map::Matrix{Int},
    operations::Vector{SymmetryOperation},
)
    output = zeros(ComplexF64, size(hamiltonian_q))
    for source in axes(hamiltonian_q, 3), operation_index in eachindex(operations)
        target = operation_map[operation_index, source]
        basis = @view sewing[:, :, operation_index, source]
        pulled = basis' * @view(hamiltonian_q[:, :, target]) * basis
        operations[operation_index].antiunitary && (pulled = conj(pulled))
        @views output[:, :, source] .+= pulled ./ length(operations)
    end
    return output
end

# Return input/output covariance residuals separately for unitary and antiunitary actions.
function _hamiltonian_covariance_residuals(
    values_q::Array{ComplexF64, 3},
    sewing::Array{ComplexF64, 4},
    operation_map::Matrix{Int},
    operations::Vector{SymmetryOperation},
)
    unitary = 0.0
    antiunitary = 0.0
    for source in axes(values_q, 3), operation_index in eachindex(operations)
        target = operation_map[operation_index, source]
        basis = @view sewing[:, :, operation_index, source]
        pulled = basis' * @view(values_q[:, :, target]) * basis
        operations[operation_index].antiunitary && (pulled = conj(pulled))
        residual = maximum(abs, pulled - @view(values_q[:, :, source]))
        if operations[operation_index].antiunitary
            antiunitary = max(antiunitary, residual)
        else
            unitary = max(unitary, residual)
        end
    end
    return unitary, antiunitary
end

# Compare sorted Hamiltonian bands on one common k-point list.
function _band_difference_metrics(raw_q::Array{ComplexF64, 3}, candidate_q::Array{ComplexF64, 3})
    size(raw_q) == size(candidate_q) || throw(DimensionMismatch("band fields disagree"))
    square_sum = 0.0
    count_values = 0
    maximum_error = 0.0
    for kpoint in axes(raw_q, 3)
        raw_energies = eigvals(Hermitian(@view(raw_q[:, :, kpoint]), :U))
        candidate_energies = eigvals(Hermitian(@view(candidate_q[:, :, kpoint]), :U))
        difference = candidate_energies - raw_energies
        maximum_error = max(maximum_error, maximum(abs, difference))
        square_sum += sum(abs2, difference)
        count_values += length(difference)
    end
    return maximum_error, sqrt(square_sum / count_values)
end

# Build the fixed Gamma-X-S-Y-Gamma path with 401 total points.
function _ges_validation_path()
    vertices = ([0.0, 0.0, 0.0], [0.5, 0.0, 0.0], [0.5, 0.5, 0.0], [0.0, 0.5, 0.0], [0.0, 0.0, 0.0])
    points = Vector{Vector{Float64}}()
    for segment in 1:4
        for step in 0:100
            segment > 1 && step == 0 && continue
            fraction = step / 100
            push!(
                points,
                (1.0 - fraction) .* vertices[segment] .+ fraction .* vertices[segment + 1],
            )
        end
    end
    return reduce(vcat, transpose(point) for point in points)
end

# Return one exact MMN edge displacement in fractional reciprocal coordinates.
function _gauge_aware_mmn_displacement(chk::WannierCHK, mmn::WannierMMN, neighbor::Int, source::Int)
    target = mmn.neighbors[neighbor, source]
    return Vector{Float64}(
        @view(chk.kpt_red[target, :]) .+ @view(mmn.reciprocal_shifts[:, neighbor, source]) .-
        @view(chk.kpt_red[source, :]),
    )
end

# Derive shell-equal finite-difference weights from the MMN geometry.
function _gauge_aware_mmn_weights(chk::WannierCHK, mmn::WannierMMN)
    vectors = Matrix{Float64}(undef, mmn.num_neighbors, 3)
    for neighbor in 1:mmn.num_neighbors
        displacement = _gauge_aware_mmn_displacement(chk, mmn, neighbor, 1)
        vectors[neighbor, :] .= transpose(chk.recip_lattice) * displacement
    end
    rank(vectors; atol = 1.0e-8) == 3 ||
        throw(ArgumentError("MMN neighbors do not form a complete 3D stencil"))
    shell_norms = Float64[]
    shells = Vector{Vector{Int}}()
    for neighbor in axes(vectors, 1)
        length_value = norm(@view vectors[neighbor, :])
        shell = findfirst(value -> abs(value - length_value) <= 1.0e-8, shell_norms)
        if shell === nothing
            push!(shell_norms, length_value)
            push!(shells, [neighbor])
        else
            push!(shells[shell], neighbor)
        end
    end
    system = Matrix{Float64}(undef, 9, length(shells))
    for shell in eachindex(shells)
        moment = zeros(Float64, 3, 3)
        for neighbor in shells[shell]
            vector = @view vectors[neighbor, :]
            moment .+= vector * vector'
        end
        system[:, shell] .= vec(moment)
    end
    shell_weights = system \ vec(Matrix{Float64}(I, 3, 3))
    norm(system * shell_weights - vec(Matrix{Float64}(I, 3, 3))) <= 1.0e-10 ||
        throw(ArgumentError("MMN finite-difference moment is incomplete"))
    weights = zeros(Float64, mmn.num_neighbors)
    for shell in eachindex(shells), neighbor in shells[shell]
        weights[neighbor] = shell_weights[shell]
    end
    return weights
end

# Construct CHK-gauge MMN links without applying a center phase.
function _wannier_gauge_links(chk::WannierCHK, mmn::WannierMMN)
    links = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, mmn.num_neighbors, chk.num_kpts)
    for source in 1:chk.num_kpts, neighbor in 1:mmn.num_neighbors
        target = mmn.neighbors[neighbor, source]
        @views links[:, :, neighbor, source] .=
            chk.v_matrix[:, :, source]' *
            mmn.data[:, :, neighbor, source] *
            chk.v_matrix[:, :, target]
    end
    return links
end

# Map every MMN edge under every reciprocal-space symmetry action.
function _gauge_aware_edge_map(
    chk::WannierCHK,
    mmn::WannierMMN,
    operation_map::Matrix{Int},
    operations::Vector{SymmetryOperation};
    tolerance::Float64 = 1.0e-8,
)
    mapping = Array{Int, 3}(undef, mmn.num_neighbors, chk.num_kpts, length(operations))
    for operation_index in eachindex(operations), source in 1:chk.num_kpts
        operation = operations[operation_index]
        sign = operation.antiunitary ? -1.0 : 1.0
        target_source = operation_map[operation_index, source]
        for neighbor in 1:mmn.num_neighbors
            endpoint = mmn.neighbors[neighbor, source]
            target_endpoint = operation_map[operation_index, endpoint]
            displacement = _gauge_aware_mmn_displacement(chk, mmn, neighbor, source)
            transformed = sign .* (transpose(inv(operation.rotation_fractional)) * displacement)
            matches = Int[]
            for candidate in 1:mmn.num_neighbors
                mmn.neighbors[candidate, target_source] == target_endpoint || continue
                candidate_displacement =
                    _gauge_aware_mmn_displacement(chk, mmn, candidate, target_source)
                maximum(abs, transformed - candidate_displacement) <= tolerance &&
                    push!(matches, candidate)
            end
            length(matches) == 1 ||
                throw(ArgumentError("MMN edge has $(length(matches)) symmetry images"))
            mapping[neighbor, source, operation_index] = only(matches)
        end
    end
    return mapping
end

# Project link endpoints with the actual CHK-gauge sewing matrices.
function _project_gauge_aware_links(
    links::Array{ComplexF64, 4},
    mmn::WannierMMN,
    sewing::Array{ComplexF64, 4},
    operation_map::Matrix{Int},
    edge_map::Array{Int, 3},
    operations::Vector{SymmetryOperation},
)
    output = zeros(ComplexF64, size(links))
    for source in axes(links, 4),
        neighbor in axes(links, 3),
        operation_index in eachindex(operations)

        endpoint = mmn.neighbors[neighbor, source]
        target_source = operation_map[operation_index, source]
        target_neighbor = edge_map[neighbor, source, operation_index]
        left = @view sewing[:, :, operation_index, source]
        right = @view sewing[:, :, operation_index, endpoint]
        pulled = left' * @view(links[:, :, target_neighbor, target_source]) * right
        operations[operation_index].antiunitary && (pulled = conj(pulled))
        @views output[:, :, neighbor, source] .+= pulled ./ length(operations)
    end
    return output
end

# Reconstruct the Convention-II position field from center-aware MMN links.
function _position_from_wannier_links(
    links::Array{ComplexF64, 4},
    chk::WannierCHK,
    mmn::WannierMMN,
    weights::Vector{Float64},
    centers_cartesian::Matrix{Float64},
)
    output = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3, chk.num_kpts)
    for source in 1:chk.num_kpts, neighbor in 1:mmn.num_neighbors
        displacement = _gauge_aware_mmn_displacement(chk, mmn, neighbor, source)
        b_cartesian = transpose(chk.recip_lattice) * displacement
        overlap = Matrix(@view links[:, :, neighbor, source])
        overlap .*= transpose(cis.(centers_cartesian * b_cartesian))
        for direction in 1:3
            @views output[:, :, direction, source] .+=
                1.0im * weights[neighbor] * b_cartesian[direction] .* overlap
        end
    end
    return output
end

# Collect the complete pair-dependent minimum-distance R support for C11.
function _gauge_aware_pair_support(
    chk::WannierCHK,
    centers_fractional::Matrix{Float64};
    tolerance::Float64,
    search_size::Int,
)
    images = Set{NTuple{3, Int}}()
    residues = vec(mp_residue_grid(chk.mp_grid))
    for left in 1:chk.num_orbitals, right in 1:chk.num_orbitals
        shift = -centers_fractional[left, :] .+ centers_fractional[right, :]
        for residue in residues
            union!(
                images,
                nearest_wigner_seitz_images(
                    residue,
                    Vector{Float64}(shift),
                    chk.real_lattice,
                    chk.mp_grid;
                    tolerance,
                    search_size,
                ),
            )
        end
    end
    ordered = sort!(collect(images))
    return reduce(hcat, (collect(image) for image in ordered); init = zeros(Int, 3, 0))
end

# Clone a CHK while changing only the centers used by pair-dependent materialization.
function _gauge_aware_chk_with_centers(chk::WannierCHK, centers_cartesian::Matrix{Float64})
    size(centers_cartesian) == (chk.num_orbitals, 3) ||
        throw(ArgumentError("materialization centers have incompatible dimensions"))
    all(isfinite, centers_cartesian) ||
        throw(ArgumentError("materialization centers contain non-finite values"))
    return WannierCHK(
        chk.num_bands,
        chk.num_orbitals,
        chk.num_kpts,
        chk.mp_grid,
        chk.kpt_red,
        chk.real_lattice,
        chk.recip_lattice,
        centers_cartesian,
        chk.v_matrix,
    )
end

# Materialize one orthogonal WCC/replica variant from the same projected q-space fields.
function _materialize_gauge_aware_variant(
    config::GaugeAwareSymmetrizationConfig,
    variant::Symbol,
    source_model::TightBindingModel,
    chk::WannierCHK,
    symmetrized_hamiltonian_q::Array{ComplexF64, 3},
    symmetrized_position_q::Array{ComplexF64, 4},
    input_hamiltonian_r::Array{ComplexF64, 3},
    input_position_r::Array{ComplexF64, 4},
    projected_centers::Matrix{Float64},
)
    policy = _gauge_aware_materialization_policy(variant)
    centers_cartesian =
        policy.center_policy == :keep_input ? chk.wannier_centers_cart : projected_centers
    variant_chk = _gauge_aware_chk_with_centers(chk, centers_cartesian)

    if policy.replica_policy == :input
        r_vectors = copy(source_model.r_vectors)
        degeneracies = copy(source_model.r_degeneracies)
        hamiltonian_r = copy(input_hamiltonian_r)
        position_r = copy(input_position_r)
        hamiltonian_roundtrip = maximum(
            abs,
            _gauge_aware_r_to_q(hamiltonian_r, r_vectors, degeneracies, chk.kpt_red) -
            symmetrized_hamiltonian_q,
        )
        position_roundtrip = maximum(
            abs,
            _gauge_aware_r_to_q(position_r, r_vectors, degeneracies, chk.kpt_red) -
            symmetrized_position_q,
        )
        plan = nothing
    else
        centers_fractional = centers_cartesian * inv(chk.real_lattice)
        r_vectors = _gauge_aware_pair_support(
            variant_chk,
            centers_fractional;
            tolerance = config.wigner_seitz_tolerance,
            search_size = config.wigner_seitz_search_size,
        )
        plan = WannierPairWignerSeitzTransformPlan(
            variant_chk,
            r_vectors;
            wigner_seitz_tolerance = config.wigner_seitz_tolerance,
            search_size = config.wigner_seitz_search_size,
            image_policy = :minimum_distance,
            wannier_centers_fractional = centers_fractional,
        )
        hamiltonian_r = wannier_q_to_pair_wigner_seitz(
            symmetrized_hamiltonian_q,
            variant_chk,
            plan;
            support_tolerance = 0.0,
            label = "$(variant) Hamiltonian",
        )
        position_r = wannier_q_to_pair_wigner_seitz(
            symmetrized_position_q,
            variant_chk,
            plan;
            support_tolerance = 0.0,
            label = "$(variant) position",
        )
        degeneracies = ones(Int, size(r_vectors, 2))
        hamiltonian_roundtrip = unit_degeneracy_roundtrip_error(
            symmetrized_hamiltonian_q,
            hamiltonian_r,
            variant_chk,
            plan,
        )
        position_roundtrip =
            unit_degeneracy_roundtrip_error(symmetrized_position_q, position_r, variant_chk, plan)
    end

    home_index = only(findall(index -> all(iszero, @view(r_vectors[:, index])), axes(r_vectors, 2)))
    for wannier in 1:chk.num_orbitals, direction in 1:3
        position_r[wannier, wannier, direction, home_index] = centers_cartesian[wannier, direction]
    end
    model = TightBindingModel(
        source_model.lattice,
        source_model.num_orbitals,
        size(r_vectors, 2),
        degeneracies,
        r_vectors,
        hamiltonian_r,
        position_r,
    )
    return (;
        model,
        centers_cartesian,
        center_policy = policy.center_policy,
        replica_policy = policy.replica_policy,
        hamiltonian_roundtrip,
        position_roundtrip,
        plan,
    )
end
