"""
Qualified, non-exported MatrixElements API consumed by sibling expert workflows.

Entries in this tuple are stable cross-layer contracts. Implementation helpers
absent from the tuple remain private to `MatrixElements` and must not be used by
production code in another module.
"""
const MATRIX_ELEMENTS_INTEGRATION_API = (
    :intrinsic_hall_position_between_occupations,
    :regularized_orbital_geometry,
    :validate_orthogonal_band_derivatives,
    # Worker-local analytic geometry contracts consumed by Responses/Runtime.
    # Recurrence arrays retain their prepared generation and gauge-dependent
    # meaning; only response contractions expose physical observables.
    :OrthogonalGeometryJets,
    :OrthogonalBandDerivativeWorkspace,
    :geometry_derivative_order,
    :geometry_hamiltonian_derivative_source,
    :geometry_position_derivative_source,
    :geometry_isolated_spectrum_minimum_gap,
    :geometry_position_channel,
    :orthogonal_band_first_derivative!,
    :orthogonal_band_second_derivative!,
    :orthogonal_band_third_derivative!,
    :orthogonal_geometry_storage_bytes,
    :prepare_orthogonal_band_derivatives!,
    :prepare_orthogonal_geometry_jets!,
    :wannier_pair_wigner_seitz_plan_from_images,
    # Existing cross-layer response fast paths; worker-private scratch and complete groups.
    :ActiveVelocityInsertionWorkspace,
    :supports_active_velocity_insertions,
    :active_velocity_gradient,
    :active_velocity_insertions!,
    :active_velocity_paired_insertions!,
    :spectral_subspace_blocks,
    :mark_wilson_response_groups!,
    :mark_response_degeneracy_groups!,
    :REAL_SPACE_REPLICA_MAP_REFERENCE_SCHEMA,
    :MatrixElementDirectionRequirements,
    :RealSpaceReplicaMap,
    :RawReplicaValues,
    :SharedInterpolationCache,
    :apply_wannier_center_phases!,
    :begin_shared_interpolation!,
    :compute_spin_velocity_real_space_streaming_with_transform,
    :compute_spin_velocity_real_space_with_transform,
    :compute_loop_overlap!,
    :compute_optical_momentum_overlap!,
    :derive_axial_and_symmetric_derivative_overlaps,
    :hermitianize_real_space_pairs,
    :input_real_space_replica_map,
    :input_real_space_support_definition,
    :matrix_element_axis_required,
    :matrix_element_pair_required,
    :materialize_replica_component,
    :materialize_replica_components,
    :reuse_completed_mixed_blocks!,
    :has_mixed_fourier_provider,
    :minimum_distance_real_space_replica_map,
    :mp_residue_grid,
    :projector_block_velocity,
    :projector_block_curvature,
    :real_space_replica_map_from_wsvec,
    :require_matrix_element_axes,
    :require_matrix_element_pairs,
    :extend_matrix_element_directions,
    :shared_interpolation_stats,
    :transform_pair_wigner_seitz_spin_q_to_r,
    :unit_degeneracy_roundtrip_error,
    :wannier_centers_fractional,
    :wannier_q_to_pair_wigner_seitz,
    :with_shared_interpolation,
)

"""
Qualified MatrixElements implementation helpers intentionally exercised by
white-box tests. These names are not production integration contracts.
"""
const MATRIX_ELEMENTS_TEST_API = (:_axis_channel,)

"""Shared response grouping port; retain the exact owner callable and workspace contract."""
const mark_response_degeneracy_groups! = _mark_response_degeneracy_groups!

"""Add required one-axis channels to an immutable direction contract."""
function require_matrix_element_axes(
    requirements::MatrixElementDirectionRequirements,
    kind::MatrixElementKind,
    axes,
)
    return _require_axes(requirements, kind, axes)
end

"""Add required ordered direction pairs to an immutable direction contract."""
function require_matrix_element_pairs(
    requirements::MatrixElementDirectionRequirements,
    kind::MatrixElementKind,
    pairs,
)
    return _require_pairs(requirements, kind, pairs)
end

