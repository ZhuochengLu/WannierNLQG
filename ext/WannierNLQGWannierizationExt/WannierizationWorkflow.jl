"""Select coefficient-normalized legacy input or strict raw full-cutoff input."""
_read_band_sewing_source(source::AbstractWavefunctionSource, ::CoefficientMappingSewing) =
    read_native_source(source; purpose = :band_representation)
"""Read one augmentation-aware backend from raw full-cutoff native data."""
_read_band_sewing_source(source::AbstractWavefunctionSource, ::AugmentationAwareSewing) =
    read_augmentation_aware_native_source(source)

# Select either the unchanged native eigenstates or a sealed star-covariant payload.
function _read_wavefunction_gauge_source(
    source::AbstractWavefunctionSource,
    sewing_backend::AbstractBandSewingBackend,
    ::NativeEigenstateGauge,
    authority::AbstractAuthoritativeHamiltonian,
    gauge_hdf5;
    construction_policy::Symbol = :strict,
)
    gauge_hdf5 === nothing || throw(ArgumentError("WAVEFUNCTION_GAUGE_BACKEND_MISMATCH"))
    return (
        native = _read_band_sewing_source(source, sewing_backend),
        strict_metric = nothing,
        artifact_sha256 = nothing,
        block_partition_metadata = star_authoritative_hamiltonian_metadata(authority),
    )
end

# Read a fresh-process-verifiable star-gauge artifact without rereading native WFC arrays.
function _read_wavefunction_gauge_source(
    source::AbstractWavefunctionSource,
    sewing_backend::AbstractBandSewingBackend,
    backend::StarCovariantPAWGauge,
    authority::AbstractAuthoritativeHamiltonian,
    gauge_hdf5;
    construction_policy::Symbol = :strict,
)
    sewing_backend isa AugmentationAwareSewing ||
        throw(ArgumentError("WAVEFUNCTION_GAUGE_BACKEND_MISMATCH"))
    gauge_hdf5 === nothing && throw(ArgumentError("WAVEFUNCTION_GAUGE_ARTIFACT_REQUIRED"))
    diagnostic_requested =
        backend.hamiltonian_correction isa FarBandCovarianceCorrection &&
        (backend.hamiltonian_correction::FarBandCovarianceCorrection).qualification_mode ==
        :diagnostic_only
    restored = read_star_covariant_paw_gauge_hdf5(
        something(gauge_hdf5);
        require_pass = construction_policy == :strict && !diagnostic_requested,
        construction_policy = construction_policy == :diagnostic ? :diagnostic : nothing,
        source,
    )
    construction_policy == :strict &&
        diagnostic_requested &&
        restored.status != :DIAGNOSTIC_ONLY &&
        throw(
            ArgumentError(
                "WAVEFUNCTION_GAUGE_BACKEND_MISMATCH: diagnostic correction requires a DIAGNOSTIC_ONLY artifact",
            ),
        )
    construction_policy == :strict &&
        !diagnostic_requested &&
        restored.status != :PASS &&
        throw(ArgumentError("PAW_SEWING_HOLD: strict gauge artifact is not PASS"))
    restored.status in (:PASS, :DIAGNOSTIC_ONLY) ||
        throw(ArgumentError("PAW_SEWING_HOLD: gauge has no valid diagnostic payload"))
    validate_star_gauge_source_identity(source, restored.payload)
    recorded_correction =
        get(restored.payload.source_metadata, "discrete_hamiltonian_correction", "none")
    recorded_correction == discrete_hamiltonian_correction_key(backend.hamiltonian_correction) ||
        throw(ArgumentError("WAVEFUNCTION_GAUGE_BACKEND_MISMATCH: correction policy differs"))
    expected_correction_sha = star_hamiltonian_correction_sha256(backend.hamiltonian_correction)
    get(restored.payload.input_sha256, "DISCRETE_HAMILTONIAN_CORRECTION_SHA256", "MISSING") ==
    expected_correction_sha ||
        throw(ArgumentError("WAVEFUNCTION_GAUGE_ARTIFACT_MISMATCH: correction digest differs"))
    recorded_authority =
        get(restored.payload.source_metadata, "authoritative_hamiltonian", "native_dft")
    expected_authority = authoritative_hamiltonian_key(authority)
    recorded_authority == expected_authority || throw(
        ArgumentError(
            "HAMILTONIAN_REFERENCE_MISMATCH: requested $(expected_authority), artifact records $(recorded_authority)",
        ),
    )
    get(restored.payload.input_sha256, "AUTHORITATIVE_HAMILTONIAN_SHA256", "MISSING") ==
    star_authoritative_hamiltonian_sha256(authority) ||
        throw(ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: authority digest differs"))
    qualification_metadata = Dict(
        key => value for (key, value) in restored.payload.source_metadata if
        startswith(key, "block_partition_") ||
        startswith(key, "controlled_symmetrization_") ||
        startswith(key, "energy_shift_") ||
        startswith(key, "target_") ||
        startswith(key, "target_contract_") ||
        startswith(key, "target_scope_") ||
        startswith(key, "parent_audit_") ||
        startswith(key, "outer_") ||
        startswith(key, "frozen_") ||
        key in (
            "maximum_energy_shift_audit_reference_ev",
            "rms_energy_shift_audit_reference_ev",
            "target_energy_shift_audit_status",
            "symmetrized_parent_energy_shift_audit_status",
            "residual_gate_phase",
            "raw_preflight_diagnostic_status",
            "native_difference_qualification",
            "native_difference_audit_status",
            "qualification_scope",
            "target_anchor",
            "target_complement_completion",
            "target_complement_max_element_ev",
            "auxiliary_parent_qualification",
            "symmetrized_dft_hamiltonian_status",
            "auxiliary_parent_audit_status",
            "target_scope_production_eligible",
        ) ||
        key == "discrete_hamiltonian_correction" ||
        startswith(key, "authoritative_") ||
        key in (
            "native_fidelity_scope",
            "global_production_eligible",
            "symmetrized_dft_hamiltonian_is_pure_gauge",
        )
    )
    qualification_metadata["production_eligible"] = string(restored.status == :PASS)
    qualification_metadata["diagnostic_only"] = string(restored.status == :DIAGNOSTIC_ONLY)
    native_residual = get(
        restored.payload.maxima,
        "native_fidelity_projected_eigen_residual_ev",
        get(restored.payload.maxima, "projected_eigen_residual_ev", Inf),
    )
    qualification_metadata["native_fidelity_status"] =
        native_residual <= backend.thresholds.projected_eigen_residual_ev ?
        "NATIVE_DFT_FIDELITY_PASS" : "NATIVE_DFT_FIDELITY_HOLD"
    qualification_metadata["scoped_production_eligible"] =
        string(restored.payload.qualification_scope !== nothing && restored.status == :PASS)
    qualification_metadata["symmetrized_dft_hamiltonian_status"] =
        authority isa SymmetrizedDFTHamiltonian && restored.status == :PASS ?
        "SYMMETRIZED_DFT_HAMILTONIAN_PASS" : "NOT_APPLICABLE"
    qualification_metadata["target_scope_production_eligible"] =
        string(restored.payload.qualification_scope !== nothing && restored.status == :PASS)
    qualification_metadata["global_production_eligible"] = "false"
    if construction_policy == :diagnostic
        qualification_metadata["construction_gauge_status"] = String(restored.status)
        qualification_metadata["construction_gauge_metrics_json"] = JSON3.write(
            Dict(
                key => value for (key, value) in restored.payload.maxima if
                startswith(key, "construction_") && isfinite(value)
            ),
        )
    end
    return (
        native = restored.payload.native,
        strict_metric = restored.payload.metric,
        artifact_sha256 = sha256_file(something(gauge_hdf5)),
        block_partition_metadata = qualification_metadata,
    )
end

# Prevent a supplied representation, Z/U state, or checkpoint from changing backend identity.
function _validate_sewing_backend_identity(
    backend::AbstractBandSewingBackend,
    representation::BandRepresentation,
)
    expected = band_sewing_backend_key(backend)
    recorded = get(representation.conventions, "sewing_backend", "coefficient_mapping")
    recorded == expected || throw(
        ArgumentError(
            "SEWING_BACKEND_MISMATCH: requested $(expected), representation records $(recorded)",
        ),
    )
    backend isa AugmentationAwareSewing &&
        !(
            representation.schema_version in (
                "1.0",
                "1.5",
                "1.6",
                "1.7",
                "1.8",
                "1.9",
                "1.10",
                "1.11",
                "1.12",
                "1.13",
                "1.14",
                "1.15",
                "1.16",
                "1.17",
            )
        ) &&
        throw(
            ArgumentError(
                "SEWING_BACKEND_MISMATCH: legacy schema $(representation.schema_version) cannot be relabeled as augmentation-aware",
            ),
        )
    return nothing
end

# Prevent old or cross-artifact representation/Z/U reuse under a new gauge label.
function _validate_wavefunction_gauge_identity(
    backend::AbstractWavefunctionGaugeBackend,
    gauge_hdf5,
    representation::BandRepresentation,
)
    expected = wavefunction_gauge_backend_key(backend)
    recorded = get(representation.conventions, "wavefunction_gauge_backend", "native_eigenstate")
    recorded == expected || throw(
        ArgumentError(
            "WAVEFUNCTION_GAUGE_BACKEND_MISMATCH: requested $(expected), " *
            "representation records $(recorded)",
        ),
    )
    if backend isa StarCovariantPAWGauge
        allowed_schema =
            backend.hamiltonian_correction isa FarBandCovarianceCorrection ?
            ("1.0", "1.9", "1.10", "1.11", "1.12", "1.13", "1.14", "1.15", "1.16", "1.17") :
            ("1.0", "1.8", "1.9", "1.15", "1.16", "1.17")
        representation.schema_version in allowed_schema || throw(
            ArgumentError(
                "WAVEFUNCTION_GAUGE_BACKEND_MISMATCH: correction policy is incompatible with representation schema $(representation.schema_version)",
            ),
        )
        expected_sha = sha256_file(something(gauge_hdf5))
        get(representation.conventions, "wavefunction_gauge_hdf5_sha256", "MISSING") ==
        expected_sha || throw(ArgumentError("WAVEFUNCTION_GAUGE_ARTIFACT_MISMATCH"))
        expected_correction = discrete_hamiltonian_correction_key(backend.hamiltonian_correction)
        get(representation.conventions, "discrete_hamiltonian_correction", "none") ==
        expected_correction ||
            throw(ArgumentError("WAVEFUNCTION_GAUGE_BACKEND_MISMATCH: correction identity differs"))
    end
    return nothing
end

# Prevent native/symmetrized representations and downstream states from crossing authority.
function _validate_authoritative_hamiltonian_identity(
    authority::AbstractAuthoritativeHamiltonian,
    representation::BandRepresentation,
)
    expected = authoritative_hamiltonian_key(authority)
    recorded = get(representation.conventions, "authoritative_hamiltonian", "native_dft")
    recorded == expected || throw(
        ArgumentError(
            "HAMILTONIAN_REFERENCE_MISMATCH: requested $(expected), representation records $(recorded)",
        ),
    )
    authority isa SymmetrizedDFTHamiltonian &&
        !(representation.schema_version in ("1.0", "1.16", "1.17")) &&
        throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: SymmetrizedDFTHamiltonian target authority requires a complete public 1.0 or internal target contract",
            ),
        )
    return nothing
end

# Bind the gauge backend and artifact identity while preserving every representation array.
function _representation_with_wavefunction_gauge(
    representation::BandRepresentation,
    backend::AbstractWavefunctionGaugeBackend,
    authority::AbstractAuthoritativeHamiltonian,
    artifact_sha256,
    block_partition_metadata::AbstractDict = Dict{String, String}(),
)
    conventions = Dict{String, String}(representation.conventions)
    conventions["wavefunction_gauge_backend"] = wavefunction_gauge_backend_key(backend)
    conventions["wavefunction_gauge_hdf5_sha256"] =
        artifact_sha256 === nothing ? "NOT_APPLICABLE" : String(artifact_sha256)
    conventions["authoritative_hamiltonian"] = authoritative_hamiltonian_key(authority)
    conventions["authoritative_hamiltonian_sha256"] =
        star_authoritative_hamiltonian_sha256(authority)
    conventions["global_production_eligible"] = "false"
    merge!(
        conventions,
        Dict(string(key) => string(value) for (key, value) in block_partition_metadata),
    )
    return BandRepresentation(
        authority isa SymmetrizedDFTHamiltonian ? "1.16" : "1.9",
        representation.source_code,
        representation.spinor,
        representation.real_lattice,
        representation.reciprocal_lattice,
        representation.mp_grid,
        representation.kpoints_fractional,
        representation.energies_ev,
        representation.operations,
        representation.kpoint_map,
        representation.reciprocal_shifts,
        representation.sewing_matrices,
        representation.band_block_labels,
        representation.irreducible_indices,
        representation.full_to_irreducible,
        representation.full_to_operation;
        conventions,
        input_sha256 = representation.input_sha256,
    )
end

