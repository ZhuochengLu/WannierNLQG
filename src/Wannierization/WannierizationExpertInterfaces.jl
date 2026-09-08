"""
    construct_symmetry_adapted_wannier_functions(config)

Build or read the native band representation, run the configured two-stage,
joint, or fixed-subspace SAWF solver, and atomically persist requested HDF5/TB artifacts. The requested
checkpoint path is stable across terminal statuses; convergence and production
eligibility remain explicit file metadata.
"""
function construct_symmetry_adapted_wannier_functions(config::SymmetryAdaptedWannierizationConfig)
    return _call_wannierization_extension(:construct_symmetry_adapted_wannier_functions, config)
end

"""
    diagnose_wannier_gauge_chain(config)

Run the expert-only, read-only Z/U/Fourier diagnostic on a sealed checkpoint.
The routine verifies all input identities before emitting versioned JSON/HDF5
evidence. Its output is diagnostic and cannot promote a solver or TB result.
"""
function diagnose_wannier_gauge_chain(config::WannierGaugeChainDiagnosticConfig)
    for (name, value) in (
        ("wannierization_checkpoint_hdf5", config.wannierization_checkpoint_hdf5),
        ("eig_file", config.eig_file),
        ("mmn_file", config.mmn_file),
        ("band_representation_hdf5", config.band_representation_hdf5),
        ("output_json", config.output_json),
        ("output_hdf5", config.output_hdf5),
    )
        isempty(strip(value)) && throw(ArgumentError("$(name) must not be empty"))
    end
    if config.frozen_min_ev <= config.frozen_max_ev
        isfinite(config.frozen_min_ev) && isfinite(config.frozen_max_ev) ||
            throw(ArgumentError("nonempty frozen window bounds must be finite"))
    end
    config.tail_radius_angstrom >= 0.0 && isfinite(config.tail_radius_angstrom) ||
        throw(ArgumentError("tail_radius_angstrom must be finite and nonnegative"))
    config.roundtrip_tolerance > 0.0 && isfinite(config.roundtrip_tolerance) ||
        throw(ArgumentError("roundtrip_tolerance must be positive and finite"))
    return _call_wannierization_extension(:diagnose_wannier_gauge_chain, config)
end

"""
    search_projection_representations(config)

Search explicit projection candidates against the frozen/outer representation
bounds in `config`. The operation is read-only with respect to band data and
never enters AMN generation, SAWF optimization, TB construction, or response
evaluation.
"""
function search_projection_representations(config::ProjectionRepresentationSearchConfig)
    return _call_wannierization_extension(:search_projection_representations, config)
end

"""Atomically persist one projection-representation search result as schema-2.1 HDF5."""
function write_projection_representation_search_hdf5(
    filename::AbstractString,
    result::ProjectionRepresentationSearchResult,
)
    isempty(strip(filename)) && throw(ArgumentError("filename must not be empty"))
    return _call_wannierization_extension(
        :write_projection_representation_search_hdf5,
        filename,
        result,
    )
end

"""Read and verify one schema-2.1 projection-representation search artifact."""
function read_projection_representation_search_hdf5(filename::AbstractString)
    isempty(strip(filename)) && throw(ArgumentError("filename must not be empty"))
    return _call_wannierization_extension(:read_projection_representation_search_hdf5, filename)
end

"""Materialize one complete validated solution as a canonically numbered projection basis."""
function materialize_projection_basis(
    result::ProjectionRepresentationSearchResult;
    solution_index::Integer = 1,
)
    return _call_wannierization_extension(
        :materialize_projection_basis,
        result;
        solution_index = Int(solution_index),
    )
end

"""Replace only `projection_basis` in a compatible immutable SAWF configuration."""
function materialize_symmetry_adapted_wannierization_config(
    template::SymmetryAdaptedWannierizationConfig,
    result::ProjectionRepresentationSearchResult;
    solution_index::Integer = 1,
)
    return _call_wannierization_extension(
        :materialize_symmetry_adapted_wannierization_config,
        template,
        result;
        solution_index = Int(solution_index),
    )
end

"""
    prepare_band_representation(config)

Read a native plane-wave source (or a supplied representation), construct the
selected expert sewing backend, evaluate scoped raw diagnostics, and optionally
persist the schema-1.5 artifact. `CoefficientMappingSewing()` preserves the
legacy coefficient-map route. `AugmentationAwareSewing()` requires full-cutoff,
unnormalized native coefficients and a complete QE/VASP projector/Q₀ backend;
it fails closed rather than substituting a pseudo-only overlap. This routine
does not read MMN or AMN data and never enters the SAWF solver.
"""
function prepare_band_representation(config::BandRepresentationPreparationConfig)
    return _call_wannierization_extension(:prepare_band_representation, config)
end

"""
    prepare_symmetry_covariant_wavefunctions(config)

Construct and seal a PAW-S-orthogonal k-star gauge before band sewing. The
routine uses a bounded adjacent-band workspace, Reynolds-averages the pulled-
back native Hamiltonian (including antiunitary conjugation), rediagonalizes it,
and transports the retained frame from one representative to every star point.
It is independently restartable and never enters the SAWF Z/U solver.
"""
function prepare_symmetry_covariant_wavefunctions(
    config::SymmetryCovariantWavefunctionPreparationConfig,
)
    return _call_wannierization_extension(:prepare_symmetry_covariant_wavefunctions, config)
end

"""
    prepare_paw_scdm_input_artifact(gauge_hdf5, representation_hdf5, output_hdf5; num_wannier)

Read a qualified augmentation-aware gauge capsule and strict representation,
verify their complete WFC/projector/Q/cutoff/k-map/spinor/authority identity,
and atomically write a PAW-S SCDM seed.  The operation is read-only with
respect to the DFT and gauge inputs and never reconstructs PAW data from
MMN/AMN files.
"""
function prepare_paw_scdm_input_artifact(
    gauge_hdf5::AbstractString,
    representation_hdf5::AbstractString,
    output_hdf5::AbstractString;
    num_wannier::Integer,
)
    num_wannier > 0 || throw(ArgumentError("num_wannier must be positive"))
    for (name, value) in (
        ("gauge_hdf5", gauge_hdf5),
        ("representation_hdf5", representation_hdf5),
        ("output_hdf5", output_hdf5),
    )
        isempty(strip(value)) && throw(ArgumentError("$(name) must not be empty"))
    end
    return _call_wannierization_extension(
        :prepare_paw_scdm_input_artifact,
        gauge_hdf5,
        representation_hdf5,
        output_hdf5;
        num_wannier = Int(num_wannier),
    )
end

"""Read and fully verify one persisted PAW-S SCDM input artifact."""
function read_paw_scdm_input_artifact(filename::AbstractString)
    isempty(strip(filename)) && throw(ArgumentError("filename must not be empty"))
    return _call_wannierization_extension(:read_paw_scdm_input_artifact, filename)
end

