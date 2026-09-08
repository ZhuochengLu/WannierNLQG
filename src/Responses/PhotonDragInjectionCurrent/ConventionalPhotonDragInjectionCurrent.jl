# Conventional photon-drag injection-current response.

const _PHOTON_DRAG_INJECTION_CURRENT_MATRIX_STRATEGIES = (:auto, :scalar, :blas)
const _PHOTON_DRAG_INJECTION_CURRENT_BLAS_AUTO_MIN_ORBITALS_WITH_EXPLICIT_CENTER_PHASE = 16
const _PHOTON_DRAG_INJECTION_CURRENT_BLAS_AUTO_MIN_ORBITALS_WITHOUT_EXPLICIT_CENTER_PHASE = 64

# Choose scalar or BLAS matrix assembly from the explicit strategy, calibrated orbital/window shape and available scratch; reject invalid forced choices.
@inline function _select_photon_drag_injection_current_matrix_strategy(
    requested_strategy::Symbol,
    num_orbitals::Int,
    explicit_center_phase_enabled::Bool,
    full_band_window::Bool,
    active_pairs_nmajor,
    tensor_indices,
    matrix_scratch_1,
    matrix_scratch_2,
)
    requested_strategy in _PHOTON_DRAG_INJECTION_CURRENT_MATRIX_STRATEGIES || throw(
        ArgumentError(
            "Unsupported PDIC matrix strategy=$(requested_strategy); expected one of $(_PHOTON_DRAG_INJECTION_CURRENT_MATRIX_STRATEGIES).",
        ),
    )
    requested_strategy === :scalar && return :scalar
    if requested_strategy === :blas
        matrix_scratch_1 === nothing &&
            throw(ArgumentError("PDIC BLAS strategy requires matrix_scratch_1."))
        matrix_scratch_2 === nothing &&
            throw(ArgumentError("PDIC BLAS strategy requires matrix_scratch_2."))
        return :blas
    end
    calibrated_shape = if explicit_center_phase_enabled
        num_orbitals >= 64 || (
            num_orbitals >=
            _PHOTON_DRAG_INJECTION_CURRENT_BLAS_AUTO_MIN_ORBITALS_WITH_EXPLICIT_CENTER_PHASE &&
            full_band_window
        )
    else
        num_orbitals >=
        _PHOTON_DRAG_INJECTION_CURRENT_BLAS_AUTO_MIN_ORBITALS_WITHOUT_EXPLICIT_CENTER_PHASE &&
            full_band_window
    end
    return calibrated_shape &&
           active_pairs_nmajor === nothing &&
           tensor_indices === nothing &&
           matrix_scratch_1 !== nothing &&
           matrix_scratch_2 !== nothing ? :blas : :scalar
end

"""
Return separate inclusive band windows around the Fermi level for valence/conduction momentum legs and an availability flag.

Sorted energies and Fermi level use eV. `-1` selects all bands; invalid nonpositive sizes raise an error and absent Fermi boundaries yield empty windows.
"""
function photon_drag_band_windows(
    valence_energies::AbstractVector{<:Real},
    conduction_energies::AbstractVector{<:Real},
    fermi_energy::Real,
    band_window_size::Integer,
    num_orbitals::Integer,
)
    if band_window_size == -1 || 2 * band_window_size > num_orbitals
        return 1, num_orbitals, 1, num_orbitals, true
    elseif band_window_size <= 0
        error(
            "Invalid band_window_size=$(band_window_size); use a positive value or -1 for all bands.",
        )
    end

    valence_fermi_index = searchsortedlast(valence_energies, fermi_energy)
    conduction_fermi_index = searchsortedlast(conduction_energies, fermi_energy)
    if valence_fermi_index < 1 ||
       valence_fermi_index >= num_orbitals ||
       conduction_fermi_index < 1 ||
       conduction_fermi_index >= num_orbitals
        return 1, 0, 1, 0, false
    end

    valence_band_start = max(1, valence_fermi_index - band_window_size + 1)
    valence_band_end = min(num_orbitals, valence_fermi_index + band_window_size)
    conduction_band_start = max(1, conduction_fermi_index - band_window_size + 1)
    conduction_band_end = min(num_orbitals, conduction_fermi_index + band_window_size)
    return (valence_band_start, valence_band_end, conduction_band_start, conduction_band_end, true)
