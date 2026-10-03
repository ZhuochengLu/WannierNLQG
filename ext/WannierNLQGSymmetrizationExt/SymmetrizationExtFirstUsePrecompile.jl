
# Compile expert entry signatures without executing file writes or MPI initialization.
@compile_workload begin
    if workload_enabled(parentmodule(SymmetrizationConfig))
        precompile(screen_wannier_mesh, (MeshScreenConfig,))
        precompile(symmetrize_wannier_operators, (SymmetrizationConfig,))
        # First successful existing-model expert call in the frozen fixture.
        precompile(
            Symmetrization.symmetrize_existing_wannier_model,
            (GaugeAwareSymmetrizationConfig,),
        )
        precompile(symmetrize_existing_wannier_model, (GaugeAwareSymmetrizationConfig,))
    end
end

# Real cold public-entry trace, compile only. No writes or MPI initialization.
_symmetrization_compile_call(f::F, args::Vararg{Any, N}) where {F, N} = Base.@noinline f(args...)
const FIRST_USE_SYMMETRIZATION_RESULTS = Tuple{Bool, Bool}[]
# Record direct and owned-bridge compilation without executing symmetrization.
function _record_symmetrization(@nospecialize(signature))
    direct = precompile(signature)
    bridge = precompile(Tuple{typeof(_symmetrization_compile_call), signature.parameters...})
    push!(FIRST_USE_SYMMETRIZATION_RESULTS, (direct, bridge))
    nothing
