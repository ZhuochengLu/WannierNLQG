"""Marker for one complete source of Wannier MMN and AMN matrices."""
abstract type AbstractWannierMatrixElementSource end

"""
    ExternalWannier90Matrices(mmn_file, amn_file)

Use complete formatted Wannier90 MMN and AMN files. Both files are mandatory;
this type never permits an implicit pseudo-only VASP AMN fallback.
"""
struct ExternalWannier90Matrices <: AbstractWannierMatrixElementSource
    mmn_file::String
    amn_file::String

    function ExternalWannier90Matrices(mmn_file::AbstractString, amn_file::AbstractString)
        isempty(strip(mmn_file)) && throw(ArgumentError("MMN path must not be empty"))
        isempty(strip(amn_file)) && throw(ArgumentError("AMN path must not be empty"))
        return new(String(mmn_file), String(amn_file))
    end
end

"""Fail-closed numerical thresholds for one native VASP PAW qualification."""
struct VASPPAWParityThresholds
    radial_q_max_absolute::Float64
    generalized_norm_max_absolute::Float64
    mmn_max_absolute::Float64
    mmn_rms::Float64
    mmn_relative_l2::Float64
    amn_max_absolute::Float64
    amn_rms::Float64
    amn_relative_l2::Float64
    amn_max_principal_angle_rad::Float64
    amn_projector_max_absolute::Float64
end

# Construct the fail-closed threshold set while rejecting invalid scientific gates.
function VASPPAWParityThresholds(;
    radial_q_max_absolute::Real = 5.0e-7,
    generalized_norm_max_absolute::Real = 5.0e-6,
    mmn_max_absolute::Real = 1.0e-5,
    mmn_rms::Real = 1.0e-7,
    mmn_relative_l2::Real = 1.0e-6,
    amn_max_absolute::Real = 1.0e-5,
    amn_rms::Real = 1.0e-7,
    amn_relative_l2::Real = 1.0e-6,
    amn_max_principal_angle_rad::Real = 1.0e-4,
    amn_projector_max_absolute::Real = 1.0e-5,
)
    values = Float64[
        radial_q_max_absolute,
        generalized_norm_max_absolute,
        mmn_max_absolute,
        mmn_rms,
        mmn_relative_l2,
        amn_max_absolute,
        amn_rms,
        amn_relative_l2,
        amn_max_principal_angle_rad,
        amn_projector_max_absolute,
    ]
    all(isfinite, values) && all(>(0.0), values) ||
        throw(ArgumentError("VASP PAW parity thresholds must be finite and strictly positive"))
    return VASPPAWParityThresholds(values...)
end

"""Raw-array parity metrics with the one-based index of the largest residual."""
struct VASPPAWArrayParityMetrics
    max_absolute::Float64
    root_mean_square::Float64
    relative_l2::Float64
    worst_index::Vector{Int}
    finite::Bool
end

"""Numerical evidence for the raw-VASP to solver-facing AMN gauge adapter."""
struct VASPPAWSolverGaugeDiagnostics
    maximum_unitarity_residual::Float64
    maximum_roundtrip_absolute::Float64
    maximum_projector_absolute::Float64
    minimum_singular_value::Float64
    maximum_condition_number::Float64
    maximum_raw_solver_absolute::Float64
    spinor_pair_count::Int
    nonzero_translation_count::Int
end

"""
Qualified or diagnostic native VASP PAW MMN/AMN products.

`passed` is true only when every configured raw-array, subspace, radial, and
generalized-norm gate passes. A false result retains its failed quality checks;
diagnostic construction may consume finite, structurally valid matrices, while
strict construction rejects them.
"""
struct VASPPAWMatrixElementResult
    mmn::WannierMMN
    amn::WannierAMN
    solver_amn::WannierAMN
    solver_gauge_diagnostics::Union{Nothing, VASPPAWSolverGaugeDiagnostics}
    mmn_parity::Union{Nothing, VASPPAWArrayParityMetrics}
    amn_parity::Union{Nothing, VASPPAWArrayParityMetrics}
    amn_max_principal_angle_rad::Float64
    amn_projector_max_absolute::Float64
    radial_q_max_absolute::Float64
    generalized_norm_max_absolute::Float64
    passed::Bool
    diagnostics::Vector{String}
    artifacts::Dict{String, String}
    input_sha256::Dict{String, String}
end

"""Fail-closed numerical thresholds for native VASP PAW SPN construction."""
struct VASPPAWSPNThresholds
    radial_q_max_absolute::Float64
    generalized_norm_max_absolute::Float64
    hermiticity_max_absolute::Float64
    diagonal_imaginary_max_absolute::Float64
    oracle_max_absolute::Float64
    oracle_rms::Float64
    oracle_relative_l2::Float64
end

