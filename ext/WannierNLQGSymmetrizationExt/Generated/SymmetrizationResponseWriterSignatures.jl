# Generated from a true first-call response writer trace.
# See candidate_008_split_writer_generation_v1.json for every source line.
const RESPONSE_WRITER_SYMMETRIZATION_RESULTS = Bool[]
# Record the direct compiler success flag for one response writer specialization.
_record_response_writer_symmetrization(signature) =
    push!(RESPONSE_WRITER_SYMMETRIZATION_RESULTS, precompile(signature))
@compile_workload begin
    if workload_enabled(parentmodule(Symmetrization))
        let WannierNLQGSymmetrizationExt=@__MODULE__, StructTypes=JSON3.StructTypes
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{
                        (
                            :structure_file,
                            :structure_format,
                            :model_file,
                            :vasp_magnetic_input_file,
                        ),
                        Tuple{String, Symbol, String, String},
                    },
                    typeof(Symmetrization.write_response_symmetry_artifact),
                    String,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.sym_in), Symbol, NTuple{21, Symbol}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{String, Nothing}, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{String, Nothing}, Int64, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.something), Nothing, Nothing, Vararg{Any}},
            )
            _record_response_writer_symmetrization(
                Tuple{Type{NamedTuple{(:allow_yes_no,), T} where T <: Tuple}, Tuple{Bool}},
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(>)), Int64})
            _record_response_writer_symmetrization(
                Tuple{typeof(Core.checked_dims), Int64, Int64, Vararg{Int64}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Core._checked_mul_dims), Int64, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.ntuple), Base.Returns{Bool}, Base.Val{2}},
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(*)), Float64, Float64})
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.MappingRF{typeof(Base.identity), typeof(Base.mul_prod)},
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{Type{NamedTuple{(:check,), T} where T <: Tuple}, Tuple{Bool}},
            )
            _record_response_writer_symmetrization(Tuple{typeof(LinearAlgebra._chkstride1), Bool})
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.pairs), NamedTuple{(:check,), Tuple{Bool}}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{NamedTuple{(:check, :allowsingular), T} where T <: Tuple},
                    Tuple{Bool, Bool},
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.in), Tuple{Char, Char, Char}})
            _record_response_writer_symmetrization(
                Tuple{Type{Base.IteratorsMD.CartesianIndex{N} where N}, Tuple{Int64, Int64}},
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(==)), Char, Char})
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.in), Char, Tuple{Char, Char, Char}},
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.in), Char, Tuple{Char, Char}})
            _record_response_writer_symmetrization(
                Tuple{
                    Type{
                        LinearAlgebra.MulAddMul{
                            ais1,
                            bis0,
                            TA,
                            TB,
                        } where {TB} where {TA} where {bis0} where ais1,
                    },
                    Bool,
                    Bool,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    LinearAlgebra.MulAddMul{true, true, Bool, Bool},
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.iszero), Bool})
            _record_response_writer_symmetrization(Tuple{typeof(Base.promote), Bool, Bool, Float64})
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{Float64, Float64, Float64}, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{Float64, Float64, Float64}, Int64, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.convert), Type{Float64}, Float64},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.map),
                    Base.Fix2{typeof(Base.in), Tuple{Char, Char, Char}},
                    Tuple{Char, Char},
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.all), Tuple{Bool, Bool}})
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.getproperty), Base.IteratorsMD.CartesianIndex{2}, Symbol},
            )
            _record_response_writer_symmetrization(Tuple{typeof(LinearAlgebra.norm), Float64})
            _record_response_writer_symmetrization(Tuple{typeof(Base.float), Float64})
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.MappingRF{typeof(LinearAlgebra.norm), typeof(Base.max)},
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.abs), Int64})
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.MappingRF{
                        Base.ComposedFunction{typeof(Base.float), typeof(LinearAlgebra.norm)},
                        typeof(Base.:(+)),
                    },
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.MappingRF{typeof(LinearAlgebra.norm), typeof(Base.min)},
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(/)), Float64, Int64})
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.literal_pow), typeof(Base.:(^)), Float64, Base.Val{-57}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.literal_pow), typeof(Base.:(^)), Float64, Base.Val{66}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.literal_pow), typeof(Base.:(^)), Float64, Base.Val{-27}},
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(*)), Int64, Float64})
            _record_response_writer_symmetrization(Tuple{typeof(Base.sqrt), Float64})
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.:(/)), Int64, Base.Irrational{:π}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.Iterators.var"#10#11"{Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}}},
                    Int64,
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(|)), Int32, Int32})
            _record_response_writer_symmetrization(
                Tuple{
                    EzXML.var"##parse_options#8",
                    Bool,
                    Bool,
                    Bool,
                    Bool,
                    typeof(EzXML.parse_options),
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.indexed_iterate),
                    Tuple{Int32, NamedTuple{(:noerror, :nowarning), Tuple{Bool, Bool}}},
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.indexed_iterate),
                    Tuple{Int32, NamedTuple{(:noerror, :nowarning), Tuple{Bool, Bool}}},
                    Int64,
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.merge),
                    NamedTuple{(), Tuple{}},
                    NamedTuple{(:noerror, :nowarning), Tuple{Bool, Bool}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.convert), Type{Ptr{EzXML._Node}}, Ptr{Nothing}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{:not_atomic, EzXML.Node, Core.AddrSpace{Core}(0x00)},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.Broadcast._broadcast_getindex), Float64, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        SymmetryFoundation.SymmetryOperation,
                        Core.AddrSpace{Core}(0x00),
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{Type{Tuple{Vararg{Int64, N}} where N}, Tuple{Int64, Int64}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.getproperty), LinearAlgebra.UniformScaling{Bool}, Symbol},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(LinearAlgebra.diagind), Int64, Int64},
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.abs), Float64})
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(&)), Int64, Int64})
            _record_response_writer_symmetrization(Tuple{typeof(Base.float), Int64})
            _record_response_writer_symmetrization(Tuple{typeof(Base.inv), Int64})
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(-)), Int64, Float64})
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64, Int64},
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.isconcretetype), Any})
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{:not_atomic, Array{Int64, 2}, Core.AddrSpace{Core}(0x00)},
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(LinearAlgebra.char_uplo), Symbol})
            _record_response_writer_symmetrization(Tuple{typeof(Base.abs2), Float64})
            _record_response_writer_symmetrization(Tuple{typeof(LinearAlgebra.sym_uplo), Char})
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.MappingRF{typeof(Base.identity), typeof(Base.min)},
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(Tuple{Type{Float64}, Bool})
            _record_response_writer_symmetrization(
                Tuple{Type{Pair{A, B} where {B} where A}, String, Float64},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        NamedTuple{names, T} where {T <: Tuple} where names,
                        Core.AddrSpace{Core}(0x00),
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{:not_atomic, Float64, Core.AddrSpace{Core}(0x00)},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.Order.By{
                        WannierNLQGSymmetrizationExt.var"#129#131",
                        Base.Order.ForwardOrdering,
                    },
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.Order.Lt{
                        Base.Sort.var"#30#31"{
                            Base.Order.By{
                                WannierNLQGSymmetrizationExt.var"#129#131",
                                Base.Order.ForwardOrdering,
                            },
                        },
                    },
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(Tuple{Base.var"##s128#278", Vararg{Any, 5}})
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.MappingRF{
                        WannierNLQGSymmetrizationExt.var"#134#137",
                        Base.BottomRF{typeof(Base.max)},
                    },
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.MappingRF{
                        WannierNLQGSymmetrizationExt.var"#135#138",
                        Base.BottomRF{typeof(Base.max)},
                    },
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{Type{Pair{A, B} where {B} where A}, String, Bool},
            )
            _record_response_writer_symmetrization(
                Tuple{Type{Pair{A, B} where {B} where A}, String, Nothing},
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.negate), UInt64})
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.Broadcast._getindex), Tuple{Float64}, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.identity), Float64},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{0},
                        Nothing,
                        typeof(Base.identity),
                        Tuple{Float64},
                    },
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.getindex), Float64})
            _record_response_writer_symmetrization(
                Tuple{
                    Type{NamedTuple{(:read, :write, :append, :truncate), T} where T <: Tuple},
                    Tuple{Bool, Bool, Nothing, Nothing},
                },
            )
            _record_response_writer_symmetrization(Tuple{Dates.var"##s53#31", Vararg{Any, 5}})
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, Bool}, Int64}, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, Bool}, Int64}, Int64, Int64},
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.iterate), Pair{String, Bool}})
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.iterate), Pair{String, Bool}, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{Bool, Int64}, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{Bool, Int64}, Int64, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}},
            )

            _record_response_writer_symmetrization(Tuple{typeof(Base.:(!=)), UInt64, UInt64})
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(|)), UInt64, UInt64})
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(*)), UInt64, UInt64})
            _record_response_writer_symmetrization(Tuple{typeof(Base.signed), UInt64})
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(>)), UInt64, UInt64})
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{
                        (
                            :structure_file,
                            :structure_format,
                            :model_file,
                            :vasp_magnetic_input_file,
                        ),
                        Tuple{String, Symbol, String, String},
                    },
                    typeof(WannierNLQGSymmetrizationExt.write_response_symmetry_artifact),
                    String,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties},
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.prod), Tuple{Int64, Int64}})
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Fix1{F, T} where {T} where F},
                    Type{Base.MappingRF{F, T} where {T} where F},
                    Type,
                },
            )

            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{(:init,), Tuple{Int64}},
                    typeof(Base.mapreduce),
                    Type,
                    Function,
                    Tuple{Int64, Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.mapfoldl_impl),
                    Type{Int64},
                    typeof(Base.:(*)),
                    Int64,
                    Tuple{Int64, Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.all), Function, Core.SimpleVector},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.mapfoldl_impl),
                    Type{Int64},
                    typeof(Base.min),
                    Int64,
                    Tuple{Int64, Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.MappingRF{typeof(Base.identity), typeof(Base.promote_type)},
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.reverse), Tuple{Int64, Int64}})
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.map), typeof(Base.unchecked_oneto), Tuple{Int64, Int64}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.reverse), Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.to_shape), Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
            )
            _record_response_writer_symmetrization(
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
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.checkbounds),
                    Type{Bool},
                    Base.LinearIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.last),
                    Base.LinearIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.iterate),
                    Base.LinearIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.iterate),
                    Base.LinearIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
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
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.iterate),
                    Base.IteratorsMD.CartesianIndices{
                        2,
                        Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.tail),
                    Tuple{Base.IteratorsMD.CartesianIndex{2}, Base.IteratorsMD.CartesianIndex{2}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.iterate),
                    Base.IteratorsMD.CartesianIndices{
                        2,
                        Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}},
                    },
                    Base.IteratorsMD.CartesianIndex{2},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.MappingRF{typeof(Base.eltype), typeof(Base.promote_type)},
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.prod), Tuple{Int64}})
            _record_response_writer_symmetrization(Tuple{typeof(Base.top_set_bit), UInt64})
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(-)), Int32, Int32})

            _record_response_writer_symmetrization(
                Tuple{
                    Type{NamedTuple{(:atol, :rtol), T} where T <: Tuple},
                    Tuple{Float64, Float64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.merge),
                    NamedTuple{(), Tuple{}},
                    Base.Pairs{
                        Symbol,
                        Float64,
                        Tuple{Symbol, Symbol},
                        NamedTuple{(:atol, :rtol), Tuple{Float64, Float64}},
                    },
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.isfinite), Float64})
            _record_response_writer_symmetrization(
                Tuple{Base.Iterators.var"#5#6"{Tuple{Array{Float64, 2}, Array{Float64, 2}}}, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.MappingRF{typeof(Base.identity), typeof(Base.:(&))},
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    Base.MappingRF{
                        Base.var"#361#362"{SymmetryFoundation.var"#9#10"},
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(Tuple{Base.var"#58#59", Type})
            _record_response_writer_symmetrization(Tuple{Base.var"#325#329"{Tuple{Int64}}, Int64})
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.any), Function, Tuple{DataType, DataType, DataType}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base._any),
                    Base.var"#58#59",
                    Tuple{DataType, DataType, DataType},
                    Base.Colon,
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(*)), Int64})
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.Iterators.product),
                    Base.UnitRange{Int64},
                    Vararg{Base.UnitRange{Int64}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.in), NTuple{9, Int64}, Base.Set{Tuple}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.push!), Base.Set{Tuple}, NTuple{9, Int64}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.isequal), NTuple{9, Int64}, NTuple{9, Int64}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.hashindex), NTuple{9, Int64}, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.setindex!),
                    Base.Dict{Tuple, Array{Float64, 2}},
                    Array{Float64, 2},
                    NTuple{9, Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{Type{Pair{A, B} where {B} where A}, NTuple{9, Int64}, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.empty), Base.Dict{Any, Any}, Type{NTuple{9, Int64}}, Type{Int64}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.setindex!),
                    Base.Dict{NTuple{9, Int64}, Int64},
                    Int64,
                    NTuple{9, Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{NTuple{9, Int64}, Int64},
                    Base.Generator{
                        Base.Iterators.Enumerate{Array{Array{Int64, 2}, 1}},
                        SymmetryFoundation.var"#3#4",
                    },
                    Tuple{Int64, Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.haskey), Base.Dict{NTuple{9, Int64}, Int64}, NTuple{9, Int64}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.getindex), Base.Dict{Tuple, Array{Float64, 2}}, NTuple{9, Int64}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getindex),
                    Type{SymmetryFoundation.SymmetryOperation},
                    SymmetryFoundation.SymmetryOperation,
                    SymmetryFoundation.SymmetryOperation,
                    SymmetryFoundation.SymmetryOperation,
                    SymmetryFoundation.SymmetryOperation,
                    SymmetryFoundation.SymmetryOperation,
                    SymmetryFoundation.SymmetryOperation,
                    Vararg{SymmetryFoundation.SymmetryOperation},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    SymmetryFoundation.MagneticSymmetryInventory,
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.haskey),
                    Base.Dict{Tuple{Tuple, Bool}, Int64},
                    Tuple{NTuple{9, Int64}, Bool},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.setindex!),
                    Base.Dict{Tuple{Tuple, Bool}, Int64},
                    Int64,
                    Tuple{NTuple{9, Int64}, Bool},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.isequal),
                    Tuple{NTuple{9, Int64}, Bool},
                    Tuple{NTuple{9, Int64}, Bool},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.hashindex), Tuple{NTuple{9, Int64}, Bool}, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.empty), Base.Dict{String, Bool}, Type{String}, Type{Any}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, Bool},
                        Pair{String, Array{Int64, 1}},
                        Pair{String, Bool},
                        Pair{String, Array{Int64, 1}},
                        Pair{String, Bool},
                        Pair{String, Array{Array{Int64, 1}, 1}},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, Bool},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.empty),
                    Base.Set{Tuple{Tuple{Vararg{Int64}}, Bool}},
                    Type{Tuple{NTuple{9, Int64}, Bool}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.push!),
                    Base.Set{Tuple{NTuple{9, Int64}, Bool}},
                    Tuple{NTuple{9, Int64}, Bool},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Set{Tuple{NTuple{9, Int64}, Bool}},
                    Base.Generator{
                        Array{SymmetryFoundation.SymmetryOperation, 1},
                        WannierNLQGSymmetrizationExt.var"#114#118",
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.in),
                    Tuple{NTuple{9, Int64}, Bool},
                    Base.Set{Tuple{NTuple{9, Int64}, Bool}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGSymmetrizationExt.var"#116#119"{
                        Array{SymmetryFoundation.SymmetryOperation, 1},
                        Base.Set{Tuple{NTuple{9, Int64}, Bool}},
                    },
                    Array{SymmetryFoundation.SymmetryOperation, 1},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Iterators.Flatten{I} where I},
                    Base.Generator{
                        Array{SymmetryFoundation.SymmetryOperation, 1},
                        WannierNLQGSymmetrizationExt.var"#116#119"{
                            Array{SymmetryFoundation.SymmetryOperation, 1},
                            Base.Set{Tuple{NTuple{9, Int64}, Bool}},
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.all),
                    Base.Iterators.Flatten{
                        Base.Generator{
                            Array{SymmetryFoundation.SymmetryOperation, 1},
                            WannierNLQGSymmetrizationExt.var"#116#119"{
                                Array{SymmetryFoundation.SymmetryOperation, 1},
                                Base.Set{Tuple{NTuple{9, Int64}, Bool}},
                            },
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGSymmetrizationExt.var"#117#121"{
                        Base.Set{Tuple{NTuple{9, Int64}, Bool}},
                    },
                    Array{SymmetryFoundation.SymmetryOperation, 1},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.all),
                    Base.Generator{
                        Array{SymmetryFoundation.SymmetryOperation, 1},
                        WannierNLQGSymmetrizationExt.var"#117#121"{
                            Base.Set{Tuple{NTuple{9, Int64}, Bool}},
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGSymmetrizationExt.var"#142#146",
                    Array{SymmetryFoundation.SymmetryOperation, 1},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.collect),
                    Base.Generator{
                        Array{SymmetryFoundation.SymmetryOperation, 1},
                        WannierNLQGSymmetrizationExt.var"#142#146",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(SymmetryFoundation.group_invariant_cartesian_rotation_data),
                    Array{Array{Int64, 2}, 1},
                    Array{Float64, 2},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Array{Int64, 1}},
                        Pair{String, Float64},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    WannierNLQGSymmetrizationExt.var"#assign_source#132"{
                        Array{Int64, 1},
                        Array{Int64, 1},
                        Array{Array{NamedTuple{names, T} where {T <: Tuple} where names, 1}, 1},
                    },
                    Int64,
                    Base.BitArray{1},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    WannierNLQGSymmetrizationExt.var"#130#133"{Int64},
                    NamedTuple{
                        (:target, :fractional_residual, :cartesian_residual_angstrom),
                        Tuple{Int64, Float64, Float64},
                    },
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.max), Float64, Float64})
            _record_response_writer_symmetrization(Tuple{typeof(Base.:(<=)), Float64, Float64})
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, Int64},
                        Pair{String, Array{Int64, 1}},
                        Pair{String, Bool},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Bool},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Bool},
                        Pair{String, Bool},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.empty), Base.Dict{String, Int64}, Type{String}, Type{Any}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.merge!), Base.Dict{String, Any}, Base.Dict{String, Int64}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, Int64},
                        Pair{String, Array{Int64, 1}},
                        Pair{String, Bool},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Bool},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Bool},
                        Pair{String, Bool},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.push!), Array{Base.Dict{String, Any}, 1}, Base.Dict{String, Any}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, Array{Base.Dict{String, Any}, 1}},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, Array{Base.Dict{String, Any}, 1}},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Base.ReshapedArray{
                        Int64,
                        1,
                        LinearAlgebra.Transpose{Int64, Array{Int64, 2}},
                        Tuple{Base.MultiplicativeInverses.SignedMultiplicativeInverse{Int64}},
                    },
                    String,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Array{Float64, 1},
                    Char,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.Broadcast.broadcasted),
                    typeof(SymmetryFoundation.canonical_band_operation_key),
                    Array{SymmetryFoundation.SymmetryOperation, 1},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.Broadcast.materialize),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Nothing,
                        typeof(SymmetryFoundation.canonical_band_operation_key),
                        Tuple{Array{SymmetryFoundation.SymmetryOperation, 1}},
                    },
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.sort), Array{String, 1}})
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.:(==)), Array{String, 1}, Array{String, 1}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.length), Array{SymmetryFoundation.SymmetryOperation, 1}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.join), Array{String, 1}, String},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, Float64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, String},
                        Pair{String, Bool},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.empty), Base.Dict{String, Float64}, Type{String}, Type{Real}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.merge!), Base.Dict{String, Real}, Base.Dict{String, Float64}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.setindex!), Base.Dict{String, Real}, Int64, String},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Real},
                    Tuple{
                        Pair{String, Float64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, String},
                        Pair{String, Bool},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.empty), Base.Dict{String, Real}, Type{String}, Type{Any}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.merge!), Base.Dict{String, Any}, Base.Dict{String, Real}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, Float64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, String},
                        Pair{String, Bool},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, Array{Base.Dict{String, Any}, 1}},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, Array{Base.Dict{String, Any}, 1}},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.Iterators.enumerate),
                    Array{SymmetryFoundation.SymmetryOperation, 1},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGSymmetrizationExt.var"#144#148"{
                        NamedTuple{
                            (
                                :unique_rotations,
                                :raw_rotations,
                                :effective_rotations,
                                :metric,
                                :symmetrized_metric,
                                :effective_lattice_rows,
                                :relative_metric_change,
                                :maximum_correction,
                                :maximum_raw_orthogonality,
                                :maximum_effective_orthogonality,
                                :maximum_effective_closure,
                                :worst_effective_closure_pair,
                            ),
                            Tuple{
                                Array{Array{Int64, 2}, 1},
                                Base.Dict{Tuple, Array{Float64, 2}},
                                Base.Dict{Tuple, Array{Float64, 2}},
                                Array{Float64, 2},
                                Array{Float64, 2},
                                Array{Float64, 2},
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Tuple{Int64, Int64},
                            },
                        },
                        Symbol,
                    },
                    Base.Iterators.Enumerate{Array{SymmetryFoundation.SymmetryOperation, 1}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.collect),
                    Base.Generator{
                        Base.Iterators.Enumerate{Array{SymmetryFoundation.SymmetryOperation, 1}},
                        WannierNLQGSymmetrizationExt.var"#144#148"{
                            NamedTuple{
                                (
                                    :unique_rotations,
                                    :raw_rotations,
                                    :effective_rotations,
                                    :metric,
                                    :symmetrized_metric,
                                    :effective_lattice_rows,
                                    :relative_metric_change,
                                    :maximum_correction,
                                    :maximum_raw_orthogonality,
                                    :maximum_effective_orthogonality,
                                    :maximum_effective_closure,
                                    :worst_effective_closure_pair,
                                ),
                                Tuple{
                                    Array{Array{Int64, 2}, 1},
                                    Base.Dict{Tuple, Array{Float64, 2}},
                                    Base.Dict{Tuple, Array{Float64, 2}},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Float64,
                                    Float64,
                                    Float64,
                                    Float64,
                                    Float64,
                                    Tuple{Int64, Int64},
                                },
                            },
                            Symbol,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.empty),
                    Base.Dict{String, Array{Array{Int64, 1}, 1}},
                    Type{String},
                    Type{Array{T, 1} where T},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.merge!),
                    Base.Dict{String, Array{T, 1} where T},
                    Base.Dict{String, Array{Array{Int64, 1}, 1}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.setindex!),
                    Base.Dict{String, Array{T, 1} where T},
                    Array{Float64, 1},
                    String,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Array{T, 1} where T},
                    Tuple{
                        Pair{String, Array{Array{Int64, 1}, 1}},
                        Pair{String, Array{Float64, 1}},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Array{Int64, 1}},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.empty),
                    Base.Dict{String, Array{T, 1} where T},
                    Type{String},
                    Type{Any},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.merge!),
                    Base.Dict{String, Any},
                    Base.Dict{String, Array{T, 1} where T},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, Array{Array{Int64, 1}, 1}},
                        Pair{String, Array{Float64, 1}},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Array{Int64, 1}},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base._array_for),
                    Type{Base.Dict{String, Any}},
                    Base.HasShape{1},
                    Tuple{Base.OneTo{Int64}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.collect_to_with_first!),
                    Array{Base.Dict{String, Any}, 1},
                    Base.Dict{String, Any},
                    Base.Generator{
                        Base.Iterators.Enumerate{Array{SymmetryFoundation.SymmetryOperation, 1}},
                        WannierNLQGSymmetrizationExt.var"#144#148"{
                            NamedTuple{
                                (
                                    :unique_rotations,
                                    :raw_rotations,
                                    :effective_rotations,
                                    :metric,
                                    :symmetrized_metric,
                                    :effective_lattice_rows,
                                    :relative_metric_change,
                                    :maximum_correction,
                                    :maximum_raw_orthogonality,
                                    :maximum_effective_orthogonality,
                                    :maximum_effective_closure,
                                    :worst_effective_closure_pair,
                                ),
                                Tuple{
                                    Array{Array{Int64, 2}, 1},
                                    Base.Dict{Tuple, Array{Float64, 2}},
                                    Base.Dict{Tuple, Array{Float64, 2}},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Float64,
                                    Float64,
                                    Float64,
                                    Float64,
                                    Float64,
                                    Tuple{Int64, Int64},
                                },
                            },
                            Symbol,
                        },
                    },
                    Tuple{Int64, Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.collect_to_with_first!),
                    Array{Base.Dict{String, Any}, 1},
                    Base.Dict{String, Any},
                    Base.Generator{
                        Base.Iterators.Enumerate{Array{SymmetryFoundation.SymmetryOperation, 1}},
                        WannierNLQGSymmetrizationExt.var"#145#149"{
                            NamedTuple{
                                (
                                    :unique_rotations,
                                    :raw_rotations,
                                    :effective_rotations,
                                    :metric,
                                    :symmetrized_metric,
                                    :effective_lattice_rows,
                                    :relative_metric_change,
                                    :maximum_correction,
                                    :maximum_raw_orthogonality,
                                    :maximum_effective_orthogonality,
                                    :maximum_effective_closure,
                                    :worst_effective_closure_pair,
                                ),
                                Tuple{
                                    Array{Array{Int64, 2}, 1},
                                    Base.Dict{Tuple, Array{Float64, 2}},
                                    Base.Dict{Tuple, Array{Float64, 2}},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Float64,
                                    Float64,
                                    Float64,
                                    Float64,
                                    Float64,
                                    Tuple{Int64, Int64},
                                },
                            },
                            Array{Array{Int64, 1}, 1},
                            Symbol,
                        },
                    },
                    Tuple{Int64, Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.empty),
                    Base.Dict{String, String},
                    Type{String},
                    Type{Union{Nothing, String}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.merge!),
                    Base.Dict{String, Union{Nothing, String}},
                    Base.Dict{String, String},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Union{Nothing, String}},
                    Tuple{
                        Pair{String, String},
                        Pair{String, Nothing},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, Bool},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.empty),
                    Base.Dict{String, Union{Nothing, String}},
                    Type{String},
                    Type{Any},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.merge!),
                    Base.Dict{String, Any},
                    Base.Dict{String, Union{Nothing, String}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, String},
                        Pair{String, Nothing},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, Bool},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Any}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, String},
                        Pair{String, Nothing},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Base.Dict{String, Any}},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Union{Nothing, String}},
                    Tuple{
                        Pair{String, String},
                        Pair{String, Nothing},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Base.Dict{String, Any}},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, String},
                        Pair{String, Nothing},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Base.Dict{String, Any}},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, Array{Float64, 1}},
                        Pair{String, Array{Float64, 1}},
                        Pair{String, Nothing},
                        Pair{String, Array{Float64, 1}},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, String},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.getproperty),
                    NamedTuple{(:package, :version), Tuple{String, String}},
                    Symbol,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Pair{String, Base.Dict{String, String}},
                    Vararg{Pair{A, B} where {B} where A},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Nothing},
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Base.Dict{String, Any}},
                        Pair{String, String},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Bool},
                        Pair{String, String},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.empty),
                    Base.Dict{String, Base.Dict{String, String}},
                    Type{String},
                    Type{Union{Nothing, Base.Dict{String, String}}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.merge!),
                    Base.Dict{String, Union{Nothing, Base.Dict{String, String}}},
                    Base.Dict{String, Base.Dict{String, String}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.setindex!),
                    Base.Dict{String, Union{Nothing, Base.Dict{String, String}}},
                    Nothing,
                    String,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Union{Nothing, Base.Dict{String, String}}},
                    Tuple{
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Nothing},
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Base.Dict{String, Any}},
                        Pair{String, String},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Bool},
                        Pair{String, String},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.empty),
                    Base.Dict{String, Union{Nothing, Base.Dict{String, String}}},
                    Type{String},
                    Type{Any},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.merge!),
                    Base.Dict{String, Any},
                    Base.Dict{String, Union{Nothing, Base.Dict{String, String}}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Nothing},
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Base.Dict{String, Any}},
                        Pair{String, String},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Bool},
                        Pair{String, String},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Array{Array{Float64, 1}, 1}},
                    Tuple{
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, Array{String, 1}},
                        Pair{String, Nothing},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Array{T, 1} where T},
                    Tuple{
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, Array{String, 1}},
                        Pair{String, Nothing},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                        Pair{String, Array{Array{Float64, 1}, 1}},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Pair{A, B} where {B} where A},
                    String,
                    Base.Dict{String, Union{Nothing, Array{T, 1} where T}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{Type{Pair{A, B} where {B} where A}, String, Array{Base.Dict{String, Any}, 1}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Vararg{Pair{String, Base.Dict{String, Any}}, 5},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, Bool},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Array{Base.Dict{String, Any}, 1}},
                        Pair{String, Array{Base.Dict{String, Any}, 1}},
                        Pair{String, Base.Dict{String, Any}},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.empty), Base.Dict{String, Bool}, Type{String}, Type{Integer}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.merge!), Base.Dict{String, Integer}, Base.Dict{String, Bool}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.setindex!), Base.Dict{String, Integer}, Int64, String},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Integer},
                    Tuple{
                        Pair{String, Bool},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Array{Base.Dict{String, Any}, 1}},
                        Pair{String, Array{Base.Dict{String, Any}, 1}},
                        Pair{String, Base.Dict{String, Any}},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.empty), Base.Dict{String, Integer}, Type{String}, Type{Any}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.merge!), Base.Dict{String, Any}, Base.Dict{String, Integer}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, Bool},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Array{Base.Dict{String, Any}, 1}},
                        Pair{String, Array{Base.Dict{String, Any}, 1}},
                        Pair{String, Base.Dict{String, Any}},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Base.Dict{String, Any}},
                        Pair{String, Base.Dict{String, String}},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Pair{A, B} where {B} where A},
                    String,
                    Base.Dict{String, Base.Dict{String, _A} where _A},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Pair{String, Base.Dict{String, Any}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Pair{A, B} where {B} where A},
                    String,
                    Base.Dict{String, Base.Dict{String, Any}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Array{String, 1}},
                        Pair{String, Base.Dict{String, Base.Dict{String, _A} where _A}},
                        Pair{String, Base.Dict{String, Any}},
                        Pair{String, Base.Dict{String, Base.Dict{String, Any}}},
                        Pair{String, Base.Dict{String, Any}},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(Base.empty), Base.Dict{String, String}, Type{String}, Type{Any}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Array{String, 1}},
                        Pair{String, Base.Dict{String, Base.Dict{String, _A} where _A}},
                        Pair{String, Base.Dict{String, Any}},
                        Pair{String, Base.Dict{String, Base.Dict{String, Any}}},
                        Pair{String, Base.Dict{String, Any}},
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(JSON3.defaultminimum), Base.Dict{String, Any}},
            )

            _record_response_writer_symmetrization(Tuple{typeof(Base.add_sum), Int64, Int64})

            _record_response_writer_symmetrization(
                Tuple{Base.BottomRF{typeof(Base.add_sum)}, Base._InitialValue, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(JSON3.defaultminimum), Array{Float64, 1}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(JSON3.defaultminimum), Array{Array{Float64, 1}, 1}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(JSON3.defaultminimum), Base.Dict{String, String}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.defaultminimum),
                    Base.Dict{String, Base.Dict{String, _A} where _A},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.sum),
                    Base.Generator{
                        Base.Dict{String, Base.Dict{String, _A} where _A},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.var"##sum#343",
                    Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                    typeof(Base.sum),
                    Base.Generator{
                        Base.Dict{String, Base.Dict{String, _A} where _A},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.sum),
                    Function,
                    Base.Generator{
                        Base.Dict{String, Base.Dict{String, _A} where _A},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.var"##sum#342",
                    Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                    typeof(Base.sum),
                    Function,
                    Base.Generator{
                        Base.Dict{String, Base.Dict{String, _A} where _A},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.mapreduce),
                    Function,
                    Function,
                    Base.Generator{
                        Base.Dict{String, Base.Dict{String, _A} where _A},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.var"##mapreduce#339",
                    Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                    typeof(Base.mapreduce),
                    Function,
                    Function,
                    Base.Generator{
                        Base.Dict{String, Base.Dict{String, _A} where _A},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.mapfoldl),
                    Function,
                    Function,
                    Base.Generator{
                        Base.Dict{String, Base.Dict{String, _A} where _A},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.var"##mapfoldl#335",
                    Base._InitialValue,
                    typeof(Base.mapfoldl),
                    Function,
                    Function,
                    Base.Generator{
                        Base.Dict{String, Base.Dict{String, _A} where _A},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.mapfoldl_impl),
                    typeof(Base.identity),
                    typeof(Base.add_sum),
                    Base._InitialValue,
                    Base.Generator{
                        Base.Dict{String, Base.Dict{String, _A} where _A},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.foldl_impl),
                    Base.MappingRF{JSON3.var"#61#62", Base.BottomRF{typeof(Base.add_sum)}},
                    Base._InitialValue,
                    Base.Dict{String, Base.Dict{String, _A} where _A},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base._foldl_impl),
                    Base.MappingRF{JSON3.var"#61#62", Base.BottomRF{typeof(Base.add_sum)}},
                    Base._InitialValue,
                    Base.Dict{String, Base.Dict{String, _A} where _A},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.MappingRF{JSON3.var"#61#62", Base.BottomRF{typeof(Base.add_sum)}},
                    Base._InitialValue,
                    Pair{String, Base.Dict{String, _A} where _A},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{JSON3.var"#61#62", Pair{String, Base.Dict{String, _A} where _A}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.MappingRF{JSON3.var"#61#62", Base.BottomRF{typeof(Base.add_sum)}},
                    Int64,
                    Pair{String, Base.Dict{String, _A} where _A},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(JSON3.defaultminimum), Array{String, 1}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(JSON3.defaultminimum), Base.Dict{String, Base.Dict{String, Any}}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(JSON3.defaultminimum), Array{Base.Dict{String, Any}, 1}},
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(JSON3.defaultminimum), Array{Int64, 1}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.MappingRF{
                        typeof(JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                    Int64,
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{typeof(JSON3.defaultminimum), Array{Array{Int64, 1}, 1}},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.defaultminimum),
                    Base.Dict{String, Union{Nothing, Array{T, 1} where T}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.var"##sum#342",
                    Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                    typeof(Base.sum),
                    Function,
                    Base.Generator{
                        Base.Dict{String, Union{Nothing, Array{T, 1} where T}},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.mapreduce),
                    Function,
                    Function,
                    Base.Generator{
                        Base.Dict{String, Union{Nothing, Array{T, 1} where T}},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.var"##mapreduce#339",
                    Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                    typeof(Base.mapreduce),
                    Function,
                    Function,
                    Base.Generator{
                        Base.Dict{String, Union{Nothing, Array{T, 1} where T}},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.mapfoldl),
                    Function,
                    Function,
                    Base.Generator{
                        Base.Dict{String, Union{Nothing, Array{T, 1} where T}},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.var"##mapfoldl#335",
                    Base._InitialValue,
                    typeof(Base.mapfoldl),
                    Function,
                    Function,
                    Base.Generator{
                        Base.Dict{String, Union{Nothing, Array{T, 1} where T}},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.mapfoldl_impl),
                    typeof(Base.identity),
                    typeof(Base.add_sum),
                    Base._InitialValue,
                    Base.Generator{
                        Base.Dict{String, Union{Nothing, Array{T, 1} where T}},
                        JSON3.var"#61#62",
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.foldl_impl),
                    Base.MappingRF{JSON3.var"#61#62", Base.BottomRF{typeof(Base.add_sum)}},
                    Base._InitialValue,
                    Base.Dict{String, Union{Nothing, Array{T, 1} where T}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base._foldl_impl),
                    Base.MappingRF{JSON3.var"#61#62", Base.BottomRF{typeof(Base.add_sum)}},
                    Base._InitialValue,
                    Base.Dict{String, Union{Nothing, Array{T, 1} where T}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.MappingRF{JSON3.var"#61#62", Base.BottomRF{typeof(Base.add_sum)}},
                    Base._InitialValue,
                    Pair{String, Union{Nothing, Array{T, 1} where T}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.MappingRF{JSON3.var"#61#62", Base.BottomRF{typeof(Base.add_sum)}},
                    Int64,
                    Pair{String, Union{Nothing, Array{T, 1} where T}},
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.StringVector), Int64})

            _record_response_writer_symmetrization(
                Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.DictType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Base.Dict{String, Any},
                },
            )

            _record_response_writer_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{Array{UInt8, 1}, Int64, Int64}, Int64},
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.indexed_iterate),
                    Tuple{Array{UInt8, 1}, Int64, Int64},
                    Int64,
                    Int64,
                },
            )

            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Array{Float64, 1},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Array{Array{Float64, 1}, 1},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.DictType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Base.Dict{String, String},
                },
            )

            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.DictType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Base.Dict{String, Base.Dict{String, _A} where _A},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    JSON3.var"##write#84",
                    Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                    typeof(JSON3.write),
                    StructTypes.DictType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Base.Dict{String, Base.Dict{String, _A} where _A},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Array{String, 1},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.DictType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Base.Dict{String, Base.Dict{String, Any}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Array{Base.Dict{String, Any}, 1},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Array{Int64, 1},
                },
            )

            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Array{Array{Int64, 1}, 1},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.DictType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Base.Dict{String, Union{Nothing, Array{T, 1} where T}},
                },
            )
            _record_response_writer_symmetrization(Tuple{Type{String}, Array{UInt8, 1}})
            _record_response_writer_symmetrization(
                Tuple{typeof(JSON3.pretty), Base.IOStream, String, JSON3.AlignmentContext},
            )

            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    JSON3.Object{
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(Tuple{typeof(Base.add_sum), UInt64, UInt64})
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.defaultminimum),
                    JSON3.Object{
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )

            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.defaultminimum),
                    JSON3.Array{
                        JSON3.Array{
                            T,
                            S,
                            TT,
                        } where {
                            TT <: AbstractArray{UInt64, 1},
                        } where {S <: AbstractArray{UInt8, 1}} where T,
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.sum),
                    Function,
                    Base.Generator{
                        Base.OneTo{Int64},
                        JSON3.var"#59#60"{
                            JSON3.Array{
                                JSON3.Array{
                                    T,
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where {S <: AbstractArray{UInt8, 1}} where T,
                                Base.CodeUnits{UInt8, String},
                                Base.SubArray{
                                    UInt64,
                                    1,
                                    Array{UInt64, 1},
                                    Tuple{Base.UnitRange{Int64}},
                                    true,
                                },
                            },
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.var"##sum#342",
                    Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                    typeof(Base.sum),
                    Function,
                    Base.Generator{
                        Base.OneTo{Int64},
                        JSON3.var"#59#60"{
                            JSON3.Array{
                                JSON3.Array{
                                    T,
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where {S <: AbstractArray{UInt8, 1}} where T,
                                Base.CodeUnits{UInt8, String},
                                Base.SubArray{
                                    UInt64,
                                    1,
                                    Array{UInt64, 1},
                                    Tuple{Base.UnitRange{Int64}},
                                    true,
                                },
                            },
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.mapreduce),
                    Function,
                    Function,
                    Base.Generator{
                        Base.OneTo{Int64},
                        JSON3.var"#59#60"{
                            JSON3.Array{
                                JSON3.Array{
                                    T,
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where {S <: AbstractArray{UInt8, 1}} where T,
                                Base.CodeUnits{UInt8, String},
                                Base.SubArray{
                                    UInt64,
                                    1,
                                    Array{UInt64, 1},
                                    Tuple{Base.UnitRange{Int64}},
                                    true,
                                },
                            },
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.var"##mapreduce#339",
                    Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                    typeof(Base.mapreduce),
                    Function,
                    Function,
                    Base.Generator{
                        Base.OneTo{Int64},
                        JSON3.var"#59#60"{
                            JSON3.Array{
                                JSON3.Array{
                                    T,
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where {S <: AbstractArray{UInt8, 1}} where T,
                                Base.CodeUnits{UInt8, String},
                                Base.SubArray{
                                    UInt64,
                                    1,
                                    Array{UInt64, 1},
                                    Tuple{Base.UnitRange{Int64}},
                                    true,
                                },
                            },
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.mapfoldl),
                    Function,
                    Function,
                    Base.Generator{
                        Base.OneTo{Int64},
                        JSON3.var"#59#60"{
                            JSON3.Array{
                                JSON3.Array{
                                    T,
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where {S <: AbstractArray{UInt8, 1}} where T,
                                Base.CodeUnits{UInt8, String},
                                Base.SubArray{
                                    UInt64,
                                    1,
                                    Array{UInt64, 1},
                                    Tuple{Base.UnitRange{Int64}},
                                    true,
                                },
                            },
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.var"##mapfoldl#335",
                    Base._InitialValue,
                    typeof(Base.mapfoldl),
                    Function,
                    Function,
                    Base.Generator{
                        Base.OneTo{Int64},
                        JSON3.var"#59#60"{
                            JSON3.Array{
                                JSON3.Array{
                                    T,
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where {S <: AbstractArray{UInt8, 1}} where T,
                                Base.CodeUnits{UInt8, String},
                                Base.SubArray{
                                    UInt64,
                                    1,
                                    Array{UInt64, 1},
                                    Tuple{Base.UnitRange{Int64}},
                                    true,
                                },
                            },
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.mapfoldl_impl),
                    typeof(JSON3.defaultminimum),
                    typeof(Base.add_sum),
                    Base._InitialValue,
                    Base.Generator{
                        Base.OneTo{Int64},
                        JSON3.var"#59#60"{
                            JSON3.Array{
                                JSON3.Array{
                                    T,
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where {S <: AbstractArray{UInt8, 1}} where T,
                                Base.CodeUnits{UInt8, String},
                                Base.SubArray{
                                    UInt64,
                                    1,
                                    Array{UInt64, 1},
                                    Tuple{Base.UnitRange{Int64}},
                                    true,
                                },
                            },
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.foldl_impl),
                    Base.MappingRF{
                        JSON3.var"#59#60"{
                            JSON3.Array{
                                JSON3.Array{
                                    T,
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where {S <: AbstractArray{UInt8, 1}} where T,
                                Base.CodeUnits{UInt8, String},
                                Base.SubArray{
                                    UInt64,
                                    1,
                                    Array{UInt64, 1},
                                    Tuple{Base.UnitRange{Int64}},
                                    true,
                                },
                            },
                        },
                        Base.MappingRF{
                            typeof(JSON3.defaultminimum),
                            Base.BottomRF{typeof(Base.add_sum)},
                        },
                    },
                    Base._InitialValue,
                    Base.OneTo{Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base._foldl_impl),
                    Base.MappingRF{
                        JSON3.var"#59#60"{
                            JSON3.Array{
                                JSON3.Array{
                                    T,
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where {S <: AbstractArray{UInt8, 1}} where T,
                                Base.CodeUnits{UInt8, String},
                                Base.SubArray{
                                    UInt64,
                                    1,
                                    Array{UInt64, 1},
                                    Tuple{Base.UnitRange{Int64}},
                                    true,
                                },
                            },
                        },
                        Base.MappingRF{
                            typeof(JSON3.defaultminimum),
                            Base.BottomRF{typeof(Base.add_sum)},
                        },
                    },
                    Base._InitialValue,
                    Base.OneTo{Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.MappingRF{
                        JSON3.var"#59#60"{
                            JSON3.Array{
                                JSON3.Array{
                                    T,
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where {S <: AbstractArray{UInt8, 1}} where T,
                                Base.CodeUnits{UInt8, String},
                                Base.SubArray{
                                    UInt64,
                                    1,
                                    Array{UInt64, 1},
                                    Tuple{Base.UnitRange{Int64}},
                                    true,
                                },
                            },
                        },
                        Base.MappingRF{
                            typeof(JSON3.defaultminimum),
                            Base.BottomRF{typeof(Base.add_sum)},
                        },
                    },
                    Base._InitialValue,
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    JSON3.var"#59#60"{
                        JSON3.Array{
                            JSON3.Array{
                                T,
                                S,
                                TT,
                            } where {
                                TT <: AbstractArray{UInt64, 1},
                            } where {S <: AbstractArray{UInt8, 1}} where T,
                            Base.CodeUnits{UInt8, String},
                            Base.SubArray{
                                UInt64,
                                1,
                                Array{UInt64, 1},
                                Tuple{Base.UnitRange{Int64}},
                                true,
                            },
                        },
                    },
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.MappingRF{
                        JSON3.var"#59#60"{
                            JSON3.Array{
                                JSON3.Array{
                                    T,
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where {S <: AbstractArray{UInt8, 1}} where T,
                                Base.CodeUnits{UInt8, String},
                                Base.SubArray{
                                    UInt64,
                                    1,
                                    Array{UInt64, 1},
                                    Tuple{Base.UnitRange{Int64}},
                                    true,
                                },
                            },
                        },
                        Base.MappingRF{
                            typeof(JSON3.defaultminimum),
                            Base.BottomRF{typeof(Base.add_sum)},
                        },
                    },
                    Int64,
                    Int64,
                },
            )

            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.DictType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    JSON3.Object{
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )

            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    JSON3.Array{
                        JSON3.Array{
                            T,
                            S,
                            TT,
                        } where {
                            TT <: AbstractArray{UInt64, 1},
                        } where {S <: AbstractArray{UInt8, 1}} where T,
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    JSON3.var"##write#86",
                    Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    JSON3.Array{
                        JSON3.Array{
                            T,
                            S,
                            TT,
                        } where {
                            TT <: AbstractArray{UInt64, 1},
                        } where {S <: AbstractArray{UInt8, 1}} where T,
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )

            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    JSON3.Array{
                        JSON3.Array{
                            T,
                            S,
                            TT,
                        } where {
                            TT <: AbstractArray{UInt64, 1},
                        } where {S <: AbstractArray{UInt8, 1}} where T,
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.length),
                    JSON3.Array{
                        JSON3.Array{
                            T,
                            S,
                            TT,
                        } where {
                            TT <: AbstractArray{UInt64, 1},
                        } where {S <: AbstractArray{UInt8, 1}} where T,
                        Base.CodeUnits{UInt8, String},
                        Array{UInt64, 1},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.Iterators.enumerate),
                    JSON3.Array{
                        JSON3.Array{
                            T,
                            S,
                            TT,
                        } where {
                            TT <: AbstractArray{UInt64, 1},
                        } where {S <: AbstractArray{UInt8, 1}} where T,
                        Base.CodeUnits{UInt8, String},
                        Array{UInt64, 1},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        JSON3.Array{
                            JSON3.Array{
                                T,
                                S,
                                TT,
                            } where {
                                TT <: AbstractArray{UInt64, 1},
                            } where {S <: AbstractArray{UInt8, 1}} where T,
                            Base.CodeUnits{UInt8, String},
                            Array{UInt64, 1},
                        },
                    },
                    Tuple{Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        JSON3.Array{
                            JSON3.Array{
                                T,
                                S,
                                TT,
                            } where {
                                TT <: AbstractArray{UInt64, 1},
                            } where {S <: AbstractArray{UInt8, 1}} where T,
                            Base.CodeUnits{UInt8, String},
                            Array{UInt64, 1},
                        },
                    },
                    Tuple{Int64, Tuple{Int64, Int64}},
                },
            )

            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.defaultminimum),
                    JSON3.Array{
                        Union{},
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    JSON3.Array{
                        Union{},
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    JSON3.Array{
                        Union{},
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.length),
                    JSON3.Array{Union{}, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.defaultminimum),
                    JSON3.Array{
                        JSON3.Object{
                            S,
                            TT,
                        } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.MappingRF{
                        JSON3.var"#59#60"{
                            JSON3.Array{
                                JSON3.Object{
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where S <: AbstractArray{UInt8, 1},
                                Base.CodeUnits{UInt8, String},
                                Base.SubArray{
                                    UInt64,
                                    1,
                                    Array{UInt64, 1},
                                    Tuple{Base.UnitRange{Int64}},
                                    true,
                                },
                            },
                        },
                        Base.MappingRF{
                            typeof(JSON3.defaultminimum),
                            Base.BottomRF{typeof(Base.add_sum)},
                        },
                    },
                    Base._InitialValue,
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    Base.MappingRF{
                        JSON3.var"#59#60"{
                            JSON3.Array{
                                JSON3.Object{
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where S <: AbstractArray{UInt8, 1},
                                Base.CodeUnits{UInt8, String},
                                Base.SubArray{
                                    UInt64,
                                    1,
                                    Array{UInt64, 1},
                                    Tuple{Base.UnitRange{Int64}},
                                    true,
                                },
                            },
                        },
                        Base.MappingRF{
                            typeof(JSON3.defaultminimum),
                            Base.BottomRF{typeof(Base.add_sum)},
                        },
                    },
                    Int64,
                    Int64,
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    JSON3.Array{
                        JSON3.Object{
                            S,
                            TT,
                        } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    JSON3.Array{
                        JSON3.Object{
                            S,
                            TT,
                        } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.length),
                    JSON3.Array{
                        JSON3.Object{
                            S,
                            TT,
                        } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Array{UInt64, 1},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.Iterators.enumerate),
                    JSON3.Array{
                        JSON3.Object{
                            S,
                            TT,
                        } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Array{UInt64, 1},
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        JSON3.Array{
                            JSON3.Object{
                                S,
                                TT,
                            } where {
                                TT <: AbstractArray{UInt64, 1},
                            } where S <: AbstractArray{UInt8, 1},
                            Base.CodeUnits{UInt8, String},
                            Array{UInt64, 1},
                        },
                    },
                    Tuple{Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        JSON3.Array{
                            JSON3.Object{
                                S,
                                TT,
                            } where {
                                TT <: AbstractArray{UInt64, 1},
                            } where S <: AbstractArray{UInt8, 1},
                            Base.CodeUnits{UInt8, String},
                            Array{UInt64, 1},
                        },
                    },
                    Tuple{Int64, Tuple{Int64, Int64}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.defaultminimum),
                    JSON3.Array{
                        Float64,
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.defaultminimum),
                    JSON3.Array{
                        String,
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    JSON3.Array{
                        Float64,
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    JSON3.Array{
                        String,
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    JSON3.Array{
                        Float64,
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.length),
                    JSON3.Array{Float64, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.Iterators.enumerate),
                    JSON3.Array{Float64, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        JSON3.Array{Float64, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                    },
                    Tuple{Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        JSON3.Array{Float64, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                    },
                    Tuple{Int64, Tuple{Int64, Int64}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(JSON3.write),
                    JSON3.Array{
                        String,
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.length),
                    JSON3.Array{String, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.Iterators.enumerate),
                    JSON3.Array{String, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        JSON3.Array{String, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                    },
                    Tuple{Int64},
                },
            )
            _record_response_writer_symmetrization(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        JSON3.Array{String, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                    },
                    Tuple{Int64, Tuple{Int64, Int64}},
                },
            )
        end
    end
end
