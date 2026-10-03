# Remaining post-backend native declarations without foreign private references.
const WannierNLQGSymmetrizationExt = Base.get_extension(WannierNLQG, :WannierNLQGSymmetrizationExt)
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        @assert WannierNLQGSymmetrizationExt !== nothing
        _record_sequence(Tuple{Base.var"#58#59", Type})
        _record_sequence(
            Tuple{
                HDF5.var"##h5open#16",
                HDF5.HDF5Context,
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(HDF5.h5open),
                WannierNLQGOperatorBundleExt.var"#67#82"{
                    String,
                    Base.Dict{String, Any},
                    Base.Dict{String, Any},
                    Base.Dict{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperator{N} where N,
                    },
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    Base.Dict{String, Any},
                    Bool,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    String,
                    Base.Dict{String, Any},
                    String,
                    String,
                    String,
                    String,
                    Nothing,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Array{String, 1},
                    Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                    Array{Base.Complex{Float64}, 1},
                    String,
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Int64,
                    Array{Int64, 1},
                    Array{Int64, 2},
                    Bool,
                    Bool,
                    Nothing,
                    Array{Float64, 2},
                },
                String,
                Vararg{String},
            },
        )
        _record_sequence(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}})
        _record_sequence(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Array{Int8, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
        _record_sequence(
            Tuple{
                Type{Base.Fix1{F, T} where {T} where F},
                Type{Base.MappingRF{F, T} where {T} where F},
                Type,
            },
        )
        _record_sequence(
            Tuple{
                Type{
                    Base.IteratorsMD.CartesianIndices{
                        N,
                        R,
                    } where {R <: Tuple{Vararg{Base.OrdinalRange{Int64, Int64}, N}}} where N,
                },
                Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}},
            },
        )
        _record_sequence(
            Tuple{
                Type{
                    Base.LinearIndices{
                        N,
                        R,
                    } where {R <: Tuple{Vararg{Base.AbstractUnitRange{Int64}, N}}} where N,
                },
                Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}},
            },
        )
        _record_sequence(Tuple{Type{Base.Set{T} where T}, Array{String, 1}})
        _record_sequence(
            Tuple{Type{NamedTuple{(:atol, :rtol), T} where T <: Tuple}, Tuple{Float64, Float64}},
        )
        _record_sequence(
            Tuple{Type{NamedTuple{(:hermitize, :atol), T} where T <: Tuple}, Tuple{Bool, Float64}},
        )
        _record_sequence(Tuple{Type{NamedTuple{(:hermitize,), T} where T <: Tuple}, Tuple{Bool}})
        _record_sequence(Tuple{Type{NamedTuple{(:init,), T} where T <: Tuple}, Tuple{Float64}})
        _record_sequence(Tuple{Type{NamedTuple{(:prevalidated,), T} where T <: Tuple}, Tuple{Bool}})
        _record_sequence(Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Any}})
        _record_sequence(Tuple{Type{Pair{A, B} where {B} where A}, String, Bool})
        _record_sequence(
            Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64},
        )
        _record_sequence(
            Tuple{
                Type{Pair{A, B} where {B} where A},
                WannierNLQG.Core.RealSpaceOperatorKind,
                NamedTuple{(:covariance_error, :idempotence_error), Tuple{Float64, Float64}},
            },
        )
        _record_sequence(
            Tuple{
                Type{Pair{A, B} where {B} where A},
                WannierNLQG.Core.RealSpaceOperatorKind,
                WannierNLQG.Core.RealSpaceOperator{3},
            },
        )
        _record_sequence(
            Tuple{
                Type{Pair{A, B} where {B} where A},
                WannierNLQG.Core.RealSpaceOperatorKind,
                WannierNLQG.Core.RealSpaceOperator{4},
            },
        )
        _record_sequence(Tuple{Type{String}, Array{UInt8, 1}})
        _record_sequence(Tuple{Type{UInt8}, UInt8})
        _record_sequence(Tuple{Type{UInt8}, WannierNLQG.Core.RealSpaceOperatorKind})
        _record_sequence(
            Tuple{
                Type{
                    WannierNLQG.Core.TightBindingModel{
                        H,
                        P,
                    } where {
                        P <: AbstractArray{Base.Complex{Float64}, 4},
                    } where H <: AbstractArray{Base.Complex{Float64}, 3},
                },
                Array{Float64, 2},
                Int64,
                Int64,
                Array{Int64, 1},
                Array{Int64, 2},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 4},
            },
        )
        false
        _record_sequence(Tuple{typeof(Base.:(&)), Int64, Int64})
        _record_sequence(Tuple{typeof(Base.:(*)), Float64, Float64})
        _record_sequence(Tuple{typeof(Base.:(*)), Int64})
        _record_sequence(Tuple{typeof(Base.:(+)), Int64, UInt64})
        _record_sequence(Tuple{typeof(Base.:(-)), Int32, Int32})
        _record_sequence(Tuple{typeof(Base.:(<=)), Float64, Float64})
        _record_sequence(Tuple{typeof(Base.:(==)), Array{UInt64, 1}, Array{UInt64, 1}})
        _record_sequence(Tuple{typeof(Base.:(==)), Bool, Bool})
        _record_sequence(Tuple{typeof(Base.:(==)), Char, Char})
        _record_sequence(
            Tuple{typeof(Base.:(==)), Tuple{Int64, Int64, Int64}, Tuple{Int64, Int64, Int64}},
        )
        _record_sequence(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        _record_sequence(Tuple{typeof(Base.:(==)), UInt64, UInt64})
        _record_sequence(Tuple{typeof(Base.:(>)), Float64, Float64})
        _record_sequence(Tuple{typeof(Base.:(>)), Int64})
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(WannierNLQG.Core.real_space_operator_name),
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(WannierNLQG.Core.real_space_operator_name),
                    Tuple{Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
                },
            },
        )
        _record_sequence(
            Tuple{typeof(Base.Iterators.enumerate), Array{Tuple{Int64, Int64, Int64}, 1}},
        )
        _record_sequence(
            Tuple{
                typeof(Base._all),
                Base.Fix2{typeof(Base.:(>)), Int64},
                Array{Int64, 1},
                Base.Colon,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base._array_for),
                Type{Tuple{Int64, Int64, Int64}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base._array_for),
                Type{WannierNLQG.SymmetryFoundation.RealSpaceSymmetrizationResult{3}},
                Base.HasLength,
                Int64,
            },
        )
        _record_sequence(Tuple{typeof(Base.abs), Float64})
        _record_sequence(Tuple{typeof(Base.abs), Int64})
        _record_sequence(Tuple{typeof(Base.add_sum), Int64, Int64})
        _record_sequence(Tuple{typeof(Base.add_sum), UInt64, UInt64})
        _record_sequence(Tuple{typeof(Base.all), Function, Core.SimpleVector})
        _record_sequence(
            Tuple{
                typeof(Base.checkbounds),
                Type{Bool},
                Base.LinearIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
                Int64,
            },
        )
        _record_sequence(Tuple{typeof(Base.collect), Base.KeySet{String, Base.Dict{String, Any}}})
        _record_sequence(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{WannierNLQG.SymmetryFoundation.RealSpaceSymmetrizationResult{3}, 1},
                WannierNLQG.SymmetryFoundation.RealSpaceSymmetrizationResult{3},
                Base.Generator{
                    Base.ValueIterator{
                        Base.Dict{
                            WannierNLQG.Core.RealSpaceOperatorKind,
                            WannierNLQG.Core.RealSpaceOperator{N} where N,
                        },
                    },
                    WannierNLQGSymmetrizationExt.var"#188#189"{
                        NamedTuple{
                            (:input, :model, :operations, :basis, :plan, :projection),
                            Tuple{
                                WannierNLQG.WannierProjection.WannierWinData,
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
                                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                                WannierNLQG.WannierProjection.WannierProjectionBasis,
                                WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                                WannierNLQG.SymmetryFoundation.RealSpaceProjectionContext,
                            },
                        },
                    },
                },
                Int64,
            },
        )
        _record_sequence(Tuple{typeof(Base.convert), Type{Float64}, Float64})
        _record_sequence(Tuple{typeof(Base.get), Base.Dict{String, Any}, String, String})
        _record_sequence(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{Tuple{Int64, Int64, Int64}, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{UInt64, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
        _record_sequence(
            Tuple{
                typeof(Base.getindex),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Tuple{Int64, Int64, Int64},
            },
        )
        false
        _record_sequence(Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol})
        _record_sequence(
            Tuple{typeof(Base.getproperty), LinearAlgebra.UniformScaling{Bool}, Symbol},
        )
        _record_sequence(Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId})
        _record_sequence(Tuple{typeof(Base.haskey), Base.Dict{String, Any}, Symbol})
        _record_sequence(Tuple{typeof(Base.imag), Base.Complex{Float64}})
        _record_sequence(Tuple{typeof(Base.in), Char, Tuple{Char, Char}})
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{4, String}})
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{5, String}})
        _record_sequence(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
        _record_sequence(Tuple{typeof(Base.in), String, Tuple{String, String}})
        _record_sequence(
            Tuple{
                typeof(Base.in),
                WannierNLQG.Core.RealSpaceOperatorKind,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{String, Bool}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{String, Bool}, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64})
        _record_sequence(
            Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, String}, Int64}, Int64, Int64},
        )
        _record_sequence(
            Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, String}, Int64}, Int64},
        )
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{String, String}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{String, String}, Int64})
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
        _record_sequence(
            Tuple{typeof(Base.iterate), Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}, Int64},
        )
        _record_sequence(
            Tuple{typeof(Base.iterate), Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
        )
        _record_sequence(
            Tuple{
                typeof(Base.iterate),
                Base.IteratorsMD.CartesianIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
                Base.IteratorsMD.CartesianIndex{2},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.iterate),
                Base.IteratorsMD.CartesianIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.iterate),
                Base.LinearIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.iterate),
                Base.LinearIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
            },
        )
        _record_sequence(Tuple{typeof(Base.iterate), Base.Set{Tuple{Int64, Int64, Int64}}, Int64})
        _record_sequence(Tuple{typeof(Base.iterate), Base.Set{Tuple{Int64, Int64, Int64}}})
        _record_sequence(Tuple{typeof(Base.iterate), Pair{String, String}, Int64})
        _record_sequence(Tuple{typeof(Base.iterate), Pair{String, String}})
        _record_sequence(Tuple{typeof(Base.join), Array{String, 1}, String})
        _record_sequence(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Base.SubString{String}, 1},
                Char,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Int64, Int64, Int64},
                Char,
            },
        )
        _record_sequence(Tuple{typeof(Base.keys), Base.Dict{String, Any}})
        _record_sequence(
            Tuple{
                typeof(Base.last),
                Base.LinearIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
            },
        )
        _record_sequence(Tuple{typeof(Base.length), Array{Base.Complex{Float64}, 1}})
        _record_sequence(Tuple{typeof(Base.length), Array{Int64, 1}})
        _record_sequence(Tuple{typeof(Base.length), Array{Tuple{Int64, Int64, Int64}, 1}})
        _record_sequence(Tuple{typeof(Base.length), Array{UInt8, 1}})
        _record_sequence(
            Tuple{typeof(Base.length), Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
        )
        _record_sequence(
            Tuple{typeof(Base.length), Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1}},
        )
        _record_sequence(Tuple{typeof(Base.map), typeof(Base.unchecked_oneto), Tuple{Int64, Int64}})
        _record_sequence(
            Tuple{
                typeof(Base.mapfoldl_impl),
                Type{Int64},
                typeof(Base.:(*)),
                Int64,
                Tuple{Int64, Int64},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.mapfoldl_impl),
                Type{Int64},
                typeof(Base.min),
                Int64,
                Tuple{Int64, Int64},
            },
        )
        _record_sequence(Tuple{typeof(Base.occursin), Base.Regex, String})
        _record_sequence(Tuple{typeof(Base.prod), Tuple{Int64, Int64}})
        _record_sequence(Tuple{typeof(Base.prod), Tuple{Int64}})
        _record_sequence(
            Tuple{
                typeof(Base.push!),
                Base.Set{Tuple{Int64, Int64, Int64}},
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_sequence(Tuple{typeof(Base.real), Base.Complex{Float64}})
        _record_sequence(Tuple{typeof(Base.reverse), Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}})
        _record_sequence(Tuple{typeof(Base.reverse), Tuple{Int64, Int64}})
        _record_sequence(Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64})
        _record_sequence(Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64})
        _record_sequence(Tuple{typeof(Base.setindex!), Base.EnvDict, String, String})
        _record_sequence(
            Tuple{
                typeof(Base.setindex_widen_up_to),
                Array{WannierNLQG.SymmetryFoundation.RealSpaceSymmetrizationResult{3}, 1},
                WannierNLQG.SymmetryFoundation.RealSpaceSymmetrizationResult{4},
                Int64,
            },
        )
        _record_sequence(Tuple{typeof(Base.size), Array{Float64, 2}})
        _record_sequence(Tuple{typeof(Base.size), Array{Int64, 2}, Int64})
        _record_sequence(Tuple{typeof(Base.size), Array{Int64, 2}})
        _record_sequence(
            Tuple{
                typeof(Base.tail),
                Tuple{Base.IteratorsMD.CartesianIndex{2}, Base.IteratorsMD.CartesianIndex{2}},
            },
        )
        _record_sequence(Tuple{typeof(Base.to_shape), Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}})
        _record_sequence(Tuple{typeof(Base.top_set_bit), UInt64})
        _record_sequence(Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}})
        _record_sequence(Tuple{typeof(Core._checked_mul_dims), Int64, Int64})
        _record_sequence(Tuple{typeof(Core.checked_dims), Int64, Int64, Vararg{Int64}})

        # Foundation-owned coverage is compiled in its owning extension.

        _record_sequence(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:init,), Tuple{Int64}},
                typeof(Base.mapreduce),
                Type,
                Function,
                Tuple{Int64, Int64},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :profile,
                        :operator_tasks,
                        :overwrite,
                        :paired_tb_sha256,
                        :provenance,
                        :symmetry,
                        :geometry,
                        :diagnostics,
                        :eligibility,
                    ),
                    Tuple{
                        Symbol,
                        Tuple{},
                        Bool,
                        String,
                        Base.Dict{String, Any},
                        Base.Dict{String, Any},
                        Base.Dict{String, Any},
                        Base.Dict{
                            String,
                            Base.Dict{
                                String,
                                NamedTuple{
                                    (:covariance_error, :idempotence_error),
                                    Tuple{Float64, Float64},
                                },
                            },
                        },
                        Base.Dict{String, Any},
                    },
                },
                typeof(WannierNLQGOperatorBundleExt.write_real_space_operator_bundle),
                String,
                Array{Float64, 2},
                Array{Int64, 1},
                Base.Dict{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    WannierNLQG.Core.RealSpaceOperator{N} where N,
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.IO.OperatorBundleIndexEntry,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.SymmetryFoundation.SymmetryOperation,
                    Core.AddrSpace{Core}(0x00),
                },
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
        _record_sequence(Tuple{typeof(JSON3.pretty), Base.IOStream, String, JSON3.AlignmentContext})
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
                typeof(WannierNLQG.Symmetrization.symmetrize_wannier_operators),
                WannierNLQG.Symmetrization.SymmetrizationConfig,
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGOperatorBundleExt._bind_pair_wigner_seitz_qualification),
                Nothing,
                Base.Dict{String, Any},
                Symbol,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGOperatorBundleExt._construction_evidence_for_write),
                Base.Dict{
                    String,
                    Base.Dict{
                        String,
                        NamedTuple{
                            (:covariance_error, :idempotence_error),
                            Tuple{Float64, Float64},
                        },
                    },
                },
                Base.Dict{String, Any},
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGOperatorBundleExt._qualification_digest_value!),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Base.Dict{String, String},
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGOperatorBundleExt._write_metadata_group),
                HDF5.File,
                String,
                Base.Dict{
                    String,
                    Base.Dict{
                        String,
                        NamedTuple{
                            (:covariance_error, :idempotence_error),
                            Tuple{Float64, Float64},
                        },
                    },
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                HDF5.Group,
                String,
                Array{Float64, 1},
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                HDF5.Group,
                String,
                Base.Dict{String, Float64},
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                HDF5.Group,
                String,
                Nothing,
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._build_symmetrization_context),
                WannierNLQG.Symmetrization.SymmetrizationConfig,
                NamedTuple{
                    (
                        :families,
                        :win,
                        :tb,
                        :chk,
                        :eig,
                        :mmn,
                        :spn,
                        :output_tb,
                        :operator_bundle,
                        :report,
                        :checksums,
                    ),
                    Tuple{
                        NamedTuple{
                            (
                                :profile,
                                :selected_operator_kinds,
                                :derivative,
                                :spin,
                                :spin_velocity,
                            ),
                            Tuple{
                                Symbol,
                                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                                Bool,
                            },
                        },
                        String,
                        String,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Vararg{String, 4},
                    },
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._symmetrize_tight_binding_operators),
                NamedTuple{
                    (:input, :model, :operations, :basis, :plan, :projection),
                    Tuple{
                        WannierNLQG.WannierProjection.WannierWinData,
                        WannierNLQG.Core.TightBindingModel{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                        },
                        Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                        WannierNLQG.WannierProjection.WannierProjectionBasis,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        WannierNLQG.SymmetryFoundation.RealSpaceProjectionContext,
                    },
                },
                WannierNLQG.Symmetrization.SymmetrizationConfig,
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._symmetrized_tight_binding_model),
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
                WannierNLQG.SymmetryFoundation.RealSpaceSymmetrizationResult{3},
                WannierNLQG.SymmetryFoundation.RealSpaceSymmetrizationResult{4},
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._validate_symmetrized_operator),
                WannierNLQG.SymmetryFoundation.RealSpaceSymmetrizationResult{3},
                WannierNLQG.SymmetryFoundation.RealSpaceProjectionContext,
                WannierNLQG.Symmetrization.SymmetrizationConfig,
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._validate_symmetrized_operator),
                WannierNLQG.SymmetryFoundation.RealSpaceSymmetrizationResult{4},
                WannierNLQG.SymmetryFoundation.RealSpaceProjectionContext,
                WannierNLQG.Symmetrization.SymmetrizationConfig,
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._write_symmetrization_report),
                WannierNLQG.Symmetrization.SymmetrizationConfig,
                String,
                Base.Dict{String, Any},
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt.symmetrize_wannier_operators),
                WannierNLQG.Symmetrization.SymmetrizationConfig,
            },
        )

        # Foundation-owned coverage is compiled in its owning extension.

        @assert !MPI.Initialized()
    end
end
