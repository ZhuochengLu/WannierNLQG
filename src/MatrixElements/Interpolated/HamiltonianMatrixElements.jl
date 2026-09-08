"""
Rotate each eigenvector column so its largest-magnitude entry is real and nonnegative; return the same matrix.

Resolve magnitude ties by first occurrence and leave all-zero columns unchanged. This fixes column phases, not mixing within degenerate subspaces.
"""
function canonicalize_eigenvectors!(eigenvectors::Matrix{ComplexF64})
    @inbounds for column in axes(eigenvectors, 2)
        pivot = first(axes(eigenvectors, 1))
        pivot_magnitude = abs(eigenvectors[pivot, column])
        for row in (pivot + 1):last(axes(eigenvectors, 1))
            magnitude = abs(eigenvectors[row, column])
            if magnitude > pivot_magnitude
                pivot = row
                pivot_magnitude = magnitude
            end
        end
        if pivot_magnitude > 0.0
            phase = conj(eigenvectors[pivot, column]) / pivot_magnitude
            for row in axes(eigenvectors, 1)
                eigenvectors[row, column] *= phase
            end
        end
    end
    return eigenvectors
end

# Fill `exp(2pi*i*R.k)/R_degeneracy` for the model's R vectors and fractional reciprocal point.
function _prepare_fourier_factors!(
    fourier_factors::Vector{ComplexF64},
    model::TightBindingModel,
    kpoint::AbstractVector{<:Real},
)
    phases = transpose(model.r_vectors) * kpoint
    @inbounds for r_vector_index in 1:model.num_r_vectors
        fourier_factors[r_vector_index] =
            cis(2.0 * pi * phases[r_vector_index]) / model.r_degeneracies[r_vector_index]
    end
    return fourier_factors
end

# Zero and fill the Wannier-gauge Hamiltonian by summing real-space blocks against the supplied weighted Fourier factors in R order.
function _fourier_hamiltonian!(
    hamiltonian_wannier::Matrix{ComplexF64},
    fourier_factors::Vector{ComplexF64},
    model::TightBindingModel,
)
    fill!(hamiltonian_wannier, COMPLEX_ZERO)
    @inbounds for r_vector_index in 1:model.num_r_vectors
        for orbital_column in 1:model.num_orbitals
            for orbital_row in 1:model.num_orbitals
                hamiltonian_wannier[orbital_row, orbital_column] +=
                    fourier_factors[r_vector_index] *
                    model.hamiltonian_r[orbital_row, orbital_column, r_vector_index]
            end
        end
    end
    return hamiltonian_wannier
end

# Write `U' * input * U` into `output`, using the supplied eigensystem and multiplication scratch; return `output`.
function transform_to_hamiltonian_gauge!(
    output::AbstractMatrix{ComplexF64},
    spectrum::KPointSpectrum,
    input::AbstractMatrix{ComplexF64},
    temporary::AbstractMatrix{ComplexF64},
)
    mul!(temporary, spectrum.eigenvectors_adjoint, input)
    mul!(output, temporary, spectrum.eigenvectors)
    return output
end

# Convert one integer R vector through the model's row-stored lattice into a Cartesian displacement tuple.
function _r_vector_cartesian(model::TightBindingModel, r_vector_index::Int)
    r1 = model.r_vectors[1, r_vector_index]
    r2 = model.r_vectors[2, r_vector_index]
    r3 = model.r_vectors[3, r_vector_index]
    return (
        r1 * model.lattice[1, 1] + r2 * model.lattice[2, 1] + r3 * model.lattice[3, 1],
        r1 * model.lattice[1, 2] + r2 * model.lattice[2, 2] + r3 * model.lattice[3, 2],
        r1 * model.lattice[1, 3] + r2 * model.lattice[2, 3] + r3 * model.lattice[3, 3],
    )
end

