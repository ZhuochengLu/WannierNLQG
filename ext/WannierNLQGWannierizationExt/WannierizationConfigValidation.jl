"""Return the native input group without exposing flat SAW properties."""
_wannierization_input_config(config::SymmetryAdaptedWannierizationConfig) = config.input
# Preserve the already-flat preparation config through the same narrow adapter.
_wannierization_input_config(config::BandRepresentationPreparationConfig) = config

# Enforce the independent sewing-metric and wavefunction-gauge identities.
function _validate_wavefunction_gauge_contract(config)
    backend = _wannierization_input_config(config).wavefunction_gauge_backend
    artifact = _wannierization_input_config(config).wavefunction_gauge_hdf5
    authority = _wannierization_input_config(config).authoritative_hamiltonian
    authority isa Union{NativeDFTHamiltonian, SymmetrizedDFTHamiltonian} ||
        throw(ArgumentError("unsupported authoritative Hamiltonian $(typeof(authority))"))
    if is_symmetrized_authority(authority)
        backend isa StarCovariantPAWGauge || throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: symmetrized authority requires StarCovariantPAWGauge",
            ),
        )
        _wannierization_input_config(config).sewing_backend isa AugmentationAwareSewing || throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: symmetrized authority requires AugmentationAwareSewing",
            ),
        )
        backend.hamiltonian_correction isa FarBandCovarianceCorrection || throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: symmetrized authority requires FarBandCovarianceCorrection",
            ),
        )
    end
    if backend isa NativeEigenstateGauge
        artifact === nothing || throw(
            ArgumentError(
                "WAVEFUNCTION_GAUGE_BACKEND_MISMATCH: native_eigenstate cannot consume a " *
                "star-covariant gauge artifact",
            ),
        )
        return nothing
    end
    backend isa StarCovariantPAWGauge ||
        throw(ArgumentError("unsupported wavefunction gauge backend $(typeof(backend))"))
    _wannierization_input_config(config).sewing_backend isa AugmentationAwareSewing || throw(
        ArgumentError(
            "WAVEFUNCTION_GAUGE_BACKEND_MISMATCH: star_covariant_paw requires " *
            "AugmentationAwareSewing",
        ),
    )
    _wannierization_input_config(config).sewing_backend.thresholds.target_leakage_weight ==
    backend.thresholds.target_leakage_weight || throw(
        ArgumentError(
            "TARGET_SUBSPACE_CONTRACT_MISMATCH: sewing and star-gauge target leakage-weight thresholds differ",
        ),
    )
    _effective_wannierization_mode(config) == :symmetry_adapted || throw(
        ArgumentError(
            "WAVEFUNCTION_GAUGE_BACKEND_MISMATCH: star_covariant_paw requires " *
            "wannierization_mode=:symmetry_adapted",
        ),
    )
    artifact === nothing && throw(
        ArgumentError(
            "WAVEFUNCTION_GAUGE_ARTIFACT_REQUIRED: star_covariant_paw requires " *
            "wavefunction_gauge_hdf5",
        ),
    )
    if _representation_source(config) == :detected
        source = _wannierization_input_config(config).source
        source isa Union{QuantumEspressoWavefunctionSource, VASPWavefunctionSource} ||
            throw(ArgumentError("star_covariant_paw requires a QE or VASP native source"))
        source.representation_cutoff_ev === nothing || throw(
            ArgumentError(
                "PAW_GAUGE_FULL_CUTOFF_REQUIRED: representation_cutoff_ev must be nothing",
            ),
        )
    elseif _wannierization_input_config(config).source !== nothing
        source = _wannierization_input_config(config).source
        source isa Union{QuantumEspressoWavefunctionSource, VASPWavefunctionSource} || throw(
            ArgumentError(
                "a provided star_covariant_paw representation accepts only an optional QE or VASP source",
            ),
        )
        source.representation_cutoff_ev === nothing || throw(
            ArgumentError(
                "PAW_GAUGE_FULL_CUTOFF_REQUIRED: representation_cutoff_ev must be nothing",
            ),
        )
    end
    return nothing
end

# Keep the physical constraint mode independent of the sewing metric. PAW
# augmentation data may seed an ordinary no-symmetry calculation without
# activating any SAWF constraint.
function _validate_wannierization_mode_contract(config)
    _wannierization_input_config(config).wannierization_mode in
    (:auto, :ordinary, :symmetry_adapted) ||
        throw(ArgumentError("wannierization_mode must be :auto, :ordinary, or :symmetry_adapted"))
    config isa BandRepresentationPreparationConfig && return nothing
    config.solver.algorithm_profile in (:auto, :custom) ||
        throw(ArgumentError("algorithm_profile must be :auto or :custom"))
    validate_smv_fletcher_reeves_two_stage_audit_thresholds(
        config.solver.smv_fletcher_reeves_two_stage_audit_thresholds,
    )
    return nothing
end

"""Resolve the sole public mode tag. `:auto` retains the SAWF default."""
_effective_wannierization_mode(config) =
    _wannierization_input_config(config).wannierization_mode == :auto ? :symmetry_adapted :
    _wannierization_input_config(config).wannierization_mode

"""Infer whether the representation is identity, detected, or supplied."""
function _representation_source(config)
    mode = _effective_wannierization_mode(config)
    representation_count =
        Int(_wannierization_input_config(config).band_representation !== nothing) +
        Int(_wannierization_input_config(config).band_representation_hdf5 !== nothing)
    representation_count <= 1 || throw(
        ArgumentError(
            "REPRESENTATION_SOURCE_CONFLICT: supply at most one in-memory or HDF5 representation",
        ),
    )
    if mode == :ordinary
        _wannierization_input_config(config).band_representation === nothing || throw(
            ArgumentError(
                "ORDINARY_IDENTITY_REPRESENTATION_REQUIRED: ordinary mode does not accept an " *
                "in-memory non-identity representation; omit it or provide a sealed identity HDF5 artifact",
            ),
        )
        return representation_count == 0 ? :identity : :provided
    end
    representation_count == 1 && return :provided
    _wannierization_input_config(config).source !== nothing || throw(
        ArgumentError(
            "REPRESENTATION_SOURCE_MISSING: symmetry_adapted mode requires a native source " *
            "for detection or exactly one supplied representation",
        ),
    )
    return :detected