"""
    audit_paw_block_partitions(config)

Inventory every above-threshold physical PAW sewing edge and evaluate the
declared fixed-gap lanes without sealing a gauge or entering SAWF.  The HDF5,
CSV, and JSON outputs are diagnostic-only and bind the same source identities
used by strict wavefunction preparation.
"""
function audit_paw_block_partitions(config::PAWBlockPartitionAuditConfig)
    isempty(strip(config.output_hdf5)) && throw(ArgumentError("output_hdf5 must not be empty"))
    isempty(strip(config.output_csv)) && throw(ArgumentError("output_csv must not be empty"))
    isempty(strip(config.output_json)) && throw(ArgumentError("output_json must not be empty"))
    config.target_band_count >= 0 || throw(ArgumentError("target_band_count must be nonnegative"))
    config.symmetry_tolerance > 0.0 && isfinite(config.symmetry_tolerance) ||
        throw(ArgumentError("symmetry_tolerance must be positive and finite"))
    isempty(config.fixed_gap_scan_ev) && throw(ArgumentError("fixed_gap_scan_ev must not be empty"))
    issorted(config.fixed_gap_scan_ev) || throw(ArgumentError("fixed_gap_scan_ev must be sorted"))
    all(value -> isfinite(value) && value > 0.0, config.fixed_gap_scan_ev) ||
        throw(ArgumentError("fixed_gap_scan_ev values must be positive and finite"))
    return _call_wannierization_extension(:audit_paw_block_partitions, config)
end

"""
    generate_wannier_amn(source, basis; amn_file=nothing, provenance_hdf5=nothing)

Generate physical native plane-wave projections in the public `WannierAMN`
model. QE PAW/USPP sources require an augmentation-aware beta/Q backend and
fail with `QE_AUGMENTATION_METRIC_REQUIRED` while that backend is unavailable;
external `pw2wannier90` AMN data must instead enter through the typed matrix-
element source. If `amn_file` is supplied, the formatted file is atomically
published with a versioned provenance companion. The DFT source remains read-only.
"""
function generate_wannier_amn(
    source::SymmetryFoundation.AbstractWavefunctionSource,
    basis::WannierProjection.WannierProjectionBasis;
    amn_file::Union{Nothing, AbstractString} = nothing,
    provenance_hdf5::Union{Nothing, AbstractString} = nothing,
)
    return _call_wannierization_extension(
        :generate_wannier_amn,
        source,
        basis;
        amn_file,
        provenance_hdf5,
    )
end

"""
    generate_vasp_paw_matrix_elements(source, basis, topology_mmn_file; ...)

Generate operator-specific PAW-complete MMN and AMN matrices from raw VASP
WAVECAR coefficients and POTCAR data. The topology MMN contributes only
neighbor indices and reciprocal shifts. Optional oracle files are read only
after generation for fail-closed numerical qualification.
"""
function generate_vasp_paw_matrix_elements(
    source::SymmetryFoundation.VASPWavefunctionSource,
    basis::WannierProjection.WannierProjectionBasis,
    topology_mmn_file::AbstractString;
    output_mmn_file::AbstractString,
    output_amn_file::AbstractString,
    provenance_hdf5::AbstractString,
    oracle_mmn_file::Union{Nothing, AbstractString} = nothing,
    oracle_amn_file::Union{Nothing, AbstractString} = nothing,
    thresholds::VASPPAWParityThresholds = VASPPAWParityThresholds(),
    require_oracle::Bool = true,
)
    return _call_wannierization_extension(
        :generate_vasp_paw_matrix_elements,
        source,
        basis,
        topology_mmn_file;
        output_mmn_file,
        output_amn_file,
        provenance_hdf5,
        oracle_mmn_file,
        oracle_amn_file,
        thresholds,
        require_oracle,
    )
end

"""
    generate_vasp_paw_spn(source; output_spn_file, provenance_hdf5, spin_channel, ...)

Generate a Wannier90 SPN file from the same full-cutoff, unnormalized VASP
WAVECAR and POTCAR projector/Q₀ data used by the augmentation-aware matrix
backend. The output contains dimensionless Cartesian Pauli matrices in the
selected native band gauge. Optional oracle SPN data is validation-only.
"""
function generate_vasp_paw_spn(
    source::SymmetryFoundation.VASPWavefunctionSource;
    output_spn_file::AbstractString,
    provenance_hdf5::AbstractString,
    spin_channel::Integer,
    oracle_spn_file::Union{Nothing, AbstractString} = nothing,
    thresholds::VASPPAWSPNThresholds = VASPPAWSPNThresholds(),
    require_oracle::Bool = false,
    formatted::Bool = false,
)
    isempty(strip(output_spn_file)) && throw(ArgumentError("output_spn_file must not be empty"))
    isempty(strip(provenance_hdf5)) && throw(ArgumentError("provenance_hdf5 must not be empty"))
    return _call_wannierization_extension(
        :generate_vasp_paw_spn,
        source;
        output_spn_file,
        provenance_hdf5,
        spin_channel,
        oracle_spn_file,
        thresholds,
        require_oracle,
        formatted,
    )
end

"""
    read_vasp_paw_spn_provenance(path; verify_spn=true)

Read a schema-1.0 VASP PAW-SPN provenance artifact, recompute its logical
payload digest, and optionally verify the referenced SPN file byte digest.
"""
function read_vasp_paw_spn_provenance(path::AbstractString; verify_spn::Bool = true)
    isempty(strip(path)) && throw(ArgumentError("path must not be empty"))
    return _call_wannierization_extension(:read_vasp_paw_spn_provenance, path; verify_spn)
end

"""
    generate_qe_paw_spn(source, topology_file; output_spn_file, ...)

Generate dimensionless Cartesian Pauli matrices from the native QE
full-cutoff spinor coefficients plus PAW/USPP q=0 augmentation.  An optional
pw2wannier90 SPN is an oracle only.
"""
function generate_qe_paw_spn(
    source::SymmetryFoundation.QuantumEspressoWavefunctionSource,
    topology_file::AbstractString;
    output_spn_file::AbstractString,
    provenance_json::AbstractString = output_spn_file * ".provenance.json",
    oracle_spn_file::Union{Nothing, AbstractString} = nothing,
    thresholds::VASPPAWSPNThresholds = VASPPAWSPNThresholds(),
    require_oracle::Bool = false,
    formatted::Bool = false,
    overwrite::Bool = false,
    max_cached_wavefunction_kpoints::Int = 8,
)
    isempty(strip(topology_file)) && throw(ArgumentError("topology_file must not be empty"))
    isempty(strip(output_spn_file)) && throw(ArgumentError("output_spn_file must not be empty"))
    isempty(strip(provenance_json)) && throw(ArgumentError("provenance_json must not be empty"))
    return _call_wannierization_extension(
        :generate_qe_paw_spn,
        source,
        topology_file;
        output_spn_file,
        provenance_json,
        oracle_spn_file,
        thresholds,
        require_oracle,
        formatted,
        overwrite,
        max_cached_wavefunction_kpoints,
    )
end