"""
Fill required Cartesian Hamiltonian gradient/Hessian R blocks using `i*displacement*H_R` and `-displacement_a*displacement_b*H_R`.

Displacements follow the plan's Wannier-center convention and lattice length unit; mutate only selected compact channels of supplied scratch.

Prepare hamiltonian real space in place.
"""
function prepare_hamiltonian_real_space!(
    scratch::HamiltonianMatrixScratch,
    model::TightBindingModel,
    plan::MatrixElementPlan,
    ;
    scratch_workspace::MatrixElementScratch,
)
    gradient = scratch.gradient_real_space
    hessian = scratch.hessian_real_space
    spatial_dimension = plan.spatial_dimension
    if gradient !== nothing
        for direction in 1:spatial_dimension
            _axis_required(plan, HAMILTONIAN_DERIVATIVES, direction) || continue
            channel = _axis_channel(plan, HAMILTONIAN_DERIVATIVES, direction)
            fill!(@view(gradient[:, :, channel, :]), COMPLEX_ZERO)
        end
    end
    if hessian !== nothing
        for first_direction in 1:spatial_dimension, second_direction in 1:spatial_dimension
            _pair_required(
                plan,
                HAMILTONIAN_SECOND_DERIVATIVES,
                first_direction,
                second_direction,
            ) || continue
            channel = _pair_channel(
                plan,
                HAMILTONIAN_SECOND_DERIVATIVES,
                first_direction,
                second_direction,
            )
            fill!(@view(hessian[:, :, channel, :]), COMPLEX_ZERO)
        end
    end
    @inbounds for r_vector_index in 1:model.num_r_vectors
        r_cartesian = _r_vector_cartesian(model, r_vector_index)
        for orbital_row in 1:model.num_orbitals
            for orbital_column in 1:model.num_orbitals
                hopping = model.hamiltonian_r[orbital_row, orbital_column, r_vector_index]
                for first_direction in 1:spatial_dimension
                    first_displacement = _convention_displacement_component(
                        r_cartesian,
                        first_direction,
                        orbital_row,
                        orbital_column,
                        scratch_workspace,
                        plan,
                    )
                    if gradient !== nothing &&
                       _axis_required(plan, HAMILTONIAN_DERIVATIVES, first_direction)
                        channel = _axis_channel(plan, HAMILTONIAN_DERIVATIVES, first_direction)
                        gradient[orbital_row, orbital_column, channel, r_vector_index] =
                            1.0im * first_displacement * hopping
                    end
                    if hessian !== nothing
                        for second_direction in 1:spatial_dimension
                            _pair_required(
                                plan,
                                HAMILTONIAN_SECOND_DERIVATIVES,
                                first_direction,
                                second_direction,
                            ) || continue
                            channel = _pair_channel(
                                plan,
                                HAMILTONIAN_SECOND_DERIVATIVES,
                                first_direction,
                                second_direction,
                            )
                            second_displacement = _convention_displacement_component(
                                r_cartesian,
                                second_direction,
                                orbital_row,
                                orbital_column,
                                scratch_workspace,
                                plan,
                            )
                            hessian[orbital_row, orbital_column, channel, r_vector_index] =
                                -first_displacement * second_displacement * hopping
                        end
                    end
                end
            end
        end
    end
    return scratch
end

# Reuse caller-owned scratch and the plan's Wannier-center convention; no k-space or response accumulation occurs.
function prepare_real_space!(workspace::MatrixElementWorkspace, model::TightBindingModel)
    workspace.prepared && return workspace
    _initialize_wannier_center_scratch!(workspace.scratch, model, workspace.plan)
    workspace.scratch.hamiltonian === nothing || prepare_hamiltonian_real_space!(
        workspace.scratch.hamiltonian,
        model,
        workspace.plan;
        scratch_workspace = workspace.scratch,
    )
    workspace.scratch.position === nothing || prepare_position_real_space!(
        workspace.scratch.position,
        model,
        workspace.plan;
        scratch_workspace = workspace.scratch,
    )
    workspace.prepared = true
    return workspace
end

