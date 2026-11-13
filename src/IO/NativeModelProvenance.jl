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

"""Write the complete native definition to a sequential stream without executing callbacks.

The producer is shared by exact cross-rank comparison and persistent model binding.
Numerical array bytes, parameter ordering and callback capture values retain their
existing representation. Source lifetime and live ownership are checked first.
"""
function write_native_model_definition(
    buffer::Base.IO,
    input::AbstractNativeModelInput;
    definition_version::Int = 2,
)
    _validate_native_definition_version(definition_version)
    scientific_data_generation(input)
    source_identity = native_source_file_identity(input)
    print(
        buffer,
        native_physical_dimension(input) < 3 ? "wanniernlqg-native-axis-aligned-lowD-v1\n" :
        definition_version == 1 ? "wanniernlqg-native-model-v2\n" :
        "wanniernlqg-native-model-v3-stable-types\n",
        typeof(input).name.name,
        "\n",
    )
    if native_physical_dimension(input) < 3
        print(
            buffer,
            "physical_dimension=",
            native_physical_dimension(input),
            ";auxiliary_length_angstrom=1.0;physical_axes=leading;no_auxiliary_periodicity\n",
        )
    end
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
                print(
                    buffer,
                    input.basis == :explicit ? "orbital_positions_absent_explicit_connection\n" :
                    "orbital_positions_absent_fixed_basis\n",
                )
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
    write_native_definition_value(buffer, input.parameters; definition_version)
    write_native_definition_value(buffer, input.operators; definition_version)
    if input isa AnalyticKInput
        write_native_definition_value(buffer, input.hamiltonian; definition_version)
        write_native_definition_value(buffer, input.derivatives; definition_version)
    end
    print(buffer, input.wannier_center_convention)
    if !isempty(input.source_file)
        isfile(input.source_file) || throw(ArgumentError("native model source_file does not exist"))
        print(buffer, "\nsource_file_identity:", source_identity, "\n")
    end
    return nothing
end

"""Write localized raw/effective H/S/r, metric controls and source observation exactly."""
function write_native_model_definition(
    buffer::Base.IO,
    input::NonorthogonalLocalizedInput;
    definition_version::Int = 2,
)
    _validate_native_definition_version(definition_version)
    scientific_data_generation(input)
    source_identity = native_source_file_identity(input)
    print(
        buffer,
        definition_version == 1 ?
        "wanniernlqg-nonorthogonal-localized-effective-spin-convention-v3\n" :
        "wanniernlqg-nonorthogonal-localized-effective-spin-convention-v4-stable-types\n",
    )
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
    write_native_definition_value(
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
        );
        definition_version,
    )
    if !isempty(input.source_file)
        isfile(input.source_file) || throw(ArgumentError("native model source_file does not exist"))
        print(buffer, "\nsource_file_identity:", source_identity, "\n")
    end
    return nothing
end

# Native model definition versions are explicit; generic frame/mask callers retain v1.
function _validate_native_definition_version(version::Int)
    version in (1, 2) || throw(ArgumentError("unsupported native definition encoding version"))
    return version
end

# Write a length-delimited identifier atom, never Julia's contextual display of a type.
function _native_type_atom(io, value::Symbol)
    bytes = codeunits(String(value))
    print(io, length(bytes), ':')
    write(io, bytes)
end