end

"""
Test energy-window overlap for transitions between distinct valence/conduction momentum legs.

Require occupation differences above `1e-10`; use conduction minus valence energy and the same eV unit as photon energies and broadening. A nonpositive threshold disables energy screening; scalar/vector photon inputs share this policy.
"""
function photon_drag_has_active_transition(
    valence_energies::AbstractVector{<:Real},
    conduction_energies::AbstractVector{<:Real},
    valence_occupations::AbstractVector{<:Real},
    conduction_occupations::AbstractVector{<:Real},
    photon_energies,
    broadening::Real,
    transition_window_factor::Real,
    valence_band_start::Integer,
    valence_band_end::Integer,
    conduction_band_start::Integer,
    conduction_band_end::Integer,
)
    threshold = transition_window_factor * broadening
    @inbounds for n in valence_band_start:valence_band_end
        for m in conduction_band_start:conduction_band_end
            occupation_differences = valence_occupations[n] - conduction_occupations[m]
            if abs(occupation_differences) <= 1.0e-10
                continue
            end
            transition_energy = conduction_energies[m] - valence_energies[n]
            if threshold <= 0
                return true
            end
            for photon_energy in photon_energies
                if abs(transition_energy - photon_energy) < threshold
                    return true
                end
            end
        end
    end
    return false
end

# Test energy-window overlap for transitions between distinct valence/conduction momentum legs.
#
# Require occupation differences above `1e-10`; use conduction minus valence energy and the same eV unit as photon energies and broadening. A nonpositive threshold disables energy screening; scalar/vector photon inputs share this policy.
function photon_drag_has_active_transition(
    valence_energies::AbstractVector{<:Real},
    conduction_energies::AbstractVector{<:Real},
    valence_occupations::AbstractVector{<:Real},
    conduction_occupations::AbstractVector{<:Real},
    photon_energy::Real,
    broadening::Real,
    transition_window_factor::Real,
    valence_band_start::Integer,
    valence_band_end::Integer,
    conduction_band_start::Integer,
    conduction_band_end::Integer,
)
    threshold = transition_window_factor * broadening
    @inbounds for n in valence_band_start:valence_band_end
        for m in conduction_band_start:conduction_band_end
            occupation_differences = valence_occupations[n] - conduction_occupations[m]
            if abs(occupation_differences) <= 1.0e-10
                continue
            end
            transition_energy = conduction_energies[m] - valence_energies[n]
            if threshold <= 0 || abs(transition_energy - photon_energy) < threshold
                return true
            end
        end
    end
    return false
end

