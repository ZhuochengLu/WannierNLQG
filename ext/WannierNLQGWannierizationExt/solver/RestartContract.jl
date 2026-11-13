"""Immutable complete numerical definition for one restart trajectory."""
struct WannierizationRestartContract
    numerical_values::Tuple
    canonical_representation::String
end

# Render only controls that affect the numerical trajectory; output policy and
# the total iteration ceiling may change when a complete checkpoint is resumed.
function _restart_config_values(
    config::WannierizationConfig,
    apply_symmetry::Bool = symmetry_constraints_applied(config);
    complete_basis::Bool = true,
)
    no_symmetry_frozen_algorithm =
        effective_wannierization_mode(config) == :ordinary && (
            !isempty(config.input.frozen_states) ||
            config.input.frozen_min_ev <= config.input.frozen_max_ev
        ) ? "nosym_exact_frozen_rowspace_v2" : ""
    stage_controls = config.solver.stage_controls
    acceleration = if stage_controls === nothing
        config.solver.acceleration
    else
        # Limits and objective stopping controls may change on continuation;
        # all numerical proposal/line-search settings remain bound.
        replacements = (;
            disentanglement_max_steps = 0,
            localization_max_steps = 0,
            disentanglement_objective_tolerance = 0.0,
            z_stability_window = 1,
        )
        original = config.solver.acceleration
        typeof(original)(;
            (
                name => (
                    haskey(replacements, name) ? getproperty(replacements, name) :
                    getfield(original, name)
                ) for name in fieldnames(typeof(original))
            )...,
        )
    end
    return (
        config.input.wannierization_mode,
        effective_wannierization_mode(config),
        representation_source(config),
        apply_symmetry,
        config.input.outer_min_ev,
        config.input.outer_max_ev,
        config.input.frozen_min_ev,
        config.input.frozen_max_ev,
        config.input.frozen_states,
        config.input.num_wannier,
        representation_source(config) == :detected ? config.input.symmetry_tolerance :
        :NOT_APPLICABLE,
        config.solver.z_mix_ratio,
        config.solver.u_mix_ratio,
        acceleration,
        stage_controls === nothing ? config.solver.stage_controls.conv_tol : 0.0,
        stage_controls === nothing ? max(2, config.solver.stage_controls.conv_window) : 1,
        config.solver.little_group_tolerance,
        config.solver.little_group_max_iterations,
        config.input.degeneracy_tolerance_ev,
        config.input.representation_tolerance,
        config.input.empirical_covariance_budget,
        config.input.target_center_matching_tolerance,
        config.input.compatibility_policy,
        stage_controls === nothing ? (config.solver.stage_controls.num_iter > 0) : true,
        config.solver.symmetrize_z,
        config.solver.parallel,
        config.solver.random_seed,
        no_symmetry_frozen_algorithm,
        config.input.projection_basis === nothing ? "" :
        repr(projection_basis_input_values(something(config.input.projection_basis))),
    )
end

# Bind current numerical controls and the localization-gradient formula to one
# strict restart representation.
function _restart_config_repr(
    config::WannierizationConfig,
    effective_algorithms = effective_wannierization_algorithms(config),
    apply_symmetry::Bool = symmetry_constraints_applied(config);
    complete_basis::Bool = true,
)
    contract = (
        _restart_config_values(config, apply_symmetry; complete_basis)...,
        config.input.wannierization_mode,
        effective_wannierization_mode(config),
        :auto,
        effective_algorithms,
        SMV_FLETCHER_REEVES_TWO_STAGE_ALGORITHM_CONTRACT_VERSION,
        SYMMETRY_PROJECTED_SMV_FR_CONTRACT,
        band_sewing_backend_key(config.input.sewing_backend),
        config.input.sewing_backend isa AugmentationAwareSewing ?
        repr(config.input.sewing_backend.thresholds) : "NOT_APPLICABLE",
        wavefunction_gauge_backend_key(config.input.wavefunction_gauge_backend),
        config.input.wavefunction_gauge_backend isa StarCovariantPAWGauge ?
        repr(config.input.wavefunction_gauge_backend) : "NOT_APPLICABLE",
        authoritative_hamiltonian_key(config.input.authoritative_hamiltonian),
        # Actual produced representation/overlaps/initializer are retained and
        # compared by WannierizationRestartInputDefinition, not file hashes.
        config.solver.numerical_thresholds,
        typeof(config.solver.initialization_backend),
        config.solver.multi_start.enabled,
        config.solver.multi_start.starts,
        config.solver.multi_start.start_index,
        LOCALIZATION_GRADIENT_CONTRACT,
        JOINT_UPDATE_CONTRACT,
    )
    config.solver.stage_controls === nothing ||
        (contract = (contract..., "accepted-objective-change/1"))
    config.input.operation_indices === nothing ||
        (contract = (contract..., "detected-seitz-subgroup/1", config.input.operation_indices))
    # Public configuration validation rejects removed construction modes.
    validate_ordinary_construction_policy(config.input.construction_policy)
    contract = (contract..., "construction_policy_v1", config.input.construction_policy)
    return repr(contract)
end

# Normal continuation accepts only the current identity. Historical file decoding
# and explicit conversion are owned by hdf5/ExplicitCheckpointMigration.jl.
function WannierizationRestartContract(
    config::WannierizationConfig;
    effective_algorithms = effective_wannierization_algorithms(config),
    apply_symmetry::Bool = symmetry_constraints_applied(config),
)
    values = _restart_config_values(config, apply_symmetry)
    canonical = _restart_config_repr(config, effective_algorithms, apply_symmetry)
    return WannierizationRestartContract(values, canonical)
end
