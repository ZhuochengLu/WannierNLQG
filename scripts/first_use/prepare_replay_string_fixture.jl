# Transport preparation runs separately from every cold public-call process.
using WannierNLQG, HDF5, JSON3, EzXML, MPI, SHA, Serialization
length(ARGS) == 3 || error("usage: gauge_file replay_save_directory receipt")
gauge, replay, receipt = abspath.(ARGS)
isfile(gauge) && isdir(replay) || error("REPLAY_INPUT_MISSING")
ncodeunits(replay) == 287 || error("REPLAY_LOCATOR_LENGTH_MUST_BE_287")
function native_fields(file)
    result = Dict{String, String}()
    function record(path, value)
        buffer = IOBuffer()
        Serialization.serialize(buffer, (string(typeof(value)), value))
        result[path] = bytes2hex(sha256(take!(buffer)))
    end
    function visit(group, prefix)
        attributes = HDF5.attributes(group)
        for key in keys(attributes)
            record(prefix*"/@"*key, HDF5.read_attribute(group, key))
        end
        for key in keys(group)
            object = group[key]
            try
                if object isa HDF5.Group
                    visit(object, prefix*"/"*key)
                else
                    record(prefix*"/"*key, read(object))
                    attributes = HDF5.attributes(object)
                    for attr in keys(attributes)
                        record(prefix*"/"*key*"/@"*attr, HDF5.read_attribute(object, attr))
                    end
                end
            finally
                close(object)
            end
        end
    end
    HDF5.h5open(file, "r") do handle
        visit(handle, "")
    end
    return result
end
# Official digest reconstruction is transport preparation only. This process is
# never traced or timed as a public first call; fresh target processes follow.
backend = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
backend === nothing && error("PREPARATION_BACKEND_MISSING")
paw = backend.PAWMatrixElements
payload_root = dirname(dirname(dirname(gauge)))
cd(payload_root)
policy, schema, contract, old_digest = HDF5.h5open(gauge, "r") do handle
    metadata = handle["source_metadata"]
    try
        (
            Symbol(HDF5.read_attribute(metadata, "construction_policy")),
            String(HDF5.read_attribute(handle, "schema_version")),
            paw._star_gauge_contract_version(
                String(HDF5.read_attribute(handle, "schema_version")),
                HDF5.attributes(handle),
                Dict{String, String}(),
                Dict{String, String}(),
            ),
            String(HDF5.read_attribute(handle, "payload_sha256")),
        )
    finally
        close(metadata)
    end
end
state = paw._read_star_covariant_paw_gauge_hdf5(gauge; construction_policy = policy)
payload = state.payload
paw._star_payload_sha256(payload; schema_version = schema, contract_version = contract) ==
old_digest || error("ORIGINAL_LOGICAL_PAYLOAD_DIGEST_MISMATCH")
before = native_fields(gauge)
payload.source_metadata["source_replay_save_directory"] = replay
payload.source_metadata["source_replay_descriptor_sha256"] =
    paw._star_source_replay_descriptor_sha256(payload.source_metadata)
# Native providers guard their source file identity. Finish digest evaluation
# before modifying that source file; do not bypass the file-change guard.
new_digest = paw._star_payload_sha256(payload; schema_version = schema, contract_version = contract)
HDF5.h5open(gauge, "r+") do handle
    metadata_group = handle["source_metadata"]
    try
        for key in ("source_replay_save_directory", "source_replay_descriptor_sha256")
            HDF5.delete_attribute(metadata_group, key)
            HDF5.write_attribute(metadata_group, key, payload.source_metadata[key])
        end
        HDF5.delete_attribute(handle, "payload_sha256")
        HDF5.write_attribute(handle, "payload_sha256", new_digest)
    finally
        close(metadata_group)
    end
end
# The official reader verifies replay, descriptor and complete logical payload.
restored = paw._read_star_covariant_paw_gauge_hdf5(gauge; construction_policy = policy)
restored.payload.source_metadata["source_replay_save_directory"] == replay ||
    error("OFFICIAL_REPLAY_READBACK_MISMATCH")
!MPI.Initialized() || error("PREPARATION_INITIALIZED_MPI")
HDF5.h5open(gauge, "r") do handle
    metadata_group = handle["source_metadata"]
    try
        actual = HDF5.read_attribute(metadata_group, "source_replay_save_directory")
        actual == replay || error("REPLAY_LOCATOR_READBACK actual="*repr(actual))
        attribute = HDF5.open_attribute(metadata_group, "source_replay_save_directory")
        try
            datatype = HDF5.datatype(attribute)
            try
                sizeof(datatype) == 287 || error("REPLAY_FIXED_STRING_STORAGE_NOT_287")
            finally
                close(datatype)
            end
        finally
            close(attribute)
        end
    finally
        close(metadata_group)
    end
end
after = native_fields(gauge)
allowed = Set((
    "/source_metadata/@source_replay_save_directory",
    "/source_metadata/@source_replay_descriptor_sha256",
    "/@payload_sha256",
))
Set(keys(before)) == Set(keys(after)) || error("HDF5_FIELD_INVENTORY_CHANGED")
changed = Set(key for key in keys(before) if before[key] != after[key])
changed == allowed || error("UNDECLARED_NATIVE_HDF5_FIELD_CHANGE")
write(
    receipt,
    "REPLAY_LOCATOR_BYTES=287\nHDF5_STRING_STORAGE_BYTES=287\nOFFICIAL_LOGICAL_PAYLOAD_READBACK=true\nPREPARATION_EXCLUDED_FROM_TRACE_AND_COLD_TIMING=true\nALL_OTHER_NATIVE_FIELDS_SIGNED_BITS_EXACT=true\nNATIVE_FIELDS="*string(
        length(before),
    )*"\n",
)
