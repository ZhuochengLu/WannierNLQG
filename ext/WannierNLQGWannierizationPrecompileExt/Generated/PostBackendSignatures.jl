# Record post-backend signature coverage without running public workflows.
function _record_sequence(@nospecialize(signature))
    push!(SEQUENCE_DIRECT_RESULTS, precompile(signature))
    push!(
        SEQUENCE_BRIDGE_RESULTS,
        precompile(Tuple{typeof(_first_solve_compile_call), signature.parameters...}),
    )
    return nothing
end
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_sequence(
            Tuple{
                typeof(WannierNLQG.Wannierization.prepare_band_representation),
                WannierNLQG.Wannierization.BandRepresentationPreparationConfig,
            },
        )
        _record_sequence(
            Tuple{typeof(WannierNLQGWannierizationExt.resolve_wannierization_entrypoint), Symbol},
        )
        _record_sequence(Tuple{Type{NamedTuple{(:purpose,), T} where T <: Tuple}, Tuple{Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{16, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{15, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{14, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{13, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{12, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{11, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{10, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{9, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{8, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{7, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{6, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{5, Symbol}})
        _record_sequence(Tuple{typeof(Base.tail), NTuple{4, Symbol}})
        _record_sequence(
            Tuple{Type{NamedTuple{(:fclose_degree,), T} where T <: Tuple}, Tuple{Symbol}},
        )
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{Symbol, Symbol}, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{Symbol, Symbol}, Int64, Int64})
        _record_sequence(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    NamedTuple{names, T} where {T <: Tuple} where names,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.in), Symbol, Tuple{Symbol, Symbol, Symbol}})
        _record_sequence(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration.prepare_band_representation,
                ),
                WannierNLQG.Wannierization.BandRepresentationPreparationConfig,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.collect_to!),
                Array{Union{Nothing, Symbol}, 1},
                Base.Generator{
                    NTuple{24, Symbol},
                    WannierNLQGWannierizationExt.WorkflowOrchestration.var"#83#84"{
                        WannierNLQG.Wannierization.BandRepresentationPreparationConfig,
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.setindex_widen_up_to),
                Array{Union{Nothing, Symbol}, 1},
                WannierNLQG.Wannierization.CoefficientMappingSewing,
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.collect_to!),
                Array{Any, 1},
                Base.Generator{
                    NTuple{24, Symbol},
                    WannierNLQGWannierizationExt.WorkflowOrchestration.var"#83#84"{
                        WannierNLQG.Wannierization.BandRepresentationPreparationConfig,
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :construction_policy,
                        :wannierization_mode,
                        :source,
                        :sewing_backend,
                        :wavefunction_gauge_backend,
                        :authoritative_hamiltonian,
                        :wavefunction_gauge_hdf5,
                        :win_file,
                        :eig_file,
                        :projection_basis,
                        :band_representation,
                        :band_representation_hdf5,
                        :output_hdf5,
                        :outer_min_ev,
                        :outer_max_ev,
                        :frozen_min_ev,
                        :frozen_max_ev,
                        :frozen_states,
                        :num_wannier,
                        :symmetry_tolerance,
                        :degeneracy_tolerance_ev,
                        :representation_tolerance,
                        :target_center_matching_tolerance,
                        :compatibility_policy,
                    ),
                    Tuple{
                        Symbol,
                        Symbol,
                        Nothing,
                        WannierNLQG.Wannierization.CoefficientMappingSewing,
                        WannierNLQG.Wannierization.NativeEigenstateGauge,
                        WannierNLQG.Wannierization.NativeDFTHamiltonian,
                        Nothing,
                        String,
                        String,
                        WannierNLQG.WannierProjection.WannierProjectionBasis,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Nothing,
                        String,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Array{Tuple{Int64, Int64}, 1},
                        Int64,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Symbol,
                    },
                },
                Type{WannierNLQG.Wannierization.BandRepresentationPreparationConfig},
            },
        )
        _record_sequence(Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}})
        _record_sequence(Tuple{typeof(Base.zeros), Type{Float64}, Tuple{Int64, Int64}})
        _record_sequence(Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}})
        _record_sequence(Tuple{typeof(Base.falses), Tuple{Int64, Int64}})
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:preserve_public_origin_absence,), Tuple{Bool}},
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._representation_with_mode_contract,
                ),
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                WannierNLQG.Wannierization.BandRepresentationPreparationConfig,
            },
        )
        _record_sequence(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._validate_sewing_backend_identity,
                ),
                WannierNLQG.Wannierization.CoefficientMappingSewing,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        _record_sequence(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._validate_wavefunction_gauge_identity,
                ),
                WannierNLQG.Wannierization.NativeEigenstateGauge,
                Nothing,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        _record_sequence(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._validate_authoritative_hamiltonian_identity,
                ),
                WannierNLQG.Wannierization.NativeDFTHamiltonian,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        _record_sequence(Tuple{typeof(Base.size), Array{Float64, 2}})
        _record_sequence(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        _record_sequence(Tuple{typeof(Base.hcat), Array{Float64, 1}})
        _record_sequence(Tuple{typeof(Base.:(\)), Array{Float64, 2}, Array{Float64, 2}})
        _record_sequence(Tuple{typeof(Base.:(*)), Array{Float64, 2}, Array{Float64, 2}})
        _record_sequence(Tuple{typeof(Base.maximum), Function, Array{Float64, 2}})
        _record_sequence(
            Tuple{
                typeof(Base._mapreduce_dim),
                Function,
                Function,
                Base._InitialValue,
                Array{Float64, 2},
                Base.Colon,
            },
        )
        _record_sequence(
            Tuple{typeof(Base._all), typeof(Base.isfinite), Array{Float64, 2}, Base.Colon},
        )
        _record_sequence(Tuple{typeof(Base.minimum), Array{Float64, 1}})
        _record_sequence(Tuple{typeof(Base.maximum), Array{Float64, 1}})
        _record_sequence(Tuple{typeof(Base.max), Float64, Float64})
        _record_sequence(Tuple{typeof(Base.:(>)), Float64, Float64})
        _record_sequence(Tuple{typeof(Base.:(<=)), Float64, Float64})
        _record_sequence(
            Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.abs), Array{Float64, 2}},
        )
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
        _record_sequence(Tuple{typeof(Base.maybeview), Array{Float64, 2}, Base.BitArray{2}})
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
                typeof(Base.Broadcast.broadcasted),
                Type{Base.Complex{Float64}},
                Array{Float64, 2},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    Type{Base.Complex{Float64}},
                    Tuple{Array{Float64, 2}},
                },
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.identity),
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Array{Int64, 1}, Array{Int64, 1}, Int64},
                    false,
                },
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Array{Base.Complex{Float64}, 2}},
                },
            },
        )
        _record_sequence(Tuple{typeof(Base.hcat), Base.BitArray{1}, Base.BitArray{1}})
        _record_sequence(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :outer_min_ev,
                        :outer_max_ev,
                        :frozen_min_ev,
                        :frozen_max_ev,
                        :num_wannier,
                        :scoped_paw_thresholds,
                        :target_complement_maximum_element_ev,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.Wannierization.PAWGaugeThresholds,
                        Float64,
                    },
                },
                Type{WannierNLQG.Wannierization.TargetSubspaceQualificationContract},
                WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
            },
        )
        _record_sequence(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._star_authoritative_hamiltonian_sha256,
                ),
                WannierNLQG.Wannierization.NativeDFTHamiltonian,
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
                Base.Broadcast.Style{Tuple},
                typeof(Base.identity),
                Tuple{NTuple{4, Float64}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.Broadcast.DefaultArrayStyle{1},
                Array{Float64, 1},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.Style{Tuple},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{NTuple{4, Float64}},
                },
            },
        )
        _record_sequence(Tuple{typeof(Base.vec), Array{Float64, 2}})
        _record_sequence(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Float64, 1},
            },
        )
        _record_sequence(Tuple{typeof(Base.vec), Array{Int64, 2}})
        _record_sequence(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Int64, 1},
            },
        )
        _record_sequence(Tuple{typeof(Base.vec), Array{Int64, 3}})
        _record_sequence(Tuple{typeof(Base.vec), Array{Base.Complex{Float64}, 4}})
        _record_sequence(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Base.Complex{Float64}, 1},
            },
        )
        _record_sequence(Tuple{typeof(Base.vec), Array{Int64, 1}})
        _record_sequence(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (:public_origin_fallback_validated, :construction_policy),
                    Tuple{Bool, Symbol},
                },
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._effective_compatibility_policy,
                ),
                Symbol,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                Nothing,
            },
        )
        _record_sequence(
            Tuple{typeof(Base.getindex), Type{WannierNLQG.Wannierization.WannierizationDiagnostic}},
        )
        _record_sequence(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Wannierization.WannierizationDiagnostic,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_sequence(Tuple{typeof(Base.haskey), Base.Dict{String, String}, String})
        _record_sequence(
            Tuple{
                WannierNLQGWannierizationExt.WorkflowOrchestration.var"#75#79",
                NamedTuple{
                    (:stage, :code, :operation, :orbital_set, :value, :threshold, :result, :action),
                    Tuple{String, String, Int64, String, Float64, Float64, String, String},
                },
            },
        )
        _record_sequence(
            Tuple{
                WannierNLQGWannierizationExt.WorkflowOrchestration.var"#75#79",
                NamedTuple{
                    (:stage, :code, :operation, :value, :threshold, :result, :action),
                    Tuple{String, String, Int64, Float64, Float64, String, String},
                },
            },
        )
        _record_sequence(Tuple{typeof(Base.get), Base.Dict{String, String}, String, String})
        _record_sequence(Tuple{Base.var"##s128#278", Vararg{Any, 5}})
        _record_sequence(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :inventory,
                        :raw_diagnostics,
                        :qualification_scope,
                        :requested_policy,
                        :effective_policy,
                        :symmetry_tolerance_status,
                    ),
                    Tuple{
                        Nothing,
                        Array{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic, 1},
                        WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                        Symbol,
                        Symbol,
                        Symbol,
                    },
                },
                typeof(WannierNLQG.SymmetryFoundation.write_band_representation_hdf5),
                String,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                WannierNLQG.Wannierization.RepresentationCompatibilityReport,
            },
        )
        _record_sequence(Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}})
        _record_sequence(
            Tuple{typeof(Base._similar_shape), Base.StepRange{Int64, Int64}, Base.HasShape{1}},
        )
        _record_sequence(Tuple{Base.var"##s1116#1003", Vararg{Any, 5}})
        _record_sequence(Tuple{Base.var"##s1116#714", Vararg{Any, 6}})
        _record_sequence(
            Tuple{typeof(Base.Cartesian._nloops), Int64, Symbol, Symbol, Expr, Vararg{Expr}},
        )
        _record_sequence(
            Tuple{typeof(Base.Cartesian.lreplace!), QuoteNode, Base.Cartesian.LReplace{String}},
        )
        _record_sequence(Tuple{typeof(Base.Iterators.enumerate), NTuple{4, String}})
        _record_sequence(Tuple{Type{Base.Iterators.Enumerate{I} where I}, NTuple{4, String}})
        _record_sequence(Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{NTuple{4, String}}})
        _record_sequence(
            Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{NTuple{4, String}}, Tuple{Int64}},
        )
        _record_sequence(
            Tuple{typeof(Base.getproperty), Base.Iterators.Enumerate{NTuple{4, String}}, Symbol},
        )
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{Int64, String}, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Tuple{Int64, String}, Int64, Int64})
        _record_sequence(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{NTuple{4, String}},
                Tuple{Int64, Int64},
            },
        )
        _record_sequence(Tuple{typeof(Base.tail), Tuple{Int64, Int64}})
        _record_sequence(
            Tuple{Base.Iterators.var"#5#6"{Tuple{Array{Int64, 1}, Array{Int64, 1}}}, Int64},
        )
        _record_sequence(Tuple{typeof(Base.convert), Type{Bool}, Bool})
        _record_sequence(Tuple{Type{Pair{A, B} where {B} where A}, Symbol, UInt8})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{Symbol, UInt8}, Int64})
        _record_sequence(Tuple{typeof(Base.indexed_iterate), Pair{Symbol, UInt8}, Int64, Int64})

        # Foundation-owned coverage is compiled in its owning extension.

        _record_sequence(
            Tuple{
                typeof(Base.hasproperty),
                WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                Symbol,
            },
        )
        _record_sequence(Tuple{typeof(Base.collect), NTuple{4, Float64}})
        _record_sequence(
            Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 1}},
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{Float64},
                    Tuple{Array{Float64, 1}},
                },
            },
        )

        # Foundation-owned coverage is compiled in its owning extension.

        # Foundation-owned coverage is compiled in its owning extension.

        _record_sequence(Tuple{Type{Tuple}, Array{Float64, 1}})

        # Foundation-owned coverage is compiled in its owning extension.

        # Foundation-owned coverage is compiled in its owning extension.

        # Foundation-owned coverage is compiled in its owning extension.

        _record_sequence(Tuple{typeof(Base.repeat), Char, Int64})
        _record_sequence(Tuple{typeof(Base.setindex!), HDF5.Attributes, Float64, String})
        _record_sequence(Tuple{typeof(Base.setindex!), HDF5.Attributes, String, String})
        _record_sequence(Tuple{typeof(Base.setindex!), HDF5.Group, Array{Float64, 1}, String})

        # Foundation-owned coverage is compiled in its owning extension.

        _record_sequence(
            Tuple{
                typeof(Base.getindex),
                Type{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic},
                WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic,
                WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic,
                WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic,
                WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic,
                WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic,
                WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic,
                Vararg{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic},
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
        _record_sequence(Tuple{typeof(Base.prod), Tuple{Int64}})
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{9, 0}},
            },
        )
        _record_sequence(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{20, 0}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{40, 0}},
            },
        )
        _record_sequence(
            Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64, Int64},
        )
        _record_sequence(
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
        _record_sequence(
            Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64, Int64},
        )
        _record_sequence(
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
        _record_sequence(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{typeof(Base.axes), Array{Int64, 3}, Int64})

        # Foundation-owned coverage is compiled in its owning extension.

        _record_sequence(Tuple{Base.var"##s1116#691", Vararg{Any, 5}})

        # Foundation-owned coverage is compiled in its owning extension.

        _record_sequence(Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol})
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{15, 0}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{6, 0}},
            },
        )
        _record_sequence(Tuple{typeof(Base.transpose), Array{Float64, 2}})
        _record_sequence(
            Tuple{Type{Array{T, 2} where T}, LinearAlgebra.Transpose{Float64, Array{Float64, 2}}},
        )
        _record_sequence(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        _record_sequence(Tuple{typeof(Base.Broadcast.broadcasted), Type{Int64}, Array{Int64, 1}})
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{Int64},
                    Tuple{Array{Int64, 1}},
                },
            },
        )
        _record_sequence(Tuple{Type{Tuple}, Array{Int64, 1}})
        _record_sequence(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Dataset,
                HDF5.Datatype,
                Type{Base.Complex{Float64}},
            },
        )
        _record_sequence(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Int64,
                Vararg{Int64},
            },
        )
        _record_sequence(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                NTuple{4, Int64},
            },
        )
        _record_sequence(
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
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{30, 0}},
            },
        )
        _record_sequence(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties},
        )
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
        _record_sequence(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties},
        )
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties})
        _record_sequence(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties},
        )
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties})
        _record_sequence(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties})
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{33, 0}},
            },
        )
        _record_sequence(Tuple{typeof(Base.transpose), Array{Int64, 2}})
        _record_sequence(
            Tuple{
                typeof(Base.:(==)),
                LinearAlgebra.Transpose{Int64, Array{Int64, 2}},
                Array{Int64, 2},
            },
        )
        _record_sequence(Tuple{typeof(Base.:(==)), Array{Int64, 3}, Array{Int64, 3}})
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
                typeof(HDF5.API.h5d_read),
                HDF5.Dataset,
                HDF5.Datatype,
                HDF5.Dataspace,
                HDF5.Dataspace,
                HDF5.DatasetTransferProperties,
                Array{Base.Complex{Float64}, 3},
            },
        )
        _record_sequence(Tuple{typeof(Base.maximum), Function, Array{Base.Complex{Float64}, 3}})
        _record_sequence(
            Tuple{
                typeof(Base._mapreduce_dim),
                Function,
                Function,
                Base._InitialValue,
                Array{Base.Complex{Float64}, 3},
                Base.Colon,
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{23, 0}},
            },
        )
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{4, String}})
        _record_sequence(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{17, 0}},
            },
        )
        _record_sequence(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64})
        _record_sequence(Tuple{typeof(Base.Broadcast.broadcasted), Type{Bool}, Array{UInt8, 2}})
        _record_sequence(Tuple{typeof(Base.:(&)), Int64, Int64})
        _record_sequence(
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
        _record_sequence(Tuple{typeof(Base.size), Base.BitArray{2}})
        _record_sequence(
            Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.:(!)), Base.BitArray{2}},
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(|)),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(!)),
                    Tuple{Base.BitArray{2}},
                },
                Base.BitArray{2},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(|)),
                    Tuple{
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{2},
                            Nothing,
                            typeof(Base.:(!)),
                            Tuple{Base.BitArray{2}},
                        },
                        Base.BitArray{2},
                    },
                },
            },
        )
        _record_sequence(Tuple{typeof(Base.all), Base.BitArray{2}})
        _record_sequence(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (:outer_mask_sha256, :frozen_mask_sha256, :diagnostic_status),
                    Tuple{String, String, Symbol},
                },
                Type{WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope},
                Base.BitArray{2},
                Base.BitArray{2},
            },
        )
        _record_sequence(Tuple{typeof(Base.Broadcast.broadcasted), Type{Int64}, Array{Int64, 2}})
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
            Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 2}},
        )
        _record_sequence(
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
        _record_sequence(Tuple{typeof(Base.Broadcast.broadcasted), Type{UInt8}, Array{UInt8, 1}})
        _record_sequence(
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
        _record_sequence(Tuple{typeof(Base.size), Array{Int64, 2}})
        _record_sequence(Tuple{typeof(Base.length), Array{UInt8, 1}})
        _record_sequence(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
        _record_sequence(Tuple{typeof(Base.haskey), Base.Dict{UInt8, Symbol}, UInt8})
        _record_sequence(Tuple{typeof(Base.getindex), Base.Dict{UInt8, Symbol}, UInt8})
        _record_sequence(Tuple{Type{Bool}, Int64})
        _record_sequence(
            Tuple{
                Type{WannierNLQG.Wannierization.BandRepresentationPreparationResult},
                Symbol,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                Nothing,
                Array{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic, 1},
                WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                Symbol,
                Symbol,
                Symbol,
                String,
                String,
                Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
            },
        )
        _record_sequence(
            Tuple{typeof(WannierNLQG.Wannierization.read_wannierization_checkpoint_hdf5), String},
        )
        _record_sequence(
            Tuple{
                Type{Pair{A, B} where {B} where A},
                String,
                WannierNLQG.Wannierization.WannierizationStatus,
            },
        )
        _record_sequence(
            Tuple{
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._wannierization_status),
                String,
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.API.h5d_read),
                HDF5.Dataset,
                HDF5.Datatype,
                HDF5.Dataspace,
                HDF5.Dataspace,
                HDF5.DatasetTransferProperties,
                Array{Float64, 1},
            },
        )
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{21, String}})
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{13, String}})
        _record_sequence(Tuple{typeof(Base.eachindex), Array{Int64, 1}})
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{19, String}})
        _record_sequence(Tuple{typeof(Base.getindex), Array{Float64, 2}, Function, Int64})
        _record_sequence(Tuple{typeof(Base.getindex), Array{UInt8, 2}, Int64, Int64})
        _record_sequence(Tuple{Type{Bool}, UInt8})
        _record_sequence(
            Tuple{
                Type{WannierNLQG.Wannierization.WannierizationIteration},
                Int64,
                Float64,
                Float64,
                Float64,
                WannierNLQG.Wannierization.WannierizationIterationDiagnostics,
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{71, 0}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:context,), Tuple{Base.Dict{String, String}}},
                Type{WannierNLQG.Wannierization.WannierizationDiagnostic},
                Symbol,
                Symbol,
                String,
            },
        )
        _record_sequence(Tuple{typeof(HDF5.generic_read), HDF5.Dataset, HDF5.Datatype, Type{Bool}})
        _record_sequence(
            Tuple{
                typeof(HDF5.API.h5d_read),
                HDF5.Dataset,
                HDF5.Datatype,
                HDF5.Dataspace,
                HDF5.Dataspace,
                HDF5.DatasetTransferProperties,
                Array{Bool, 1},
            },
        )
        _record_sequence(Tuple{typeof(Base.length), Array{Float64, 1}})
        _record_sequence(Tuple{Type{Array{Float64, 1}}, Array{Float64, 1}})
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{18, String}})
        _record_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WannierizationOptimizerState,
                Symbol,
            },
        )
        _record_sequence(Tuple{Type{Array{Bool, 1}}, Array{Bool, 1}})
        _record_sequence(
            Tuple{
                Type{WannierNLQG.Wannierization.WannierizationOptimizerState},
                Symbol,
                Float64,
                Float64,
                Int64,
                Int64,
                NTuple{4, Float64},
                Float64,
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Int64,
                Int64,
                Int64,
                Int64,
                Int64,
                Float64,
                Bool,
                Int64,
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 2},
                Array{Float64, 1},
                Float64,
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Int64, 1},
                Array{Int64, 1},
                Array{Bool, 1},
            },
        )
        _record_sequence(
            Tuple{
                Type{WannierNLQG.Wannierization.WannierizationOptimizerState},
                Symbol,
                Float64,
                Float64,
                Int64,
                Int64,
                NTuple{4, Float64},
                Float64,
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Int64,
                Int64,
                Int64,
                Int64,
                Int64,
                Float64,
                Bool,
                Int64,
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 2},
                Array{Float64, 1},
                Float64,
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Int64, 1},
                Array{Int64, 1},
                Base.BitArray{1},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Int64,
                Int64,
                Float64,
                Symbol,
                Symbol,
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{39, 0}},
            },
        )
        _record_sequence(
            Tuple{
                Type{WannierNLQG.Wannierization.WannierizationOptimizerState},
                Symbol,
                Float64,
                Float64,
                Int64,
                Int64,
                NTuple{4, Float64},
                Float64,
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Int64,
                Int64,
                Int64,
                Int64,
                Int64,
                Float64,
                Bool,
                Int64,
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 2},
                Array{Float64, 1},
                Float64,
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Int64, 1},
                Array{Int64, 1},
                Array{Bool, 1},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Int64,
                Int64,
                Float64,
                Symbol,
                Symbol,
                String,
                String,
                Int64,
                Float64,
                Array{Base.Complex{Float64}, 4},
                Array{Base.Complex{Float64}, 4},
                Array{Float64, 1},
                Int64,
                Symbol,
                Array{Base.Complex{Float64}, 4},
                Array{Base.Complex{Float64}, 3},
                Float64,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base._array_for),
                Type{Symbol},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Symbol, 1},
                Symbol,
                Base.Generator{
                    Base.UnitRange{Int64},
                    Base.var"#252#253"{WannierNLQGWannierizationExt.SolverCheckpoint.var"#456#460"},
                },
                Int64,
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.collect_to!),
                Array{Any, 1},
                Base.Generator{
                    Base.UnitRange{Int64},
                    Base.var"#252#253"{WannierNLQGWannierizationExt.SolverCheckpoint.var"#456#460"},
                },
                Int64,
                Int64,
            },
        )
        _record_sequence(Tuple{Type{Base.BitArray{2}}, Base.BitArray{2}})
        _record_sequence(
            Tuple{
                Type{WannierNLQG.Wannierization.WannierizationRestartState},
                Int64,
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 2},
                Array{Float64, 1},
                Array{Float64, 2},
                Base.BitArray{2},
                Float64,
                String,
                String,
                WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                String,
                String,
                WannierNLQG.Wannierization.WannierizationOptimizerState,
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Nothing,
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{2, 0}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{55, 0}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{27, 0}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{46, 0}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{49, 0}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{67, 0}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{65, 0}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{57, 0}},
            },
        )
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{52, 0}},
            },
        )
        false
        _record_sequence(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{41, 0}},
            },
        )
        _record_sequence(Tuple{typeof(Base.in), String, NTuple{14, String}})
        _record_sequence(
            Tuple{
                Type{WannierNLQG.Wannierization.WannierizationResult},
                WannierNLQG.Wannierization.WannierizationStatus,
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 2},
                Array{Float64, 1},
                Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                Base.Dict{String, String},
                WannierNLQG.IO.WannierCHK,
                String,
                WannierNLQG.Wannierization.WannierizationRestartState,
                WannierNLQG.Wannierization.WannierizationArtifacts,
                Nothing,
                WannierNLQG.Wannierization.TBSymmetryQualification,
            },
        )
    end
end
