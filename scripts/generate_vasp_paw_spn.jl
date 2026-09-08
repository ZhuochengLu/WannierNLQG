#!/usr/bin/env julia

using WannierNLQG
import WannierNLQG.Wannierization as W

const HELP = """
Generate a dimensionless Cartesian Wannier90 SPN file from VASP PAW data.

Required:
  --poscar=PATH --potcar=PATH --wavecar=PATH --bands=FIRST:LAST
  --output=PATH --provenance=PATH --spin-channel=INTEGER

Spin basis (choose one):
  --incar=PATH
  --saxis=X,Y,Z

Optional:
  --oracle=PATH --require-oracle=true|false --formatted=true|false

The command always reads the full WAVECAR cutoff and never reconstructs PAW
data from MMN/AMN. Existing outputs are atomically replaced only after a
complete write.
"""

# Parse one strict key=value command line without implicit path defaults.
function parse_options(arguments)
    any(argument -> argument in ("-h", "--help"), arguments) && (println(HELP); exit(0))
    options = Dict{String, String}()
    for argument in arguments
        startswith(argument, "--") && occursin('=', argument) ||
            throw(ArgumentError("arguments must use --key=value: $(argument)"))
        key, value = split(argument[3:end], '='; limit = 2)
        !isempty(key) && !isempty(value) || throw(ArgumentError("empty command-line key or value"))
        haskey(options, key) && throw(ArgumentError("duplicate option --$(key)"))
        options[key] = value
    end
    allowed = Set([
        "poscar",
        "potcar",
        "wavecar",
        "incar",
        "saxis",
        "bands",
        "spin-channel",
        "output",
        "provenance",
        "oracle",
        "require-oracle",
        "formatted",
    ])
    unknown = sort!(collect(setdiff(keys(options), allowed)))
    isempty(unknown) || throw(ArgumentError("unknown options: $(join(unknown, ", "))"))
    return options
end

# Read one mandatory option by its public CLI name.
function required_option(options, key)
    haskey(options, key) || throw(ArgumentError("missing required option --$(key)"))
    return options[key]
end

# Parse one explicit true/false option.
function boolean_option(options, key, default)
    value = lowercase(get(options, key, string(default)))
    value in ("true", "false") || throw(ArgumentError("--$(key) must be true or false"))
    return value == "true"
end

# Parse the required one-based contiguous VASP band range.
function band_range_option(value)
    matched = match(r"^(\d+):(\d+)$", value)
    matched === nothing && throw(ArgumentError("--bands must use FIRST:LAST"))
    first_band, last_band = parse.(Int, matched.captures)
    1 <= first_band <= last_band || throw(ArgumentError("--bands is not a positive range"))
    return first_band:last_band
end

# Parse an explicit normalized SAXIS vector.
function saxis_option(value)
    components = parse.(Float64, split(value, ','))
    length(components) == 3 || throw(ArgumentError("--saxis must contain X,Y,Z"))
    all(isfinite, components) && sum(abs2, components) > 0.0 ||
        throw(ArgumentError("--saxis must be finite and nonzero"))
    return Tuple(components)
end

function main(arguments = ARGS)
    options = parse_options(arguments)
    has_incar = haskey(options, "incar")
    has_saxis = haskey(options, "saxis")
    xor(has_incar, has_saxis) || throw(ArgumentError("choose exactly one of --incar or --saxis"))
    source = VASPWavefunctionSource(
        required_option(options, "poscar"),
        required_option(options, "wavecar");
        potcar_file = required_option(options, "potcar"),
        incar_file = has_incar ? options["incar"] : nothing,
        spin_basis_saxis = has_saxis ? saxis_option(options["saxis"]) : nothing,
        band_range = band_range_option(required_option(options, "bands")),
        spin_channel = parse(Int, required_option(options, "spin-channel")),
        spinor = true,
        representation_cutoff_ev = nothing,
        include_time_reversal = false,
    )
    result = W.generate_vasp_paw_spn(
        source;
        output_spn_file = required_option(options, "output"),
        provenance_hdf5 = required_option(options, "provenance"),
        spin_channel = parse(Int, required_option(options, "spin-channel")),
        oracle_spn_file = get(options, "oracle", nothing),
        require_oracle = boolean_option(options, "require-oracle", false),
        formatted = boolean_option(options, "formatted", false),
    )
    println("status = ", result.passed ? "PASS" : "NUMERICAL_HOLD")
    println("spn = ", result.artifacts["spn"])
    println("provenance = ", result.artifacts["provenance_hdf5"])
    return result.passed ? 0 : 2
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
