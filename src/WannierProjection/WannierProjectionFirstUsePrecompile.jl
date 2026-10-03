# Compile observed private closure signatures in their owning module.
# No public task, backend activation, external resource, or scientific update runs here.
import PrecompileTools
if parentmodule(@__MODULE__).FIRST_USE_TRACE_COMPATIBLE &&
   ccall(:jl_generating_output, Cint, ()) == 1 &&
   PrecompileTools.workload_enabled(parentmodule(@__MODULE__))
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            var"#32#34"{Array{Tuple{Int64, Int64, Int64}, 1}},
            Tuple{String},
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Generator{Tuple{String}, var"#32#34"{Array{Tuple{Int64, Int64, Int64}, 1}}},
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Generator{Tuple{String}, var"#32#34"{Array{Tuple{Int64, Int64, Int64}, 1}}},
            Int64,
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            var"#33#35"{Array{Float64, 2}, Array{Tuple{Int64, Int64, Int64}, 1}},
            Tuple{String},
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Generator{
                Tuple{String},
                var"#33#35"{Array{Float64, 2}, Array{Tuple{Int64, Int64, Int64}, 1}},
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Generator{
                Tuple{String},
                var"#33#35"{Array{Float64, 2}, Array{Tuple{Int64, Int64, Int64}, 1}},
            },
            Int64,
        },
    )
    # Public WIN parser and basis construction: signatures only, no file is opened.
    false
    false
end