"""
Fill cross-momentum valence/conduction eigenvector overlaps in caller-owned storage.

Preserve native source-gauge and optional Wannier-center phases; the overlap is dimensionless and carries no response prefactor.
"""
function photon_drag_compute_overlaps!(
    overlap_1::Matrix{ComplexF64},
    overlap_2::Matrix{ComplexF64},
    valence_data::KPointMatrixData,
    conduction_data::KPointMatrixData,
    valence_kpoint::Vector{Float64},
    conduction_kpoint::Vector{Float64},
    wannier_centers_fractional::Matrix{Float64},
    explicit_center_phase_enabled::Bool,
    num_orbitals::Int64,
)
    fill!(overlap_1, COMPLEX_ZERO)
    fill!(overlap_2, COMPLEX_ZERO)
    valence_to_conduction_delta_k = valence_kpoint .- conduction_kpoint
    conduction_to_valence_delta_k = conduction_kpoint .- valence_kpoint
    @inbounds for n in 1:num_orbitals
        for m in 1:num_orbitals
            valence_to_conduction_overlap = COMPLEX_ZERO
            conduction_to_valence_overlap = COMPLEX_ZERO
            for l in 1:num_orbitals
                if explicit_center_phase_enabled
                    phase12 =
                        valence_to_conduction_delta_k[1] * wannier_centers_fractional[1, l] +
                        valence_to_conduction_delta_k[2] * wannier_centers_fractional[2, l] +
                        valence_to_conduction_delta_k[3] * wannier_centers_fractional[3, l]
                    phase21 =
                        conduction_to_valence_delta_k[1] * wannier_centers_fractional[1, l] +
                        conduction_to_valence_delta_k[2] * wannier_centers_fractional[2, l] +
                        conduction_to_valence_delta_k[3] * wannier_centers_fractional[3, l]
                    valence_to_conduction_overlap +=
                        cis(2.0 * pi * phase12) *
                        valence_data.spectrum.source_eigenvectors_adjoint[n, l] *
                        conduction_data.spectrum.source_eigenvectors[l, m]
                    conduction_to_valence_overlap +=
                        cis(2.0 * pi * phase21) *
                        conduction_data.spectrum.source_eigenvectors_adjoint[n, l] *
                        valence_data.spectrum.source_eigenvectors[l, m]
                else
                    valence_to_conduction_overlap +=
                        valence_data.spectrum.source_eigenvectors_adjoint[n, l] *
                        conduction_data.spectrum.source_eigenvectors[l, m]
                    conduction_to_valence_overlap +=
                        conduction_data.spectrum.source_eigenvectors_adjoint[n, l] *
                        valence_data.spectrum.source_eigenvectors[l, m]
                end
            end
            overlap_1[n, m] = valence_to_conduction_overlap
            overlap_2[n, m] = conduction_to_valence_overlap
        end
    end
    return nothing
end

# Form cross-momentum eigenvector overlaps by BLAS, using provided center-phase and matrix scratch buffers.
function _photon_drag_compute_overlaps_blas!(
    overlap_1::Matrix{ComplexF64},
    overlap_2::Matrix{ComplexF64},
    matrix_scratch_1::Matrix{ComplexF64},
    matrix_scratch_2::Matrix{ComplexF64},
    valence_data::KPointMatrixData,
    conduction_data::KPointMatrixData,
    valence_kpoint::Vector{Float64},
    conduction_kpoint::Vector{Float64},
    wannier_centers_fractional::Matrix{Float64},
    explicit_center_phase_enabled::Bool,
    num_orbitals::Int64,
)
    valence_eigenvectors = valence_data.spectrum.source_eigenvectors
    valence_eigenvectors_adjoint = valence_data.spectrum.source_eigenvectors_adjoint
    conduction_eigenvectors = conduction_data.spectrum.source_eigenvectors
    conduction_eigenvectors_adjoint = conduction_data.spectrum.source_eigenvectors_adjoint
    if explicit_center_phase_enabled
        delta_12_1 = valence_kpoint[1] - conduction_kpoint[1]
        delta_12_2 = valence_kpoint[2] - conduction_kpoint[2]
        delta_12_3 = valence_kpoint[3] - conduction_kpoint[3]
        delta_21_1 = conduction_kpoint[1] - valence_kpoint[1]
        delta_21_2 = conduction_kpoint[2] - valence_kpoint[2]
        delta_21_3 = conduction_kpoint[3] - valence_kpoint[3]
        @inbounds for column in 1:num_orbitals
            for row in 1:num_orbitals
                phase_12 =
                    delta_12_1 * wannier_centers_fractional[1, row] +
                    delta_12_2 * wannier_centers_fractional[2, row] +
                    delta_12_3 * wannier_centers_fractional[3, row]
                phase_21 =
                    delta_21_1 * wannier_centers_fractional[1, row] +
                    delta_21_2 * wannier_centers_fractional[2, row] +
                    delta_21_3 * wannier_centers_fractional[3, row]
                matrix_scratch_1[row, column] =
                    cis(2.0 * pi * phase_12) * conduction_eigenvectors[row, column]
                matrix_scratch_2[row, column] =
                    cis(2.0 * pi * phase_21) * valence_eigenvectors[row, column]
            end
        end
        mul!(overlap_1, valence_eigenvectors_adjoint, matrix_scratch_1)
        mul!(overlap_2, conduction_eigenvectors_adjoint, matrix_scratch_2)
    else
        mul!(overlap_1, valence_eigenvectors_adjoint, conduction_eigenvectors)
        mul!(overlap_2, conduction_eigenvectors_adjoint, valence_eigenvectors)
    end
    return nothing