# Assemble the shared Wannier-gauge Hamiltonian for one fractional k point.
function _assemble_hamiltonian_wannier!(
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    kpoint::AbstractVector{<:Real},
)
    scratch = workspace.scratch
    _prepare_fourier_factors!(scratch.fourier_factors, model, kpoint)
    used_mixed =
        _shared_or_mixed_copy!(scratch.hamiltonian_wannier, workspace, model, Val(:H), kpoint)
    if !used_mixed
        fourier_t0 = time_ns()
        _fourier_hamiltonian!(scratch.hamiltonian_wannier, scratch.fourier_factors, model)
        _record_direct_fourier!(workspace, (time_ns() - fourier_t0) * 1e-9)
    end
    _store_shared_fourier!(scratch.hamiltonian_wannier, workspace, model, :H, kpoint)
    _apply_wannier_center_similarity!(scratch.hamiltonian_wannier, scratch, workspace.plan)
    return scratch.hamiltonian_wannier
end

# Store one Hermitian eigensystem without changing the historical gauge convention.
function _store_spectrum_eigensystem!(workspace::MatrixElementWorkspace, eigensystem)
    data = workspace.data
    data.spectrum.energies .= eigensystem.values
    data.spectrum.source_eigenvectors .= eigensystem.vectors
    data.spectrum.source_eigenvectors_adjoint .= eigensystem.vectors'
    data.spectrum.eigenvectors .= eigensystem.vectors
    canonicalize_eigenvectors!(data.spectrum.eigenvectors)
    data.spectrum.eigenvectors_adjoint .= data.spectrum.eigenvectors'
    data.computed_mask |= _capability_bit(SPECTRUM)
    workspace.counts.fourier_transforms += 1
    workspace.counts.diagonalizations += 1
    workspace.counts.capability_computations[SPECTRUM] += 1
    return data.spectrum
end

# Prepare the caller-owned phase and Fourier-factor storage before a cache check.
function _prepare_spectrum_inputs!(
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    kpoint::AbstractVector{<:Real},
)
    length(kpoint) == 3 || throw(DimensionMismatch("kpoint must have length 3"))
    data = workspace.data
    scratch = workspace.scratch
    _prepare_wannier_center_phases!(scratch, model, workspace.plan, kpoint)
    length(data.fourier_factors) == model.num_r_vectors || error(
        "KPointMatrixData Fourier-factor length $(length(data.fourier_factors)) != num_r_vectors=$(model.num_r_vectors).",
    )
    scratch.fourier_factors = data.fourier_factors
    return data
end

# Start one uncached workspace generation for a spectrum calculation.
function _start_spectrum_generation!(data::KPointMatrixData, kpoint::AbstractVector{<:Real})
    data.generation += UInt64(1)
    data.computed_mask = UInt64(0)
    data.kpoint .= kpoint
    return data
end

# Prepare one uncached workspace generation for a spectrum calculation.
function _begin_spectrum_evaluation!(
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    kpoint::AbstractVector{<:Real},
)
    data = _prepare_spectrum_inputs!(workspace, model, kpoint)
    return _start_spectrum_generation!(data, kpoint)
end

"""
Assemble and diagonalize the Hermitian Wannier Hamiltonian at fractional `kpoint`, returning the cached spectrum.

Reuse a spectrum already computed at the same point; otherwise start a new generation and update Fourier/diagonalization counts. The explicit-data overload restores the workspace's original data reference on exit.
"""
function compute_spectrum!(
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    kpoint::AbstractVector{<:Real},
)
    data = _prepare_spectrum_inputs!(workspace, model, kpoint)
    if _has_capability(data.computed_mask, SPECTRUM) && all(data.kpoint .== kpoint)
        return data.spectrum
    end
    _start_spectrum_generation!(data, kpoint)
    _restore_shared_spectrum!(workspace, model, kpoint) && return data.spectrum
    hamiltonian = _assemble_hamiltonian_wannier!(workspace, model, kpoint)
    _store_spectrum_eigensystem!(workspace, eigen(Hermitian(hamiltonian)))
    return _store_shared_spectrum!(workspace, model, kpoint)