"""
    generate_qe_paw_matrix_elements(source, nnkp_file; artifact_dir, ...)

Generate deterministic native QE PAW/USPP-aware MMN and AMN files. NNKP owns
the full topology, excluded-band, and projection contract. Oracle inputs are
validation-only; a missing or failed required oracle leaves diagnostic files
but never exposes a physical-overlap result to SAWF.
"""
function generate_qe_paw_matrix_elements(
    source::SymmetryFoundation.QuantumEspressoWavefunctionSource,
    nnkp_file::AbstractString;
    artifact_dir::AbstractString,
    oracle_mmn_file::Union{Nothing, AbstractString} = nothing,
    oracle_amn_file::Union{Nothing, AbstractString} = nothing,
    require_oracle::Bool = true,
    thresholds::QEPAWParityThresholds = QEPAWParityThresholds(),
)
    return _call_wannierization_extension(
        :generate_qe_paw_matrix_elements,
        source,
        nnkp_file;
        artifact_dir,
        oracle_mmn_file,
        oracle_amn_file,
        require_oracle,
        thresholds,
    )
end

"""
    generate_symmetry_completed_qe_paw_matrix_elements(source, gauge_hdf5, nnkp_file; ...)

Generate QE PAW-aware MMN/AMN directly from a sealed star-covariant gauge and
qualify them against the independent raw-parent rectangular-rotation identity.
NNKP contributes topology and trial projections, but not the completed band gauge.
"""
function generate_symmetry_completed_qe_paw_matrix_elements(
    source::SymmetryFoundation.QuantumEspressoWavefunctionSource,
    gauge_hdf5::AbstractString,
    nnkp_file::AbstractString;
    artifact_dir::AbstractString,
    thresholds::QEPAWParityThresholds = QEPAWParityThresholds(),
    qualification_mode::Symbol = :strict,
)
    return _call_wannierization_extension(
        :generate_symmetry_completed_qe_paw_matrix_elements,
        source,
        gauge_hdf5,
        nnkp_file;
        artifact_dir,
        thresholds,
        qualification_mode,
    )
end

"""
    generate_wannier_uiu(config::WannierUIUGenerationConfig)

Generate Wannier90 neighbor-neighbor direct overlaps from a native VASP or QE
wavefunction source using the complete PAW/USPP metric. The final uIu and its
JSON provenance are published atomically only after same-source MMN, generalized
normalization, diagonal-identity, exchange-Hermiticity, and readback gates pass.
"""
function generate_wannier_uiu(config::WannierUIUGenerationConfig)
    isempty(strip(config.topology_file)) && throw(ArgumentError("topology_file must not be empty"))
    isempty(strip(config.output_file)) && throw(ArgumentError("output_file must not be empty"))
    return _call_wannierization_extension(:generate_wannier_uiu, config)
end

"""Generate a finite-band Galerkin `.uHu` using the declared Hamiltonian authority."""
function generate_wannier_uhu(config::WannierHamiltonianOperatorGenerationConfig)
    return _call_wannierization_extension(:generate_wannier_uhu, config)
end

"""Generate a finite-band Galerkin `.sHu` after the physical-metric closure gate."""
function generate_wannier_shu(config::WannierHamiltonianOperatorGenerationConfig)
    return _call_wannierization_extension(:generate_wannier_shu, config)
end

"""Generate a finite-band Galerkin `.sIu` after the physical-metric closure gate."""
function generate_wannier_siu(config::WannierHamiltonianOperatorGenerationConfig)
    return _call_wannierization_extension(:generate_wannier_siu, config)
end

"""
    prepare_wannier_operator_target_contract(config)

Resolve the target workflow's raw operator-oracle MMN and solver MMN as
separate roles, then seal their digests together with the target band frame and
Hamiltonian authority. Pass the returned contract unchanged to uIu/uHu/sIu/sHu
generation configs before starting the full-profile workflow.
"""
function prepare_wannier_operator_target_contract(config::SymmetryAdaptedWannierizationConfig)
    return _call_wannierization_extension(:prepare_wannier_operator_target_contract, config)
end

"""
    prepare_exact_wannier_operator_bundle(config::ExactWannierOperatorBundleConfig)

Build an unsymmetrized schema-6 derivative-profile bundle from one sealed
TB/CHK/EIG/MMN/uIu gauge chain. A qualified uIu provenance companion is
mandatory; the historical MMN-product tensor is never substituted.
"""
function prepare_exact_wannier_operator_bundle(config::ExactWannierOperatorBundleConfig)
    return _call_wannierization_extension(:prepare_exact_wannier_operator_bundle, config)
end

"""Read one strict, versioned Wannierization checkpoint, including historical SAWF files."""
function read_wannierization_checkpoint_hdf5(filename::AbstractString)
    return _call_wannierization_extension(:read_wannierization_checkpoint_hdf5, filename)
end

"""Atomically write one Wannierization result to the exact requested checkpoint path."""
function write_wannierization_checkpoint_hdf5(
    filename::AbstractString,
    result::WannierizationResult,
)
    return _call_wannierization_extension(:write_wannierization_checkpoint_hdf5, filename, result)
end

"""Read a schema-1.0 fixed Bloch subspace for U-only localization."""
function read_wannierization_fixed_subspace_hdf5(filename::AbstractString)
    return _call_wannierization_extension(:read_wannierization_fixed_subspace_hdf5, filename)
end

"""Atomically write a schema-1.0 fixed Bloch subspace."""
function write_wannierization_fixed_subspace_hdf5(
    filename::AbstractString,
    fixed_subspace::WannierizationFixedSubspace,
)
    return _call_wannierization_extension(
        :write_wannierization_fixed_subspace_hdf5,
        filename,
        fixed_subspace,
    )
end

"""Write the independent schema-1.0 U-convergence diagnostic stream."""
function write_wannierization_u_convergence_diagnostics_hdf5(
    filename::AbstractString,
    records::AbstractVector,
    ibz_frame_snapshots::AbstractVector,
    irreducible_indices::AbstractVector{<:Integer};
    metadata::AbstractDict = Dict{String, String}(),
)
    return _call_wannierization_extension(
        :write_wannierization_u_convergence_diagnostics_hdf5,
        filename,
        records,
        ibz_frame_snapshots,
        irreducible_indices;
        metadata,
    )
end

"""
Build the Hamiltonian/position tight-binding boundary product from a completed
Wannierization result and explicit EIG/MMN inputs. The solver itself never implicitly
constructs or symmetrizes a real-space model.
"""
function build_wannier_tight_binding_model(
    result::WannierizationResult,
    eig::WannierEIG,
    mmn::WannierMMN;
    keywords...,
)
    return _call_wannierization_extension(
        :build_wannier_tight_binding_model,
        result,
        eig,
        mmn;
        keywords...,
    )
end

"""
    qualify_exported_wannierization_tb(packed_hdf5, representation, plan; ...)

Qualify the final independently read-back Hamiltonian/position TB against one
predeclared symmetry representation and Wannier plan. The returned payload is
fail-closed and does not alter Wannierization convergence, representation, band, or
physics qualification.
"""
function qualify_exported_wannierization_tb(arguments...; keywords...)
    return _call_wannierization_extension(
        :qualify_exported_wannierization_tb,
        arguments...;
        keywords...,
    )