end

# Build cross-momentum velocity insertions with matrix products, retaining the valence/conduction leg ordering and supplied scratch.
function _photon_drag_compute_velocity_vertices_blas!(
    forward_velocity_vertex::Array{ComplexF64, 3},
    backward_velocity_vertex::Array{ComplexF64, 3},
    matrix_scratch_1::Matrix{ComplexF64},
    matrix_scratch_2::Matrix{ComplexF64},
    overlap_1::Matrix{ComplexF64},
    overlap_2::Matrix{ComplexF64},
    valence_data::KPointMatrixData,
    conduction_data::KPointMatrixData,
    spatial_dimension::Int64,
    tensor_indices,
)
    forward_axes =
        tensor_indices === nothing ? (1:spatial_dimension) : (tensor_indices[3]:tensor_indices[3])
    backward_axes =
        tensor_indices === nothing ? (1:spatial_dimension) : (tensor_indices[2]:tensor_indices[2])
    @views for axis in forward_axes
        forward_vertex = forward_velocity_vertex[:, :, axis]
        valence_velocity = valence_data.source_gauge_velocity_vertices[:, :, axis]
        conduction_velocity = conduction_data.source_gauge_velocity_vertices[:, :, axis]
        mul!(forward_vertex, valence_velocity, overlap_1)
        mul!(matrix_scratch_1, overlap_1, conduction_velocity)
        @. forward_vertex = 0.5 * (forward_vertex + matrix_scratch_1)
    end
    @views for axis in backward_axes
        backward_vertex = backward_velocity_vertex[:, :, axis]
        valence_velocity = valence_data.source_gauge_velocity_vertices[:, :, axis]
        conduction_velocity = conduction_data.source_gauge_velocity_vertices[:, :, axis]
        mul!(backward_vertex, conduction_velocity, overlap_2)
        mul!(matrix_scratch_2, overlap_2, valence_velocity)
        @. backward_vertex = 0.5 * (backward_vertex + matrix_scratch_2)
    end
    return nothing
end

