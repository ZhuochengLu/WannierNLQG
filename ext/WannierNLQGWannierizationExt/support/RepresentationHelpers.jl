"""Build the k-dependent target representation including center phases."""
function target_representation(
    plan::WannierSymmetryPlan,
    representation::BandRepresentation,
    operation_index::Int,
    source_kpoint::Int,
    plan_operation_index::Int = operation_index,
)
    target_kpoint = representation.kpoint_map[operation_index, source_kpoint]
    target_k = @view representation.kpoints_fractional[target_kpoint, :]
    matrix = copy(@view plan.representation_matrices[:, :, plan_operation_index])
    for source_wannier in axes(matrix, 2)
        shift = @view plan.wannier_shifts[:, source_wannier, plan_operation_index]
        matrix[:, source_wannier] .*= cis(-2.0 * pi * dot(target_k, shift))
    end
    return matrix
end

"""Validate the immutable Wannier90-reference parity thresholds."""
function validate_smv_fletcher_reeves_two_stage_audit_thresholds(
    thresholds::SMVFletcherReevesTwoStageAuditThresholds,
)
    isempty(strip(thresholds.standard_version)) &&
        throw(ArgumentError("Wannier90 parity standard_version must not be empty"))
    thresholds.semantic == "SMV_FLETCHER_REEVES_TWO_STAGE_ORACLE_PARITY_WITH_FROZEN_TOLERANCE" ||
        throw(ArgumentError("SMV--Fletcher--Reeves audit semantic is unsupported"))
    thresholds.accepted_step_combination_rule ==
    "abs_diff <= abs_tol + rel_tol * max(abs(reference), abs(candidate))" || throw(
        ArgumentError("unsupported Wannier90 accepted-step absolute/relative combination rule"),
    )
    for (name, value) in (
        ("accepted_step_absolute_tolerance", thresholds.accepted_step_absolute_tolerance),
        ("accepted_step_relative_tolerance", thresholds.accepted_step_relative_tolerance),
        ("omega_i_absolute_tolerance_angstrom2", thresholds.omega_i_absolute_tolerance_angstrom2),
        ("projector_operator_tolerance", thresholds.projector_operator_tolerance),
        ("maximum_principal_angle_tolerance_rad", thresholds.maximum_principal_angle_tolerance_rad),
        (
            "z_to_u_initial_spread_absolute_tolerance_angstrom2",
            thresholds.z_to_u_initial_spread_absolute_tolerance_angstrom2,
        ),
        ("u_nonstep_relative_tolerance", thresholds.u_nonstep_relative_tolerance),
    )
        isfinite(value) && value > 0.0 ||
            throw(ArgumentError("$(name) must be positive and finite"))
    end
    return nothing
end

"""Materialize complete-block outer and frozen masks from energies."""
function window_masks_from_energies(
    config::Union{SymmetryAdaptedWannierizationConfig, BandRepresentationPreparationConfig},
    energies::AbstractMatrix{<:Real},
    band_block_labels::AbstractMatrix{<:Integer},
)
    input = config isa SymmetryAdaptedWannierizationConfig ? config.input : config
    size(energies) == size(band_block_labels) ||
        throw(ArgumentError("energy and block-label dimensions disagree"))
    num_bands, num_kpoints = size(energies)
    outer_masks = [falses(num_bands) for _ in 1:num_kpoints]
    frozen_masks = [falses(num_bands) for _ in 1:num_kpoints]
    for kpoint in 1:num_kpoints
        outer = complete_window_indices(
            @view(energies[:, kpoint]),
            @view(band_block_labels[:, kpoint]),
            input.outer_min_ev,
            input.outer_max_ev,
        )
        selected_frozen_labels = Set{Int}()
        if input.frozen_min_ev <= input.frozen_max_ev
            for band in 1:num_bands
                input.frozen_min_ev <= energies[band, kpoint] <= input.frozen_max_ev &&
                    push!(selected_frozen_labels, band_block_labels[band, kpoint])
            end
        end
        for (explicit_kpoint, band) in input.frozen_states
            explicit_kpoint == kpoint || continue
            1 <= band <= num_bands || throw(
                ArgumentError("explicit frozen band $(band) is out of range at k-point $(kpoint)"),
            )
            push!(selected_frozen_labels, band_block_labels[band, kpoint])
        end
        frozen =
            findall(label -> label in selected_frozen_labels, @view(band_block_labels[:, kpoint]))
        outer_masks[kpoint][outer] .= true
        frozen_masks[kpoint][frozen] .= true
    end
    return outer_masks, frozen_masks
end
