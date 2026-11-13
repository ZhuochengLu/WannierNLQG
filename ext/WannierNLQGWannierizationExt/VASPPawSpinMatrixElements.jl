const VASP_PAW_SPN_SCHEMA = "wanniernlqg.vasp-paw-spn"
const VASP_PAW_SPN_SCHEMA_VERSION = "2.0"

"""Compare complete qualification-mask values using the shared definition contract."""
_operator_qualification_mask_definition(mask::AbstractMatrix{Bool}) =
    qualification_mask_definition(mask)

"""Compare SPN tensors on the ragged outer-window band block only."""
function _vasp_paw_spn_scoped_parity(generated, oracle, outer_mask)
    size(generated) == size(oracle) ||
        throw(ArgumentError("VASP_PAW_SPN_ORACLE_MISMATCH: SPN dimensions differ"))
    size(outer_mask) == (size(generated, 1), size(generated, 4)) ||
        throw(ArgumentError("VASP_PAW_SPN_SCOPE_DIMENSION_MISMATCH"))
    maximum_value = -Inf
    worst_index = Int[]
    sum_squared = 0.0
    oracle_sum_squared = 0.0
    count = 0
    finite = true
    for kpoint in axes(generated, 4)
        selected = findall(@view outer_mask[:, kpoint])
        isempty(selected) && throw(ArgumentError("VASP_PAW_SPN_EMPTY_TARGET_SCOPE"))
        for component in axes(generated, 3), right in selected, left in selected
            index = CartesianIndex(left, right, component, kpoint)
            difference = generated[index] - oracle[index]
            absolute = abs(difference)
            finite &= isfinite(absolute)
            sum_squared += abs2(difference)
            oracle_sum_squared += abs2(oracle[index])
            count += 1
            if absolute > maximum_value
                maximum_value = absolute
                worst_index = collect(Tuple(index))
            end
        end
    end
    return VASPPAWArrayParityMetrics(
        maximum_value,
        sqrt(sum_squared / count),
        sqrt(sum_squared / max(oracle_sum_squared, eps(Float64))),
        worst_index,
        finite,
    )
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
    wavecar_header::VASPWavecarHeader;
    qualification_scope = nothing,
    parent_generalized_norm_max_absolute::Real = result.generalized_norm_max_absolute,
    parent_generalized_norm_worst = (0, 0, 0),
    target_generalized_norm_worst = (0, 0, 0),
    target_contract_sha256::AbstractString = "LEGACY_NOT_RECORDED",
    require_oracle::Bool = false,
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
            attributes["require_oracle"] = require_oracle
            attributes["source_code"] = "vasp"
            attributes["quantity"] = "dimensionless Cartesian Pauli matrix elements"
            attributes["spin_components"] = "x,y,z"
            attributes["band_gauge"] = NATIVE_DFT_BAND_GAUGE
            attributes["source_band_gauge"] = NATIVE_DFT_BAND_GAUGE
            attributes["target_band_gauge"] = NATIVE_DFT_BAND_GAUGE
            attributes["gauge_definition"] = "NOT_APPLICABLE"
            attributes["band_frame_transform_definition"] = frame_contract.transform_definition
            attributes["band_frame_contract_definition"] = frame_contract.contract_definition
            contract_group = HDF5.create_group(handle, "band_frame_contract")
            write_band_frame_contract_attributes!(contract_group, frame_contract)
            attributes["num_bands"] = result.spn.num_bands
            attributes["num_kpoints"] = result.spn.num_kpts
            attributes["physical_metric"] = "VASP PAW q=0 pseudo plus POTCAR augmentation"
            attributes["coefficient_normalization"] = "vasp_raw"
            attributes["augmentation_metric"] = "POTCAR q0 AE-minus-PS"
            attributes["band_first"] = first(
                something(
                    source.band_range,
                    1:length(native_point_metadata(native, 1).energies_ev),
                ),
            )
            attributes["band_last"] = last(
                something(
                    source.band_range,
                    1:length(native_point_metadata(native, 1).energies_ev),
                ),
            )
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
            attributes["target_generalized_norm_max_absolute"] =
                result.generalized_norm_max_absolute
            attributes["parent_generalized_norm_max_absolute"] =
                Float64(parent_generalized_norm_max_absolute)
            attributes["parent_audit_status"] =
                parent_generalized_norm_max_absolute <= thresholds.generalized_norm_max_absolute ?
                "PASS" : "AUDIT_EXCEEDED"
            attributes["target_authority"] =
                qualification_scope === nothing ? "full_parent" : "outer_window"
            attributes["parent_audit_policy"] =
                qualification_scope === nothing ? "legacy_hard_gate" : "audit_only"
            attributes["operator_target_contract_sha256"] = String(target_contract_sha256)
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
            handle["kpoints_fractional"] = reduce(
                vcat,
                transpose(native_point_metadata(native, k).k_fractional) for
                k in eachindex(native.kpoints)
            )
            handle["energies_ev"] = reduce(
                hcat,
                native_point_metadata(native, k).energies_ev for k in eachindex(native.kpoints)
            )
            handle["real_lattice_angstrom"] = native.structure.lattice
            handle["reciprocal_lattice_inverse_angstrom"] = native.reciprocal_lattice
            handle["positions_fractional"] = native.structure.positions_fractional
            handle["species"] = native.structure.species
            handle["diagnostics"] = result.diagnostics
            handle["target_generalized_norm_worst"] = collect(target_generalized_norm_worst)
            handle["parent_generalized_norm_worst"] = collect(parent_generalized_norm_worst)
            if qualification_scope !== nothing
                scope_group = HDF5.create_group(handle, "qualification_scope")
                scope_attributes = HDF5.attributes(scope_group)
                scope_attributes["outer_mask_definition"] =
                    qualification_scope.outer_mask_definition
                scope_attributes["frozen_mask_definition"] =
                    qualification_scope.frozen_mask_definition
                scope_attributes["diagnostic_status"] =
                    String(qualification_scope.diagnostic_status)
                scope_group["outer_mask"] = UInt8.(qualification_scope.outer_mask)
                scope_group["frozen_mask"] = UInt8.(qualification_scope.frozen_mask)
            end
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
            _write_spn_complete_references(handle, native, result.artifacts)
        end
    end
