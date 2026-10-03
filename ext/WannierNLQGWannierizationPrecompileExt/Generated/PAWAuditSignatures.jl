# R16: actual four-band audit signatures; compile only, without audit execution.
import EzXML
const PAW_AUDIT_COVERAGE_RESULTS = Tuple{Bool, Bool}[]
@compile_workload let
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        StructTypes = JSON3.StructTypes
        let signature = Tuple{
                typeof(WannierNLQG.Wannierization.audit_paw_block_partitions),
                WannierNLQG.Wannierization.PAWBlockPartitionAuditConfig,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.issorted),
                Array{String, 1},
                Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.setindex!), Base.EnvDict, String, String}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Type{Union{Nothing, Array{String, 1}}},
                Nothing,
                Array{String, 1},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (false, false))
        end
        let signature = Tuple{typeof(Base.iterate), Array{Union{Nothing, Array{String, 1}}, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (false, false))
        end
        let signature =
                Tuple{typeof(Base.iterate), Array{Union{Nothing, Array{String, 1}}, 1}, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (false, false))
        end
        let signature = Tuple{typeof(Base.:(==)), Char, Char}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.iszero), Bool}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{Type{NamedTuple{(:normalize_coefficients,), T} where T <: Tuple}, Tuple{Bool}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.in), Int64, Base.UnitRange{Int64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#809#837",
                    Base.BottomRF{typeof(Base.vcat)},
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{NamedTuple{(:tolerance,), T} where T <: Tuple}, Tuple{Float64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.convert), Type{Bool}, Bool}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.PAWMatrixElements._PAWBlockEvidenceRecord,
                    Core.AddrSpace{Core}(0x00),
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                WannierNLQG.Wannierization.var"#_#7#8",
                Float64,
                Float64,
                Int64,
                Type{WannierNLQG.Wannierization.ClosureDrivenBandBuffer},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    NamedTuple{
                        (
                            :raw,
                            :pseudo,
                            :augmentation,
                            :transformed,
                            :transformed_projectors,
                            :reconstruction,
                        ),
                        Tuple{
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            NamedTuple{
                                (
                                    :reconstruction_leakage_weight,
                                    :state_leakage_weight,
                                    :reconstruction_leakage_amplitude_audit,
                                    :state_leakage_amplitude_audit,
                                    :minimum_residual_gram_eigenvalue,
                                ),
                                NTuple{5, Float64},
                            },
                        },
                    },
                    Core.AddrSpace{Core}(0x00),
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{typeof(Base.abs2), Base.BottomRF{typeof(Base.add_sum)}},
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.ClosureDrivenBandBuffer,
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(&)), Bool, Base.Missing}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.isempty), Base.UnitRange{Int64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{NamedTuple{(:init,), T} where T <: Tuple}, Tuple{Float64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    NamedTuple{names, T} where {T <: Tuple} where names,
                    Core.AddrSpace{Core}(0x00),
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.Order.By{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#812#840",
                    Base.Order.ForwardOrdering,
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.Order.Lt{
                    Base.Sort.var"#30#31"{
                        Base.Order.By{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#812#840",
                            Base.Order.ForwardOrdering,
                        },
                    },
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Base.var"##s128#278", Vararg{Any, 5}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.isconcretetype), Any}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.real), Base.Complex{Float64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.imag), Base.Complex{Float64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.float), Float64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.abs), Float64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.isinf), Float64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(>)), Float64, Float64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(/)), Float64, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(*)), Float64, Float64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(<=)), Float64, Float64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.Order.By{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#814#842",
                    Base.Order.ForwardOrdering,
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.Order.Lt{
                    Base.Sort.var"#30#31"{
                        Base.Order.By{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#814#842",
                            Base.Order.ForwardOrdering,
                        },
                    },
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    Base.var"#361#362"{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#816#844",
                    },
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    Base.var"#361#362"{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#817#845",
                    },
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#818#846",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#822#850",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(&)), Int64, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#825#853",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.pairs), NamedTuple{(:rev,), Tuple{Bool}}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#830#858",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#831#859",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, String, Bool}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{16, Symbol}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{15, Symbol}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{14, Symbol}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{13, Symbol}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{12, Symbol}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{11, Symbol}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{10, Symbol}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{9, Symbol}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{8, Symbol}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{7, Symbol}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{6, Symbol}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{5, Symbol}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{4, Symbol}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{MethodError}, Any, Any}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements.audit_paw_block_partitions),
                WannierNLQG.Wannierization.PAWBlockPartitionAuditConfig,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :band_range,
                        :spin_channel,
                        :representation_cutoff_ev,
                        :include_time_reversal,
                        :magnetic_moments_cartesian,
                    ),
                    Tuple{Nothing, Symbol, Nothing, Bool, Nothing},
                },
                Type{WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource},
                String,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                WannierNLQGWannierizationExt.RepresentationPreparation.var"##_read_qe_wavefunctions#98",
                Symbol,
                Bool,
                Bool,
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
                Bool,
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                typeof(
                    WannierNLQGWannierizationExt.RepresentationPreparation._read_qe_wavefunctions,
                ),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (false, false))
        end
        let signature = Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.size), Array{Int64, 2}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 1}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{Float64},
                    Tuple{Array{Float64, 1}},
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.transpose), Array{Float64, 1}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.length), Array{Float64, 1}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.collect), Base.UnitRange{Int64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.size), Array{Float64, 2}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.isfinite), Float64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.length), Array{Int64, 1}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{typeof(Base.zeros), Type{Base.Complex{Float64}}, Int64, Int64, Vararg{Int64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.reshape), Array{Base.Complex{Float64}, 1}, Int64, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:normalize_coefficients,), Tuple{Bool}},
                Type{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                Array{Float64, 1},
                Array{Int64, 2},
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 1},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Type{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Base.KeyError}, String}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.literal_pow), typeof(Base.:(^)), Int64, Base.Val{2}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.maximum), Array{Int64, 1}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{typeof(Base.length), Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.Iterators.enumerate),
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
                Tuple{Int64},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
                Tuple{Int64, Int64},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Array{Base.Complex{Float64}, 2},
                    Core.AddrSpace{Core}(0x00),
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{typeof(Base.axes), Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                Int64,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{typeof(Base.getindex), Array{Array{Base.Complex{Float64}, 3}, 1}, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Type{LinearAlgebra.Diagonal{T, V} where {V <: AbstractArray{T, 1}} where T},
                Array{Float64, 1},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.:(*)),
                LinearAlgebra.Adjoint{Base.Complex{Float64}, Array{Base.Complex{Float64}, 2}},
                LinearAlgebra.Diagonal{Float64, Array{Float64, 1}},
                Array{Base.Complex{Float64}, 2},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.push!),
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Base.Complex{Float64}, 2},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end

        let signature = Tuple{
                typeof(Core.memoryref),
                GenericMemory{:not_atomic, Array{Int64, 2}, Core.AddrSpace{Core}(0x00)},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.hashindex), NTuple{9, Int64}, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.isequal), NTuple{9, Int64}, NTuple{9, Int64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, NTuple{9, Int64}, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{typeof(Base.empty), Base.Dict{Any, Any}, Type{NTuple{9, Int64}}, Type{Int64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.MagneticSymmetryInventory,
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#809#837",
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.reduce),
                Function,
                Base.Generator{
                    Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#809#837",
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Base.var"##mapfoldl#335",
                Base._InitialValue,
                typeof(Base.mapfoldl),
                Function,
                Function,
                Base.Generator{
                    Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#809#837",
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                typeof(Base.vcat),
                Base._InitialValue,
                Base.Generator{
                    Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#809#837",
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{Type{Array{Float64, 2}}, LinearAlgebra.Transpose{Float64, Array{Float64, 1}}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.zeros), Type{Int64}, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.Broadcast.dotview), Array{Int64, 1}, Array{Int64, 1}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{Int64, 1, Array{Int64, 1}, Tuple{Array{Int64, 1}}, false},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{0},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Int64},
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base._all),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#810#838"{
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                },
                Array{Int64, 1},
                Base.Colon,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.in), Int64, Base.OneTo{Int64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.eachindex),
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#811#839"{
                    Array{Int64, 3},
                    Array{Int64, 2},
                    Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    Int64,
                },
                Base.OneTo{Int64},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#811#839"{
                        Array{Int64, 3},
                        Array{Int64, 2},
                        Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        Int64,
                    },
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#385#386"{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    },
                },
                Int64,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.:(*)),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
                Array{Base.Complex{Float64}, 2},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(getfield),
                Array{
                    NamedTuple{
                        (
                            :raw,
                            :pseudo,
                            :augmentation,
                            :transformed,
                            :transformed_projectors,
                            :reconstruction,
                        ),
                        Tuple{
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            NamedTuple{
                                (
                                    :reconstruction_leakage_weight,
                                    :state_leakage_weight,
                                    :reconstruction_leakage_amplitude_audit,
                                    :state_leakage_amplitude_audit,
                                    :minimum_residual_gram_eigenvalue,
                                ),
                                NTuple{5, Float64},
                            },
                        },
                    },
                    1,
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(getfield),
                    Tuple{
                        Array{
                            NamedTuple{
                                (
                                    :raw,
                                    :pseudo,
                                    :augmentation,
                                    :transformed,
                                    :transformed_projectors,
                                    :reconstruction,
                                ),
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 3},
                                    NamedTuple{
                                        (
                                            :reconstruction_leakage_weight,
                                            :state_leakage_weight,
                                            :reconstruction_leakage_amplitude_audit,
                                            :state_leakage_amplitude_audit,
                                            :minimum_residual_gram_eigenvalue,
                                        ),
                                        NTuple{5, Float64},
                                    },
                                },
                            },
                            1,
                        },
                        Base.RefValue{Symbol},
                    },
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.setindex!),
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Base.Complex{Float64}, 2},
                Int64,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.checkbounds),
                Type{Bool},
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                Int64,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.getindex), Array{Float64, 1}, Base.UnitRange{Int64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Array{
                    NamedTuple{
                        (
                            :raw,
                            :pseudo,
                            :augmentation,
                            :transformed,
                            :transformed_projectors,
                            :reconstruction,
                        ),
                        Tuple{
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            NamedTuple{
                                (
                                    :reconstruction_leakage_weight,
                                    :state_leakage_weight,
                                    :reconstruction_leakage_amplitude_audit,
                                    :state_leakage_amplitude_audit,
                                    :minimum_residual_gram_eigenvalue,
                                ),
                                NTuple{5, Float64},
                            },
                        },
                    },
                    1,
                },
                Int64,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :raw,
                        :pseudo,
                        :augmentation,
                        :transformed,
                        :transformed_projectors,
                        :reconstruction,
                    ),
                    Tuple{
                        Array{Base.Complex{Float64}, 2},
                        Array{Base.Complex{Float64}, 2},
                        Array{Base.Complex{Float64}, 2},
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 3},
                        NamedTuple{
                            (
                                :reconstruction_leakage_weight,
                                :state_leakage_weight,
                                :reconstruction_leakage_amplitude_audit,
                                :state_leakage_amplitude_audit,
                                :minimum_residual_gram_eigenvalue,
                            ),
                            NTuple{5, Float64},
                        },
                    },
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :reconstruction_leakage_weight,
                        :state_leakage_weight,
                        :reconstruction_leakage_amplitude_audit,
                        :state_leakage_amplitude_audit,
                        :minimum_residual_gram_eigenvalue,
                    ),
                    NTuple{5, Float64},
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.view),
                Array{Base.Complex{Float64}, 2},
                Base.UnitRange{Int64},
                Base.UnitRange{Int64},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Type{Array{T, 2} where T},
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 2},
                    Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}},
                    false,
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.adjoint), Array{Base.Complex{Float64}, 2}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.:(*)),
                LinearAlgebra.Adjoint{Base.Complex{Float64}, Array{Base.Complex{Float64}, 2}},
                Array{Base.Complex{Float64}, 2},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                LinearAlgebra.Adjoint{Base.Complex{Float64}, Array{Base.Complex{Float64}, 2}},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(LinearAlgebra.svd), Array{Base.Complex{Float64}, 2}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                LinearAlgebra.SVD{
                    Base.Complex{Float64},
                    Float64,
                    Array{Base.Complex{Float64}, 2},
                    Array{Float64, 1},
                },
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                Array{Base.Complex{Float64}, 2},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Int64,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.SymmetryOperation,
                Symbol,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._star_hamiltonian_residual_metrics,
                ),
                Array{Base.Complex{Float64}, 2},
                Array{Base.Complex{Float64}, 2},
                Array{Base.Complex{Float64}, 2},
                Bool,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 2}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.getindex), Array{Base.Complex{Float64}, 2}, Int64, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.abs), Base.Complex{Float64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.setindex!), Base.BitArray{2}, Bool, Int64, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(*)), Float64, Base.Complex{Float64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 2},
                    Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}},
                    false,
                },
                Int64,
                Int64,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.maximum), NTuple{5, Float64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.length),
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.findall),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#819#847"{
                    WannierNLQG.Wannierization.RepresentationProductTable,
                    Int64,
                },
                Base.OneTo{Int64},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.Iterators.only), Array{Int64, 1}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, Int64, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.empty), Base.Dict{Any, Any}, Type{Int64}, Type{Int64}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Int64, Int64},
                Base.Generator{
                    Base.Iterators.Enumerate{Array{Int64, 1}},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#779#790",
                },
                Tuple{Int64, Int64},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Int64, Int64, Int64},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{typeof(Base.empty), Base.Dict{String, Float64}, Type{String}, Type{Real}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.grow_to!),
                Base.Dict{String, Real},
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Real,
                        NTuple{6, Symbol},
                        NamedTuple{
                            (
                                :cap_ev,
                                :admitted,
                                :unresolved,
                                :maximum_component_bands,
                                :maximum_component_span_ev,
                                :cascade_edge_count,
                            ),
                            Tuple{Float64, Int64, Int64, Int64, Float64, Int64},
                        },
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#834#862",
                },
                Int64,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base._array_for),
                Type{Base.Dict{String, Real}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Base.Dict{String, Real}, 1},
                Base.Dict{String, Real},
                Base.Generator{
                    Array{
                        NamedTuple{
                            (
                                :cap_ev,
                                :admitted,
                                :unresolved,
                                :maximum_component_bands,
                                :maximum_component_span_ev,
                                :cascade_edge_count,
                            ),
                            Tuple{Float64, Int64, Int64, Int64, Float64, Int64},
                        },
                        1,
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#833#861",
                },
                Int64,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{Type{Pair{A, B} where {B} where A}, String, Array{Base.Dict{String, Real}, 1}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.add_sum), Int64, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(JSON3.defaultminimum), Array{Base.Dict{String, Real}, 1}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Base.MappingRF{
                    JSON3.var"#59#60"{Array{Base.Dict{String, Real}, 1}},
                    Base.MappingRF{
                        typeof(JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Base._InitialValue,
                Int64,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Base.MappingRF{
                    JSON3.var"#59#60"{Array{Base.Dict{String, Real}, 1}},
                    Base.MappingRF{
                        typeof(JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Int64,
                Int64,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.StringVector), Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(JSON3.write),
                StructTypes.ArrayType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Array{Base.Dict{String, Real}, 1},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(JSON3.write),
                StructTypes.DictType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Base.Dict{String, Real},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{String}, Array{UInt8, 1}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.add_sum), UInt64, UInt64}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(JSON3.write),
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Base.MappingRF{
                    JSON3.var"#59#60"{
                        JSON3.Array{
                            JSON3.Object{
                                S,
                                TT,
                            } where {
                                TT <: AbstractArray{UInt64, 1},
                            } where S <: AbstractArray{UInt8, 1},
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
                    Base.MappingRF{
                        typeof(JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Base._InitialValue,
                Int64,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Base.MappingRF{
                    JSON3.var"#59#60"{
                        JSON3.Array{
                            JSON3.Object{
                                S,
                                TT,
                            } where {
                                TT <: AbstractArray{UInt64, 1},
                            } where S <: AbstractArray{UInt8, 1},
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
                    Base.MappingRF{
                        typeof(JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Int64,
                Int64,
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.length),
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Array{UInt64, 1},
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.Iterators.enumerate),
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Array{UInt64, 1},
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{
                    JSON3.Array{
                        JSON3.Object{
                            S,
                            TT,
                        } where {
                            TT <: AbstractArray{UInt64, 1},
                        } where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Array{UInt64, 1},
                    },
                },
                Tuple{Int64},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{
                    JSON3.Array{
                        JSON3.Object{
                            S,
                            TT,
                        } where {
                            TT <: AbstractArray{UInt64, 1},
                        } where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Array{UInt64, 1},
                    },
                },
                Tuple{Int64, Tuple{Int64, Int64}},
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{Type{Array{Int64, 2}}, LinearAlgebra.Transpose{Int64, Array{Int64, 2}}}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Array{Base.Complex{Float64}, 2}},
                },
            }
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.setindex!), HDF5.Attributes, Int64, String}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.setindex!), HDF5.Attributes, Bool, String}
            push!(
                PAW_AUDIT_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
    end
end
