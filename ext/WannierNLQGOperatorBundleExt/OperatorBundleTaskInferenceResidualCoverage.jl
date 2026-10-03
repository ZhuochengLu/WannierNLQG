# Generated from exact Type-proved inference within real cold public calls, Julia 1.11.2.
# No target execution, writes, MPI initialization or saved handles. Provenance is external.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let WannierNLQGOperatorBundleExt=@__MODULE__
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (
                            :profile,
                            :operator_tasks,
                            :overwrite,
                            :paired_tb_sha256,
                            :provenance,
                            :symmetry,
                            :geometry,
                            :diagnostics,
                            :eligibility,
                        ),
                        Tuple{Symbol, Tuple{}, Bool, String, Vararg{Base.Dict{String, Any}, 5}},
                    },
                    typeof(WannierNLQGOperatorBundleExt.write_real_space_operator_bundle),
                    String,
                    Array{Float64, 2},
                    Array{Int64, 1},
                    Base.Dict{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperator{N} where N,
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (
                            :profile,
                            :operator_tasks,
                            :overwrite,
                            :paired_tb_sha256,
                            :provenance,
                            :symmetry,
                            :geometry,
                            :diagnostics,
                            :eligibility,
                        ),
                        Tuple{Symbol, Tuple{}, Bool, String, Vararg{Base.Dict{String, Any}, 5}},
                    },
                    typeof(WannierNLQGOperatorBundleExt.write_real_space_operator_bundle),
                    String,
                    Array{Float64, 2},
                    Array{Int64, 1},
                    Base.Dict{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperator{N} where N,
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:standard, :numerical_audit), Tuple{Bool, Base.RefValue{Float64}}},
                    typeof(WannierNLQGOperatorBundleExt._bundle_wannier_centers),
                    Base.Dict{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperator{N} where N,
                    },
                    Array{Int64, 2},
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:standard, :numerical_audit), Tuple{Bool, Base.RefValue{Float64}}},
                    typeof(WannierNLQGOperatorBundleExt._bundle_wannier_centers),
                    Base.Dict{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperator{N} where N,
                    },
                    Array{Int64, 2},
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._validated_geometry_metadata),
                    Base.Dict{String, Any},
                    Int64,
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._validated_geometry_metadata),
                    Base.Dict{String, Any},
                    Int64,
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._component_values),
                    WannierNLQG.Core.RealSpaceOperator{3},
                    Tuple{Int8, Int8},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._component_values),
                    WannierNLQG.Core.RealSpaceOperator{3},
                    Tuple{Int8, Int8},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._component_values),
                    WannierNLQG.Core.RealSpaceOperator{4},
                    Tuple{Int8, Int8},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._component_values),
                    WannierNLQG.Core.RealSpaceOperator{4},
                    Tuple{Int8, Int8},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._component_values),
                    WannierNLQG.Core.RealSpaceOperator{5},
                    Tuple{Int8, Int8},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._component_values),
                    WannierNLQG.Core.RealSpaceOperator{5},
                    Tuple{Int8, Int8},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._bind_pair_wigner_seitz_qualification),
                    Nothing,
                    Base.Dict{String, Any},
                    Symbol,
                    Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._bind_pair_wigner_seitz_qualification),
                    Nothing,
                    Base.Dict{String, Any},
                    Symbol,
                    Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._qualification_digest_value!),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                    Base.Dict{String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._qualification_digest_value!),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                    Base.Dict{String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                    Base.Dict{String, Base.Dict{String, Any}},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                    Base.Dict{String, Base.Dict{String, Any}},
                },
            )
            precompile(
                Tuple{typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree), String},
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                    String,
                },
            )
            precompile(
                Tuple{typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree), Bool},
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                    Bool,
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                    Base.Dict{String, Any},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                    Base.Dict{String, Any},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                    Base.Dict{String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                    Base.Dict{String, String},
                },
            )
            precompile(
                Tuple{typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree), Float64},
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                    Float64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (:standard, :inventory),
                        Tuple{Bool, Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
                    },
                    typeof(WannierNLQGOperatorBundleExt._bundle_band_frame_contract),
                    Base.Dict{String, Any},
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (:standard, :inventory),
                        Tuple{Bool, Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
                    },
                    typeof(WannierNLQGOperatorBundleExt._bundle_band_frame_contract),
                    Base.Dict{String, Any},
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(Base._any),
                    WannierNLQGOperatorBundleExt.var"#62#77",
                    Base.ValueIterator{Base.Dict{String, Any}},
                    Base.Colon,
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(Base._any),
                    WannierNLQGOperatorBundleExt.var"#62#77",
                    Base.ValueIterator{Base.Dict{String, Any}},
                    Base.Colon,
                },
            )
            precompile(Tuple{WannierNLQGOperatorBundleExt.var"#62#77", Base.Dict{String, Any}})
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    WannierNLQGOperatorBundleExt.var"#62#77",
                    Base.Dict{String, Any},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._construction_evidence_for_write),
                    Base.Dict{String, Any},
                    Base.Dict{String, Any},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._construction_evidence_for_write),
                    Base.Dict{String, Any},
                    Base.Dict{String, Any},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.getproperty),
                    Base.MappingRF{
                        WannierNLQGOperatorBundleExt.var"#68#83",
                        Base.BottomRF{typeof(Base.hcat)},
                    },
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(Base.getproperty),
                    Base.MappingRF{
                        WannierNLQGOperatorBundleExt.var"#68#83",
                        Base.BottomRF{typeof(Base.hcat)},
                    },
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.getproperty),
                    Base.MappingRF{
                        WannierNLQGOperatorBundleExt.var"#69#84",
                        Base.BottomRF{typeof(Base.hcat)},
                    },
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(Base.getproperty),
                    Base.MappingRF{
                        WannierNLQGOperatorBundleExt.var"#69#84",
                        Base.BottomRF{typeof(Base.hcat)},
                    },
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    HDF5.var"##h5open#16",
                    HDF5.HDF5Context,
                    Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                    typeof(HDF5.h5open),
                    WannierNLQGOperatorBundleExt.var"#67#82"{
                        String,
                        Base.Dict{String, Any},
                        Base.Dict{String, Any},
                        Base.Dict{
                            WannierNLQG.Core.RealSpaceOperatorKind,
                            WannierNLQG.Core.RealSpaceOperator{N} where N,
                        },
                        String,
                        Nothing,
                        Nothing,
                        Nothing,
                        String,
                        Base.Dict{String, Any},
                        Bool,
                        String,
                        String,
                        Bool,
                        String,
                        String,
                        String,
                        Base.Dict{String, Any},
                        String,
                        String,
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
                        Bool,
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
                        Array{String, 1},
                        Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                        Array{Base.Complex{Float64}, 1},
                        String,
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Int64,
                        Array{Int64, 1},
                        Array{Int64, 2},
                        Bool,
                        Bool,
                        Nothing,
                        Array{Float64, 2},
                    },
                    String,
                    Vararg{String},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    HDF5.var"##h5open#16",
                    HDF5.HDF5Context,
                    Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                    typeof(HDF5.h5open),
                    WannierNLQGOperatorBundleExt.var"#67#82"{
                        String,
                        Base.Dict{String, Any},
                        Base.Dict{String, Any},
                        Base.Dict{
                            WannierNLQG.Core.RealSpaceOperatorKind,
                            WannierNLQG.Core.RealSpaceOperator{N} where N,
                        },
                        String,
                        Nothing,
                        Nothing,
                        Nothing,
                        String,
                        Base.Dict{String, Any},
                        Bool,
                        String,
                        String,
                        Bool,
                        String,
                        String,
                        String,
                        Base.Dict{String, Any},
                        String,
                        String,
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
                        Bool,
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
                        Array{String, 1},
                        Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                        Array{Base.Complex{Float64}, 1},
                        String,
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Int64,
                        Array{Int64, 1},
                        Array{Int64, 2},
                        Bool,
                        Bool,
                        Nothing,
                        Array{Float64, 2},
                    },
                    String,
                    Vararg{String},
                },
            )
            precompile(
                Tuple{
                    Type{Base.Iterators.Filter{F, I} where {I} where F},
                    WannierNLQGOperatorBundleExt.var"#71#86"{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                    },
                    Base.Pairs{
                        Int64,
                        WannierNLQG.IO.OperatorBundleIndexEntry,
                        Base.LinearIndices{1, Tuple{Base.OneTo{Int64}}},
                        Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    Type{Base.Iterators.Filter{F, I} where {I} where F},
                    WannierNLQGOperatorBundleExt.var"#71#86"{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                    },
                    Base.Pairs{
                        Int64,
                        WannierNLQG.IO.OperatorBundleIndexEntry,
                        Base.LinearIndices{1, Tuple{Base.OneTo{Int64}}},
                        Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                    },
                },
            )
            precompile(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGOperatorBundleExt.var"#70#85",
                    Base.Iterators.Filter{
                        WannierNLQGOperatorBundleExt.var"#71#86"{
                            WannierNLQG.Core.RealSpaceOperatorKind,
                        },
                        Base.Pairs{
                            Int64,
                            WannierNLQG.IO.OperatorBundleIndexEntry,
                            Base.LinearIndices{1, Tuple{Base.OneTo{Int64}}},
                            Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGOperatorBundleExt.var"#70#85",
                    Base.Iterators.Filter{
                        WannierNLQGOperatorBundleExt.var"#71#86"{
                            WannierNLQG.Core.RealSpaceOperatorKind,
                        },
                        Base.Pairs{
                            Int64,
                            WannierNLQG.IO.OperatorBundleIndexEntry,
                            Base.LinearIndices{1, Tuple{Base.OneTo{Int64}}},
                            Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.collect),
                    Type{UInt64},
                    Base.Generator{
                        Base.Iterators.Filter{
                            WannierNLQGOperatorBundleExt.var"#71#86"{
                                WannierNLQG.Core.RealSpaceOperatorKind,
                            },
                            Base.Pairs{
                                Int64,
                                WannierNLQG.IO.OperatorBundleIndexEntry,
                                Base.LinearIndices{1, Tuple{Base.OneTo{Int64}}},
                                Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                            },
                        },
                        WannierNLQGOperatorBundleExt.var"#70#85",
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(Base.collect),
                    Type{UInt64},
                    Base.Generator{
                        Base.Iterators.Filter{
                            WannierNLQGOperatorBundleExt.var"#71#86"{
                                WannierNLQG.Core.RealSpaceOperatorKind,
                            },
                            Base.Pairs{
                                Int64,
                                WannierNLQG.IO.OperatorBundleIndexEntry,
                                Base.LinearIndices{1, Tuple{Base.OneTo{Int64}}},
                                Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                            },
                        },
                        WannierNLQGOperatorBundleExt.var"#70#85",
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Array{Int64, 2},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Array{Int64, 2},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Array{Float64, 2},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Array{Float64, 2},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Bool,
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Bool,
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Float64,
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Float64,
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Base.Dict{String, Base.Dict{String, Any}},
                },
            )
            precompile(
                Tuple{
                    typeof(_operator_bundle_first_use_call),
                    typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                    HDF5.Group,
                    String,
                    Base.Dict{String, Base.Dict{String, Any}},
                },
            )
        end
        @assert !WannierNLQG.MPI.Initialized()
    end
end

# Grouped exact residual requests from both legal nonzero Zeeman first calls.
# Compilation only through the existing owned bridge; no target execution,
# library initialization, MPI initialization, file writes, or saved handles.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        precompile(Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(Base.getproperty),
                HDF5.GroupCreateProperties,
                Symbol,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.AttributeAccessProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.AttributeCreateProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.DatasetAccessProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.DatasetTransferProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.DatatypeAccessProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.DatatypeCreateProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.Datatype,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.FileCreateProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.FileMountProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.GroupAccessProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.GroupCreateProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.LinkAccessProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.LinkCreateProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.ObjectCopyProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.ObjectCreateProperties,
            },
        )
        precompile(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties})
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.StringCreateProperties,
            },
        )
        precompile(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{17, 0}},
            },
        )
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{17, 0}},
            },
        )
        precompile(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{51, 0}},
            },
        )
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{51, 0}},
            },
        )
    end
end
