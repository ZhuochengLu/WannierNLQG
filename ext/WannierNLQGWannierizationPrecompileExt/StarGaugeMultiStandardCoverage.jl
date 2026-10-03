# Generated from the 018/P real four-star STANDARD public-call trace.
# Signature declarations only; no scientific computation or file IO at package precompile.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        false
        false
        false
        _record_precompile(
            Tuple{
                typeof(Base.repr),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
            },
        )
        false
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:normalize_coefficients,), Tuple{Bool}},
                Type{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                Array{Float64, 1},
                Array{Int64, 2},
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
                Symbol,
            },
        )
        _record_precompile(
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
        _record_precompile(
            Tuple{typeof(Base.getproperty), WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, Symbol},
        )
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:include_time_reversal, :symmetry_tolerance), Tuple{Bool, Float64}},
                typeof(WannierNLQG.SymmetryFoundation.detect_magnetic_symmetry_inventory),
                WannierNLQG.SymmetryFoundation.CrystalStructure,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.MagneticSymmetryInventory,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 3}},
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 2}},
                Symbol,
            },
        )
        _record_precompile(
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
        _record_precompile(
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
        _record_precompile(
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
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 3}},
                Int64,
            },
        )
        _record_precompile(
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
        _record_precompile(
            Tuple{
                typeof(Base.first),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.length),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.axes),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{typeof(Base.length), Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1}},
        )
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 2}},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                Symbol,
            },
        )
        _record_precompile(
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
        false
        _record_precompile(
            Tuple{typeof(Base.length), Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
        )
        false
        false
        false
        false
        _record_precompile(
            Tuple{typeof(Base.first), Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
        )
        _record_precompile(
            Tuple{typeof(Base.axes), Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
        )
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                Int64,
            },
        )
        false
        false
        _record_precompile(
            Tuple{
                typeof(Base.checkbounds),
                Type{Bool},
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
                Int64,
            },
        )
        false
        false
        false
        false
        false
        false
        _record_precompile(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Wannierization.WannierizationDiagnostic,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        false
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:context,), Tuple{String}},
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._star_construction_quality_gate!,
                ),
                WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                Base.Dict{String, Float64},
                Base.Dict{String, String},
                String,
                Float64,
                Float64,
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
        _record_precompile(
            Tuple{
                typeof(Base.eachindex),
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                Type{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            },
        )
        false
        false
        false
        false
        _record_precompile(
            Tuple{
                typeof(Base.eachindex),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        false
        false
        false
        false
        false
        false
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Int64,
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
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                Symbol,
            },
        )
        false
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (:representation, :construction_diagnostics),
                    Tuple{WannierNLQG.SymmetryFoundation.BandRepresentation, Array{Any, 1}},
                },
                Symbol,
            },
        )
        false
        @assert !MPI.Initialized()
    end
end