end

"""Evaluate the full three-dimensional spread through the activated extension."""
function evaluate_full_3d_wannier_spreads(arguments...; keywords...)
    return _call_wannierization_extension(
        :evaluate_full_3d_wannier_spreads,
        arguments...;
        keywords...,
    )
end

"""Validate a band representation through the activated extension."""
function validate_band_representation_compatibility(arguments...; keywords...)
    return _call_wannierization_extension(
        :validate_band_representation_compatibility,
        arguments...;
        keywords...,
    )
end

"""Classify a sealed Wannierization U-periodicity diagnostic through the extension."""
function classify_wannierization_u_periodicity(arguments...; keywords...)
    return _call_wannierization_extension(
        :classify_wannierization_u_periodicity,
        arguments...;
        keywords...,
    )
end

"""Return the digest of the extension-owned frozen SMV--FR audit contract."""
function smv_fletcher_reeves_two_stage_audit_contract_sha256(arguments...; keywords...)
    return _call_wannierization_extension(
        :smv_fletcher_reeves_two_stage_audit_contract_sha256,
        arguments...;
        keywords...,
    )
end

"""Audit optional SMV--FR evidence without changing solver eligibility."""
function smv_fletcher_reeves_two_stage_audit(arguments...; keywords...)
    return _call_wannierization_extension(
        :smv_fletcher_reeves_two_stage_audit,
        arguments...;
        keywords...,
    )
end

# Static private expert-test and script bridges. Implementations and numerical state
# remain exclusively in WannierNLQGWannierizationExt; only reachable callers are retained.

"""Forward `_acceleration_trial_action` to the active Wannierization extension."""
function _acceleration_trial_action(arguments...; keywords...)
    return _call_wannierization_extension(:_acceleration_trial_action, arguments...; keywords...)
end

"""Forward `_accepted_unitary_displacement` to the active Wannierization extension."""
function _accepted_unitary_displacement(arguments...; keywords...)
    return _call_wannierization_extension(
        :_accepted_unitary_displacement,
        arguments...;
        keywords...,
    )
end

"""Forward `_adaptive_next_mixing` to the active Wannierization extension."""
function _adaptive_next_mixing(arguments...; keywords...)
    return _call_wannierization_extension(:_adaptive_next_mixing, arguments...; keywords...)
end

"""Forward `_amn_target_qualification_metrics` to the active Wannierization extension."""
function _amn_target_qualification_metrics(arguments...; keywords...)
    return _call_wannierization_extension(
        :_amn_target_qualification_metrics,
        arguments...;
        keywords...,
    )
end

"""Forward `_anderson_trial_policy` to the active Wannierization extension."""
function _anderson_trial_policy(arguments...; keywords...)
    return _call_wannierization_extension(:_anderson_trial_policy, arguments...; keywords...)
end

"""Forward `_anderson_z_proposal` to the active Wannierization extension."""
function _anderson_z_proposal(arguments...; keywords...)
    return _call_wannierization_extension(:_anderson_z_proposal, arguments...; keywords...)
end

"""Forward `_backtracking_step_scale` to the active Wannierization extension."""
function _backtracking_step_scale(arguments...; keywords...)
    return _call_wannierization_extension(:_backtracking_step_scale, arguments...; keywords...)
end

"""Forward `_best_fletcher_reeves_finite_descent` to the active Wannierization extension."""
function _best_fletcher_reeves_finite_descent(arguments...; keywords...)
    return _call_wannierization_extension(
        :_best_fletcher_reeves_finite_descent,
        arguments...;
        keywords...,
    )
end

"""Forward `_block_alignment_unitary` to the active Wannierization extension."""
function _block_alignment_unitary(arguments...; keywords...)
    return _call_wannierization_extension(:_block_alignment_unitary, arguments...; keywords...)
end

"""Forward `_build_representation_product_table` to the active Wannierization extension."""
function _build_representation_product_table(arguments...; keywords...)
    return _call_wannierization_extension(
        :_build_representation_product_table,
        arguments...;
        keywords...,
    )
end

"""Forward `_build_target_symmetry_tangent_plans` to the active Wannierization extension."""
function _build_target_symmetry_tangent_plans(arguments...; keywords...)
    return _call_wannierization_extension(
        :_build_target_symmetry_tangent_plans,
        arguments...;
        keywords...,
    )
end

"""Forward `_candidate_invariant_failure` to the active Wannierization extension."""
function _candidate_invariant_failure(arguments...; keywords...)
    return _call_wannierization_extension(:_candidate_invariant_failure, arguments...; keywords...)
end

"""Forward `_candidate_invariant_residuals` to the active Wannierization extension."""
function _candidate_invariant_residuals(arguments...; keywords...)
    return _call_wannierization_extension(
        :_candidate_invariant_residuals,
        arguments...;
        keywords...,
    )
end

"""Forward `_centers_spreads_and_directions` to the active Wannierization extension."""
function _centers_spreads_and_directions(arguments...; keywords...)
    return _call_wannierization_extension(
        :_centers_spreads_and_directions,
        arguments...;
        keywords...,
    )
end

"""Forward `_classify_wannier_gauge_chain_cause` to the active Wannierization extension."""
function _classify_wannier_gauge_chain_cause(arguments...; keywords...)
    return _call_wannierization_extension(
        :_classify_wannier_gauge_chain_cause,
        arguments...;
        keywords...,
    )
end

"""Forward `_common_degeneracy_blocks` to the active Wannierization extension."""
function _common_degeneracy_blocks(arguments...; keywords...)
    return _call_wannierization_extension(:_common_degeneracy_blocks, arguments...; keywords...)
end

"""Forward `_compare_wannier_projectors` to the active Wannierization extension."""
function _compare_wannier_projectors(arguments...; keywords...)
    return _call_wannierization_extension(:_compare_wannier_projectors, arguments...; keywords...)
end

"""Forward `_complete_selected_subspace_star` to the active Wannierization extension."""
function _complete_selected_subspace_star(arguments...; keywords...)
    return _call_wannierization_extension(
        :_complete_selected_subspace_star,
        arguments...;
        keywords...,
    )
end

"""Forward `_complete_window_indices` to the active Wannierization extension."""
function _complete_window_indices(arguments...; keywords...)
    return _call_wannierization_extension(:_complete_window_indices, arguments...; keywords...)
end

"""Forward `_complex_field_sha256` to the active Wannierization extension."""
function _complex_field_sha256(arguments...; keywords...)
    return _call_wannierization_extension(:_complex_field_sha256, arguments...; keywords...)
end

"""Forward `_corepresentation_aware_maximum_subspace_result` to the active Wannierization extension."""
function _corepresentation_aware_maximum_subspace_result(arguments...; keywords...)
    return _call_wannierization_extension(
        :_corepresentation_aware_maximum_subspace_result,
        arguments...;
        keywords...,
    )
end

