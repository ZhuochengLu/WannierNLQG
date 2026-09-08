"""
Qualified, non-exported MatrixElements API consumed by sibling expert workflows.

Entries in this tuple are stable cross-layer contracts. Implementation helpers
absent from the tuple remain private to `MatrixElements` and must not be used by
production code in another module.
"""
const MATRIX_ELEMENTS_INTEGRATION_API = (
    :REAL_SPACE_REPLICA_MAP_DIGEST_SCHEME,
    :MatrixElementDirectionRequirements,
    :RealSpaceReplicaMap,
    :SerializedWannier90ReplicaValues,
    :SharedInterpolationCache,
    :apply_wannier_center_phases!,
    :begin_shared_interpolation!,
    :compute_spin_velocity_real_space_streaming_with_transform,
    :compute_spin_velocity_real_space_with_transform,
    :compute_loop_overlap!,
    :derive_axial_and_symmetric_derivative_overlaps,
    :hermitianize_real_space_pairs,
    :input_real_space_replica_map,
    :input_real_space_replica_mapping_sha256,
    :matrix_element_axis_required,
    :matrix_element_pair_required,
    :materialize_replica_component,
    :minimum_distance_real_space_replica_map,
    :mp_residue_grid,
    :real_space_replica_map_from_wsvec,
    :require_matrix_element_axes,
    :require_matrix_element_pairs,
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
    model::TightBindingModel,
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
    model::TightBindingModel,
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