# This private codec handles only the structural type parameters of supported native
# values. It is not an object serializer: callbacks are not executed, and arbitrary
# values remain rejected by the existing value walker below.
function _write_native_type_parameter(io, parameter, bound::IdDict{TypeVar, Int})
    if parameter === Union{}
        print(io, "B;")
    elseif parameter isa DataType
        print(io, 'D')
        parts = fullname(parameter.name.module)
        print(io, length(parts), ':')
        for part in parts
            _native_type_atom(io, part)
        end
        _native_type_atom(io, parameter.name.name)
        print(io, length(parameter.parameters), ':')
        for item in parameter.parameters
            _write_native_type_parameter(io, item, bound)
        end
    elseif parameter isa UnionAll
        variable = parameter.var
        previous = get(bound, variable, nothing)
        index = isempty(bound) ? 1 : maximum(values(bound)) + 1
        bound[variable] = index
        try
            print(io, "U", index, ':')
            _write_native_type_parameter(io, variable.lb, bound)
            _write_native_type_parameter(io, variable.ub, bound)
            _write_native_type_parameter(io, parameter.body, bound)
        finally
            previous === nothing ? delete!(bound, variable) : (bound[variable] = previous)
        end
    elseif parameter isa TypeVar
        haskey(bound, parameter) || throw(ArgumentError("unbound native definition type variable"))
        print(io, "R", bound[parameter], ';')
    elseif parameter isa Union
        members = [
            sprint(stream -> _write_native_type_parameter(stream, item, copy(bound))) for
            item in Base.uniontypes(parameter)
        ]
        sort!(members)
        print(io, "J", length(members), ':')
        for item in members
            print(io, ncodeunits(item), ':')
            write(io, codeunits(item))
        end
    elseif Base.isvarargtype(parameter)
        # Type parameters of Tuple/NamedTuple containers are not new value kinds.
        # T and an optional N are encoded structurally using the same TypeVar scope.
        print(io, 'G')
        _write_native_type_parameter(io, parameter.T, bound)
        if isdefined(parameter, :N)
            print(io, 'N')
            _write_native_type_parameter(io, parameter.N, bound)
        else
            print(io, 'A')
        end
    elseif parameter isa Symbol
        print(io, 'S');
        _native_type_atom(io, parameter)
    elseif parameter isa Tuple
        print(io, "Q", length(parameter), ':')
        for item in parameter
            _write_native_type_parameter(io, item, bound)
        end
    elseif isbits(parameter)
        print(io, 'V')
        _write_native_type_parameter(io, typeof(parameter), bound)
        if isprimitivetype(typeof(parameter))
            bytes = reinterpret(UInt8, [parameter])
            print(io, "P", length(bytes), ':');
            write(io, bytes)
        else
            # Do not serialize padding bytes from an isbits composite parameter.
            print(io, "F", fieldcount(typeof(parameter)), ':')
            for field in fieldnames(typeof(parameter))
                _write_native_type_parameter(io, getfield(parameter, field), bound)
            end
        end
    else
        throw(ArgumentError("unsupported native definition type parameter"))
    end
    return nothing
end

# Encode a stable native type prefix using the existing type-parameter encoder and a trailing separator.
function _native_type_prefix(type::DataType)
    return sprint() do io
        _write_native_type_parameter(io, type, IdDict{TypeVar, Int}())
        print(io, ':')
    end
end

"""Write complete values; non-model callers keep the historical encoding by default."""
function write_native_definition_value(buffer, value; definition_version::Int = 1)
    _validate_native_definition_version(definition_version)
    return _write_native_definition_value(
        buffer,
        value,
        Dict{DataType, String}(),
        definition_version,
    )
end

# Serialize complete native values with cached type prefixes under the selected definition encoding version.
function _write_native_definition_value(
    buffer,
    value,
    type_prefixes::Dict{DataType, String},
    definition_version::Int,
)
    prefix = get!(type_prefixes, typeof(value)) do
        definition_version == 1 ? string(typeof(value), ':') : _native_type_prefix(typeof(value))
    end
    print(buffer, prefix)
    if value isa AbstractArray
        print(buffer, size(value), ':')
        for element in value
            _write_native_definition_value(buffer, element, type_prefixes, definition_version)
        end
    elseif value isa Union{Tuple, NamedTuple}
        for element in value
            _write_native_definition_value(buffer, element, type_prefixes, definition_version)
        end
    elseif value isa AbstractDict
        if definition_version == 1
            for key in sort!(collect(keys(value)); by = repr)
                _write_native_definition_value(buffer, key, type_prefixes, definition_version)
                _write_native_definition_value(
                    buffer,
                    value[key],
                    type_prefixes,
                    definition_version,
                )
            end
        else
            # Ordering consumes complete encoded keys once, rather than contextual repr.
            rows = [
                (
                    key,
                    let io = IOBuffer()
                        _write_native_definition_value(io, key, type_prefixes, definition_version)
                        take!(io)
                    end,
                ) for key in keys(value)
            ]
            sort!(rows; by = row -> bytes2hex(row[2]))
            for (key, bytes) in rows
                write(buffer, bytes)
                _write_native_definition_value(
                    buffer,
                    value[key],
                    type_prefixes,
                    definition_version,
                )
            end
        end
    elseif value isa Function
        for field in fieldnames(typeof(value))
            _write_native_definition_value(
                buffer,
                getfield(value, field),
                type_prefixes,
                definition_version,
            )
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

The owned native input retains complete values; this metadata is descriptive.
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
            values_omitted = "owned input array; shape summary only",
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

"""Adopt a native definition using the common owned sequential scratch port."""
function native_model_definition_stream(
    input::AbstractNativeModelInput;
    definition_version::Int = 2,
)
    _validate_native_definition_version(definition_version)
    return scientific_definition_stream(;
        changed_error = "NATIVE_DEFINITION_STREAM_CHANGED",
        negative_read_error = "negative native definition chunk length",
    ) do stream
        write_native_model_definition(stream, input; definition_version)
    end
end