# Validate the physical reconstruction and optional-oracle SPN thresholds.
function VASPPAWSPNThresholds(;
    radial_q_max_absolute::Real = 5.0e-7,
    generalized_norm_max_absolute::Real = 5.0e-6,
    hermiticity_max_absolute::Real = 1.0e-10,
    diagonal_imaginary_max_absolute::Real = 1.0e-10,
    oracle_max_absolute::Real = 1.0e-8,
    oracle_rms::Real = 1.0e-10,
    oracle_relative_l2::Real = 1.0e-8,
)
    values = Float64[
        radial_q_max_absolute,
        generalized_norm_max_absolute,
        hermiticity_max_absolute,
        diagonal_imaginary_max_absolute,
        oracle_max_absolute,
        oracle_rms,
        oracle_relative_l2,
    ]
    all(isfinite, values) && all(>(0.0), values) ||
        throw(ArgumentError("VASP PAW SPN thresholds must be finite and strictly positive"))
    return VASPPAWSPNThresholds(values...)
end

"""
Qualified or diagnostic native VASP PAW spin-matrix product.

`spn` stores dimensionless Cartesian Pauli matrix elements in the selected
VASP band gauge. `passed` requires generalized-norm, Hermiticity, diagonal,
and any requested oracle gates; it does not grant a downstream physics or
production qualification.
"""
struct VASPPAWSPNResult
    spn::WannierSPN
    oracle_parity::Union{Nothing, VASPPAWArrayParityMetrics}
    radial_q_max_absolute::Float64
    generalized_norm_max_absolute::Float64
    hermiticity_max_absolute::Float64
    diagonal_imaginary_max_absolute::Float64
    passed::Bool
    diagnostics::Vector{String}
    component_norms::Dict{String, Float64}
    artifacts::Dict{String, String}
    input_sha256::Dict{String, String}
end

"""Fail-closed native QE PAW/USPP SPN generation result."""
struct QEPAWSPNResult
    spn::Union{Nothing, WannierSPN}
    oracle_parity::Union{Nothing, VASPPAWArrayParityMetrics}
    generalized_norm_max_absolute::Float64
    hermiticity_max_absolute::Float64
    diagonal_imaginary_max_absolute::Float64
    passed::Bool
    provenance_json::String
    artifacts::Dict{String, String}
    input_sha256::Dict{String, String}
    diagnostics::Vector{String}
end

# Preserve the schema-1.1 positional constructor for downstream code that only
# consumes raw parity products. Native generation uses the complete constructor
# and always supplies a distinct solver-facing AMN plus adapter diagnostics.
function VASPPAWMatrixElementResult(
    mmn,
    amn,
    mmn_parity,
    amn_parity,
    amn_max_principal_angle_rad,
    amn_projector_max_absolute,
    radial_q_max_absolute,
    generalized_norm_max_absolute,
    passed,
    diagnostics,
    artifacts,
    input_sha256,
)
    return VASPPAWMatrixElementResult(
        mmn,
        amn,
        amn,
        nothing,
        mmn_parity,
        amn_parity,
        Float64(amn_max_principal_angle_rad),
        Float64(amn_projector_max_absolute),
        Float64(radial_q_max_absolute),
        Float64(generalized_norm_max_absolute),
        Bool(passed),
        Vector{String}(diagnostics),
        Dict{String, String}(artifacts),
        Dict{String, String}(input_sha256),
    )
end

"""
    NativeVASPPAWMatrices(topology_mmn_file; ...)

Generate VASP PAW MMN and AMN from raw WAVECAR coefficients and POTCAR data.
The topology file supplies only neighbor indices and reciprocal shifts. Oracle
files are validation-only and never provide matrix values to the generator.
"""
struct NativeVASPPAWMatrices <: AbstractWannierMatrixElementSource
    topology_mmn_file::String
    oracle_mmn_file::Union{Nothing, String}
    oracle_amn_file::Union{Nothing, String}
    artifact_dir::String
    thresholds::VASPPAWParityThresholds
    require_oracle::Bool

    function NativeVASPPAWMatrices(
        topology_mmn_file::AbstractString;
        oracle_mmn_file::Union{Nothing, AbstractString} = nothing,
        oracle_amn_file::Union{Nothing, AbstractString} = nothing,
        artifact_dir::AbstractString,
        thresholds::VASPPAWParityThresholds = VASPPAWParityThresholds(),
        require_oracle::Bool = true,
    )
        isempty(strip(topology_mmn_file)) &&
            throw(ArgumentError("topology MMN path must not be empty"))
        isempty(strip(artifact_dir)) && throw(ArgumentError("artifact_dir must not be empty"))
        return new(
            String(topology_mmn_file),
            oracle_mmn_file === nothing ? nothing : String(oracle_mmn_file),
            oracle_amn_file === nothing ? nothing : String(oracle_amn_file),
            String(artifact_dir),
            thresholds,
            require_oracle,
        )
    end
end

"""Fail-closed numerical thresholds for native QE PAW/USPP qualification."""
struct QEPAWParityThresholds
    generalized_norm_max_absolute::Float64
    mmn_max_absolute::Float64
    mmn_rms::Float64
    mmn_relative_l2::Float64
    amn_max_absolute::Float64
    amn_rms::Float64
    amn_relative_l2::Float64
    amn_max_principal_angle_rad::Float64
    amn_projector_max_absolute::Float64
end