"""Forward `_deterministic_sealed_subspace_perturbation` to the active Wannierization extension."""
function _deterministic_sealed_subspace_perturbation(arguments...; keywords...)
    return _call_wannierization_extension(
        :_deterministic_sealed_subspace_perturbation,
        arguments...;
        keywords...,
    )
end

"""Forward `_disentanglement_candidate` to the active Wannierization extension."""
function _disentanglement_candidate(arguments...; keywords...)
    return _call_wannierization_extension(:_disentanglement_candidate, arguments...; keywords...)
end

"""Forward `_effective_wannierization_algorithms` to the active Wannierization extension."""
function _effective_wannierization_algorithms(arguments...; keywords...)
    return _call_wannierization_extension(
        :_effective_wannierization_algorithms,
        arguments...;
        keywords...,
    )
end

"""Forward `_effective_wannierization_mode` to the active Wannierization extension."""
function _effective_wannierization_mode(arguments...; keywords...)
    return _call_wannierization_extension(
        :_effective_wannierization_mode,
        arguments...;
        keywords...,
    )
end

"""Forward `_evaluate_full_mesh_centers_spreads_and_directions` to the active Wannierization extension."""
function _evaluate_full_mesh_centers_spreads_and_directions(arguments...; keywords...)
    return _call_wannierization_extension(
        :_evaluate_full_mesh_centers_spreads_and_directions,
        arguments...;
        keywords...,
    )
end

"""Forward `_evaluate_mv_localization` to the active Wannierization extension."""
function _evaluate_mv_localization(arguments...; keywords...)
    return _call_wannierization_extension(:_evaluate_mv_localization, arguments...; keywords...)
end

"""Forward `_expand_ibz_frames` to the active Wannierization extension."""
function _expand_ibz_frames(arguments...; keywords...)
    return _call_wannierization_extension(:_expand_ibz_frames, arguments...; keywords...)
end

"""Forward `_expand_ibz_target_tangents` to the active Wannierization extension."""
function _expand_ibz_target_tangents(arguments...; keywords...)
    return _call_wannierization_extension(:_expand_ibz_target_tangents, arguments...; keywords...)
end

"""Forward `_finite_difference_weights` to the active Wannierization extension."""
function _finite_difference_weights(arguments...; keywords...)
    return _call_wannierization_extension(:_finite_difference_weights, arguments...; keywords...)
end

"""Forward `_fixed_subspace_initial_frames` to the active Wannierization extension."""
function _fixed_subspace_initial_frames(arguments...; keywords...)
    return _call_wannierization_extension(
        :_fixed_subspace_initial_frames,
        arguments...;
        keywords...,
    )
end

"""Forward `_fixed_subspace_projector_drift_tolerance` to the active Wannierization extension."""
function _fixed_subspace_projector_drift_tolerance(arguments...; keywords...)
    return _call_wannierization_extension(
        :_fixed_subspace_projector_drift_tolerance,
        arguments...;
        keywords...,
    )
end

"""Forward `_frame_geodesic_distance` to the active Wannierization extension."""
function _frame_geodesic_distance(arguments...; keywords...)
    return _call_wannierization_extension(:_frame_geodesic_distance, arguments...; keywords...)
end

"""Forward `_frozen_indices` to the active Wannierization extension."""
function _frozen_indices(arguments...; keywords...)
    return _call_wannierization_extension(:_frozen_indices, arguments...; keywords...)
end

"""Forward `_frozen_target_embedding` to the active Wannierization extension."""
function _frozen_target_embedding(arguments...; keywords...)
    return _call_wannierization_extension(:_frozen_target_embedding, arguments...; keywords...)
end

"""Forward `_gauge_transform_sewing` to the active Wannierization extension."""
function _gauge_transform_sewing(arguments...; keywords...)
    return _call_wannierization_extension(:_gauge_transform_sewing, arguments...; keywords...)
end

"""Forward `_global_permutation_phase_diagnostic` to the active Wannierization extension."""
function _global_permutation_phase_diagnostic(arguments...; keywords...)
    return _call_wannierization_extension(
        :_global_permutation_phase_diagnostic,
        arguments...;
        keywords...,
    )
end

"""Forward `_group_law_combination_index` to the active Wannierization extension."""
function _group_law_combination_index(arguments...; keywords...)
    return _call_wannierization_extension(:_group_law_combination_index, arguments...; keywords...)
end

"""Forward `_hungarian_maximum_assignment` to the active Wannierization extension."""
function _hungarian_maximum_assignment(arguments...; keywords...)
    return _call_wannierization_extension(:_hungarian_maximum_assignment, arguments...; keywords...)
end

"""Forward `_initial_frames` to the active Wannierization extension."""
function _initial_frames(arguments...; keywords...)
    return _call_wannierization_extension(:_initial_frames, arguments...; keywords...)
end

"""Forward `_initial_frames_with_diagnostics` to the active Wannierization extension."""
function _initial_frames_with_diagnostics(arguments...; keywords...)
    return _call_wannierization_extension(
        :_initial_frames_with_diagnostics,
        arguments...;
        keywords...,
    )
end

"""Forward `_initial_wannier_centers` to the active Wannierization extension."""
function _initial_wannier_centers(arguments...; keywords...)
    return _call_wannierization_extension(:_initial_wannier_centers, arguments...; keywords...)
end

"""Forward `_is_complete_outer_space` to the active Wannierization extension."""
function _is_complete_outer_space(arguments...; keywords...)
    return _call_wannierization_extension(:_is_complete_outer_space, arguments...; keywords...)
end

"""Forward `_legacy_initial_frames` to the active Wannierization extension."""
function _legacy_initial_frames(arguments...; keywords...)
    return _call_wannierization_extension(:_legacy_initial_frames, arguments...; keywords...)
end

"""Forward `_localization_backtracking_limit` to the active Wannierization extension."""
function _localization_backtracking_limit(arguments...; keywords...)
    return _call_wannierization_extension(
        :_localization_backtracking_limit,
        arguments...;
        keywords...,
    )
end

"""Forward `_localization_directional_derivative` to the active Wannierization extension."""
function _localization_directional_derivative(arguments...; keywords...)
    return _call_wannierization_extension(
        :_localization_directional_derivative,
        arguments...;
        keywords...,
    )
end

"""Forward `_localization_objective_accepts` to the active Wannierization extension."""
function _localization_objective_accepts(arguments...; keywords...)
    return _call_wannierization_extension(
        :_localization_objective_accepts,
        arguments...;
        keywords...,
    )
end

"""Forward `_localization_svd_polar` to the active Wannierization extension."""
function _localization_svd_polar(arguments...; keywords...)
    return _call_wannierization_extension(:_localization_svd_polar, arguments...; keywords...)
end

"""Forward `_localization_sweep_entry_count` to the active Wannierization extension."""
function _localization_sweep_entry_count(arguments...; keywords...)
    return _call_wannierization_extension(
        :_localization_sweep_entry_count,
        arguments...;
        keywords...,
    )
end

"""Forward `_match_symmetry_operations` to the active Wannierization extension."""
function _match_symmetry_operations(arguments...; keywords...)
    return _call_wannierization_extension(:_match_symmetry_operations, arguments...; keywords...)