"""
This finite-q kernel connects valence states at `k-q/2` to conduction states at
`k+q/2`. It builds source-gauge overlap-dressed forward/backward velocity
vertices and stores their optical contraction at `[n,m,a,b,c]`. The typed
convention cold path determines whether this finite-q Conventional kernel needs
an explicit Wannier-center link phase; this does not change slot ownership or
introduce a second eigensystem. Matrix strategy selection is a
scratch/layout choice only. Runtime owns occupations, broadening, physical
prefactors, k-point normalization, and deterministic reduction. Runtime reports
one ordered-field injection-rate contribution; the conjugate-frequency/momentum
outer factor `2` and steady-state `tau` conversion are external to this kernel.
"""
function compute_photon_drag_injection_current_kernel!(
    response_kernel::Array{ComplexF64, 5},
    forward_velocity_vertex::Array{ComplexF64, 3},
    backward_velocity_vertex::Array{ComplexF64, 3},
    overlap_1::Matrix{ComplexF64},
    overlap_2::Matrix{ComplexF64},
    valence_data::KPointMatrixData,
    conduction_data::KPointMatrixData,
    valence_kpoint::Vector{Float64},
    conduction_kpoint::Vector{Float64},
    wannier_centers_fractional::Matrix{Float64},
    explicit_center_phase_enabled::Bool,
    valence_band_start::Int64,
    valence_band_end::Int64,
    conduction_band_start::Int64,
    conduction_band_end::Int64,
    num_orbitals::Int64,
    spatial_dimension::Int64,
    ;
    active_pair_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
    active_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
    _matrix_scratch_1::Union{Nothing, Matrix{ComplexF64}} = nothing,
    _matrix_scratch_2::Union{Nothing, Matrix{ComplexF64}} = nothing,
    _pdic_matrix_strategy::Symbol = :auto,
)
    _clear_response_kernel!(response_kernel, tensor_indices)
    if tensor_indices === nothing
        fill!(forward_velocity_vertex, COMPLEX_ZERO)
        fill!(backward_velocity_vertex, COMPLEX_ZERO)
    else
        _, b, c = tensor_indices
        fill!(@view(forward_velocity_vertex[:, :, c]), COMPLEX_ZERO)
        fill!(@view(backward_velocity_vertex[:, :, b]), COMPLEX_ZERO)
    end

    matrix_strategy = _select_photon_drag_injection_current_matrix_strategy(
        _pdic_matrix_strategy,
        num_orbitals,
        explicit_center_phase_enabled,
        valence_band_start == 1 &&
        valence_band_end == num_orbitals &&
        conduction_band_start == 1 &&
        conduction_band_end == num_orbitals,
        active_pairs_nmajor,
        tensor_indices,
        _matrix_scratch_1,
        _matrix_scratch_2,
    )
    if matrix_strategy === :blas
        _photon_drag_compute_overlaps_blas!(
            overlap_1,
            overlap_2,
            _matrix_scratch_1,
            _matrix_scratch_2,
            valence_data,
            conduction_data,
            valence_kpoint,
            conduction_kpoint,
            wannier_centers_fractional,
            explicit_center_phase_enabled,
            num_orbitals,
        )
        _photon_drag_compute_velocity_vertices_blas!(
            forward_velocity_vertex,
            backward_velocity_vertex,
            _matrix_scratch_1,
            _matrix_scratch_2,
            overlap_1,
            overlap_2,
            valence_data,
            conduction_data,
            spatial_dimension,
            tensor_indices,
        )
        if active_pairs_nmajor !== nothing
            pair_count = _compact_injection_pair_count(active_pairs_nmajor, active_pair_count)
            if tensor_indices === nothing
                @inbounds for pair_index in 1:pair_count
                    n, m = active_pairs_nmajor[pair_index]
                    for a in 1:spatial_dimension
                        velocity_diff =
                            conduction_data.source_gauge_hamiltonian_derivatives[m, m, a] -
                            valence_data.source_gauge_hamiltonian_derivatives[n, n, a]
                        for b in 1:spatial_dimension
                            for c in 1:spatial_dimension
                                response_kernel[n, m, a, b, c] =
                                    velocity_diff *
                                    forward_velocity_vertex[n, m, c] *
                                    backward_velocity_vertex[m, n, b]
                            end
                        end
                    end
                end
            else
                a, b, c = tensor_indices
                @inbounds for pair_index in 1:pair_count
                    n, m = active_pairs_nmajor[pair_index]
                    velocity_diff =
                        conduction_data.source_gauge_hamiltonian_derivatives[m, m, a] -
                        valence_data.source_gauge_hamiltonian_derivatives[n, n, a]
                    response_kernel[n, m, a, b, c] =
                        velocity_diff *
                        forward_velocity_vertex[n, m, c] *
                        backward_velocity_vertex[m, n, b]
                end
            end
        elseif tensor_indices === nothing
            @inbounds for n in valence_band_start:valence_band_end
                for m in conduction_band_start:conduction_band_end
                    active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                    for a in 1:spatial_dimension
                        velocity_diff =
                            conduction_data.source_gauge_hamiltonian_derivatives[m, m, a] -
                            valence_data.source_gauge_hamiltonian_derivatives[n, n, a]
                        for b in 1:spatial_dimension
                            for c in 1:spatial_dimension
                                response_kernel[n, m, a, b, c] =
                                    velocity_diff *
                                    forward_velocity_vertex[n, m, c] *
                                    backward_velocity_vertex[m, n, b]
                            end
                        end
                    end
                end
            end
        else
            a, b, c = tensor_indices
            @inbounds for n in valence_band_start:valence_band_end
                for m in conduction_band_start:conduction_band_end
                    active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                    velocity_diff =
                        conduction_data.source_gauge_hamiltonian_derivatives[m, m, a] -
                        valence_data.source_gauge_hamiltonian_derivatives[n, n, a]
                    response_kernel[n, m, a, b, c] =
                        velocity_diff *
                        forward_velocity_vertex[n, m, c] *
                        backward_velocity_vertex[m, n, b]
                end
            end
        end
        return response_kernel
    end

    photon_drag_compute_overlaps!(
        overlap_1,
        overlap_2,
        valence_data,
        conduction_data,
        valence_kpoint,
        conduction_kpoint,
        wannier_centers_fractional,
        explicit_center_phase_enabled,
        num_orbitals,
    )

    if active_pairs_nmajor !== nothing
        pair_count = _compact_injection_pair_count(active_pairs_nmajor, active_pair_count)
        if tensor_indices === nothing
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                for a in 1:spatial_dimension
                    forward_velocity_sum = COMPLEX_ZERO
                    backward_velocity_sum = COMPLEX_ZERO
                    for l in 1:num_orbitals
                        forward_velocity_sum +=
                            valence_data.source_gauge_velocity_vertices[n, l, a] * overlap_1[l, m] +
                            overlap_1[n, l] *
                            conduction_data.source_gauge_velocity_vertices[l, m, a]
                        backward_velocity_sum +=
                            conduction_data.source_gauge_velocity_vertices[m, l, a] *
                            overlap_2[l, n] +
                            overlap_2[m, l] * valence_data.source_gauge_velocity_vertices[l, n, a]
                    end
                    forward_velocity_vertex[n, m, a] = 0.5 * forward_velocity_sum
                    backward_velocity_vertex[m, n, a] = 0.5 * backward_velocity_sum
                end
            end
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                for a in 1:spatial_dimension
                    velocity_diff =
                        conduction_data.source_gauge_hamiltonian_derivatives[m, m, a] -
                        valence_data.source_gauge_hamiltonian_derivatives[n, n, a]
                    for b in 1:spatial_dimension
                        for c in 1:spatial_dimension
                            response_kernel[n, m, a, b, c] =
                                velocity_diff *
                                forward_velocity_vertex[n, m, c] *
                                backward_velocity_vertex[m, n, b]
                        end
                    end
                end
            end
        else
            a, b, c = tensor_indices
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                forward_velocity_sum = COMPLEX_ZERO
                backward_velocity_sum = COMPLEX_ZERO
                for l in 1:num_orbitals
                    forward_velocity_sum +=
                        valence_data.source_gauge_velocity_vertices[n, l, c] * overlap_1[l, m] +
                        overlap_1[n, l] * conduction_data.source_gauge_velocity_vertices[l, m, c]
                    backward_velocity_sum +=
                        conduction_data.source_gauge_velocity_vertices[m, l, b] * overlap_2[l, n] +
                        overlap_2[m, l] * valence_data.source_gauge_velocity_vertices[l, n, b]
                end
                forward_velocity_vertex[n, m, c] = 0.5 * forward_velocity_sum
                backward_velocity_vertex[m, n, b] = 0.5 * backward_velocity_sum
                velocity_diff =
                    conduction_data.source_gauge_hamiltonian_derivatives[m, m, a] -
                    valence_data.source_gauge_hamiltonian_derivatives[n, n, a]
                response_kernel[n, m, a, b, c] =
                    velocity_diff *
                    forward_velocity_vertex[n, m, c] *
                    backward_velocity_vertex[m, n, b]
            end
        end
        return response_kernel
    end

    if tensor_indices === nothing
        @inbounds for n in valence_band_start:valence_band_end
            for m in conduction_band_start:conduction_band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                for a in 1:spatial_dimension
                    forward_velocity_sum = COMPLEX_ZERO
                    backward_velocity_sum = COMPLEX_ZERO
                    for l in 1:num_orbitals
                        forward_velocity_sum +=
                            valence_data.source_gauge_velocity_vertices[n, l, a] * overlap_1[l, m] +
                            overlap_1[n, l] *
                            conduction_data.source_gauge_velocity_vertices[l, m, a]
                        backward_velocity_sum +=
                            conduction_data.source_gauge_velocity_vertices[m, l, a] *
                            overlap_2[l, n] +
                            overlap_2[m, l] * valence_data.source_gauge_velocity_vertices[l, n, a]
                    end
                    forward_velocity_vertex[n, m, a] = 0.5 * forward_velocity_sum
                    backward_velocity_vertex[m, n, a] = 0.5 * backward_velocity_sum
                end
            end
        end

        @inbounds for n in valence_band_start:valence_band_end
            for m in conduction_band_start:conduction_band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                for a in 1:spatial_dimension
                    velocity_diff =
                        conduction_data.source_gauge_hamiltonian_derivatives[m, m, a] -
                        valence_data.source_gauge_hamiltonian_derivatives[n, n, a]
                    for b in 1:spatial_dimension
                        for c in 1:spatial_dimension
                            response_kernel[n, m, a, b, c] =
                                velocity_diff *
                                forward_velocity_vertex[n, m, c] *
                                backward_velocity_vertex[m, n, b]
                        end
                    end
                end
            end
        end
    else
        a, b, c = tensor_indices
        @inbounds for n in valence_band_start:valence_band_end
            for m in conduction_band_start:conduction_band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                forward_velocity_sum = COMPLEX_ZERO
                backward_velocity_sum = COMPLEX_ZERO
                for l in 1:num_orbitals
                    forward_velocity_sum +=
                        valence_data.source_gauge_velocity_vertices[n, l, c] * overlap_1[l, m] +
                        overlap_1[n, l] * conduction_data.source_gauge_velocity_vertices[l, m, c]
                    backward_velocity_sum +=
                        conduction_data.source_gauge_velocity_vertices[m, l, b] * overlap_2[l, n] +
                        overlap_2[m, l] * valence_data.source_gauge_velocity_vertices[l, n, b]
                end
                forward_velocity_vertex[n, m, c] = 0.5 * forward_velocity_sum
                backward_velocity_vertex[m, n, b] = 0.5 * backward_velocity_sum
                velocity_diff =
                    conduction_data.source_gauge_hamiltonian_derivatives[m, m, a] -
                    valence_data.source_gauge_hamiltonian_derivatives[n, n, a]
                response_kernel[n, m, a, b, c] =
                    velocity_diff *
                    forward_velocity_vertex[n, m, c] *
                    backward_velocity_vertex[m, n, b]
            end
        end
    end

    return response_kernel
