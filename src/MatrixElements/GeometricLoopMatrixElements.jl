"""
Shared k-point matrix data plus contiguous degeneracy-group bounds and averaging weights used by finite loops.

The constructor initially treats each band as a singleton; source-gauge connection and velocity properties alias the shared data.
"""
mutable struct GeometricLoopMatrixData{D}
    num_orbitals::Int
    common::D
    degeneracy_weights::Vector{Float64}
    degeneracy_group_starts::Vector{Int}
    degeneracy_group_stops::Vector{Int}
end

# Shared k-point matrix data plus contiguous degeneracy-group bounds and averaging weights used by finite loops.
#
# The constructor initially treats each band as a singleton; source-gauge connection and velocity properties alias the shared data.
function GeometricLoopMatrixData(common::KPointMatrixData)
    num_orbitals = length(common.spectrum.energies)
    return GeometricLoopMatrixData(
        num_orbitals,
        common,
        ones(Float64, num_orbitals),
        collect(1:num_orbitals),
        collect(1:num_orbitals),
    )
end

# Expose compatibility matrix-property names through the shared k-point payload; read all other names as stored fields.
function Base.getproperty(data::GeometricLoopMatrixData, name::Symbol)
    if name === :inverse_energy_differences
        return subspace_inverse_energy_differences(getfield(data, :common))
    elseif name === :gauge_correction
        return subspace_gauge_correction(getfield(data, :common))
    elseif name === :hamiltonian_derivatives
        return getproperty(getfield(data, :common), :source_gauge_hamiltonian_derivatives)
    elseif name === :berry_connection || name === :source_gauge_berry_connection
        return subspace_connection(getfield(data, :common); source_gauge = true)
    elseif name === :velocity_vertices || name === :source_gauge_velocity_vertices
        return subspace_velocity_vertices(getfield(data, :common); source_gauge = true)
    elseif name === :spectrum ||
           name === :energy_differences ||
           name === :inverse_energy_differences ||
           name === :gauge_correction ||
           name === :internal_connection ||
           name === :source_gauge_hamiltonian_derivatives ||
           name === :source_gauge_berry_connection ||
           name === :source_gauge_velocity_vertices
        return getproperty(getfield(data, :common), name)
    end
    return getfield(data, name)
end

"""
Shared matrix workspace, optional offset cache, and a reduced raw-position plan for shifted Wilson points.

The dimension-based constructor requests raw h/A; constructors from an existing workspace preserve its convention and denominator controls.
"""
mutable struct GeometricLoopMatrixWorkspace{W, B, P}
    matrix_elements::W
    batch::B
    berry_plan::P
end

# Shared matrix workspace, optional offset cache, and a reduced raw-position plan for shifted Wilson points.
#
# The dimension-based constructor requests raw h/A; constructors from an existing workspace preserve its convention and denominator controls.
function GeometricLoopMatrixWorkspace(matrix_elements::MatrixElementWorkspace, batch)
    source_plan = matrix_elements.plan
    berry_plan = compile_matrix_plan(
        MatrixElementRequest(
            HAMILTONIAN_DERIVATIVES,
            INTERNAL_CONNECTION;
            spatial_dimension = source_plan.spatial_dimension,
            denominator_regularization = source_plan.denominator_regularization,
            degeneracy_threshold = source_plan.degeneracy_threshold,
        ),
        source_plan.direction_requirements,
        wannier_center_convention = source_plan.wannier_center_convention,
    )
    return GeometricLoopMatrixWorkspace(matrix_elements, batch, berry_plan)
end

# Shared matrix workspace, optional offset cache, and a reduced raw-position plan for shifted Wilson points.
#
# The dimension-based constructor requests raw h/A; constructors from an existing workspace preserve its convention and denominator controls.
GeometricLoopMatrixWorkspace(matrix_elements::MatrixElementWorkspace) =
    GeometricLoopMatrixWorkspace(matrix_elements, nothing)