# Final-TB covariance is a formal qualification gate. It deliberately does not
# inherit the finite-cutoff empirical budget used by dynamic projector checks.
_final_tb_hamiltonian_covariance_threshold(config::SymmetryAdaptedWannierizationConfig) =
    config.input.representation_tolerance

# Validate a discovered AMN provenance companion against the selected basis.
function _validate_amn_projection_contract(
    amn_filename::AbstractString,
    basis::WannierProjectionBasis,
)
    root, _ = splitext(abspath(amn_filename))
    provenance = root * ".amn-provenance.h5"
    isfile(provenance) || return nothing
    expected_basis = projection_basis_sha256(basis)
    expected_contract =
        WannierProjection.projection_radial_transform_contract(basis.radial_transform)
    expected_radial = bytes2hex(SHA.sha256(codeunits(repr(expected_contract))))
    HDF5.h5open(provenance, "r") do handle
        attributes = HDF5.attributes(handle)
        String(read(attributes["schema"])) == "WannierNLQG.amn_provenance" ||
            throw(ArgumentError("AMN provenance has an unsupported schema"))
        String(read(attributes["basis_sha256"])) == expected_basis || throw(
            ArgumentError("AMN provenance projection basis does not match the configured basis"),
        )
        haskey(handle, "radial_transform") ||
            throw(ArgumentError("AMN provenance omits the radial transform contract"))
        radial_attributes = HDF5.attributes(handle["radial_transform"])
        String(read(radial_attributes["implementation_digest"])) == expected_radial || throw(
            ArgumentError("AMN provenance radial transform does not match the configured backend"),
        )
    end
    return provenance
end

# Reconstruct an immutable config with the resolved projection basis and dimension.
function _config_with_projection_basis(
    config::SymmetryAdaptedWannierizationConfig,
    basis::WannierProjectionBasis,
)
    dimension = config.input.num_wannier == 0 ? basis.num_wannier : config.input.num_wannier
    return replace_wannierization_config(
        config;
        input = (projection_basis = basis, num_wannier = dimension),
    )
end

# Copy an immutable solver config with the resolved effective compatibility policy.
function _config_with_compatibility_policy(
    config::SymmetryAdaptedWannierizationConfig,
    policy::Symbol,
)
    return replace_wannierization_config(config; input = (compatibility_policy = policy,))
end

# Complete native VASP PAW matrices into the same sealed star gauge used by
# the representation.  This uses the package-wide band-column convention
# A'_k=R_k^dagger A_k and M'_{k,b}=R_k^dagger M_{k,b}R_{k+b}; it is the same
# convention as `star_transform_sewing_gauge` and the completed QE path.
function _validate_square_star_gauge_rotations(rotations, parent_bands::Int, parent_kpoints::Int)
    size(rotations) == (parent_bands, parent_bands, parent_kpoints) || throw(
        ArgumentError(
            "PAW_PROPAGATION_IMPLEMENTATION_HOLD: star-gauge rotations have size " *
            "$(size(rotations)); expected ($(parent_bands), $(parent_bands), $(parent_kpoints))",
        ),
    )
    all(isfinite, rotations) ||
        throw(ArgumentError("PAW_PROPAGATION_IMPLEMENTATION_HOLD: non-finite star rotations"))
    return Array{ComplexF64, 3}(rotations)
end

"""Complete native VASP PAW matrices in the sealed representation star gauge."""
function _complete_native_vasp_paw_matrices_in_star_gauge(
    config::SymmetryAdaptedWannierizationConfig,
    native_source::NativeVASPPAWMatrices,
    result::VASPPAWMatrixElementResult,
)
    config.input.wavefunction_gauge_backend isa StarCovariantPAWGauge || return nothing
    config.input.wavefunction_gauge_hdf5 === nothing &&
        throw(ArgumentError("WAVEFUNCTION_GAUGE_ARTIFACT_REQUIRED"))
    gauge_file = abspath(something(config.input.wavefunction_gauge_hdf5))
    restored = read_star_covariant_paw_gauge_hdf5(
        gauge_file;
        require_pass = config.input.construction_policy == :strict,
        construction_policy = config.input.construction_policy,
        source = config.input.source,
    )
    rotations = restored.payload.rotations
    parent_bands = result.mmn.num_bands
    parent_kpoints = result.mmn.num_kpts
    rotations = _validate_square_star_gauge_rotations(rotations, parent_bands, parent_kpoints)
    rotated_mmn = star_rotate_parent_mmn(result.mmn, rotations)
    rotated_amn = star_rotate_parent_amn(result.solver_amn, rotations)
    completed_dir = joinpath(native_source.artifact_dir, "completed", "symmetry-gauge")
    mkpath(completed_dir)
    mmn_file = IO.write_wannier_mmn(
        joinpath(completed_dir, "native_paw.symmetry_gauge.mmn"),
        rotated_mmn;
        comment = "Native VASP PAW MMN completed in sealed star gauge",
    )
    amn_file = IO.write_wannier_amn(
        joinpath(completed_dir, "native_paw.symmetry_gauge.sawf.amn"),
        rotated_amn;
        comment = "Native VASP PAW solver AMN completed in sealed star gauge",
    )
    mmn_readback = IO.read_wannier_mmn(mmn_file)
    amn_readback = IO.read_wannier_amn(amn_file)
    maximum(abs, mmn_readback.data - rotated_mmn.data) <= 5.0e-15 || throw(
        ArgumentError("PAW_PROPAGATION_IMPLEMENTATION_HOLD: symmetry-gauge MMN readback differs"),
    )
    maximum(abs, amn_readback.data - rotated_amn.data) <= 5.0e-15 || throw(
        ArgumentError("PAW_PROPAGATION_IMPLEMENTATION_HOLD: symmetry-gauge AMN readback differs"),
    )
    gauge_sha256 = sha256_file(gauge_file)
    provenance_file = joinpath(completed_dir, "native_paw.symmetry_gauge.provenance.h5")
    HDF5.enable_complex_support()
    atomic_hdf5_write(provenance_file) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = "WannierNLQG.native_vasp_paw_symmetry_gauge"
            attributes["schema_version"] = "1.0"
            attributes["gauge_sha256"] = gauge_sha256
            attributes["gauge_file"] = gauge_file
            attributes["rotation_convention"] = "A'=R_k^dagger*A;M'=R_k^dagger*M*R_kplusb"
            attributes["parent_band_count"] = parent_bands
            attributes["kpoint_count"] = parent_kpoints
            attributes["mmn_sha256"] = sha256_file(mmn_file)
            attributes["amn_sha256"] = sha256_file(amn_file)
            handle["native_to_completed_rotations"] = rotations
        end
    end
    return (
        mmn = mmn_readback,
        amn = amn_readback,
        mmn_file,
        amn_file,
        provenance_file = abspath(provenance_file),
        gauge_sha256,
    )
end

# Derive the native-VASP matrix-element authority from the exact solver windows.
function _native_vasp_paw_qualification_contract(config::SymmetryAdaptedWannierizationConfig)
    eig = IO.read_wannier_eig(config.input.eig_file)
    band_block_labels = canonical_band_block_labels(eig.data, config.input.degeneracy_tolerance_ev)
    outer_masks, frozen_masks = window_masks_from_energies(config, eig.data, band_block_labels)
    scope = BandRepresentationQualificationScope(
        BitMatrix(hcat(outer_masks...)),
        BitMatrix(hcat(frozen_masks...)),
    )
    metadata = Dict(
        "target_authority" => "outer_window",
        "parent_audit_policy" => "audit_only",
        "target_leakage_semantics" => TARGET_LEAKAGE_WEIGHT_SEMANTICS,
        "target_leakage_formula_sha256" => TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
        "target_leakage_threshold" => repr(
            config.input.wavefunction_gauge_backend isa StarCovariantPAWGauge ?
            config.input.wavefunction_gauge_backend.thresholds.target_leakage_weight :
            5.0e-6,
        ),
        "outer_min_ev" => string(config.input.outer_min_ev),
        "outer_max_ev" => string(config.input.outer_max_ev),
        "frozen_min_ev" => string(config.input.frozen_min_ev),
        "frozen_max_ev" => string(config.input.frozen_max_ev),
        "degeneracy_tolerance_ev" => string(config.input.degeneracy_tolerance_ev),
        "window_closure" => "complete_degeneracy_blocks",
    )
    input_sha256 = Dict(
        "EIG" => sha256_file(config.input.eig_file),
        "WIN" => sha256_file(config.input.win_file),
    )
    return (; scope, metadata, input_sha256)
end

# Fail-stop only on the authoritative target result; parent audit text is inert.
function _require_native_vasp_paw_qualification(
    result::VASPPAWMatrixElementResult,
    thresholds::VASPPAWParityThresholds;
    construction_policy::Symbol = :strict,
)
    result.passed && return nothing
    engineering_failure = findfirst(
        diagnostic ->
            startswith(diagnostic, "VASP_PAW_DATA_REQUIRED") ||
            startswith(diagnostic, "VASP_PAW_RAW_COEFFICIENTS_REQUIRED"),
        result.diagnostics,
    )
    engineering_failure === nothing || throw(
        ArgumentError(
            "VASP_PAW_TARGET_SCOPE_QUALIFICATION_FAILED: " *
            result.diagnostics[something(engineering_failure)] *
            "; " *
            join(result.diagnostics, "; "),
        ),
    )
    if construction_policy == :diagnostic
        all(isfinite, result.mmn.data) && all(isfinite, result.solver_amn.data) ||
            throw(ArgumentError("VASP_PAW_NONFINITE_MATRICES: no finite diagnostic matrices"))
        return nothing
    end
    if result.mmn_parity === nothing ||
       !paw_metric_passes(
        something(result.mmn_parity),
        thresholds.mmn_max_absolute,
        thresholds.mmn_rms,
        thresholds.mmn_relative_l2,
    )
        throw(
            ArgumentError(
                "VASP_PAW_MMN_PARITY_FAILED: native target MMN is diagnostic-only; " *
                join(result.diagnostics, "; "),
            ),
        )
    end
    throw(
        ArgumentError(
            "VASP_PAW_AMN_PARITY_FAILED: native target AMN is diagnostic-only; " *
            join(result.diagnostics, "; "),
        ),
    )
end

# Preserve each native PAW quality result independently of diagnostic admission.
function _native_vasp_paw_gate_diagnostics(result::VASPPAWMatrixElementResult, thresholds)
    measurements = Pair{String, Union{Nothing, Float64}}[
        "radial_q_max_absolute" => result.radial_q_max_absolute,
        "generalized_norm_max_absolute" => result.generalized_norm_max_absolute,
        "amn_max_principal_angle_rad" => (result.amn_parity === nothing ? nothing :
                                          result.amn_max_principal_angle_rad),
        "amn_projector_max_absolute" => (result.amn_parity === nothing ? nothing :
                                         result.amn_projector_max_absolute),
    ]
    for (prefix, parity) in (("mmn", result.mmn_parity), ("amn", result.amn_parity))
        for (suffix, field) in (
            ("max_absolute", :max_absolute),
            ("rms", :root_mean_square),
            ("relative_l2", :relative_l2),
        )
            push!(
                measurements,
                prefix * "_" * suffix =>
                    (parity === nothing ? nothing : getproperty(parity, field)),
            )
        end
    end
    return WannierizationDiagnostic[
        WannierizationDiagnostic(
            :NATIVE_PAW_QUALITY_CHECK,
            value !== nothing && value <= getproperty(thresholds, Symbol(metric)) ? :info :
            :warning,
            "Native PAW quality measurement retained for manual review.";
            context = Dict(
                "stage" => "matrix_preparation",
                "metric" => metric,
                "value" => value === nothing ? "NOT_AVAILABLE" : string(value),
                "threshold" => string(getproperty(thresholds, Symbol(metric))),
                "gate_result" =>
                    value === nothing ? "NOT_AVAILABLE" :
                    (value <= getproperty(thresholds, Symbol(metric)) ? "PASS" : "FAIL"),
                "action" => "CONTINUE_DIAGNOSTIC",
                "construction_policy" => "diagnostic",
            ),
        ) for (metric, value) in measurements
    ]
end

