"""
Store the complete raw-to-final Wannier-center lifecycle for one model build.

Centers use Wannier-major rows and fractional row-lattice coordinates. Branch
shifts align input centers to the projection-center branches used by the
`WannierSymmetryPlan`; operation residuals use those same fixed branches.
"""
struct WannierCenterGeometry
    policy::Symbol
    raw_fractional::Matrix{Float64}
    aligned_fractional::Matrix{Float64}
    final_fractional::Matrix{Float64}
    raw_cartesian::Matrix{Float64}
    final_cartesian::Matrix{Float64}
    alignment_lattice_shifts::Matrix{Int}
    raw_operation_residuals::Vector{Float64}
    aligned_operation_residuals::Vector{Float64}
    final_operation_residuals::Vector{Float64}
    idempotence_error::Float64
    maximum_displacement_cartesian::Float64
    rms_displacement_cartesian::Float64
    production_eligible::Bool
end

# Return projection-center branches in Wannier-major fractional storage.
function _projection_reference_centers_fractional(basis::WannierProjectionBasis)
    centers = zeros(Float64, basis.num_wannier, 3)
    assigned = falses(basis.num_wannier)
    for block in basis.blocks, center_index in axes(block.positions_fractional, 2)
        position = @view block.positions_fractional[:, center_index]
        for wannier_index in @view(block.indices[:, center_index])
            centers[wannier_index, :] .= position
            assigned[wannier_index] = true
        end
    end
    all(assigned) || error("projection basis did not assign every Wannier center")
    return centers
end

# Extract normalized Cartesian centers from the position R=(0,0,0) diagonal.
function _position_wannier_centers_cartesian(position::RealSpaceOperator)
    position.spec.kind == REAL_SPACE_POSITION ||
        throw(ArgumentError("Wannier centers require the position operator"))
    home_indices = findall(
        index -> all(iszero, @view(position.r_vectors[:, index])),
        axes(position.r_vectors, 2),
    )
    length(home_indices) == 1 ||
        throw(ArgumentError("position operator must contain exactly one home-cell block"))
    home_index = only(home_indices)
    num_wannier = size(position.data, 1)
    centers = zeros(Float64, num_wannier, 3)
    for wannier_index in 1:num_wannier, direction in 1:3
        value = position.data[wannier_index, wannier_index, direction, home_index]
        isfinite(real(value)) && isfinite(imag(value)) ||
            throw(ArgumentError("position-derived Wannier center is non-finite"))
        abs(imag(value)) <= 1.0e-10 ||
            throw(ArgumentError("position-derived Wannier center has an imaginary component"))
        centers[wannier_index, direction] = real(value)
    end
    return centers
end

# Convert Wannier-major Cartesian centers to fractional row-lattice coordinates.
function _center_rows_cartesian_to_fractional(centers::Matrix{Float64}, lattice::Matrix{Float64})
    output = similar(centers)
    for wannier_index in axes(centers, 1)
        output[wannier_index, :] .=
            real_space_cartesian_to_fractional(@view(centers[wannier_index, :]), lattice)
    end
    return output
end

# Convert Wannier-major fractional centers to Cartesian row coordinates.
function _center_rows_fractional_to_cartesian(centers::Matrix{Float64}, lattice::Matrix{Float64})
    return centers * lattice
end

# Align input centers to the projection-center branches recorded by the plan.
function _align_wannier_center_branches(
    raw_fractional::Matrix{Float64},
    reference_fractional::Matrix{Float64},
)
    size(raw_fractional) == size(reference_fractional) ||
        throw(ArgumentError("Wannier-center and projection-center dimensions differ"))
    shifts = round.(Int, raw_fractional .- reference_fractional)
    return raw_fractional .- shifts, shifts
end

# Apply one affine symmetry action to diagonal Wannier-center expectations.
function _transform_wannier_centers(
    centers_fractional::Matrix{Float64},
    plan::WannierSymmetryPlan,
    operation_index::Int,
)
    operation = plan.operations[operation_index]
    representation = @view plan.representation_matrices[:, :, operation_index]
    num_wannier = size(centers_fractional, 1)
    transformed = zeros(Float64, num_wannier, 3)
    row_weights = zeros(Float64, num_wannier)
    for target in 1:num_wannier, source in 1:num_wannier
        weight = abs2(representation[target, source])
        weight == 0.0 && continue
        candidate =
            operation.rotation_fractional * @view(centers_fractional[source, :]) .+
            operation.translation_fractional .-
            @view(plan.wannier_shifts[:, source, operation_index])
        transformed[target, :] .+= weight .* candidate
        row_weights[target] += weight
    end
    maximum(abs, row_weights .- 1.0; init = 0.0) <= 10plan.tolerance ||
        throw(ArgumentError("Wannier representation rows are not normalized"))
    transformed ./= reshape(row_weights, :, 1)
    return transformed
end

