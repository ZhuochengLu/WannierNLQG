"""
Prepare selected R-space derivatives of the Wannier connection using Cartesian displacements in the plan's center convention.

Reuse caller scratch and compact direction-pair channels; no Fourier phases or response normalization are applied at this stage.

Prepare position real space in place.
"""
function prepare_position_real_space!(
    scratch::PositionMatrixScratch,
    model::TightBindingModel,
    plan::MatrixElementPlan,
    ;
    scratch_workspace::MatrixElementScratch,
)
    gradient = scratch.gradient_real_space
    gradient === nothing && return scratch
    spatial_dimension = plan.spatial_dimension
    for position_direction in 1:spatial_dimension, derivative_direction in 1:spatial_dimension
        _pair_required(
            plan,
            INTERNAL_CONNECTION_DERIVATIVES,
            position_direction,
            derivative_direction,
        ) || continue
        channel = _pair_channel(
            plan,
            INTERNAL_CONNECTION_DERIVATIVES,
            position_direction,
            derivative_direction,
        )
        fill!(@view(gradient[:, :, channel, :]), COMPLEX_ZERO)
    end
    @inbounds for r_vector_index in 1:model.num_r_vectors
        r_cartesian = _r_vector_cartesian(model, r_vector_index)
        for orbital_row in 1:model.num_orbitals
            for orbital_column in 1:model.num_orbitals
                for position_direction in 1:spatial_dimension
                    for derivative_direction in 1:spatial_dimension
                        _pair_required(
                            plan,
                            INTERNAL_CONNECTION_DERIVATIVES,
                            position_direction,
                            derivative_direction,
                        ) || continue
                        position_value = _convention_position_value(
                            model.position_r[
                                orbital_row,
                                orbital_column,
                                position_direction,
                                r_vector_index,
                            ],
                            position_direction,
                            orbital_row,
                            orbital_column,
                            r_vector_index,
                            scratch_workspace,
                            plan,
                        )
                        displacement = _convention_displacement_component(
                            r_cartesian,
                            derivative_direction,
                            orbital_row,
                            orbital_column,
                            scratch_workspace,
                            plan,
                        )
                        channel = _pair_channel(
                            plan,
                            INTERNAL_CONNECTION_DERIVATIVES,
                            position_direction,
                            derivative_direction,
                        )
                        gradient[orbital_row, orbital_column, channel, r_vector_index] =
                            1.0im * displacement * position_value
                    end
                end
            end
        end
    end
    return scratch
end

# Rotate an input matrix with native source-gauge eigenvectors into the caller's output, reusing multiplication scratch.
function _transform_source_gauge!(
    output::AbstractMatrix{ComplexF64},
    eigenvectors_adjoint::AbstractMatrix{ComplexF64},
    input::AbstractMatrix{ComplexF64},
    eigenvectors::AbstractMatrix{ComplexF64},
    temporary::AbstractMatrix{ComplexF64},
)
    count = size(output, 1)
    fill!(temporary, COMPLEX_ZERO)
    @inbounds for column in 1:count
        for intermediate in 1:count
            input_value = input[intermediate, column]
            for row in 1:count
                temporary[row, column] += eigenvectors_adjoint[row, intermediate] * input_value
            end
        end
    end
    fill!(output, COMPLEX_ZERO)
    @inbounds for column in 1:count
        for intermediate in 1:count
            eigenvector_value = eigenvectors[intermediate, column]
            for row in 1:count
                output[row, column] += temporary[row, intermediate] * eigenvector_value
            end
        end
    end
    return output
end

# Assemble native-source-gauge Hamiltonian derivatives, Berry connections and velocity vertices from the current eigensystem.
function _compute_source_gauge_geometry!(workspace::MatrixElementWorkspace)
    data = workspace.data
    position_data = data.position
    position_scratch = workspace.scratch.position
    spectrum = data.spectrum
    spatial_dimension = workspace.plan.spatial_dimension
    for direction in 1:spatial_dimension
        _axis_required(workspace.plan, BERRY_CONNECTION, direction) || continue
        @views _transform_source_gauge!(
            position_data.source_gauge_berry_connection[:, :, direction],
            spectrum.source_eigenvectors_adjoint,
            position_data.wannier_gauge[:, :, direction],
            spectrum.source_eigenvectors,
            position_scratch.source_internal_temporary,
        )
        @views position_data.source_gauge_berry_connection[:, :, direction] .+=
            -1.0im .* data.hamiltonian.source_gauge_derivatives[:, :, direction] .*
            position_data.inverse_energy_differences
    end
    return position_data.source_gauge_berry_connection