"""Fail-closed numerical gates for streamed first-principles Wannier90 uIu generation."""
struct WannierUIUGenerationThresholds
    radial_q_max_absolute::Float64
    generalized_norm_max_absolute::Float64
    mmn_max_absolute::Float64
    mmn_rms::Float64
    mmn_relative_l2::Float64
    diagonal_identity_max_absolute::Float64
    exchange_hermiticity_max_absolute::Float64
end

"""Construct and validate the complete uIu-generation threshold set."""
function WannierUIUGenerationThresholds(;
    radial_q_max_absolute::Real = 5.0e-7,
    generalized_norm_max_absolute::Real = 5.0e-6,
    mmn_max_absolute::Real = 1.0e-5,
    mmn_rms::Real = 1.0e-7,
    mmn_relative_l2::Real = 1.0e-6,
    diagonal_identity_max_absolute::Real = 1.0e-5,
    exchange_hermiticity_max_absolute::Real = 1.0e-10,
)
    values = Float64[
        radial_q_max_absolute,
        generalized_norm_max_absolute,
        mmn_max_absolute,
        mmn_rms,
        mmn_relative_l2,
        diagonal_identity_max_absolute,
        exchange_hermiticity_max_absolute,
    ]
    all(isfinite, values) && all(>(0.0), values) ||
        throw(ArgumentError("uIu generation thresholds must be finite and strictly positive"))
    return WannierUIUGenerationThresholds(values...)
end

"""Provider-neutral MMN oracle residuals evaluated without retaining the oracle array."""
struct WannierUIUParityMetrics
    max_absolute::Float64
    root_mean_square::Float64
    relative_l2::Float64
    worst_index::Vector{Int}
    finite::Bool
end

"""Digest-bound identities shared by operator generation, SAWF, and full export."""
struct WannierOperatorTargetContract
    operator_oracle_mmn_file::String
    operator_oracle_mmn_sha256::String
    solver_mmn_file::String
    solver_mmn_sha256::String
    source_band_gauge::String
    target_band_gauge::String
    band_frame_transform_sha256::String
    band_frame_contract_sha256::String
    gauge_artifact_sha256::String
    authoritative_hamiltonian::String
    authoritative_hamiltonian_digest::String
    num_bands::Int
    num_kpoints::Int
    num_neighbors::Int
    contract_sha256::String
end

"""Hash the immutable source, solver, gauge, and Hamiltonian target identities."""
function wannier_operator_target_contract_sha256(
    operator_oracle_mmn_file,
    operator_oracle_mmn_sha256,
    solver_mmn_file,
    solver_mmn_sha256,
    source_band_gauge,
    target_band_gauge,
    band_frame_transform_sha256,
    band_frame_contract_sha256,
    gauge_artifact_sha256,
    authoritative_hamiltonian,
    authoritative_hamiltonian_digest,
    num_bands,
    num_kpoints,
    num_neighbors,
)
    buffer = IOBuffer()
    for value in (
        "WannierNLQG.wannier_operator_target_contract/1.0",
        operator_oracle_mmn_file,
        operator_oracle_mmn_sha256,
        solver_mmn_file,
        solver_mmn_sha256,
        source_band_gauge,
        target_band_gauge,
        band_frame_transform_sha256,
        band_frame_contract_sha256,
        gauge_artifact_sha256,
        authoritative_hamiltonian,
        authoritative_hamiltonian_digest,
        num_bands,
        num_kpoints,
        num_neighbors,
    )
        write(buffer, string(value), '\0')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Construct a target contract and derive its digest from every bound field."""
function WannierOperatorTargetContract(
    operator_oracle_mmn_file,
    operator_oracle_mmn_sha256,
    solver_mmn_file,
    solver_mmn_sha256,
    source_band_gauge,
    target_band_gauge,
    band_frame_transform_sha256,
    band_frame_contract_sha256,
    gauge_artifact_sha256,
    authoritative_hamiltonian,
    authoritative_hamiltonian_digest,
    num_bands,
    num_kpoints,
    num_neighbors,
)
    values = String.((
        operator_oracle_mmn_file,
        operator_oracle_mmn_sha256,
        solver_mmn_file,
        solver_mmn_sha256,
        source_band_gauge,
        target_band_gauge,
        band_frame_transform_sha256,
        band_frame_contract_sha256,
        gauge_artifact_sha256,
        authoritative_hamiltonian,
        authoritative_hamiltonian_digest,
    ),)
    all(digest -> occursin(r"^[0-9a-f]{64}$", digest), values[[2, 4, 7, 8, 11]]) ||
        throw(ArgumentError("operator target contract digests must be SHA-256"))
    (values[9] == "NOT_APPLICABLE" || occursin(r"^[0-9a-f]{64}$", values[9])) || throw(
        ArgumentError("operator target gauge artifact digest must be SHA-256 or NOT_APPLICABLE"),
    )
    all(>(0), (num_bands, num_kpoints, num_neighbors)) ||
        throw(ArgumentError("operator target contract dimensions must be positive"))
    contract_sha256 = wannier_operator_target_contract_sha256(
        values...,
        Int(num_bands),
        Int(num_kpoints),
        Int(num_neighbors),
    )
    return WannierOperatorTargetContract(
        values...,
        Int(num_bands),
        Int(num_kpoints),
        Int(num_neighbors),
        contract_sha256,
    )
end

"""
Expert configuration for a resumable first-principles Wannier90 `.uIu` build.

