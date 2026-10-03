# Generated from a successful two-band VASP expert first-call trace.
# Trace SHA-256: fc020b47dcf352d83f190f72909ca838823b78247705ae5d0cca2212de24ae07
# Owned by BandPublicFirstUseCoverage.jl. Regenerate after source/Julia changes.
# Each declaration compiles a type only; no model or user file is opened here.
@compile_workload begin
    if workload_enabled(parentmodule(BandRepresentation))
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties})
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties})
        precompile(
            Tuple{Type{NamedTuple{(:atol, :rtol), T} where T <: Tuple}, Tuple{Float64, Float64}},
        )
        precompile(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    NamedTuple{names, T} where {T <: Tuple} where names,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        precompile(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64})
        precompile(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64, Int64})
        precompile(Tuple{typeof(Base.:(==)), Bool, Bool})
        precompile(Tuple{Type{NamedTuple{(:tolerance,), T} where T <: Tuple}, Tuple{Float64}})
        false
        precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Float64})
        precompile(Tuple{typeof(Base.:(&)), Bool, Base.Missing})
        precompile(Tuple{Type{NamedTuple{(:check,), T} where T <: Tuple}, Tuple{Bool}})
        precompile(Tuple{typeof(Base.in), Int64, Base.UnitRange{Int64}})
        precompile(Tuple{typeof(Base.tail), NTuple{16, Symbol}})
        precompile(Tuple{typeof(Base.tail), NTuple{15, Symbol}})
        precompile(Tuple{typeof(Base.tail), NTuple{14, Symbol}})
        precompile(Tuple{typeof(Base.tail), NTuple{13, Symbol}})
        precompile(Tuple{typeof(Base.tail), NTuple{12, Symbol}})
        precompile(Tuple{typeof(Base.tail), NTuple{11, Symbol}})
        precompile(Tuple{typeof(Base.tail), NTuple{10, Symbol}})
        precompile(Tuple{typeof(Base.tail), NTuple{9, Symbol}})
        precompile(Tuple{typeof(Base.tail), NTuple{8, Symbol}})
        precompile(Tuple{typeof(Base.tail), NTuple{7, Symbol}})
        precompile(Tuple{typeof(Base.tail), NTuple{6, Symbol}})
        precompile(Tuple{typeof(Base.tail), NTuple{5, Symbol}})
        precompile(Tuple{typeof(Base.tail), NTuple{4, Symbol}})
        precompile(Tuple{Base.var"#58#59", Type})
        precompile(Tuple{typeof(Base.:(&)), Int64, Int64})
        precompile(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (
                        :incar_file,
                        :spin_basis_saxis,
                        :band_range,
                        :spin_channel,
                        :spinor,
                        :representation_cutoff_ev,
                        :include_time_reversal,
                        :magnetic_moments_cartesian,
                    ),
                    Tuple{
                        Nothing,
                        Tuple{Float64, Float64, Float64},
                        Base.UnitRange{Int64},
                        Int64,
                        Bool,
                        Float64,
                        Bool,
                        Array{Float64, 2},
                    },
                },
                Type{WannierNLQG.SymmetryFoundation.VASPWavefunctionSource},
                String,
                String,
            },
        )
        precompile(
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
        precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQG.SymmetryFoundation.var"#125#133"{
                    WannierNLQG.SymmetryFoundation.var"#124#132"{
                        Bool,
                        WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                        Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                        Base.UnitRange{Int64},
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                    },
                },
                Base.OneTo{Int64},
            },
        )
        precompile(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQG.SymmetryFoundation.var"#125#133"{
                        WannierNLQG.SymmetryFoundation.var"#124#132"{
                            Bool,
                            WannierNLQG.SymmetryFoundation.VASPWavefunctionSource,
                            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                            Base.UnitRange{Int64},
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQG.SymmetryFoundation.VASPWavecarHeader,
                        },
                    },
                },
            },
        )
        precompile(Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}})
        precompile(Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}})
        precompile(Tuple{Type{Pair{A, B} where {B} where A}, NTuple{9, Int64}, Int64})
        precompile(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        precompile(
            Tuple{
                typeof(Base._all),
                WannierNLQG.SymmetryFoundation.var"#145#153"{Int64},
                Array{Base.BitArray{1}, 1},
                Base.Colon,
            },
        )
        precompile(
            Tuple{
                typeof(Base._all),
                WannierNLQG.SymmetryFoundation.var"#146#154"{Int64},
                Array{Base.BitArray{1}, 1},
                Base.Colon,
            },
        )
        precompile(
            Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.identity), Array{Float64, 1}},
        )
        precompile(
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
        precompile(Tuple{typeof(Base.collect), Base.UnitRange{Int64}})
        precompile(Tuple{typeof(Base.getindex), Array{Base.BitArray{1}, 1}, Int64})
        precompile(Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.:(!)), Base.BitArray{1}})
        precompile(
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
        precompile(Tuple{typeof(Base.:(==)), Char, Char})
        precompile(
            Tuple{
                typeof(Base.merge),
                NamedTuple{(), Tuple{}},
                Base.Pairs{Symbol, Bool, Tuple{Symbol}, NamedTuple{(:check,), Tuple{Bool}}},
            },
        )
        precompile(Tuple{typeof(Base.iszero), Bool})
        precompile(Tuple{typeof(Base.in), Char, Tuple{Char, Char, Char}})
        precompile(Tuple{typeof(Base.in), Char, Tuple{Char, Char}})
        precompile(
            Tuple{
                Type{NamedTuple{(:full, :alg), T} where T <: Tuple},
                Tuple{Bool, LinearAlgebra.DivideAndConquer},
            },
        )
        precompile(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:convention, :raw_diagnostics, :diagnostic_scopes),
                    Tuple{
                        Symbol,
                        Array{Any, 1},
                        NTuple{
                            4,
                            NamedTuple{
                                (:scope, :source_indices, :target_indices),
                                Tuple{Symbol, Array{Int64, 1}, Array{Int64, 1}},
                            },
                        },
                    },
                },
                typeof(WannierNLQG.SymmetryFoundation.canonical_plane_wave_sewing_matrix),
                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                WannierNLQG.SymmetryFoundation.SymmetryOperation,
                Base.SubArray{
                    Int64,
                    1,
                    Array{Int64, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Int64, Int64},
                    true,
                },
                Float64,
            },
        )
        precompile(Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64})
        precompile(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQG.SymmetryFoundation.var"#140#141"{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    },
                },
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:sortby,), Tuple{typeof(LinearAlgebra.eigsortby)}},
                typeof(LinearAlgebra.eigen),
                LinearAlgebra.Diagonal{Float64, Array{Float64, 1}},
            },
        )
        precompile(
            Tuple{typeof(Base.getindex), Array{Base.Complex{Float64}, 3}, Int64, Int64, Int64},
        )
        precompile(Tuple{typeof(Base.:(+)), Base.Complex{Float64}, Base.Complex{Float64}})
        precompile(
            Tuple{
                typeof(Base.setindex!),
                Array{Base.Complex{Float64}, 3},
                Base.Complex{Float64},
                Int64,
                Int64,
                Int64,
            },
        )
        precompile(
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
        precompile(Tuple{WannierNLQG.SymmetryFoundation.var"#147#155", Base.Dict{String, Any}})
        precompile(Tuple{WannierNLQG.SymmetryFoundation.var"#148#156", Base.Dict{String, Any}})
        precompile(Tuple{WannierNLQG.SymmetryFoundation.var"#149#157", Base.Dict{String, Any}})
        precompile(
            Tuple{
                Base.MappingRF{
                    WannierNLQG.SymmetryFoundation.var"#149#157",
                    Base.BottomRF{typeof(Base.min)},
                },
                Float64,
                Base.Dict{String, Any},
            },
        )
        precompile(Tuple{typeof(Base.min), Float64, Float64})
        precompile(Tuple{WannierNLQG.SymmetryFoundation.var"#150#158", Base.Dict{String, Any}})
        precompile(
            Tuple{
                Base.MappingRF{
                    WannierNLQG.SymmetryFoundation.var"#150#158",
                    Base.BottomRF{typeof(Base.max)},
                },
                Float64,
                Base.Dict{String, Any},
            },
        )
        precompile(Tuple{WannierNLQG.SymmetryFoundation.var"#151#159", Base.Dict{String, Any}})
        precompile(
            Tuple{
                Base.MappingRF{
                    WannierNLQG.SymmetryFoundation.var"#151#159",
                    Base.BottomRF{typeof(Base.max)},
                },
                Float64,
                Base.Dict{String, Any},
            },
        )
        precompile(Tuple{WannierNLQG.SymmetryFoundation.var"#152#160", Base.Dict{String, Any}})
        precompile(
            Tuple{
                Base.MappingRF{
                    WannierNLQG.SymmetryFoundation.var"#152#160",
                    Base.BottomRF{typeof(Base.max)},
                },
                Float64,
                Base.Dict{String, Any},
            },
        )
        precompile(Tuple{typeof(Base.maximum), NTuple{4, Float64}})
        precompile(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{Int64, 1},
            },
        )
        precompile(Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}})
        precompile(
            Tuple{typeof(Base._similar_shape), Base.StepRange{Int64, Int64}, Base.HasShape{1}},
        )
        precompile(Tuple{typeof(Base.indexed_iterate), Tuple{String, Nothing}, Int64})
        precompile(Tuple{typeof(Base.indexed_iterate), Tuple{String, Nothing}, Int64, Int64})
        precompile(Tuple{typeof(Base.indexed_iterate), Tuple{Int64, String}, Int64})
        precompile(Tuple{typeof(Base.indexed_iterate), Tuple{Int64, String}, Int64, Int64})
        precompile(Tuple{typeof(Base.tail), Tuple{Int64, Int64}})
        precompile(Tuple{Type{Pair{A, B} where {B} where A}, Symbol, UInt8})
        precompile(
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
        precompile(Tuple{typeof(Base.repeat), Char, Int64})
        precompile(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (
                        :inventory,
                        :qualification_outer_mask,
                        :qualification_frozen_mask,
                        :raw_diagnostics,
                        :requested_policy,
                        :effective_policy,
                        :symmetry_tolerance_status,
                    ),
                    Tuple{
                        WannierNLQG.SymmetryFoundation.MagneticSymmetryInventory,
                        Base.BitArray{2},
                        Base.BitArray{2},
                        Array{Any, 1},
                        Symbol,
                        Symbol,
                        Symbol,
                    },
                },
                typeof(WannierNLQGSymmetryFoundationExt._write_band_v14_preparation_metadata),
                HDF5.File,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        precompile(Tuple{WannierNLQGSymmetryFoundationExt.var"#79#80", Base.Dict{String, Any}})
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.SymmetryOperation,
                Symbol,
            },
        )
        precompile(Tuple{typeof(Base.isequal), Symbol, Symbol})
        precompile(
            Tuple{typeof(Base.repr), Tuple{Bool, Int64, Int64, Int64, Int64, Int64, Float64}},
        )
        precompile(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Tuple{Bool, Int64, Int64, Int64, Int64, Int64, Float64},
            },
        )
        precompile(Tuple{typeof(Base.prod), Tuple{Int64}})
        precompile(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        precompile(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64, Int64})
        precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64, Int64})
        precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64})
        precompile(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
        precompile(Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol})
        precompile(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{58, 0}},
            },
        )
        precompile(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{42, 0}},
            },
        )
        precompile(
            Tuple{Type{Array{T, 2} where T}, LinearAlgebra.Transpose{Float64, Array{Float64, 2}}},
        )
        precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        precompile(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                NTuple{4, Int64},
            },
        )
        precompile(
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
        precompile(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Int64,
                Int64,
                Int64,
            },
        )
        precompile(Tuple{typeof(Base.:(<=)), Float64, Float64})
        precompile(Tuple{typeof(Base.in), String, NTuple{4, String}})
        precompile(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
        precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
        precompile(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
        precompile(
            Tuple{
                Type{WannierNLQG.SymmetryFoundation.MagneticSymmetryInventory},
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Bool,
                Int64,
                Int64,
                Int64,
                Float64,
            },
        )
        precompile(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64})
        precompile(Tuple{typeof(Base.size), Array{Int64, 2}})
        precompile(Tuple{typeof(Base.size), Array{Float64, 2}})
        precompile(Tuple{typeof(Base.length), Array{UInt8, 1}})
        precompile(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
        precompile(Tuple{Type{Bool}, Int64})
        precompile(Tuple{typeof(Base.add_sum), Int64, Int64})
        precompile(Tuple{typeof(Base.StringVector), Int64})
        precompile(Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64})
        precompile(Tuple{Type{String}, Array{UInt8, 1}})
    end
end
