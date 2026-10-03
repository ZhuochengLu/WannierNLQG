# Native VASP PAW spin generation signatures from qualified cold calls.
# Signatures only: no wavefunction loading, operator writing, or MPI initialization here.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        false
        _record_early_prepare(
            Tuple{
                Type{NamedTuple{(:point_provider, :normalize_coefficients), T} where T <: Tuple},
                Tuple{
                    typeof(
                        WannierNLQGWannierizationExt.RepresentationPreparation.native_vasp_point_provider,
                    ),
                    Bool,
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.abs), Int64})
        _record_early_prepare(
            Tuple{typeof(Base._similar_shape), Base.StepRange{Int64, Int64}, Base.HasShape{1}},
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#200#206",
                NTuple{7, Symbol},
            },
        )
        false
        false
        _record_early_prepare(
            Tuple{
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#226#228",
                Tuple{String, String, String, Nothing, Nothing},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#225#227",
                Base.Iterators.Filter{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#226#228",
                    Tuple{String, String, String, Nothing, Nothing},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Set{T} where T},
                Base.Generator{
                    Base.Iterators.Filter{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#226#228",
                        Tuple{String, String, String, Nothing, Nothing},
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#225#227",
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.iterate), Base.Set{String}})
        false
        false
        _record_early_prepare(
            Tuple{
                Type{
                    Array{Tuple{Symbol, WannierNLQG.SymmetryFoundation.VASPWavefunctionSource}, 1},
                },
                UndefInitializer,
                Tuple{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.push!),
                Array{Tuple{Symbol, WannierNLQG.SymmetryFoundation.VASPWavefunctionSource}, 1},
                Tuple{Symbol, WannierNLQG.SymmetryFoundation.VASPWavefunctionSource},
            },
        )
        false
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                Tuple{Symbol, WannierNLQG.SymmetryFoundation.VASPWavefunctionSource},
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
                Base.UnitRange{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.print),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                Char,
            },
        )
        false
        false
        _record_early_prepare(
            Tuple{typeof(Base._array_for), Type{Tuple{String, String}}, Base.HasLength, Int64},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Tuple{String, String}, 1},
                Tuple{String, String},
                Base.Generator{
                    Base.ValueIterator{Base.Dict{String, String}},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#25#30",
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
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#26#31"{String},
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.repr),
                Tuple{String, Array{Tuple{String, String}, 1}, Array{Tuple{String, String}, 1}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Tuple{String, Array{Tuple{String, String}, 1}, Array{Tuple{String, String}, 1}},
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##mapfoldl#335",
                Base._InitialValue,
                typeof(Base.mapfoldl),
                Function,
                Function,
                Base.SubArray{
                    Int64,
                    2,
                    Array{Int64, 2},
                    Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}},
                    false,
                },
            },
        )
        _record_early_prepare(
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
        _record_early_prepare(Tuple{typeof(Base.in), Char, Tuple{Char, Char, Char}})
        _record_early_prepare(Tuple{typeof(Base.join), Tuple{Float64, Float64, Float64}, String})
        _record_early_prepare(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Tuple{Float64, Float64, Float64},
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#36#37"{
                    WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    Base.UnitRange{Int64},
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.map),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#36#37"{
                    WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    Base.UnitRange{Int64},
                },
                NTuple{11, Symbol},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.repr),
                Tuple{
                    Tuple{
                        Pair{Symbol, String},
                        Pair{Symbol, String},
                        Pair{Symbol, String},
                        Pair{Symbol, Nothing},
                        Pair{Symbol, Nothing},
                        Pair{Symbol, Tuple{Float64, Float64, Float64}},
                        Pair{Symbol, Base.UnitRange{Int64}},
                        Pair{Symbol, Int64},
                        Pair{Symbol, Bool},
                        Pair{Symbol, Nothing},
                        Pair{Symbol, Bool},
                        Pair{Symbol, Nothing},
                    },
                    Array{Pair{String, String}, 1},
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
                    Tuple{
                        Pair{Symbol, String},
                        Pair{Symbol, String},
                        Pair{Symbol, String},
                        Pair{Symbol, Nothing},
                        Pair{Symbol, Nothing},
                        Pair{Symbol, Tuple{Float64, Float64, Float64}},
                        Pair{Symbol, Base.UnitRange{Int64}},
                        Pair{Symbol, Int64},
                        Pair{Symbol, Bool},
                        Pair{Symbol, Nothing},
                        Pair{Symbol, Bool},
                        Pair{Symbol, Nothing},
                    },
                    Array{Pair{String, String}, 1},
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
                Tuple{
                    Pair{Symbol, String},
                    Pair{Symbol, String},
                    Pair{Symbol, String},
                    Pair{Symbol, Nothing},
                    Pair{Symbol, Nothing},
                    Pair{Symbol, Tuple{Float64, Float64, Float64}},
                    Pair{Symbol, Base.UnitRange{Int64}},
                    Pair{Symbol, Int64},
                    Pair{Symbol, Bool},
                    Pair{Symbol, Nothing},
                    Pair{Symbol, Bool},
                    Pair{Symbol, Nothing},
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
                Pair{Symbol, String},
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
                Pair{Symbol, Nothing},
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
                Pair{Symbol, Tuple{Float64, Float64, Float64}},
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
                Pair{Symbol, Base.UnitRange{Int64}},
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
                Pair{Symbol, Int64},
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
                Pair{Symbol, Bool},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO.cached_preparation_artifact),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#33#35"{
                    WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                },
                String,
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#38#46"{String},
            },
        )
        _record_early_prepare(
            Tuple{
                Base.SummarySize,
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawDataset,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawDataset,
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
                    WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawCubicSpline,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawCubicSpline,
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
                    WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawAtomLayout,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawAtomLayout,
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
                    WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawChannel,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Base.Dict{
                    String,
                    WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawDataset,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Array{Array{Float64, 1}, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Array{WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawCubicSpline, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Array{WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawAtomLayout, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Array{WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawChannel, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO.cached_preparation_artifact),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#39#47"{
                    WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawSystem,
                },
                String,
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#40#48"{String},
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.indexed_iterate), Tuple{Float64, Tuple{String, Int64, Int64}}, Int64},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{Float64, Tuple{String, Int64, Int64}},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#41#49"{
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    String,
                    WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawSystem,
                },
                Base.OneTo{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#41#49"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawSystem,
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.SymmetryFoundation.read_values_at),
                Base.IOStream,
                Type{Base.Complex{Float64}},
                Int64,
                Int64,
            },
        )
        false
        false
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._paw_projector_point),
                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawSystem,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base._array_for),
                Type{Array{Base.Complex{Float64}, 3}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Array{Base.Complex{Float64}, 3}, 1},
                Array{Base.Complex{Float64}, 3},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#41#49"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawSystem,
                    },
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO.cached_preparation_artifact),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#44#52"{
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    Array{Array{Base.Complex{Float64}, 3}, 1},
                    WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawSystem,
                },
                String,
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#45#53"{String},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                LinearAlgebra.Transpose{
                    Base.Complex{Float64},
                    Base.SubArray{
                        Base.Complex{Float64},
                        2,
                        Array{Base.Complex{Float64}, 3},
                        Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                        true,
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                Array{Float64, 2},
                LinearAlgebra.Transpose{
                    Base.Complex{Float64},
                    Base.SubArray{
                        Base.Complex{Float64},
                        2,
                        Array{Base.Complex{Float64}, 3},
                        Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                        true,
                    },
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.trues), Int64})
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._paw_scoped_identity_residual,
                ),
                Array{Base.Complex{Float64}, 2},
                Base.BitArray{1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.repr),
                Tuple{
                    WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                    Array{Pair{String, String}, 1},
                    String,
                    String,
                    WannierNLQG.Wannierization.VASPPAWSPNThresholds,
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
                    WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                    Array{Pair{String, String}, 1},
                    String,
                    String,
                    WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:execution,),
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
                    },
                },
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._vasp_spn_blocks!),
                Array{Base.Complex{Float64}, 4},
                Array{Base.Complex{Float64}, 4},
                Function,
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#128#131"{
                    Array{Base.Complex{Float64}, 4},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#134#135"{
                        Array{Array{Base.Complex{Float64}, 3}, 1},
                        WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawSystem,
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
                    String,
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#127#130"{
                        Array{Base.Complex{Float64}, 4},
                        Array{Base.Complex{Float64}, 4},
                        Tuple{Int64, Int64, Int64},
                    },
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
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#134#135"{
                    Array{Array{Base.Complex{Float64}, 3}, 1},
                    WannierNLQGWannierizationExt.RepresentationPreparation.VASPPawSystem,
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#127#130"{
                    Array{Base.Complex{Float64}, 4},
                    Array{Base.Complex{Float64}, 4},
                    Tuple{Int64, Int64, Int64},
                },
                Int64,
                Tuple{Array{Base.Complex{Float64}, 3}, Array{Base.Complex{Float64}, 3}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO.write_preparation_checkpoint),
                String,
                String,
                Tuple{Array{Base.Complex{Float64}, 3}, Array{Base.Complex{Float64}, 3}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Tuple{Array{Base.Complex{Float64}, 3}, Array{Base.Complex{Float64}, 3}},
            },
        )
        _record_early_prepare(Tuple{Base.Colon, Int64, UInt64})
        _record_early_prepare(Tuple{typeof(Base.iterate), Base.UnitRange{UInt64}})
        _record_early_prepare(Tuple{typeof(Base.min), UInt64, UInt64})
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (
                        :qualification_scope,
                        :parent_generalized_norm_max_absolute,
                        :parent_generalized_norm_worst,
                        :target_generalized_norm_worst,
                        :target_contract_sha256,
                    ),
                    Tuple{
                        Nothing,
                        Float64,
                        Tuple{Int64, Int64, Int64},
                        Tuple{Int64, Int64, Int64},
                        String,
                    },
                },
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._write_vasp_paw_spn_provenance,
                ),
                String,
                WannierNLQG.Wannierization.VASPPAWSPNResult,
                WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Tuple{
                    WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
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
                typeof(
                    WannierNLQGWannierizationExt.WannierizationInternalSupport.atomic_hdf5_write,
                ),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#106#110"{
                    Nothing,
                    Float64,
                    Tuple{Int64, Int64, Int64},
                    Tuple{Int64, Int64, Int64},
                    String,
                    WannierNLQG.Wannierization.VASPPAWSPNResult,
                    WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                    WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                    WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                },
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#108#112"{
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                },
                Base.OneTo{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.reduce),
                Function,
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#108#112"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
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
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#108#112"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
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
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#108#112"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.setindex!), HDF5.File, Array{Float64, 2}, String})
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#109#113"{
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                },
                Base.OneTo{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.reduce),
                Function,
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#109#113"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
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
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#109#113"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                typeof(Base.hcat),
                Base._InitialValue,
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#109#113"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.hcat), Array{Float64, 1}, Array{Float64, 1}})
        _record_early_prepare(Tuple{typeof(Base.getproperty), HDF5.FileCreateProperties, Symbol})
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._vasp_paw_spn_digest_value!),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._vasp_paw_spn_digest_value!),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._vasp_paw_spn_digest_value!),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Float64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._vasp_paw_spn_digest_value!),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Bool,
            },
        )
        false
        false
        false
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._vasp_paw_spn_digest_value!),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{String, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._vasp_paw_spn_digest_value!),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{Float64, 2},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._vasp_paw_spn_digest_value!),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{Int64, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{23, 0}},
            },
        )
        false
        false
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Serialization.serialize),
                WannierNLQG.Serialization.Serializer{Base.IOStream},
                Base.Dict{String, Float64},
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
        _record_early_prepare(Tuple{Type{Array{String, 1}}, UndefInitializer, Tuple{Int64}})
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