The source is read-only. `topology_file` is either the same-run formatted MMN
or NNKP. Publication is k-point checkpointed and atomic; an existing final
output is never reused or replaced unless `overwrite=true`. QE coefficient and
beta-projector entries use a deterministic bounded LRU controlled by
`max_cached_wavefunction_kpoints`; this operational limit does not enter the
scientific input fingerprint. `authoritative_hamiltonian` and
`wavefunction_gauge_hdf5` bind the generated link matrices to the exact target
band gauge. A native route without an artifact is identity; a sealed native- or
symmetrized-SAWF artifact supplies the rotations that must actually be applied.
"""
Base.@kwdef struct WannierUIUGenerationConfig
    construction_policy::Symbol = :diagnostic
    source::SymmetryFoundation.AbstractWavefunctionSource
    topology_file::String
    output_file::String
    scratch_directory::Union{Nothing, String} = nothing
    provenance_json::Union{Nothing, String} = nothing
    resume::Bool = true
    overwrite::Bool = false
    oracle_mmn_file::Union{Nothing, String} = nothing
    authoritative_mmn_file::Union{Nothing, String} = nothing
    target_contract::Union{Nothing, WannierOperatorTargetContract} = nothing
    require_mmn_oracle::Bool = true
    authoritative_hamiltonian::AbstractAuthoritativeHamiltonian = NativeDFTHamiltonian()
    wavefunction_gauge_hdf5::Union{Nothing, String} = nothing
    thresholds::WannierUIUGenerationThresholds = WannierUIUGenerationThresholds()
    max_cached_wavefunction_kpoints::Int = 8
end

"""Dimension-only, hash-bound result of one streamed uIu generation attempt."""
struct WannierUIUGenerationResult
    source_code::Symbol
    num_bands::Int
    num_kpts::Int
    num_neighbors::Int
    generalized_norm_max_absolute::Float64
    mmn_parity::Union{Nothing, WannierUIUParityMetrics}
    diagonal_identity_max_absolute::Float64
    exchange_hermiticity_max_absolute::Float64
    passed::Bool
    resumed_from_kpoint::Int
    peak_memory_bytes::Int
    artifacts::Dict{String, String}
    input_sha256::Dict{String, String}
    diagnostics::Vector{String}
end

"""
Fail-closed inputs shared by the finite-band Galerkin uHu/sHu/sIu generators.

