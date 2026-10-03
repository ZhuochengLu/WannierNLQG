# Generated from candidate-009's valid nonzero VASP PAW-SPN first call.
# See candidate_010_vasp_spn_generation_v1.json for source-line provenance.
const VASP_SPN_RESIDUAL_RESULTS = Bool[]
# Record compilation of an observed VASP PAW spin specialization without executing it.
_record_vasp_spn_residual(signature) = push!(VASP_SPN_RESIDUAL_RESULTS, precompile(signature))
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let WannierNLQGWannierizationExt=@__MODULE__,
            LinearAlgebra=only(
                filter(m -> nameof(m) == :LinearAlgebra, Base.loaded_modules_array()),
            ),
            Serialization=only(
                filter(m -> nameof(m) == :Serialization, Base.loaded_modules_array()),
            )

            _record_vasp_spn_residual(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{
                        (:output_spn_file, :provenance_hdf5, :spin_channel, :execution),
                        Tuple{
                            String,
                            String,
                            Int64,
                            WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                        },
                    },
                    typeof(WannierNLQG.Wannierization.generate_vasp_paw_spn),
                    WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                },
            )
            _record_vasp_spn_residual(
                Tuple{Type{NamedTuple{(:change_error,), T} where T <: Tuple}, Tuple{String}},
            )
            _record_vasp_spn_residual(
                Tuple{
                    Type{
                        NamedTuple{(:point_provider, :normalize_coefficients), T} where T <: Tuple,
                    },
                    Tuple{
                        typeof(
                            WannierNLQGWannierizationExt.RepresentationPreparation.native_vasp_point_provider,
                        ),
                        Bool,
                    },
                },
            )
            _record_vasp_spn_residual(
                Tuple{typeof(Base.literal_pow), typeof(Base.:(^)), Int64, Base.Val{2}},
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Core.memoryref),
                    GenericMemory{:not_atomic, Tuple{Symbol, Any}, Core.AddrSpace{Core}(0x00)},
                },
            )
            _record_vasp_spn_residual(Tuple{Type{UInt8}, Int32})
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Core.kwcall),
                    NamedTuple{
                        (
                            :output_spn_file,
                            :provenance_hdf5,
                            :spin_channel,
                            :oracle_spn_file,
                            :thresholds,
                            :require_oracle,
                            :formatted,
                            :execution,
                            :target_contract,
                        ),
                        Tuple{
                            String,
                            String,
                            Int64,
                            Nothing,
                            WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                            Bool,
                            Bool,
                            WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                            Nothing,
                        },
                    },
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements.generate_vasp_paw_spn),
                    WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._validate_generation_output_paths,
                    ),
                    NamedTuple{(:output, :provenance), Tuple{String, String}},
                    Tuple{Nothing, String, String, String, Nothing, Nothing},
                },
            )
            _record_vasp_spn_residual(Tuple{typeof(Base.iterate), Base.Set{String}})
            _record_vasp_spn_residual(
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
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#122#124"{
                            String,
                            String,
                            Int64,
                            Nothing,
                            WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                            Bool,
                            Bool,
                            WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                            Nothing,
                            WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
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
                            :spin_channel,
                            :oracle_spn_file,
                            :thresholds,
                            :require_oracle,
                            :formatted,
                            :target_contract,
                        ),
                        Tuple{
                            WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                            Int64,
                            Nothing,
                            WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                            Bool,
                            Bool,
                            Nothing,
                        },
                    },
                    Symbol,
                    NamedTuple{(:output, :provenance), Tuple{String, String}},
                    Array{String, 1},
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.task_local_storage),
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#195#201"{
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
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#210#214"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#122#124"{
                                String,
                                String,
                                Int64,
                                Nothing,
                                WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                                Bool,
                                Bool,
                                WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                                Nothing,
                                WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
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
                                :spin_channel,
                                :oracle_spn_file,
                                :thresholds,
                                :require_oracle,
                                :formatted,
                                :target_contract,
                            ),
                            Tuple{
                                WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                                Int64,
                                Nothing,
                                WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                                Bool,
                                Bool,
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
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base._array_for),
                    Type{Tuple{String, String}},
                    Base.HasShape{1},
                    Tuple{Base.OneTo{Int64}},
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    Type{
                        Array{
                            Tuple{Symbol, WannierNLQG.SymmetryFoundation.VASPWavefunctionSource},
                            1,
                        },
                    },
                    UndefInitializer,
                    Tuple{Int64},
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.grow_to!),
                    Array{Tuple{Symbol, WannierNLQG.SymmetryFoundation.VASPWavefunctionSource}, 1},
                    Base.Generator{
                        Base.Iterators.Filter{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#200#206",
                            NTuple{7, Symbol},
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#199#205"{
                            NamedTuple{
                                (
                                    :source,
                                    :spin_channel,
                                    :oracle_spn_file,
                                    :thresholds,
                                    :require_oracle,
                                    :formatted,
                                    :target_contract,
                                ),
                                Tuple{
                                    WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                                    Int64,
                                    Nothing,
                                    WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                                    Bool,
                                    Bool,
                                    Nothing,
                                },
                            },
                        },
                    },
                    Int64,
                },
            )
            _record_vasp_spn_residual(
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
            _record_vasp_spn_residual(
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
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.show),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                    Int64,
                },
            )
            _record_vasp_spn_residual(
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
            _record_vasp_spn_residual(
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
            _record_vasp_spn_residual(
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
            _record_vasp_spn_residual(
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
            _record_vasp_spn_residual(
                Tuple{
                    typeof(WannierNLQG.SymmetryFoundation.with_verified_file_digests),
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#22#27"{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#123#125"{
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
                            String,
                            String,
                            Int64,
                            Nothing,
                            WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                            Bool,
                            Bool,
                            Nothing,
                            WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                        },
                        WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                        String,
                        Array{String, 1},
                        String,
                        WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                    },
                    Array{String, 1},
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.task_local_storage),
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#22#27"{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#123#125"{
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
                            String,
                            String,
                            Int64,
                            Nothing,
                            WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                            Bool,
                            Bool,
                            Nothing,
                            WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                        },
                        WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                        String,
                        Array{String, 1},
                        String,
                        WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                    },
                    Symbol,
                    Base.Dict{String, Tuple{Tuple, String}},
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.mapfoldl_impl),
                    typeof(Base.identity),
                    typeof(Base.min),
                    Base._InitialValue,
                    Base.SubArray{
                        Int64,
                        2,
                        Array{Int64, 2},
                        Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}},
                        false,
                    },
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(
                        WannierNLQGWannierizationExt.RepresentationPreparation.native_vasp_point_provider,
                    ),
                    WannierNLQG.SymmetryFoundation.var"#124#132"{
                        Bool,
                        WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                        Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                        Base.UnitRange{Int64},
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                    },
                    Int64,
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base._array_for),
                    Type{Array{Float64, 1}},
                    Base.HasShape{1},
                    Tuple{Base.OneTo{Int64}},
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    Type{
                        WannierNLQG.SymmetryFoundation.IndexedPlaneWavePoints{
                            V,
                        } where V <:
                                AbstractArray{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                    },
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.SymmetryFoundation.var"#124#132"{
                            Bool,
                            WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                            Base.UnitRange{Int64},
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                        },
                    },
                    Array{Array{Float64, 1}, 1},
                    Array{Array{Float64, 1}, 1},
                    Int64,
                    Int64,
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    Type{WannierNLQG.SymmetryFoundation.NativeWavefunctionData},
                    Symbol,
                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                    Array{Float64, 2},
                    Tuple{Int64, Int64, Int64},
                    Bool,
                    WannierNLQG.SymmetryFoundation.IndexedPlaneWavePoints{
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.SymmetryFoundation.var"#124#132"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                                Base.UnitRange{Int64},
                                Array{Base.Complex{Float64}, 2},
                                WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                            },
                        },
                    },
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.checkbounds),
                    Type{Bool},
                    WannierNLQG.SymmetryFoundation.IndexedPlaneWavePoints{
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.SymmetryFoundation.var"#124#132"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                                Base.UnitRange{Int64},
                                Array{Base.Complex{Float64}, 2},
                                WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                            },
                        },
                    },
                    Int64,
                },
            )
            _record_vasp_spn_residual(Tuple{typeof(Base.length), Base.UnitRange{Int64}})
            _record_vasp_spn_residual(Tuple{typeof(Base.print), Base.IOStream, String})
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.getindex),
                    GenericMemory{:not_atomic, String, Core.AddrSpace{Core}(0x00)},
                    Int64,
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.axes),
                    WannierNLQG.SymmetryFoundation.IndexedPlaneWavePoints{
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.SymmetryFoundation.var"#124#132"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                                Base.UnitRange{Int64},
                                Array{Base.Complex{Float64}, 2},
                                WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                            },
                        },
                    },
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.getindex),
                    WannierNLQG.SymmetryFoundation.IndexedPlaneWavePoints{
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.SymmetryFoundation.var"#124#132"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                                Base.UnitRange{Int64},
                                Array{Base.Complex{Float64}, 2},
                                WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                            },
                        },
                    },
                    Int64,
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.length),
                    WannierNLQG.SymmetryFoundation.IndexedPlaneWavePoints{
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.SymmetryFoundation.var"#124#132"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                                Base.UnitRange{Int64},
                                Array{Base.Complex{Float64}, 2},
                                WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                            },
                        },
                    },
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.Iterators.enumerate),
                    WannierNLQG.SymmetryFoundation.IndexedPlaneWavePoints{
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.SymmetryFoundation.var"#124#132"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                                Base.UnitRange{Int64},
                                Array{Base.Complex{Float64}, 2},
                                WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                            },
                        },
                    },
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        WannierNLQG.SymmetryFoundation.IndexedPlaneWavePoints{
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQG.SymmetryFoundation.var"#124#132"{
                                    Bool,
                                    WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                                    Base.UnitRange{Int64},
                                    Array{Base.Complex{Float64}, 2},
                                    WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                                },
                            },
                        },
                    },
                    Tuple{Int64},
                },
            )
            _record_vasp_spn_residual(
                Tuple{typeof(Base.zeros), Type{Base.Complex{Float64}}, Int64, Int64, Vararg{Int64}},
            )
            _record_vasp_spn_residual(
                Tuple{typeof(Base.zeros), Type{Base.Complex{Float64}}, Tuple{Int64, Int64}},
            )
            _record_vasp_spn_residual(
                Tuple{typeof(Base.axes), Array{Base.Complex{Float64}, 3}, Int64},
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.transpose),
                    Base.SubArray{
                        Base.Complex{Float64},
                        2,
                        Array{Base.Complex{Float64}, 3},
                        Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                        true,
                    },
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.Broadcast.broadcasted),
                    typeof(Base.:(+)),
                    Array{Base.Complex{Float64}, 2},
                    Array{Base.Complex{Float64}, 2},
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.Broadcast.materialize!),
                    Array{Base.Complex{Float64}, 2},
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{2},
                        Nothing,
                        typeof(Base.:(+)),
                        Tuple{Array{Base.Complex{Float64}, 2}, Array{Base.Complex{Float64}, 2}},
                    },
                },
            )
            _record_vasp_spn_residual(Tuple{typeof(Base.trues), Int64})
            _record_vasp_spn_residual(Tuple{typeof(Base.:(>)), Float64, Float64})
            _record_vasp_spn_residual(
                Tuple{typeof(Base.setindex!), Array{Float64, 1}, Float64, Int64},
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        WannierNLQG.SymmetryFoundation.IndexedPlaneWavePoints{
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQG.SymmetryFoundation.var"#124#132"{
                                    Bool,
                                    WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                                    Base.UnitRange{Int64},
                                    Array{Base.Complex{Float64}, 2},
                                    WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                                },
                            },
                        },
                    },
                    Tuple{Int64, Tuple{Base.OneTo{Int64}, Int64}},
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.size),
                    WannierNLQG.SymmetryFoundation.IndexedPlaneWavePoints{
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.SymmetryFoundation.var"#124#132"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                                Base.UnitRange{Int64},
                                Array{Base.Complex{Float64}, 2},
                                WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                            },
                        },
                    },
                },
            )
            _record_vasp_spn_residual(Tuple{typeof(Base.prod), Tuple{Int64}})
            _record_vasp_spn_residual(Tuple{typeof(Base.min), Int64, Int64})
            _record_vasp_spn_residual(Tuple{typeof(Base.string), Int64})
            _record_vasp_spn_residual(Tuple{typeof(Base.:(-)), Int64, UInt64})
            _record_vasp_spn_residual(Tuple{typeof(Base.:(<=)), Int64, UInt64})
            _record_vasp_spn_residual(Tuple{typeof(Base.div), UInt64, Int64})
            _record_vasp_spn_residual(Tuple{typeof(Base.min), Int64, UInt64})
            _record_vasp_spn_residual(Tuple{typeof(Base.:(==)), Char, Char})
            _record_vasp_spn_residual(Tuple{typeof(Base.iszero), Bool})
            _record_vasp_spn_residual(
                Tuple{
                    WannierNLQG.IO.var"#23#29"{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#129#132",
                        Int64,
                        Tuple{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            Array{Base.Complex{Float64}, 3},
                            Array{Float64, 2},
                        },
                    },
                },
            )
            _record_vasp_spn_residual(Tuple{typeof(Base.Filesystem.mkpath), String})
            _record_vasp_spn_residual(Tuple{Base.Colon, Int64, UInt64})
            _record_vasp_spn_residual(Tuple{typeof(Base.iterate), Base.UnitRange{UInt64}})
            _record_vasp_spn_residual(Tuple{typeof(Base.min), UInt64, UInt64})
            _record_vasp_spn_residual(Tuple{typeof(Base.:(<=)), Float64, Float64})
            _record_vasp_spn_residual(Tuple{typeof(Base.repeat), Char, Int64})
            _record_vasp_spn_residual(Tuple{typeof(Base.length), Array{Float64, 1}})
            _record_vasp_spn_residual(Tuple{typeof(Base.transpose), Array{Float64, 1}})
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Base.vcat),
                    LinearAlgebra.Transpose{Float64, Array{Float64, 1}},
                    LinearAlgebra.Transpose{Float64, Array{Float64, 1}},
                },
            )
            _record_vasp_spn_residual(
                Tuple{typeof(Base.getproperty), HDF5.FileCreateProperties, Symbol},
            )
            _record_vasp_spn_residual(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
            _record_vasp_spn_residual(
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64},
            )
            _record_vasp_spn_residual(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
            _record_vasp_spn_residual(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
            _record_vasp_spn_residual(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
            _record_vasp_spn_residual(
                Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol},
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{69, 0}},
                },
            )
            _record_vasp_spn_residual(
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64},
            )
            _record_vasp_spn_residual(
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
                                        Float64,
                                        Bool,
                                        Array{String, 1},
                                        Base.Dict{String, Float64},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                    },
                                    NTuple{4, Int64},
                                    String,
                                },
                            },
                        },
                    },
                },
            )
            _record_vasp_spn_residual(
                Tuple{
                    typeof(Serialization.serialize),
                    Serialization.Serializer{Base.IOStream},
                    Tuple{
                        Nothing,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Bool,
                        Array{String, 1},
                        Base.Dict{String, Float64},
                        Base.Dict{String, String},
                        Base.Dict{String, String},
                    },
                },
            )
        end
    end
end
