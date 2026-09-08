# Remove the shared Fortran/Wannier90/VASP inline comment syntax.
function strip_input_comment(line::AbstractString)
    return strip(first(split(first(split(String(line), '!'; limit = 2)), '#'; limit = 2)))
end

# Parse the common Fortran-style boolean tokens with an explicit yes/no policy.
function parse_input_boolean(
    value::AbstractString,
    field::AbstractString;
    allow_yes_no::Bool = false,
)
    normalized = lowercase(strip(value))
    normalized in (".true.", "true", "t", "1") && return true
    normalized in (".false.", "false", "f", "0") && return false
    allow_yes_no && normalized == "yes" && return true
    allow_yes_no && normalized == "no" && return false
    throw(ArgumentError("cannot interpret $(field)=$(value) as a boolean"))
end