Spin generators require both `spn_file` and formal schema-1.2
`spn_provenance_file`. All generated matrices are transformed into the target
band frame selected by `authoritative_hamiltonian` and
`wavefunction_gauge_hdf5`.
"""
Base.@kwdef struct WannierHamiltonianOperatorGenerationConfig
    construction_policy::Symbol = :diagnostic
    source::SymmetryFoundation.AbstractWavefunctionSource
    topology_file::String
    authoritative_mmn_file::Union{Nothing, String} = nothing
    target_contract::Union{Nothing, WannierOperatorTargetContract} = nothing
    eig_file::String
    output_file::String
    provenance_json::String = output_file * ".provenance.json"
    spn_file::Union{Nothing, String} = nothing
    spn_provenance_file::Union{Nothing, String} = nothing
    spn_formatted::Bool = false
    authoritative_hamiltonian::AbstractAuthoritativeHamiltonian = NativeDFTHamiltonian()
    wavefunction_gauge_hdf5::Union{Nothing, String} = nothing
    # Deprecated compatibility name.  This value is a non-vetoing diagnostic
    # reference for finite-parent-band leakage; it is not an operator-error or
    # publication threshold.
    closure_tolerance::Float64 = 1.0e-6
    formatted::Bool = false
    overwrite::Bool = false
    max_cached_wavefunction_kpoints::Int = 8
end

"""Auditable outcome of one formal uHu/sHu/sIu generation attempt."""
struct WannierHamiltonianOperatorGenerationResult
    operator::Symbol
    "Whether the source operator passed the structural generation contract."
    passed::Bool
    source_generation_qualified::Bool
    artifact_published::Bool
    output_file::Union{Nothing, String}
    provenance_json::String
    "Deprecated numerical alias for the maximum recorded leakage diagnostic."
    closure_residual::Float64
    "Deprecated compatibility name for the non-vetoing diagnostic reference."
    closure_tolerance::Float64
    diagnostic_reference::Float64
    diagnostic_reference_status::String
    actual_operator_error_status::String
    nbands_convergence_status::String
    authoritative_hamiltonian::String
    authoritative_hamiltonian_digest::String
    input_sha256::Dict{String, String}
    diagnostics::Vector{String}
end

"""
Source-compatible constructor for expert callers that built the pre-1.3 result
positionally. New generators use the complete structural/audit constructor.
"""
function WannierHamiltonianOperatorGenerationResult(
    operator::Symbol,
    passed::Bool,
    output_file::Union{Nothing, String},
    provenance_json::String,
    closure_residual::Float64,
    closure_tolerance::Float64,
    authoritative_hamiltonian::String,
    authoritative_hamiltonian_digest::String,
    input_sha256::Dict{String, String},
    diagnostics::Vector{String},
)
    published = passed && output_file !== nothing
    reference_status =
        closure_residual <= closure_tolerance ? "WITHIN_REFERENCE" : "ABOVE_REFERENCE"
    return WannierHamiltonianOperatorGenerationResult(
        operator,
        passed,
        passed,
        published,
        output_file,
        provenance_json,
        closure_residual,
        closure_tolerance,
        closure_tolerance,
        reference_status,
        "NOT_AVAILABLE_WITHOUT_COMPLEMENT_HAMILTONIAN_OR_NBANDS_REFERENCE",
        "NOT_ESTABLISHED",
        authoritative_hamiltonian,
        authoritative_hamiltonian_digest,
        input_sha256,
        diagnostics,
    )
end

"""Inputs for a same-gauge schema-6 exact Wannier derivative operator bundle."""
Base.@kwdef struct ExactWannierOperatorBundleConfig
    tb_file::String
    chk_file::String
    eig_file::String
    mmn_file::String
    uiu_file::String
    uiu_provenance_json::String
    output_bundle_file::String
    overwrite::Bool = false
    support_tolerance::Float64 = 1.0e-12
    wigner_seitz_tolerance::Float64 = 1.0e-5
    wigner_seitz_search_size::Int = 3
end

"""Hash-bound artifact summary for a raw, unsymmetrized exact operator bundle."""
struct ExactWannierOperatorBundleResult
    operator_bundle_file::String
    operator_bundle_sha256::String
    scientific_content_sha256::String
    input_sha256::Dict{String, String}
    passed::Bool
end

# Construct and validate the complete native-QE parity threshold set.
function QEPAWParityThresholds(;
    generalized_norm_max_absolute::Real = 5.0e-6,
    mmn_max_absolute::Real = 1.0e-5,
    mmn_rms::Real = 1.0e-7,
    mmn_relative_l2::Real = 1.0e-6,
    amn_max_absolute::Real = 1.0e-5,
    amn_rms::Real = 1.0e-7,
    amn_relative_l2::Real = 1.0e-6,
    amn_max_principal_angle_rad::Real = 1.0e-4,
    amn_projector_max_absolute::Real = 1.0e-5,
)
    values = Float64[
        generalized_norm_max_absolute,
        mmn_max_absolute,
        mmn_rms,
        mmn_relative_l2,
        amn_max_absolute,
        amn_rms,
        amn_relative_l2,
        amn_max_principal_angle_rad,
        amn_projector_max_absolute,
    ]
    all(isfinite, values) && all(>(0.0), values) ||
        throw(ArgumentError("QE PAW parity thresholds must be finite and strictly positive"))
    return QEPAWParityThresholds(values...)
end

"""Raw-array QE parity metrics with a one-based worst residual index."""
struct QEPAWArrayParityMetrics
    max_absolute::Float64
    root_mean_square::Float64
    relative_l2::Float64
    worst_index::Vector{Int}
    finite::Bool
end

"""
Qualified or diagnostic native QE PAW/USPP MMN and AMN products.

`physical_overlap_available` is true if and only if `passed` is true; these
fields retain the original complete qualification result. Diagnostic construction
may consume finite quality failures through its separate admission checks without
changing either field. Missing required data or oracle provenance, nonfinite values,
rank deficiencies, and propagation-identity failures remain forbidden.
"""
struct QEPAWMatrixElementResult
    mmn::WannierMMN
    amn::WannierAMN
    mmn_parity::Union{Nothing, QEPAWArrayParityMetrics}
    amn_parity::Union{Nothing, QEPAWArrayParityMetrics}
    amn_max_principal_angle_rad::Float64
    amn_projector_max_absolute::Float64
    generalized_norm_max_absolute::Float64
    passed::Bool
    physical_overlap_available::Bool
    diagnostics::Vector{String}
    artifacts::Dict{String, String}
    input_sha256::Dict{String, String}

    function QEPAWMatrixElementResult(
        mmn,
        amn,
        mmn_parity,
        amn_parity,
        amn_max_principal_angle_rad,
        amn_projector_max_absolute,
        generalized_norm_max_absolute,
        passed,
        physical_overlap_available,
        diagnostics,
        artifacts,
        input_sha256,
    )
        passed_value = Bool(passed)
        physical_value = Bool(physical_overlap_available)
        passed_value == physical_value || throw(
            ArgumentError(
                "QE physical_overlap_available must equal the complete qualification result",
            ),
        )
        values = Float64[
            amn_max_principal_angle_rad,
            amn_projector_max_absolute,
            generalized_norm_max_absolute,
        ]
        all(value -> isfinite(value) || isnan(value), values) ||
            throw(ArgumentError("QE PAW result contains an invalid numerical diagnostic"))
        return new(
            mmn,
            amn,
            mmn_parity,
            amn_parity,
            values[1],
            values[2],
            values[3],
            passed_value,
            physical_value,
            String.(diagnostics),
            Dict{String, String}(artifacts),
            Dict{String, String}(input_sha256),
        )
    end
end

"""
    NativeQEPAWMatrices(nnkp_file; artifact_dir, ...)

