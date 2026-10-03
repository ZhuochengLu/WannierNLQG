# Remaining emitted stdlib native specializations from the measured cold solver.
@compile_workload begin
    if FIRST_USE_WORKLOAD_ENABLED
        precompile(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Int64,
                Int64,
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Int64,
                Int64,
                Int64,
            },
        )
        precompile(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                NTuple{4, Int64},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                NTuple{4, Int64},
            },
        )
        precompile(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Bool, N} where N},
                UndefInitializer,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Float64, N} where N},
                UndefInitializer,
                Int64,
                Int64,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Float64, N} where N},
                UndefInitializer,
                Int64,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Float64, N} where N},
                UndefInitializer,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), Type{Array{Int64, 1}}, Array{Int64, 1}})
        precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Int64, N} where N},
                UndefInitializer,
                Int64,
                Int64,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Int64, N} where N},
                UndefInitializer,
                Int64,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Int64, N} where N},
                UndefInitializer,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{Int8, N} where N}, UndefInitializer, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Int8, N} where N},
                UndefInitializer,
                Int64,
                Int64,
            },
        )
        precompile(
            Tuple{Type{Array{T, 2} where T}, LinearAlgebra.Transpose{Float64, Array{Float64, 2}}},
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{T, 2} where T},
                LinearAlgebra.Transpose{Float64, Array{Float64, 2}},
            },
        )
        precompile(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{UInt64, N} where N},
                UndefInitializer,
                Int64,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{UInt64, N} where N},
                UndefInitializer,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{UInt8, N} where N},
                UndefInitializer,
                Int64,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{UInt8, N} where N},
                UndefInitializer,
                Int64,
            },
        )
        precompile(Tuple{Type{Base.Dict{String, String}}, Tuple{Pair{String, String}}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Base.Dict{String, String}},
                Tuple{Pair{String, String}},
            },
        )
        precompile(Tuple{Type{Base.Set{T} where T}, Array{String, 1}})
        precompile(
            Tuple{typeof(_first_use_foreign_call), Type{Base.Set{T} where T}, Array{String, 1}},
        )
        precompile(Tuple{Type{Bool}, Int64})
        precompile(Tuple{typeof(_first_use_foreign_call), Type{Bool}, Int64})
        false
        false
        false
        false
        precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, String}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Pair{A, B} where {B} where A},
                String,
                Base.Dict{String, String},
            },
        )
        precompile(Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Pair{A, B} where {B} where A},
                Tuple{Int64, Int64, Int64},
                Int64,
            },
        )
        precompile(
            Tuple{
                Type{Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}}},
                Bool,
                Bool,
                Bool,
                Bool,
                Bool,
                Int64,
                Int64,
                Bool,
                Bool,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}}},
                Bool,
                Bool,
                Bool,
                Bool,
                Bool,
                Int64,
                Int64,
                Bool,
                Bool,
            },
        )
        precompile(Tuple{Type{String}, Array{UInt8, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), Type{String}, Array{UInt8, 1}})
        precompile(Tuple{typeof(Base.:(*)), Array{Float64, 2}, Array{Float64, 2}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.:(*)),
                Array{Float64, 2},
                Array{Float64, 2},
            },
        )
        precompile(Tuple{typeof(Base.:(/)), Base.Complex{Float64}, Int64})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.:(/)), Base.Complex{Float64}, Int64},
        )
        precompile(Tuple{typeof(Base.:(<=)), Float64, Float64})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(<=)), Float64, Float64})
        precompile(
            Tuple{
                typeof(Base.:(==)),
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.:(==)),
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
            },
        )
        precompile(
            Tuple{
                typeof(Base.:(==)),
                Array{Base.Complex{Float64}, 4},
                Array{Base.Complex{Float64}, 4},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.:(==)),
                Array{Base.Complex{Float64}, 4},
                Array{Base.Complex{Float64}, 4},
            },
        )
        precompile(Tuple{typeof(Base.:(==)), Array{Int64, 1}, Array{Int64, 1}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.:(==)),
                Array{Int64, 1},
                Array{Int64, 1},
            },
        )
        precompile(Tuple{typeof(Base.:(==)), Array{Int64, 2}, Array{Int64, 2}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.:(==)),
                Array{Int64, 2},
                Array{Int64, 2},
            },
        )
        precompile(Tuple{typeof(Base.:(==)), Array{UInt64, 1}, Array{UInt64, 1}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.:(==)),
                Array{UInt64, 1},
                Array{UInt64, 1},
            },
        )
        precompile(Tuple{typeof(Base.:(==)), Bool, Bool})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(==)), Bool, Bool})
        precompile(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.:(==)),
                Tuple{Int64, Int64},
                Tuple{Int64, Int64},
            },
        )
        precompile(Tuple{typeof(Base.:(==)), UInt64, UInt64})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(==)), UInt64, UInt64})
        precompile(Tuple{typeof(Base.:(>)), Float64, Float64})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(>)), Float64, Float64})
        precompile(Tuple{typeof(Base.Broadcast.broadcasted), Type{Int64}, Array{Int64, 2}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.Broadcast.broadcasted),
                Type{Int64},
                Array{Int64, 2},
            },
        )
        precompile(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(<)),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.abs),
                    Tuple{Array{Float64, 2}},
                },
                Float64,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(<)),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.abs),
                    Tuple{Array{Float64, 2}},
                },
                Float64,
            },
        )
        precompile(Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.abs), Array{Float64, 2}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.abs),
                Array{Float64, 2},
            },
        )
        precompile(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{Float64, 1, Array{Float64, 1}, Tuple{Array{Int64, 1}}, false},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{0},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Float64},
                },
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{Float64, 1, Array{Float64, 1}, Tuple{Array{Int64, 1}}, false},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{0},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Float64},
                },
            },
        )
        precompile(
            Tuple{
                typeof(Base.Order.lt),
                Base.Order.ForwardOrdering,
                Tuple{Int64, String},
                Tuple{Int64, String},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.Order.lt),
                Base.Order.ForwardOrdering,
                Tuple{Int64, String},
                Tuple{Int64, String},
            },
        )
        precompile(
            Tuple{
                typeof(Base._all),
                Base.Fix2{typeof(Base.:(>)), Int64},
                Array{Int64, 1},
                Base.Colon,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base._all),
                Base.Fix2{typeof(Base.:(>)), Int64},
                Array{Int64, 1},
                Base.Colon,
            },
        )
        precompile(
            Tuple{
                typeof(Base._all),
                typeof(Base.isfinite),
                Array{Base.Complex{Float64}, 3},
                Base.Colon,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base._all),
                typeof(Base.isfinite),
                Array{Base.Complex{Float64}, 3},
                Base.Colon,
            },
        )
        precompile(
            Tuple{
                typeof(Base._all),
                typeof(Base.isfinite),
                Array{Base.Complex{Float64}, 4},
                Base.Colon,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base._all),
                typeof(Base.isfinite),
                Array{Base.Complex{Float64}, 4},
                Base.Colon,
            },
        )
        precompile(Tuple{typeof(Base.add_sum), UInt64, UInt64})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.add_sum), UInt64, UInt64})
        precompile(
            Tuple{
                typeof(Base.adjoint),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.adjoint),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
            },
        )
        precompile(
            Tuple{
                typeof(Base.adjoint),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 4},
                    Tuple{
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Int64,
                        Int64,
                    },
                    true,
                },
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.adjoint),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 4},
                    Tuple{
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Int64,
                        Int64,
                    },
                    true,
                },
            },
        )
        precompile(Tuple{typeof(Base.all), Base.BitArray{2}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.all), Base.BitArray{2}})
        precompile(Tuple{typeof(Base.axes), Array{Base.Complex{Float64}, 2}, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.axes),
                Array{Base.Complex{Float64}, 2},
                Int64,
            },
        )
        precompile(Tuple{typeof(Base.axes), Array{Int64, 3}, Int64})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.axes), Array{Int64, 3}, Int64},
        )
        precompile(Tuple{typeof(Base.collect), Base.KeySet{String, Base.Dict{String, Any}}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.collect),
                Base.KeySet{String, Base.Dict{String, Any}},
            },
        )
        false
        false
        false
        false
        precompile(Tuple{typeof(Base.eachindex), Array{Float64, 1}})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.eachindex), Array{Float64, 1}},
        )
        precompile(Tuple{typeof(Base.empty), Base.Dict{String, String}, Type{String}, Type{Any}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.empty),
                Base.Dict{String, String},
                Type{String},
                Type{Any},
            },
        )
        precompile(Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.falses),
                Int64,
                Int64,
                Vararg{Int64},
            },
        )
        precompile(Tuple{typeof(Base.falses), Tuple{Int64, Int64}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.falses), Tuple{Int64, Int64}})
        precompile(Tuple{typeof(Base.get), Base.Dict{String, Any}, String, Base.Dict{String, Any}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.get),
                Base.Dict{String, Any},
                String,
                Base.Dict{String, Any},
            },
        )
        precompile(Tuple{typeof(Base.get), Base.Dict{String, Any}, String, String})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.get),
                Base.Dict{String, Any},
                String,
                String,
            },
        )
        precompile(Tuple{typeof(Base.get), Base.Dict{String, String}, String, String})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.get),
                Base.Dict{String, String},
                String,
                String,
            },
        )
        precompile(
            Tuple{
                typeof(Base.get),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Tuple{Int64, Int64, Int64},
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.get),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Tuple{Int64, Int64, Int64},
                Int64,
            },
        )
        precompile(Tuple{typeof(Base.getindex), Array{Array{Base.Complex{Float64}, 2}, 1}, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.getindex),
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Int64,
            },
        )
        precompile(Tuple{typeof(Base.getindex), Array{Array{Float64, 1}, 1}, Base.UnitRange{Int64}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.getindex),
                Array{Array{Float64, 1}, 1},
                Base.UnitRange{Int64},
            },
        )
        precompile(Tuple{typeof(Base.getindex), Array{Base.Complex{Float64}, 4}, Vararg{Int64, 4}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.getindex),
                Array{Base.Complex{Float64}, 4},
                Vararg{Int64, 4},
            },
        )
        precompile(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.getindex), Array{Bool, 1}, Int64},
        )
        precompile(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.getindex), Array{Float64, 1}, Int64},
        )
        precompile(Tuple{typeof(Base.getindex), Array{Float64, 2}, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.getindex),
                Array{Float64, 2},
                Int64,
                Int64,
            },
        )
        precompile(Tuple{typeof(Base.getindex), Array{UInt64, 1}, Int64})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.getindex), Array{UInt64, 1}, Int64},
        )
        precompile(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.getindex), Array{UInt8, 1}, Int64},
        )
        precompile(Tuple{typeof(Base.getindex), Type{Int64}, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.getindex),
                Type{Int64},
                Int64,
                Int64,
            },
        )
        precompile(Tuple{typeof(Base.getindex), Type{Int64}, Int64})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.getindex), Type{Int64}, Int64},
        )
        false
        false
        precompile(Tuple{typeof(Base.haskey), Base.Dict{String, String}, String})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.haskey),
                Base.Dict{String, String},
                String,
            },
        )
        precompile(
            Tuple{
                typeof(Base.in!),
                Tuple{Int64, Int64, Int64},
                Base.Set{Tuple{Int64, Int64, Int64}},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.in!),
                Tuple{Int64, Int64, Int64},
                Base.Set{Tuple{Int64, Int64, Int64}},
            },
        )
        precompile(Tuple{typeof(Base.in), String, NTuple{6, String}})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.in), String, NTuple{6, String}},
        )
        precompile(Tuple{typeof(Base.in), String, NTuple{8, String}})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.in), String, NTuple{8, String}},
        )
        precompile(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.in),
                String,
                Tuple{String, String, String},
            },
        )
        precompile(Tuple{typeof(Base.indexed_iterate), Pair{String, Any}, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.indexed_iterate),
                Pair{String, Any},
                Int64,
                Int64,
            },
        )
        precompile(Tuple{typeof(Base.indexed_iterate), Pair{String, Any}, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.indexed_iterate),
                Pair{String, Any},
                Int64,
            },
        )
        precompile(Tuple{typeof(Base.isempty), Base.Dict{String, Any}})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.isempty), Base.Dict{String, Any}},
        )
        precompile(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.iterate),
                Array{Array{String, 1}, 1},
            },
        )
        false
        false
        false
        false
        precompile(Tuple{typeof(Base.iterate), Base.Dict{String, Any}, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.iterate),
                Base.Dict{String, Any},
                Int64,
            },
        )
        precompile(Tuple{typeof(Base.iterate), Base.Dict{String, String}})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.iterate), Base.Dict{String, String}},
        )
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        precompile(Tuple{typeof(Base.keys), Base.Dict{String, Any}})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.keys), Base.Dict{String, Any}},
        )
        precompile(Tuple{typeof(Base.length), Array{Base.Complex{Float64}, 1}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.length),
                Array{Base.Complex{Float64}, 1},
            },
        )
        precompile(Tuple{typeof(Base.length), Array{Int64, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.length), Array{Int64, 1}})
        precompile(Tuple{typeof(Base.length), Array{UInt8, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.length), Array{UInt8, 1}})
        precompile(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.abs),
                typeof(Base.max),
                Float64,
                Array{Base.Complex{Float64}, 2},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.mapfoldl_impl),
                typeof(Base.abs),
                typeof(Base.max),
                Float64,
                Array{Base.Complex{Float64}, 2},
            },
        )
        precompile(Tuple{typeof(Base.max), Float64, Float64})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.max), Float64, Float64})
        precompile(Tuple{typeof(Base.maximum), Array{Float64, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.maximum), Array{Float64, 1}})
        precompile(Tuple{typeof(Base.merge), Base.Dict{String, Any}, Base.Dict{String, Any}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.merge),
                Base.Dict{String, Any},
                Base.Dict{String, Any},
            },
        )
        precompile(Tuple{typeof(Base.merge), Base.Dict{String, String}, Base.Dict{String, String}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.merge),
                Base.Dict{String, String},
                Base.Dict{String, String},
            },
        )
        precompile(Tuple{typeof(Base.minimum), Array{Float64, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.minimum), Array{Float64, 1}})
        precompile(Tuple{typeof(Base.occursin), Base.Regex, String})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.occursin), Base.Regex, String},
        )
        false
        false
        precompile(Tuple{typeof(Base.print), Base.IOStream, Symbol})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.print), Base.IOStream, Symbol},
        )
        precompile(Tuple{typeof(Base.prod), Tuple{Int64}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.prod), Tuple{Int64}})
        precompile(Tuple{typeof(Base.setindex!), Array{Float64, 2}, Float64, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.setindex!),
                Array{Float64, 2},
                Float64,
                Int64,
                Int64,
            },
        )
        precompile(Tuple{typeof(Base.setindex_widen_up_to), Array{Int64, 1}, Nothing, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.setindex_widen_up_to),
                Array{Int64, 1},
                Nothing,
                Int64,
            },
        )
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        precompile(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 3}, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.size),
                Array{Base.Complex{Float64}, 3},
                Int64,
            },
        )
        precompile(Tuple{typeof(Base.size), Array{Float64, 2}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.size), Array{Float64, 2}})
        precompile(Tuple{typeof(Base.size), Array{Int64, 2}, Int64})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.size), Array{Int64, 2}, Int64},
        )
        precompile(Tuple{typeof(Base.size), Array{Int64, 2}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.size), Array{Int64, 2}})
        precompile(Tuple{typeof(Base.size), Base.BitArray{2}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.size), Base.BitArray{2}})
        precompile(Tuple{typeof(Base.sum), Array{Float64, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.sum), Array{Float64, 1}})
        false
        false
        false
        false
        precompile(Tuple{typeof(Base.transpose), Array{Float64, 2}})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.transpose), Array{Float64, 2}},
        )
        precompile(Tuple{typeof(Base.transpose), Array{Int64, 2}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.transpose), Array{Int64, 2}})
        precompile(Tuple{typeof(Base.unique), Array{String, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.unique), Array{String, 1}})
        precompile(Tuple{typeof(Base.vec), Array{Int64, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.vec), Array{Int64, 1}})
        precompile(Tuple{typeof(Base.vec), Array{Int64, 2}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.vec), Array{Int64, 2}})
        precompile(Tuple{typeof(Base.vect), Array{Float64, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.vect), Array{Float64, 1}})
        precompile(Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.vect),
                Array{String, 1},
                Vararg{Array{String, 1}},
            },
        )
        false
        false
        false
        false
        precompile(Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.zeros),
                Type{Float64},
                Int64,
                Int64,
                Vararg{Int64},
            },
        )
        precompile(Tuple{typeof(Base.zeros), Type{Float64}, Tuple{Int64, Int64}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.zeros),
                Type{Float64},
                Tuple{Int64, Int64},
            },
        )
        precompile(Tuple{typeof(LinearAlgebra.norm), Array{Base.Complex{Float64}, 2}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(LinearAlgebra.norm),
                Array{Base.Complex{Float64}, 2},
            },
        )
        @assert !MPI.Initialized()
    end
end
