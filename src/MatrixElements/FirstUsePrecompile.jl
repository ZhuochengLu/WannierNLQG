using PrecompileTools: @compile_workload, workload_enabled
import ..IO: PackedCartesianOperator

# Private matrix signatures stay in their owning layer. No higher-layer dependency.
_matrix_first_compile_call(f::F, args::Vararg{Any, N}) where {F, N} = Base.@noinline f(args...)
const FIRST_USE_MATRIX_RESULTS = Tuple{Bool, Bool}[]
# Record direct and bridge compilation for private matrix-layer signatures.
function _record_matrix_first_use(@nospecialize(signature))
    push!(
        FIRST_USE_MATRIX_RESULTS,
        (
            precompile(signature),
            precompile(Tuple{typeof(_matrix_first_compile_call), signature.parameters...}),
        ),
    )
    nothing
end
@compile_workload begin
    if parentmodule(@__MODULE__).FIRST_USE_TRACE_COMPATIBLE &&
       workload_enabled(parentmodule(@__MODULE__))
        false
        false
        false
        false
        _record_matrix_first_use(
            Tuple{
                typeof(_materialize_replica_component),
                Array{Base.Complex{Float64}, 3},
                Array{Int64, 1},
                RealSpaceReplicaMap,
                SerializedWannier90ReplicaValues,
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
            },
        )
        _record_matrix_first_use(
            Tuple{
                typeof(_materialize_replica_component),
                Base.SubArray{
                    Base.Complex{Float64},
                    3,
                    Array{Base.Complex{Float64}, 4},
                    Tuple{
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Int64,
                        Base.Slice{Base.OneTo{Int64}},
                    },
                    false,
                },
                Array{Int64, 1},
                RealSpaceReplicaMap,
                SerializedWannier90ReplicaValues,
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
            },
        )
        _record_matrix_first_use(Tuple{typeof(_mixed_group_kind), Symbol})
        false
        false
        false
        _record_matrix_first_use(
            Tuple{
                typeof(_materialize_replica_component),
                Base.ReshapedArray{
                    Base.Complex{Float64},
                    3,
                    Base.SubArray{
                        Base.Complex{Float64},
                        1,
                        Base.ReinterpretArray{
                            Base.Complex{Float64},
                            1,
                            UInt8,
                            Array{UInt8, 1},
                            false,
                        },
                        Tuple{Base.UnitRange{Int64}},
                        true,
                    },
                    Tuple{},
                },
                Array{Int64, 1},
                RealSpaceReplicaMap,
                SerializedWannier90ReplicaValues,
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
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
        _record_matrix_first_use(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{var"#123#124", Base.BottomRF{typeof(Base.hcat)}},
                Symbol,
            },
        )
        _record_matrix_first_use(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{var"#92#94", Base.BottomRF{typeof(Base.add_sum)}},
                Symbol,
            },
        )
        _record_matrix_first_use(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.By{var"#88#89", Base.Order.ForwardOrdering},
                Symbol,
            },
        )
        _record_matrix_first_use(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.Lt{
                    Base.Sort.var"#30#31"{Base.Order.By{var"#88#89", Base.Order.ForwardOrdering}},
                },
                Symbol,
            },
        )
        _record_matrix_first_use(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{Base.OneTo{Int64}, var"#130#131"{RealSpaceReplicaMap}},
                Int64,
            },
        )
        false
        false
        false
        false
        _record_matrix_first_use(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                var"#12#13",
                UInt64,
                NTuple{4, MatrixElementKind},
            },
        )
        _record_matrix_first_use(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                var"#12#13",
                UInt64,
                Tuple{MatrixElementKind},
            },
        )
        _record_matrix_first_use(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                var"#12#13",
                UInt64,
                NTuple{5, MatrixElementKind},
            },
        )
        false
        _record_matrix_first_use(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                var"#12#13",
                UInt64,
                Tuple{MatrixElementKind, MatrixElementKind},
            },
        )
        _record_matrix_first_use(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.Iterators.Filter{
                        var"#142#145"{Base.Dict{Tuple{Int64, Int64, Int64}, Int64}},
                        Array{Tuple{Int64, Int64, Int64}, 1},
                    },
                    var"#141#144"{Base.Dict{Tuple{Int64, Int64, Int64}, Int64}},
                },
            },
        )
        _record_matrix_first_use(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{Base.OneTo{Int64}, var"#140#143"{Array{Int64, 2}}},
                Int64,
            },
        )
        _record_matrix_first_use(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{Base.OneTo{Int64}, var"#152#154"{Array{Int64, 2}}},
                Int64,
            },
        )
        false
        false
        false
        false
        false
        false
        _record_matrix_first_use(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{Base.OneTo{Int64}, var"#140#143"{Array{Int64, 2}}},
                Int64,
            },
        )
        _record_matrix_first_use(
            Tuple{
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                var"#142#145"{Base.Dict{Tuple{Int64, Int64, Int64}, Int64}},
                Array{Tuple{Int64, Int64, Int64}, 1},
            },
        )
        _record_matrix_first_use(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                var"#141#144"{Base.Dict{Tuple{Int64, Int64, Int64}, Int64}},
                Base.Iterators.Filter{
                    var"#142#145"{Base.Dict{Tuple{Int64, Int64, Int64}, Int64}},
                    Array{Tuple{Int64, Int64, Int64}, 1},
                },
            },
        )
        _record_matrix_first_use(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.Iterators.Filter{
                        var"#142#145"{Base.Dict{Tuple{Int64, Int64, Int64}, Int64}},
                        Array{Tuple{Int64, Int64, Int64}, 1},
                    },
                    var"#141#144"{Base.Dict{Tuple{Int64, Int64, Int64}, Int64}},
                },
            },
        )
        _record_matrix_first_use(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{Base.OneTo{Int64}, var"#152#154"{Array{Int64, 2}}},
                Int64,
            },
        )
    end
end

# Preserve the observed private transform specialization in its unique owner.
@compile_workload begin
    if workload_enabled(parentmodule(@__MODULE__))
        precompile(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:support_tolerance, :label), Tuple{Float64, String}},
                typeof(_wannier_q_to_pair_wigner_seitz),
                Array{Base.Complex{Float64}, 4},
                WannierCHK,
                WannierPairWignerSeitzTransformPlan,
            },
        )
    end
end
