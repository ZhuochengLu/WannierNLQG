"""Read saved OUTCAR point order and spin flags without opening WAVECAR/POTCAR.

Only the explicitly labelled reciprocal-lattice point table is accepted. An
irreducible table remains irreducible; no complete mesh or magnetic moments are
inferred from weights, ISPIN, or local PAW moment summaries.
"""
function read_vasp_geometry_metadata(filename::AbstractString)
    observed = with_scientific_source(filename; resolve_links = true) do path
        lines = readlines(path)
        function unique_header(pattern, convert_value, label)
            values = [convert_value(m.captures[1]) for line in lines for m in eachmatch(pattern, line)]
            isempty(values) && return nothing
            all(==(first(values)), values) ||
                throw(ArgumentError("OUTCAR conflicting $label declarations"))
            return first(values)
        end
        nk = unique_header(r"\bNKPTS\s*=\s*(\d+)", x->parse(Int, x), "NKPTS")
        nk !== nothing && nk > 0 || throw(ArgumentError("OUTCAR requires positive NKPTS"))
        ispin = unique_header(r"\bISPIN\s*=\s*(\d+)", x->parse(Int, x), "ISPIN")
        ispin in (nothing, 1, 2) || throw(ArgumentError("OUTCAR unsupported ISPIN"))
        noncollinear =
            unique_header(r"\bLNONCOLLINEAR\s*=\s*([TF])\b", ==("T"), "LNONCOLLINEAR")
        spinorbit = unique_header(r"\bLSORBIT\s*=\s*([TF])\b", ==("T"), "LSORBIT")
        points = nothing
        weights = nothing
        for index in eachindex(lines)
            occursin(r"^\s*k-points in reciprocal lattice and weights\s*:", lines[index]) ||
                continue
            rows = Vector{Vector{Float64}}()
            cursor = index+1
            while cursor <= length(lines) && isempty(strip(lines[cursor]))
                ;
                cursor += 1;
            end
            for _ in 1:nk
                cursor <= length(lines) ||
                    throw(ArgumentError("OUTCAR truncated reciprocal point table"))
                tokens = split(strip(lines[cursor]));
                cursor += 1
                length(tokens)==4 ||
                    throw(ArgumentError("OUTCAR reciprocal point row requires four values"))
                row =
                    [tryparse(Float64, replace(token, 'D'=>'E', 'd'=>'e')) for token in tokens]
                all(value->value!==nothing && isfinite(value), row) ||
                    throw(ArgumentError("OUTCAR reciprocal point row must be finite"))
                row[4] >= 0 || throw(ArgumentError("OUTCAR negative k-point weight"))
                push!(rows, Float64.(row))
            end
            table = hcat(rows...)
            if points !== nothing
                isequal(points, table[1:3, :]) && isequal(weights, vec(table[4, :])) || throw(
                    ArgumentError(
                        "OUTCAR repeated reciprocal point tables disagree; select one calculation",
                    ),
                )
            end
            points = table[1:3, :];
            weights = vec(table[4, :])
        end
        points === nothing &&
            throw(ArgumentError("OUTCAR has no labelled reciprocal-lattice point table"))
        return (
            kpoints_fractional = points,
            kpoint_weights = weights,
            original_kpoint_indices = collect(1:nk),
            spin_channels = ispin,
            noncollinear_spin = noncollinear,
            spinorbit = spinorbit,
            magnetic_moments_available = false,
            loaded_files = [abspath(path)],
            wavefunctions_loaded = false,
            physical_metric_loaded = false,
        )
    end
    return observed.value
end
