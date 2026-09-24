
"""Energy-weighted material operators sharing the Hamiltonian R support and replica weights."""
struct OrbitalRealSpaceSources{B, F, C}
    energy_connection::B
    derivative_overlap::F
    axial_energy_overlap::C
    qualification::Dict{String, Any}
end

const ORBITAL_RESPONSE_OPERATOR_NAMES = (
    "hamiltonian",
    "position",
    "hamiltonian_weighted_connection",
    "derivative_overlap_tensor",
    "hamiltonian_weighted_axial_derivative_overlap",
)

# Read an optional String/Symbol-keyed qualification entry without inventing evidence.
function _orbital_optional_entry(values, name::String, default = nothing)
    values isa AbstractDict || values isa NamedTuple || return default
    values isa NamedTuple &&
        hasproperty(values, Symbol(name)) &&
        return getproperty(values, Symbol(name))
    haskey(values, name) && return values[name]
    haskey(values, Symbol(name)) && return values[Symbol(name)]
    return default
end

# Identify a recorded SHA-256 rather than a NOT_RECORDED-style sentinel.
_orbital_sha256(value) = value isa AbstractString && occursin(r"^[0-9a-f]{64}$", String(value))

# Identify a concrete contract value that can participate in a conflict comparison.
function _orbital_recorded(value)
    value === nothing && return false
    text = String(value)
    return !isempty(text) &&
           text ∉ ("NOT_RECORDED", "NOT_APPLICABLE", "LEGACY_NOT_RECORDED") &&
           !startswith(text, "LEGACY_")
end

