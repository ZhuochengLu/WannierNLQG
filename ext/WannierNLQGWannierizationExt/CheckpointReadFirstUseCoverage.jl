# Observed cold checkpoint decoding signatures, including restored optimizer state.
# Compile signatures only; no checkpoint file is opened during package precompile.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_early_prepare(Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}})
        _record_early_prepare(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
        _record_early_prepare(
            Tuple{
                typeof(Base.issorted),
                Array{String, 1},
                Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.setindex!), Base.EnvDict, String, String})
        _record_early_prepare(Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId})
        false
        false
        false
        _record_early_prepare(Tuple{typeof(Base.prod), Tuple{Int64}})
        _record_early_prepare(Tuple{typeof(Base.in), String, Tuple{String, String}})
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{9, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Pair{A, B} where {B} where A},
                String,
                WannierNLQG.Wannierization.WannierizationStatus,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._wannierization_status),
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Dataset,
                HDF5.Datatype,
                Type{Base.Complex{Float64}},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Int64,
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.API.h5d_read),
                HDF5.Dataset,
                HDF5.Datatype,
                HDF5.Dataspace,
                HDF5.Dataspace,
                HDF5.DatasetTransferProperties,
                Array{Base.Complex{Float64}, 3},
            },
        )
        _record_early_prepare(
            Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64},
        )
        _record_early_prepare(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
        _record_early_prepare(
            Tuple{
                typeof(HDF5.API.h5d_read),
                HDF5.Dataset,
                HDF5.Datatype,
                HDF5.Dataspace,
                HDF5.Dataspace,
                HDF5.DatasetTransferProperties,
                Array{Float64, 1},
            },
        )
        _record_early_prepare(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{21, String}})
        _record_early_prepare(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        _record_early_prepare(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64})
        _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{13, String}})
        _record_early_prepare(Tuple{typeof(Base.eachindex), Array{Int64, 1}})
        _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{19, String}})
        _record_early_prepare(Tuple{typeof(Base.getindex), Array{Float64, 2}, Function, Int64})
        _record_early_prepare(Tuple{typeof(Base.getindex), Array{UInt8, 2}, Int64, Int64})
        _record_early_prepare(Tuple{Type{Bool}, UInt8})
        _record_early_prepare(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
        _record_early_prepare(
            Tuple{
                Type{WannierNLQG.Wannierization.WannierizationIteration},
                Int64,
                Float64,
                Float64,
                Float64,
                WannierNLQG.Wannierization.WannierizationIterationDiagnostics,
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 1}},
        )
        _record_early_prepare(
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
        _record_early_prepare(Tuple{Type{Tuple}, Array{Float64, 1}})
        _record_early_prepare(Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol})
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{72, 0}},
            },
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties},
        )
        _record_early_prepare(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties},
        )
        false
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{7, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:context,), Tuple{Base.Dict{String, String}}},
                Type{WannierNLQG.Wannierization.WannierizationDiagnostic},
                Symbol,
                Symbol,
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{30, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{71, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{20, 0}},
            },
        )
        _record_early_prepare(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        _record_early_prepare(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        _record_early_prepare(
            Tuple{typeof(HDF5.generic_read), HDF5.Dataset, HDF5.Datatype, Type{Bool}},
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.API.h5d_read),
                HDF5.Dataset,
                HDF5.Datatype,
                HDF5.Dataspace,
                HDF5.Dataspace,
                HDF5.DatasetTransferProperties,
                Array{Bool, 1},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.length), Array{Float64, 1}})
        _record_early_prepare(Tuple{Type{Array{Float64, 1}}, Array{Float64, 1}})
        _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{18, String}})
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WannierizationOptimizerState,
                Symbol,
            },
        )
        _record_early_prepare(Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}})
        _record_early_prepare(Tuple{Type{Array{Bool, 1}}, Array{Bool, 1}})
        _record_early_prepare(Tuple{typeof(Base.:(&)), Int64, Int64})
        _record_early_prepare(Tuple{typeof(Base.Core.checked_dims), Int64, Int64, Vararg{Int64}})
        _record_early_prepare(
            Tuple{typeof(Base.Core._checked_mul_dims), Int64, Int64, Int64, Vararg{Int64}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Base.Complex{Float64},
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{WannierNLQG.Wannierization.WannierizationOptimizerState},
                Symbol,
                Float64,
                Float64,
                Int64,
                Int64,
                NTuple{4, Float64},
                Float64,
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Int64,
                Int64,
                Int64,
                Int64,
                Int64,
                Float64,
                Bool,
                Int64,
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 2},
                Array{Float64, 1},
                Float64,
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Int64, 1},
                Array{Int64, 1},
                Array{Bool, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{WannierNLQG.Wannierization.WannierizationOptimizerState},
                Symbol,
                Float64,
                Float64,
                Int64,
                Int64,
                NTuple{4, Float64},
                Float64,
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Int64,
                Int64,
                Int64,
                Int64,
                Int64,
                Float64,
                Bool,
                Int64,
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 2},
                Array{Float64, 1},
                Float64,
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Int64, 1},
                Array{Int64, 1},
                Base.BitArray{1},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Int64,
                Int64,
                Float64,
                Symbol,
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{15, 0}},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{11, String}})
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{39, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Int64,
                Vararg{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                NTuple{4, Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.API.h5d_read),
                HDF5.Dataset,
                HDF5.Datatype,
                HDF5.Dataspace,
                HDF5.Dataspace,
                HDF5.DatasetTransferProperties,
                Array{Base.Complex{Float64}, 4},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{WannierNLQG.Wannierization.WannierizationOptimizerState},
                Symbol,
                Float64,
                Float64,
                Int64,
                Int64,
                NTuple{4, Float64},
                Float64,
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Int64,
                Int64,
                Int64,
                Int64,
                Int64,
                Float64,
                Bool,
                Int64,
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 2},
                Array{Float64, 1},
                Float64,
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Int64, 1},
                Array{Int64, 1},
                Array{Bool, 1},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Int64,
                Int64,
                Float64,
                Symbol,
                Symbol,
                String,
                String,
                Int64,
                Float64,
                Array{Base.Complex{Float64}, 4},
                Array{Base.Complex{Float64}, 4},
                Array{Float64, 1},
                Int64,
                Symbol,
                Array{Base.Complex{Float64}, 4},
                Array{Base.Complex{Float64}, 3},
                Float64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{8, String}})
        _record_early_prepare(
            Tuple{
                typeof(Base._array_for),
                Type{Symbol},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Symbol, 1},
                Symbol,
                Base.Generator{
                    Base.UnitRange{Int64},
                    Base.var"#252#253"{WannierNLQGWannierizationExt.SolverCheckpoint.var"#456#460"},
                },
                Int64,
            },
        )
        false
        _record_early_prepare(
            Tuple{
                typeof(Base.collect_to!),
                Array{Any, 1},
                Base.Generator{
                    Base.UnitRange{Int64},
                    Base.var"#252#253"{WannierNLQGWannierizationExt.SolverCheckpoint.var"#456#460"},
                },
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.Broadcast.broadcasted), Type{Bool}, Array{UInt8, 2}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    Type{Bool},
                    Tuple{Array{UInt8, 2}},
                },
            },
        )
        _record_early_prepare(Tuple{Type{Base.BitArray{2}}, Base.BitArray{2}})
        false
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{17, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{6, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{55, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{2, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{27, 0}},
            },
        )
        false
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{46, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{49, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{67, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{38, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{65, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{57, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{40, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{52, 0}},
            },
        )
        false
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{41, 0}},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{4, String}})
        _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{14, String}})
        _record_early_prepare(Tuple{typeof(Base.:(==)), Bool, Bool})
        _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{6, String}})
        _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{5, String}})
        _record_early_prepare(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
        _record_early_prepare(Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64})
        _record_early_prepare(Tuple{typeof(Base.unique), Array{String, 1}})
        _record_early_prepare(
            Tuple{
                Type{WannierNLQG.Wannierization.WannierizationResult},
                WannierNLQG.Wannierization.WannierizationStatus,
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 2},
                Array{Float64, 1},
                Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                Base.Dict{String, String},
                WannierNLQG.IO.WannierCHK,
                String,
                WannierNLQG.Wannierization.WannierizationRestartState,
                WannierNLQG.Wannierization.WannierizationArtifacts,
                Nothing,
                WannierNLQG.Wannierization.TBSymmetryQualification,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                Array{Float64, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{51, 0}},
            },
        )
        false
        false
        false
        false
        _record_early_prepare(
            Tuple{
                Type{WannierNLQG.Wannierization.WannierizationRestartState},
                Int64,
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 2},
                Array{Float64, 1},
                Array{Float64, 2},
                Base.BitArray{2},
                Float64,
                String,
                String,
                WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                String,
                String,
                WannierNLQG.Wannierization.WannierizationOptimizerState,
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Nothing,
            },
        )
        false
    end
end