# Keep native QE quality residuals separate from data, rank, and propagation identity failures.
function _require_native_qe_paw_qualification(
    result::Wannierization.QEPAWMatrixElementResult;
    construction_policy::Symbol = :strict,
    propagation_identity::Bool = false,
)
    all(isfinite, result.mmn.data) && all(isfinite, result.amn.data) ||
        throw(ArgumentError("QE_PAW_NONFINITE_MATRICES: no finite diagnostic matrices"))
    isfinite(result.generalized_norm_max_absolute) ||
        throw(ArgumentError("QE_PAW_NONFINITE_METRIC: norm residual is nonfinite"))
    for kpoint in axes(result.amn.data, 3)
        singular = svdvals(Matrix(@view result.amn.data[:, :, kpoint]))
        length(singular) >= result.amn.num_wannier &&
        count(value -> value > 1.0e-12 * maximum(singular), singular) >= result.amn.num_wannier ||
            throw(ArgumentError("QE_PAW_AMN_RANK_DEFICIENT: target subspace is unavailable"))
    end
    for parity in (result.mmn_parity, result.amn_parity)
        parity === nothing && continue
        parity.finite &&
        all(isfinite, (parity.max_absolute, parity.root_mean_square, parity.relative_l2)) ||
            throw(ArgumentError("QE_PAW_NONFINITE_PARITY: reference comparison is invalid"))
    end
    result.passed && return nothing
    quality_codes =
        propagation_identity ? ("QE_GENERALIZED_NORM_FAILED",) :
        ("QE_GENERALIZED_NORM_FAILED", "QE_PAW_MMN_PARITY_FAILED", "QE_PAW_AMN_PARITY_FAILED")
    hard_failures = filter(result.diagnostics) do diagnostic
        (
            startswith(diagnostic, "QE_") ||
            startswith(diagnostic, "PAW_PROPAGATION_IMPLEMENTATION_HOLD")
        ) && !(diagnostic in quality_codes)
    end
    isempty(hard_failures) || throw(ArgumentError(join(hard_failures, "; ")))
    if result.amn_parity !== nothing
        all(isfinite, (result.amn_max_principal_angle_rad, result.amn_projector_max_absolute)) ||
            throw(ArgumentError("QE_PAW_INVALID_REFERENCE_SUBSPACE: comparison is not finite"))
        for diagnostic in result.diagnostics
            startswith(diagnostic, "amn_minimum_rank=") || continue
            parsed = tryparse(Int, split(diagnostic, '='; limit = 2)[2])
            parsed !== nothing && parsed >= result.amn.num_wannier || throw(
                ArgumentError("QE_PAW_REFERENCE_RANK_DEFICIENT: reference target rank differs"),
            )
        end
    end
    construction_policy == :diagnostic &&
        any(diagnostic -> diagnostic in quality_codes, result.diagnostics) &&
        return nothing
    prefix =
        propagation_identity ?
        "PAW_PROPAGATION_IMPLEMENTATION_HOLD: completed QE MMN/AMN are diagnostic-only; " :
        "QE_AUGMENTATION_METRIC_REQUIRED: native QE MMN/AMN are diagnostic-only; "
    throw(ArgumentError(prefix * join(result.diagnostics, "; ")))
end

# Persist the original QE quality measurements without assigning implementation failures new status.
function _native_qe_paw_gate_diagnostics(
    result::Wannierization.QEPAWMatrixElementResult,
    thresholds,
)
    measurements = Pair{String, Union{Nothing, Float64}}[
        "generalized_norm_max_absolute" => result.generalized_norm_max_absolute,
        "amn_max_principal_angle_rad" => (result.amn_parity === nothing ? nothing :
                                          result.amn_max_principal_angle_rad),
        "amn_projector_max_absolute" => (result.amn_parity === nothing ? nothing :
                                         result.amn_projector_max_absolute),
    ]
    for (prefix, parity) in (("mmn", result.mmn_parity), ("amn", result.amn_parity))
        for (suffix, field) in (
            ("max_absolute", :max_absolute),
            ("rms", :root_mean_square),
            ("relative_l2", :relative_l2),
        )
            push!(
                measurements,
                prefix * "_" * suffix =>
                    (parity === nothing ? nothing : getproperty(parity, field)),
            )
        end
    end
    return WannierizationDiagnostic[
        WannierizationDiagnostic(
            :NATIVE_QE_PAW_QUALITY_CHECK,
            value !== nothing && value <= getproperty(thresholds, Symbol(metric)) ? :info :
            :warning,
            "Native QE PAW quality measurement retained for manual review.";
            context = Dict(
                "stage" => "matrix_preparation",
                "metric" => metric,
                "value" => value === nothing ? "NOT_AVAILABLE" : string(value),
                "threshold" => string(getproperty(thresholds, Symbol(metric))),
                "gate_result" =>
                    value === nothing ? "NOT_AVAILABLE" :
                    (value <= getproperty(thresholds, Symbol(metric)) ? "PASS" : "FAIL"),
                "action" => "CONTINUE_DIAGNOSTIC",
                "construction_policy" => "diagnostic",
            ),
        ) for (metric, value) in measurements
    ]
end

# Resolve old MMN/AMN fields or one typed matrix-element source before solver entry.
function _resolve_wannier_matrix_elements(
    config::SymmetryAdaptedWannierizationConfig,
    basis::WannierProjectionBasis,
)
    configured = config.input.matrix_elements
    if configured === nothing && config.input.amn_file !== nothing
        configured =
            ExternalWannier90Matrices(config.input.mmn_file, something(config.input.amn_file))
    end
    if configured === nothing
        config.solver.initialization == :amn &&
            config.input.source isa VASPWavefunctionSource &&
            throw(
                ArgumentError(
                    "VASP_PAW_AMN_REQUIRED: VASP initialization cannot fall back to pseudo AMN",
                ),
            )
        return (
            mmn = IO.read_wannier_mmn(config.input.mmn_file),
            amn = nothing,
            mmn_file = config.input.mmn_file,
            amn_file = nothing,
            raw_amn_file = nothing,
            source_kind = "legacy_mmn_only",
            paw_result = nothing,
            gauge_sha256 = "",
            gauge_provenance_file = nothing,
        )
    elseif configured isa ExternalWannier90Matrices
        external = configured::ExternalWannier90Matrices
        _validate_amn_projection_contract(external.amn_file, basis)
        return (
            mmn = IO.read_wannier_mmn(external.mmn_file),
            amn = read_wannier_amn(external.amn_file),
            mmn_file = external.mmn_file,
            amn_file = external.amn_file,
            raw_amn_file = nothing,
            source_kind = "external_wannier90",
            paw_result = nothing,
            gauge_sha256 = "",
            gauge_provenance_file = nothing,
        )
    end

    if configured isa SymmetryCompletedQEPAWMatrices
        completed_source = configured::SymmetryCompletedQEPAWMatrices
        config.input.source isa QuantumEspressoWavefunctionSource || throw(
            ArgumentError(
                "QE_AUGMENTATION_METRIC_REQUIRED: completed QE matrices require a QE source",
            ),
        )
        result = generate_symmetry_completed_qe_paw_matrix_elements(
            config.input.source::QuantumEspressoWavefunctionSource,
            completed_source.gauge_hdf5,
            completed_source.nnkp_file;
            artifact_dir = completed_source.artifact_dir,
            thresholds = completed_source.thresholds,
            qualification_mode = config.input.construction_policy == :diagnostic ?
                                 :diagnostic_only : completed_source.qualification_mode,
        )
        _require_native_qe_paw_qualification(
            result;
            construction_policy = config.input.construction_policy,
            propagation_identity = true,
        )
        return (
            mmn = result.mmn,
            amn = result.amn.data,
            mmn_file = result.artifacts["mmn"],
            amn_file = result.artifacts["amn"],
            raw_amn_file = result.artifacts["amn"],
            source_kind = config.input.construction_policy == :strict &&
                          completed_source.qualification_mode == :strict ?
                          "symmetry_completed_qe_paw" : "symmetry_completed_qe_paw_DIAGNOSTIC_ONLY",
            paw_result = result,
            gauge_sha256 = sha256_file(completed_source.gauge_hdf5),
            gauge_provenance_file = get(result.artifacts, "provenance_hdf5", nothing),
        )
    end

    if configured isa NativeQEPAWMatrices
        native_source = configured::NativeQEPAWMatrices
        config.input.source isa QuantumEspressoWavefunctionSource || throw(
            ArgumentError(
                "QE_AUGMENTATION_METRIC_REQUIRED: native QE matrices require a QE source",
            ),
        )
        mkpath(native_source.artifact_dir)
        result = generate_qe_paw_matrix_elements(
            config.input.source::QuantumEspressoWavefunctionSource,
            native_source.nnkp_file;
            artifact_dir = native_source.artifact_dir,
            oracle_mmn_file = native_source.oracle_mmn_file,
            oracle_amn_file = native_source.oracle_amn_file,
            thresholds = native_source.thresholds,
            require_oracle = native_source.require_oracle,
        )
        _require_native_qe_paw_qualification(
            result;
            construction_policy = config.input.construction_policy,
        )
        return (
            mmn = result.mmn,
            amn = result.amn.data,
            mmn_file = result.artifacts["mmn"],
            amn_file = result.artifacts["amn"],
            raw_amn_file = result.artifacts["amn"],
            source_kind = "native_qe_paw",
            paw_result = result,
            gauge_sha256 = "",
            gauge_provenance_file = nothing,
        )
    end

    native_source = configured::NativeVASPPAWMatrices
    config.input.source isa VASPWavefunctionSource ||
        throw(ArgumentError("VASP_PAW_DATA_REQUIRED: native PAW matrices require a VASP source"))
    mkpath(native_source.artifact_dir)
    mmn_file = joinpath(native_source.artifact_dir, "native_paw.mmn")
    raw_amn_file = joinpath(native_source.artifact_dir, "native_paw.amn")
    amn_file = joinpath(native_source.artifact_dir, "native_paw.wannierization.amn")
    provenance_file = joinpath(native_source.artifact_dir, "native_paw.provenance.h5")
    qualification = _native_vasp_paw_qualification_contract(config)
    result = generate_vasp_paw_matrix_elements_impl(
        config.input.source::VASPWavefunctionSource,
        basis,
        native_source.topology_mmn_file;
        output_mmn_file = mmn_file,
        output_amn_file = raw_amn_file,
        output_solver_amn_file = amn_file,
        provenance_hdf5 = provenance_file,
        oracle_mmn_file = native_source.oracle_mmn_file,
        oracle_amn_file = native_source.oracle_amn_file,
        thresholds = native_source.thresholds,
        require_oracle = native_source.require_oracle,
        qualification_scope = qualification.scope,
        qualification_metadata = qualification.metadata,
        qualification_input_sha256 = qualification.input_sha256,
    )
    _require_native_vasp_paw_qualification(
        result,
        native_source.thresholds;
        construction_policy = config.input.construction_policy,
    )
    completed = _complete_native_vasp_paw_matrices_in_star_gauge(config, native_source, result)
    return (
        mmn = completed === nothing ? result.mmn : completed.mmn,
        amn = completed === nothing ? result.solver_amn.data : completed.amn.data,
        mmn_file = completed === nothing ? mmn_file : completed.mmn_file,
        amn_file = completed === nothing ? amn_file : completed.amn_file,
        raw_amn_file,
        source_kind = completed === nothing ? "native_vasp_paw" : "native_vasp_paw_symmetry_gauge",
        paw_result = result,
        gauge_sha256 = completed === nothing ? "" : completed.gauge_sha256,
        gauge_provenance_file = completed === nothing ? nothing : completed.provenance_file,
    )
end

"""Select the MMN that authoritatively certifies full-profile source operators."""
function _operator_oracle_mmn_file(resolved_matrices)
    paw_result = resolved_matrices.paw_result
    if paw_result !== nothing && haskey(paw_result.artifacts, "mmn")
        return String(paw_result.artifacts["mmn"])
    end
    return String(resolved_matrices.mmn_file)
end

"""Prepare the shared operator target before any uIu/uHu/sIu/sHu generation."""
function prepare_wannier_operator_target_contract(
    original_config::SymmetryAdaptedWannierizationConfig,
)
    validate_wannierization_config(original_config)
    original_config.output.profile == :full ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_REQUIRES_FULL_PROFILE"))
    eig = IO.read_wannier_eig(original_config.input.eig_file)
    basis =
        original_config.input.projection_basis === nothing ?
        build_wannier_projection_basis(original_config.input.win_file) :
        original_config.input.projection_basis
    config = _config_with_projection_basis(original_config, basis)
    resolved_matrices = _resolve_wannier_matrix_elements(config, basis)
    return wannier_operator_target_contract(
        config,
        eig,
        resolved_matrices.mmn,
        _operator_oracle_mmn_file(resolved_matrices),
        resolved_matrices.mmn_file,
    )
end

# Copy a band representation while extending its provenance dictionary.
function _representation_with_hashes(
    representation::BandRepresentation,
    additional_hashes::Dict{String, String},
)
    return BandRepresentation(
        representation.schema_version,
        representation.source_code,
        representation.spinor,
        representation.real_lattice,
        representation.reciprocal_lattice,
        representation.mp_grid,
        representation.kpoints_fractional,
        representation.energies_ev,
        representation.operations,
        representation.kpoint_map,
        representation.reciprocal_shifts,
        representation.sewing_matrices,
        representation.band_block_labels,
        representation.irreducible_indices,
        representation.full_to_irreducible,
        representation.full_to_operation;
        conventions = representation.conventions,
        input_sha256 = merge(representation.input_sha256, additional_hashes),
    )
end

# Seal the unified mode contract into every newly prepared representation.
_requested_wannierization_mode(config::SymmetryAdaptedWannierizationConfig) =
    config.input.wannierization_mode
# Read the preparation-specific mode without routing through the SAWF groups.
_requested_wannierization_mode(config::BandRepresentationPreparationConfig) =
    config.wannierization_mode

