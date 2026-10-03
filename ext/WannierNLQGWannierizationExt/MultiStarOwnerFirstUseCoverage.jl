# Residual from the 021/P real four-star Standard public-call trace.
# Signatures only; no solver, output writer or MPI lifecycle is invoked.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationSourceVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                        Bool,
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        Int64,
                        Nothing,
                        Base.UnitRange{Int64},
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
                },
                Symbol,
            },
        )
        precompile(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Float64,
                    Tuple{Int64, Int64, Int64},
                },
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Float64,
                    Tuple{Int64, Int64, Int64},
                },
                Int64,
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(Base.axes),
                WannierNLQG.IO.PreparationSourceVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                        Bool,
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        Int64,
                        Nothing,
                        Base.UnitRange{Int64},
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
                },
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :native,
                        :metric,
                        :rotations,
                        :hamiltonians,
                        :maximum_before,
                        :maximum_after,
                        :worst_context,
                    ),
                    Tuple{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Float64,
                        String,
                    },
                },
                Symbol,
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                Symbol,
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._strict_reconstruction_diagnostics,
                ),
                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 2},
            },
        )
        false
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                Symbol,
            },
        )
        false
        @assert !WannierizationInternalSupport.WannierNLQG.MPI.Initialized()
    end
end