# Shared matrix workspace, optional offset cache, and a reduced raw-position plan for shifted Wilson points.
#
# The dimension-based constructor requests raw h/A; constructors from an existing workspace preserve its convention and denominator controls.
function GeometricLoopMatrixWorkspace(
    num_orbitals::Integer,
    num_r_vectors::Integer,
    spatial_dimension::Integer,
)
    request = MatrixElementRequest(
        HAMILTONIAN_DERIVATIVES,
        INTERNAL_CONNECTION;
        spatial_dimension = spatial_dimension,
    )
    plan = compile_matrix_plan(request)
    return GeometricLoopMatrixWorkspace(
        MatrixElementWorkspace(num_orbitals, num_r_vectors, plan),
        nothing,
    )
end

"""
Bind `data.common` to the cached slot for a discrete k-point offset and return `data`.

Without a batch cache this is a no-op; existing cached matrices are shared, not copied.
"""
function bind_kpoint_offset!(
    data::GeometricLoopMatrixData,
    workspace::GeometricLoopMatrixWorkspace,
    offset::KPointOffset,
)
    workspace.batch === nothing && return data
    data.common = matrix_data!(workspace.batch, offset)
    return data
end

"""
Compute a shifted Wilson-loop point with the minimum required capability set.

The full response workspace can carry a larger bundled plan.  Wilson transport
at a shifted point needs the eigensystem and raw h/A for cached bare r0, but not the
central point's second derivatives or spin channels.
"""
function compute_wilson_shifted!(
    data::GeometricLoopMatrixData,
    workspace::GeometricLoopMatrixWorkspace,
    model::AbstractResponseModel,
    kpoint::AbstractVector{<:Real};
    denominator_regularization::Real,
    spatial_dimension::Integer = workspace.matrix_elements.plan.spatial_dimension,
)
    matrix_workspace = workspace.matrix_elements
    previous_plan = matrix_workspace.plan
    Int(spatial_dimension) == previous_plan.spatial_dimension || error(
        "Workspace spatial_dimension=$(previous_plan.spatial_dimension) does not match requested $(spatial_dimension).",
    )
    reduced = workspace.berry_plan
    matrix_workspace.plan = MatrixElementPlan(
        reduced.requested_mask,
        reduced.required_mask,
        reduced.spatial_dimension,
        Float64(denominator_regularization),
        previous_plan.degeneracy_threshold,
        previous_plan.wannier_center_convention,
        reduced.direction_requirements,
        reduced.source_gauge_required,
    )
    try
        compute_kpoint!(
            data.common,
            matrix_workspace,
            model,
            kpoint;
            denominator_regularization,
            spatial_dimension,
        )
    finally
        matrix_workspace.plan = previous_plan
    end
    return data
end

"""
Prepare k-independent real-space derivative buffers selected by the matrix plan.

Wrapper workspaces delegate to their shared interpolation workspace and retain slot ownership and Wannier-center convention.

Prepare real space in place.
"""
prepare_real_space!(workspace::GeometricLoopMatrixWorkspace, model::AbstractResponseModel) =
    prepare_real_space!(workspace.matrix_elements, model)