# Persist the requested and effective modes in the prepared representation.
function _representation_with_mode_contract(
    representation::BandRepresentation,
    config::Union{SymmetryAdaptedWannierizationConfig, BandRepresentationPreparationConfig};
    preserve_public_origin_absence::Bool = false,
)
    conventions = Dict{String, String}(representation.conventions)
    if !preserve_public_origin_absence
        conventions["pre_unified_schema_version"] =
            representation.schema_version == "1.0" ?
            get(conventions, "pre_unified_schema_version", representation.schema_version) :
            representation.schema_version
    end
    conventions["requested_wannierization_mode"] = String(_requested_wannierization_mode(config))
    conventions["effective_wannierization_mode"] = String(effective_wannierization_mode(config))
    conventions["representation_source"] = String(representation_source(config))
    conventions["symmetry_constraints_applied"] =
        string(symmetry_constraints_applied(config, representation))
    delete!(conventions, "symmetry_mode")
    return BandRepresentation(
        "1.16",
        representation.source_code,
        representation.spinor,
        representation.real_lattice,
        representation.reciprocal_lattice,
        representation.mp_grid,
        representation.kpoints_fractional,
        representation.energies_ev,
        representation.operations,
        representation.kpoint_map,
        representation.reciprocal_shifts,
        representation.sewing_matrices,
        representation.band_block_labels,
        representation.irreducible_indices,
        representation.full_to_irreducible,
        representation.full_to_operation;
        conventions,
        input_sha256 = representation.input_sha256,
    )
end

# Bind one finite-window symmetry-adapted representation to the authoritative
# ragged target scope shared by Native and Symmetrized DFT Hamiltonian routes.
function _validate_existing_target_subspace_contract(
    representation::BandRepresentation,
    qualification_scope::BandRepresentationQualificationScope,
    contract::TargetSubspaceQualificationContract,
)
    conventions = representation.conventions
    get(conventions, "qualification_scope", "") == "target_subspace" || return nothing
    for (key, expected) in (
        ("outer_mask_sha256", qualification_scope.outer_mask_sha256),
        ("frozen_mask_sha256", qualification_scope.frozen_mask_sha256),
        ("target_subspace_contract_sha256", contract.contract_sha256),
        ("target_leakage_semantics", TARGET_LEAKAGE_WEIGHT_SEMANTICS),
        ("target_leakage_formula_sha256", TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256),
        ("target_leakage_threshold", repr(contract.scoped_paw_thresholds.target_leakage_weight)),
    )
        get(conventions, key, "MISSING") == expected || throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: existing $(key) differs from current solver window",
            ),
        )
    end
    if haskey(representation.input_sha256, "TARGET_SUBSPACE_CONTRACT_SHA256")
        representation.input_sha256["TARGET_SUBSPACE_CONTRACT_SHA256"] ==
        contract.contract_sha256 || throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: input-bound target contract digest differs",
            ),
        )
    end
    return nothing
end

"""Bind a symmetry-adapted representation to its authoritative target-subspace contract."""
_workflow_input_config(config::SymmetryAdaptedWannierizationConfig) = config.input
# Preserve the independent preparation config API behind the same narrow input view.
_workflow_input_config(config::BandRepresentationPreparationConfig) = config

# Bind a representation to the target-subspace contract owned by its input view.
function _representation_with_target_subspace_contract(
    representation::BandRepresentation,
    config::Union{SymmetryAdaptedWannierizationConfig, BandRepresentationPreparationConfig},
    qualification_scope::BandRepresentationQualificationScope,
)
    input = _workflow_input_config(config)
    effective_wannierization_mode(config) == :symmetry_adapted || return representation
    bounds = (input.outer_min_ev, input.outer_max_ev, input.frozen_min_ev, input.frozen_max_ev)
    if !all(isfinite, bounds)
        get(representation.conventions, "qualification_scope", "full_parent") ==
        "target_subspace" && throw(
            ArgumentError(
                "TARGET_SUBSPACE_WINDOWS_REQUIRED: target authority requires finite outer and frozen windows",
            ),
        )
        return representation
    end
    contract = TargetSubspaceQualificationContract(
        qualification_scope;
        outer_min_ev = input.outer_min_ev,
        outer_max_ev = input.outer_max_ev,
        frozen_min_ev = input.frozen_min_ev,
        frozen_max_ev = input.frozen_max_ev,
        num_wannier = configured_num_wannier(config),
        scoped_paw_thresholds = input.wavefunction_gauge_backend isa StarCovariantPAWGauge ?
                                input.wavefunction_gauge_backend.thresholds :
                                PAWGaugeThresholds(),
        target_complement_maximum_element_ev = input.authoritative_hamiltonian isa
                                               SymmetrizedDFTHamiltonian ?
                                               input.authoritative_hamiltonian.completion.target_complement_max_element_ev :
                                               5.0e-6,
    )
    _validate_existing_target_subspace_contract(representation, qualification_scope, contract)
    conventions = Dict{String, String}(representation.conventions)
    conventions["authoritative_hamiltonian"] =
        authoritative_hamiltonian_key(input.authoritative_hamiltonian)
    conventions["authoritative_hamiltonian_sha256"] =
        star_authoritative_hamiltonian_sha256(input.authoritative_hamiltonian)
    conventions["qualification_scope"] = "target_subspace"
    conventions["target_authority"] = "outer_window"
    conventions["parent_audit_policy"] = "audit_only"
    conventions["outer_mask_sha256"] = qualification_scope.outer_mask_sha256
    conventions["frozen_mask_sha256"] = qualification_scope.frozen_mask_sha256
    conventions["target_subspace_contract_sha256"] = contract.contract_sha256
    conventions["target_leakage_semantics"] = TARGET_LEAKAGE_WEIGHT_SEMANTICS
    conventions["target_leakage_formula_sha256"] = TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256
    conventions["target_leakage_threshold"] =
        repr(contract.scoped_paw_thresholds.target_leakage_weight)
    conventions["target_scope_production_eligible"] =
        get(conventions, "target_scope_production_eligible", "false")
    conventions["scoped_production_eligible"] =
        get(conventions, "scoped_production_eligible", "false")
    input_sha256 = merge(
        representation.input_sha256,
        Dict("TARGET_SUBSPACE_CONTRACT_SHA256" => contract.contract_sha256),
    )
    return BandRepresentation(
        "1.17",
        representation.source_code,
        representation.spinor,
        representation.real_lattice,
        representation.reciprocal_lattice,
        representation.mp_grid,
        representation.kpoints_fractional,
        representation.energies_ev,
        representation.operations,
        representation.kpoint_map,
        representation.reciprocal_shifts,
        representation.sewing_matrices,
        representation.band_block_labels,
        representation.irreducible_indices,
        representation.full_to_irreducible,
        representation.full_to_operation;
        conventions,
        input_sha256,
    )
end

"""Seal a completed preparation's wire identity without changing its arrays or qualification.

The caller has already computed mode, authority, target scope, diagnostics, and compatibility.
Internal construction tags remain separate; even diagnostic outcomes require the full public
field contract before they can be returned or persisted.
"""
function _completed_public_band_representation(representation::BandRepresentation)
    representation.schema_version in ("1.16", "1.17") || throw(
        ArgumentError(
            "BAND_REPRESENTATION_PREPARATION_INCOMPLETE: completed mode contract required",
        ),
    )
    completed = BandRepresentation(
        "1.0",
        representation.source_code,
        representation.spinor,
        representation.real_lattice,
        representation.reciprocal_lattice,
        representation.mp_grid,
        representation.kpoints_fractional,
        representation.energies_ev,
        representation.operations,
        representation.kpoint_map,
        representation.reciprocal_shifts,
        representation.sewing_matrices,
        representation.band_block_labels,
        representation.irreducible_indices,
        representation.full_to_irreducible,
        representation.full_to_operation;
        conventions = representation.conventions,
        input_sha256 = representation.input_sha256,
    )
    SymmetryFoundation.validate_public_band_representation_contract(completed)
    return completed
end