end

"""Read a fixed string with a byte buffer, avoiding a gigantic tuple datatype."""
function _read_vasp_spn_attribute(attributes, key)
    attribute = attributes[key]
    datatype = HDF5.datatype(attribute)
    try
        width = HDF5.API.h5t_get_size(datatype.id)
        if width > 1_000_000
            size(attribute) == () &&
            HDF5.API.h5t_get_class(datatype.id) == HDF5.API.H5T_STRING &&
            !HDF5.API.h5t_is_variable_str(datatype.id) ||
                throw(ArgumentError("VASP_PAW_SPN_LARGE_ATTRIBUTE_TYPE_INVALID"))
            width <= 2_147_483_648 ||
                throw(ArgumentError("VASP_PAW_SPN_ATTRIBUTE_EXCEEDS_RESOURCE_BOUND"))
            bytes = Vector{UInt8}(undef, Int(width))
            GC.@preserve bytes HDF5.API.h5a_read(attribute.id, datatype.id, pointer(bytes))
            while !isempty(bytes) && bytes[end] == 0x00
                pop!(bytes)
            end
            return String(bytes)
        end
        return read(attribute)
    finally
        close(datatype)
        close(attribute)
    end
end

"""Read HDF5 attributes without specializing a dictionary on every value type."""
function _read_vasp_spn_attributes(attributes)
    values = Dict{String, Any}()
    for key in keys(attributes)
        values[String(key)] = _read_vasp_spn_attribute(attributes, key)
    end
    return values
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
        schema_version == VASP_PAW_SPN_SCHEMA_VERSION ||
            throw(ArgumentError("VASP_PAW_SPN_PROVENANCE_VERSION_MISMATCH"))
        any(
            haskey(attributes, key) for
            key in ("band_gauge_rotation_sha256", "band_gauge_rotation_semantics")
        ) && throw(ArgumentError("VASP_PAW_SPN_LEGACY_ROTATION_FIELDS_REQUIRE_MIGRATION"))
        required = (
            "source_code",
            "source_band_gauge",
            "target_band_gauge",
            "band_frame_transform_definition",
            "band_frame_contract_definition",
            "gauge_definition",
            "num_bands",
            "num_kpoints",
            "physical_metric",
            "spinor",
        )
        all(haskey(attributes, key) for key in required) && haskey(handle, "band_frame_contract") ||
            throw(ArgumentError("VASP_PAW_SPN_PROVENANCE_INCOMPLETE"))
        haskey(attributes, "require_oracle") && haskey(handle, "thresholds") ||
            throw(ArgumentError("SPN_RESIDUAL_CONTRACT_MIGRATION_REQUIRED"))
        values = _read_vasp_spn_attributes(attributes)
        limits_attributes = HDF5.attributes(handle["thresholds"])
        limits = _read_vasp_spn_attributes(limits_attributes)
        oracle = if haskey(handle, "oracle_parity")
            a = HDF5.attributes(handle["oracle_parity"])
            _read_vasp_spn_attributes(a)
        else
            nothing
        end
        values["require_oracle"] isa Bool || throw(ArgumentError("SPN_ORACLE_POLICY_INVALID"))
        _validate_spn_residual_data(values, limits, oracle, values["require_oracle"]; radial = true)
        references=_read_spn_complete_references(handle)
        artifacts=read_string_dictionary(handle["artifacts"])
        if verify_spn
            haskey(artifacts, "spn") || throw(ArgumentError("VASP_PAW_SPN_OUTPUT_MISSING"))
            _validate_spn_reference(references, artifacts["spn"])
        end
        return (
            schema = VASP_PAW_SPN_SCHEMA,
            schema_version,
            source_code = Symbol(String(read(attributes["source_code"]))),
            source_band_gauge = String(read(attributes["source_band_gauge"])),
            target_band_gauge = String(read(attributes["target_band_gauge"])),
            transform_definition = String(values["band_frame_transform_definition"]),
            contract_definition = String(values["band_frame_contract_definition"]),
            frame_contract = _vasp_paw_spn_frame_contract(handle["band_frame_contract"]),
            gauge_definition = String(read(attributes["gauge_definition"])),
            num_bands = Int(read(attributes["num_bands"])),
            num_kpts = Int(read(attributes["num_kpoints"])),
            num_kpoints = Int(read(attributes["num_kpoints"])),
            physical_metric = String(read(attributes["physical_metric"])),
            target_authority = haskey(attributes, "target_authority") ?
                               String(read(attributes["target_authority"])) : "full_parent",
            parent_audit_policy = haskey(attributes, "parent_audit_policy") ?
                                  String(read(attributes["parent_audit_policy"])) :
                                  "legacy_hard_gate",
            parent_audit_status = haskey(attributes, "parent_audit_status") ?
                                  String(read(attributes["parent_audit_status"])) :
                                  "LEGACY_NOT_RECORDED",
            target_generalized_norm_max_absolute = haskey(
                attributes,
                "target_generalized_norm_max_absolute",
            ) ? Float64(
                read(attributes["target_generalized_norm_max_absolute"]),
            ) :
                                                   haskey(
                attributes,
                "generalized_norm_max_absolute",
            ) ? Float64(
                read(attributes["generalized_norm_max_absolute"]),
            ) : NaN,
            parent_generalized_norm_max_absolute = haskey(
                attributes,
                "parent_generalized_norm_max_absolute",
            ) ? Float64(
                read(attributes["parent_generalized_norm_max_absolute"]),
            ) :
                                                   haskey(
                attributes,
                "generalized_norm_max_absolute",
            ) ? Float64(
                read(attributes["generalized_norm_max_absolute"]),
            ) : NaN,
            operator_target_contract_sha256 = haskey(
                attributes,
                "operator_target_contract_sha256",
            ) ? String(values["operator_target_contract_sha256"]) : "LEGACY_NOT_RECORDED",
            qualification_scope = haskey(handle, "qualification_scope") ?
                                  (
                outer_mask = BitMatrix(Bool.(read(handle["qualification_scope/outer_mask"]))),
                frozen_mask = BitMatrix(Bool.(read(handle["qualification_scope/frozen_mask"]))),
                outer_mask_definition = String(
                    read(HDF5.attributes(handle["qualification_scope"])["outer_mask_definition"]),
                ),
                frozen_mask_definition = String(
                    read(HDF5.attributes(handle["qualification_scope"])["frozen_mask_definition"]),
                ),
            ) : nothing,
            spinor = Bool(read(attributes["spinor"])),
            kpoints_fractional = haskey(handle, "kpoints_fractional") ?
                                 Float64.(read(handle["kpoints_fractional"])) :
                                 zeros(Float64, 0, 3),
            content_authentication = "NOT_PERFORMED",
            source_reference = references.source_reference,
            spn_reference = references.spn_reference,
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
    execution = nothing,
    target_contract = nothing,
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
    _validate_generation_output_paths(
        (; output = output_spn_file, provenance = provenance_hdf5),
        (oracle_spn_file,),
        source,
    )
    paths = (output = abspath(output_spn_file), provenance = abspath(provenance_hdf5))
    inputs = oracle_spn_file === nothing ? String[] : [String(oracle_spn_file)]
    config = (;
        source,
        spin_channel,
        oracle_spn_file,
        thresholds,
        require_oracle,
        formatted,
        target_contract,
    )
    return _with_spn_publication_receipt(config, paths, inputs; execution) do block_execution
        return _with_vasp_operator_artifacts(
            source,
            dirname(abspath(output_spn_file));
            execution,
            additional_inputs = oracle_spn_file === nothing ? String[] : [String(oracle_spn_file)],
        ) do
            _generate_vasp_paw_spn_prepared(
                source;
                output_spn_file,
                provenance_hdf5,
                spin_channel,
                oracle_spn_file,
                thresholds,
                require_oracle,
                formatted,
                target_contract,
                execution = block_execution,
            )
        end
    end
end

"""Compute missing VASP spin blocks with private worker temporaries and ordered commits."""
function _vasp_spn_blocks!(pseudo, augmentation, load, contract; execution = nothing)
    size(pseudo) == size(augmentation) || throw(ArgumentError("VASP_SPN_BLOCK_DIMENSION_MISMATCH"))
    expected = size(pseudo)[1:3]
    consume = function (k, result)
        left, right = result
        size(left) == expected && size(right) == expected ||
            throw(ArgumentError("VASP_SPN_BLOCK_DIMENSION_MISMATCH"))
        all(isfinite, left) && all(isfinite, right) ||
            throw(ArgumentError("VASP_PAW_SPN_NONFINITE"))
        pseudo[:, :, :, k] .= left
        augmentation[:, :, :, k] .= right
    end
    task_local_storage(:wannier_preparation_execution, execution) do
        foreach_preparation_block(
            (_, input) -> _vasp_paw_spn_kpoint(input...),
            load,
            consume,
            size(pseudo, 4);
            contract,
            label = "vasp-spn",
            input_values = execution !== nothing && execution.resume ?
                           input -> (input[1].coefficients, input[2], input[3]) : nothing,
            reuse_completed_blocks = execution !== nothing && execution.resume,
        )
    end
    return nothing
end

"""Run the original VASP spin calculation inside its input-bound preparation scope."""
function _generate_vasp_paw_spn_prepared(
    source::VASPWavefunctionSource;
    output_spn_file::AbstractString,
    provenance_hdf5::AbstractString,
    spin_channel::Integer,
    oracle_spn_file::Union{Nothing, AbstractString} = nothing,
    thresholds::VASPPAWSPNThresholds = VASPPAWSPNThresholds(),
    require_oracle::Bool = false,
    formatted::Bool = false,
    target_contract = nothing,
    execution = nothing,
)
    wavecar_header = read_vasp_wavecar_header(source.wavecar_file)
    native = read_vasp_wavefunctions(
        source;
        content_authentication = false,
        point_provider = native_vasp_point_provider,
        normalize_coefficients = false,
    )
    native.spinor || throw(
        ArgumentError("VASP_PAW_SPN_SPINOR_REQUIRED: WAVECAR must contain two-component spinors"),
    )
    get(native.source_metadata, "coefficient_normalization", "") == "vasp_raw" ||
        throw(ArgumentError("VASP_PAW_SPN_RAW_COEFFICIENTS_REQUIRED: coefficients were normalized"))
    prepared = _vasp_operator_paw_context(source, native)
    (; paw, radial_q_maximum, radial_q_worst, projectors, generalized_norm_worst) = prepared
    num_bands = native_point_metadata(native, 1).num_bands
    qualification_scope =
        target_contract === nothing ? nothing : target_contract.qualification_scope
    if qualification_scope !== nothing
        target_contract.target_authority == "outer_window" ||
            throw(ArgumentError("VASP_PAW_SPN_TARGET_AUTHORITY_MISMATCH"))
        target_contract.parent_audit_policy == "audit_only" ||
            throw(ArgumentError("VASP_PAW_SPN_PARENT_AUDIT_POLICY_MISMATCH"))
        size(qualification_scope.outer_mask) == (num_bands, length(native.kpoints)) ||
            throw(ArgumentError("VASP_PAW_SPN_SCOPE_DIMENSION_MISMATCH"))
        _operator_qualification_mask_definition(qualification_scope.outer_mask) ==
        qualification_scope.outer_mask_definition ||
            throw(ArgumentError("VASP_PAW_SPN_OUTER_MASK_DIGEST_MISMATCH"))
        _operator_qualification_mask_definition(qualification_scope.frozen_mask) ==
        qualification_scope.frozen_mask_definition ||
            throw(ArgumentError("VASP_PAW_SPN_FROZEN_MASK_DIGEST_MISMATCH"))
    end
    target_norm, parent_norm = if qualification_scope === nothing
        legacy = (prepared.generalized_norm, prepared.generalized_norm_worst)
        (legacy, legacy)
    else
        _paw_generalized_norm_scopes(native, paw, projectors, (qualification_scope.outer_mask, nothing))
    end
    generalized_norm_maximum, target_generalized_norm_worst = target_norm
    parent_generalized_norm_maximum, parent_generalized_norm_worst = parent_norm
    pseudo = zeros(ComplexF64, num_bands, num_bands, 3, length(native.kpoints))
    augmentation = zeros(ComplexF64, size(pseudo))
    binding = "vasp-spn-values-v1"
    context = get(task_local_storage(), :wannier_preparation_artifact_cache, nothing)
    selected =
        execution === nothing ? get(task_local_storage(), :wannier_preparation_execution, nothing) :
        execution
    checkpoint_root =
        selected === nothing ? (context === nothing ? nothing : context.directory) :
        selected.checkpoint_directory
    block_execution = (
        mode = selected === nothing ? :streaming_serial : selected.mode,
        max_workers = selected === nothing ? 1 : selected.max_workers,
        memory_budget_bytes = selected === nothing ? 24 * 1024^3 : selected.memory_budget_bytes,
        checkpoint_directory = checkpoint_root === nothing ||
                               (selected !== nothing && selected.mode == :dense_reference) ?
                               nothing : joinpath(checkpoint_root, "spin-blocks", binding),
        resume = selected === nothing ? true : selected.resume,
    )
    _vasp_spn_blocks!(
        pseudo,
        augmentation,
        k -> (native.kpoints[k], projectors[k], paw.q0_augmentation),
        binding;
        execution = block_execution,
    )
    all(isfinite, pseudo) && all(isfinite, augmentation) || throw(
        ArgumentError("VASP_PAW_SPN_NONFINITE: pseudo or augmentation contribution is non-finite"),
    )
    _record_spn_publication_blocks(
        :vasp,
        block_execution,
        "vasp-spn",
        binding,
        length(native.kpoints),
    )
    total, hermiticity, diagonal_imaginary, component_norms =
        _vasp_paw_spn_diagnostics(pseudo, augmentation)
    spn = WannierSPN(num_bands, length(native.kpoints), total)
    oracle =
        oracle_spn_file === nothing ? nothing :
        read_wannier_spn(something(oracle_spn_file); formatted)
    oracle === nothing ||
        size(oracle.data) == size(spn.data) ||
        throw(ArgumentError("VASP_PAW_SPN_ORACLE_MISMATCH: SPN dimensions differ"))
    oracle_parity =
        oracle === nothing ? nothing :
        qualification_scope === nothing ? _paw_array_parity(spn.data, oracle.data) :
        _vasp_paw_spn_scoped_parity(spn.data, oracle.data, qualification_scope.outer_mask)
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
    parent_audit_status =
        parent_generalized_norm_maximum <= thresholds.generalized_norm_max_absolute ? "PASS" :
        "AUDIT_EXCEEDED"
    diagnostics = String[
        "radial_q_worst=$(radial_q_worst)",
        "target_generalized_norm_worst=$(target_generalized_norm_worst)",
        "parent_generalized_norm_worst=$(parent_generalized_norm_worst)",
        "parent_generalized_norm_max_absolute=$(parent_generalized_norm_maximum)",
        "parent_audit_status=$(parent_audit_status)",
        "oracle_status=$(oracle_status)",
    ]
    input_sha256 = _vasp_operator_input_sha256(source, native)
    target_contract === nothing ||
        (input_sha256["OPERATOR_TARGET_CONTRACT"] = target_contract.definition)
    artifacts = Dict("provenance_hdf5" => abspath(provenance_hdf5))
    # Preserve the legacy diagnostic writer when no target contract exists.
    # A target-scoped request is fail-closed and never publishes an SPN payload.
    if passed || target_contract === nothing
        output_path = write_wannier_spn(
            output_spn_file,
            spn;
            formatted,
            comment = "Generated by WannierNLQG VASP PAW-SPN",
        )
        artifacts["spn"] = abspath(output_path)
    else
        isfile(output_spn_file) && rm(output_spn_file; force = true)
    end
    oracle_spn_file === nothing ||
        (artifacts["oracle_spn"] = abspath(something(oracle_spn_file)); nothing)
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
        qualification_scope = qualification_scope,
        require_oracle = require_oracle,
        parent_generalized_norm_max_absolute = parent_generalized_norm_maximum,
        parent_generalized_norm_worst = parent_generalized_norm_worst,
        target_generalized_norm_worst = target_generalized_norm_worst,
        target_contract_sha256 = target_contract === nothing ? "LEGACY_NOT_RECORDED" :
                                 target_contract.definition,
    )
    return result
end