"""
Populate the supplied workspace or k-point data for a fractional reciprocal point using its capability plan.

Compute the spectrum before dependent matrices and return the populated data; wrapper overloads borrow the common workspace and restore its previous data reference. Caller-owned buffers are reused, and no response prefactor or k-mesh weight is applied.
"""
function compute_kpoint!(
    data::GeometricLoopMatrixData,
    workspace::GeometricLoopMatrixWorkspace,
    model::AbstractResponseModel,
    kpoint::AbstractVector{<:Real};
    denominator_regularization::Real,
    spatial_dimension::Integer = workspace.matrix_elements.plan.spatial_dimension,
)
    compute_kpoint!(
        data.common,
        workspace.matrix_elements,
        model,
        kpoint;
        denominator_regularization = denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    return data
end

"""Mark adjacent-gap response groups without altering spectra, operators or pair weights.

Projector, Wilson and Geometric response entrypoints share this chain policy.
The exact spectral partition and reconstruction guard are independent.
"""
function mark_geometric_response_groups!(
    data::GeometricLoopMatrixData,
    degeneracy_threshold::Float64,
)
    return _mark_response_degeneracy_groups!(data, degeneracy_threshold)
end

"""Mark Wilson transport groups using the shared adjacent-gap response policy."""
function mark_wilson_response_groups!(data::GeometricLoopMatrixData, degeneracy_threshold::Float64)
    return _mark_response_degeneracy_groups!(data, degeneracy_threshold)
end

"""Mark Geometric quantum-geometry response groups using the supplied threshold."""
function mark_degenerate_groups!(data::GeometricLoopMatrixData, degeneracy_threshold::Float64)
    # Retain the original exact-spectral admissibility check independently.
    # Its ranges do not choose or overwrite the response near-degeneracy groups.
    spectral_subspace_blocks(
        data.spectrum.energies;
        gap_tolerance = data.common.spectral_gap_tolerance,
    )
    return _mark_response_degeneracy_groups!(data, degeneracy_threshold)
end

"""
Construct the native source-gauge overlap `U_left^dagger * U_right` in place.

Both Wannier-center conventions use this identical link definition. Convention
dependence is already contained in the source-gauge eigensystems constructed by
the upstream typed matrix-element plan; no response-level center phase is added.
"""
function compute_loop_overlap!(
    output::AbstractMatrix{ComplexF64},
    left::GeometricLoopMatrixData,
    right::GeometricLoopMatrixData,
)
    num_orbitals = left.num_orbitals
    right.num_orbitals == num_orbitals || error("Loop overlap orbital counts do not match.")
    size(output) == (num_orbitals, num_orbitals) ||
        throw(DimensionMismatch("Loop overlap output has the wrong shape."))
    mul!(output, left.spectrum.source_eigenvectors_adjoint, right.spectrum.source_eigenvectors)
    return output
end

"""
Return the number of nonsingleton contiguous degeneracy groups and their maximum size (at least one).

Read stored group bounds without changing weights or the eigensystem.
"""
function degenerate_group_summary(data::GeometricLoopMatrixData)
    group_count = 0
    max_group_size = 1
    band = 1
    while band <= data.num_orbitals
        group_size = data.degeneracy_group_stops[band] - data.degeneracy_group_starts[band] + 1
        if group_size > 1
            group_count += 1
            max_group_size = max(max_group_size, group_size)
        end
        band = data.degeneracy_group_stops[band] + 1
    end
    return group_count, max_group_size
end

"""Worker-owned rectangular insertion scratch; all intermediate dimensions remain N.

Only the selected external rows/columns are valid. Selections are rebuilt for each
kernel, and derivatives are evaluated for each actual endpoint, never cached here.
Capacity is allocated once at the full finite basis size, independent of activity.
"""
mutable struct ActiveVelocityInsertionWorkspace
    valence_bands::Vector{Int}
    conduction_bands::Vector{Int}
    valence_active::BitVector
    conduction_active::BitVector
    buffers::Vector{Matrix{ComplexF64}}
    nonzero_indices::Vector{Int}
end

"""Allocate worker-private active-band selectors and reusable velocity insertion buffers for the given orbital count."""
function ActiveVelocityInsertionWorkspace(num_orbitals::Int)
    valence = Int[]
    conduction = Int[]
    sizehint!(valence, num_orbitals)
    sizehint!(conduction, num_orbitals)
    return ActiveVelocityInsertionWorkspace(
        valence,
        conduction,
        falses(num_orbitals),
        falses(num_orbitals),
        Matrix{ComplexF64}[],
        zeros(Int, num_orbitals),
    )
end

"""Reject active velocity insertions by default; model-specific methods must establish the fixed-basis contract."""
supports_active_velocity_insertions(model::AbstractResponseModel, centers, dimension) = false

# The declared fixed basis has raw A=0 and V=dH; no inferred position operator.
function supports_active_velocity_insertions(model::AnalyticKModel, centers, dimension)
    input = model.input
    return dimension in (2, 3) &&
           model.num_orbitals >= 64 &&
           input.basis == :fixed_orthonormal &&
           input.orbital_positions === nothing &&
           !haskey(input.operators, :position) &&
           !haskey(input.operators, :position_derivative) &&
           input.derivatives[1] !== nothing &&
           all(iszero, centers)
end

"""Evaluate the analytic Hamiltonian first derivative at the data point in physical reciprocal coordinates, using the model diagnostics."""
function active_velocity_gradient(data::KPointMatrixData, model::AnalyticKModel)
    physical_kpoint = transpose(reciprocal_lattice(model.lattice)) * data.kpoint
    return analytic_hamiltonian_derivative(
        model.input,
        physical_kpoint,
        1;
        diagnostics = model.evaluation_diagnostics,
    )
end

# Retain the established scalar source rotation order for selected velocity rows
# or columns. The first factor retains all N rows and columns so its finiteness
# and zero-factor decisions are identical to the complete reference transform.
function selected_source_velocity!(
    output,
    gradient,
    spectrum,
    temporary,
    indices,
    select_rows,
    gradient_buffer,
    nonzero_indices,
)
    n = size(output, 1)
    copyto!(gradient_buffer, gradient)
    source_gauge_first_product!(
        temporary,
        spectrum.source_eigenvectors_adjoint,
        gradient_buffer,
        nonzero_indices,
    )
    return fill_selected_source_velocity!(
        output,
        spectrum.source_eigenvectors,
        temporary,
        indices,
        select_rows,
    )
end

# The first source product is valid only for the current endpoint and direction.
# A second selected-column write can extend the same velocity matrix without
# clearing its already prepared rows; intersection entries retain identical sums.
function fill_selected_source_velocity!(
    output,
    eigenvectors,
    temporary,
    indices,
    select_rows;
    clear_output = true,
)
    n = size(output, 1)
    skip_zero = _source_gauge_zero_skipping_eligible(n, temporary, eigenvectors)
    clear_output && fill!(output, COMPLEX_ZERO)
    rows = select_rows ? indices : (1:n)
    columns = select_rows ? (1:n) : indices
    @inbounds for column in columns, row in rows
        value = COMPLEX_ZERO
        for intermediate in 1:n
            right = eigenvectors[intermediate, column]
            skip_zero && iszero(right) && continue
            value += temporary[row, intermediate] * right
        end
        output[row, column] = value
    end
    return output
end

"""Overwrite the insertion with left_velocity*overlap followed by overlap*right_velocity in the original two-GEMM order."""
function active_velocity_insertion_direction!(output, left_velocity, right_velocity, overlap)
    mul!(output, left_velocity, overlap)
    mul!(output, overlap, right_velocity, 1.0, 1.0)
    return output
end

# Only selected output columns are valid for active insertions. Keep every row,
# every intermediate band, and the two original ordered GEMMs. Fixed 64-column
# panels preserve dense BLAS work; this is not a skinny source-gauge rotation.
# Rebuild panels from the current sorted bands; no selection survives a call.
function active_velocity_selected_columns!(output, left_velocity, right_velocity, overlap, indices)
    n = size(output, 1)
    if !_dense_column_panel_storage_eligible(
        output,
        indices,
        left_velocity,
        right_velocity,
        overlap,
    )
        return active_velocity_insertion_direction!(output, left_velocity, right_velocity, overlap)
    end
    previous_band = 0
    previous_panel = 0
    columns = 0
    for band in indices
        if !(previous_band < band <= n)
            return active_velocity_insertion_direction!(
                output,
                left_velocity,
                right_velocity,
                overlap,
            )
        end
        first_column = 64 * div(band - 1, 64) + 1
        if first_column != previous_panel
            columns += min(64, n - first_column + 1)
            previous_panel = first_column
        end
        previous_band = band
    end
    if 2 * columns > n ||
       !all(isfinite, left_velocity) ||
       !all(isfinite, right_velocity) ||
       !all(isfinite, overlap)
        return active_velocity_insertion_direction!(output, left_velocity, right_velocity, overlap)
    end
    previous_panel = 0
    for band in indices
        first_column = 64 * div(band - 1, 64) + 1
        first_column == previous_panel && continue
        previous_panel = first_column
        columns = first_column:min(first_column + 63, n)
        @views mul!(output[:, columns], left_velocity, overlap[:, columns])
        @views mul!(output[:, columns], overlap, right_velocity[:, columns], 1.0, 1.0)
    end
    return output
end

"""Prepare selected external velocity rows/columns with all N intermediate bands.

The established source-rotation summation order and full-size insertion GEMM
intermediate dimension and product association are retained. Only selected output
columns are written in fixed dense panels when eligible. Inactive velocity
rows/columns are zero scratch, never a capability or a physical band truncation.
Only output[left_indices,right_indices,directions] is valid. Both terms and the
explicit reverse central insertion retain all finite bands and diagonal terms.
"""
function active_velocity_insertions!(
    output,
    left::KPointMatrixData,
    right::KPointMatrixData,
    left_indices,
    right_indices,
    directions,
    left_gradient,
    right_gradient,
    scratch::ActiveVelocityInsertionWorkspace;
    overlap = nothing,
)
    n = length(left.spectrum.energies)
    if isempty(scratch.buffers)
        append!(scratch.buffers, [zeros(ComplexF64, n, n) for _ in 1:5])
    end
    left_velocity, right_velocity, local_overlap, temporary, gradient_buffer = scratch.buffers
    if overlap === nothing
        mul!(
            local_overlap,
            left.spectrum.source_eigenvectors_adjoint,
            right.spectrum.source_eigenvectors,
        )
        overlap = local_overlap
    end
    @views for direction in directions
        selected_source_velocity!(
            left_velocity,
            left_gradient[:, :, direction],
            left.spectrum,
            temporary,
            left_indices,
            true,
            gradient_buffer,
            scratch.nonzero_indices,
        )
        selected_source_velocity!(
            right_velocity,
            right_gradient[:, :, direction],
            right.spectrum,
            temporary,
            right_indices,
            false,
            gradient_buffer,
            scratch.nonzero_indices,
        )
        active_velocity_selected_columns!(
            output[:, :, direction],
            left_velocity,
            right_velocity,
            overlap,
            right_indices,
        )
    end
    return output
end

"""Prepare both ordered central insertions with same-call endpoint factor reuse.

Each endpoint/direction first factor U†dH is computed once. Complete required
rows and columns use its original ordered sums, and both ordered overlaps and
insertion products retain all rows and intermediate bands with selected output
columns in eligible dense panels. No derivative,
first factor, or selection is retained as valid across calls or k/q endpoints.
"""
function active_velocity_paired_insertions!(
    forward_output,
    reverse_output,
    left::KPointMatrixData,
    right::KPointMatrixData,
    left_indices,
    right_indices,
    directions,
    left_gradient,
    right_gradient,
    scratch::ActiveVelocityInsertionWorkspace,
    reverse_overlap,
)
    n = length(left.spectrum.energies)
    if isempty(scratch.buffers)
        append!(scratch.buffers, [zeros(ComplexF64, n, n) for _ in 1:5])
    end
    left_velocity, right_velocity, forward_overlap, temporary, gradient_buffer = scratch.buffers
    # Independent ordered overlaps, matching the stable preparation, not an adjoint shortcut.
    mul!(
        forward_overlap,
        left.spectrum.source_eigenvectors_adjoint,
        right.spectrum.source_eigenvectors,
    )
    mul!(
        reverse_overlap,
        right.spectrum.source_eigenvectors_adjoint,
        left.spectrum.source_eigenvectors,
    )
    @views for direction in directions
        for (velocity, gradient, data, indices) in (
            (left_velocity, left_gradient, left, left_indices),
            (right_velocity, right_gradient, right, right_indices),
        )
            copyto!(gradient_buffer, gradient[:, :, direction])
            source_gauge_first_product!(
                temporary,
                data.spectrum.source_eigenvectors_adjoint,
                gradient_buffer,
                scratch.nonzero_indices,
            )
            fill_selected_source_velocity!(
                velocity,
                data.spectrum.source_eigenvectors,
                temporary,
                indices,
                true,
            )
            fill_selected_source_velocity!(
                velocity,
                data.spectrum.source_eigenvectors,
                temporary,
                indices,
                false;
                clear_output = false,
            )
        end
        active_velocity_selected_columns!(
            forward_output[:, :, direction],
            left_velocity,
            right_velocity,
            forward_overlap,
            right_indices,
        )
        active_velocity_selected_columns!(
            reverse_output[:, :, direction],
            right_velocity,
            left_velocity,
            reverse_overlap,
            left_indices,
        )
    end
    return forward_output
end
