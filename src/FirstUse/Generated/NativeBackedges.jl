# Preserve native entries as well as their package-owned inference backedges.
# In particular, MPI operations are compiled as signatures; MPI is never initialized here.
@compile_workload begin
    precompile(Tuple{Base.var"##s128#278", Vararg{Any, 5}})
    precompile(Tuple{typeof(_first_use_foreign_call), Base.var"##s128#278", Vararg{Any, 5}})
    precompile(Tuple{Dates.var"##s53#31", Vararg{Any, 5}})
    precompile(Tuple{typeof(_first_use_foreign_call), Dates.var"##s53#31", Vararg{Any, 5}})
    precompile(Tuple{MPI.var"#11#12"})
    false
    precompile(Tuple{MPI.var"#13#14"})
    false
    precompile(Tuple{MPI.var"#15#16"})
    false
    precompile(Tuple{MPI.var"#17#18"})
    false
    precompile(Tuple{MPI.var"#19#20"})
    false
    precompile(Tuple{MPI.var"#21#22"})
    false
    precompile(Tuple{MPI.var"#23#24"})
    false
    precompile(Tuple{MPI.var"#25#26"})
    false
    precompile(Tuple{MPI.var"#53#54"})
    false
    precompile(Tuple{MPI.var"#55#56"})
    false
    precompile(Tuple{MPI.var"#57#58"})
    false
    precompile(Tuple{MPI.var"#59#60"})
    false
    precompile(Tuple{MPI.var"#61#62"})
    false
    precompile(Tuple{MPI.var"#63#64"})
    false
    precompile(Tuple{MPI.var"#7#8", Int32})
    precompile(Tuple{typeof(_first_use_foreign_call), MPI.var"#7#8", Int32})
    precompile(Tuple{MPI.var"#9#10"})
    false
    precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Tuple{Int64, Int64}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{Float64, N} where N},
            UndefInitializer,
            Tuple{Int64, Int64},
        },
    )
    precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Tuple{Int64, Int64}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{Int64, N} where N},
            UndefInitializer,
            Tuple{Int64, Int64},
        },
    )
    precompile(
        Tuple{
            Type{Array{NamedTuple{names, T} where {T <: Tuple} where names, 1}},
            UndefInitializer,
            Tuple{Int64},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Array{NamedTuple{names, T} where {T <: Tuple} where names, 1}},
            UndefInitializer,
            Tuple{Int64},
        },
    )
    false
    false
    false
    false
    precompile(Tuple{Type{Base.GC_Diff}, Base.GC_Num, Base.GC_Num})
    precompile(Tuple{typeof(_first_use_foreign_call), Type{Base.GC_Diff}, Base.GC_Num, Base.GC_Num})
    precompile(
        Tuple{
            Type{Base.Iterators.ProductIterator{T} where T <: Tuple},
            Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}, Base.UnitRange{Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Base.Iterators.ProductIterator{T} where T <: Tuple},
            Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}, Base.UnitRange{Int64}},
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
    precompile(Tuple{Type{Base.TwicePrecision{Float64}}, Float64})
    precompile(Tuple{typeof(_first_use_foreign_call), Type{Base.TwicePrecision{Float64}}, Float64})
    false
    false
    false
    false
    precompile(
        Tuple{
            Type{
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Runtime.TaskSpec,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
            UndefInitializer,
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Runtime.TaskSpec,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
            UndefInitializer,
            Int64,
        },
    )
    precompile(Tuple{Type{MPI.Op}, typeof(Base.:(+)), Type{Base.Complex{Float64}}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{MPI.Op},
            typeof(Base.:(+)),
            Type{Base.Complex{Float64}},
        },
    )
    precompile(Tuple{Type{MPI.Op}, typeof(Base.:(+)), Type{Int64}})
    precompile(Tuple{typeof(_first_use_foreign_call), Type{MPI.Op}, typeof(Base.:(+)), Type{Int64}})
    precompile(
        Tuple{
            Type{
                NamedTuple{
                    (
                        :broadening,
                        :broadening_type,
                        :transition_window_factor,
                        :denominator_regularization,
                        :band_window_size,
                    ),
                    T,
                } where T <: Tuple,
            },
            Tuple{Float64, String, Float64, Float64, Int64},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{
                NamedTuple{
                    (
                        :broadening,
                        :broadening_type,
                        :transition_window_factor,
                        :denominator_regularization,
                        :band_window_size,
                    ),
                    T,
                } where T <: Tuple,
            },
            Tuple{Float64, String, Float64, Float64, Int64},
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
    precompile(Tuple{Type{NamedTuple{(:length,), T} where T <: Tuple}, Tuple{Int64}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{NamedTuple{(:length,), T} where T <: Tuple},
            Tuple{Int64},
        },
    )
    false
    false
    false
    false
    false
    false
    precompile(
        Tuple{
            Type{NamedTuple{(:read, :write, :append, :truncate), T} where T <: Tuple},
            Tuple{Bool, Bool, Nothing, Nothing},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{NamedTuple{(:read, :write, :append, :truncate), T} where T <: Tuple},
            Tuple{Bool, Bool, Nothing, Nothing},
        },
    )
    precompile(
        Tuple{
            Type{
                NamedTuple{
                    (
                        :value,
                        :time,
                        :bytes,
                        :gctime,
                        :gcstats,
                        :lock_conflicts,
                        :compile_time,
                        :recompile_time,
                    ),
                    T,
                } where T <: Tuple,
            },
            Tuple{
                WannierNLQG.Runtime.RunResult,
                Float64,
                Int64,
                Float64,
                Base.GC_Diff,
                Int64,
                Float64,
                Float64,
            },
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{
                NamedTuple{
                    (
                        :value,
                        :time,
                        :bytes,
                        :gctime,
                        :gcstats,
                        :lock_conflicts,
                        :compile_time,
                        :recompile_time,
                    ),
                    T,
                } where T <: Tuple,
            },
            Tuple{
                WannierNLQG.Runtime.RunResult,
                Float64,
                Int64,
                Float64,
                Base.GC_Diff,
                Int64,
                Float64,
                Float64,
            },
        },
    )
    precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Array{Int64, 1}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Pair{A, B} where {B} where A},
            String,
            Array{Int64, 1},
        },
    )
    false
    false
    false
    false
    precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Array{String, 1}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Pair{A, B} where {B} where A},
            String,
            Array{String, 1},
        },
    )
    false
    false
    precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Any}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Pair{A, B} where {B} where A},
            String,
            Base.Dict{String, Any},
        },
    )
    precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Float64}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Pair{A, B} where {B} where A},
            String,
            Base.Dict{String, Float64},
        },
    )
    false
    false
    precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Float64})
    precompile(
        Tuple{typeof(_first_use_foreign_call), Type{Pair{A, B} where {B} where A}, String, Float64},
    )
    false
    false
    false
    false
    false
    false
    precompile(
        Tuple{
            Type{Printf.Format{S, T} where {T} where S},
            Base.CodeUnits{UInt8, String},
            Array{Base.UnitRange{Int64}, 1},
            Tuple{Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Printf.Format{S, T} where {T} where S},
            Base.CodeUnits{UInt8, String},
            Array{Base.UnitRange{Int64}, 1},
            Tuple{Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}}},
            Int64,
        },
    )
    precompile(
        Tuple{
            Type{Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x66000000))}}},
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
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            Type{Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x66000000))}}},
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
    false
    false
    precompile(Tuple{Type{UInt8}, Int32})
    precompile(Tuple{typeof(_first_use_foreign_call), Type{UInt8}, Int32})
    precompile(Tuple{Type{UInt8}, UInt8})
    precompile(Tuple{typeof(_first_use_foreign_call), Type{UInt8}, UInt8})
    false
    false
    false
    false
    precompile(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64, Int64}, Tuple{Int64, Int64, Int64}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.:(==)),
            Tuple{Int64, Int64, Int64},
            Tuple{Int64, Int64, Int64},
        },
    )
    precompile(Tuple{typeof(Base.:(>)), Float64, Int64})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(>)), Float64, Int64})
    precompile(
        Tuple{
            typeof(Base.Broadcast.broadcasted),
            typeof(Base.:(+)),
            Array{Base.Complex{Float64}, 4},
            Array{Base.Complex{Float64}, 4},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Broadcast.broadcasted),
            typeof(Base.:(+)),
            Array{Base.Complex{Float64}, 4},
            Array{Base.Complex{Float64}, 4},
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
    precompile(
        Tuple{
            typeof(Base.Broadcast.materialize!),
            Array{Base.Complex{Float64}, 4},
            Base.Broadcast.Broadcasted{
                Base.Broadcast.DefaultArrayStyle{4},
                Nothing,
                typeof(Base.:(+)),
                Tuple{Array{Base.Complex{Float64}, 4}, Array{Base.Complex{Float64}, 4}},
            },
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Broadcast.materialize!),
            Array{Base.Complex{Float64}, 4},
            Base.Broadcast.Broadcasted{
                Base.Broadcast.DefaultArrayStyle{4},
                Nothing,
                typeof(Base.:(+)),
                Tuple{Array{Base.Complex{Float64}, 4}, Array{Base.Complex{Float64}, 4}},
            },
        },
    )
    false
    false
    precompile(Tuple{typeof(Base.Filesystem.mkpath), String})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.Filesystem.mkpath), String})
    false
    false
    precompile(
        Tuple{typeof(Base.Iterators.product), Base.UnitRange{Int64}, Vararg{Base.UnitRange{Int64}}},
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Iterators.product),
            Base.UnitRange{Int64},
            Vararg{Base.UnitRange{Int64}},
        },
    )
    precompile(Tuple{typeof(Base.Libc.Libdl.dlopen), FFTW.FakeLazyLibrary})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Libc.Libdl.dlopen),
            FFTW.FakeLazyLibrary,
        },
    )
    precompile(Tuple{typeof(Base.Order.lt), Base.Order.ForwardOrdering, Int64, Int64})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Order.lt),
            Base.Order.ForwardOrdering,
            Int64,
            Int64,
        },
    )
    precompile(Tuple{typeof(Base.StringVector), Int64})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.StringVector), Int64})
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base._array_for),
            Type{Array{Tuple{String, String, String}, 1}},
            Base.HasShape{1},
            Tuple{Base.OneTo{Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base._array_for),
            Type{Array{Tuple{String, String, String}, 1}},
            Base.HasShape{1},
            Tuple{Base.OneTo{Int64}},
        },
    )
    precompile(
        Tuple{typeof(Base._array_for), Type{Int64}, Base.HasShape{1}, Tuple{Base.OneTo{Int64}}},
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base._array_for),
            Type{Int64},
            Base.HasShape{1},
            Tuple{Base.OneTo{Int64}},
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
    precompile(Tuple{typeof(Base.add_sum), Int64, Int64})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.add_sum), Int64, Int64})
    false
    false
    false
    false
    false
    false
    false
    false
    precompile(Tuple{typeof(Base.all), Array{Bool, 1}})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.all), Array{Bool, 1}})
    precompile(Tuple{typeof(Base.any), Array{Bool, 1}})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.any), Array{Bool, 1}})
    false
    false
    precompile(Tuple{typeof(Base.cconvert), Type{MPI.API.MPIPtr}, Ptr{Nothing}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.cconvert),
            Type{MPI.API.MPIPtr},
            Ptr{Nothing},
        },
    )
    false
    false
    false
    false
    precompile(Tuple{typeof(Base.convert), Type{Int64}, Float32})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.convert), Type{Int64}, Float32})
    false
    false
    precompile(
        Tuple{
            typeof(Base.copyto!),
            Array{Base.Complex{Float64}, 1},
            Array{Base.Complex{Float64}, 1},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.copyto!),
            Array{Base.Complex{Float64}, 1},
            Array{Base.Complex{Float64}, 1},
        },
    )
    precompile(
        Tuple{
            typeof(Base.copyto!),
            Array{Base.Complex{Float64}, 1},
            Base.ReshapedArray{
                Base.Complex{Float64},
                1,
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
                Tuple{
                    Base.MultiplicativeInverses.SignedMultiplicativeInverse{Int64},
                    Base.MultiplicativeInverses.SignedMultiplicativeInverse{Int64},
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.copyto!),
            Array{Base.Complex{Float64}, 1},
            Base.ReshapedArray{
                Base.Complex{Float64},
                1,
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
                Tuple{
                    Base.MultiplicativeInverses.SignedMultiplicativeInverse{Int64},
                    Base.MultiplicativeInverses.SignedMultiplicativeInverse{Int64},
                },
            },
        },
    )
    precompile(Tuple{typeof(Base.deepcopy_internal), NTuple{5, Symbol}, Base.IdDict{Any, Any}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.deepcopy_internal),
            NTuple{5, Symbol},
            Base.IdDict{Any, Any},
        },
    )
    false
    false
    false
    false
    precompile(Tuple{typeof(Base.fill), Array{Base.Complex{Float64}, 3}, Int64})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.fill),
            Array{Base.Complex{Float64}, 3},
            Int64,
        },
    )
    precompile(Tuple{typeof(Base.first), Array{Any, 1}})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.first), Array{Any, 1}})
    precompile(Tuple{typeof(Base.flush), Base.TTY})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.flush), Base.TTY})
    false
    false
    precompile(
        Tuple{
            typeof(Base.getindex),
            Array{Base.Complex{Float64}, 4},
            Base.IteratorsMD.CartesianIndex{4},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.getindex),
            Array{Base.Complex{Float64}, 4},
            Base.IteratorsMD.CartesianIndex{4},
        },
    )
    false
    false
    false
    false
    precompile(Tuple{typeof(Base.getindex), Array{Tuple{Int64, Int64, Int64}, 1}, Int64})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.getindex),
            Array{Tuple{Int64, Int64, Int64}, 1},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getindex),
            Base.Dict{Tuple{Int8, Int8}, AbstractArray{Base.Complex{Float64}, 3}},
            Tuple{Int8, Int8},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.getindex),
            Base.Dict{Tuple{Int8, Int8}, AbstractArray{Base.Complex{Float64}, 3}},
            Tuple{Int8, Int8},
        },
    )
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base.getindex),
            Type{Pair{String, String}},
            Pair{String, String},
            Pair{String, String},
            Pair{String, String},
            Pair{String, String},
            Pair{String, String},
            Pair{String, String},
            Vararg{Any},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.getindex),
            Type{Pair{String, String}},
            Pair{String, String},
            Pair{String, String},
            Pair{String, String},
            Pair{String, String},
            Pair{String, String},
            Pair{String, String},
            Vararg{Any},
        },
    )
    false
    false
    precompile(Tuple{typeof(Base.getproperty), Base.GC_Diff, Symbol})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.getproperty), Base.GC_Diff, Symbol},
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{typeof(Base.length), typeof(Base.max)},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.getproperty),
            Base.MappingRF{typeof(Base.length), typeof(Base.max)},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.ValueIterator{Base.IdDict{Type, MPI.Datatype}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.getproperty),
            Base.ValueIterator{Base.IdDict{Type, MPI.Datatype}},
            Symbol,
        },
    )
    false
    false
    precompile(
        Tuple{
            typeof(Base.getproperty),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, Int64, String}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.getproperty),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, Int64, String}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, Nothing, String}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.getproperty),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, Nothing, String}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, String, String}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.getproperty),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, String, String}},
            Symbol,
        },
    )
    false
    false
    precompile(Tuple{typeof(Base.hash), Array{Union{}, 1}, UInt64})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.hash), Array{Union{}, 1}, UInt64})
    false
    false
    precompile(Tuple{typeof(Base.hash), String, UInt64})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.hash), String, UInt64})
    precompile(Tuple{typeof(Base.imag), Base.Complex{Float64}})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.imag), Base.Complex{Float64}})
    precompile(Tuple{typeof(Base.in), String, NTuple{4, String}})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.in), String, NTuple{4, String}})
    precompile(Tuple{typeof(Base.in), String, NTuple{5, String}})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.in), String, NTuple{5, String}})
    precompile(Tuple{typeof(Base.in), String, Tuple{String, String}})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.in), String, Tuple{String, String}},
    )
    precompile(Tuple{typeof(Base.indexed_iterate), Array{String, 1}, Int64, Int64})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.indexed_iterate),
            Array{String, 1},
            Int64,
            Int64,
        },
    )
    precompile(Tuple{typeof(Base.indexed_iterate), Array{String, 1}, Int64})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.indexed_iterate),
            Array{String, 1},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.indexed_iterate),
            Tuple{MPI.Win, Array{Base.Complex{Float64}, 1}},
            Int64,
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.indexed_iterate),
            Tuple{MPI.Win, Array{Base.Complex{Float64}, 1}},
            Int64,
            Int64,
        },
    )
    precompile(
        Tuple{typeof(Base.indexed_iterate), Tuple{MPI.Win, Array{Base.Complex{Float64}, 1}}, Int64},
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.indexed_iterate),
            Tuple{MPI.Win, Array{Base.Complex{Float64}, 1}},
            Int64,
        },
    )
    precompile(Tuple{typeof(Base.invokelatest), Any})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.invokelatest), Any})
    precompile(Tuple{typeof(Base.isempty), Array{Float64, 1}})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.isempty), Array{Float64, 1}})
    precompile(Tuple{typeof(Base.isequal), Symbol, Symbol})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.isequal), Symbol, Symbol})
    precompile(Tuple{typeof(Base.isfinite), Float64})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.isfinite), Float64})
    precompile(
        Tuple{
            typeof(Base.issorted),
            Array{String, 1},
            Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.issorted),
            Array{String, 1},
            Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.iterate),
            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
            Int64,
        },
    )
    precompile(
        Tuple{typeof(Base.iterate), Array{NamedTuple{names, T} where {T <: Tuple} where names, 1}},
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.iterate),
            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Iterators.ProductIterator{
                Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}, Base.UnitRange{Int64}},
            },
            Tuple{Tuple{Int64, Int64}, Tuple{Int64, Int64}, Tuple{Int64, Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.iterate),
            Base.Iterators.ProductIterator{
                Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}, Base.UnitRange{Int64}},
            },
            Tuple{Tuple{Int64, Int64}, Tuple{Int64, Int64}, Tuple{Int64, Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Iterators.ProductIterator{
                Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}, Base.UnitRange{Int64}},
            },
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.iterate),
            Base.Iterators.ProductIterator{
                Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}, Base.UnitRange{Int64}},
            },
        },
    )
    precompile(Tuple{typeof(Base.iterate), Float64})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.iterate), Float64})
    precompile(Tuple{typeof(Base.join), Array{String, 1}, String})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.join), Array{String, 1}, String})
    false
    false
    precompile(
        Tuple{
            typeof(Base.join),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            NTuple{4, String},
            String,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.join),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            NTuple{4, String},
            String,
        },
    )
    precompile(
        Tuple{
            typeof(Base.join),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Tuple{Int64, Int64, Int64},
            String,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.join),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Tuple{Int64, Int64, Int64},
            String,
        },
    )
    precompile(
        Tuple{
            typeof(Base.join),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Tuple{String, String},
            String,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.join),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Tuple{String, String},
            String,
        },
    )
    precompile(
        Tuple{typeof(Base.length), Array{NamedTuple{names, T} where {T <: Tuple} where names, 1}},
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.length),
            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
        },
    )
    precompile(Tuple{typeof(Base.length), Array{Tuple{Int64, Int64, Int64}, 1}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.length),
            Array{Tuple{Int64, Int64, Int64}, 1},
        },
    )
    precompile(
        Tuple{
            typeof(Base.length),
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
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.length),
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
        },
    )
    false
    false
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base.merge),
            NamedTuple{(:denominator_regularization,), Tuple{Float64}},
            NamedTuple{
                (:broadening, :broadening_type, :transition_window_factor, :band_window_size),
                Tuple{Float64, String, Float64, Int64},
            },
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.merge),
            NamedTuple{(:denominator_regularization,), Tuple{Float64}},
            NamedTuple{
                (:broadening, :broadening_type, :transition_window_factor, :band_window_size),
                Tuple{Float64, String, Float64, Int64},
            },
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
    precompile(Tuple{typeof(Base.min), Float32, Float32})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.min), Float32, Float32})
    precompile(Tuple{typeof(Base.min), Float64, Float64})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.min), Float64, Float64})
    false
    false
    precompile(Tuple{typeof(Base.prevfloat), Float64})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.prevfloat), Float64})
    precompile(Tuple{typeof(Base.print), Base.IOStream, Base.SubString{String}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.print),
            Base.IOStream,
            Base.SubString{String},
        },
    )
    precompile(Tuple{typeof(Base.print), Base.IOStream, String})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.print), Base.IOStream, String})
    precompile(Tuple{typeof(Base.prod), Tuple{Int64, Int64}})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.prod), Tuple{Int64, Int64}})
    false
    false
    false
    false
    precompile(Tuple{typeof(Base.push!), Array{Symbol, 1}, Symbol})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.push!), Array{Symbol, 1}, Symbol})
    precompile(
        Tuple{typeof(Base.push!), Array{Tuple{Int64, Int64, Int64}, 1}, Tuple{Int64, Int64, Int64}},
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.push!),
            Array{Tuple{Int64, Int64, Int64}, 1},
            Tuple{Int64, Int64, Int64},
        },
    )
    precompile(
        Tuple{
            typeof(Base.read!),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Array{Float64, 2},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.read!),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Array{Float64, 2},
        },
    )
    precompile(
        Tuple{
            typeof(Base.read!),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Array{Int64, 1},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.read!),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Array{Int64, 1},
        },
    )
    precompile(
        Tuple{
            typeof(Base.read!),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Array{Int64, 2},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.read!),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Array{Int64, 2},
        },
    )
    precompile(
        Tuple{
            typeof(Base.read),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Type{WannierNLQG.Core.RealSpaceOperatorKind},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.read),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Type{WannierNLQG.Core.RealSpaceOperatorKind},
        },
    )
    precompile(Tuple{typeof(Base.real), Base.Complex{Float64}})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.real), Base.Complex{Float64}})
    precompile(
        Tuple{
            typeof(Base.reduce),
            typeof(Base.vcat),
            Array{Array{Tuple{String, String, String}, 1}, 1},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.reduce),
            typeof(Base.vcat),
            Array{Array{Tuple{String, String, String}, 1}, 1},
        },
    )
    precompile(Tuple{typeof(Base.reinterpret), Type{MPI.API.MPIPtr}, Ptr{Nothing}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.reinterpret),
            Type{MPI.API.MPIPtr},
            Ptr{Nothing},
        },
    )
    precompile(Tuple{typeof(Base.repeat), Char, Int64})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.repeat), Char, Int64})
    false
    false
    precompile(
        Tuple{typeof(Base.reshape), Array{Base.Complex{Float64}, 1}, Tuple{Int64, Int64, Int64}},
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.reshape),
            Array{Base.Complex{Float64}, 1},
            Tuple{Int64, Int64, Int64},
        },
    )
    precompile(
        Tuple{
            typeof(Base.reverse),
            Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}, Base.UnitRange{Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.reverse),
            Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}, Base.UnitRange{Int64}},
        },
    )
    precompile(Tuple{typeof(Base.reverse), Tuple{Int64, Int64, Int64}})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.reverse), Tuple{Int64, Int64, Int64}},
    )
    precompile(
        Tuple{
            typeof(Base.setindex!),
            Array{Array{Base.Complex{Float64}, 3}, 1},
            Array{Base.Complex{Float64}, 3},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.setindex!),
            Array{Array{Base.Complex{Float64}, 3}, 1},
            Array{Base.Complex{Float64}, 3},
            Int64,
        },
    )
    precompile(
        Tuple{typeof(Base.setindex!), Array{Pair{String, String}, 1}, Pair{String, String}, Int64},
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.setindex!),
            Array{Pair{String, String}, 1},
            Pair{String, String},
            Int64,
        },
    )
    precompile(Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.setindex!),
            Array{String, 1},
            String,
            Int64,
        },
    )
    precompile(Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.setindex!),
            Array{UInt8, 1},
            UInt8,
            Int64,
        },
    )
    precompile(Tuple{typeof(Base.setindex!), Base.EnvDict, String, String})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.setindex!),
            Base.EnvDict,
            String,
            String,
        },
    )
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base.show),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Tuple{Int64, Int64, Int64},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.show),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            Tuple{Int64, Int64, Int64},
        },
    )
    precompile(
        Tuple{
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{Bool, 1},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{Bool, 1},
        },
    )
    precompile(
        Tuple{
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{Int64, 1},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{Int64, 1},
        },
    )
    precompile(
        Tuple{
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
        },
    )
    precompile(
        Tuple{
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{String, 1},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{String, 1},
        },
    )
    precompile(
        Tuple{
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{Symbol, 1},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{Symbol, 1},
        },
    )
    precompile(
        Tuple{
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Bool,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Bool,
        },
    )
    precompile(
        Tuple{
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.show),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Int64,
        },
    )
    false
    false
    precompile(
        Tuple{
            typeof(Base.show_at_namedtuple),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            NTuple{8, Symbol},
            DataType,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.show_at_namedtuple),
            Base.IOContext{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            NTuple{8, Symbol},
            DataType,
        },
    )
    precompile(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 3}})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.size), Array{Base.Complex{Float64}, 3}},
    )
    precompile(
        Tuple{
            typeof(Base.size),
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
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.size),
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
        },
    )
    precompile(Tuple{typeof(Base.sym_in), Symbol, NTuple{14, Symbol}})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.sym_in), Symbol, NTuple{14, Symbol}},
    )
    precompile(Tuple{typeof(Base.sym_in), Symbol, NTuple{16, Symbol}})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.sym_in), Symbol, NTuple{16, Symbol}},
    )
    precompile(Tuple{typeof(Base.sym_in), Symbol, NTuple{23, Symbol}})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.sym_in), Symbol, NTuple{23, Symbol}},
    )
    precompile(Tuple{typeof(Base.sym_in), Symbol, NTuple{29, Symbol}})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.sym_in), Symbol, NTuple{29, Symbol}},
    )
    precompile(Tuple{typeof(Base.sym_in), Symbol, NTuple{32, Symbol}})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.sym_in), Symbol, NTuple{32, Symbol}},
    )
    precompile(Tuple{typeof(Base.sym_in), Symbol, NTuple{36, Symbol}})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.sym_in), Symbol, NTuple{36, Symbol}},
    )
    precompile(Tuple{typeof(Base.sym_in), Symbol, NTuple{43, Symbol}})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.sym_in), Symbol, NTuple{43, Symbol}},
    )
    false
    false
    false
    false
    precompile(Tuple{typeof(Base.twiceprecision), Base.TwicePrecision{Float64}, Int64})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.twiceprecision),
            Base.TwicePrecision{Float64},
            Int64,
        },
    )
    precompile(Tuple{typeof(Base.unique!), Array{String, 1}})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.unique!), Array{String, 1}})
    false
    false
    precompile(Tuple{typeof(Base.unsafe_convert), Type{MPI.API.MPIPtr}, MPI.API.MPIPtr})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.unsafe_convert),
            Type{MPI.API.MPIPtr},
            MPI.API.MPIPtr,
        },
    )
    precompile(Tuple{typeof(Base.unsafe_convert), Type{MPI.API.MPIPtr}, Ptr{Nothing}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.unsafe_convert),
            Type{MPI.API.MPIPtr},
            Ptr{Nothing},
        },
    )
    precompile(Tuple{typeof(Base.values), Base.IdDict{Type, MPI.Datatype}})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.values),
            Base.IdDict{Type, MPI.Datatype},
        },
    )
    precompile(Tuple{typeof(Base.vec), Array{Base.Complex{Float64}, 3}})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.vec), Array{Base.Complex{Float64}, 3}},
    )
    precompile(
        Tuple{
            typeof(Base.vec),
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
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.vec),
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
    precompile(
        Tuple{
            typeof(Base.write),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            WannierNLQG.Core.RealSpaceOperatorKind,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.write),
            Base.GenericIOBuffer{
                GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
            WannierNLQG.Core.RealSpaceOperatorKind,
        },
    )
    precompile(Tuple{typeof(Base.write), Base.IOStream, Array{UInt8, 1}})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(Base.write), Base.IOStream, Array{UInt8, 1}},
    )
    false
    false
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:rank, :type, :nocheck), Tuple{Int64, Symbol, Bool}},
            typeof(MPI.Win_lock),
            MPI.Win,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Core.kwcall),
            NamedTuple{(:rank, :type, :nocheck), Tuple{Int64, Symbol, Bool}},
            typeof(MPI.Win_lock),
            MPI.Win,
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:rank,), Tuple{Int64}},
            typeof(MPI.Win_shared_query),
            Type{Array{Base.Complex{Float64}, N} where N},
            Tuple{Int64},
            MPI.Win,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Core.kwcall),
            NamedTuple{(:rank,), Tuple{Int64}},
            typeof(MPI.Win_shared_query),
            Type{Array{Base.Complex{Float64}, N} where N},
            Tuple{Int64},
            MPI.Win,
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:rank,), Tuple{Int64}},
            typeof(MPI.Win_unlock),
            MPI.Win,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Core.kwcall),
            NamedTuple{(:rank,), Tuple{Int64}},
            typeof(MPI.Win_unlock),
            MPI.Win,
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.memoryref),
            GenericMemory{:not_atomic, Base.Complex{Float64}, Base.Core.AddrSpace{Base.Core}(0x00)},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Base.Core.memoryref),
            GenericMemory{:not_atomic, Base.Complex{Float64}, Base.Core.AddrSpace{Base.Core}(0x00)},
        },
    )
    false
    false
    false
    false
    precompile(Tuple{typeof(FFTW.fftw_init_check)})
    false
    precompile(
        Tuple{typeof(FFTW.spawnloop), Ptr{Nothing}, Ptr{Nothing}, UInt64, Int32, Ptr{Nothing}},
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(FFTW.spawnloop),
            Ptr{Nothing},
            Ptr{Nothing},
            UInt64,
            Int32,
            Ptr{Nothing},
        },
    )
    false
    false
    precompile(Tuple{typeof(MPI.Barrier), MPI.Comm})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(MPI.Barrier), MPI.Comm})
    precompile(Tuple{typeof(MPI.Bcast!), Array{Base.Complex{Float64}, 1}, Int64, MPI.Comm})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(MPI.Bcast!),
            Array{Base.Complex{Float64}, 1},
            Int64,
            MPI.Comm,
        },
    )
    precompile(Tuple{typeof(MPI.Comm_split), MPI.Comm, Int64, Int64})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(MPI.Comm_split), MPI.Comm, Int64, Int64},
    )
    precompile(Tuple{typeof(MPI.Comm_split), MPI.Comm, Nothing, Int64})
    precompile(
        Tuple{typeof(_first_use_foreign_call), typeof(MPI.Comm_split), MPI.Comm, Nothing, Int64},
    )
    precompile(Tuple{typeof(MPI.Comm_split_type), MPI.Comm, MPI.SplitType, Int64})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(MPI.Comm_split_type),
            MPI.Comm,
            MPI.SplitType,
            Int64,
        },
    )
    precompile(Tuple{typeof(MPI.Finalize)})
    false
    precompile(Tuple{typeof(MPI.Finalized)})
    false
    precompile(Tuple{typeof(MPI.Initialized)})
    false
    precompile(
        Tuple{typeof(MPI.Reduce!), Array{Base.Complex{Float64}, 4}, Function, Int64, MPI.Comm},
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(MPI.Reduce!),
            Array{Base.Complex{Float64}, 4},
            Function,
            Int64,
            MPI.Comm,
        },
    )
    precompile(Tuple{typeof(MPI.Reduce!), Array{Int64, 1}, Function, Int64, MPI.Comm})
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(MPI.Reduce!),
            Array{Int64, 1},
            Function,
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(MPI.Reduce!),
            MPI.RBuffer{Array{Base.Complex{Float64}, 4}, Nothing},
            MPI.Op,
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(MPI.Reduce!),
            MPI.RBuffer{Array{Base.Complex{Float64}, 4}, Nothing},
            MPI.Op,
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{typeof(MPI.Reduce!), MPI.RBuffer{Array{Int64, 1}, Nothing}, MPI.Op, Int64, MPI.Comm},
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(MPI.Reduce!),
            MPI.RBuffer{Array{Int64, 1}, Nothing},
            MPI.Op,
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(MPI.Reduce!),
            MPI.RBuffer{MPI.InPlace, Array{Base.Complex{Float64}, 4}},
            MPI.Op,
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(MPI.Reduce!),
            MPI.RBuffer{MPI.InPlace, Array{Base.Complex{Float64}, 4}},
            MPI.Op,
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(MPI.Reduce!),
            MPI.RBuffer{MPI.InPlace, Array{Int64, 1}},
            MPI.Op,
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(MPI.Reduce!),
            MPI.RBuffer{MPI.InPlace, Array{Int64, 1}},
            MPI.Op,
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(MPI.Win_allocate_shared),
            Type{Array{Base.Complex{Float64}, N} where N},
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(MPI.Win_allocate_shared),
            Type{Array{Base.Complex{Float64}, N} where N},
            Int64,
            MPI.Comm,
        },
    )
    precompile(Tuple{typeof(MPI.Win_sync), MPI.Win})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(MPI.Win_sync), MPI.Win})
    precompile(
        Tuple{
            typeof(MPI.bcast),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, Int64, String}},
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(MPI.bcast),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, Int64, String}},
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(MPI.bcast),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, Nothing, String}},
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(MPI.bcast),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, Nothing, String}},
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(MPI.bcast),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, String, String}},
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(MPI.bcast),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, String, String}},
            Int64,
            MPI.Comm,
        },
    )
    precompile(Tuple{typeof(MPI.bcast), Nothing, Int64, MPI.Comm})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(MPI.bcast), Nothing, Int64, MPI.Comm})
    precompile(Tuple{typeof(MPI.free), MPI.Comm})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(MPI.free), MPI.Comm})
    precompile(Tuple{typeof(MPI.free), MPI.Win})
    precompile(Tuple{typeof(_first_use_foreign_call), typeof(MPI.free), MPI.Win})
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Printf.fmt),
            Array{UInt8, 1},
            Int64,
            Float64,
            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x66000000))}},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Printf.fmt),
            Array{UInt8, 1},
            Int64,
            Float64,
            Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x66000000))}},
        },
    )
    false
    false
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Serialization.deserialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            DataType,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.deserialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            DataType,
        },
    )
    precompile(
        Tuple{
            typeof(Serialization.deserialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Type{UnionAll},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.deserialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Type{UnionAll},
        },
    )
    precompile(
        Tuple{
            typeof(Serialization.deserialize_fillarray!),
            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.deserialize_fillarray!),
            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{Float64, 2},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{Float64, 2},
        },
    )
    precompile(
        Tuple{
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{Int64, 1},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{Int64, 1},
        },
    )
    precompile(
        Tuple{
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{Int64, 2},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Array{Int64, 2},
        },
    )
    precompile(
        Tuple{
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Float64,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Float64,
        },
    )
    precompile(
        Tuple{
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            NTuple{4, Symbol},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            NTuple{4, Symbol},
        },
    )
    precompile(
        Tuple{
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            NTuple{7, Symbol},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            NTuple{7, Symbol},
        },
    )
    precompile(
        Tuple{
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Tuple{Int64, Int64, Int64},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Tuple{Int64, Int64, Int64},
        },
    )
    precompile(
        Tuple{
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Tuple{Int8, Int8},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Tuple{Int8, Int8},
        },
    )
    precompile(
        Tuple{
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Tuple{Symbol, Symbol, Symbol},
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            Tuple{Symbol, Symbol, Symbol},
        },
    )
    precompile(
        Tuple{
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            UInt128,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            UInt128,
        },
    )
    precompile(
        Tuple{
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            UnionAll,
        },
    )
    precompile(
        Tuple{
            typeof(_first_use_foreign_call),
            typeof(Serialization.serialize),
            Serialization.Serializer{
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
            },
            UnionAll,
        },
    )
end