end

"""Forward `_maximum_projector_covariance_error` to the active Wannierization extension."""
function _maximum_projector_covariance_error(arguments...; keywords...)
    return _call_wannierization_extension(
        :_maximum_projector_covariance_error,
        arguments...;
        keywords...,
    )
end

"""Forward `_maximum_projector_drift` to the active Wannierization extension."""
function _maximum_projector_drift(arguments...; keywords...)
    return _call_wannierization_extension(:_maximum_projector_drift, arguments...; keywords...)
end

"""Forward `_maximum_projector_step` to the active Wannierization extension."""
function _maximum_projector_step(arguments...; keywords...)
    return _call_wannierization_extension(:_maximum_projector_step, arguments...; keywords...)
end

"""Forward `_maximum_subspace` to the active Wannierization extension."""
function _maximum_subspace(arguments...; keywords...)
    return _call_wannierization_extension(:_maximum_subspace, arguments...; keywords...)
end

"""Forward `_maximum_subspace_result` to the active Wannierization extension."""
function _maximum_subspace_result(arguments...; keywords...)
    return _call_wannierization_extension(:_maximum_subspace_result, arguments...; keywords...)
end

"""Forward `_maximum_target_frame_symmetry_error` to the active Wannierization extension."""
function _maximum_target_frame_symmetry_error(arguments...; keywords...)
    return _call_wannierization_extension(
        :_maximum_target_frame_symmetry_error,
        arguments...;
        keywords...,
    )
end

"""Forward `_mesh_neighbor_displacement` to the active Wannierization extension."""
function _mesh_neighbor_displacement(arguments...; keywords...)
    return _call_wannierization_extension(:_mesh_neighbor_displacement, arguments...; keywords...)
end

"""Forward `_minimum_diagonal_phase_margin` to the active Wannierization extension."""
function _minimum_diagonal_phase_margin(arguments...; keywords...)
    return _call_wannierization_extension(
        :_minimum_diagonal_phase_margin,
        arguments...;
        keywords...,
    )
end

"""Forward `_minimum_norm_clarke_combination` to the active Wannierization extension."""
function _minimum_norm_clarke_combination(arguments...; keywords...)
    return _call_wannierization_extension(
        :_minimum_norm_clarke_combination,
        arguments...;
        keywords...,
    )
end

"""Forward `_minimum_z_boundary_gap` to the active Wannierization extension."""
function _minimum_z_boundary_gap(arguments...; keywords...)
    return _call_wannierization_extension(:_minimum_z_boundary_gap, arguments...; keywords...)
end

"""Forward `_mix_unitaries` to the active Wannierization extension."""
function _mix_unitaries(arguments...; keywords...)
    return _call_wannierization_extension(:_mix_unitaries, arguments...; keywords...)
end

"""Forward `_mix_z_fields` to the active Wannierization extension."""
function _mix_z_fields(arguments...; keywords...)
    return _call_wannierization_extension(:_mix_z_fields, arguments...; keywords...)
end

"""Forward `_mv_centered_full_mesh_centers_spreads_and_directions` to the active Wannierization extension."""
function _mv_centered_full_mesh_centers_spreads_and_directions(arguments...; keywords...)
    return _call_wannierization_extension(
        :_mv_centered_full_mesh_centers_spreads_and_directions,
        arguments...;
        keywords...,
    )
end

"""Forward `_mv_centered_gradient_data` to the active Wannierization extension."""
function _mv_centered_gradient_data(arguments...; keywords...)
    return _call_wannierization_extension(:_mv_centered_gradient_data, arguments...; keywords...)
end

"""Forward `_mv_generalized_directional_derivative` to the active Wannierization extension."""
function _mv_generalized_directional_derivative(arguments...; keywords...)
    return _call_wannierization_extension(
        :_mv_generalized_directional_derivative,
        arguments...;
        keywords...,
    )
end

"""Forward `_mv_localization_phase` to the active Wannierization extension."""
function _mv_localization_phase(arguments...; keywords...)
    return _call_wannierization_extension(:_mv_localization_phase, arguments...; keywords...)
end

"""Forward `_mv_spread_gradient` to the active Wannierization extension."""
function _mv_spread_gradient(arguments...; keywords...)
    return _call_wannierization_extension(:_mv_spread_gradient, arguments...; keywords...)
end

"""Forward `_objective_aware_anderson_decision` to the active Wannierization extension."""
function _objective_aware_anderson_decision(arguments...; keywords...)
    return _call_wannierization_extension(
        :_objective_aware_anderson_decision,
        arguments...;
        keywords...,
    )
end

"""Forward `_orthonormalize_columns` to the active Wannierization extension."""
function _orthonormalize_columns(arguments...; keywords...)
    return _call_wannierization_extension(:_orthonormalize_columns, arguments...; keywords...)
end

"""Forward `_orthonormalize_columns_result` to the active Wannierization extension."""
function _orthonormalize_columns_result(arguments...; keywords...)
    return _call_wannierization_extension(
        :_orthonormalize_columns_result,
        arguments...;
        keywords...,
    )
end

"""Forward `_pack_complex_real` to the active Wannierization extension."""
function _pack_complex_real(arguments...; keywords...)
    return _call_wannierization_extension(:_pack_complex_real, arguments...; keywords...)
end

"""Forward `_paired_matrix_residual_metrics` to the active Wannierization extension."""
function _paired_matrix_residual_metrics(arguments...; keywords...)
    return _call_wannierization_extension(
        :_paired_matrix_residual_metrics,
        arguments...;
        keywords...,
    )
end

"""Forward `_polar_retracted_tangent_step` to the active Wannierization extension."""
function _polar_retracted_tangent_step(arguments...; keywords...)
    return _call_wannierization_extension(:_polar_retracted_tangent_step, arguments...; keywords...)
end

"""Forward `_polar_retraction_curve_velocity` to the active Wannierization extension."""
function _polar_retraction_curve_velocity(arguments...; keywords...)
    return _call_wannierization_extension(
        :_polar_retraction_curve_velocity,
        arguments...;
        keywords...,
    )
end

"""Forward `_project_target_symmetry_tangent` to the active Wannierization extension."""
function _project_target_symmetry_tangent(arguments...; keywords...)
    return _call_wannierization_extension(
        :_project_target_symmetry_tangent,
        arguments...;
        keywords...,
    )
end

"""Forward `_projector_covariance_tolerance` to the active Wannierization extension."""
function _projector_covariance_tolerance(arguments...; keywords...)
    return _call_wannierization_extension(
        :_projector_covariance_tolerance,
        arguments...;
        keywords...,
    )
end

"""Forward `_qualify_nonconverged_disentanglement_state` to the active Wannierization extension."""
function _qualify_nonconverged_disentanglement_state(arguments...; keywords...)
    return _call_wannierization_extension(
        :_qualify_nonconverged_disentanglement_state,
        arguments...;
        keywords...,
    )
end

