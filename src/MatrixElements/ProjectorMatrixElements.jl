# Projector-specific data built on shared interpolated matrix elements.

"""
Shared eigensystem plus effective connections, external geometry and first/second derivatives of band projectors.

Arrays use `(band,orbital,orbital,Cartesian...)` for projectors and store contiguous degeneracy bounds and averaging weights separately.
"""
mutable struct ProjectorMatrixData{D}
    num_orbitals::Int
    common::D
    effective_connection::Array{ComplexF64, 3}
    effective_connection_derivatives::Array{ComplexF64, 4}
    external_geometry::Array{ComplexF64, 4}
    projectors::Array{ComplexF64, 3}
    projector_derivatives::Array{ComplexF64, 4}
    projector_second_derivatives::Array{ComplexF64, 5}
    degeneracy_weights::Vector{Float64}
    degeneracy_group_starts::Vector{Int}
    degeneracy_group_stops::Vector{Int}
end

# Shared eigensystem plus effective connections, external geometry and first/second derivatives of band projectors.
#
# Arrays use `(band,orbital,orbital,Cartesian...)` for projectors and store contiguous degeneracy bounds and averaging weights separately.
function ProjectorMatrixData(common::KPointMatrixData, spatial_dimension::Integer)
    num_orbitals = length(common.spectrum.energies)
    dimension = Int(spatial_dimension)
    return ProjectorMatrixData(
        num_orbitals,
        common,
        zeros(ComplexF64, num_orbitals, num_orbitals, dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, dimension, dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, dimension, dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals, num_orbitals, dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, num_orbitals, dimension, dimension),
        zeros(Float64, num_orbitals),
        collect(1:num_orbitals),
        collect(1:num_orbitals),
    )
end

# Expose compatibility matrix-property names through the shared k-point payload; read all other names as stored fields.
function Base.getproperty(data::ProjectorMatrixData, name::Symbol)
    if name === :spectrum ||
       name === :energy_differences ||
       name === :inverse_energy_differences ||
       name === :berry_connection ||
       name === :gauge_correction ||
       name === :internal_connection ||
       name === :hamiltonian_derivatives ||
       name === :velocity_vertices
        return getproperty(getfield(data, :common), name)
    elseif name === :wannier_connection
        return getfield(data, :common).position.wannier_gauge
    end
    return getfield(data, name)
end

"""
Shared interpolation workspace and optional offset cache with raw connection/derivative-overlap buffers and a convention-specific frame connector.

Scratch and Wannier-center phase arrays belong to this execution slot; constructors preserve the underlying matrix plan.
"""
mutable struct ProjectorMatrixWorkspace{W, B, F}
    matrix_elements::W
    batch::B
    raw_wannier_connection::Array{ComplexF64, 3}
    raw_wannier_connection_derivatives::Array{ComplexF64, 4}
    derivative_overlap_wannier::Array{ComplexF64, 4}
    frame_connector::F
    frame_phase_factors::Vector{ComplexF64}
    wannier_centers_cartesian::Matrix{Float64}
    wannier_centers_fractional::Matrix{Float64}
end

# Shared interpolation workspace and optional offset cache with raw connection/derivative-overlap buffers and a convention-specific frame connector.
#
# Scratch and Wannier-center phase arrays belong to this execution slot; constructors preserve the underlying matrix plan.
ProjectorMatrixWorkspace(matrix_elements::MatrixElementWorkspace) =
    ProjectorMatrixWorkspace(matrix_elements, nothing)

# Shared interpolation workspace and optional offset cache with raw connection/derivative-overlap buffers and a convention-specific frame connector.
#
# Scratch and Wannier-center phase arrays belong to this execution slot; constructors preserve the underlying matrix plan.
function ProjectorMatrixWorkspace(matrix_elements::MatrixElementWorkspace, batch)
    num_orbitals = matrix_elements.data.num_orbitals
    dimension = matrix_elements.plan.spatial_dimension
    connector = make_convention_frame_connector(matrix_elements.plan.wannier_center_convention)
    return ProjectorMatrixWorkspace(
        matrix_elements,
        batch,
        zeros(ComplexF64, num_orbitals, num_orbitals, dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, dimension, dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, dimension, dimension),
        connector,
        zeros(ComplexF64, num_orbitals),
        zeros(Float64, 3, num_orbitals),
        zeros(Float64, 3, num_orbitals),
    )
