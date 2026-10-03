# Generated from exact Type-proved inference within real cold public calls, Julia 1.11.2.
# No target execution, writes, MPI initialization or saved handles. Provenance is external.
@compile_workload begin
    if workload_enabled(parentmodule(SymmetrizationConfig))
        let WannierNLQGSymmetrizationExt=@__MODULE__
            _record_symmetrization(
                Tuple{
                    typeof(Symmetrization.symmetrize_existing_wannier_model),
                    Symmetrization.GaugeAwareSymmetrizationConfig,
                },
            )

            _record_symmetrization(
                Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}},
            )
            _record_symmetrization(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
            _record_symmetrization(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGSymmetrizationExt.var"#190#197",
                    Tuple{Symbol, Symbol},
                },
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.collect),
                    Base.Generator{
                        Tuple{Symbol, Symbol},
                        WannierNLQGSymmetrizationExt.var"#190#197",
                    },
                },
            )
            _record_symmetrization(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
            _record_symmetrization(
                Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64, Int64},
            )
            _record_symmetrization(
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64, Int64},
            )
            _record_symmetrization(
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64},
            )
            _record_symmetrization(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
            _record_symmetrization(
                Tuple{
                    Type{Array{T, 2} where T},
                    LinearAlgebra.Transpose{Float64, Array{Float64, 2}},
                },
            )
            _record_symmetrization(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
            _record_symmetrization(
                Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64},
            )
            _record_symmetrization(
                Tuple{
                    Type{Array{Base.Complex{Float64}, N} where N},
                    UndefInitializer,
                    NTuple{4, Int64},
                },
            )
            _record_symmetrization(
                Tuple{
                    Type{Array{Base.Complex{Float64}, N} where N},
                    UndefInitializer,
                    Int64,
                    Int64,
                    Int64,
                },
            )
            _record_symmetrization(
                Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64},
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        Tuple{Int64, Int64, Float64},
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
            )
            _record_symmetrization(
                Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}},
            )
            _record_symmetrization(Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}})
            _record_symmetrization(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (
                            :absolute_tolerance,
                            :oracle_excess_tolerance,
                            :oracle_hdf5_file,
                            :require_oracle,
                        ),
                        Tuple{Float64, Float64, Nothing, Bool},
                    },
                    typeof(SymmetryFoundation.validate_band_representation),
                    SymmetryFoundation.BandRepresentation,
                },
            )
            _record_symmetrization(
                Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}},
            )
            _record_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{String, Nothing}, Int64},
            )
            _record_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{String, Nothing}, Int64, Int64},
            )
            _record_symmetrization(Tuple{typeof(Base.indexed_iterate), Tuple{Int64, String}, Int64})
            _record_symmetrization(
                Tuple{typeof(Base.indexed_iterate), Tuple{Int64, String}, Int64, Int64},
            )
            _record_symmetrization(Tuple{typeof(Base.tail), Tuple{Int64, Int64}})
            _record_symmetrization(Tuple{Type{Pair{A, B} where {B} where A}, Symbol, UInt8})
            _record_symmetrization(Tuple{typeof(Base.repeat), Char, Int64})
            _record_symmetrization(Tuple{typeof(Base.view), Array{Float64, 2}, Int64, Function})
            _record_symmetrization(
                Tuple{typeof(Base.view), Array{Int64, 3}, Function, Int64, Int64},
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.Broadcast.broadcasted),
                    typeof(Base.:(*)),
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
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.Broadcast.materialize),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{2},
                        Nothing,
                        typeof(Base.:(*)),
                        Tuple{
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
                },
            )
            _record_symmetrization(
                Tuple{
                    Base.var"##open#463",
                    Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                    typeof(Base.open),
                    WannierNLQGSymmetrizationExt.var"#168#169"{
                        NamedTuple{
                            (
                                :sewing,
                                :operation_map,
                                :maximum_semiunitarity,
                                :maximum_closure,
                                :closure_rms,
                                :maximum_unitarity,
                                :maximum_group_law_residuals,
                                :semiunitarity_residuals,
                                :closure_residuals,
                                :unitarity_residuals,
                                :block_residuals,
                                :worst_closure,
                                :worst_unitarity,
                                :worst_group,
                            ),
                            Tuple{
                                Array{Base.Complex{Float64}, 4},
                                Array{Int64, 2},
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                NTuple{4, Float64},
                                Array{Float64, 1},
                                Array{Float64, 2},
                                Array{Float64, 2},
                                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                                NamedTuple{
                                    (:operation, :source, :target),
                                    Tuple{Int64, Int64, Int64},
                                },
                                NamedTuple{
                                    (:operation, :source, :target),
                                    Tuple{Int64, Int64, Int64},
                                },
                                Array{
                                    NamedTuple{
                                        (:left, :right, :source),
                                        Tuple{Int64, Int64, Int64},
                                    },
                                    1,
                                },
                            },
                        },
                    },
                    String,
                    Vararg{String},
                },
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.join),
                    Tuple{Int64, Bool, Int64, Int64, Int64, Int64, Int64, Vararg{Float64, 4}},
                    Char,
                },
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.similar),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        typeof(Base.getproperty),
                        Tuple{
                            Base.Broadcast.Extruded{
                                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                                Tuple{Bool},
                                Tuple{Int64},
                            },
                            Base.RefValue{Symbol},
                        },
                    },
                    Type{Float64},
                },
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.Broadcast.copyto_nonleaf!),
                    Array{Float64, 1},
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        typeof(Base.getproperty),
                        Tuple{
                            Base.Broadcast.Extruded{
                                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                                Tuple{Bool},
                                Tuple{Int64},
                            },
                            Base.RefValue{Symbol},
                        },
                    },
                    Base.OneTo{Int64},
                    Int64,
                    Int64,
                },
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (:operation, :kpoint, :band_block, :context),
                        Tuple{Int64, Int64, Int64, String},
                    },
                    typeof(WannierNLQGSymmetrizationExt._record_gauge_aware_threshold!),
                    Array{Symmetrization.GaugeAwareThresholdEvent, 1},
                    Array{String, 1},
                    Symbol,
                    String,
                    Float64,
                    Float64,
                },
            )
            _record_symmetrization(
                Tuple{
                    typeof(Printf.computelen),
                    Array{Base.UnitRange{Int64}, 1},
                    Tuple{
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                    },
                    Tuple{Int64, Int64, Int64, Int64, Int64, Float64, Float64},
                },
            )
            _record_symmetrization(
                Tuple{
                    typeof(Printf.fmt),
                    Array{UInt8, 1},
                    Int64,
                    Tuple{Int64, Int64, Int64, Int64, Int64, Float64, Float64},
                    Int64,
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                },
            )
            _record_symmetrization(
                Tuple{
                    Type{
                        Base.Broadcast.Broadcasted{
                            Style,
                            Axes,
                            F,
                            Args,
                        } where {
                            Args <: Tuple,
                        } where {
                            F,
                        } where {Axes} where Style <: Union{Nothing, Base.Broadcast.BroadcastStyle},
                    },
                    Base.Broadcast.Style{Tuple},
                    typeof(Base.string),
                    Tuple{Tuple{Symbol, Symbol}},
                },
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.ntuple),
                    Base.Broadcast.var"#17#18"{
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.Style{Tuple},
                            Nothing,
                            typeof(Base.string),
                            Tuple{Tuple{Symbol, Symbol}},
                        },
                    },
                    Base.Val{2},
                },
            )
            _record_symmetrization(
                Tuple{Type{Pair{A, B} where {B} where A}, String, Tuple{String, String}},
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, String},
                    },
                    Int64,
                },
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.similar),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        typeof(WannierNLQGSymmetrizationExt._gauge_aware_threshold_payload),
                        Tuple{
                            Base.Broadcast.Extruded{
                                Array{Symmetrization.GaugeAwareThresholdEvent, 1},
                                Tuple{Bool},
                                Tuple{Int64},
                            },
                        },
                    },
                    Type{Base.Dict{String, Any}},
                },
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.Broadcast.copyto_nonleaf!),
                    Array{Base.Dict{String, Any}, 1},
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        typeof(WannierNLQGSymmetrizationExt._gauge_aware_threshold_payload),
                        Tuple{
                            Base.Broadcast.Extruded{
                                Array{Symmetrization.GaugeAwareThresholdEvent, 1},
                                Tuple{Bool},
                                Tuple{Int64},
                            },
                        },
                    },
                    Base.OneTo{Int64},
                    Int64,
                    Int64,
                },
            )
            _record_symmetrization(
                Tuple{Type{Pair{A, B} where {B} where A}, String, Array{Base.Dict{String, Any}, 1}},
            )
            _record_symmetrization(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Tuple{String, String}},
                        Pair{String, Bool},
                        Pair{String, Int64},
                        Pair{String, Array{Base.Dict{String, Any}, 1}},
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Base.Dict{String, Any}},
                        Pair{String, Array{String, 1}},
                    },
                },
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Tuple{String, String}},
                        Pair{String, Bool},
                        Pair{String, Int64},
                        Pair{String, Array{Base.Dict{String, Any}, 1}},
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Base.Dict{String, Any}},
                        Pair{String, Array{String, 1}},
                    },
                    Int64,
                },
            )
            _record_symmetrization(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:overwrite,), Tuple{Bool}},
                    typeof(WannierNLQGSymmetrizationExt._write_gauge_aware_json),
                    String,
                    Base.Dict{String, Any},
                },
            )
            _record_symmetrization(Tuple{typeof(JSON3.defaultminimum), Tuple{String, String}})
        end
        # MPI state is checked by the independent lifecycle gate after activation.
    end
end
