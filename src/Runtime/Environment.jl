using LinearAlgebra
using Printf

"""
Format a duration in seconds with exactly three digits after the decimal point.
"""
format_seconds(seconds::Real) = @sprintf("%.3f", seconds)

try
    BLAS.set_num_threads(1)
catch err
    @warn "Unable to set BLAS threads to 1" exception = (err, catch_backtrace())
end

"""
Return true for stripped case-insensitive `1`, `true`, `yes` or `on`; all other text is false.

Parse bool env.
"""
parse_bool_env(value::AbstractString) = lowercase(strip(value)) in ("1", "true", "yes", "on")

"""
Return the first defined environment variable from the ordered names, or the supplied default.

A single-name overload uses the same policy; an explicitly empty variable is retained.
"""
function env_value(names::Tuple{Vararg{String}}, default::AbstractString)
    for name in names
        haskey(ENV, name) && return ENV[name]
    end
    return default
end

"""
Return the first defined environment variable from the ordered names, or the supplied default.

A single-name overload uses the same policy; an explicitly empty variable is retained.
"""
env_value(name::String, default::AbstractString) = env_value((name,), default)

"""
Parse the first defined environment value as Int, using the default for absent or blank text.

Invalid nonblank integer text raises a parse error; multiple names are checked in order.
"""
function env_int(names::Tuple{Vararg{String}}, default::Integer)
    value = strip(env_value(names, string(default)))
    isempty(value) && return Int(default)
    return parse(Int, value)
end

"""
Parse the first defined environment value as Int, using the default for absent or blank text.

Invalid nonblank integer text raises a parse error; multiple names are checked in order.
"""
env_int(name::String, default::Integer) = env_int((name,), default)

"""
Parse the first defined environment value as Float64, using the default for absent or blank text.

Invalid nonblank numeric text raises a parse error; multiple names are checked in order.
"""
function env_float(names::Tuple{Vararg{String}}, default::Real)
    value = strip(env_value(names, string(default)))
    isempty(value) && return Float64(default)
    return parse(Float64, value)
end

"""
Parse the first defined environment value as Float64, using the default for absent or blank text.

Invalid nonblank numeric text raises a parse error; multiple names are checked in order.
"""
env_float(name::String, default::Real) = env_float((name,), default)
