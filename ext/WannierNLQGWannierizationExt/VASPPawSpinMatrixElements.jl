const VASP_PAW_SPN_SCHEMA = "wanniernlqg.vasp-paw-spn"
const VASP_PAW_SPN_SCHEMA_VERSION = "1.0"

# Append one typed value to the logical HDF5 payload hash. This encoding is
# independent of HDF5 object addresses and traversal order.
function _vasp_paw_spn_digest_value!(io::Base.IO, value)
    if value isa AbstractString
        bytes = codeunits(String(value))
        write(io, UInt8('S'), Int64(length(bytes)), bytes)
    elseif value isa Bool
        write(io, UInt8('B'), UInt8(value))
    elseif value isa Integer
        write(io, UInt8('I'))
        _vasp_paw_spn_digest_value!(io, string(value))
    elseif value isa AbstractFloat
        write(io, UInt8('F'))
        _vasp_paw_spn_digest_value!(io, bitstring(Float64(value)))
    elseif value isa Complex
        write(io, UInt8('C'))
        _vasp_paw_spn_digest_value!(io, real(value))
        _vasp_paw_spn_digest_value!(io, imag(value))
    elseif value isa AbstractArray
        write(io, UInt8('A'), Int64(ndims(value)))
        for dimension in size(value)
            write(io, Int64(dimension))
        end
        for entry in value
            _vasp_paw_spn_digest_value!(io, entry)
        end
    else
        throw(ArgumentError("unsupported VASP PAW-SPN provenance value type $(typeof(value))"))
    end
    return nothing
end

# Hash every persisted logical field except the digest attribute itself.
function _vasp_paw_spn_digest_object!(io::Base.IO, object, path::String)
    _vasp_paw_spn_digest_value!(io, path)
    attributes = HDF5.attributes(object)
    names = sort!(String.(collect(keys(attributes))))
    for name in names
        name == "payload_sha256" && continue
        _vasp_paw_spn_digest_value!(io, "attribute/$(name)")
        _vasp_paw_spn_digest_value!(io, read(attributes[name]))
    end
    if object isa HDF5.Dataset
        _vasp_paw_spn_digest_value!(io, "dataset")
        _vasp_paw_spn_digest_value!(io, read(object))
    else
        for name in sort!(String.(collect(keys(object))))
            _vasp_paw_spn_digest_object!(io, object[name], "$(path)/$(name)")
        end
    end
    return nothing
end

# Compute the sealed logical provenance digest from one open HDF5 root.
function _vasp_paw_spn_provenance_payload_sha256(handle)
    buffer = IOBuffer()
    _vasp_paw_spn_digest_object!(buffer, handle, "")
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Read the scalar identity-frame contract stored in native SPN provenance.
function _vasp_paw_spn_frame_contract(group)
    group_attributes = HDF5.attributes(group)
    return Dict{String, Any}(
        String(key) => read(group_attributes[key]) for key in keys(group_attributes)
    )
end

# Return the fixed Cartesian Pauli matrices used by the SPN format contract.
function _vasp_paw_cartesian_pauli_matrices()
    return (ComplexF64[0 1; 1 0], ComplexF64[0 -im; im 0], ComplexF64[1 0; 0 -1])
end

# Construct pseudo and augmentation Pauli blocks at one VASP k-point.
function _vasp_paw_spn_kpoint(
    point::PlaneWaveKPoint,
    projectors::Array{ComplexF64, 3},
    q0_augmentation::Matrix{Float64},
)
    size(point.coefficients, 3) == 2 || throw(
        ArgumentError("VASP_PAW_SPN_SPINOR_REQUIRED: WAVECAR must contain two-component spinors"),
    )
    size(projectors, 3) == 2 || throw(
        ArgumentError("VASP_PAW_SPN_SPINOR_REQUIRED: projector overlaps must have two spin blocks"),
    )
    num_bands = size(point.coefficients, 1)
    pseudo = zeros(ComplexF64, num_bands, num_bands, 3)
    augmentation = zeros(ComplexF64, num_bands, num_bands, 3)
    for (component, pauli) in enumerate(_vasp_paw_cartesian_pauli_matrices())
        for left_spin in 1:2, right_spin in 1:2
            factor = pauli[left_spin, right_spin]
            iszero(factor) && continue
            left_coefficients = @view point.coefficients[:, :, left_spin]
            right_coefficients = @view point.coefficients[:, :, right_spin]
            left_projectors = @view projectors[:, :, left_spin]
            right_projectors = @view projectors[:, :, right_spin]
            pseudo[:, :, component] .+=
                factor .* (conj(left_coefficients) * transpose(right_coefficients))
            augmentation[:, :, component] .+=
                factor .* (conj(left_projectors) * q0_augmentation * transpose(right_projectors))
        end
    end
    return pseudo, augmentation
