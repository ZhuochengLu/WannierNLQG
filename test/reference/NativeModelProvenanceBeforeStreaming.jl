"""Check a native import's observed source lifetime without reading its bytes again.

The parsed payload is separately owned. A local file observation is descriptive,
not a byte equality or authenticity claim. Legacy importer checksum bindings are
not accepted by this source-lifetime contract.
"""
function native_source_file_identity(input::AbstractNativeModelInput)
    parameters = input.parameters
    legacy =
        parameters isa NamedTuple ? haskey(parameters, :file_sha256) :
        parameters isa AbstractDict &&
        (haskey(parameters, "file_sha256") || haskey(parameters, :file_sha256))
    legacy && throw(ArgumentError("NATIVE_SOURCE_LEGACY_CHECKSUM_BINDING_UNSUPPORTED"))
    filename = input.source_file
    isempty(filename) && return nothing
    identity = scientific_file_identity(filename)
    recorded = if parameters isa NamedTuple && haskey(parameters, :file_identity)
        parameters.file_identity
    elseif parameters isa AbstractDict && haskey(parameters, "file_identity")
        parameters["file_identity"]
    else
        nothing
    end
    recorded === nothing ||
        isequal(recorded, identity) ||
        throw(ArgumentError("NATIVE_SOURCE_FILE_IDENTITY_MISMATCH: source changed after import"))
    return identity
end

"""Hash declared native model data and a observed source-file identity; never serialize executable callbacks."""
function native_model_digest(input::AbstractNativeModelInput)
    scientific_data_generation(input)
    source_identity = native_source_file_identity(input)
    buffer=IOBuffer()
    print(buffer, "wanniernlqg-native-model-v2\n", typeof(input).name.name, "\n")
    if input isa RealSpaceTBInput
        model=input.model
        for value in (model.lattice, model.r_vectors, model.hamiltonian_r, model.position_r)
            print(buffer, size(value), ':');
            write(buffer, reinterpret(UInt8, vec(value)))
        end
        print(buffer, input.position_model)
    elseif input isa AnalyticKInput
        isempty(input.source_file) &&
            throw(ArgumentError("AnalyticKInput requires source_file for reproducibility"))
        for value in (input.lattice, input.orbital_positions)
            if value === nothing
                print(buffer, "orbital_positions_absent_fixed_basis\n")
                continue
            end
            print(buffer, size(value), ':');
            write(buffer, reinterpret(UInt8, vec(value)))
        end
        print(
            buffer,
            input.num_orbitals,
            input.periodic,
            input.basis,
            input.derivative_method,
            input.finite_difference_step,
            input.evaluation_bounds,
        )
    else
        throw(ArgumentError("unsupported native model input backend"))
    end
    native_digest_value(buffer, input.parameters)
    native_digest_value(buffer, input.operators)
    if input isa AnalyticKInput
        native_digest_value(buffer, input.hamiltonian)
        native_digest_value(buffer, input.derivatives)
    end
    print(buffer, input.wannier_center_convention)
    if !isempty(input.source_file)
        isfile(input.source_file) || throw(ArgumentError("native model source_file does not exist"))
        print(buffer, "\nsource_file_identity:", source_identity, "\n")
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Bind all localized H/S/r bytes, metric thresholds, parameters and importer source-file observation."""
function native_model_digest(input::NonorthogonalLocalizedInput)
    scientific_data_generation(input)
    source_identity = native_source_file_identity(input)
    buffer = IOBuffer()
    print(buffer, "wanniernlqg-nonorthogonal-localized-effective-spin-convention-v3\n")
    model = input.model
    for value in (
        model.lattice,
        model.r_vectors,
        model.hamiltonian_r,
        model.overlap_r,
        model.position_r,
        model.raw_hamiltonian_r,
        model.raw_overlap_r,
        model.raw_position_r,
    )
        if value === nothing
            print(buffer, "position_operator_absent\n")
            continue
        end
        print(buffer, size(value), ':')
        write(buffer, reinterpret(UInt8, vec(value)))
    end
    native_digest_value(
        buffer,
        (
            model.representation_diagnostics,
            model.metric_relative_floor,
            model.hamiltonian_representation_tolerance_ev,
            model.overlap_representation_tolerance,
            model.position_translation_tolerance_angstrom,
            model.spin_representation,
            model.magnetic_state,
            model.spin_orbit_coupling,
            model.spin_ordering,
            model.num_spatial_orbitals,
            model.orbital_centers_cartesian,
            input.parameters,
            input.wannier_center_convention,
        ),
    )
    if !isempty(input.source_file)
        isfile(input.source_file) || throw(ArgumentError("native model source_file does not exist"))
        print(buffer, "\nsource_file_identity:", source_identity, "\n")
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Hash complete parameter and closure data without executing or serializing callbacks."""
function native_digest_value(buffer, value)
    return _native_digest_value(buffer, value, Dict{DataType, String}())
end

# Type display scans module aliases. Cache identical prefixes only within this
# synchronous traversal; the byte stream and model identity remain unchanged.
function _native_digest_value(buffer, value, type_prefixes::Dict{DataType, String})
    prefix = get!(type_prefixes, typeof(value)) do
        string(typeof(value), ':')
    end
    print(buffer, prefix)
    if value isa AbstractArray
        print(buffer, size(value), ':')
        for element in value
            _native_digest_value(buffer, element, type_prefixes)
        end
    elseif value isa Union{Tuple, NamedTuple}
        for element in value
            _native_digest_value(buffer, element, type_prefixes)
        end
    elseif value isa AbstractDict
        for key in sort!(collect(keys(value)); by = repr)
            _native_digest_value(buffer, key, type_prefixes)
            _native_digest_value(buffer, value[key], type_prefixes)
        end
    elseif value isa Function
        for field in fieldnames(typeof(value))
            _native_digest_value(buffer, getfield(value, field), type_prefixes)
        end
    elseif value isa Union{Number, AbstractString, Symbol, Nothing, Bool}
        print(buffer, repr(value), ';')
    else
        throw(
            ArgumentError(
                "native parameters must be reproducible numeric/string arrays, tuples or dictionaries; unsupported $(typeof(value))",
            ),
        )
    end
    return nothing
end

"""Describe large caller payload arrays without duplicating their scientific data.

The existing native model digest binds complete values and the source file.
Small scalar controls and input identities remain readable; large arrays record
shape/type/count only. This summary does not qualify an operator or material.
"""
function native_parameters_metadata(value)
    if value isa AbstractArray
        length(value) <= 32 && return value
        return (
            storage = "array",
            element_type = string(eltype(value)),
            shape = size(value),
            element_count = length(value),
            values_bound_by = "native model_sha256",
        )
    elseif value isa NamedTuple
        return NamedTuple{keys(value)}(
            Tuple(native_parameters_metadata(item) for item in values(value)),
        )
    elseif value isa Tuple
        return map(native_parameters_metadata, value)
    elseif value isa AbstractDict
        return Dict(key => native_parameters_metadata(item) for (key, item) in value)
    end
    return value
end
