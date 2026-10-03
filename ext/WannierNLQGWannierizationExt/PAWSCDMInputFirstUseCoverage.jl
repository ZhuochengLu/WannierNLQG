# Candidate 015: three literal signatures from the first successful PAW-SCDM
# public call trace. No fixture, output file, or MPI runtime is opened here.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:num_wannier,), Tuple{Int64}},
                typeof(WannierNLQG.Wannierization.prepare_paw_scdm_input_artifact),
                String,
                String,
                String,
            },
        )
        precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (:num_wannier, :construction_policy, :execution),
                    Tuple{
                        Int64,
                        Symbol,
                        WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                    },
                },
                typeof(PAWMatrixElements.prepare_paw_scdm_input_artifact),
                String,
                String,
                String,
            },
        )
        precompile(
            Tuple{
                typeof(PAWMatrixElements._paw_scdm_source_identity),
                PAWMatrixElements._StarCovariantPAWPayload,
                String,
                String,
            },
        )
        # Residual trace from candidate 015's valid PAW-SCDM first call.
        precompile(
            Tuple{
                typeof(PAWMatrixElements._paw_scdm_lowdin),
                PAWMatrixElements._QEStrictSewingMetric,
                Int64,
                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            },
        )
        precompile(
            Tuple{
                typeof(PAWMatrixElements._paw_scdm_anchor_samples),
                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                Array{ComplexF64, 2},
                Tuple{Int64, Int64, Int64},
            },
        )
        precompile(
            Tuple{
                typeof(PAWMatrixElements._paw_scdm_selected_coordinates),
                Array{Int64, 1},
                Tuple{Int64, Int64, Int64},
            },
        )
        precompile(
            Tuple{
                typeof(PAWMatrixElements._paw_scdm_payload_sha256),
                Array{ComplexF64, 3},
                Array{ComplexF64, 3},
                Array{Int64, 2},
                Tuple{Int64, Int64, Int64},
                Array{Float64, 2},
                Array{Int64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 2},
                Tuple{Int64, Int64, Int64},
                Bool,
                String,
                String,
                String,
                String,
                String,
                Dict{String, String},
            },
        )
        # Identity-tied closure signatures from the candidate 016 residual trace.
        precompile(
            Tuple{
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#load_metric#767"{
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                },
                Int64,
            },
        )
        precompile(
            Tuple{
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#consume_frame#766"{
                    Array{Float64, 1},
                    Array{Float64, 1},
                    Array{Float64, 1},
                    Array{Float64, 1},
                    Array{Int64, 1},
                    Array{Float64, 2},
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 3},
                },
                Int64,
                NamedTuple{
                    (
                        :frame,
                        :singular_values,
                        :rank,
                        :condition,
                        :generalized_residual,
                        :paw_s_residual,
                        :euclidean_residual,
                    ),
                    Tuple{
                        Array{Base.Complex{Float64}, 2},
                        Array{Float64, 1},
                        Int64,
                        Vararg{Float64, 4},
                    },
                },
            },
        )
        # Ten residual data-provider signatures from candidate 021, tied to this source identity.
        precompile(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#634#635"{
                    Base.Pairs{
                        Symbol,
                        Symbol,
                        Tuple{Symbol},
                        NamedTuple{(:construction_policy,), Tuple{Symbol}},
                    },
                    String,
                },
                Symbol,
                Bool,
            },
        )
        precompile(
            Tuple{
                WannierNLQG.IO.var"#23#29"{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#765#768"{
                        Array{Int64, 1},
                        Array{Float64, 2},
                    },
                    Int64,
                    Tuple{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        Array{Base.Complex{Float64}, 2},
                        Array{Base.Complex{Float64}, 2},
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationSourceVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                        String,
                        Array{String, 1},
                    },
                },
                Symbol,
            },
        )
        precompile(
            Tuple{
                typeof(Base.lock),
                WannierNLQG.IO.var"#9#10"{
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                            String,
                            Array{String, 1},
                        },
                    },
                },
                Base.ReentrantLock,
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationSourceVector{
                    Tuple{Array{Base.Complex{Float64}, 3}, Array{Base.Complex{Float64}, 2}},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        Base.Dict{
                            String,
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                        },
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    },
                },
                Symbol,
            },
        )
        precompile(
            Tuple{
                typeof(Base.lock),
                WannierNLQG.IO.var"#9#10"{
                    WannierNLQG.IO.PreparationSourceVector{
                        Tuple{Array{Base.Complex{Float64}, 3}, Array{Base.Complex{Float64}, 2}},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                            Base.Dict{
                                String,
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                            },
                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                        },
                    },
                },
                Base.ReentrantLock,
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationSourceVector{
                    Array{Base.Complex{Float64}, 3},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                        WannierNLQG.IO.PreparationSourceVector{
                            Tuple{Array{Base.Complex{Float64}, 3}, Array{Base.Complex{Float64}, 2}},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            },
                        },
                    },
                },
                Symbol,
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationSourceVector{
                    Array{Base.Complex{Float64}, 2},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                        WannierNLQG.IO.PreparationSourceVector{
                            Tuple{Array{Base.Complex{Float64}, 3}, Array{Base.Complex{Float64}, 2}},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                Base.Dict{
                                    String,
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                },
                                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                            },
                        },
                    },
                },
                Symbol,
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationSourceVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        Array{Base.Complex{Float64}, 3},
                        Array{Float64, 2},
                    },
                },
                Symbol,
            },
        )
        precompile(
            Tuple{
                typeof(Base.lock),
                WannierNLQG.IO.var"#9#10"{
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                            Array{Base.Complex{Float64}, 3},
                            Array{Float64, 2},
                        },
                    },
                },
                Base.ReentrantLock,
            },
        )
    end
end
