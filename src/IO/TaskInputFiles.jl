"""Parse one observed TOML input; the returned document owns its parsed values."""
function read_task_input_file(path::AbstractString)
    source = read_scientific_source(path)
    return (;
        document = TOML.parse(String(source.bytes)),
        path = source.state.path,
        identity = scientific_file_identity(source.state),
    )
end

# TOML cannot encode nothing. Omit absent optional controls rather than inventing
# a sentinel which would change the meaning on a subsequent read.
"""Represent an absent optional value; dictionary serialization omits this entry."""
task_input_toml_value(value::Nothing) = nothing
"""Serialize a symbolic configuration selector as its TOML string spelling."""
task_input_toml_value(value::Symbol) = String(value)
"""Convert a configuration tuple to a TOML array while preserving element order."""
task_input_toml_value(value::Tuple) = [task_input_toml_value(x) for x in value]
"""Recursively serialize an ordered configuration vector as a TOML array."""
task_input_toml_value(value::AbstractVector) = [task_input_toml_value(x) for x in value]
"""Serialize named configuration fields through the dictionary conversion."""
task_input_toml_value(value::NamedTuple) = task_input_toml_value(Dict(pairs(value)))
"""Convert dictionary keys to strings and values recursively, omitting only absent optional values."""
function task_input_toml_value(value::AbstractDict)
    return Dict(
        string(key) => task_input_toml_value(item) for (key, item) in value if item !== nothing
    )
end
"""Pass remaining values unchanged to the TOML writer for validation."""
task_input_toml_value(value) = value

# Read the existing runtime text format, never evaluate its Julia-looking tuples.
# Restrict this reader to the scalar execution fields needed for input provenance.
function _read_task_input_fourier_record(path::AbstractString)
    source = read_scientific_source(path)
    fields = Dict{String, String}()
    in_fourier = false
    sections = 0
    for line in split(String(source.bytes), '\n')
        text = strip(line)
        if startswith(text, "[") && endswith(text, "]")
            in_fourier = text == "[Fourier]"
            in_fourier && (sections += 1)
        elseif in_fourier && occursin('=', text)
            key, value = strip.(split(text, '='; limit = 2))
            if key in ("requested_backend", "effective_backend", "NKdiv", "NKFFT", "factor_source")
                haskey(fields, key) && throw(ArgumentError("Duplicate runtime Fourier field $key."))
                fields[key] = value
            end
        end
    end
    sections == 1 || throw(ArgumentError("Expected one actual runtime Fourier section."))
    all(
        key -> haskey(fields, key),
        ("requested_backend", "effective_backend", "NKdiv", "NKFFT", "factor_source"),
    ) || throw(ArgumentError("Incomplete actual runtime Fourier evidence."))
    fields["requested_backend"] in ("direct", "mixed", "auto") ||
        throw(ArgumentError("Unknown requested runtime Fourier backend."))
    fields["effective_backend"] in ("direct", "mixed") ||
        throw(ArgumentError("Runtime Fourier backend remains unresolved."))
    function factor(key)
        value = fields[key]
        value == "nothing" && return nothing
        occursin(r"^\(\s*[1-9][0-9]*\s*,\s*[1-9][0-9]*\s*,\s*[1-9][0-9]*\s*\)$", value) ||
            throw(ArgumentError("Invalid actual runtime Fourier factor $key."))
        parsed = tryparse.(Int, strip.(split(value[2:(end - 1)], ',')))
        any(isnothing, parsed) &&
            throw(ArgumentError("Actual runtime Fourier factor $key exceeds the integer range."))
        return Tuple(Int.(parsed))
    end
    nkdiv, nkfft = factor("NKdiv"), factor("NKFFT")
    backend = fields["effective_backend"]
    backend == "direct" &&
        (nkdiv !== nothing || nkfft !== nothing) &&
        throw(ArgumentError("Actual direct Fourier metadata contains mixed factors."))
    backend == "mixed" &&
        (nkdiv === nothing || nkfft === nothing) &&
        throw(ArgumentError("Actual mixed Fourier metadata lacks factors."))
    return (;
        path = source.state.path,
        identity = scientific_file_identity(source.state),
        requested_backend = fields["requested_backend"],
        backend,
        nkdiv,
        nkfft,
        factor_source = fields["factor_source"],
    )
end

"""Atomically write a TOML record in the caller's explicitly selected directory."""
function write_task_input_file(path::AbstractString, document::AbstractDict)
    absolute = abspath(path)
    mkpath(dirname(absolute))
    temporary, stream = mktemp(dirname(absolute))
    try
        TOML.print(stream, task_input_toml_value(document); sorted = true)
        close(stream)
        atomic_file_replace(temporary, absolute)
    finally
        isopen(stream) && close(stream)
        isfile(temporary) && rm(temporary)
    end
    return absolute
end

"""Write a generated human explanation or template without changing user settings."""
function write_task_input_text(path::AbstractString, content::AbstractString)
    absolute = abspath(path)
    mkpath(dirname(absolute))
    open(absolute, "w") do stream
        write(stream, content)
    end
    return absolute
end

"""Atomically write a workflow JSON report through the already declared JSON3 dependency."""
function write_task_input_json(path::AbstractString, document::AbstractDict)
    json3 = Base.require(Base.PkgId(Base.UUID("0f8b85d8-7281-11e9-16c2-39a750bddbf1"), "JSON3"))
    absolute = abspath(path)
    mkpath(dirname(absolute))
    temporary, stream = mktemp(dirname(absolute))
    try
        Base.invokelatest(getproperty(json3, :write), stream, document)
        close(stream)
        atomic_file_replace(temporary, absolute)
    finally
        isopen(stream) && close(stream)
        isfile(temporary) && rm(temporary)
    end
    return absolute
end