end

"""Return whether a non-solver configuration can select the identity-group fast path."""
_configured_identity_group_fast_path(config) = false

"""Return whether the configured in-memory representation is exactly the identity group."""
function _configured_identity_group_fast_path(config::SymmetryAdaptedWannierizationConfig)
    representation = _wannierization_input_config(config).band_representation
    representation === nothing && return false
    if representation.schema_version == "1.0"
        all(
            key -> haskey(representation.conventions, key),
            (
                "requested_wannierization_mode",
                "effective_wannierization_mode",
                "representation_source",
                "symmetry_constraints_applied",
            ),
        ) || return false
        validate_unified_representation_mode_contract(representation)
    else
        representation.schema_version in ("1.15", "1.16", "1.17") || return false
    end
    return is_identity_group_representation(representation)
end

"""Resolve the identity-group fast path after an HDF5 representation is loaded."""
function _configured_identity_group_fast_path(config, representation::BandRepresentation)
    _effective_wannierization_mode(config) == :symmetry_adapted || return false
    if representation.schema_version == "1.0"
        all(
            key -> haskey(representation.conventions, key),
            (
                "requested_wannierization_mode",
                "effective_wannierization_mode",
                "representation_source",
                "symmetry_constraints_applied",
            ),
        ) || return false
        validate_unified_representation_mode_contract(representation)
    else
        representation.schema_version in ("1.15", "1.16", "1.17") || return false
    end
    return is_identity_group_representation(representation)
end

"""Return whether the selected Wannierization mode enforces nontrivial symmetry constraints."""
function _symmetry_constraints_applied(config)
    _effective_wannierization_mode(config) == :symmetry_adapted || return false
    return !_configured_identity_group_fast_path(config)
end

"""Resolve symmetry application against the authoritative loaded representation."""
function _symmetry_constraints_applied(config, representation::BandRepresentation)
    _effective_wannierization_mode(config) == :symmetry_adapted || return false
    return !_configured_identity_group_fast_path(config, representation)
end

"""Resolve the active Z/U algorithms without coupling provenance to constraints."""
function _effective_wannierization_algorithms(config::SymmetryAdaptedWannierizationConfig)
    if config.solver.algorithm_profile == :custom
        return (
            disentanglement = config.solver.acceleration.disentanglement_algorithm,
            localization = config.solver.acceleration.localization_algorithm,
            profile = :custom,
            default_selection_reason = "EXPLICIT_CUSTOM",
        )
    end
    if _effective_wannierization_mode(config) == :ordinary
        return (
            disentanglement = :smv_fletcher_reeves_two_stage,
            localization = :smv_fletcher_reeves_two_stage,
            profile = :smv_fletcher_reeves_two_stage,
            default_selection_reason = "UNCONDITIONAL_ORDINARY_DEFAULT",
        )
    end
    if _configured_identity_group_fast_path(config)
        return (
            disentanglement = :smv_fletcher_reeves_two_stage,
            localization = :smv_fletcher_reeves_two_stage,
            profile = :symmetry_projected_smv_fletcher_reeves_two_stage,
            default_selection_reason = "IDENTITY_GROUP_EXACT_ORDINARY_FAST_PATH",
        )
    end
    return (
        disentanglement = :symmetry_projected_smv_fletcher_reeves_two_stage,
        localization = :symmetry_projected_smv_fletcher_reeves_two_stage,
        profile = :symmetry_projected_smv_fletcher_reeves_two_stage,
        default_selection_reason = "UNCONDITIONAL_SYMMETRY_PROJECTED_DEFAULT",
    )
end

"""Resolve Z/U algorithms after a supplied representation has been loaded."""
function _effective_wannierization_algorithms(
    config::SymmetryAdaptedWannierizationConfig,
    representation::BandRepresentation,
)
    if config.solver.algorithm_profile == :auto &&
       _configured_identity_group_fast_path(config, representation)
        return (
            disentanglement = :smv_fletcher_reeves_two_stage,
            localization = :smv_fletcher_reeves_two_stage,
            profile = :symmetry_projected_smv_fletcher_reeves_two_stage,
            default_selection_reason = "IDENTITY_GROUP_EXACT_ORDINARY_FAST_PATH",
        )
    end
    return _effective_wannierization_algorithms(config)
end

