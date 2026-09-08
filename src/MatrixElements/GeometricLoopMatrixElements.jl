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
    if name === :hamiltonian_derivatives
        return getproperty(getfield(data, :common), :source_gauge_hamiltonian_derivatives)
    elseif name === :berry_connection
        return getproperty(getfield(data, :common), :source_gauge_berry_connection)
    elseif name === :velocity_vertices
        return getproperty(getfield(data, :common), :source_gauge_velocity_vertices)
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
Shared matrix workspace, optional offset cache, and a reduced Berry-connection plan for shifted Wilson points.

The dimension-based constructor requests velocity vertices; constructors from an existing workspace preserve its convention and denominator controls.
"""
mutable struct GeometricLoopMatrixWorkspace{W, B, P}
    matrix_elements::W
    batch::B
    berry_plan::P
end

# Shared matrix workspace, optional offset cache, and a reduced Berry-connection plan for shifted Wilson points.
#
# The dimension-based constructor requests velocity vertices; constructors from an existing workspace preserve its convention and denominator controls.
function GeometricLoopMatrixWorkspace(matrix_elements::MatrixElementWorkspace, batch)
    source_plan = matrix_elements.plan
    berry_plan = compile_matrix_plan(
        MatrixElementRequest(
            BERRY_CONNECTION;
            spatial_dimension = source_plan.spatial_dimension,
            denominator_regularization = source_plan.denominator_regularization,
            degeneracy_threshold = source_plan.degeneracy_threshold,
        ),
        source_plan.direction_requirements,
        wannier_center_convention = source_plan.wannier_center_convention,
    )
    return GeometricLoopMatrixWorkspace(matrix_elements, batch, berry_plan)
end

# Shared matrix workspace, optional offset cache, and a reduced Berry-connection plan for shifted Wilson points.
#
# The dimension-based constructor requests velocity vertices; constructors from an existing workspace preserve its convention and denominator controls.
GeometricLoopMatrixWorkspace(matrix_elements::MatrixElementWorkspace) =
    GeometricLoopMatrixWorkspace(matrix_elements, nothing)

# Shared matrix workspace, optional offset cache, and a reduced Berry-connection plan for shifted Wilson points.
#
# The dimension-based constructor requests velocity vertices; constructors from an existing workspace preserve its convention and denominator controls.
function GeometricLoopMatrixWorkspace(
    num_orbitals::Integer,
    num_r_vectors::Integer,
    spatial_dimension::Integer,
)
    request = MatrixElementRequest(VELOCITY_VERTICES; spatial_dimension = spatial_dimension)
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
at a shifted point needs the eigensystem and Berry connection, but not the
central point's second derivatives or spin channels.
"""
function compute_wilson_shifted!(
    data::GeometricLoopMatrixData,
    workspace::GeometricLoopMatrixWorkspace,
    model::TightBindingModel,
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
prepare_real_space!(workspace::GeometricLoopMatrixWorkspace, model::TightBindingModel) =
    prepare_real_space!(workspace.matrix_elements, model)

"""
Populate the supplied workspace or k-point data for a fractional reciprocal point using its capability plan.

Compute the spectrum before dependent matrices and return the populated data; wrapper overloads borrow the common workspace and restore its previous data reference. Caller-owned buffers are reused, and no response prefactor or k-mesh weight is applied.
"""
function compute_kpoint!(
    data::GeometricLoopMatrixData,
    workspace::GeometricLoopMatrixWorkspace,
    model::TightBindingModel,
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

"""
Mark degenerate groups in caller-owned state.
"""
function mark_degenerate_groups!(data::GeometricLoopMatrixData, degeneracy_threshold::Float64)
    band = 1
    while band <= data.num_orbitals
        group_start = band
        while band < data.num_orbitals &&
            (data.spectrum.energies[band + 1] - data.spectrum.energies[band]) < degeneracy_threshold
            band += 1
        end
        group_stop = band
        group_size = group_stop - group_start + 1
        group_weight = 1.0 / group_size
        for group_band in group_start:group_stop
            data.degeneracy_weights[group_band] = group_weight
            data.degeneracy_group_starts[group_band] = group_start
            data.degeneracy_group_stops[group_band] = group_stop
        end
        band = group_stop + 1
    end
    return data
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
