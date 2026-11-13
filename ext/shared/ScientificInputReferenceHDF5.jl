"""Persist complete bytes, or explicit versioned source slices under a caller-bound root."""
function write_scientific_input_reference_hdf5(
    group,
    name,
    definition::WannierNLQG.IO.ScientificInputDefinition;
    reference_root::Union{Nothing, AbstractString} = nothing,
)
    definition.byte_count>0 || throw(ArgumentError("EMPTY_RESTART_INPUT_REFERENCE"))
    if reference_root !== nothing
        text = WannierNLQG.IO.scientific_input_reference_toml(definition, reference_root)
        ncodeunits(text) <= 16*1024^2 ||
            throw(ArgumentError("SCIENTIFIC_REFERENCE_INDEX_TOO_LARGE"))
        node = HDF5.create_group(group, name)
        try
            HDF5.attributes(node)["schema"] = "wanniernlqg.scientific-input-reference/1"
            node["manifest_utf8"] = collect(codeunits(text))
        finally
            close(node)
        end
        return nothing
    end
    dataset=HDF5.create_dataset(
        group,
        name,
        UInt8,
        (definition.byte_count,);
        chunk = (min(65536, definition.byte_count),),
    )
    try
        WannierNLQG.IO.with_scientific_input_definition_bytes(definition) do source
            offset=0
            while offset<definition.byte_count
                count=min(65536, definition.byte_count-offset)
                bytes=read(source, count)
                length(bytes)==count || throw(ArgumentError("INCOMPLETE_RESTART_INPUT_REFERENCE"))
                dataset[(offset + 1):(offset + count)]=bytes
                offset+=count
            end
            eof(source) || throw(ArgumentError("RESTART_INPUT_REFERENCE_EXTENT_MISMATCH"))
        end
    finally
        close(dataset)
    end
    return nothing
end

"""Read inline bytes compatibly, or verify an explicitly bound immutable source bundle."""
function read_scientific_input_reference_hdf5(
    group,
    name;
    reference_root::Union{Nothing, AbstractString} = nothing,
)
    dataset=group[name]
    try
        if dataset isa HDF5.Group
            Set(String.(keys(dataset))) == Set(["manifest_utf8"]) &&
            Set(String.(keys(HDF5.attributes(dataset)))) == Set(["schema"]) &&
            String(HDF5.read_attribute(dataset, "schema")) ==
            "wanniernlqg.scientific-input-reference/1" ||
                throw(ArgumentError("SCIENTIFIC_REFERENCE_SCHEMA_UNSUPPORTED"))
            reference_root === nothing && throw(ArgumentError("SCIENTIFIC_REFERENCE_ROOT_REQUIRED"))
            bytes = dataset["manifest_utf8"]
            try
                ndims(bytes)==1 && eltype(bytes)===UInt8 && 0<length(bytes)<=16*1024^2 ||
                    throw(ArgumentError("SCIENTIFIC_REFERENCE_INDEX_INVALID"))
                text = String(read(bytes))
                isvalid(text) || throw(ArgumentError("SCIENTIFIC_REFERENCE_INDEX_INVALID"))
                return WannierNLQG.IO.scientific_input_definition_from_reference_toml(
                    text,
                    reference_root,
                )
            finally
                close(bytes)
            end
        end
        ndims(dataset)==1 && eltype(dataset)===UInt8 && length(dataset)>0 ||
            throw(ArgumentError("INVALID_RESTART_INPUT_REFERENCE"))
        return WannierNLQG.IO.scientific_input_definition_bytes() do stream
            buffer = Vector{UInt8}(undef, min(65536, length(dataset)))
            for first in 1:length(buffer):length(dataset)
                last = min(first + length(buffer) - 1, length(dataset))
                bytes = @view buffer[1:(last - first + 1)]
                copyto!(bytes, dataset, first:last)
                write(stream, bytes)==length(bytes) ||
                    throw(ArgumentError("INCOMPLETE_RESTART_INPUT_REFERENCE"))
            end
        end
    finally
        close(dataset)
    end
end
