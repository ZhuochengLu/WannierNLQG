# Public BandRepresentation persistence, group table, and absolute validation.
# Compile observed signatures only; no HDF5 file is opened and no MPI is initialized.
@compile_workload begin
    if workload_enabled(parentmodule(BandRepresentation))
        # Valid two-band VASP first-call trace, after the completed public
        # representation contract was restored in this isolated candidate.
        _record_foundation(
            Tuple{
                typeof(WannierNLQG.SymmetryFoundation.generate_vasp_band_representation),
                WannierNLQG.SymmetryFoundation.VASPBandRepresentationConfig,
            },
        )
        _record_foundation(
            Tuple{
                typeof(generate_vasp_band_representation),
                WannierNLQG.SymmetryFoundation.VASPBandRepresentationConfig,
            },
        )
        _record_foundation(
            Tuple{typeof(WannierNLQG.SymmetryFoundation.read_band_representation_hdf5), String},
        )
        _record_foundation(Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}})
        _record_foundation(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
        _record_foundation(
            Tuple{
                typeof(Base.issorted),
                Array{String, 1},
                Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
            },
        )
        _record_foundation(Tuple{typeof(Base.setindex!), Base.EnvDict, String, String})
        _record_foundation(Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId})
        false
        false
        false
        _record_foundation(Tuple{typeof(Base.tail), NTuple{16, Symbol}})
        _record_foundation(Tuple{typeof(Base.tail), NTuple{15, Symbol}})
        _record_foundation(Tuple{typeof(Base.tail), NTuple{14, Symbol}})
        _record_foundation(Tuple{typeof(Base.tail), NTuple{13, Symbol}})
        _record_foundation(Tuple{typeof(Base.tail), NTuple{12, Symbol}})
        _record_foundation(Tuple{typeof(Base.tail), NTuple{11, Symbol}})
        _record_foundation(Tuple{typeof(Base.tail), NTuple{10, Symbol}})
        _record_foundation(Tuple{typeof(Base.tail), NTuple{9, Symbol}})
        _record_foundation(Tuple{typeof(Base.tail), NTuple{8, Symbol}})
        _record_foundation(Tuple{typeof(Base.tail), NTuple{7, Symbol}})
        _record_foundation(Tuple{typeof(Base.tail), NTuple{6, Symbol}})
        _record_foundation(Tuple{typeof(Base.tail), NTuple{5, Symbol}})
        _record_foundation(Tuple{typeof(Base.tail), NTuple{4, Symbol}})
        false
        _record_foundation(Tuple{typeof(Base.prod), Tuple{Int64}})
        _record_foundation(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{9, 0}},
            },
        )
        _record_foundation(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        _record_foundation(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        _record_foundation(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties},
        )
        _record_foundation(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties})
        _record_foundation(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
        _record_foundation(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties})
        _record_foundation(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{20, 0}},
            },
        )
        _record_foundation(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{40, 0}},
            },
        )
        _record_foundation(
            Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64, Int64},
        )
        _record_foundation(
            Tuple{
                typeof(HDF5.API.h5d_read),
                HDF5.Dataset,
                HDF5.Datatype,
                HDF5.Dataspace,
                HDF5.Dataspace,
                HDF5.DatasetTransferProperties,
                Array{Int64, 3},
            },
        )
        _record_foundation(
            Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64, Int64},
        )
        _record_foundation(
            Tuple{
                typeof(HDF5.API.h5d_read),
                HDF5.Dataset,
                HDF5.Datatype,
                HDF5.Dataspace,
                HDF5.Dataspace,
                HDF5.DatasetTransferProperties,
                Array{Float64, 3},
            },
        )
        _record_foundation(Tuple{Base.var"##s1116#1003", Vararg{Any, 5}})
        _record_foundation(Tuple{Base.var"##s1116#714", Vararg{Any, 6}})
        _record_foundation(
            Tuple{typeof(Base.Cartesian._nloops), Int64, Symbol, Symbol, Expr, Vararg{Expr}},
        )
        _record_foundation(
            Tuple{typeof(Base.Cartesian.lreplace!), QuoteNode, Base.Cartesian.LReplace{String}},
        )
        false
        false
        _record_foundation(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64})
        _record_foundation(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
        _record_foundation(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                var"#102#105"{
                    Array{UInt8, 1},
                    Array{Float64, 2},
                    Array{Float64, 3},
                    Array{Int64, 3},
                },
                Base.OneTo{Int64},
            },
        )
        _record_foundation(Tuple{Base.var"##s1116#691", Vararg{Any, 5}})
        _record_foundation(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.OneTo{Int64},
                    var"#102#105"{
                        Array{UInt8, 1},
                        Array{Float64, 2},
                        Array{Float64, 3},
                        Array{Int64, 3},
                    },
                },
            },
        )
        _record_foundation(Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol})
        _record_foundation(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{39, 0}},
            },
        )
        _record_foundation(
            Tuple{Type{Array{T, 2} where T}, LinearAlgebra.Transpose{Float64, Array{Float64, 2}}},
        )
        _record_foundation(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        _record_foundation(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        _record_foundation(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Dataset,
                HDF5.Datatype,
                Type{Base.Complex{Float64}},
            },
        )
        _record_foundation(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Int64,
                Vararg{Int64},
            },
        )
        _record_foundation(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                NTuple{4, Int64},
            },
        )
        _record_foundation(
            Tuple{
                typeof(HDF5.API.h5d_read),
                HDF5.Dataset,
                HDF5.Datatype,
                HDF5.Dataspace,
                HDF5.Dataspace,
                HDF5.DatasetTransferProperties,
                Array{Base.Complex{Float64}, 4},
            },
        )
        _record_foundation(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties},
        )
        _record_foundation(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties})
        false
        _record_foundation(
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
        _record_foundation(
            Tuple{
                typeof(Base.getindex),
                Type{WannierNLQG.SymmetryFoundation.SymmetryOperation},
                WannierNLQG.SymmetryFoundation.SymmetryOperation,
                WannierNLQG.SymmetryFoundation.SymmetryOperation,
            },
        )
        _record_foundation(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{30, 0}},
            },
        )
        _record_foundation(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{33, 0}},
            },
        )
        _record_foundation(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{Float64, 1},
                Char,
            },
        )
        _record_foundation(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:sortby,), Tuple{typeof(LinearAlgebra.eigsortby)}},
                typeof(LinearAlgebra.eigen),
                LinearAlgebra.Diagonal{Float64, Array{Float64, 1}},
            },
        )
        _record_foundation(
            Tuple{
                typeof(Base.:(==)),
                LinearAlgebra.Transpose{Int64, Array{Int64, 2}},
                Array{Int64, 2},
            },
        )
        _record_foundation(Tuple{typeof(Base.:(==)), Array{Int64, 3}, Array{Int64, 3}})
        _record_foundation(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Int64,
                Int64,
                Int64,
            },
        )
        _record_foundation(
            Tuple{
                typeof(HDF5.API.h5d_read),
                HDF5.Dataset,
                HDF5.Datatype,
                HDF5.Dataspace,
                HDF5.Dataspace,
                HDF5.DatasetTransferProperties,
                Array{Base.Complex{Float64}, 3},
            },
        )
        _record_foundation(
            Tuple{
                typeof(Base.permutedims),
                Array{Base.Complex{Float64}, 3},
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_foundation(
            Tuple{
                typeof(Base.:(-)),
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
            },
        )
        _record_foundation(Tuple{typeof(Base.maximum), Function, Array{Base.Complex{Float64}, 3}})
        _record_foundation(
            Tuple{
                typeof(Base._mapreduce_dim),
                Function,
                Function,
                Base._InitialValue,
                Array{Base.Complex{Float64}, 3},
                Base.Colon,
            },
        )
        _record_foundation(Tuple{typeof(Base.:(<=)), Float64, Float64})
        _record_foundation(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{Float64, 1},
            },
        )
        _record_foundation(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{Int64, 1},
            },
        )
        _record_foundation(Tuple{typeof(Base.vec), Array{Int64, 3}})
        _record_foundation(Tuple{typeof(Base.vec), Array{Base.Complex{Float64}, 4}})
        _record_foundation(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{Base.Complex{Float64}, 1},
            },
        )
        _record_foundation(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{23, 0}},
            },
        )
        _record_foundation(Tuple{typeof(Base.in), String, NTuple{4, String}})
        _record_foundation(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
        _record_foundation(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{17, 0}},
            },
        )
        _record_foundation(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64})
        _record_foundation(Tuple{typeof(Base.Broadcast.broadcasted), Type{Bool}, Array{UInt8, 2}})
        _record_foundation(Tuple{typeof(Base.:(&)), Int64, Int64})
        _record_foundation(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    Type{Bool},
                    Tuple{Array{UInt8, 2}},
                },
            },
        )
        _record_foundation(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:outer_mask_sha256, :frozen_mask_sha256, :diagnostic_status),
                    Tuple{String, String, Symbol},
                },
                Type{WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope},
                Base.BitArray{2},
                Base.BitArray{2},
            },
        )
        _record_foundation(
            Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 2}},
        )
        _record_foundation(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    Type{Float64},
                    Tuple{Array{Float64, 2}},
                },
            },
        )
        _record_foundation(Tuple{typeof(Base.Broadcast.broadcasted), Type{UInt8}, Array{UInt8, 1}})
        _record_foundation(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{UInt8},
                    Tuple{Array{UInt8, 1}},
                },
            },
        )
        _record_foundation(Tuple{typeof(Base.size), Array{Int64, 2}})
        _record_foundation(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        _record_foundation(Tuple{typeof(Base.size), Array{Float64, 2}})
        _record_foundation(Tuple{typeof(Base.length), Array{UInt8, 1}})
        _record_foundation(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
        _record_foundation(Tuple{typeof(Base.haskey), Base.Dict{UInt8, Symbol}, UInt8})
        _record_foundation(Tuple{typeof(Base.getindex), Base.Dict{UInt8, Symbol}, UInt8})
        _record_foundation(Tuple{Type{Bool}, Int64})
        _record_foundation(Tuple{typeof(Base.length), Base.UnitRange{Int64}})
        _record_foundation(Tuple{typeof(Base.:(>)), Int64})
        _record_foundation(
            Tuple{
                Type{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic},
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
        )
        _record_foundation(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{6, 0}},
            },
        )
        _record_foundation(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
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
        _record_foundation(
            Tuple{
                typeof(WannierNLQG.SymmetryFoundation.build_band_product_table),
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Vararg{Any},
            },
        )
        _record_foundation(
            Tuple{
                WannierNLQG.SymmetryFoundation.var"##build_band_product_table#192",
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(WannierNLQG.SymmetryFoundation.build_band_product_table),
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Vararg{Any},
            },
        )
        _record_foundation(
            Tuple{
                typeof(WannierNLQG.SymmetryFoundation._call_symmetry_foundation_extension),
                Symbol,
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Vararg{Any},
            },
        )
        _record_foundation(
            Tuple{
                WannierNLQG.SymmetryFoundation.var"##_call_symmetry_foundation_extension#187",
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(WannierNLQG.SymmetryFoundation._call_symmetry_foundation_extension),
                Symbol,
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Vararg{Any},
            },
        )
        _record_foundation(
            Tuple{
                typeof(build_band_product_table),
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Bool,
            },
        )
        _record_foundation(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:absolute_tolerance, :oracle_excess_tolerance, :require_oracle),
                    Tuple{Float64, Float64, Bool},
                },
                typeof(WannierNLQG.SymmetryFoundation.validate_band_representation),
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        _record_foundation(Tuple{typeof(Base.:(==)), Char, Char})
        _record_foundation(Tuple{typeof(Base.in), Char, Tuple{Char, Char, Char}})
        _record_foundation(Tuple{typeof(Base.in), Char, Tuple{Char, Char}})
        _record_foundation(Tuple{typeof(Base.iszero), Bool})
        _record_foundation(
            Tuple{Base.Iterators.var"#5#6"{Tuple{Array{Int64, 1}, Array{Int64, 1}}}, Int64},
        )
        _record_foundation(Tuple{typeof(LinearAlgebra.dot), Float64, Int64})
        _record_foundation(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:absolute_tolerance, :oracle_excess_tolerance, :require_oracle),
                    Tuple{Float64, Float64, Bool},
                },
                typeof(validate_band_representation),
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        _record_foundation(Tuple{typeof(Base.maximum), NTuple{4, Float64}})
        false
        _record_foundation(
            Tuple{typeof(Base.getproperty), Base.Generator{Tuple{}, typeof(Base.identity)}, Symbol},
        )
        _record_foundation(
            Tuple{typeof(Base.indexed_iterate), Tuple{Tuple{}, typeof(Base.identity)}, Int64},
        )
        _record_foundation(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{Tuple{}, typeof(Base.identity)},
                Int64,
                Int64,
            },
        )
        _record_foundation(Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}})
        _record_foundation(Tuple{typeof(Base.cconvert), Type{Int32}, HDF5.API.H5S_class_t})
        _record_foundation(
            Tuple{typeof(Base.getproperty), Base.Generator{Tuple{}, HDF5.var"#116#118"}, Symbol},
        )
        _record_foundation(
            Tuple{typeof(Base.getproperty), Base.Generator{Tuple{}, HDF5.var"#117#119"}, Symbol},
        )
        _record_foundation(
            Tuple{typeof(Base._similar_shape), Base.StepRange{Int64, Int64}, Base.HasShape{1}},
        )
        _record_foundation(Tuple{typeof(Base.Iterators.enumerate), NTuple{4, String}})
        _record_foundation(Tuple{Type{Base.Iterators.Enumerate{I} where I}, NTuple{4, String}})
        _record_foundation(Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{NTuple{4, String}}})
        _record_foundation(
            Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{NTuple{4, String}}, Tuple{Int64}},
        )
        _record_foundation(
            Tuple{typeof(Base.getproperty), Base.Iterators.Enumerate{NTuple{4, String}}, Symbol},
        )
        _record_foundation(Tuple{typeof(Base.indexed_iterate), Tuple{Int64, String}, Int64})
        _record_foundation(Tuple{typeof(Base.indexed_iterate), Tuple{Int64, String}, Int64, Int64})
        _record_foundation(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{NTuple{4, String}},
                Tuple{Int64, Int64},
            },
        )
        _record_foundation(Tuple{typeof(Base.tail), Tuple{Int64, Int64}})
        _record_foundation(Tuple{typeof(Base.convert), Type{Bool}, Bool})
        _record_foundation(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{:not_atomic, Float64, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
        )
        _record_foundation(Tuple{Type{Pair{A, B} where {B} where A}, Symbol, UInt8})
        _record_foundation(Tuple{typeof(Base.indexed_iterate), Pair{Symbol, UInt8}, Int64})
        _record_foundation(Tuple{typeof(Base.indexed_iterate), Pair{Symbol, UInt8}, Int64, Int64})
        _record_foundation(
            Tuple{
                Type{NamedTuple{(:read, :write, :append, :truncate), T} where T <: Tuple},
                Tuple{Bool, Bool, Nothing, Nothing},
            },
        )
        _record_foundation(Tuple{Dates.var"##s53#31", Vararg{Any, 5}})
        false
        _record_foundation(Tuple{typeof(Base.indexed_iterate), Tuple{String, Nothing}, Int64})
        _record_foundation(
            Tuple{typeof(Base.indexed_iterate), Tuple{String, Nothing}, Int64, Int64},
        )
        false
        _record_foundation(Tuple{typeof(Base.repeat), Char, Int64})
        _record_foundation(Tuple{typeof(Base.setindex!), HDF5.Attributes, Float64, String})
        _record_foundation(Tuple{typeof(Base.setindex!), HDF5.Attributes, String, String})
        _record_foundation(Tuple{typeof(Base.setindex!), HDF5.Group, Array{Float64, 1}, String})
        _record_foundation(
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
                    Tuple{Nothing, Nothing, Nothing, Nothing, Symbol, Symbol, Symbol},
                },
                typeof(_write_band_v14_preparation_metadata),
                HDF5.File,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        _record_foundation(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties},
        )
        _record_foundation(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties})
        _record_foundation(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties},
        )
        _record_foundation(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{27, 0}},
            },
        )
    end
end