end

# Shared interpolation workspace and optional offset cache with raw connection/derivative-overlap buffers and a convention-specific frame connector.
#
# Scratch and Wannier-center phase arrays belong to this execution slot; constructors preserve the underlying matrix plan.
function ProjectorMatrixWorkspace(
    num_orbitals::Integer,
    num_r_vectors::Integer,
    spatial_dimension::Integer,
)
    request = MatrixElementRequest(VELOCITY_VERTICES; spatial_dimension = spatial_dimension)
    plan = compile_matrix_plan(request)
    return ProjectorMatrixWorkspace(MatrixElementWorkspace(num_orbitals, num_r_vectors, plan))
end

"""
Build the center-frame connection, its derivative, and the external geometry
`G_mu_beta = Dprime_mu_beta - A_mu A_beta` for the complete Projector kernel.

The derivative-overlap tensor must have entered through a schema-6 bundle
whose runtime preflight established `full_hilbert_space` provenance. This
method deliberately has no MMN-internal fallback.
"""
function prepare_projector_covariant_geometry!(
    data::ProjectorMatrixData,
    workspace::ProjectorMatrixWorkspace,
    model::TightBindingModel,
)
    source = workspace.matrix_elements.sources.derivative_overlap
    source === nothing && throw(
        ArgumentError(
            "PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: exact uIu/FF_R source is absent",
        ),
    )
    derivative_overlap_r = source.derivative_overlap_r
    size(derivative_overlap_r, 1) == model.num_orbitals &&
    size(derivative_overlap_r, 2) == model.num_orbitals &&
    size(derivative_overlap_r, 5) == model.num_r_vectors ||
        throw(DimensionMismatch("derivative-overlap tensor and tight-binding model disagree"))
    dimension = workspace.matrix_elements.plan.spatial_dimension
    raw_connection = workspace.raw_wannier_connection
    raw_connection_derivatives = workspace.raw_wannier_connection_derivatives
    derivative_overlap = workspace.derivative_overlap_wannier
    plan = workspace.matrix_elements.plan
    fill!(raw_connection, COMPLEX_ZERO)
    fill!(raw_connection_derivatives, COMPLEX_ZERO)
    fill!(derivative_overlap, COMPLEX_ZERO)
    home = _home_cell_r_index(model)
    centers = workspace.wannier_centers_cartesian
    centers_fractional = workspace.wannier_centers_fractional
    @inbounds for orbital in 1:model.num_orbitals, axis in 1:3
        center = model.position_r[orbital, orbital, axis, home]
        abs(imag(center)) <= 1.0e-10 ||
            throw(ArgumentError("Wannier center has a non-negligible imaginary part"))
        centers[axis, orbital] = real(center)
    end
    @inbounds for orbital in 1:model.num_orbitals
        centers_fractional[:, orbital] .=
            real_space_cartesian_to_fractional(@view(centers[:, orbital]), model.lattice)
    end
    @inbounds for r_index in 1:model.num_r_vectors
        factor = data.common.fourier_factors[r_index]
        r_cartesian = _r_vector_cartesian(model, r_index)
        for beta in 1:dimension, mu in 1:dimension
            _pair_required(plan, INTERNAL_CONNECTION_DERIVATIVES, mu, beta) || continue
            for column in 1:model.num_orbitals, row in 1:model.num_orbitals
                derivative_overlap[row, column, mu, beta] +=
                    factor * derivative_overlap_r[row, column, mu, beta, r_index]
            end
        end
        for mu in 1:dimension
            for column in 1:model.num_orbitals, row in 1:model.num_orbitals
                raw_connection[row, column, mu] +=
                    factor * model.position_r[row, column, mu, r_index]
                for beta in 1:dimension
                    raw_connection_derivatives[row, column, beta, mu] +=
                        1.0im *
                        r_cartesian[mu] *
                        factor *
                        model.position_r[row, column, beta, r_index]
                end
            end
        end
    end
    temporary = workspace.matrix_elements.scratch.matrix_temporary
    for mu in 1:dimension, beta in 1:dimension
        _pair_required(plan, INTERNAL_CONNECTION_DERIVATIVES, mu, beta) || continue
        @views begin
            mul!(temporary, raw_connection[:, :, mu], raw_connection[:, :, beta])
            data.external_geometry[:, :, mu, beta] .=
                derivative_overlap[:, :, mu, beta] .- temporary
            if workspace.matrix_elements.plan.wannier_center_convention == CONVENTION_I
                _apply_wannier_center_similarity!(
                    data.external_geometry[:, :, mu, beta],
                    workspace.matrix_elements.scratch,
                    workspace.matrix_elements.plan,
                )
            end
        end
    end
    data.effective_connection .= raw_connection
    @inbounds for beta in 1:dimension, orbital in 1:model.num_orbitals
        data.effective_connection[orbital, orbital, beta] -= centers[beta, orbital]
    end
    data.effective_connection_derivatives .= raw_connection_derivatives
    for beta in 1:dimension
        effective = @view data.effective_connection[:, :, beta]
        for mu in 1:dimension
            derivative = @view data.effective_connection_derivatives[:, :, beta, mu]
            for column in 1:model.num_orbitals, row in 1:model.num_orbitals
                derivative[row, column] -=
                    1.0im * (centers[mu, row] - centers[mu, column]) * effective[row, column]
            end
            if workspace.matrix_elements.plan.wannier_center_convention == CONVENTION_I
                _apply_wannier_center_similarity!(
                    derivative,
                    workspace.matrix_elements.scratch,
                    workspace.matrix_elements.plan,
                )
            end
        end
        if workspace.matrix_elements.plan.wannier_center_convention == CONVENTION_I
            _apply_wannier_center_similarity!(
                effective,
                workspace.matrix_elements.scratch,
                workspace.matrix_elements.plan,
            )
        end
    end
    return data