Generate QE PAW/USPP-aware MMN and AMN matrices using the `.nnkp` file as the
only topology and trial-projection authority. Oracle files qualify generated
arrays but never supply construction values.
"""
struct NativeQEPAWMatrices <: AbstractWannierMatrixElementSource
    nnkp_file::String
    oracle_mmn_file::Union{Nothing, String}
    oracle_amn_file::Union{Nothing, String}
    artifact_dir::String
    thresholds::QEPAWParityThresholds
    require_oracle::Bool

    function NativeQEPAWMatrices(
        nnkp_file::AbstractString;
        artifact_dir::AbstractString,
        oracle_mmn_file::Union{Nothing, AbstractString} = nothing,
        oracle_amn_file::Union{Nothing, AbstractString} = nothing,
        require_oracle::Bool = true,
        thresholds::QEPAWParityThresholds = QEPAWParityThresholds(),
    )
        isempty(strip(nnkp_file)) && throw(ArgumentError("NNKP path must not be empty"))
        isempty(strip(artifact_dir)) && throw(ArgumentError("artifact_dir must not be empty"))
        return new(
            String(nnkp_file),
            oracle_mmn_file === nothing ? nothing : String(oracle_mmn_file),
            oracle_amn_file === nothing ? nothing : String(oracle_amn_file),
            String(artifact_dir),
            thresholds,
            Bool(require_oracle),
        )
    end
end

"""
    SymmetryCompletedQEPAWMatrices(nnkp_file, gauge_hdf5; artifact_dir, ...)