end
@compile_workload begin
    if workload_enabled(parentmodule(SymmetrizationConfig))
        _record_symmetrization(
            Tuple{
                Base.Filesystem.var"#_walkdir#35"{Bool, Bool, typeof(throw)},
                Base.Channel{Tuple{String, Array{String, 1}, Array{String, 1}}},
                String,
            },
        )
        _record_symmetrization(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        _record_symmetrization(
            Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64},
        )
        _record_symmetrization(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
        _record_symmetrization(Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}})
        _record_symmetrization(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        _record_symmetrization(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        _record_symmetrization(Tuple{Type{Array{Int8, N} where N}, UndefInitializer, Int64, Int64})
        _record_symmetrization(
            Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64, Int64},
        )
        _record_symmetrization(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64})
        _record_symmetrization(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
        _record_symmetrization(
            Tuple{
                Type{Base.Dict{K, V} where {V} where K},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, Any}},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Array{String, 1}},
                    Pair{String, Int64},
                    Pair{String, Array{Int64, 1}},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{
                        String,
                        Base.Dict{
                            String,
                            NamedTuple{
                                (:covariance_error, :idempotence_error),
                                Tuple{Float64, Float64},
                            },
                        },
                    },
                    Pair{String, Base.Dict{String, Any}},
                    Pair{String, String},
                },
            },
        )
        _record_symmetrization(
            Tuple{
                Type{Base.Dict{K, V} where {V} where K},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, Any}},
                },
            },
        )
        _record_symmetrization(
            Tuple{
                Type{
                    Base.Dict{
                        RealSpaceOperatorKind,
                        NamedTuple{
                            (:covariance_error, :idempotence_error),
                            Tuple{Float64, Float64},
                        },
                    },
                },
                Pair{
                    RealSpaceOperatorKind,
                    NamedTuple{(:covariance_error, :idempotence_error), Tuple{Float64, Float64}},
                },
                Vararg{
                    Pair{
                        RealSpaceOperatorKind,
                        NamedTuple{
                            (:covariance_error, :idempotence_error),
                            Tuple{Float64, Float64},
                        },
                    },
                },
            },
        )
        _record_symmetrization(
            Tuple{
                Type{Base.Dict{RealSpaceOperatorKind, RealSpaceOperator{N} where N}},
                Pair{RealSpaceOperatorKind, RealSpaceOperator{3}},
                Vararg{Pair{A, B} where {B} where A},
            },
        )
        _record_symmetrization(
            Tuple{
                Type{Base.Fix1{F, T} where {T} where F},
                Type{Base.MappingRF{F, T} where {T} where F},
                Type,
            },
        )
        _record_symmetrization(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGSymmetrizationExt.var"#188#189"{
                    NamedTuple{
                        (:input, :model, :operations, :basis, :plan, :projection),
                        Tuple{
                            WannierWinData,
                            TightBindingModel{
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 4},
                            },
                            Array{SymmetryOperation, 1},
                            WannierProjectionBasis,
                            WannierSymmetryPlan,
                            RealSpaceProjectionContext,
                        },
                    },
                },
                Base.ValueIterator{Base.Dict{RealSpaceOperatorKind, RealSpaceOperator{N} where N}},
            },
        )
        _record_symmetrization(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGSymmetrizationExt.var"#84#86"{
                    Array{Int64, 2},
                    Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                },
                Base.OneTo{Int64},
            },
        )
        _record_symmetrization(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                typeof(Base.identity),
                Base.Iterators.Filter{
                    WannierNLQGSymmetrizationExt.var"#15#18"{Array{RealSpaceOperatorKind, 1}},
                    NTuple{5, RealSpaceOperatorKind},
                },
            },
        )
        _record_symmetrization(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                typeof(Base.identity),
                Base.Iterators.Filter{
                    WannierNLQGSymmetrizationExt.var"#16#19"{Array{RealSpaceOperatorKind, 1}},
                    NTuple{4, RealSpaceOperatorKind},
                },
            },
        )
        _record_symmetrization(
            Tuple{
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                WannierNLQGSymmetrizationExt.var"#15#18"{Array{RealSpaceOperatorKind, 1}},
                NTuple{5, RealSpaceOperatorKind},
            },
        )
        _record_symmetrization(
            Tuple{
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                WannierNLQGSymmetrizationExt.var"#16#19"{Array{RealSpaceOperatorKind, 1}},
                NTuple{4, RealSpaceOperatorKind},
            },
        )
        _record_symmetrization(
            Tuple{
                Type{
                    Base.IteratorsMD.CartesianIndices{
                        N,
                        R,
                    } where {R <: Tuple{Vararg{Base.OrdinalRange{Int64, Int64}, N}}} where N,
                },
                Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}},
            },
        )
        _record_symmetrization(
            Tuple{
                Type{
                    Base.LinearIndices{
                        N,
                        R,
                    } where {R <: Tuple{Vararg{Base.AbstractUnitRange{Int64}, N}}} where N,
                },
                Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}},
            },
        )
        _record_symmetrization(Tuple{Type{Base.Set{T} where T}, Array{String, 1}})
        _record_symmetrization(
            Tuple{Type{Base.Set{T} where T}, Array{Tuple{Int64, Int64, Int64}, 1}},
        )
        _record_symmetrization(
            Tuple{
                Type{Base.Set{T} where T},
                Base.KeySet{
                    Tuple{Int64, Int64, Int64},
                    Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                },
            },
        )
        _record_symmetrization(
            Tuple{Type{NamedTuple{(:atol, :rtol), T} where T <: Tuple}, Tuple{Float64, Float64}},
        )
        _record_symmetrization(
            Tuple{Type{NamedTuple{(:init,), T} where T <: Tuple}, Tuple{Float64}},
        )
        _record_symmetrization(
            Tuple{Type{NamedTuple{(:prevalidated,), T} where T <: Tuple}, Tuple{Bool}},
        )
        _record_symmetrization(
            Tuple{
                Type{OperatorBundleManifest},
                String,
                Symbol,
                Array{RealSpaceOperatorKind, 1},
                Int64,
                Array{Float64, 2},
                Array{Int64, 2},
                Array{Int64, 1},
                Array{OperatorBundleIndexEntry, 1},
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
                Nothing,
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
        _record_symmetrization(
            Tuple{
                Type{Pair{A, B} where {B} where A},
                RealSpaceOperatorKind,
                NamedTuple{(:covariance_error, :idempotence_error), Tuple{Float64, Float64}},
            },
        )
        _record_symmetrization(
            Tuple{Type{Pair{A, B} where {B} where A}, RealSpaceOperatorKind, RealSpaceOperator{3}},
        )
        _record_symmetrization(
            Tuple{Type{Pair{A, B} where {B} where A}, RealSpaceOperatorKind, RealSpaceOperator{4}},
        )
        _record_symmetrization(
            Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Any}},
        )
        _record_symmetrization(Tuple{Type{Pair{A, B} where {B} where A}, String, Bool})
        _record_symmetrization(Tuple{Type{Pair{A, B} where {B} where A}, String, Nothing})
        _record_symmetrization(
            Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64},
        )
        _record_symmetrization(
            Tuple{
                Type{RealSpaceOperator{N} where N},
                RealSpaceOperatorSymmetrySpec,
                Array{Int64, 2},
                Base.SubArray{
                    Base.Complex{Float64},
                    3,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Array{Int64, 1},
                    },
                    false,
                },
            },
        )
        _record_symmetrization(
            Tuple{
                Type{RealSpaceOperator{N} where N},
                RealSpaceOperatorSymmetrySpec,
                Array{Int64, 2},
                Base.SubArray{
                    Base.Complex{Float64},
                    4,
                    Array{Base.Complex{Float64}, 4},
                    Tuple{
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Array{Int64, 1},
                    },
                    false,
                },
            },
        )
        _record_symmetrization(
            Tuple{
                Type{RealSpaceSymmetrizationResult{N} where N},
                RealSpaceOperator{3},
                Int64,
                Array{Int64, 2},
                Array{Int64, 1},
            },
        )
        _record_symmetrization(
            Tuple{
                Type{RealSpaceSymmetrizationResult{N} where N},
                RealSpaceOperator{4},
                Int64,
                Array{Int64, 2},
                Array{Int64, 1},
            },
        )
        _record_symmetrization(Tuple{Type{String}, Array{UInt8, 1}})
        _record_symmetrization(
            Tuple{
                Type{
                    TightBindingModel{
                        H,
                        P,
                    } where {
                        P <: AbstractArray{Base.Complex{Float64}, 4},
                    } where H <: AbstractArray{Base.Complex{Float64}, 3},
                },
                Array{Float64, 2},
                Int64,
                Int64,
                Array{Int64, 1},
                Array{Int64, 2},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 4},
            },
        )
        _record_symmetrization(Tuple{Type{UInt8}, RealSpaceOperatorKind})
        _record_symmetrization(Tuple{Type{UInt8}, UInt8})
        _record_symmetrization(
            Tuple{
                WannierNLQGSymmetrizationExt.var"#188#189"{
                    NamedTuple{
                        (:input, :model, :operations, :basis, :plan, :projection),
                        Tuple{
                            WannierWinData,
                            TightBindingModel{
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 4},
                            },
                            Array{SymmetryOperation, 1},
                            WannierProjectionBasis,
                            WannierSymmetryPlan,
                            RealSpaceProjectionContext,
                        },
                    },
                },
                RealSpaceOperator{3},
            },
        )
        _record_symmetrization(
            Tuple{
                WannierNLQGSymmetrizationExt.var"#188#189"{
                    NamedTuple{
                        (:input, :model, :operations, :basis, :plan, :projection),
                        Tuple{
                            WannierWinData,
                            TightBindingModel{
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 4},
                            },
                            Array{SymmetryOperation, 1},
                            WannierProjectionBasis,
                            WannierSymmetryPlan,
                            RealSpaceProjectionContext,
                        },
                    },
                },
                RealSpaceOperator{4},
            },
        )
        false
        _record_symmetrization(Tuple{typeof(Base.:(&)), Int64, Int64})
        _record_symmetrization(Tuple{typeof(Base.:(*)), Float64, Float64})
        _record_symmetrization(Tuple{typeof(Base.:(*)), Int64})
        _record_symmetrization(
            Tuple{
                typeof(Base.:(+)),
                Array{Base.Complex{Float64}, 1},
                Array{Base.Complex{Float64}, 1},
            },
        )
        _record_symmetrization(Tuple{typeof(Base.:(+)), Int64, UInt64})
        _record_symmetrization(Tuple{typeof(Base.:(-)), Int32, Int32})
        _record_symmetrization(Tuple{typeof(Base.:(<=)), Float64, Float64})
        _record_symmetrization(Tuple{typeof(Base.:(==)), Array{UInt64, 1}, Array{UInt64, 1}})
        _record_symmetrization(Tuple{typeof(Base.:(==)), Bool, Bool})
        _record_symmetrization(Tuple{typeof(Base.:(==)), Char, Char})
        _record_symmetrization(
            Tuple{typeof(Base.:(==)), Tuple{Int64, Int64, Int64}, Tuple{Int64, Int64, Int64}},
        )
        _record_symmetrization(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        _record_symmetrization(Tuple{typeof(Base.:(==)), UInt64, UInt64})
        _record_symmetrization(Tuple{typeof(Base.:(>)), Float64, Float64})
        _record_symmetrization(Tuple{typeof(Base.:(>)), Int64})
        false
        false
        _record_symmetrization(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(-)),
                Array{Base.Complex{Float64}, 1},
                Array{Base.Complex{Float64}, 1},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(-)),
                Base.Complex{Float64},
                Base.Complex{Float64},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.collect),
                Array{Tuple{Int64, Int64, Int64}, 1},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(real_space_operator_name),
                Array{RealSpaceOperatorKind, 1},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.Broadcast.instantiate),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{0},
                    Nothing,
                    typeof(Base.:(-)),
                    Tuple{Base.Complex{Float64}, Base.Complex{Float64}},
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.Broadcast.instantiate),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.:(-)),
                    Tuple{Array{Base.Complex{Float64}, 1}, Array{Base.Complex{Float64}, 1}},
                },
            },
        )
        false
        false
        _record_symmetrization(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.collect),
                    Tuple{Array{Tuple{Int64, Int64, Int64}, 1}},
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(real_space_operator_name),
                    Tuple{Array{RealSpaceOperatorKind, 1}},
                },
            },
        )
        _record_symmetrization(Tuple{typeof(Base.Broadcast.to_index), NTuple{4, Int64}})
        _record_symmetrization(Tuple{typeof(Base.Broadcast.to_index), Tuple{Int64, Int64, Int64}})
        _record_symmetrization(
            Tuple{typeof(Base.Iterators.enumerate), Array{Tuple{Int64, Int64, Int64}, 1}},
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.Iterators.enumerate),
                JSON3.Array{String, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base._all),
                Base.Fix2{typeof(Base.:(>)), Int64},
                Array{Int64, 1},
                Base.Colon,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base._any),
                WannierNLQGSymmetrizationExt.var"#17#20",
                Array{RealSpaceOperatorKind, 1},
                Base.Colon,
            },
        )
        false
        _record_symmetrization(
            Tuple{
                typeof(Base._array_for),
                Type{Tuple{Int64, Int64, Int64}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base._selectdim),
                Array{Base.Complex{Float64}, 3},
                Int64,
                Array{Int64, 1},
                Tuple{
                    Base.Slice{Base.OneTo{Int64}},
                    Base.Slice{Base.OneTo{Int64}},
                    Array{Int64, 1},
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base._selectdim),
                Array{Base.Complex{Float64}, 4},
                Int64,
                Array{Int64, 1},
                Tuple{
                    Base.Slice{Base.OneTo{Int64}},
                    Base.Slice{Base.OneTo{Int64}},
                    Base.Slice{Base.OneTo{Int64}},
                    Array{Int64, 1},
                },
            },
        )
        _record_symmetrization(Tuple{typeof(Base.abs), Float64})
        _record_symmetrization(Tuple{typeof(Base.abs), Int64})
        _record_symmetrization(Tuple{typeof(Base.add_sum), Int64, Int64})
        _record_symmetrization(Tuple{typeof(Base.add_sum), Int64, UInt64})
        _record_symmetrization(Tuple{typeof(Base.add_sum), UInt64, Int64})
        _record_symmetrization(Tuple{typeof(Base.add_sum), UInt64, UInt64})
        _record_symmetrization(Tuple{typeof(Base.all), Function, Core.SimpleVector})
        _record_symmetrization(Tuple{typeof(Base.any), Function, Array{RealSpaceOperatorKind, 1}})
        _record_symmetrization(
            Tuple{
                typeof(Base.append!),
                Array{Tuple{Int64, Int64, Int64}, 1},
                Array{Tuple{Int64, Int64, Int64}, 1},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.checkbounds),
                Type{Bool},
                Base.LinearIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
                Int64,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.Iterators.Filter{
                        WannierNLQGSymmetrizationExt.var"#15#18"{Array{RealSpaceOperatorKind, 1}},
                        NTuple{5, RealSpaceOperatorKind},
                    },
                    typeof(Base.identity),
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.Iterators.Filter{
                        WannierNLQGSymmetrizationExt.var"#16#19"{Array{RealSpaceOperatorKind, 1}},
                        NTuple{4, RealSpaceOperatorKind},
                    },
                    typeof(Base.identity),
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGSymmetrizationExt.var"#84#86"{
                        Array{Int64, 2},
                        Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                    },
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.ValueIterator{
                        Base.Dict{RealSpaceOperatorKind, RealSpaceOperator{N} where N},
                    },
                    WannierNLQGSymmetrizationExt.var"#188#189"{
                        NamedTuple{
                            (:input, :model, :operations, :basis, :plan, :projection),
                            Tuple{
                                WannierWinData,
                                TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
                                Array{SymmetryOperation, 1},
                                WannierProjectionBasis,
                                WannierSymmetryPlan,
                                RealSpaceProjectionContext,
                            },
                        },
                    },
                },
            },
        )
        _record_symmetrization(
            Tuple{typeof(Base.collect), Base.KeySet{String, Base.Dict{String, Any}}},
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.collect_to!),
                Array{RealSpaceSymmetrizationResult{N} where N, 1},
                Base.Generator{
                    Base.ValueIterator{
                        Base.Dict{RealSpaceOperatorKind, RealSpaceOperator{N} where N},
                    },
                    WannierNLQGSymmetrizationExt.var"#188#189"{
                        NamedTuple{
                            (:input, :model, :operations, :basis, :plan, :projection),
                            Tuple{
                                WannierWinData,
                                TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
                                Array{SymmetryOperation, 1},
                                WannierProjectionBasis,
                                WannierSymmetryPlan,
                                RealSpaceProjectionContext,
                            },
                        },
                    },
                },
                Int64,
                Int64,
            },
        )
        false
        _record_symmetrization(Tuple{typeof(Base.convert), Type{Float64}, Float64})
        _record_symmetrization(
            Tuple{
                typeof(Base.copy),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{0},
                    Nothing,
                    typeof(Base.:(-)),
                    Tuple{Base.Complex{Float64}, Base.Complex{Float64}},
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.copy),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Tuple{Base.OneTo{Int64}},
                    typeof(Base.:(-)),
                    Tuple{Array{Base.Complex{Float64}, 1}, Array{Base.Complex{Float64}, 1}},
                },
            },
        )
        _record_symmetrization(Tuple{typeof(Base.get), Base.Dict{String, Any}, String, String})
        _record_symmetrization(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        _record_symmetrization(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
        _record_symmetrization(
            Tuple{typeof(Base.getindex), Array{Tuple{Int64, Int64, Int64}, 1}, Array{Int64, 1}},
        )
        _record_symmetrization(
            Tuple{typeof(Base.getindex), Array{Tuple{Int64, Int64, Int64}, 1}, Int64},
        )
        _record_symmetrization(Tuple{typeof(Base.getindex), Array{UInt64, 1}, Int64})
        _record_symmetrization(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
        _record_symmetrization(
            Tuple{
                typeof(Base.getindex),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.getindex),
                Base.Dict{Tuple{Int64, Int64}, Base.Set{Tuple{Int64, Int64, Int64}}},
                Tuple{Int64, Int64},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.getindex),
                Type{SymmetryOperation},
                SymmetryOperation,
                SymmetryOperation,
            },
        )
        false
        _record_symmetrization(
            Tuple{typeof(Base.getindex), Type{WannierProjectionBlock}, WannierProjectionBlock},
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{typeof(Base.identity), typeof(Base.promote_type)},
                Symbol,
            },
        )
        _record_symmetrization(Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol})
        _record_symmetrization(
            Tuple{typeof(Base.getproperty), LinearAlgebra.UniformScaling{Bool}, Symbol},
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{(:chk, :eig, :mmn, :mmn_path, :spn), NTuple{5, Nothing}},
                Symbol,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{(:package, :version), Tuple{String, String}},
                Symbol,
            },
        )
        _record_symmetrization(Tuple{typeof(Base.getproperty), RealSpaceOperator{3}, Symbol})
        _record_symmetrization(Tuple{typeof(Base.getproperty), RealSpaceOperator{4}, Symbol})
        _record_symmetrization(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{String, Any},
                Tuple{
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Int64},
                    Pair{String, Array{Int64, 1}},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Int64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                },
                Int64,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{String, Any},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Array{Int64, 1}},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Int64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Nothing},
                    Pair{String, Float64},
                    Pair{String, Array{Float64, 2}},
                    Pair{String, Array{Float64, 2}},
                    Pair{String, Array{Float64, 2}},
                    Pair{String, Array{Float64, 2}},
                    Pair{String, Array{Float64, 2}},
                    Pair{String, Array{Float64, 2}},
                    Pair{String, Array{Float64, 2}},
                    Pair{String, Array{Int64, 2}},
                    Pair{String, Array{Float64, 1}},
                    Pair{String, Array{Float64, 1}},
                    Pair{String, Array{Float64, 1}},
                    Pair{String, Array{Float64, 1}},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Array{Int64, 2}},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Base.Dict{String, Float64}},
                    Pair{String, Base.Dict{String, Float64}},
                },
                Int64,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{String, Any},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, Any}},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Array{String, 1}},
                    Pair{String, Int64},
                    Pair{String, Array{Int64, 1}},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{
                        String,
                        Base.Dict{
                            String,
                            NamedTuple{
                                (:covariance_error, :idempotence_error),
                                Tuple{Float64, Float64},
                            },
                        },
                    },
                    Pair{String, Base.Dict{String, Any}},
                    Pair{String, String},
                },
                Int64,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.UnitRange{Int64},
                    WannierNLQGSymmetrizationExt.var"#83#85"{
                        TightBindingModel{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                        },
                    },
                },
                Int64,
            },
        )
        _record_symmetrization(
            Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId},
        )
        _record_symmetrization(Tuple{typeof(Base.haskey), Base.Dict{String, Any}, Symbol})
        _record_symmetrization(Tuple{typeof(Base.imag), Base.Complex{Float64}})
        _record_symmetrization(Tuple{typeof(Base.in), Char, Tuple{Char, Char}})
        _record_symmetrization(
            Tuple{typeof(Base.in), RealSpaceOperatorKind, Array{RealSpaceOperatorKind, 1}},
        )
        _record_symmetrization(Tuple{typeof(Base.in), String, NTuple{4, String}})
        _record_symmetrization(Tuple{typeof(Base.in), String, NTuple{5, String}})
        _record_symmetrization(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
        _record_symmetrization(Tuple{typeof(Base.in), String, Tuple{String, String}})
        _record_symmetrization(
            Tuple{typeof(Base.indexed_iterate), Pair{String, Bool}, Int64, Int64},
        )
        _record_symmetrization(Tuple{typeof(Base.indexed_iterate), Pair{String, Bool}, Int64})
        _record_symmetrization(
            Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64, Int64},
        )
        _record_symmetrization(Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64})
        _record_symmetrization(
            Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, String}, Int64}, Int64, Int64},
        )
        _record_symmetrization(
            Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, String}, Int64}, Int64},
        )
        _record_symmetrization(
            Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64, Int64},
        )
        _record_symmetrization(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64})
        _record_symmetrization(
            Tuple{typeof(Base.indexed_iterate), Tuple{String, String}, Int64, Int64},
        )
        _record_symmetrization(Tuple{typeof(Base.indexed_iterate), Tuple{String, String}, Int64})
        _record_symmetrization(Tuple{typeof(Base.isfinite), Float64})
        _record_symmetrization(
            Tuple{
                typeof(Base.issorted),
                Array{String, 1},
                Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
            },
        )
        _record_symmetrization(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
        _record_symmetrization(Tuple{typeof(Base.iterate), Array{RealSpaceOperatorKind, 1}, Int64})
        _record_symmetrization(Tuple{typeof(Base.iterate), Array{RealSpaceOperatorKind, 1}})
        false
        false
        _record_symmetrization(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{
                    JSON3.Array{String, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                },
                Tuple{Int64, Tuple{Int64, Int64}},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{
                    JSON3.Array{String, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                },
                Tuple{Int64},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.iterate),
                Base.IteratorsMD.CartesianIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
                Base.IteratorsMD.CartesianIndex{2},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.iterate),
                Base.IteratorsMD.CartesianIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.iterate),
                Base.KeySet{
                    RealSpaceOperatorKind,
                    Base.Dict{RealSpaceOperatorKind, RealSpaceOperator{N} where N},
                },
                Int64,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.iterate),
                Base.KeySet{
                    RealSpaceOperatorKind,
                    Base.Dict{RealSpaceOperatorKind, RealSpaceOperator{N} where N},
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.iterate),
                Base.LinearIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
                Int64,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.iterate),
                Base.LinearIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
            },
        )
        _record_symmetrization(
            Tuple{typeof(Base.iterate), Base.Set{Tuple{Int64, Int64, Int64}}, Int64},
        )
        _record_symmetrization(Tuple{typeof(Base.iterate), Base.Set{Tuple{Int64, Int64, Int64}}})
        _record_symmetrization(Tuple{typeof(Base.iterate), Pair{String, String}, Int64})
        _record_symmetrization(Tuple{typeof(Base.iterate), Pair{String, String}})
        _record_symmetrization(Tuple{typeof(Base.join), Array{String, 1}, String})
        _record_symmetrization(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Base.SubString{String}, 1},
                Char,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Int64, Int64, Int64},
                Char,
            },
        )
        _record_symmetrization(Tuple{typeof(Base.keys), Base.Dict{String, Any}})
        _record_symmetrization(
            Tuple{typeof(Base.keys), Base.Dict{Tuple{Int64, Int64, Int64}, Int64}},
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.last),
                Base.LinearIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
            },
        )
        _record_symmetrization(Tuple{typeof(Base.length), Array{Base.Complex{Float64}, 1}})
        _record_symmetrization(Tuple{typeof(Base.length), Array{Int64, 1}})
        _record_symmetrization(Tuple{typeof(Base.length), Array{RealSpaceOperatorKind, 1}})
        _record_symmetrization(Tuple{typeof(Base.length), Array{SymmetryOperation, 1}})
        _record_symmetrization(Tuple{typeof(Base.length), Array{Tuple{Int64, Int64, Int64}, 1}})
        _record_symmetrization(Tuple{typeof(Base.length), Array{UInt8, 1}})
        _record_symmetrization(
            Tuple{
                typeof(Base.length),
                JSON3.Array{String, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
            },
        )
        _record_symmetrization(
            Tuple{typeof(Base.map), typeof(Base.unchecked_oneto), Tuple{Int64, Int64}},
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.mapfoldl_impl),
                Type{Int64},
                typeof(Base.:(*)),
                Int64,
                Tuple{Int64, Int64},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.mapfoldl_impl),
                Type{Int64},
                typeof(Base.min),
                Int64,
                Tuple{Int64, Int64},
            },
        )
        _record_symmetrization(Tuple{typeof(Base.occursin), Base.Regex, String})
        _record_symmetrization(Tuple{typeof(Base.prod), Tuple{Int64, Int64}})
        _record_symmetrization(Tuple{typeof(Base.prod), Tuple{Int64}})
        _record_symmetrization(
            Tuple{
                typeof(Base.push!),
                Base.Set{Tuple{Int64, Int64, Int64}},
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_symmetrization(Tuple{typeof(Base.real), Base.Complex{Float64}})
        _record_symmetrization(
            Tuple{typeof(Base.reduce), typeof(Base.hcat), Array{Array{Int64, 1}, 1}},
        )
        _record_symmetrization(
            Tuple{typeof(Base.reverse), Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
        )
        _record_symmetrization(Tuple{typeof(Base.reverse), Tuple{Int64, Int64}})
        _record_symmetrization(
            Tuple{typeof(Base.selectdim), Array{Base.Complex{Float64}, 3}, Int64, Array{Int64, 1}},
        )
        _record_symmetrization(
            Tuple{typeof(Base.selectdim), Array{Base.Complex{Float64}, 4}, Int64, Array{Int64, 1}},
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.setdiff),
                Base.Set{Tuple{Int64, Int64, Int64}},
                Base.Set{Tuple{Int64, Int64, Int64}},
            },
        )
        _record_symmetrization(Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64})
        _record_symmetrization(Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64})
        _record_symmetrization(Tuple{typeof(Base.setindex!), Base.EnvDict, String, String})
        _record_symmetrization(Tuple{typeof(Base.setindex!), HDF5.Attributes, Bool, String})
        _record_symmetrization(Tuple{typeof(Base.setindex!), HDF5.Attributes, Int64, String})
        false
        _record_symmetrization(Tuple{typeof(Base.size), Array{Float64, 2}})
        _record_symmetrization(Tuple{typeof(Base.size), Array{Int64, 2}, Int64})
        _record_symmetrization(Tuple{typeof(Base.size), Array{Int64, 2}})
        _record_symmetrization(
            Tuple{
                typeof(Base.sum),
                Base.Generator{
                    Base.Dict{
                        String,
                        NamedTuple{
                            (:covariance_error, :idempotence_error),
                            Tuple{Float64, Float64},
                        },
                    },
                    JSON3.var"#61#62",
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Base.tail),
                Tuple{Base.IteratorsMD.CartesianIndex{2}, Base.IteratorsMD.CartesianIndex{2}},
            },
        )
        _record_symmetrization(
            Tuple{typeof(Base.to_shape), Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}},
        )
        _record_symmetrization(Tuple{typeof(Base.top_set_bit), UInt64})
        _record_symmetrization(Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}})
        false
        false
        _record_symmetrization(Tuple{typeof(Core._checked_mul_dims), Int64, Int64})
        _record_symmetrization(Tuple{typeof(Core.checked_dims), Int64, Int64, Vararg{Int64}})
        _record_symmetrization(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:init,), Tuple{Int64}},
                typeof(Base.mapreduce),
                Type,
                Function,
                Tuple{Int64, Int64},
            },
        )
        _record_symmetrization(
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
                    Tuple{
                        Symbol,
                        Bool,
                        String,
                        Base.Dict{String, Any},
                        Base.Dict{String, Any},
                        Base.Dict{String, Any},
                        Base.Dict{
                            String,
                            Base.Dict{
                                String,
                                NamedTuple{
                                    (:covariance_error, :idempotence_error),
                                    Tuple{Float64, Float64},
                                },
                            },
                        },
                    },
                },
                typeof(write_real_space_operator_bundle),
                String,
                Array{Float64, 2},
                Array{Int64, 1},
                Base.Dict{RealSpaceOperatorKind, RealSpaceOperator{N} where N},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{:not_atomic, OperatorBundleIndexEntry, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{:not_atomic, RealSpaceOperatorKind, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{:not_atomic, SymmetryOperation, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties},
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties},
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties},
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties},
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties},
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties},
        )
        _record_symmetrization(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties},
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties},
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties},
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties},
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties},
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties},
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties},
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties},
        )
        _record_symmetrization(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties},
        )
        _record_symmetrization(Tuple{typeof(JSON3.defaultminimum), Array{Float64, 1}})
        _record_symmetrization(Tuple{typeof(JSON3.defaultminimum), Array{Float64, 2}})
        _record_symmetrization(Tuple{typeof(JSON3.defaultminimum), Array{Int64, 1}})
        _record_symmetrization(Tuple{typeof(JSON3.defaultminimum), Array{Int64, 2}})
        _record_symmetrization(Tuple{typeof(JSON3.defaultminimum), Array{String, 1}})
        _record_symmetrization(Tuple{typeof(JSON3.defaultminimum), Base.Dict{String, Any}})
        _record_symmetrization(Tuple{typeof(JSON3.defaultminimum), Base.Dict{String, Float64}})
        _record_symmetrization(
            Tuple{
                typeof(JSON3.defaultminimum),
                Base.Dict{
                    String,
                    NamedTuple{(:covariance_error, :idempotence_error), Tuple{Float64, Float64}},
                },
            },
        )
        _record_symmetrization(Tuple{typeof(JSON3.defaultminimum), Base.Dict{String, String}})
        _record_symmetrization(
            Tuple{typeof(JSON3.pretty), Base.IOStream, String, JSON3.AlignmentContext},
        )
        _record_symmetrization(
            Tuple{
                typeof(JSON3.write),
                JSON3.Array{
                    String,
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(JSON3.write),
                JSON3.Object{
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(JSON3.write),
                JSON3.StructTypes.ArrayType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Array{Float64, 1},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(JSON3.write),
                JSON3.StructTypes.ArrayType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Array{Float64, 2},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(JSON3.write),
                JSON3.StructTypes.ArrayType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Array{Int64, 1},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(JSON3.write),
                JSON3.StructTypes.ArrayType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Array{Int64, 2},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(JSON3.write),
                JSON3.StructTypes.ArrayType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Array{String, 1},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(JSON3.write),
                JSON3.StructTypes.DictType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Base.Dict{String, Float64},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(JSON3.write),
                JSON3.StructTypes.DictType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Base.Dict{
                    String,
                    NamedTuple{(:covariance_error, :idempotence_error), Tuple{Float64, Float64}},
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(JSON3.write),
                JSON3.StructTypes.DictType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Base.Dict{String, String},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Printf.format),
                Array{UInt8, 1},
                Int64,
                Printf.Format{
                    Base.CodeUnits{UInt8, String},
                    Tuple{
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
        _record_symmetrization(
            Tuple{
                typeof(Printf.format),
                Array{UInt8, 1},
                Int64,
                Printf.Format{
                    Base.CodeUnits{UInt8, String},
                    Tuple{
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                    },
                },
                Float64,
                Vararg{Float64},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Printf.format),
                Base.IOStream,
                Printf.Format{
                    Base.CodeUnits{UInt8, String},
                    Tuple{
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                    },
                },
                Float64,
                Float64,
                Vararg{Float64},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._build_symmetrization_context),
                SymmetrizationConfig,
                NamedTuple{
                    (
                        :families,
                        :win,
                        :tb,
                        :chk,
                        :eig,
                        :mmn,
                        :spn,
                        :output_tb,
                        :operator_bundle,
                        :report,
                        :checksums,
                    ),
                    Tuple{
                        NamedTuple{
                            (
                                :profile,
                                :selected_operator_kinds,
                                :derivative,
                                :spin,
                                :spin_velocity,
                            ),
                            Tuple{
                                Symbol,
                                Array{RealSpaceOperatorKind, 1},
                                Array{RealSpaceOperatorKind, 1},
                                Array{RealSpaceOperatorKind, 1},
                                Bool,
                            },
                        },
                        String,
                        String,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Vararg{String, 4},
                    },
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._geometry_metadata),
                WannierNLQGSymmetrizationExt.WannierCenterGeometry,
                Array{Float64, 2},
                Array{Float64, 2},
                RealSpaceReplicaPolicyResult,
                NamedTuple{
                    (:input, :model, :operations, :basis, :plan, :projection),
                    Tuple{
                        WannierWinData,
                        TightBindingModel{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                        },
                        Array{SymmetryOperation, 1},
                        WannierProjectionBasis,
                        WannierSymmetryPlan,
                        RealSpaceProjectionContext,
                    },
                },
                SymmetrizationConfig,
                Nothing,
                Float64,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._input_file_evidence),
                NamedTuple{
                    (
                        :families,
                        :win,
                        :tb,
                        :chk,
                        :eig,
                        :mmn,
                        :spn,
                        :output_tb,
                        :operator_bundle,
                        :report,
                        :checksums,
                    ),
                    Tuple{
                        NamedTuple{
                            (
                                :profile,
                                :selected_operator_kinds,
                                :derivative,
                                :spin,
                                :spin_velocity,
                            ),
                            Tuple{
                                Symbol,
                                Array{RealSpaceOperatorKind, 1},
                                Array{RealSpaceOperatorKind, 1},
                                Array{RealSpaceOperatorKind, 1},
                                Bool,
                            },
                        },
                        String,
                        String,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Vararg{String, 4},
                    },
                },
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._operator_maximum_difference),
                RealSpaceOperator{3},
                RealSpaceOperator{3},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._operator_maximum_difference),
                RealSpaceOperator{4},
                RealSpaceOperator{4},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._position_operator_with_wannier_centers),
                RealSpaceOperator{4},
                Array{Float64, 2},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._symmetrize_spin_family),
                NamedTuple{
                    (:input, :model, :operations, :basis, :plan, :projection),
                    Tuple{
                        WannierWinData,
                        TightBindingModel{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                        },
                        Array{SymmetryOperation, 1},
                        WannierProjectionBasis,
                        WannierSymmetryPlan,
                        RealSpaceProjectionContext,
                    },
                },
                NamedTuple{
                    (:model, :operators, :validation, :center_geometry, :generated_num_r_vectors),
                    Tuple{
                        TightBindingModel{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                        },
                        Base.Dict{RealSpaceOperatorKind, RealSpaceOperator{N} where N},
                        Base.Dict{
                            RealSpaceOperatorKind,
                            NamedTuple{
                                (:covariance_error, :idempotence_error),
                                Tuple{Float64, Float64},
                            },
                        },
                        WannierNLQGSymmetrizationExt.WannierCenterGeometry,
                        Int64,
                    },
                },
                NamedTuple{(:chk, :eig, :mmn, :mmn_path, :spn), NTuple{5, Nothing}},
                Nothing,
                Array{RealSpaceOperatorKind, 1},
                SymmetrizationConfig,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._symmetrize_tight_binding_operators),
                NamedTuple{
                    (:input, :model, :operations, :basis, :plan, :projection),
                    Tuple{
                        WannierWinData,
                        TightBindingModel{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                        },
                        Array{SymmetryOperation, 1},
                        WannierProjectionBasis,
                        WannierSymmetryPlan,
                        RealSpaceProjectionContext,
                    },
                },
                SymmetrizationConfig,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._symmetrize_wannier_derivative_operators),
                NamedTuple{
                    (:input, :model, :operations, :basis, :plan, :projection),
                    Tuple{
                        WannierWinData,
                        TightBindingModel{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                        },
                        Array{SymmetryOperation, 1},
                        WannierProjectionBasis,
                        WannierSymmetryPlan,
                        RealSpaceProjectionContext,
                    },
                },
                NamedTuple{
                    (:model, :operators, :validation, :center_geometry, :generated_num_r_vectors),
                    Tuple{
                        TightBindingModel{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                        },
                        Base.Dict{RealSpaceOperatorKind, RealSpaceOperator{N} where N},
                        Base.Dict{
                            RealSpaceOperatorKind,
                            NamedTuple{
                                (:covariance_error, :idempotence_error),
                                Tuple{Float64, Float64},
                            },
                        },
                        WannierNLQGSymmetrizationExt.WannierCenterGeometry,
                        Int64,
                    },
                },
                NamedTuple{(:chk, :eig, :mmn, :mmn_path, :spn), NTuple{5, Nothing}},
                Nothing,
                Array{RealSpaceOperatorKind, 1},
                SymmetrizationConfig,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._symmetrized_tight_binding_model),
                TightBindingModel{Array{Base.Complex{Float64}, 3}, Array{Base.Complex{Float64}, 4}},
                RealSpaceSymmetrizationResult{3},
                RealSpaceSymmetrizationResult{4},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._validate_symmetrized_operator),
                RealSpaceSymmetrizationResult{3},
                RealSpaceProjectionContext,
                SymmetrizationConfig,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._validate_symmetrized_operator),
                RealSpaceSymmetrizationResult{4},
                RealSpaceProjectionContext,
                SymmetrizationConfig,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(WannierNLQGSymmetrizationExt._write_symmetrization_report),
                SymmetrizationConfig,
                String,
                Base.Dict{String, Any},
            },
        )
    end
end
