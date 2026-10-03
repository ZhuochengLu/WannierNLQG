module FirstUseExpertProbe
using JSON3
using SHA
const target = Main.TARGET
const records = Any[]
const seen = Ref(false)

function collect_numeric!(leaves, value, path::String, depth::Int = 0)
    depth > 5 && return
    if value isa Number
        payload = isbitstype(typeof(value)) ? bytes2hex(reinterpret(UInt8, [value])) : string(value)
        push!(
            leaves,
            (
                path = path,
                type = string(typeof(value)),
                finite = isfinite(value),
                payload = payload,
            ),
        )
    elseif value isa AbstractArray{<:Number} && isbitstype(eltype(value))
        array = Array(value)
        push!(
            leaves,
            (
                path = path,
                type = string(typeof(value)),
                shape = collect(size(value)),
                finite = all(isfinite, array),
                max_abs = all(isfinite, array) ? maximum(abs, array; init = 0.0) : nothing,
                max_abs_nonfinite_repr = all(isfinite, array) ? nothing :
                                         string(maximum(abs, array; init = 0.0)),
                sha256 = bytes2hex(sha256(reinterpret(UInt8, vec(array)))),
            ),
        )
    elseif value isa AbstractArray
        length(value) <= 256 || error("NONNUMERIC_ARRAY_TOO_LARGE_FOR_EXPERT_PROBE")
        for (index, item) in pairs(value)
            collect_numeric!(leaves, item, path * "[" * string(index) * "]", depth + 1)
        end
    elseif value isa NamedTuple
        for (key, item) in pairs(value)
            collect_numeric!(leaves, item, path * "." * string(key), depth + 1)
        end
    elseif value isa AbstractDict
        for key in sort!(collect(keys(value)); by = string)
            collect_numeric!(leaves, value[key], path * "." * string(key), depth + 1)
        end
    elseif value isa Tuple
        for (index, item) in enumerate(value)
            collect_numeric!(leaves, item, path * "[$(index)]", depth + 1)
        end
    elseif startswith(string(parentmodule(typeof(value))), "WannierNLQG") &&
           isstructtype(typeof(value))
        for key in fieldnames(typeof(value))
            collect_numeric!(leaves, getfield(value, key), path * "." * string(key), depth + 1)
        end
    end
end

function numeric_summary(value)
    leaves = Any[]
    collect_numeric!(leaves, value, "result")
    return (
        type = string(typeof(value)),
        numeric_leaf_count = length(leaves),
        all_finite = all(leaf.finite for leaf in leaves),
        numeric_sha256 = bytes2hex(sha256(JSON3.write(leaves))),
        leaves = leaves,
    )
end

end
