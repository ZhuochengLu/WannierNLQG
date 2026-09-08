# Apply one unitary or antiunitary operation to a matrix-valued field entry.
function _operation_action(operation, matrix)
    return operation.antiunitary ? conj(matrix) : matrix
end

"""Typed fail-stop raised by the frozen corepresentation initializer."""
struct FrozenCorepresentationInitializationError <: Exception
    code::Symbol
    message::String
    context::Dict{String, String}
end

"""Render a frozen-corepresentation initialization failure with its typed context."""
function Base.showerror(io::Base.IO, exception::FrozenCorepresentationInitializationError)
    print(io, exception.code, ": ", exception.message)
    isempty(exception.context) || print(io, " ", exception.context)
end

# Return a rank-gated Hermitian polar retraction together with its spectrum.
# Deliberately do not use a pseudoinverse: a deficient intertwiner is physical
# incompatibility evidence, not a numerical condition to conceal.
function _rank_gated_polar_columns(
    matrix::AbstractMatrix{<:Complex};
    minimum_singular_value::Float64,
    maximum_condition::Float64,
    audit::Union{Nothing, HermitianSpectrumAudit} = nothing,
    context::AbstractString = "rank_gated_polar_gram",
)
    isempty(matrix) && return Matrix{ComplexF64}(matrix), Float64[], 1.0
    gram = Matrix{ComplexF64}(matrix' * matrix)
    factorization =
        _validated_hermitian_spectrum(gram; tolerance = minimum_singular_value^2, context, audit)
    factorization.success || return nothing, Float64[], Inf
    eigenvalues = max.(real.(factorization.values), 0.0)
    singular_values = sqrt.(eigenvalues)
    smallest = minimum(singular_values)
    largest = maximum(singular_values)
    condition = smallest > 0.0 ? largest / smallest : Inf
    smallest >= minimum_singular_value && condition <= maximum_condition ||
        return nothing, singular_values, condition
    inverse_square_root =
        factorization.vectors * Diagonal(inv.(singular_values)) * factorization.vectors'
    result = Matrix{ComplexF64}(matrix * inverse_square_root)
    all(isfinite, result) || return nothing, singular_values, condition
    return result, singular_values, condition
end

# Direct thin-SVD polar for the low-dimensional coordinates of a newly
# completed Z corepresentation.  The generic initializer above deliberately
# retains its historical Hermitian-Gram arithmetic.  Reusing that Gram route
# for a nearly rank-deficient ambient intertwiner squares its condition number
# and can amplify roundoff outside the sealed remaining-band projector.  Keep
# the stable direct-SVD arithmetic confined to the new symmetry-Z completion.
function _rank_gated_svd_polar_columns(
    matrix::AbstractMatrix{<:Complex};
    minimum_singular_value::Float64,
    maximum_condition::Float64,
)
    isempty(matrix) && return Matrix{ComplexF64}(matrix), Float64[], 1.0
    size(matrix, 1) >= size(matrix, 2) || return nothing, Float64[], Inf
    decomposition = svd(Matrix{ComplexF64}(matrix); full = false)
    singular_values = Float64.(decomposition.S)
    all(isfinite, singular_values) || return nothing, singular_values, Inf
    smallest = minimum(singular_values)
    largest = maximum(singular_values)
    condition = smallest > 0.0 ? largest / smallest : Inf
    smallest >= minimum_singular_value && condition <= maximum_condition ||
        return nothing, singular_values, condition
    column_count = size(matrix, 2)
    result =
        Matrix{ComplexF64}(decomposition.U[:, 1:column_count] * decomposition.Vt[1:column_count, :])
    all(isfinite, result) || return nothing, singular_values, condition
    return result, singular_values, condition
end

# Construct a deterministic orthonormal basis for one Hermitian projector.
function _deterministic_projector_basis(
    projector::AbstractMatrix{<:Complex},
    dimension::Int,
    tolerance::Float64,
)
    dimension == 0 && return zeros(ComplexF64, size(projector, 1), 0)
    basis = zeros(ComplexF64, size(projector, 1), dimension)
    count = 0
    for column in axes(projector, 2)
        vector = Vector{ComplexF64}(@view projector[:, column])
        count > 0 && (vector .-= @view(basis[:, 1:count]) * (@view(basis[:, 1:count])' * vector))
        vector = projector * vector
        count > 0 && (vector .-= @view(basis[:, 1:count]) * (@view(basis[:, 1:count])' * vector))
        magnitude = norm(vector)
        magnitude > tolerance || continue
        count += 1
        basis[:, count] .= vector ./ magnitude
        pivot = argmax(abs.(@view basis[:, count]))
        basis[:, count] .*= cis(-angle(basis[pivot, count]))
        count == dimension && return basis
    end
    return nothing
end

# Project one supplied frozen-band/target seed over a magnetic little group.
function _frozen_target_embedding(
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    representative::Int,
    frozen::Vector{Int},
    operation_mapping::Vector{Int},
    probe::AbstractMatrix{<:Complex},
)
    num_wannier = size(plan.representation_matrices, 1)
    size(probe) == (num_wannier, length(frozen)) ||
        throw(DimensionMismatch("frozen AMN seed has incompatible dimensions"))
    projected = zeros(ComplexF64, size(probe))
    count = 0
    for operation_index in eachindex(representation.operations)
        representation.kpoint_map[operation_index, representative] == representative || continue
        sewing = Matrix(
            @view representation.sewing_matrices[frozen, frozen, operation_index, representative]
        )
        target = target_representation(
            plan,
            representation,
            operation_index,
            representative,
            operation_mapping[operation_index],
        )
        projected .+=
            target * _operation_action(representation.operations[operation_index], probe) * sewing'
        count += 1
    end
    count > 0 || throw(ArgumentError("IBZ representative has an empty little group"))
    return projected ./ count
end

# Preserve deterministic probe generation for fixed-subspace diagnostic paths.
function _frozen_target_embedding(
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    representative::Int,
    frozen::Vector{Int},
    operation_mapping::Vector{Int},
    probe_index::Int,
)
    num_wannier = size(plan.representation_matrices, 1)
    rng = MersenneTwister(UInt64(0x66726f7a656e) + UInt64(4099 * representative + probe_index))
    probe =
        randn(rng, num_wannier, length(frozen)) .+ 1.0im .* randn(rng, num_wannier, length(frozen))
    return _frozen_target_embedding(
        representation,
        plan,
        representative,
        frozen,
        operation_mapping,
        probe,
    )
end

# Project one supplied target-to-band seed into the outer free complement.
function _free_complement_embedding(
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    representative::Int,
    outer::Vector{Int},
    frozen_projector::Matrix{ComplexF64},
    target_complement::Matrix{ComplexF64},
    operation_mapping::Vector{Int},
    probe::AbstractMatrix{<:Complex},
)
    num_bands = size(representation.energies_ev, 1)
    num_wannier = size(plan.representation_matrices, 1)
    size(probe) == (num_bands, num_wannier) ||
        throw(DimensionMismatch("free-complement AMN seed has incompatible dimensions"))
    projected = zeros(ComplexF64, size(probe))
    count = 0
    for operation_index in eachindex(representation.operations)
        representation.kpoint_map[operation_index, representative] == representative || continue
        sewing = @view representation.sewing_matrices[:, :, operation_index, representative]
        target = target_representation(
            plan,
            representation,
            operation_index,
            representative,
            operation_mapping[operation_index],
        )
        projected .+=
            sewing * _operation_action(representation.operations[operation_index], probe) * target'
        count += 1
    end
    count > 0 || throw(ArgumentError("IBZ representative has an empty little group"))
    projected ./= count
    outer_projector = zeros(ComplexF64, num_bands, num_bands)
    outer_projector[outer, outer] .= Matrix{ComplexF64}(I, length(outer), length(outer))
    return outer_projector *
           (Matrix{ComplexF64}(I, num_bands, num_bands) - frozen_projector) *
           projected *
           target_complement
end

# Preserve deterministic probe generation for fixed-subspace diagnostic paths.
function _free_complement_embedding(
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    representative::Int,
    outer::Vector{Int},
    frozen_projector::Matrix{ComplexF64},
    target_complement::Matrix{ComplexF64},
    operation_mapping::Vector{Int},
    probe_index::Int,
)
    num_bands = size(representation.energies_ev, 1)
    num_wannier = size(plan.representation_matrices, 1)
    rng = MersenneTwister(UInt64(0x636f6d706c656d) + UInt64(6151 * representative + probe_index))
    probe = zeros(ComplexF64, num_bands, num_wannier)
    probe[outer, :] .=
        randn(rng, length(outer), num_wannier) .+ 1.0im .* randn(rng, length(outer), num_wannier)
    return _free_complement_embedding(
        representation,
        plan,
        representative,
        outer,
        frozen_projector,
        target_complement,
        operation_mapping,
        probe,
    )
end

# Rotate the disentanglement field with the same ordering as
# WannierBerri's Symmetrizer_Zirr: d† Z d, followed by complex conjugation
# for an antiunitary little-group operation.
function _rotate_hermitian_field_entry(operation, sewing, matrix)
    rotated = sewing' * matrix * sewing
    return operation.antiunitary ? conj(rotated) : rotated
end

# Project each IBZ Hermitian field over its little group.
function _symmetrize_hermitian_field(
    field::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
)
    projected = deepcopy(field)
    for representative in representation.irreducible_indices
        total = zeros(ComplexF64, size(field[representative]))
        count = 0
        for operation_index in eachindex(representation.operations)
            representation.kpoint_map[operation_index, representative] == representative || continue
            sewing = @view representation.sewing_matrices[:, :, operation_index, representative]
            total .+= _rotate_hermitian_field_entry(
                representation.operations[operation_index],
                sewing,
                field[representative],
            )
            count += 1
        end
        count > 0 || throw(ArgumentError("IBZ representative has an empty little group"))
        projected[representative] = Matrix{ComplexF64}(Hermitian(total ./ count))
    end
    return projected
end

# Reduce a full-BZ disentanglement field to IBZ representatives by pulling
# every star member back through the same sewing convention used to expand
# frames.  This is part of the constrained objective itself: little-group
# projection of the representative alone omits the other star contributions.
function _reduce_full_star_hermitian_field(
    field::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
)
    length(field) == size(representation.energies_ev, 2) ||
        throw(DimensionMismatch("full-BZ Hermitian field has an incompatible k-point count"))
    reduced = [zeros(ComplexF64, size(matrix)) for matrix in field]
    star_counts = zeros(Int, length(representation.irreducible_indices))
    for target_kpoint in eachindex(field)
        ibz_index = representation.full_to_irreducible[target_kpoint]
        representative = representation.irreducible_indices[ibz_index]
        operation_index = representation.full_to_operation[target_kpoint]
        representation.kpoint_map[operation_index, representative] == target_kpoint || throw(
            ArgumentError("stored k-star operation does not reach its Hermitian-field target"),
        )
        sewing = @view representation.sewing_matrices[:, :, operation_index, representative]
        reduced[representative] .+= _rotate_hermitian_field_entry(
            representation.operations[operation_index],
            sewing,
            field[target_kpoint],
        )
        star_counts[ibz_index] += 1
    end
    for (ibz_index, representative) in enumerate(representation.irreducible_indices)
        star_counts[ibz_index] > 0 ||
            throw(ArgumentError("IBZ representative has an empty full-BZ star"))
        reduced[representative] =
            Matrix{ComplexF64}(Hermitian(reduced[representative] ./ star_counts[ibz_index]))
    end
    return reduced
end

# Project the frame at every IBZ representative over its little group.
function _symmetrize_ibz_frames_once(
    frames::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
)
    projected = deepcopy(frames)
    for representative in representation.irreducible_indices
        total = zeros(ComplexF64, size(frames[representative]))
        count = 0
        for operation_index in eachindex(representation.operations)
            representation.kpoint_map[operation_index, representative] == representative || continue
            sewing = @view representation.sewing_matrices[:, :, operation_index, representative]
            target = target_representation(plan, representation, operation_index, representative)
            total .+=
                sewing *
                _operation_action(
                    representation.operations[operation_index],
                    frames[representative],
                ) *
                target'
            count += 1
        end
        count > 0 || throw(ArgumentError("IBZ representative has an empty little group"))
        projected[representative] = total ./ count
    end
    return projected
end

# Expand IBZ frames to the full mesh using the deterministic first star operation.
function _expand_ibz_frames(
    frames::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
)
    operation_mapping, inventory_diagnostics =
        validate_target_operation_inventory(representation, plan, 1.0e-10)
    isempty(inventory_diagnostics) ||
        throw(ArgumentError("cannot expand frames from mismatched operation inventories"))
    expanded = deepcopy(frames)
    for target_kpoint in eachindex(frames)
        ibz_index = representation.full_to_irreducible[target_kpoint]
        representative = representation.irreducible_indices[ibz_index]
        operation_index = representation.full_to_operation[target_kpoint]
        representation.kpoint_map[operation_index, representative] == target_kpoint ||
            throw(ArgumentError("stored k-star operation does not reach its target"))
        sewing = @view representation.sewing_matrices[:, :, operation_index, representative]
        target = target_representation(
            plan,
            representation,
            operation_index,
            representative,
            operation_mapping[operation_index],
        )
        expanded[target_kpoint] =
            sewing *
            _operation_action(representation.operations[operation_index], frames[representative]) *
            target'
    end
    return expanded
end

"""Maximum full-BZ target-frame covariance error in the canonical sewing convention."""
function _maximum_target_frame_symmetry_error(
    frames::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
)
    operation_mapping, inventory_diagnostics =
        validate_target_operation_inventory(representation, plan, 1.0e-10)
    isempty(inventory_diagnostics) || return Inf
    residual = 0.0
    for source in eachindex(frames), operation_index in eachindex(representation.operations)
        target_kpoint = representation.kpoint_map[operation_index, source]
        sewing = @view representation.sewing_matrices[:, :, operation_index, source]
        target = target_representation(
            plan,
            representation,
            operation_index,
            source,
            operation_mapping[operation_index],
        )
        expected =
            sewing *
            _operation_action(representation.operations[operation_index], frames[source]) *
            target'
        residual = max(residual, maximum(abs, expected - frames[target_kpoint]))
    end
    return residual
end

# Iterate the little-group/full-star frame projector and preserve a typed nonconvergence signal.
function _symmetrize_frame(
    frames::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    config::SymmetryAdaptedWannierizationConfig,
    included_bands::Vector{BitVector},
)
    current = deepcopy(frames)
    maximum_residual = Inf
    for iteration in 1:config.solver.little_group_max_iterations
        projected = _symmetrize_ibz_frames_once(current, representation, plan)
        maximum_residual = 0.0
        for kpoint in representation.irreducible_indices
            included = included_bands[kpoint]
            orthonormal = _orthonormalize_columns(
                @view(projected[kpoint][included, :]),
                config.input.representation_tolerance,
            )
            orthonormal === nothing && return current, false, true, iteration, maximum_residual
            updated = zeros(ComplexF64, size(projected[kpoint]))
            updated[included, :] .= orthonormal
            maximum_residual = max(
                maximum_residual,
                maximum(abs, updated[included, :] - current[kpoint][included, :]),
            )
            projected[kpoint] = updated
        end
        current = _expand_ibz_frames(projected, representation, plan)
        maximum_residual <= config.solver.little_group_tolerance &&
            return current, true, false, iteration, maximum_residual
    end
    return current, false, false, config.solver.little_group_max_iterations, maximum_residual
end

# Identify inaccurate terminal band blocks using the same upper-four-band rule
# as the fixed IrRep oracle.  Lower-block errors remain diagnostics and are not
# silently discarded.
function _representation_inclusion_masks(
    frames::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    config::SymmetryAdaptedWannierizationConfig,
)
    nb = size(representation.energies_ev, 1)
    masks = [trues(nb) for _ in eachindex(frames)]
    diagnostics = WannierizationDiagnostic[]
    probe = deepcopy(frames)
    for _ in 1:config.solver.little_group_max_iterations
        projected = _symmetrize_ibz_frames_once(probe, representation, plan)
        valid = true
        for representative in representation.irreducible_indices
            orthonormal = _orthonormalize_columns(
                projected[representative],
                config.input.representation_tolerance,
            )
            if orthonormal === nothing
                valid = false
                break
            end
            projected[representative] = orthonormal
        end
        valid || break
        probe = _expand_ibz_frames(projected, representation, plan)
    end
    for representative in representation.irreducible_indices
        labels = @view representation.band_block_labels[:, representative]
        block_residuals = Dict(label => 0.0 for label in unique(labels))
        for operation_index in eachindex(representation.operations)
            representation.kpoint_map[operation_index, representative] == representative || continue
            sewing = @view representation.sewing_matrices[:, :, operation_index, representative]
            target = target_representation(plan, representation, operation_index, representative)
            rotated =
                sewing *
                _operation_action(
                    representation.operations[operation_index],
                    probe[representative],
                ) *
                target'
            for label in unique(labels)
                block = findall(==(label), labels)
                residual = maximum(abs, rotated[block, :] - probe[representative][block, :])
                block_residuals[label] = max(block_residuals[label], residual)
            end
        end
        for label in sort!(collect(keys(block_residuals)))
            residual = block_residuals[label]
            residual <= 1.0e-6 && continue
            block = findall(==(label), labels)
            if last(block) > nb - 4
                masks[representative][block] .= false
            else
                push!(
                    diagnostics,
                    WannierizationDiagnostic(
                        :BAND_BLOCK_REPRESENTATION_RESIDUAL,
                        :warning,
                        "nonterminal band block is not exactly symmetrizable";
                        context = Dict(
                            "kpoint" => string(representative),
                            "first_band" => string(first(block)),
                            "last_band" => string(last(block)),
                            "maximum_error" => string(residual),
                        ),
                    ),
                )
            end
        end
    end
    for target_kpoint in eachindex(frames)
        representative =
            representation.irreducible_indices[representation.full_to_irreducible[target_kpoint]]
        masks[target_kpoint] .= masks[representative]
    end
    return masks, diagnostics
end

# A square, undisentangled outer window is the complete band Hilbert space.
# Its selected projector is the identity at every k-point and is therefore
# closed under every unitary and antiunitary sewing matrix.  The empirical
# terminal-band exclusion used for truncated outer windows must not remove
# states from this exact full-space contract.
function _is_complete_outer_space(
    outer_indices::Vector{Vector{Int}},
    num_bands::Int,
    num_wannier::Int,
)
    num_wannier == num_bands || return false
    expected = collect(1:num_bands)
    return all(indices -> indices == expected, outer_indices)
end

# Return the maximum projector covariance residual over the complete k-star action.
function _maximum_projector_covariance_error(
    frames::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
)
    maximum_error = 0.0
    for source_kpoint in eachindex(frames), operation_index in eachindex(representation.operations)
        target_kpoint = representation.kpoint_map[operation_index, source_kpoint]
        sewing = @view representation.sewing_matrices[:, :, operation_index, source_kpoint]
        source_projector = frames[source_kpoint] * frames[source_kpoint]'
        transformed =
            sewing *
            _operation_action(representation.operations[operation_index], source_projector) *
            sewing'
        target_projector = frames[target_kpoint] * frames[target_kpoint]'
        maximum_error = max(maximum_error, maximum(abs, transformed - target_projector))
    end
    return maximum_error
end

# Return the exact Monkhorst-Pack displacement represented by one MMN edge.
# Formatted k-points can carry last-bit decimal noise; retaining that noise in
# the shell moments makes otherwise identical Julia/WannierBerri weights differ.
function _mesh_neighbor_displacement(
    representation::BandRepresentation,
    mmn::WannierMMN,
    neighbor::Int,
    kpoint::Int;
    tolerance::Float64 = 1.0e-8,
)
    target = mmn.neighbors[neighbor, kpoint]
    displacement =
        @view(representation.kpoints_fractional[target, :]) .+
        @view(mmn.reciprocal_shifts[:, neighbor, kpoint]) .-
        @view(representation.kpoints_fractional[kpoint, :])
    mesh = Float64[representation.mp_grid...]
    mesh_coordinates = displacement .* mesh
    integer_coordinates = round.(mesh_coordinates)
    maximum(abs, mesh_coordinates - integer_coordinates) <= tolerance || throw(
        ArgumentError(
            "MMN_STENCIL_INCONSISTENT_MESH: neighbour displacement is not an integer MP-grid edge",
        ),
    )
    return integer_coordinates ./ mesh
end

"""Hash the exact realized finite-difference stencil payload."""
function _finite_difference_stencil_sha256(vectors, shell_ids, weights, target)
    buffer = IOBuffer()
    write(buffer, reinterpret(UInt8, vec(vectors)))
    write(buffer, reinterpret(UInt8, Int64.(shell_ids)))
    write(buffer, reinterpret(UInt8, weights))
    write(buffer, reinterpret(UInt8, vec(target)))
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Compare floating payloads within a strict cross-platform roundoff bound."""
function _stencil_float_payload_equivalent(left, right)
    size(left) == size(right) || return false
    scale = max(1.0, maximum(abs, left; init = 0.0), maximum(abs, right; init = 0.0))
    tolerance = 64 * eps(Float64) * scale
    return all(index -> abs(left[index] - right[index]) <= tolerance, eachindex(left, right))
end

"""Validate exact or tightly bounded cross-platform restart-stencil identity."""
function _restart_stencils_compatible(
    stored::WannierizationFiniteDifferenceStencil,
    current::WannierizationFiniteDifferenceStencil,
)
    stored.digest == _finite_difference_stencil_sha256(
        stored.vectors_cartesian,
        stored.shell_ids,
        stored.weights,
        stored.target_moment,
    ) || return false
    current.digest == _finite_difference_stencil_sha256(
        current.vectors_cartesian,
        current.shell_ids,
        current.weights,
        current.target_moment,
    ) || return false
    stored.digest == current.digest && return true
    stored.shell_ids == current.shell_ids || return false
    _stencil_float_payload_equivalent(stored.vectors_cartesian, current.vectors_cartesian) ||
        return false
    _stencil_float_payload_equivalent(stored.weights, current.weights) || return false
    _stencil_float_payload_equivalent(stored.target_moment, current.target_moment) || return false
    return _stencil_float_payload_equivalent(
        [stored.completeness_residual],
        [current.completeness_residual],
    )
end

# Determine shell-equal finite-difference weights for the full Cartesian identity.
function _finite_difference_weights(
    representation::BandRepresentation,
    mmn::WannierMMN;
    tolerance::Float64 = 1.0e-8,
    completeness_tolerance::Float64 = 1.0e-10,
    construction_policy::Symbol = :strict,
)
    kpoint = 1
    vectors = Matrix{Float64}(undef, mmn.num_neighbors, 3)
    for neighbor in 1:mmn.num_neighbors
        displacement = _mesh_neighbor_displacement(representation, mmn, neighbor, kpoint; tolerance)
        vectors[neighbor, :] .= transpose(representation.reciprocal_lattice) * displacement
    end
    rank(vectors; atol = tolerance) == 3 || throw(
        ArgumentError(
            "MMN_STENCIL_INCOMPLETE_3D: neighbour vectors do not span three Cartesian dimensions",
        ),
    )
    shell_norms = Float64[]
    shell_indices = Vector{Vector{Int}}()
    shell_ids = zeros(Int, mmn.num_neighbors)
    for neighbor in axes(vectors, 1)
        length_value = norm(@view vectors[neighbor, :])
        shell = findfirst(value -> abs(value - length_value) <= tolerance, shell_norms)
        if shell === nothing
            push!(shell_norms, length_value)
            push!(shell_indices, [neighbor])
            shell_ids[neighbor] = length(shell_indices)
        else
            push!(shell_indices[shell], neighbor)
            shell_ids[neighbor] = shell
        end
    end
    system = Matrix{Float64}(undef, 9, length(shell_indices))
    for shell in eachindex(shell_indices)
        moment = zeros(Float64, 3, 3)
        for neighbor in shell_indices[shell]
            vector = @view vectors[neighbor, :]
            moment .+= vector * vector'
        end
        system[:, shell] .= vec(moment)
    end
    target = Matrix{Float64}(I, 3, 3)
    shell_weights = system \ vec(target)
    residual = norm(system * shell_weights - vec(target))
    all(isfinite, shell_weights) && isfinite(residual) ||
        throw(ArgumentError("MMN_STENCIL_NONFINITE_WEIGHTS"))
    construction_policy == :diagnostic ||
        residual <= completeness_tolerance ||
        throw(
            ArgumentError(
                "MMN_STENCIL_INCOMPLETE_3D: shell moment residual $(residual) exceeds " *
                "$(completeness_tolerance)",
            ),
        )
    weights = zeros(Float64, mmn.num_neighbors)
    for shell in eachindex(shell_indices), neighbor in shell_indices[shell]
        weights[neighbor] = shell_weights[shell]
    end
    digest = _finite_difference_stencil_sha256(vectors, shell_ids, weights, target)
    return WannierizationFiniteDifferenceStencil(
        vectors,
        shell_ids,
        weights,
        target,
        residual,
        digest,
    )
end

"""Reproduce Wannier90's `utility_recip_lattice` scalar path.

Wannier90 retains an `Ang` `unit_cell_cart` in Angstrom internally; it does not
perform an Angstrom -> Bohr -> Angstrom round trip.  The representation lattice
is likewise in Angstrom, so applying that extra conversion changes the
reciprocal lattice by one ulp.
"""
function _wannier90_reference_b_cartesian(
    representation::BandRepresentation,
    displacement::AbstractVector{<:Real},
)
    # Reproduce `utility_inv3` followed by
    # `recip_lat = twopi*recip_lat/volume`. Calling generic `inv` dispatches
    # through LAPACK and changes the last bit even for the diagonal Cr cell;
    # that perturbation is amplified by the FR parabolic step after U3.
    a = representation.real_lattice
    adjugate = zeros(Float64, 3, 3)
    adjugate[1, 1] = a[2, 2] * a[3, 3] - a[3, 2] * a[2, 3]
    adjugate[1, 2] = a[2, 3] * a[3, 1] - a[3, 3] * a[2, 1]
    adjugate[1, 3] = a[2, 1] * a[3, 2] - a[3, 1] * a[2, 2]
    adjugate[2, 1] = a[3, 2] * a[1, 3] - a[1, 2] * a[3, 3]
    adjugate[2, 2] = a[3, 3] * a[1, 1] - a[1, 3] * a[3, 1]
    adjugate[2, 3] = a[3, 1] * a[1, 2] - a[1, 1] * a[3, 2]
    adjugate[3, 1] = a[1, 2] * a[2, 3] - a[2, 2] * a[1, 3]
    adjugate[3, 2] = a[1, 3] * a[2, 1] - a[2, 3] * a[1, 1]
    adjugate[3, 3] = a[1, 1] * a[2, 2] - a[2, 1] * a[1, 2]
    volume = a[1, 1] * adjugate[1, 1] + a[1, 2] * adjugate[1, 2] + a[1, 3] * adjugate[1, 3]
    reciprocal_lattice_angstrom = 2pi .* adjugate ./ volume
    # `utility_frac_to_cart` is an explicit three-term scalar assignment, not
    # BLAS GEMV.  Preserve the source expression and its rounding order.
    output = zeros(Float64, 3)
    for direction in 1:3
        output[direction] =
            reciprocal_lattice_angstrom[1, direction] * displacement[1] +
            reciprocal_lattice_angstrom[2, direction] * displacement[2] +
            reciprocal_lattice_angstrom[3, direction] * displacement[3]
    end
    return output
end

"""Reproduce Wannier90's separately transformed `G + k_target - k_source`."""
function _wannier90_reference_edge_b_cartesian(
    representation::BandRepresentation,
    mmn::WannierMMN,
    neighbor::Int,
    kpoint::Int,
)
    # Retain the fail-closed mesh identity check, but do not use its rounded
    # displacement in the reference arithmetic.  `kmesh_get` transforms the
    # source, target, and reciprocal shift separately before subtracting them.
    _mesh_neighbor_displacement(representation, mmn, neighbor, kpoint)
    target = mmn.neighbors[neighbor, kpoint]
    target_cartesian = _wannier90_reference_b_cartesian(
        representation,
        @view(representation.kpoints_fractional[target, :]),
    )
    shift_cartesian = _wannier90_reference_b_cartesian(
        representation,
        @view(mmn.reciprocal_shifts[:, neighbor, kpoint]),
    )
    source_cartesian = _wannier90_reference_b_cartesian(
        representation,
        @view(representation.kpoints_fractional[kpoint, :]),
    )
    return (shift_cartesian + target_cartesian) - source_cartesian
end

"""LP64 `DGESVD('A','A')` used by Wannier90's B1 shell-weight solve."""
function _wannier90_reference_dgesvd(matrix::Matrix{Float64})
    rows, columns = size(matrix)
    rows >= columns > 0 || return nothing
    values = copy(matrix)
    singular_values = zeros(Float64, columns)
    left = zeros(Float64, rows, rows)
    right_adjoint = zeros(Float64, columns, columns)
    work = zeros(Float64, 10rows)
    all_vectors = UInt8('A')
    use_external_lp64 = _WANNIER90_REFERENCE_LP64_LAPACK !== nothing
    integer_type = use_external_lp64 ? Cint : LinearAlgebra.BlasInt
    m = integer_type(rows)
    n = integer_type(columns)
    lda = integer_type(rows)
    ldu = integer_type(rows)
    ldvt = integer_type(columns)
    lwork = integer_type(length(work))
    info = Ref{integer_type}(0)
    if use_external_lp64
        ccall(
            (:dgesvd_, _WANNIER90_REFERENCE_LP64_LAPACK),
            Cvoid,
            (
                Ref{UInt8},
                Ref{UInt8},
                Ref{Cint},
                Ref{Cint},
                Ptr{Float64},
                Ref{Cint},
                Ptr{Float64},
                Ptr{Float64},
                Ref{Cint},
                Ptr{Float64},
                Ref{Cint},
                Ptr{Float64},
                Ref{Cint},
                Ref{Cint},
            ),
            all_vectors,
            all_vectors,
            m,
            n,
            values,
            lda,
            singular_values,
            left,
            ldu,
            right_adjoint,
            ldvt,
            work,
            lwork,
            info,
        )
    else
        ccall(
            (LinearAlgebra.BLAS.@blasfunc(dgesvd_), LinearAlgebra.BLAS.libblastrampoline),
            Cvoid,
            (
                Ref{UInt8},
                Ref{UInt8},
                Ref{LinearAlgebra.BlasInt},
                Ref{LinearAlgebra.BlasInt},
                Ptr{Float64},
                Ref{LinearAlgebra.BlasInt},
                Ptr{Float64},
                Ptr{Float64},
                Ref{LinearAlgebra.BlasInt},
                Ptr{Float64},
                Ref{LinearAlgebra.BlasInt},
                Ptr{Float64},
                Ref{LinearAlgebra.BlasInt},
                Ref{LinearAlgebra.BlasInt},
            ),
            all_vectors,
            all_vectors,
            m,
            n,
            values,
            lda,
            singular_values,
            left,
            ldu,
            right_adjoint,
            ldvt,
            work,
            lwork,
            info,
        )
    end
    info[] == 0 || return nothing
    return (; singular_values, left, right_adjoint)
end

"""Wannier90-reference finite-difference weights with its unit roundoff path."""
function _wannier90_reference_finite_difference_weights(
    representation::BandRepresentation,
    mmn::WannierMMN;
    tolerance::Float64 = 1.0e-8,
    completeness_tolerance::Float64 = 1.0e-10,
    construction_policy::Symbol = :strict,
)
    vectors = Matrix{Float64}(undef, mmn.num_neighbors, 3)
    for neighbor in 1:mmn.num_neighbors
        _mesh_neighbor_displacement(representation, mmn, neighbor, 1; tolerance)
        vectors[neighbor, :] .=
            _wannier90_reference_edge_b_cartesian(representation, mmn, neighbor, 1)
    end
    shell_norms = Float64[]
    shell_indices = Vector{Vector{Int}}()
    shell_ids = zeros(Int, mmn.num_neighbors)
    for neighbor in axes(vectors, 1)
        length_value = norm(@view vectors[neighbor, :])
        shell = findfirst(value -> abs(value - length_value) <= tolerance, shell_norms)
        if shell === nothing
            push!(shell_norms, length_value)
            push!(shell_indices, [neighbor])
            shell_ids[neighbor] = length(shell_indices)
        else
            push!(shell_indices[shell], neighbor)
            shell_ids[neighbor] = shell
        end
    end
    # Wannier90 order for the six second-order monomials is
    # (xx, xy, yy, xz, yz, zz); target=(1,0,1,0,0,1).
    system = zeros(Float64, 6, length(shell_indices))
    for shell in eachindex(shell_indices)
        for neighbor in shell_indices[shell]
            vector = @view vectors[neighbor, :]
            x, y, z = vector
            system[1, shell] += x^2
            system[2, shell] += x * y
            system[3, shell] += y^2
            system[4, shell] += x * z
            system[5, shell] += y * z
            system[6, shell] += z^2
        end
    end
    target = Float64[1, 0, 1, 0, 0, 1]
    decomposition = _wannier90_reference_dgesvd(system)
    decomposition === nothing && throw(ArgumentError("WANNIER90_REFERENCE_STENCIL_SVD_FAILED"))
    singular_values = decomposition.singular_values
    any(value -> abs(value) < 1.0e-5, singular_values) &&
        throw(ArgumentError("WANNIER90_REFERENCE_STENCIL_SINGULAR"))
    tmp1 = zeros(Float64, 6)
    for shell in 1:6, equation in 1:6
        tmp1[shell] += decomposition.left[equation, shell] * target[equation]
    end
    tmp2 = zeros(Float64, length(shell_indices))
    for shell in eachindex(tmp2)
        tmp2[shell] = tmp1[shell] / singular_values[shell]
    end
    shell_weights = zeros(Float64, length(shell_indices))
    for shell in eachindex(shell_weights), inner in eachindex(tmp2)
        shell_weights[shell] += decomposition.right_adjoint[inner, shell] * tmp2[inner]
    end
    residual = norm(system * shell_weights - target)
    all(isfinite, shell_weights) && isfinite(residual) ||
        throw(ArgumentError("MMN_STENCIL_NONFINITE_WEIGHTS"))
    construction_policy == :diagnostic ||
        residual <= completeness_tolerance ||
        throw(ArgumentError("WANNIER90_REFERENCE_STENCIL_INCOMPLETE_3D"))
    weights = zeros(Float64, mmn.num_neighbors)
    for shell in eachindex(shell_indices), neighbor in shell_indices[shell]
        weights[neighbor] = shell_weights[shell]
    end
    return WannierizationFiniteDifferenceStencil(
        vectors,
        shell_ids,
        weights,
        Matrix{Float64}(I, 3, 3),
        residual,
        _finite_difference_stencil_sha256(vectors, shell_ids, weights, target),
    )
end
