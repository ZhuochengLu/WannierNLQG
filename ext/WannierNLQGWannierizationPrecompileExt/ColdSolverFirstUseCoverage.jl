# Observed cold public solve signatures, including real MPI rank paths.
# Compile only: no solve, MPI initialization, or persistent external resource.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_sequence(
            Tuple{
                Base.MappingRF{
                    JSON3.var"#59#60"{Array{Base.Dict{String, Any}, 1}},
                    Base.MappingRF{
                        typeof(JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Base._InitialValue,
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                Base.MappingRF{
                    JSON3.var"#59#60"{Array{Base.Dict{String, Any}, 1}},
                    Base.MappingRF{
                        typeof(JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Int64,
                Int64,
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                NTuple{4, Int64},
            },
        )
        _record_sequence(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        _record_sequence(
            Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64, Int64},
        )
        _record_sequence(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}})
        _record_sequence(
            Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64, Int64},
        )
        _record_sequence(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Array{Int8, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(
            Tuple{Type{Array{T, 2} where T}, LinearAlgebra.Transpose{Float64, Array{Float64, 2}}},
        )
        _record_sequence(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Base.Dict{String, String}}, Tuple{Pair{String, String}}})
        _record_sequence(Tuple{Type{Base.Set{T} where T}, Array{String, 1}})
        _record_sequence(Tuple{Type{Bool}, Int64})
        _record_sequence(
            Tuple{
                Type{
                    GenericMemory{
                        :not_atomic,
                        Array{Base.Complex{Float64}, 2},
                        Core.AddrSpace{Core}(0x00),
                    },
                },
                UndefInitializer,
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                Type{GenericMemory{:not_atomic, Base.BitArray{1}, Core.AddrSpace{Core}(0x00)}},
                UndefInitializer,
                Int64,
            },
        )
        _record_sequence(
            Tuple{Type{NamedTuple{(:construction_policy,), T} where T <: Tuple}, Tuple{Symbol}},
        )
        _record_sequence(
            Tuple{
                Type{NamedTuple{(:retained_disentanglement_nonconverged,), T} where T <: Tuple},
                Tuple{Bool},
            },
        )
        _record_sequence(Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Any}})
        _record_sequence(
            Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, String}},
        )
        _record_sequence(
            Tuple{
                Type{Pair{A, B} where {B} where A},
                String,
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Array{UInt64, 1},
                },
            },
        )
        _record_sequence(
            Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64},
        )
        _record_sequence(
            Tuple{
                Type{Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}}},
                Bool,
                Bool,
                Bool,
                Bool,
                Bool,
                Int64,
                Int64,
                Bool,
                Bool,
            },
        )
        _record_sequence(Tuple{Type{String}, Array{UInt8, 1}})
        _record_sequence(Tuple{Type{UInt8}, UInt8})
        _record_sequence(Tuple{Type{UInt8}, WannierNLQG.Core.RealSpaceOperatorKind})
        _record_sequence(Tuple{typeof(Base.:(*)), Array{Float64, 2}, Array{Float64, 2}})
        _record_sequence(Tuple{typeof(Base.:(/)), Base.Complex{Float64}, Int64})
        _record_sequence(Tuple{typeof(Base.:(<=)), Float64, Float64})
        _record_sequence(
            Tuple{
                typeof(Base.:(==)),
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.:(==)),
                Array{Base.Complex{Float64}, 4},
                Array{Base.Complex{Float64}, 4},
            },
        )
        _record_sequence(Tuple{typeof(Base.:(==)), Array{Int64, 1}, Array{Int64, 1}})
        _record_sequence(Tuple{typeof(Base.:(==)), Array{Int64, 2}, Array{Int64, 2}})
        _record_sequence(Tuple{typeof(Base.:(==)), Array{UInt64, 1}, Array{UInt64, 1}})
        _record_sequence(Tuple{typeof(Base.:(==)), Bool, Bool})
        _record_sequence(
            Tuple{typeof(Base.:(==)), Tuple{Int64, Int64, Int64}, Tuple{Int64, Int64, Int64}},
        )
        _record_sequence(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        _record_sequence(Tuple{typeof(Base.:(==)), UInt64, UInt64})
        _record_sequence(Tuple{typeof(Base.:(>)), Float64, Float64})
        _record_sequence(Tuple{typeof(Base.Broadcast.broadcasted), Type{Int64}, Array{Int64, 2}})
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(<)),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.abs),
                    Tuple{Array{Float64, 2}},
                },
                Float64,
            },
        )
        _record_sequence(
            Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.abs), Array{Float64, 2}},
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(WannierNLQG.Core.real_space_operator_name),
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{Float64, 1, Array{Float64, 1}, Tuple{Array{Int64, 1}}, false},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{0},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Float64},
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(WannierNLQG.Core.real_space_operator_name),
                    Tuple{Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    Type{Int64},
                    Tuple{Array{Int64, 2}},
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(<)),
                    Tuple{
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{2},
                            Nothing,
                            typeof(Base.abs),
                            Tuple{Array{Float64, 2}},
                        },
                        Float64,
                    },
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Order.lt),
                Base.Order.ForwardOrdering,
                Tuple{Int64, String},
                Tuple{Int64, String},
            },
        )
        _record_sequence(Tuple{typeof(Base.StringVector), Int64})
        _record_sequence(
            Tuple{
                typeof(Base._all),
                Base.Fix2{typeof(Base.:(>)), Int64},
                Array{Int64, 1},
                Base.Colon,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base._all),
                typeof(Base.isfinite),
                Array{Base.Complex{Float64}, 3},
                Base.Colon,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base._all),
                typeof(Base.isfinite),
                Array{Base.Complex{Float64}, 4},
                Base.Colon,
            },
        )
        _record_sequence(Tuple{typeof(Base.add_sum), Int64, Int64})
        _record_sequence(Tuple{typeof(Base.add_sum), UInt64, UInt64})
        _record_sequence(
            Tuple{
                typeof(Base.adjoint),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.adjoint),
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
        _record_sequence(Tuple{typeof(Base.all), Base.BitArray{2}})
        _record_sequence(Tuple{typeof(Base.axes), Array{Base.Complex{Float64}, 2}, Int64})
        _record_sequence(Tuple{typeof(Base.axes), Array{Int64, 3}, Int64})
        _record_sequence(Tuple{typeof(Base.collect), Base.KeySet{String, Base.Dict{String, Any}}})
        _record_sequence(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Nothing, 1},
                Nothing,
                Base.Generator{
                    NTuple{21, Symbol},
                    WannierNLQG.Wannierization.var"#101#102"{
                        WannierNLQG.Wannierization.WannierizationOutputConfig,
                    },
                },
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Nothing, 1},
                Nothing,
                Base.Generator{
                    NTuple{4, Symbol},
                    WannierNLQG.Wannierization.var"#101#102"{
                        WannierNLQG.Wannierization.WannierizationCheckpointConfig,
                    },
                },
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.copy),
                GenericMemory{:not_atomic, Base.Complex{Float64}, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.copy),
                GenericMemory{:not_atomic, UInt64, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_sequence(Tuple{typeof(Base.eachindex), Array{Float64, 1}})
        _record_sequence(
            Tuple{typeof(Base.empty), Base.Dict{String, String}, Type{String}, Type{Any}},
        )
        _record_sequence(Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}})
        _record_sequence(Tuple{typeof(Base.falses), Tuple{Int64, Int64}})
        _record_sequence(
            Tuple{typeof(Base.get), Base.Dict{String, Any}, String, Base.Dict{String, Any}},
        )
        _record_sequence(Tuple{typeof(Base.get), Base.Dict{String, Any}, String, String})
        _record_sequence(Tuple{typeof(Base.get), Base.Dict{String, String}, String, String})
        _record_sequence(
            Tuple{
                typeof(Base.get),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Tuple{Int64, Int64, Int64},
                Int64,
            },
        )
        _record_sequence(
            Tuple{typeof(Base.getindex), Array{Array{Base.Complex{Float64}, 2}, 1}, Int64},
        )
        _record_sequence(
            Tuple{typeof(Base.getindex), Array{Array{Float64, 1}, 1}, Base.UnitRange{Int64}},
        )
        _record_sequence(
            Tuple{typeof(Base.getindex), Array{Base.Complex{Float64}, 4}, Vararg{Int64, 4}},
        )
        _record_sequence(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{Float64, 2}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{UInt64, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Type{Int64}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Type{Int64}, Int64})
        false
        _record_sequence(
            Tuple{
                typeof(Base.getindex),
                Type{WannierNLQG.SymmetryFoundation.SymmetryOperation},
                WannierNLQG.SymmetryFoundation.SymmetryOperation,
            },
        )
        _record_sequence(
            Tuple{typeof(Base.getindex), Type{WannierNLQG.Wannierization.TBSymmetryMetric}},
        )
        _record_sequence(
            Tuple{typeof(Base.getindex), Type{WannierNLQG.Wannierization.WannierizationIteration}},
        )
        _record_sequence(Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol})
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :inventory,
                        :raw_diagnostics,
                        :qualification_scope,
                        :requested_policy,
                        :effective_policy,
                        :symmetry_tolerance_status,
                        :preparation_digest,
                    ),
                    Tuple{
                        Nothing,
                        Array{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic, 1},
                        WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                        Symbol,
                        Symbol,
                        Symbol,
                        String,
                    },
                },
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :mmn,
                        :amn,
                        :mmn_file,
                        :amn_file,
                        :raw_amn_file,
                        :source_kind,
                        :paw_result,
                        :gauge_sha256,
                        :gauge_provenance_file,
                    ),
                    Tuple{
                        WannierNLQG.IO.WannierMMN,
                        Nothing,
                        String,
                        Nothing,
                        Nothing,
                        String,
                        Nothing,
                        String,
                        Nothing,
                    },
                },
                Symbol,
            },
        )
        _record_sequence(
            Tuple{typeof(Base.getproperty), WannierNLQG.Core.RealSpaceOperator{3}, Symbol},
        )
        _record_sequence(
            Tuple{typeof(Base.getproperty), WannierNLQG.Core.RealSpaceOperator{4}, Symbol},
        )
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.TBSymmetryQualification,
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WannierizationAccelerationConfig,
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WannierizationInputConfig,
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WannierizationOutputConfig,
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WannierizationRuntimeConfig,
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WannierizationSolverConfig,
                Symbol,
            },
        )
        _record_sequence(Tuple{typeof(Base.haskey), Base.Dict{String, String}, String})
        _record_sequence(Tuple{typeof(Base.imag), Base.Complex{Float64}})
        _record_sequence(
            Tuple{
                typeof(Base.in!),
                Tuple{Int64, Int64, Int64},
                Base.Set{Tuple{Int64, Int64, Int64}},
            },
        )
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{4, String}})
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{5, String}})
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{6, String}})
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{8, String}})
        _record_sequence(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
        _record_sequence(Tuple{typeof(Base.in), String, Tuple{String, String}})
        _record_sequence(Tuple{typeof(Base.in), Symbol, Tuple{Symbol, Symbol, Symbol}})
        _record_sequence(
            Tuple{
                typeof(Base.in),
                WannierNLQG.Core.RealSpaceOperatorKind,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{String, Any}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{String, Any}, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64})
        _record_sequence(Tuple{typeof(Base.isempty), Base.Dict{String, Any}})
        _record_sequence(
            Tuple{
                typeof(Base.issorted),
                Array{String, 1},
                Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
            },
        )
        _record_sequence(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
        false
        false
        _record_sequence(
            Tuple{typeof(Base.iterate), Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}, Int64},
        )
        _record_sequence(
            Tuple{typeof(Base.iterate), Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
        )
        _record_sequence(Tuple{typeof(Base.iterate), Base.Dict{String, Any}, Int64})
        _record_sequence(Tuple{typeof(Base.iterate), Base.Dict{String, String}})
        _record_sequence(
            Tuple{
                typeof(Base.iterate),
                Base.KeySet{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Base.Dict{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperator{N} where N,
                    },
                },
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.iterate),
                Base.KeySet{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Base.Dict{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperator{N} where N,
                    },
                },
            },
        )
        _record_sequence(Tuple{typeof(Base.join), Array{String, 1}, String})
        _record_sequence(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Base.SubString{String}, 1},
                Char,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Float64, 1},
                Char,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Int64, 1},
                Char,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Base.OneTo{Int64},
                Char,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                NTuple{5, String},
                Char,
            },
        )
        _record_sequence(Tuple{typeof(Base.keys), Base.Dict{String, Any}})
        _record_sequence(Tuple{typeof(Base.length), Array{Base.Complex{Float64}, 1}})
        _record_sequence(Tuple{typeof(Base.length), Array{Int64, 1}})
        _record_sequence(Tuple{typeof(Base.length), Array{Tuple{Int64, Int64, Int64}, 1}})
        _record_sequence(Tuple{typeof(Base.length), Array{UInt8, 1}})
        _record_sequence(
            Tuple{typeof(Base.length), Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
        )
        _record_sequence(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.abs),
                typeof(Base.max),
                Float64,
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_sequence(Tuple{typeof(Base.max), Float64, Float64})
        _record_sequence(Tuple{typeof(Base.maximum), Array{Float64, 1}})
        _record_sequence(Tuple{typeof(Base.maybeview), Array{Float64, 2}, Base.BitArray{2}})
        _record_sequence(Tuple{typeof(Base.merge), Base.Dict{String, Any}, Base.Dict{String, Any}})
        _record_sequence(
            Tuple{typeof(Base.merge), Base.Dict{String, String}, Base.Dict{String, String}},
        )
        _record_sequence(Tuple{typeof(Base.minimum), Array{Float64, 1}})
        _record_sequence(Tuple{typeof(Base.occursin), Base.Regex, String})
        _record_sequence(
            Tuple{
                typeof(Base.print),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                UInt64,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.print),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                WannierNLQG.Wannierization.WannierizationStatus,
            },
        )
        _record_sequence(Tuple{typeof(Base.print), Base.IOStream, String})
        _record_sequence(Tuple{typeof(Base.print), Base.IOStream, Symbol})
        _record_sequence(Tuple{typeof(Base.prod), Tuple{Int64}})
        _record_sequence(
            Tuple{
                typeof(Base.push!),
                Array{Tuple{Int64, Int64, Int64}, 1},
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_sequence(Tuple{typeof(Base.real), Base.Complex{Float64}})
        _record_sequence(Tuple{typeof(Base.repeat), Char, Int64})
        _record_sequence(Tuple{typeof(Base.setindex!), Array{Float64, 2}, Float64, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64})
        _record_sequence(Tuple{typeof(Base.setindex!), Base.EnvDict, String, String})
        _record_sequence(Tuple{typeof(Base.setindex!), HDF5.Attributes, Bool, String})
        _record_sequence(Tuple{typeof(Base.setindex!), HDF5.Attributes, Int64, String})
        _record_sequence(Tuple{typeof(Base.setindex_widen_up_to), Array{Int64, 1}, Nothing, Int64})
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Float64, Float64, Int64, Int64, Float64, Float64, Symbol},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Int64, Int64, Float64, Symbol, Symbol},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{String, String, Int64, Float64, Array{Float64, 1}, Int64, Symbol},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{String, String},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Symbol, Float64, Float64, Int64, Int64, NTuple{4, Float64}, Float64},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{
                    Symbol,
                    Float64,
                    Int64,
                    Int64,
                    Int64,
                    Float64,
                    Bool,
                    Symbol,
                    Float64,
                    Float64,
                    Int64,
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{
                    Symbol,
                    Int64,
                    Int64,
                    Int64,
                    Bool,
                    Int64,
                    Int64,
                    Int64,
                    Int64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Symbol,
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Symbol, Int64, Int64, Int64, Int64, Int64, Float64, Bool, Int64, Float64},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Symbol, Symbol, String},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Array{Float64, 1},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Bool,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Nothing,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                UInt64,
            },
        )
        _record_sequence(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 3}, Int64})
        _record_sequence(Tuple{typeof(Base.size), Array{Float64, 2}})
        _record_sequence(Tuple{typeof(Base.size), Array{Int64, 2}, Int64})
        _record_sequence(Tuple{typeof(Base.size), Array{Int64, 2}})
        _record_sequence(Tuple{typeof(Base.size), Base.BitArray{2}})
        _record_sequence(Tuple{typeof(Base.something), String})
        _record_sequence(Tuple{typeof(Base.sum), Array{Float64, 1}})
        _record_sequence(Tuple{typeof(Base.sym_in), Symbol, NTuple{111, Symbol}})
        _record_sequence(Tuple{typeof(Base.transpose), Array{Float64, 2}})
        _record_sequence(Tuple{typeof(Base.transpose), Array{Int64, 2}})
        _record_sequence(Tuple{typeof(Base.unique), Array{String, 1}})
        _record_sequence(Tuple{typeof(Base.vec), Array{Int64, 1}})
        _record_sequence(Tuple{typeof(Base.vec), Array{Int64, 2}})
        _record_sequence(Tuple{typeof(Base.vect), Array{Float64, 1}})
        _record_sequence(Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}})
        _record_sequence(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Float64, 1},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Int64, 1},
            },
        )
        _record_sequence(Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}})
        _record_sequence(Tuple{typeof(Base.zeros), Type{Float64}, Tuple{Int64, Int64}})
        _record_sequence(Tuple{typeof(Core._checked_mul_dims), Int64, Int64, Int64, Vararg{Int64}})
        false
        _record_sequence(
            Tuple{
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
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{:not_atomic, Array{Float64, 1}, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{:not_atomic, Base.Complex{Float64}, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Wannierization.TBSymmetryMetric,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Wannierization.WannierizationIteration,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_sequence(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties},
        )
        _record_sequence(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties},
        )
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties})
        _record_sequence(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties},
        )
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties})
        _record_sequence(Tuple{typeof(JSON3.defaultminimum), Base.Dict{String, Any}})
        _record_sequence(Tuple{typeof(JSON3.defaultminimum), Base.Dict{String, String}})
        _record_sequence(
            Tuple{
                typeof(JSON3.write),
                StructTypes.DictType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Base.Dict{String, String},
            },
        )
        _record_sequence(Tuple{typeof(LinearAlgebra.norm), Array{Base.Complex{Float64}, 2}})
        _record_sequence(
            Tuple{
                typeof(Printf.computelen),
                Array{Base.UnitRange{Int64}, 1},
                Tuple{
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                },
                Tuple{Int64, Int64, Float64, Float64},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Printf.fmt),
                Array{UInt8, 1},
                Int64,
                Float64,
                Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Printf.fmt),
                Array{UInt8, 1},
                Int64,
                Tuple{Int64, Int64, Float64, Float64},
                Int64,
                Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQG.Wannierization.construct_symmetry_adapted_wannier_functions),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
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
        @assert !MPI.Initialized()
    end
end