"""Forward `_rank_gated_polar_columns` to the active Wannierization extension."""
function _rank_gated_polar_columns(arguments...; keywords...)
    return _call_wannierization_extension(:_rank_gated_polar_columns, arguments...; keywords...)
end

"""Forward `_rank_gated_svd_polar_columns` to the active Wannierization extension."""
function _rank_gated_svd_polar_columns(arguments...; keywords...)
    return _call_wannierization_extension(:_rank_gated_svd_polar_columns, arguments...; keywords...)
end

"""Forward `_raw_amn_localization_reference` to the active Wannierization extension."""
function _raw_amn_localization_reference(arguments...; keywords...)
    return _call_wannierization_extension(
        :_raw_amn_localization_reference,
        arguments...;
        keywords...,
    )
end

"""Forward `_raw_z_field` to the active Wannierization extension."""
function _raw_z_field(arguments...; keywords...)
    return _call_wannierization_extension(:_raw_z_field, arguments...; keywords...)
end

"""Forward `_record_terminal_state!` to the active Wannierization extension."""
function _record_terminal_state!(arguments...; keywords...)
    return _call_wannierization_extension(:_record_terminal_state!, arguments...; keywords...)
end

"""Forward `_reduce_full_star_hermitian_field` to the active Wannierization extension."""
function _reduce_full_star_hermitian_field(arguments...; keywords...)
    return _call_wannierization_extension(
        :_reduce_full_star_hermitian_field,
        arguments...;
        keywords...,
    )
end

"""Forward `_repair_expanded_frozen_frame` to the active Wannierization extension."""
function _repair_expanded_frozen_frame(arguments...; keywords...)
    return _call_wannierization_extension(:_repair_expanded_frozen_frame, arguments...; keywords...)
end

"""Forward `_representation_static_sha256` to the active Wannierization extension."""
function _representation_static_sha256(arguments...; keywords...)
    return _call_wannierization_extension(:_representation_static_sha256, arguments...; keywords...)
end

"""Forward `_representation_target_subspace_contract` to the active Wannierization extension."""
function _representation_target_subspace_contract(arguments...; keywords...)
    return _call_wannierization_extension(
        :_representation_target_subspace_contract,
        arguments...;
        keywords...,
    )
end

"""Forward `_restart_config_repr` to the active Wannierization extension."""
function _restart_config_repr(arguments...; keywords...)
    return _call_wannierization_extension(:_restart_config_repr, arguments...; keywords...)
end

"""Forward `_restart_config_sha256` to the active Wannierization extension."""
function _restart_config_sha256(arguments...; keywords...)
    return _call_wannierization_extension(:_restart_config_sha256, arguments...; keywords...)
end

"""Forward `_restart_config_sha256_pre_v2_11` to the active Wannierization extension."""
function _restart_config_sha256_pre_v2_11(arguments...; keywords...)
    return _call_wannierization_extension(
        :_restart_config_sha256_pre_v2_11,
        arguments...;
        keywords...,
    )
end

"""Forward `_restart_config_sha256_pre_v2_6` to the active Wannierization extension."""
function _restart_config_sha256_pre_v2_6(arguments...; keywords...)
    return _call_wannierization_extension(
        :_restart_config_sha256_pre_v2_6,
        arguments...;
        keywords...,
    )
end

"""Forward `_restart_config_sha256_pre_v2_7` to the active Wannierization extension."""
function _restart_config_sha256_pre_v2_7(arguments...; keywords...)
    return _call_wannierization_extension(
        :_restart_config_sha256_pre_v2_7,
        arguments...;
        keywords...,
    )
end

"""Forward `_restart_matrix_field` to the active Wannierization extension."""
function _restart_matrix_field(arguments...; keywords...)
    return _call_wannierization_extension(:_restart_matrix_field, arguments...; keywords...)
end

"""Forward `_restore_expanded_frames_to_subspaces` to the active Wannierization extension."""
function _restore_expanded_frames_to_subspaces(arguments...; keywords...)
    return _call_wannierization_extension(
        :_restore_expanded_frames_to_subspaces,
        arguments...;
        keywords...,
    )
end

"""Forward `_riemannian_lbfgs_direction` to the active Wannierization extension."""
function _riemannian_lbfgs_direction(arguments...; keywords...)
    return _call_wannierization_extension(:_riemannian_lbfgs_direction, arguments...; keywords...)
end

"""Forward `_rotate_hermitian_field_entry` to the active Wannierization extension."""
function _rotate_hermitian_field_entry(arguments...; keywords...)
    return _call_wannierization_extension(:_rotate_hermitian_field_entry, arguments...; keywords...)
end

"""Forward `_rotate_localized_overlap_state` to the active Wannierization extension."""
function _rotate_localized_overlap_state(arguments...; keywords...)
    return _call_wannierization_extension(
        :_rotate_localized_overlap_state,
        arguments...;
        keywords...,
    )
end

"""Forward `_sealed_amn_polar` to the active Wannierization extension."""
function _sealed_amn_polar(arguments...; keywords...)
    return _call_wannierization_extension(:_sealed_amn_polar, arguments...; keywords...)
end

"""Forward `_select_wannierization_multistart` to the active Wannierization extension."""
function _select_wannierization_multistart(arguments...; keywords...)
    return _call_wannierization_extension(
        :_select_wannierization_multistart,
        arguments...;
        keywords...,
    )
end

"""Forward `_sha256_file` to the active Wannierization extension."""
function _sha256_file(arguments...; keywords...)
    return _call_wannierization_extension(:sha256_file, arguments...; keywords...)
end

"""Forward `_shrunken_acceleration_mixing` to the active Wannierization extension."""
function _shrunken_acceleration_mixing(arguments...; keywords...)
    return _call_wannierization_extension(:_shrunken_acceleration_mixing, arguments...; keywords...)
end

"""Forward `_solve_symmetry_adapted_wannierization` to the active Wannierization extension."""
function _solve_symmetry_adapted_wannierization(arguments...; keywords...)
    return _call_wannierization_extension(
        :_solve_symmetry_adapted_wannierization,
        arguments...;
        keywords...,
    )
end

"""Forward `_stable_subspace_alignment` to the active Wannierization extension."""
function _stable_subspace_alignment(arguments...; keywords...)
    return _call_wannierization_extension(:_stable_subspace_alignment, arguments...; keywords...)
end

"""Forward `_symmetry_constraints_applied` to the active Wannierization extension."""
function _symmetry_constraints_applied(arguments...; keywords...)
    return _call_wannierization_extension(:_symmetry_constraints_applied, arguments...; keywords...)
end

"""Forward `_symmetry_projected_spread_gradient` to the active Wannierization extension."""
function _symmetry_projected_spread_gradient(arguments...; keywords...)
    return _call_wannierization_extension(
        :_symmetry_projected_spread_gradient,
        arguments...;
        keywords...,
    )
end

"""Forward `_target_representation` to the active Wannierization extension."""
function _target_representation(arguments...; keywords...)
    return _call_wannierization_extension(:_target_representation, arguments...; keywords...)
end

