# Observed real first-use IOStream signatures; compile only, never execute writes.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Array{Array{Base.Complex{Float64}, 2}, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Array{Int64, 3},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Base.Dict{Int64, Array{Float64, 1}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Base.Dict{Int64, Array{Int64, 1}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Base.Dict{Int64, Float64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Base.Dict{Int64, Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Base.Dict{String, Any},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Base.Dict{
                    Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                    Array{Base.Complex{Float64}, 4},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Base.ReentrantLock,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                NTuple{24, Symbol},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                NTuple{7, Symbol},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                NTuple{9, Symbol},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Tuple{Int64, Int64, Int64},
            },
        )
    end
end