"""
Assess material-orbital source, gauge, frame, and energy-window evidence.

Missing optional evidence is returned as an unverified contract. Explicitly disagreeing
recorded hashes, gauges, frames, or input semantics are returned as conflicts for Runtime
to reject before numerical execution. This routine never upgrades missing evidence to PASS.
"""
function validate_orbital_sources(manifest, semantics, mu, temperature)
    mus = mu isa Vector{Float64} ? validate_fermi_energies(mu) : Float64[mu]
    qualification = manifest.operator_qualification
    verified = String[]
    unverified = String[]
    conflicts = String[]
    reasons = String[]
    operators = _orbital_optional_entry(qualification, "operators", Dict{String, Any}())
    target_gauges = String[]
    generic_common_frame_records = 0
    root_transform =
        hasproperty(manifest, :band_frame_transform_sha256) ?
        getproperty(manifest, :band_frame_transform_sha256) : nothing
    root_contract =
        hasproperty(manifest, :band_frame_contract_sha256) ?
        getproperty(manifest, :band_frame_contract_sha256) : nothing
    root_authority =
        hasproperty(manifest, :authoritative_hamiltonian_sha256) ?
        getproperty(manifest, :authoritative_hamiltonian_sha256) : nothing

    for name in ORBITAL_RESPONSE_OPERATOR_NAMES
        operator = _orbital_optional_entry(operators, name, nothing)
        if operator === nothing
            push!(unverified, "operator.$(name).qualification")
            push!(reasons, "ORBITAL_OPERATOR_QUALIFICATION_NOT_RECORDED")
            continue
        end
        source_status = String(_orbital_optional_entry(operator, "source_status", "NOT_RECORDED"))
        gauge_status = String(_orbital_optional_entry(operator, "gauge_status", "NOT_RECORDED"))
        if source_status == "PASS"
            push!(verified, "operator.$(name).source")
        else
            push!(unverified, "operator.$(name).source")
            push!(reasons, "ORBITAL_OPERATOR_SOURCE_UNVERIFIED")
        end
        if gauge_status == "PASS"
            push!(verified, "operator.$(name).gauge")
        else
            push!(unverified, "operator.$(name).gauge")
            push!(reasons, "ORBITAL_OPERATOR_GAUGE_UNVERIFIED")
        end
        target_gauge = _orbital_optional_entry(operator, "target_band_gauge", nothing)
        if _orbital_recorded(target_gauge) && gauge_status == "PASS"
            push!(target_gauges, String(target_gauge))
            generic_common_frame_records += 1
        end
        operator_transform =
            _orbital_optional_entry(operator, "band_frame_transform_sha256", nothing)
        operator_contract = _orbital_optional_entry(operator, "band_frame_contract_sha256", nothing)
        operator_authority =
            _orbital_optional_entry(operator, "authoritative_hamiltonian_digest", nothing)
        _orbital_sha256(root_transform) &&
            _orbital_sha256(operator_transform) &&
            String(root_transform) != String(operator_transform) &&
            push!(conflicts, "operator.$(name).band_frame_transform_sha256")
        _orbital_sha256(root_contract) &&
            _orbital_sha256(operator_contract) &&
            String(root_contract) != String(operator_contract) &&
            push!(conflicts, "operator.$(name).band_frame_contract_sha256")
        _orbital_sha256(root_authority) &&
            _orbital_sha256(operator_authority) &&
            String(root_authority) != String(operator_authority) &&
            push!(conflicts, "operator.$(name).authoritative_hamiltonian_sha256")
    end
    length(unique(target_gauges)) > 1 && push!(conflicts, "orbital.common_target_band_gauge")
    generic_common_frame_verified =
        generic_common_frame_records == length(ORBITAL_RESPONSE_OPERATOR_NAMES) &&
        length(unique(target_gauges)) == 1
    if generic_common_frame_verified
        push!(verified, "orbital.common_target_band_gauge")
    else
        push!(unverified, "orbital.common_frame")
        push!(reasons, "ORBITAL_COMMON_FRAME_UNVERIFIED")
    end

    raw_record = _orbital_optional_entry(qualification, "orbital_response", nothing)
    record =
        raw_record === nothing ? nothing :
        Dict{String, Any}(String(key) => value for (key, value) in pairs(raw_record))
    if record === nothing
        push!(unverified, "orbital_response.qualification")
        push!(unverified, "orbital.material_energy_window")
        temperature > 0 && push!(unverified, "orbital.thermal_tail")
        push!(reasons, "ORBITAL_RESPONSE_QUALIFICATION_NOT_RECORDED")
        push!(reasons, "ORBITAL_ENERGY_WINDOW_UNVERIFIED")
        temperature > 0 && push!(reasons, "ORBITAL_THERMAL_TAIL_UNVERIFIED")
    else
        recorded_semantics = _orbital_optional_entry(record, "input_semantics", nothing)
        if _orbital_recorded(recorded_semantics) && String(recorded_semantics) != string(semantics)
            push!(conflicts, "orbital_response.input_semantics")
        elseif String(something(recorded_semantics, "")) == string(semantics)
            push!(verified, "orbital_response.input_semantics")
        else
            push!(unverified, "orbital_response.input_semantics")
            push!(reasons, "ORBITAL_INPUT_SEMANTICS_UNVERIFIED")
        end
        derivative_frame = _orbital_optional_entry(record, "derivative_frame", nothing)
        if _orbital_recorded(derivative_frame) &&
           String(derivative_frame) != "uncentered_periodic_wannier"
            push!(conflicts, "orbital_response.derivative_frame")
        elseif String(something(derivative_frame, "")) == "uncentered_periodic_wannier"
            push!(verified, "orbital_response.derivative_frame")
        else
            push!(unverified, "orbital_response.derivative_frame")
            push!(reasons, "ORBITAL_COMMON_FRAME_UNVERIFIED")
        end
        if String(_orbital_optional_entry(record, "frame_status", "NOT_RECORDED")) == "PASS" &&
           generic_common_frame_verified
            push!(verified, "orbital_response.common_frame")
        else
            push!(unverified, "orbital_response.common_frame")
            push!(reasons, "ORBITAL_COMMON_FRAME_UNVERIFIED")
        end

        hashes = _orbital_optional_entry(record, "operator_source_sha256", Dict{String, Any}())
        for name in ORBITAL_RESPONSE_OPERATOR_NAMES
            digest = _orbital_optional_entry(hashes, name, nothing)
            operator = _orbital_optional_entry(operators, name, nothing)
            generic_digest = _orbital_optional_entry(operator, "source_artifact_sha256", nothing)
            if digest === nothing || !_orbital_recorded(digest)
                push!(unverified, "orbital_response.operator_source_sha256.$(name)")
                push!(reasons, "ORBITAL_OPERATOR_SOURCE_HASH_UNVERIFIED")
            elseif !_orbital_sha256(digest)
                push!(conflicts, "orbital_response.operator_source_sha256.$(name).invalid")
            elseif _orbital_sha256(generic_digest) && String(digest) != String(generic_digest)
                push!(conflicts, "orbital_response.operator_source_sha256.$(name)")
            elseif _orbital_sha256(generic_digest)
                push!(verified, "orbital_response.operator_source_sha256.$(name)")
            else
                push!(unverified, "orbital_response.operator_source_sha256.$(name)")
                push!(reasons, "ORBITAL_OPERATOR_SOURCE_HASH_UNVERIFIED")
            end
        end

        window = _orbital_optional_entry(record, "validated_energy_window_ev", nothing)
        if window isa AbstractVector && length(window) == 2
            lower, upper = Float64.(window)
            if !(isfinite(lower) && isfinite(upper) && lower < upper)
                push!(conflicts, "orbital_response.validated_energy_window_ev.invalid")
            elseif String(_orbital_optional_entry(record, "window_status", "NOT_RECORDED")) !=
                   "PASS" || !all(value -> lower < value < upper, mus)
                push!(unverified, "orbital.material_energy_window")
                push!(reasons, "ORBITAL_ENERGY_WINDOW_UNVERIFIED")
            else
                push!(verified, "orbital.material_energy_window")
                thermal = temperature * 8.617333262145e-5
                if thermal > 0
                    tail =
                        maximum(exp(-min(value - lower, upper - value) / thermal) for value in mus)
                    if tail <= 1e-12
                        push!(verified, "orbital.thermal_tail")
                    else
                        push!(unverified, "orbital.thermal_tail")
                        push!(reasons, "ORBITAL_THERMAL_TAIL_UNVERIFIED")
                    end
                end
            end
        else
            push!(unverified, "orbital.material_energy_window")
            temperature > 0 && push!(unverified, "orbital.thermal_tail")
            push!(reasons, "ORBITAL_ENERGY_WINDOW_UNVERIFIED")
            temperature > 0 && push!(reasons, "ORBITAL_THERMAL_TAIL_UNVERIFIED")
        end
    end
    return (
        record = record,
        verified_contracts = sort!(unique!(verified)),
        unverified_contracts = sort!(unique!(unverified)),
        conflicting_contracts = sort!(unique!(conflicts)),
        reasons = sort!(unique!(reasons)),
    )
