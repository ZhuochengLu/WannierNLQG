# Actual first-public-call boundaries observed with phase-delimited traces.
# This compiles calls only; no file creation, communicator initialization, or task execution.
@compile_workload let direct_ok=0, bridge_ok=0, direct_failed=0, bridge_failed=0
    if precompile(Tuple{Type{Array{Base.Complex{Float64}, 1}}, Array{Base.Complex{Float64}, 1}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{Base.Complex{Float64}, 1}},
            Array{Base.Complex{Float64}, 1},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{Bool, N} where N},
            UndefInitializer,
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{Float64, N} where N},
            UndefInitializer,
            Int64,
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{Float64, N} where N},
            UndefInitializer,
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), Type{Array{Int64, 1}}, Array{Int64, 1}})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{Int64, N} where N},
            UndefInitializer,
            Int64,
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{Int64, N} where N},
            UndefInitializer,
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Array{Int8, N} where N}, UndefInitializer, Int64, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{Int8, N} where N},
            UndefInitializer,
            Int64,
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Array{String, 1}}, UndefInitializer, Tuple{Int64}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{String, 1}},
            UndefInitializer,
            Tuple{Int64},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{UInt64, N} where N},
            UndefInitializer,
            Int64,
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{UInt64, N} where N},
            UndefInitializer,
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{UInt8, N} where N},
            UndefInitializer,
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{Type{Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}}, UndefInitializer, Int64},
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
            UndefInitializer,
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            Type{Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1}},
            UndefInitializer,
            Tuple{Int64},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1}},
            UndefInitializer,
            Tuple{Int64},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            Type{Base.Iterators.ProductIterator{T} where T <: Tuple},
            NTuple{4, Base.UnitRange{Int64}},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Base.Iterators.ProductIterator{T} where T <: Tuple},
            NTuple{4, Base.UnitRange{Int64}},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Base.Set{NTuple{4, Int64}}}, Tuple{NTuple{4, Int64}}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Base.Set{NTuple{4, Int64}}},
            Tuple{NTuple{4, Int64}},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Base.Set{T} where T}, Array{String, 1}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), Type{Base.Set{T} where T}, Array{String, 1}},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Pair{A, B} where {B} where A},
            Tuple{Int64, Int64, Int64},
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{Type{Tuple}, Array{Int64, 1}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), Type{Tuple}, Array{Int64, 1}})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.:(<=)), Float64, Float64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(<=)), Float64, Float64})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.:(==)), Array{UInt64, 1}, Array{UInt64, 1}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.:(==)),
            Array{UInt64, 1},
            Array{UInt64, 1},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.:(==)), Bool, Bool})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(==)), Bool, Bool})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.:(==)),
            Tuple{Int64, Int64},
            Tuple{Int64, Int64},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.:(==)), UInt64, UInt64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(==)), UInt64, UInt64})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.:(>)), Float64, Float64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(>)), Float64, Float64})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.:(>=)), Float64, Float64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(>=)), Float64, Float64})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.Broadcast.broadcasted), Type{Int64}, Array{Int64, 1}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Broadcast.broadcasted),
            Type{Int64},
            Array{Int64, 1},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.Broadcast.broadcasted),
            typeof(Base.:(+)),
            Array{Base.Complex{Float64}, 5},
            Array{Base.Complex{Float64}, 5},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Broadcast.broadcasted),
            typeof(Base.:(+)),
            Array{Base.Complex{Float64}, 5},
            Array{Base.Complex{Float64}, 5},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.Broadcast.broadcasted),
            typeof(Base.:(-)),
            Array{Float64, 2},
            Array{Float64, 2},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Broadcast.broadcasted),
            typeof(Base.:(-)),
            Array{Float64, 2},
            Array{Float64, 2},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.Broadcast.broadcasted),
            typeof(Base.identity),
            Array{Base.Complex{Float64}, 2},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Broadcast.broadcasted),
            typeof(Base.identity),
            Array{Base.Complex{Float64}, 2},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.Broadcast.materialize!),
            Array{Base.Complex{Float64}, 2},
            Base.Broadcast.Broadcasted{
                Base.Broadcast.DefaultArrayStyle{2},
                Nothing,
                typeof(Base.identity),
                Tuple{Array{Base.Complex{Float64}, 2}},
            },
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Broadcast.materialize!),
            Array{Base.Complex{Float64}, 2},
            Base.Broadcast.Broadcasted{
                Base.Broadcast.DefaultArrayStyle{2},
                Nothing,
                typeof(Base.identity),
                Tuple{Array{Base.Complex{Float64}, 2}},
            },
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.Broadcast.materialize!),
            Array{Base.Complex{Float64}, 5},
            Base.Broadcast.Broadcasted{
                Base.Broadcast.DefaultArrayStyle{5},
                Nothing,
                typeof(Base.:(+)),
                Tuple{Array{Base.Complex{Float64}, 5}, Array{Base.Complex{Float64}, 5}},
            },
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Broadcast.materialize!),
            Array{Base.Complex{Float64}, 5},
            Base.Broadcast.Broadcasted{
                Base.Broadcast.DefaultArrayStyle{5},
                Nothing,
                typeof(Base.:(+)),
                Tuple{Array{Base.Complex{Float64}, 5}, Array{Base.Complex{Float64}, 5}},
            },
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.Broadcast.materialize),
            Base.Broadcast.Broadcasted{
                Base.Broadcast.DefaultArrayStyle{1},
                Nothing,
                Type{Int64},
                Tuple{Array{Int64, 1}},
            },
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Broadcast.materialize),
            Base.Broadcast.Broadcasted{
                Base.Broadcast.DefaultArrayStyle{1},
                Nothing,
                Type{Int64},
                Tuple{Array{Int64, 1}},
            },
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.Broadcast.materialize),
            Base.Broadcast.Broadcasted{
                Base.Broadcast.DefaultArrayStyle{2},
                Nothing,
                typeof(Base.:(-)),
                Tuple{Array{Float64, 2}, Array{Float64, 2}},
            },
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Broadcast.materialize),
            Base.Broadcast.Broadcasted{
                Base.Broadcast.DefaultArrayStyle{2},
                Nothing,
                typeof(Base.:(-)),
                Tuple{Array{Float64, 2}, Array{Float64, 2}},
            },
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{typeof(Base._all), Base.Fix2{typeof(Base.:(>)), Int64}, Array{Int64, 1}, Base.Colon},
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base._all),
            Base.Fix2{typeof(Base.:(>)), Int64},
            Array{Int64, 1},
            Base.Colon,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base._all), typeof(Base.isfinite), Array{Float64, 2}, Base.Colon})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base._all),
            typeof(Base.isfinite),
            Array{Float64, 2},
            Base.Colon,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.collect), Base.KeySet{String, Base.Dict{String, Any}}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.collect),
            Base.KeySet{String, Base.Dict{String, Any}},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.collect), NTuple{4, Int64}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.collect), NTuple{4, Int64}})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.empty),
            Base.Dict{Any, Any},
            Type{Tuple{Int64, Int64, Int64}},
            Type{Int64},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.empty),
            Base.Dict{Any, Any},
            Type{Tuple{Int64, Int64, Int64}},
            Type{Int64},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.fill),
            Base.ReshapedArray{
                Base.Complex{Float64},
                3,
                Base.SubArray{
                    Base.Complex{Float64},
                    1,
                    Base.ReinterpretArray{Base.Complex{Float64}, 1, UInt8, Array{UInt8, 1}, false},
                    Tuple{Base.UnitRange{Int64}},
                    true,
                },
                Tuple{},
            },
            Int64,
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.fill),
            Base.ReshapedArray{
                Base.Complex{Float64},
                3,
                Base.SubArray{
                    Base.Complex{Float64},
                    1,
                    Base.ReinterpretArray{Base.Complex{Float64}, 1, UInt8, Array{UInt8, 1}, false},
                    Tuple{Base.UnitRange{Int64}},
                    true,
                },
                Tuple{},
            },
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.getindex),
            Array{Base.Complex{Float64}, 5},
            Base.IteratorsMD.CartesianIndex{5},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.getindex),
            Array{Base.Complex{Float64}, 5},
            Base.IteratorsMD.CartesianIndex{5},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.getindex), Array{Bool, 1}, Int64},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.getindex), Array{Float64, 1}, Int64},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.getindex), Array{NTuple{4, Int64}, 1}, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.getindex),
            Array{NTuple{4, Int64}, 1},
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.getindex), Array{UInt64, 1}, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.getindex), Array{UInt64, 1}, Int64},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.getindex), Array{UInt8, 1}, Int64},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.getindex), Type{NTuple{4, Int64}}, NTuple{4, Int64}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.getindex),
            Type{NTuple{4, Int64}},
            NTuple{4, Int64},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.getindex),
            Type{WannierNLQG.Core.RealSpaceOperatorKind},
            Vararg{WannierNLQG.Core.RealSpaceOperatorKind, 6},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.getindex),
            Type{WannierNLQG.Core.RealSpaceOperatorKind},
            Vararg{WannierNLQG.Core.RealSpaceOperatorKind, 6},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.haskey),
            Base.Dict{Base.PkgId, Module},
            Base.PkgId,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.in),
            String,
            Tuple{String, String, String},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.iterate), Array{Array{String, 1}, 1}},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Iterators.ProductIterator{NTuple{4, Base.UnitRange{Int64}}},
            NTuple{4, Tuple{Int64, Int64}},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.iterate),
            Base.Iterators.ProductIterator{NTuple{4, Base.UnitRange{Int64}}},
            NTuple{4, Tuple{Int64, Int64}},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Iterators.ProductIterator{NTuple{4, Base.UnitRange{Int64}}},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.iterate),
            Base.Iterators.ProductIterator{NTuple{4, Base.UnitRange{Int64}}},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.join), Tuple{Int64, Int64, Int64}, Char})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.join), Tuple{Int64, Int64, Int64}, Char},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.keys), Base.Dict{String, Any}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.keys), Base.Dict{String, Any}})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.length), Array{Float64, 1}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.length), Array{Float64, 1}})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.length), Array{Int64, 1}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.length), Array{Int64, 1}})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.length), Array{NTuple{4, Int64}, 1}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.length), Array{NTuple{4, Int64}, 1}},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.length), Array{UInt8, 1}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.length), Array{UInt8, 1}})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.mapfoldl_impl),
            typeof(Base.abs),
            typeof(Base.max),
            Float64,
            Array{Float64, 2},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.mapfoldl_impl),
            typeof(Base.abs),
            typeof(Base.max),
            Float64,
            Array{Float64, 2},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{
                (:denominator_regularization, :degeneracy_threshold),
                Tuple{Float64, Float64},
            },
            NamedTuple{
                (:broadening, :broadening_type, :transition_window_factor, :band_window_size),
                Tuple{Float64, String, Float64, Int64},
            },
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{
                (:denominator_regularization, :degeneracy_threshold),
                Tuple{Float64, Float64},
            },
            NamedTuple{
                (:broadening, :broadening_type, :transition_window_factor, :band_window_size),
                Tuple{Float64, String, Float64, Int64},
            },
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                },
            },
            NamedTuple{(:k_mesh, :spatial_dimension), Tuple{Tuple{Int64, Int64}, Int64}},
            NamedTuple{
                (
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                ),
                Tuple{String, Nothing, Nothing, Nothing, String, String, Bool},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                },
            },
            NamedTuple{(:k_mesh, :spatial_dimension), Tuple{Tuple{Int64, Int64}, Int64}},
            NamedTuple{
                (
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                ),
                Tuple{String, Nothing, Nothing, Nothing, String, String, Bool},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                },
            },
            NamedTuple{
                (:k_mesh, :spatial_dimension, :kslice_origin, :kslice_vector_1, :kslice_vector_2),
                Tuple{
                    Tuple{Int64, Int64},
                    Int64,
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                },
            },
            NamedTuple{
                (
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                ),
                Tuple{String, Nothing, Nothing, Nothing, String, String, Bool},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                },
            },
            NamedTuple{
                (:k_mesh, :spatial_dimension, :kslice_origin, :kslice_vector_1, :kslice_vector_2),
                Tuple{
                    Tuple{Int64, Int64},
                    Int64,
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                },
            },
            NamedTuple{
                (
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                ),
                Tuple{String, Nothing, Nothing, Nothing, String, String, Bool},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                },
            },
            NamedTuple{
                (
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                ),
                Tuple{String, Nothing, Nothing, Nothing, String, String, Bool},
            },
            NamedTuple{
                (
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                ),
                Tuple{String, String, Int64, Bool, Int64, String},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                },
            },
            NamedTuple{
                (
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                ),
                Tuple{String, Nothing, Nothing, Nothing, String, String, Bool},
            },
            NamedTuple{
                (
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                ),
                Tuple{String, String, Int64, Bool, Int64, String},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                },
            },
            NamedTuple{
                (
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                ),
                Tuple{String, String, Int64, Bool, Int64, String},
            },
            NamedTuple{
                (:tensor_indices, :band_selection, :include_occupied_sum),
                Tuple{NTuple{4, Int64}, Int64, Bool},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                },
            },
            NamedTuple{
                (
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                ),
                Tuple{String, String, Int64, Bool, Int64, String},
            },
            NamedTuple{
                (:tensor_indices, :band_selection, :include_occupied_sum),
                Tuple{NTuple{4, Int64}, Int64, Bool},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Int64,
                    Bool,
                    Int64,
                    String,
                },
            },
            NamedTuple{
                (:tensor_indices, :band_selection, :include_occupied_sum),
                Tuple{NTuple{4, Int64}, Int64, Bool},
            },
            NamedTuple{
                (:photon_energies, :fermi_energy, :temperature, :photon_momentum),
                Tuple{Array{Float64, 1}, Float64, Float64, Tuple{Float64, Float64, Float64}},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Int64,
                    Bool,
                    Int64,
                    String,
                },
            },
            NamedTuple{
                (:tensor_indices, :band_selection, :include_occupied_sum),
                Tuple{NTuple{4, Int64}, Int64, Bool},
            },
            NamedTuple{
                (:photon_energies, :fermi_energy, :temperature, :photon_momentum),
                Tuple{Array{Float64, 1}, Float64, Float64, Tuple{Float64, Float64, Float64}},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                    :tensor_indices,
                    :band_selection,
                    :include_occupied_sum,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Int64,
                    Bool,
                    Int64,
                    String,
                    NTuple{4, Int64},
                    Int64,
                    Bool,
                },
            },
            NamedTuple{
                (:photon_energies, :fermi_energy, :temperature, :photon_momentum),
                Tuple{Array{Float64, 1}, Float64, Float64, Tuple{Float64, Float64, Float64}},
            },
            NamedTuple{
                (
                    :denominator_regularization,
                    :degeneracy_threshold,
                    :finite_difference_step,
                    :band_window_size,
                    :broadening,
                    :broadening_type,
                    :transition_window_factor,
                ),
                Tuple{Float64, Float64, Float64, Int64, Float64, String, Float64},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                    :tensor_indices,
                    :band_selection,
                    :include_occupied_sum,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Int64,
                    Bool,
                    Int64,
                    String,
                    NTuple{4, Int64},
                    Int64,
                    Bool,
                },
            },
            NamedTuple{
                (:photon_energies, :fermi_energy, :temperature, :photon_momentum),
                Tuple{Array{Float64, 1}, Float64, Float64, Tuple{Float64, Float64, Float64}},
            },
            NamedTuple{
                (
                    :denominator_regularization,
                    :degeneracy_threshold,
                    :finite_difference_step,
                    :band_window_size,
                    :broadening,
                    :broadening_type,
                    :transition_window_factor,
                ),
                Tuple{Float64, Float64, Float64, Int64, Float64, String, Float64},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                    :tensor_indices,
                    :band_selection,
                    :include_occupied_sum,
                    :photon_energies,
                    :fermi_energy,
                    :temperature,
                    :photon_momentum,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Int64,
                    Bool,
                    Int64,
                    String,
                    NTuple{4, Int64},
                    Int64,
                    Bool,
                    Array{Float64, 1},
                    Float64,
                    Float64,
                    Tuple{Float64, Float64, Float64},
                },
            },
            NamedTuple{
                (
                    :denominator_regularization,
                    :degeneracy_threshold,
                    :finite_difference_step,
                    :band_window_size,
                    :broadening,
                    :broadening_type,
                    :transition_window_factor,
                ),
                Tuple{Float64, Float64, Float64, Int64, Float64, String, Float64},
            },
            NamedTuple{
                (:tasks, :output_root),
                Tuple{Array{Tuple{String, String, String}, 1}, String},
            },
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                    :tensor_indices,
                    :band_selection,
                    :include_occupied_sum,
                    :photon_energies,
                    :fermi_energy,
                    :temperature,
                    :photon_momentum,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Int64,
                    Bool,
                    Int64,
                    String,
                    NTuple{4, Int64},
                    Int64,
                    Bool,
                    Array{Float64, 1},
                    Float64,
                    Float64,
                    Tuple{Float64, Float64, Float64},
                },
            },
            NamedTuple{
                (
                    :denominator_regularization,
                    :degeneracy_threshold,
                    :finite_difference_step,
                    :band_window_size,
                    :broadening,
                    :broadening_type,
                    :transition_window_factor,
                ),
                Tuple{Float64, Float64, Float64, Int64, Float64, String, Float64},
            },
            NamedTuple{
                (:tasks, :output_root),
                Tuple{Array{Tuple{String, String, String}, 1}, String},
            },
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :kslice_origin,
                    :kslice_vector_1,
                    :kslice_vector_2,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                },
            },
            NamedTuple{
                (
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                ),
                Tuple{String, Nothing, Nothing, Nothing, String, String, Bool},
            },
            NamedTuple{
                (
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                ),
                Tuple{String, String, Int64, Bool, Int64, String},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :kslice_origin,
                    :kslice_vector_1,
                    :kslice_vector_2,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                },
            },
            NamedTuple{
                (
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                ),
                Tuple{String, Nothing, Nothing, Nothing, String, String, Bool},
            },
            NamedTuple{
                (
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                ),
                Tuple{String, String, Int64, Bool, Int64, String},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :kslice_origin,
                    :kslice_vector_1,
                    :kslice_vector_2,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                },
            },
            NamedTuple{
                (
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                ),
                Tuple{String, String, Int64, Bool, Int64, String},
            },
            NamedTuple{
                (:tensor_indices, :band_selection, :include_occupied_sum),
                Tuple{NTuple{4, Int64}, Tuple{Array{Int64, 1}, Array{Int64, 1}}, Bool},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :kslice_origin,
                    :kslice_vector_1,
                    :kslice_vector_2,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                },
            },
            NamedTuple{
                (
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                ),
                Tuple{String, String, Int64, Bool, Int64, String},
            },
            NamedTuple{
                (:tensor_indices, :band_selection, :include_occupied_sum),
                Tuple{NTuple{4, Int64}, Tuple{Array{Int64, 1}, Array{Int64, 1}}, Bool},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :kslice_origin,
                    :kslice_vector_1,
                    :kslice_vector_2,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Int64,
                    Bool,
                    Int64,
                    String,
                },
            },
            NamedTuple{
                (:tensor_indices, :band_selection, :include_occupied_sum),
                Tuple{NTuple{4, Int64}, Tuple{Array{Int64, 1}, Array{Int64, 1}}, Bool},
            },
            NamedTuple{
                (:photon_energies, :fermi_energy, :temperature, :photon_momentum),
                Tuple{Array{Float64, 1}, Float64, Float64, Tuple{Float64, Float64, Float64}},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :kslice_origin,
                    :kslice_vector_1,
                    :kslice_vector_2,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Int64,
                    Bool,
                    Int64,
                    String,
                },
            },
            NamedTuple{
                (:tensor_indices, :band_selection, :include_occupied_sum),
                Tuple{NTuple{4, Int64}, Tuple{Array{Int64, 1}, Array{Int64, 1}}, Bool},
            },
            NamedTuple{
                (:photon_energies, :fermi_energy, :temperature, :photon_momentum),
                Tuple{Array{Float64, 1}, Float64, Float64, Tuple{Float64, Float64, Float64}},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :kslice_origin,
                    :kslice_vector_1,
                    :kslice_vector_2,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                    :tensor_indices,
                    :band_selection,
                    :include_occupied_sum,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Int64,
                    Bool,
                    Int64,
                    String,
                    NTuple{4, Int64},
                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                    Bool,
                },
            },
            NamedTuple{
                (:photon_energies, :fermi_energy, :temperature, :photon_momentum),
                Tuple{Array{Float64, 1}, Float64, Float64, Tuple{Float64, Float64, Float64}},
            },
            NamedTuple{
                (
                    :denominator_regularization,
                    :degeneracy_threshold,
                    :finite_difference_step,
                    :band_window_size,
                    :broadening,
                    :broadening_type,
                    :transition_window_factor,
                ),
                Tuple{Float64, Float64, Float64, Int64, Float64, String, Float64},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :kslice_origin,
                    :kslice_vector_1,
                    :kslice_vector_2,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                    :tensor_indices,
                    :band_selection,
                    :include_occupied_sum,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Int64,
                    Bool,
                    Int64,
                    String,
                    NTuple{4, Int64},
                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                    Bool,
                },
            },
            NamedTuple{
                (:photon_energies, :fermi_energy, :temperature, :photon_momentum),
                Tuple{Array{Float64, 1}, Float64, Float64, Tuple{Float64, Float64, Float64}},
            },
            NamedTuple{
                (
                    :denominator_regularization,
                    :degeneracy_threshold,
                    :finite_difference_step,
                    :band_window_size,
                    :broadening,
                    :broadening_type,
                    :transition_window_factor,
                ),
                Tuple{Float64, Float64, Float64, Int64, Float64, String, Float64},
            },
            Vararg{NamedTuple{names, T} where {T <: Tuple} where names},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :kslice_origin,
                    :kslice_vector_1,
                    :kslice_vector_2,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                    :tensor_indices,
                    :band_selection,
                    :include_occupied_sum,
                    :photon_energies,
                    :fermi_energy,
                    :temperature,
                    :photon_momentum,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Int64,
                    Bool,
                    Int64,
                    String,
                    NTuple{4, Int64},
                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                    Bool,
                    Array{Float64, 1},
                    Float64,
                    Float64,
                    Tuple{Float64, Float64, Float64},
                },
            },
            NamedTuple{
                (
                    :denominator_regularization,
                    :degeneracy_threshold,
                    :finite_difference_step,
                    :band_window_size,
                    :broadening,
                    :broadening_type,
                    :transition_window_factor,
                ),
                Tuple{Float64, Float64, Float64, Int64, Float64, String, Float64},
            },
            NamedTuple{
                (:tasks, :output_root),
                Tuple{Array{Tuple{String, String, String}, 1}, String},
            },
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{
                (
                    :model_file,
                    :real_space_operator_bundle_file,
                    :seedname,
                    :case_root,
                    :wannier_center_convention,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :spin_enabled,
                    :spin_file,
                    :checkpoint_file,
                    :spin_file_formatted,
                    :k_mesh,
                    :spatial_dimension,
                    :kslice_origin,
                    :kslice_vector_1,
                    :kslice_vector_2,
                    :fourier_backend,
                    :NKdiv,
                    :NKFFT,
                    :response_symmetry_file,
                    :response_symmetry_policy,
                    :response_symmetry_kmesh_mode,
                    :response_symmetry_report_enabled,
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                    :tensor_indices,
                    :band_selection,
                    :include_occupied_sum,
                    :photon_energies,
                    :fermi_energy,
                    :temperature,
                    :photon_momentum,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    Tuple{Float64, Float64, Float64},
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Int64,
                    Bool,
                    Int64,
                    String,
                    NTuple{4, Int64},
                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                    Bool,
                    Array{Float64, 1},
                    Float64,
                    Float64,
                    Tuple{Float64, Float64, Float64},
                },
            },
            NamedTuple{
                (
                    :denominator_regularization,
                    :degeneracy_threshold,
                    :finite_difference_step,
                    :band_window_size,
                    :broadening,
                    :broadening_type,
                    :transition_window_factor,
                ),
                Tuple{Float64, Float64, Float64, Int64, Float64, String, Float64},
            },
            NamedTuple{
                (:tasks, :output_root),
                Tuple{Array{Tuple{String, String, String}, 1}, String},
            },
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.occursin), Base.Regex, String})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.occursin), Base.Regex, String})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.pairs), Base.Dict{String, Any}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.pairs), Base.Dict{String, Any}},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.prod), Tuple{Int64}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.prod), Tuple{Int64}})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.reinterpret), Type{UInt8}, Array{Float64, 1}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.reinterpret),
            Type{UInt8},
            Array{Float64, 1},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.repr),
            NamedTuple{
                (
                    :backend,
                    :NKdiv,
                    :NKFFT,
                    :factor_source,
                    :estimated_memory_bytes,
                    :memory_limit_bytes,
                    :load_imbalance,
                    :blocks_per_rank,
                    :kpoints_per_rank,
                    :task_signatures,
                    :union_capabilities,
                    :union_fourier_groups,
                    :union_offset_signatures,
                    :union_group_offset_counts,
                    :groups,
                    :offset_count,
                    :cache_entries,
                    :allocated_bytes,
                    :allocated_memory_limit_bytes,
                    :pack_seconds,
                    :fft_seconds,
                    :extract_seconds,
                    :fft_calls,
                    :cache_hits,
                    :evictions,
                ),
                Tuple{
                    Symbol,
                    Nothing,
                    Nothing,
                    Symbol,
                    Int64,
                    Int64,
                    Float64,
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{String, 1},
                    Array{Symbol, 1},
                    Array{Symbol, 1},
                    Array{String, 1},
                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                    Array{String, 1},
                    Int64,
                    Int64,
                    Int64,
                    Int64,
                    Float64,
                    Float64,
                    Float64,
                    Int64,
                    Int64,
                    Int64,
                },
            },
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.repr),
            NamedTuple{
                (
                    :backend,
                    :NKdiv,
                    :NKFFT,
                    :factor_source,
                    :estimated_memory_bytes,
                    :memory_limit_bytes,
                    :load_imbalance,
                    :blocks_per_rank,
                    :kpoints_per_rank,
                    :task_signatures,
                    :union_capabilities,
                    :union_fourier_groups,
                    :union_offset_signatures,
                    :union_group_offset_counts,
                    :groups,
                    :offset_count,
                    :cache_entries,
                    :allocated_bytes,
                    :allocated_memory_limit_bytes,
                    :pack_seconds,
                    :fft_seconds,
                    :extract_seconds,
                    :fft_calls,
                    :cache_hits,
                    :evictions,
                ),
                Tuple{
                    Symbol,
                    Nothing,
                    Nothing,
                    Symbol,
                    Int64,
                    Int64,
                    Float64,
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{String, 1},
                    Array{Symbol, 1},
                    Array{Symbol, 1},
                    Array{String, 1},
                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                    Array{String, 1},
                    Int64,
                    Int64,
                    Int64,
                    Int64,
                    Float64,
                    Float64,
                    Float64,
                    Int64,
                    Int64,
                    Int64,
                },
            },
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.reverse), NTuple{4, Base.UnitRange{Int64}}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.reverse),
            NTuple{4, Base.UnitRange{Int64}},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.reverse), NTuple{4, Int64}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.reverse), NTuple{4, Int64}})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.setindex!),
            Array{
                Base.ReshapedArray{
                    Base.Complex{Float64},
                    3,
                    Base.SubArray{
                        Base.Complex{Float64},
                        1,
                        Base.ReinterpretArray{
                            Base.Complex{Float64},
                            1,
                            UInt8,
                            Array{UInt8, 1},
                            false,
                        },
                        Tuple{Base.UnitRange{Int64}},
                        true,
                    },
                    Tuple{},
                },
                1,
            },
            Base.ReshapedArray{
                Base.Complex{Float64},
                3,
                Base.SubArray{
                    Base.Complex{Float64},
                    1,
                    Base.ReinterpretArray{Base.Complex{Float64}, 1, UInt8, Array{UInt8, 1}, false},
                    Tuple{Base.UnitRange{Int64}},
                    true,
                },
                Tuple{},
            },
            Int64,
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.setindex!),
            Array{
                Base.ReshapedArray{
                    Base.Complex{Float64},
                    3,
                    Base.SubArray{
                        Base.Complex{Float64},
                        1,
                        Base.ReinterpretArray{
                            Base.Complex{Float64},
                            1,
                            UInt8,
                            Array{UInt8, 1},
                            false,
                        },
                        Tuple{Base.UnitRange{Int64}},
                        true,
                    },
                    Tuple{},
                },
                1,
            },
            Base.ReshapedArray{
                Base.Complex{Float64},
                3,
                Base.SubArray{
                    Base.Complex{Float64},
                    1,
                    Base.ReinterpretArray{Base.Complex{Float64}, 1, UInt8, Array{UInt8, 1}, false},
                    Tuple{Base.UnitRange{Int64}},
                    true,
                },
                Tuple{},
            },
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.setindex!),
            Array{Tuple{Int64, Int64, Int64}, 1},
            Tuple{Int64, Int64, Int64},
            Int64,
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.setindex!),
            Array{Tuple{Int64, Int64, Int64}, 1},
            Tuple{Int64, Int64, Int64},
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{typeof(Base.setindex!), Array{Tuple{Int8, Int8}, 1}, Tuple{Int8, Int8}, Int64},
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.setindex!),
            Array{Tuple{Int8, Int8}, 1},
            Tuple{Int8, Int8},
            Int64,
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.size), Array{Float64, 2}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.size), Array{Float64, 2}})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.size), Array{Int64, 2}, Int64})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.size), Array{Int64, 2}, Int64})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(
        Tuple{
            typeof(Base.size),
            Base.ReshapedArray{
                Base.Complex{Float64},
                3,
                Base.SubArray{
                    Base.Complex{Float64},
                    1,
                    Base.ReinterpretArray{Base.Complex{Float64}, 1, UInt8, Array{UInt8, 1}, false},
                    Tuple{Base.UnitRange{Int64}},
                    true,
                },
                Tuple{},
            },
        },
    )
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.size),
            Base.ReshapedArray{
                Base.Complex{Float64},
                3,
                Base.SubArray{
                    Base.Complex{Float64},
                    1,
                    Base.ReinterpretArray{Base.Complex{Float64}, 1, UInt8, Array{UInt8, 1}, false},
                    Tuple{Base.UnitRange{Int64}},
                    true,
                },
                Tuple{},
            },
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.strip), String})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.strip), String})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.sym_in), Symbol, NTuple{19, Symbol}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.sym_in), Symbol, NTuple{19, Symbol}},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.sym_in), Symbol, NTuple{26, Symbol}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.sym_in), Symbol, NTuple{26, Symbol}},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.sym_in), Symbol, NTuple{35, Symbol}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.sym_in), Symbol, NTuple{35, Symbol}},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.sym_in), Symbol, NTuple{39, Symbol}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.sym_in), Symbol, NTuple{39, Symbol}},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.sym_in), Symbol, NTuple{46, Symbol}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.sym_in), Symbol, NTuple{46, Symbol}},
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.vec), Array{Float64, 2}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.vec), Array{Float64, 2}})
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if precompile(Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}})
        direct_ok += 1
    else
        direct_failed += 1
    end
    if precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.vect),
            Array{String, 1},
            Vararg{Array{String, 1}},
        },
    )
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    if false
        direct_ok += 1
    else
        direct_failed += 1
    end
    if false
        bridge_ok += 1
    else
        bridge_failed += 1
    end
    @info "CALL_BOUNDARY_COVERAGE" direct_ok bridge_ok direct_failed bridge_failed
    @assert !MPI.Initialized()
end