# Return one fixed-branch covariance residual per selected operation.
function _wannier_center_operation_residuals(
    centers_fractional::Matrix{Float64},
    plan::WannierSymmetryPlan,
)
    return [
        maximum(
            abs,
            _transform_wannier_centers(centers_fractional, plan, operation_index) .-
            centers_fractional;
            init = 0.0,
        ) for operation_index in plan.operation_indices
    ]
end

# Apply the finite-group affine projector once.
function _project_wannier_centers(centers_fractional::Matrix{Float64}, plan::WannierSymmetryPlan)
    output = zeros(Float64, size(centers_fractional))
    for operation_index in plan.operation_indices
        output .+= _transform_wannier_centers(centers_fractional, plan, operation_index)
    end
    output ./= length(plan.operation_indices)
    return output
end

"""
Resolve the configured Wannier-center policy and return auditable geometry.

`:symmetrize` projects branch-aligned input centers, `:validate` preserves input
centers only after a covariance gate, and `:keep_input` preserves them while
marking the model diagnostic. The function changes no operator data.
"""
function _resolve_wannier_center_geometry(
    raw_cartesian::Matrix{Float64},
    lattice::Matrix{Float64},
    basis::WannierProjectionBasis,
    plan::WannierSymmetryPlan,
    policy::Symbol,
    tolerance::Float64,
)
    policy in (:symmetrize, :validate, :keep_input) ||
        throw(ArgumentError("wannier_center_policy must be :symmetrize, :validate, or :keep_input"))
    isfinite(tolerance) && tolerance > 0.0 ||
        throw(ArgumentError("wannier_center_tolerance must be finite and positive"))
    raw_fractional = _center_rows_cartesian_to_fractional(raw_cartesian, lattice)
    reference_fractional = _projection_reference_centers_fractional(basis)
    aligned_fractional, alignment_shifts =
        _align_wannier_center_branches(raw_fractional, reference_fractional)
    raw_residuals = _wannier_center_operation_residuals(raw_fractional, plan)
    aligned_residuals = _wannier_center_operation_residuals(aligned_fractional, plan)
    final_fractional = if policy == :symmetrize
        _project_wannier_centers(aligned_fractional, plan)
    elseif policy == :validate
        # A lattice-branch change does not move a Wannier center physically.
        # Store the branch-aligned representative so the durable model and the
        # symmetry plan use one consistent affine gauge.
        copy(aligned_fractional)
    else
        copy(raw_fractional)
    end
    final_residuals = _wannier_center_operation_residuals(final_fractional, plan)
    maximum_final_residual = maximum(final_residuals; init = 0.0)
    if policy in (:symmetrize, :validate) && maximum_final_residual > tolerance
        throw(
            ArgumentError(
                "Wannier-center covariance residual $(maximum_final_residual) exceeds $(tolerance)",
            ),
        )
    end
    repeated =
        policy == :symmetrize ? _project_wannier_centers(final_fractional, plan) : final_fractional
    idempotence_error = maximum(abs, repeated .- final_fractional; init = 0.0)
    policy == :symmetrize &&
        idempotence_error > tolerance &&
        throw(
            ArgumentError(
                "Wannier-center idempotence error $(idempotence_error) exceeds $(tolerance)",
            ),
        )
    final_cartesian = _center_rows_fractional_to_cartesian(final_fractional, lattice)
    aligned_cartesian = _center_rows_fractional_to_cartesian(aligned_fractional, lattice)
    displacements =
        policy == :keep_input ? zeros(Float64, size(final_cartesian)) :
        final_cartesian .- aligned_cartesian
    displacement_norms = [norm(@view(displacements[index, :])) for index in axes(displacements, 1)]
    return WannierCenterGeometry(
        policy,
        raw_fractional,
        aligned_fractional,
        final_fractional,
        copy(raw_cartesian),
        final_cartesian,
        alignment_shifts,
        raw_residuals,
        aligned_residuals,
        final_residuals,
        idempotence_error,
        maximum(displacement_norms; init = 0.0),
        isempty(displacement_norms) ? 0.0 :
        sqrt(sum(abs2, displacement_norms) / length(displacement_norms)),
        policy != :keep_input,
    )
end

# Verify that CHK and TB encode the same raw centers modulo lattice vectors.
function _validate_checkpoint_wannier_centers(
    chk::WannierCHK,
    geometry::WannierCenterGeometry,
    tolerance::Float64,
)
    checkpoint_fractional = wannier_centers_fractional(chk)
    size(checkpoint_fractional) == size(geometry.raw_fractional) ||
        throw(ArgumentError("CHK and TB Wannier-center dimensions differ"))
    residual = checkpoint_fractional .- geometry.raw_fractional
    residual .-= round.(residual)
    maximum_error = maximum(abs, residual; init = 0.0)
    maximum_error <= tolerance || throw(
        ArgumentError(
            "CHK and TB Wannier centers differ modulo lattice vectors: max_abs=$(maximum_error)",
        ),
    )
    return maximum_error
end
