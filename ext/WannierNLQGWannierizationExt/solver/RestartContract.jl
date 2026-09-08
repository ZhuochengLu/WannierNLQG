const WannierizationLegacyRestartDigests = NamedTuple{
    (:pre_v2_12, :pre_v2_11, :pre_v2_10, :pre_v2_9, :pre_v2_8, :pre_v2_7, :pre_v2_6),
    Tuple{
        Union{Nothing, String},
        Union{Nothing, String},
        Union{Nothing, String},
        Union{Nothing, String},
        Union{Nothing, String},
        Union{Nothing, String},
        Union{Nothing, String},
    },
}

"""Immutable canonical representation and digest family for one restart trajectory."""
struct WannierizationRestartContract
    numerical_values::Tuple
    canonical_representation::String
    current_sha256::String
    legacy_sha256::WannierizationLegacyRestartDigests
end

# Render only controls that affect the numerical trajectory; output policy and
# the total iteration ceiling may change when a complete checkpoint is resumed.
function _restart_config_values(
    config::SymmetryAdaptedWannierizationConfig,
    apply_symmetry::Bool = symmetry_constraints_applied(config),
)
    no_symmetry_frozen_algorithm =
        effective_wannierization_mode(config) == :ordinary && (
            !isempty(config.input.frozen_states) ||
            config.input.frozen_min_ev <= config.input.frozen_max_ev
        ) ? "nosym_exact_frozen_rowspace_v2" : ""
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
        config.solver.acceleration,
        config.solver.convergence_tolerance,
        config.solver.convergence_window,
        config.solver.little_group_tolerance,
        config.solver.little_group_max_iterations,
        config.input.degeneracy_tolerance_ev,
        config.input.representation_tolerance,
        config.input.empirical_covariance_budget,
        config.input.target_center_matching_tolerance,
        config.input.compatibility_policy,
        config.solver.localize,
        config.solver.symmetrize_z,
        config.solver.parallel,
        config.solver.random_seed,
        no_symmetry_frozen_algorithm,
        config.input.projection_basis === nothing ? "" :
        projection_basis_sha256(something(config.input.projection_basis)),
    )
end

# Bind current numerical controls and the localization-gradient formula to one
# strict restart representation.
function _restart_config_repr(
    config::SymmetryAdaptedWannierizationConfig,
    effective_algorithms = effective_wannierization_algorithms(config),
    apply_symmetry::Bool = symmetry_constraints_applied(config),
)
    contract = (
        _restart_config_values(config, apply_symmetry)...,
        config.input.wannierization_mode,
        effective_wannierization_mode(config),
        config.solver.algorithm_profile,
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
        config.input.wavefunction_gauge_hdf5 === nothing ? "NOT_APPLICABLE" :
        open(
            filename -> bytes2hex(SHA.sha256(filename)),
            something(config.input.wavefunction_gauge_hdf5),
            "r",
        ),
        config.solver.numerical_thresholds,
        typeof(config.solver.initialization_backend),
        config.solver.multi_start.enabled,
        config.solver.multi_start.starts,
        config.solver.multi_start.start_index,
        LOCALIZATION_GRADIENT_CONTRACT,
        JOINT_UPDATE_CONTRACT,
    )
    # Strict keeps the historical representation byte-for-byte. Diagnostic
    # construction is a different trajectory and can never match a legacy hash.
    if config.input.construction_policy != :strict
        contract = (contract..., "construction_policy_v1", config.input.construction_policy)
    end
    if config.solver.initialization_backend isa PAWSCDMInitialization
        artifact = something(config.solver.paw_scdm_input_hdf5)
        artifact_sha256 =
            isfile(artifact) ? open(filename -> bytes2hex(SHA.sha256(filename)), artifact, "r") :
            "UNRESOLVED_INTERNAL_SCDM_ARTIFACT"
        return repr((contract..., artifact_sha256))
    end
    return repr(contract)
end

# Render an older append-only acceleration struct without changing any field value.
function _legacy_acceleration_repr(
    acceleration::WannierizationAccelerationConfig,
    final_field::Symbol,
)
    names = fieldnames(typeof(acceleration))
    final_index = findfirst(==(final_field), names)
    final_index === nothing && error("legacy acceleration boundary $(final_field) is missing")
    values = [getfield(acceleration, index) for index in 1:something(final_index)]
    return string(typeof(acceleration), "(", join(repr.(values), ", "), ")")
end

# Replace the current acceleration value in one restart representation exactly once.
function _restart_repr_with_legacy_acceleration(
    config::SymmetryAdaptedWannierizationConfig,
    representation::String,
    final_field::Symbol,
)
    legacy = _legacy_acceleration_repr(config.solver.acceleration, final_field)
    output = replace(representation, repr(config.solver.acceleration) => legacy; count = 1)
    output == representation && error("legacy acceleration repr replacement failed")
    return output
end