end

# Measure reconstruction invariants without modifying the physical SPN matrices.
function _vasp_paw_spn_diagnostics(pseudo::Array{ComplexF64, 4}, augmentation::Array{ComplexF64, 4})
    total = pseudo .+ augmentation
    hermiticity = 0.0
    diagonal_imaginary = 0.0
    for kpoint in axes(total, 4), component in axes(total, 3)
        matrix = @view total[:, :, component, kpoint]
        hermiticity = max(hermiticity, maximum(abs, matrix .- matrix'; init = 0.0))
        diagonal_imaginary = max(diagonal_imaginary, maximum(abs, imag.(diag(matrix)); init = 0.0))
    end
    cancellation_condition = 0.0
    for index in eachindex(total)
        denominator = max(abs(total[index]), eps(Float64))
        cancellation_condition = max(
            cancellation_condition,
            (abs(pseudo[index]) + abs(augmentation[index])) / denominator,
        )
    end
    component_norms = Dict(
        "pseudo_max_absolute" => maximum(abs, pseudo; init = 0.0),
        "pseudo_frobenius" => norm(pseudo),
        "augmentation_max_absolute" => maximum(abs, augmentation; init = 0.0),
        "augmentation_frobenius" => norm(augmentation),
        "total_max_absolute" => maximum(abs, total; init = 0.0),
        "total_frobenius" => norm(total),
        "maximum_cancellation_condition" => cancellation_condition,
    )
    return total, hermiticity, diagonal_imaginary, component_norms
end

# Persist the complete SPN source identity and reconstruction evidence.
function _write_vasp_paw_spn_provenance(
    filename::AbstractString,
    result::VASPPAWSPNResult,
    thresholds::VASPPAWSPNThresholds,
    native::NativeWavefunctionData,
    source::VASPWavefunctionSource,
    wavecar_header::VASPWavecarHeader,
)
    HDF5.enable_complex_support()
    frame_contract = _generation_band_gauge_contract(
        source,
        NativeDFTHamiltonian(),
        nothing,
        result.spn.num_bands,
        result.spn.num_kpts,
    )
    return atomic_hdf5_write(filename) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = VASP_PAW_SPN_SCHEMA
            attributes["schema_version"] = VASP_PAW_SPN_SCHEMA_VERSION
            attributes["passed"] = result.passed
            attributes["status"] = result.passed ? "PASS" : "FAIL"
            attributes["source_code"] = "vasp"
            attributes["quantity"] = "dimensionless Cartesian Pauli matrix elements"
            attributes["spin_components"] = "x,y,z"
            attributes["band_gauge"] = NATIVE_DFT_BAND_GAUGE
            attributes["source_band_gauge"] = NATIVE_DFT_BAND_GAUGE
            attributes["target_band_gauge"] = NATIVE_DFT_BAND_GAUGE
            attributes["gauge_artifact_sha256"] = "NOT_APPLICABLE"
            attributes["band_frame_transform_sha256"] = frame_contract.transform_sha256
            attributes["band_frame_contract_sha256"] = frame_contract.contract_sha256
            attributes["band_gauge_rotation_sha256"] = frame_contract.transform_sha256
            attributes["band_gauge_rotation_semantics"] = "legacy_alias_of_band_frame_transform_sha256"
            contract_group = HDF5.create_group(handle, "band_frame_contract")
            write_band_frame_contract_attributes!(contract_group, frame_contract)
            attributes["num_bands"] = result.spn.num_bands
            attributes["num_kpoints"] = result.spn.num_kpts
            attributes["physical_metric"] = "VASP PAW q=0 pseudo plus POTCAR augmentation"
            attributes["coefficient_normalization"] = "vasp_raw"
            attributes["augmentation_metric"] = "POTCAR q0 AE-minus-PS"
            attributes["band_first"] =
                first(something(source.band_range, 1:length(native.kpoints[1].energies_ev)))
            attributes["band_last"] =
                last(something(source.band_range, 1:length(native.kpoints[1].energies_ev)))
            attributes["spin_channel"] = source.spin_channel
            attributes["full_cutoff_required"] = true
            attributes["wavecar_cutoff_ev"] = wavecar_header.cutoff_ev
            attributes["wavecar_num_bands"] = wavecar_header.num_bands
            attributes["wavecar_num_kpoints"] = wavecar_header.num_kpoints
            attributes["wavecar_spin_channels"] = wavecar_header.spin_channels
            attributes["wavecar_precision_tag"] = wavecar_header.precision_tag
            attributes["spinor"] = native.spinor
            attributes["radial_q_max_absolute"] = result.radial_q_max_absolute
            attributes["generalized_norm_max_absolute"] = result.generalized_norm_max_absolute
            attributes["hermiticity_max_absolute"] = result.hermiticity_max_absolute
            attributes["diagonal_imaginary_max_absolute"] = result.diagonal_imaginary_max_absolute
            input_group = HDF5.create_group(handle, "input_sha256")
            write_string_dictionary(input_group, result.input_sha256)
            source_group = HDF5.create_group(handle, "source_metadata")
            write_string_dictionary(source_group, native.source_metadata)
            artifact_group = HDF5.create_group(handle, "artifacts")
            write_string_dictionary(artifact_group, result.artifacts)
            threshold_group = HDF5.create_group(handle, "thresholds")
            for field in fieldnames(VASPPAWSPNThresholds)
                HDF5.attributes(threshold_group)[String(field)] = getfield(thresholds, field)
            end
            component_group = HDF5.create_group(handle, "component_norms")
            for (key, value) in result.component_norms
                HDF5.attributes(component_group)[key] = value
            end
            handle["kpoints_fractional"] =
                reduce(vcat, transpose(point.k_fractional) for point in native.kpoints)
            handle["energies_ev"] = reduce(hcat, point.energies_ev for point in native.kpoints)
            handle["real_lattice_angstrom"] = native.structure.lattice
            handle["reciprocal_lattice_inverse_angstrom"] = native.reciprocal_lattice
            handle["positions_fractional"] = native.structure.positions_fractional
            handle["species"] = native.structure.species
            handle["diagnostics"] = result.diagnostics
            if result.oracle_parity !== nothing
                parity = something(result.oracle_parity)
                oracle_group = HDF5.create_group(handle, "oracle_parity")
                oracle_attributes = HDF5.attributes(oracle_group)
                oracle_attributes["max_absolute"] = parity.max_absolute
                oracle_attributes["root_mean_square"] = parity.root_mean_square
                oracle_attributes["relative_l2"] = parity.relative_l2
                oracle_attributes["finite"] = parity.finite
                oracle_group["worst_index"] = parity.worst_index
            end
            attributes["payload_sha256"] = _vasp_paw_spn_provenance_payload_sha256(handle)
        end
    end
end

"""Read and verify one sealed VASP PAW-SPN provenance artifact."""
function read_vasp_paw_spn_provenance(filename::AbstractString; verify_spn::Bool = true)
    isfile(filename) || throw(ArgumentError("VASP PAW-SPN provenance file does not exist"))
    HDF5.enable_complex_support()
    return HDF5.h5open(filename, "r") do handle
        attributes = HDF5.attributes(handle)
        String(read(attributes["schema"])) == VASP_PAW_SPN_SCHEMA ||
            throw(ArgumentError("VASP_PAW_SPN_PROVENANCE_SCHEMA_MISMATCH"))
        schema_version = String(read(attributes["schema_version"]))
        schema_version in ("1.0", "1.1", "1.2") ||
            throw(ArgumentError("VASP_PAW_SPN_PROVENANCE_VERSION_MISMATCH"))
        # A current frame-contract marker selects the complete contract once;
        # an incomplete current file must never fall back to legacy qualification.
        modern_intent =
            haskey(handle, "band_frame_contract") ||
            any(startswith(String(key), "band_frame_") for key in keys(attributes))
        contract_version = schema_version == "1.0" && modern_intent ? "1.2" : schema_version
        if contract_version == "1.2"
            required = (
                "source_code",
                "source_band_gauge",
                "target_band_gauge",
                "band_frame_transform_sha256",
                "band_frame_contract_sha256",
                "band_gauge_rotation_sha256",
                "gauge_artifact_sha256",
                "num_bands",
                "num_kpoints",
                "physical_metric",
                "spinor",
            )
            all(haskey(attributes, key) for key in required) &&
            haskey(handle, "band_frame_contract") ||
                throw(ArgumentError("VASP_PAW_SPN_PROVENANCE_INCOMPLETE"))
        end
        stored = String(read(attributes["payload_sha256"]))
        computed = _vasp_paw_spn_provenance_payload_sha256(handle)
        stored == computed || throw(
            ArgumentError(
                "VASP_PAW_SPN_PROVENANCE_DIGEST_MISMATCH: stored logical payload digest differs",
            ),
        )
        artifacts = read_string_dictionary(handle["artifacts"])
        if verify_spn
            haskey(artifacts, "spn") && haskey(artifacts, "spn_sha256") ||
                throw(ArgumentError("VASP_PAW_SPN_PROVENANCE_ARTIFACT_MISSING"))
            isfile(artifacts["spn"]) ||
                throw(ArgumentError("VASP_PAW_SPN_OUTPUT_MISSING: $(artifacts["spn"])"))
            sha256_file(artifacts["spn"]) == artifacts["spn_sha256"] ||
                throw(ArgumentError("VASP_PAW_SPN_OUTPUT_DIGEST_MISMATCH"))
        end
        return (
            schema = VASP_PAW_SPN_SCHEMA,
            schema_version,
            source_code = Symbol(
                contract_version == "1.0" ? "vasp" : String(read(attributes["source_code"])),
            ),
            passed = Bool(read(attributes["passed"])),
            source_band_gauge = contract_version == "1.0" ? NATIVE_DFT_BAND_GAUGE :
                                String(read(attributes["source_band_gauge"])),
            target_band_gauge = contract_version == "1.0" ? NATIVE_DFT_BAND_GAUGE :
                                String(read(attributes["target_band_gauge"])),
            transform_sha256 = contract_version == "1.2" ?
                               String(read(attributes["band_frame_transform_sha256"])) :
                               contract_version == "1.1" ?
                               String(read(attributes["band_gauge_rotation_sha256"])) :
                               "LEGACY_NOT_RECORDED",
            contract_sha256 = contract_version == "1.2" ?
                              String(read(attributes["band_frame_contract_sha256"])) :
                              "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED",
            frame_contract = contract_version == "1.2" ?
                             _vasp_paw_spn_frame_contract(handle["band_frame_contract"]) :
                             Dict{String, Any}(
                "status" => "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED",
            ),
            rotation_sha256 = contract_version == "1.0" ? "LEGACY_NOT_RECORDED" :
                              String(read(attributes["band_gauge_rotation_sha256"])),
            gauge_artifact_sha256 = contract_version == "1.0" ? "LEGACY_NOT_RECORDED" :
                                    String(read(attributes["gauge_artifact_sha256"])),
            num_bands = contract_version == "1.0" ? read_wannier_spn(artifacts["spn"]).num_bands :
                        Int(read(attributes["num_bands"])),
            num_kpts = contract_version == "1.0" ? read_wannier_spn(artifacts["spn"]).num_kpts :
                       Int(read(attributes["num_kpoints"])),
            num_kpoints = contract_version == "1.0" ? read_wannier_spn(artifacts["spn"]).num_kpts :
                          Int(read(attributes["num_kpoints"])),
            physical_metric = contract_version == "1.0" ?
                              "VASP PAW q=0 pseudo plus POTCAR augmentation" :
                              String(read(attributes["physical_metric"])),
            spinor = contract_version == "1.0" ? true : Bool(read(attributes["spinor"])),
            kpoints_fractional = haskey(handle, "kpoints_fractional") ?
                                 Float64.(read(handle["kpoints_fractional"])) :
                                 zeros(Float64, 0, 3),
            payload_sha256 = stored,
            input_sha256 = read_string_dictionary(handle["input_sha256"]),
            artifacts = artifacts,
            diagnostics = String.(read(handle["diagnostics"])),
        )
    end
end

"""
    generate_vasp_paw_spn(source; output_spn_file, provenance_hdf5, spin_channel, ...)

Generate Cartesian dimensionless Pauli matrices directly from full-cutoff,
unnormalized VASP spinor coefficients. The physical matrix is the pseudo
plane-wave contraction plus the POTCAR projector/Q₀ augmentation term.
Optional SPN input is an oracle evaluated only after native construction; it
never supplies coefficients or matrix elements.
`spin_channel` is mandatory and must equal the channel recorded by `source`,
so the public generator cannot silently accept the source constructor default.
"""
function generate_vasp_paw_spn(
    source::VASPWavefunctionSource;
    output_spn_file::AbstractString,
    provenance_hdf5::AbstractString,
    spin_channel::Integer,
    oracle_spn_file::Union{Nothing, AbstractString} = nothing,
    thresholds::VASPPAWSPNThresholds = VASPPAWSPNThresholds(),
    require_oracle::Bool = false,
    formatted::Bool = false,
)
    source.potcar_file === nothing && throw(
        ArgumentError("VASP_PAW_DATA_REQUIRED: VASPWavefunctionSource.potcar_file is required"),
    )
    source.band_range === nothing &&
        throw(ArgumentError("VASP_PAW_SPN_BAND_RANGE_REQUIRED: source.band_range must be explicit"))
    spin_channel > 0 ||
        throw(ArgumentError("VASP_PAW_SPN_SPIN_CHANNEL_REQUIRED: spin_channel must be positive"))
    source.spin_channel == spin_channel || throw(
        ArgumentError(
            "VASP_PAW_SPN_SPIN_CHANNEL_MISMATCH: source records $(source.spin_channel), " *
            "generator requested $(spin_channel)",
        ),
    )
    source.representation_cutoff_ev === nothing || throw(
        ArgumentError(
            "VASP_PAW_SPN_FULL_CUTOFF_REQUIRED: representation_cutoff_ev must be nothing",
        ),
    )
    require_oracle &&
        oracle_spn_file === nothing &&
        throw(ArgumentError("VASP_PAW_SPN_ORACLE_REQUIRED: oracle_spn_file is required"))
    wavecar_header = read_vasp_wavecar_header(source.wavecar_file)
    native = read_vasp_wavefunctions(source; normalize_coefficients = false)
    native.spinor || throw(
        ArgumentError("VASP_PAW_SPN_SPINOR_REQUIRED: WAVECAR must contain two-component spinors"),
    )
    get(native.source_metadata, "coefficient_normalization", "") == "vasp_raw" ||
        throw(ArgumentError("VASP_PAW_SPN_RAW_COEFFICIENTS_REQUIRED: coefficients were normalized"))
    paw = read_vasp_paw_system(something(source.potcar_file), native.structure)
    radial_q_maximum, radial_q_worst = _paw_radial_q_gate(paw)
    projectors = _paw_projectors(native, paw)
    generalized_norm_maximum, generalized_norm_worst =
        _paw_generalized_norm_residuals(native, paw, projectors)
    num_bands = size(first(native.kpoints).coefficients, 1)
    pseudo = zeros(ComplexF64, num_bands, num_bands, 3, length(native.kpoints))
    augmentation = zeros(ComplexF64, size(pseudo))
    for kpoint in eachindex(native.kpoints)
        pseudo_block, augmentation_block =
            _vasp_paw_spn_kpoint(native.kpoints[kpoint], projectors[kpoint], paw.q0_augmentation)
        pseudo[:, :, :, kpoint] .= pseudo_block
        augmentation[:, :, :, kpoint] .= augmentation_block
    end
    all(isfinite, pseudo) && all(isfinite, augmentation) || throw(
        ArgumentError("VASP_PAW_SPN_NONFINITE: pseudo or augmentation contribution is non-finite"),
    )
    total, hermiticity, diagonal_imaginary, component_norms =
        _vasp_paw_spn_diagnostics(pseudo, augmentation)
    spn = WannierSPN(num_bands, length(native.kpoints), total)
    output_path = write_wannier_spn(
        output_spn_file,
        spn;
        formatted,
        comment = "Generated by WannierNLQG VASP PAW-SPN",
    )
    oracle =
        oracle_spn_file === nothing ? nothing :
        read_wannier_spn(something(oracle_spn_file); formatted)
    oracle === nothing ||
        size(oracle.data) == size(spn.data) ||
        throw(ArgumentError("VASP_PAW_SPN_ORACLE_MISMATCH: SPN dimensions differ"))
    oracle_parity = oracle === nothing ? nothing : _paw_array_parity(spn.data, oracle.data)
    radial_pass = radial_q_maximum <= thresholds.radial_q_max_absolute
    norm_pass = generalized_norm_maximum <= thresholds.generalized_norm_max_absolute
    hermiticity_pass = hermiticity <= thresholds.hermiticity_max_absolute
    diagonal_pass = diagonal_imaginary <= thresholds.diagonal_imaginary_max_absolute
    oracle_pass =
        oracle_parity !== nothing && _paw_metric_passes(
            something(oracle_parity),
            thresholds.oracle_max_absolute,
            thresholds.oracle_rms,
            thresholds.oracle_relative_l2,
        )
    passed =
        radial_pass &&
        norm_pass &&
        hermiticity_pass &&
        diagonal_pass &&
        (!require_oracle || oracle_pass) &&
        (oracle_parity === nothing || oracle_pass)
    oracle_status = oracle_parity === nothing ? "NOT_PROVIDED" : oracle_pass ? "PASS" : "FAIL"
    diagnostics = String[
        "radial_q_worst=$(radial_q_worst)",
        "generalized_norm_worst=$(generalized_norm_worst)",
        "oracle_status=$(oracle_status)",
    ]
    input_sha256 = copy(native.input_sha256)
    input_sha256["POTCAR"] = sha256_file(something(source.potcar_file))
    if get(input_sha256, "INCAR", "") == "EXPLICIT_SPIN_BASIS"
        delete!(input_sha256, "INCAR")
        input_sha256["SPIN_BASIS_CONTRACT"] =
            bytes2hex(SHA.sha256(codeunits(get(native.source_metadata, "saxis", "not_applicable"))))
    end
    artifacts = Dict(
        "spn" => abspath(output_path),
        "spn_sha256" => sha256_file(output_path),
        "provenance_hdf5" => abspath(provenance_hdf5),
    )
    oracle_spn_file === nothing || (
        artifacts["oracle_spn"] = abspath(something(oracle_spn_file));
        artifacts["oracle_spn_sha256"] = sha256_file(something(oracle_spn_file))
    )
    result = VASPPAWSPNResult(
        spn,
        oracle_parity,
        radial_q_maximum,
        generalized_norm_maximum,
        hermiticity,
        diagonal_imaginary,
        passed,
        diagnostics,
        component_norms,
        artifacts,
        input_sha256,
    )
    _write_vasp_paw_spn_provenance(
        provenance_hdf5,
        result,
        thresholds,
        native,
        source,
        wavecar_header,
    )
    return result
end
