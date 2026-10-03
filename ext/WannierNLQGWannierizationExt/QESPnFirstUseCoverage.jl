# Native QE SPN generation and its observed second-call publication branch.
# Signatures only: no wavefunction loading, SPN writing, or MPI initialization here.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_early_prepare(Tuple{typeof(Base.:(>)), Float64})
        false
        false
        _record_early_prepare(
            Tuple{
                WannierNLQG.Wannierization.var"##VASPPAWSPNThresholds#78",
                Float64,
                Float64,
                Float64,
                Float64,
                Float64,
                Float64,
                Float64,
                Type{WannierNLQG.Wannierization.VASPPAWSPNThresholds},
            },
        )
        _record_early_prepare(
            Tuple{Type{WannierNLQG.Wannierization.VASPPAWSPNThresholds}, Vararg{Float64, 7}},
        )
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
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                Base.BottomRF{Base.var"#70#71"{typeof(WannierNLQG.SymmetryFoundation.sha256_file)}},
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    NamedTuple{names, T} where {T <: Tuple} where names,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.tail), NTuple{16, Symbol}})
        _record_early_prepare(Tuple{typeof(Base.tail), NTuple{15, Symbol}})
        _record_early_prepare(Tuple{typeof(Base.tail), NTuple{14, Symbol}})
        _record_early_prepare(Tuple{typeof(Base.tail), NTuple{13, Symbol}})
        _record_early_prepare(Tuple{typeof(Base.tail), NTuple{12, Symbol}})
        _record_early_prepare(Tuple{typeof(Base.tail), NTuple{11, Symbol}})
        _record_early_prepare(Tuple{typeof(Base.tail), NTuple{10, Symbol}})
        _record_early_prepare(Tuple{typeof(Base.tail), NTuple{9, Symbol}})
        _record_early_prepare(Tuple{typeof(Base.tail), NTuple{8, Symbol}})
        _record_early_prepare(Tuple{typeof(Base.tail), NTuple{7, Symbol}})
        _record_early_prepare(Tuple{typeof(Base.tail), NTuple{6, Symbol}})
        _record_early_prepare(Tuple{typeof(Base.tail), NTuple{5, Symbol}})
        _record_early_prepare(Tuple{typeof(Base.tail), NTuple{4, Symbol}})
        _record_early_prepare(Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64})
        _record_early_prepare(
            Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64, Int64},
        )
        _record_early_prepare(
            Tuple{Type{NamedTuple{(:atol, :rtol), T} where T <: Tuple}, Tuple{Float64, Float64}},
        )
        _record_early_prepare(Tuple{typeof(Base.:(>)), UInt32, Int64})
        _record_early_prepare(Tuple{Type{UInt8}, Int32})
        _record_early_prepare(
            Tuple{typeof(Base.literal_pow), typeof(Base.:(^)), Int64, Base.Val{2}},
        )
        _record_early_prepare(
            Tuple{Type{NamedTuple{(:build_missing,), T} where T <: Tuple}, Tuple{Bool}},
        )
        _record_early_prepare(Tuple{typeof(Base.Core.checked_dims), Int64, Int64, Vararg{Int64}})
        _record_early_prepare(Tuple{typeof(Base.Core._checked_mul_dims), Int64, Int64})
        _record_early_prepare(Tuple{Type{UndefKeywordError}, Symbol})
        _record_early_prepare(Tuple{Type{NamedTuple{(:init,), T} where T <: Tuple}, Tuple{Float64}})
        _record_early_prepare(Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}})
        _record_early_prepare(
            Tuple{typeof(Base.Core.Compiler.instanceof_tfunc), Any, Bool, Base.Core.PartialStruct},
        )
        _record_early_prepare(
            Tuple{Type{NamedTuple{(:construction_policy,), T} where T <: Tuple}, Tuple{Symbol}},
        )
        _record_early_prepare(Tuple{Type{Pair{A, B} where {B} where A}, String, Nothing})
        _record_early_prepare(
            Tuple{Type{NamedTuple{(:change_error,), T} where T <: Tuple}, Tuple{String}},
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#200#206",
                NTuple{8, Symbol},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Tuple{Symbol, Any},
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.in), Int64, Base.UnitRange{Int64}})
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (
                        :output_spn_file,
                        :provenance_json,
                        :oracle_spn_file,
                        :thresholds,
                        :require_oracle,
                        :formatted,
                        :overwrite,
                        :max_cached_wavefunction_kpoints,
                        :execution,
                    ),
                    Tuple{
                        String,
                        String,
                        Nothing,
                        WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                    },
                },
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements.generate_qe_paw_spn),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:execution, :native_execution, :published, :pack_result, :restore_result),
                    Tuple{
                        NamedTuple{
                            (
                                :mode,
                                :max_workers,
                                :memory_budget_bytes,
                                :checkpoint_directory,
                                :resume,
                            ),
                            Tuple{Symbol, Int64, Int64, String, Bool},
                        },
                        WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#212#216",
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#213#217"{
                            NamedTuple{(:owner, :slot), Tuple{Task, Base.RefValue{Any}}},
                        },
                        typeof(
                            WannierNLQGWannierizationExt.PAWMatrixElements._restore_spn_publication_result,
                        ),
                    },
                },
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._with_operator_publication_receipt,
                ),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#210#214"{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#358#359"{
                        String,
                        String,
                        Nothing,
                        WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Nothing,
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        String,
                    },
                    NamedTuple{(:owner, :slot), Tuple{Task, Base.RefValue{Any}}},
                    NamedTuple{
                        (:mode, :max_workers, :memory_budget_bytes, :checkpoint_directory, :resume),
                        Tuple{Symbol, Int64, Int64, String, Bool},
                    },
                },
                NamedTuple{
                    (
                        :source,
                        :topology_file,
                        :oracle_spn_file,
                        :thresholds,
                        :require_oracle,
                        :formatted,
                        :max_cached_wavefunction_kpoints,
                        :target_contract,
                    ),
                    Tuple{
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        String,
                        Nothing,
                        WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                        Bool,
                        Bool,
                        Int64,
                        Nothing,
                    },
                },
                Symbol,
                NamedTuple{(:output, :provenance), Tuple{String, String}},
                Array{String, 1},
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.haskey), Base.Dict{String, Tuple{Tuple, String}}, String},
        )
        _record_early_prepare(Tuple{typeof(Base.length), Base.UnitRange{Int64}})
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:change_error,), Tuple{String}},
                typeof(WannierNLQG.SymmetryFoundation.verified_file_digest_identity),
                String,
                Tuple{UInt64, UInt64, Int64, Float64, Float64},
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.setindex!),
                Base.Dict{String, Tuple{Tuple, String}},
                Tuple{Tuple{UInt64, UInt64, Int64, Float64, Float64}, String},
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#195#201"{
                    NamedTuple{
                        (:mode, :max_workers, :memory_budget_bytes, :checkpoint_directory, :resume),
                        Tuple{Symbol, Int64, Int64, String, Bool},
                    },
                    WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#212#216",
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#213#217"{
                        NamedTuple{(:owner, :slot), Tuple{Task, Base.RefValue{Any}}},
                    },
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._restore_spn_publication_result,
                    ),
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#210#214"{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#358#359"{
                            String,
                            String,
                            Nothing,
                            WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                            Bool,
                            Bool,
                            Bool,
                            Int64,
                            Nothing,
                            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                            String,
                        },
                        NamedTuple{(:owner, :slot), Tuple{Task, Base.RefValue{Any}}},
                        NamedTuple{
                            (
                                :mode,
                                :max_workers,
                                :memory_budget_bytes,
                                :checkpoint_directory,
                                :resume,
                            ),
                            Tuple{Symbol, Int64, Int64, String, Bool},
                        },
                    },
                    NamedTuple{
                        (
                            :source,
                            :topology_file,
                            :oracle_spn_file,
                            :thresholds,
                            :require_oracle,
                            :formatted,
                            :max_cached_wavefunction_kpoints,
                            :target_contract,
                        ),
                        Tuple{
                            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                            String,
                            Nothing,
                            WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                            Bool,
                            Bool,
                            Int64,
                            Nothing,
                        },
                    },
                    Symbol,
                    NamedTuple{(:output, :provenance), Tuple{String, String}},
                    Array{String, 1},
                    Array{String, 1},
                    Array{String, 1},
                    String,
                    Array{String, 1},
                },
                Symbol,
                Base.Dict{String, Tuple{Tuple, String}},
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.getindex), Base.Dict{String, Tuple{Tuple, String}}, String},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{Tuple{UInt64, UInt64, Int64, Float64, Float64}, String},
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{Tuple{UInt64, UInt64, Int64, Float64, Float64}, String},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.SymmetryFoundation.verified_file_digest_identity),
                String,
                Tuple{UInt64, UInt64, Int64, Float64, Float64},
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.:(!=)),
                Tuple{UInt64, UInt64, Int64, Float64, Float64},
                Tuple{UInt64, UInt64, Int64, Float64, Float64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base._array_for),
                Type{Tuple{String, String}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Tuple{String, String}, 1},
                Tuple{String, String},
                Base.Generator{
                    Array{String, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#196#202",
                },
                Int64,
            },
        )
        _record_early_prepare(Tuple{Base.var"##s128#278", Vararg{Any, 5}})
        _record_early_prepare(Tuple{typeof(Base.sort!), Array{Tuple{String, String}, 1}})
        _record_early_prepare(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Tuple{String, String}, 1},
                Tuple{String, String},
                Base.Generator{
                    Array{String, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#197#203"{String},
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Tuple{String, String}, 1},
                Tuple{String, String},
                Base.Generator{
                    Array{String, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#198#204",
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                Type{
                    Array{
                        Tuple{
                            Symbol,
                            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        },
                        1,
                    },
                },
                UndefInitializer,
                Tuple{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.push!),
                Array{
                    Tuple{Symbol, WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource},
                    1,
                },
                Tuple{Symbol, WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.isbitstype), Any})
        _record_early_prepare(
            Tuple{
                typeof(Base.grow_to!),
                Array{
                    Tuple{Symbol, WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource},
                    1,
                },
                Base.Generator{
                    Base.Iterators.Filter{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#200#206",
                        NTuple{8, Symbol},
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#199#205"{
                        NamedTuple{
                            (
                                :source,
                                :topology_file,
                                :oracle_spn_file,
                                :thresholds,
                                :require_oracle,
                                :formatted,
                                :max_cached_wavefunction_kpoints,
                                :target_contract,
                            ),
                            Tuple{
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                String,
                                Nothing,
                                WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                                Bool,
                                Bool,
                                Int64,
                                Nothing,
                            },
                        },
                    },
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.repr),
                Tuple{
                    String,
                    Base.VersionNumber,
                    String,
                    Array{Tuple{String, String}, 1},
                    Symbol,
                    Tuple{String, String},
                    Array{Tuple{Symbol, Any}, 1},
                    Array{Tuple{String, String}, 1},
                    Array{Tuple{String, String}, 1},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Tuple{
                    String,
                    Base.VersionNumber,
                    String,
                    Array{Tuple{String, String}, 1},
                    Symbol,
                    Tuple{String, String},
                    Array{Tuple{Symbol, Any}, 1},
                    Array{Tuple{String, String}, 1},
                    Array{Tuple{String, String}, 1},
                },
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
                Base.VersionNumber,
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
                Array{Tuple{String, String}, 1},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.all), Function, Tuple{DataType, DataType}})
        _record_early_prepare(
            Tuple{
                typeof(Base._all),
                typeof(Base._typeinfo_implicit),
                Tuple{DataType, DataType},
                Base.Colon,
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
                Tuple{String, String},
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
                Array{Tuple{Symbol, Any}, 1},
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
                Tuple{Symbol, WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource},
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
                Nothing,
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
                Bool,
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
                Tuple{Symbol, String},
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
                Tuple{Symbol, Nothing},
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
                Tuple{Symbol, WannierNLQG.Wannierization.VASPPAWSPNThresholds},
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
                Tuple{Symbol, Bool},
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
                Tuple{Symbol, Int64},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.copy), Base.Dict{String, Tuple{Tuple, String}}})
        _record_early_prepare(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#259#263"{
                    Array{String, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#210#214"{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#358#359"{
                            String,
                            String,
                            Nothing,
                            WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                            Bool,
                            Bool,
                            Bool,
                            Int64,
                            Nothing,
                            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                            String,
                        },
                        NamedTuple{(:owner, :slot), Tuple{Task, Base.RefValue{Any}}},
                        NamedTuple{
                            (
                                :mode,
                                :max_workers,
                                :memory_budget_bytes,
                                :checkpoint_directory,
                                :resume,
                            ),
                            Tuple{Symbol, Int64, Int64, String, Bool},
                        },
                    },
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    String,
                    String,
                    Int64,
                    Array{String, 1},
                    String,
                    WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                },
                Symbol,
                Base.Dict{String, Tuple{Tuple, String}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Tuple{String, String}, 1},
                Tuple{String, String},
                Base.Generator{
                    Array{String, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#260#264"{String},
                },
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.repr), Array{Tuple{String, String}, 1}})
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{Tuple{String, String}, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#247#253"{
                    String,
                    String,
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#210#214"{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#358#359"{
                            String,
                            String,
                            Nothing,
                            WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                            Bool,
                            Bool,
                            Bool,
                            Int64,
                            Nothing,
                            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                            String,
                        },
                        NamedTuple{(:owner, :slot), Tuple{Task, Base.RefValue{Any}}},
                        NamedTuple{
                            (
                                :mode,
                                :max_workers,
                                :memory_budget_bytes,
                                :checkpoint_directory,
                                :resume,
                            ),
                            Tuple{Symbol, Int64, Int64, String, Bool},
                        },
                    },
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    String,
                    Int64,
                    Array{String, 1},
                    Array{String, 1},
                },
                Symbol,
                Base.Dict{String, Tuple{Tuple, String}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Tuple{String, String}, 1},
                Tuple{String, String},
                Base.Generator{
                    Array{String, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#250#256",
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.repr),
                Tuple{
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    Array{Tuple{String, String}, 1},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Tuple{
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    Array{Tuple{String, String}, 1},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Any,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (:key, :state, :owner, :paths),
                    Tuple{Tuple{String, String, Int64}, Base.RefValue{Any}, Task, Array{String, 1}},
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.:(==)), Tuple{String, String, Int64}, Tuple{String, String, Int64}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.foreach),
                typeof(WannierNLQG.SymmetryFoundation.sha256_file),
                Array{String, 1},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.getindex), Base.RefValue{Any}})
        _record_early_prepare(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        _record_early_prepare(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
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
        _record_early_prepare(Tuple{typeof(Base.transpose), Array{Float64, 1}})
        _record_early_prepare(Tuple{typeof(Base.length), Array{Float64, 1}})
        _record_early_prepare(Tuple{Type{Array{Float64, 1}}, Array{Float64, 1}})
        _record_early_prepare(
            Tuple{
                typeof(Base._all),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#266#285"{Int64},
                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                Base.Colon,
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#266#285"{Int64},
                NamedTuple{
                    (:k_fractional, :num_bands, :spin_components, :plane_wave_count),
                    Tuple{Array{Float64, 1}, Int64, Int64, Int64},
                },
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.identity), Array{Float64, 1}},
        )
        _record_early_prepare(
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
        _record_early_prepare(
            Tuple{
                typeof(Base._array_for),
                Type{Tuple{Int64, Tuple{Int64, Int64, Int64}}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Tuple{Int64, Tuple{Int64, Int64, Int64}}, 1},
                Tuple{Int64, Tuple{Int64, Int64, Int64}},
                Base.Generator{
                    Base.UnitRange{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#218#219"{
                        WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                        Int64,
                    },
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Tuple{Int64, Tuple{Int64, Int64, Int64}},
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.unique), Array{Tuple{Int64, Tuple{Int64, Int64, Int64}}, 1}},
        )
        _record_early_prepare(Tuple{typeof(Base.collect), Base.Dict{String, String}})
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:by,), Tuple{typeof(Base.first)}},
                typeof(Base.sort!),
                Array{Pair{String, String}, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.repr),
                Tuple{Array{Pair{String, String}, 1}, String, Array{Int64, 1}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Tuple{Array{Pair{String, String}, 1}, String, Array{Int64, 1}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :directory,
                        :contract,
                        :max_artifact_bytes,
                        :max_resident_bytes,
                        :resident_bytes,
                        :resident,
                        :recency,
                        :owner,
                    ),
                    Tuple{
                        String,
                        String,
                        Int64,
                        Int64,
                        Base.RefValue{Int64},
                        Base.Dict{String, Any},
                        Array{String, 1},
                        Task,
                    },
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._preparation_artifact_event),
                NamedTuple{
                    (
                        :directory,
                        :contract,
                        :max_artifact_bytes,
                        :max_resident_bytes,
                        :resident_bytes,
                        :resident,
                        :recency,
                        :owner,
                    ),
                    Tuple{
                        String,
                        String,
                        Int64,
                        Int64,
                        Base.RefValue{Int64},
                        Base.Dict{String, Any},
                        Array{String, 1},
                        Task,
                    },
                },
                String,
                String,
                Nothing,
                Float64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.print), Base.IOStream, Float64})
        _record_early_prepare(Tuple{Type{Base.KeyError}, String})
        _record_early_prepare(Tuple{typeof(Base.maximum), Array{Int64, 1}})
        _record_early_prepare(Tuple{Base.SummarySize, Any})
        _record_early_prepare(
            Tuple{
                Base.SummarySize,
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
        )
        _record_early_prepare(
            Tuple{
                Base.SummarySize,
                GenericMemory{:not_atomic, String, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                GenericMemory{:not_atomic, String, Base.Core.AddrSpace{Base.Core}(0x00)},
                Int64,
            },
        )
        _record_early_prepare(Tuple{Base.SummarySize, String})
        _record_early_prepare(
            Tuple{
                Base.SummarySize,
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                Base.SummarySize,
                GenericMemory{:not_atomic, Float64, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
        )
        _record_early_prepare(
            Tuple{
                Base.SummarySize,
                GenericMemory{:not_atomic, Int64, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
        )
        _record_early_prepare(
            Tuple{
                Base.SummarySize,
                GenericMemory{
                    :not_atomic,
                    Tuple{Int64, Int64, Int64},
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.SummarySize,
                GenericMemory{:not_atomic, Array{Float64, 1}, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                GenericMemory{:not_atomic, Array{Float64, 1}, Base.Core.AddrSpace{Base.Core}(0x00)},
                Int64,
            },
        )
        false
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Base.Dict{String, WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Bool,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Array{Float64, 2},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Array{Int64, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Base.Dict{Tuple{Int64, Int64, Int64}, Array{Float64, 1}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Array{Float64, 4},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Float64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO.cached_preparation_artifact),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#270#289"{
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                    NamedTuple{
                        (
                            :xml_file,
                            :structure,
                            :reciprocal_lattice,
                            :noncollinear,
                            :spinorbit,
                            :collinear,
                            :num_bands,
                            :cutoff_ev,
                            :kpoint_nodes,
                            :atomic_type_labels,
                            :type_elements,
                            :upf_files,
                            :metric_kinds,
                        ),
                        Tuple{
                            String,
                            WannierNLQG.SymmetryFoundation.CrystalStructure,
                            Array{Float64, 2},
                            Bool,
                            Bool,
                            Bool,
                            Int64,
                            Float64,
                            Array{WannierizationInternalSupport.EzXML.Node, 1},
                            Array{String, 1},
                            Base.Dict{String, String},
                            Base.Dict{String, String},
                            Base.Dict{String, Symbol},
                        },
                    },
                },
                String,
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#271#290"{String},
            },
        )
        _record_early_prepare(
            Tuple{
                Base.SummarySize,
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                Base.SummarySize,
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorChannel,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Array{
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                    1,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Tuple{Float64, Float64, Float64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Array{WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorChannel, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:max_bytes, :estimate_bytes),
                    Tuple{
                        Int64,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#275#295"{
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Array{Int64, 1},
                            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                            Int64,
                        },
                    },
                },
                Type{WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache},
                Int64,
                Function,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#282#306"{
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                },
                Array{
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                    1,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Array{
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                        1,
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#282#306"{
                        Base.Dict{
                            String,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Base.Dict{String, Symbol},
                Char,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.setindex!),
                Base.RefValue{Any},
                NamedTuple{
                    (
                        :native,
                        :topology,
                        :overlap,
                        :generalized_norm,
                        :radial_q_maximum,
                        :input_sha256,
                        :diagnostics,
                        :wavefunction_cache,
                        :beta_cache,
                        :beta_contractions,
                        :normalization_points,
                        :overlap_contractions,
                        :spn_block,
                        :spn_input,
                        :spn_evaluate,
                        :spn_evaluate_with_norm,
                        :accept_norm,
                        :finish_norm,
                    ),
                    Tuple{
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#overlap#303"{
                            Base.RefValue{Int64},
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{WannierizationInternalSupport.EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                        Nothing,
                        Float64,
                        Base.Dict{String, String},
                        Array{String, 1},
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEBetaOverlapCache,
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#284#309"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                                Base.RefValue{Any},
                                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                                Base.RefValue{Int64},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                            Tuple{
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                            },
                            Array{Array{Base.Complex{Float64}, 2}, 1},
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate_with_norm#310"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.RefValue{Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#accept_norm#297"{
                            Base.Dict{Int64, Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#finish_norm#298"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            Base.Dict{Int64, Any},
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :native,
                        :topology,
                        :overlap,
                        :generalized_norm,
                        :radial_q_maximum,
                        :input_sha256,
                        :diagnostics,
                        :wavefunction_cache,
                        :beta_cache,
                        :beta_contractions,
                        :normalization_points,
                        :overlap_contractions,
                        :spn_block,
                        :spn_input,
                        :spn_evaluate,
                        :spn_evaluate_with_norm,
                        :accept_norm,
                        :finish_norm,
                    ),
                    Tuple{
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#overlap#303"{
                            Base.RefValue{Int64},
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{WannierizationInternalSupport.EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                        Nothing,
                        Float64,
                        Base.Dict{String, String},
                        Array{String, 1},
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEBetaOverlapCache,
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#284#309"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                                Base.RefValue{Any},
                                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                                Base.RefValue{Int64},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                            Tuple{
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                            },
                            Array{Array{Base.Complex{Float64}, 2}, 1},
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate_with_norm#310"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.RefValue{Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#accept_norm#297"{
                            Base.Dict{Int64, Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#finish_norm#298"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            Base.Dict{Int64, Any},
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        },
                    },
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                Symbol,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.min), Int64, Int64})
        _record_early_prepare(
            Tuple{
                typeof(Base.setproperty!),
                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                Symbol,
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.copy), Base.Dict{String, String}})
        _record_early_prepare(Tuple{typeof(Base.sym_in), Symbol, NTuple{18, Symbol}})
        _record_early_prepare(
            Tuple{
                typeof(Base.merge),
                NamedTuple{
                    (
                        :native,
                        :topology,
                        :overlap,
                        :generalized_norm,
                        :radial_q_maximum,
                        :input_sha256,
                        :diagnostics,
                        :wavefunction_cache,
                        :beta_cache,
                        :beta_contractions,
                        :normalization_points,
                        :overlap_contractions,
                        :spn_block,
                        :spn_input,
                        :spn_evaluate,
                        :spn_evaluate_with_norm,
                        :accept_norm,
                        :finish_norm,
                    ),
                    Tuple{
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#overlap#303"{
                            Base.RefValue{Int64},
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{WannierizationInternalSupport.EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                        Nothing,
                        Float64,
                        Base.Dict{String, String},
                        Array{String, 1},
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEBetaOverlapCache,
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#284#309"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                                Base.RefValue{Any},
                                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                                Base.RefValue{Int64},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                            Tuple{
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                            },
                            Array{Array{Base.Complex{Float64}, 2}, 1},
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate_with_norm#310"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.RefValue{Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#accept_norm#297"{
                            Base.Dict{Int64, Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#finish_norm#298"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            Base.Dict{Int64, Any},
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        },
                    },
                },
                NamedTuple{
                    (:input_sha256, :diagnostics),
                    Tuple{Base.Dict{String, String}, Array{String, 1}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.zeros), Type{Base.Complex{Float64}}, Int64, Int64, Vararg{Int64}},
        )
        _record_early_prepare(Tuple{typeof(Base.repr), Array{Pair{String, String}, 1}})
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{Pair{String, String}, 1},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.join), Array{String, 1}, String})
        _record_early_prepare(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#363#369"{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#362#368"{
                        Array{Base.Complex{Float64}, 4},
                        Int64,
                    },
                    String,
                    Int64,
                },
                Symbol,
                NamedTuple{
                    (:mode, :max_workers, :memory_budget_bytes, :checkpoint_directory, :resume),
                    Tuple{Symbol, Int64, Int64, String, Bool},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:contract, :label, :fingerprint_index),
                    Tuple{String, String, typeof(Base.string)},
                },
                typeof(WannierNLQG.IO.foreach_preparation_block),
                Function,
                Function,
                Function,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQG.IO.var"##foreach_preparation_block#21",
                String,
                String,
                WannierNLQG.IO.var"#27#33",
                typeof(Base.string),
                typeof(WannierNLQG.IO.foreach_preparation_block),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#364#370",
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                    Base.RefValue{Any},
                    WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                    Base.RefValue{Int64},
                },
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#362#368"{
                    Array{Base.Complex{Float64}, 4},
                    Int64,
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (:mode, :max_workers, :memory_budget_bytes, :checkpoint_directory, :resume),
                    Tuple{Symbol, Int64, Int64, String, Bool},
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Tuple{Int64, String, Bool, Task},
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.string), Int64})
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                    Base.RefValue{Any},
                    WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                    Base.RefValue{Int64},
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#275#295"{
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    Array{Int64, 1},
                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                    Int64,
                },
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.afoldl), typeof(Base.:(*)), Int64, Int64})
        _record_early_prepare(Tuple{typeof(Base.:(+)), Vararg{Int64, 5}})
        _record_early_prepare(Tuple{typeof(Base.:(&)), Bool, Base.Missing})
        _record_early_prepare(Tuple{typeof(Base.:(==)), Char, Char})
        _record_early_prepare(Tuple{typeof(Base.iszero), Bool})
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties},
        )
        _record_early_prepare(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties},
        )
        _record_early_prepare(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties})
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties},
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#load_entry#291"{
                    Base.RefValue{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.QEBetaOverlapCache,
                    Base.Dict{Tuple{String, Int64, Int64}, Float64},
                    Array{Array{Float64, 1}, 1},
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                    String,
                    WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                    Array{Int64, 1},
                    Array{String, 1},
                    Int64,
                    NamedTuple{
                        (
                            :xml_file,
                            :structure,
                            :reciprocal_lattice,
                            :noncollinear,
                            :spinorbit,
                            :collinear,
                            :num_bands,
                            :cutoff_ev,
                            :kpoint_nodes,
                            :atomic_type_labels,
                            :type_elements,
                            :upf_files,
                            :metric_kinds,
                        ),
                        Tuple{
                            String,
                            WannierNLQG.SymmetryFoundation.CrystalStructure,
                            Array{Float64, 2},
                            Bool,
                            Bool,
                            Bool,
                            Int64,
                            Float64,
                            Array{WannierizationInternalSupport.EzXML.Node, 1},
                            Array{String, 1},
                            Base.Dict{String, String},
                            Base.Dict{String, String},
                            Base.Dict{String, Symbol},
                        },
                    },
                },
                Int64,
            },
        )
        _record_early_prepare(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        _record_early_prepare(Tuple{typeof(Base.size), Array{Int64, 2}})
        _record_early_prepare(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        _record_early_prepare(Tuple{typeof(Base.collect), Base.UnitRange{Int64}})
        _record_early_prepare(
            Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64},
        )
        _record_early_prepare(Tuple{typeof(Base.size), Array{Float64, 2}})
        _record_early_prepare(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
        _record_early_prepare(Tuple{typeof(Base.isfinite), Float64})
        _record_early_prepare(Tuple{typeof(Base.length), Array{Int64, 1}})
        _record_early_prepare(
            Tuple{typeof(Base.reshape), Array{Base.Complex{Float64}, 1}, Int64, Int64},
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._preparation_artifact_event),
                NamedTuple{
                    (
                        :directory,
                        :contract,
                        :max_artifact_bytes,
                        :max_resident_bytes,
                        :resident_bytes,
                        :resident,
                        :recency,
                        :owner,
                    ),
                    Tuple{
                        String,
                        String,
                        Int64,
                        Int64,
                        Base.RefValue{Int64},
                        Base.Dict{String, Any},
                        Array{String, 1},
                        Task,
                    },
                },
                String,
                String,
                Int64,
                Float64,
            },
        )
        _record_early_prepare(
            Tuple{
                Base.SummarySize,
                GenericMemory{
                    :not_atomic,
                    Base.Complex{Float64},
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.setindex!),
                Base.Dict{Int64, Array{Base.Complex{Float64}, 3}},
                Array{Base.Complex{Float64}, 3},
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.setindex!),
                Base.Dict{Int64, WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUCacheEntry},
                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUCacheEntry,
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.:(-)), Int64, UInt64})
        _record_early_prepare(Tuple{typeof(Base.:(<=)), Int64, UInt64})
        _record_early_prepare(Tuple{typeof(Base.div), UInt64, Int64})
        _record_early_prepare(Tuple{typeof(Base.max), Int64, UInt64})
        _record_early_prepare(Tuple{typeof(Base.min), Int64, UInt64})
        _record_early_prepare(
            Tuple{
                typeof(Base.push!),
                Array{Tuple{Int64, String, Bool, Task}, 1},
                Tuple{Int64, String, Bool, Task},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.:(>=)), Int64, UInt64})
        _record_early_prepare(
            Tuple{
                WannierNLQG.IO.var"#23#29"{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#364#370",
                    Int64,
                    WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUCacheEntry,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate_with_norm#310"{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                        Tuple{
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                        },
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                        Base.Dict{
                            String,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                        },
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                        Base.Dict{
                            String,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                        },
                        NamedTuple{
                            (
                                :xml_file,
                                :structure,
                                :reciprocal_lattice,
                                :noncollinear,
                                :spinorbit,
                                :collinear,
                                :num_bands,
                                :cutoff_ev,
                                :kpoint_nodes,
                                :atomic_type_labels,
                                :type_elements,
                                :upf_files,
                                :metric_kinds,
                            ),
                            Tuple{
                                String,
                                WannierNLQG.SymmetryFoundation.CrystalStructure,
                                Array{Float64, 2},
                                Bool,
                                Bool,
                                Bool,
                                Int64,
                                Float64,
                                Array{WannierizationInternalSupport.EzXML.Node, 1},
                                Array{String, 1},
                                Base.Dict{String, String},
                                Base.Dict{String, String},
                                Base.Dict{String, Symbol},
                            },
                        },
                    },
                    Base.RefValue{Any},
                },
                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUCacheEntry,
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#362#368"{
                    Array{Base.Complex{Float64}, 4},
                    Int64,
                },
                Int64,
                Tuple{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Float64, Base.IteratorsMD.CartesianIndex{2}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#accept_norm#297"{
                    Base.Dict{Int64, Any},
                },
                Int64,
                Tuple{Float64, Base.IteratorsMD.CartesianIndex{2}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO.write_preparation_checkpoint),
                String,
                String,
                Tuple{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Float64, Base.IteratorsMD.CartesianIndex{2}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Tuple{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Float64, Base.IteratorsMD.CartesianIndex{2}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Tuple{Int64, Int64},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.print), Base.IOStream, UInt64})
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._qe_state_with_completed_norm,
                ),
                NamedTuple{
                    (
                        :native,
                        :topology,
                        :overlap,
                        :generalized_norm,
                        :radial_q_maximum,
                        :input_sha256,
                        :diagnostics,
                        :wavefunction_cache,
                        :beta_cache,
                        :beta_contractions,
                        :normalization_points,
                        :overlap_contractions,
                        :spn_block,
                        :spn_input,
                        :spn_evaluate,
                        :spn_evaluate_with_norm,
                        :accept_norm,
                        :finish_norm,
                    ),
                    Tuple{
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#overlap#303"{
                            Base.RefValue{Int64},
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{WannierizationInternalSupport.EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                        Nothing,
                        Float64,
                        Base.Dict{String, String},
                        Array{String, 1},
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEBetaOverlapCache,
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#284#309"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                                Base.RefValue{Any},
                                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                                Base.RefValue{Int64},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                            Tuple{
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                            },
                            Array{Array{Base.Complex{Float64}, 2}, 1},
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate_with_norm#310"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.RefValue{Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#accept_norm#297"{
                            Base.Dict{Int64, Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#finish_norm#298"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            Base.Dict{Int64, Any},
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{Float64, Base.IteratorsMD.CartesianIndex{2}},
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{Float64, Base.IteratorsMD.CartesianIndex{2}},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.:(>)), Float64, Float64})
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO.write_preparation_checkpoint),
                String,
                String,
                Tuple{Float64, Tuple{Int64, Int64, Int64}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Tuple{Float64, Tuple{Int64, Int64, Int64}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._uiu_state_with_qualification_scope,
                ),
                NamedTuple{
                    (
                        :native,
                        :topology,
                        :overlap,
                        :generalized_norm,
                        :radial_q_maximum,
                        :input_sha256,
                        :diagnostics,
                        :wavefunction_cache,
                        :beta_cache,
                        :beta_contractions,
                        :normalization_points,
                        :overlap_contractions,
                        :spn_block,
                        :spn_input,
                        :spn_evaluate,
                        :spn_evaluate_with_norm,
                        :accept_norm,
                        :finish_norm,
                    ),
                    Tuple{
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#overlap#303"{
                            Base.RefValue{Int64},
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{WannierizationInternalSupport.EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                        Float64,
                        Float64,
                        Base.Dict{String, String},
                        Array{String, 1},
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEBetaOverlapCache,
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#284#309"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                                Base.RefValue{Any},
                                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                                Base.RefValue{Int64},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                            Tuple{
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                            },
                            Array{Array{Base.Complex{Float64}, 2}, 1},
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate_with_norm#310"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.RefValue{Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#accept_norm#297"{
                            Base.Dict{Int64, Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#finish_norm#298"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            Base.Dict{Int64, Any},
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        },
                    },
                },
                Nothing,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._record_spn_publication_blocks,
                ),
                Symbol,
                NamedTuple{
                    (:mode, :max_workers, :memory_budget_bytes, :checkpoint_directory, :resume),
                    Tuple{Symbol, Int64, Int64, String, Bool},
                },
                String,
                String,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{(:owner, :slot), Tuple{Task, Base.RefValue{Any}}},
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.setindex!),
                Base.RefValue{Any},
                NamedTuple{
                    (:kind, :directory, :label, :contract, :count),
                    Tuple{Symbol, String, String, String, Int64},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :native,
                        :topology,
                        :overlap,
                        :generalized_norm,
                        :radial_q_maximum,
                        :input_sha256,
                        :diagnostics,
                        :wavefunction_cache,
                        :beta_cache,
                        :beta_contractions,
                        :normalization_points,
                        :overlap_contractions,
                        :spn_block,
                        :spn_input,
                        :spn_evaluate,
                        :spn_evaluate_with_norm,
                        :accept_norm,
                        :finish_norm,
                        :parent_generalized_norm,
                        :target_generalized_norm_worst,
                        :parent_generalized_norm_worst,
                        :target_authority,
                        :parent_audit_policy,
                        :outer_mask_sha256,
                        :frozen_mask_sha256,
                    ),
                    Tuple{
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#overlap#303"{
                            Base.RefValue{Int64},
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{WannierizationInternalSupport.EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                        Float64,
                        Float64,
                        Base.Dict{String, String},
                        Array{String, 1},
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEBetaOverlapCache,
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#284#309"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                                Base.RefValue{Any},
                                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                                Base.RefValue{Int64},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                            Tuple{
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                            },
                            Array{Array{Base.Complex{Float64}, 2}, 1},
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate_with_norm#310"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.RefValue{Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#accept_norm#297"{
                            Base.Dict{Int64, Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#finish_norm#298"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            Base.Dict{Int64, Any},
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        },
                        Float64,
                        Tuple{Int64, Int64, Int64},
                        Tuple{Int64, Int64, Int64},
                        Vararg{String, 4},
                    },
                },
                Symbol,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.:(<=)), Float64, Float64})
        _record_early_prepare(Tuple{typeof(Base.repeat), Char, Int64})
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#365#371",
                Base.UnitRange{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.reduce),
                Function,
                Base.Generator{
                    Base.UnitRange{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#365#371",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##mapfoldl#335",
                Base._InitialValue,
                typeof(Base.mapfoldl),
                Function,
                Function,
                Base.Generator{
                    Base.UnitRange{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#365#371",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                typeof(Base.vcat),
                Base._InitialValue,
                Base.Generator{
                    Base.UnitRange{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#365#371",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.transpose),
                Base.SubArray{
                    Float64,
                    1,
                    Array{Float64, 2},
                    Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                    true,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Tuple{
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    WannierNLQG.Wannierization.NativeDFTHamiltonian,
                    Nothing,
                    Int64,
                    Int64,
                    Symbol,
                },
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
        _record_early_prepare(Tuple{Type{Pair{A, B} where {B} where A}, String, Bool})
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                Symbol,
            },
        )
        false
        false
        _record_early_prepare(
            Tuple{Type{Pair{A, B} where {B} where A}, String, Array{Array{Float64, 1}, 1}},
        )
        _record_early_prepare(
            Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, String}},
        )
        _record_early_prepare(Tuple{Type{Pair{A, B} where {B} where A}, String, Array{String, 1}})
        _record_early_prepare(
            Tuple{
                Type{Base.Dict{K, V} where {V} where K},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{
                        String,
                        NamedTuple{
                            (
                                :schema,
                                :schema_version,
                                :status,
                                :legacy,
                                :source_band_gauge,
                                :target_band_gauge,
                                :transform_sha256,
                                :contract_sha256,
                                :gauge_artifact_sha256,
                                :metric_kind,
                                :physical_isometry_maximum,
                                :physical_isometry_tolerance,
                                :replay_maximum,
                                :replay_tolerance,
                                :euclidean_nonunitarity_maximum,
                                :minimum_singular_value,
                                :maximum_condition_number,
                            ),
                            Tuple{
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
                                Vararg{Float64, 7},
                            },
                        },
                    },
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Array{Array{Float64, 1}, 1}},
                    Pair{String, Array{String, 1}},
                    Pair{String, Bool},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
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
                    Pair{String, Base.Dict{String, Float64}},
                    Pair{String, Nothing},
                    Pair{String, Base.Dict{String, String}},
                    Pair{String, Base.Dict{String, String}},
                    Pair{String, Array{String, 1}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{String, Any},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{
                        String,
                        NamedTuple{
                            (
                                :schema,
                                :schema_version,
                                :status,
                                :legacy,
                                :source_band_gauge,
                                :target_band_gauge,
                                :transform_sha256,
                                :contract_sha256,
                                :gauge_artifact_sha256,
                                :metric_kind,
                                :physical_isometry_maximum,
                                :physical_isometry_tolerance,
                                :replay_maximum,
                                :replay_tolerance,
                                :euclidean_nonunitarity_maximum,
                                :minimum_singular_value,
                                :maximum_condition_number,
                            ),
                            Tuple{
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
                                Vararg{Float64, 7},
                            },
                        },
                    },
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Array{Array{Float64, 1}, 1}},
                    Pair{String, Array{String, 1}},
                    Pair{String, Bool},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
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
                    Pair{String, Base.Dict{String, Float64}},
                    Pair{String, Nothing},
                    Pair{String, Base.Dict{String, String}},
                    Pair{String, Base.Dict{String, String}},
                    Pair{String, Array{String, 1}},
                },
                Int64,
            },
        )
        false
        _record_early_prepare(
            Tuple{
                Type{Pair{A, B} where {B} where A},
                String,
                NamedTuple{
                    (
                        :schema,
                        :schema_version,
                        :status,
                        :legacy,
                        :source_band_gauge,
                        :target_band_gauge,
                        :transform_sha256,
                        :contract_sha256,
                        :gauge_artifact_sha256,
                        :metric_kind,
                        :physical_isometry_maximum,
                        :physical_isometry_tolerance,
                        :replay_maximum,
                        :replay_tolerance,
                        :euclidean_nonunitarity_maximum,
                        :minimum_singular_value,
                        :maximum_condition_number,
                    ),
                    Tuple{
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
                        Vararg{Float64, 7},
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Float64}},
        )
        _record_early_prepare(Tuple{typeof(Base.add_sum), Int64, Int64})
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                NamedTuple{
                    (
                        :schema,
                        :schema_version,
                        :status,
                        :legacy,
                        :source_band_gauge,
                        :target_band_gauge,
                        :transform_sha256,
                        :contract_sha256,
                        :gauge_artifact_sha256,
                        :metric_kind,
                        :physical_isometry_maximum,
                        :physical_isometry_tolerance,
                        :replay_maximum,
                        :replay_tolerance,
                        :euclidean_nonunitarity_maximum,
                        :minimum_singular_value,
                        :maximum_condition_number,
                    ),
                    Tuple{
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
                        Vararg{Float64, 7},
                    },
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.add_sum), UInt64, UInt64})
        _record_early_prepare(Tuple{typeof(Base.:(+)), Int64, UInt64})
        _record_early_prepare(
            Tuple{typeof(PAWMatrixElements.JSON3.defaultminimum), Array{Array{Float64, 1}, 1}},
        )
        _record_early_prepare(Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64})
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.write),
                PAWMatrixElements.JSON3.StructTypes.UnorderedStruct,
                Array{UInt8, 1},
                Int64,
                Int64,
                NamedTuple{
                    (
                        :schema,
                        :schema_version,
                        :status,
                        :legacy,
                        :source_band_gauge,
                        :target_band_gauge,
                        :transform_sha256,
                        :contract_sha256,
                        :gauge_artifact_sha256,
                        :metric_kind,
                        :physical_isometry_maximum,
                        :physical_isometry_tolerance,
                        :replay_maximum,
                        :replay_tolerance,
                        :euclidean_nonunitarity_maximum,
                        :minimum_singular_value,
                        :maximum_condition_number,
                    ),
                    Tuple{
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
                        Vararg{Float64, 7},
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.write),
                PAWMatrixElements.JSON3.StructTypes.ArrayType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Array{Array{Float64, 1}, 1},
            },
        )
        _record_early_prepare(Tuple{Type{String}, Array{UInt8, 1}})
        _record_early_prepare(
            Tuple{typeof(PAWMatrixElements.JSON3.read), String, Type{Base.Dict{String, Any}}},
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
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._uiu_atomic_json),
                String,
                Base.Dict{String, Any},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.write), Base.IOStream, Array{UInt8, 1}})
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO.write_preparation_checkpoint),
                String,
                String,
                NamedTuple{
                    (:output_sha256, :provenance_sha256, :result),
                    Tuple{
                        String,
                        String,
                        NamedTuple{
                            (:schema, :blocks, :fields, :shape, :array_sha256),
                            Tuple{
                                String,
                                NamedTuple{
                                    (:kind, :directory, :label, :contract, :count),
                                    Tuple{Symbol, String, String, String, Int64},
                                },
                                Tuple{
                                    Nothing,
                                    Float64,
                                    Float64,
                                    Float64,
                                    Bool,
                                    String,
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Array{String, 1},
                                },
                                NTuple{4, Int64},
                                String,
                            },
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Tuple{Symbol, Symbol, Symbol},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                NTuple{5, Symbol},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Tuple{
                    Nothing,
                    Float64,
                    Float64,
                    Float64,
                    Bool,
                    String,
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                    Array{String, 1},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Base.Dict{String, String},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Array{String, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                NTuple{4, Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.deserialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                DataType,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.deserialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Type{
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                },
            },
        )
        _record_early_prepare(Tuple{Type{Array{Float64, 1}}, UndefInitializer, Int64})
        _record_early_prepare(Tuple{typeof(Base.read!), Base.IOStream, Array{Float64, 1}})
        _record_early_prepare(Tuple{typeof(Base.prod), Tuple{Int64, Int64}})
        _record_early_prepare(
            Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Tuple{Int64, Int64}},
        )
        _record_early_prepare(Tuple{typeof(Base.read!), Base.IOStream, Array{Float64, 2}})
        _record_early_prepare(Tuple{typeof(Base.read!), Base.IOStream, Array{Int64, 1}})
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.deserialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Type{Base.Dict{Tuple{Int64, Int64, Int64}, Array{Float64, 1}}},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.prod), NTuple{4, Int64}})
        _record_early_prepare(
            Tuple{Type{Array{Float64, N} where N}, UndefInitializer, NTuple{4, Int64}},
        )
        _record_early_prepare(Tuple{typeof(Base.read!), Base.IOStream, Array{Float64, 4}})
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (:contract, :payload),
                    Tuple{
                        String,
                        Base.Dict{
                            String,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                        },
                    },
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._preparation_remember_artifact!),
                NamedTuple{
                    (
                        :directory,
                        :contract,
                        :max_artifact_bytes,
                        :max_resident_bytes,
                        :resident_bytes,
                        :resident,
                        :recency,
                        :owner,
                    ),
                    Tuple{
                        String,
                        String,
                        Int64,
                        Int64,
                        Base.RefValue{Int64},
                        Base.Dict{String, Any},
                        Array{String, 1},
                        Task,
                    },
                },
                String,
                Base.Dict{String, WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData},
                Tuple{
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                },
                String,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.deepcopy_internal), Symbol, Base.IdDict{Any, Any}})
        _record_early_prepare(
            Tuple{typeof(Base.deepcopy_internal), Array{Float64, 2}, Base.IdDict{Any, Any}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.copy),
                GenericMemory{:not_atomic, Int64, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.deepcopy_internal),
                Base.Dict{Tuple{Int64, Int64, Int64}, Array{Float64, 1}},
                Base.IdDict{Any, Any},
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.deepcopy_internal), Array{Float64, 4}, Base.IdDict{Any, Any}},
        )
        _record_early_prepare(
            Tuple{
                Type{
                    Array{
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                        1,
                    },
                },
                UndefInitializer,
                Tuple{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.length),
                Array{
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                    1,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.deserialize_fillarray!),
                Array{
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                    1,
                },
                WannierNLQG.Serialization.Serializer{Base.IOStream},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{
                    Array{
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorChannel,
                        1,
                    },
                },
                UndefInitializer,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.read!),
                Base.IOStream,
                Array{WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorChannel, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.setindex!),
                Array{
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                    1,
                },
                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (:contract, :payload),
                    Tuple{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    },
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._preparation_remember_artifact!),
                NamedTuple{
                    (
                        :directory,
                        :contract,
                        :max_artifact_bytes,
                        :max_resident_bytes,
                        :resident_bytes,
                        :resident,
                        :recency,
                        :owner,
                    ),
                    Tuple{
                        String,
                        String,
                        Int64,
                        Int64,
                        Base.RefValue{Int64},
                        Base.Dict{String, Any},
                        Array{String, 1},
                        Task,
                    },
                },
                String,
                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                Tuple{
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                },
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.deepcopy_internal),
                Array{
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                    1,
                },
                Base.IdDict{Any, Any},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{
                    GenericMemory{
                        :not_atomic,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
                UndefInitializer,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.deepcopy_internal),
                Array{WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorChannel, 1},
                Base.IdDict{Any, Any},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.copy),
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorChannel,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (:contract, :payload),
                    Tuple{String, Tuple{Float64, Tuple{Int64, Int64, Int64}}},
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._preparation_remember_artifact!),
                NamedTuple{
                    (
                        :directory,
                        :contract,
                        :max_artifact_bytes,
                        :max_resident_bytes,
                        :resident_bytes,
                        :resident,
                        :recency,
                        :owner,
                    ),
                    Tuple{
                        String,
                        String,
                        Int64,
                        Int64,
                        Base.RefValue{Int64},
                        Base.Dict{String, Any},
                        Array{String, 1},
                        Task,
                    },
                },
                String,
                Tuple{Float64, Tuple{Int64, Int64, Int64}},
                Tuple{
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                },
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.setindex!),
                Base.RefValue{Any},
                NamedTuple{
                    (
                        :native,
                        :topology,
                        :overlap,
                        :generalized_norm,
                        :radial_q_maximum,
                        :input_sha256,
                        :diagnostics,
                        :wavefunction_cache,
                        :beta_cache,
                        :beta_contractions,
                        :normalization_points,
                        :overlap_contractions,
                        :spn_block,
                        :spn_input,
                        :spn_evaluate,
                        :spn_evaluate_with_norm,
                        :accept_norm,
                        :finish_norm,
                    ),
                    Tuple{
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#overlap#303"{
                            Base.RefValue{Int64},
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{WannierizationInternalSupport.EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                        Float64,
                        Float64,
                        Base.Dict{String, String},
                        Array{String, 1},
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEBetaOverlapCache,
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#284#309"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                                Base.RefValue{Any},
                                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                                Base.RefValue{Int64},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                            Tuple{
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                            },
                            Array{Array{Base.Complex{Float64}, 2}, 1},
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate_with_norm#310"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.RefValue{Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#accept_norm#297"{
                            Base.Dict{Int64, Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#finish_norm#298"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            Base.Dict{Int64, Any},
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :native,
                        :topology,
                        :overlap,
                        :generalized_norm,
                        :radial_q_maximum,
                        :input_sha256,
                        :diagnostics,
                        :wavefunction_cache,
                        :beta_cache,
                        :beta_contractions,
                        :normalization_points,
                        :overlap_contractions,
                        :spn_block,
                        :spn_input,
                        :spn_evaluate,
                        :spn_evaluate_with_norm,
                        :accept_norm,
                        :finish_norm,
                    ),
                    Tuple{
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#overlap#303"{
                            Base.RefValue{Int64},
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{WannierizationInternalSupport.EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                        Float64,
                        Float64,
                        Base.Dict{String, String},
                        Array{String, 1},
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEBetaOverlapCache,
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#284#309"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                                Base.RefValue{Any},
                                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                                Base.RefValue{Int64},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                            Tuple{
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                            },
                            Array{Array{Base.Complex{Float64}, 2}, 1},
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate_with_norm#310"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.RefValue{Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#accept_norm#297"{
                            Base.Dict{Int64, Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#finish_norm#298"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            Base.Dict{Int64, Any},
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        },
                    },
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.merge),
                NamedTuple{
                    (
                        :native,
                        :topology,
                        :overlap,
                        :generalized_norm,
                        :radial_q_maximum,
                        :input_sha256,
                        :diagnostics,
                        :wavefunction_cache,
                        :beta_cache,
                        :beta_contractions,
                        :normalization_points,
                        :overlap_contractions,
                        :spn_block,
                        :spn_input,
                        :spn_evaluate,
                        :spn_evaluate_with_norm,
                        :accept_norm,
                        :finish_norm,
                    ),
                    Tuple{
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#overlap#303"{
                            Base.RefValue{Int64},
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{WannierizationInternalSupport.EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                        Float64,
                        Float64,
                        Base.Dict{String, String},
                        Array{String, 1},
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEBetaOverlapCache,
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#284#309"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                                Base.RefValue{Any},
                                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                                Base.RefValue{Int64},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                            Tuple{
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                            },
                            Array{Array{Base.Complex{Float64}, 2}, 1},
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate_with_norm#310"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.RefValue{Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#accept_norm#297"{
                            Base.Dict{Int64, Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#finish_norm#298"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            Base.Dict{Int64, Any},
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        },
                    },
                },
                NamedTuple{
                    (:input_sha256, :diagnostics),
                    Tuple{Base.Dict{String, String}, Array{String, 1}},
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.prod), Tuple{Int64, Int64, Int64}})
        _record_early_prepare(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.read!), Base.IOStream, Array{Base.Complex{Float64}, 3}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{(:contract, :payload), Tuple{String, Array{Base.Complex{Float64}, 3}}},
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._preparation_remember_artifact!),
                NamedTuple{
                    (
                        :directory,
                        :contract,
                        :max_artifact_bytes,
                        :max_resident_bytes,
                        :resident_bytes,
                        :resident,
                        :recency,
                        :owner,
                    ),
                    Tuple{
                        String,
                        String,
                        Int64,
                        Int64,
                        Base.RefValue{Int64},
                        Base.Dict{String, Any},
                        Array{String, 1},
                        Task,
                    },
                },
                String,
                Array{Base.Complex{Float64}, 3},
                Tuple{
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                },
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.copy),
                GenericMemory{
                    :not_atomic,
                    Base.Complex{Float64},
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        false
        false
        false
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._qe_state_with_completed_norm,
                ),
                NamedTuple{
                    (
                        :native,
                        :topology,
                        :overlap,
                        :generalized_norm,
                        :radial_q_maximum,
                        :input_sha256,
                        :diagnostics,
                        :wavefunction_cache,
                        :beta_cache,
                        :beta_contractions,
                        :normalization_points,
                        :overlap_contractions,
                        :spn_block,
                        :spn_input,
                        :spn_evaluate,
                        :spn_evaluate_with_norm,
                        :accept_norm,
                        :finish_norm,
                    ),
                    Tuple{
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#overlap#303"{
                            Base.RefValue{Int64},
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{WannierizationInternalSupport.EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                        Float64,
                        Float64,
                        Base.Dict{String, String},
                        Array{String, 1},
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                        WannierNLQGWannierizationExt.PAWMatrixElements.QEBetaOverlapCache,
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        Base.RefValue{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#284#309"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                                Base.RefValue{Any},
                                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                                Base.RefValue{Int64},
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#283#308"{
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                            Tuple{
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                            },
                            Array{Array{Base.Complex{Float64}, 2}, 1},
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate_with_norm#310"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#spn_evaluate#307"{
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.RefValue{Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#accept_norm#297"{
                            Base.Dict{Int64, Any},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#finish_norm#298"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#norm_point#296"{
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{WannierizationInternalSupport.EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                            Base.Dict{
                                Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                                Array{Base.Complex{Float64}, 4},
                            },
                            Base.Dict{Int64, Any},
                            Base.RefValue{Any},
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUWavefunctionCache,
                            Base.RefValue{Int64},
                            String,
                            WannierNLQGWannierizationExt.PAWMatrixElements.QEUIULazyNative,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (:contract, :payload),
                    Tuple{
                        String,
                        WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                    },
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._preparation_remember_artifact!),
                NamedTuple{
                    (
                        :directory,
                        :contract,
                        :max_artifact_bytes,
                        :max_resident_bytes,
                        :resident_bytes,
                        :resident,
                        :recency,
                        :owner,
                    ),
                    Tuple{
                        String,
                        String,
                        Int64,
                        Int64,
                        Base.RefValue{Int64},
                        Base.Dict{String, Any},
                        Array{String, 1},
                        Task,
                    },
                },
                String,
                WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                Tuple{
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                },
                String,
            },
        )
    end
end
