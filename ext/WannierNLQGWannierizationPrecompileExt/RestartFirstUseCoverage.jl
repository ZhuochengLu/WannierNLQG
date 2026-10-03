# Actual serial/MPI checkpoint tail-replay signatures; compile only.
# No checkpoint IO, solve, MPI initialization, or persistent resource is executed.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_sequence(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Int64,
                Int64,
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                NTuple{4, Int64},
            },
        )
        _record_sequence(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Array{Float64, 1}}, Array{Float64, 1}})
        _record_sequence(
            Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64, Int64},
        )
        _record_sequence(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}})
        _record_sequence(
            Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64, Int64},
        )
        _record_sequence(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        _record_sequence(
            Tuple{Type{Array{T, 2} where T}, LinearAlgebra.Transpose{Float64, Array{Float64, 2}}},
        )
        _record_sequence(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
        false
        _record_sequence(Tuple{Type{Base.BitArray{2}}, Base.BitArray{2}})
        _record_sequence(Tuple{Type{Bool}, Int64})
        _record_sequence(Tuple{Type{Bool}, UInt8})
        false
        _record_sequence(
            Tuple{
                Type{
                    GenericMemory{
                        :not_atomic,
                        Array{Base.Complex{Float64}, 2},
                        Base.Core.AddrSpace{Core}(0x00),
                    },
                },
                UndefInitializer,
                Int64,
            },
        )
        false
        _record_sequence(
            Tuple{
                Type{GenericMemory{:not_atomic, Base.BitArray{1}, Base.Core.AddrSpace{Core}(0x00)}},
                UndefInitializer,
                Int64,
            },
        )
        _record_sequence(
            Tuple{Type{NamedTuple{(:change_error,), T} where T <: Tuple}, Tuple{String}},
        )
        _record_sequence(
            Tuple{Type{NamedTuple{(:construction_policy,), T} where T <: Tuple}, Tuple{Symbol}},
        )
        _record_sequence(Tuple{Type{NamedTuple{(:jsonlines,), T} where T <: Tuple}, Tuple{Bool}})
        _record_sequence(
            Tuple{
                Type{NamedTuple{(:retained_disentanglement_nonconverged,), T} where T <: Tuple},
                Tuple{Bool},
            },
        )
        false
        _record_sequence(Tuple{Type{Tuple}, Array{Float64, 1}})
        false
        _record_sequence(
            Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_sequence(Tuple{typeof(Base.:(*)), Float64, Float64})
        _record_sequence(
            Tuple{
                typeof(Base.:(*)),
                LinearAlgebra.Adjoint{Base.Complex{Float64}, Array{Base.Complex{Float64}, 2}},
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_sequence(Tuple{typeof(Base.:(<=)), Float64, Float64})
        _record_sequence(Tuple{typeof(Base.:(==)), Bool, Bool})
        _record_sequence(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        _record_sequence(Tuple{typeof(Base.:(>)), Float64, Float64})
        _record_sequence(
            Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 1}},
        )
        _record_sequence(Tuple{typeof(Base.Broadcast.broadcasted), Type{String}, Array{String, 1}})
        _record_sequence(
            Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.:(!)), Base.BitArray{2}},
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(|)),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(!)),
                    Tuple{Base.BitArray{2}},
                },
                Base.BitArray{2},
            },
        )
        _record_sequence(
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
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{String},
                    Tuple{Array{String, 1}},
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(|)),
                    Tuple{
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{2},
                            Nothing,
                            typeof(Base.:(!)),
                            Tuple{Base.BitArray{2}},
                        },
                        Base.BitArray{2},
                    },
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Order.lt),
                Base.Order.ForwardOrdering,
                Tuple{Int64, String},
                Tuple{Int64, String},
            },
        )
        _record_sequence(Tuple{typeof(Base.StringVector), Int64})
        _record_sequence(
            Tuple{
                typeof(Base._array_for),
                Type{Array{Float64, 1}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base._array_for),
                Type{Array{Int64, 1}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base._array_for),
                Type{Symbol},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_sequence(Tuple{typeof(Base.abs), Float64})
        _record_sequence(Tuple{typeof(Base.add_sum), Int64, Int64})
        _record_sequence(Tuple{typeof(Base.add_sum), UInt64, UInt64})
        _record_sequence(Tuple{typeof(Base.adjoint), Array{Base.Complex{Float64}, 2}})
        false
        false
        _record_sequence(Tuple{typeof(Base.convert), Type{Bool}, Bool})
        false
        _record_sequence(Tuple{typeof(Base.copy), Array{Int64, 1}})
        _record_sequence(
            Tuple{
                typeof(Base.copy),
                GenericMemory{:not_atomic, Base.Complex{Float64}, Base.Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_sequence(Tuple{typeof(Base.eachindex), Array{Float64, 1}})
        _record_sequence(Tuple{typeof(Base.eachindex), Array{Int64, 1}})
        _record_sequence(Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}})
        _record_sequence(Tuple{typeof(Base.get), Base.Dict{String, String}, String, String})
        _record_sequence(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{UInt8, 2}, Int64, Int64})
        false
        false
        false
        false
        false
        _record_sequence(Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol})
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :inventory,
                        :raw_diagnostics,
                        :qualification_scope,
                        :requested_policy,
                        :effective_policy,
                        :symmetry_tolerance_status,
                        :preparation_digest,
                    ),
                    Tuple{
                        Nothing,
                        Array{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic, 1},
                        WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                        Symbol,
                        Symbol,
                        Symbol,
                        String,
                    },
                },
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WannierizationInputConfig,
                Symbol,
            },
        )
        _record_sequence(Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId})
        _record_sequence(Tuple{typeof(Base.haskey), Base.Dict{String, String}, String})
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{11, String}})
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{4, String}})
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{5, String}})
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{6, String}})
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{8, String}})
        _record_sequence(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
        _record_sequence(Tuple{typeof(Base.in), String, Tuple{String, String}})
        _record_sequence(Tuple{typeof(Base.in), Symbol, Tuple{Symbol, Symbol, Symbol}})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64})
        _record_sequence(Tuple{typeof(Base.isfinite), Float64})
        _record_sequence(
            Tuple{
                typeof(Base.issorted),
                Array{String, 1},
                Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
            },
        )
        _record_sequence(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
        false
        false
        false
        _record_sequence(Tuple{typeof(Base.length), Array{Float64, 1}})
        _record_sequence(Tuple{typeof(Base.length), Array{UInt8, 1}})
        false
        _record_sequence(Tuple{typeof(Base.min), Float64, Float64})
        _record_sequence(
            Tuple{
                typeof(Base.print),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Core}(0x00)},
                },
                UInt64,
            },
        )
        _record_sequence(Tuple{typeof(Base.print), Base.IOStream, String})
        _record_sequence(Tuple{typeof(Base.prod), Tuple{Int64}})
        false
        _record_sequence(Tuple{typeof(Base.repeat), Char, Int64})
        _record_sequence(Tuple{typeof(Base.repr), Float64})
        _record_sequence(Tuple{typeof(Base.repr), Int64})
        false
        false
        false
        false
        false
        false
        _record_sequence(
            Tuple{
                typeof(Base.setindex!),
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Base.Complex{Float64}, 2},
                Int64,
            },
        )
        _record_sequence(Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64})
        _record_sequence(Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64})
        _record_sequence(Tuple{typeof(Base.setindex!), Base.EnvDict, String, String})
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Core}(0x00)},
                },
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Core}(0x00)},
                },
                Symbol,
            },
        )
        false
        false
        false
        false
        false
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Core}(0x00)},
                    },
                },
                Array{Float64, 1},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Core}(0x00)},
                    },
                },
                Bool,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Core}(0x00)},
                    },
                },
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Core}(0x00)},
                    },
                },
                Nothing,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Core}(0x00)},
                    },
                },
                UInt64,
            },
        )
        _record_sequence(Tuple{typeof(Base.size), Array{Float64, 2}})
        _record_sequence(Tuple{typeof(Base.size), Array{Int64, 2}})
        _record_sequence(Tuple{typeof(Base.size), Base.BitArray{2}})
        _record_sequence(Tuple{typeof(Base.something), String})
        false
        _record_sequence(Tuple{typeof(Base.sym_in), Symbol, NTuple{111, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{10, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{11, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{12, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{13, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{14, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{15, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{16, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{4, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{5, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{6, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{7, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{8, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{9, Symbol}})
        _record_sequence(Tuple{typeof(Base.unique), Array{String, 1}})
        _record_sequence(Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}})
        _record_sequence(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Core}(0x00)},
                },
                Array{Int64, 1},
            },
        )
        _record_sequence(Tuple{typeof(Base.write), Base.IOStream, Array{UInt8, 1}})
        _record_sequence(Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}})
        false
        false
        false
        _record_sequence(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:conventions, :input_sha256),
                    Tuple{Base.Dict{String, String}, Base.Dict{String, String}},
                },
                Type{WannierNLQG.SymmetryFoundation.BandRepresentation},
                String,
                Symbol,
                Bool,
                Array{Float64, 2},
                Array{Float64, 2},
                Tuple{Int64, Int64, Int64},
                Array{Float64, 2},
                Array{Float64, 2},
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Array{Int64, 2},
                Array{Int64, 3},
                Array{Base.Complex{Float64}, 4},
                Array{Int64, 2},
                Array{Int64, 1},
                Array{Int64, 1},
                Array{Int64, 1},
            },
        )
        false
        _record_sequence(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    Base.Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{:not_atomic, Base.Complex{Float64}, Base.Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{:not_atomic, Tuple{Symbol, Any}, Base.Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_sequence(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties},
        )
        _record_sequence(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties},
        )
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties})
        _record_sequence(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties},
        )
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties})
        _record_sequence(
            Tuple{
                typeof(JSON3.write),
                StructTypes.DictType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Base.Dict{String, Any},
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQG.Wannierization.construct_symmetry_adapted_wannier_functions),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
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
    end
end