"""Validate the standalone star-covariant PAW preparation contract."""
function _validate_symmetry_covariant_wavefunction_preparation_config(
    config::SymmetryCovariantWavefunctionPreparationConfig,
)
    config.construction_policy in (:diagnostic, :strict) ||
        throw(ArgumentError("construction_policy must be :diagnostic or :strict"))
    config.sewing_backend isa AugmentationAwareSewing || throw(
        ArgumentError("star-covariant wavefunction preparation requires AugmentationAwareSewing"),
    )
    config.wavefunction_gauge_backend isa StarCovariantPAWGauge ||
        throw(ArgumentError("standalone preparation requires StarCovariantPAWGauge"))
    config.authoritative_hamiltonian isa Union{NativeDFTHamiltonian, SymmetrizedDFTHamiltonian} ||
        throw(ArgumentError("unsupported authoritative Hamiltonian"))
    contract = config.target_subspace_contract
    if is_symmetrized_authority(config.authoritative_hamiltonian)
        contract === nothing && throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_REQUIRED: SymmetrizedDFTHamiltonian requires an explicit target-subspace contract",
            ),
        )
    end
    if contract !== nothing
        scope = contract.qualification_scope
        size(scope.outer_mask) == size(scope.frozen_mask) ||
            throw(ArgumentError("target-subspace masks must have identical dimensions"))
        size(scope.outer_mask, 2) > 0 ||
            throw(ArgumentError("target-subspace masks must contain at least one k point"))
        source_band_range = config.source.band_range
        source_band_range === nothing ||
            size(scope.outer_mask, 1) == length(source_band_range) ||
            throw(
                ArgumentError(
                    "TARGET_SUBSPACE_DIMENSION_MISMATCH: mask band dimension differs from source.band_range",
                ),
            )
        if config.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian
            config.authoritative_hamiltonian.completion.target_complement_max_element_ev ==
            contract.target_complement_maximum_element_ev || throw(
                ArgumentError(
                    "TARGET_SUBSPACE_CONTRACT_MISMATCH: Hamiltonian completion and contract H_TC thresholds differ",
                ),
            )
        end
        gauge_thresholds = config.wavefunction_gauge_backend.thresholds
        contract_thresholds = contract.scoped_paw_thresholds
        all(
            field -> getfield(gauge_thresholds, field) == getfield(contract_thresholds, field),
            fieldnames(PAWGaugeThresholds),
        ) || throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: gauge and scoped PAW thresholds differ",
            ),
        )
        config.sewing_backend.thresholds.target_leakage_weight ==
        contract_thresholds.target_leakage_weight || throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: sewing and scoped target leakage-weight thresholds differ",
            ),
        )
    end
    if is_symmetrized_authority(config.authoritative_hamiltonian)
        config.wavefunction_gauge_backend.hamiltonian_correction isa FarBandCovarianceCorrection ||
            throw(
                ArgumentError(
                    "HAMILTONIAN_REFERENCE_MISMATCH: symmetrized authority requires FarBandCovarianceCorrection",
                ),
            )
    end
    config.source isa Union{QuantumEspressoWavefunctionSource, VASPWavefunctionSource} ||
        throw(ArgumentError("star-covariant wavefunction preparation requires a QE or VASP source"))
    config.source.representation_cutoff_ev === nothing || throw(
        ArgumentError("PAW_GAUGE_FULL_CUTOFF_REQUIRED: representation_cutoff_ev must be nothing"),
    )
    config.source.band_range === nothing && throw(
        ArgumentError(
            "PAW_GAUGE_TARGET_BANDS_REQUIRED: source.band_range must select target bands",
        ),
    )
    isempty(strip(config.output_hdf5)) && throw(ArgumentError("output_hdf5 must not be empty"))
    config.symmetry_tolerance > 0.0 && isfinite(config.symmetry_tolerance) ||
        throw(ArgumentError("symmetry_tolerance must be positive and finite"))
    config.target_band_count >= 0 || throw(ArgumentError("target_band_count must be nonnegative"))
    config.maximum_star_count === nothing ||
        something(config.maximum_star_count) > 0 ||
        throw(ArgumentError("maximum_star_count must be positive when provided"))
    config.maximum_star_count === nothing ||
        config.selected_star_indices === nothing ||
        throw(ArgumentError("maximum_star_count and selected_star_indices are mutually exclusive"))
    if config.selected_star_indices !== nothing
        selected = something(config.selected_star_indices)
        isempty(selected) && throw(ArgumentError("selected_star_indices must not be empty"))
        all(>(0), selected) || throw(ArgumentError("selected_star_indices must be positive"))
        issorted(selected) || throw(ArgumentError("selected_star_indices must be sorted"))
        length(unique(selected)) == length(selected) ||
            throw(ArgumentError("selected_star_indices must be unique"))
    end
    expected = length(something(config.source.band_range))
    config.target_band_count in (0, expected) ||
        throw(ArgumentError("target_band_count disagrees with source.band_range"))
    config.input_symmetry_audit_json === nothing ||
        isfile(something(config.input_symmetry_audit_json)) ||
        throw(ArgumentError("INPUT_PROVENANCE_HOLD: input symmetry audit JSON does not exist"))
    return nothing
end

# Validate preparation contracts before native wavefunction I/O.
function _validate_band_representation_preparation_config(
    config::BandRepresentationPreparationConfig,
)
    config.construction_policy in (:diagnostic, :strict) ||
        throw(ArgumentError("construction_policy must be :diagnostic or :strict"))
    _validate_wannierization_mode_contract(config)
    representation_source = _representation_source(config)
    if config.sewing_backend isa AugmentationAwareSewing
        if representation_source == :detected
            source = something(config.source)
            source isa Union{QuantumEspressoWavefunctionSource, VASPWavefunctionSource} || throw(
                ArgumentError("augmentation-aware sewing requires a QE or VASP native source"),
            )
            source.representation_cutoff_ev === nothing || throw(
                ArgumentError(
                    "PAW_SEWING_FULL_CUTOFF_REQUIRED: representation_cutoff_ev must be nothing",
                ),
            )
            if source isa VASPWavefunctionSource
                source.potcar_file !== nothing || throw(
                    ArgumentError(
                        "VASP_PAW_DATA_REQUIRED: augmentation-aware sewing requires POTCAR",
                    ),
                )
            end
        end
    end
    config.outer_min_ev <= config.outer_max_ev ||
        throw(ArgumentError("outer_min_ev must not exceed outer_max_ev"))
    (
        config.frozen_min_ev > config.frozen_max_ev ||
        config.outer_min_ev <= config.frozen_min_ev <= config.frozen_max_ev <= config.outer_max_ev
    ) || throw(ArgumentError("frozen window must be empty or contained in the outer window"))
    config.num_wannier >= 0 || throw(ArgumentError("num_wannier must be nonnegative"))
    all(state -> state[1] > 0 && state[2] > 0, config.frozen_states) ||
        throw(ArgumentError("frozen_states entries must contain positive one-based indices"))
    config.symmetry_tolerance > 0.0 && isfinite(config.symmetry_tolerance) ||
        throw(ArgumentError("symmetry_tolerance must be positive and finite"))
    config.degeneracy_tolerance_ev > 0.0 && isfinite(config.degeneracy_tolerance_ev) ||
        throw(ArgumentError("degeneracy_tolerance_ev must be positive and finite"))
    config.representation_tolerance > 0.0 && isfinite(config.representation_tolerance) ||
        throw(ArgumentError("representation_tolerance must be positive and finite"))
    config.target_center_matching_tolerance > 0.0 &&
    isfinite(config.target_center_matching_tolerance) ||
        throw(ArgumentError("target_center_matching_tolerance must be positive and finite"))
    config.compatibility_policy in (:strict, :warn, :off) ||
        throw(ArgumentError("compatibility_policy must be :strict, :warn, or :off"))
    _validate_wavefunction_gauge_contract(config)
    return nothing
