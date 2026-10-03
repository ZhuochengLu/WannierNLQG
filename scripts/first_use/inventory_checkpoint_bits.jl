# Offline native field inventory and official integrity-reader validation.
using HDF5, JSON3, SHA, WannierNLQG
length(ARGS) == 2 || error("input-file list and fresh output required")
inputs, output = ARGS
ispath(output) && error("checkpoint inventory output must be fresh")
rows = Any[]
for file in JSON3.read(read(inputs, String))
    before = bytes2hex(open(sha256, String(file)))
    fields = Any[]
    function record_value(value, path)
        if value isa Number || (value isa AbstractArray && isbitstype(eltype(value)))
            data = value isa Number ? [value] : vec(Array(value))
            push!(
                fields,
                (
                    path = path,
                    kind = "bits",
                    element_type = string(eltype(data)),
                    shape = value isa Number ? Int[] : collect(size(value)),
                    bit_sha256 = bytes2hex(sha256(reinterpret(UInt8, data))),
                    bytes = sizeof(data),
                ),
            )
        else
            push!(fields, (path = path, kind = "metadata", value = value))
        end
    end
    function record_attributes(handle, prefix)
        for name in sort!(collect(keys(attributes(handle))))
            attribute = attributes(handle)[name]
            try
                record_value(read(attribute), prefix * "/@attribute/" * name)
            finally
                close(attribute)
            end
        end
    end
    function visit(handle, prefix)
        record_attributes(handle, prefix)
        for name in sort!(collect(keys(handle)))
            entry = handle[name]
            path = prefix * "/" * name
            try
                if entry isa HDF5.Group
                    visit(entry, path)
                else
                    record_attributes(entry, path)
                    record_value(read(entry), path)
                end
            finally
                close(entry)
            end
        end
    end
    h5open(String(file), "r") do handle
        visit(handle, "")
    end
    restored = WannierNLQG.Wannierization.read_wannierization_checkpoint_hdf5(String(file))
    before == bytes2hex(open(sha256, String(file))) ||
        error("checkpoint bytes changed during readback")
    push!(
        rows,
        (
            file = file,
            artifact_sha256 = before,
            status = string(restored.status),
            v_finite = all(isfinite, restored.v_matrix),
            v_max_abs = maximum(abs, restored.v_matrix),
            fields = fields,
            official_integrity_reader_verified = true,
        ),
    )
end
write(output, JSON3.write(rows))