end

"""Fourier-sum a material operator in its original uncentered orbital frame."""
function _orbital_fourier(real_space, factors)
    leading=size(real_space)[1:(end - 1)]
    output=zeros(ComplexF64, leading)
    for index in eachindex(factors)
        output .+= factors[index] .* selectdim(real_space, ndims(real_space), index)
    end
    return output
end

"""Complete F,B,C before center transformation, then rotate to the common eigenframe.

Only the antisymmetric C part is reconstructed from i(Cab-Cba); the omitted
symmetric part cannot enter the axial-vector contraction. No result is normalized here.
"""
function orbital_completion(sources::OrbitalRealSpaceSources, model, workspace)
    data=workspace.data;
    factors=data.fourier_factors
    h=_orbital_fourier(model.hamiltonian_r, factors)
    a=_orbital_fourier(model.position_r, factors)
    b=_orbital_fourier(sources.energy_connection, factors)
    f=_orbital_fourier(sources.derivative_overlap, factors)
    axial=_orbital_fourier(sources.axial_energy_overlap, factors)
    count=model.num_orbitals
    c=zeros(ComplexF64, count, count, 3, 3)
    for (axis, (x, y)) in enumerate(((2, 3), (3, 1), (1, 2)))
        c[:, :, x, y].=-0.5im .* axial[:, :, axis]
        c[:, :, y, x].=0.5im .* axial[:, :, axis]
    end
    tb=similar(b);
    tf=similar(f);
    tc=similar(c)
    for x in 1:3
        tb[:, :, x].=b[:, :, x]-h*a[:, :, x]
    end
    for y in 1:3, x in 1:3
        tf[:, :, x, y].=f[:, :, x, y]-a[:, :, x]*a[:, :, y]
        tc[
            :,
            :,
            x,
            y,
        ].=c[:, :, x, y]-a[:, :, x]*b[:, :, y]-b[:, :, x]'*a[:, :, y]+a[:, :, x]*h*a[:, :, y]
    end
    phases=workspace.scratch.center_phase_factors
    u=Diagonal(phases)*data.spectrum.eigenvectors
    for x in 1:3
        tb[:, :, x].=u'*tb[:, :, x]*u
    end
    for y in 1:3, x in 1:3
        tf[:, :, x, y].=u'*tf[:, :, x, y]*u
        tc[:, :, x, y].=u'*tc[:, :, x, y]*u
    end
    return OrbitalCompletion(tf, tb, tc)
end