"""
Extend a direction contract without adding channels or changing ordered-pair meaning.

Only the storage/preparation dimension grows; callers retain their response axes.
Spatial pairs are re-encoded with the new stride, while spin pairs retain stride three.
"""
function extend_matrix_element_directions(
    requirements::MatrixElementDirectionRequirements,
    spatial_dimension::Integer,
)
    old_dimension = requirements.spatial_dimension
    dimension = Int(spatial_dimension)
    old_dimension <= dimension <= 3 ||
        throw(ArgumentError("Direction extension must stay in old_dimension:3."))
    dimension == old_dimension && return requirements
    result = MatrixElementDirectionRequirements(dimension)
    spatial_pairs =
        (HAMILTONIAN_SECOND_DERIVATIVES, INTERNAL_CONNECTION_DERIVATIVES, WANNIER_CURVATURE)
    spin_pairs = (SPIN_TIMES_POSITION, SPIN_TIMES_HAMILTONIAN_POSITION, SPIN_VELOCITY)
    old_plan = (; direction_requirements = requirements, spatial_dimension = old_dimension)
    for kind in _ALL_MATRIX_ELEMENT_KINDS
        if kind in spatial_pairs || kind in spin_pairs
            second_limit = kind in spin_pairs ? 3 : old_dimension
            for first in 1:old_dimension, second in 1:second_limit
                _pair_required(old_plan, kind, first, second) || continue
                result = _require_pair(result, kind, first, second)
            end
        else
            # One-axis masks (and the unused spectrum/energy masks) have no stride.
            result = _replace_direction_mask(result, kind, _direction_mask(requirements, kind))
        end
    end
    return result
end

"""Report whether a compiled plan requires one Cartesian axis."""
@inline function matrix_element_axis_required(plan, kind::MatrixElementKind, axis::Integer)
    return _axis_required(plan, kind, axis)
end

"""Report whether a compiled plan requires one ordered Cartesian pair."""
@inline function matrix_element_pair_required(
    plan,
    kind::MatrixElementKind,
    first_direction::Integer,
    second_direction::Integer,
)
    return _pair_required(plan, kind, first_direction, second_direction)
end

"""
Apply the centered-orbital Wannier phases in place without changing the
established left/right phase construction or broadcast order.
"""
function apply_wannier_center_phases!(
    matrix::Matrix{ComplexF64},
    centers_cartesian::Matrix{Float64},
    left_vector::AbstractVector{<:Real},
    right_vector::AbstractVector{<:Real},
)
    return _apply_wannier_center_phases!(matrix, centers_cartesian, left_vector, right_vector)
end

"""
Derive axial and symmetric real-space operators from a full Cartesian
derivative-overlap tensor while preserving its component and allocation order.
"""
function derive_axial_and_symmetric_derivative_overlaps(
    derivative_overlap_tensor::Array{ComplexF64, 5},
)
    return _derive_axial_and_symmetric_derivative_overlaps(derivative_overlap_tensor)
end

"""
Apply the established R/-R Hermiticity projection to paired real-space blocks
without mutating the input array.
"""
function hermitianize_real_space_pairs(values::Array{ComplexF64}, r_vectors::Matrix{Int})
    return _hermitianize_real_space_pairs(values, r_vectors)
end

"""Return CHK Wannier centers as finite fractional row coordinates."""
function wannier_centers_fractional(chk::WannierCHK)
    return _wannier_centers_fractional(chk)
end

"""Return the complete noncentered Monkhorst-Pack residue grid."""
function mp_residue_grid(mp_grid::NTuple{3, Int})
    return _mp_residue_grid(mp_grid)
end

"""
Transform a q-last operator to unit-degeneracy, pair-dependent nearest-image
real-space storage using a prepared Wannier transform plan.

The wrapper preserves the plan's center shift, minimum-distance tie splitting,
Fourier normalization, tensor-index order, and target-support validation.
"""
function wannier_q_to_pair_wigner_seitz(
    values_q::Array{ComplexF64, N},
    chk::WannierCHK,
    plan::WannierPairWignerSeitzTransformPlan;
    support_tolerance::Float64,
    label::AbstractString,
) where {N}
    return _wannier_q_to_pair_wigner_seitz(values_q, chk, plan; support_tolerance, label)
end

"""
Return the maximum q-space reconstruction error for unit-degeneracy real-space
storage without changing the transform plan or either input array.
"""
function unit_degeneracy_roundtrip_error(
    values_q::Array{ComplexF64, N},
    values_r::Array{ComplexF64, N},
    chk::WannierCHK,
    plan::WannierPairWignerSeitzTransformPlan,
) where {N}
    return _unit_degeneracy_roundtrip_error(values_q, values_r, chk, plan)
end

