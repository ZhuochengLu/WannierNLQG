# Build the localization reference from the untouched numerical AMN. Magnetic
# symmetry is imposed before the constrained polar alignment, never by replacing
# the raw projection data with the exact-frozen disentanglement initializer.
function _raw_amn_localization_reference(
    amn::Array{ComplexF64, 3},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    apply_symmetry::Bool,
    outer_indices::Vector{Vector{Int}},
    frozen_indices::Vector{Vector{Int}},
    wannier90_reference::Bool = false,
)
    frames = [Matrix{ComplexF64}(@view amn[:, :, kpoint]) for kpoint in axes(amn, 3)]
    all(frame -> all(isfinite, frame), frames) || return (
        success = false,
        code = :NONFINITE_RAW_AMN_LOCALIZATION_REFERENCE,
        frames,
        algorithm = :unavailable,
    )
    if wannier90_reference
        apply_symmetry && return (
            success = false,
            code = :WANNIER90_REFERENCE_MODE_MISMATCH,
            frames,
            algorithm = :unavailable,
        )
        for kpoint in eachindex(frames)
            outer = outer_indices[kpoint]
            decomposition = _wannier90_reference_dis_project(@view amn[outer, :, kpoint])
            decomposition.success || return (
                success = false,
                code = :WANNIER90_REFERENCE_AMN_SVD_FAILED,
                frames,
                algorithm = :wannier90_4_0_1_dis_project_reconstructed_amn,
            )
            frames[kpoint] .= 0.0
            frames[kpoint][outer, :] .= decomposition.reconstructed
        end
        return (
            success = true,
            code = :OK,
            frames,
            algorithm = :wannier90_4_0_1_dis_project_reconstructed_amn,
        )
    end
    if apply_symmetry && any(indices -> !isempty(indices), frozen_indices)
        try
            # This is a fresh projection of the untouched AMN at the stage
            # boundary.  It is not the carried exact-frozen solver frame: the
            # resulting target-compatible reference is subsequently projected
            # into the sealed S and aligned by one conditioned polar factor.
            projected, _, _ = _constrained_frozen_initial_frames(
                representation,
                plan,
                outer_indices,
                frozen_indices,
                amn,
            )
            return (
                success = true,
                code = :OK,
                frames = projected,
                algorithm = :type3_symmetry_compatible_raw_amn_projection,
            )
        catch exception
            exception isa FrozenCorepresentationInitializationError || rethrow()
            return (
                success = false,
                code = exception.code,
                frames,
                algorithm = :type3_symmetry_compatible_raw_amn_projection,
            )
        end
    end
    projected = apply_symmetry ? _symmetrize_ibz_frames_once(frames, representation, plan) : frames
    return (
        success = true,
        code = :OK,
        frames = projected,
        algorithm = apply_symmetry ? :raw_amn_little_group_projection : :raw_amn,
    )
end