# Reproduce schema 2.11, where the implicit wavefunction gauge was native eigenstates.
function _legacy_restart_config_sha256_pre_v2_12(
    config::SymmetryAdaptedWannierizationConfig,
)::Union{Nothing, String}
    config.input.construction_policy == :strict || return nothing
    config.input.wavefunction_gauge_backend isa NativeEigenstateGauge || return nothing
    config.input.wavefunction_gauge_hdf5 === nothing || return nothing
    representation = repr((
        _restart_config_values(config)...,
        band_sewing_backend_key(config.input.sewing_backend),
        config.input.sewing_backend isa AugmentationAwareSewing ?
        repr(config.input.sewing_backend.thresholds) : "NOT_APPLICABLE",
        LOCALIZATION_GRADIENT_CONTRACT,
        JOINT_UPDATE_CONTRACT,
    ))
    return bytes2hex(SHA.sha256(codeunits(representation)))
end

# Reproduce schema 2.10, where the implicit backend was coefficient mapping.
function _legacy_restart_config_sha256_pre_v2_11(
    config::SymmetryAdaptedWannierizationConfig,
)::Union{Nothing, String}
    config.input.construction_policy == :strict || return nothing
    config.input.sewing_backend isa CoefficientMappingSewing || return nothing
    representation = repr((
        _restart_config_values(config)...,
        LOCALIZATION_GRADIENT_CONTRACT,
        JOINT_UPDATE_CONTRACT,
    ))
    return bytes2hex(SHA.sha256(codeunits(representation)))
end

# Reproduce schema 2.9 before the centered-residual chart and six expert U controls.
function _legacy_restart_config_sha256_pre_v2_10(
    config::SymmetryAdaptedWannierizationConfig,
)::Union{Nothing, String}
    config.input.construction_policy == :strict || return nothing
    acceleration = config.solver.acceleration
    acceleration.u_phase_branch_tolerance == 1.0e-6 || return nothing
    acceleration.u_branch_active_set_max_orbits == 64 || return nothing
    acceleration.u_lbfgs_history == 8 || return nothing
    acceleration.u_lbfgs_curvature_tolerance == 1.0e-12 || return nothing
    acceleration.u_wolfe_c2 == 0.9 || return nothing
    acceleration.u_line_search_max_trials == 24 || return nothing
    representation =
        repr((_restart_config_values(config)..., "mv_q_unwrapped_center_v1", JOINT_UPDATE_CONTRACT))
    legacy =
        _restart_repr_with_legacy_acceleration(config, representation, :constraint_operation_scope)
    return bytes2hex(SHA.sha256(codeunits(legacy)))
end

# Reproduce schema 2.8 before the constraint-operation scope was appended.
function _legacy_restart_config_sha256_pre_v2_9(
    config::SymmetryAdaptedWannierizationConfig,
)::Union{Nothing, String}
    config.input.construction_policy == :strict || return nothing
    config.solver.acceleration.constraint_operation_scope == :full || return nothing
    representation =
        repr((_restart_config_values(config)..., "mv_q_unwrapped_center_v1", JOINT_UPDATE_CONTRACT))
    legacy = _restart_repr_with_legacy_acceleration(
        config,
        representation,
        :joint_z_backtracking_max_steps,
    )
    return bytes2hex(SHA.sha256(codeunits(legacy)))
end

# Reproduce schema 2.7 before the joint contract and three expert controls existed.
function _legacy_restart_config_sha256_pre_v2_8(
    config::SymmetryAdaptedWannierizationConfig,
)::Union{Nothing, String}
    config.input.construction_policy == :strict || return nothing
    acceleration = config.solver.acceleration
    acceleration.disentanglement_limit_policy == :diagnostic_continue || return nothing
    acceleration.joint_z_backtracking_factor == 0.5 || return nothing
    acceleration.joint_z_backtracking_max_steps == 12 || return nothing
    acceleration.constraint_operation_scope == :full || return nothing
    representation = repr((_restart_config_values(config)..., "mv_q_unwrapped_center_v1"))
    legacy =
        _restart_repr_with_legacy_acceleration(config, representation, :u_cg_minimum_descent_cosine)
    return bytes2hex(SHA.sha256(codeunits(legacy)))
end

# Reproduce schema 2.6 before the localization-gradient and joint contracts.
function _legacy_restart_config_sha256_pre_v2_7(
    config::SymmetryAdaptedWannierizationConfig,
)::Union{Nothing, String}
    config.input.construction_policy == :strict || return nothing
    acceleration = config.solver.acceleration
    acceleration.disentanglement_limit_policy == :diagnostic_continue || return nothing
    acceleration.joint_z_backtracking_factor == 0.5 || return nothing
    acceleration.joint_z_backtracking_max_steps == 12 || return nothing
    acceleration.constraint_operation_scope == :full || return nothing
    representation = repr(_restart_config_values(config))
    legacy =
        _restart_repr_with_legacy_acceleration(config, representation, :u_cg_minimum_descent_cosine)
    return bytes2hex(SHA.sha256(codeunits(legacy)))
end