# Return the maximum sewing-matrix unitarity residual.
function _maximum_sewing_unitarity_error(representation::BandRepresentation)
    nb = size(representation.sewing_matrices, 1)
    identity_matrix = Matrix{ComplexF64}(I, nb, nb)
    maximum_error = 0.0
    for kpoint in axes(representation.sewing_matrices, 4),
        operation in axes(representation.sewing_matrices, 3)

        sewing = @view representation.sewing_matrices[:, :, operation, kpoint]
        maximum_error = max(maximum_error, maximum(abs, sewing' * sewing - identity_matrix))
    end
    return maximum_error
end

# Check permutation coverage of every full-mesh group action.
function _validate_kpoint_action(representation::BandRepresentation)
    expected = collect(1:size(representation.kpoint_map, 2))
    for operation in axes(representation.kpoint_map, 1)
        sort(@view(representation.kpoint_map[operation, :])) == expected ||
            throw(ArgumentError("operation $(operation) is not a permutation of the k mesh"))
    end
    return nothing
end

# Attach the durable terminal boundary to a result without changing solver arrays.
function _result_for_terminal_persistence(result::WannierizationResult)
    summary = Dict{String, String}(result.input_summary)
    accepted = result.restart_state === nothing ? -1 : result.restart_state.iteration
    attempted = parse(Int, get(summary, "last_attempted_iteration", string(accepted)))
    summary["solver_status"] = get(summary, "solver_status", string(result.status))
    summary["stopping_reason"] = get(summary, "stopping_reason", checkpoint_stopping_reason(result))
    summary["last_attempted_iteration"] = string(attempted)
    summary["last_accepted_iteration"] = string(accepted)
    summary["last_persisted_iteration"] = string(accepted)
    summary["has_accepted_state"] = string(accepted >= 0)
    summary["legacy_terminal_semantics"] = get(summary, "legacy_terminal_semantics", "false")
    summary["convergence_metric_name"] =
        get(summary, "convergence_metric_name", "center_spread_window_std_max")
    summary["convergence_metric"] = get(
        summary,
        "convergence_metric",
        isempty(result.history) ? "Inf" : string(last(result.history).spread_standard_deviation),
    )
    return updated_wannierization_result(result; input_summary = summary)
end

# A downstream model may use only a finite, invariant-valid accepted boundary.
function _has_accepted_wannierization_state(result::WannierizationResult)
    return result.restart_state !== nothing &&
           result.wannier_chk !== nothing &&
           get(result.input_summary, "has_accepted_state", "false") == "true" &&
           wannierization_result_is_finite(result)
end

# Construct one typed early failure from an exception and input paths.
function _workflow_failure(
    status::WannierizationStatus,
    code::Symbol,
    exception,
    config::SymmetryAdaptedWannierizationConfig,
    backtrace = nothing,
)
    summary = Dict(
        "win_file" => abspath(config.input.win_file),
        "eig_file" => abspath(config.input.eig_file),
        "mmn_file" => abspath(config.input.mmn_file),
        "initialization" => String(config.solver.initialization),
        "requested_wannierization_mode" => String(config.input.wannierization_mode),
        "effective_wannierization_mode" => String(effective_wannierization_mode(config)),
        "representation_source" => try
            String(representation_source(config))
        catch
            "UNRESOLVED"
        end,
        "symmetry_constraints_applied" => string(symmetry_constraints_applied(config)),
    )
    return WannierizationResult(
        status,
        zeros(ComplexF64, 0, 0, 0),
        zeros(Float64, 0, 3),
        Float64[],
        WannierizationIteration[],
        [
            WannierizationDiagnostic(
                code,
                :error,
                sprint(showerror, exception);
                context = backtrace === nothing ? Dict{String, String}() :
                          Dict("stacktrace" => sprint(Base.show_backtrace, backtrace)),
            ),
        ],
        summary,
        nothing,
        nothing,
    )
end

# Materialize the exact solver windows once for the static compatibility preflight.
function _compatibility_window_masks(
    config::Union{SymmetryAdaptedWannierizationConfig, BandRepresentationPreparationConfig},
    representation::BandRepresentation,
)
    return window_masks_from_energies(
        config,
        representation.energies_ev,
        representation.band_block_labels,
    )
end

# Analyze the mapped sewing matrices after construction without changing them.
function _mapped_representation_raw_diagnostics(
    representation::BandRepresentation,
    outer_masks::Vector{BitVector},
    frozen_masks::Vector{BitVector},
)
    all(isfinite, representation.sewing_matrices) || throw(
        ArgumentError("NONFINITE_SEWING_MATRIX: band representation contains non-finite values"),
    )
    num_bands, num_kpoints = size(representation.energies_ev)
    length(outer_masks) == num_kpoints == length(frozen_masks) ||
        throw(ArgumentError("qualification-mask k-point count is inconsistent"))
    diagnostics = RepresentationRawDiagnostic[]
    for source_kpoint in 1:num_kpoints, operation_index in eachindex(representation.operations)
        target_kpoint = representation.kpoint_map[operation_index, source_kpoint]
        operation = representation.operations[operation_index]
        for scope in (:full, :outer, :frozen, :outside)
            source_mask =
                scope == :full ? trues(num_bands) :
                scope == :outer ? outer_masks[source_kpoint] :
                scope == :frozen ? frozen_masks[source_kpoint] : .!outer_masks[source_kpoint]
            target_mask =
                scope == :full ? trues(num_bands) :
                scope == :outer ? outer_masks[target_kpoint] :
                scope == :frozen ? frozen_masks[target_kpoint] : .!outer_masks[target_kpoint]
            source_indices = findall(source_mask)
            target_indices = findall(target_mask)
            required_rank = min(length(source_indices), length(target_indices))
            if isempty(source_indices) || isempty(target_indices)
                push!(
                    diagnostics,
                    RepresentationRawDiagnostic(
                        scope,
                        operation_index,
                        source_kpoint,
                        target_kpoint,
                        operation.antiunitary,
                        length(source_indices),
                        length(target_indices),
                        required_rank,
                        0,
                        0.0,
                        0.0,
                        0.0,
                        Inf,
                        0.0,
                        0.0,
                        :EMPTY_SCOPE,
                    ),
                )
                continue
            end
            block = Matrix{ComplexF64}(
                @view representation.sewing_matrices[
                    target_indices,
                    source_indices,
                    operation_index,
                    source_kpoint,
                ]
            )
            singular_values = svdvals(block)
            maximum_singular = isempty(singular_values) ? 0.0 : maximum(singular_values)
            minimum_singular = isempty(singular_values) ? 0.0 : minimum(singular_values)
            rank_threshold = max(size(block)...) * eps(Float64) * max(maximum_singular, 1.0)
            numerical_rank = count(>(rank_threshold), singular_values)
            left_identity = Matrix{ComplexF64}(I, size(block, 1), size(block, 1))
            right_identity = Matrix{ComplexF64}(I, size(block, 2), size(block, 2))
            push!(
                diagnostics,
                RepresentationRawDiagnostic(
                    scope,
                    operation_index,
                    source_kpoint,
                    target_kpoint,
                    operation.antiunitary,
                    length(source_indices),
                    length(target_indices),
                    required_rank,
                    numerical_rank,
                    rank_threshold,
                    minimum_singular,
                    maximum_singular,
                    minimum_singular > 0.0 ? maximum_singular / minimum_singular : Inf,
                    maximum(abs, block * block' - left_identity),
                    maximum(abs, block' * block - right_identity),
                    length(source_indices) == length(target_indices) ? :REPORT_ONLY :
                    :DIMENSION_MISMATCH,
                ),
            )
        end
    end
    return diagnostics
end

# Convert canonical pre-polar construction records into the public typed contract.
function _construction_raw_diagnostics(construction_diagnostics, representation::BandRepresentation)
    scoped = filter(diagnostic -> haskey(diagnostic, "scope"), construction_diagnostics)
    expected = size(representation.energies_ev, 2) * length(representation.operations) * 4
    length(scoped) == expected || throw(
        ArgumentError(
            "canonical pre-polar raw diagnostic count $(length(scoped)) disagrees with $(expected)",
        ),
    )
    return RepresentationRawDiagnostic[
        RepresentationRawDiagnostic(
            Symbol(diagnostic["scope"]),
            diagnostic["operation"],
            diagnostic["source_kpoint"],
            diagnostic["target_kpoint"],
            representation.operations[diagnostic["operation"]].antiunitary,
            diagnostic["source_band_count"],
            diagnostic["target_band_count"],
            diagnostic["required_rank"],
            diagnostic["numerical_rank"],
            diagnostic["rank_threshold"],
            diagnostic["sigma_min"],
            diagnostic["sigma_max"],
            diagnostic["condition_estimate"],
            diagnostic["left_unitarity_residual"],
            diagnostic["right_unitarity_residual"],
            Symbol(diagnostic["status"]),
        ) for diagnostic in scoped
    ]
end

# Materialize explicit EMPTY_SCOPE diagnostics after removing a frozen window.
function _empty_frozen_raw_diagnostics(representation::BandRepresentation)
    return RepresentationRawDiagnostic[
        RepresentationRawDiagnostic(
            :frozen,
            operation_index,
            source_kpoint,
            representation.kpoint_map[operation_index, source_kpoint],
            representation.operations[operation_index].antiunitary,
            0,
            0,
            0,
            0,
            0.0,
            0.0,
            0.0,
            Inf,
            0.0,
            0.0,
            :EMPTY_SCOPE,
        ) for source_kpoint in axes(representation.energies_ev, 2) for
        operation_index in eachindex(representation.operations)
    ]
end

# A pre-1.16 artifact may be requalified without rereading plane waves only
# when the outer mask is unchanged. The 24-way campaign uses this to remove an
# existing frozen window; arbitrary new frozen masks require a detected rebuild.
function _requalified_stored_raw_diagnostics(
    stored_metadata,
    qualification_scope::BandRepresentationQualificationScope,
    representation::BandRepresentation,
)
    stored_scope = stored_metadata.qualification_scope
    stored_scope.diagnostic_status == :UNAVAILABLE_LEGACY_SCHEMA &&
        return stored_metadata.raw_diagnostics
    stored_scope.outer_mask_sha256 == qualification_scope.outer_mask_sha256 || throw(
        ArgumentError(
            "RAW_DIAGNOSTIC_REQUALIFICATION_REQUIRES_DETECTED_SOURCE: outer mask changed",
        ),
    )
    stored_scope.frozen_mask_sha256 == qualification_scope.frozen_mask_sha256 &&
        return stored_metadata.raw_diagnostics
    any(qualification_scope.frozen_mask) && throw(
        ArgumentError(
            "RAW_DIAGNOSTIC_REQUALIFICATION_REQUIRES_DETECTED_SOURCE: a new frozen mask cannot be reconstructed from polar sewing",
        ),
    )
    retained = filter(diagnostic -> diagnostic.scope != :frozen, stored_metadata.raw_diagnostics)
    return vcat(retained, _empty_frozen_raw_diagnostics(representation))
end

# Preserve first occurrence while retaining distinct operations, measurements, and failure contexts.
function _unique_construction_diagnostics(diagnostics)
    retained = WannierizationDiagnostic[]
    seen = Set{Tuple{Symbol, Symbol, String, Tuple}}()
    for diagnostic in diagnostics
        key = (
            diagnostic.code,
            diagnostic.severity,
            diagnostic.message,
            Tuple(sort!(collect(diagnostic.context); by = first)),
        )
        key in seen && continue
        push!(seen, key)
        push!(retained, diagnostic)
    end
    return retained
end

# Preserve measured center-mapping quality independently of construction admission.
function _center_mapping_diagnostics(records)
    return [
        WannierizationDiagnostic(
            Symbol(record.code),
            :warning,
            "A projection-plan quality check exceeded its strict tolerance.";
            context = merge(
                Dict(
                    string(key) => string(value) for (key, value) in pairs(record) if key != :code
                ),
                Dict("gate_result" => String(record.result)),
            ),
        ) for record in records if record.result == "FAIL"
    ]
end

# Resolve admission independently of magnetic representation quality assessment.
function _effective_compatibility_policy(
    requested::Symbol,
    representation::BandRepresentation,
    inventory;
    public_origin_fallback_validated::Bool = false,
    construction_policy::Symbol = :strict,
)
    construction_policy == :diagnostic && return requested
    magnetic =
        inventory !== nothing ? inventory.magnetic :
        lowercase(get(representation.conventions, "magnetic_structure", "unknown")) == "true"
    antiunitary = any(operation.antiunitary for operation in representation.operations)
    recorded_origin =
        get(representation.conventions, "pre_unified_schema_version", representation.schema_version)
    legacy_uncertain = !(
        (public_origin_fallback_validated && recorded_origin == "1.0") || recorded_origin in (
            "1.4",
            "1.5",
            "1.6",
            "1.7",
            "1.8",
            "1.9",
            "1.10",
            "1.11",
            "1.12",
            "1.13",
            "1.14",
            "1.15",
            "1.16",
            "1.17",
        )
    )
    return magnetic || antiunitary || legacy_uncertain ? :strict : requested
end

# Copy a preparation config with its resolved projection basis and dimension.
function _preparation_with_projection_basis(
    config::BandRepresentationPreparationConfig,
    basis::WannierProjectionBasis,
)
    names = fieldnames(BandRepresentationPreparationConfig)
    values = NamedTuple{names}(Tuple(getfield(config, name) for name in names))
    dimension = config.num_wannier == 0 ? basis.num_wannier : config.num_wannier
    return BandRepresentationPreparationConfig(;
        merge(values, (projection_basis = basis, num_wannier = dimension))...,
    )
end

"""Prepare and optionally persist one complete public schema-1.0 band representation."""
function prepare_band_representation(original_config::BandRepresentationPreparationConfig)
    original_config.construction_policy in (:diagnostic, :strict) ||
        throw(ArgumentError("construction_policy must be :diagnostic or :strict"))
    basis =
        original_config.projection_basis === nothing ?
        build_wannier_projection_basis(original_config.win_file) : original_config.projection_basis
    config = _preparation_with_projection_basis(original_config, basis)
    eig = IO.read_wannier_eig(config.eig_file)
    num_wannier = configured_num_wannier(config)
    inventory = nothing
    stored_metadata = nothing
    detected_raw_diagnostics = nothing
    representation_source_kind = representation_source(config)
    ordinary = effective_wannierization_mode(config) == :ordinary
    representation = if ordinary
        if config.band_representation_hdf5 === nothing
            identity_band_representation(config, basis, eig)
        else
            supplied = read_band_representation_hdf5(something(config.band_representation_hdf5))
            supplied.schema_version == "1.0" || throw(
                ArgumentError(
                    "ORDINARY_IDENTITY_REPRESENTATION_REGENERATION_REQUIRED: legacy identity " *
                    "representations do not carry the unified mode contract",
                ),
            )
            stored_metadata = read_band_representation_preparation_hdf5(
                something(config.band_representation_hdf5),
                supplied,
            )
            inventory = stored_metadata.inventory
            validate_no_symmetry_identity_representation(supplied, config.representation_tolerance)
            supplied
        end
    elseif representation_source_kind == :provided
        if config.band_representation !== nothing
            config.band_representation
        else
            supplied = read_band_representation_hdf5(something(config.band_representation_hdf5))
            stored_metadata = read_band_representation_preparation_hdf5(
                something(config.band_representation_hdf5),
                supplied,
            )
            inventory = stored_metadata.inventory
            supplied
        end
    else
        gauge_source = _read_wavefunction_gauge_source(
            something(config.source),
            config.sewing_backend,
            config.wavefunction_gauge_backend,
            config.authoritative_hamiltonian,
            config.wavefunction_gauge_hdf5;
            construction_policy = config.construction_policy,
        )
        native = gauge_source.native
        inventory = detect_magnetic_symmetry_inventory(
            native.structure;
            include_time_reversal = config.source.include_time_reversal,
            symmetry_tolerance = config.symmetry_tolerance,
        )
        labels = canonical_band_block_labels(eig.data, config.degeneracy_tolerance_ev)
        diagnostic_outer_masks, diagnostic_frozen_masks =
            window_masks_from_energies(config, eig.data, labels)
        built = build_band_representation(
            native,
            eig.data,
            inventory.operations,
            config.degeneracy_tolerance_ev;
            symmetry_inventory = inventory,
            diagnostic_outer_masks,
            diagnostic_frozen_masks,
            source = config.source,
            sewing_backend = config.sewing_backend,
            strict_metric = gauge_source.strict_metric,
            construction_policy = config.construction_policy,
            return_diagnostics = true,
        )
        detected_raw_diagnostics =
            _construction_raw_diagnostics(built.construction_diagnostics, built.representation)
        _representation_with_wavefunction_gauge(
            built.representation,
            config.wavefunction_gauge_backend,
            config.authoritative_hamiltonian,
            gauge_source.artifact_sha256,
            gauge_source.block_partition_metadata,
        )
    end
    # Remember a validated public input before the binders can complete a legacy object.
    public_input_complete =
        representation.schema_version == "1.0" && all(
            key -> haskey(representation.conventions, key),
            (
                "requested_wannierization_mode",
                "effective_wannierization_mode",
                "representation_source",
                "symmetry_constraints_applied",
            ),
        )
    if public_input_complete
        SymmetryFoundation.validate_public_band_representation_contract(representation)
    end
    public_origin_fallback_validated =
        public_input_complete && !haskey(representation.conventions, "pre_unified_schema_version")
    representation = _representation_with_mode_contract(
        representation,
        config;
        preserve_public_origin_absence = public_origin_fallback_validated,
    )
    _validate_sewing_backend_identity(config.sewing_backend, representation)
    _validate_wavefunction_gauge_identity(
        config.wavefunction_gauge_backend,
        config.wavefunction_gauge_hdf5,
        representation,
    )
    _validate_authoritative_hamiltonian_identity(config.authoritative_hamiltonian, representation)
    _validate_kpoint_action(representation)
    size(representation.energies_ev) == size(eig.data) ||
        throw(ArgumentError("band representation and EIG dimensions disagree"))
    representation = _representation_with_hashes(
        representation,
        Dict("WIN" => sha256_file(config.win_file), "EIG" => sha256_file(config.eig_file)),
    )
    mapping_diagnostics = NamedTuple[]
    plan =
        ordinary ? identity_wannier_plan(num_wannier, only(representation.operations)) :
        build_wannier_symmetry_plan(
            basis,
            representation.operations;
            tolerance = config.target_center_matching_tolerance,
            construction_policy = config.construction_policy,
            mapping_diagnostics,
        )
    if config.construction_policy == :diagnostic
        representation.conventions["construction_policy"] = "diagnostic"
        representation.conventions["construction_mapping_diagnostics"] = JSON3.write([
            Dict(
                string(key) =>
                    value isa AbstractFloat && !isfinite(value) ? string(value) : value for
                (key, value) in pairs(record)
            ) for record in mapping_diagnostics
        ])
    end
    outer_masks, frozen_masks = _compatibility_window_masks(config, representation)
    qualification_scope = BandRepresentationQualificationScope(
        BitMatrix(hcat(outer_masks...)),
        BitMatrix(hcat(frozen_masks...)),
    )
    representation =
        _representation_with_target_subspace_contract(representation, config, qualification_scope)
    raw_diagnostics = if detected_raw_diagnostics !== nothing
        detected_raw_diagnostics
    elseif stored_metadata !== nothing
        _requalified_stored_raw_diagnostics(stored_metadata, qualification_scope, representation)
    else
        _mapped_representation_raw_diagnostics(representation, outer_masks, frozen_masks)
    end
    compatibility_report =
        ordinary ?
        no_symmetry_compatibility_contract(representation, config.representation_tolerance) :
        validate_band_representation_compatibility(
            representation,
            plan;
            outer_mask = outer_masks,
            frozen_mask = frozen_masks,
            tolerance = config.representation_tolerance,
        )
    effective_policy = _effective_compatibility_policy(
        config.compatibility_policy,
        representation,
        inventory;
        public_origin_fallback_validated,
        construction_policy = config.construction_policy,
    )
    tolerance_status = representation_source_kind == :detected ? :APPLIED : :NOT_APPLICABLE
    diagnostics = WannierizationDiagnostic[compatibility_report.diagnostics...]
    if haskey(representation.conventions, "paw_sewing_gate_records_json")
        records = JSON3.read(representation.conventions["paw_sewing_gate_records_json"])
        records isa AbstractVector || throw(ArgumentError("PAW_SEWING_DIAGNOSTICS_INVALID"))
        for record in records
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    Symbol(record["code"]),
                    Symbol(record["severity"]),
                    String(record["message"]);
                    context = Dict(
                        String(key) => string(value) for (key, value) in pairs(record["context"])
                    ),
                ),
            )
        end
    end
    append!(diagnostics, _center_mapping_diagnostics(mapping_diagnostics))
    gauge_metrics = get(representation.conventions, "construction_gauge_metrics_json", "")
    if !isempty(gauge_metrics)
        metrics = JSON3.read(gauge_metrics, Dict{String, Float64})
        for key in sort!(collect(keys(metrics)))
            startswith(key, "construction_") && endswith(key, "_failed") || continue
            metrics[key] > 0.0 || continue
            prefix = key[1:(end - length("_failed"))]
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :GAUGE_QUALITY_DIAGNOSTIC_CONTINUE,
                    :warning,
                    "A retained wavefunction preparation quality check failed.";
                    context = Dict(
                        "stage" => "prepare_wavefunctions",
                        "metric" => prefix,
                        "gate_result" => "FAIL",
                        "value" => string(get(metrics, prefix * "_value", NaN)),
                        "threshold" => string(get(metrics, prefix * "_threshold", NaN)),
                        "action" => "CONTINUE_DIAGNOSTIC",
                    ),
                ),
            )
        end
    end
    if !compatibility_report.passed && config.construction_policy == :diagnostic
        push!(
            diagnostics,
            WannierizationDiagnostic(
                :REPRESENTATION_QUALITY_DIAGNOSTIC_CONTINUE,
                :warning,
                "Representation quality failed; retain the available constraints for diagnostic construction.";
                context = Dict(
                    "stage" => "prepare_representation",
                    "gate_result" => "FAIL",
                    "action" => "CONTINUE_DIAGNOSTIC",
                ),
            ),
        )
    end
    if effective_policy != config.compatibility_policy
        push!(
            diagnostics,
            WannierizationDiagnostic(
                :COMPATIBILITY_POLICY_ESCALATED,
                :warning,
                "Construction policy resolved the compatibility admission decision.";
                context = Dict(
                    "requested" => String(config.compatibility_policy),
                    "effective" => String(effective_policy),
                ),
            ),
        )
    end
    status =
        compatibility_report.passed ?
        (isempty(filter(d -> d.severity == :warning, diagnostics)) ? :PASS : :PASS_WITH_WARNINGS) :
        config.construction_policy == :strict && effective_policy == :strict ? :FAILED :
        :PASS_WITH_WARNINGS
    representation = _completed_public_band_representation(representation)
    output_hdf5 = if config.output_hdf5 === nothing
        nothing
    else
        write_band_representation_hdf5(
            something(config.output_hdf5),
            representation,
            compatibility_report;
            inventory,
            raw_diagnostics,
            qualification_scope,
            requested_policy = config.compatibility_policy,
            effective_policy,
            symmetry_tolerance_status = tolerance_status,
        )
    end
    artifact_sha256 = output_hdf5 === nothing ? nothing : sha256_file(something(output_hdf5))
    return BandRepresentationPreparationResult(
        status,
        representation,
        inventory,
        raw_diagnostics,
        qualification_scope,
        compatibility_report,
        config.compatibility_policy,
        effective_policy,
        tolerance_status,
        output_hdf5,
        artifact_sha256,
        diagnostics,
    )