# Restore a symmetry-expanded diagnostic frame to the exact sealed subspace.
#
# A non-full operation scope rebuilds its own k stars. Expanding a frame with
# finite-cutoff sewing matrices can then leave the otherwise unchanged sealed
# projector at the empirical sewing floor. The fixed-subspace ablation
# contract is stricter: Z must remain unchanged and only its in-subspace U
# gauge may move. Project each expanded frame through the sealed subspace and
# retain its closest conditioned polar factor. The full Type-IV path never
# calls this helper and therefore remains elementwise unchanged.
function _restore_expanded_frames_to_subspaces(
    frames::Vector{Matrix{ComplexF64}},
    subspaces::Vector{Matrix{ComplexF64}},
    tolerance::Float64,
    maximum_condition::Float64,
)
    length(frames) == length(subspaces) || return (
        success = false,
        code = :FIXED_SUBSPACE_DIMENSION_MISMATCH,
        frames,
        kpoint = 0,
        singular_values = Float64[],
        rank = 0,
        condition = Inf,
    )
    restored = deepcopy(frames)
    minimum_singular_value = Inf
    maximum_observed_condition = 0.0
    for kpoint in eachindex(frames)
        polar = _localization_svd_polar(
            subspaces[kpoint]' * frames[kpoint],
            tolerance,
            maximum_condition,
        )
        polar.success || return merge(polar, (frames = restored, kpoint = kpoint))
        restored[kpoint] = subspaces[kpoint] * polar.unitary
        minimum_singular_value = min(minimum_singular_value, minimum(polar.singular_values))
        maximum_observed_condition = max(maximum_observed_condition, polar.condition)
    end
    reference_projectors = [subspace * subspace' for subspace in subspaces]
    projector_drift = _maximum_projector_drift(restored, reference_projectors)
    return (
        success = true,
        code = :OK,
        frames = restored,
        kpoint = 0,
        singular_values = Float64[],
        rank = size(first(subspaces), 2),
        condition = maximum_observed_condition,
        minimum_singular_value,
        maximum_condition = maximum_observed_condition,
        projector_drift,
    )
end

"""Deterministic canonical complement of an orthonormal column frame."""
function _deterministic_canonical_complement(
    active::AbstractMatrix{<:Complex},
    dimension::Int,
    count::Int;
    tolerance::Float64 = 1.0e-12,
)
    count == 0 && return zeros(ComplexF64, dimension, 0)
    basis = Matrix{ComplexF64}(active)
    output = zeros(ComplexF64, dimension, count)
    for column in 1:count
        best_index = 0
        best_vector = zeros(ComplexF64, dimension)
        best_norm = -Inf
        for index in 1:dimension
            candidate = zeros(ComplexF64, dimension)
            candidate[index] = 1.0
            isempty(basis) || (candidate .-= basis * (basis' * candidate))
            if column > 1
                previous = @view output[:, 1:(column - 1)]
                candidate .-= previous * (previous' * candidate)
            end
            candidate_norm = norm(candidate)
            if candidate_norm > best_norm + tolerance || (
                abs(candidate_norm - best_norm) <= tolerance &&
                (best_index == 0 || index < best_index)
            )
                best_index = index
                best_vector = candidate
                best_norm = candidate_norm
            end
        end
        best_norm > tolerance || throw(ArgumentError("deterministic complement is rank deficient"))
        best_vector ./= best_norm
        pivot = argmax(abs.(best_vector))
        abs(best_vector[pivot]) > tolerance &&
            (best_vector .*= conj(best_vector[pivot]) / abs(best_vector[pivot]))
        output[:, column] .= best_vector
    end
    return output
end

"""Conditioned sealed-subspace AMN polar with deterministic null completion."""
function _sealed_amn_polar(
    projected_amn::AbstractMatrix{<:Complex},
    minimum_singular_value::Float64,
    maximum_condition::Float64,
)
    size(projected_amn, 1) == size(projected_amn, 2) || return (
        success = false,
        code = :SINGULAR_LOCALIZATION_ALIGNMENT,
        unitary = zeros(ComplexF64, size(projected_amn)),
        singular_values = Float64[],
        rank = 0,
        condition = Inf,
        completion_count = 0,
    )
    decomposition = svd(Matrix{ComplexF64}(projected_amn))
    singular_values = Float64.(decomposition.S)
    all(isfinite, singular_values) || return (
        success = false,
        code = :NONFINITE_LOCALIZATION_ALIGNMENT,
        unitary = zeros(ComplexF64, size(projected_amn)),
        singular_values,
        rank = 0,
        condition = Inf,
        completion_count = 0,
    )
    threshold = max(minimum_singular_value, eps(Float64) * maximum(size(projected_amn)))
    numerical_rank = count(value -> value >= threshold, singular_values)
    condition =
        numerical_rank == 0 ? 1.0 : maximum(singular_values) / singular_values[numerical_rank]
    condition <= maximum_condition || return (
        success = false,
        code = :ILL_CONDITIONED_LOCALIZATION_ALIGNMENT,
        unitary = zeros(ComplexF64, size(projected_amn)),
        singular_values,
        rank = numerical_rank,
        condition,
        completion_count = size(projected_amn, 1) - numerical_rank,
    )
    dimension = size(projected_amn, 1)
    left_active = decomposition.U[:, 1:numerical_rank]
    right_active = decomposition.V[:, 1:numerical_rank]
    completion_count = dimension - numerical_rank
    left_null = _deterministic_canonical_complement(
        left_active,
        dimension,
        completion_count;
        tolerance = threshold,
    )
    right_null = _deterministic_canonical_complement(
        right_active,
        dimension,
        completion_count;
        tolerance = threshold,
    )
    unitary = left_active * right_active' + left_null * right_null'
    return (
        success = true,
        code = :OK,
        unitary,
        singular_values,
        rank = numerical_rank,
        condition,
        completion_count,
    )
end

"""Wannier90 4.0.1 `internal_find_u` full-SVD polar.

The upstream routine multiplies every left and right singular vector returned
by ZGESVD, including numerically small directions.  The reference route must
therefore not apply the projectability rank threshold or deterministic null
completion used by the conditioned expert routes.
"""
function _wannier90_reference_amn_polar(projected_amn::AbstractMatrix{<:Complex})
    size(projected_amn, 1) == size(projected_amn, 2) || return (
        success = false,
        code = :SINGULAR_LOCALIZATION_ALIGNMENT,
        unitary = zeros(ComplexF64, size(projected_amn)),
        singular_values = Float64[],
        rank = 0,
        condition = Inf,
        completion_count = 0,
    )
    decomposition = _wannier90_reference_dis_project(projected_amn)
    singular_values = decomposition.singular_values
    decomposition.success || return (
        success = false,
        code = :WANNIER90_REFERENCE_AMN_SVD_FAILED,
        unitary = zeros(ComplexF64, size(projected_amn)),
        singular_values,
        rank = 0,
        condition = Inf,
        completion_count = 0,
    )
    all(isfinite, singular_values) || return (
        success = false,
        code = :NONFINITE_LOCALIZATION_ALIGNMENT,
        unitary = zeros(ComplexF64, size(projected_amn)),
        singular_values,
        rank = 0,
        condition = Inf,
        completion_count = 0,
    )
    # `dis_project` reconstructs its rectangular polar factor with explicit
    # scalar loops, whereas `internal_find_u` forms the square C_Z C_V product
    # with ZGEMM.  Reusing `decomposition.frame` here therefore implements the
    # wrong arithmetic contract even though the SVD itself is identical.
    # Preserve the two upstream paths separately.
    unitary = _wannier90_reference_zgemm(
        @view(decomposition.left_vectors[:, 1:size(projected_amn, 1)]),
        'N',
        @view(decomposition.right_adjoint[1:size(projected_amn, 1), :]),
        'N',
    )
    all(isfinite, unitary) || return (
        success = false,
        code = :NONFINITE_LOCALIZATION_ALIGNMENT,
        unitary,
        singular_values,
        rank = 0,
        condition = Inf,
        completion_count = 0,
    )
    smallest = isempty(singular_values) ? 0.0 : minimum(singular_values)
    condition = smallest <= 0.0 ? Inf : maximum(singular_values) / smallest
    return (
        success = true,
        code = :OK,
        unitary,
        singular_values,
        rank = length(singular_values),
        condition,
        completion_count = 0,
    )
end

# Align projected reference frames by conditioned polar factors on the IBZ.
function _projected_reference_alignment(
    subspace_frames::Vector{Matrix{ComplexF64}},
    reference_frames::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    tolerance::Float64,
    maximum_condition::Float64,
    minimum_singular_value::Float64,
    apply_symmetry::Bool,
    restore_fixed_subspace::Bool = false,
    wannier90_reference::Bool = false,
    outer_indices::Union{Nothing, Vector{Vector{Int}}} = nothing,
)
    aligned = deepcopy(subspace_frames)
    spectra = [Float64[] for _ in eachindex(subspace_frames)]
    ranks = zeros(Int, length(subspace_frames))
    completion_counts = zeros(Int, length(subspace_frames))
    conditions = fill(NaN, length(subspace_frames))
    unitaries = [Matrix{ComplexF64}(I, size(frame, 2), size(frame, 2)) for frame in subspace_frames]
    for kpoint in representation.irreducible_indices
        # Wannier90's `internal_find_u` forms C_AA = U_opt^H A and the
        # completed localization frame with the LP64 ZGEMM linked into the
        # registered 4.0.1 oracle.  Generic Julia `*` is algebraically
        # equivalent, but it changes the reduction order at this stage and
        # produces a measurable first divergence in the Cr U initializer.
        # Keep this dedicated numerical contract confined to the explicit
        # reference algorithm; all other localization backends retain their
        # existing multiplication path.
        projected = if wannier90_reference
            outer_indices === nothing && throw(
                ArgumentError(
                    "Wannier90-reference AMN alignment requires explicit outer-window indices",
                ),
            )
            length(something(outer_indices)) == length(subspace_frames) ||
                throw(DimensionMismatch("Wannier90-reference outer-window list is incomplete"))
            _wannier90_reference_logical_window_caa(
                subspace_frames[kpoint],
                reference_frames[kpoint],
                something(outer_indices)[kpoint],
            )
        else
            subspace_frames[kpoint]' * reference_frames[kpoint]
        end
        polar =
            wannier90_reference ? _wannier90_reference_amn_polar(projected) :
            _sealed_amn_polar(projected, minimum_singular_value, maximum_condition)
        polar.success || return merge(polar, (kpoint = kpoint,))
        spectra[kpoint] = polar.singular_values
        ranks[kpoint] = polar.rank
        completion_counts[kpoint] = polar.completion_count
        conditions[kpoint] = polar.condition
        unitaries[kpoint] = polar.unitary
        aligned[kpoint] =
            wannier90_reference ?
            _wannier90_reference_zgemm(subspace_frames[kpoint], 'N', polar.unitary, 'N') :
            subspace_frames[kpoint] * polar.unitary
    end
    aligned = apply_symmetry ? _expand_ibz_frames(aligned, representation, plan) : aligned
    if restore_fixed_subspace
        restored = _restore_expanded_frames_to_subspaces(
            aligned,
            subspace_frames,
            tolerance,
            maximum_condition,
        )
        restored.success || return restored
        aligned = restored.frames
    end
    reference_projectors = [subspace * subspace' for subspace in subspace_frames]
    projector_drift = _maximum_projector_drift(aligned, reference_projectors)
    projector_drift_tolerance = wannier90_reference ? 1.0e-10 : 1.0e-12
    projector_drift <= projector_drift_tolerance || return (
        success = false,
        code = :FIXED_SUBSPACE_PROJECTOR_DRIFT,
        frames = aligned,
        kpoint = 0,
        singular_values = Float64[],
        rank = 0,
        condition = Inf,
        projector_drift,
    )
    finite_spectra = filter(values -> !isempty(values), spectra)
    finite_conditions = filter(isfinite, conditions)
    return (
        success = true,
        code = :OK,
        frames = aligned,
        spectra,
        ranks,
        completion_counts,
        conditions,
        minimum_singular_value = isempty(finite_spectra) ? NaN :
                                 minimum(minimum(values) for values in finite_spectra),
        maximum_condition = isempty(finite_conditions) ? NaN : maximum(finite_conditions),
        projector_drift,
        unitaries,
    )
end

# Complete a newly selected IBZ subspace over every k star before deriving
# fixed projectors for the transactional U step.  Entries outside the IBZ still
# contain the previous accepted frames while `_maximum_subspace_result` is
# running; treating those stale entries as the new projector makes the
# subsequent symmetry expansion appear to change the projector by O(1).
function _complete_selected_subspace_star(
    subspaces::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    apply_symmetry::Bool,
)
    return apply_symmetry ? _expand_ibz_frames(subspaces, representation, plan) : subspaces
end

# Project a seed onto the target corepresentation inside one already selected
# symmetry-invariant band projector.  Unlike the frozen initializer, both the
# band and target complements are supplied explicitly by the Z continuity
# transport.
function _selected_corepresentation_embedding(
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    representative::Int,
    selected_projector::Matrix{ComplexF64},
    target_projector::Matrix{ComplexF64},
    operation_mapping::Vector{Int},
    probe::Matrix{ComplexF64},
)
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
    return selected_projector * (projected ./ count) * target_projector
end

# Reconstruct the complete target corepresentation inside one selected band
# projector.  This path is used only when continuity overlap loses rank: a
# partial singular subspace need not itself carry a closed (co)representation,
# so completing its orthogonal complement independently can preserve the band
# projector while violating the target group law.  A full little-group
# intertwiner either has the requested rank or fails closed as representation
# incompatibility evidence.
function _reconstruct_selected_corepresentation(
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    representative::Int,
    selected_frame::Matrix{ComplexF64},
    reference_frame::Matrix{ComplexF64},
    operation_mapping::Vector{Int},
    relative_tolerance::Float64,
    maximum_condition::Float64,
)
    num_wannier = size(selected_frame, 2)
    selected_projector = selected_frame * selected_frame'
    selected_basis = _deterministic_projector_basis(
        selected_projector,
        num_wannier,
        max(relative_tolerance, eps(Float64)),
    )
    selected_basis === nothing &&
        return (success = false, frame = nothing, singular_values = Float64[], condition = Inf)
    target_projector = Matrix{ComplexF64}(I, num_wannier, num_wannier)
    best_frame = nothing
    best_singular_values = Float64[]
    best_condition = Inf
    best_score = -Inf
    for probe_index in 0:9
        probe = if probe_index == 0
            reference_frame
        elseif probe_index == 1
            selected_frame
        else
            rng = MersenneTwister(UInt64(0x7a2d66756c6c) + UInt64(8191 * representative + probe_index))
            coefficients =
                randn(rng, num_wannier, num_wannier) .+
                1.0im .* randn(rng, num_wannier, num_wannier)
            selected_frame * coefficients
        end
        projected = _selected_corepresentation_embedding(
            representation,
            plan,
            representative,
            selected_projector,
            target_projector,
            operation_mapping,
            probe,
        )
        coordinates = something(selected_basis)' * projected
        scale = opnorm(coordinates)
        isfinite(scale) && scale > eps(Float64) || continue
        coordinate_polar, singular_values, condition = _rank_gated_svd_polar_columns(
            coordinates ./ scale;
            minimum_singular_value = max(relative_tolerance, eps(Float64)),
            maximum_condition,
        )
        coordinate_polar === nothing && continue
        score = minimum(singular_values; init = Inf)
        score > best_score || continue
        best_score = score
        best_singular_values = singular_values
        best_condition = condition
        best_frame = something(selected_basis) * something(coordinate_polar)
    end
    return (
        success = best_frame !== nothing,
        frame = best_frame,
        singular_values = best_singular_values,
        condition = best_condition,
    )
end

# Enumerate a bounded lexicographic combination set without adding a package
# dependency.  The symmetry-aware selector uses this only after the ordinary
# leading eigenspace proves representation-incompatible.
function _bounded_index_combinations(count::Int, selected_count::Int, maximum_combinations::Int)
    0 <= selected_count <= count || return nothing
    binomial_count = binomial(BigInt(count), BigInt(selected_count))
    binomial_count <= maximum_combinations || return nothing
    output = Vector{Vector{Int}}()
    current = Vector{Int}(undef, selected_count)
    function visit(start::Int, depth::Int)
        remaining = selected_count - depth + 1
        if remaining == 0
            push!(output, copy(current))
            return
        end
        for index in start:(count - remaining + 1)
            current[depth] = index
            visit(index + 1, depth + 1)
        end
    end
    visit(1, 1)
    return output
end

# Select the highest-weight eigenspace whose little-group inventory contains
# the complete accepted target corepresentation.  Frozen bands are retained
# exactly.  Because the SMV field is Hermitian and symmetry covariant, the
# constrained optimum is a union of its little-group eigenspaces; enumerating
# the small outer-window complement is exact for this boundary selection, not
# a stochastic multi-start approximation.
function _corepresentation_aware_maximum_subspace_result(
    selected,
    outer_indices::Vector{Int},
    frozen_indices::Vector{Int},
    num_wannier::Int,
    reference_frame::Matrix{ComplexF64},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    representative::Int,
    operation_mapping::Vector{Int},
    relative_tolerance::Float64,
    maximum_condition::Float64;
    maximum_combinations::Int = 4096,
)
    selected.success || return selected
    overlap_singular_values = svdvals(something(selected.frame)' * reference_frame)
    sigma_maximum = maximum(overlap_singular_values; init = 0.0)
    rank_ratio = max(relative_tolerance, inv(maximum_condition))
    overlap_rank =
        sigma_maximum == 0.0 ? 0 :
        count(value -> value / sigma_maximum >= rank_ratio, overlap_singular_values)
    overlap_rank == num_wannier && return (
        success = true,
        code = :OK,
        frame = something(selected.frame),
        selection_method = :corepresentation_continuity_full_rank,
        combination_count = 1,
        selected_eigenvector_indices = collect(1:(num_wannier - length(frozen_indices))),
        constrained_eigenvalue_sum = sum(
            selected.eligible_values[1:(num_wannier - length(frozen_indices))];
            init = 0.0,
        ),
    )
    reconstructed = _reconstruct_selected_corepresentation(
        representation,
        plan,
        representative,
        something(selected.frame),
        reference_frame,
        operation_mapping,
        relative_tolerance,
        maximum_condition,
    )
    reconstructed.success && return (
        success = true,
        code = :OK,
        frame = something(reconstructed.frame),
        selection_method = :corepresentation_reconstructed_leading_eigenspace,
        combination_count = 1,
        selected_eigenvector_indices = collect(1:(num_wannier - length(frozen_indices))),
        constrained_eigenvalue_sum = sum(
            selected.eligible_values[1:(num_wannier - length(frozen_indices))];
            init = 0.0,
        ),
    )
    needed = num_wannier - length(frozen_indices)
    combinations =
        _bounded_index_combinations(length(selected.eligible_vectors), needed, maximum_combinations)
    combinations === nothing && return (
        success = false,
        code = :SUBSPACE_COREPRESENTATION_SEARCH_SPACE_EXCEEDED,
        message = "corepresentation-aware eigenspace search exceeds its deterministic bound",
        kpoint = representative,
        rank = overlap_rank,
        condition = Inf,
        candidate_count = binomial(BigInt(length(selected.eligible_vectors)), BigInt(needed)),
        maximum_combinations,
        invariant_residual = Inf,
    )
    scored = [
        (indices, score = sum(selected.eligible_values[index] for index in indices; init = 0.0)) for indices in combinations
    ]
    sort!(
        scored;
        lt = (left, right) ->
            left.score > right.score ||
            (left.score == right.score && Tuple(left.indices) < Tuple(right.indices)),
    )
    outer_position = Dict(index => position for (position, index) in enumerate(outer_indices))
    frozen_local = [outer_position[index] for index in frozen_indices]
    dimension = length(outer_indices)
    tested_count = 0
    for candidate in scored
        tested_count += 1
        local_frame = zeros(ComplexF64, dimension, num_wannier)
        column = 1
        for index in frozen_local
            local_frame[index, column] = 1.0
            column += 1
        end
        for eigenvector_index in candidate.indices
            local_frame[:, column] .= selected.eligible_vectors[eigenvector_index]
            column += 1
        end
        orthonormalized =
            _orthonormalize_columns(local_frame, max(relative_tolerance, eps(Float64)))
        orthonormalized === nothing && continue
        candidate_frame = zeros(ComplexF64, size(reference_frame))
        candidate_frame[outer_indices, :] .= something(orthonormalized)
        candidate_corepresentation = _reconstruct_selected_corepresentation(
            representation,
            plan,
            representative,
            candidate_frame,
            reference_frame,
            operation_mapping,
            relative_tolerance,
            maximum_condition,
        )
        candidate_corepresentation.success || continue
        return (
            success = true,
            code = :OK,
            frame = something(candidate_corepresentation.frame),
            selection_method = :corepresentation_constrained_eigenspace,
            combination_count = tested_count,
            selected_eigenvector_indices = candidate.indices,
            constrained_eigenvalue_sum = candidate.score,
        )
    end
    return (
        success = false,
        code = :SUBSPACE_COREPRESENTATION_SELECTION_FAILED,
        message = "no SMV eigenspace carries the complete target corepresentation",
        kpoint = representative,
        rank = overlap_rank,
        condition = Inf,
        candidate_count = length(scored),
        maximum_combinations,
        invariant_residual = Inf,
    )
end

# A symmetry-invariant projector does not determine a symmetry-compatible
# frame: an eigensolver may return any unitary gauge inside a degenerate
# selected subspace.  Preserve a full-rank overlap by its polar factor.  If Z
# replaces orthogonal directions, reconstruct the complete little-group
# intertwiner inside the new selected projector; partial singular subspaces
# need not themselves close under the magnetic group.  This is not an
# unconstrained pseudoinverse: reconstruction fails closed unless the new
# projector contains the full unitary/antiunitary target corepresentation.
function _transport_selected_subspace_corepresentation(
    subspaces::Vector{Matrix{ComplexF64}},
    reference_frames::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    relative_tolerance::Float64,
    maximum_condition::Float64,
    covariance_tolerance::Float64;
    construction_policy::Symbol = :strict,
)
    length(subspaces) == length(reference_frames) || return (
        success = false,
        code = :SUBSPACE_COREPRESENTATION_TRANSPORT_DIMENSION_MISMATCH,
        message = "selected and reference frame meshes disagree",
        kpoint = 0,
        invariant_residual = Inf,
    )
    operation_mapping, inventory_diagnostics =
        validate_target_operation_inventory(representation, plan, covariance_tolerance)
    isempty(inventory_diagnostics) || return (
        success = false,
        code = :SUBSPACE_COREPRESENTATION_OPERATION_INVENTORY_MISMATCH,
        message = "band and target operation inventories cannot be matched",
        kpoint = 0,
        invariant_residual = Inf,
    )
    transported = deepcopy(subspaces)
    minimum_singular_value = Inf
    maximum_observed_condition = 0.0
    completion_count = 0
    maximum_local_isometry_residual = 0.0
    maximum_local_projector_drift = 0.0
    maximum_local_residual_representative = 0
    maximum_local_retained_rank = 0
    maximum_local_missing_rank = 0
    worst_selected_isometry_residual = 0.0
    worst_active_gram_residual = 0.0
    worst_remaining_projector_idempotence_residual = 0.0
    worst_remaining_active_annihilation_residual = 0.0
    worst_completion_isometry_residual = 0.0
    worst_completion_containment_residual = 0.0
    worst_completion_cross_residual = 0.0
    worst_target_complement_basis_isometry_residual = 0.0
    for representative in representation.irreducible_indices
        size(subspaces[representative]) == size(reference_frames[representative]) || return (
            success = false,
            code = :SUBSPACE_COREPRESENTATION_TRANSPORT_DIMENSION_MISMATCH,
            message = "selected and reference frame dimensions disagree",
            kpoint = representative,
            invariant_residual = Inf,
        )
        overlap = subspaces[representative]' * reference_frames[representative]
        decomposition = svd(Matrix{ComplexF64}(overlap))
        singular_values = Float64.(decomposition.S)
        sigma_maximum = maximum(singular_values; init = 0.0)
        rank_ratio = max(relative_tolerance, inv(maximum_condition))
        retained_rank =
            sigma_maximum == 0.0 ? 0 :
            count(value -> value / sigma_maximum >= rank_ratio, singular_values)
        minimum_singular_value = min(minimum_singular_value, minimum(singular_values; init = 0.0))
        retained_condition =
            retained_rank == 0 ? 1.0 : sigma_maximum / singular_values[retained_rank]
        maximum_observed_condition = max(maximum_observed_condition, retained_condition)
        active_transport = if retained_rank == 0
            zeros(ComplexF64, size(overlap))
        else
            decomposition.U[:, 1:retained_rank] * decomposition.Vt[1:retained_rank, :]
        end
        transported_frame = subspaces[representative] * active_transport
        missing_rank = size(overlap, 1) - retained_rank
        selected_isometry_residual = norm(
            subspaces[representative]' * subspaces[representative] -
            Matrix{ComplexF64}(I, size(overlap, 1), size(overlap, 1)),
        )
        active_gram_residual =
            norm(transported_frame' * transported_frame - active_transport' * active_transport)
        remaining_projector_idempotence_residual = 0.0
        remaining_active_annihilation_residual = 0.0
        completion_isometry_residual = 0.0
        completion_containment_residual = 0.0
        completion_cross_residual = 0.0
        target_complement_basis_isometry_residual = 0.0
        if missing_rank > 0
            reconstructed = _reconstruct_selected_corepresentation(
                representation,
                plan,
                representative,
                subspaces[representative],
                reference_frames[representative],
                operation_mapping,
                relative_tolerance,
                maximum_condition,
            )
            reconstructed.success || return (
                success = false,
                code = :SUBSPACE_COREPRESENTATION_MISMATCH,
                message = "selected projector does not contain the complete target corepresentation",
                kpoint = representative,
                singular_values,
                rank = retained_rank,
                condition = retained_condition,
                completion_singular_values = reconstructed.singular_values,
                completion_condition = reconstructed.condition,
                invariant_residual = Inf,
            )
            transported_frame = something(reconstructed.frame)
            completion_count += missing_rank
            maximum_observed_condition = max(maximum_observed_condition, reconstructed.condition)
        end
        local_isometry_residual = norm(
            transported_frame' * transported_frame -
            Matrix{ComplexF64}(I, size(transported_frame, 2), size(transported_frame, 2)),
        )
        local_projector_drift = norm(
            transported_frame * transported_frame' -
            subspaces[representative] * subspaces[representative]',
        )
        if max(local_isometry_residual, local_projector_drift) >
           max(maximum_local_isometry_residual, maximum_local_projector_drift)
            maximum_local_residual_representative = representative
            maximum_local_retained_rank = retained_rank
            maximum_local_missing_rank = missing_rank
            worst_selected_isometry_residual = selected_isometry_residual
            worst_active_gram_residual = active_gram_residual
            worst_remaining_projector_idempotence_residual =
                remaining_projector_idempotence_residual
            worst_remaining_active_annihilation_residual = remaining_active_annihilation_residual
            worst_completion_isometry_residual = completion_isometry_residual
            worst_completion_containment_residual = completion_containment_residual
            worst_completion_cross_residual = completion_cross_residual
            worst_target_complement_basis_isometry_residual =
                target_complement_basis_isometry_residual
        end
        maximum_local_isometry_residual =
            max(maximum_local_isometry_residual, local_isometry_residual)
        maximum_local_projector_drift = max(maximum_local_projector_drift, local_projector_drift)
        transported[representative] = transported_frame
    end
    completed_subspaces = _expand_ibz_frames(subspaces, representation, plan)
    transported = _expand_ibz_frames(transported, representation, plan)
    selected_projectors = [frame * frame' for frame in completed_subspaces]
    full_bz_projector_drifts = [
        norm(transported[kpoint] * transported[kpoint]' - selected_projectors[kpoint]) for
        kpoint in eachindex(transported)
    ]
    worst_projector_kpoint = argmax(full_bz_projector_drifts)
    projector_drift = full_bz_projector_drifts[worst_projector_kpoint]
    worst_ibz_index = representation.full_to_irreducible[worst_projector_kpoint]
    source_representative = representation.irreducible_indices[worst_ibz_index]
    expansion_operation_index = representation.full_to_operation[worst_projector_kpoint]
    expansion_target = target_representation(
        plan,
        representation,
        expansion_operation_index,
        source_representative,
        operation_mapping[expansion_operation_index],
    )
    expansion_sewing =
        @view representation.sewing_matrices[:, :, expansion_operation_index, source_representative]
    target_unitarity_residual = norm(
        expansion_target' * expansion_target -
        Matrix{ComplexF64}(I, size(expansion_target, 2), size(expansion_target, 2)),
    )
    sewing_isometry_residual = norm(
        expansion_sewing' * expansion_sewing -
        Matrix{ComplexF64}(I, size(expansion_sewing, 2), size(expansion_sewing, 2)),
    )
    projector_drift <= covariance_tolerance || return (
        success = false,
        code = :SUBSPACE_COREPRESENTATION_PROJECTOR_DRIFT,
        message = "corepresentation transport changed the selected projector",
        frames = transported,
        kpoint = worst_projector_kpoint,
        source_representative,
        minimum_singular_value,
        maximum_condition = maximum_observed_condition,
        completion_count,
        projector_drift,
        maximum_local_isometry_residual,
        maximum_local_projector_drift,
        maximum_local_residual_representative,
        maximum_local_retained_rank,
        maximum_local_missing_rank,
        worst_selected_isometry_residual,
        worst_active_gram_residual,
        worst_remaining_projector_idempotence_residual,
        worst_remaining_active_annihilation_residual,
        worst_completion_isometry_residual,
        worst_completion_containment_residual,
        worst_completion_cross_residual,
        worst_target_complement_basis_isometry_residual,
        target_unitarity_residual,
        sewing_isometry_residual,
        invariant_residual = projector_drift,
    )
    target_symmetry = _maximum_target_frame_symmetry_error(transported, representation, plan)
    (
        isfinite(target_symmetry) &&
        (construction_policy == :diagnostic || target_symmetry <= covariance_tolerance)
    ) || return (
        success = false,
        code = :SUBSPACE_COREPRESENTATION_TRANSPORT_FAILED,
        message = "transported selected frame does not realize the accepted target corepresentation",
        frames = transported,
        kpoint = 0,
        minimum_singular_value,
        maximum_condition = maximum_observed_condition,
        completion_count,
        projector_drift,
        maximum_local_isometry_residual,
        maximum_local_projector_drift,
        maximum_local_residual_representative,
        maximum_local_retained_rank,
        maximum_local_missing_rank,
        worst_selected_isometry_residual,
        worst_active_gram_residual,
        worst_remaining_projector_idempotence_residual,
        worst_remaining_active_annihilation_residual,
        worst_completion_isometry_residual,
        worst_completion_containment_residual,
        worst_completion_cross_residual,
        worst_target_complement_basis_isometry_residual,
        target_unitarity_residual,
        sewing_isometry_residual,
        target_symmetry,
        invariant_residual = target_symmetry,
    )
    return (
        success = true,
        code = :OK,
        frames = transported,
        kpoint = 0,
        minimum_singular_value,
        maximum_condition = maximum_observed_condition,
        completion_count,
        projector_drift,
        maximum_local_isometry_residual,
        maximum_local_projector_drift,
        maximum_local_residual_representative,
        maximum_local_retained_rank,
        maximum_local_missing_rank,
        worst_selected_isometry_residual,
        worst_active_gram_residual,
        worst_remaining_projector_idempotence_residual,
        worst_remaining_active_annihilation_residual,
        worst_completion_isometry_residual,
        worst_completion_containment_residual,
        worst_completion_cross_residual,
        worst_target_complement_basis_isometry_residual,
        target_unitarity_residual,
        sewing_isometry_residual,
        target_symmetry,
    )
end

"""Commit a two-stage Z candidate without entering any localization code."""
function _disentanglement_candidate(
    config::SymmetryAdaptedWannierizationConfig,
    representation::BandRepresentation,
    mmn::WannierMMN,
    plan::WannierSymmetryPlan,
    weights::Vector{Float64},
    frozen_indices::Vector{Vector{Int}},
    subspaces::Vector{Matrix{ComplexF64}},
    centers::Matrix{Float64},
    spreads::Vector{Float64},
    projector_covariance_tolerance::Float64,
)
    apply_symmetry = symmetry_constraints_applied(config, representation)
    failure = _candidate_invariant_failure(
        subspaces,
        centers,
        spreads,
        frozen_indices,
        representation,
        plan,
        config.input.representation_tolerance,
        projector_covariance_tolerance,
        apply_symmetry;
        construction_policy = config.input.construction_policy,
    )
    failure === nothing || return (
        success = false,
        code = first(failure),
        message = "disentanglement projector failed a structural invariant",
        kpoint = 0,
        invariant_residual = last(failure),
    )
    nk = length(subspaces)
    omega_i = _gauge_invariant_spread(subspaces, mmn, weights)
    return (
        success = true,
        code = :OK,
        frames = deepcopy(subspaces),
        centers = copy(centers),
        spreads = copy(spreads),
        directional = nothing,
        u_residual = 0.0,
        gradient_rms = Inf,
        projection_converged = true,
        projection_iterations = 0,
        projection_residual = 0.0,
        completed_sweeps = 0,
        accepted_step_scale = 0.0,
        backtracking_steps = 0,
        trial_objective = sum(spreads),
        accepted_objective = sum(spreads),
        localization_spectra = [Float64[] for _ in 1:nk],
        localization_ranks = zeros(Int, nk),
        localization_conditions = fill(NaN, nk),
        raw_eigenphases = [Float64[] for _ in 1:nk],
        aligned_eigenphases = [Float64[] for _ in 1:nk],
        raw_geodesic_distances = fill(NaN, nk),
        aligned_geodesic_distances = fill(NaN, nk),
        block_permutations = [Int[] for _ in 1:nk],
        block_phases = [Float64[] for _ in 1:nk],
        polar_fallback_triggered = false,
        active_localization_algorithm = :not_run_z_only,
        base_objective = sum(spreads),
        trial_zero_objective = sum(spreads),
        trial_zero_frame_residual = 0.0,
        attempted_step_scales = Float64[],
        attempted_objectives = Float64[],
        attempted_required_changes = Float64[],
        attempted_actual_changes = Float64[],
        attempted_directional_derivatives = Float64[],
        attempted_sweeps = Int[],
        attempted_accepted = Bool[],
        directional_derivative = NaN,
        fixed_projector_drift = NaN,
        accepted_required_change = NaN,
        accepted_actual_change = NaN,
        minimum_diagonal_phase_margin = Inf,
        minimum_phase_kpoint = 0,
        minimum_phase_neighbor = 0,
        minimum_phase_wannier = 0,
        minimum_phase_value = NaN,
        branch_safe_backtracking_triggered = false,
        previous_u_gradient = nothing,
        previous_u_direction = nothing,
        u_cg_iteration = 0,
        u_cg_restart_count = 0,
        cg_beta = NaN,
        cg_restarted = false,
        cg_restart_reason = :NOT_APPLICABLE,
        cg_descent_cosine = NaN,
        kstar_gradient_rms = Float64[],
        maximum_kstar_gradient_rms = NaN,
        maximum_kstar_gradient_index = 0,
        transport_minimum_singular_value = NaN,
        transport_maximum_condition = NaN,
        transported_omega_i = omega_i,
        u_phase_contract = LOCALIZATION_GRADIENT_CONTRACT,
        u_active_orbit_sha256 = "",
        u_active_orbit_count = 0,
        generalized_gradient_rms = Inf,
        u_lbfgs_s_history = Vector{Vector{Matrix{ComplexF64}}}(),
        u_lbfgs_y_history = Vector{Vector{Matrix{ComplexF64}}}(),
        u_lbfgs_rho_history = Float64[],
        u_lbfgs_restart_count = 0,
        u_optimizer_restart_reason = :NOT_APPLICABLE,
    )
end

# Select the fixed outer subspace and run the configured synchronized U sweeps.
function _outer_iteration_candidate(
    config::SymmetryAdaptedWannierizationConfig,
    representation::BandRepresentation,
    mmn::WannierMMN,
    plan::WannierSymmetryPlan,
    weights::Vector{Float64},
    included_bands::Vector{BitVector},
    outer_indices::Vector{Vector{Int}},
    frozen_indices::Vector{Vector{Int}},
    num_wannier::Int,
    z_proposal::Vector{Matrix{ComplexF64}},
    frames::Vector{Matrix{ComplexF64}},
    centers::Matrix{Float64},
    spreads::Vector{Float64},
    u_mix_ratio::Float64,
    projector_covariance_tolerance::Float64,
    tangent_plans::Vector{Union{Nothing, TargetSymmetryTangentPlan}},
    localize::Bool,
    localization_algorithm::Symbol,
    ;
    fixed_stage_subspaces::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
    fixed_stage_projectors::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
    localization_reference_frames::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
    spectrum_audit::Union{Nothing, HermitianSpectrumAudit} = nothing,
    iteration::Int = 0,
    previous_u_gradient::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
    previous_u_direction::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
    u_cg_iteration::Int = 0,
    u_cg_restart_count::Int = 0,
    u_lbfgs_s_history::Vector{Vector{Matrix{ComplexF64}}} = Vector{Vector{Matrix{ComplexF64}}}(),
    u_lbfgs_y_history::Vector{Vector{Matrix{ComplexF64}}} = Vector{Vector{Matrix{ComplexF64}}}(),
    u_lbfgs_rho_history::Vector{Float64} = Float64[],
    u_lbfgs_restart_count::Int = 0,
    u_branch_signature::String = "",
    wannier90_reference_overlaps::Union{Nothing, Array{ComplexF64, 4}} = nothing,
    wannier90_reference_omega_i::Union{Nothing, Float64} = nothing,
    wannier90_reference_unitaries::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
)
    corepresentation_transport_applied = false
    corepresentation_transport_minimum_singular_value = NaN
    corepresentation_transport_maximum_condition = NaN
    corepresentation_transport_projector_drift = NaN
    corepresentation_transport_target_symmetry = NaN
    subspaces = if fixed_stage_subspaces === nothing
        selected_subspaces = deepcopy(frames)
        disentanglement_algorithm =
            effective_wannierization_algorithms(config, representation).disentanglement
        apply_symmetry = symmetry_constraints_applied(config, representation)
        corepresentation_aware_selection =
            apply_symmetry && _is_symmetry_projected_smv_fr(disentanglement_algorithm)
        operation_mapping, inventory_diagnostics = if corepresentation_aware_selection
            validate_target_operation_inventory(representation, plan, projector_covariance_tolerance)
        else
            Int[], WannierizationDiagnostic[]
        end
        isempty(inventory_diagnostics) || return (
            success = false,
            code = :SUBSPACE_COREPRESENTATION_OPERATION_INVENTORY_MISMATCH,
            message = "band and target operation inventories cannot be matched",
            kpoint = 0,
            invariant_residual = Inf,
        )
        for kpoint in representation.irreducible_indices
            if config.solver.acceleration.hot_storage_backend == :contiguous &&
               length(outer_indices[kpoint]) == num_wannier
                exact_outer = zeros(ComplexF64, size(z_proposal[kpoint], 1), num_wannier)
                for (column, band) in enumerate(outer_indices[kpoint])
                    exact_outer[band, column] = 1.0
                end
                selected_subspaces[kpoint] = exact_outer
                continue
            end
            reference_z = disentanglement_algorithm == :smv_fletcher_reeves_two_stage
            selected = if reference_z
                _wannier90_reference_maximum_subspace_result(
                    z_proposal[kpoint],
                    outer_indices[kpoint],
                    frozen_indices[kpoint],
                    num_wannier;
                    audit = spectrum_audit,
                    context = "maximum_subspace:iteration=$(iteration):kpoint=$(kpoint)",
                )
            else
                _maximum_subspace_result(
                    z_proposal[kpoint],
                    outer_indices[kpoint],
                    frozen_indices[kpoint],
                    num_wannier,
                    config.input.representation_tolerance;
                    audit = spectrum_audit,
                    context = "maximum_subspace:iteration=$(iteration):kpoint=$(kpoint)",
                    reference_frame = frames[kpoint],
                    maximum_reference_condition = config.solver.numerical_thresholds.maximum_transport_condition,
                    numerical_thresholds = config.solver.numerical_thresholds,
                )
            end
            selected.success || return (
                success = false,
                code = selected.code,
                message = selected.code == :HERMITIAN_SPECTRAL_DECOMPOSITION_FAILED ?
                          "validated Hermitian subspace decomposition failed" :
                          "maximum-eigenvalue subspace has insufficient numerical rank",
                kpoint = kpoint,
                spectral_backend = selected.backend,
                spectral_gap = selected.gap,
            )
            if corepresentation_aware_selection
                aware = _corepresentation_aware_maximum_subspace_result(
                    selected,
                    outer_indices[kpoint],
                    frozen_indices[kpoint],
                    num_wannier,
                    frames[kpoint],
                    representation,
                    plan,
                    kpoint,
                    operation_mapping,
                    config.solver.numerical_thresholds.frame_transport_rtol,
                    config.solver.numerical_thresholds.maximum_transport_condition,
                )
                aware.success || return aware
                selected_subspaces[kpoint] = something(aware.frame)
            else
                selected_subspaces[kpoint] = something(selected.frame)
            end
        end
        if apply_symmetry && _is_symmetry_projected_smv_fr(disentanglement_algorithm)
            transport = _transport_selected_subspace_corepresentation(
                selected_subspaces,
                frames,
                representation,
                plan,
                config.solver.numerical_thresholds.frame_transport_rtol,
                config.solver.numerical_thresholds.maximum_transport_condition,
                projector_covariance_tolerance;
                construction_policy = config.input.construction_policy,
            )
            transport.success || return transport
            corepresentation_transport_applied = true
            corepresentation_transport_minimum_singular_value = transport.minimum_singular_value
            corepresentation_transport_maximum_condition = transport.maximum_condition
            corepresentation_transport_projector_drift = transport.projector_drift
            corepresentation_transport_target_symmetry = transport.target_symmetry
            transport.frames
        else
            _complete_selected_subspace_star(selected_subspaces, representation, plan, apply_symmetry)
        end
    else
        length(something(fixed_stage_subspaces)) == length(frames) || return (
            success = false,
            code = :FIXED_SUBSPACE_DIMENSION_MISMATCH,
            message = "sealed localization subspace mesh does not match",
            kpoint = 0,
        )
        deepcopy(something(fixed_stage_subspaces))
    end
    if !localize && config.solver.acceleration.schedule == :two_stage
        result = _disentanglement_candidate(
            config,
            representation,
            mmn,
            plan,
            weights,
            frozen_indices,
            subspaces,
            centers,
            spreads,
            projector_covariance_tolerance,
        )
        return merge(
            result,
            (
                subspaces = subspaces,
                raw_amn_alignment_applied = false,
                raw_amn_alignment_minimum_singular_value = NaN,
                raw_amn_alignment_maximum_condition = NaN,
                raw_amn_alignment_projector_drift = NaN,
                raw_amn_alignment_completion_count = 0,
                localization_initial_frames = nothing,
                corepresentation_transport_applied,
                corepresentation_transport_minimum_singular_value,
                corepresentation_transport_maximum_condition,
                corepresentation_transport_projector_drift,
                corepresentation_transport_target_symmetry,
            ),
        )
    end
    localization_projectors = if !localize
        nothing
    elseif fixed_stage_projectors === nothing
        [subspace * subspace' for subspace in subspaces]
    else
        deepcopy(something(fixed_stage_projectors))
    end
    localization_frames = frames
    alignment = nothing
    if localize && localization_reference_frames !== nothing
        alignment = _projected_reference_alignment(
            subspaces,
            something(localization_reference_frames),
            representation,
            plan,
            config.solver.numerical_thresholds.frame_transport_rtol,
            config.solver.numerical_thresholds.maximum_transport_condition,
            config.solver.numerical_thresholds.projectability_minimum_singular_value,
            symmetry_constraints_applied(config, representation),
            config.solver.acceleration.constraint_operation_scope != :full,
            localization_algorithm == :smv_fletcher_reeves_two_stage,
            outer_indices,
        )
        alignment.success ||
            return merge(alignment, (message = "raw-AMN localization alignment failed",))
        localization_frames = alignment.frames
    end
    result = _localization_sweeps(
        config,
        representation,
        mmn,
        plan,
        weights,
        included_bands,
        frozen_indices,
        subspaces,
        localization_frames,
        centers,
        spreads,
        u_mix_ratio,
        projector_covariance_tolerance,
        tangent_plans,
        localize,
        localization_algorithm,
        fixed_projectors = localization_projectors,
        previous_u_gradient = previous_u_gradient,
        previous_u_direction = previous_u_direction,
        u_cg_iteration = u_cg_iteration,
        u_cg_restart_count = u_cg_restart_count,
        u_lbfgs_s_history = u_lbfgs_s_history,
        u_lbfgs_y_history = u_lbfgs_y_history,
        u_lbfgs_rho_history = u_lbfgs_rho_history,
        u_lbfgs_restart_count = u_lbfgs_restart_count,
        u_branch_signature = u_branch_signature,
        wannier90_reference_overlaps = wannier90_reference_overlaps,
        wannier90_reference_omega_i = wannier90_reference_omega_i,
        wannier90_reference_unitaries = wannier90_reference_unitaries === nothing &&
                                        alignment !== nothing ? alignment.unitaries :
                                        wannier90_reference_unitaries,
    )
    if localization_algorithm == :smv_fletcher_reeves_two_stage && config.solver.parallel == :mpi
        all_ranks_success = _mpi_all_ranks_success(result.success, config.solver.parallel)
        if !all_ranks_success
            if MPI.Comm_rank(MPI.COMM_WORLD) == 0
                root_code = hasproperty(result, :code) ? result.code : :NOT_RECORDED
                root_message = hasproperty(result, :message) ? result.message : "NOT_RECORDED"
                println(
                    stderr,
                    "WANNIER90_REFERENCE_MPI_CANDIDATE_HOLD root_code=$(root_code) root_message=$(root_message)",
                )
            end
            return (
                success = false,
                code = :MPI_REFERENCE_CANDIDATE_CONSENSUS_HOLD,
                message = "at least one MPI rank rejected the Wannier90-reference localization candidate",
                kpoint = 0,
                sweep = 0,
                singular_values = Float64[],
                rank = 0,
                condition = Inf,
                frames = deepcopy(frames),
                centers = copy(centers),
                spreads = copy(spreads),
            )
        end
    end
    alignment_evidence =
        alignment === nothing ?
        (
            raw_amn_alignment_applied = false,
            raw_amn_alignment_minimum_singular_value = NaN,
            raw_amn_alignment_maximum_condition = NaN,
            raw_amn_alignment_projector_drift = NaN,
            raw_amn_alignment_completion_count = 0,
            localization_initial_frames = nothing,
        ) :
        (
            raw_amn_alignment_applied = true,
            raw_amn_alignment_minimum_singular_value = alignment.minimum_singular_value,
            raw_amn_alignment_maximum_condition = alignment.maximum_condition,
            raw_amn_alignment_projector_drift = alignment.projector_drift,
            raw_amn_alignment_completion_count = sum(alignment.completion_counts),
            localization_initial_frames = deepcopy(alignment.frames),
        )
    return merge(
        result,
        (
            subspaces = subspaces,
            corepresentation_transport_applied,
            corepresentation_transport_minimum_singular_value,
            corepresentation_transport_maximum_condition,
            corepresentation_transport_projector_drift,
            corepresentation_transport_target_symmetry,
        ),
        alignment_evidence,
    )
end

# Build the uncommitted Z field used by joint and disentanglement stages.
function _raw_z_field(
    representation::BandRepresentation,
    mmn::WannierMMN,
    weights::Vector{Float64},
    outer_indices::Vector{Vector{Int}},
    frames::Vector{Matrix{ComplexF64}},
    parallel::Symbol,
    ;
    full_bz::Bool = false,
    storage_backend::Symbol = :legacy_vector,
    wannier90_reference::Bool = false,
)
    nb, nk = size(representation.energies_ev)
    effective_backend = storage_backend == :auto ? :legacy_vector : storage_backend
    effective_backend in (:legacy_vector, :contiguous) ||
        throw(ArgumentError("unsupported raw-Z storage backend $(storage_backend)"))
    z_raw = [zeros(ComplexF64, nb, nb) for _ in 1:nk]
    z_contiguous = effective_backend == :contiguous ? zeros(ComplexF64, nb, nb, nk) : nothing
    update_z! = function (kpoint)
        outer = outer_indices[kpoint]
        local_z = zeros(ComplexF64, length(outer), length(outer))
        for neighbor in 1:mmn.num_neighbors
            target = mmn.neighbors[neighbor, kpoint]
            overlap = @view mmn.data[outer, :, neighbor, kpoint]
            if wannier90_reference
                # `internal_zmatrix` reaches this contraction through LP64
                # ZGEMM in the same OpenBLAS linked by the reference build.
                # A generic `*` may dispatch through Julia's configured BLAS;
                # its last-bit differences are amplified by the nearly
                # degenerate Cr top-eigenspace boundary.
                transported_frame = _wannier90_reference_zgemm(overlap, 'N', frames[target], 'N')
                # Match Wannier90 `internal_zmatrix`: accumulate the upper
                # Hermitian triangle in (neighbor,n,m,l) order rather than
                # replacing the l contraction by a second GEMM.  Both are
                # algebraically identical, but the explicit order is required
                # for the registered near-degenerate Cr projector parity.
                for column in axes(local_z, 2), row in 1:column
                    contracted = zero(ComplexF64)
                    for wannier in axes(transported_frame, 2)
                        contracted += _wannier90_reference_gfortran_complex_product(
                            transported_frame[row, wannier],
                            conj(transported_frame[column, wannier]),
                        )
                    end
                    local_z[row, column] += weights[neighbor] * contracted
                    local_z[column, row] = conj(local_z[row, column])
                end
            elseif effective_backend == :contiguous
                transported_frame = overlap * frames[target]
                mul!(local_z, transported_frame, transported_frame', weights[neighbor], 1.0)
            else
                local_z .+=
                    weights[neighbor] .* overlap * (frames[target] * frames[target]') * overlap'
            end
        end
        if effective_backend == :contiguous
            z_values = something(z_contiguous)
            @view(z_values[outer, outer, kpoint]) .= local_z
        else
            z_raw[kpoint][outer, outer] .= local_z
        end
    end
    active_kpoints = full_bz ? collect(1:nk) : representation.irreducible_indices
    mpi_comm = nothing
    mpi_rank = 0
    mpi_size = 1
    if parallel == :mpi
        MPI.Initialized() || MPI.Init()
        mpi_comm = MPI.COMM_WORLD
        mpi_rank = MPI.Comm_rank(something(mpi_comm))
        mpi_size = MPI.Comm_size(something(mpi_comm))
    end
    local_kpoints = parallel == :mpi ? active_kpoints[(mpi_rank + 1):mpi_size:end] : active_kpoints
    if parallel == :threads && Threads.nthreads() > 1
        Threads.@threads :static for index in eachindex(active_kpoints)
            update_z!(active_kpoints[index])
        end
    else
        for kpoint in local_kpoints
            update_z!(kpoint)
        end
    end
    if parallel == :mpi
        if effective_backend == :contiguous
            MPI.Allreduce!(something(z_contiguous), +, something(mpi_comm))
        else
            for matrix in z_raw
                MPI.Allreduce!(matrix, +, something(mpi_comm))
            end
        end
    end
    if effective_backend == :contiguous
        z_values = something(z_contiguous)
        return [Matrix{ComplexF64}(@view z_values[:, :, kpoint]) for kpoint in 1:nk]
    end
    return z_raw
end

"""Retract one strict top-eigenspace proposal inside a bounded Grassmann ball."""
function _grassmann_trust_region_step(
    current_frames::Vector{Matrix{ComplexF64}},
    proposed_frames::Vector{Matrix{ComplexF64}},
    radius::Float64,
    outer_indices::Vector{Vector{Int}},
    frozen_indices::Vector{Vector{Int}},
    num_wannier::Int,
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    config::SymmetryAdaptedWannierizationConfig,
)
    representatives = representation.irreducible_indices
    trial = deepcopy(current_frames)
    maximum_angle = 0.0
    for kpoint in representatives
        overlap = svd(current_frames[kpoint]' * proposed_frames[kpoint])
        singular_values = clamp.(Float64.(overlap.S), 0.0, 1.0)
        local_angle = isempty(singular_values) ? 0.0 : maximum(acos.(singular_values))
        maximum_angle = max(maximum_angle, local_angle)
        alpha = local_angle <= eps(Float64) ? 1.0 : min(1.0, radius / local_angle)
        aligned_proposal = proposed_frames[kpoint] * (overlap.V * overlap.U')
        blended = (1.0 - alpha) .* current_frames[kpoint] .+ alpha .* aligned_proposal
        retract = qr(blended)
        retracted = Matrix(retract.Q[:, 1:num_wannier])
        projector_evidence = retracted * retracted'
        selected = _maximum_subspace_result(
            projector_evidence,
            outer_indices[kpoint],
            frozen_indices[kpoint],
            num_wannier,
            config.input.representation_tolerance;
            reference_frame = current_frames[kpoint],
            maximum_reference_condition = config.solver.numerical_thresholds.maximum_transport_condition,
            numerical_thresholds = config.solver.numerical_thresholds,
            context = "grassmann_trust_region:kpoint=$(kpoint)",
        )
        selected.success ||
            return (success = false, code = selected.code, frames = trial, maximum_angle, alpha)
        trial[kpoint] = something(selected.frame)
    end
    trial = _complete_selected_subspace_star(
        trial,
        representation,
        plan,
        symmetry_constraints_applied(config, representation),
    )
    return (
        success = true,
        code = :OK,
        frames = trial,
        maximum_angle,
        alpha = maximum_angle <= eps(Float64) ? 1.0 : min(1.0, radius / maximum_angle),
    )
end

"""Select a deterministic multi-start winner without consulting held-out bands."""
function _select_wannierization_multistart(
    results::AbstractVector{<:WannierizationResult};
    long_range_tails::AbstractVector{<:Real} = fill(Inf, length(results)),
    elapsed_seconds::AbstractVector{<:Real} = fill(Inf, length(results)),
)
    isempty(results) && throw(ArgumentError("multi-start selection requires at least one result"))
    length(results) == length(long_range_tails) == length(elapsed_seconds) ||
        throw(DimensionMismatch("multi-start evidence lengths disagree"))
    keys = map(eachindex(results)) do index
        result = results[index]
        qualification =
            result.status in (COMPLETED, COMPLETED_WITH_WARNINGS) ? 0 :
            result.status == MAX_ITERATIONS ? 1 : 2
        total_spread =
            all(isfinite, result.spreads_angstrom2) ? sum(result.spreads_angstrom2) : Inf
        tail = isfinite(long_range_tails[index]) ? Float64(long_range_tails[index]) : Inf
        runtime = isfinite(elapsed_seconds[index]) ? Float64(elapsed_seconds[index]) : Inf
        (qualification, total_spread, tail, runtime, index)
    end
    winner = argmin(keys)
    return (
        winner_index = winner,
        winner = results[winner],
        selection_key = keys[winner],
        all_keys = keys,
        held_out_bands_used = false,
    )
end

"""Generate one deterministic in-subspace gauge perturbation for multi-start U."""
function _deterministic_sealed_subspace_perturbation(
    frames::Vector{Matrix{ComplexF64}},
    seed::UInt64,
    start_index::Int;
    magnitude::Float64 = 0.05,
)
    start_index >= 1 || throw(ArgumentError("multi-start index must be positive"))
    0.0 <= magnitude <= 1.0 || throw(ArgumentError("perturbation magnitude must lie in [0,1]"))
    start_index == 1 && return deepcopy(frames)
    perturbed = deepcopy(frames)
    for kpoint in eachindex(frames)
        dimension = size(frames[kpoint], 2)
        rng = MersenneTwister(seed + UInt64(104729 * start_index) + UInt64(13007 * kpoint))
        raw = randn(rng, ComplexF64, dimension, dimension)
        generator = (raw - raw') / 2
        generator_norm = opnorm(generator)
        generator_norm > eps(Float64) && (generator .*= magnitude / generator_norm)
        perturbed[kpoint] = frames[kpoint] * exp(generator)
    end
    return perturbed
end

# The Wannier90-reference path carries the accepted U matrix without applying
# a polar repair between localization iterations. Forming F = S*U and then
# reconstructing F*F' consequently accumulates a few ulps more roundoff than
# the generic retracted optimizers. Use one named implementation tolerance for
# both the base and trial fixed-projector checks; finite/isometry/rank gates and
# the immutable sealed-subspace digest remain independent hard gates.
const _GENERIC_FIXED_SUBSPACE_PROJECTOR_DRIFT_ATOL = 1.0e-12
const _WANNIER90_REFERENCE_FIXED_SUBSPACE_PROJECTOR_DRIFT_ATOL = 1.0e-10

"""Return the fixed-subspace drift tolerance for one localization backend."""
@inline function _fixed_subspace_projector_drift_tolerance(localization_algorithm::Symbol)
    return localization_algorithm == :smv_fletcher_reeves_two_stage ?
           _WANNIER90_REFERENCE_FIXED_SUBSPACE_PROJECTOR_DRIFT_ATOL :
           _GENERIC_FIXED_SUBSPACE_PROJECTOR_DRIFT_ATOL
end

"""Evaluate the explicit gauge-invariant disentanglement objective Omega_I."""
function _gauge_invariant_spread(
    frames::Vector{Matrix{ComplexF64}},
    mmn::WannierMMN,
    weights::Vector{Float64},
)
    nk = length(frames)
    nw = size(first(frames), 2)
    total = 0.0
    for kpoint in 1:nk, neighbor in 1:mmn.num_neighbors
        target = mmn.neighbors[neighbor, kpoint]
        projected_overlap =
            frames[kpoint]' * @view(mmn.data[:, :, neighbor, kpoint]) * frames[target]
        total += weights[neighbor] * (nw - sum(abs2, projected_overlap))
    end
    objective = total / nk
    isfinite(objective) || throw(ArgumentError("non-finite gauge-invariant spread objective"))
    return objective
end

"""Measure non-committing projector drift for a disentanglement candidate."""
function _disentanglement_projector_drift(
    z_raw::Vector{Matrix{ComplexF64}},
    frames::Vector{Matrix{ComplexF64}},
    outer_indices::Vector{Vector{Int}},
    frozen_indices::Vector{Vector{Int}},
    irreducible_indices::Vector{Int},
    num_wannier::Int,
    tolerance::Float64,
)
    maximum_drift = 0.0
    for kpoint in irreducible_indices
        selected = _maximum_subspace(
            z_raw[kpoint],
            outer_indices[kpoint],
            frozen_indices[kpoint],
            num_wannier,
            tolerance,
        )
        selected === nothing && return Inf
        maximum_drift =
            max(maximum_drift, norm(selected * selected' - frames[kpoint] * frames[kpoint]'))
    end
    return maximum_drift
end

# Gate finite, isometry, frozen-subspace, and covariance invariants for every
# fixed, adaptive, and Anderson trial.
function _candidate_invariant_failure(
    frames::Vector{Matrix{ComplexF64}},
    centers::Matrix{Float64},
    spreads::Vector{Float64},
    frozen_indices::Vector{Vector{Int}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    tolerance::Float64,
    covariance_tolerance::Float64,
    apply_symmetry::Bool = true;
    construction_policy::Symbol = :strict,
)
    all(isfinite, centers) &&
    all(isfinite, spreads) &&
    all(frame -> all(isfinite, frame), frames) || return (:NONFINITE_SOLVER_TRIAL, Inf)
    residuals = _candidate_invariant_residuals(frames, frozen_indices, representation)
    isometry = residuals.isometry
    isometry <= tolerance || return (:SOLVER_TRIAL_ISOMETRY_FAILED, isometry)
    residuals.frozen <= tolerance ||
        return (:SOLVER_TRIAL_FROZEN_PROJECTOR_FAILED, residuals.frozen)
    if apply_symmetry
        isfinite(residuals.covariance) || return (:NONFINITE_SOLVER_TRIAL, Inf)
        target = _maximum_target_frame_symmetry_error(frames, representation, plan)
        isfinite(target) || return (:NONFINITE_SOLVER_TRIAL, Inf)
    end
    if apply_symmetry && construction_policy == :strict
        residuals.covariance <= covariance_tolerance ||
            return (:SOLVER_TRIAL_COVARIANCE_FAILED, residuals.covariance)
        target_symmetry = _maximum_target_frame_symmetry_error(frames, representation, plan)
        target_symmetry <= covariance_tolerance ||
            return (:SOLVER_TRIAL_TARGET_SYMMETRY_FAILED, target_symmetry)
    end
    return nothing
end

"""Return isometry, exact-frozen, and magnetic covariance residuals for a trial."""
function _candidate_invariant_residuals(
    frames::Vector{Matrix{ComplexF64}},
    frozen_indices::Vector{Vector{Int}},
    representation::BandRepresentation,
)
    isometry = maximum(
        maximum(abs, frame' * frame - Matrix{ComplexF64}(I, size(frame, 2), size(frame, 2))) for
        frame in frames
    )
    frozen_residual = 0.0
    for kpoint in eachindex(frames), band in frozen_indices[kpoint]
        projector_column = frames[kpoint] * conj.(@view frames[kpoint][band, :])
        expected = zeros(ComplexF64, size(frames[kpoint], 1))
        expected[band] = 1.0
        frozen_residual = max(frozen_residual, norm(projector_column - expected))
    end
    covariance = _maximum_projector_covariance_error(frames, representation)
    return (isometry = isometry, frozen = frozen_residual, covariance = covariance)
end

"""Measure the retained accepted frame against every structural export invariant."""
function _accepted_state_structural_residuals(
    frames::Vector{Matrix{ComplexF64}},
    frozen_indices::Vector{Vector{Int}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    apply_symmetry::Bool,
)
    residuals = _candidate_invariant_residuals(frames, frozen_indices, representation)
    return merge(
        residuals,
        (
            target_symmetry = apply_symmetry ?
                              _maximum_target_frame_symmetry_error(frames, representation, plan) :
                              NaN,
        ),
    )
end

# A nonconverged disentanglement subspace may enter diagnostic localization
# only when the retained Z field is finite and every selected frame remains
# full-rank, isometric, frozen-containing, and symmetry covariant.  The Z
# matrices themselves are not required to be full-rank because their null
# space outside the selected outer window is part of the construction.
function _qualify_nonconverged_disentanglement_state(
    frames::Vector{Matrix{ComplexF64}},
    z_field,
    centers::Matrix{Float64},
    spreads::Vector{Float64},
    frozen_indices::Vector{Vector{Int}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    tolerance::Float64,
    covariance_tolerance::Float64,
    apply_symmetry::Bool;
    construction_policy::Symbol = :strict,
)
    z_finite = z_field !== nothing && all(matrix -> all(isfinite, matrix), something(z_field))
    residuals = _candidate_invariant_residuals(frames, frozen_indices, representation)
    target_symmetry_residual =
        apply_symmetry ? _maximum_target_frame_symmetry_error(frames, representation, plan) : 0.0
    kstar_expansion_residual = if apply_symmetry
        try
            expanded = _expand_ibz_frames(frames, representation, plan)
            maximum(norm(expanded[index] - frames[index]) for index in eachindex(frames))
        catch
            Inf
        end
    else
        0.0
    end
    corepresentation_residual =
        max(residuals.covariance, target_symmetry_residual, kstar_expansion_residual)
    required_rank = isempty(frames) ? 0 : size(first(frames), 2)
    numerical_ranks = Int[]
    minimum_singular_value = Inf
    for frame in frames
        singular_values = svdvals(frame)
        rank_threshold = max(
            tolerance,
            eps(Float64) * max(size(frame)...) * maximum(singular_values; init = 0.0),
        )
        push!(numerical_ranks, count(value -> value > rank_threshold, singular_values))
        minimum_singular_value = min(minimum_singular_value, minimum(singular_values))
    end
    minimum_rank = isempty(numerical_ranks) ? 0 : minimum(numerical_ranks)
    isempty(numerical_ranks) && (minimum_singular_value = 0.0)
    invariant_failure = _candidate_invariant_failure(
        frames,
        centers,
        spreads,
        frozen_indices,
        representation,
        plan,
        tolerance,
        covariance_tolerance,
        apply_symmetry;
        construction_policy,
    )
    failure_code = if !z_finite
        :NONFINITE_DISENTANGLEMENT_STATE
    elseif minimum_rank < required_rank
        :RANK_DEFICIENT_DISENTANGLEMENT_PROJECTOR
    elseif !isfinite(corepresentation_residual) ||
           (construction_policy == :strict && corepresentation_residual > covariance_tolerance)
        :DISENTANGLEMENT_COREPRESENTATION_CONTINUATION_GATE_FAILED
    elseif invariant_failure !== nothing
        first(something(invariant_failure))
    else
        :NONE
    end
    return (
        qualified = failure_code == :NONE,
        failure_code,
        z_finite,
        required_rank,
        minimum_rank,
        minimum_singular_value,
        isometry_residual = residuals.isometry,
        frozen_residual = residuals.frozen,
        covariance_residual = residuals.covariance,
        target_symmetry_residual,
        kstar_expansion_residual,
        corepresentation_residual,
    )
end

# Record terminal counters without changing the accepted numerical state.
function _record_terminal_state!(
    input_summary::Dict{String, String},
    status::WannierizationStatus,
    diagnostics::Vector{WannierizationDiagnostic},
    history::Vector{WannierizationIteration},
    last_attempted_iteration::Int,
    last_accepted_iteration::Int;
    hard_gate_residuals = nothing,
    legacy_terminal_semantics::Bool = false,
)
    input_summary["solver_status"] = string(status)
    input_summary["stopping_reason"] =
        isempty(diagnostics) ? string(status) : string(last(diagnostics).code)
    input_summary["last_attempted_iteration"] = string(last_attempted_iteration)
    input_summary["last_accepted_iteration"] = string(last_accepted_iteration)
    input_summary["last_persisted_iteration"] = "-1"
    input_summary["has_accepted_state"] = string(last_accepted_iteration >= 0)
    input_summary["legacy_terminal_semantics"] = string(legacy_terminal_semantics)
    input_summary["convergence_metric_name"] = "center_spread_window_std_max"
    input_summary["convergence_metric"] =
        isempty(history) ? "Inf" : string(last(history).spread_standard_deviation)
    stopping_code = isempty(diagnostics) ? Symbol(string(status)) : last(diagnostics).code
    input_summary["solver_convergence"] = if status in (COMPLETED, COMPLETED_WITH_WARNINGS)
        "CONVERGED"
    elseif status == MAX_ITERATIONS
        "MAX_ITERATIONS"
    elseif stopping_code in (
        :SPREAD_INCREASE_BACKTRACKING_EXHAUSTED,
        :SPREAD_GRADIENT_LINE_SEARCH_FAILED,
        :LOCALIZATION_BACKTRACKING_EXHAUSTED,
        :LOCALIZATION_LINE_SEARCH_EXHAUSTED,
        :NON_DESCENT_LOCALIZATION_DIRECTION,
        :NONFINITE_LOCALIZATION_DIRECTION,
    )
        "LINE_SEARCH_EXHAUSTED"
    elseif last_accepted_iteration < 0
        "NOT_STARTED"
    else
        "FAILED_NUMERICAL"
    end
    if hard_gate_residuals !== nothing
        for name in propertynames(hard_gate_residuals)
            input_summary["hard_gate_$(name)"] = string(getproperty(hard_gate_residuals, name))
        end
        if get(input_summary, "covariance_qualification", "") == "DIAGNOSTIC_ONLY" &&
           hasproperty(hard_gate_residuals, :covariance)
            input_summary["diagnostic_covariance_residual"] =
                string(getproperty(hard_gate_residuals, :covariance))
        end
    end
    if get(input_summary, "construction_policy", "strict") == "diagnostic"
        if get(input_summary, "construction_quality_failed", "false") == "true" ||
           any(diagnostic -> get(diagnostic.context, "gate_result", "") == "FAIL", diagnostics)
            input_summary["construction_quality_failed"] = "true"
        end
        input_summary["manual_review_required"] = "true"
        startswith(get(input_summary, "model_qualification", ""), "DIAGNOSTIC_ONLY") ||
            (input_summary["model_qualification"] = "DIAGNOSTIC_ONLY")
        input_summary["standard_tb_export_eligible"] = "false"
        input_summary["route_selection_eligible"] = "false"
        input_summary["scoped_production_eligible"] = "false"
        input_summary["global_production_eligible"] = "false"
    end
    return input_summary
end

# Package a typed failure while retaining only the last accepted finite state.
function _failure_result(
    status::WannierizationStatus,
    diagnostics::Vector{WannierizationDiagnostic},
    input_summary::Dict{String, String};
    frames = Matrix{ComplexF64}[],
    centers = zeros(Float64, 0, 3),
    spreads = Float64[],
    history = WannierizationIteration[],
    restart_state = nothing,
    representation = nothing,
    last_attempted_iteration = nothing,
    hard_gate_residuals = nothing,
    initialization_report = nothing,
)
    accepted_iteration = restart_state === nothing ? -1 : restart_state.iteration
    attempted_iteration =
        last_attempted_iteration === nothing ? accepted_iteration : Int(last_attempted_iteration)
    retained_frames =
        restart_state === nothing ? frames : _restart_matrix_field(restart_state.frames)
    retained_centers =
        restart_state === nothing ? Matrix{Float64}(centers) : copy(restart_state.centers_cartesian)
    retained_spreads =
        restart_state === nothing ? Float64.(spreads) : copy(restart_state.spreads_angstrom2)
    v_matrix =
        isempty(retained_frames) ? zeros(ComplexF64, 0, 0, 0) : cat(retained_frames...; dims = 3)
    chk = if restart_state !== nothing && representation !== nothing
        WannierCHK(
            size(v_matrix, 1),
            size(v_matrix, 2),
            size(v_matrix, 3),
            representation.mp_grid,
            representation.kpoints_fractional,
            representation.real_lattice,
            representation.reciprocal_lattice,
            retained_centers,
            v_matrix,
        )
    else
        nothing
    end
    summary = Dict{String, String}(input_summary)
    _record_terminal_state!(
        summary,
        status,
        diagnostics,
        WannierizationIteration[history...],
        attempted_iteration,
        accepted_iteration;
        hard_gate_residuals,
    )
    return WannierizationResult(
        status,
        v_matrix,
        retained_centers,
        retained_spreads,
        WannierizationIteration[history...],
        diagnostics,
        summary,
        chk,
        nothing,
        restart_state,
        WannierizationArtifacts(),
        initialization_report,
    )
end

# Reconstruct k-indexed matrices from the k-last checkpoint layout.
function _restart_matrix_field(values::Array{ComplexF64, 3})
    return [Matrix{ComplexF64}(@view values[:, :, kpoint]) for kpoint in axes(values, 3)]
end

# Capture the complete state only after a full Z/U iteration has committed.
function _restart_state(
    iteration,
    frames,
    z_previous,
    centers,
    spreads,
    convergence_values,
    included_bands,
    elapsed_seconds,
    config_sha256,
    representation_sha256,
    stencil,
    projection_basis_sha256,
    amn_sha256,
    optimizer_state;
    fixed_subspace_projectors = nothing,
    fixed_subspace_frames = nothing,
    localization_initial_frames = nothing,
)
    values =
        isempty(convergence_values) ? zeros(Float64, length(vec(centers)) + length(spreads), 0) :
        reduce(hcat, convergence_values)
    masks = BitMatrix(reduce(hcat, included_bands))
    return WannierizationRestartState(
        iteration,
        cat(frames...; dims = 3),
        z_previous === nothing ? nothing : cat(z_previous...; dims = 3),
        Matrix{Float64}(centers),
        Float64.(spreads),
        Matrix{Float64}(values),
        masks,
        Float64(elapsed_seconds),
        String(config_sha256),
        String(representation_sha256),
        stencil,
        String(projection_basis_sha256),
        String(amn_sha256),
        optimizer_state,
        fixed_subspace_projectors === nothing ? nothing :
        cat(fixed_subspace_projectors...; dims = 3),
        fixed_subspace_frames === nothing ? nothing : cat(fixed_subspace_frames...; dims = 3),
        localization_initial_frames === nothing ? nothing :
        cat(localization_initial_frames...; dims = 3),
    )
end

# Check only the dynamic selected projector; static group checks are preflight-only.
function _selected_projector_compatibility_diagnostic(
    frames::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
    tolerance::Float64,
    policy::Symbol,
    stage::String,
    theta_index::Union{Nothing, Int},
)
    any(operation -> operation.antiunitary, representation.operations) || return nothing
    residual, context = antiunitary_projector_covariance_residual(frames, representation)
    rank_diagnostics =
        validate_selected_kramers_ranks(frames, representation, theta_index, tolerance)
    if residual <= tolerance && isempty(rank_diagnostics)
        return nothing
    end
    severity = :error
    if !isempty(rank_diagnostics)
        rank_diagnostic = first(rank_diagnostics)
        return WannierizationDiagnostic(
            rank_diagnostic.code,
            severity,
            rank_diagnostic.message;
            context = merge(rank_diagnostic.context, Dict("stage" => stage)),
        )
    end
    return representation_diagnostic(
        :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED,
        severity,
        "selected projector is not covariant under the antiunitary k-star action";
        context = merge(
            context,
            Dict(
                "stage" => stage,
                "maximum_error" => string(residual),
                "tolerance" => string(tolerance),
            ),
        ),
    )
end

# A canonically expanded projector inherits the finite-cutoff group-law floor.
# Analytic fixtures retain the absolute representation tolerance. An empirical
# finite-cutoff representation uses its measured internal group-law residual as
# a covariance budget. Paired-oracle evidence is diagnostic only.
function _projector_covariance_tolerance(
    config::SymmetryAdaptedWannierizationConfig,
    compatibility::RepresentationCompatibilityReport,
)
    compatibility.validation_profile == :empirical || return config.input.representation_tolerance
    measured_floor = maximum(compatibility.maximum_group_law_residuals)
    declared_budget = something(config.input.empirical_covariance_budget, measured_floor)
    return max(config.input.representation_tolerance, measured_floor, declared_budget)
end

# Hash sorted sewing and gauge diagnostics that constrain restart provenance.
function _strict_sewing_diagnostics_sha256(representation::BandRepresentation)
    selected = sort!([
        key for key in keys(representation.conventions) if key == "sewing_backend" ||
        key == "sewing_metric" ||
        key == "augmentation_backend" ||
        key == "paw_sewing_thresholds" ||
        startswith(key, "wavefunction_gauge") ||
        startswith(key, "strict_") ||
        startswith(key, "raw_group_law") ||
        startswith(key, "raw_projective_group_law") ||
        startswith(key, "raw_cocycle_phase") ||
        startswith(key, "raw_little_group") ||
        startswith(key, "raw_reciprocal_cocycle") ||
        startswith(key, "generalized_norm")
    ],)
    buffer = IOBuffer()
    for key in selected
        write(buffer, key, '=', representation.conventions[key], '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# A Hamiltonian authority selects the matrix values, whereas this contract
# selects the only physical qualification scope.  In particular, native DFT
# remains numerically unchanged while an explicit complete outer-window
# contract makes its full parent a non-gating audit just like the symmetrized
# DFT route.
function _representation_target_subspace_contract(representation::BandRepresentation)
    conventions = representation.conventions
    qualification_scope = get(conventions, "qualification_scope", "full_parent")
    target_authority = get(conventions, "target_authority", "NOT_APPLICABLE")
    parent_audit_policy = get(conventions, "parent_audit_policy", "legacy_hard_gate")
    contract_sha256 = get(
        conventions,
        "target_subspace_contract_sha256",
        get(representation.input_sha256, "TARGET_SUBSPACE_CONTRACT_SHA256", "NOT_RECORDED"),
    )
    target_leakage_semantics =
        get(conventions, "target_leakage_semantics", "LEGACY_AMPLITUDE_LEAKAGE_CONTRACT")
    target_leakage_formula_sha256 =
        get(conventions, "target_leakage_formula_sha256", "NOT_RECORDED")
    target_leakage_threshold = get(conventions, "target_leakage_threshold", "NOT_RECORDED")
    declares_target_scope =
        qualification_scope == "target_subspace" || target_authority == "outer_window"
    declares_target_scope || return (
        active = false,
        qualification_scope,
        target_authority,
        parent_audit_policy,
        contract_sha256,
        target_leakage_semantics,
        target_leakage_formula_sha256,
        target_leakage_threshold,
    )
    representation.schema_version in ("1.0", "1.17") || throw(
        ArgumentError(
            "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: target authority requires the complete public 1.0 or internal 1.17 contract",
        ),
    )
    qualification_scope == "target_subspace" || throw(
        ArgumentError(
            "TARGET_SUBSPACE_CONTRACT_MISMATCH: qualification_scope must be target_subspace",
        ),
    )
    target_authority == "outer_window" || throw(
        ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: target_authority must be outer_window"),
    )
    parent_audit_policy == "audit_only" || throw(
        ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: parent_audit_policy must be audit_only"),
    )
    occursin(r"^[0-9a-f]{64}$", contract_sha256) || throw(
        ArgumentError(
            "TARGET_SUBSPACE_CONTRACT_MISMATCH: target_subspace_contract_sha256 is invalid",
        ),
    )
    target_leakage_semantics == "physical_paw_s_leakage_weight_v1" || throw(
        ArgumentError(
            "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: target representation does not declare PAW-S weights",
        ),
    )
    target_leakage_formula_sha256 ==
    "bac0eb8b0df105c221d0e5a253be1890ac7933e51c776bf9aa760fb91362a3b7" || throw(
        ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: leakage formula digest is unsupported"),
    )
    threshold = tryparse(Float64, target_leakage_threshold)
    threshold !== nothing && isfinite(something(threshold)) && something(threshold) > 0.0 || throw(
        ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: leakage weight threshold is invalid"),
    )
    return (
        active = true,
        qualification_scope,
        target_authority,
        parent_audit_policy,
        contract_sha256,
        target_leakage_semantics,
        target_leakage_formula_sha256,
        target_leakage_threshold,
    )
end

"""
Run the ordered preparation, continuation, initialization and Z/U solver stages.

Frames use `(band, Wannier, kpoint)` order in the supplied representation gauge;
spreads are in square angstroms. Each stage retains the existing array ownership
and exact arithmetic order. Invalid inputs and failed trials return a diagnostic
result; an accepted restart state survives later observer or convergence failure.
"""
function _solve_symmetry_adapted_wannierization(
    config::SymmetryAdaptedWannierizationConfig,
    representation::BandRepresentation,
    eig::WannierEIG,
    mmn::WannierMMN,
    plan::WannierSymmetryPlan;
    amn::Union{Nothing, Array{ComplexF64, 3}} = nothing,
    restart::Union{Nothing, Array{ComplexF64, 3}} = nothing,
    restart_state::Union{Nothing, WannierizationRestartState} = nothing,
    restart_history::Vector{WannierizationIteration} = WannierizationIteration[],
    restart_input_summary::AbstractDict{String, String} = Dict{String, String}(),
    fixed_subspace::Union{Nothing, WannierizationFixedSubspace} = nothing,
    observer = nothing,
    compatibility_report::Union{Nothing, RepresentationCompatibilityReport} = nothing,
    initialization_amn_sha256::AbstractString = "",
    paw_scdm_input::Union{Nothing, PAWSCDMInputArtifact} = nothing,
)
    state = (;
        amn,
        compatibility_report,
        config,
        eig,
        fixed_subspace,
        initialization_amn_sha256,
        mmn,
        observer,
        paw_scdm_input,
        plan,
        representation,
        restart,
        restart_history,
        restart_input_summary,
        restart_state,
    )
    state = _prepare_solver_input_summary(state)
    state isa WannierizationResult && return state
    state = _qualify_solver_inputs(state)
    state isa WannierizationResult && return state
    state = _validate_solver_restart(state)
    state isa WannierizationResult && return state
    state = _initialize_solver_frames(state)
    state isa WannierizationResult && return state
    state = _initialize_solver_optimizer(state)
    state isa WannierizationResult && return state
    state = _run_solver_iterations(state)
    state isa WannierizationResult && return state
    return _assemble_solver_terminal_result(state)
end