end

# Populate only requested Wannier position/derivative Fourier channels, using Mixed-FFT where available and direct sums otherwise.
function _fourier_position_capabilities!(
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
)
    plan = workspace.plan
    data = workspace.data
    position_data = data.position
    position_data === nothing && return data
    scratch = workspace.scratch
    position_scratch = scratch.position
    spatial_dimension = plan.spatial_dimension
    needs_wannier =
        has_capability(plan, WANNIER_POSITION) &&
        !_has_capability(data.computed_mask, WANNIER_POSITION)
    needs_gradient =
        has_capability(plan, INTERNAL_CONNECTION_DERIVATIVES) &&
        !_has_capability(data.computed_mask, INTERNAL_CONNECTION_DERIVATIVES)
    if !(needs_wannier || needs_gradient)
        return data
    end
    wannier_channel_map = _axis_channel_map(plan, WANNIER_POSITION)
    gradient_channel_map = _pair_channel_map(plan, INTERNAL_CONNECTION_DERIVATIVES)
    wannier_mixed =
        needs_wannier && _shared_or_mixed_copy!(
            position_scratch.wannier_gauge,
            workspace,
            model,
            Val(:A),
            data.kpoint,
        )
    gradient_mixed =
        needs_gradient && _shared_or_mixed_copy!(
            position_scratch.gradient_wannier,
            workspace,
            model,
            Val(:dA),
            data.kpoint,
        )
    if needs_wannier && !wannier_mixed
        for direction in 1:spatial_dimension
            channel = wannier_channel_map[direction]
            iszero(channel) && continue
            fill!(@view(position_scratch.wannier_gauge[:, :, channel]), COMPLEX_ZERO)
        end
    end
    if needs_gradient && !gradient_mixed
        for position_direction in 1:spatial_dimension, derivative_direction in 1:spatial_dimension
            channel =
                _pair_map_channel(gradient_channel_map, position_direction, derivative_direction)
            iszero(channel) && continue
            fill!(@view(position_scratch.gradient_wannier[:, :, channel]), COMPLEX_ZERO)
        end
    end
    if (needs_wannier && !wannier_mixed) || (needs_gradient && !gradient_mixed)
        fourier_t0 = time_ns()
        @inbounds for r_vector_index in 1:model.num_r_vectors
            fourier_factor = scratch.fourier_factors[r_vector_index]
            if needs_wannier && !wannier_mixed
                for position_direction in 1:spatial_dimension
                    channel = wannier_channel_map[position_direction]
                    iszero(channel) && continue
                    for orbital_column in 1:model.num_orbitals
                        for orbital_row in 1:model.num_orbitals
                            position_scratch.wannier_gauge[orbital_row, orbital_column, channel] +=
                                fourier_factor * model.position_r[
                                    orbital_row,
                                    orbital_column,
                                    position_direction,
                                    r_vector_index,
                                ]
                        end
                    end
                end
            end
            if needs_gradient && !gradient_mixed
                for channel in axes(position_scratch.gradient_wannier, 3)
                    for orbital_column in 1:model.num_orbitals
                        for orbital_row in 1:model.num_orbitals
                            position_scratch.gradient_wannier[
                                orbital_row,
                                orbital_column,
                                channel,
                            ] +=
                                fourier_factor * position_scratch.gradient_real_space[
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
    needs_wannier &&
        _store_shared_fourier!(position_scratch.wannier_gauge, workspace, model, :A, data.kpoint)
    needs_gradient && _store_shared_fourier!(
        position_scratch.gradient_wannier,
        workspace,
        model,
        :dA,
        data.kpoint,
    )
    if needs_wannier
        for position_direction in 1:spatial_dimension
            channel = wannier_channel_map[position_direction]
            iszero(channel) && continue
            matrix = @view position_scratch.wannier_gauge[:, :, channel]
            if plan.wannier_center_convention == CONVENTION_I
                @inbounds for orbital in 1:model.num_orbitals
                    matrix[orbital, orbital] -=
                        scratch.wannier_centers_cartesian[position_direction, orbital]
                end
            end
            _apply_wannier_center_similarity!(matrix, scratch, plan)
        end
    end
    if needs_gradient
        for channel in axes(position_scratch.gradient_wannier, 3)
            @views _apply_wannier_center_similarity!(
                position_scratch.gradient_wannier[:, :, channel],
                scratch,
                plan,
            )
        end
    end
    if needs_wannier
        for direction in 1:spatial_dimension
            channel = wannier_channel_map[direction]
            iszero(channel) && continue
            @views position_data.wannier_gauge[:, :, direction] .=
                position_scratch.wannier_gauge[:, :, channel]
        end
        data.computed_mask |= _capability_bit(WANNIER_POSITION)
        workspace.counts.capability_computations[WANNIER_POSITION] += 1
    end
    if needs_gradient
        for position_direction in 1:spatial_dimension
            for derivative_direction in 1:spatial_dimension
                channel = _pair_map_channel(
                    gradient_channel_map,
                    position_direction,
                    derivative_direction,
                )
                iszero(channel) && continue
                @views position_data.wannier_connection_derivatives[
                    :,
                    :,
                    position_direction,
                    derivative_direction,
                ] .= position_scratch.gradient_wannier[:, :, channel]
                @views transform_to_hamiltonian_gauge!(
                    position_data.internal_connection_derivatives[
                        :,
                        :,
                        position_direction,
                        derivative_direction,
                    ],
                    data.spectrum,
                    position_scratch.gradient_wannier[:, :, channel],
                    scratch.matrix_temporary,
                )
            end
        end
        data.computed_mask |= _capability_bit(INTERNAL_CONNECTION_DERIVATIVES)
        workspace.counts.capability_computations[INTERNAL_CONNECTION_DERIVATIVES] += 1
    end
    return data
end

"""
Fill missing position, connection, curvature and velocity capabilities after the spectrum is available.

Apply the plan's regularized denominators and native Wannier-center convention, update capability masks/counters, and return workspace data without response normalization.
"""
function compute_position_capabilities!(workspace::MatrixElementWorkspace, model::TightBindingModel)
    plan = workspace.plan
    data = workspace.data
    position_data = data.position
    position_data === nothing && return data
    _fourier_position_capabilities!(workspace, model)
    scratch = workspace.scratch
    position_scratch = scratch.position
    spatial_dimension = plan.spatial_dimension

    if has_capability(plan, INTERNAL_CONNECTION) &&
       !_has_capability(data.computed_mask, INTERNAL_CONNECTION)
        for direction in 1:spatial_dimension
            _axis_required(plan, INTERNAL_CONNECTION, direction) || continue
            @views transform_to_hamiltonian_gauge!(
                position_data.internal_connection[:, :, direction],
                data.spectrum,
                position_data.wannier_gauge[:, :, direction],
                scratch.matrix_temporary,
            )
        end
        data.computed_mask |= _capability_bit(INTERNAL_CONNECTION)
        workspace.counts.capability_computations[INTERNAL_CONNECTION] += 1
    end

    if has_capability(plan, GAUGE_CORRECTION) &&
       !_has_capability(data.computed_mask, GAUGE_CORRECTION)
        energy_differences = data.hamiltonian.energy_differences
        @. position_data.inverse_energy_differences =
            energy_differences / (energy_differences^2 + plan.denominator_regularization^2)
        for direction in 1:spatial_dimension
            _axis_required(plan, GAUGE_CORRECTION, direction) || continue
            @views position_data.gauge_correction[:, :, direction] .=
                -data.hamiltonian.derivatives[:, :, direction] .*
                position_data.inverse_energy_differences
        end
        data.computed_mask |= _capability_bit(GAUGE_CORRECTION)
        workspace.counts.capability_computations[GAUGE_CORRECTION] += 1
    end

    if has_capability(plan, BERRY_CONNECTION) &&
       !_has_capability(data.computed_mask, BERRY_CONNECTION)
        for direction in 1:spatial_dimension
            _axis_required(plan, BERRY_CONNECTION, direction) || continue
            @views position_data.berry_connection[:, :, direction] .=
                position_data.internal_connection[:, :, direction] .+
                1.0im .* position_data.gauge_correction[:, :, direction]
        end
        plan.source_gauge_required && _compute_source_gauge_geometry!(workspace)
        data.computed_mask |= _capability_bit(BERRY_CONNECTION)
        workspace.counts.capability_computations[BERRY_CONNECTION] += 1
    end

    if has_capability(plan, WANNIER_CURVATURE) &&
       !_has_capability(data.computed_mask, WANNIER_CURVATURE)
        num_orbitals = model.num_orbitals
        wannier_position = position_data.wannier_gauge
        wannier_gradient = position_scratch.gradient_wannier
        wannier_curvature = position_data.wannier_curvature
        @inbounds for first_direction in 1:spatial_dimension
            for second_direction in 1:spatial_dimension
                _pair_required(plan, WANNIER_CURVATURE, first_direction, second_direction) ||
                    continue
                for column in 1:num_orbitals
                    for row in 1:num_orbitals
                        value =
                            wannier_gradient[
                                row,
                                column,
                                _pair_channel(
                                    plan,
                                    INTERNAL_CONNECTION_DERIVATIVES,
                                    second_direction,
                                    first_direction,
                                ),
                            ] - wannier_gradient[
                                row,
                                column,
                                _pair_channel(
                                    plan,
                                    INTERNAL_CONNECTION_DERIVATIVES,
                                    first_direction,
                                    second_direction,
                                ),
                            ]
                        for intermediate in 1:num_orbitals
                            value -=
                                1.0im * (
                                    wannier_position[row, intermediate, first_direction] *
                                    wannier_position[intermediate, column, second_direction] -
                                    wannier_position[row, intermediate, second_direction] *
                                    wannier_position[intermediate, column, first_direction]
                                )
                        end
                        wannier_curvature[row, column, first_direction, second_direction] = value
                    end
                end
                @views transform_to_hamiltonian_gauge!(
                    position_data.hamiltonian_curvature[:, :, first_direction, second_direction],
                    data.spectrum,
                    wannier_curvature[:, :, first_direction, second_direction],
                    scratch.matrix_temporary,
                )
            end
        end
        data.computed_mask |= _capability_bit(WANNIER_CURVATURE)
        workspace.counts.capability_computations[WANNIER_CURVATURE] += 1
    end

    if has_capability(plan, VELOCITY_VERTICES) &&
       !_has_capability(data.computed_mask, VELOCITY_VERTICES)
        energy_differences = data.hamiltonian.energy_differences
        if plan.source_gauge_required
            @inbounds for orbital_row in 1:model.num_orbitals
                for orbital_column in 1:model.num_orbitals
                    for direction in 1:spatial_dimension
                        _axis_required(plan, VELOCITY_VERTICES, direction) || continue
                        position_data.velocity_vertices[orbital_row, orbital_column, direction] =
                            1.0im *
                            energy_differences[orbital_row, orbital_column] *
                            position_data.berry_connection[orbital_row, orbital_column, direction]
                        position_data.source_gauge_velocity_vertices[
                            orbital_row,
                            orbital_column,
                            direction,
                        ] =
                            1.0im *
                            energy_differences[orbital_row, orbital_column] *
                            position_data.source_gauge_berry_connection[
                                orbital_row,
                                orbital_column,
                                direction,
                            ]
                    end
                end
            end
        else
            @inbounds for orbital_row in 1:model.num_orbitals
                for orbital_column in 1:model.num_orbitals
                    for direction in 1:spatial_dimension
                        _axis_required(plan, VELOCITY_VERTICES, direction) || continue
                        position_data.velocity_vertices[orbital_row, orbital_column, direction] =
                            1.0im *
                            energy_differences[orbital_row, orbital_column] *
                            position_data.berry_connection[orbital_row, orbital_column, direction]
                    end
                end
            end
        end
        data.computed_mask |= _capability_bit(VELOCITY_VERTICES)
        workspace.counts.capability_computations[VELOCITY_VERTICES] += 1
    end
    return data
end