# Reproduce the exact schema-2.4/2.5 acceleration representation.
function _legacy_restart_config_sha256_pre_v2_6(
    config::SymmetryAdaptedWannierizationConfig,
)::Union{Nothing, String}
    config.input.construction_policy == :strict || return nothing
    acceleration = config.solver.acceleration
    acceleration.u_cg_restart_interval == 20 || return nothing
    acceleration.u_cg_beta_cap == 10.0 || return nothing
    acceleration.u_cg_minimum_descent_cosine == 1.0e-3 || return nothing
    acceleration.disentanglement_limit_policy == :diagnostic_continue || return nothing
    acceleration.joint_z_backtracking_factor == 0.5 || return nothing
    acceleration.joint_z_backtracking_max_steps == 12 || return nothing
    acceleration.constraint_operation_scope == :full || return nothing
    acceleration.localization_algorithm in (:symmetry_projected_gradient, :polar_then_gradient) ||
        return nothing
    current_repr = repr(_restart_config_values(config))
    legacy_repr =
        _restart_repr_with_legacy_acceleration(config, current_repr, :anderson_regularization)
    return bytes2hex(SHA.sha256(codeunits(legacy_repr)))
end

"""Build the immutable current-and-legacy restart identity contract."""
function WannierizationRestartContract(
    config::SymmetryAdaptedWannierizationConfig;
    effective_algorithms = effective_wannierization_algorithms(config),
    apply_symmetry::Bool = symmetry_constraints_applied(config),
)
    values = _restart_config_values(config, apply_symmetry)
    canonical_representation = _restart_config_repr(config, effective_algorithms, apply_symmetry)
    current_sha256 = bytes2hex(SHA.sha256(codeunits(canonical_representation)))
    legacy_sha256 = (
        pre_v2_12 = _legacy_restart_config_sha256_pre_v2_12(config),
        pre_v2_11 = _legacy_restart_config_sha256_pre_v2_11(config),
        pre_v2_10 = _legacy_restart_config_sha256_pre_v2_10(config),
        pre_v2_9 = _legacy_restart_config_sha256_pre_v2_9(config),
        pre_v2_8 = _legacy_restart_config_sha256_pre_v2_8(config),
        pre_v2_7 = _legacy_restart_config_sha256_pre_v2_7(config),
        pre_v2_6 = _legacy_restart_config_sha256_pre_v2_6(config),
    )
    return WannierizationRestartContract(
        values,
        canonical_representation,
        current_sha256,
        legacy_sha256,
    )
end

# Preserve the expert digest entrypoints while making the immutable contract
# their single owner. The hot current-digest path is intentionally lazy: it
# must not allocate the seven legacy representations unless a compatibility
# check explicitly requests them.
function _current_restart_config_sha256(
    config::SymmetryAdaptedWannierizationConfig;
    effective_algorithms = effective_wannierization_algorithms(config),
    apply_symmetry::Bool = symmetry_constraints_applied(config),
)
    representation = _restart_config_repr(config, effective_algorithms, apply_symmetry)
    return bytes2hex(SHA.sha256(codeunits(representation)))
end

"""Digest a configuration without materializing any legacy digest variants."""
_restart_config_sha256(config::SymmetryAdaptedWannierizationConfig) =
    _current_restart_config_sha256(config)

"""Digest a configuration using the effective loaded representation route."""
function _restart_config_sha256(
    config::SymmetryAdaptedWannierizationConfig,
    representation::BandRepresentation,
)
    return _current_restart_config_sha256(
        config;
        effective_algorithms = effective_wannierization_algorithms(config, representation),
        apply_symmetry = symmetry_constraints_applied(config, representation),
    )
end

"""Return the accepted pre-v2.12 restart digest when applicable."""
_restart_config_sha256_pre_v2_12(config::SymmetryAdaptedWannierizationConfig) =
    _legacy_restart_config_sha256_pre_v2_12(config)
"""Return the accepted pre-v2.11 restart digest when applicable."""
_restart_config_sha256_pre_v2_11(config::SymmetryAdaptedWannierizationConfig) =
    _legacy_restart_config_sha256_pre_v2_11(config)
"""Return the accepted pre-v2.10 restart digest when applicable."""
_restart_config_sha256_pre_v2_10(config::SymmetryAdaptedWannierizationConfig) =
    _legacy_restart_config_sha256_pre_v2_10(config)
"""Return the accepted pre-v2.9 restart digest when applicable."""
_restart_config_sha256_pre_v2_9(config::SymmetryAdaptedWannierizationConfig) =
    _legacy_restart_config_sha256_pre_v2_9(config)
"""Return the accepted pre-v2.8 restart digest when applicable."""
_restart_config_sha256_pre_v2_8(config::SymmetryAdaptedWannierizationConfig) =
    _legacy_restart_config_sha256_pre_v2_8(config)
"""Return the accepted pre-v2.7 restart digest when applicable."""
_restart_config_sha256_pre_v2_7(config::SymmetryAdaptedWannierizationConfig) =
    _legacy_restart_config_sha256_pre_v2_7(config)
"""Return the accepted pre-v2.6 restart digest when applicable."""
_restart_config_sha256_pre_v2_6(config::SymmetryAdaptedWannierizationConfig) =
    _legacy_restart_config_sha256_pre_v2_6(config)
