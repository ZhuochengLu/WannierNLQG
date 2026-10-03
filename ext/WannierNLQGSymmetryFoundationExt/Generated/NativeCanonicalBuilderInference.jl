@compile_workload begin
    # Generated from the real VASP first-call inference parent, candidate033.
    # This package-owned method caches its typed native dependencies; no physical branch is run here.
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (
                    :symmetry_inventory,
                    :plane_wave_convention,
                    :diagnostic_outer_masks,
                    :diagnostic_frozen_masks,
                ),
                Tuple{
                    WannierNLQG.SymmetryFoundation.MagneticSymmetryInventory,
                    Symbol,
                    Vector{BitVector},
                    Vector{BitVector},
                },
            },
            typeof(WannierNLQG.SymmetryFoundation.build_canonical_band_representation),
            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
            Matrix{Float64},
            Vector{WannierNLQG.SymmetryFoundation.SymmetryOperation},
            Float64,
        },
    )
end

# Exact native requests from the cold public VASP entry, Julia 1.11.2.
# Trace SHA256: 7f9fbb5163d8ae40ae715fd99d12522480fce694cea5ae12873d783ffed09a83
# Compilation only; no fixture execution, I/O, or MPI activation.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let StructTypes = JSON3.StructTypes,
            spglib_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("ac4a9f1e-bdb2-5204-990c-47c8b2f70d4e"),
                "spglib_jll",
            )]

            _foundation_owner_sequence(
                Tuple{
                    typeof(WannierNLQG.SymmetryFoundation.generate_vasp_band_representation),
                    WannierNLQG.SymmetryFoundation.VASPBandRepresentationConfig,
                },
            )
            _foundation_owner_sequence(Tuple{typeof(spglib_jll.find_artifact_dir)})
            _foundation_owner_sequence(
                Tuple{
                    Type{NamedTuple{(:atol, :rtol), T} where T <: Tuple},
                    Tuple{Float64, Float64},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.Core.memoryref),
                    Base.GenericMemory{
                        :not_atomic,
                        NamedTuple{names, T} where {T <: Tuple} where names,
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64},
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64, Int64},
            )
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{16, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{15, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{14, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{13, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{12, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{11, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{10, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{9, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{8, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{7, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{6, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{5, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{4, Symbol}})
            _foundation_owner_sequence(Tuple{Base.var"#58#59", Type})
            _foundation_owner_sequence(Tuple{typeof(Base.:(&)), Int64, Int64})
            _foundation_owner_sequence(
                Tuple{
                    typeof(WannierNLQGSymmetryFoundationExt.generate_vasp_band_representation),
                    WannierNLQG.SymmetryFoundation.VASPBandRepresentationConfig,
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    Base.var"##mapfoldl#335",
                    Base._InitialValue,
                    typeof(Base.mapfoldl),
                    Function,
                    Function,
                    Base.SubArray{
                        Int64,
                        2,
                        Array{Int64, 2},
                        Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}},
                        false,
                    },
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.mapfoldl_impl),
                    typeof(Base.identity),
                    typeof(Base.min),
                    Base._InitialValue,
                    Base.SubArray{
                        Int64,
                        2,
                        Array{Int64, 2},
                        Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}},
                        false,
                    },
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(WannierNLQG.SymmetryFoundation.read_values_at),
                    Base.IOStream,
                    Type{Base.Complex{Float64}},
                    Int64,
                    Int64,
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base._unsafe_getindex),
                    Base.IndexLinear,
                    Array{Base.Complex{Float64}, 2},
                    Array{Int64, 1},
                    Base.Slice{Base.OneTo{Int64}},
                },
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.join), Tuple{Float64, Float64, Float64}, String},
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        Base.GenericMemory{
                            :not_atomic,
                            UInt8,
                            Base.Core.AddrSpace{Base.Core}(0x00),
                        },
                    },
                    Tuple{Float64, Float64, Float64},
                    String,
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    Type{WannierNLQG.SymmetryFoundation.NativeWavefunctionData},
                    Symbol,
                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                    Array{Float64, 2},
                    Tuple{Int64, Int64, Int64},
                    Bool,
                    Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.getindex),
                    Type{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.Core.memoryref),
                    Base.GenericMemory{
                        :not_atomic,
                        Tuple{Int64, Int64, Float64},
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}},
            )
            _foundation_owner_sequence(Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}})
            _foundation_owner_sequence(Tuple{typeof(Base.in), NTuple{9, Int64}, Base.Set{Tuple}})
            _foundation_owner_sequence(Tuple{typeof(Base.push!), Base.Set{Tuple}, NTuple{9, Int64}})
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.setindex!),
                    Base.Dict{Tuple, Array{Float64, 2}},
                    Array{Float64, 2},
                    NTuple{9, Int64},
                },
            )
            _foundation_owner_sequence(
                Tuple{Type{Pair{A, B} where {B} where A}, NTuple{9, Int64}, Int64},
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.empty), Base.Dict{Any, Any}, Type{NTuple{9, Int64}}, Type{Int64}},
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.haskey), Base.Dict{NTuple{9, Int64}, Int64}, NTuple{9, Int64}},
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.getindex), Base.Dict{Tuple, Array{Float64, 2}}, NTuple{9, Int64}},
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}},
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.Iterators.enumerate),
                    Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                    },
                    Tuple{Int64},
                },
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.identity), Array{Float64, 1}},
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.Broadcast.materialize!),
                    Base.SubArray{
                        Float64,
                        1,
                        Array{Float64, 2},
                        Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                        true,
                    },
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Nothing,
                        typeof(Base.identity),
                        Tuple{Array{Float64, 1}},
                    },
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                    },
                    Tuple{Int64, Int64},
                },
            )
            _foundation_owner_sequence(Tuple{typeof(Base.collect), Base.UnitRange{Int64}})
            _foundation_owner_sequence(
                Tuple{typeof(Base.getindex), Array{Base.BitArray{1}, 1}, Int64},
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.:(!)), Base.BitArray{1}},
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.Broadcast.materialize),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Nothing,
                        typeof(Base.:(!)),
                        Tuple{Base.BitArray{1}},
                    },
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.view),
                    Array{Base.Complex{Float64}, 4},
                    Function,
                    Function,
                    Int64,
                    Int64,
                },
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.view), Array{Int64, 3}, Function, Int64, Int64},
            )
            _foundation_owner_sequence(
                Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64},
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.getindex), Array{Base.Complex{Float64}, 3}, Int64, Int64, Int64},
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.:(+)), Base.Complex{Float64}, Base.Complex{Float64}},
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.setindex!),
                    Array{Base.Complex{Float64}, 3},
                    Base.Complex{Float64},
                    Int64,
                    Int64,
                    Int64,
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.Broadcast.materialize!),
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
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{2},
                        Nothing,
                        typeof(Base.identity),
                        Tuple{Array{Base.Complex{Float64}, 2}},
                    },
                },
            )
            _foundation_owner_sequence(Tuple{typeof(Base.min), Float64, Float64})
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.write),
                    Base.GenericIOBuffer{
                        Base.GenericMemory{
                            :not_atomic,
                            UInt8,
                            Base.Core.AddrSpace{Base.Core}(0x00),
                        },
                    },
                    Array{Int64, 1},
                },
            )
            _foundation_owner_sequence(Tuple{typeof(Base.hcat), Base.BitArray{1}, Base.BitArray{1}})
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.hasproperty),
                    WannierNLQGSymmetryFoundationExt.BandRepresentationValidation,
                    Symbol,
                },
            )
            _foundation_owner_sequence(
                Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}},
            )
            _foundation_owner_sequence(
                Tuple{
                    WannierNLQGSymmetryFoundationExt.var"##_atomic_band_hdf5_write#76",
                    Bool,
                    typeof(WannierNLQGSymmetryFoundationExt._atomic_band_hdf5_write),
                    WannierNLQGSymmetryFoundationExt.var"#85#94"{
                        WannierNLQG.SymmetryFoundation.MagneticSymmetryInventory,
                        Array{Any, 1},
                        Symbol,
                        Symbol,
                        Symbol,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        WannierNLQGSymmetryFoundationExt.BandRepresentationProductTable,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                    },
                    String,
                },
            )
            _foundation_owner_sequence(Tuple{typeof(Base.repeat), Char, Int64})
            _foundation_owner_sequence(Tuple{typeof(Base.collect), NTuple{4, Float64}})
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.getproperty),
                    WannierNLQG.SymmetryFoundation.SymmetryOperation,
                    Symbol,
                },
            )
            _foundation_owner_sequence(Tuple{typeof(Base.prod), Tuple{Int64}})
            _foundation_owner_sequence(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
            _foundation_owner_sequence(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties},
            )
            _foundation_owner_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties},
            )
            _foundation_owner_sequence(
                Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64, Int64},
            )
            _foundation_owner_sequence(
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64, Int64},
            )
            _foundation_owner_sequence(
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64},
            )
            _foundation_owner_sequence(
                Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64},
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol},
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{15, 0}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    Type{Array{T, 2} where T},
                    LinearAlgebra.Transpose{Float64, Array{Float64, 2}},
                },
            )
            _foundation_owner_sequence(
                Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64},
            )
            _foundation_owner_sequence(
                Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64},
            )
            _foundation_owner_sequence(
                Tuple{
                    Type{Array{Base.Complex{Float64}, N} where N},
                    UndefInitializer,
                    NTuple{4, Int64},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.Core.kwcall),
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
            _foundation_owner_sequence(
                Tuple{
                    Type{Array{Base.Complex{Float64}, N} where N},
                    UndefInitializer,
                    Int64,
                    Int64,
                    Int64,
                },
            )
            _foundation_owner_sequence(Tuple{typeof(Base.:(<=)), Float64, Float64})
            _foundation_owner_sequence(Tuple{typeof(Base.in), String, NTuple{4, String}})
            _foundation_owner_sequence(
                Tuple{typeof(Base.in), String, Tuple{String, String, String}},
            )
            _foundation_owner_sequence(
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64},
            )
            _foundation_owner_sequence(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
            _foundation_owner_sequence(
                Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64},
            )
            _foundation_owner_sequence(Tuple{typeof(Base.size), Array{Int64, 2}})
            _foundation_owner_sequence(Tuple{typeof(Base.size), Array{Float64, 2}})
            _foundation_owner_sequence(Tuple{typeof(Base.length), Array{UInt8, 1}})
            _foundation_owner_sequence(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
            _foundation_owner_sequence(Tuple{Type{Bool}, Int64})
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{7, 0}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, String},
                        Pair{String, Base.Dict{String, String}},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Int64},
                        Pair{String, Array{Int64, 1}},
                        Pair{String, Array{Float64, 1}},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Nothing},
                        Pair{String, Nothing},
                        Pair{String, Array{String, 1}},
                    },
                    Int64,
                },
            )
            _foundation_owner_sequence(Tuple{typeof(Base.:(!=)), UInt64, UInt64})
            _foundation_owner_sequence(Tuple{typeof(Base.:(|)), UInt64, UInt64})
            _foundation_owner_sequence(
                Tuple{typeof(JSON3.pretty), Base.IOStream, Base.Dict{String, Any}},
            )
            _foundation_owner_sequence(Tuple{typeof(Base.add_sum), Int64, Int64})
            _foundation_owner_sequence(
                Tuple{typeof(JSON3.defaultminimum), Base.Dict{String, String}},
            )
            _foundation_owner_sequence(Tuple{typeof(JSON3.defaultminimum), Array{Int64, 1}})
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties},
            )
            _foundation_owner_sequence(Tuple{typeof(JSON3.defaultminimum), Array{Float64, 1}})
            _foundation_owner_sequence(Tuple{typeof(JSON3.defaultminimum), Array{String, 1}})
            _foundation_owner_sequence(Tuple{typeof(Base.StringVector), Int64})
            _foundation_owner_sequence(Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64})
            _foundation_owner_sequence(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.DictType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Base.Dict{String, String},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Array{Int64, 1},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Array{Float64, 1},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(JSON3.write),
                    StructTypes.ArrayType,
                    Array{UInt8, 1},
                    Int64,
                    Int64,
                    Array{String, 1},
                },
            )
            _foundation_owner_sequence(Tuple{Type{String}, Array{UInt8, 1}})
            _foundation_owner_sequence(
                Tuple{
                    Type{NamedTuple{(:jsonlines, :numbertype), T} where T <: Tuple},
                    Tuple{Bool, Nothing},
                },
            )
            _foundation_owner_sequence(
                Tuple{typeof(JSON3.pretty), Base.IOStream, String, JSON3.AlignmentContext},
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(JSON3.write),
                    JSON3.Object{
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
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(JSON3.write),
                    JSON3.Array{
                        Float64,
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
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.length),
                    JSON3.Array{Float64, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.Iterators.enumerate),
                    JSON3.Array{Float64, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        JSON3.Array{Float64, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                    },
                    Tuple{Int64},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        JSON3.Array{Float64, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                    },
                    Tuple{Int64, Tuple{Int64, Int64}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(JSON3.write),
                    JSON3.Array{
                        Union{},
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
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.length),
                    JSON3.Array{Union{}, Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                },
            )
        end
    end
end

# Exact requests from cold read_band_representation_hdf5; Julia 1.11.2.
# Trace SHA256: 81eebba0684236b312df221c018037306c5fea0299cc2bb8377a42fab9768e9b
# Compilation only; no file reads, runtime handles, physical tasks, or MPI calls.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let HDF5_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("0234f1f7-429e-5d53-9886-15a909be8d59"),
                "HDF5_jll",
            )],
            Hwloc_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("e33a78d0-f292-5ffc-b300-72abe9b543c8"),
                "Hwloc_jll",
            )],
            OpenMPI_jll = Base.get(
                Base.loaded_modules,
                Base.PkgId(Base.UUID("fe0851c0-eecd-5654-98d4-656369965a5c"), "OpenMPI_jll"),
                nothing,
            ),
            OpenSSL_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("458c3c95-2e84-50aa-8efc-19380b2a3a95"),
                "OpenSSL_jll",
            )],
            Requires = Base.loaded_modules[Base.PkgId(
                Base.UUID("ae029012-a4dd-5104-9daa-d747884805df"),
                "Requires",
            )],
            aws_c_auth_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("2b3700d1-4306-52e2-a478-c162f0c514be"),
                "aws_c_auth_jll",
            )],
            aws_c_cal_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("70f11efc-bab2-57f1-b0f3-22aad4e67c4b"),
                "aws_c_cal_jll",
            )],
            aws_c_common_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("73048d1d-b8c4-5092-a58d-866c5e8d1e50"),
                "aws_c_common_jll",
            )],
            aws_c_compression_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("73a04cd5-f3d7-5bac-9290-e8adb709f224"),
                "aws_c_compression_jll",
            )],
            aws_c_http_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("3254fc65-9028-534d-aa9d-d76d128babc6"),
                "aws_c_http_jll",
            )],
            aws_c_io_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("13c41daa-f319-5298-b5eb-5754e0170d52"),
                "aws_c_io_jll",
            )],
            aws_c_s3_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("bd1f34fb-993f-5903-a121-aaf302eed6d4"),
                "aws_c_s3_jll",
            )],
            aws_c_sdkutils_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("1282aa60-004d-510b-9f52-12498d409daa"),
                "aws_c_sdkutils_jll",
            )],
            aws_checksums_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("b2a88e68-78e7-5e94-8c20-c02986ec140e"),
                "aws_checksums_jll",
            )],
            libaec_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("477f73a3-ac25-53e9-8cc3-50b2fa2566f0"),
                "libaec_jll",
            )],
            spglib_jll = Base.loaded_modules[Base.PkgId(
                Base.UUID("ac4a9f1e-bdb2-5204-990c-47c8b2f70d4e"),
                "spglib_jll",
            )]

            _foundation_owner_sequence(
                Tuple{typeof(WannierNLQG.SymmetryFoundation.read_band_representation_hdf5), String},
            )
            false
            _foundation_owner_sequence(
                Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}},
            )
            _foundation_owner_sequence(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
            _foundation_owner_sequence(Tuple{typeof(spglib_jll.find_artifact_dir)})
            _foundation_owner_sequence(Tuple{typeof(OpenSSL_jll.find_artifact_dir)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_common_jll.find_artifact_dir)})
            _foundation_owner_sequence(Tuple{typeof(aws_checksums_jll.find_artifact_dir)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_common_jll.eager_mode)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_compression_jll.find_artifact_dir)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_cal_jll.find_artifact_dir)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_io_jll.find_artifact_dir)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_cal_jll.eager_mode)})
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.issorted),
                    Array{String, 1},
                    Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
                },
            )
            _foundation_owner_sequence(Tuple{typeof(aws_c_http_jll.find_artifact_dir)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_compression_jll.eager_mode)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_io_jll.eager_mode)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_sdkutils_jll.find_artifact_dir)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_auth_jll.find_artifact_dir)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_http_jll.eager_mode)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_sdkutils_jll.eager_mode)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_s3_jll.find_artifact_dir)})
            _foundation_owner_sequence(Tuple{typeof(aws_checksums_jll.eager_mode)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_auth_jll.eager_mode)})
            _foundation_owner_sequence(Tuple{typeof(libaec_jll.find_artifact_dir)})
            _foundation_owner_sequence(Tuple{typeof(Hwloc_jll.find_artifact_dir)})
            if OpenMPI_jll !== nothing
                _foundation_owner_sequence(Tuple{typeof(OpenMPI_jll.find_artifact_dir)})
            end
            _foundation_owner_sequence(Tuple{typeof(Hwloc_jll.eager_mode)})
            _foundation_owner_sequence(Tuple{typeof(Base.setindex!), Base.EnvDict, String, String})
            _foundation_owner_sequence(Tuple{typeof(HDF5_jll.find_artifact_dir)})
            _foundation_owner_sequence(Tuple{typeof(OpenSSL_jll.eager_mode)})
            _foundation_owner_sequence(Tuple{typeof(aws_c_s3_jll.eager_mode)})
            _foundation_owner_sequence(Tuple{typeof(libaec_jll.eager_mode)})
            if OpenMPI_jll !== nothing
                _foundation_owner_sequence(Tuple{typeof(OpenMPI_jll.eager_mode)})
            end
            _foundation_owner_sequence(Tuple{typeof(Requires.listenpkg), Any, Base.PkgId})
            _foundation_owner_sequence(Tuple{typeof(Requires.loaded), Base.PkgId})
            _foundation_owner_sequence(
                Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId},
            )
            _foundation_owner_sequence(Tuple{typeof(Requires.callbacks), Base.PkgId})
            _foundation_owner_sequence(Tuple{typeof(Requires.loadpkg), Base.PkgId})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{16, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{15, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{14, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{13, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{12, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{11, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{10, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{9, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{8, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{7, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{6, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{5, Symbol}})
            _foundation_owner_sequence(Tuple{typeof(Base.tail), NTuple{4, Symbol}})
            _foundation_owner_sequence(
                Tuple{
                    typeof(WannierNLQGSymmetryFoundationExt.read_band_representation_hdf5),
                    String,
                },
            )
            _foundation_owner_sequence(Tuple{typeof(Base.prod), Tuple{Int64}})
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{2, 0}},
                },
            )
            _foundation_owner_sequence(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
            _foundation_owner_sequence(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
            _foundation_owner_sequence(
                Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64, Int64},
            )
            _foundation_owner_sequence(
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64, Int64},
            )
            _foundation_owner_sequence(
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64},
            )
            _foundation_owner_sequence(
                Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64},
            )
            _foundation_owner_sequence(
                Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol},
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{530, 0}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{1336, 0}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{388, 0}},
                },
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties},
            )
            _foundation_owner_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties},
            )
            _foundation_owner_sequence(
                Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties},
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{4193, 0}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{118, 0}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{79, 0}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{35, 0}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{41, 0}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{116, 0}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{150, 0}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{166, 0}},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    Type{Array{T, 2} where T},
                    LinearAlgebra.Transpose{Float64, Array{Float64, 2}},
                },
            )
            _foundation_owner_sequence(
                Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64},
            )
            _foundation_owner_sequence(
                Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64},
            )
            _foundation_owner_sequence(
                Tuple{
                    Type{Array{Base.Complex{Float64}, N} where N},
                    UndefInitializer,
                    NTuple{4, Int64},
                },
            )
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.Core.kwcall),
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
            _foundation_owner_sequence(
                Tuple{
                    Type{Array{Base.Complex{Float64}, N} where N},
                    UndefInitializer,
                    Int64,
                    Int64,
                    Int64,
                },
            )
            _foundation_owner_sequence(Tuple{typeof(Base.:(<=)), Float64, Float64})
            _foundation_owner_sequence(
                Tuple{
                    typeof(Base.write),
                    Base.GenericIOBuffer{
                        Base.GenericMemory{
                            :not_atomic,
                            UInt8,
                            Base.Core.AddrSpace{Base.Core}(0x00),
                        },
                    },
                    Array{Int64, 1},
                },
            )
            _foundation_owner_sequence(Tuple{typeof(Base.in), String, NTuple{4, String}})
            _foundation_owner_sequence(
                Tuple{typeof(Base.in), String, Tuple{String, String, String}},
            )
            _foundation_owner_sequence(
                Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64},
            )
            _foundation_owner_sequence(Tuple{typeof(Base.size), Array{Int64, 2}})
            _foundation_owner_sequence(
                Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}},
            )
            _foundation_owner_sequence(Tuple{typeof(Base.size), Array{Float64, 2}})
            _foundation_owner_sequence(Tuple{typeof(Base.length), Array{UInt8, 1}})
            _foundation_owner_sequence(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
            _foundation_owner_sequence(Tuple{Type{Bool}, Int64})
        end
    end
end