"""Forward `_target_symmetry_tangent_plan` to the active Wannierization extension."""
function _target_symmetry_tangent_plan(arguments...; keywords...)
    return _call_wannierization_extension(:_target_symmetry_tangent_plan, arguments...; keywords...)
end

"""Forward `_transport_selected_subspace_corepresentation` to the active Wannierization extension."""
function _transport_selected_subspace_corepresentation(arguments...; keywords...)
    return _call_wannierization_extension(
        :_transport_selected_subspace_corepresentation,
        arguments...;
        keywords...,
    )
end

"""Forward `_unitary_geodesic_plan` to the active Wannierization extension."""
function _unitary_geodesic_plan(arguments...; keywords...)
    return _call_wannierization_extension(:_unitary_geodesic_plan, arguments...; keywords...)
end

"""Forward `_unitary_geodesic_step` to the active Wannierization extension."""
function _unitary_geodesic_step(arguments...; keywords...)
    return _call_wannierization_extension(:_unitary_geodesic_step, arguments...; keywords...)
end

"""Forward `_unpack_complex_real` to the active Wannierization extension."""
function _unpack_complex_real(arguments...; keywords...)
    return _call_wannierization_extension(:_unpack_complex_real, arguments...; keywords...)
end

"""Forward `_validate_band_representation_preparation_config` to the active Wannierization extension."""
function _validate_band_representation_preparation_config(arguments...; keywords...)
    return _call_wannierization_extension(
        :_validate_band_representation_preparation_config,
        arguments...;
        keywords...,
    )
end

"""Forward `_validate_hermitian_eigensystem` to the active Wannierization extension."""
function _validate_hermitian_eigensystem(arguments...; keywords...)
    return _call_wannierization_extension(
        :_validate_hermitian_eigensystem,
        arguments...;
        keywords...,
    )
end

"""Forward `_validate_symmetry_covariant_wavefunction_preparation_config` to the active Wannierization extension."""
function _validate_symmetry_covariant_wavefunction_preparation_config(arguments...; keywords...)
    return _call_wannierization_extension(
        :_validate_symmetry_covariant_wavefunction_preparation_config,
        arguments...;
        keywords...,
    )
end

"""Forward `_validate_target_operation_inventory` to the active Wannierization extension."""
function _validate_target_operation_inventory(arguments...; keywords...)
    return _call_wannierization_extension(
        :_validate_target_operation_inventory,
        arguments...;
        keywords...,
    )
end

"""Forward `_validate_wannierization_config` to the active Wannierization extension."""
function _validate_wannierization_config(arguments...; keywords...)
    return _call_wannierization_extension(
        :_validate_wannierization_config,
        arguments...;
        keywords...,
    )
end

"""Forward `_validated_hermitian_spectrum` to the active Wannierization extension."""
function _validated_hermitian_spectrum(arguments...; keywords...)
    return _call_wannierization_extension(:_validated_hermitian_spectrum, arguments...; keywords...)
end

"""Forward `_wannier90_reference_amn_polar` to the active Wannierization extension."""
function _wannier90_reference_amn_polar(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_amn_polar,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_b_cartesian` to the active Wannierization extension."""
function _wannier90_reference_b_cartesian(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_b_cartesian,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_complex_exponential` to the active Wannierization extension."""
function _wannier90_reference_complex_exponential(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_complex_exponential,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_dis_project` to the active Wannierization extension."""
function _wannier90_reference_dis_project(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_dis_project,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_edge_b_cartesian` to the active Wannierization extension."""
function _wannier90_reference_edge_b_cartesian(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_edge_b_cartesian,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_finite_difference_weights` to the active Wannierization extension."""
function _wannier90_reference_finite_difference_weights(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_finite_difference_weights,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_gfortran_column_conjugate_product` to the active Wannierization extension."""
function _wannier90_reference_gfortran_column_conjugate_product(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_gfortran_column_conjugate_product,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_gfortran_column_division` to the active Wannierization extension."""
function _wannier90_reference_gfortran_column_division(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_gfortran_column_division,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_gfortran_complex_product` to the active Wannierization extension."""
function _wannier90_reference_gfortran_complex_product(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_gfortran_complex_product,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_gfortran_magnitude_squared` to the active Wannierization extension."""
function _wannier90_reference_gfortran_magnitude_squared(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_gfortran_magnitude_squared,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_gfortran_phase_column_product` to the active Wannierization extension."""
function _wannier90_reference_gfortran_phase_column_product(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_gfortran_phase_column_product,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_gfortran_scalar_magnitude_squared` to the active Wannierization extension."""
function _wannier90_reference_gfortran_scalar_magnitude_squared(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_gfortran_scalar_magnitude_squared,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_gradient_center_accumulate` to the active Wannierization extension."""
function _wannier90_reference_gradient_center_accumulate(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_gradient_center_accumulate,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_invariant_spread` to the active Wannierization extension."""
function _wannier90_reference_invariant_spread(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_invariant_spread,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_maximum_subspace_result` to the active Wannierization extension."""
function _wannier90_reference_maximum_subspace_result(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_maximum_subspace_result,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_objective_center_accumulate` to the active Wannierization extension."""
function _wannier90_reference_objective_center_accumulate(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_objective_center_accumulate,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_omega_d_accumulate` to the active Wannierization extension."""
function _wannier90_reference_omega_d_accumulate(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_omega_d_accumulate,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_optimal_step` to the active Wannierization extension."""
function _wannier90_reference_optimal_step(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_optimal_step,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_phase` to the active Wannierization extension."""
function _wannier90_reference_phase(arguments...; keywords...)
    return _call_wannierization_extension(:_wannier90_reference_phase, arguments...; keywords...)
end

"""Forward `_wannier90_reference_search_direction` to the active Wannierization extension."""
function _wannier90_reference_search_direction(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_search_direction,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_unitary_step` to the active Wannierization extension."""
function _wannier90_reference_unitary_step(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_unitary_step,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_weight_total` to the active Wannierization extension."""
function _wannier90_reference_weight_total(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier90_reference_weight_total,
        arguments...;
        keywords...,
    )
end

"""Forward `_wannier90_reference_zdot` to the active Wannierization extension."""
function _wannier90_reference_zdot(arguments...; keywords...)
    return _call_wannierization_extension(:_wannier90_reference_zdot, arguments...; keywords...)
end

"""Forward `_wannier90_reference_zgemm` to the active Wannierization extension."""
function _wannier90_reference_zgemm(arguments...; keywords...)
    return _call_wannierization_extension(:_wannier90_reference_zgemm, arguments...; keywords...)
end

"""Forward `_wannier90_reference_zhpevx` to the active Wannierization extension."""
function _wannier90_reference_zhpevx(arguments...; keywords...)
    return _call_wannierization_extension(:_wannier90_reference_zhpevx, arguments...; keywords...)
end

"""Forward `_wannier_gauge_link_diagnostics` to the active Wannierization extension."""
function _wannier_gauge_link_diagnostics(arguments...; keywords...)
    return _call_wannierization_extension(
        :_wannier_gauge_link_diagnostics,
        arguments...;
        keywords...,
    )
end