end

# Validate all scalar configuration contracts before any expensive I/O.
function _validate_wannierization_config(config::SymmetryAdaptedWannierizationConfig)
    config.input.construction_policy in (:diagnostic, :strict) ||
        throw(ArgumentError("construction_policy must be :diagnostic or :strict"))
    _validate_wannierization_mode_contract(config)
    representation_source = _representation_source(config)
    if _effective_wannierization_mode(config) == :ordinary
        config.solver.initialization != :fixed_subspace || throw(
            ArgumentError("initialization=:fixed_subspace requires a symmetry-constrained mode"),
        )
    end
    if config.input.sewing_backend isa AugmentationAwareSewing
        if representation_source == :detected
            source = something(config.input.source)
            source isa Union{QuantumEspressoWavefunctionSource, VASPWavefunctionSource} || throw(
                ArgumentError("augmentation-aware sewing requires a QE or VASP native source"),
            )
            source.representation_cutoff_ev === nothing || throw(
                ArgumentError(
                    "PAW_SEWING_FULL_CUTOFF_REQUIRED: representation_cutoff_ev must be nothing",
                ),
            )
            if source isa VASPWavefunctionSource
                source.potcar_file !== nothing || throw(
                    ArgumentError(
                        "VASP_PAW_DATA_REQUIRED: augmentation-aware sewing requires POTCAR",
                    ),
                )
            end
        end
    end
    config.input.outer_min_ev <= config.input.outer_max_ev ||
        throw(ArgumentError("outer_min_ev must not exceed outer_max_ev"))
    (
        config.input.frozen_min_ev > config.input.frozen_max_ev ||
        config.input.outer_min_ev <=
        config.input.frozen_min_ev <=
        config.input.frozen_max_ev <=
        config.input.outer_max_ev
    ) || throw(ArgumentError("frozen window must be empty or contained in the outer window"))
    config.solver.initialization in (:amn, :random, :restart, :fixed_subspace) ||
        throw(ArgumentError("initialization must be :amn, :random, :restart, or :fixed_subspace"))
    if config.input.matrix_elements isa ExternalWannier90Matrices
        external = config.input.matrix_elements::ExternalWannier90Matrices
        config.input.mmn_file == external.mmn_file ||
            throw(ArgumentError("matrix_elements MMN path disagrees with legacy mmn_file"))
        config.input.amn_file === nothing ||
            config.input.amn_file == external.amn_file ||
            throw(ArgumentError("matrix_elements AMN path disagrees with legacy amn_file"))
    elseif config.input.matrix_elements isa NativeVASPPAWMatrices
        config.input.source isa VASPWavefunctionSource || throw(
            ArgumentError("VASP_PAW_DATA_REQUIRED: NativeVASPPAWMatrices requires a VASP source"),
        )
        vasp_source = config.input.source::VASPWavefunctionSource
        vasp_source.potcar_file !== nothing ||
            throw(ArgumentError("VASP_PAW_DATA_REQUIRED: native VASP PAW matrices require POTCAR"))
        vasp_source.outcar_file !== nothing || throw(
            ArgumentError(
                "VASP_PAW_OUTCAR_REQUIRED: native VASP PAW AMN requires the same-run OUTCAR",
            ),
        )
        vasp_source.representation_cutoff_ev === nothing || throw(
            ArgumentError(
                "VASP_PAW_RAW_COEFFICIENTS_REQUIRED: native PAW matrices require full cutoff",
            ),
        )
    elseif config.input.matrix_elements isa SymmetryCompletedQEPAWMatrices
        config.input.source isa QuantumEspressoWavefunctionSource || throw(
            ArgumentError(
                "QE_AUGMENTATION_METRIC_REQUIRED: SymmetryCompletedQEPAWMatrices requires a QE source",
            ),
        )
        qe_source = config.input.source::QuantumEspressoWavefunctionSource
        qe_source.representation_cutoff_ev === nothing || throw(
            ArgumentError(
                "QE_PAW_RAW_COEFFICIENTS_REQUIRED: completed QE matrices require full cutoff",
            ),
        )
        qe_source.band_range === nothing && throw(
            ArgumentError(
                "PAW_GAUGE_TARGET_BANDS_REQUIRED: completed QE matrices require source.band_range",
            ),
        )
    elseif config.input.matrix_elements isa NativeQEPAWMatrices
        config.input.source isa QuantumEspressoWavefunctionSource || throw(
            ArgumentError(
                "QE_AUGMENTATION_METRIC_REQUIRED: NativeQEPAWMatrices requires a QE source",
            ),
        )
        qe_source = config.input.source::QuantumEspressoWavefunctionSource
        qe_source.representation_cutoff_ev === nothing || throw(
            ArgumentError(
                "QE_PAW_RAW_COEFFICIENTS_REQUIRED: native QE matrices require the full wavefunction cutoff",
            ),
        )
        qe_source.band_range === nothing || throw(
            ArgumentError(
                "QE_NNKP_BAND_AUTHORITY_REQUIRED: excluded bands must come only from the NNKP file",
            ),
        )
    end
    if config.solver.initialization == :amn &&
       config.input.source isa VASPWavefunctionSource &&
       config.input.matrix_elements === nothing &&
       config.input.amn_file === nothing
        throw(
            ArgumentError(
                "VASP_PAW_AMN_REQUIRED: VASP initialization requires external or native PAW AMN",
            ),
        )
    end
    config.solver.initialization == :fixed_subspace &&
        config.checkpoint.fixed_subspace_hdf5 === nothing &&
        throw(ArgumentError("fixed_subspace_hdf5 is required for initialization=:fixed_subspace"))
    config.solver.initialization != :fixed_subspace &&
        config.checkpoint.fixed_subspace_hdf5 !== nothing &&
        throw(ArgumentError("fixed_subspace_hdf5 requires initialization=:fixed_subspace"))
    config.solver.parallel in (:serial, :threads, :mpi) ||
        throw(ArgumentError("parallel must be :serial, :threads, or :mpi"))
    config.input.compatibility_policy in (:strict, :warn, :off) ||
        throw(ArgumentError("compatibility_policy must be :strict, :warn, or :off"))
    0.0 <= config.solver.z_mix_ratio <= 1.0 || throw(ArgumentError("z_mix_ratio must be in [0, 1]"))
    0.0 <= config.solver.u_mix_ratio <= 1.0 || throw(ArgumentError("u_mix_ratio must be in [0, 1]"))
    config.solver.max_iterations > 0 || throw(ArgumentError("max_iterations must be positive"))
    config.solver.convergence_window > 0 ||
        throw(ArgumentError("convergence_window must be positive"))
    config.solver.little_group_max_iterations > 0 ||
        throw(ArgumentError("little_group_max_iterations must be positive"))
    config.solver.convergence_tolerance > 0.0 && isfinite(config.solver.convergence_tolerance) ||
        throw(ArgumentError("convergence_tolerance must be positive and finite"))
    config.solver.little_group_tolerance > 0.0 && isfinite(config.solver.little_group_tolerance) ||
        throw(ArgumentError("little_group_tolerance must be positive and finite"))
    config.input.degeneracy_tolerance_ev > 0.0 && isfinite(config.input.degeneracy_tolerance_ev) ||
        throw(ArgumentError("degeneracy_tolerance_ev must be positive and finite"))
    config.input.representation_tolerance > 0.0 &&
    isfinite(config.input.representation_tolerance) ||
        throw(ArgumentError("representation_tolerance must be positive and finite"))
    config.input.symmetry_tolerance > 0.0 && isfinite(config.input.symmetry_tolerance) ||
        throw(ArgumentError("symmetry_tolerance must be positive and finite"))
    config.input.empirical_covariance_budget === nothing ||
        (
            isfinite(something(config.input.empirical_covariance_budget)) &&
            something(config.input.empirical_covariance_budget) > 0.0
        ) ||
        throw(ArgumentError("empirical_covariance_budget must be positive and finite"))
    config.input.target_center_matching_tolerance > 0.0 &&
    isfinite(config.input.target_center_matching_tolerance) ||
        throw(ArgumentError("target_center_matching_tolerance must be positive and finite"))
    config.runtime.progress_interval >= 0 ||
        throw(ArgumentError("progress_interval must be nonnegative"))
    config.checkpoint.checkpoint_interval >= 0 ||
        throw(ArgumentError("checkpoint_interval must be nonnegative"))
    config.runtime.iteration_observer === nothing ||
        config.runtime.iteration_observer isa Function ||
        throw(ArgumentError("iteration_observer must be nothing or callable"))
    allowed_formats = (:packed_hdf5, :wannier90_tb)
    all(format -> format in allowed_formats, config.output.tb_output_formats) ||
        throw(ArgumentError("tb_output_formats accepts only :packed_hdf5 and :wannier90_tb"))
    length(unique(config.output.tb_output_formats)) == length(config.output.tb_output_formats) ||
        throw(ArgumentError("tb_output_formats must not contain duplicates"))
    config.output.final_tb_symmetry_report_enabled === nothing ||
        config.output.final_tb_symmetry_report_enabled isa Bool ||
        throw(ArgumentError("final_tb_symmetry_report_enabled must be nothing or Bool"))
    config.output.profile == :spin && throw(
        ArgumentError("profile=:spin was removed; migrate to profile=:hamiltonian_position_spin"),
    )
    config.output.profile in (:hamiltonian_position, :hamiltonian_position_spin, :full) || throw(
        ArgumentError(
            "profile must be :hamiltonian_position, :hamiltonian_position_spin, or :full",
        ),
    )
    isfinite(config.output.operator_closure_tolerance) &&
    config.output.operator_closure_tolerance > 0.0 || throw(
        ArgumentError(
            "operator_closure_tolerance diagnostic reference must be positive and finite",
        ),
    )
    isfinite(config.output.spin_family_covariance_tolerance) &&
    config.output.spin_family_covariance_tolerance > 0.0 ||
        throw(ArgumentError("spin_family_covariance_tolerance must be positive and finite"))
    isfinite(config.output.spin_family_idempotence_tolerance) &&
    config.output.spin_family_idempotence_tolerance > 0.0 ||
        throw(ArgumentError("spin_family_idempotence_tolerance must be positive and finite"))
    if config.output.profile in (:hamiltonian_position_spin, :full)
        config.output.spn_file === nothing &&
            throw(ArgumentError("SPN_FILE_REQUIRED: selected output profile requires spn_file"))
        config.output.spn_provenance_file === nothing && throw(
            ArgumentError(
                "SPN_PROVENANCE_REQUIRED: selected output profile requires spn_provenance_file",
            ),
        )
        isempty(strip(something(config.output.spn_provenance_file))) &&
            throw(ArgumentError("SPN_PROVENANCE_REQUIRED: spn_provenance_file must not be empty"))
    end
    if config.output.profile == :full
        for (label, value) in (
            ("uiu_file", config.output.uiu_file),
            ("uhu_file", config.output.uhu_file),
            ("siu_file", config.output.siu_file),
            ("shu_file", config.output.shu_file),
            ("uiu_provenance_json", config.output.uiu_provenance_json),
            ("uhu_provenance_json", config.output.uhu_provenance_json),
            ("siu_provenance_json", config.output.siu_provenance_json),
            ("shu_provenance_json", config.output.shu_provenance_json),
        )
            value === nothing && throw(
                ArgumentError("FULL_OPERATOR_INPUT_REQUIRED: profile=:full requires $(label)"),
            )
        end
    end
    acceleration = config.solver.acceleration
    acceleration.strategy in (:fixed, :adaptive, :anderson_z) ||
        throw(ArgumentError("acceleration strategy must be :fixed, :adaptive, or :anderson_z"))
    acceleration.schedule == :nested && throw(
        ArgumentError(
            "UNSUPPORTED_LEGACY_SCHEDULE: schedule=:nested was removed; use schedule=:two_stage",
        ),
    )
    acceleration.schedule in (:two_stage, :joint, :fixed_subspace) ||
        throw(ArgumentError("acceleration schedule must be :two_stage, :joint, or :fixed_subspace"))
    acceleration.localization_algorithm == :wannier90_fletcher_reeves && throw(
        ArgumentError(
            "REMOVED_LEGACY_LOCALIZATION_ALGORITHM: :wannier90_fletcher_reeves was not " *
            "Wannier90-equivalent; use algorithm_profile=:auto for ordinary no-symmetry " *
            "Wannierization or choose an expert algorithm with algorithm_profile=:custom",
        ),
    )
    acceleration.localization_algorithm in (
        :symmetry_projected_gradient,
        :polar_then_gradient,
        :riemannian_cg,
        :riemannian_lbfgs,
        :smv_fletcher_reeves_two_stage,
        :symmetry_projected_smv_fletcher_reeves_two_stage,
    ) || throw(ArgumentError("unsupported localization_algorithm"))
    acceleration.disentanglement_algorithm in (
        :smv_fixed_point,
        :grassmann_trust_region,
        :smv_fletcher_reeves_two_stage,
        :symmetry_projected_smv_fletcher_reeves_two_stage,
    ) || throw(ArgumentError("unsupported disentanglement_algorithm"))
    acceleration.subspace_gauge_policy == :boundary_cluster_procrustes ||
        throw(ArgumentError("subspace_gauge_policy must be :boundary_cluster_procrustes"))
    acceleration.hot_storage_backend in (:legacy_vector, :contiguous, :auto) ||
        throw(ArgumentError("hot_storage_backend must be :legacy_vector, :contiguous, or :auto"))
    acceleration.u_w90_restart_interval > 0 ||
        throw(ArgumentError("u_w90_restart_interval must be positive"))
    acceleration.u_w90_trial_step > 0.0 && isfinite(acceleration.u_w90_trial_step) ||
        throw(ArgumentError("u_w90_trial_step must be positive and finite"))
    effective_algorithms = _effective_wannierization_algorithms(config)
    effective_algorithms.localization == :smv_fletcher_reeves_two_stage &&
        _symmetry_constraints_applied(config) &&
        throw(
            ArgumentError(
                "WANNIER90_REFERENCE_MODE_MISMATCH: :smv_fletcher_reeves_two_stage is valid only for ordinary",
            ),
        )
    effective_algorithms.disentanglement == :smv_fletcher_reeves_two_stage &&
        acceleration.schedule != :two_stage &&
        throw(
            ArgumentError(
                "WANNIER90_REFERENCE_SCHEDULE_MISMATCH: exact Wannier90 disentanglement requires schedule=:two_stage",
            ),
        )
    effective_algorithms.disentanglement == :symmetry_projected_smv_fletcher_reeves_two_stage &&
        acceleration.schedule != :two_stage &&
        throw(
            ArgumentError(
                "SYMMETRY_PROJECTED_SMV_FR_SCHEDULE_MISMATCH: the projected profile requires schedule=:two_stage",
            ),
        )
    0.0 < acceleration.trust_radius_initial <= acceleration.trust_radius_maximum ||
        throw(ArgumentError("trust radii must be positive and ordered"))
    isfinite(acceleration.trust_radius_maximum) ||
        throw(ArgumentError("trust radii must be finite"))
    0.0 < acceleration.trust_acceptance_threshold < 1.0 ||
        throw(ArgumentError("trust_acceptance_threshold must be in (0, 1)"))
    0.0 < acceleration.trust_shrink_threshold < acceleration.trust_expand_threshold < 1.0 ||
        throw(ArgumentError("trust shrink/expand thresholds must be ordered in (0, 1)"))
    config.solver.initialization == :fixed_subspace &&
        acceleration.schedule != :fixed_subspace &&
        throw(ArgumentError("initialization=:fixed_subspace requires schedule=:fixed_subspace"))
    acceleration.schedule == :fixed_subspace &&
        config.solver.initialization != :fixed_subspace &&
        throw(ArgumentError("schedule=:fixed_subspace requires initialization=:fixed_subspace"))
    acceleration.u_acceptance in (:armijo, :strong_wolfe, :monotone, :invariant_only) || throw(
        ArgumentError("u_acceptance must be :armijo, :strong_wolfe, :monotone, or :invariant_only"),
    )
    acceleration.u_initial_step > 0.0 && isfinite(acceleration.u_initial_step) ||
        throw(ArgumentError("u_initial_step must be positive and finite"))
    0.0 < acceleration.u_armijo_c1 < 1.0 || throw(ArgumentError("u_armijo_c1 must be in (0, 1)"))
    (isinf(acceleration.u_max_geodesic_step) || acceleration.u_max_geodesic_step > 0.0) &&
    !isnan(acceleration.u_max_geodesic_step) ||
        throw(ArgumentError("u_max_geodesic_step must be positive or Inf"))
    0.0 < acceleration.u_backtracking_factor < 1.0 ||
        throw(ArgumentError("u_backtracking_factor must be in (0, 1)"))
    acceleration.u_backtracking_max_steps >= 0 ||
        throw(ArgumentError("u_backtracking_max_steps must be nonnegative"))
    acceleration.u_phase_branch_tolerance > 0.0 &&
    isfinite(acceleration.u_phase_branch_tolerance) ||
        throw(ArgumentError("u_phase_branch_tolerance must be positive and finite"))
    acceleration.u_phase_branch_tolerance < pi ||
        throw(ArgumentError("u_phase_branch_tolerance must be smaller than pi"))
    acceleration.u_branch_active_set_max_orbits > 0 ||
        throw(ArgumentError("u_branch_active_set_max_orbits must be positive"))
    acceleration.u_lbfgs_history > 0 || throw(ArgumentError("u_lbfgs_history must be positive"))
    acceleration.u_lbfgs_curvature_tolerance > 0.0 &&
    isfinite(acceleration.u_lbfgs_curvature_tolerance) ||
        throw(ArgumentError("u_lbfgs_curvature_tolerance must be positive and finite"))
    acceleration.u_armijo_c1 < acceleration.u_wolfe_c2 < 1.0 ||
        throw(ArgumentError("u_wolfe_c2 must lie in (u_armijo_c1, 1)"))
    acceleration.u_line_search_max_trials > 0 ||
        throw(ArgumentError("u_line_search_max_trials must be positive"))
    acceleration.u_objective_tolerance >= 0.0 && isfinite(acceleration.u_objective_tolerance) ||
        throw(ArgumentError("u_objective_tolerance must be nonnegative and finite"))
    acceleration.u_gradient_norm_tolerance > 0.0 &&
    isfinite(acceleration.u_gradient_norm_tolerance) ||
        throw(ArgumentError("u_gradient_norm_tolerance must be positive and finite"))
    acceleration.localization_max_steps > 0 ||
        throw(ArgumentError("localization_max_steps must be positive"))
    acceleration.disentanglement_max_steps > 0 ||
        throw(ArgumentError("disentanglement_max_steps must be positive"))
    acceleration.disentanglement_objective_tolerance >= 0.0 &&
    isfinite(acceleration.disentanglement_objective_tolerance) ||
        throw(ArgumentError("disentanglement_objective_tolerance must be nonnegative and finite"))
    acceleration.z_projector_tolerance > 0.0 && isfinite(acceleration.z_projector_tolerance) ||
        throw(ArgumentError("z_projector_tolerance must be positive and finite"))
    acceleration.z_stability_window > 0 ||
        throw(ArgumentError("z_stability_window must be positive"))
    acceleration.disentanglement_limit_policy in (:diagnostic_continue, :strict_hold) || throw(
        ArgumentError("disentanglement_limit_policy must be :diagnostic_continue or :strict_hold"),
    )
    0.0 < acceleration.joint_z_backtracking_factor < 1.0 ||
        throw(ArgumentError("joint_z_backtracking_factor must be in (0, 1)"))
    acceleration.joint_z_backtracking_max_steps >= 0 ||
        throw(ArgumentError("joint_z_backtracking_max_steps must be nonnegative"))
    acceleration.constraint_operation_scope in (:full, :unitary, :identity) ||
        throw(ArgumentError("constraint_operation_scope must be :full, :unitary, or :identity"))
    _effective_wannierization_mode(config) == :ordinary &&
        acceleration.constraint_operation_scope != :full &&
        throw(
            ArgumentError(
                "constraint_operation_scope=:unitary/:identity requires a supplied or detected representation",
            ),
        )
    acceleration.localization_max_condition >= 1.0 &&
    isfinite(acceleration.localization_max_condition) ||
        throw(ArgumentError("localization_max_condition must be finite and at least one"))
    acceleration.polar_warm_start_max_steps >= 0 ||
        throw(ArgumentError("polar_warm_start_max_steps must be nonnegative"))
    acceleration.u_inner_sweeps > 0 || throw(ArgumentError("u_inner_sweeps must be positive"))
    isfinite(acceleration.u_inner_tolerance) && acceleration.u_inner_tolerance > 0.0 ||
        throw(ArgumentError("u_inner_tolerance must be positive and finite"))
    for (name, bounds) in (
        ("adaptive_z_bounds", acceleration.adaptive_z_bounds),
        ("adaptive_u_bounds", acceleration.adaptive_u_bounds),
    )
        0.0 < bounds[1] <= bounds[2] <= 1.0 ||
            throw(ArgumentError("$(name) must be ordered inside (0, 1]"))
    end
    acceleration.adaptive_growth > 1.0 && isfinite(acceleration.adaptive_growth) ||
        throw(ArgumentError("adaptive_growth must be finite and greater than one"))
    0.0 < acceleration.adaptive_shrink < 1.0 ||
        throw(ArgumentError("adaptive_shrink must be in (0, 1)"))
    0.0 < acceleration.adaptive_improvement_ratio <= 1.0 ||
        throw(ArgumentError("adaptive_improvement_ratio must be in (0, 1]"))
    acceleration.adaptive_reject_ratio > 1.0 ||
        throw(ArgumentError("adaptive_reject_ratio must exceed one"))
    acceleration.adaptive_patience > 0 || throw(ArgumentError("adaptive_patience must be positive"))
    acceleration.anderson_depth > 0 || throw(ArgumentError("anderson_depth must be positive"))
    acceleration.anderson_start_iteration > 0 ||
        throw(ArgumentError("anderson_start_iteration must be positive"))
    acceleration.anderson_regularization >= 0.0 && isfinite(acceleration.anderson_regularization) ||
        throw(ArgumentError("anderson_regularization must be nonnegative and finite"))
    acceleration.u_cg_restart_interval > 0 ||
        throw(ArgumentError("u_cg_restart_interval must be positive"))
    acceleration.u_cg_beta_cap > 0.0 && isfinite(acceleration.u_cg_beta_cap) ||
        throw(ArgumentError("u_cg_beta_cap must be positive and finite"))
    0.0 < acceleration.u_cg_minimum_descent_cosine <= 1.0 ||
        throw(ArgumentError("u_cg_minimum_descent_cosine must be in (0, 1]"))
    thresholds = config.solver.numerical_thresholds
    for (name, value) in (
        (:hermitian_residual_rtol, thresholds.hermitian_residual_rtol),
        (:subspace_cluster_atol, thresholds.subspace_cluster_atol),
        (:subspace_cluster_rtol, thresholds.subspace_cluster_rtol),
        (:frame_transport_atol, thresholds.frame_transport_atol),
        (:frame_transport_rtol, thresholds.frame_transport_rtol),
        (:projectability_minimum_singular_value, thresholds.projectability_minimum_singular_value),
    )
        value > 0.0 && isfinite(value) ||
            throw(ArgumentError("$(name) must be positive and finite"))
    end
    thresholds.maximum_transport_condition >= 1.0 &&
    isfinite(thresholds.maximum_transport_condition) ||
        throw(ArgumentError("maximum_transport_condition must be finite and at least one"))
    config.solver.multi_start.starts > 0 ||
        throw(ArgumentError("multi-start count must be positive"))
    1 <= config.solver.multi_start.start_index <= config.solver.multi_start.starts ||
        throw(ArgumentError("multi-start index must lie in 1:starts"))
    config.solver.initialization_backend isa Union{
        AMNExactFrozenInitialization,
        PAWSCDMInitialization,
        ProjectabilityDisentanglementInitialization,
    } || throw(ArgumentError("unsupported initialization backend"))
    if config.solver.initialization_backend isa PAWSCDMInitialization
        config.solver.paw_scdm_input_hdf5 === nothing && throw(
            ArgumentError(
                "SCDM_INPUT_PRECONDITION: PAWSCDMInitialization requires paw_scdm_input_hdf5",
            ),
        )
        isempty(strip(something(config.solver.paw_scdm_input_hdf5))) &&
            throw(ArgumentError("SCDM_INPUT_PRECONDITION: paw_scdm_input_hdf5 must not be empty"))
    elseif config.solver.paw_scdm_input_hdf5 !== nothing
        throw(
            ArgumentError(
                "SCDM_INPUT_PRECONDITION: paw_scdm_input_hdf5 is valid only with PAWSCDMInitialization",
            ),
        )
    elseif config.solver.initialization_backend isa ProjectabilityDisentanglementInitialization
        config.input.amn_file === nothing && throw(
            ArgumentError(
                "PROJECTABILITY_INPUT_PRECONDITION: projectability initialization requires AMN",
            ),
        )
    end
    config.solver.initialization == :amn &&
        config.input.amn_file === nothing &&
        config.input.source === nothing &&
        throw(
            ArgumentError("initialization=:amn requires amn_file or a native wavefunction source"),
        )
    config.solver.initialization == :restart &&
        config.checkpoint.restart_hdf5 === nothing &&
        throw(ArgumentError("initialization=:restart requires restart_hdf5"))
    _validate_wavefunction_gauge_contract(config)
    if config.input.matrix_elements isa SymmetryCompletedQEPAWMatrices
        matrices = config.input.matrix_elements::SymmetryCompletedQEPAWMatrices
        config.input.wavefunction_gauge_backend isa StarCovariantPAWGauge || throw(
            ArgumentError(
                "WAVEFUNCTION_GAUGE_BACKEND_MISMATCH: completed QE matrices require " *
                "StarCovariantPAWGauge",
            ),
        )
        abspath(matrices.gauge_hdf5) == abspath(something(config.input.wavefunction_gauge_hdf5)) ||
            throw(
                ArgumentError(
                    "WAVEFUNCTION_GAUGE_ARTIFACT_MISMATCH: matrix and solver artifacts differ",
                ),
            )
    end
    return nothing
end

# Return the requested target dimension and cross-check a supplied projection basis.
function _configured_num_wannier(
    config::Union{SymmetryAdaptedWannierizationConfig, BandRepresentationPreparationConfig},
)
    basis_dimension =
        _wannierization_input_config(config).projection_basis === nothing ? 0 :
        _wannierization_input_config(config).projection_basis.num_wannier
    dimension =
        _wannierization_input_config(config).num_wannier == 0 ? basis_dimension :
        _wannierization_input_config(config).num_wannier
    dimension > 0 || throw(ArgumentError("num_wannier or projection_basis is required"))
    basis_dimension == 0 ||
        basis_dimension == dimension ||
        throw(ArgumentError("num_wannier disagrees with projection_basis"))
    return dimension
end