end

"""
Compute one spectrum after finite-value and Hermiticity checks.

This is the fail-closed Band-task entry point. It calls the same Hamiltonian
assembly used by `compute_spectrum!`, checks the assembled matrix before
constructing `Hermitian`, and returns the maximum absolute Hermiticity residual.
"""
function compute_checked_spectrum!(
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    kpoint::AbstractVector{<:Real};
    hermiticity_tolerance::Real,
)
    isfinite(hermiticity_tolerance) && hermiticity_tolerance >= 0 ||
        throw(ArgumentError("hermiticity_tolerance must be finite and nonnegative"))
    _begin_spectrum_evaluation!(workspace, model, kpoint)
    hamiltonian = _assemble_hamiltonian_wannier!(workspace, model, kpoint)
    all(isfinite, hamiltonian) || error("assembled H(k) contains non-finite values")
    residual = maximum(abs, hamiltonian .- hamiltonian')
    residual <= hermiticity_tolerance || error(
        "assembled H(k) Hermiticity residual $(residual) exceeds tolerance $(hermiticity_tolerance)",
    )
    spectrum = _store_spectrum_eigensystem!(workspace, eigen(Hermitian(hamiltonian)))
    all(isfinite, spectrum.energies) || error("Band eigensolver produced non-finite energies")
    return (spectrum = spectrum, hermiticity_residual = Float64(residual))
end

# Assemble and diagonalize the Hermitian Wannier Hamiltonian at fractional `kpoint`, returning the cached spectrum.
#
# Reuse a spectrum already computed at the same point; otherwise start a new generation and update Fourier/diagonalization counts. The explicit-data overload restores the workspace's original data reference on exit.
function compute_spectrum!(
    data::KPointMatrixData,
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    kpoint::AbstractVector{<:Real},
)
    previous_data = workspace.data
    workspace.data = data
    try
        return compute_spectrum!(workspace, model, kpoint)
    finally
        workspace.data = previous_data
    end
end

# Provide the checked spectrum overload for caller-owned k-point storage.
function compute_checked_spectrum!(
    data::KPointMatrixData,
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    kpoint::AbstractVector{<:Real};
    hermiticity_tolerance::Real,
)
    previous_data = workspace.data
    workspace.data = data
    try
        return compute_checked_spectrum!(
            workspace,
            model,
            kpoint;
            hermiticity_tolerance = hermiticity_tolerance,
        )
    finally
        workspace.data = previous_data
    end
end

# Compute missing band-energy differences and selected Hamiltonian gradient/Hessian channels, updating masks and evaluation counters.
function _compute_hamiltonian_capabilities!(
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
)
    plan = workspace.plan
    data = workspace.data
    hamiltonian_data = data.hamiltonian
    hamiltonian_data === nothing && return data
    scratch = workspace.scratch
    hamiltonian_scratch = scratch.hamiltonian
    spatial_dimension = plan.spatial_dimension

    if has_capability(plan, ENERGY_DIFFERENCES) &&
       !_has_capability(data.computed_mask, ENERGY_DIFFERENCES)
        hamiltonian_data.energy_differences .= data.spectrum.energies .- data.spectrum.energies'
        data.computed_mask |= _capability_bit(ENERGY_DIFFERENCES)
        workspace.counts.capability_computations[ENERGY_DIFFERENCES] += 1
    end

    needs_gradient =
        has_capability(plan, HAMILTONIAN_DERIVATIVES) &&
        !_has_capability(data.computed_mask, HAMILTONIAN_DERIVATIVES)
    needs_hessian =
        has_capability(plan, HAMILTONIAN_SECOND_DERIVATIVES) &&
        !_has_capability(data.computed_mask, HAMILTONIAN_SECOND_DERIVATIVES)
    if !(needs_gradient || needs_hessian)
        return data
    end

    gradient_wannier = hamiltonian_scratch.gradient_wannier
    hessian_wannier = hamiltonian_scratch.hessian_wannier
    gradient_channel_map = _axis_channel_map(plan, HAMILTONIAN_DERIVATIVES)
    hessian_channel_map = _pair_channel_map(plan, HAMILTONIAN_SECOND_DERIVATIVES)
    gradient_mixed =
        needs_gradient &&
        _shared_or_mixed_copy!(gradient_wannier, workspace, model, Val(:dH), data.kpoint)
    hessian_mixed =
        needs_hessian &&
        _shared_or_mixed_copy!(hessian_wannier, workspace, model, Val(:ddH), data.kpoint)
    if needs_gradient && !gradient_mixed
        for direction in 1:spatial_dimension
            channel = gradient_channel_map[direction]
            iszero(channel) && continue
            fill!(@view(gradient_wannier[:, :, channel]), COMPLEX_ZERO)
        end
    end
    if needs_hessian && !hessian_mixed
        for first_direction in 1:spatial_dimension, second_direction in 1:spatial_dimension
            channel = _pair_map_channel(hessian_channel_map, first_direction, second_direction)
            iszero(channel) && continue
            fill!(@view(hessian_wannier[:, :, channel]), COMPLEX_ZERO)
        end
    end
    if (needs_gradient && !gradient_mixed) || (needs_hessian && !hessian_mixed)
        fourier_t0 = time_ns()
        @inbounds for r_vector_index in 1:model.num_r_vectors
            fourier_factor = scratch.fourier_factors[r_vector_index]
            if needs_gradient && !gradient_mixed
                for channel in axes(gradient_wannier, 3)
                    for orbital_column in 1:model.num_orbitals
                        for orbital_row in 1:model.num_orbitals
                            gradient_wannier[orbital_row, orbital_column, channel] +=
                                fourier_factor * hamiltonian_scratch.gradient_real_space[
                                    orbital_row,
                                    orbital_column,
                                    channel,
                                    r_vector_index,
                                ]
                        end
                    end
                end
            end
            if needs_hessian && !hessian_mixed
                for channel in axes(hessian_wannier, 3)
                    for orbital_column in 1:model.num_orbitals
                        for orbital_row in 1:model.num_orbitals
                            hessian_wannier[orbital_row, orbital_column, channel] +=
                                fourier_factor * hamiltonian_scratch.hessian_real_space[
                                    orbital_row,
                                    orbital_column,
                                    channel,
                                    r_vector_index,
                                ]
                        end
                    end
                end
            end
        end
        _record_direct_fourier!(workspace, (time_ns() - fourier_t0) * 1e-9)
    end

    needs_gradient && _store_shared_fourier!(gradient_wannier, workspace, model, :dH, data.kpoint)
    needs_hessian && _store_shared_fourier!(hessian_wannier, workspace, model, :ddH, data.kpoint)

    if needs_gradient
        for channel in axes(gradient_wannier, 3)
            @views _apply_wannier_center_similarity!(gradient_wannier[:, :, channel], scratch, plan)
        end
    end
    if needs_hessian
        for channel in axes(hessian_wannier, 3)
            @views _apply_wannier_center_similarity!(hessian_wannier[:, :, channel], scratch, plan)
        end
    end

    for first_direction in 1:spatial_dimension
        gradient_channel = gradient_channel_map[first_direction]
        if needs_gradient && !iszero(gradient_channel)
            @views transform_to_hamiltonian_gauge!(
                hamiltonian_data.derivatives[:, :, first_direction],
                data.spectrum,
                gradient_wannier[:, :, gradient_channel],
                scratch.matrix_temporary,
            )
            if plan.source_gauge_required
                @views _transform_source_gauge!(
                    hamiltonian_data.source_gauge_derivatives[:, :, first_direction],
                    data.spectrum.source_eigenvectors_adjoint,
                    gradient_wannier[:, :, gradient_channel],
                    data.spectrum.source_eigenvectors,
                    scratch.matrix_temporary,
                )
            end
        end
        if needs_hessian
            for second_direction in 1:spatial_dimension
                channel = _pair_map_channel(hessian_channel_map, first_direction, second_direction)
                iszero(channel) && continue
                @views transform_to_hamiltonian_gauge!(
                    hamiltonian_data.second_derivatives[:, :, first_direction, second_direction],
                    data.spectrum,
                    hessian_wannier[:, :, channel],
                    scratch.matrix_temporary,
                )
            end
        end
    end
    if needs_gradient
        data.computed_mask |= _capability_bit(HAMILTONIAN_DERIVATIVES)
        workspace.counts.capability_computations[HAMILTONIAN_DERIVATIVES] += 1
    end
    if needs_hessian
        data.computed_mask |= _capability_bit(HAMILTONIAN_SECOND_DERIVATIVES)
        workspace.counts.capability_computations[HAMILTONIAN_SECOND_DERIVATIVES] += 1
    end
    return data
end

"""
Fill only capability-plan matrices not yet computed for the current spectrum and return workspace data.

The spectrum must correspond to the requested point; computation updates cache masks and counters and reuses prepared real-space scratch.
"""
function compute_remaining!(workspace::MatrixElementWorkspace, model::TightBindingModel)
    workspace.prepared || error("prepare_real_space! must be called before compute_remaining!.")
    _has_capability(workspace.data.computed_mask, SPECTRUM) ||
        error("compute_spectrum! must be called before compute_remaining!.")
    _compute_hamiltonian_capabilities!(workspace, model)
    compute_position_capabilities!(workspace, model)
    compute_spin_capabilities!(workspace, model)
    compute_spin_velocity_capabilities!(workspace, model)
    return workspace.data
end

# Populate the supplied workspace or k-point data for a fractional reciprocal point using its capability plan.
#
# Compute the spectrum before dependent matrices and return the populated data; wrapper overloads borrow the common workspace and restore its previous data reference. Caller-owned buffers are reused, and no response prefactor or k-mesh weight is applied.
function compute_kpoint!(
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    kpoint::AbstractVector{<:Real},
    ;
    denominator_regularization::Real = workspace.plan.denominator_regularization,
    degeneracy_threshold::Real = workspace.plan.degeneracy_threshold,
)
    workspace.plan = MatrixElementPlan(
        workspace.plan.requested_mask,
        workspace.plan.required_mask,
        workspace.plan.spatial_dimension,
        Float64(denominator_regularization),
        Float64(degeneracy_threshold),
        workspace.plan.wannier_center_convention,
        workspace.plan.direction_requirements,
        workspace.plan.source_gauge_required,
    )
    compute_spectrum!(workspace, model, kpoint)
    return compute_remaining!(workspace, model)
end

# Populate the supplied workspace or k-point data for a fractional reciprocal point using its capability plan.
#
# Compute the spectrum before dependent matrices and return the populated data; wrapper overloads borrow the common workspace and restore its previous data reference. Caller-owned buffers are reused, and no response prefactor or k-mesh weight is applied.
function compute_kpoint!(
    data::KPointMatrixData,
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    kpoint::AbstractVector{<:Real};
    denominator_regularization::Real = workspace.plan.denominator_regularization,
    degeneracy_threshold::Real = workspace.plan.degeneracy_threshold,
    spatial_dimension::Integer = workspace.plan.spatial_dimension,
)
    Int(spatial_dimension) == workspace.plan.spatial_dimension || error(
        "Workspace spatial_dimension=$(workspace.plan.spatial_dimension) does not match requested $(spatial_dimension).",
    )
    previous_data = workspace.data
    workspace.data = data
    try
        return compute_kpoint!(
            workspace,
            model,
            kpoint;
            denominator_regularization = denominator_regularization,
            degeneracy_threshold = degeneracy_threshold,
        )
    finally
        workspace.data = previous_data
    end
end