end

"""
The passed prefactor produces
one ordered-field injection-rate contribution; it does not include the conjugate
frequency/momentum outer factor `2` or the steady-state `tau`.
"""
function accumulate_photon_drag_injection_current_response!(
    local_response::Array{ComplexF64, 4},
    response_kernel::Array{ComplexF64, 5},
    occupation_differences::Matrix{Float64},
    delta::Array{Float64, 3},
    frequency_denominator_weights::Vector{Float64},
    prefactor,
    valence_band_start::Int64,
    valence_band_end::Int64,
    conduction_band_start::Int64,
    conduction_band_end::Int64,
    spatial_dimension::Int64,
    ;
    active_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
    frequency_weight_scratch::Union{Nothing, AbstractVector{Float64}} = nothing,
    _frequency_contraction_scratch::Union{Nothing, _FrequencyContractionScratch} = nothing,
)
    num_photon_energies = size(delta, 1)
    use_frequency_scratch =
        _use_injection_frequency_scratch(frequency_weight_scratch, num_photon_energies)
    if active_pairs_nmajor !== nothing
        pair_count = _compact_injection_pair_count(active_pairs_nmajor, active_pair_count)
        if use_frequency_scratch
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                for energy_index in 1:num_photon_energies
                    frequency_denominator_weight = frequency_denominator_weights[energy_index]
                    frequency_weight_scratch[energy_index] =
                        occupation_differences[n, m] *
                        delta[energy_index, n, m] *
                        frequency_denominator_weight
                end
                for c in 1:spatial_dimension
                    for b in 1:spatial_dimension
                        for a in 1:spatial_dimension
                            kernel = response_kernel[n, m, a, b, c]
                            for energy_index in 1:num_photon_energies
                                weight = frequency_weight_scratch[energy_index]
                                if weight != 0.0
                                    cweight = prefactor * weight
                                    local_response[energy_index, a, b, c] += cweight * kernel
                                end
                            end
                        end
                    end
                end
            end
        else
            @inbounds for energy_index in 1:num_photon_energies
                frequency_denominator_weight = frequency_denominator_weights[energy_index]
                for pair_index in 1:pair_count
                    n, m = active_pairs_nmajor[pair_index]
                    weight =
                        occupation_differences[n, m] *
                        delta[energy_index, n, m] *
                        frequency_denominator_weight
                    if weight == 0.0
                        continue
                    end
                    cweight = prefactor * weight
                    for c in 1:spatial_dimension
                        for b in 1:spatial_dimension
                            for a in 1:spatial_dimension
                                local_response[energy_index, a, b, c] +=
                                    cweight * response_kernel[n, m, a, b, c]
                            end
                        end
                    end
                end
            end
        end
        return local_response
    end
    pair_count =
        (valence_band_end - valence_band_start + 1) *
        (conduction_band_end - conduction_band_start + 1)
    frequency_contraction_strategy = _select_frequency_contraction_strategy(
        num_photon_energies,
        pair_count,
        active_pairs_nmajor,
        _frequency_contraction_scratch,
    )
    if frequency_contraction_strategy !== :scalar
        return _accumulate_frequency_contraction_prototype!(
            local_response,
            response_kernel,
            occupation_differences,
            delta,
            prefactor,
            valence_band_start,
            valence_band_end,
            conduction_band_start,
            conduction_band_end,
            _frequency_contraction_scratch,
            strategy = frequency_contraction_strategy,
            pair_order = :nmajor,
            frequency_weights = frequency_denominator_weights,
        )
    end
    @inbounds for energy_index in 1:num_photon_energies
        frequency_denominator_weight = frequency_denominator_weights[energy_index]
        for n in valence_band_start:valence_band_end
            for m in conduction_band_start:conduction_band_end
                weight =
                    occupation_differences[n, m] *
                    delta[energy_index, n, m] *
                    frequency_denominator_weight
                if weight == 0.0
                    continue
                end
                cweight = prefactor * weight
                for c in 1:spatial_dimension
                    for b in 1:spatial_dimension
                        for a in 1:spatial_dimension
                            local_response[energy_index, a, b, c] +=
                                cweight * response_kernel[n, m, a, b, c]
                        end
                    end
                end
            end
        end
    end
    return local_response
