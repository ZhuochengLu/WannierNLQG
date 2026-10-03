# Observed gauge-chain signatures: compile only, never execute writers.
const GAUGE_CHAIN_COVERAGE_RESULTS = Tuple{Bool, Bool}[]
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let signature = Tuple{
                typeof(WannierNLQG.Wannierization.diagnose_wannier_gauge_chain),
                WannierNLQG.Wannierization.WannierGaugeChainDiagnosticConfig,
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
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
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
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
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (false, false))
        end
        let signature = Tuple{typeof(Base.iterate), Array{Union{Nothing, Array{String, 1}}, 1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (false, false))
        end
        let signature =
                Tuple{typeof(Base.iterate), Array{Union{Nothing, Array{String, 1}}, 1}, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (false, false))
        end
        let signature = Tuple{typeof(Base.isempty), Base.UnitRange{Int64}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{NamedTuple{(:init,), T} where T <: Tuple}, Tuple{Float64}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(==)), Char, Char}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.iszero), Bool}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(&)), Int64, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{typeof(Base.abs), typeof(Base.min)},
                Symbol,
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Type{
                    NamedTuple{(:wigner_seitz_tolerance, :search_size, :label), T} where T <: Tuple,
                },
                Tuple{Float64, Int64, String},
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Type{NamedTuple{(:support_tolerance, :label), T} where T <: Tuple},
                Tuple{Float64, String},
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.real), Base.Complex{Float64}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.imag), Base.Complex{Float64}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.float), Float64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.abs), Float64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.isinf), Float64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(>)), Float64, Float64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(/)), Float64, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(*)), Float64, Float64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(<=)), Float64, Float64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{typeof(LinearAlgebra.norm), Base.BottomRF{typeof(Base.max)}},
                Symbol,
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    Base.ComposedFunction{typeof(Base.float), typeof(LinearAlgebra.norm)},
                    Base.BottomRF{typeof(Base.:(+))},
                },
                Symbol,
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), Tuple{Int64, Int64}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{typeof(LinearAlgebra.norm), Base.BottomRF{typeof(Base.min)}},
                Symbol,
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{16, Symbol}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{15, Symbol}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{14, Symbol}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{13, Symbol}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{12, Symbol}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{11, Symbol}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{10, Symbol}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{9, Symbol}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{8, Symbol}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{7, Symbol}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{6, Symbol}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{5, Symbol}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.tail), NTuple{4, Symbol}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{typeof(Base._similar_shape), Base.StepRange{Int64, Int64}, Base.HasShape{1}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport.diagnose_wannier_gauge_chain),
                WannierNLQG.Wannierization.WannierGaugeChainDiagnosticConfig,
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.empty), Base.Dict{Any, Any}, Type{String}, Type{String}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.grow_to!),
                Base.Dict{String, String},
                Base.Generator{
                    Base.Dict{String, String},
                    WannierNLQGWannierizationExt.OperatorExport.var"#211#214",
                },
                Int64,
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.prod), Tuple{Int64}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.in), String, Tuple{String, String}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Int64,
                Int64,
                Int64,
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.Broadcast.broadcasted), Type{String}, Array{String, 1}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
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
                    Type{String},
                    Tuple{Array{String, 1}},
                },
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.eachindex), Array{Int64, 1}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Bool}, UInt8}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 1}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
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
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Tuple}, Array{Float64, 1}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.length), Array{Float64, 1}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Array{Float64, 1}}, Array{Float64, 1}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{11, String}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                NTuple{4, Int64},
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{8, String}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base._array_for),
                Type{Symbol},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Base.BitArray{2}}, Base.BitArray{2}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{255, 0}},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (false, false))
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{4, String}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(==)), Bool, Bool}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{6, String}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{5, String}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.in), String, Tuple{String, String, String}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.unique), Array{String, 1}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Int64,
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Array{Float64, 1},
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
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
                    Tuple{Int64, Int64, Float64},
                    Core.AddrSpace{Core}(0x00),
                },
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Type{Array{T, 2} where T},
                LinearAlgebra.Transpose{Float64, Array{Float64, 2}},
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (:conventions, :input_sha256),
                    Tuple{Base.Dict{String, String}, Base.Dict{String, String}},
                },
                Type{WannierNLQG.SymmetryFoundation.BandRepresentation},
                String,
                Symbol,
                Bool,
                Array{Float64, 2},
                Array{Float64, 2},
                Tuple{Int64, Int64, Int64},
                Array{Float64, 2},
                Array{Float64, 2},
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Array{Int64, 2},
                Array{Int64, 3},
                Array{Base.Complex{Float64}, 4},
                Array{Int64, 2},
                Array{Int64, 1},
                Array{Int64, 1},
                Array{Int64, 1},
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Int64, 1},
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.size), Base.BitArray{2}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.:(!)), Base.BitArray{2}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(|)),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(!)),
                    Tuple{Base.BitArray{2}},
                },
                Base.BitArray{2},
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(|)),
                    Tuple{
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{2},
                            Nothing,
                            typeof(Base.:(!)),
                            Tuple{Base.BitArray{2}},
                        },
                        Base.BitArray{2},
                    },
                },
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.size), Array{Int64, 2}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.size), Array{Float64, 2}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.length), Array{UInt8, 1}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Bool}, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature =
                Tuple{typeof(Base.:(==)), Tuple{Int64, Int64, Int64}, Tuple{Int64, Int64, Int64}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.get), Base.Dict{String, String}, String, String}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                WannierNLQGWannierizationExt.OperatorExport.var"#119#122"{
                    WannierNLQG.IO.WannierCHK,
                },
                Array{Base.Complex{Float64}, 3},
                String,
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                WannierNLQGWannierizationExt.OperatorExport.var"#119#122"{
                    WannierNLQG.IO.WannierCHK,
                },
                Array{Base.Complex{Float64}, 4},
                String,
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Base.SubString{String}, 1},
                Char,
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WannierizationInternalSupport.atomic_hdf5_write,
                ),
                WannierNLQGWannierizationExt.OperatorExport.var"#212#215"{
                    Base.Dict{String, String},
                    Symbol,
                    Array{Float64, 3},
                    Array{Float64, 3},
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
                    Array{Base.Complex{Float64}, 3},
                    Array{Int64, 2},
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
                    Array{Base.Complex{Float64}, 3},
                    Array{Int64, 2},
                    Array{Base.Complex{Float64}, 3},
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Array{Float64, 2},
                    WannierNLQG.Wannierization.WannierGaugeLinkDiagnostics,
                    Base.Dict{String, String},
                },
                String,
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, String}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                Type{Base.Dict{K, V} where {V} where K},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, String}},
                    Pair{String, Base.Dict{String, String}},
                    Pair{String, String},
                },
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport._atomic_gauge_chain_json),
                String,
                Base.Dict{String, Any},
            }
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.add_sum), Int64, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.StringVector), Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
        let signature = Tuple{typeof(Base.write), Base.IOStream, Array{UInt8, 1}}
            push!(
                GAUGE_CHAIN_COVERAGE_RESULTS,
                (
                    precompile(signature),
                    precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
                ),
            )
        end
    end
end
