# Native uHu, sHu, and sIu generation signatures observed in real cold calls.
# Signatures only: no wavefunction loading, operator writing, or MPI initialization here.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Wannierization.generate_wannier_shu),
                WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
            },
        )
        _record_early_prepare(
            Tuple{
                Type{
                    NamedTuple{(:center, :neighbor, :endpoint, :kpoint, :rank), T} where T <: Tuple,
                },
                Tuple{Int64, Int64, String, Int64, Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{NamedTuple{(:center, :neighbor, :right), T} where T <: Tuple},
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.indexed_iterate), Tuple{Base.Missing, Base.Missing}, Int64},
        )
        _record_early_prepare(
            Tuple{typeof(Base.indexed_iterate), Tuple{Base.Missing, Base.Missing}, Int64, Int64},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                Base.BottomRF{typeof(Base.Checked.checked_mul)},
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Array{Base.Complex{Float64}, 2},
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.isequal), Symbol, Symbol})
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                Base.Generator{Tuple{Base.Colon}, typeof(Base.identity)},
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{Tuple{Base.Colon}, typeof(Base.identity)},
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{Tuple{Base.Colon}, typeof(Base.identity)},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{Base.BottomRF{typeof(Base.mul_prod)}, Tuple{Base.Colon}},
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{Base.BottomRF{typeof(Base.mul_prod)}, Tuple{Base.Colon}},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{WannierNLQGWannierizationExt.OperatorExport.var"#65#67", Nothing},
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#200#206",
                NTuple{18, Symbol},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport.generate_wannier_shu),
                WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.any), Function, Tuple{String, String}})
        _record_early_prepare(
            Tuple{
                typeof(Base._any),
                WannierNLQGWannierizationExt.OperatorExport.var"#65#67",
                Tuple{String, String},
                Base.Colon,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._validate_generation_output_paths,
                ),
                NamedTuple{(:output, :provenance), Tuple{String, String}},
                Tuple{String, String, String, String, Vararg{Nothing, 4}},
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#195#201"{
                    WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                    WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                    WannierNLQGWannierizationExt.OperatorExport.var"#70#72",
                    typeof(Base.identity),
                    typeof(Base.identity),
                    WannierNLQGWannierizationExt.OperatorExport.var"#69#71"{
                        WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
                        Symbol,
                    },
                    WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
                    Symbol,
                    NamedTuple{
                        (:output, :provenance, :recover_publication),
                        Tuple{String, String, Bool},
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
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#195#201"{
                    WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                    WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                    WannierNLQGWannierizationExt.OperatorExport.var"#70#72",
                    typeof(Base.identity),
                    typeof(Base.identity),
                    WannierNLQGWannierizationExt.OperatorExport.var"#69#71"{
                        WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
                        Symbol,
                    },
                    WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
                    Symbol,
                    NamedTuple{
                        (:output, :provenance, :recover_publication),
                        Tuple{String, String, Bool},
                    },
                    Array{String, 1},
                    Array{String, 1},
                    Array{String, 1},
                    String,
                    Array{String, 1},
                },
            },
        )
        _record_early_prepare(
            Tuple{Type{Array{Tuple{Symbol, Symbol}, 1}}, UndefInitializer, Tuple{Int64}},
        )
        _record_early_prepare(
            Tuple{typeof(Base.push!), Array{Tuple{Symbol, Symbol}, 1}, Tuple{Symbol, Symbol}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.grow_to!),
                Array{Tuple{Symbol, Symbol}, 1},
                Base.Generator{
                    Base.Iterators.Filter{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#200#206",
                        NTuple{18, Symbol},
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#199#205"{
                        WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
                    },
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.push_widen),
                Array{Tuple{Symbol, Symbol}, 1},
                Tuple{Symbol, WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.grow_to!),
                Array{Tuple{Symbol, Any}, 1},
                Base.Generator{
                    Base.Iterators.Filter{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#200#206",
                        NTuple{18, Symbol},
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#199#205"{
                        WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
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
                Tuple{Symbol, Symbol},
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
                Tuple{Symbol, WannierNLQG.Wannierization.NativeDFTHamiltonian},
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
                Tuple{Symbol, Float64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.SymmetryFoundation.with_verified_file_digests),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#259#263"{
                    Array{String, 1},
                    WannierNLQGWannierizationExt.OperatorExport.var"#69#71"{
                        WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
                        Symbol,
                    },
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    String,
                    String,
                    Int64,
                    Array{String, 1},
                    String,
                    WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                },
                Array{String, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#259#263"{
                    Array{String, 1},
                    WannierNLQGWannierizationExt.OperatorExport.var"#69#71"{
                        WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
                        Symbol,
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
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#247#253"{
                    String,
                    String,
                    WannierNLQGWannierizationExt.OperatorExport.var"#69#71"{
                        WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
                        Symbol,
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
        false
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Tuple{Int64, Int64, Float64},
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._generation_gauge_source),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                Nothing,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 3}})
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:construction_policy,), Tuple{Symbol}},
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._generation_band_gauge_contract,
                ),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                WannierNLQG.Wannierization.NativeDFTHamiltonian,
                Nothing,
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._validate_hamiltonian_authority_frame_binding,
                ),
                WannierNLQGWannierizationExt.OperatorExport.AuthoritativeBandHamiltonian,
                WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport._generation_spn),
                WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
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
                WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
            },
        )
        _record_early_prepare(Tuple{Base.var"##s128#279", Vararg{Any, 5}})
        _record_early_prepare(
            Tuple{Type{NamedTuple{(:verify_spn,), T} where T <: Tuple}, Tuple{Bool}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (
                        :expected_num_bands,
                        :expected_num_kpoints,
                        :target_authority,
                        :gauge_artifact_sha256,
                        :band_frame_transform_sha256,
                        :band_frame_contract_sha256,
                    ),
                    Tuple{
                        Int64,
                        Int64,
                        WannierNLQG.Wannierization.NativeDFTHamiltonian,
                        Nothing,
                        String,
                        String,
                    },
                },
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._read_and_validate_spn_provenance,
                ),
                String,
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                NamedTuple{
                    (
                        :expected_num_bands,
                        :expected_num_kpoints,
                        :target_authority,
                        :gauge_artifact_sha256,
                        :band_frame_transform_sha256,
                        :band_frame_contract_sha256,
                    ),
                    Tuple{
                        Int64,
                        Int64,
                        WannierNLQG.Wannierization.NativeDFTHamiltonian,
                        Nothing,
                        String,
                        String,
                    },
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.setindex!), Base.RefValue{Any}, Nothing})
        _record_early_prepare(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#914#917"{
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._read_and_validate_spn_provenance_uncached,
                    ),
                    Base.Pairs{
                        Symbol,
                        Any,
                        NTuple{6, Symbol},
                        NamedTuple{
                            (
                                :expected_num_bands,
                                :expected_num_kpoints,
                                :target_authority,
                                :gauge_artifact_sha256,
                                :band_frame_transform_sha256,
                                :band_frame_contract_sha256,
                            ),
                            Tuple{
                                Int64,
                                Int64,
                                WannierNLQG.Wannierization.NativeDFTHamiltonian,
                                Nothing,
                                String,
                                String,
                            },
                        },
                    },
                    String,
                    String,
                    Tuple{
                        Tuple{UInt64, UInt64, Int64, Float64, Float64},
                        Tuple{UInt64, UInt64, Int64, Float64, Float64},
                    },
                    Tuple{String, String},
                },
                Symbol,
                Base.Dict{String, Tuple{Tuple, String}},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#902#907",
                Base.Dict{String, Any},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Dict{String, String}},
                Base.Generator{
                    Base.Dict{String, Any},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#902#907",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#903#908",
                Base.Dict{String, Any},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Dict{String, String}},
                Base.Generator{
                    Base.Dict{String, Any},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#903#908",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#904#909",
                Array{Any, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.reduce),
                Function,
                Base.Generator{
                    Array{Any, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#904#909",
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
                    Array{Any, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#904#909",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#904#909",
                    Base.BottomRF{typeof(Base.vcat)},
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                typeof(Base.vcat),
                Base._InitialValue,
                Base.Generator{
                    Array{Any, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#904#909",
                },
            },
        )
        _record_early_prepare(
            Tuple{WannierNLQGWannierizationExt.PAWMatrixElements.var"#904#909", Array{Any, 1}},
        )
        _record_early_prepare(Tuple{typeof(Base.setindex!), Array{Float64, 1}, Float64, Int64})
        _record_early_prepare(
            Tuple{
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#904#909",
                    Base.BottomRF{typeof(Base.vcat)},
                },
                LinearAlgebra.Transpose{Float64, Array{Float64, 1}},
                Array{Any, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#904#909",
                    Base.BottomRF{typeof(Base.vcat)},
                },
                Array{Float64, 2},
                Array{Any, 1},
            },
        )
        false
        _record_early_prepare(Tuple{Type{Pair{A, B} where {B} where A}, String, Array{Any, 1}})
        _record_early_prepare(Tuple{typeof(PAWMatrixElements.JSON3.defaultminimum), Array{Any, 1}})
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.write),
                PAWMatrixElements.JSON3.StructTypes.ArrayType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Array{Any, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#905#910",
                Base.Dict{String, Any},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Dict{String, Any}},
                Base.Generator{
                    Base.Dict{String, Any},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#905#910",
                },
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.Broadcast.broadcasted), Type{String}, Array{Any, 1}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{String},
                    Tuple{Array{Any, 1}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.similar),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Tuple{Base.OneTo{Int64}},
                    Type{String},
                    Tuple{Base.Broadcast.Extruded{Array{Any, 1}, Tuple{Bool}, Tuple{Int64}}},
                },
                Type{String},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.copyto_nonleaf!),
                Array{String, 1},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Tuple{Base.OneTo{Int64}},
                    Type{String},
                    Tuple{Base.Broadcast.Extruded{Array{Any, 1}, Tuple{Bool}, Tuple{Int64}}},
                },
                Base.OneTo{Int64},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.map),
                Function,
                Tuple{String, String},
                Tuple{
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                },
                Tuple{String, String},
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#915#918",
                String,
                Tuple{UInt64, UInt64, Int64, Float64, Float64},
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :schema,
                        :schema_version,
                        :source_code,
                        :passed,
                        :source_band_gauge,
                        :target_band_gauge,
                        :transform_sha256,
                        :contract_sha256,
                        :frame_contract,
                        :rotation_sha256,
                        :num_bands,
                        :num_kpoints,
                        :num_kpts,
                        :physical_metric,
                        :spinor,
                        :kpoints_fractional,
                        :payload_sha256,
                        :input_sha256,
                        :artifacts,
                        :diagnostics,
                        :status,
                        :spn_sha256,
                        :provenance_sha256,
                        :qualification_target_band_gauge,
                        :qualification_transform_sha256,
                        :qualification_contract_sha256,
                        :qualification_rotation_sha256,
                        :gauge_artifact_sha256,
                    ),
                    Tuple{
                        String,
                        String,
                        Symbol,
                        Bool,
                        String,
                        String,
                        String,
                        String,
                        Base.Dict{String, Any},
                        String,
                        Int64,
                        Int64,
                        Int64,
                        String,
                        Bool,
                        Array{Float64, 2},
                        String,
                        Base.Dict{String, String},
                        Base.Dict{String, String},
                        Array{String, 1},
                        Vararg{String, 8},
                    },
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.deepcopy_internal), Base.Dict{String, String}, Base.IdDict{Any, Any}},
        )
        _record_early_prepare(
            Tuple{typeof(Base.deepcopy_internal), Array{String, 1}, Base.IdDict{Any, Any}},
        )
        _record_early_prepare(
            Tuple{
                Type{GenericMemory{:not_atomic, String, Base.Core.AddrSpace{Base.Core}(0x00)}},
                UndefInitializer,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.setindex!),
                Base.RefValue{Any},
                NamedTuple{
                    (:key, :identities, :digests, :record),
                    Tuple{
                        Tuple{Tuple{String, String}, String},
                        Tuple{
                            Tuple{UInt64, UInt64, Int64, Float64, Float64},
                            Tuple{UInt64, UInt64, Int64, Float64, Float64},
                        },
                        Tuple{String, String},
                        NamedTuple{
                            (
                                :schema,
                                :schema_version,
                                :source_code,
                                :passed,
                                :source_band_gauge,
                                :target_band_gauge,
                                :transform_sha256,
                                :contract_sha256,
                                :frame_contract,
                                :rotation_sha256,
                                :num_bands,
                                :num_kpoints,
                                :num_kpts,
                                :physical_metric,
                                :spinor,
                                :kpoints_fractional,
                                :payload_sha256,
                                :input_sha256,
                                :artifacts,
                                :diagnostics,
                                :status,
                                :spn_sha256,
                                :provenance_sha256,
                                :qualification_target_band_gauge,
                                :qualification_transform_sha256,
                                :qualification_contract_sha256,
                                :qualification_rotation_sha256,
                                :gauge_artifact_sha256,
                            ),
                            Tuple{
                                String,
                                String,
                                Symbol,
                                Bool,
                                String,
                                String,
                                String,
                                String,
                                Base.Dict{String, Any},
                                String,
                                Int64,
                                Int64,
                                Int64,
                                String,
                                Bool,
                                Array{Float64, 2},
                                String,
                                Base.Dict{String, String},
                                Base.Dict{String, String},
                                Array{String, 1},
                                Vararg{String, 8},
                            },
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._validate_generation_spn_provenance,
                ),
                NamedTuple{
                    (
                        :schema,
                        :schema_version,
                        :source_code,
                        :passed,
                        :source_band_gauge,
                        :target_band_gauge,
                        :transform_sha256,
                        :contract_sha256,
                        :frame_contract,
                        :rotation_sha256,
                        :num_bands,
                        :num_kpoints,
                        :num_kpts,
                        :physical_metric,
                        :spinor,
                        :kpoints_fractional,
                        :payload_sha256,
                        :input_sha256,
                        :artifacts,
                        :diagnostics,
                        :status,
                        :spn_sha256,
                        :provenance_sha256,
                        :qualification_target_band_gauge,
                        :qualification_transform_sha256,
                        :qualification_contract_sha256,
                        :qualification_rotation_sha256,
                        :gauge_artifact_sha256,
                    ),
                    Tuple{
                        String,
                        String,
                        Symbol,
                        Bool,
                        String,
                        String,
                        String,
                        String,
                        Base.Dict{String, Any},
                        String,
                        Int64,
                        Int64,
                        Int64,
                        String,
                        Bool,
                        Array{Float64, 2},
                        String,
                        Base.Dict{String, String},
                        Base.Dict{String, String},
                        Array{String, 1},
                        Vararg{String, 8},
                    },
                },
                String,
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
                typeof(Base.Core.kwcall),
                NamedTuple{(:construction_policy, :target_contract), Tuple{Symbol, Nothing}},
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._hamiltonian_operator_closure_scope,
                ),
                Nothing,
                WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.view), Base.BitArray{2}, Function, Int64})
        _record_early_prepare(
            Tuple{
                typeof(Base.count),
                Base.SubArray{
                    Bool,
                    1,
                    Base.BitArray{2},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
            },
        )
        _record_early_prepare(Tuple{Base.var"#58#59", Type})
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._hamiltonian_operator_neighbor_overlaps,
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
                WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
            },
        )
        _record_early_prepare(
            Tuple{
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
                Int64,
                Int64,
                Tuple{Int64, Int64, Int64},
                Array{Float64, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Tuple{Int64, Int64, Tuple{Int64, Int64, Int64}, Array{Float64, 1}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.PAWMatrixElements.QEUIUCacheEntry,
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._rotate_generation_link),
                Array{Base.Complex{Float64}, 2},
                WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                Int64,
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.all), Function, Array{Base.Complex{Float64}, 2}})
        _record_early_prepare(
            Tuple{
                typeof(Base._all),
                typeof(Base.isfinite),
                Array{Base.Complex{Float64}, 2},
                Base.Colon,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize!),
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
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Array{Base.Complex{Float64}, 2}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._hamiltonian_operator_overlap_numerical_tolerance,
                ),
                WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.in), Char, Tuple{Char, Char}})
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:numerical_tolerance,), Tuple{Float64}},
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._hamiltonian_operator_closure_metrics,
                ),
                Array{Base.Complex{Float64}, 4},
                WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                NamedTuple{
                    (
                        :authority,
                        :parent_audit_policy,
                        :artifact_sha256,
                        :outer_mask,
                        :frozen_mask,
                        :outer_mask_sha256,
                        :frozen_mask_sha256,
                        :outer_rank_minimum,
                        :outer_rank_maximum,
                        :frozen_rank_minimum,
                        :frozen_rank_maximum,
                        :contract_sha256,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        Base.BitArray{2},
                        Base.BitArray{2},
                        String,
                        String,
                        Int64,
                        Int64,
                        Int64,
                        Int64,
                        String,
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._hamiltonian_operator_closure_audit_findings,
                ),
                NamedTuple{
                    (
                        :target_probability_leakage_maximum,
                        :parent_mutual_containment_audit_maximum,
                        :contraction_excess_maximum,
                        :defect_psd_violation_maximum,
                        :outer_probability_leakage_audit_maximum,
                        :frozen_probability_leakage_audit_maximum,
                        :parent_overlap_contraction_excess_audit_maximum,
                        :outer_overlap_contraction_excess_audit_maximum,
                        :frozen_overlap_contraction_excess_audit_maximum,
                        :numerical_tolerance,
                        :target_worst_context,
                        :outer_worst_context,
                        :frozen_worst_context,
                        :parent_worst_context,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Nothing,
                        Float64,
                        Float64,
                        Nothing,
                        Float64,
                        NamedTuple{
                            (:center, :neighbor, :endpoint, :kpoint, :rank),
                            Tuple{Int64, Int64, String, Int64, Int64},
                        },
                        NamedTuple{
                            (:center, :neighbor, :endpoint, :kpoint, :rank),
                            Tuple{Int64, Int64, String, Int64, Int64},
                        },
                        Nothing,
                        NamedTuple{(:center, :neighbor, :right), Tuple{Int64, Int64, Int64}},
                    },
                },
                Float64,
            },
        )
        _record_early_prepare(
            Tuple{Type{WannierNLQG.IO.WannierSHUHeader}, String, Int64, Int64, Int64},
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.OperatorExport.var"#83#99"{
                    Array{Base.Complex{Float64}, 4},
                },
                Base.Iterators.ProductIterator{Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}}},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.float), Float64})
        _record_early_prepare(Tuple{typeof(Base.abs), Float64})
        _record_early_prepare(Tuple{typeof(Base.isinf), Float64})
        _record_early_prepare(Tuple{typeof(Base.:(*)), Float64, Float64})
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.Iterators.ProductIterator{
                        Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}},
                    },
                    WannierNLQGWannierizationExt.OperatorExport.var"#83#99"{
                        Array{Base.Complex{Float64}, 4},
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.OperatorExport.var"#84#100"{
                    WannierNLQGWannierizationExt.OperatorExport.AuthoritativeBandHamiltonian,
                },
                Base.UnitRange{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.UnitRange{Int64},
                    WannierNLQGWannierizationExt.OperatorExport.var"#84#100"{
                        WannierNLQGWannierizationExt.OperatorExport.AuthoritativeBandHamiltonian,
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:formatted,), Tuple{Bool}},
                typeof(WannierNLQG.IO.write_wannier_shu),
                Function,
                String,
                WannierNLQG.IO.WannierSHUHeader,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._atomic_wannier_operator_write),
                String,
                WannierNLQG.IO.var"#130#131"{
                    Bool,
                    WannierNLQG.IO.WannierSHUHeader,
                    WannierNLQGWannierizationExt.OperatorExport.var"#85#101"{
                        WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
                        Symbol,
                        Base.RefValue{Any},
                        Base.RefValue{Int64},
                        String,
                        WannierNLQGWannierizationExt.OperatorExport._HamiltonianOperatorGalerkinBlockAudit,
                        Float64,
                        WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                        Array{Base.Complex{Float64}, 4},
                        WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                        WannierNLQGWannierizationExt.OperatorExport.AuthoritativeBandHamiltonian,
                    },
                    String,
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.getproperty), WannierNLQG.IO.WannierSPN, Symbol})
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._rotate_generation_single),
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
                WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
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
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.OperatorExport.var"#86#102"{
                    WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                },
                Array{Array{Base.Complex{Float64}, 2}, 2},
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.getindex), Array{Array{Base.Complex{Float64}, 2}, 2}, Int64, Int64},
        )
        _record_early_prepare(Tuple{typeof(Base.:(*)), Float64, Float64, Float64})
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:numerical_tolerance,), Tuple{Float64}},
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._record_hamiltonian_operator_galerkin_block!,
                ),
                WannierNLQGWannierizationExt.OperatorExport._HamiltonianOperatorGalerkinBlockAudit,
                Array{Base.Complex{Float64}, 2},
                Float64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._validate_wannier_operator_block),
                Array{Base.Complex{Float64}, 2},
                WannierNLQG.IO.WannierSHUHeader,
                String,
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._write_wannier_operator_block),
                Base.IOStream,
                Array{Base.Complex{Float64}, 2},
                Bool,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:formatted, :expected_num_bands, :expected_num_kpts, :expected_num_neighbors),
                    Tuple{Bool, Int64, Int64, Int64},
                },
                typeof(WannierNLQG.IO.foreach_wannier_shu_block),
                Function,
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##open#463",
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(Base.open),
                WannierNLQG.IO.var"#118#119"{
                    Bool,
                    Int64,
                    Int64,
                    Int64,
                    WannierNLQGWannierizationExt.OperatorExport.var"#89#105",
                    String,
                    String,
                    DataType,
                },
                String,
                Vararg{String},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{WannierNLQG.IO.WannierSHUHeader},
                Base.SubString{String},
                Int64,
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:expected_num_bands, :expected_num_kpts, :expected_num_neighbors),
                    Tuple{Int64, Int64, Int64},
                },
                typeof(WannierNLQG.IO._validate_wannier_operator_expected_dimensions),
                WannierNLQG.IO.WannierSHUHeader,
                String,
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.getproperty), WannierNLQG.IO.WannierSHUHeader, Symbol},
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._read_wannier_operator_matrix),
                Base.IOStream,
                WannierNLQG.IO.WannierSHUHeader,
                Symbol,
                String,
                String,
                Bool,
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.OperatorExport.var"#89#105",
                Array{Base.Complex{Float64}, 2},
                Vararg{Any},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.getindex), Base.RefValue{Int64}})
        _record_early_prepare(Tuple{typeof(Base.setindex!), Base.RefValue{Int64}, Int64})
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._hamiltonian_operator_provenance,
                ),
                WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
                Symbol,
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
                WannierNLQGWannierizationExt.OperatorExport.AuthoritativeBandHamiltonian,
                WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                NamedTuple{
                    (
                        :schema,
                        :schema_version,
                        :source_code,
                        :passed,
                        :source_band_gauge,
                        :target_band_gauge,
                        :transform_sha256,
                        :contract_sha256,
                        :frame_contract,
                        :rotation_sha256,
                        :num_bands,
                        :num_kpoints,
                        :num_kpts,
                        :physical_metric,
                        :spinor,
                        :kpoints_fractional,
                        :payload_sha256,
                        :input_sha256,
                        :artifacts,
                        :diagnostics,
                        :status,
                        :spn_sha256,
                        :provenance_sha256,
                        :qualification_target_band_gauge,
                        :qualification_transform_sha256,
                        :qualification_contract_sha256,
                        :qualification_rotation_sha256,
                        :gauge_artifact_sha256,
                    ),
                    Tuple{
                        String,
                        String,
                        Symbol,
                        Bool,
                        String,
                        String,
                        String,
                        String,
                        Base.Dict{String, Any},
                        String,
                        Int64,
                        Int64,
                        Int64,
                        String,
                        Bool,
                        Array{Float64, 2},
                        String,
                        Base.Dict{String, String},
                        Base.Dict{String, String},
                        Array{String, 1},
                        Vararg{String, 8},
                    },
                },
                NamedTuple{
                    (
                        :target_probability_leakage_maximum,
                        :parent_mutual_containment_audit_maximum,
                        :contraction_excess_maximum,
                        :defect_psd_violation_maximum,
                        :outer_probability_leakage_audit_maximum,
                        :frozen_probability_leakage_audit_maximum,
                        :parent_overlap_contraction_excess_audit_maximum,
                        :outer_overlap_contraction_excess_audit_maximum,
                        :frozen_overlap_contraction_excess_audit_maximum,
                        :numerical_tolerance,
                        :target_worst_context,
                        :outer_worst_context,
                        :frozen_worst_context,
                        :parent_worst_context,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Nothing,
                        Float64,
                        Float64,
                        Nothing,
                        Float64,
                        NamedTuple{
                            (:center, :neighbor, :endpoint, :kpoint, :rank),
                            Tuple{Int64, Int64, String, Int64, Int64},
                        },
                        NamedTuple{
                            (:center, :neighbor, :endpoint, :kpoint, :rank),
                            Tuple{Int64, Int64, String, Int64, Int64},
                        },
                        Nothing,
                        NamedTuple{(:center, :neighbor, :right), Tuple{Int64, Int64, Int64}},
                    },
                },
                NamedTuple{
                    (
                        :authority,
                        :parent_audit_policy,
                        :artifact_sha256,
                        :outer_mask,
                        :frozen_mask,
                        :outer_mask_sha256,
                        :frozen_mask_sha256,
                        :outer_rank_minimum,
                        :outer_rank_maximum,
                        :frozen_rank_minimum,
                        :frozen_rank_maximum,
                        :contract_sha256,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        Base.BitArray{2},
                        Base.BitArray{2},
                        String,
                        String,
                        Int64,
                        Int64,
                        Int64,
                        Int64,
                        String,
                    },
                },
                Bool,
                Array{String, 1},
                WannierNLQGWannierizationExt.OperatorExport._HamiltonianOperatorGalerkinBlockAudit,
                String,
                Base.Dict{String, String},
                Array{String, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{String, Any},
                Tuple{
                    Pair{String, String},
                    Pair{String, Int64},
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Nothing},
                    Pair{String, Nothing},
                    Pair{String, String},
                },
                Int64,
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
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, Array{String, 1}},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{
                        String,
                        NamedTuple{
                            (:center, :neighbor, :endpoint, :kpoint, :rank),
                            Tuple{Int64, Int64, String, Int64, Int64},
                        },
                    },
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{
                        String,
                        NamedTuple{
                            (:center, :neighbor, :endpoint, :kpoint, :rank),
                            Tuple{Int64, Int64, String, Int64, Int64},
                        },
                    },
                    Pair{String, Nothing},
                    Pair{String, String},
                    Pair{String, Nothing},
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{
                        String,
                        NamedTuple{(:center, :neighbor, :right), Tuple{Int64, Int64, Int64}},
                    },
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Nothing},
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, Any}},
                    Pair{String, Nothing},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, Any}},
                    Pair{String, Base.Dict{String, Union{Nothing, String}}},
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
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
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
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, Array{String, 1}},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{
                        String,
                        NamedTuple{
                            (:center, :neighbor, :endpoint, :kpoint, :rank),
                            Tuple{Int64, Int64, String, Int64, Int64},
                        },
                    },
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{
                        String,
                        NamedTuple{
                            (:center, :neighbor, :endpoint, :kpoint, :rank),
                            Tuple{Int64, Int64, String, Int64, Int64},
                        },
                    },
                    Pair{String, Nothing},
                    Pair{String, String},
                    Pair{String, Nothing},
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{
                        String,
                        NamedTuple{(:center, :neighbor, :right), Tuple{Int64, Int64, Int64}},
                    },
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Nothing},
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, Any}},
                    Pair{String, Nothing},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, Any}},
                    Pair{String, Base.Dict{String, Union{Nothing, String}}},
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
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, String}},
                    Pair{String, Array{String, 1}},
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                NamedTuple{
                    (:center, :neighbor, :endpoint, :kpoint, :rank),
                    Tuple{Int64, Int64, String, Int64, Int64},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                NamedTuple{(:center, :neighbor, :right), Tuple{Int64, Int64, Int64}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                Base.Dict{String, Union{Nothing, String}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.write),
                PAWMatrixElements.JSON3.StructTypes.UnorderedStruct,
                Array{UInt8, 1},
                Int64,
                Int64,
                NamedTuple{
                    (:center, :neighbor, :endpoint, :kpoint, :rank),
                    Tuple{Int64, Int64, String, Int64, Int64},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.write),
                PAWMatrixElements.JSON3.StructTypes.UnorderedStruct,
                Array{UInt8, 1},
                Int64,
                Int64,
                NamedTuple{(:center, :neighbor, :right), Tuple{Int64, Int64, Int64}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.write),
                PAWMatrixElements.JSON3.StructTypes.DictType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Base.Dict{String, Union{Nothing, String}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._hamiltonian_operator_reference_status,
                ),
                Float64,
                Float64,
            },
        )
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
                        WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationResult,
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Tuple{Int64, Int64},
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.read!), Base.IOStream, Array{Base.Complex{Float64}, 2}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{(:contract, :payload), Tuple{String, Array{Base.Complex{Float64}, 2}}},
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
                Array{Base.Complex{Float64}, 2},
                Tuple{
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                    Tuple{UInt64, UInt64, Int64, Float64, Float64},
                },
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Wannierization.generate_wannier_siu),
                WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport.generate_wannier_siu),
                WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
            },
        )
        _record_early_prepare(
            Tuple{Type{WannierNLQG.IO.WannierSIUHeader}, String, Int64, Int64, Int64},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:formatted,), Tuple{Bool}},
                typeof(WannierNLQG.IO.write_wannier_siu),
                Function,
                String,
                WannierNLQG.IO.WannierSIUHeader,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._atomic_wannier_operator_write),
                String,
                WannierNLQG.IO.var"#130#131"{
                    Bool,
                    WannierNLQG.IO.WannierSIUHeader,
                    WannierNLQGWannierizationExt.OperatorExport.var"#85#101"{
                        WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
                        Symbol,
                        Base.RefValue{Any},
                        Base.RefValue{Int64},
                        String,
                        WannierNLQGWannierizationExt.OperatorExport._HamiltonianOperatorGalerkinBlockAudit,
                        Float64,
                        WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                        Array{Base.Complex{Float64}, 4},
                        WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                        WannierNLQGWannierizationExt.OperatorExport.AuthoritativeBandHamiltonian,
                    },
                    String,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
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
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._validate_wannier_operator_block),
                Array{Base.Complex{Float64}, 2},
                WannierNLQG.IO.WannierSIUHeader,
                String,
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:formatted, :expected_num_bands, :expected_num_kpts, :expected_num_neighbors),
                    Tuple{Bool, Int64, Int64, Int64},
                },
                typeof(WannierNLQG.IO.foreach_wannier_siu_block),
                Function,
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                Type{WannierNLQG.IO.WannierSIUHeader},
                Base.SubString{String},
                Int64,
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:expected_num_bands, :expected_num_kpts, :expected_num_neighbors),
                    Tuple{Int64, Int64, Int64},
                },
                typeof(WannierNLQG.IO._validate_wannier_operator_expected_dimensions),
                WannierNLQG.IO.WannierSIUHeader,
                String,
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.getproperty), WannierNLQG.IO.WannierSIUHeader, Symbol},
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._read_wannier_operator_matrix),
                Base.IOStream,
                WannierNLQG.IO.WannierSIUHeader,
                Symbol,
                String,
                String,
                Bool,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Wannierization.generate_wannier_uhu),
                WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport.generate_wannier_uhu),
                WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._validate_generation_output_paths,
                ),
                NamedTuple{(:output, :provenance), Tuple{String, String}},
                Tuple{String, String, Vararg{Nothing, 6}},
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
            },
        )
        _record_early_prepare(
            Tuple{Type{WannierNLQG.IO.WannierUHUHeader}, String, Int64, Int64, Int64},
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.OperatorExport.var"#75#90"{
                    Array{Base.Complex{Float64}, 4},
                },
                Base.Iterators.ProductIterator{Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.Iterators.ProductIterator{
                        Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}},
                    },
                    WannierNLQGWannierizationExt.OperatorExport.var"#75#90"{
                        Array{Base.Complex{Float64}, 4},
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.OperatorExport.var"#76#91"{
                    WannierNLQGWannierizationExt.OperatorExport.AuthoritativeBandHamiltonian,
                },
                Base.UnitRange{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.UnitRange{Int64},
                    WannierNLQGWannierizationExt.OperatorExport.var"#76#91"{
                        WannierNLQGWannierizationExt.OperatorExport.AuthoritativeBandHamiltonian,
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.OperatorExport.var"#77#92",
                Base.Iterators.ProductIterator{Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.Iterators.ProductIterator{
                        Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}},
                    },
                    WannierNLQGWannierizationExt.OperatorExport.var"#77#92",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._atomic_wannier_operator_write),
                String,
                WannierNLQG.IO.var"#127#128"{
                    Bool,
                    WannierNLQG.IO.WannierUHUHeader,
                    WannierNLQGWannierizationExt.OperatorExport.var"#81#97"{
                        WannierNLQGWannierizationExt.OperatorExport.var"#populate_center!#93"{
                            WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
                            Symbol,
                            Base.RefValue{Int64},
                            String,
                            WannierNLQGWannierizationExt.OperatorExport._HamiltonianOperatorGalerkinBlockAudit,
                            Float64,
                            WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                            Array{Base.Complex{Float64}, 4},
                            WannierNLQGWannierizationExt.OperatorExport.AuthoritativeBandHamiltonian,
                        },
                        Base.RefValue{Int64},
                    },
                    String,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.OperatorExport.var"#78#94"{
                    WannierNLQGWannierizationExt.PAWMatrixElements.WannierNeighborTopology,
                },
                Array{Array{Base.Complex{Float64}, 2}, 2},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.setindex!),
                Array{Array{Base.Complex{Float64}, 2}, 2},
                Array{Base.Complex{Float64}, 2},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._hamiltonian_operator_uhu_exchange_hermiticity,
                ),
                Array{Array{Base.Complex{Float64}, 2}, 2},
                Float64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.setproperty!),
                WannierNLQGWannierizationExt.OperatorExport._HamiltonianOperatorGalerkinBlockAudit,
                Symbol,
                Float64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._validate_wannier_operator_block),
                Array{Base.Complex{Float64}, 2},
                WannierNLQG.IO.WannierUHUHeader,
                String,
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:formatted, :expected_num_bands, :expected_num_kpts, :expected_num_neighbors),
                    Tuple{Bool, Int64, Int64, Int64},
                },
                typeof(WannierNLQG.IO.foreach_wannier_uhu_block),
                Function,
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##open#463",
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(Base.open),
                WannierNLQG.IO.var"#115#116"{
                    Bool,
                    Int64,
                    Int64,
                    Int64,
                    WannierNLQGWannierizationExt.OperatorExport.var"#82#98",
                    String,
                    String,
                    DataType,
                },
                String,
                Vararg{String},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{WannierNLQG.IO.WannierUHUHeader},
                Base.SubString{String},
                Int64,
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:expected_num_bands, :expected_num_kpts, :expected_num_neighbors),
                    Tuple{Int64, Int64, Int64},
                },
                typeof(WannierNLQG.IO._validate_wannier_operator_expected_dimensions),
                WannierNLQG.IO.WannierUHUHeader,
                String,
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.getproperty), WannierNLQG.IO.WannierUHUHeader, Symbol},
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO._read_wannier_operator_matrix),
                Base.IOStream,
                WannierNLQG.IO.WannierUHUHeader,
                Symbol,
                String,
                String,
                Bool,
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.OperatorExport.var"#82#98",
                Array{Base.Complex{Float64}, 2},
                Vararg{Any},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._hamiltonian_operator_provenance,
                ),
                WannierNLQG.Wannierization.WannierHamiltonianOperatorGenerationConfig,
                Symbol,
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
                WannierNLQGWannierizationExt.OperatorExport.AuthoritativeBandHamiltonian,
                WannierNLQGWannierizationExt.WannierizationInternalSupport.BandFrameTransformContract,
                Nothing,
                NamedTuple{
                    (
                        :target_probability_leakage_maximum,
                        :parent_mutual_containment_audit_maximum,
                        :contraction_excess_maximum,
                        :defect_psd_violation_maximum,
                        :outer_probability_leakage_audit_maximum,
                        :frozen_probability_leakage_audit_maximum,
                        :parent_overlap_contraction_excess_audit_maximum,
                        :outer_overlap_contraction_excess_audit_maximum,
                        :frozen_overlap_contraction_excess_audit_maximum,
                        :numerical_tolerance,
                        :target_worst_context,
                        :outer_worst_context,
                        :frozen_worst_context,
                        :parent_worst_context,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Nothing,
                        Float64,
                        Float64,
                        Nothing,
                        Float64,
                        NamedTuple{
                            (:center, :neighbor, :endpoint, :kpoint, :rank),
                            Tuple{Int64, Int64, String, Int64, Int64},
                        },
                        NamedTuple{
                            (:center, :neighbor, :endpoint, :kpoint, :rank),
                            Tuple{Int64, Int64, String, Int64, Int64},
                        },
                        Nothing,
                        NamedTuple{(:center, :neighbor, :right), Tuple{Int64, Int64, Int64}},
                    },
                },
                NamedTuple{
                    (
                        :authority,
                        :parent_audit_policy,
                        :artifact_sha256,
                        :outer_mask,
                        :frozen_mask,
                        :outer_mask_sha256,
                        :frozen_mask_sha256,
                        :outer_rank_minimum,
                        :outer_rank_maximum,
                        :frozen_rank_minimum,
                        :frozen_rank_maximum,
                        :contract_sha256,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        Base.BitArray{2},
                        Base.BitArray{2},
                        String,
                        String,
                        Int64,
                        Int64,
                        Int64,
                        Int64,
                        String,
                    },
                },
                Bool,
                Array{String, 1},
                WannierNLQGWannierizationExt.OperatorExport._HamiltonianOperatorGalerkinBlockAudit,
                String,
                Base.Dict{String, String},
                Array{String, 1},
            },
        )
    end
end
