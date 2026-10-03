# Generated from exact Type-proved inference within real cold public calls, Julia 1.11.2.
# No target execution, writes, MPI initialization or saved handles. Provenance is external.
import Dates, EzXML, JSON3, LinearAlgebra, Printf
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let WannierNLQGWannierizationExt=@__MODULE__
            precompile(Tuple{typeof(Base.:(>)), Float64})
            precompile(
                Tuple{typeof(_wannierization_entry_compile_call), typeof(Base.:(>)), Float64},
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:artifact_dir, :qualification_mode), Tuple{String, Symbol}},
                    typeof(
                        WannierNLQG.Wannierization.generate_symmetry_completed_qe_paw_matrix_elements,
                    ),
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    String,
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:artifact_dir, :qualification_mode), Tuple{String, Symbol}},
                    typeof(
                        WannierNLQG.Wannierization.generate_symmetry_completed_qe_paw_matrix_elements,
                    ),
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    String,
                    String,
                },
            )
            precompile(
                Tuple{
                    WannierNLQG.Wannierization.var"##QEPAWParityThresholds#88",
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Type{WannierNLQG.Wannierization.QEPAWParityThresholds},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    WannierNLQG.Wannierization.var"##QEPAWParityThresholds#88",
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Type{WannierNLQG.Wannierization.QEPAWParityThresholds},
                },
            )
            precompile(
                Tuple{Type{WannierNLQG.Wannierization.QEPAWParityThresholds}, Vararg{Float64, 9}},
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{WannierNLQG.Wannierization.QEPAWParityThresholds},
                    Vararg{Float64, 9},
                },
            )

            precompile(Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.vect),
                    Array{String, 1},
                    Vararg{Array{String, 1}},
                },
            )
            precompile(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.iterate),
                    Array{Array{String, 1}, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._star_gauge_contract_version,
                    ),
                    String,
                    HDF5.Attributes,
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._star_gauge_contract_version,
                    ),
                    String,
                    HDF5.Attributes,
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.task_local_storage),
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#877#878"{
                        Base.Pairs{
                            Symbol,
                            Any,
                            Tuple{Symbol, Symbol, Symbol},
                            NamedTuple{
                                (:artifact_dir, :thresholds, :qualification_mode),
                                Tuple{
                                    String,
                                    WannierNLQG.Wannierization.QEPAWParityThresholds,
                                    Symbol,
                                },
                            },
                        },
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        String,
                        String,
                    },
                    Symbol,
                    Bool,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.task_local_storage),
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#877#878"{
                        Base.Pairs{
                            Symbol,
                            Any,
                            Tuple{Symbol, Symbol, Symbol},
                            NamedTuple{
                                (:artifact_dir, :thresholds, :qualification_mode),
                                Tuple{
                                    String,
                                    WannierNLQG.Wannierization.QEPAWParityThresholds,
                                    Symbol,
                                },
                            },
                        },
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        String,
                        String,
                    },
                    Symbol,
                    Bool,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.task_local_storage),
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#634#635"{
                        Base.Pairs{
                            Symbol,
                            Any,
                            Tuple{Symbol, Symbol},
                            NamedTuple{
                                (:construction_policy, :source),
                                Tuple{
                                    Symbol,
                                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                },
                            },
                        },
                        String,
                    },
                    Symbol,
                    Bool,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.task_local_storage),
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#634#635"{
                        Base.Pairs{
                            Symbol,
                            Any,
                            Tuple{Symbol, Symbol},
                            NamedTuple{
                                (:construction_policy, :source),
                                Tuple{
                                    Symbol,
                                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                },
                            },
                        },
                        String,
                    },
                    Symbol,
                    Bool,
                },
            )
            precompile(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Bool, N} where N},
                    UndefInitializer,
                    Int64,
                },
            )
            precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Float64, N} where N},
                    UndefInitializer,
                    Int64,
                    Int64,
                },
            )
            precompile(
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
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Broadcast.materialize),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{2},
                        Nothing,
                        Type{Float64},
                        Tuple{Array{Float64, 2}},
                    },
                },
            )
            precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Int64, N} where N},
                    UndefInitializer,
                    Int64,
                },
            )
            precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Int64, N} where N},
                    UndefInitializer,
                    Int64,
                    Int64,
                },
            )
            precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Int64, N} where N},
                    UndefInitializer,
                    Int64,
                    Int64,
                    Int64,
                },
            )
            precompile(
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
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.API.h5d_read),
                    HDF5.Dataset,
                    HDF5.Datatype,
                    HDF5.Dataspace,
                    HDF5.Dataspace,
                    HDF5.DatasetTransferProperties,
                    Array{Int64, 3},
                },
            )
            precompile(Tuple{typeof(Base.Broadcast.broadcasted), Type{Int64}, Array{Int64, 3}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Broadcast.broadcasted),
                    Type{Int64},
                    Array{Int64, 3},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Broadcast.materialize),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{3},
                        Nothing,
                        Type{Int64},
                        Tuple{Array{Int64, 3}},
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Broadcast.materialize),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{3},
                        Nothing,
                        Type{Int64},
                        Tuple{Array{Int64, 3}},
                    },
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
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Base.Complex{Float64}, N} where N},
                    UndefInitializer,
                    Int64,
                    Int64,
                    Int64,
                },
            )
            precompile(Tuple{typeof(Base.in), String, Tuple{String, String}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.in),
                    String,
                    Tuple{String, String},
                },
            )
            precompile(Tuple{typeof(Base.in), String, NTuple{8, String}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.in),
                    String,
                    NTuple{8, String},
                },
            )
            precompile(
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64, Int64},
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Float64, N} where N},
                    UndefInitializer,
                    Int64,
                    Int64,
                    Int64,
                },
            )
            precompile(
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
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.API.h5d_read),
                    HDF5.Dataset,
                    HDF5.Datatype,
                    HDF5.Dataspace,
                    HDF5.Dataspace,
                    HDF5.DatasetTransferProperties,
                    Array{Float64, 3},
                },
            )
            precompile(Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 3}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Broadcast.broadcasted),
                    Type{Float64},
                    Array{Float64, 3},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Broadcast.materialize),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{3},
                        Nothing,
                        Type{Float64},
                        Tuple{Array{Float64, 3}},
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Broadcast.materialize),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{3},
                        Nothing,
                        Type{Float64},
                        Tuple{Array{Float64, 3}},
                    },
                },
            )
            precompile(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{UInt8, N} where N},
                    UndefInitializer,
                    Int64,
                },
            )
            precompile(Tuple{typeof(Base.Broadcast.broadcasted), Type{Bool}, Array{UInt8, 1}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Broadcast.broadcasted),
                    Type{Bool},
                    Array{UInt8, 1},
                },
            )
            precompile(Tuple{typeof(Base.:(&)), Int64, Int64})
            precompile(
                Tuple{typeof(_wannierization_entry_compile_call), typeof(Base.:(&)), Int64, Int64},
            )
            precompile(
                Tuple{
                    typeof(Base.Broadcast.materialize),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Nothing,
                        Type{Bool},
                        Tuple{Array{UInt8, 1}},
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Broadcast.materialize),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Nothing,
                        Type{Bool},
                        Tuple{Array{UInt8, 1}},
                    },
                },
            )
            precompile(Tuple{typeof(Base.eachindex), Base.BitArray{1}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.eachindex),
                    Base.BitArray{1},
                },
            )
            precompile(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#639#648"{
                        Base.BitArray{1},
                        Array{Float64, 2},
                        Array{Float64, 3},
                        Array{Int64, 3},
                    },
                    Base.OneTo{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#639#648"{
                        Base.BitArray{1},
                        Array{Float64, 2},
                        Array{Float64, 3},
                        Array{Int64, 3},
                    },
                    Base.OneTo{Int64},
                },
            )
            precompile(Tuple{Base.var"##s1116#691", Vararg{Any, 5}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Base.var"##s1116#691",
                    Vararg{Any, 5},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.collect),
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#639#648"{
                            Base.BitArray{1},
                            Array{Float64, 2},
                            Array{Float64, 3},
                            Array{Int64, 3},
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.collect),
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#639#648"{
                            Base.BitArray{1},
                            Array{Float64, 2},
                            Array{Float64, 3},
                            Array{Int64, 3},
                        },
                    },
                },
            )
            precompile(Tuple{Type{Pair{A, B} where {B} where A}, Int64, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Pair{A, B} where {B} where A},
                    Int64,
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{Int64, Int64},
                    Base.Generator{
                        Base.Iterators.Enumerate{Array{String, 1}},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#640#649"{HDF5.File},
                    },
                    Tuple{Int64, Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.grow_to!),
                    Base.Dict{Int64, Int64},
                    Base.Generator{
                        Base.Iterators.Enumerate{Array{String, 1}},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#640#649"{HDF5.File},
                    },
                    Tuple{Int64, Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (
                            :band_range,
                            :spin_channel,
                            :representation_cutoff_ev,
                            :include_time_reversal,
                            :magnetic_moments_cartesian,
                        ),
                        Tuple{Base.UnitRange{Int64}, Symbol, Nothing, Bool, Nothing},
                    },
                    Type{WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource},
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (
                            :band_range,
                            :spin_channel,
                            :representation_cutoff_ev,
                            :include_time_reversal,
                            :magnetic_moments_cartesian,
                        ),
                        Tuple{Base.UnitRange{Int64}, Symbol, Nothing, Bool, Nothing},
                    },
                    Type{WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource},
                    String,
                },
            )
            precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Float64, N} where N},
                    UndefInitializer,
                    Int64,
                },
            )
            precompile(
                Tuple{typeof(Base.zeros), Type{Base.Complex{Float64}}, Int64, Int64, Vararg{Int64}},
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.zeros),
                    Type{Base.Complex{Float64}},
                    Int64,
                    Int64,
                    Vararg{Int64},
                },
            )
            precompile(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#373#377"{
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    },
                    Base.OneTo{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#373#377"{
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    },
                    Base.OneTo{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.collect),
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#373#377"{
                            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.collect),
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#373#377"{
                            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#374#378",
                    Tuple{String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#374#378",
                    Tuple{String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.collect),
                    Base.Generator{
                        Tuple{String, String},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#374#378",
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.collect),
                    Base.Generator{
                        Tuple{String, String},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#374#378",
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_guarded),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                            Bool,
                            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                            Int64,
                            Nothing,
                            Base.UnitRange{Int64},
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_guarded),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                            Bool,
                            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                            Int64,
                            Nothing,
                            Base.UnitRange{Int64},
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                    Bool,
                                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                    Int64,
                                    Nothing,
                                    Base.UnitRange{Int64},
                                    NamedTuple{
                                        (
                                            :xml_file,
                                            :structure,
                                            :reciprocal_lattice,
                                            :noncollinear,
                                            :spinorbit,
                                            :collinear,
                                            :num_bands,
                                            :cutoff_ev,
                                            :kpoint_nodes,
                                            :atomic_type_labels,
                                            :type_elements,
                                            :upf_files,
                                            :metric_kinds,
                                        ),
                                        Tuple{
                                            String,
                                            WannierNLQG.SymmetryFoundation.CrystalStructure,
                                            Array{Float64, 2},
                                            Bool,
                                            Bool,
                                            Bool,
                                            Int64,
                                            Float64,
                                            Array{EzXML.Node, 1},
                                            Array{String, 1},
                                            Base.Dict{String, String},
                                            Base.Dict{String, String},
                                            Base.Dict{String, Symbol},
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                    },
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                            Bool,
                            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                            Int64,
                            Nothing,
                            Base.UnitRange{Int64},
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                    Bool,
                                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                    Int64,
                                    Nothing,
                                    Base.UnitRange{Int64},
                                    NamedTuple{
                                        (
                                            :xml_file,
                                            :structure,
                                            :reciprocal_lattice,
                                            :noncollinear,
                                            :spinorbit,
                                            :collinear,
                                            :num_bands,
                                            :cutoff_ev,
                                            :kpoint_nodes,
                                            :atomic_type_labels,
                                            :type_elements,
                                            :upf_files,
                                            :metric_kinds,
                                        ),
                                        Tuple{
                                            String,
                                            WannierNLQG.SymmetryFoundation.CrystalStructure,
                                            Array{Float64, 2},
                                            Bool,
                                            Bool,
                                            Bool,
                                            Int64,
                                            Float64,
                                            Array{EzXML.Node, 1},
                                            Array{String, 1},
                                            Base.Dict{String, String},
                                            Base.Dict{String, String},
                                            Base.Dict{String, Symbol},
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                    },
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                            Bool,
                            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                            Int64,
                            Nothing,
                            Base.UnitRange{Int64},
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    Type{WannierNLQG.SymmetryFoundation.NativeWavefunctionData},
                    Symbol,
                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                    Array{Float64, 2},
                    Tuple{Int64, Int64, Int64},
                    Bool,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                Int64,
                                Nothing,
                                Base.UnitRange{Int64},
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{WannierNLQG.SymmetryFoundation.NativeWavefunctionData},
                    Symbol,
                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                    Array{Float64, 2},
                    Tuple{Int64, Int64, Int64},
                    Bool,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                Int64,
                                Nothing,
                                Base.UnitRange{Int64},
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.length),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                Int64,
                                Nothing,
                                Base.UnitRange{Int64},
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.length),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                Int64,
                                Nothing,
                                Base.UnitRange{Int64},
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(Tuple{typeof(Base.size), Array{Float64, 2}, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.size),
                    Array{Float64, 2},
                    Int64,
                },
            )
            precompile(Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.zeros),
                    Type{Float64},
                    Int64,
                    Int64,
                    Vararg{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_guarded),
                    WannierNLQG.IO.PreparationSourceVector{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                            WannierNLQG.IO.PreparationSourceVector{
                                Tuple{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Base.Dict{
                                        String,
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                    },
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_guarded),
                    WannierNLQG.IO.PreparationSourceVector{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                            WannierNLQG.IO.PreparationSourceVector{
                                Tuple{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Base.Dict{
                                        String,
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                    },
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQG.IO.PreparationSourceVector{
                                Array{Base.Complex{Float64}, 3},
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                    WannierNLQG.IO.PreparationSourceVector{
                                        Tuple{
                                            Array{Base.Complex{Float64}, 3},
                                            Array{Base.Complex{Float64}, 2},
                                        },
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                            Base.Dict{
                                                String,
                                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                            },
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                    },
                    WannierNLQG.IO.PreparationSourceVector{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                            WannierNLQG.IO.PreparationSourceVector{
                                Tuple{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Base.Dict{
                                        String,
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                    },
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQG.IO.PreparationSourceVector{
                                Array{Base.Complex{Float64}, 3},
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                    WannierNLQG.IO.PreparationSourceVector{
                                        Tuple{
                                            Array{Base.Complex{Float64}, 3},
                                            Array{Base.Complex{Float64}, 2},
                                        },
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                            Base.Dict{
                                                String,
                                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                            },
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                    },
                    WannierNLQG.IO.PreparationSourceVector{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                            WannierNLQG.IO.PreparationSourceVector{
                                Tuple{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Base.Dict{
                                        String,
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                    },
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_guarded),
                    WannierNLQG.IO.PreparationSourceVector{
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                            WannierNLQG.IO.PreparationSourceVector{
                                Tuple{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Base.Dict{
                                        String,
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                    },
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_guarded),
                    WannierNLQG.IO.PreparationSourceVector{
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                            WannierNLQG.IO.PreparationSourceVector{
                                Tuple{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Base.Dict{
                                        String,
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                    },
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQG.IO.PreparationSourceVector{
                                Array{Base.Complex{Float64}, 2},
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                                    WannierNLQG.IO.PreparationSourceVector{
                                        Tuple{
                                            Array{Base.Complex{Float64}, 3},
                                            Array{Base.Complex{Float64}, 2},
                                        },
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                            Base.Dict{
                                                String,
                                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                            },
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                    },
                    WannierNLQG.IO.PreparationSourceVector{
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                            WannierNLQG.IO.PreparationSourceVector{
                                Tuple{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Base.Dict{
                                        String,
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                    },
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQG.IO.PreparationSourceVector{
                                Array{Base.Complex{Float64}, 2},
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                                    WannierNLQG.IO.PreparationSourceVector{
                                        Tuple{
                                            Array{Base.Complex{Float64}, 3},
                                            Array{Base.Complex{Float64}, 2},
                                        },
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                            Base.Dict{
                                                String,
                                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                            },
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                    },
                    WannierNLQG.IO.PreparationSourceVector{
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                            WannierNLQG.IO.PreparationSourceVector{
                                Tuple{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Base.Dict{
                                        String,
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                    },
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._qe_generalized_norm_residual,
                    ),
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    Bool,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._qe_generalized_norm_residual,
                    ),
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    Bool,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Iterators.enumerate),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                Int64,
                                Nothing,
                                Base.UnitRange{Int64},
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Iterators.enumerate),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                Int64,
                                Nothing,
                                Base.UnitRange{Int64},
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                    Bool,
                                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                    Int64,
                                    Nothing,
                                    Base.UnitRange{Int64},
                                    NamedTuple{
                                        (
                                            :xml_file,
                                            :structure,
                                            :reciprocal_lattice,
                                            :noncollinear,
                                            :spinorbit,
                                            :collinear,
                                            :num_bands,
                                            :cutoff_ev,
                                            :kpoint_nodes,
                                            :atomic_type_labels,
                                            :type_elements,
                                            :upf_files,
                                            :metric_kinds,
                                        ),
                                        Tuple{
                                            String,
                                            WannierNLQG.SymmetryFoundation.CrystalStructure,
                                            Array{Float64, 2},
                                            Bool,
                                            Bool,
                                            Bool,
                                            Int64,
                                            Float64,
                                            Array{EzXML.Node, 1},
                                            Array{String, 1},
                                            Base.Dict{String, String},
                                            Base.Dict{String, String},
                                            Base.Dict{String, Symbol},
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                    },
                    Tuple{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                    Bool,
                                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                    Int64,
                                    Nothing,
                                    Base.UnitRange{Int64},
                                    NamedTuple{
                                        (
                                            :xml_file,
                                            :structure,
                                            :reciprocal_lattice,
                                            :noncollinear,
                                            :spinorbit,
                                            :collinear,
                                            :num_bands,
                                            :cutoff_ev,
                                            :kpoint_nodes,
                                            :atomic_type_labels,
                                            :type_elements,
                                            :upf_files,
                                            :metric_kinds,
                                        ),
                                        Tuple{
                                            String,
                                            WannierNLQG.SymmetryFoundation.CrystalStructure,
                                            Array{Float64, 2},
                                            Bool,
                                            Bool,
                                            Bool,
                                            Int64,
                                            Float64,
                                            Array{EzXML.Node, 1},
                                            Array{String, 1},
                                            Base.Dict{String, String},
                                            Base.Dict{String, String},
                                            Base.Dict{String, Symbol},
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                    },
                    Tuple{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                    Bool,
                                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                    Int64,
                                    Nothing,
                                    Base.UnitRange{Int64},
                                    NamedTuple{
                                        (
                                            :xml_file,
                                            :structure,
                                            :reciprocal_lattice,
                                            :noncollinear,
                                            :spinorbit,
                                            :collinear,
                                            :num_bands,
                                            :cutoff_ev,
                                            :kpoint_nodes,
                                            :atomic_type_labels,
                                            :type_elements,
                                            :upf_files,
                                            :metric_kinds,
                                        ),
                                        Tuple{
                                            String,
                                            WannierNLQG.SymmetryFoundation.CrystalStructure,
                                            Array{Float64, 2},
                                            Bool,
                                            Bool,
                                            Bool,
                                            Int64,
                                            Float64,
                                            Array{EzXML.Node, 1},
                                            Array{String, 1},
                                            Base.Dict{String, String},
                                            Base.Dict{String, String},
                                            Base.Dict{String, Symbol},
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                    },
                    Tuple{Int64, Tuple{Base.OneTo{Int64}, Int64}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                    Bool,
                                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                    Int64,
                                    Nothing,
                                    Base.UnitRange{Int64},
                                    NamedTuple{
                                        (
                                            :xml_file,
                                            :structure,
                                            :reciprocal_lattice,
                                            :noncollinear,
                                            :spinorbit,
                                            :collinear,
                                            :num_bands,
                                            :cutoff_ev,
                                            :kpoint_nodes,
                                            :atomic_type_labels,
                                            :type_elements,
                                            :upf_files,
                                            :metric_kinds,
                                        ),
                                        Tuple{
                                            String,
                                            WannierNLQG.SymmetryFoundation.CrystalStructure,
                                            Array{Float64, 2},
                                            Bool,
                                            Bool,
                                            Bool,
                                            Int64,
                                            Float64,
                                            Array{EzXML.Node, 1},
                                            Array{String, 1},
                                            Base.Dict{String, String},
                                            Base.Dict{String, String},
                                            Base.Dict{String, Symbol},
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                    },
                    Tuple{Int64, Tuple{Base.OneTo{Int64}, Int64}},
                },
            )
            precompile(
                Tuple{
                    Type{NamedTuple{(:normalize_coefficients,), T} where T <: Tuple},
                    Tuple{Bool},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{NamedTuple{(:normalize_coefficients,), T} where T <: Tuple},
                    Tuple{Bool},
                },
            )
            precompile(
                Tuple{
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._star_replay_local_completed_frame,
                    ),
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Array{Base.Complex{Float64}, 3},
                    Array{Float64, 2},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._star_replay_local_completed_frame,
                    ),
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Array{Base.Complex{Float64}, 3},
                    Array{Float64, 2},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.first),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                Int64,
                                Nothing,
                                Base.UnitRange{Int64},
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.first),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                Int64,
                                Nothing,
                                Base.UnitRange{Int64},
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_guarded),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                            Array{Base.Complex{Float64}, 3},
                            Array{Float64, 2},
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_guarded),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                            Array{Base.Complex{Float64}, 3},
                            Array{Float64, 2},
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                    },
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                            Array{Base.Complex{Float64}, 3},
                            Array{Float64, 2},
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                    },
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                            Array{Base.Complex{Float64}, 3},
                            Array{Float64, 2},
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.axes),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                Int64,
                                Nothing,
                                Base.UnitRange{Int64},
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.axes),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                Int64,
                                Nothing,
                                Base.UnitRange{Int64},
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    Type{Array{Float64, 1}},
                    Base.SubArray{
                        Float64,
                        1,
                        Array{Float64, 2},
                        Tuple{Base.Slice{Base.OneTo{Int64}}, Int64},
                        true,
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Float64, 1}},
                    Base.SubArray{
                        Float64,
                        1,
                        Array{Float64, 2},
                        Tuple{Base.Slice{Base.OneTo{Int64}}, Int64},
                        true,
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.axes1),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                Array{Base.Complex{Float64}, 3},
                                Array{Float64, 2},
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.axes1),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                Array{Base.Complex{Float64}, 3},
                                Array{Float64, 2},
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.getindex),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                Array{Base.Complex{Float64}, 3},
                                Array{Float64, 2},
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.getindex),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                Array{Base.Complex{Float64}, 3},
                                Array{Float64, 2},
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Int64,
                },
            )
            precompile(Tuple{typeof(Base.view), Array{Float64, 2}, Int64, Function})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.view),
                    Array{Float64, 2},
                    Int64,
                    Function,
                },
            )
            precompile(
                Tuple{
                    WannierNLQG.IO.var"#1#2"{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                String,
                                Array{String, 1},
                            },
                        },
                        Int64,
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    WannierNLQG.IO.var"#1#2"{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                String,
                                Array{String, 1},
                            },
                        },
                        Int64,
                    },
                },
            )
            precompile(Tuple{typeof(Base.maximum), Function, Array{Base.Complex{Float64}, 3}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.maximum),
                    Function,
                    Array{Base.Complex{Float64}, 3},
                },
            )
            precompile(
                Tuple{
                    typeof(Base._mapreduce_dim),
                    Function,
                    Function,
                    Base._InitialValue,
                    Array{Base.Complex{Float64}, 3},
                    Base.Colon,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base._mapreduce_dim),
                    Function,
                    Function,
                    Base._InitialValue,
                    Array{Base.Complex{Float64}, 3},
                    Base.Colon,
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_guarded),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                Array{Base.Complex{Float64}, 3},
                                Array{Float64, 2},
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_guarded),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                Array{Base.Complex{Float64}, 3},
                                Array{Float64, 2},
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQG.IO.PreparationSourceVector{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Float64, 2},
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                            },
                        },
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                Array{Base.Complex{Float64}, 3},
                                Array{Float64, 2},
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQG.IO.PreparationSourceVector{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Float64, 2},
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                            },
                        },
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                Array{Base.Complex{Float64}, 3},
                                Array{Float64, 2},
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    Type{WannierNLQG.SymmetryFoundation.NativeWavefunctionData},
                    Symbol,
                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                    Array{Float64, 2},
                    Tuple{Int64, Int64, Int64},
                    Bool,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{WannierNLQG.SymmetryFoundation.NativeWavefunctionData},
                    Symbol,
                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                    Array{Float64, 2},
                    Tuple{Int64, Int64, Int64},
                    Bool,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                },
            )
            precompile(
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Vararg{Int64}},
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Float64, N} where N},
                    UndefInitializer,
                    Int64,
                    Vararg{Int64},
                },
            )
            precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, NTuple{4, Int64}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Float64, N} where N},
                    UndefInitializer,
                    NTuple{4, Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.API.h5d_read),
                    HDF5.Dataset,
                    HDF5.Datatype,
                    HDF5.Dataspace,
                    HDF5.Dataspace,
                    HDF5.DatasetTransferProperties,
                    Array{Float64, 4},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.API.h5d_read),
                    HDF5.Dataset,
                    HDF5.Datatype,
                    HDF5.Dataspace,
                    HDF5.Dataspace,
                    HDF5.DatasetTransferProperties,
                    Array{Float64, 4},
                },
            )
            precompile(Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 4}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Broadcast.broadcasted),
                    Type{Float64},
                    Array{Float64, 4},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Broadcast.materialize),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{4},
                        Nothing,
                        Type{Float64},
                        Tuple{Array{Float64, 4}},
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Broadcast.materialize),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{4},
                        Nothing,
                        Type{Float64},
                        Tuple{Array{Float64, 4}},
                    },
                },
            )
            precompile(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#619#621"{Array{Int64, 2}},
                    Base.OneTo{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#619#621"{Array{Int64, 2}},
                    Base.OneTo{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.collect),
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#619#621"{
                            Array{Int64, 2},
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.collect),
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#619#621"{
                            Array{Int64, 2},
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.length),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.length),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQG.IO.PreparationSourceVector{
                                Array{Base.Complex{Float64}, 3},
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                    WannierNLQG.IO.PreparationSourceVector{
                                        Tuple{
                                            Array{Base.Complex{Float64}, 3},
                                            Array{Base.Complex{Float64}, 2},
                                        },
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                            Base.Dict{
                                                String,
                                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                            },
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                            },
                        },
                    },
                    WannierNLQG.IO.PreparationSourceVector{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                            WannierNLQG.IO.PreparationSourceVector{
                                Tuple{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Base.Dict{
                                        String,
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                    },
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQG.IO.PreparationSourceVector{
                                Array{Base.Complex{Float64}, 3},
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                    WannierNLQG.IO.PreparationSourceVector{
                                        Tuple{
                                            Array{Base.Complex{Float64}, 3},
                                            Array{Base.Complex{Float64}, 2},
                                        },
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                            Base.Dict{
                                                String,
                                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                            },
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                            },
                        },
                    },
                    WannierNLQG.IO.PreparationSourceVector{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                            WannierNLQG.IO.PreparationSourceVector{
                                Tuple{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Base.Dict{
                                        String,
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                    },
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQG.IO.PreparationSourceVector{
                                Array{Base.Complex{Float64}, 2},
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                                    WannierNLQG.IO.PreparationSourceVector{
                                        Tuple{
                                            Array{Base.Complex{Float64}, 3},
                                            Array{Base.Complex{Float64}, 2},
                                        },
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                            Base.Dict{
                                                String,
                                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                            },
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                            },
                        },
                    },
                    WannierNLQG.IO.PreparationSourceVector{
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                            WannierNLQG.IO.PreparationSourceVector{
                                Tuple{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Base.Dict{
                                        String,
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                    },
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQG.IO.PreparationSourceVector{
                                Array{Base.Complex{Float64}, 2},
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                                    WannierNLQG.IO.PreparationSourceVector{
                                        Tuple{
                                            Array{Base.Complex{Float64}, 3},
                                            Array{Base.Complex{Float64}, 2},
                                        },
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                            Base.Dict{
                                                String,
                                                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                            },
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                        },
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                            },
                        },
                    },
                    WannierNLQG.IO.PreparationSourceVector{
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                            WannierNLQG.IO.PreparationSourceVector{
                                Tuple{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 2},
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Base.Dict{
                                        String,
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                    },
                                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                },
                            },
                        },
                    },
                    Function,
                },
            )
            precompile(
                Tuple{
                    Type{WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric},
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    Bool,
                    Base.Dict{
                        Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                        Array{Base.Complex{Float64}, 4},
                    },
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric},
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    Bool,
                    Base.Dict{
                        Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                        Array{Base.Complex{Float64}, 4},
                    },
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._star_array_sha256),
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._star_array_sha256),
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._star_array_sha256),
                    Array{Float64, 4},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._star_array_sha256),
                    Array{Float64, 4},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.axes),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.axes),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#644#653"{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    },
                    Base.OneTo{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#644#653"{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    },
                    Base.OneTo{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.maximum),
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#644#653"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.maximum),
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#644#653"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.getindex),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.getindex),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.getindex),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.getindex),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Iterators.enumerate),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Iterators.enumerate),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQG.IO.PreparationSourceVector{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Float64, 2},
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                            },
                        },
                    },
                    Tuple{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQG.IO.PreparationSourceVector{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Float64, 2},
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                            },
                        },
                    },
                    Tuple{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQG.IO.PreparationSourceVector{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Float64, 2},
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                            },
                        },
                    },
                    Tuple{Int64, Tuple{Base.OneTo{Int64}, Int64}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.iterate),
                    Base.Iterators.Enumerate{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQG.IO.PreparationSourceVector{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Float64, 2},
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                        1,
                                    },
                                },
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                            },
                        },
                    },
                    Tuple{Int64, Tuple{Base.OneTo{Int64}, Int64}},
                },
            )
            precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Float64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Pair{A, B} where {B} where A},
                    String,
                    Float64,
                },
            )
            precompile(
                Tuple{
                    Type{WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload},
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                    Array{Int64, 2},
                    Array{Int64, 3},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Base.Complex{Float64}, 3},
                    Base.UnitRange{Int64},
                    Base.UnitRange{Int64},
                    Base.Dict{String, Float64},
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                    Nothing,
                    Nothing,
                    Nothing,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload},
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                    Array{Int64, 2},
                    Array{Int64, 3},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Base.Complex{Float64}, 3},
                    Base.UnitRange{Int64},
                    Base.UnitRange{Int64},
                    Base.Dict{String, Float64},
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                    Nothing,
                    Nothing,
                    Nothing,
                },
            )
            precompile(
                Tuple{
                    Type{WannierNLQG.SymmetryFoundation.NativeWavefunctionData},
                    Symbol,
                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                    Array{Float64, 2},
                    Tuple{Int64, Int64, Int64},
                    Bool,
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{WannierNLQG.SymmetryFoundation.NativeWavefunctionData},
                    Symbol,
                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                    Array{Float64, 2},
                    Tuple{Int64, Int64, Int64},
                    Bool,
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:schema_version, :contract_version), Tuple{String, String}},
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._star_payload_sha256),
                    WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:schema_version, :contract_version), Tuple{String, String}},
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._star_payload_sha256),
                    WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.axes),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.axes),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#614#615"{
                        WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                    },
                    Base.OneTo{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#614#615"{
                        WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                    },
                    Base.OneTo{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.reduce),
                    Function,
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#614#615"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.reduce),
                    Function,
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#614#615"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    Base.var"##mapfoldl#335",
                    Base._InitialValue,
                    typeof(Base.mapfoldl),
                    Function,
                    Function,
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#614#615"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Base.var"##mapfoldl#335",
                    Base._InitialValue,
                    typeof(Base.mapfoldl),
                    Function,
                    Function,
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#614#615"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.mapfoldl_impl),
                    typeof(Base.identity),
                    typeof(Base.hcat),
                    Base._InitialValue,
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#614#615"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.mapfoldl_impl),
                    typeof(Base.identity),
                    typeof(Base.hcat),
                    Base._InitialValue,
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#614#615"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.checkbounds),
                    Type{Bool},
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.checkbounds),
                    Type{Bool},
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.getindex),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.getindex),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.iterate),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.iterate),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.iterate),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                    Tuple{Base.OneTo{Int64}, Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.iterate),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                    Tuple{Base.OneTo{Int64}, Int64},
                },
            )
            precompile(Tuple{typeof(Base.isempty), Base.UnitRange{Int64}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.isempty),
                    Base.UnitRange{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._restore_band_frame_transform_contract,
                    ),
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Array{Base.Complex{Float64}, 3},
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._restore_band_frame_transform_contract,
                    ),
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Array{Base.Complex{Float64}, 3},
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.first),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.first),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        Array{Base.Complex{Float64}, 2},
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        Array{Base.Complex{Float64}, 2},
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
            )
            precompile(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#453#454"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
                    Base.OneTo{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#453#454"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
                    Base.OneTo{Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.iterate),
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#453#454"{
                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.iterate),
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#453#454"{
                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.checkbounds),
                    Type{Bool},
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.checkbounds),
                    Type{Bool},
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.iterate),
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#453#454"{
                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.iterate),
                    Base.Generator{
                        Base.OneTo{Int64},
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#453#454"{
                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (:reference_native, :reference_metric),
                        Tuple{
                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        },
                    },
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._star_replay_local_completed_frame,
                    ),
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Array{Base.Complex{Float64}, 3},
                    Array{Float64, 2},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (:reference_native, :reference_metric),
                        Tuple{
                            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        },
                    },
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._star_replay_local_completed_frame,
                    ),
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Array{Base.Complex{Float64}, 3},
                    Array{Float64, 2},
                },
            )
            precompile(
                Tuple{
                    Type{NamedTuple{(:atol, :rtol), T} where T <: Tuple},
                    Tuple{Float64, Float64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{NamedTuple{(:atol, :rtol), T} where T <: Tuple},
                    Tuple{Float64, Float64},
                },
            )
            precompile(
                Tuple{
                    Type{WannierNLQG.IO.WannierNNKP},
                    Array{Float64, 2},
                    Array{Float64, 2},
                    LinearAlgebra.Transpose{Float64, Array{Float64, 1}},
                    Array{Int64, 2},
                    Array{Int64, 3},
                    Array{Int64, 1},
                    Array{WannierNLQG.IO.WannierNNKPProjection, 1},
                    Bool,
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{WannierNLQG.IO.WannierNNKP},
                    Array{Float64, 2},
                    Array{Float64, 2},
                    LinearAlgebra.Transpose{Float64, Array{Float64, 1}},
                    Array{Int64, 2},
                    Array{Int64, 3},
                    Array{Int64, 1},
                    Array{WannierNLQG.IO.WannierNNKPProjection, 1},
                    Bool,
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_generate_amn),
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQG.IO.WannierNNKP,
                    Array{Array{Base.Complex{Float64}, 3}, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    Bool,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_generate_amn),
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQG.IO.WannierNNKP,
                    Array{Array{Base.Complex{Float64}, 3}, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    Bool,
                },
            )
            precompile(Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Pair{A, B} where {B} where A},
                    Tuple{Int64, Int64, Int64},
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_generate_amn),
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQG.IO.WannierNNKP,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    Bool,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_generate_amn),
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQG.IO.WannierNNKP,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 2},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    Bool,
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_generate_mmn),
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQG.IO.WannierNNKP,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    Bool,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_generate_mmn),
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQG.IO.WannierNNKP,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                    Base.Dict{
                        String,
                        WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                    },
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                    Bool,
                },
            )
            precompile(
                Tuple{
                    Type{WannierNLQG.Wannierization.QEPAWMatrixElementResult},
                    WannierNLQG.IO.WannierMMN,
                    WannierNLQG.IO.WannierAMN,
                    WannierNLQG.Wannierization.QEPAWArrayParityMetrics,
                    WannierNLQG.Wannierization.QEPAWArrayParityMetrics,
                    Float64,
                    Float64,
                    Float64,
                    Bool,
                    Bool,
                    Array{String, 1},
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{WannierNLQG.Wannierization.QEPAWMatrixElementResult},
                    WannierNLQG.IO.WannierMMN,
                    WannierNLQG.IO.WannierAMN,
                    WannierNLQG.Wannierization.QEPAWArrayParityMetrics,
                    WannierNLQG.Wannierization.QEPAWArrayParityMetrics,
                    Float64,
                    Float64,
                    Float64,
                    Bool,
                    Bool,
                    Array{String, 1},
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                },
            )
            precompile(Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{NamedTuple{(:cleanup,), T} where T <: Tuple},
                    Tuple{Bool},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (
                            :target_scope_active,
                            :parent_mmn_parity,
                            :parent_amn_parity,
                            :parent_generalized_norm_max_absolute,
                            :completed_parent_generalized_norm_max_absolute,
                        ),
                        Tuple{Bool, Vararg{Nothing, 4}},
                    },
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._write_symmetry_completed_qe_paw_provenance,
                    ),
                    String,
                    WannierNLQG.Wannierization.QEPAWMatrixElementResult,
                    WannierNLQG.Wannierization.QEPAWParityThresholds,
                    String,
                    WannierNLQG.IO.WannierNNKP,
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (
                            :target_scope_active,
                            :parent_mmn_parity,
                            :parent_amn_parity,
                            :parent_generalized_norm_max_absolute,
                            :completed_parent_generalized_norm_max_absolute,
                        ),
                        Tuple{Bool, Vararg{Nothing, 4}},
                    },
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements._write_symmetry_completed_qe_paw_provenance,
                    ),
                    String,
                    WannierNLQG.Wannierization.QEPAWMatrixElementResult,
                    WannierNLQG.Wannierization.QEPAWParityThresholds,
                    String,
                    WannierNLQG.IO.WannierNNKP,
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQG.Wannierization.prepare_exact_wannier_operator_bundle),
                    WannierNLQG.Wannierization.ExactWannierOperatorBundleConfig,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(WannierNLQG.Wannierization.prepare_exact_wannier_operator_bundle),
                    WannierNLQG.Wannierization.ExactWannierOperatorBundleConfig,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.task_local_storage),
                    WannierNLQGWannierizationExt.OperatorExport.var"#17#20"{
                        WannierNLQG.Wannierization.ExactWannierOperatorBundleConfig,
                        Base.Dict{String, String},
                    },
                    Symbol,
                    Base.Dict{String, Tuple{Tuple, String}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.task_local_storage),
                    WannierNLQGWannierizationExt.OperatorExport.var"#17#20"{
                        WannierNLQG.Wannierization.ExactWannierOperatorBundleConfig,
                        Base.Dict{String, String},
                    },
                    Symbol,
                    Base.Dict{String, Tuple{Tuple, String}},
                },
            )
            precompile(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.OperatorExport.var"#10#12",
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
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.OperatorExport.var"#10#12",
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
            precompile(
                Tuple{
                    Type{Base.Dict{String, String}},
                    Base.Generator{
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
                        WannierNLQGWannierizationExt.OperatorExport.var"#10#12",
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Base.Dict{String, String}},
                    Base.Generator{
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
                        WannierNLQGWannierizationExt.OperatorExport.var"#10#12",
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        Tuple{Int64, Int64, Float64},
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        Tuple{Int64, Int64, Float64},
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
            )
            precompile(Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.falses),
                    Int64,
                    Int64,
                    Vararg{Int64},
                },
            )
            precompile(
                Tuple{
                    Type{Array{Base.Complex{Float64}, N} where N},
                    Array{Base.Complex{Float64}, 4},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Base.Complex{Float64}, N} where N},
                    Array{Base.Complex{Float64}, 4},
                },
            )
            precompile(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 4}, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.size),
                    Array{Base.Complex{Float64}, 4},
                    Int64,
                },
            )
            precompile(
                Tuple{
                    Type{Array{Base.Complex{Float64}, N} where N},
                    Array{Base.Complex{Float64}, 5},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Base.Complex{Float64}, N} where N},
                    Array{Base.Complex{Float64}, 5},
                },
            )
            precompile(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 5}, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.size),
                    Array{Base.Complex{Float64}, 5},
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(
                        WannierNLQGWannierizationExt.OperatorExport._exact_bundle_serialized_derivative,
                    ),
                    Array{Base.Complex{Float64}, 4},
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(
                        WannierNLQGWannierizationExt.OperatorExport._exact_bundle_serialized_derivative,
                    ),
                    Array{Base.Complex{Float64}, 4},
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(
                        WannierNLQGWannierizationExt.OperatorExport._exact_bundle_serialized_derivative,
                    ),
                    Array{Base.Complex{Float64}, 5},
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(
                        WannierNLQGWannierizationExt.OperatorExport._exact_bundle_serialized_derivative,
                    ),
                    Array{Base.Complex{Float64}, 5},
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, String},
                    Base.Generator{
                        NTuple{6, String},
                        WannierNLQGWannierizationExt.OperatorExport.var"#21#23"{
                            Base.Dict{String, String},
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.grow_to!),
                    Base.Dict{String, String},
                    Base.Generator{
                        NTuple{6, String},
                        WannierNLQGWannierizationExt.OperatorExport.var"#21#23"{
                            Base.Dict{String, String},
                        },
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.OperatorExport.var"#22#24"{
                        Base.Dict{String, String},
                        Base.Dict{String, String},
                    },
                    Base.KeySet{String, Base.Dict{String, String}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Base.Generator{I, F} where {F} where I},
                    WannierNLQGWannierizationExt.OperatorExport.var"#22#24"{
                        Base.Dict{String, String},
                        Base.Dict{String, String},
                    },
                    Base.KeySet{String, Base.Dict{String, String}},
                },
            )
            precompile(
                Tuple{typeof(Base.indexed_iterate), Tuple{Pair{String, String}, Int64}, Int64},
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.indexed_iterate),
                    Tuple{Pair{String, String}, Int64},
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.indexed_iterate),
                    Tuple{Pair{String, String}, Int64},
                    Int64,
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.indexed_iterate),
                    Tuple{Pair{String, String}, Int64},
                    Int64,
                    Int64,
                },
            )
            precompile(Tuple{typeof(Base.iterate), Pair{String, String}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.iterate),
                    Pair{String, String},
                },
            )
            precompile(Tuple{typeof(Base.iterate), Pair{String, String}, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.iterate),
                    Pair{String, String},
                    Int64,
                },
            )
            precompile(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.indexed_iterate),
                    Tuple{String, Int64},
                    Int64,
                },
            )
            precompile(Tuple{typeof(Base.indexed_iterate), Tuple{String, Int64}, Int64, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.indexed_iterate),
                    Tuple{String, Int64},
                    Int64,
                    Int64,
                },
            )
            precompile(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Base.Generator{
                        Base.KeySet{String, Base.Dict{String, String}},
                        WannierNLQGWannierizationExt.OperatorExport.var"#22#24"{
                            Base.Dict{String, String},
                            Base.Dict{String, String},
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Base.Dict{K, V} where {V} where K},
                    Base.Generator{
                        Base.KeySet{String, Base.Dict{String, String}},
                        WannierNLQGWannierizationExt.OperatorExport.var"#22#24"{
                            Base.Dict{String, String},
                            Base.Dict{String, String},
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, Array{Int64, 1}},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Int64},
                        Pair{String, Array{Float64, 2}},
                        Pair{String, Array{Float64, 2}},
                        Pair{String, Array{Float64, 2}},
                        Pair{String, Array{Float64, 2}},
                        Pair{String, Array{Int64, 2}},
                        Pair{String, String},
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.grow_to!),
                    Base.Dict{String, Any},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Bool},
                        Pair{String, Bool},
                        Pair{String, Array{Int64, 1}},
                        Pair{String, Float64},
                        Pair{String, Float64},
                        Pair{String, Int64},
                        Pair{String, Array{Float64, 2}},
                        Pair{String, Array{Float64, 2}},
                        Pair{String, Array{Float64, 2}},
                        Pair{String, Array{Float64, 2}},
                        Pair{String, Array{Int64, 2}},
                        Pair{String, String},
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    Type{Pair{A, B} where {B} where A},
                    String,
                    Base.Dict{String, Base.Dict{String, Any}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Pair{A, B} where {B} where A},
                    String,
                    Base.Dict{String, Base.Dict{String, Any}},
                },
            )
            precompile(
                Tuple{
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Base.Dict{String, Base.Dict{String, Any}}},
                        Pair{String, String},
                        Pair{String, Base.Dict{String, Any}},
                        Vararg{Pair{String, String}, 9},
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Base.Dict{K, V} where {V} where K},
                    Tuple{
                        Pair{String, String},
                        Pair{String, String},
                        Pair{String, Base.Dict{String, Base.Dict{String, Any}}},
                        Pair{String, String},
                        Pair{String, Base.Dict{String, Any}},
                        Vararg{Pair{String, String}, 9},
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (
                            :profile,
                            :overwrite,
                            :paired_tb_sha256,
                            :provenance,
                            :symmetry,
                            :geometry,
                            :diagnostics,
                        ),
                        Tuple{Symbol, Bool, String, Vararg{Base.Dict{String, Any}, 4}},
                    },
                    typeof(WannierNLQG.IO.write_real_space_operator_bundle),
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
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (
                            :profile,
                            :overwrite,
                            :paired_tb_sha256,
                            :provenance,
                            :symmetry,
                            :geometry,
                            :diagnostics,
                        ),
                        Tuple{Symbol, Bool, String, Vararg{Base.Dict{String, Any}, 4}},
                    },
                    typeof(WannierNLQG.IO.write_real_space_operator_bundle),
                    String,
                    Array{Float64, 2},
                    Array{Int64, 1},
                    Base.Dict{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperator{N} where N,
                    },
                },
            )
            precompile(Tuple{typeof(Base.isequal), Symbol, Symbol})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.isequal),
                    Symbol,
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
            )
            precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Bool})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Pair{A, B} where {B} where A},
                    String,
                    Bool,
                },
            )
            precompile(Tuple{typeof(Base.indexed_iterate), Pair{String, Bool}, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.indexed_iterate),
                    Pair{String, Bool},
                    Int64,
                },
            )
            precompile(Tuple{typeof(Base.indexed_iterate), Pair{String, Bool}, Int64, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.indexed_iterate),
                    Pair{String, Bool},
                    Int64,
                    Int64,
                },
            )
            precompile(
                Tuple{
                    Type{NamedTuple{(:read, :write, :append, :truncate), T} where T <: Tuple},
                    Tuple{Bool, Bool, Nothing, Nothing},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{NamedTuple{(:read, :write, :append, :truncate), T} where T <: Tuple},
                    Tuple{Bool, Bool, Nothing, Nothing},
                },
            )
            precompile(Tuple{Dates.var"##s53#31", Vararg{Any, 5}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Dates.var"##s53#31",
                    Vararg{Any, 5},
                },
            )
            precompile(Tuple{typeof(Base.indexed_iterate), Tuple{String, String}, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.indexed_iterate),
                    Tuple{String, String},
                    Int64,
                },
            )
            precompile(Tuple{typeof(Base.indexed_iterate), Tuple{String, String}, Int64, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.indexed_iterate),
                    Tuple{String, String},
                    Int64,
                    Int64,
                },
            )
            precompile(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.in),
                    String,
                    Tuple{String, String, String},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.in),
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.in),
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                },
            )
            precompile(Tuple{typeof(Base.setindex!), Base.RefValue{Float64}, Float64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.setindex!),
                    Base.RefValue{Float64},
                    Float64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base._all),
                    Base.Fix2{typeof(Base.:(>)), Int64},
                    Array{Int64, 1},
                    Base.Colon,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base._all),
                    Base.Fix2{typeof(Base.:(>)), Int64},
                    Array{Int64, 1},
                    Base.Colon,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        WannierNLQG.IO.OperatorBundleIndexEntry,
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        WannierNLQG.IO.OperatorBundleIndexEntry,
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.append!),
                    Array{Base.Complex{Float64}, 1},
                    Array{Base.Complex{Float64}, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.append!),
                    Array{Base.Complex{Float64}, 1},
                    Array{Base.Complex{Float64}, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Broadcast.copyto_nonleaf!),
                    Array{String, 1},
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        typeof(getfield),
                        Tuple{
                            Base.Broadcast.Extruded{
                                Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
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
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Broadcast.copyto_nonleaf!),
                    Array{String, 1},
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        typeof(getfield),
                        Tuple{
                            Base.Broadcast.Extruded{
                                Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
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
            precompile(Tuple{typeof(Base.haskey), Base.Dict{String, Any}, Symbol})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.haskey),
                    Base.Dict{String, Any},
                    Symbol,
                },
            )
            precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Any}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Pair{A, B} where {B} where A},
                    String,
                    Base.Dict{String, Any},
                },
            )
            precompile(Tuple{typeof(Base.in), String, NTuple{5, String}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.in),
                    String,
                    NTuple{5, String},
                },
            )
            precompile(Tuple{Type{Base.Set{T} where T}, Array{String, 1}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Base.Set{T} where T},
                    Array{String, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.getproperty),
                    NamedTuple{
                        (
                            :wannier_center_policy,
                            :real_space_replica_policy,
                            :production_eligible,
                            :minimum_distance_materialized,
                            :mp_grid,
                            :raw_centers_cartesian,
                            :raw_centers_fractional,
                            :final_centers_cartesian,
                            :final_centers_fractional,
                            :geometry_content_sha256,
                        ),
                        Tuple{
                            Symbol,
                            Symbol,
                            Bool,
                            Bool,
                            Tuple{Int64, Int64, Int64},
                            Array{Float64, 2},
                            Array{Float64, 2},
                            Array{Float64, 2},
                            Array{Float64, 2},
                            String,
                        },
                    },
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.getproperty),
                    NamedTuple{
                        (
                            :wannier_center_policy,
                            :real_space_replica_policy,
                            :production_eligible,
                            :minimum_distance_materialized,
                            :mp_grid,
                            :raw_centers_cartesian,
                            :raw_centers_fractional,
                            :final_centers_cartesian,
                            :final_centers_fractional,
                            :geometry_content_sha256,
                        ),
                        Tuple{
                            Symbol,
                            Symbol,
                            Bool,
                            Bool,
                            Tuple{Int64, Int64, Int64},
                            Array{Float64, 2},
                            Array{Float64, 2},
                            Array{Float64, 2},
                            Array{Float64, 2},
                            String,
                        },
                    },
                    Symbol,
                },
            )
            precompile(Tuple{typeof(Base.setindex!), HDF5.Attributes, UInt8, String})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.setindex!),
                    HDF5.Attributes,
                    UInt8,
                    String,
                },
            )
            precompile(Tuple{typeof(Base.size), Array{Int64, 2}, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.size),
                    Array{Int64, 2},
                    Int64,
                },
            )
            precompile(Tuple{Type{Array{Int8, N} where N}, UndefInitializer, Int64, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Int8, N} where N},
                    UndefInitializer,
                    Int64,
                    Int64,
                },
            )
            precompile(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{UInt64, N} where N},
                    UndefInitializer,
                    Int64,
                },
            )
            precompile(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{UInt64, N} where N},
                    UndefInitializer,
                    Int64,
                    Int64,
                },
            )
            precompile(
                Tuple{
                    Type{WannierNLQG.IO.OperatorBundleManifest},
                    String,
                    Symbol,
                    Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                    Int64,
                    Array{Float64, 2},
                    Array{Int64, 2},
                    Array{Int64, 1},
                    Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                    Int64,
                    String,
                    String,
                    String,
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Symbol,
                    Symbol,
                    Bool,
                    Bool,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    String,
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Bool,
                    Bool,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Bool,
                    Nothing,
                    Nothing,
                    Bool,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Bool,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Bool,
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
                    Bool,
                    Bool,
                    Bool,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Nothing,
                    String,
                    String,
                    String,
                    String,
                    Base.Dict{String, Any},
                    String,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    String,
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    Array{String, 1},
                    String,
                    String,
                    String,
                    String,
                    String,
                    Nothing,
                    Nothing,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{WannierNLQG.IO.OperatorBundleManifest},
                    String,
                    Symbol,
                    Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                    Int64,
                    Array{Float64, 2},
                    Array{Int64, 2},
                    Array{Int64, 1},
                    Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                    Int64,
                    String,
                    String,
                    String,
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Symbol,
                    Symbol,
                    Bool,
                    Bool,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    String,
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Bool,
                    Bool,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Bool,
                    Nothing,
                    Nothing,
                    Bool,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Bool,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Bool,
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
                    Bool,
                    Bool,
                    Bool,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Nothing,
                    String,
                    String,
                    String,
                    String,
                    Base.Dict{String, Any},
                    String,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    Bool,
                    String,
                    String,
                    String,
                    String,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    String,
                    Array{String, 1},
                    String,
                    String,
                    String,
                    String,
                    String,
                    Nothing,
                    Nothing,
                },
            )
            precompile(
                Tuple{typeof(Base.getproperty), WannierNLQG.Core.RealSpaceOperator{4}, Symbol},
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.getproperty),
                    WannierNLQG.Core.RealSpaceOperator{4},
                    Symbol,
                },
            )
            precompile(
                Tuple{typeof(Base.getproperty), WannierNLQG.Core.RealSpaceOperator{5}, Symbol},
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.getproperty),
                    WannierNLQG.Core.RealSpaceOperator{5},
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.:(==)),
                    Array{Base.Complex{Float64}, 5},
                    Array{Base.Complex{Float64}, 5},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.:(==)),
                    Array{Base.Complex{Float64}, 5},
                    Array{Base.Complex{Float64}, 5},
                },
            )
            precompile(
                Tuple{typeof(Base.getproperty), WannierNLQG.Core.RealSpaceOperator{3}, Symbol},
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.getproperty),
                    WannierNLQG.Core.RealSpaceOperator{3},
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    WannierNLQG.Wannierization.var"##WavefunctionPreparationExecutionConfig#45",
                    Symbol,
                    Int64,
                    Int64,
                    Nothing,
                    Bool,
                    Type{WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    WannierNLQG.Wannierization.var"##WavefunctionPreparationExecutionConfig#45",
                    Symbol,
                    Int64,
                    Int64,
                    Nothing,
                    Bool,
                    Type{WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:num_wannier,), Tuple{Int64}},
                    typeof(WannierNLQG.Wannierization.prepare_paw_scdm_input_artifact),
                    String,
                    String,
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:num_wannier,), Tuple{Int64}},
                    typeof(WannierNLQG.Wannierization.prepare_paw_scdm_input_artifact),
                    String,
                    String,
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.getproperty),
                    NamedTuple{(:directory, :vectors), Tuple{String, Array{Any, 1}}},
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.getproperty),
                    NamedTuple{(:directory, :vectors), Tuple{String, Array{Any, 1}}},
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:prefix, :cleanup), Tuple{String, Bool}},
                    typeof(Base.Filesystem.mktempdir),
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:prefix, :cleanup), Tuple{String, Bool}},
                    typeof(Base.Filesystem.mktempdir),
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.eachindex),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                Array{Base.Complex{Float64}, 3},
                                Array{Float64, 2},
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.eachindex),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                Array{Base.Complex{Float64}, 3},
                                Array{Float64, 2},
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                            Array{
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                    Base.Filesystem.StatStruct,
                                    String,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(Tuple{typeof(Base.axes), Array{Int64, 2}, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.axes),
                    Array{Int64, 2},
                    Int64,
                },
            )
            precompile(
                Tuple{
                    Type{Array{Base.Complex{Float64}, N} where N},
                    UndefInitializer,
                    Tuple{Int64, Int64, Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Base.Complex{Float64}, N} where N},
                    UndefInitializer,
                    Tuple{Int64, Int64, Int64},
                },
            )
            precompile(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{UInt8, N} where N},
                    UndefInitializer,
                    Int64,
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.getindex),
                    Array{Base.Complex{Float64}, 3},
                    Array{Int64, 1},
                    Function,
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.getindex),
                    Array{Base.Complex{Float64}, 3},
                    Array{Int64, 1},
                    Function,
                    Function,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:outer_mask_sha256, :frozen_mask_sha256), Tuple{String, String}},
                    Type{WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope},
                    Base.BitArray{2},
                    Base.BitArray{2},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:outer_mask_sha256, :frozen_mask_sha256), Tuple{String, String}},
                    Type{WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope},
                    Base.BitArray{2},
                    Base.BitArray{2},
                },
            )
            precompile(
                Tuple{
                    Type{WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload},
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                    Array{Int64, 2},
                    Array{Int64, 3},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Base.Complex{Float64}, 3},
                    Base.UnitRange{Int64},
                    Base.UnitRange{Int64},
                    Base.Dict{String, Float64},
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                    WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                    Nothing,
                    Nothing,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload},
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                    Array{Int64, 2},
                    Array{Int64, 3},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{Base.Complex{Float64}, 3},
                    Base.UnitRange{Int64},
                    Base.UnitRange{Int64},
                    Base.Dict{String, Float64},
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                    Base.Dict{String, String},
                    WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                    Nothing,
                    Nothing,
                },
            )
            precompile(
                Tuple{
                    Type{Array{T, 2} where T},
                    LinearAlgebra.Transpose{Float64, Array{Float64, 2}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{T, 2} where T},
                    LinearAlgebra.Transpose{Float64, Array{Float64, 2}},
                },
            )
            precompile(
                Tuple{
                    Type{Array{Base.Complex{Float64}, N} where N},
                    UndefInitializer,
                    NTuple{4, Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{Array{Base.Complex{Float64}, N} where N},
                    UndefInitializer,
                    NTuple{4, Int64},
                },
            )
            precompile(Tuple{typeof(Base.in), String, NTuple{4, String}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.in),
                    String,
                    NTuple{4, String},
                },
            )
            precompile(
                Tuple{
                    Type{WannierNLQG.SymmetryFoundation.MagneticSymmetryInventory},
                    Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                    Bool,
                    Int64,
                    Nothing,
                    Int64,
                    Float64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    Type{WannierNLQG.SymmetryFoundation.MagneticSymmetryInventory},
                    Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                    Bool,
                    Int64,
                    Nothing,
                    Int64,
                    Float64,
                },
            )
            precompile(
                Tuple{typeof(Base.repr), Tuple{Bool, Int64, Nothing, Int64, Int64, Int64, Float64}},
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.repr),
                    Tuple{Bool, Int64, Nothing, Int64, Int64, Int64, Float64},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.show),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                    Tuple{Bool, Int64, Nothing, Int64, Int64, Int64, Float64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.show),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                    Tuple{Bool, Int64, Nothing, Int64, Int64, Int64, Float64},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.intersect),
                    Base.KeySet{String, Base.Dict{String, String}},
                    Base.KeySet{String, Base.Dict{String, String}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.intersect),
                    Base.KeySet{String, Base.Dict{String, String}},
                    Base.KeySet{String, Base.Dict{String, String}},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.iterate),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.iterate),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                },
            )
            precompile(Tuple{typeof(Base.eachrow), Array{Int64, 2}})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.eachrow),
                    Array{Int64, 2},
                },
            )
            precompile(
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
                    Type{Tuple},
                    Tuple{
                        Base.Slices{
                            Array{Int64, 2},
                            Tuple{Int64, Base.Colon},
                            Tuple{Base.OneTo{Int64}},
                            Base.SubArray{
                                Int64,
                                1,
                                Array{Int64, 2},
                                Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                                true,
                            },
                            1,
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
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
                    Type{Tuple},
                    Tuple{
                        Base.Slices{
                            Array{Int64, 2},
                            Tuple{Int64, Base.Colon},
                            Tuple{Base.OneTo{Int64}},
                            Base.SubArray{
                                Int64,
                                1,
                                Array{Int64, 2},
                                Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                                true,
                            },
                            1,
                        },
                    },
                },
            )
            precompile(
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
                    Type{Tuple},
                    Tuple{
                        Base.Slices{
                            Array{Int64, 2},
                            Tuple{Int64, Base.Colon},
                            Tuple{Base.OneTo{Int64}},
                            Base.SubArray{
                                Int64,
                                1,
                                Array{Int64, 2},
                                Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                                true,
                            },
                            1,
                        },
                    },
                    Tuple{Base.OneTo{Int64}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
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
                    Type{Tuple},
                    Tuple{
                        Base.Slices{
                            Array{Int64, 2},
                            Tuple{Int64, Base.Colon},
                            Tuple{Base.OneTo{Int64}},
                            Base.SubArray{
                                Int64,
                                1,
                                Array{Int64, 2},
                                Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                                true,
                            },
                            1,
                        },
                    },
                    Tuple{Base.OneTo{Int64}},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.copy),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        Type{Tuple},
                        Tuple{
                            Base.Slices{
                                Array{Int64, 2},
                                Tuple{Int64, Base.Colon},
                                Tuple{Base.OneTo{Int64}},
                                Base.SubArray{
                                    Int64,
                                    1,
                                    Array{Int64, 2},
                                    Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                                    true,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.copy),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        Type{Tuple},
                        Tuple{
                            Base.Slices{
                                Array{Int64, 2},
                                Tuple{Int64, Base.Colon},
                                Tuple{Base.OneTo{Int64}},
                                Base.SubArray{
                                    Int64,
                                    1,
                                    Array{Int64, 2},
                                    Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                                    true,
                                },
                                1,
                            },
                        },
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.similar),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        Type{Tuple},
                        Tuple{
                            Base.Broadcast.Extruded{
                                Base.Slices{
                                    Array{Int64, 2},
                                    Tuple{Int64, Base.Colon},
                                    Tuple{Base.OneTo{Int64}},
                                    Base.SubArray{
                                        Int64,
                                        1,
                                        Array{Int64, 2},
                                        Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                                        true,
                                    },
                                    1,
                                },
                                Tuple{Bool},
                                Tuple{Int64},
                            },
                        },
                    },
                    Type{Tuple{Int64, Int64, Int64}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.similar),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        Type{Tuple},
                        Tuple{
                            Base.Broadcast.Extruded{
                                Base.Slices{
                                    Array{Int64, 2},
                                    Tuple{Int64, Base.Colon},
                                    Tuple{Base.OneTo{Int64}},
                                    Base.SubArray{
                                        Int64,
                                        1,
                                        Array{Int64, 2},
                                        Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                                        true,
                                    },
                                    1,
                                },
                                Tuple{Bool},
                                Tuple{Int64},
                            },
                        },
                    },
                    Type{Tuple{Int64, Int64, Int64}},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Broadcast.copyto_nonleaf!),
                    Array{Tuple{Int64, Int64, Int64}, 1},
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        Type{Tuple},
                        Tuple{
                            Base.Broadcast.Extruded{
                                Base.Slices{
                                    Array{Int64, 2},
                                    Tuple{Int64, Base.Colon},
                                    Tuple{Base.OneTo{Int64}},
                                    Base.SubArray{
                                        Int64,
                                        1,
                                        Array{Int64, 2},
                                        Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                                        true,
                                    },
                                    1,
                                },
                                Tuple{Bool},
                                Tuple{Int64},
                            },
                        },
                    },
                    Base.OneTo{Int64},
                    Int64,
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Broadcast.copyto_nonleaf!),
                    Array{Tuple{Int64, Int64, Int64}, 1},
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        Type{Tuple},
                        Tuple{
                            Base.Broadcast.Extruded{
                                Base.Slices{
                                    Array{Int64, 2},
                                    Tuple{Int64, Base.Colon},
                                    Tuple{Base.OneTo{Int64}},
                                    Base.SubArray{
                                        Int64,
                                        1,
                                        Array{Int64, 2},
                                        Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                                        true,
                                    },
                                    1,
                                },
                                Tuple{Bool},
                                Tuple{Int64},
                            },
                        },
                    },
                    Base.OneTo{Int64},
                    Int64,
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:dims,), Tuple{Int64}},
                    typeof(Base.maximum),
                    Function,
                    Array{Int64, 2},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:dims,), Tuple{Int64}},
                    typeof(Base.maximum),
                    Function,
                    Array{Int64, 2},
                },
            )
            precompile(Tuple{typeof(Base.abs), Int64})
            precompile(Tuple{typeof(_wannierization_entry_compile_call), typeof(Base.abs), Int64})
            precompile(
                Tuple{
                    typeof(Base.reducedim_init),
                    typeof(Base.abs),
                    typeof(Base.max),
                    Array{Int64, 2},
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.reducedim_init),
                    typeof(Base.abs),
                    typeof(Base.max),
                    Array{Int64, 2},
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.mapreducedim!),
                    Function,
                    Function,
                    Array{Int64, 2},
                    Array{Int64, 2},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.mapreducedim!),
                    Function,
                    Function,
                    Array{Int64, 2},
                    Array{Int64, 2},
                },
            )
            precompile(
                Tuple{
                    typeof(Base._mapreducedim!),
                    typeof(Base.abs),
                    typeof(Base.max),
                    Array{Int64, 2},
                    Array{Int64, 2},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base._mapreducedim!),
                    typeof(Base.abs),
                    typeof(Base.max),
                    Array{Int64, 2},
                    Array{Int64, 2},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Broadcast.broadcasted),
                    typeof(Base.max),
                    Array{Int64, 1},
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Broadcast.broadcasted),
                    typeof(Base.max),
                    Array{Int64, 1},
                    Array{Int64, 1},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Broadcast.materialize!),
                    Array{Int64, 1},
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Nothing,
                        typeof(Base.max),
                        Tuple{Array{Int64, 1}, Array{Int64, 1}},
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Broadcast.materialize!),
                    Array{Int64, 1},
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Nothing,
                        typeof(Base.max),
                        Tuple{Array{Int64, 1}, Array{Int64, 1}},
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.iterate),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    Tuple{Base.OneTo{Int64}, Int64},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.iterate),
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQG.IO.PreparationSourceVector{
                                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                WannierNLQGWannierizationExt.PAWMatrixElements.var"#450#451"{
                                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Float64, 2},
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                        },
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#643#652"{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#375#379"{
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                                Array{
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                    1,
                                },
                            },
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                Base.Filesystem.StatStruct,
                                String,
                            },
                        },
                    },
                    Tuple{Base.OneTo{Int64}, Int64},
                },
            )
            precompile(
                Tuple{
                    WannierNLQG.IO.var"##foreach_preparation_block#21",
                    String,
                    String,
                    WannierNLQG.IO.var"#27#33",
                    Nothing,
                    typeof(WannierNLQG.IO.foreach_preparation_block),
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#765#768"{
                        Array{Int64, 1},
                        Array{Float64, 2},
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#load_metric#767"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#consume_frame#766"{
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 2},
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 3},
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    WannierNLQG.IO.var"##foreach_preparation_block#21",
                    String,
                    String,
                    WannierNLQG.IO.var"#27#33",
                    Nothing,
                    typeof(WannierNLQG.IO.foreach_preparation_block),
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#765#768"{
                        Array{Int64, 1},
                        Array{Float64, 2},
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#load_metric#767"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#consume_frame#766"{
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 2},
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 3},
                    },
                    Int64,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        Tuple{Int64, String, Bool, Task},
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.memoryref),
                    GenericMemory{
                        :not_atomic,
                        Tuple{Int64, String, Bool, Task},
                        Base.Core.AddrSpace{Base.Core}(0x00),
                    },
                },
            )
            precompile(
                Tuple{
                    typeof(Base.lock),
                    WannierNLQG.IO.var"#9#10"{
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                Int64,
                                Nothing,
                                Base.UnitRange{Int64},
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                        },
                    },
                    Base.ReentrantLock,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.lock),
                    WannierNLQG.IO.var"#9#10"{
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                                Bool,
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                Int64,
                                Nothing,
                                Base.UnitRange{Int64},
                                NamedTuple{
                                    (
                                        :xml_file,
                                        :structure,
                                        :reciprocal_lattice,
                                        :noncollinear,
                                        :spinorbit,
                                        :collinear,
                                        :num_bands,
                                        :cutoff_ev,
                                        :kpoint_nodes,
                                        :atomic_type_labels,
                                        :type_elements,
                                        :upf_files,
                                        :metric_kinds,
                                    ),
                                    Tuple{
                                        String,
                                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                                        Array{Float64, 2},
                                        Bool,
                                        Bool,
                                        Bool,
                                        Int64,
                                        Float64,
                                        Array{EzXML.Node, 1},
                                        Array{String, 1},
                                        Base.Dict{String, String},
                                        Base.Dict{String, String},
                                        Base.Dict{String, Symbol},
                                    },
                                },
                            },
                        },
                    },
                    Base.ReentrantLock,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.lock),
                    WannierNLQG.IO.var"#9#10"{
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                    },
                    Base.ReentrantLock,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.lock),
                    WannierNLQG.IO.var"#9#10"{
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 3},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#158#161"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                    },
                    Base.ReentrantLock,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.lock),
                    WannierNLQG.IO.var"#9#10"{
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                    },
                    Base.ReentrantLock,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.lock),
                    WannierNLQG.IO.var"#9#10"{
                        WannierNLQG.IO.PreparationSourceVector{
                            Array{Base.Complex{Float64}, 2},
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#159#162"{
                                WannierNLQG.IO.PreparationSourceVector{
                                    Tuple{
                                        Array{Base.Complex{Float64}, 3},
                                        Array{Base.Complex{Float64}, 2},
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#157#160"{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        Base.Dict{
                                            String,
                                            WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
                                        },
                                        WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                                    },
                                },
                            },
                        },
                    },
                    Base.ReentrantLock,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.lock),
                    WannierNLQG.IO.var"#9#10"{
                        WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 3}},
                    },
                    Base.ReentrantLock,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.lock),
                    WannierNLQG.IO.var"#9#10"{
                        WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 3}},
                    },
                    Base.ReentrantLock,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.getproperty),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.getproperty),
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                            WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                            WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                    WannierNLQG.IO.PreparationSourceVector{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                            String,
                                            Array{String, 1},
                                        },
                                    },
                                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                        Base.Filesystem.StatStruct,
                                        String,
                                    },
                                },
                            },
                        },
                    },
                    Symbol,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.lock),
                    WannierNLQG.IO.var"#9#10"{
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                                WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                                WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQG.IO.PreparationSourceVector{
                                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                                String,
                                                Array{String, 1},
                                            },
                                        },
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                    },
                                },
                            },
                        },
                    },
                    Base.ReentrantLock,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.lock),
                    WannierNLQG.IO.var"#9#10"{
                        WannierNLQG.IO.PreparationSourceVector{
                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#436#437"{
                                WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                                WannierNLQGWannierizationExt.PAWMatrixElements._QERepresentativeMap{
                                    WannierNLQGWannierizationExt.PAWMatrixElements._QEGuardedProvider{
                                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        WannierNLQG.IO.PreparationSourceVector{
                                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#641#650"{
                                                String,
                                                Array{String, 1},
                                            },
                                        },
                                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#627#628"{
                                            Base.Filesystem.StatStruct,
                                            String,
                                        },
                                    },
                                },
                            },
                        },
                    },
                    Base.ReentrantLock,
                },
            )
            precompile(Tuple{typeof(Base.join), Tuple{Int64, Int64}, Char})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.join),
                    Tuple{Int64, Int64},
                    Char,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                    Tuple{Int64, Int64},
                    Char,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                    Tuple{Int64, Int64},
                    Char,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.write),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                    Base.ReinterpretArray{UInt8, 1, Int64, Array{Int64, 1}, false},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.write),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                    Base.ReinterpretArray{UInt8, 1, Int64, Array{Int64, 1}, false},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.write),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                    Base.ReinterpretArray{UInt8, 1, Float64, Array{Float64, 1}, false},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.write),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                    Base.ReinterpretArray{UInt8, 1, Float64, Array{Float64, 1}, false},
                },
            )
            precompile(Tuple{typeof(Base.join), Tuple{Int64}, Char})
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.join),
                    Tuple{Int64},
                    Char,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                    Tuple{Int64},
                    Char,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.join),
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                    Tuple{Int64},
                    Char,
                },
            )
        end
        @assert !WannierNLQG.MPI.Initialized()
    end
end
