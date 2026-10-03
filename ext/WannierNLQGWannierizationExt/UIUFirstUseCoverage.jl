# Native uIu generation and MMN oracle signatures observed in real cold calls.
# Signatures only: no wavefunction loading, operator writing, or MPI initialization here.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Wannierization.generate_wannier_uiu),
                WannierNLQG.Wannierization.WannierUIUGenerationConfig,
            },
        )
        _record_early_prepare(
            Tuple{Type{NamedTuple{(:repair_truncated,), T} where T <: Tuple}, Tuple{Bool}},
        )
        _record_early_prepare(Tuple{typeof(Base.isempty), Base.CodeUnits{UInt8, String}})
        _record_early_prepare(Tuple{typeof(Base.dataids), Base.CodeUnits{UInt8, String}})
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements.generate_wannier_uiu),
                WannierNLQG.Wannierization.WannierUIUGenerationConfig,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._validate_generation_output_paths,
                ),
                NamedTuple{
                    (:output, :provenance, :scratch, :partial, :checkpoint),
                    NTuple{5, String},
                },
                Array{String, 1},
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._validate_generation_output_paths,
                ),
                NamedTuple{
                    (:output, :provenance, :scratch, :partial, :checkpoint),
                    NTuple{5, String},
                },
                NTuple{4, String},
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.Filesystem.joinpath), String, String, Vararg{AbstractString}},
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#200#206",
                NTuple{17, Symbol},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.SymmetryFoundation.with_verified_file_digests),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#331#334"{
                    WannierNLQG.Wannierization.WannierUIUGenerationConfig,
                    Array{String, 1},
                    NamedTuple{
                        (:output, :provenance, :scratch, :partial, :checkpoint),
                        NTuple{5, String},
                    },
                    String,
                    Nothing,
                },
                Array{String, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#331#334"{
                    WannierNLQG.Wannierization.WannierUIUGenerationConfig,
                    Array{String, 1},
                    NamedTuple{
                        (:output, :provenance, :scratch, :partial, :checkpoint),
                        NTuple{5, String},
                    },
                    String,
                    Nothing,
                },
                Symbol,
                Base.Dict{String, Tuple{Tuple, String}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:oracle_mmn_file,), Tuple{String}},
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._validate_authoritative_mmn_binding,
                ),
                String,
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#195#201"{
                    Nothing,
                    Nothing,
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#333#336",
                    typeof(Base.identity),
                    typeof(Base.identity),
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#332#335"{
                        WannierNLQG.Wannierization.WannierUIUGenerationConfig,
                    },
                    WannierNLQG.Wannierization.WannierUIUGenerationConfig,
                    Symbol,
                    NamedTuple{
                        (:output, :provenance, :scratch, :partial, :checkpoint),
                        NTuple{5, String},
                    },
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
            Tuple{
                typeof(Base.grow_to!),
                Array{Tuple{Symbol, Symbol}, 1},
                Base.Generator{
                    Base.Iterators.Filter{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#200#206",
                        NTuple{17, Symbol},
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#199#205"{
                        WannierNLQG.Wannierization.WannierUIUGenerationConfig,
                    },
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.grow_to!),
                Array{Tuple{Symbol, Any}, 1},
                Base.Generator{
                    Base.Iterators.Filter{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#200#206",
                        NTuple{17, Symbol},
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#199#205"{
                        WannierNLQG.Wannierization.WannierUIUGenerationConfig,
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
                Tuple{Symbol, WannierNLQG.Wannierization.WannierUIUGenerationThresholds},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:execution, :additional_inputs), Tuple{Nothing, Array{String, 1}}},
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._with_qe_operator_artifacts),
                Function,
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                String,
                String,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.SymmetryFoundation.with_verified_file_digests),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#259#263"{
                    Array{String, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#332#335"{
                        WannierNLQG.Wannierization.WannierUIUGenerationConfig,
                    },
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    String,
                    String,
                    Int64,
                    Array{String, 1},
                    String,
                    Nothing,
                },
                Array{String, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#259#263"{
                    Array{String, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#332#335"{
                        WannierNLQG.Wannierization.WannierUIUGenerationConfig,
                    },
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    String,
                    String,
                    Int64,
                    Array{String, 1},
                    String,
                    Nothing,
                },
                Symbol,
                Base.Dict{String, Tuple{Tuple, String}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#247#253"{
                    String,
                    String,
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#332#335"{
                        WannierNLQG.Wannierization.WannierUIUGenerationConfig,
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
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._validate_generation_output_paths,
                ),
                NamedTuple{
                    (:output, :provenance, :scratch, :partial, :checkpoint),
                    NTuple{5, String},
                },
                Tuple{String, String, String, Nothing, Nothing, Nothing},
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:source, :bands, :kpoints, :neighbors),
                    Tuple{Symbol, Int64, Int64, Int64},
                },
                typeof(Base.invokelatest),
                Any,
                Any,
                Vararg{Any},
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##invokelatest#2",
                Base.Pairs{
                    Symbol,
                    Any,
                    NTuple{4, Symbol},
                    NamedTuple{
                        (:source, :bands, :kpoints, :neighbors),
                        Tuple{Symbol, Int64, Int64, Int64},
                    },
                },
                typeof(Base.invokelatest),
                Any,
                Any,
                Vararg{Any},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.pairs),
                NamedTuple{
                    (:source, :bands, :kpoints, :neighbors),
                    Tuple{Symbol, Int64, Int64, Int64},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.haskey),
                Base.Pairs{
                    Symbol,
                    Any,
                    NTuple{4, Symbol},
                    NamedTuple{
                        (:source, :bands, :kpoints, :neighbors),
                        Tuple{Symbol, Int64, Int64, Int64},
                    },
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.IOContext{IO_t} where IO_t <: IO},
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Base.IOStream,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.CoreLogging.showvalue),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.CoreLogging.default_metafmt),
                Base.CoreLogging.LogLevel,
                Vararg{Any, 5},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._uiu_input_fingerprint),
                Base.Dict{String, String},
                WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._uiu_execution_contract),
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
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                NTuple{4, String},
                Char,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._uiu_mmn_parity),
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
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                Type{
                    Base.IteratorsMD.CartesianIndices{
                        N,
                        R,
                    } where {R <: Tuple{Vararg{Base.OrdinalRange{Int64, Int64}, N}}} where N,
                },
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.iterate),
                Base.IteratorsMD.CartesianIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                Array{Base.Complex{Float64}, 2},
                Base.IteratorsMD.CartesianIndex{2},
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.:(-)), Base.Complex{Float64}, Base.Complex{Float64}},
        )
        _record_early_prepare(Tuple{typeof(Base.abs), Base.Complex{Float64}})
        _record_early_prepare(
            Tuple{typeof(Base.getindex), Base.IteratorsMD.CartesianIndex{2}, Int64},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.iterate),
                Base.IteratorsMD.CartesianIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
                Base.IteratorsMD.CartesianIndex{2},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:generalized_norm, :radial_q, :mmn_max, :mmn_rms, :mmn_relative_l2),
                    NTuple{5, Float64},
                },
                typeof(Base.invokelatest),
                Any,
                Any,
                Vararg{Any},
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##invokelatest#2",
                Base.Pairs{
                    Symbol,
                    Float64,
                    NTuple{5, Symbol},
                    NamedTuple{
                        (:generalized_norm, :radial_q, :mmn_max, :mmn_rms, :mmn_relative_l2),
                        NTuple{5, Float64},
                    },
                },
                typeof(Base.invokelatest),
                Any,
                Any,
                Vararg{Any},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.pairs),
                NamedTuple{
                    (:generalized_norm, :radial_q, :mmn_max, :mmn_rms, :mmn_relative_l2),
                    NTuple{5, Float64},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.haskey),
                Base.Pairs{
                    Symbol,
                    Float64,
                    NTuple{5, Symbol},
                    NamedTuple{
                        (:generalized_norm, :radial_q, :mmn_max, :mmn_rms, :mmn_relative_l2),
                        NTuple{5, Float64},
                    },
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.CoreLogging.showvalue),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                Float64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._uiu_validate_checkpoint),
                String,
                String,
                Int64,
                Array{String, 1},
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##open#463",
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(Base.open),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#352#355"{
                    Array{String, 1},
                    Int64,
                    String,
                    String,
                    WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                    NamedTuple{
                        (:output, :provenance, :scratch, :partial, :checkpoint),
                        NTuple{5, String},
                    },
                },
                String,
                Vararg{String},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._uiu_compute_center_blocks),
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
                Int64,
                WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._uiu_block_diagnostics),
                Array{Array{Base.Complex{Float64}, 2}, 2},
                WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._uiu_write_center!),
                Base.IOStream,
                Array{Array{Base.Complex{Float64}, 2}, 2},
                WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._uiu_checkpoint_payload),
                String,
                WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                Int64,
                Array{String, 1},
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:expected_num_bands, :expected_num_kpts, :expected_num_neighbors),
                    Tuple{Int64, Int64, Int64},
                },
                typeof(WannierNLQG.IO.foreach_wannier_uiu_block),
                Function,
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##open#463",
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(Base.open),
                WannierNLQG.IO.var"#103#104"{
                    Int64,
                    Int64,
                    Int64,
                    Bool,
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#353#356"{
                        Base.RefValue{Int64},
                    },
                    String,
                },
                String,
                Vararg{String},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._uiu_cache_diagnostics),
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
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._uiu_provenance_payload),
                WannierNLQG.Wannierization.WannierUIUGenerationConfig,
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
                WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                NamedTuple{
                    (:output, :provenance, :scratch, :partial, :checkpoint),
                    NTuple{5, String},
                },
                String,
                WannierNLQG.Wannierization.WannierUIUParityMetrics,
                Float64,
                Float64,
                Bool,
                Int64,
                Array{String, 1},
                Int64,
                Array{String, 1},
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
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
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
                    Pair{String, Base.Dict{String, Any}},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Base.Dict{String, Float64}},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, String}},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Int64},
                    Pair{String, Array{String, 1}},
                    Pair{String, Int64},
                    Pair{String, Base.Dict{String, Any}},
                    Pair{String, String},
                    Pair{String, Int64},
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
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
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
                    Pair{String, Base.Dict{String, Any}},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Base.Dict{String, Float64}},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, String}},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Int64},
                    Pair{String, Array{String, 1}},
                    Pair{String, Int64},
                    Pair{String, Base.Dict{String, Any}},
                    Pair{String, String},
                    Pair{String, Int64},
                    Pair{String, Array{String, 1}},
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#333#336",
                WannierNLQG.Wannierization.WannierUIUGenerationResult,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO.write_preparation_checkpoint),
                String,
                String,
                NamedTuple{
                    (:output_sha256, :provenance_sha256, :result),
                    Tuple{String, String, WannierNLQG.Wannierization.WannierUIUGenerationResult},
                },
            },
        )
        false
        false
        false
        false
    end
end