Generate QE PAW-aware MMN/AMN from the authoritative completed wavefunctions in
one sealed star-gauge artifact. NNKP supplies only topology and trial functions;
its independently diagonalized band gauge is not reused.
"""
struct SymmetryCompletedQEPAWMatrices <: AbstractWannierMatrixElementSource
    nnkp_file::String
    gauge_hdf5::String
    artifact_dir::String
    thresholds::QEPAWParityThresholds
    qualification_mode::Symbol

    function SymmetryCompletedQEPAWMatrices(
        nnkp_file::AbstractString,
        gauge_hdf5::AbstractString;
        artifact_dir::AbstractString,
        thresholds::QEPAWParityThresholds = QEPAWParityThresholds(),
        qualification_mode::Symbol = :strict,
    )
        isempty(strip(nnkp_file)) && throw(ArgumentError("NNKP path must not be empty"))
        isempty(strip(gauge_hdf5)) && throw(ArgumentError("gauge_hdf5 path must not be empty"))
        isempty(strip(artifact_dir)) && throw(ArgumentError("artifact_dir must not be empty"))
        qualification_mode in (:strict, :diagnostic_only) ||
            throw(ArgumentError("qualification_mode must be :strict or :diagnostic_only"))
        return new(
            String(nnkp_file),
            String(gauge_hdf5),
            String(artifact_dir),
            thresholds,
            qualification_mode,
        )
    end
end

"""Immutable native inputs and representation-compatibility controls."""
Base.@kwdef struct WannierizationInputConfig
    construction_policy::Symbol = :diagnostic
    wannierization_mode::Symbol = :auto
    source::Union{Nothing, SymmetryFoundation.AbstractWavefunctionSource} = nothing
    sewing_backend::AbstractBandSewingBackend = CoefficientMappingSewing()
    wavefunction_gauge_backend::AbstractWavefunctionGaugeBackend = NativeEigenstateGauge()
    authoritative_hamiltonian::AbstractAuthoritativeHamiltonian = NativeDFTHamiltonian()
    wavefunction_gauge_hdf5::Union{Nothing, String} = nothing
    win_file::String
    eig_file::String
    mmn_file::String
    amn_file::Union{Nothing, String} = nothing
    matrix_elements::Union{Nothing, AbstractWannierMatrixElementSource} = nothing
    projection_basis::Union{Nothing, WannierProjection.WannierProjectionBasis} = nothing
    band_representation::Union{Nothing, SymmetryFoundation.BandRepresentation} = nothing
    band_representation_hdf5::Union{Nothing, String} = nothing
    outer_min_ev::Float64 = -Inf
    outer_max_ev::Float64 = Inf
    frozen_min_ev::Float64 = Inf
    frozen_max_ev::Float64 = -Inf
    frozen_states::Vector{Tuple{Int, Int}} = Tuple{Int, Int}[]
    num_wannier::Int = 0
    symmetry_tolerance::Float64 = 1.0e-5
    degeneracy_tolerance_ev::Float64 = 0.01
    representation_tolerance::Float64 = 1.0e-8
    empirical_covariance_budget::Union{Nothing, Float64} = nothing
    target_center_matching_tolerance::Float64 = 1.0e-8
    compatibility_policy::Symbol = :warn
end

"""Immutable numerical solver, initialization, and deterministic execution controls."""
Base.@kwdef struct WannierizationSolverConfig
    algorithm_profile::Symbol = :auto
    smv_fletcher_reeves_two_stage_audit_thresholds::SMVFletcherReevesTwoStageAuditThresholds =
        SMVFletcherReevesTwoStageAuditThresholds()
    smv_fletcher_reeves_two_stage_audit_manifest::Union{Nothing, String} = nothing
    initialization::Symbol = :amn
    z_mix_ratio::Float64 = 0.5
    u_mix_ratio::Float64 = 1.0
    acceleration::WannierizationAccelerationConfig = WannierizationAccelerationConfig()
    numerical_thresholds::WannierizationNumericalThresholds = WannierizationNumericalThresholds()
    initialization_backend::AbstractWannierInitializationBackend = AMNExactFrozenInitialization()
    paw_scdm_input_hdf5::Union{Nothing, String} = nothing
    multi_start::WannierizationMultiStartConfig = WannierizationMultiStartConfig()
    max_iterations::Int = 1000
    convergence_tolerance::Float64 = 1.0e-9
    convergence_window::Int = 3
    little_group_tolerance::Float64 = 1.0e-6
    little_group_max_iterations::Int = 10
    localize::Bool = true
    symmetrize_z::Bool = true
    parallel::Symbol = :serial
    random_seed::UInt64 = 0x6e6c716773617766
end

"""Immutable restart, fixed-subspace, and periodic-checkpoint controls."""
Base.@kwdef struct WannierizationCheckpointConfig
    restart_hdf5::Union{Nothing, String} = nothing
    fixed_subspace_hdf5::Union{Nothing, String} = nothing
    checkpoint_hdf5::Union{Nothing, String} = nothing
    checkpoint_interval::Int = 10
end

"""Cold-path progress and observer controls kept outside numerical state."""
Base.@kwdef struct WannierizationRuntimeConfig
    progress_interval::Int = 10
    iteration_observer::Any = nothing
end

"""Immutable durable-output inventory and operator-qualification controls."""
Base.@kwdef struct WannierizationOutputConfig
    band_representation_output_hdf5::Union{Nothing, String} = nothing
    tb_output_formats::Tuple{Vararg{Symbol}} = (:packed_hdf5,)
    write_wannier90_tb::Bool = false
    profile::Symbol = :hamiltonian_position
    spn_file::Union{Nothing, String} = nothing
    spn_provenance_file::Union{Nothing, String} = nothing
    uiu_file::Union{Nothing, String} = nothing
    uhu_file::Union{Nothing, String} = nothing
    siu_file::Union{Nothing, String} = nothing
    shu_file::Union{Nothing, String} = nothing
    uiu_provenance_json::Union{Nothing, String} = nothing
    uhu_provenance_json::Union{Nothing, String} = nothing
    siu_provenance_json::Union{Nothing, String} = nothing
    shu_provenance_json::Union{Nothing, String} = nothing
    spn_formatted::Bool = false
    operator_files_formatted::Bool = false
    # Deprecated compatibility name.  This remains a non-vetoing diagnostic
    # reference and must not be used to infer Galerkin operator error.
    operator_closure_tolerance::Float64 = 1.0e-6
    spin_family_covariance_tolerance::Float64 = 1.0e-8
    spin_family_idempotence_tolerance::Float64 = 1.0e-9
    final_tb_symmetry_report_enabled::Union{Nothing, Bool} = nothing
end

const WANNIERIZATION_INPUT_CONFIG_FIELDS = fieldnames(WannierizationInputConfig)
const WANNIERIZATION_SOLVER_CONFIG_FIELDS = fieldnames(WannierizationSolverConfig)
const WANNIERIZATION_CHECKPOINT_CONFIG_FIELDS = fieldnames(WannierizationCheckpointConfig)
const WANNIERIZATION_RUNTIME_CONFIG_FIELDS = fieldnames(WannierizationRuntimeConfig)
const WANNIERIZATION_OUTPUT_CONFIG_FIELDS = fieldnames(WannierizationOutputConfig)
const WANNIERIZATION_CONFIG_LEAF_FIELDS = (
    WANNIERIZATION_INPUT_CONFIG_FIELDS...,
    WANNIERIZATION_SOLVER_CONFIG_FIELDS...,
    WANNIERIZATION_CHECKPOINT_CONFIG_FIELDS...,
    WANNIERIZATION_RUNTIME_CONFIG_FIELDS...,
    WANNIERIZATION_OUTPUT_CONFIG_FIELDS...,
)
@assert length(WANNIERIZATION_CONFIG_LEAF_FIELDS) == 73
@assert length(unique(WANNIERIZATION_CONFIG_LEAF_FIELDS)) == 73

# Store one native Wannierization workflow as five immutable configuration groups.
Base.@kwdef struct SymmetryAdaptedWannierizationConfig
    input::WannierizationInputConfig
    solver::WannierizationSolverConfig = WannierizationSolverConfig()
    checkpoint::WannierizationCheckpointConfig = WannierizationCheckpointConfig()
    runtime::WannierizationRuntimeConfig = WannierizationRuntimeConfig()
    output::WannierizationOutputConfig = WannierizationOutputConfig()
end

"""Copy one immutable configuration group with selected replacements."""
function _replace_wannierization_group(group::T, replacements::NamedTuple) where {T}
    names = fieldnames(T)
    values = NamedTuple{names}(Tuple(getfield(group, name) for name in names))
    return T(; merge(values, replacements)...)
end

"""Copy a grouped configuration while replacing only declared group leaves."""
function _replace_wannierization_config(
    config::SymmetryAdaptedWannierizationConfig;
    input::NamedTuple = NamedTuple(),
    solver::NamedTuple = NamedTuple(),
    checkpoint::NamedTuple = NamedTuple(),
    runtime::NamedTuple = NamedTuple(),
    output::NamedTuple = NamedTuple(),
)
    return SymmetryAdaptedWannierizationConfig(
        input = _replace_wannierization_group(config.input, input),
        solver = _replace_wannierization_group(config.solver, solver),
        checkpoint = _replace_wannierization_group(config.checkpoint, checkpoint),
        runtime = _replace_wannierization_group(config.runtime, runtime),
        output = _replace_wannierization_group(config.output, output),
    )
end

@doc """
    SymmetryAdaptedWannierizationConfig(; input, solver, checkpoint, runtime, output)

