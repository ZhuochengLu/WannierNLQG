# Observed external signatures from one real four-star Standard public call.
# Optional extension only; no scientific task, output or MPI lifecycle at cache build.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_precompile(Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}})
        _record_precompile(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
        _record_precompile(
            Tuple{
                typeof(Base.issorted),
                Array{String, 1},
                Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
            },
        )
        _record_precompile(Tuple{typeof(Base.setindex!), Base.EnvDict, String, String})
        _record_precompile(Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId})
        false
        false
        false
        _record_precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
        _record_precompile(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties},
        )
        _record_precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties})
        _record_precompile(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties},
        )
        _record_precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties})
        _record_precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties})
        _record_precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties})
        _record_precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties})
        _record_precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties})
        _record_precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties})
        _record_precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties})
        _record_precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties})
        _record_precompile(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties},
        )
        _record_precompile(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties},
        )
        _record_precompile(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties},
        )
        _record_precompile(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties},
        )
        _record_precompile(Tuple{typeof(Base.length), Base.UnitRange{Int64}})
        _record_precompile(Tuple{typeof(Base.in), Int64, Tuple{Int64, Int64}})
        _record_precompile(
            Tuple{typeof(Base.empty), Base.Dict{Any, Any}, Type{String}, Type{String}},
        )
        _record_precompile(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.print),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Char,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Nothing,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Bool,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Int64,
            },
        )
        false
        false
        false
        false
        false
        _record_precompile(Tuple{typeof(Base.add_sum), UInt64, UInt64})
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{(:directory, :vectors), Tuple{String, Array{Any, 1}}},
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:prefix, :cleanup), Tuple{String, Bool}},
                typeof(Base.Filesystem.mktempdir),
                String,
            },
        )
        _record_precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        _record_precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        _record_precompile(Tuple{typeof(Base.size), Array{Int64, 2}})
        _record_precompile(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        _record_precompile(
            Tuple{Type{Array{Int64, 2}}, LinearAlgebra.Transpose{Int64, Array{Int64, 2}}},
        )
        _record_precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
        _record_precompile(
            Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 1}},
        )
        _record_precompile(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{Float64},
                    Tuple{Array{Float64, 1}},
                },
            },
        )
        _record_precompile(Tuple{typeof(Base.transpose), Array{Float64, 1}})
        _record_precompile(Tuple{typeof(Base.length), Array{Float64, 1}})
        _record_precompile(Tuple{typeof(Base.collect), Base.UnitRange{Int64}})
        _record_precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64})
        _record_precompile(Tuple{typeof(Base.size), Array{Float64, 2}})
        _record_precompile(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
        _record_precompile(Tuple{typeof(Base.isfinite), Float64})
        _record_precompile(Tuple{typeof(Base.length), Array{Int64, 1}})
        _record_precompile(
            Tuple{typeof(Base.zeros), Type{Base.Complex{Float64}}, Int64, Int64, Vararg{Int64}},
        )
        _record_precompile(
            Tuple{typeof(Base.reshape), Array{Base.Complex{Float64}, 1}, Int64, Int64},
        )
        _record_precompile(Tuple{Type{Pair{A, B} where {B} where A}, NTuple{9, Int64}, Int64})
        _record_precompile(Tuple{Type{Base.KeyError}, String})
        _record_precompile(Tuple{typeof(Base.literal_pow), typeof(Base.:(^)), Int64, Base.Val{2}})
        _record_precompile(Tuple{typeof(Base.maximum), Array{Int64, 1}})
        _record_precompile(Tuple{typeof(Base.prod), Tuple{Int64, Int64, Int64}})
        _record_precompile(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_precompile(
            Tuple{
                Type{LinearAlgebra.Diagonal{T, V} where {V <: AbstractArray{T, 1}} where T},
                Array{Float64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.push!),
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_precompile(Tuple{Type{Array{Float64, 1}}, UndefInitializer, Int64})
        _record_precompile(Tuple{typeof(Base.prod), Tuple{Int64, Int64}})
        _record_precompile(
            Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Tuple{Int64, Int64}},
        )
        _record_precompile(Tuple{typeof(Base.read!), Base.IOStream, Array{Int64, 2}})
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_precompile(Tuple{typeof(Base.isempty), Array{Int64, 1}})
        false
        _record_precompile(
            Tuple{
                typeof(Base.to_indices),
                Array{Base.Complex{Float64}, 3},
                Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}, Base.OneTo{Int64}},
                Tuple{Array{Int64, 1}, Base.Colon, Base.Colon},
            },
        )
        _record_precompile(Tuple{typeof(Base.:(<=)), Float64, Float64})
        _record_precompile(Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}})
        _record_precompile(Tuple{typeof(Base.zeros), Type{Float64}, Int64})
        false
        false
        _record_precompile(Tuple{typeof(Base.zeros), Type{Int64}, Int64})
        _record_precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Float64})
        _record_precompile(Tuple{typeof(Base.repr), Tuple{Int64, Int64, Int64}})
        _record_precompile(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Int64, Int64, Int64},
            },
        )
        false
        _record_precompile(Tuple{typeof(Base.copy), Base.Dict{String, String}})
        _record_precompile(Tuple{typeof(Base.:(<=)), Int64, UInt64})
        _record_precompile(
            Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64},
        )
        _record_precompile(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Tuple{Int64, Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.:(*)),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Array{Base.Complex{Float64}, 2}},
                },
            },
        )
        _record_precompile(
            Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.identity), Array{Float64, 1}},
        )
        _record_precompile(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{
                    Float64,
                    1,
                    Array{Float64, 2},
                    Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                    true,
                },
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Array{Float64, 1}},
                },
            },
        )
        _record_precompile(Tuple{typeof(Base.length), Array{Array{Base.Complex{Float64}, 3}, 1}})
        _record_precompile(
            Tuple{typeof(Base.getindex), Array{Array{Base.Complex{Float64}, 3}, 1}, Int64},
        )
        _record_precompile(
            Tuple{
                Type{Array{Base.Complex{Float64}, 2}},
                LinearAlgebra.UniformScaling{Bool},
                Int64,
                Int64,
            },
        )
        _record_precompile(Tuple{typeof(Base.view), Array{Int64, 3}, Function, Int64, Int64})
        _record_precompile(
            Tuple{
                typeof(Base.Broadcast.materialize!),
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
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Array{Base.Complex{Float64}, 2}},
                },
            },
        )
        _record_precompile(Tuple{typeof(Base.getindex), Array{Base.BitArray{1}, 1}, Int64})
        _record_precompile(
            Tuple{
                typeof(Base._getindex),
                Base.IndexLinear,
                Array{Base.Complex{Float64}, 3},
                Array{Int64, 1},
                Base.Slice{Base.OneTo{Int64}},
                Vararg{Base.Slice{Base.OneTo{Int64}}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.checkbounds),
                Array{Base.Complex{Float64}, 3},
                Array{Int64, 1},
                Base.Slice{Base.OneTo{Int64}},
                Base.Slice{Base.OneTo{Int64}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base._maybe_reshape),
                Base.IndexLinear,
                Array{Base.Complex{Float64}, 3},
                Array{Int64, 1},
                Vararg{Any},
            },
        )
        _record_precompile(
            Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.:(!)), Base.BitArray{1}},
        )
        _record_precompile(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.:(!)),
                    Tuple{Base.BitArray{1}},
                },
            },
        )
        _record_precompile(Tuple{typeof(Base.getindex), Type{Int64}, Int64})
        false
        _record_precompile(Tuple{typeof(Base.:(&)), Int64, Int64})
        false
        _record_precompile(
            Tuple{
                typeof(Base.view),
                Array{Base.Complex{Float64}, 2},
                Array{Int64, 1},
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_precompile(Tuple{typeof(Base.sqrt), Int64})
        _record_precompile(
            Tuple{
                typeof(Base.maybeview),
                Array{Base.Complex{Float64}, 4},
                Array{Int64, 1},
                Array{Int64, 1},
                Vararg{Any},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.view),
                Array{Base.Complex{Float64}, 4},
                Array{Int64, 1},
                Array{Int64, 1},
                Int64,
                Int64,
            },
        )
        _record_precompile(Tuple{typeof(Base.adjoint), Array{Base.Complex{Float64}, 2}})
        _record_precompile(
            Tuple{
                typeof(Base.:(*)),
                LinearAlgebra.Adjoint{Base.Complex{Float64}, Array{Base.Complex{Float64}, 2}},
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                LinearAlgebra.Adjoint{Base.Complex{Float64}, Array{Base.Complex{Float64}, 2}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                NTuple{7, String},
                Char,
            },
        )
        _record_precompile(Tuple{typeof(Base.add_sum), Int64, Int64})
        _record_precompile(
            Tuple{
                Base.MappingRF{typeof(JSON3.defaultminimum), Base.BottomRF{typeof(Base.add_sum)}},
                Int64,
                Int64,
            },
        )
        _record_precompile(Tuple{typeof(Base.StringVector), Int64})
        _record_precompile(
            Tuple{
                typeof(JSON3.write),
                StructTypes.DictType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Base.Dict{String, Any},
            },
        )
        _record_precompile(Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64})
        _record_precompile(Tuple{Type{String}, Array{UInt8, 1}})
        _record_precompile(Tuple{typeof(Base.getindex), Base.Dict{String, String}, String})
        _record_precompile(Tuple{typeof(Base.size), Array{Float64, 2}, Int64})
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                Array{Base.Complex{Float64}, 3},
                Base.UnitRange{Int64},
                Function,
                Function,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.to_indices),
                Array{Base.Complex{Float64}, 3},
                Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}, Base.OneTo{Int64}},
                Tuple{Base.UnitRange{Int64}, Base.Colon, Base.Colon},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                Array{Base.Complex{Float64}, 2},
                Function,
                Base.UnitRange{Int64},
            },
        )
        _record_precompile(Tuple{typeof(Base.getindex), Array{Float64, 1}, Base.UnitRange{Int64}})
        _record_precompile(
            Tuple{
                typeof(Base._array_for),
                Type{Array{Float64, 1}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.view),
                Array{Base.Complex{Float64}, 2},
                Base.UnitRange{Int64},
                Base.UnitRange{Int64},
            },
        )
        _record_precompile(
            Tuple{
                Type{Array{T, 2} where T},
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 2},
                    Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}},
                    false,
                },
            },
        )
        _record_precompile(Tuple{typeof(Base.:(*)), Float64, Float64})
        _record_precompile(Tuple{typeof(Base.cis), Float64})
        _record_precompile(Tuple{typeof(Base.:(*)), Int64, Base.Complex{Float64}})
        false
        false
        _record_precompile(Tuple{typeof(Base.setindex!), Array{Float64, 1}, Float64, Int64})
        _record_precompile(Tuple{typeof(Base.:(>)), Float64, Float64})
        false
        false
        false
        false
        false
        false
        _record_precompile(
            Tuple{typeof(Base.zeros), Type{Base.Complex{Float64}}, Tuple{Int64, Int64}},
        )
        false
        false
        false
        false
        _record_precompile(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Int64, 1},
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
        _record_precompile(Tuple{typeof(Base.argmax), Array{Float64, 1}})
        _record_precompile(Tuple{typeof(Base.getindex), Base.UnitRange{Int64}, Int64})
        false
        _record_precompile(Tuple{typeof(Base.:(/)), Float64, Int64})
        _record_precompile(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{String, Any},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Array{Int64, 1}},
                    Pair{String, Array{Int64, 1}},
                    Pair{String, Int64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, Float64}},
                    Pair{String, Base.Dict{String, String}},
                    Pair{String, Base.Dict{String, Float64}},
                    Pair{String, Base.Dict{String, String}},
                    Pair{String, String},
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{typeof(Base.copy), GenericMemory{:not_atomic, Int64, Core.AddrSpace{Core}(0x00)}},
        )
        _record_precompile(Tuple{typeof(Base.get), Base.Dict{String, Float64}, String, Float64})
        _record_precompile(Tuple{typeof(Base.:(>=)), Float64, Float64})
        _record_precompile(Tuple{typeof(Base.:(>)), Float64, Int64})
        _record_precompile(Tuple{typeof(Base.append!), Array{Float64, 1}, Array{Float64, 1}})
        false
        false
        false
        _record_precompile(
            Tuple{
                typeof(Base.maybeview),
                Array{Base.Complex{Float64}, 3},
                Function,
                Function,
                Vararg{Any},
            },
        )
        _record_precompile(Tuple{typeof(Base.maybeview), Array{Float64, 2}, Function, Int64})
        _record_precompile(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{
                    Float64,
                    1,
                    Array{Float64, 2},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Array{Float64, 1}},
                },
            },
        )
        false
        false
        false
        _record_precompile(Tuple{typeof(Base.:(==)), Array{Float64, 1}, Array{Float64, 1}})
        false
        _record_precompile(Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64})
        false
        false
        false
        false
        _record_precompile(Tuple{typeof(Base.get), Base.Dict{String, String}, String, String})
        _record_precompile(
            Tuple{typeof(Base.indexed_iterate), Tuple{String, Float64, Float64, String}, Int64},
        )
        _record_precompile(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{String, Float64, Float64, String},
                Int64,
                Int64,
            },
        )
        _record_precompile(Tuple{typeof(Base.string), Int64, String, Vararg{Any}})
        _record_precompile(Tuple{typeof(Base.string), Int64})
        _record_precompile(Tuple{typeof(Base.iterate), Base.Dict{String, String}})
        _record_precompile(Tuple{typeof(Base.iterate), Base.Dict{String, String}, Int64})
        false
        false
        false
        false
        _record_precompile(
            Tuple{typeof(Base.:(==)), Tuple{Int64, Int64, Int64}, Tuple{Int64, Int64, Int64}},
        )
        _record_precompile(
            Tuple{
                Type{Array{Float64, 1}},
                Base.SubArray{
                    Float64,
                    1,
                    Array{Float64, 2},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
            },
        )
        _record_precompile(Tuple{Type{UInt8}, Int32})
        false
        _record_precompile(Tuple{typeof(Base.in), Int64, Base.OneTo{Int64}})
        _record_precompile(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 3}})
        _record_precompile(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Int64, Int64, Int64},
                Char,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Float64, Float64, Float64},
                Char,
            },
        )
        false
        _record_precompile(Tuple{typeof(Base.all), Function, Array{String, 1}})
        _record_precompile(Tuple{typeof(Base.collect), Base.OneTo{Int64}})
        false
        _record_precompile(
            Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Float64}},
        )
        _record_precompile(
            Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, String}},
        )
        _record_precompile(Tuple{typeof(Base.setindex!), HDF5.Group, Array{Int64, 2}, String})
        _record_precompile(
            Tuple{typeof(Base.setindex!), HDF5.Group, Array{Base.Complex{Float64}, 3}, String},
        )
        _record_precompile(Tuple{typeof(Base.print), Base.IOStream, String})
        @assert !MPI.Initialized()
    end
end
