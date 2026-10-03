# Real first public solve, actual ordinary/localization branches and MPI ranks.
# Signatures only; no solve, file write, or MPI initialization during precompilation.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let WannierNLQGOperatorBundleExt=Base.get_extension(
                WannierNLQG,
                :WannierNLQGOperatorBundleExt,
            )
            _record_early_prepare(
                Tuple{
                    Base.MappingRF{
                        PAWMatrixElements.JSON3.var"#59#60"{
                            PAWMatrixElements.JSON3.Array{
                                PAWMatrixElements.JSON3.Object{
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where S <: AbstractArray{UInt8, 1},
                                Base.CodeUnits{UInt8, String},
                                Array{UInt64, 1},
                            },
                        },
                        Base.MappingRF{
                            typeof(PAWMatrixElements.JSON3.defaultminimum),
                            Base.BottomRF{typeof(Base.add_sum)},
                        },
                    },
                    Base._InitialValue,
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    Base.MappingRF{
                        PAWMatrixElements.JSON3.var"#59#60"{
                            PAWMatrixElements.JSON3.Array{
                                PAWMatrixElements.JSON3.Object{
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where S <: AbstractArray{UInt8, 1},
                                Base.CodeUnits{UInt8, String},
                                Array{UInt64, 1},
                            },
                        },
                        Base.MappingRF{
                            typeof(PAWMatrixElements.JSON3.defaultminimum),
                            Base.BottomRF{typeof(Base.add_sum)},
                        },
                    },
                    Int64,
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    Base.MappingRF{
                        typeof(PAWMatrixElements.JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                    Int64,
                    Int64,
                },
            )
            _record_early_prepare(Tuple{Base.var"##s1116#1003", Vararg{Any, 5}})
            _record_early_prepare(
                Tuple{
                    Core.Compiler.var"#464#465"{
                        Core.Compiler.NativeInterpreter,
                        Nothing,
                        Core.Compiler.IRInterpretationState,
                    },
                    Any,
                },
            )
            false
            false
            _record_early_prepare(
                Tuple{
                    Type{Array{Base.Complex{Float64}, 2}},
                    LinearAlgebra.UniformScaling{Bool},
                    Int64,
                    Int64,
                },
            )
            _record_early_prepare(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
            _record_early_prepare(
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64},
            )
            _record_early_prepare(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
            _record_early_prepare(Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}})
            _record_early_prepare(
                Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64},
            )
            _record_early_prepare(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
            _record_early_prepare(
                Tuple{Type{Array{Int8, N} where N}, UndefInitializer, Int64, Int64},
            )
            _record_early_prepare(
                Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64, Int64},
            )
            _record_early_prepare(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64})
            _record_early_prepare(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
            false
            _record_early_prepare(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{
                            String,
                            PAWMatrixElements.JSON3.Array{
                                PAWMatrixElements.JSON3.Object{
                                    S,
                                    TT,
                                } where {
                                    TT <: AbstractArray{UInt64, 1},
                                } where S <: AbstractArray{UInt8, 1},
                                Base.CodeUnits{UInt8, String},
                                Array{UInt64, 1},
                            },
                        },
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Bool},
                        Vararg{Pair{String, Float64}, 7},
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Base.Dict{String, String}},
                    },
                },
            )
            false
            false
            false
            false
            false
            false
            false
            _record_early_prepare(Tuple{Type{Base.Set{T} where T}, Array{String, 1}})
            false
            _record_early_prepare(
                Tuple{
                    Type{
                        GenericMemory{
                            :not_atomic,
                            Array{Base.Complex{Float64}, 2},
                            Core.AddrSpace{Core}(0x00),
                        },
                    },
                    UndefInitializer,
                    Int64,
                },
            )
            false
            _record_early_prepare(
                Tuple{
                    Type{GenericMemory{:not_atomic, Base.BitArray{1}, Core.AddrSpace{Core}(0x00)}},
                    UndefInitializer,
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}},
            )
            _record_early_prepare(
                Tuple{Type{NamedTuple{(:construction_policy,), T} where T <: Tuple}, Tuple{Symbol}},
            )
            _record_early_prepare(
                Tuple{Type{NamedTuple{(:init,), T} where T <: Tuple}, Tuple{Float64}},
            )
            _record_early_prepare(
                Tuple{Type{NamedTuple{(:message,), T} where T <: Tuple}, Tuple{String}},
            )
            _record_early_prepare(
                Tuple{
                    Type{
                        NamedTuple{
                            (
                                :raw_amn_alignment_applied,
                                :raw_amn_alignment_minimum_singular_value,
                                :raw_amn_alignment_maximum_condition,
                                :raw_amn_alignment_projector_drift,
                                :raw_amn_alignment_completion_count,
                                :localization_initial_frames,
                            ),
                            T,
                        } where T <: Tuple,
                    },
                    Tuple{Bool, Float64, Float64, Float64, Int64, Nothing},
                },
            )
            _record_early_prepare(
                Tuple{
                    Type{NamedTuple{(:retained_disentanglement_nonconverged,), T} where T <: Tuple},
                    Tuple{Bool},
                },
            )
            _record_early_prepare(
                Tuple{
                    Type{NamedTuple{(:success, :code, :message), T} where T <: Tuple},
                    Tuple{Bool, Symbol, String},
                },
            )
            _record_early_prepare(
                Tuple{
                    Type{NamedTuple{(:success, :code, :message, :kpoint), T} where T <: Tuple},
                    Tuple{Bool, Symbol, String, Int64},
                },
            )
            _record_early_prepare(
                Tuple{
                    Type{
                        NamedTuple{
                            (:success, :code, :message, :kpoint, :invariant_residual),
                            T,
                        } where T <: Tuple,
                    },
                    Tuple{Bool, Symbol, String, Int64, Float64},
                },
            )
            _record_early_prepare(
                Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Any}},
            )
            _record_early_prepare(
                Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, String}},
            )
            _record_early_prepare(
                Tuple{
                    Type{Pair{A, B} where {B} where A},
                    String,
                    PAWMatrixElements.JSON3.Array{
                        PAWMatrixElements.JSON3.Object{
                            S,
                            TT,
                        } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Array{UInt64, 1},
                    },
                },
            )
            _record_early_prepare(Tuple{Type{Pair{A, B} where {B} where A}, String, Nothing})
            _record_early_prepare(
                Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64},
            )
            _record_early_prepare(
                Tuple{
                    Type{Pair{A, B} where {B} where A},
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Nothing,
                },
            )
            _record_early_prepare(Tuple{Type{String}, Array{UInt8, 1}})
            _record_early_prepare(Tuple{Type{UInt8}, Bool})
            _record_early_prepare(Tuple{Type{UInt8}, UInt8})
            _record_early_prepare(Tuple{Type{UInt8}, WannierNLQG.Core.RealSpaceOperatorKind})
            false
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
                    String,
                    String,
                    Int64,
                    Float64,
                    Array{Base.Complex{Float64}, 4},
                    Array{Base.Complex{Float64}, 4},
                    Array{Float64, 1},
                    Int64,
                    Symbol,
                },
            )
            false
            false
            false
            false
            _record_early_prepare(Tuple{typeof(Base.:(&)), Int64, Int64})
            _record_early_prepare(
                Tuple{
                    typeof(Base.:(*)),
                    Array{Base.Complex{Float64}, 2},
                    Array{Base.Complex{Float64}, 2},
                },
            )
            _record_early_prepare(Tuple{typeof(Base.:(*)), Int64, Float64})
            _record_early_prepare(
                Tuple{
                    typeof(Base.:(*)),
                    LinearAlgebra.Adjoint{Base.Complex{Float64}, Array{Base.Complex{Float64}, 2}},
                    Array{Base.Complex{Float64}, 2},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.:(-)),
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
                    LinearAlgebra.Adjoint{
                        Base.Complex{Float64},
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
                },
            )
            _record_early_prepare(Tuple{typeof(Base.:(/)), Float64, Int64})
            _record_early_prepare(Tuple{typeof(Base.:(<=)), Float64, Float64})
            _record_early_prepare(Tuple{typeof(Base.:(==)), Array{Int64, 1}, Array{Int64, 1}})
            _record_early_prepare(Tuple{typeof(Base.:(==)), Array{UInt64, 1}, Array{UInt64, 1}})
            _record_early_prepare(Tuple{typeof(Base.:(==)), Bool, Bool})
            _record_early_prepare(
                Tuple{typeof(Base.:(==)), Tuple{Int64, Int64, Int64}, Tuple{Int64, Int64, Int64}},
            )
            _record_early_prepare(
                Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}},
            )
            _record_early_prepare(Tuple{typeof(Base.:(==)), UInt64, UInt64})
            _record_early_prepare(Tuple{typeof(Base.:(>)), Float64, Float64})
            _record_early_prepare(
                Tuple{
                    typeof(Base.Broadcast._broadcast_getindex),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.Style{Tuple},
                        Nothing,
                        Type{String},
                        Tuple{Tuple{Symbol, Symbol}},
                    },
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{typeof(Base.Broadcast._broadcast_getindex_evalf), Type{String}, Symbol},
            )
            _record_early_prepare(
                Tuple{typeof(Base.Broadcast._getindex), Tuple{Tuple{Symbol, Symbol}}, Int64},
            )
            _record_early_prepare(
                Tuple{typeof(Base.Broadcast.broadcasted), Type{String}, Tuple{Symbol, Symbol}},
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.Broadcast.broadcasted),
                    typeof(Base.:(*)),
                    Float64,
                    Array{Base.Complex{Float64}, 3},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.Broadcast.broadcasted),
                    typeof(Base.:(+)),
                    Base.SubArray{
                        Base.Complex{Float64},
                        3,
                        Array{Base.Complex{Float64}, 4},
                        Tuple{
                            Base.Slice{Base.OneTo{Int64}},
                            Base.Slice{Base.OneTo{Int64}},
                            Base.Slice{Base.OneTo{Int64}},
                            Int64,
                        },
                        true,
                    },
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{3},
                        Nothing,
                        typeof(Base.:(*)),
                        Tuple{Float64, Array{Base.Complex{Float64}, 3}},
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.Broadcast.broadcasted),
                    typeof(WannierNLQG.Core.real_space_operator_name),
                    Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.Broadcast.instantiate),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.Style{Tuple},
                        Nothing,
                        Type{String},
                        Tuple{Tuple{Symbol, Symbol}},
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.Broadcast.materialize!),
                    Base.SubArray{
                        Base.Complex{Float64},
                        3,
                        Array{Base.Complex{Float64}, 4},
                        Tuple{
                            Base.Slice{Base.OneTo{Int64}},
                            Base.Slice{Base.OneTo{Int64}},
                            Base.Slice{Base.OneTo{Int64}},
                            Int64,
                        },
                        true,
                    },
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{3},
                        Nothing,
                        typeof(Base.:(+)),
                        Tuple{
                            Base.SubArray{
                                Base.Complex{Float64},
                                3,
                                Array{Base.Complex{Float64}, 4},
                                Tuple{
                                    Base.Slice{Base.OneTo{Int64}},
                                    Base.Slice{Base.OneTo{Int64}},
                                    Base.Slice{Base.OneTo{Int64}},
                                    Int64,
                                },
                                true,
                            },
                            Base.Broadcast.Broadcasted{
                                Base.Broadcast.DefaultArrayStyle{3},
                                Nothing,
                                typeof(Base.:(*)),
                                Tuple{Float64, Array{Base.Complex{Float64}, 3}},
                            },
                        },
                    },
                },
            )
            _record_early_prepare(
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
            _record_early_prepare(
                Tuple{
                    typeof(Base.Broadcast.materialize),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.Style{Tuple},
                        Nothing,
                        Type{String},
                        Tuple{Tuple{Symbol, Symbol}},
                    },
                },
            )
            false
            _record_early_prepare(
                Tuple{
                    typeof(Base.Order.lt),
                    Base.Order.ForwardOrdering,
                    Tuple{Int64, String},
                    Tuple{Int64, String},
                },
            )
            _record_early_prepare(Tuple{typeof(Base.StringVector), Int64})
            _record_early_prepare(
                Tuple{
                    typeof(Base._all),
                    Base.Fix2{typeof(Base.:(>)), Int64},
                    Array{Int64, 1},
                    Base.Colon,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base._array_for),
                    Type{Array{Float64, 1}},
                    Base.HasShape{1},
                    Tuple{Base.OneTo{Int64}},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base._array_for),
                    Type{Array{Int64, 1}},
                    Base.HasShape{1},
                    Tuple{Base.OneTo{Int64}},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base._mapreduce),
                    typeof(LinearAlgebra.norm),
                    typeof(Base.max),
                    Base.IndexLinear,
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base._mapreduce_dim),
                    Function,
                    Function,
                    Base._InitialValue,
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    Base.Colon,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base._mapreduce_dim),
                    Function,
                    Function,
                    Base._InitialValue,
                    Array{Base.Complex{Float64}, 2},
                    Base.Colon,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base._mapreduce_dim),
                    Function,
                    Function,
                    Float64,
                    Array{Base.Complex{Float64}, 2},
                    Base.Colon,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base._maximum),
                    Function,
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    Base.Colon,
                },
            )
            _record_early_prepare(Tuple{typeof(Base.add_sum), Int64, Int64})
            _record_early_prepare(Tuple{typeof(Base.add_sum), UInt64, UInt64})
            _record_early_prepare(Tuple{typeof(Base.adjoint), Array{Base.Complex{Float64}, 2}})
            false
            false
            false
            false
            _record_early_prepare(
                Tuple{typeof(Base.collect), Base.KeySet{String, Base.Dict{String, Any}}},
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.collect_to!),
                    Array{Any, 1},
                    Base.Generator{
                        NTuple{20, Symbol},
                        WannierNLQG.Wannierization.var"#101#102"{
                            WannierNLQG.Wannierization.WannierizationSolverConfig,
                        },
                    },
                    Int64,
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.collect_to!),
                    Array{Any, 1},
                    Base.Generator{
                        NTuple{21, Symbol},
                        WannierNLQG.Wannierization.var"#101#102"{
                            WannierNLQG.Wannierization.WannierizationOutputConfig,
                        },
                    },
                    Int64,
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.collect_to!),
                    Array{Any, 1},
                    Base.Generator{
                        NTuple{28, Symbol},
                        WannierNLQG.Wannierization.var"#101#102"{
                            WannierNLQG.Wannierization.WannierizationInputConfig,
                        },
                    },
                    Int64,
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.collect_to!),
                    Array{Nothing, 1},
                    Base.Generator{
                        NTuple{4, Symbol},
                        WannierNLQG.Wannierization.var"#101#102"{
                            WannierNLQG.Wannierization.WannierizationCheckpointConfig,
                        },
                    },
                    Int64,
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.collect_to!),
                    Array{Union{Nothing, Int64}, 1},
                    Base.Generator{
                        Tuple{Symbol, Symbol},
                        WannierNLQG.Wannierization.var"#101#102"{
                            WannierNLQG.Wannierization.WannierizationRuntimeConfig,
                        },
                    },
                    Int64,
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.collect_to!),
                    Array{Union{Nothing, String}, 1},
                    Base.Generator{
                        NTuple{4, Symbol},
                        WannierNLQG.Wannierization.var"#101#102"{
                            WannierNLQG.Wannierization.WannierizationCheckpointConfig,
                        },
                    },
                    Int64,
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.collect_to!),
                    Array{Union{Nothing, Symbol}, 1},
                    Base.Generator{
                        NTuple{28, Symbol},
                        WannierNLQG.Wannierization.var"#101#102"{
                            WannierNLQG.Wannierization.WannierizationInputConfig,
                        },
                    },
                    Int64,
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.collect_to!),
                    Array{Union{Nothing, Tuple{Symbol, Symbol}}, 1},
                    Base.Generator{
                        NTuple{21, Symbol},
                        WannierNLQG.Wannierization.var"#101#102"{
                            WannierNLQG.Wannierization.WannierizationOutputConfig,
                        },
                    },
                    Int64,
                    Int64,
                },
            )
            false
            false
            _record_early_prepare(
                Tuple{
                    typeof(Base.collect_to_with_first!),
                    Array{Nothing, 1},
                    Nothing,
                    Base.Generator{
                        NTuple{21, Symbol},
                        WannierNLQG.Wannierization.var"#101#102"{
                            WannierNLQG.Wannierization.WannierizationOutputConfig,
                        },
                    },
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.collect_to_with_first!),
                    Array{Nothing, 1},
                    Nothing,
                    Base.Generator{
                        NTuple{4, Symbol},
                        WannierNLQG.Wannierization.var"#101#102"{
                            WannierNLQG.Wannierization.WannierizationCheckpointConfig,
                        },
                    },
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.conj),
                    Base.SubArray{
                        Base.Complex{Float64},
                        3,
                        Array{Base.Complex{Float64}, 4},
                        Tuple{
                            Base.Slice{Base.OneTo{Int64}},
                            Base.Slice{Base.OneTo{Int64}},
                            Base.Slice{Base.OneTo{Int64}},
                            Int64,
                        },
                        true,
                    },
                },
            )
            _record_early_prepare(Tuple{typeof(Base.convert), Type{Bool}, Bool})
            false
            _record_early_prepare(Tuple{typeof(Base.copy), Array{Int64, 1}})
            _record_early_prepare(
                Tuple{
                    typeof(Base.copy),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.Style{Tuple},
                        Nothing,
                        Type{String},
                        Tuple{Tuple{Symbol, Symbol}},
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.copy),
                    GenericMemory{:not_atomic, Base.Complex{Float64}, Core.AddrSpace{Core}(0x00)},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.copy),
                    GenericMemory{:not_atomic, UInt64, Core.AddrSpace{Core}(0x00)},
                },
            )
            false
            _record_early_prepare(Tuple{typeof(Base.eachindex), Array{Float64, 1}})
            _record_early_prepare(Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}})
            false
            false
            _record_early_prepare(Tuple{typeof(Base.get), Base.Dict{String, Any}, String, String})
            _record_early_prepare(
                Tuple{typeof(Base.get), Base.Dict{String, String}, String, String},
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.get),
                    Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                    Tuple{Int64, Int64, Int64},
                    Nothing,
                },
            )
            _record_early_prepare(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
            _record_early_prepare(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
            false
            _record_early_prepare(Tuple{typeof(Base.getindex), Array{UInt64, 1}, Int64})
            _record_early_prepare(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
            false
            _record_early_prepare(Tuple{typeof(Base.getindex), Type{Int64}, Int64})
            false
            _record_early_prepare(
                Tuple{
                    typeof(Base.getindex),
                    Type{WannierNLQG.SymmetryFoundation.SymmetryOperation},
                    WannierNLQG.SymmetryFoundation.SymmetryOperation,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.getindex),
                    Type{WannierNLQG.Wannierization.TBSymmetryMetric},
                    WannierNLQG.Wannierization.TBSymmetryMetric,
                    WannierNLQG.Wannierization.TBSymmetryMetric,
                    WannierNLQG.Wannierization.TBSymmetryMetric,
                    WannierNLQG.Wannierization.TBSymmetryMetric,
                    WannierNLQG.Wannierization.TBSymmetryMetric,
                    WannierNLQG.Wannierization.TBSymmetryMetric,
                    Vararg{WannierNLQG.Wannierization.TBSymmetryMetric},
                },
            )
            _record_early_prepare(
                Tuple{typeof(Base.getindex), Type{WannierNLQG.Wannierization.TBSymmetryMetric}},
            )
            false
            false
            false
            _record_early_prepare(
                Tuple{
                    typeof(Base.getindex),
                    Type{WannierNLQG.Wannierization.WannierizationIteration},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.getproperty),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.Style{Tuple},
                        Nothing,
                        Type{String},
                        Tuple{Tuple{Symbol, Symbol}},
                    },
                    Symbol,
                },
            )
            _record_early_prepare(
                Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol},
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.getproperty),
                    PAWMatrixElements.JSON3.Object{Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                    Symbol,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.getproperty),
                    NamedTuple{
                        (
                            :mmn,
                            :amn,
                            :mmn_file,
                            :amn_file,
                            :raw_amn_file,
                            :source_kind,
                            :paw_result,
                            :gauge_sha256,
                            :gauge_provenance_file,
                        ),
                        Tuple{
                            WannierNLQG.IO.WannierMMN,
                            Nothing,
                            String,
                            Nothing,
                            Nothing,
                            String,
                            Nothing,
                            String,
                            Nothing,
                        },
                    },
                    Symbol,
                },
            )
            _record_early_prepare(Tuple{typeof(Base.getproperty), Pair{Symbol, String}, Symbol})
            _record_early_prepare(
                Tuple{
                    typeof(Base.getproperty),
                    WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                    Symbol,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.getproperty),
                    WannierNLQG.Wannierization.TBSymmetryQualification,
                    Symbol,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.getproperty),
                    WannierNLQG.Wannierization.WannierizationAccelerationConfig,
                    Symbol,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.getproperty),
                    WannierNLQG.Wannierization.WannierizationInputConfig,
                    Symbol,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.getproperty),
                    WannierNLQG.Wannierization.WannierizationOutputConfig,
                    Symbol,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.getproperty),
                    WannierNLQG.Wannierization.WannierizationRuntimeConfig,
                    Symbol,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.getproperty),
                    WannierNLQG.Wannierization.WannierizationSolverConfig,
                    Symbol,
                },
            )
            false
            _record_early_prepare(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, Array{Int64, 1}},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Int64},
                        Pair{String, Array{Float64, 2}},
                        Pair{String, Array{Float64, 2}},
                        Pair{String, Array{Float64, 2}},
                        Pair{String, Array{Float64, 2}},
                        Pair{String, Array{Int64, 2}},
                        Pair{String, String},
                    },
                    Int64,
                },
            )
            false
            _record_early_prepare(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Bool},
                        Vararg{Pair{String, Float64}, 7},
                    },
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Nothing},
                    Tuple{
                        Pair{String, Nothing},
                        Pair{String, Float64},
                        Vararg{Pair{String, String}, 4},
                    },
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Union{Nothing, Float64}},
                    Tuple{
                        Pair{String, Nothing},
                        Pair{String, Float64},
                        Vararg{Pair{String, String}, 4},
                    },
                    Int64,
                },
            )
            _record_early_prepare(Tuple{typeof(Base.haskey), Base.Dict{String, String}, String})
            _record_early_prepare(
                Tuple{
                    typeof(Base.haskey),
                    Base.Dict{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperator{N} where N,
                    },
                    WannierNLQG.Core.RealSpaceOperatorKind,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.hasproperty),
                    NamedTuple{
                        (
                            :mmn,
                            :amn,
                            :mmn_file,
                            :amn_file,
                            :raw_amn_file,
                            :source_kind,
                            :paw_result,
                            :gauge_sha256,
                            :gauge_provenance_file,
                        ),
                        Tuple{
                            WannierNLQG.IO.WannierMMN,
                            Nothing,
                            String,
                            Nothing,
                            Nothing,
                            String,
                            Nothing,
                            String,
                            Nothing,
                        },
                    },
                    Symbol,
                },
            )
            _record_early_prepare(Tuple{typeof(Base.imag), Base.Complex{Float64}})
            false
            _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{4, String}})
            _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{5, String}})
            _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{6, String}})
            _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{8, String}})
            _record_early_prepare(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
            _record_early_prepare(Tuple{typeof(Base.in), String, Tuple{String, String}})
            false
            _record_early_prepare(Tuple{typeof(Base.in), Symbol, Tuple{Symbol, Symbol, Symbol}})
            false
            _record_early_prepare(
                Tuple{
                    typeof(Base.in),
                    Tuple{
                        Symbol,
                        Symbol,
                        String,
                        Tuple{Pair{String, String}, Pair{String, String}, Pair{String, String}},
                    },
                    Base.Set{Tuple{Symbol, Symbol, String, Tuple}},
                },
            )
            false
            _record_early_prepare(
                Tuple{
                    typeof(Base.in),
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                },
            )
            _record_early_prepare(
                Tuple{typeof(Base.indexed_iterate), Pair{String, Any}, Int64, Int64},
            )
            _record_early_prepare(Tuple{typeof(Base.indexed_iterate), Pair{String, Any}, Int64})
            _record_early_prepare(
                Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64, Int64},
            )
            _record_early_prepare(Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64})
            _record_early_prepare(
                Tuple{
                    typeof(Base.indexed_iterate),
                    Tuple{Pair{String, String}, Int64},
                    Int64,
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, String}, Int64}, Int64},
            )
            _record_early_prepare(
                Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64, Int64},
            )
            _record_early_prepare(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64})
            _record_early_prepare(
                Tuple{typeof(Base.indexed_iterate), Tuple{String, String}, Int64, Int64},
            )
            _record_early_prepare(Tuple{typeof(Base.indexed_iterate), Tuple{String, String}, Int64})
            false
            _record_early_prepare(Tuple{typeof(Base.isempty), Base.Dict{String, Any}})
            _record_early_prepare(
                Tuple{
                    typeof(Base.issorted),
                    Array{String, 1},
                    Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
                },
            )
            _record_early_prepare(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
            false
            false
            _record_early_prepare(
                Tuple{
                    typeof(Base.iterate),
                    Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{typeof(Base.iterate), Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
            )
            _record_early_prepare(Tuple{typeof(Base.iterate), Base.Dict{String, Any}, Int64})
            _record_early_prepare(Tuple{typeof(Base.iterate), Base.Dict{String, String}, Int64})
            _record_early_prepare(Tuple{typeof(Base.iterate), Base.Dict{String, String}})
            _record_early_prepare(Tuple{typeof(Base.iterate), Pair{String, String}, Int64})
            _record_early_prepare(Tuple{typeof(Base.iterate), Pair{String, String}})
            _record_early_prepare(Tuple{typeof(Base.join), Array{String, 1}, String})
            _record_early_prepare(
                Tuple{
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Array{Base.SubString{String}, 1},
                    Char,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Array{Int64, 1},
                    Char,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Base.OneTo{Int64},
                    Char,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    NTuple{5, String},
                    Char,
                },
            )
            _record_early_prepare(Tuple{typeof(Base.keys), Base.Dict{String, Any}})
            _record_early_prepare(Tuple{typeof(Base.last), Array{Array{Float64, 1}, 1}})
            false
            _record_early_prepare(Tuple{typeof(Base.length), Array{Base.Complex{Float64}, 1}})
            _record_early_prepare(Tuple{typeof(Base.length), Array{Int64, 1}})
            _record_early_prepare(Tuple{typeof(Base.length), Array{Tuple{Int64, Int64, Int64}, 1}})
            _record_early_prepare(Tuple{typeof(Base.length), Array{UInt8, 1}})
            _record_early_prepare(
                Tuple{typeof(Base.length), Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
            )
            false
            false
            _record_early_prepare(
                Tuple{typeof(Base.maximum), Function, Array{Base.Complex{Float64}, 2}},
            )
            _record_early_prepare(
                Tuple{typeof(Base.merge), Base.Dict{String, Any}, Base.Dict{String, Any}},
            )
            _record_early_prepare(
                Tuple{typeof(Base.merge), Base.Dict{String, Any}, Base.Dict{String, String}},
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.merge),
                    NamedTuple{
                        (
                            :success,
                            :code,
                            :frames,
                            :centers,
                            :spreads,
                            :directional,
                            :u_residual,
                            :gradient_rms,
                            :projection_converged,
                            :projection_iterations,
                            :projection_residual,
                            :completed_sweeps,
                            :accepted_step_scale,
                            :backtracking_steps,
                            :trial_objective,
                            :accepted_objective,
                            :localization_spectra,
                            :localization_ranks,
                            :localization_conditions,
                            :raw_eigenphases,
                            :aligned_eigenphases,
                            :raw_geodesic_distances,
                            :aligned_geodesic_distances,
                            :block_permutations,
                            :block_phases,
                            :polar_fallback_triggered,
                            :active_localization_algorithm,
                            :base_objective,
                            :trial_zero_objective,
                            :trial_zero_frame_residual,
                            :attempted_step_scales,
                            :attempted_objectives,
                            :attempted_required_changes,
                            :attempted_actual_changes,
                            :attempted_directional_derivatives,
                            :attempted_sweeps,
                            :attempted_accepted,
                            :directional_derivative,
                            :fixed_projector_drift,
                            :accepted_required_change,
                            :accepted_actual_change,
                            :minimum_diagonal_phase_margin,
                            :minimum_phase_kpoint,
                            :minimum_phase_neighbor,
                            :minimum_phase_wannier,
                            :minimum_phase_value,
                            :branch_safe_backtracking_triggered,
                            :previous_u_gradient,
                            :previous_u_direction,
                            :u_cg_iteration,
                            :u_cg_restart_count,
                            :cg_beta,
                            :cg_restarted,
                            :cg_restart_reason,
                            :cg_descent_cosine,
                            :kstar_gradient_rms,
                            :maximum_kstar_gradient_rms,
                            :maximum_kstar_gradient_index,
                            :transport_minimum_singular_value,
                            :transport_maximum_condition,
                            :transported_omega_i,
                            :u_phase_contract,
                            :u_active_orbit_sha256,
                            :u_active_orbit_count,
                            :generalized_gradient_rms,
                            :u_lbfgs_s_history,
                            :u_lbfgs_y_history,
                            :u_lbfgs_rho_history,
                            :u_lbfgs_restart_count,
                            :u_optimizer_restart_reason,
                            :subspaces,
                            :raw_amn_alignment_applied,
                            :raw_amn_alignment_minimum_singular_value,
                            :raw_amn_alignment_maximum_condition,
                            :raw_amn_alignment_projector_drift,
                            :raw_amn_alignment_completion_count,
                            :localization_initial_frames,
                            :corepresentation_transport_applied,
                            :corepresentation_transport_minimum_singular_value,
                            :corepresentation_transport_maximum_condition,
                            :corepresentation_transport_projector_drift,
                            :corepresentation_transport_target_symmetry,
                        ),
                        Tuple{
                            Bool,
                            Symbol,
                            Array{Array{Base.Complex{Float64}, 2}, 1},
                            Array{Float64, 2},
                            Array{Float64, 1},
                            Nothing,
                            Float64,
                            Float64,
                            Bool,
                            Int64,
                            Float64,
                            Int64,
                            Float64,
                            Int64,
                            Float64,
                            Float64,
                            Array{Array{Float64, 1}, 1},
                            Array{Int64, 1},
                            Array{Float64, 1},
                            Array{Array{Float64, 1}, 1},
                            Array{Array{Float64, 1}, 1},
                            Array{Float64, 1},
                            Array{Float64, 1},
                            Array{Array{Int64, 1}, 1},
                            Array{Array{Float64, 1}, 1},
                            Bool,
                            Symbol,
                            Float64,
                            Float64,
                            Float64,
                            Array{Float64, 1},
                            Array{Float64, 1},
                            Array{Float64, 1},
                            Array{Float64, 1},
                            Array{Float64, 1},
                            Array{Int64, 1},
                            Array{Bool, 1},
                            Float64,
                            Float64,
                            Float64,
                            Float64,
                            Float64,
                            Int64,
                            Int64,
                            Int64,
                            Float64,
                            Bool,
                            Nothing,
                            Nothing,
                            Int64,
                            Int64,
                            Float64,
                            Bool,
                            Symbol,
                            Float64,
                            Array{Float64, 1},
                            Float64,
                            Int64,
                            Float64,
                            Float64,
                            Float64,
                            String,
                            String,
                            Int64,
                            Float64,
                            Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                            Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                            Array{Float64, 1},
                            Int64,
                            Symbol,
                            Array{Array{Base.Complex{Float64}, 2}, 1},
                            Bool,
                            Float64,
                            Float64,
                            Float64,
                            Int64,
                            Nothing,
                            Bool,
                            Vararg{Float64, 4},
                        },
                    },
                    NamedTuple{
                        (
                            :spread_total,
                            :spread_std,
                            :covariance_error,
                            :projector_residual,
                            :wcc_step,
                            :spread_step,
                            :z_boundary_gap,
                        ),
                        NTuple{7, Float64},
                    },
                },
            )
            false
            false
            false
            false
            false
            false
            _record_early_prepare(Tuple{typeof(Base.min), Float64, Float64})
            false
            _record_early_prepare(
                Tuple{
                    typeof(Base.ntuple),
                    Base.Broadcast.var"#17#18"{
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.Style{Tuple},
                            Nothing,
                            Type{String},
                            Tuple{Tuple{Symbol, Symbol}},
                        },
                    },
                    Base.Val{2},
                },
            )
            false
            false
            _record_early_prepare(Tuple{typeof(Base.occursin), Base.Regex, String})
            _record_early_prepare(
                Tuple{
                    typeof(Base.permutedims),
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Int64, Int64, Int64},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.print),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    UInt64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.print),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    WannierNLQG.Wannierization.WannierizationStatus,
                },
            )
            _record_early_prepare(Tuple{typeof(Base.print), Base.IOStream, String})
            _record_early_prepare(Tuple{typeof(Base.prod), Tuple{Int64}})
            false
            _record_early_prepare(
                Tuple{
                    typeof(Base.push!),
                    Array{Tuple{Int64, Int64, Int64}, 1},
                    Tuple{Int64, Int64, Int64},
                },
            )
            false
            _record_early_prepare(
                Tuple{
                    typeof(Base.push!),
                    Base.Set{Tuple{Symbol, Symbol, String, Tuple}},
                    Tuple{
                        Symbol,
                        Symbol,
                        String,
                        Tuple{Pair{String, String}, Pair{String, String}, Pair{String, String}},
                    },
                },
            )
            false
            _record_early_prepare(Tuple{typeof(Base.real), Base.Complex{Float64}})
            _record_early_prepare(Tuple{typeof(Base.repeat), Char, Int64})
            _record_early_prepare(
                Tuple{
                    typeof(Base.repr),
                    Tuple{
                        Symbol,
                        Symbol,
                        Symbol,
                        Bool,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Array{Tuple{Int64, Int64}, 1},
                        Int64,
                        Symbol,
                        Float64,
                        Float64,
                        WannierNLQG.Wannierization.WannierizationAccelerationConfig,
                        Float64,
                        Int64,
                        Float64,
                        Int64,
                        Float64,
                        Float64,
                        Nothing,
                        Float64,
                        Symbol,
                        Bool,
                        Bool,
                        Symbol,
                        UInt64,
                        String,
                        String,
                        Symbol,
                        Symbol,
                        Symbol,
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        WannierNLQG.Wannierization.WannierizationNumericalThresholds,
                        DataType,
                        Bool,
                        Int64,
                        Int64,
                        String,
                        String,
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.setindex!),
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    Array{Base.Complex{Float64}, 2},
                    Int64,
                },
            )
            _record_early_prepare(Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64})
            _record_early_prepare(Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64})
            false
            _record_early_prepare(Tuple{typeof(Base.setindex!), Base.EnvDict, String, String})
            _record_early_prepare(
                Tuple{
                    typeof(Base.setindex_widen_up_to),
                    Array{Nothing, 1},
                    Tuple{Symbol, Symbol},
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Tuple{Float64, Float64, Int64, Int64, Float64, Float64, Symbol},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Tuple{Int64, Int64, Float64, Symbol, Symbol},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Tuple{String, String, Int64, Float64, Array{Float64, 1}, Int64, Symbol},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Tuple{String, String},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Tuple{Symbol, Float64, Float64, Int64, Int64, NTuple{4, Float64}, Float64},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Tuple{
                        Symbol,
                        Float64,
                        Int64,
                        Int64,
                        Int64,
                        Float64,
                        Bool,
                        Symbol,
                        Float64,
                        Float64,
                        Int64,
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Tuple{Symbol, Int64, Int64, Int64, Int64, Int64, Float64, Bool, Int64, Float64},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Tuple{Symbol, Symbol, String},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Tuple{
                        Symbol,
                        Symbol,
                        Symbol,
                        Bool,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Array{Tuple{Int64, Int64}, 1},
                        Int64,
                        Symbol,
                        Float64,
                        Float64,
                        WannierNLQG.Wannierization.WannierizationAccelerationConfig,
                        Float64,
                        Int64,
                        Float64,
                        Int64,
                        Float64,
                        Float64,
                        Nothing,
                        Float64,
                        Symbol,
                        Bool,
                        Bool,
                        Symbol,
                        UInt64,
                        String,
                        String,
                        Symbol,
                        Symbol,
                        Symbol,
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        WannierNLQG.Wannierization.WannierizationNumericalThresholds,
                        DataType,
                        Bool,
                        Int64,
                        Int64,
                        String,
                        String,
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.IOContext{
                        Base.GenericIOBuffer{
                            GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                        },
                    },
                    Any,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.IOContext{
                        Base.GenericIOBuffer{
                            GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                        },
                    },
                    Array{Float64, 1},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.IOContext{
                        Base.GenericIOBuffer{
                            GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                        },
                    },
                    Array{Tuple{Int64, Int64}, 1},
                },
            )
            _record_early_prepare(
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
            _record_early_prepare(
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
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.IOContext{
                        Base.GenericIOBuffer{
                            GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                        },
                    },
                    NTuple{4, Float64},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.IOContext{
                        Base.GenericIOBuffer{
                            GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                        },
                    },
                    NamedTuple{
                        (:disentanglement, :localization, :profile, :default_selection_reason),
                        Tuple{Symbol, Symbol, Symbol, String},
                    },
                },
            )
            _record_early_prepare(
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
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.IOContext{
                        Base.GenericIOBuffer{
                            GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                        },
                    },
                    Tuple{Float64, Float64},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.show),
                    Base.IOContext{
                        Base.GenericIOBuffer{
                            GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                        },
                    },
                    UInt64,
                },
            )
            false
            _record_early_prepare(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 2}})
            _record_early_prepare(Tuple{typeof(Base.size), Array{Float64, 2}})
            _record_early_prepare(Tuple{typeof(Base.size), Array{Int64, 2}, Int64})
            _record_early_prepare(Tuple{typeof(Base.size), Array{Int64, 2}})
            _record_early_prepare(Tuple{typeof(Base.something), String})
            _record_early_prepare(Tuple{typeof(Base.string), Int64})
            _record_early_prepare(Tuple{typeof(Base.sum), Array{Int64, 1}})
            _record_early_prepare(Tuple{typeof(Base.sym_in), Symbol, NTuple{111, Symbol}})
            _record_early_prepare(Tuple{typeof(Base.sym_in), Symbol, NTuple{12, Symbol}})
            _record_early_prepare(Tuple{typeof(Base.sym_in), Symbol, NTuple{70, Symbol}})
            false
            false
            _record_early_prepare(Tuple{typeof(Base.sym_in), Symbol, NTuple{82, Symbol}})
            false
            _record_early_prepare(Tuple{typeof(Base.unique), Array{String, 1}})
            _record_early_prepare(Tuple{typeof(Base.unique), Tuple{Symbol, Symbol}})
            _record_early_prepare(
                Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}},
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.view),
                    Array{Base.Complex{Float64}, 4},
                    Function,
                    Function,
                    Function,
                    Int64,
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Base.write),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Array{Int64, 1},
                },
            )
            _record_early_prepare(Tuple{typeof(Base.write), Base.IOStream, Array{UInt8, 1}})
            false
            _record_early_prepare(
                Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}},
            )
            _record_early_prepare(
                Tuple{typeof(Core._checked_mul_dims), Int64, Int64, Int64, Vararg{Int64}},
            )
            _record_early_prepare(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{
                        (
                            :algorithm_profile,
                            :smv_fletcher_reeves_two_stage_audit_thresholds,
                            :smv_fletcher_reeves_two_stage_audit_manifest,
                            :initialization,
                            :z_mix_ratio,
                            :u_mix_ratio,
                            :acceleration,
                            :numerical_thresholds,
                            :initialization_backend,
                            :paw_scdm_input_hdf5,
                            :multi_start,
                            :max_iterations,
                            :convergence_tolerance,
                            :convergence_window,
                            :little_group_tolerance,
                            :little_group_max_iterations,
                            :localize,
                            :symmetrize_z,
                            :parallel,
                            :random_seed,
                        ),
                        Tuple{
                            Symbol,
                            WannierNLQG.Wannierization.SMVFletcherReevesTwoStageAuditThresholds,
                            Nothing,
                            Symbol,
                            Float64,
                            Float64,
                            WannierNLQG.Wannierization.WannierizationAccelerationConfig,
                            WannierNLQG.Wannierization.WannierizationNumericalThresholds,
                            WannierNLQG.Wannierization.AMNExactFrozenInitialization,
                            Nothing,
                            WannierNLQG.Wannierization.WannierizationMultiStartConfig,
                            Int64,
                            Float64,
                            Int64,
                            Float64,
                            Int64,
                            Bool,
                            Bool,
                            Symbol,
                            UInt64,
                        },
                    },
                    Type{WannierNLQG.Wannierization.WannierizationSolverConfig},
                },
            )
            false
            false
            _record_early_prepare(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{
                        (
                            :band_representation_output_hdf5,
                            :tb_output_formats,
                            :write_wannier90_tb,
                            :profile,
                            :operator_tasks,
                            :spn_file,
                            :spn_provenance_file,
                            :uiu_file,
                            :uhu_file,
                            :siu_file,
                            :shu_file,
                            :uiu_provenance_json,
                            :uhu_provenance_json,
                            :siu_provenance_json,
                            :shu_provenance_json,
                            :spn_formatted,
                            :operator_files_formatted,
                            :operator_closure_tolerance,
                            :spin_family_covariance_tolerance,
                            :spin_family_idempotence_tolerance,
                            :final_tb_symmetry_report_enabled,
                        ),
                        Tuple{
                            Nothing,
                            Tuple{Symbol, Symbol},
                            Bool,
                            Symbol,
                            Tuple{},
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Bool,
                            Bool,
                            Float64,
                            Float64,
                            Float64,
                            Nothing,
                        },
                    },
                    Type{WannierNLQG.Wannierization.WannierizationOutputConfig},
                },
            )
            false
            false
            false
            false
            false
            false
            _record_early_prepare(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{(:init,), Tuple{Float64}},
                    typeof(Base.maximum),
                    Function,
                    Array{Base.Complex{Float64}, 2},
                },
            )
            false
            _record_early_prepare(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{
                        (
                            :profile,
                            :operator_tasks,
                            :overwrite,
                            :paired_tb_sha256,
                            :provenance,
                            :geometry,
                            :diagnostics,
                            :eligibility,
                        ),
                        Tuple{Symbol, Tuple{}, Bool, String, Vararg{Base.Dict{String, Any}, 4}},
                    },
                    typeof(WannierNLQG.IO.write_real_space_operator_bundle),
                    String,
                    Array{Float64, 2},
                    Array{Int64, 1},
                    Base.Dict{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperator{N} where N,
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{(:progress_interval, :iteration_observer), Tuple{Int64, Nothing}},
                    Type{WannierNLQG.Wannierization.WannierizationRuntimeConfig},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{
                        (
                            :restart_hdf5,
                            :fixed_subspace_hdf5,
                            :checkpoint_hdf5,
                            :checkpoint_interval,
                        ),
                        Tuple{Nothing, Nothing, String, Int64},
                    },
                    Type{WannierNLQG.Wannierization.WannierizationCheckpointConfig},
                },
            )
            false
            false
            false
            _record_early_prepare(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Core.AddrSpace{Core}(0x00),
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{:not_atomic, Array{Float64, 1}, Core.AddrSpace{Core}(0x00)},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        Array{WannierNLQGWannierizationExt.SolverCheckpoint.MVPhaseBranchLink, 1},
                        Core.AddrSpace{Core}(0x00),
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{:not_atomic, Base.Complex{Float64}, Core.AddrSpace{Core}(0x00)},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        Tuple{Int64, Int64, Float64},
                        Core.AddrSpace{Core}(0x00),
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        WannierNLQG.Wannierization.TBSymmetryMetric,
                        Core.AddrSpace{Core}(0x00),
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        WannierNLQG.Wannierization.WannierizationIteration,
                        Core.AddrSpace{Core}(0x00),
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        WannierNLQGWannierizationExt.SolverCheckpoint.MVPhaseBranchLink,
                        Core.AddrSpace{Core}(0x00),
                    },
                },
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties},
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties},
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties},
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties},
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties},
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties},
            )
            _record_early_prepare(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties},
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties},
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties},
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties},
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties},
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties},
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties},
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties},
            )
            _record_early_prepare(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties},
            )
            false
            false
            false
            _record_early_prepare(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{33, 0}},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{35, 0}},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{54, 0}},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{56, 0}},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{63, 0}},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{66, 0}},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{74, 0}},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{75, 0}},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{89, 0}},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{92, 0}},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(PAWMatrixElements.JSON3.defaultminimum),
                    PAWMatrixElements.JSON3.Array{
                        PAWMatrixElements.JSON3.Object{
                            S,
                            TT,
                        } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Array{UInt64, 1},
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(PAWMatrixElements.JSON3.defaultminimum),
                    NamedTuple{
                        (:record, :severity, :code, :message, :context),
                        Tuple{Int64, String, String, String, Base.Dict{String, String}},
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(PAWMatrixElements.JSON3.read),
                    String,
                    Type{Array{Base.Dict{String, Any}, 1}},
                },
            )
            _record_early_prepare(Tuple{typeof(PAWMatrixElements.JSON3.read), String})
            _record_early_prepare(
                Tuple{typeof(PAWMatrixElements.JSON3.write), Base.IOStream, Base.Dict{String, Any}},
            )
            _record_early_prepare(
                Tuple{
                    typeof(PAWMatrixElements.JSON3.write),
                    PAWMatrixElements.JSON3.StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    PAWMatrixElements.JSON3.Array{
                        PAWMatrixElements.JSON3.Object{
                            S,
                            TT,
                        } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Array{UInt64, 1},
                    },
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(PAWMatrixElements.JSON3.write),
                    PAWMatrixElements.JSON3.StructTypes.DictType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Base.Dict{String, Any},
                },
            )
            _record_early_prepare(
                Tuple{
                    typeof(LinearAlgebra.generic_trimatdiv!),
                    Base.SubArray{
                        Float64,
                        2,
                        Array{Float64, 2},
                        Tuple{Base.UnitRange{Int64}, Base.Slice{Base.OneTo{Int64}}},
                        false,
                    },
                    Char,
                    Char,
                    Function,
                    Base.SubArray{
                        Float64,
                        2,
                        Array{Float64, 2},
                        Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}},
                        false,
                    },
                    Base.SubArray{
                        Float64,
                        2,
                        Array{Float64, 2},
                        Tuple{Base.UnitRange{Int64}, Base.Slice{Base.OneTo{Int64}}},
                        false,
                    },
                },
            )
            _record_early_prepare(
                Tuple{typeof(LinearAlgebra.opnorm), Array{Base.Complex{Float64}, 2}},
            )
            _record_early_prepare(
                Tuple{
                    typeof(WannierNLQG.IO.operator_inventory_source_closure),
                    Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                },
            )
            _record_early_prepare(
                Tuple{typeof(WannierNLQG.IO.resolve_operator_selection), Symbol, Tuple{}},
            )
            _record_early_prepare(
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
        @assert !WannierNLQG.MPI.Initialized()
    end
end