end

"""
The passed prefactor produces
one ordered-field injection-rate contribution; it does not include the conjugate
frequency/momentum outer factor `2` or the steady-state `tau`.
"""
function photon_drag_injection_current_component(
    response_kernel::Array{ComplexF64, 5},
    occupation_differences::AbstractMatrix{Float64},
    delta::AbstractMatrix{Float64},
    frequency_denominator_weight::Float64,
    prefactor,
    tensor_indices::Vector{Int},
    valence_band_start::Int64,
    valence_band_end::Int64,
    conduction_band_start::Int64,
    conduction_band_end::Int64,
    ;
    active_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
)
    a, b, c = tensor_indices
    value = COMPLEX_ZERO
    if active_pairs_nmajor !== nothing
        pair_count = _compact_injection_pair_count(active_pairs_nmajor, active_pair_count)
        @inbounds for pair_index in 1:pair_count
            n, m = active_pairs_nmajor[pair_index]
            weight = occupation_differences[n, m] * delta[n, m] * frequency_denominator_weight
            if weight != 0.0
                value += prefactor * weight * response_kernel[n, m, a, b, c]
            end
        end
        return value
    end
    @inbounds for n in valence_band_start:valence_band_end
        for m in conduction_band_start:conduction_band_end
            weight = occupation_differences[n, m] * delta[n, m] * frequency_denominator_weight
            if weight != 0.0
                value += prefactor * weight * response_kernel[n, m, a, b, c]
            end
        end
    end
    return value
end