"""
Apply the pair-dependent Wannier spin q-to-R transform and return its numerical
round-trip diagnostics.
"""
function transform_pair_wigner_seitz_spin_q_to_r(
    transform::PairWignerSeitzSpinQToRTransform,
    values_q::Array{ComplexF64, N},
    label::AbstractString,
) where {N}
    return _transform_spin_q_to_r(transform, values_q, label)
end

"""
Construct all spin-family real-space operators through an explicitly prepared
pair-dependent transform while preserving the established in-memory pipeline.
"""
function compute_spin_velocity_real_space_with_transform(
    model::AbstractResponseModel,
    spn::WannierSPN,
    chk::WannierCHK,
    eig::WannierEIG,
    mmn::WannierMMN,
    transform::PairWignerSeitzSpinQToRTransform;
    k_mesh_tolerance::Float64 = 1e-7,
    stencil_completeness_tolerance::Float64 = 1e-5,
    search_supercell::Int = 2,
)
    return _compute_spin_velocity_real_space_with_transform(
        model,
        spn,
        chk,
        eig,
        mmn,
        transform;
        k_mesh_tolerance,
        stencil_completeness_tolerance,
        search_supercell,
    )
end

"""
Construct all spin-family real-space operators through an explicitly prepared
pair-dependent transform while preserving the established streaming pipeline.
"""
function compute_spin_velocity_real_space_streaming_with_transform(
    model::AbstractResponseModel,
    spn::WannierSPN,
    chk::WannierCHK,
    eig::WannierEIG,
    overlap_file::AbstractString,
    transform::PairWignerSeitzSpinQToRTransform;
    k_mesh_tolerance::Float64 = 1e-7,
    stencil_completeness_tolerance::Float64 = 1e-5,
    search_supercell::Int = 2,
)
    return _compute_spin_velocity_real_space_streaming_with_transform(
        model,
        spn,
        chk,
        eig,
        overlap_file,
        transform;
        k_mesh_tolerance,
        stencil_completeness_tolerance,
        search_supercell,
    )
end

"""
Materialize a dictionary of selected operator components through one replica map.

The target-index lookup is shared only within this call. Each component keeps its
original replica normalization and accumulation order and owns its output array.
Neither the source components nor the map are mutated.
"""
function materialize_replica_components(
    components::Dict{K, V},
    input_degeneracies::Vector{Int},
    map::RealSpaceReplicaMap,
    normalization::Union{RawReplicaValues, PredividedReplicaValues},
) where {K, V}
    target_indices = _replica_target_indices(map)
    prepared = Dict{K, Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}}()
    for (kind, component_views) in components
        selected = Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}()
        for (component, values) in component_views
            selected[component] = _materialize_replica_component(
                values,
                input_degeneracies,
                map,
                normalization,
                target_indices,
            )
        end
        prepared[kind] = selected
    end
    return prepared
end

"""
Allow a mixed workspace to recycle same-group buffers when moving to a new block.

Runtime uses this hint only for whole-block ownership. Revisited blocks remain
correct: recycling invalidates the previous key, so a revisit is recomputed by
the normal miss path. This changes storage retention, never interpolation values.
"""
function reuse_completed_mixed_blocks!(workspace::MatrixElementWorkspace)
    return _reuse_completed_mixed_blocks!(workspace)
end

"""
Build an export-local pair transform from already computed nearest-image lists.

The caller must supply lists produced for this same CHK, centers, tolerance and
search size in the current export invocation. Ownership of the lists transfers
to the returned plan: the caller must not mutate or retain them for another call.
This port preserves target-support validation and does not cache across exports.
The independent public constructor continues to compute its own geometry.
"""
function wannier_pair_wigner_seitz_plan_from_images(
    chk::WannierCHK,
    target_r_vectors::Matrix{Int};
    wigner_seitz_tolerance::Float64,
    search_size::Int,
    precomputed_images::Dict{Tuple{Int, Int, NTuple{3, Int}}, Vector{NTuple{3, Int}}},
    wannier_centers_fractional::Union{Nothing, Matrix{Float64}} = nothing,
)
    return _wannier_pair_wigner_seitz_transform_plan(
        chk,
        target_r_vectors;
        wigner_seitz_tolerance,
        search_size,
        precomputed_images,
        wannier_centers_fractional,
    )
end

"""Reject an unprepared or stale worker-local orthogonal derivative state.

This sibling-response port preserves the owner's original preparation/generation
checks. It does not prepare, copy, or change any derivative matrices.
"""
@inline function validate_orthogonal_band_derivatives(workspace::OrthogonalBandDerivativeWorkspace)
    return _check_orthogonal_band_derivatives(workspace)
end
