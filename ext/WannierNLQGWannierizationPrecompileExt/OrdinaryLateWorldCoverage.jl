# Actual ordinary solver specializations recompiled after optional backend activation.
# Compile only, including later calls; do not shift missing compilation to call two.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_sequence(
            Tuple{
                Base.MappingRF{typeof(JSON3.defaultminimum), Base.BottomRF{typeof(Base.add_sum)}},
                Int64,
                Int64,
            },
        )
        false
        _record_sequence(
            Tuple{
                Core.Compiler.var"#464#465"{
                    Core.Compiler.NativeInterpreter,
                    Nothing,
                    Core.Compiler.IRInterpretationState,
                },
                Any,
            },
        )
        false
        _record_sequence(
            Tuple{
                HDF5.Mmap.var"#3#5"{Ptr{Nothing}, Int64},
                GenericMemory{:not_atomic, Base.Complex{Float64}, Core.AddrSpace{Core}(0x00)},
            },
        )
        false
        _record_sequence(
            Tuple{
                Type{Array{Base.Complex{Float64}, 2}},
                LinearAlgebra.UniformScaling{Bool},
                Int64,
                Int64,
            },
        )
        _record_sequence(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}})
        _record_sequence(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Array{Int8, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
        false
        _record_sequence(Tuple{Type{Base.Set{T} where T}, Array{String, 1}})
        false
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
        false
        _record_sequence(
            Tuple{
                Type{GenericMemory{:not_atomic, Base.BitArray{1}, Core.AddrSpace{Core}(0x00)}},
                UndefInitializer,
                Int64,
            },
        )
        _record_sequence(Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}})
        _record_sequence(Tuple{Type{NamedTuple{(:init,), T} where T <: Tuple}, Tuple{Float64}})
        _record_sequence(
            Tuple{
                Type{
                    NamedTuple{
                        (
                            :raw_amn_alignment_applied,
                            :raw_amn_alignment_minimum_singular_value,
                            :raw_amn_alignment_maximum_condition,
                            :raw_amn_alignment_projector_drift,
                            :raw_amn_alignment_completion_count,
                            :localization_initial_frames,
                        ),
                        T,
                    } where T <: Tuple,
                },
                Tuple{Bool, Float64, Float64, Float64, Int64, Nothing},
            },
        )
        _record_sequence(
            Tuple{
                Type{NamedTuple{(:success, :code, :message, :kpoint), T} where T <: Tuple},
                Tuple{Bool, Symbol, String, Int64},
            },
        )
        _record_sequence(
            Tuple{
                Type{
                    NamedTuple{
                        (:success, :code, :message, :kpoint, :invariant_residual),
                        T,
                    } where T <: Tuple,
                },
                Tuple{Bool, Symbol, String, Int64, Float64},
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
        _record_sequence(Tuple{Type{Pair{A, B} where {B} where A}, String, Nothing})
        _record_sequence(
            Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64},
        )
        _record_sequence(
            Tuple{
                Type{Pair{A, B} where {B} where A},
                WannierNLQG.Core.RealSpaceOperatorKind,
                Nothing,
            },
        )
        _record_sequence(Tuple{Type{String}, Array{UInt8, 1}})
        _record_sequence(Tuple{Type{UInt8}, UInt8})
        _record_sequence(Tuple{Type{UInt8}, WannierNLQG.Core.RealSpaceOperatorKind})
        _record_sequence(
            Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_sequence(Tuple{typeof(Base.:(*)), Int64, Float64})
        _record_sequence(
            Tuple{
                typeof(Base.:(*)),
                LinearAlgebra.Adjoint{Base.Complex{Float64}, Array{Base.Complex{Float64}, 2}},
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_sequence(Tuple{typeof(Base.:(/)), Float64, Int64})
        _record_sequence(Tuple{typeof(Base.:(<=)), Float64, Float64})
        _record_sequence(Tuple{typeof(Base.:(==)), Array{Int64, 1}, Array{Int64, 1}})
        _record_sequence(Tuple{typeof(Base.:(==)), Array{UInt64, 1}, Array{UInt64, 1}})
        _record_sequence(Tuple{typeof(Base.:(==)), Bool, Bool})
        _record_sequence(
            Tuple{typeof(Base.:(==)), Tuple{Int64, Int64, Int64}, Tuple{Int64, Int64, Int64}},
        )
        _record_sequence(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        _record_sequence(Tuple{typeof(Base.:(==)), UInt64, UInt64})
        _record_sequence(Tuple{typeof(Base.:(>)), Float64, Float64})
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(WannierNLQG.Core.real_space_operator_name),
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
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
                typeof(Base._array_for),
                Type{Array{Float64, 1}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base._array_for),
                Type{Array{Int64, 1}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_sequence(Tuple{typeof(Base.add_sum), Int64, Int64})
        _record_sequence(Tuple{typeof(Base.add_sum), UInt64, UInt64})
        _record_sequence(Tuple{typeof(Base.adjoint), Array{Base.Complex{Float64}, 2}})
        _record_sequence(Tuple{typeof(Base.collect), Base.KeySet{String, Base.Dict{String, Any}}})
        false
        _record_sequence(Tuple{typeof(Base.copy), Array{Int64, 1}})
        _record_sequence(
            Tuple{
                typeof(Base.copy),
                GenericMemory{:not_atomic, Base.Complex{Float64}, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_sequence(Tuple{typeof(Base.eachindex), Array{Float64, 1}})
        _record_sequence(Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}})
        _record_sequence(Tuple{typeof(Base.get), Base.Dict{String, Any}, String, String})
        _record_sequence(Tuple{typeof(Base.get), Base.Dict{String, String}, String, String})
        _record_sequence(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
        false
        _record_sequence(Tuple{typeof(Base.getindex), Array{UInt64, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Type{Int64}, Int64})
        false
        _record_sequence(Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol})
        _record_sequence(Tuple{typeof(Base.getproperty), Pair{Symbol, String}, Symbol})
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
                WannierNLQG.Wannierization.WannierizationInputConfig,
                Symbol,
            },
        )
        _record_sequence(Tuple{typeof(Base.haskey), Base.Dict{String, String}, String})
        _record_sequence(Tuple{typeof(Base.imag), Base.Complex{Float64}})
        false
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
        _record_sequence(
            Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, String}, Int64}, Int64, Int64},
        )
        _record_sequence(
            Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, String}, Int64}, Int64},
        )
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{String, String}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{String, String}, Int64})
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
        _record_sequence(Tuple{typeof(Base.iterate), Base.Dict{String, String}, Int64})
        _record_sequence(Tuple{typeof(Base.iterate), Base.Dict{String, String}})
        _record_sequence(Tuple{typeof(Base.iterate), Pair{String, String}, Int64})
        _record_sequence(Tuple{typeof(Base.iterate), Pair{String, String}})
        _record_sequence(Tuple{typeof(Base.join), Array{String, 1}, String})
        _record_sequence(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Base.SubString{String}, 1},
                Char,
            },
        )
        _record_sequence(Tuple{typeof(Base.keys), Base.Dict{String, Any}})
        false
        _record_sequence(Tuple{typeof(Base.length), Array{Base.Complex{Float64}, 1}})
        _record_sequence(Tuple{typeof(Base.length), Array{Int64, 1}})
        _record_sequence(Tuple{typeof(Base.length), Array{Tuple{Int64, Int64, Int64}, 1}})
        _record_sequence(Tuple{typeof(Base.length), Array{UInt8, 1}})
        _record_sequence(
            Tuple{typeof(Base.length), Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
        )
        _record_sequence(Tuple{typeof(Base.merge), Base.Dict{String, Any}, Base.Dict{String, Any}})
        _record_sequence(Tuple{typeof(Base.min), Float64, Float64})
        false
        _record_sequence(Tuple{typeof(Base.occursin), Base.Regex, String})
        _record_sequence(
            Tuple{
                typeof(Base.print),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                UInt64,
            },
        )
        _record_sequence(Tuple{typeof(Base.print), Base.IOStream, String})
        _record_sequence(Tuple{typeof(Base.prod), Tuple{Int64}})
        false
        _record_sequence(
            Tuple{
                typeof(Base.push!),
                Array{Tuple{Int64, Int64, Int64}, 1},
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_sequence(Tuple{typeof(Base.real), Base.Complex{Float64}})
        _record_sequence(Tuple{typeof(Base.repeat), Char, Int64})
        _record_sequence(
            Tuple{
                typeof(Base.setindex!),
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Base.Complex{Float64}, 2},
                Int64,
            },
        )
        _record_sequence(Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64})
        _record_sequence(Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64})
        _record_sequence(Tuple{typeof(Base.setindex!), Base.EnvDict, String, String})
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
        false
        _record_sequence(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 2}})
        _record_sequence(Tuple{typeof(Base.size), Array{Float64, 2}})
        _record_sequence(Tuple{typeof(Base.size), Array{Int64, 2}, Int64})
        _record_sequence(Tuple{typeof(Base.size), Array{Int64, 2}})
        _record_sequence(Tuple{typeof(Base.string), Int64})
        _record_sequence(Tuple{typeof(Base.sum), Array{Int64, 1}})
        _record_sequence(Tuple{typeof(Base.unique), Array{String, 1}})
        _record_sequence(Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}})
        _record_sequence(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Int64, 1},
            },
        )
        _record_sequence(Tuple{typeof(Base.write), Base.IOStream, Array{UInt8, 1}})
        false
        _record_sequence(Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}})
        _record_sequence(Tuple{typeof(Core._checked_mul_dims), Int64, Int64, Int64, Vararg{Int64}})
        false
        false
        false
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
                GenericMemory{:not_atomic, Base.Complex{Float64}, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{:not_atomic, Float64, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Tuple{Int64, Int64, Float64},
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
        _record_sequence(Tuple{typeof(JSON3.read), String})
        _record_sequence(
            Tuple{
                typeof(JSON3.write),
                StructTypes.DictType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Base.Dict{String, Any},
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
        @assert !MPI.Initialized()
    end
end