end

# Bind `data.common` to the cached slot for a discrete k-point offset and return `data`.
#
# Without a batch cache this is a no-op; existing cached matrices are shared, not copied.
function bind_kpoint_offset!(
    data::ProjectorMatrixData,
    workspace::ProjectorMatrixWorkspace,
    offset::KPointOffset,
)
    workspace.batch === nothing && return data
    data.common = matrix_data!(workspace.batch, offset)
    return data
end

# Reuse caller-owned scratch and the plan's Wannier-center convention; no k-space or response accumulation occurs.
prepare_real_space!(workspace::ProjectorMatrixWorkspace, model::TightBindingModel) =
    prepare_real_space!(workspace.matrix_elements, model)

# Populate the supplied workspace or k-point data for a fractional reciprocal point using its capability plan.
#
# Compute the spectrum before dependent matrices and return the populated data; wrapper overloads borrow the common workspace and restore its previous data reference. Caller-owned buffers are reused, and no response prefactor or k-mesh weight is applied.
function compute_kpoint!(
    data::ProjectorMatrixData,
    workspace::ProjectorMatrixWorkspace,
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
Compute only the eigensystem needed to build a shifted-band projector.

Projector finite differences do not consume velocity or Berry-connection data at
the shifted point.  Keeping this entry point separate prevents a bundled
matrix-element plan from materializing the central point's larger mixed-Fourier
channel set for every offset.
"""
function compute_projector_spectrum!(
    data::ProjectorMatrixData,
    workspace::ProjectorMatrixWorkspace,
    model::TightBindingModel,
    kpoint::AbstractVector{<:Real},
    ;
    denominator_regularization::Real = workspace.matrix_elements.plan.denominator_regularization,
    spatial_dimension::Integer = workspace.matrix_elements.plan.spatial_dimension,
)
    Int(spatial_dimension) == workspace.matrix_elements.plan.spatial_dimension || error(
        "Workspace spatial_dimension=$(workspace.matrix_elements.plan.spatial_dimension) does not match requested $(spatial_dimension).",
    )
    isfinite(denominator_regularization) ||
        throw(ArgumentError("denominator_regularization must be finite."))
    compute_spectrum!(data.common, workspace.matrix_elements, model, kpoint)
    return data
end

"""
Build the central Hamiltonian-gauge band projectors and degeneracy groups.

For a nondegenerate band `n`, the stored matrix is `P_n = |u_n><u_n|`. Bands
connected by adjacent energy gaps below `degeneracy_threshold` share the summed
subspace projector and weight `1 / group_size`. `active_bands` may skip whole
groups but never splits a degenerate group. The routine mutates `data` only;
response prefactors and k-point normalization remain Runtime responsibilities.
"""
function projector_reference_projectors!(
    data::ProjectorMatrixData,
    band_num::Int64,
    degeneracy_threshold::Float64,
    ;
    active_bands::Union{Nothing, AbstractVector{Bool}} = nothing,
)
    mark_degenerate_groups!(data, degeneracy_threshold)
    projector_fill_projectors_from_groups!(data, band_num; active_bands)
end

"""
Build shifted-point projectors using the central point's degeneracy partition.

`deg_index`, `deg_start`, and `deg_stop` are copied from the central k point so
finite differences compare the same band subspaces at every offset. Projectors
use the Hamiltonian-gauge eigenvectors already stored in `data.spectrum`; no
additional diagonalization, gauge rotation, or normalization is introduced.
"""
function projector_projectors!(
    data::ProjectorMatrixData,
    band_num::Int64,
    deg_index::Array{Float64, 1},
    deg_start::Array{Int64, 1},
    deg_stop::Array{Int64, 1},
    ;
    active_bands::Union{Nothing, AbstractVector{Bool}} = nothing,
)
    data.degeneracy_weights .= deg_index
    data.degeneracy_group_starts .= deg_start
    data.degeneracy_group_stops .= deg_stop
    projector_fill_projectors_from_groups!(data, band_num; active_bands)
end

# Populate contiguous energy-degeneracy group bounds, projectors and normalized group weights for the current spectrum.
function mark_degenerate_groups!(data::ProjectorMatrixData, degeneracy_threshold::Float64)
    num_orbitals = data.num_orbitals
    band = 1
    while band <= num_orbitals
        group_start = band
        while band < num_orbitals &&
            (data.spectrum.energies[band + 1] - data.spectrum.energies[band]) < degeneracy_threshold
            band += 1
        end
        group_stop = band
        group_size = group_stop - group_start + 1
        group_weight = 1.0 / group_size
        for ib in group_start:group_stop
            data.degeneracy_weights[ib] = group_weight
            data.degeneracy_group_starts[ib] = group_start
            data.degeneracy_group_stops[ib] = group_stop
        end
        band = group_stop + 1
    end
    return data
end

"""
Fill `data.projectors` from the precomputed degeneracy groups.

Each group stores `sum_n |u_n><u_n|` in every member slot. The first two matrix
indices are Wannier-basis row and column indices; the leading index labels the
band/group slot. Inactive groups are left untouched for caller-managed scratch
reuse, and no response normalization is applied here.
"""
function projector_fill_projectors_from_groups!(
    data::ProjectorMatrixData,
    band_num::Int64;
    active_bands::Union{Nothing, AbstractVector{Bool}} = nothing,
)
    band = 1
    while band <= band_num
        group_start = data.degeneracy_group_starts[band]
        group_stop = data.degeneracy_group_stops[band]
        group_active = active_bands === nothing || any(@view active_bands[group_start:group_stop])
        if group_active
            projector_temporary = @view data.projectors[group_start, :, :]
            fill!(projector_temporary, COMPLEX_ZERO)
            @inbounds for ib in group_start:group_stop
                for col in 1:band_num
                    eigenvector_conjugate = conj(data.spectrum.eigenvectors[col, ib])
                    for row in 1:band_num
                        projector_temporary[row, col] +=
                            data.spectrum.eigenvectors[row, ib] * eigenvector_conjugate
                    end
                end
            end
            for ib in group_start:group_stop
                ib == group_start && continue
                @views data.projectors[ib, :, :] .= projector_temporary
            end
        end
        band = group_stop + 1
    end
    return data
end

"""
Compute the first and diagonal second covariant derivatives of band projectors.

The central differences are `partial_a P = (P(+a)-P(-a))/(2*dk)` and
`partial_a^2 P = (P(+a)+P(-a)-2P)/dk^2`. Commutators with the native Wannier
connection convert these to covariant derivatives in the selected convention. The derivative direction is the
last index `a`; results overwrite the corresponding caller-owned slices without
changing band weights, gauge, prefactors, or k-point normalization.
"""
function projector_diff_projectors!(
    data::ProjectorMatrixData,
    forward_projectors::AbstractArray{ComplexF64, 3},
    backward_projectors::AbstractArray{ComplexF64, 3},
    finite_difference_step::Float64,
    band_num::Int64,
    a::Int64,
    ;
    active_bands::Union{Nothing, AbstractVector{Bool}} = nothing,
)
    for band in 1:band_num
        active_bands !== nothing && !active_bands[band] && continue
        data.projector_derivatives[band, :, :, a] .=
            (forward_projectors[band, :, :] - backward_projectors[band, :, :]) /
            (2 * finite_difference_step) -
            im * data.effective_connection[:, :, a] * data.projectors[band, :, :] +
            im * data.projectors[band, :, :] * data.effective_connection[:, :, a]
        puredp =
            (forward_projectors[band, :, :] - backward_projectors[band, :, :]) /
            (2 * finite_difference_step)
        data.projector_second_derivatives[band, :, :, a, a] .= (
            (
                forward_projectors[band, :, :] + backward_projectors[band, :, :] -
                2 * data.projectors[band, :, :]
            ) / (finite_difference_step^2) -
            2im * (
                data.effective_connection[:, :, a] * puredp[:, :] -
                puredp[:, :] * data.effective_connection[:, :, a]
            ) -
            im * (
                data.effective_connection_derivatives[:, :, a, a] * data.projectors[band, :, :] -
                data.projectors[band, :, :] * data.effective_connection_derivatives[:, :, a, a]
            ) + (
                2 *
                data.effective_connection[:, :, a] *
                data.projectors[band, :, :] *
                data.effective_connection[:, :, a] -
                data.effective_connection[:, :, a] *
                data.effective_connection[:, :, a] *
                data.projectors[band, :, :] -
                data.projectors[band, :, :] *
                data.effective_connection[:, :, a] *
                data.effective_connection[:, :, a]
            ) - (
                data.external_geometry[:, :, a, a] * data.projectors[band, :, :] +
                data.projectors[band, :, :] * data.external_geometry[:, :, a, a]
            )
        )
    end
end

"""
Store the uncorrected central first derivative of each active projector.

For direction `a`, this writes `(P(+a)-P(-a))/(2*dk)` into
`pure_projector_derivatives[:, :, :, a]`. This scratch is intentionally separate
from the covariant derivative because the mixed second-derivative formula uses
the pure finite difference inside its connection commutators.
"""
function projector_pure_diff_projectors!(
    forward_projectors::AbstractArray{ComplexF64, 3},
    backward_projectors::AbstractArray{ComplexF64, 3},
    finite_difference_step::Float64,
    band_num::Int64,
    a::Int64,
    pure_projector_derivatives::Array{ComplexF64, 4},
    ;
    active_bands::Union{Nothing, AbstractVector{Bool}} = nothing,
)
    for band in 1:band_num
        active_bands !== nothing && !active_bands[band] && continue
        pure_projector_derivatives[band, :, :, a] .=
            (
                forward_projectors[band, :, :] - backward_projectors[band, :, :]
            )/(2*finite_difference_step)
    end
end

"""
Compute the symmetric mixed second derivative of each active band projector.

Directions `a` and `b` use the actual six-point central stencil together
with the pure first derivatives. Native connection commutators and quadratic
connection terms produce the covariant derivative in the selected convention.
The same matrix is written to tensor slots `(a,b)` and `(b,a)`; offset order,
factor `1/(2*dk^2)`, Hamiltonian gauge, and caller-owned workspace layout are
preserved exactly. Physical response prefactors are not applied here.
"""
function projector_second_diff_projectors!(
    data::ProjectorMatrixData,
    forward_projectors::AbstractArray{ComplexF64, 4},
    backward_projectors::AbstractArray{ComplexF64, 4},
    second_forward_projectors::AbstractArray{ComplexF64, 3},
    second_backward_projectors::AbstractArray{ComplexF64, 3},
    finite_difference_step::Float64,
    band_num::Int64,
    a::Int64,
    b::Int64,
    pure_projector_derivatives::Array{ComplexF64, 4},
    ;
    active_bands::Union{Nothing, AbstractVector{Bool}} = nothing,
)
    for band in 1:band_num
        active_bands !== nothing && !active_bands[band] && continue
        data.projector_second_derivatives[band, :, :, a, b] .= (
            (
                second_forward_projectors[band, :, :] +
                second_backward_projectors[band, :, :] +
                2*data.projectors[band, :, :] - forward_projectors[band, :, :, a] -
                forward_projectors[band, :, :, b] - backward_projectors[band, :, :, a] -
                backward_projectors[band, :, :, b]
            )/(2*finite_difference_step^2) -
            im * (
                data.effective_connection[:, :, a] * pure_projector_derivatives[band, :, :, b] +
                data.effective_connection[:, :, b] * pure_projector_derivatives[band, :, :, a] -
                pure_projector_derivatives[band, :, :, a] * data.effective_connection[:, :, b] -
                pure_projector_derivatives[band, :, :, b] * data.effective_connection[:, :, a]
            ) -
            0.5im * (
                (
                    data.effective_connection_derivatives[:, :, b, a] +
                    data.effective_connection_derivatives[:, :, a, b]
                ) * data.projectors[band, :, :] -
                data.projectors[band, :, :] * (
                    data.effective_connection_derivatives[:, :, b, a] +
                    data.effective_connection_derivatives[:, :, a, b]
                )
            ) + (
                data.effective_connection[:, :, a] *
                data.projectors[band, :, :] *
                data.effective_connection[:, :, b] +
                data.effective_connection[:, :, b] *
                data.projectors[band, :, :] *
                data.effective_connection[:, :, a] -
                0.5 * (
                    (
                        data.effective_connection[:, :, a] * data.effective_connection[:, :, b] +
                        data.effective_connection[:, :, b] * data.effective_connection[:, :, a]
                    ) * data.projectors[band, :, :] +
                    data.projectors[band, :, :] * (
                        data.effective_connection[:, :, a] * data.effective_connection[:, :, b] +
                        data.effective_connection[:, :, b] * data.effective_connection[:, :, a]
                    )
                )
            ) -
            0.5 * (
                (data.external_geometry[:, :, a, b] + data.external_geometry[:, :, b, a]) *
                data.projectors[band, :, :] +
                data.projectors[band, :, :] *
                (data.external_geometry[:, :, a, b] + data.external_geometry[:, :, b, a])
            )
        )
        data.projector_second_derivatives[band, :, :, b, a] .=
            data.projector_second_derivatives[band, :, :, a, b]
    end
end