Configure one WannierBerri-compatible symmetry-adapted disentanglement and
localization run from five immutable sub-configurations. Z and U mixing are
independent. `solver.initialization` is `:amn`,
`:random`, or `:restart`; `parallel` is `:serial`, `:threads`, or expert-only
`:mpi`. A prebuilt
A supplied band representation is inferred as `representation_source=:provided`;
native reconstruction is inferred as `:detected`; and
`wannierization_mode=:ordinary` constructs or validates an identity
representation on the full Brillouin zone without space-group, magnetic-group,
or antiunitary constraints. Representation metadata remains input provenance and
cannot activate symmetry projection, little-group processing, or covariance
rejection in ordinary mode.

With `wannierization_mode=:ordinary` and `algorithm_profile=:auto`, the solver
always selects `:smv_fletcher_reeves_two_stage`. No audit manifest is required.
The path uses separated SMV disentanglement and Fletcher--Reeves localization;
the validated external-oracle envelope additionally fixes `schedule=:two_stage`,
`AMNExactFrozenInitialization()`, identical WIN/EIG/MMN/AMN data and windows,
Float64 arithmetic, five-step FR restarts, `u_w90_trial_step=2.0`, and identical
iteration budgets. Runs outside that envelope remain valid default executions
but do not inherit an external-oracle parity claim.

`profile` controls only the final operator-bundle inventory and accepts
`:hamiltonian_position`, `:hamiltonian_position_spin`, or `:full`.
`spn_provenance_file`, `spin_family_covariance_tolerance`, and
`spin_family_idempotence_tolerance` are export-qualification settings and do
not enter the solver restart digest. Spin-family profiles fail closed when the
formal source/gauge chain cannot be established; finite covariance or
idempotence excess is retained only as explicitly diagnostic output.
""" SymmetryAdaptedWannierizationConfig

"""
Complete or retained SAWF state, including a directly consumable `WannierCHK`
view when dimensions are valid. Non-success statuses may still carry the last
finite iterate; diagnostics distinguish a warning-bearing result from a typed
failure.
"""
struct WannierizationResult
    status::WannierizationStatus
    v_matrix::Array{ComplexF64, 3}
    wannier_centers_cartesian::Matrix{Float64}
    spreads_angstrom2::Vector{Float64}
    history::Vector{WannierizationIteration}
    diagnostics::Vector{WannierizationDiagnostic}
    input_summary::Dict{String, String}
    wannier_chk::Union{Nothing, WannierCHK}
    checkpoint_file::Union{Nothing, String}
    restart_state::Union{Nothing, WannierizationRestartState}
    artifacts::WannierizationArtifacts
    initialization_report::Union{Nothing, WannierInitializationReport}
    tb_symmetry_qualification::TBSymmetryQualification
end

# Preserve the schema-2.4 result constructor while schema 2.5 adds final-TB evidence.
function WannierizationResult(
    status,
    v_matrix,
    centers,
    spreads,
    history,
    diagnostics,
    input_summary,
    wannier_chk,
    checkpoint_file,
    restart_state,
    artifacts,
    initialization_report,
)
    return WannierizationResult(
        status,
        v_matrix,
        centers,
        spreads,
        history,
        diagnostics,
        input_summary,
        wannier_chk,
        checkpoint_file,
        restart_state,
        artifacts,
        initialization_report,
        _tb_symmetry_not_run(),
    )
end

# Preserve the schema-2.1 result constructor while adding initialization evidence.
function WannierizationResult(
    status,
    v_matrix,
    centers,
    spreads,
    history,
    diagnostics,
    input_summary,
    wannier_chk,
    checkpoint_file,
    restart_state,
    artifacts,
)
    return WannierizationResult(
        status,
        v_matrix,
        centers,
        spreads,
        history,
        diagnostics,
        input_summary,
        wannier_chk,
        checkpoint_file,
        restart_state,
        artifacts,
        nothing,
    )
end

# Preserve the established expert constructor while adding restart/artifact state.
function WannierizationResult(
    status,
    v_matrix,
    centers,
    spreads,
    history,
    diagnostics,
    input_summary,
    wannier_chk,
    checkpoint_file,
)
    return WannierizationResult(
        status,
        v_matrix,
        centers,
        spreads,
        history,
        diagnostics,
        input_summary,
        wannier_chk,
        checkpoint_file,
        nothing,
        WannierizationArtifacts(),
    )
end