end

# Reject only restarts whose numerical trajectory used the affected
# no-symmetry frozen initializer. Other restart modes remain schema-compatible.
function _validate_restart_initializer_algorithm(
    config::SymmetryAdaptedWannierizationConfig,
    frozen_masks,
    restart_result,
)
    config.solver.initialization == :restart || return nothing
    effective_wannierization_mode(config) == :ordinary || return nothing
    any(any, frozen_masks) || return nothing
    recorded_algorithm =
        get(restart_result.input_summary, "initializer_algorithm_version", "NOT_RECORDED")
    recorded_algorithm == "nosym_exact_frozen_rowspace_v2" && return nothing
    effective_algorithms = effective_wannierization_algorithms(config)
    if recorded_algorithm == "wannier90-4.0.1-dis_project-dis_proj_froz-v1" &&
       effective_algorithms.disentanglement == :smv_fletcher_reeves_two_stage &&
       config.solver.initialization_backend isa Wannierization.AMNExactFrozenInitialization
        # A two-stage Wannier90-reference restart owns the already sealed
        # dis_project/dis_proj_froz result.  It must not be reclassified as the
        # generic no-symmetry row-space initializer merely because the public
        # initialization selector is now `:restart`.
        return nothing
    end
    if recorded_algorithm == "NOT_RECORDED" &&
       config.solver.initialization_backend isa Wannierization.PAWSCDMInitialization &&
       get(restart_result.input_summary, "checkpoint_schema_version", "") == "2.24" &&
       restart_result.restart_state !== nothing &&
       something(restart_result.restart_state).config_sha256 == restart_config_sha256(config)
        # Durable in-progress schema-2.24 checkpoints may predate terminal-summary
        # enrichment and may omit the human-readable initializer version.  For
        # PAW-SCDM, the same checkpoint binds the initialization backend and the
        # complete PAW-SCDM artifact digest in `config_sha256`; accepting only an
        # exact contract match preserves fail-closed provenance without making
        # a long Z stage non-restartable.
        return nothing
    end
    throw(
        ArgumentError(
            "RESTART_INITIALIZER_ALGORITHM_MISMATCH: no-symmetry frozen restart " *
            "requires nosym_exact_frozen_rowspace_v2, found $(recorded_algorithm)",
        ),
    )
end

# Reject legacy or otherwise read-only checkpoints before numerical continuation.
function _validate_restart_schema_for_continuation(restart_result::WannierizationResult)
    get(restart_result.input_summary, "restart_eligible", "false") == "true" && return nothing
    phase =
        restart_result.restart_state === nothing ? :unknown :
        restart_result.restart_state.optimizer_state.phase
    recorded_schedule = Symbol(
        get(
            restart_result.input_summary,
            "optimizer_schedule",
            get(restart_result.input_summary, "schedule", "unknown"),
        ),
    )
    if phase in (:z, :u, :nested) || recorded_schedule == :nested
        throw(
            ArgumentError(
                "UNSUPPORTED_LEGACY_SCHEDULE: legacy nested checkpoint cannot be resumed",
            ),
        )
    end
    version = get(restart_result.input_summary, "checkpoint_schema_version", "unknown")
    throw(
        ArgumentError(
            "RESTART_SEMANTICS_INCOMPATIBLE: checkpoint schema $(version) is read-only; " *
            "start a fresh schema-2.24 trajectory",
        ),
    )
end

# Preserve a typed static incompatibility without entering the numerical solver.
function _compatibility_failure_result(
    representation::BandRepresentation,
    report::RepresentationCompatibilityReport,
)
    diagnostics =
        isempty(report.diagnostics) ?
        [
            WannierizationDiagnostic(
                :REPRESENTATION_INCOMPATIBLE,
                :error,
                "static representation compatibility preflight failed",
            ),
        ] : report.diagnostics
    undetermined = report.assessment_status == REPRESENTATION_UNDETERMINED
    status =
        undetermined ? REPRESENTATION_VALIDATION_UNDETERMINED :
        Wannierization.REPRESENTATION_INCOMPATIBLE
    return WannierizationResult(
        status,
        zeros(ComplexF64, 0, 0, 0),
        zeros(Float64, 0, 3),
        Float64[],
        WannierizationIteration[],
        diagnostics,
        Dict(
            "source_code" => String(representation.source_code),
            "schema_version" => representation.schema_version,
            "representation_sha256" => report.representation_sha256,
            "failure_class" => undetermined ? "NONE" : "REPRESENTATION_A",
            "gate_definition_status" => string(report.gate_definition_status),
            "representation_assessment_status" => string(report.assessment_status),
        ),
        nothing,
        nothing,
    )
end

