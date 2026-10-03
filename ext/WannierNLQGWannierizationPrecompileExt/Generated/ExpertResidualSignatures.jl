# Generated from three first-call residual traces on candidate-002.
# Do not edit signatures by appearance; see the numbered evidence receipt.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        # generate_qe_paw_spn: residual trace SHA-256 7cbaa51253e482f93b98c3a298a556ee6e6d463d165708ee172b28f7541c4c90
        _record_precompile(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    NamedTuple{names, T} where {T <: Tuple} where names,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_precompile(Tuple{typeof(Base.literal_pow), typeof(Base.:(^)), Int64, Base.Val{2}})
        _record_precompile(
            Tuple{Type{NamedTuple{(:build_missing,), T} where T <: Tuple}, Tuple{Bool}},
        )
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
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
        _record_precompile(
            Tuple{Type{NamedTuple{(:change_error,), T} where T <: Tuple}, Tuple{String}},
        )
        _record_precompile(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{:not_atomic, Tuple{Symbol, Any}, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_precompile(Tuple{Type{UInt8}, Int32})
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
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

        _record_precompile(
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
        _record_precompile(
            Tuple{
                typeof(Base._array_for),
                Type{Tuple{String, String}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_precompile(
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
        _record_precompile(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Base.VersionNumber,
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
                Tuple{Symbol, Int64},
            },
        )
        _record_precompile(
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
        _record_precompile(
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
        _record_precompile(Tuple{typeof(Base.getindex), Base.RefValue{Any}})
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
        _record_precompile(
            Tuple{
                typeof(Base.vcat),
                Array{Float64, 2},
                LinearAlgebra.Transpose{Float64, Array{Float64, 1}},
            },
        )
        _record_precompile(Tuple{Type{Array{Float64, 1}}, Array{Float64, 1}})
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
        _record_precompile(Tuple{typeof(Base.collect), Base.Dict{String, String}})
        _record_precompile(Tuple{typeof(Base.print), Base.IOStream, String})
        _record_precompile(Tuple{Type{Base.KeyError}, String})
        _record_precompile(Tuple{typeof(Base.maximum), Array{Int64, 1}})
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                GenericMemory{:not_atomic, String, Core.AddrSpace{Core}(0x00)},
                Int64,
            },
        )
        _record_precompile(Tuple{typeof(Base.min), Int64, Int64})
        _record_precompile(Tuple{typeof(Base.copy), Base.Dict{String, String}})
        _record_precompile(
            Tuple{typeof(Base.zeros), Type{Base.Complex{Float64}}, Int64, Int64, Vararg{Int64}},
        )
        _record_precompile(Tuple{typeof(Base.join), Array{String, 1}, String})
        _record_precompile(Tuple{typeof(Base.string), Int64})
        _record_precompile(Tuple{typeof(Base.afoldl), typeof(Base.:(*)), Int64, Int64})
        _record_precompile(Tuple{typeof(Base.:(+)), Vararg{Int64, 5}})
        _record_precompile(
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
                            Array{EzXML.Node, 1},
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
        _record_precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        _record_precompile(Tuple{typeof(Base.size), Array{Int64, 2}})
        _record_precompile(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        _record_precompile(Tuple{typeof(Base.collect), Base.UnitRange{Int64}})
        _record_precompile(Tuple{typeof(Base.size), Array{Float64, 2}})
        _record_precompile(Tuple{typeof(Base.isfinite), Float64})
        _record_precompile(Tuple{typeof(Base.length), Array{Int64, 1}})
        _record_precompile(
            Tuple{typeof(Base.reshape), Array{Base.Complex{Float64}, 1}, Int64, Int64},
        )
        _record_precompile(Tuple{typeof(Base.:(-)), Int64, UInt64})
        _record_precompile(Tuple{typeof(Base.:(<=)), Int64, UInt64})
        _record_precompile(Tuple{typeof(Base.div), UInt64, Int64})
        _record_precompile(Tuple{typeof(Base.min), Int64, UInt64})
        _record_precompile(Tuple{typeof(Base.Filesystem.mkpath), String})
        _record_precompile(Tuple{Base.Colon, Int64, UInt64})
        _record_precompile(Tuple{typeof(Base.iterate), Base.UnitRange{UInt64}})
        _record_precompile(Tuple{typeof(Base.min), UInt64, UInt64})
        _record_precompile(Tuple{typeof(Base.:(>)), Float64, Float64})
        _record_precompile(Tuple{typeof(Base.:(<=)), Float64, Float64})
        _record_precompile(Tuple{typeof(Base.split_sign), Int64})
        _record_precompile(Tuple{typeof(Base.indexed_iterate), Tuple{UInt64, Bool}, Int64})
        _record_precompile(Tuple{typeof(Base.indexed_iterate), Tuple{UInt64, Bool}, Int64, Int64})
        _record_precompile(Tuple{Type{NamedTuple{(:pad,), T} where T <: Tuple}, Tuple{Int64}})
        _record_precompile(Tuple{typeof(Base.abs), UInt64})
        _record_precompile(Tuple{typeof(Base.unsigned), UInt64})
        _record_precompile(Tuple{typeof(Base.top_set_bit), UInt64})
        _record_precompile(
            Tuple{
                typeof(Base.vcat),
                LinearAlgebra.Transpose{
                    Float64,
                    Base.SubArray{
                        Float64,
                        1,
                        Array{Float64, 2},
                        Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                        true,
                    },
                },
                LinearAlgebra.Transpose{
                    Float64,
                    Base.SubArray{
                        Float64,
                        1,
                        Array{Float64, 2},
                        Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                        true,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.vcat),
                Array{Float64, 2},
                LinearAlgebra.Transpose{
                    Float64,
                    Base.SubArray{
                        Float64,
                        1,
                        Array{Float64, 2},
                        Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                        true,
                    },
                },
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
        _record_precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#366#372"{Array{Float64, 2}},
                Base.UnitRange{Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.UnitRange{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#366#372"{Array{Float64, 2}},
                },
            },
        )
        _record_precompile(
            Tuple{Type{Pair{A, B} where {B} where A}, String, Array{Array{Float64, 1}, 1}},
        )
        _record_precompile(
            Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, String}},
        )
        _record_precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Array{String, 1}})
        _record_precompile(
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
        _record_precompile(
            Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Float64}},
        )
        _record_precompile(Tuple{typeof(Base.:(+)), Int64, UInt64})
        _record_precompile(Tuple{typeof(Base.write), Base.IOStream, Array{UInt8, 1}})
        # prepare_exact_wannier_operator_bundle: residual trace SHA-256 d0d9d6b2fdfc1ae7d6e307a04819e3027b162926c8c6f35e621750196a85f45c
        _record_precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Float64})
        _record_precompile(
            Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, String}, Int64}, Int64},
        )
        _record_precompile(
            Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, String}, Int64}, Int64, Int64},
        )
        _record_precompile(Tuple{typeof(Base.iterate), Pair{String, String}})
        _record_precompile(Tuple{typeof(Base.iterate), Pair{String, String}, Int64})
        _record_precompile(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64})
        _record_precompile(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64, Int64})
        _record_precompile(
            Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, Bool}, Int64}, Int64},
        )
        _record_precompile(
            Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, Bool}, Int64}, Int64, Int64},
        )
        _record_precompile(Tuple{typeof(Base.iterate), Pair{String, Bool}})
        _record_precompile(Tuple{typeof(Base.iterate), Pair{String, Bool}, Int64})
        _record_precompile(Tuple{typeof(Base.indexed_iterate), Tuple{Bool, Int64}, Int64})
        _record_precompile(Tuple{typeof(Base.indexed_iterate), Tuple{Bool, Int64}, Int64, Int64})
        _record_precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport.prepare_exact_wannier_operator_bundle,
                ),
                WannierNLQG.Wannierization.ExactWannierOperatorBundleConfig,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.OperatorExport.var"#17#20"{
                    WannierNLQG.Wannierization.ExactWannierOperatorBundleConfig,
                    Base.Dict{String, String},
                },
                Symbol,
                Base.Dict{String, Tuple{Tuple, String}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.pairs),
                JSON3.Object{
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.OperatorExport.var"#10#12",
                JSON3.Object{
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Dict{String, String}},
                Base.Generator{
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
                    WannierNLQGWannierizationExt.OperatorExport.var"#10#12",
                },
            },
        )
        _record_precompile(Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}})
        _record_precompile(Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}})
        _record_precompile(
            Tuple{Type{Array{Base.Complex{Float64}, N} where N}, Array{Base.Complex{Float64}, 4}},
        )
        _record_precompile(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 4}, Int64})
        _record_precompile(
            Tuple{Type{Array{Base.Complex{Float64}, N} where N}, Array{Base.Complex{Float64}, 5}},
        )
        _record_precompile(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 5}, Int64})
        _record_precompile(Tuple{typeof(Base.length), Array{Tuple{Int64, Int64, Int64}, 1}})
        _record_precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._exact_bundle_serialized_derivative,
                ),
                Array{Base.Complex{Float64}, 4},
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._exact_bundle_serialized_derivative,
                ),
                Array{Base.Complex{Float64}, 5},
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{typeof(Base.empty), Base.Dict{Any, Any}, Type{String}, Type{String}},
        )
        _record_precompile(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{String, String},
                Base.Generator{
                    NTuple{6, String},
                    WannierNLQGWannierizationExt.OperatorExport.var"#21#23"{
                        Base.Dict{String, String},
                    },
                },
                Int64,
            },
        )
        _record_precompile(Tuple{typeof(Base.keys), Base.Dict{String, String}})
        _record_precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.OperatorExport.var"#22#24"{
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                },
                Base.KeySet{String, Base.Dict{String, String}},
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Dict{K, V} where {V} where K},
                Base.Generator{
                    Base.KeySet{String, Base.Dict{String, String}},
                    WannierNLQGWannierizationExt.OperatorExport.var"#22#24"{
                        Base.Dict{String, String},
                        Base.Dict{String, String},
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{String, Any},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
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
        _record_precompile(
            Tuple{
                Type{Pair{A, B} where {B} where A},
                String,
                Base.Dict{String, Base.Dict{String, Any}},
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Dict{K, V} where {V} where K},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, Base.Dict{String, Any}}},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, Any}},
                    Vararg{Pair{String, String}, 9},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :profile,
                        :overwrite,
                        :paired_tb_sha256,
                        :provenance,
                        :symmetry,
                        :geometry,
                        :diagnostics,
                    ),
                    Tuple{Symbol, Bool, String, Vararg{Base.Dict{String, Any}, 4}},
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
        _record_precompile(
            Tuple{
                typeof(Base.in),
                WannierNLQG.Core.RealSpaceOperatorKind,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        _record_precompile(Tuple{typeof(Base.real), Base.Complex{Float64}})
        _record_precompile(Tuple{typeof(Base.imag), Base.Complex{Float64}})
        _record_precompile(Tuple{typeof(Base.abs), Float64})
        _record_precompile(Tuple{typeof(Base.:(==)), Bool, Bool})
        _record_precompile(
            Tuple{
                typeof(Base._all),
                Base.Fix2{typeof(Base.:(>)), Int64},
                Array{Int64, 1},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{typeof(Base.iterate), Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
        )
        _record_precompile(Tuple{typeof(Base.length), Array{Base.Complex{Float64}, 1}})
        _record_precompile(
            Tuple{typeof(Base.iterate), Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}, Int64},
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGOperatorBundleExt._component_values),
                WannierNLQG.Core.RealSpaceOperator{5},
                Tuple{Int8, Int8},
            },
        )
        _record_precompile(Tuple{typeof(Base.haskey), Base.Dict{String, Any}, Symbol})
        _record_precompile(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
        _record_precompile(
            Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Any}},
        )
        _record_precompile(Tuple{typeof(Base.in), String, Tuple{String, String}})
        _record_precompile(Tuple{typeof(Base.in), String, NTuple{4, String}})
        _record_precompile(Tuple{typeof(Base.in), String, NTuple{5, String}})
        _record_precompile(Tuple{typeof(Base.keys), Base.Dict{String, Any}})
        _record_precompile(Tuple{typeof(Base.collect), Base.KeySet{String, Base.Dict{String, Any}}})
        _record_precompile(
            Tuple{typeof(Base.Broadcast.broadcasted), Type{String}, Array{String, 1}},
        )
        _record_precompile(
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
        _record_precompile(Tuple{Type{Base.Set{T} where T}, Array{String, 1}})
        _record_precompile(Tuple{typeof(Base.:(==)), Base.Set{String}, Base.Set{String}})
        _record_precompile(Tuple{typeof(Base.get), Base.Dict{String, Any}, String, String})
        _record_precompile(
            Tuple{typeof(Base.length), Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
        )
        _record_precompile(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(WannierNLQG.Core.real_space_operator_name),
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        _record_precompile(
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
        _record_precompile(Tuple{Type{UInt8}, WannierNLQG.Core.RealSpaceOperatorKind})
        _record_precompile(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{178, 0}},
            },
        )
        _record_precompile(Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol})
        _record_precompile(Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}})
        _record_precompile(Tuple{typeof(Base.size), Array{Int64, 2}, Int64})
        _record_precompile(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        _record_precompile(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        _record_precompile(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
        _record_precompile(Tuple{Type{Array{Int8, N} where N}, UndefInitializer, Int64, Int64})
        _record_precompile(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64})
        _record_precompile(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64, Int64})
        _record_precompile(Tuple{typeof(Base.length), Array{UInt8, 1}})
        _record_precompile(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
        _record_precompile(Tuple{typeof(Base.getindex), Array{UInt64, 1}, Int64})
        _record_precompile(Tuple{typeof(Base.:(==)), UInt64, UInt64})
        _record_precompile(Tuple{Type{UInt8}, UInt8})
        _record_precompile(Tuple{typeof(Base.:(==)), Array{UInt64, 1}, Array{UInt64, 1}})
        _record_precompile(
            Tuple{
                Type{WannierNLQG.IO.OperatorBundleManifest},
                String,
                Symbol,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                Int64,
                Array{Float64, 2},
                Array{Int64, 2},
                Array{Int64, 1},
                Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                Int64,
                String,
                String,
                String,
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Symbol,
                Bool,
                Bool,
                Tuple{Int64, Int64, Int64},
                Float64,
                Int64,
                String,
                String,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                Bool,
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
                Nothing,
                Nothing,
                Bool,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
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
                Bool,
                Bool,
                Bool,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Nothing,
                String,
                String,
                String,
                String,
                Base.Dict{String, Any},
                String,
                String,
                String,
                Bool,
                String,
                String,
                Bool,
                String,
                String,
                String,
                String,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                String,
                Array{String, 1},
                String,
                String,
                String,
                String,
                String,
                Nothing,
                Nothing,
            },
        )
        _record_precompile(
            Tuple{typeof(Base.getproperty), WannierNLQG.Core.RealSpaceOperator{3}, Symbol},
        )
        _record_precompile(
            Tuple{typeof(Base.getproperty), WannierNLQG.Core.RealSpaceOperator{4}, Symbol},
        )
        _record_precompile(
            Tuple{typeof(Base.getproperty), WannierNLQG.Core.RealSpaceOperator{5}, Symbol},
        )
        _record_precompile(
            Tuple{
                typeof(Base.:(==)),
                Array{Base.Complex{Float64}, 5},
                Array{Base.Complex{Float64}, 5},
            },
        )
        if WannierNLQGSymmetrizationExt !== nothing && WannierNLQGSymmetryFoundationExt !== nothing
            # symmetrize_existing_wannier_model: residual trace SHA-256 d75338ef34ffbffb18cbd3f63a7562944ed4a54668304cc5a67de99dd16f36e8
            _record_precompile(Tuple{typeof(Base.:(==)), Char, Char})
            _record_precompile(Tuple{typeof(Base.iszero), Bool})
            _record_precompile(Tuple{typeof(Base.:(>)), Int64})
            _record_precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Bool})
            _record_precompile(
                Tuple{
                    typeof(WannierNLQGSymmetrizationExt.symmetrize_existing_wannier_model),
                    WannierNLQG.Symmetrization.GaugeAwareSymmetrizationConfig,
                },
            )
            _record_precompile(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGSymmetrizationExt.var"#190#197",
                    Tuple{Symbol, Symbol},
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Base.collect),
                    Base.Generator{
                        Tuple{Symbol, Symbol},
                        WannierNLQGSymmetrizationExt.var"#190#197",
                    },
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        WannierNLQG.Symmetrization.GaugeAwareThresholdEvent,
                        Core.AddrSpace{Core}(0x00),
                    },
                },
            )
            _record_precompile(
                Tuple{
                    typeof(WannierNLQGSymmetryFoundationExt.configure_band_qualification_window!),
                    WannierNLQG.SymmetryFoundation.BandRepresentation,
                    Nothing,
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{
                        (
                            :absolute_tolerance,
                            :oracle_excess_tolerance,
                            :oracle_hdf5_file,
                            :require_oracle,
                        ),
                        Tuple{Float64, Float64, Nothing, Bool},
                    },
                    typeof(WannierNLQG.SymmetryFoundation.validate_band_representation),
                    WannierNLQG.SymmetryFoundation.BandRepresentation,
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{
                        (
                            :absolute_tolerance,
                            :oracle_excess_tolerance,
                            :oracle_hdf5_file,
                            :require_oracle,
                        ),
                        Tuple{Float64, Float64, Nothing, Bool},
                    },
                    typeof(WannierNLQGSymmetryFoundationExt.validate_band_representation),
                    WannierNLQG.SymmetryFoundation.BandRepresentation,
                },
            )
            _record_precompile(Tuple{typeof(Base.maximum), NTuple{4, Float64}})
            _record_precompile(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{
                        (:validation, :overwrite),
                        Tuple{WannierNLQGSymmetryFoundationExt.BandRepresentationValidation, Bool},
                    },
                    typeof(WannierNLQG.SymmetryFoundation.write_band_representation_hdf5),
                    String,
                    WannierNLQG.SymmetryFoundation.BandRepresentation,
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{
                        (:validation, :overwrite),
                        Tuple{WannierNLQGSymmetryFoundationExt.BandRepresentationValidation, Bool},
                    },
                    typeof(WannierNLQGSymmetryFoundationExt.write_band_representation_hdf5),
                    String,
                    WannierNLQG.SymmetryFoundation.BandRepresentation,
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Base.hasproperty),
                    WannierNLQGSymmetryFoundationExt.BandRepresentationValidation,
                    Symbol,
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{(:overwrite,), Tuple{Bool}},
                    typeof(WannierNLQGSymmetryFoundationExt.write_band_representation_summary),
                    String,
                    WannierNLQG.SymmetryFoundation.BandRepresentation,
                    WannierNLQGSymmetryFoundationExt.BandRepresentationValidation,
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Array{Int64, 1}},
                        Pair{String, Array{Float64, 1}},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Nothing},
                        Pair{String, Nothing},
                        Pair{String, Array{String, 1}},
                    },
                    Int64,
                },
            )
            _record_precompile(Tuple{typeof(JSON3.pretty), Base.IOStream, Base.Dict{String, Any}})
            _record_precompile(
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
            _record_precompile(
                Tuple{
                    typeof(Base.length),
                    JSON3.Array{Union{}, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    NTuple{5, Int64},
                    Char,
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Base.getproperty),
                    WannierNLQGSymmetryFoundationExt.BandRepresentationProductTable,
                    Symbol,
                },
            )
            _record_precompile(Tuple{typeof(Base.view), Array{Float64, 2}, Int64, Function})
            _record_precompile(
                Tuple{
                    typeof(LinearAlgebra.dot),
                    Base.SubArray{
                        Float64,
                        1,
                        Array{Float64, 2},
                        Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                        true,
                    },
                    Base.SubArray{
                        Int64,
                        1,
                        Array{Int64, 3},
                        Tuple{Base.Slice{Base.OneTo{Int64}}, Int64, Int64},
                        true,
                    },
                },
            )
            _record_precompile(Tuple{typeof(Base.:(*)), Int64, Base.Complex{Float64}})
            _record_precompile(
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
            _record_precompile(
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
            _record_precompile(Tuple{typeof(LinearAlgebra.opnorm), Array{Base.Complex{Float64}, 2}})
            _record_precompile(
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
            _record_precompile(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
            _record_precompile(
                Tuple{
                    typeof(Base.join),
                    Tuple{Int64, Bool, Int64, Int64, Int64, Int64, Int64, Vararg{Float64, 4}},
                    Char,
                },
            )
            _record_precompile(
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
            _record_precompile(Tuple{typeof(Base.setindex!), Array{Float64, 1}, Float64, Int64})
            _record_precompile(
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
            _record_precompile(Tuple{typeof(Base.argmax), Array{Float64, 1}})
            _record_precompile(
                Tuple{
                    typeof(Base.getindex),
                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                    Int64,
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Base.getproperty),
                    NamedTuple{
                        (
                            :operation,
                            :antiunitary,
                            :source,
                            :target,
                            :block_label,
                            :first_band,
                            :last_band,
                            :closure_opnorm,
                        ),
                        Tuple{Int64, Bool, Int64, Int64, Int64, Int64, Int64, Float64},
                    },
                    Symbol,
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{
                        (:operation, :kpoint, :band_block, :context),
                        Tuple{Int64, Int64, Int64, String},
                    },
                    typeof(WannierNLQGSymmetrizationExt._record_gauge_aware_threshold!),
                    Array{WannierNLQG.Symmetrization.GaugeAwareThresholdEvent, 1},
                    Array{String, 1},
                    Symbol,
                    String,
                    Float64,
                    Float64,
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Array{Base.SubString{String}, 1},
                    Char,
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Printf.format),
                    Base.IOStream,
                    Printf.Format{
                        Base.CodeUnits{UInt8, String},
                        Tuple{
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                        },
                    },
                    Int64,
                    Int64,
                    Vararg{Any},
                },
            )
            _record_precompile(
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
            _record_precompile(
                Tuple{
                    typeof(Printf.format),
                    Array{UInt8, 1},
                    Int64,
                    Printf.Format{
                        Base.CodeUnits{UInt8, String},
                        Tuple{
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                        },
                    },
                    Int64,
                    Vararg{Any},
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Printf.fmt),
                    Array{UInt8, 1},
                    Int64,
                    Tuple{Int64, Int64, Int64, Int64, Int64, Float64, Float64},
                    Int64,
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                },
            )
            _record_precompile(
                Tuple{
                    Type{
                        Dates.DateFormat{
                            :var"yyyy-mm-ddTHH:MM:SS",
                            Tuple{
                                Dates.DatePart{reinterpret(Char, UInt32(0x79000000))},
                                Dates.Delim{Char, 1},
                                Dates.DatePart{reinterpret(Char, UInt32(0x6d000000))},
                                Dates.Delim{Char, 1},
                                Dates.DatePart{reinterpret(Char, UInt32(0x64000000))},
                                Dates.Delim{Char, 1},
                                Dates.DatePart{reinterpret(Char, UInt32(0x48000000))},
                                Dates.Delim{Char, 1},
                                Dates.DatePart{reinterpret(Char, UInt32(0x4d000000))},
                                Dates.Delim{Char, 1},
                                Dates.DatePart{reinterpret(Char, UInt32(0x53000000))},
                            },
                        },
                    },
                    Tuple{
                        Dates.DatePart{reinterpret(Char, UInt32(0x79000000))},
                        Dates.Delim{Char, 1},
                        Dates.DatePart{reinterpret(Char, UInt32(0x6d000000))},
                        Dates.Delim{Char, 1},
                        Dates.DatePart{reinterpret(Char, UInt32(0x64000000))},
                        Dates.Delim{Char, 1},
                        Dates.DatePart{reinterpret(Char, UInt32(0x48000000))},
                        Dates.Delim{Char, 1},
                        Dates.DatePart{reinterpret(Char, UInt32(0x4d000000))},
                        Dates.Delim{Char, 1},
                        Dates.DatePart{reinterpret(Char, UInt32(0x53000000))},
                    },
                    Dates.DateLocale,
                },
            )
            _record_precompile(
                Tuple{
                    Type{NamedTuple{(:read, :write, :append, :truncate), T} where T <: Tuple},
                    Tuple{Bool, Bool, Nothing, Nothing},
                },
            )
            _record_precompile(Tuple{Dates.var"##s53#31", Vararg{Any, 5}})
            _record_precompile(
                Tuple{
                    typeof(Dates.format),
                    Dates.DateTime,
                    Dates.DateFormat{
                        :var"yyyy-mm-ddTHH:MM:SS",
                        Tuple{
                            Dates.DatePart{reinterpret(Char, UInt32(0x79000000))},
                            Dates.Delim{Char, 1},
                            Dates.DatePart{reinterpret(Char, UInt32(0x6d000000))},
                            Dates.Delim{Char, 1},
                            Dates.DatePart{reinterpret(Char, UInt32(0x64000000))},
                            Dates.Delim{Char, 1},
                            Dates.DatePart{reinterpret(Char, UInt32(0x48000000))},
                            Dates.Delim{Char, 1},
                            Dates.DatePart{reinterpret(Char, UInt32(0x4d000000))},
                            Dates.Delim{Char, 1},
                            Dates.DatePart{reinterpret(Char, UInt32(0x53000000))},
                        },
                    },
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Base.print),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    WannierNLQG.Symmetrization.GaugeAwareSymmetrizationStatus,
                },
            )
            _record_precompile(
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
            _record_precompile(
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
            _record_precompile(Tuple{typeof(Base.join), Tuple{String, String}, Char})
            _record_precompile(
                Tuple{
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Tuple{String, String},
                    Char,
                },
            )
            _record_precompile(Tuple{typeof(Base.print), Base.AnnotatedIOBuffer, Symbol})
            _record_precompile(Tuple{typeof(Base.print), Base.AnnotatedIOBuffer, String})
            _record_precompile(
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
                    Type{String},
                    Tuple{Tuple{Symbol, Symbol}},
                },
            )
            _record_precompile(
                Tuple{Type{Pair{A, B} where {B} where A}, String, Tuple{String, String}},
            )
            _record_precompile(
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
            _record_precompile(
                Tuple{
                    typeof(Base.similar),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        typeof(WannierNLQGSymmetrizationExt._gauge_aware_threshold_payload),
                        Tuple{
                            Base.Broadcast.Extruded{
                                Array{WannierNLQG.Symmetrization.GaugeAwareThresholdEvent, 1},
                                Tuple{Bool},
                                Tuple{Int64},
                            },
                        },
                    },
                    Type{Base.Dict{String, Any}},
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Base.setindex!),
                    Array{Base.Dict{String, Any}, 1},
                    Base.Dict{String, Any},
                    Int64,
                },
            )
            _record_precompile(
                Tuple{
                    typeof(Base.Broadcast.copyto_nonleaf!),
                    Array{Base.Dict{String, Any}, 1},
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        typeof(WannierNLQGSymmetrizationExt._gauge_aware_threshold_payload),
                        Tuple{
                            Base.Broadcast.Extruded{
                                Array{WannierNLQG.Symmetrization.GaugeAwareThresholdEvent, 1},
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
            _record_precompile(
                Tuple{Type{Pair{A, B} where {B} where A}, String, Array{Base.Dict{String, Any}, 1}},
            )
            _record_precompile(
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
            _record_precompile(
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
            _record_precompile(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{(:overwrite,), Tuple{Bool}},
                    typeof(WannierNLQGSymmetrizationExt._write_gauge_aware_json),
                    String,
                    Base.Dict{String, Any},
                },
            )
            _record_precompile(
                Tuple{typeof(JSON3.defaultminimum), Array{Base.Dict{String, Any}, 1}},
            )
            _record_precompile(Tuple{typeof(JSON3.defaultminimum), Tuple{String, String}})
            _record_precompile(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Array{Base.Dict{String, Any}, 1},
                },
            )
            _record_precompile(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Tuple{String, String},
                },
            )
        end
    end
end
