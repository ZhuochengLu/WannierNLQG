# Projection search and persisted-result reading signatures from real cold calls.
# Signatures only: no representation reading, result writing, or MPI initialization here.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Wannierization.read_projection_representation_search_hdf5),
                String,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.oneto), Int64})
        _record_early_prepare(
            Tuple{
                Type{Pair{A, B} where {B} where A},
                String,
                WannierNLQG.Wannierization.ProjectionRepresentationSearchStatus,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.indexed_iterate),
                Pair{String, WannierNLQG.Wannierization.ProjectionRepresentationSearchStatus},
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.indexed_iterate),
                Pair{String, WannierNLQG.Wannierization.ProjectionRepresentationSearchStatus},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Wannierization.ProjectionCandidateSpec,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Wannierization.ProjectionRepresentationSignature,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Pair{A, B} where {B} where A},
                String,
                WannierNLQG.Wannierization.ProjectionRepresentationValidationStatus,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.indexed_iterate),
                Pair{String, WannierNLQG.Wannierization.ProjectionRepresentationValidationStatus},
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.indexed_iterate),
                Pair{String, WannierNLQG.Wannierization.ProjectionRepresentationValidationStatus},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Wannierization.ProjectionRepresentationSolution,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(Tuple{typeof(LinearAlgebra.dot), Int64, Int64})
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.ProjectionSearch.read_projection_representation_search_hdf5,
                ),
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Dataset,
                HDF5.Datatype,
                Type{HDF5.FixedString{1917, 0}},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{WannierNLQG.Wannierization.ProjectionRepresentationCompatibilityInfo},
                String,
                String,
                String,
                String,
                Bool,
                Symbol,
                Float64,
                Int64,
                Float64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                PAWMatrixElements.JSON3.Array{
                    String,
                    Base.CodeUnits{UInt8, String},
                    Array{UInt64, 1},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{
                    Base.Broadcast.Broadcasted{
                        Style,
                        Axes,
                        F,
                        Args,
                    } where {
                        Args <: Tuple,
                    } where {
                        F,
                    } where {Axes} where Style <: Union{Nothing, Base.Broadcast.BroadcastStyle},
                },
                Base.Broadcast.DefaultArrayStyle{1},
                Type{String},
                Tuple{Array{String, 1}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.foreach),
                WannierNLQGWannierizationExt.ProjectionSearch.var"#140#142"{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                Array{String, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.foreach),
                WannierNLQGWannierizationExt.ProjectionSearch.var"#141#143"{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                Array{String, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.ProjectionSearch._projection_search_write_array,
                ),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{Int64, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.ProjectionSearch._projection_search_write_string,
                ),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Iterators.Zip{Is} where Is <: Tuple},
                Tuple{Array{String, 1}, Array{Float64, 1}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Iterators._zip_iterate_all),
                Tuple{Array{String, 1}, Array{Float64, 1}},
                Tuple{Tuple{}, Tuple{}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Float64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Iterators._zip_iterate_all),
                Tuple{Array{String, 1}, Array{Float64, 1}},
                Tuple{Tuple{Int64}, Tuple{Int64}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.ProjectionSearch._projection_decode_result),
                PAWMatrixElements.JSON3.Object{Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.ProjectionSearch.var"#160#163",
                PAWMatrixElements.JSON3.Array{
                    PAWMatrixElements.JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    PAWMatrixElements.JSON3.Array{
                        PAWMatrixElements.JSON3.Object{
                            S,
                            TT,
                        } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                    WannierNLQGWannierizationExt.ProjectionSearch.var"#160#163",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.iterate),
                PAWMatrixElements.JSON3.Array{
                    PAWMatrixElements.JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                PAWMatrixElements.JSON3.Object{
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.ProjectionSearch._projection_decode_json_array),
                PAWMatrixElements.JSON3.Object{
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
                Type{Float64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                PAWMatrixElements.JSON3.Array{
                    Int64,
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{
                    Base.Broadcast.Broadcasted{
                        Style,
                        Axes,
                        F,
                        Args,
                    } where {
                        Args <: Tuple,
                    } where {
                        F,
                    } where {Axes} where Style <: Union{Nothing, Base.Broadcast.BroadcastStyle},
                },
                Base.Broadcast.DefaultArrayStyle{1},
                Type{Int64},
                Tuple{Array{Int64, 1}},
            },
        )
        _record_early_prepare(
            Tuple{
                Type{
                    Base.Broadcast.Broadcasted{
                        Style,
                        Axes,
                        F,
                        Args,
                    } where {
                        Args <: Tuple,
                    } where {
                        F,
                    } where {Axes} where Style <: Union{Nothing, Base.Broadcast.BroadcastStyle},
                },
                Base.Broadcast.DefaultArrayStyle{1},
                Type{Float64},
                Tuple{Array{Int64, 1}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{Float64},
                    Tuple{Array{Int64, 1}},
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.reshape), Array{Float64, 1}, Tuple{Int64, Int64}})
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                PAWMatrixElements.JSON3.Array{
                    String,
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:selector, :orbital_sets, :positions, :local_bases),
                    Tuple{String, Array{String, 1}, Array{Float64, 2}, Array{Float64, 2}},
                },
                Type{WannierNLQG.WannierProjection.ProjectionSpec},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.iterate),
                PAWMatrixElements.JSON3.Array{
                    PAWMatrixElements.JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
                Tuple{Int64, Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                Type{WannierNLQG.WannierProjection.ProjectionSpec},
                WannierNLQG.WannierProjection.ProjectionSpec,
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.ProjectionSearch.var"#161#164",
                PAWMatrixElements.JSON3.Array{
                    PAWMatrixElements.JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    PAWMatrixElements.JSON3.Array{
                        PAWMatrixElements.JSON3.Object{
                            S,
                            TT,
                        } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                    WannierNLQGWannierizationExt.ProjectionSearch.var"#161#164",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{
                    Base.Broadcast.Broadcasted{
                        Style,
                        Axes,
                        F,
                        Args,
                    } where {
                        Args <: Tuple,
                    } where {
                        F,
                    } where {Axes} where Style <: Union{Nothing, Base.Broadcast.BroadcastStyle},
                },
                Base.Broadcast.DefaultArrayStyle{1},
                Type{Symbol},
                Tuple{
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Nothing,
                        Type{String},
                        Tuple{Array{String, 1}},
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{Symbol},
                    Tuple{
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{1},
                            Nothing,
                            Type{String},
                            Tuple{Array{String, 1}},
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.ProjectionSearch.var"#162#165",
                PAWMatrixElements.JSON3.Array{
                    PAWMatrixElements.JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    PAWMatrixElements.JSON3.Array{
                        PAWMatrixElements.JSON3.Object{
                            S,
                            TT,
                        } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                    WannierNLQGWannierizationExt.ProjectionSearch.var"#162#165",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.ProjectionSearch.var"#156#158",
                PAWMatrixElements.JSON3.Array{
                    PAWMatrixElements.JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Dict{String, Float64}},
                Base.Generator{
                    PAWMatrixElements.JSON3.Array{
                        PAWMatrixElements.JSON3.Object{
                            S,
                            TT,
                        } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                    WannierNLQGWannierizationExt.ProjectionSearch.var"#156#158",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.ProjectionSearch.var"#157#159",
                PAWMatrixElements.JSON3.Array{
                    PAWMatrixElements.JSON3.Array{
                        T,
                        S,
                        TT,
                    } where {
                        TT <: AbstractArray{UInt64, 1},
                    } where {S <: AbstractArray{UInt8, 1}} where T,
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    PAWMatrixElements.JSON3.Array{
                        PAWMatrixElements.JSON3.Array{
                            T,
                            S,
                            TT,
                        } where {
                            TT <: AbstractArray{UInt64, 1},
                        } where {S <: AbstractArray{UInt8, 1}} where T,
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                    WannierNLQGWannierizationExt.ProjectionSearch.var"#157#159",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.ProjectionSearch.var"#157#159",
                PAWMatrixElements.JSON3.Array{
                    Int64,
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Array{Int64, 1}, 1},
                Array{Int64, 1},
                Base.Generator{
                    PAWMatrixElements.JSON3.Array{
                        PAWMatrixElements.JSON3.Array{
                            T,
                            S,
                            TT,
                        } where {
                            TT <: AbstractArray{UInt64, 1},
                        } where {S <: AbstractArray{UInt8, 1}} where T,
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                    WannierNLQGWannierizationExt.ProjectionSearch.var"#157#159",
                },
                Tuple{Int64, Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.sum),
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Any,
                        NTuple{18, Symbol},
                        NamedTuple{
                            (
                                :status,
                                :complete,
                                :representation_sha256,
                                :contract_sha256,
                                :compatibility,
                                :config_sha256,
                                :spinor,
                                :num_wannier,
                                :outer_mask_sha256,
                                :frozen_mask_sha256,
                                :candidates,
                                :radial_transform,
                                :visited_nodes,
                                :total_solution_count,
                                :truncated,
                                :signatures,
                                :solutions,
                                :diagnostics,
                            ),
                            Tuple{
                                String,
                                Bool,
                                String,
                                String,
                                NamedTuple{
                                    (
                                        :upstream_package,
                                        :upstream_version,
                                        :upstream_commit,
                                        :upstream_source_sha256,
                                        :parity_eligible,
                                        :scope,
                                        :character_tolerance,
                                        :character_round_digits,
                                        :little_group_tolerance,
                                    ),
                                    Tuple{
                                        String,
                                        String,
                                        String,
                                        String,
                                        Bool,
                                        String,
                                        Float64,
                                        Int64,
                                        Float64,
                                    },
                                },
                                String,
                                Bool,
                                Int64,
                                String,
                                String,
                                Array{
                                    NamedTuple{
                                        (
                                            :id,
                                            :min_multiplicity,
                                            :max_multiplicity,
                                            :fixed_multiplicity,
                                            :specs,
                                        ),
                                        Tuple{
                                            String,
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{
                                                NamedTuple{
                                                    (
                                                        :selector,
                                                        :orbital_sets,
                                                        :positions_fractional,
                                                        :local_bases,
                                                    ),
                                                    Tuple{
                                                        String,
                                                        Array{String, 1},
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                    },
                                                },
                                                1,
                                            },
                                        },
                                    },
                                    1,
                                },
                                NamedTuple{(:method, :gauss_laguerre_order), Tuple{String, Int64}},
                                Int64,
                                Int64,
                                Bool,
                                Array{
                                    NamedTuple{
                                        (
                                            :kpoint_index,
                                            :labels,
                                            :dimensions,
                                            :wigner_types,
                                            :frozen_lower,
                                            :outer_upper,
                                        ),
                                        Tuple{
                                            Int64,
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{Int64, 1},
                                        },
                                    },
                                    1,
                                },
                                Array{
                                    NamedTuple{
                                        (
                                            :candidate_ids,
                                            :coefficients,
                                            :total_dimension,
                                            :nonzero_candidate_types,
                                            :total_block_multiplicity,
                                            :signature_multiplicities,
                                            :validation_status,
                                            :embedding_residuals,
                                            :validation_sha256,
                                        ),
                                        Tuple{
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{Array{Int64, 1}, 1},
                                            String,
                                            Array{
                                                NamedTuple{(:name, :value), Tuple{String, Float64}},
                                                1,
                                            },
                                            String,
                                        },
                                    },
                                    1,
                                },
                                Array{String, 1},
                            },
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##sum#343",
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(Base.sum),
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Any,
                        NTuple{18, Symbol},
                        NamedTuple{
                            (
                                :status,
                                :complete,
                                :representation_sha256,
                                :contract_sha256,
                                :compatibility,
                                :config_sha256,
                                :spinor,
                                :num_wannier,
                                :outer_mask_sha256,
                                :frozen_mask_sha256,
                                :candidates,
                                :radial_transform,
                                :visited_nodes,
                                :total_solution_count,
                                :truncated,
                                :signatures,
                                :solutions,
                                :diagnostics,
                            ),
                            Tuple{
                                String,
                                Bool,
                                String,
                                String,
                                NamedTuple{
                                    (
                                        :upstream_package,
                                        :upstream_version,
                                        :upstream_commit,
                                        :upstream_source_sha256,
                                        :parity_eligible,
                                        :scope,
                                        :character_tolerance,
                                        :character_round_digits,
                                        :little_group_tolerance,
                                    ),
                                    Tuple{
                                        String,
                                        String,
                                        String,
                                        String,
                                        Bool,
                                        String,
                                        Float64,
                                        Int64,
                                        Float64,
                                    },
                                },
                                String,
                                Bool,
                                Int64,
                                String,
                                String,
                                Array{
                                    NamedTuple{
                                        (
                                            :id,
                                            :min_multiplicity,
                                            :max_multiplicity,
                                            :fixed_multiplicity,
                                            :specs,
                                        ),
                                        Tuple{
                                            String,
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{
                                                NamedTuple{
                                                    (
                                                        :selector,
                                                        :orbital_sets,
                                                        :positions_fractional,
                                                        :local_bases,
                                                    ),
                                                    Tuple{
                                                        String,
                                                        Array{String, 1},
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                    },
                                                },
                                                1,
                                            },
                                        },
                                    },
                                    1,
                                },
                                NamedTuple{(:method, :gauss_laguerre_order), Tuple{String, Int64}},
                                Int64,
                                Int64,
                                Bool,
                                Array{
                                    NamedTuple{
                                        (
                                            :kpoint_index,
                                            :labels,
                                            :dimensions,
                                            :wigner_types,
                                            :frozen_lower,
                                            :outer_upper,
                                        ),
                                        Tuple{
                                            Int64,
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{Int64, 1},
                                        },
                                    },
                                    1,
                                },
                                Array{
                                    NamedTuple{
                                        (
                                            :candidate_ids,
                                            :coefficients,
                                            :total_dimension,
                                            :nonzero_candidate_types,
                                            :total_block_multiplicity,
                                            :signature_multiplicities,
                                            :validation_status,
                                            :embedding_residuals,
                                            :validation_sha256,
                                        ),
                                        Tuple{
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{Array{Int64, 1}, 1},
                                            String,
                                            Array{
                                                NamedTuple{(:name, :value), Tuple{String, Float64}},
                                                1,
                                            },
                                            String,
                                        },
                                    },
                                    1,
                                },
                                Array{String, 1},
                            },
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.sum),
                Function,
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Any,
                        NTuple{18, Symbol},
                        NamedTuple{
                            (
                                :status,
                                :complete,
                                :representation_sha256,
                                :contract_sha256,
                                :compatibility,
                                :config_sha256,
                                :spinor,
                                :num_wannier,
                                :outer_mask_sha256,
                                :frozen_mask_sha256,
                                :candidates,
                                :radial_transform,
                                :visited_nodes,
                                :total_solution_count,
                                :truncated,
                                :signatures,
                                :solutions,
                                :diagnostics,
                            ),
                            Tuple{
                                String,
                                Bool,
                                String,
                                String,
                                NamedTuple{
                                    (
                                        :upstream_package,
                                        :upstream_version,
                                        :upstream_commit,
                                        :upstream_source_sha256,
                                        :parity_eligible,
                                        :scope,
                                        :character_tolerance,
                                        :character_round_digits,
                                        :little_group_tolerance,
                                    ),
                                    Tuple{
                                        String,
                                        String,
                                        String,
                                        String,
                                        Bool,
                                        String,
                                        Float64,
                                        Int64,
                                        Float64,
                                    },
                                },
                                String,
                                Bool,
                                Int64,
                                String,
                                String,
                                Array{
                                    NamedTuple{
                                        (
                                            :id,
                                            :min_multiplicity,
                                            :max_multiplicity,
                                            :fixed_multiplicity,
                                            :specs,
                                        ),
                                        Tuple{
                                            String,
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{
                                                NamedTuple{
                                                    (
                                                        :selector,
                                                        :orbital_sets,
                                                        :positions_fractional,
                                                        :local_bases,
                                                    ),
                                                    Tuple{
                                                        String,
                                                        Array{String, 1},
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                    },
                                                },
                                                1,
                                            },
                                        },
                                    },
                                    1,
                                },
                                NamedTuple{(:method, :gauss_laguerre_order), Tuple{String, Int64}},
                                Int64,
                                Int64,
                                Bool,
                                Array{
                                    NamedTuple{
                                        (
                                            :kpoint_index,
                                            :labels,
                                            :dimensions,
                                            :wigner_types,
                                            :frozen_lower,
                                            :outer_upper,
                                        ),
                                        Tuple{
                                            Int64,
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{Int64, 1},
                                        },
                                    },
                                    1,
                                },
                                Array{
                                    NamedTuple{
                                        (
                                            :candidate_ids,
                                            :coefficients,
                                            :total_dimension,
                                            :nonzero_candidate_types,
                                            :total_block_multiplicity,
                                            :signature_multiplicities,
                                            :validation_status,
                                            :embedding_residuals,
                                            :validation_sha256,
                                        ),
                                        Tuple{
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{Array{Int64, 1}, 1},
                                            String,
                                            Array{
                                                NamedTuple{(:name, :value), Tuple{String, Float64}},
                                                1,
                                            },
                                            String,
                                        },
                                    },
                                    1,
                                },
                                Array{String, 1},
                            },
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##sum#342",
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(Base.sum),
                Function,
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Any,
                        NTuple{18, Symbol},
                        NamedTuple{
                            (
                                :status,
                                :complete,
                                :representation_sha256,
                                :contract_sha256,
                                :compatibility,
                                :config_sha256,
                                :spinor,
                                :num_wannier,
                                :outer_mask_sha256,
                                :frozen_mask_sha256,
                                :candidates,
                                :radial_transform,
                                :visited_nodes,
                                :total_solution_count,
                                :truncated,
                                :signatures,
                                :solutions,
                                :diagnostics,
                            ),
                            Tuple{
                                String,
                                Bool,
                                String,
                                String,
                                NamedTuple{
                                    (
                                        :upstream_package,
                                        :upstream_version,
                                        :upstream_commit,
                                        :upstream_source_sha256,
                                        :parity_eligible,
                                        :scope,
                                        :character_tolerance,
                                        :character_round_digits,
                                        :little_group_tolerance,
                                    ),
                                    Tuple{
                                        String,
                                        String,
                                        String,
                                        String,
                                        Bool,
                                        String,
                                        Float64,
                                        Int64,
                                        Float64,
                                    },
                                },
                                String,
                                Bool,
                                Int64,
                                String,
                                String,
                                Array{
                                    NamedTuple{
                                        (
                                            :id,
                                            :min_multiplicity,
                                            :max_multiplicity,
                                            :fixed_multiplicity,
                                            :specs,
                                        ),
                                        Tuple{
                                            String,
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{
                                                NamedTuple{
                                                    (
                                                        :selector,
                                                        :orbital_sets,
                                                        :positions_fractional,
                                                        :local_bases,
                                                    ),
                                                    Tuple{
                                                        String,
                                                        Array{String, 1},
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                    },
                                                },
                                                1,
                                            },
                                        },
                                    },
                                    1,
                                },
                                NamedTuple{(:method, :gauss_laguerre_order), Tuple{String, Int64}},
                                Int64,
                                Int64,
                                Bool,
                                Array{
                                    NamedTuple{
                                        (
                                            :kpoint_index,
                                            :labels,
                                            :dimensions,
                                            :wigner_types,
                                            :frozen_lower,
                                            :outer_upper,
                                        ),
                                        Tuple{
                                            Int64,
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{Int64, 1},
                                        },
                                    },
                                    1,
                                },
                                Array{
                                    NamedTuple{
                                        (
                                            :candidate_ids,
                                            :coefficients,
                                            :total_dimension,
                                            :nonzero_candidate_types,
                                            :total_block_multiplicity,
                                            :signature_multiplicities,
                                            :validation_status,
                                            :embedding_residuals,
                                            :validation_sha256,
                                        ),
                                        Tuple{
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{Array{Int64, 1}, 1},
                                            String,
                                            Array{
                                                NamedTuple{(:name, :value), Tuple{String, Float64}},
                                                1,
                                            },
                                            String,
                                        },
                                    },
                                    1,
                                },
                                Array{String, 1},
                            },
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.mapreduce),
                Function,
                Function,
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Any,
                        NTuple{18, Symbol},
                        NamedTuple{
                            (
                                :status,
                                :complete,
                                :representation_sha256,
                                :contract_sha256,
                                :compatibility,
                                :config_sha256,
                                :spinor,
                                :num_wannier,
                                :outer_mask_sha256,
                                :frozen_mask_sha256,
                                :candidates,
                                :radial_transform,
                                :visited_nodes,
                                :total_solution_count,
                                :truncated,
                                :signatures,
                                :solutions,
                                :diagnostics,
                            ),
                            Tuple{
                                String,
                                Bool,
                                String,
                                String,
                                NamedTuple{
                                    (
                                        :upstream_package,
                                        :upstream_version,
                                        :upstream_commit,
                                        :upstream_source_sha256,
                                        :parity_eligible,
                                        :scope,
                                        :character_tolerance,
                                        :character_round_digits,
                                        :little_group_tolerance,
                                    ),
                                    Tuple{
                                        String,
                                        String,
                                        String,
                                        String,
                                        Bool,
                                        String,
                                        Float64,
                                        Int64,
                                        Float64,
                                    },
                                },
                                String,
                                Bool,
                                Int64,
                                String,
                                String,
                                Array{
                                    NamedTuple{
                                        (
                                            :id,
                                            :min_multiplicity,
                                            :max_multiplicity,
                                            :fixed_multiplicity,
                                            :specs,
                                        ),
                                        Tuple{
                                            String,
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{
                                                NamedTuple{
                                                    (
                                                        :selector,
                                                        :orbital_sets,
                                                        :positions_fractional,
                                                        :local_bases,
                                                    ),
                                                    Tuple{
                                                        String,
                                                        Array{String, 1},
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                    },
                                                },
                                                1,
                                            },
                                        },
                                    },
                                    1,
                                },
                                NamedTuple{(:method, :gauss_laguerre_order), Tuple{String, Int64}},
                                Int64,
                                Int64,
                                Bool,
                                Array{
                                    NamedTuple{
                                        (
                                            :kpoint_index,
                                            :labels,
                                            :dimensions,
                                            :wigner_types,
                                            :frozen_lower,
                                            :outer_upper,
                                        ),
                                        Tuple{
                                            Int64,
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{Int64, 1},
                                        },
                                    },
                                    1,
                                },
                                Array{
                                    NamedTuple{
                                        (
                                            :candidate_ids,
                                            :coefficients,
                                            :total_dimension,
                                            :nonzero_candidate_types,
                                            :total_block_multiplicity,
                                            :signature_multiplicities,
                                            :validation_status,
                                            :embedding_residuals,
                                            :validation_sha256,
                                        ),
                                        Tuple{
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{Array{Int64, 1}, 1},
                                            String,
                                            Array{
                                                NamedTuple{(:name, :value), Tuple{String, Float64}},
                                                1,
                                            },
                                            String,
                                        },
                                    },
                                    1,
                                },
                                Array{String, 1},
                            },
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##mapreduce#339",
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(Base.mapreduce),
                Function,
                Function,
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Any,
                        NTuple{18, Symbol},
                        NamedTuple{
                            (
                                :status,
                                :complete,
                                :representation_sha256,
                                :contract_sha256,
                                :compatibility,
                                :config_sha256,
                                :spinor,
                                :num_wannier,
                                :outer_mask_sha256,
                                :frozen_mask_sha256,
                                :candidates,
                                :radial_transform,
                                :visited_nodes,
                                :total_solution_count,
                                :truncated,
                                :signatures,
                                :solutions,
                                :diagnostics,
                            ),
                            Tuple{
                                String,
                                Bool,
                                String,
                                String,
                                NamedTuple{
                                    (
                                        :upstream_package,
                                        :upstream_version,
                                        :upstream_commit,
                                        :upstream_source_sha256,
                                        :parity_eligible,
                                        :scope,
                                        :character_tolerance,
                                        :character_round_digits,
                                        :little_group_tolerance,
                                    ),
                                    Tuple{
                                        String,
                                        String,
                                        String,
                                        String,
                                        Bool,
                                        String,
                                        Float64,
                                        Int64,
                                        Float64,
                                    },
                                },
                                String,
                                Bool,
                                Int64,
                                String,
                                String,
                                Array{
                                    NamedTuple{
                                        (
                                            :id,
                                            :min_multiplicity,
                                            :max_multiplicity,
                                            :fixed_multiplicity,
                                            :specs,
                                        ),
                                        Tuple{
                                            String,
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{
                                                NamedTuple{
                                                    (
                                                        :selector,
                                                        :orbital_sets,
                                                        :positions_fractional,
                                                        :local_bases,
                                                    ),
                                                    Tuple{
                                                        String,
                                                        Array{String, 1},
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                    },
                                                },
                                                1,
                                            },
                                        },
                                    },
                                    1,
                                },
                                NamedTuple{(:method, :gauss_laguerre_order), Tuple{String, Int64}},
                                Int64,
                                Int64,
                                Bool,
                                Array{
                                    NamedTuple{
                                        (
                                            :kpoint_index,
                                            :labels,
                                            :dimensions,
                                            :wigner_types,
                                            :frozen_lower,
                                            :outer_upper,
                                        ),
                                        Tuple{
                                            Int64,
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{Int64, 1},
                                        },
                                    },
                                    1,
                                },
                                Array{
                                    NamedTuple{
                                        (
                                            :candidate_ids,
                                            :coefficients,
                                            :total_dimension,
                                            :nonzero_candidate_types,
                                            :total_block_multiplicity,
                                            :signature_multiplicities,
                                            :validation_status,
                                            :embedding_residuals,
                                            :validation_sha256,
                                        ),
                                        Tuple{
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{Array{Int64, 1}, 1},
                                            String,
                                            Array{
                                                NamedTuple{(:name, :value), Tuple{String, Float64}},
                                                1,
                                            },
                                            String,
                                        },
                                    },
                                    1,
                                },
                                Array{String, 1},
                            },
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.mapfoldl),
                Function,
                Function,
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Any,
                        NTuple{18, Symbol},
                        NamedTuple{
                            (
                                :status,
                                :complete,
                                :representation_sha256,
                                :contract_sha256,
                                :compatibility,
                                :config_sha256,
                                :spinor,
                                :num_wannier,
                                :outer_mask_sha256,
                                :frozen_mask_sha256,
                                :candidates,
                                :radial_transform,
                                :visited_nodes,
                                :total_solution_count,
                                :truncated,
                                :signatures,
                                :solutions,
                                :diagnostics,
                            ),
                            Tuple{
                                String,
                                Bool,
                                String,
                                String,
                                NamedTuple{
                                    (
                                        :upstream_package,
                                        :upstream_version,
                                        :upstream_commit,
                                        :upstream_source_sha256,
                                        :parity_eligible,
                                        :scope,
                                        :character_tolerance,
                                        :character_round_digits,
                                        :little_group_tolerance,
                                    ),
                                    Tuple{
                                        String,
                                        String,
                                        String,
                                        String,
                                        Bool,
                                        String,
                                        Float64,
                                        Int64,
                                        Float64,
                                    },
                                },
                                String,
                                Bool,
                                Int64,
                                String,
                                String,
                                Array{
                                    NamedTuple{
                                        (
                                            :id,
                                            :min_multiplicity,
                                            :max_multiplicity,
                                            :fixed_multiplicity,
                                            :specs,
                                        ),
                                        Tuple{
                                            String,
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{
                                                NamedTuple{
                                                    (
                                                        :selector,
                                                        :orbital_sets,
                                                        :positions_fractional,
                                                        :local_bases,
                                                    ),
                                                    Tuple{
                                                        String,
                                                        Array{String, 1},
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                    },
                                                },
                                                1,
                                            },
                                        },
                                    },
                                    1,
                                },
                                NamedTuple{(:method, :gauss_laguerre_order), Tuple{String, Int64}},
                                Int64,
                                Int64,
                                Bool,
                                Array{
                                    NamedTuple{
                                        (
                                            :kpoint_index,
                                            :labels,
                                            :dimensions,
                                            :wigner_types,
                                            :frozen_lower,
                                            :outer_upper,
                                        ),
                                        Tuple{
                                            Int64,
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{Int64, 1},
                                        },
                                    },
                                    1,
                                },
                                Array{
                                    NamedTuple{
                                        (
                                            :candidate_ids,
                                            :coefficients,
                                            :total_dimension,
                                            :nonzero_candidate_types,
                                            :total_block_multiplicity,
                                            :signature_multiplicities,
                                            :validation_status,
                                            :embedding_residuals,
                                            :validation_sha256,
                                        ),
                                        Tuple{
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{Array{Int64, 1}, 1},
                                            String,
                                            Array{
                                                NamedTuple{(:name, :value), Tuple{String, Float64}},
                                                1,
                                            },
                                            String,
                                        },
                                    },
                                    1,
                                },
                                Array{String, 1},
                            },
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##mapfoldl#335",
                Base._InitialValue,
                typeof(Base.mapfoldl),
                Function,
                Function,
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Any,
                        NTuple{18, Symbol},
                        NamedTuple{
                            (
                                :status,
                                :complete,
                                :representation_sha256,
                                :contract_sha256,
                                :compatibility,
                                :config_sha256,
                                :spinor,
                                :num_wannier,
                                :outer_mask_sha256,
                                :frozen_mask_sha256,
                                :candidates,
                                :radial_transform,
                                :visited_nodes,
                                :total_solution_count,
                                :truncated,
                                :signatures,
                                :solutions,
                                :diagnostics,
                            ),
                            Tuple{
                                String,
                                Bool,
                                String,
                                String,
                                NamedTuple{
                                    (
                                        :upstream_package,
                                        :upstream_version,
                                        :upstream_commit,
                                        :upstream_source_sha256,
                                        :parity_eligible,
                                        :scope,
                                        :character_tolerance,
                                        :character_round_digits,
                                        :little_group_tolerance,
                                    ),
                                    Tuple{
                                        String,
                                        String,
                                        String,
                                        String,
                                        Bool,
                                        String,
                                        Float64,
                                        Int64,
                                        Float64,
                                    },
                                },
                                String,
                                Bool,
                                Int64,
                                String,
                                String,
                                Array{
                                    NamedTuple{
                                        (
                                            :id,
                                            :min_multiplicity,
                                            :max_multiplicity,
                                            :fixed_multiplicity,
                                            :specs,
                                        ),
                                        Tuple{
                                            String,
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{
                                                NamedTuple{
                                                    (
                                                        :selector,
                                                        :orbital_sets,
                                                        :positions_fractional,
                                                        :local_bases,
                                                    ),
                                                    Tuple{
                                                        String,
                                                        Array{String, 1},
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                    },
                                                },
                                                1,
                                            },
                                        },
                                    },
                                    1,
                                },
                                NamedTuple{(:method, :gauss_laguerre_order), Tuple{String, Int64}},
                                Int64,
                                Int64,
                                Bool,
                                Array{
                                    NamedTuple{
                                        (
                                            :kpoint_index,
                                            :labels,
                                            :dimensions,
                                            :wigner_types,
                                            :frozen_lower,
                                            :outer_upper,
                                        ),
                                        Tuple{
                                            Int64,
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{Int64, 1},
                                        },
                                    },
                                    1,
                                },
                                Array{
                                    NamedTuple{
                                        (
                                            :candidate_ids,
                                            :coefficients,
                                            :total_dimension,
                                            :nonzero_candidate_types,
                                            :total_block_multiplicity,
                                            :signature_multiplicities,
                                            :validation_status,
                                            :embedding_residuals,
                                            :validation_sha256,
                                        ),
                                        Tuple{
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{Array{Int64, 1}, 1},
                                            String,
                                            Array{
                                                NamedTuple{(:name, :value), Tuple{String, Float64}},
                                                1,
                                            },
                                            String,
                                        },
                                    },
                                    1,
                                },
                                Array{String, 1},
                            },
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                typeof(Base.add_sum),
                Base._InitialValue,
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Any,
                        NTuple{18, Symbol},
                        NamedTuple{
                            (
                                :status,
                                :complete,
                                :representation_sha256,
                                :contract_sha256,
                                :compatibility,
                                :config_sha256,
                                :spinor,
                                :num_wannier,
                                :outer_mask_sha256,
                                :frozen_mask_sha256,
                                :candidates,
                                :radial_transform,
                                :visited_nodes,
                                :total_solution_count,
                                :truncated,
                                :signatures,
                                :solutions,
                                :diagnostics,
                            ),
                            Tuple{
                                String,
                                Bool,
                                String,
                                String,
                                NamedTuple{
                                    (
                                        :upstream_package,
                                        :upstream_version,
                                        :upstream_commit,
                                        :upstream_source_sha256,
                                        :parity_eligible,
                                        :scope,
                                        :character_tolerance,
                                        :character_round_digits,
                                        :little_group_tolerance,
                                    ),
                                    Tuple{
                                        String,
                                        String,
                                        String,
                                        String,
                                        Bool,
                                        String,
                                        Float64,
                                        Int64,
                                        Float64,
                                    },
                                },
                                String,
                                Bool,
                                Int64,
                                String,
                                String,
                                Array{
                                    NamedTuple{
                                        (
                                            :id,
                                            :min_multiplicity,
                                            :max_multiplicity,
                                            :fixed_multiplicity,
                                            :specs,
                                        ),
                                        Tuple{
                                            String,
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{
                                                NamedTuple{
                                                    (
                                                        :selector,
                                                        :orbital_sets,
                                                        :positions_fractional,
                                                        :local_bases,
                                                    ),
                                                    Tuple{
                                                        String,
                                                        Array{String, 1},
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                        NamedTuple{
                                                            (:dimensions, :values),
                                                            Tuple{
                                                                Array{Int64, 1},
                                                                Array{Float64, 1},
                                                            },
                                                        },
                                                    },
                                                },
                                                1,
                                            },
                                        },
                                    },
                                    1,
                                },
                                NamedTuple{(:method, :gauss_laguerre_order), Tuple{String, Int64}},
                                Int64,
                                Int64,
                                Bool,
                                Array{
                                    NamedTuple{
                                        (
                                            :kpoint_index,
                                            :labels,
                                            :dimensions,
                                            :wigner_types,
                                            :frozen_lower,
                                            :outer_upper,
                                        ),
                                        Tuple{
                                            Int64,
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Array{Int64, 1},
                                        },
                                    },
                                    1,
                                },
                                Array{
                                    NamedTuple{
                                        (
                                            :candidate_ids,
                                            :coefficients,
                                            :total_dimension,
                                            :nonzero_candidate_types,
                                            :total_block_multiplicity,
                                            :signature_multiplicities,
                                            :validation_status,
                                            :embedding_residuals,
                                            :validation_sha256,
                                        ),
                                        Tuple{
                                            Array{String, 1},
                                            Array{Int64, 1},
                                            Int64,
                                            Int64,
                                            Int64,
                                            Array{Array{Int64, 1}, 1},
                                            String,
                                            Array{
                                                NamedTuple{(:name, :value), Tuple{String, Float64}},
                                                1,
                                            },
                                            String,
                                        },
                                    },
                                    1,
                                },
                                Array{String, 1},
                            },
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.foldl_impl),
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#61#62",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Base._InitialValue,
                Base.Pairs{
                    Symbol,
                    Any,
                    NTuple{18, Symbol},
                    NamedTuple{
                        (
                            :status,
                            :complete,
                            :representation_sha256,
                            :contract_sha256,
                            :compatibility,
                            :config_sha256,
                            :spinor,
                            :num_wannier,
                            :outer_mask_sha256,
                            :frozen_mask_sha256,
                            :candidates,
                            :radial_transform,
                            :visited_nodes,
                            :total_solution_count,
                            :truncated,
                            :signatures,
                            :solutions,
                            :diagnostics,
                        ),
                        Tuple{
                            String,
                            Bool,
                            String,
                            String,
                            NamedTuple{
                                (
                                    :upstream_package,
                                    :upstream_version,
                                    :upstream_commit,
                                    :upstream_source_sha256,
                                    :parity_eligible,
                                    :scope,
                                    :character_tolerance,
                                    :character_round_digits,
                                    :little_group_tolerance,
                                ),
                                Tuple{
                                    String,
                                    String,
                                    String,
                                    String,
                                    Bool,
                                    String,
                                    Float64,
                                    Int64,
                                    Float64,
                                },
                            },
                            String,
                            Bool,
                            Int64,
                            String,
                            String,
                            Array{
                                NamedTuple{
                                    (
                                        :id,
                                        :min_multiplicity,
                                        :max_multiplicity,
                                        :fixed_multiplicity,
                                        :specs,
                                    ),
                                    Tuple{
                                        String,
                                        Int64,
                                        Int64,
                                        Int64,
                                        Array{
                                            NamedTuple{
                                                (
                                                    :selector,
                                                    :orbital_sets,
                                                    :positions_fractional,
                                                    :local_bases,
                                                ),
                                                Tuple{
                                                    String,
                                                    Array{String, 1},
                                                    NamedTuple{
                                                        (:dimensions, :values),
                                                        Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                    },
                                                    NamedTuple{
                                                        (:dimensions, :values),
                                                        Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                    },
                                                },
                                            },
                                            1,
                                        },
                                    },
                                },
                                1,
                            },
                            NamedTuple{(:method, :gauss_laguerre_order), Tuple{String, Int64}},
                            Int64,
                            Int64,
                            Bool,
                            Array{
                                NamedTuple{
                                    (
                                        :kpoint_index,
                                        :labels,
                                        :dimensions,
                                        :wigner_types,
                                        :frozen_lower,
                                        :outer_upper,
                                    ),
                                    Tuple{
                                        Int64,
                                        Array{String, 1},
                                        Array{Int64, 1},
                                        Array{String, 1},
                                        Array{Int64, 1},
                                        Array{Int64, 1},
                                    },
                                },
                                1,
                            },
                            Array{
                                NamedTuple{
                                    (
                                        :candidate_ids,
                                        :coefficients,
                                        :total_dimension,
                                        :nonzero_candidate_types,
                                        :total_block_multiplicity,
                                        :signature_multiplicities,
                                        :validation_status,
                                        :embedding_residuals,
                                        :validation_sha256,
                                    ),
                                    Tuple{
                                        Array{String, 1},
                                        Array{Int64, 1},
                                        Int64,
                                        Int64,
                                        Int64,
                                        Array{Array{Int64, 1}, 1},
                                        String,
                                        Array{
                                            NamedTuple{(:name, :value), Tuple{String, Float64}},
                                            1,
                                        },
                                        String,
                                    },
                                },
                                1,
                            },
                            Array{String, 1},
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base._foldl_impl),
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#61#62",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Base._InitialValue,
                Base.Pairs{
                    Symbol,
                    Any,
                    NTuple{18, Symbol},
                    NamedTuple{
                        (
                            :status,
                            :complete,
                            :representation_sha256,
                            :contract_sha256,
                            :compatibility,
                            :config_sha256,
                            :spinor,
                            :num_wannier,
                            :outer_mask_sha256,
                            :frozen_mask_sha256,
                            :candidates,
                            :radial_transform,
                            :visited_nodes,
                            :total_solution_count,
                            :truncated,
                            :signatures,
                            :solutions,
                            :diagnostics,
                        ),
                        Tuple{
                            String,
                            Bool,
                            String,
                            String,
                            NamedTuple{
                                (
                                    :upstream_package,
                                    :upstream_version,
                                    :upstream_commit,
                                    :upstream_source_sha256,
                                    :parity_eligible,
                                    :scope,
                                    :character_tolerance,
                                    :character_round_digits,
                                    :little_group_tolerance,
                                ),
                                Tuple{
                                    String,
                                    String,
                                    String,
                                    String,
                                    Bool,
                                    String,
                                    Float64,
                                    Int64,
                                    Float64,
                                },
                            },
                            String,
                            Bool,
                            Int64,
                            String,
                            String,
                            Array{
                                NamedTuple{
                                    (
                                        :id,
                                        :min_multiplicity,
                                        :max_multiplicity,
                                        :fixed_multiplicity,
                                        :specs,
                                    ),
                                    Tuple{
                                        String,
                                        Int64,
                                        Int64,
                                        Int64,
                                        Array{
                                            NamedTuple{
                                                (
                                                    :selector,
                                                    :orbital_sets,
                                                    :positions_fractional,
                                                    :local_bases,
                                                ),
                                                Tuple{
                                                    String,
                                                    Array{String, 1},
                                                    NamedTuple{
                                                        (:dimensions, :values),
                                                        Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                    },
                                                    NamedTuple{
                                                        (:dimensions, :values),
                                                        Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                    },
                                                },
                                            },
                                            1,
                                        },
                                    },
                                },
                                1,
                            },
                            NamedTuple{(:method, :gauss_laguerre_order), Tuple{String, Int64}},
                            Int64,
                            Int64,
                            Bool,
                            Array{
                                NamedTuple{
                                    (
                                        :kpoint_index,
                                        :labels,
                                        :dimensions,
                                        :wigner_types,
                                        :frozen_lower,
                                        :outer_upper,
                                    ),
                                    Tuple{
                                        Int64,
                                        Array{String, 1},
                                        Array{Int64, 1},
                                        Array{String, 1},
                                        Array{Int64, 1},
                                        Array{Int64, 1},
                                    },
                                },
                                1,
                            },
                            Array{
                                NamedTuple{
                                    (
                                        :candidate_ids,
                                        :coefficients,
                                        :total_dimension,
                                        :nonzero_candidate_types,
                                        :total_block_multiplicity,
                                        :signature_multiplicities,
                                        :validation_status,
                                        :embedding_residuals,
                                        :validation_sha256,
                                    ),
                                    Tuple{
                                        Array{String, 1},
                                        Array{Int64, 1},
                                        Int64,
                                        Int64,
                                        Int64,
                                        Array{Array{Int64, 1}, 1},
                                        String,
                                        Array{
                                            NamedTuple{(:name, :value), Tuple{String, Float64}},
                                            1,
                                        },
                                        String,
                                    },
                                },
                                1,
                            },
                            Array{String, 1},
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                NamedTuple{
                    (
                        :upstream_package,
                        :upstream_version,
                        :upstream_commit,
                        :upstream_source_sha256,
                        :parity_eligible,
                        :scope,
                        :character_tolerance,
                        :character_round_digits,
                        :little_group_tolerance,
                    ),
                    Tuple{String, String, String, String, Bool, String, Float64, Int64, Float64},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                Array{
                    NamedTuple{
                        (:id, :min_multiplicity, :max_multiplicity, :fixed_multiplicity, :specs),
                        Tuple{
                            String,
                            Int64,
                            Int64,
                            Int64,
                            Array{
                                NamedTuple{
                                    (:selector, :orbital_sets, :positions_fractional, :local_bases),
                                    Tuple{
                                        String,
                                        Array{String, 1},
                                        NamedTuple{
                                            (:dimensions, :values),
                                            Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                        },
                                        NamedTuple{
                                            (:dimensions, :values),
                                            Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                        },
                                    },
                                },
                                1,
                            },
                        },
                    },
                    1,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.sum),
                Function,
                Base.Generator{
                    Base.OneTo{Int64},
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{
                            NamedTuple{
                                (
                                    :id,
                                    :min_multiplicity,
                                    :max_multiplicity,
                                    :fixed_multiplicity,
                                    :specs,
                                ),
                                Tuple{
                                    String,
                                    Int64,
                                    Int64,
                                    Int64,
                                    Array{
                                        NamedTuple{
                                            (
                                                :selector,
                                                :orbital_sets,
                                                :positions_fractional,
                                                :local_bases,
                                            ),
                                            Tuple{
                                                String,
                                                Array{String, 1},
                                                NamedTuple{
                                                    (:dimensions, :values),
                                                    Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                },
                                                NamedTuple{
                                                    (:dimensions, :values),
                                                    Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                },
                                            },
                                        },
                                        1,
                                    },
                                },
                            },
                            1,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##mapfoldl#335",
                Base._InitialValue,
                typeof(Base.mapfoldl),
                Function,
                Function,
                Base.Generator{
                    Base.OneTo{Int64},
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{
                            NamedTuple{
                                (
                                    :id,
                                    :min_multiplicity,
                                    :max_multiplicity,
                                    :fixed_multiplicity,
                                    :specs,
                                ),
                                Tuple{
                                    String,
                                    Int64,
                                    Int64,
                                    Int64,
                                    Array{
                                        NamedTuple{
                                            (
                                                :selector,
                                                :orbital_sets,
                                                :positions_fractional,
                                                :local_bases,
                                            ),
                                            Tuple{
                                                String,
                                                Array{String, 1},
                                                NamedTuple{
                                                    (:dimensions, :values),
                                                    Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                },
                                                NamedTuple{
                                                    (:dimensions, :values),
                                                    Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                },
                                            },
                                        },
                                        1,
                                    },
                                },
                            },
                            1,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                typeof(Base.add_sum),
                Base._InitialValue,
                Base.Generator{
                    Base.OneTo{Int64},
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{
                            NamedTuple{
                                (
                                    :id,
                                    :min_multiplicity,
                                    :max_multiplicity,
                                    :fixed_multiplicity,
                                    :specs,
                                ),
                                Tuple{
                                    String,
                                    Int64,
                                    Int64,
                                    Int64,
                                    Array{
                                        NamedTuple{
                                            (
                                                :selector,
                                                :orbital_sets,
                                                :positions_fractional,
                                                :local_bases,
                                            ),
                                            Tuple{
                                                String,
                                                Array{String, 1},
                                                NamedTuple{
                                                    (:dimensions, :values),
                                                    Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                },
                                                NamedTuple{
                                                    (:dimensions, :values),
                                                    Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                },
                                            },
                                        },
                                        1,
                                    },
                                },
                            },
                            1,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base._foldl_impl),
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{
                            NamedTuple{
                                (
                                    :id,
                                    :min_multiplicity,
                                    :max_multiplicity,
                                    :fixed_multiplicity,
                                    :specs,
                                ),
                                Tuple{
                                    String,
                                    Int64,
                                    Int64,
                                    Int64,
                                    Array{
                                        NamedTuple{
                                            (
                                                :selector,
                                                :orbital_sets,
                                                :positions_fractional,
                                                :local_bases,
                                            ),
                                            Tuple{
                                                String,
                                                Array{String, 1},
                                                NamedTuple{
                                                    (:dimensions, :values),
                                                    Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                },
                                                NamedTuple{
                                                    (:dimensions, :values),
                                                    Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                },
                                            },
                                        },
                                        1,
                                    },
                                },
                            },
                            1,
                        },
                    },
                    Base.MappingRF{
                        typeof(PAWMatrixElements.JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Base._InitialValue,
                Base.OneTo{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{
                            NamedTuple{
                                (
                                    :id,
                                    :min_multiplicity,
                                    :max_multiplicity,
                                    :fixed_multiplicity,
                                    :specs,
                                ),
                                Tuple{
                                    String,
                                    Int64,
                                    Int64,
                                    Int64,
                                    Array{
                                        NamedTuple{
                                            (
                                                :selector,
                                                :orbital_sets,
                                                :positions_fractional,
                                                :local_bases,
                                            ),
                                            Tuple{
                                                String,
                                                Array{String, 1},
                                                NamedTuple{
                                                    (:dimensions, :values),
                                                    Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                },
                                                NamedTuple{
                                                    (:dimensions, :values),
                                                    Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                                },
                                            },
                                        },
                                        1,
                                    },
                                },
                            },
                            1,
                        },
                    },
                    Base.MappingRF{
                        typeof(PAWMatrixElements.JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Base._InitialValue,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                PAWMatrixElements.JSON3.var"#59#60"{
                    Array{
                        NamedTuple{
                            (
                                :id,
                                :min_multiplicity,
                                :max_multiplicity,
                                :fixed_multiplicity,
                                :specs,
                            ),
                            Tuple{
                                String,
                                Int64,
                                Int64,
                                Int64,
                                Array{
                                    NamedTuple{
                                        (
                                            :selector,
                                            :orbital_sets,
                                            :positions_fractional,
                                            :local_bases,
                                        ),
                                        Tuple{
                                            String,
                                            Array{String, 1},
                                            NamedTuple{
                                                (:dimensions, :values),
                                                Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                            },
                                            NamedTuple{
                                                (:dimensions, :values),
                                                Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                            },
                                        },
                                    },
                                    1,
                                },
                            },
                        },
                        1,
                    },
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.foldl_impl),
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#61#62",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Base._InitialValue,
                Base.Pairs{
                    Symbol,
                    Any,
                    NTuple{5, Symbol},
                    NamedTuple{
                        (:id, :min_multiplicity, :max_multiplicity, :fixed_multiplicity, :specs),
                        Tuple{
                            String,
                            Int64,
                            Int64,
                            Int64,
                            Array{
                                NamedTuple{
                                    (:selector, :orbital_sets, :positions_fractional, :local_bases),
                                    Tuple{
                                        String,
                                        Array{String, 1},
                                        NamedTuple{
                                            (:dimensions, :values),
                                            Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                        },
                                        NamedTuple{
                                            (:dimensions, :values),
                                            Tuple{Array{Int64, 1}, Array{Float64, 1}},
                                        },
                                    },
                                },
                                1,
                            },
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                Array{
                    NamedTuple{
                        (:selector, :orbital_sets, :positions_fractional, :local_bases),
                        Tuple{
                            String,
                            Array{String, 1},
                            NamedTuple{
                                (:dimensions, :values),
                                Tuple{Array{Int64, 1}, Array{Float64, 1}},
                            },
                            NamedTuple{
                                (:dimensions, :values),
                                Tuple{Array{Int64, 1}, Array{Float64, 1}},
                            },
                        },
                    },
                    1,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base._foldl_impl),
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#61#62",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Base._InitialValue,
                Base.Pairs{
                    Symbol,
                    Any,
                    NTuple{4, Symbol},
                    NamedTuple{
                        (:selector, :orbital_sets, :positions_fractional, :local_bases),
                        Tuple{
                            String,
                            Array{String, 1},
                            NamedTuple{
                                (:dimensions, :values),
                                Tuple{Array{Int64, 1}, Array{Float64, 1}},
                            },
                            NamedTuple{
                                (:dimensions, :values),
                                Tuple{Array{Int64, 1}, Array{Float64, 1}},
                            },
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                NamedTuple{(:dimensions, :values), Tuple{Array{Int64, 1}, Array{Float64, 1}}},
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##sum#342",
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(Base.sum),
                Function,
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Array{T, 1} where T,
                        Tuple{Symbol, Symbol},
                        NamedTuple{
                            (:dimensions, :values),
                            Tuple{Array{Int64, 1}, Array{Float64, 1}},
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.mapreduce),
                Function,
                Function,
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Array{T, 1} where T,
                        Tuple{Symbol, Symbol},
                        NamedTuple{
                            (:dimensions, :values),
                            Tuple{Array{Int64, 1}, Array{Float64, 1}},
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##mapreduce#339",
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(Base.mapreduce),
                Function,
                Function,
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Array{T, 1} where T,
                        Tuple{Symbol, Symbol},
                        NamedTuple{
                            (:dimensions, :values),
                            Tuple{Array{Int64, 1}, Array{Float64, 1}},
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.mapfoldl),
                Function,
                Function,
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Array{T, 1} where T,
                        Tuple{Symbol, Symbol},
                        NamedTuple{
                            (:dimensions, :values),
                            Tuple{Array{Int64, 1}, Array{Float64, 1}},
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##mapfoldl#335",
                Base._InitialValue,
                typeof(Base.mapfoldl),
                Function,
                Function,
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Array{T, 1} where T,
                        Tuple{Symbol, Symbol},
                        NamedTuple{
                            (:dimensions, :values),
                            Tuple{Array{Int64, 1}, Array{Float64, 1}},
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                typeof(Base.add_sum),
                Base._InitialValue,
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Array{T, 1} where T,
                        Tuple{Symbol, Symbol},
                        NamedTuple{
                            (:dimensions, :values),
                            Tuple{Array{Int64, 1}, Array{Float64, 1}},
                        },
                    },
                    PAWMatrixElements.JSON3.var"#61#62",
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.foldl_impl),
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#61#62",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Base._InitialValue,
                Base.Pairs{
                    Symbol,
                    Array{T, 1} where T,
                    Tuple{Symbol, Symbol},
                    NamedTuple{(:dimensions, :values), Tuple{Array{Int64, 1}, Array{Float64, 1}}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base._foldl_impl),
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#61#62",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Base._InitialValue,
                Base.Pairs{
                    Symbol,
                    Array{T, 1} where T,
                    Tuple{Symbol, Symbol},
                    NamedTuple{(:dimensions, :values), Tuple{Array{Int64, 1}, Array{Float64, 1}}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#61#62",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Base._InitialValue,
                Pair{Symbol, Array{T, 1} where T},
            },
        )
        _record_early_prepare(
            Tuple{
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#61#62",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                UInt64,
                Pair{Symbol, Array{T, 1} where T},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                NamedTuple{(:method, :gauss_laguerre_order), Tuple{String, Int64}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                Array{
                    NamedTuple{
                        (
                            :kpoint_index,
                            :labels,
                            :dimensions,
                            :wigner_types,
                            :frozen_lower,
                            :outer_upper,
                        ),
                        Tuple{
                            Int64,
                            Array{String, 1},
                            Array{Int64, 1},
                            Array{String, 1},
                            Array{Int64, 1},
                            Array{Int64, 1},
                        },
                    },
                    1,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.sum),
                Function,
                Base.Generator{
                    Base.OneTo{Int64},
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{
                            NamedTuple{
                                (
                                    :kpoint_index,
                                    :labels,
                                    :dimensions,
                                    :wigner_types,
                                    :frozen_lower,
                                    :outer_upper,
                                ),
                                Tuple{
                                    Int64,
                                    Array{String, 1},
                                    Array{Int64, 1},
                                    Array{String, 1},
                                    Array{Int64, 1},
                                    Array{Int64, 1},
                                },
                            },
                            1,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##mapfoldl#335",
                Base._InitialValue,
                typeof(Base.mapfoldl),
                Function,
                Function,
                Base.Generator{
                    Base.OneTo{Int64},
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{
                            NamedTuple{
                                (
                                    :kpoint_index,
                                    :labels,
                                    :dimensions,
                                    :wigner_types,
                                    :frozen_lower,
                                    :outer_upper,
                                ),
                                Tuple{
                                    Int64,
                                    Array{String, 1},
                                    Array{Int64, 1},
                                    Array{String, 1},
                                    Array{Int64, 1},
                                    Array{Int64, 1},
                                },
                            },
                            1,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                typeof(Base.add_sum),
                Base._InitialValue,
                Base.Generator{
                    Base.OneTo{Int64},
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{
                            NamedTuple{
                                (
                                    :kpoint_index,
                                    :labels,
                                    :dimensions,
                                    :wigner_types,
                                    :frozen_lower,
                                    :outer_upper,
                                ),
                                Tuple{
                                    Int64,
                                    Array{String, 1},
                                    Array{Int64, 1},
                                    Array{String, 1},
                                    Array{Int64, 1},
                                    Array{Int64, 1},
                                },
                            },
                            1,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{
                            NamedTuple{
                                (
                                    :kpoint_index,
                                    :labels,
                                    :dimensions,
                                    :wigner_types,
                                    :frozen_lower,
                                    :outer_upper,
                                ),
                                Tuple{
                                    Int64,
                                    Array{String, 1},
                                    Array{Int64, 1},
                                    Array{String, 1},
                                    Array{Int64, 1},
                                    Array{Int64, 1},
                                },
                            },
                            1,
                        },
                    },
                    Base.MappingRF{
                        typeof(PAWMatrixElements.JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Base._InitialValue,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                Array{
                    NamedTuple{
                        (
                            :candidate_ids,
                            :coefficients,
                            :total_dimension,
                            :nonzero_candidate_types,
                            :total_block_multiplicity,
                            :signature_multiplicities,
                            :validation_status,
                            :embedding_residuals,
                            :validation_sha256,
                        ),
                        Tuple{
                            Array{String, 1},
                            Array{Int64, 1},
                            Int64,
                            Int64,
                            Int64,
                            Array{Array{Int64, 1}, 1},
                            String,
                            Array{NamedTuple{(:name, :value), Tuple{String, Float64}}, 1},
                            String,
                        },
                    },
                    1,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.sum),
                Function,
                Base.Generator{
                    Base.OneTo{Int64},
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{
                            NamedTuple{
                                (
                                    :candidate_ids,
                                    :coefficients,
                                    :total_dimension,
                                    :nonzero_candidate_types,
                                    :total_block_multiplicity,
                                    :signature_multiplicities,
                                    :validation_status,
                                    :embedding_residuals,
                                    :validation_sha256,
                                ),
                                Tuple{
                                    Array{String, 1},
                                    Array{Int64, 1},
                                    Int64,
                                    Int64,
                                    Int64,
                                    Array{Array{Int64, 1}, 1},
                                    String,
                                    Array{NamedTuple{(:name, :value), Tuple{String, Float64}}, 1},
                                    String,
                                },
                            },
                            1,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.var"##mapfoldl#335",
                Base._InitialValue,
                typeof(Base.mapfoldl),
                Function,
                Function,
                Base.Generator{
                    Base.OneTo{Int64},
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{
                            NamedTuple{
                                (
                                    :candidate_ids,
                                    :coefficients,
                                    :total_dimension,
                                    :nonzero_candidate_types,
                                    :total_block_multiplicity,
                                    :signature_multiplicities,
                                    :validation_status,
                                    :embedding_residuals,
                                    :validation_sha256,
                                ),
                                Tuple{
                                    Array{String, 1},
                                    Array{Int64, 1},
                                    Int64,
                                    Int64,
                                    Int64,
                                    Array{Array{Int64, 1}, 1},
                                    String,
                                    Array{NamedTuple{(:name, :value), Tuple{String, Float64}}, 1},
                                    String,
                                },
                            },
                            1,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                typeof(Base.add_sum),
                Base._InitialValue,
                Base.Generator{
                    Base.OneTo{Int64},
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{
                            NamedTuple{
                                (
                                    :candidate_ids,
                                    :coefficients,
                                    :total_dimension,
                                    :nonzero_candidate_types,
                                    :total_block_multiplicity,
                                    :signature_multiplicities,
                                    :validation_status,
                                    :embedding_residuals,
                                    :validation_sha256,
                                ),
                                Tuple{
                                    Array{String, 1},
                                    Array{Int64, 1},
                                    Int64,
                                    Int64,
                                    Int64,
                                    Array{Array{Int64, 1}, 1},
                                    String,
                                    Array{NamedTuple{(:name, :value), Tuple{String, Float64}}, 1},
                                    String,
                                },
                            },
                            1,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{
                            NamedTuple{
                                (
                                    :candidate_ids,
                                    :coefficients,
                                    :total_dimension,
                                    :nonzero_candidate_types,
                                    :total_block_multiplicity,
                                    :signature_multiplicities,
                                    :validation_status,
                                    :embedding_residuals,
                                    :validation_sha256,
                                ),
                                Tuple{
                                    Array{String, 1},
                                    Array{Int64, 1},
                                    Int64,
                                    Int64,
                                    Int64,
                                    Array{Array{Int64, 1}, 1},
                                    String,
                                    Array{NamedTuple{(:name, :value), Tuple{String, Float64}}, 1},
                                    String,
                                },
                            },
                            1,
                        },
                    },
                    Base.MappingRF{
                        typeof(PAWMatrixElements.JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Base._InitialValue,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{typeof(PAWMatrixElements.JSON3.defaultminimum), Array{Array{Int64, 1}, 1}},
        )
        _record_early_prepare(
            Tuple{
                typeof(PAWMatrixElements.JSON3.defaultminimum),
                Array{NamedTuple{(:name, :value), Tuple{String, Float64}}, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{NamedTuple{(:name, :value), Tuple{String, Float64}}, 1},
                    },
                    Base.MappingRF{
                        typeof(PAWMatrixElements.JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Base._InitialValue,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                Base.MappingRF{
                    PAWMatrixElements.JSON3.var"#59#60"{
                        Array{NamedTuple{(:name, :value), Tuple{String, Float64}}, 1},
                    },
                    Base.MappingRF{
                        typeof(PAWMatrixElements.JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.copyto_nonleaf!),
                Array{String, 1},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Tuple{Base.OneTo{Int64}},
                    typeof(getfield),
                    Tuple{
                        Base.Broadcast.Extruded{
                            Array{WannierNLQG.Wannierization.ProjectionCandidateSpec, 1},
                            Tuple{Bool},
                            Tuple{Int64},
                        },
                        Base.RefValue{Symbol},
                    },
                },
                Base.OneTo{Int64},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.WannierProjection.WannierProjectionBlock,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base._all),
                WannierNLQGWannierizationExt.ProjectionSearch.var"#144#148"{Array{String, 1}},
                Array{WannierNLQG.Wannierization.ProjectionRepresentationSolution, 1},
                Base.Colon,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base._all),
                WannierNLQGWannierizationExt.ProjectionSearch.var"#145#149"{Array{String, 1}},
                Array{WannierNLQG.Wannierization.ProjectionRepresentationSolution, 1},
                Base.Colon,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Wannierization.search_projection_representations),
                WannierNLQG.Wannierization.ProjectionRepresentationSearchConfig,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.WannierProjection.WannierProjectionBasis,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.ProjectionSearch.ProjectionProjectiveIrrep,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.ProjectionSearch.var"#30#36",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Symbol,
            },
        )
        false
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.ProjectionSearch.ProjectionRepresentationActionDecomposition,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.ProjectionSearch.ProjectionMagneticCorepresentation,
                    Base.Core.AddrSpace{Base.Core}(0x00),
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.ProjectionSearch.var"#58#62",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                Base.Iterators.var"#7#8"{
                    Tuple{
                        Array{Int64, 1},
                        Array{
                            WannierNLQGWannierizationExt.ProjectionSearch.ProjectionMagneticCorepresentation,
                            1,
                        },
                    },
                },
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.isvarargtype), Any})
        _record_early_prepare(
            Tuple{typeof(Base._similar_shape), Base.UnitRange{Int64}, Base.HasShape{1}},
        )
        _record_early_prepare(Tuple{Base.var"#13#14"{DataType}, Int64})
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.ProjectionSearch.var"#94#96",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Symbol,
            },
        )
        _record_early_prepare(Tuple{Type{NamedTuple{(:full,), T} where T <: Tuple}, Tuple{Bool}})
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{:not_atomic, Array{Float64, 1}, Base.Core.AddrSpace{Base.Core}(0x00)},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.ProjectionSearch.search_projection_representations,
                ),
                WannierNLQG.Wannierization.ProjectionRepresentationSearchConfig,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{Int64, 1},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.:(!=)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.copyto_nonleaf!),
                Array{String, 1},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Tuple{Base.OneTo{Int64}},
                    typeof(getfield),
                    Tuple{
                        Base.Broadcast.Extruded{
                            Array{
                                WannierNLQGWannierizationExt.ProjectionSearch.ProjectionProjectiveIrrep,
                                1,
                            },
                            Tuple{Bool},
                            Tuple{Int64},
                        },
                        Base.RefValue{Symbol},
                    },
                },
                Base.OneTo{Int64},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.copyto_nonleaf!),
                Array{Int64, 1},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Tuple{Base.OneTo{Int64}},
                    typeof(getfield),
                    Tuple{
                        Base.Broadcast.Extruded{
                            Array{
                                WannierNLQGWannierizationExt.ProjectionSearch.ProjectionProjectiveIrrep,
                                1,
                            },
                            Tuple{Bool},
                            Tuple{Int64},
                        },
                        Base.RefValue{Symbol},
                    },
                },
                Base.OneTo{Int64},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.fill), Symbol, Int64})
        _record_early_prepare(
            Tuple{
                Type{
                    Base.Broadcast.Broadcasted{
                        Style,
                        Axes,
                        F,
                        Args,
                    } where {
                        Args <: Tuple,
                    } where {
                        F,
                    } where {Axes} where Style <: Union{Nothing, Base.Broadcast.BroadcastStyle},
                },
                Base.Broadcast.DefaultArrayStyle{1},
                typeof(Base.:(*)),
                Tuple{Array{Int64, 1}, Array{Int64, 1}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.instantiate),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.:(*)),
                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.copy),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Tuple{Base.OneTo{Int64}},
                    typeof(Base.:(*)),
                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.vect),
                WannierNLQGWannierizationExt.ProjectionSearch.ProjectionRepresentationActionDecomposition,
                Vararg{
                    WannierNLQGWannierizationExt.ProjectionSearch.ProjectionRepresentationActionDecomposition,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.copyto_nonleaf!),
                Base.BitArray{1},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Tuple{Base.OneTo{Int64}},
                    typeof(getfield),
                    Tuple{
                        Base.Broadcast.Extruded{
                            Array{
                                WannierNLQGWannierizationExt.ProjectionSearch.ProjectionRepresentationActionDecomposition,
                                1,
                            },
                            Tuple{Bool},
                            Tuple{Int64},
                        },
                        Base.RefValue{Symbol},
                    },
                },
                Base.OneTo{Int64},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.copyto_nonleaf!),
                Array{Int64, 1},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Tuple{Base.OneTo{Int64}},
                    typeof(getfield),
                    Tuple{
                        Base.Broadcast.Extruded{
                            Array{WannierNLQG.WannierProjection.WannierProjectionBasis, 1},
                            Tuple{Bool},
                            Tuple{Int64},
                        },
                        Base.RefValue{Symbol},
                    },
                },
                Base.OneTo{Int64},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.ProjectionSearch.var"#visit#98"{
                    WannierNLQG.Wannierization.ProjectionRepresentationProblem,
                    Base.RefValue{Bool},
                    Base.RefValue{Int64},
                    Base.RefValue{Int64},
                    Array{Array{Int64, 1}, 1},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Int64, 2},
                    Array{Int64, 2},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Int64,
                    Int64,
                    Array{Int64, 1},
                    Array{Int64, 2},
                    Array{Int64, 1},
                    Int64,
                    Int64,
                    Int64,
                },
                Int64,
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.sortperm), Array{String, 1}})
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                Array{WannierNLQG.Wannierization.ProjectionCandidateSpec, 1},
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.ProjectionCandidateSpec,
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.iterate), Array{WannierNLQG.WannierProjection.ProjectionSpec, 1}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.push!),
                Array{WannierNLQG.WannierProjection.ProjectionSpec, 1},
                WannierNLQG.WannierProjection.ProjectionSpec,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.iterate),
                Array{WannierNLQG.WannierProjection.ProjectionSpec, 1},
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.vcat)})
        _record_early_prepare(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:visited_nodes, :total_solution_count, :signatures, :solutions, :diagnostics),
                    Tuple{
                        Int64,
                        Int64,
                        Array{WannierNLQG.Wannierization.ProjectionRepresentationSignature, 1},
                        Array{WannierNLQG.Wannierization.ProjectionRepresentationSolution, 1},
                        Array{Any, 1},
                    },
                },
                typeof(WannierNLQGWannierizationExt.ProjectionSearch._projection_search_result),
                WannierNLQG.Wannierization.ProjectionRepresentationSearchConfig,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                String,
                WannierNLQG.Wannierization.ProjectionRepresentationCompatibilityInfo,
                WannierNLQG.Wannierization.ProjectionRepresentationSearchStatus,
                Bool,
            },
        )
        _record_early_prepare(
            Tuple{
                Type{WannierNLQG.Wannierization.ProjectionRepresentationSearchResult},
                WannierNLQG.Wannierization.ProjectionRepresentationSearchStatus,
                Bool,
                String,
                String,
                WannierNLQG.Wannierization.ProjectionRepresentationCompatibilityInfo,
                String,
                String,
                Bool,
                Int64,
                String,
                String,
                Array{WannierNLQG.Wannierization.ProjectionCandidateSpec, 1},
                WannierNLQG.WannierProjection.ProjectionRadialTransformConfig,
                Int64,
                Int64,
                Bool,
                Array{WannierNLQG.Wannierization.ProjectionRepresentationSignature, 1},
                Array{WannierNLQG.Wannierization.ProjectionRepresentationSolution, 1},
                Array{Any, 1},
            },
        )
    end
end
