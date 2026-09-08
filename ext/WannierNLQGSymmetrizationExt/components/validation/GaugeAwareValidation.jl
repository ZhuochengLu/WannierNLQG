# Validate immutable policy choices and positive numerical thresholds.
function _validate_gauge_aware_config(config::GaugeAwareSymmetrizationConfig)
    config.threshold_policy in (:record_and_continue, :fail_stop) ||
        throw(ArgumentError("threshold_policy must be :record_and_continue or :fail_stop"))
    config.gauge_policy == :preserve_input_chk ||
        throw(ArgumentError("gauge_policy must be :preserve_input_chk"))
    config.wannier_center_policy == :keep_input ||
        throw(ArgumentError("wannier_center_policy must be :keep_input for C00"))
    config.real_space_replica_policy == :input ||
        throw(ArgumentError("real_space_replica_policy must be :input for C00"))
    isempty(config.materialization_variants) &&
        throw(ArgumentError("materialization_variants must not be empty"))
    length(unique(config.materialization_variants)) == length(config.materialization_variants) ||
        throw(ArgumentError("materialization_variants must not contain duplicates"))
    allowed_variants = (:C00, :C01, :C10, :C11)
    all(variant -> variant in allowed_variants, config.materialization_variants) ||
        throw(ArgumentError("materialization_variants must be drawn from C00/C01/C10/C11"))
    config.wigner_seitz_tolerance > 0.0 ||
        throw(ArgumentError("wigner_seitz_tolerance must be positive"))
    config.wigner_seitz_search_size > 0 ||
        throw(ArgumentError("wigner_seitz_search_size must be positive"))
    if config.qualification_window_ev !== nothing
        lower, upper = something(config.qualification_window_ev)
        isfinite(lower) && isfinite(upper) && lower < upper ||
            throw(ArgumentError("qualification_window_ev must be finite and increasing"))
    end
    for field in fieldnames(GaugeAwareSymmetrizationThresholds)
        value = getfield(config.thresholds, field)
        isfinite(value) && value > 0.0 ||
            throw(ArgumentError("threshold $(field) must be positive and finite"))
    end
    return nothing
end

# Decode one 2x2 materialization label without changing the common projected q fields.
function _gauge_aware_materialization_policy(variant::Symbol)
    variant in (:C00, :C01, :C10, :C11) ||
        throw(ArgumentError("unsupported gauge-aware materialization variant $(variant)"))
    center_policy = variant in (:C00, :C01) ? :keep_input : :symmetrize
    replica_policy = variant in (:C00, :C10) ? :input : :minimum_distance
    return (; center_policy, replica_policy)
end

# Record one finite numerical gate without changing the scientific array being assessed.
function _record_gauge_aware_threshold!(
    events::Vector{GaugeAwareThresholdEvent},
    diagnostics::Vector{String},
    stage::Symbol,
    metric::AbstractString,
    value::Real,
    threshold::Real;
    operation::Int = 0,
    kpoint::Int = 0,
    band_block::Int = 0,
    context::AbstractString = "",
)
    measured = Float64(value)
    limit = Float64(threshold)
    isfinite(measured) || throw(ArgumentError("threshold metric $(metric) is non-finite"))
    isfinite(limit) && limit > 0.0 ||
        throw(ArgumentError("threshold limit $(metric) must be positive and finite"))
    passed = measured <= limit
    event = GaugeAwareThresholdEvent(
        stage = stage,
        metric = String(metric),
        value = measured,
        threshold = limit,
        passed = passed,
        operation = operation,
        kpoint = kpoint,
        band_block = band_block,
        context = String(context),
    )
    push!(events, event)
    passed || push!(
        diagnostics,
        "threshold warning [$(stage)] $(metric)=$(measured) exceeds $(limit)" *
        (isempty(context) ? "" : "; $(context)"),
    )
    return passed
end

# Preserve the strict legacy stop path while allowing audited continuation by policy.
_gauge_aware_fail_stop(config::GaugeAwareSymmetrizationConfig, passed::Bool) =
    config.threshold_policy == :fail_stop && !passed

# Convert a threshold event into JSON-compatible scalar fields.
function _gauge_aware_threshold_payload(event::GaugeAwareThresholdEvent)
    return Dict(
        "stage" => String(event.stage),
        "metric" => event.metric,
        "value" => event.value,
        "threshold" => event.threshold,
        "relation" => String(event.relation),
        "passed" => event.passed,
        "operation" => event.operation,
        "kpoint" => event.kpoint,
        "band_block" => event.band_block,
        "context" => event.context,
    )
end

# Check exact source/target Wannier90 input identities.
function _matching_gauge_aware_wannier_inputs(source_hashes::Dict{String, String})
    return source_hashes["source_win"] == source_hashes["target_win"] &&
           source_hashes["source_eig"] == source_hashes["target_eig"] &&
           source_hashes["source_mmn"] == source_hashes["target_mmn"]
end

# Check that raw VASP/EIG identities match the stored representation provenance.
function _matching_gauge_aware_representation_inputs(
    source_hashes::Dict{String, String},
    representation::BandRepresentation,
)
    return get(representation.input_sha256, "POSCAR", "") == source_hashes["poscar"] &&
           get(representation.input_sha256, "WAVECAR", "") == source_hashes["wavecar"] &&
           get(representation.input_sha256, "EIG", "") == source_hashes["source_eig"]
end

# Verify representation energies against EIG and upgrade missing legacy provenance in memory.
function _validate_and_attach_gauge_aware_eig!(
    representation::BandRepresentation,
    eig::WannierEIG,
    eig_sha256::String;
    tolerance::Float64 = 1.0e-12,
)
    size(representation.energies_ev) == size(eig.data) ||
        return (passed = false, augmented = false, maximum_error = Inf)
    maximum_error = maximum(abs, representation.energies_ev - eig.data)
    maximum_error <= tolerance || return (passed = false, augmented = false, maximum_error)
    stored = get(representation.input_sha256, "EIG", nothing)
    stored === nothing || return (passed = stored == eig_sha256, augmented = false, maximum_error)
    representation.input_sha256["EIG"] = eig_sha256
    return (passed = true, augmented = true, maximum_error)
end
