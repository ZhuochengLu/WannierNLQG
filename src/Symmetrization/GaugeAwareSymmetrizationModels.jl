"""Closed status set for gauge-aware post-hoc symmetrization."""
@enum GaugeAwareSymmetrizationStatus::UInt8 begin
    PASS
    HOLD_POSITION_PENDING
    FAILED_INPUT_PROVENANCE
    FAILED_BAND_REPRESENTATION
    FAILED_INPUT_SUBSPACE_NOT_CLOSED
    FAILED_PHYSICAL_BAND_PRESERVATION
    FAILED_POSITION_VALIDATION
    PASS_WITH_WARNINGS
end

"""
One measured numerical threshold in a gauge-aware symmetrization workflow.

Indices use one-based Julia conventions. A zero operation, k-point, or band
block means that the metric is global and has no single worst indexed point.
"""
Base.@kwdef struct GaugeAwareThresholdEvent
    # Store a stage-local scalar gate and its optional worst-point coordinates.
    stage::Symbol
    metric::String
    value::Float64
    threshold::Float64
    relation::Symbol = :less_than_or_equal
    passed::Bool
    operation::Int = 0
    kpoint::Int = 0
    band_block::Int = 0
    context::String = ""
end

"""
Numerical gates for one gauge-aware symmetrization workflow.

Energy tolerances use eV and position tolerances use Angstrom.
"""
Base.@kwdef struct GaugeAwareSymmetrizationThresholds
    # Store immutable fail-closed thresholds by physical stage.
    chk_semiunitarity::Float64 = 1.0e-10
    subspace_closure::Float64 = 1.0e-6
    wannier_sewing_unitarity::Float64 = 1.0e-6
    group_law_absolute::Float64 = 1.0e-5
    group_law_oracle_excess::Float64 = 1.0e-8
    fourier_roundtrip::Float64 = 1.0e-10
    hamiltonian_idempotence::Float64 = 1.0e-10
    mp_band_max_ev::Float64 = 1.0e-3
    mp_band_rms_ev::Float64 = 1.0e-4
    path_band_max_ev::Float64 = 1.0e-2
    raw_position_angstrom::Float64 = 1.0e-8
    position_covariance_angstrom::Float64 = 1.0e-8
    position_roundtrip_angstrom::Float64 = 1.0e-10
end

"""
Configuration for symmetrizing an existing CHK-gauge Wannier model.

POSCAR and WAVECAR are read only for exact provenance comparison with the
stored band representation; all Wannier-gauge data come from CHK/EIG/MMN/TB.
"""
Base.@kwdef struct GaugeAwareSymmetrizationConfig
    # Store exact input identities and the isolated workflow output root.
    representation_hdf5_file::String
    poscar_file::String
    wavecar_file::String
    source_win_file::String
    source_eig_file::String
    source_mmn_file::String
    win_file::String
    eig_file::String
    mmn_file::String
    chk_file::String
    tb_file::String
    output_root::String
    oracle_hdf5_file::Union{Nothing, String} = nothing
    require_oracle::Bool = true
    complete_position::Bool = true
    thresholds::GaugeAwareSymmetrizationThresholds = GaugeAwareSymmetrizationThresholds()
    threshold_policy::Symbol = :record_and_continue
    gauge_policy::Symbol = :preserve_input_chk
    wannier_center_policy::Symbol = :keep_input
    real_space_replica_policy::Symbol = :input
    materialization_variants::Tuple{Vararg{Symbol}} = (:C00, :C11)
    qualification_window_ev::Union{Nothing, NTuple{2, Float64}} = nothing
    wigner_seitz_tolerance::Float64 = 1.0e-5
    wigner_seitz_search_size::Int = 3
    provenance_scripts::Vector{String} = String[]
    overwrite::Bool = false
end

"""Durable artifact and metric inventory from one gauge-aware workflow."""
struct GaugeAwareSymmetrizationResult
    status::GaugeAwareSymmetrizationStatus
    output_root::String
    artifacts::Dict{String, String}
    metrics::Dict{String, Float64}
    diagnostics::Vector{String}
    threshold_events::Vector{GaugeAwareThresholdEvent}
end