"""
Construct symmetry-adapted Wannier functions from native Julia DFT adapters.

The workflow keeps DFT input read-only, materializes only versioned HDF5
artifacts, runs the static operation/band/window/target compatibility preflight
before the numerical solver, and uses independent Z/U mixing.
"""
function construct_symmetry_adapted_wannier_functions(
    original_config::SymmetryAdaptedWannierizationConfig,
)
    mpi_execution = original_config.solver.parallel == :mpi
    mpi_execution && !MPI.Initialized() && MPI.Init()
    root_process = !mpi_execution || MPI.Comm_rank(MPI.COMM_WORLD) == 0
    configured_paths =
        original_config.checkpoint.checkpoint_hdf5 === nothing ? nothing :
        wannierization_output_paths(original_config.checkpoint.checkpoint_hdf5)
    # Durable output has one authoritative owner. Non-root ranks execute the
    # identical numerical trajectory but never open logs/checkpoints/TB files.
    paths = root_process ? configured_paths : nothing
    log_io = nothing
    eig_for_tb = nothing
    mmn_for_tb = nothing
    representation_for_tb = nothing
    plan_for_tb = nothing
    operator_target_contract_for_tb = nothing
    timed = @timed try
        validate_wannierization_config(original_config)
        eig = IO.read_wannier_eig(original_config.input.eig_file)
        eig_for_tb = eig
        basis =
            original_config.input.projection_basis === nothing ?
            build_wannier_projection_basis(original_config.input.win_file) :
            original_config.input.projection_basis
        config = _config_with_projection_basis(original_config, basis)
        resolved_matrices = _resolve_wannier_matrix_elements(config, basis)
        operator_oracle_mmn_file = _operator_oracle_mmn_file(resolved_matrices)
        mmn = resolved_matrices.mmn
        mmn_for_tb = mmn
        num_wannier = configured_num_wannier(config)
        preparation = prepare_band_representation(
            BandRepresentationPreparationConfig(
                construction_policy = config.input.construction_policy,
                wannierization_mode = config.input.wannierization_mode,
                source = config.input.source,
                sewing_backend = config.input.sewing_backend,
                wavefunction_gauge_backend = config.input.wavefunction_gauge_backend,
                wavefunction_gauge_hdf5 = config.input.wavefunction_gauge_hdf5,
                authoritative_hamiltonian = config.input.authoritative_hamiltonian,
                win_file = config.input.win_file,
                eig_file = config.input.eig_file,
                projection_basis = basis,
                band_representation = config.input.band_representation,
                band_representation_hdf5 = config.input.band_representation_hdf5,
                output_hdf5 = config.output.band_representation_output_hdf5,
                outer_min_ev = config.input.outer_min_ev,
                outer_max_ev = config.input.outer_max_ev,
                frozen_min_ev = config.input.frozen_min_ev,
                frozen_max_ev = config.input.frozen_max_ev,
                frozen_states = config.input.frozen_states,
                num_wannier = num_wannier,
                symmetry_tolerance = config.input.symmetry_tolerance,
                degeneracy_tolerance_ev = config.input.degeneracy_tolerance_ev,
                representation_tolerance = config.input.representation_tolerance,
                target_center_matching_tolerance = config.input.target_center_matching_tolerance,
                compatibility_policy = config.input.compatibility_policy,
            ),
        )
        parent_representation = _representation_with_hashes(
            preparation.representation,
            Dict("MMN" => sha256_file(resolved_matrices.mmn_file)),
        )
        operator_target_contract =
            config.output.profile == :full ?
            wannier_operator_target_contract(
                config,
                eig,
                mmn,
                operator_oracle_mmn_file,
                resolved_matrices.mmn_file,
            ) : nothing
        operator_target_contract_for_tb = operator_target_contract
        operator_profile_preflight = preflight_wannierization_operator_profile(
            config,
            eig,
            mmn,
            operator_target_contract,
        )
        operator_profile_checkpoint_summary = Dict{String, String}(
            "operator_profile_preflight_$(key)" => value for
            (key, value) in operator_profile_preflight
        )
        scope = config.solver.acceleration.constraint_operation_scope
        scoped = constraint_scoped_representation(parent_representation, scope)
        representation = scoped.representation
        representation_for_tb = representation
        plan =
            effective_wannierization_mode(config) == :ordinary ?
            identity_wannier_plan(num_wannier, only(representation.operations)) :
            build_wannier_symmetry_plan(
                basis,
                representation.operations;
                tolerance = config.input.target_center_matching_tolerance,
                construction_policy = config.input.construction_policy,
            )
        plan_for_tb = plan
        outer_masks = [
            BitVector(preparation.qualification_scope.outer_mask[:, kpoint]) for
            kpoint in axes(preparation.qualification_scope.outer_mask, 2)
        ]
        frozen_masks = [
            BitVector(preparation.qualification_scope.frozen_mask[:, kpoint]) for
            kpoint in axes(preparation.qualification_scope.frozen_mask, 2)
        ]
        compatibility_report = if scope == :full
            preparation.compatibility_report
        else
            validate_band_representation_compatibility(
                representation,
                plan;
                outer_mask = outer_masks,
                frozen_mask = frozen_masks,
                tolerance = config.input.representation_tolerance,
            )
        end
        requested_policy = config.input.compatibility_policy
        config = _config_with_compatibility_policy(
            config,
            preparation.effective_compatibility_policy,
        )
        paths === nothing || (
            log_io = open_wannierization_log(
                paths.log,
                config,
                representation;
                compatibility = compatibility_report,
                restart = config.solver.initialization == :restart,
            )
        )
        if !compatibility_report.passed &&
           config.input.construction_policy == :strict &&
           preparation.effective_compatibility_policy == :strict
            _compatibility_failure_result(representation, compatibility_report)
        else
            need_native = config.solver.initialization == :amn && resolved_matrices.amn === nothing
            native =
                need_native ?
                read_native_source(something(config.input.source); purpose = :physical_overlap) : nothing
            amn = if config.solver.initialization == :amn
                resolved_matrices.amn === nothing ? generate_amn(native, basis) : resolved_matrices.amn
            elseif config.solver.initialization == :restart
                # A checkpoint taken during Z does not own the yet-unstarted U
                # gauge.  The two-stage contract requires the sealed subspace
                # to reproject the same frozen raw AMN at Z->U, exactly as a
                # from-scratch run does.  Once optimizer_phase=:localization,
                # the persisted recursive M/U state remains authoritative and
                # this read-only AMN reference is not used to overwrite it.
                resolved_matrices.amn
            else
                nothing
            end
            restart_result =
                config.solver.initialization == :restart ?
                read_wannierization_checkpoint_hdf5(config.checkpoint.restart_hdf5) : nothing
            if restart_result !== nothing
                recorded_policy = get(restart_result.input_summary, "construction_policy", "strict")
                recorded_policy == String(config.input.construction_policy) ||
                    throw(ArgumentError("RESTART_CONSTRUCTION_POLICY_MISMATCH"))
                if config.output.profile == :full
                    for (key, value) in operator_profile_checkpoint_summary
                        get(restart_result.input_summary, key, "MISSING") == value || throw(
                            ArgumentError(
                                "OPERATOR_PROFILE_RESTART_SNAPSHOT_MISMATCH: $(key) differs",
                            ),
                        )
                    end
                end
            end
            fixed_subspace =
                config.solver.initialization == :fixed_subspace ?
                read_wannierization_fixed_subspace_hdf5(config.checkpoint.fixed_subspace_hdf5) :
                nothing
            paw_scdm_input =
                if config.solver.initialization_backend isa Wannierization.PAWSCDMInitialization
                    artifact = read_paw_scdm_input_artifact(
                        something(config.solver.paw_scdm_input_hdf5),
                    )
                    config.input.construction_policy == :strict &&
                        get(artifact.source_identity, "gauge_quality_status", "PASS") != "PASS" &&
                        throw(
                            ArgumentError("SCDM_DIAGNOSTIC_GAUGE_REQUIRES_DIAGNOSTIC_CONSTRUCTION"),
                        )
                    ordinary = effective_wannierization_mode(config) == :ordinary
                    if ordinary
                        # The strict gauge/representation authority is the
                        # self-contained PAW-S input provenance only. It must
                        # not become the ordinary solver's symmetry authority.
                        get(artifact.source_identity, "source_gauge_sha256", "MISSING") ==
                        artifact.source_gauge_sha256 || throw(
                            ArgumentError(
                                "SCDM_INPUT_PRECONDITION: source gauge provenance differs",
                            ),
                        )
                        get(artifact.source_identity, "strict_representation_sha256", "MISSING") == artifact.strict_representation_sha256 || throw(
                            ArgumentError(
                                "SCDM_INPUT_PRECONDITION: strict representation provenance differs",
                            ),
                        )
                        get(artifact.source_identity, "metric_sha256", "MISSING") ==
                        artifact.metric_sha256 || throw(
                            ArgumentError("SCDM_INPUT_PRECONDITION: PAW metric provenance differs"),
                        )
                    else
                        config.input.wavefunction_gauge_hdf5 === nothing && throw(
                            ArgumentError("SCDM_INPUT_PRECONDITION: strict gauge HDF5 is required"),
                        )
                        gauge_sha256 =
                            sha256_file(something(config.input.wavefunction_gauge_hdf5))
                        if config.input.band_representation_hdf5 !== nothing
                            representation_sha256 =
                                sha256_file(something(config.input.band_representation_hdf5))
                            artifact.strict_representation_sha256 == representation_sha256 ||
                                throw(
                                    ArgumentError(
                                        "SCDM_INPUT_PRECONDITION: strict representation digest differs",
                                    ),
                                )
                        elseif representation_source(config) != :detected
                            throw(
                                ArgumentError(
                                    "SCDM_INPUT_PRECONDITION: strict representation HDF5 or detected rebuild is required",
                                ),
                            )
                        end
                        artifact.source_gauge_sha256 == gauge_sha256 || throw(
                            ArgumentError("SCDM_INPUT_PRECONDITION: strict gauge digest differs"),
                        )
                        authority = get(
                            representation.conventions,
                            "authoritative_hamiltonian",
                            "native_dft",
                        )
                        authority_sha256 = get(
                            representation.conventions,
                            "authoritative_hamiltonian_sha256",
                            "LEGACY_NATIVE_DFT",
                        )
                        artifact.authoritative_hamiltonian == authority || throw(
                            ArgumentError("SCDM_INPUT_PRECONDITION: Hamiltonian authority differs"),
                        )
                        artifact.authoritative_hamiltonian_sha256 == authority_sha256 || throw(
                            ArgumentError("SCDM_INPUT_PRECONDITION: authority digest differs"),
                        )
                    end
                    artifact
                else
                    nothing
                end
            if fixed_subspace !== nothing
                fixed_subspace = constraint_scoped_fixed_subspace(
                    something(fixed_subspace),
                    representation,
                    scoped.parent_sha256,
                    scoped.subgroup_sha256,
                    scope,
                )
            end
            restart_result === nothing ||
                _validate_restart_schema_for_continuation(restart_result)
            config.solver.initialization == :restart &&
                restart_result.restart_state === nothing &&
                throw(ArgumentError("checkpoint schema does not contain a complete restart state"))
            restart_result === nothing ||
                _validate_restart_initializer_algorithm(config, frozen_masks, restart_result)
            upstream_diagnostics = WannierizationDiagnostic[preparation.diagnostics...]
            restart_result === nothing ||
                append!(upstream_diagnostics, restart_result.diagnostics)
            if config.input.construction_policy == :diagnostic &&
               resolved_matrices.paw_result isa VASPPAWMatrixElementResult &&
               config.input.matrix_elements isa NativeVASPPAWMatrices
                append!(
                    upstream_diagnostics,
                    _native_vasp_paw_gate_diagnostics(
                        resolved_matrices.paw_result,
                        config.input.matrix_elements.thresholds,
                    ),
                )
            end
            if config.input.construction_policy == :diagnostic &&
               resolved_matrices.paw_result isa Wannierization.QEPAWMatrixElementResult &&
               config.input.matrix_elements isa
               Union{NativeQEPAWMatrices, SymmetryCompletedQEPAWMatrices}
                append!(
                    upstream_diagnostics,
                    _native_qe_paw_gate_diagnostics(
                        resolved_matrices.paw_result,
                        config.input.matrix_elements.thresholds,
                    ),
                )
            end
            if resolved_matrices.paw_result !== nothing && !resolved_matrices.paw_result.passed
                push!(
                    upstream_diagnostics,
                    WannierizationDiagnostic(
                        :NATIVE_PAW_QUALITY_DIAGNOSTIC_CONTINUE,
                        :warning,
                        join(resolved_matrices.paw_result.diagnostics, "; ");
                        context = Dict(
                            "stage" => "matrix_preparation",
                            "gate_result" => "FAIL",
                            "action" => "CONTINUE_DIAGNOSTIC",
                        ),
                    ),
                )
            end
            durable_observer =
                paths === nothing ? nothing :
                wannierization_observer(
                    config,
                    representation,
                    paths,
                    log_io,
                    operator_profile_checkpoint_summary,
                )
            observer = if durable_observer === nothing
                config.runtime.iteration_observer
            else
                function (summary, state, history, diagnostics)
                    durable_diagnostics = _unique_construction_diagnostics(
                        vcat(diagnostics, upstream_diagnostics),
                    )
                    durable_observer(summary, state, history, durable_diagnostics)
                    config.runtime.iteration_observer === nothing ||
                        config.runtime.iteration_observer(summary, state, history, diagnostics)
                end
            end
            solved = solve_symmetry_adapted_wannierization(
                config,
                representation,
                eig,
                mmn,
                plan;
                amn,
                restart = restart_result === nothing ? nothing : restart_result.v_matrix,
                restart_state = restart_result === nothing ? nothing : restart_result.restart_state,
                restart_history = restart_result === nothing ? WannierizationIteration[] :
                                  restart_result.history,
                restart_input_summary = restart_result === nothing ?
                                        Dict{String, String}() :
                                        restart_result.input_summary,
                fixed_subspace,
                observer,
                compatibility_report,
                initialization_amn_sha256 = resolved_matrices.amn_file === nothing ? "" :
                                            sha256_file(resolved_matrices.amn_file),
                paw_scdm_input,
            )
            summary = Dict{String, String}(solved.input_summary)
            merge!(summary, operator_profile_checkpoint_summary)
            summary["construction_policy"] = String(config.input.construction_policy)
            summary["manual_review_required"] =
                string(config.input.construction_policy == :diagnostic)
            summary["construction_gauge_metrics_json"] =
                get(representation.conventions, "construction_gauge_metrics_json", "")
            summary["compatibility_policy_requested"] = String(requested_policy)
            summary["compatibility_policy_effective"] =
                String(preparation.effective_compatibility_policy)
            summary["symmetry_tolerance"] = string(config.input.symmetry_tolerance)
            summary["symmetry_tolerance_status"] = String(preparation.symmetry_tolerance_status)
            summary["matrix_element_source"] = resolved_matrices.source_kind
            summary["matrix_element_gauge_sha256"] = resolved_matrices.gauge_sha256
            summary["matrix_element_gauge_provenance_file"] =
                resolved_matrices.gauge_provenance_file === nothing ? "" :
                abspath(resolved_matrices.gauge_provenance_file)
            summary["matrix_element_solver_amn_sha256"] =
                resolved_matrices.amn_file === nothing ? "" :
                sha256_file(resolved_matrices.amn_file)
            summary["matrix_element_raw_amn_sha256"] =
                resolved_matrices.raw_amn_file === nothing ? "" :
                sha256_file(resolved_matrices.raw_amn_file)
            if solved.restart_state !== nothing &&
               size(solved.v_matrix) == (
                size(representation.energies_ev, 1),
                num_wannier,
                size(representation.energies_ev, 2),
            )
                link_diagnostics = wannier_gauge_link_diagnostics(
                    solved.v_matrix,
                    mmn,
                    solved.restart_state.stencil.weights,
                )
                record_wannier_gauge_link_summary!(summary, link_diagnostics)
            end
            summary["constraint_operation_scope"] = String(scope)
            summary["constraint_operation_parent_representation_sha256"] = scoped.parent_sha256
            summary["constraint_operation_subgroup_sha256"] = scoped.subgroup_sha256
            summary["constraint_operation_parent_indices"] =
                join(scoped.parent_operation_indices, ',')
            if scope != :full
                summary["symmetry_ablation_classification"] = "DIAGNOSTIC_SYMMETRY_ABLATION"
                summary["route_selection_eligible"] = "false"
                summary["standard_tb_export_eligible"] = "false"
                summary["production_eligible"] = "false"
            end
            diagnostics =
                _unique_construction_diagnostics(vcat(solved.diagnostics, upstream_diagnostics))
            updated_wannierization_result(solved; input_summary = summary, diagnostics)
        end
    catch exception
        backtrace = catch_backtrace()
        status = exception isa ArgumentError ? INVALID_INPUT : IO_FAILURE
        code = status == INVALID_INPUT ? :INVALID_INPUT : :IO_FAILURE
        _workflow_failure(status, code, exception, original_config, backtrace)
    end
    result = timed.value
    policy_summary = copy(result.input_summary)
    policy_summary["construction_policy"] = String(original_config.input.construction_policy)
    policy_summary["manual_review_required"] =
        string(original_config.input.construction_policy == :diagnostic)
    if original_config.input.construction_policy == :diagnostic
        policy_summary["model_qualification"] = "DIAGNOSTIC_ONLY"
        policy_summary["production_eligible"] = "false"
        policy_summary["route_selection_eligible"] = "false"
        policy_summary["standard_tb_export_eligible"] = "false"
        if any(
            diagnostic -> get(diagnostic.context, "gate_result", "") == "FAIL",
            result.diagnostics,
        )
            policy_summary["construction_quality_failed"] = "true"
        end
    end
    result = updated_wannierization_result(result; input_summary = policy_summary)
    if mpi_execution
        terminal = _result_for_terminal_persistence(result)
        digest = hex2bytes(wannierization_checkpoint_sha256_v2_22(terminal))
        minimum_digest = copy(digest)
        maximum_digest = copy(digest)
        MPI.Allreduce!(minimum_digest, min, MPI.COMM_WORLD)
        MPI.Allreduce!(maximum_digest, max, MPI.COMM_WORLD)
        if minimum_digest != maximum_digest
            # Emit a layered scientific-digest inventory before failing.  The
            # inventory contains hashes only and lets MPI regressions identify
            # whether divergence first entered the accepted arrays, the
            # initializer evidence, the two-stage history, the sealed
            # projector, or the carried Wannier90 state.  The mismatch remains
            # fail-closed; no rank-local payload is persisted as authoritative.
            inventory =
                "base=$(wannierization_checkpoint_sha256(terminal)) " *
                "v1_2=$(wannierization_checkpoint_sha256_v1_2(terminal)) " *
                "v2_2=$(wannierization_checkpoint_sha256_v2_2(terminal)) " *
                "v2_3=$(wannierization_checkpoint_sha256_v2_3(terminal)) " *
                "v2_4=$(wannierization_checkpoint_sha256_v2_4(terminal)) " *
                "v2_6=$(wannierization_checkpoint_sha256_v2_6(terminal)) " *
                "v2_21=$(wannierization_checkpoint_sha256_v2_21(terminal)) " *
                "v2_22=$(wannierization_checkpoint_sha256_v2_22(terminal))"
            encoded_inventory = collect(codeunits(inventory))
            gathered_inventory = MPI.Allgather(encoded_inventory, MPI.COMM_WORLD)
            if MPI.Comm_rank(MPI.COMM_WORLD) == 0
                width = length(encoded_inventory)
                for rank in 0:(MPI.Comm_size(MPI.COMM_WORLD) - 1)
                    selected = @view gathered_inventory[(rank * width + 1):((rank + 1) * width)]
                    println(stderr, "MPI_PAYLOAD_DIGEST_STAGE rank=$(rank) " * String(selected))
                end
            end
            throw(
                ArgumentError(
                    "MPI_PAYLOAD_DIGEST_MISMATCH: ranks disagree before root-only persistence",
                ),
            )
        end
        MPI.Barrier(MPI.COMM_WORLD)
    end
    checkpoint_path = nothing
    packed_path = nothing
    wannier90_path = nothing
    validated_path = nothing
    tb_export_attempted = false
    diagnostics = WannierizationDiagnostic[result.diagnostics...]
    outcome_summary = Dict{String, String}(result.input_summary)
    diagnostic_gate = diagnostic_nonconverged_tb_export_gate(result, original_config)
    outcome_summary["diagnostic_classification"] =
        result.status in (COMPLETED, COMPLETED_WITH_WARNINGS) ? "CONVERGED" :
        diagnostic_gate.classification
    outcome_summary["diagnostic_export_gate_reason"] =
        result.status in (COMPLETED, COMPLETED_WITH_WARNINGS) ? "CONVERGED_EXPORT_PATH" :
        diagnostic_gate.reason
    outcome_summary["tb_export_status"] = "NOT_EXPORTED"
    outcome_summary["numerical_quality"] =
        _has_accepted_wannierization_state(result) ? "PENDING_EXPORT_VALIDATION" : "NO_VALID_STATE"
    controlled_diagnostic =
        get(outcome_summary, "controlled_symmetrization_diagnostic_only", "false") == "true"
    if controlled_diagnostic
        outcome_summary["physics_qualification"] = "CONTROLLED_SYMMETRIZATION_HOLD"
        outcome_summary["production_eligible"] = "false"
        outcome_summary["route_selection_eligible"] = "false"
        outcome_summary["standard_tb_export_eligible"] = "false"
        outcome_summary["tb_export_classification"] = "DIAGNOSTIC_ONLY_CONTROLLED_SYMMETRIZATION"
        outcome_summary["band_result_classification"] = "DIAGNOSTIC_ONLY_CONTROLLED_SYMMETRIZATION"
    end
    result = updated_wannierization_result(result; input_summary = outcome_summary)
    terminal_state = true
    if paths !== nothing
        try
            result = _result_for_terminal_persistence(result)
            checkpoint_path = write_wannierization_checkpoint_hdf5(paths.checkpoint, result)
        catch exception
            push!(
                diagnostics,
                WannierizationDiagnostic(:IO_FAILURE, :error, sprint(showerror, exception)),
            )
            result = updated_wannierization_result(result; status = IO_FAILURE, diagnostics)
            terminal_state = false
        end
    end
    if paths !== nothing &&
       terminal_state &&
       (
           original_config.output.write_wannier90_tb ||
           !isempty(original_config.output.tb_output_formats)
       ) &&
       (
           result.status in (COMPLETED, COMPLETED_WITH_WARNINGS) ||
           diagnostic_nonconverged_tb_export_allowed(result, original_config)
       ) &&
       _has_accepted_wannierization_state(result)
        tb_export_attempted = true
        try
            packed_path, wannier90_path, export_metadata = export_wannierization_tb(
                result,
                something(eig_for_tb),
                something(mmn_for_tb),
                original_config,
                paths,
                effective_wannierization_mode(original_config) == :ordinary ? nothing : plan_for_tb,
                operator_target_contract = operator_target_contract_for_tb,
            )
            outcome_summary = Dict{String, String}(result.input_summary)
            merge!(outcome_summary, export_metadata)
            result = updated_wannierization_result(result; input_summary = outcome_summary)
        catch exception
            push!(
                diagnostics,
                WannierizationDiagnostic(:TB_EXPORT_FAILED, :error, sprint(showerror, exception)),
            )
            outcome_summary = Dict{String, String}(result.input_summary)
            outcome_summary["tb_export_status"] = "NOT_EXPORTED"
            outcome_summary["diagnostic_classification"] = "STRUCTURAL_FAILURE_UNAVAILABLE"
            outcome_summary["diagnostic_export_gate_reason"] = "TB_EXPORT_FAILED: $(sprint(showerror, exception))"
            outcome_summary["numerical_quality"] =
                get(outcome_summary, "numerical_quality", "INVALID_DIAGNOSTIC")
            result = updated_wannierization_result(result; input_summary = outcome_summary)
        end
    end
    hamiltonian_covariance_threshold = _final_tb_hamiltonian_covariance_threshold(original_config)
    qualification = if packed_path === nothing
        tb_symmetry_unavailable(
            tb_export_attempted ? "TB_EXPORT_FAILED" : "TB_NOT_AVAILABLE",
            hamiltonian_covariance_threshold;
            input_summary = result.input_summary,
        )
    else
        try
            qualify_exported_wannierization_tb(
                packed_path,
                effective_wannierization_mode(original_config) == :ordinary ? nothing :
                representation_for_tb,
                effective_wannierization_mode(original_config) == :ordinary ? nothing : plan_for_tb;
                hamiltonian_covariance_threshold,
                persist_hdf5 = false,
            )
        catch exception
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :TB_SYMMETRY_QUALIFICATION_FAILED,
                    :error,
                    sprint(showerror, exception),
                ),
            )
            tb_symmetry_incomplete(
                "QUALIFICATION_EVALUATION_FAILED",
                hamiltonian_covariance_threshold;
                input_summary = result.input_summary,
            )
        end
    end
    if paths !== nothing
        try
            packed_path === nothing || HDF5.h5open(packed_path, "r+") do handle
                write_tb_symmetry_qualification_group(handle, qualification)
            end
            write_tb_symmetry_json(paths.tb_symmetry_json, qualification)
        catch exception
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :TB_SYMMETRY_QUALIFICATION_PERSISTENCE_FAILED,
                    :error,
                    sprint(showerror, exception),
                ),
            )
        end
    end
    outcome_summary = Dict{String, String}(result.input_summary)
    outcome_summary["final_tb_hamiltonian_covariance_threshold"] =
        string(hamiltonian_covariance_threshold)
    outcome_summary["final_tb_hamiltonian_covariance_threshold_contract"] = "FORMAL_REPRESENTATION_TOLERANCE"
    outcome_summary["tb_symmetry_qualification"] = qualification.overall
    outcome_summary["tb_symmetry_qualification_reason"] = qualification.reason
    outcome_summary["tb_symmetry_qualification_sha256"] = qualification.payload_sha256
    if get(outcome_summary, "controlled_symmetrization_diagnostic_only", "false") == "true"
        outcome_summary["physics_qualification"] = "CONTROLLED_SYMMETRIZATION_HOLD"
        outcome_summary["production_eligible"] = "false"
        outcome_summary["route_selection_eligible"] = "false"
        outcome_summary["standard_tb_export_eligible"] = "false"
        outcome_summary["tb_export_classification"] = "DIAGNOSTIC_ONLY_CONTROLLED_SYMMETRIZATION"
        outcome_summary["band_result_classification"] = "DIAGNOSTIC_ONLY_CONTROLLED_SYMMETRIZATION"
    end
    result = updated_wannierization_result(
        result;
        input_summary = outcome_summary,
        tb_symmetry_qualification = qualification,
    )
    artifacts = WannierizationArtifacts(
        checkpoint_hdf5 = checkpoint_path,
        validated_checkpoint_hdf5 = validated_path,
        wannierization_log = paths === nothing ? nothing : paths.log,
        packed_hdf5 = packed_path,
        wannier90_tb = wannier90_path,
        tb_symmetry_json = paths === nothing || !isfile(paths.tb_symmetry_json) ? nothing :
                           paths.tb_symmetry_json,
    )
    result = updated_wannierization_result(
        result;
        diagnostics,
        checkpoint_file = checkpoint_path,
        artifacts,
    )
    if checkpoint_path !== nothing
        try
            result = _result_for_terminal_persistence(result)
            checkpoint_path = write_wannierization_checkpoint_hdf5(paths.checkpoint, result)
            packed_path === nothing || bind_packed_checkpoint_sha256!(packed_path, checkpoint_path)
        catch exception
            diagnostics = WannierizationDiagnostic[
                result.diagnostics...,
                WannierizationDiagnostic(:IO_FAILURE, :error, sprint(showerror, exception)),
            ]
            result = updated_wannierization_result(result; status = IO_FAILURE, diagnostics)
        end
    end
    if checkpoint_path !== nothing && wannierization_production_eligible(result)
        try
            validated_path = atomic_checkpoint_copy(checkpoint_path, paths.validated)
        catch exception
            diagnostics = WannierizationDiagnostic[
                result.diagnostics...,
                WannierizationDiagnostic(:IO_FAILURE, :error, sprint(showerror, exception)),
            ]
            result = updated_wannierization_result(result; status = IO_FAILURE, diagnostics)
        end
    end
    artifacts = WannierizationArtifacts(
        checkpoint_hdf5 = checkpoint_path,
        validated_checkpoint_hdf5 = validated_path,
        wannierization_log = paths === nothing ? nothing : paths.log,
        packed_hdf5 = packed_path,
        wannier90_tb = wannier90_path,
        tb_symmetry_json = paths === nothing || !isfile(paths.tb_symmetry_json) ? nothing :
                           paths.tb_symmetry_json,
    )
    result = updated_wannierization_result(result; checkpoint_file = checkpoint_path, artifacts)
    if log_io !== nothing
        write_wannierization_final(
            log_io,
            result,
            original_config,
            artifacts;
            wall_time = timed.time,
            allocated_bytes = timed.bytes,
            gc_time = timed.gctime,
        )
        close(log_io)
    end
    mpi_execution && MPI.Barrier(MPI.COMM_WORLD)
    return result
end
