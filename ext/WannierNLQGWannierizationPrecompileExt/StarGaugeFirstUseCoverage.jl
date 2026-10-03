# Actual scientific signatures only; @timed result construction is excluded.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_precompile(
            Tuple{
                Base.Iterators.var"#5#6"{
                    Tuple{
                        Array{Int64, 1},
                        Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                    },
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                Base.var"##mapfoldl#335",
                Base._InitialValue,
                typeof(Base.mapfoldl),
                Function,
                Function,
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#404#408"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
                },
            },
        )
        _record_precompile(
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
        _record_precompile(
            Tuple{
                Base.var"##mapfoldl#335",
                Base._InitialValue,
                typeof(Base.mapfoldl),
                Function,
                Function,
                Base.Generator{
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
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#679#690",
                },
            },
        )
        _record_precompile(
            Tuple{
                Base.var"##open#463",
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(Base.open),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#422#425"{
                    WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                    Int64,
                    UInt64,
                    Int64,
                },
                String,
                Vararg{String},
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Dict{K, V} where {V} where K},
                Base.Generator{
                    Base.Iterators.Filter{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#706#714",
                        Base.Dict{String, Float64},
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#705#713",
                },
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Dict{K, V} where {V} where K},
                Base.Generator{
                    Base.Iterators.Filter{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#708#716",
                        Base.Dict{String, Float64},
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#707#715",
                },
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#404#408"{
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                },
                Base.OneTo{Int64},
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#406#411"{Int64},
                Base.UnitRange{Int64},
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#420#423",
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#453#454"{
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                },
                Base.OneTo{Int64},
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#614#615"{
                    WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                },
                Base.OneTo{Int64},
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#679#690",
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
        )
        _record_precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#703#711"{
                    WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                },
                Base.OneTo{Int64},
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#705#713",
                Base.Iterators.Filter{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#706#714",
                    Base.Dict{String, Float64},
                },
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#707#715",
                Base.Iterators.Filter{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#708#716",
                    Base.Dict{String, Float64},
                },
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#706#714",
                Base.Dict{String, Float64},
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#708#716",
                Base.Dict{String, Float64},
            },
        )
        _record_precompile(
            Tuple{
                Type{Base.Pairs{Symbol, V, I, A} where {A} where {I} where V},
                NamedTuple{
                    (:by,),
                    Tuple{WannierNLQGWannierizationExt.PAWMatrixElements.var"#472#479"},
                },
                Tuple{Symbol},
            },
        )
        _record_precompile(
            Tuple{
                Type{WannierNLQG.SymmetryFoundation.NativeWavefunctionData},
                Symbol,
                WannierNLQG.SymmetryFoundation.CrystalStructure,
                Array{Float64, 2},
                Tuple{Int64, Int64, Int64},
                Bool,
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
                Base.Dict{String, String},
                Base.Dict{String, String},
            },
        )
        _record_precompile(
            Tuple{
                Type{WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationResult},
                Symbol,
                Symbol,
                String,
                String,
                Base.UnitRange{Int64},
                Base.UnitRange{Int64},
                Array{Int64, 1},
                Array{Int64, 1},
                Base.Dict{String, Float64},
                Base.Dict{String, String},
                Base.Dict{String, String},
                Array{String, 1},
                Symbol,
                Symbol,
                Symbol,
                Symbol,
                String,
                Bool,
                Bool,
                Bool,
                Base.Dict{String, Float64},
                Base.Dict{String, Float64},
            },
        )
        _record_precompile(
            Tuple{
                Type{WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric},
                Base.Dict{String, WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData},
                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                Array{Array{Base.Complex{Float64}, 3}, 1},
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Bool,
                Base.Dict{
                    Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                    Array{Base.Complex{Float64}, 4},
                },
                String,
            },
        )
        _record_precompile(
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
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{Base.Complex{Float64}, 3},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{Float64, 1},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{Float64, 2},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{Float64, 4},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{Int64, 2},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{Int64, 3},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{String, 1},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                    1,
                },
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorChannel, 1},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Base.Dict{String, Float64},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Base.Dict{String, String},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Base.Dict{String, WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Base.Dict{Tuple{Int64, Int64, Int64}, Array{Float64, 1}},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Base.Dict{
                    Tuple{String, Tuple{Float64, Float64, Float64}, Int64, Bool},
                    Array{Base.Complex{Float64}, 4},
                },
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 2}},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 3}},
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                WannierNLQG.SymmetryFoundation.CrystalStructure,
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData,
            },
        )
        _record_precompile(
            Tuple{
                WannierNLQG.Wannierization.var"#_#9#10",
                Float64,
                Type{WannierNLQG.Wannierization.FixedGapPAWBlockPartition},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.Iterators.enumerate),
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.Iterators.enumerate),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base._all),
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{String, 1},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base._all),
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base._all),
                WannierNLQG.IO.var"#visit#14"{
                    Bool,
                    Base.Set{String},
                    Array{Any, 1},
                    Base.IdDict{Any, Bool},
                },
                Array{
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                    1,
                },
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.all),
                Function,
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.all),
                Function,
                Array{
                    WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorAtomPlan,
                    1,
                },
            },
        )
        _record_precompile(
            Tuple{typeof(Base.axes), Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
        )
        _record_precompile(
            Tuple{
                typeof(Base.axes),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.axes),
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
        )
        _record_precompile(
            Tuple{
                typeof(Base.checkbounds),
                Type{Bool},
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.checkbounds),
                Type{Bool},
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.UnitRange{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#406#411"{Int64},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Array{Float64, 1}, 1},
                Array{Float64, 1},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#719#733"{
                        Base.UnitRange{Int64},
                        Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.eachindex),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.filter!),
                WannierNLQG.IO.var"#19#20"{Base.Set{String}},
                Array{Any, 1},
            },
        )
        _record_precompile(
            Tuple{typeof(Base.first), Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
        )
        _record_precompile(
            Tuple{
                typeof(Base.first),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.first),
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
        )
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                Type{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                Type{WannierNLQG.SymmetryFoundation.SymmetryOperation},
                WannierNLQG.SymmetryFoundation.SymmetryOperation,
                WannierNLQG.SymmetryFoundation.SymmetryOperation,
                WannierNLQG.SymmetryFoundation.SymmetryOperation,
                WannierNLQG.SymmetryFoundation.SymmetryOperation,
                WannierNLQG.SymmetryFoundation.SymmetryOperation,
                WannierNLQG.SymmetryFoundation.SymmetryOperation,
                Vararg{WannierNLQG.SymmetryFoundation.SymmetryOperation},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 2}},
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 2}},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 3}},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getindex),
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
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#420#423",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#493#498",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#494#499",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#507#521",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#510#524",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#511#525",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#528#532",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#529#533",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#679#690",
                    Base.BottomRF{typeof(Base.vcat)},
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.By{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#471#478",
                    Base.Order.ForwardOrdering,
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.By{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#472#479",
                    Base.Order.ForwardOrdering,
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.By{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#473#480",
                    Base.Order.ForwardOrdering,
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.By{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#474#481",
                    Base.Order.ForwardOrdering,
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.By{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#483#485",
                    Base.Order.ForwardOrdering,
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.By{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#509#523",
                    Base.Order.ForwardOrdering,
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.By{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#675#676",
                    Base.Order.ForwardOrdering,
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.By{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#677#678",
                    Base.Order.ForwardOrdering,
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.Lt{
                    Base.Sort.var"#30#31"{
                        Base.Order.By{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#471#478",
                            Base.Order.ForwardOrdering,
                        },
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.Lt{
                    Base.Sort.var"#30#31"{
                        Base.Order.By{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#472#479",
                            Base.Order.ForwardOrdering,
                        },
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.Lt{
                    Base.Sort.var"#30#31"{
                        Base.Order.By{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#473#480",
                            Base.Order.ForwardOrdering,
                        },
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.Lt{
                    Base.Sort.var"#30#31"{
                        Base.Order.By{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#474#481",
                            Base.Order.ForwardOrdering,
                        },
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.Lt{
                    Base.Sort.var"#30#31"{
                        Base.Order.By{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#483#485",
                            Base.Order.ForwardOrdering,
                        },
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.Lt{
                    Base.Sort.var"#30#31"{
                        Base.Order.By{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#509#523",
                            Base.Order.ForwardOrdering,
                        },
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.Lt{
                    Base.Sort.var"#30#31"{
                        Base.Order.By{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#675#676",
                            Base.Order.ForwardOrdering,
                        },
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                Base.Order.Lt{
                    Base.Sort.var"#30#31"{
                        Base.Order.By{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#677#678",
                            Base.Order.ForwardOrdering,
                        },
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :completed_energies,
                        :shifts,
                        :points,
                        :parent_points,
                        :rotations,
                        :canonical_operations,
                        :parent_rotations,
                        :parent_rotations_lowdin,
                        :parent_assignments,
                        :target_principal_angles,
                        :target_projector_operator,
                        :target_projector_frobenius,
                        :parent_energy_shifts,
                        :parent_eigenvalues,
                        :selected_indices,
                        :maxima,
                        :maximum_contexts,
                        :workspace_eigenvectors,
                        :selected_vectors,
                        :target_anchor_sha256,
                        :complement_basis,
                        :complement_rotation,
                        :target_complement_hamiltonian,
                        :complement_hamiltonian,
                    ),
                    Tuple{
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Base.Dict{Int64, WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                        Base.Dict{Int64, WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                        Base.Dict{Int64, Int64},
                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                        Base.Dict{Int64, Array{Int64, 1}},
                        Base.Dict{Int64, Array{Float64, 1}},
                        Base.Dict{Int64, Float64},
                        Base.Dict{Int64, Float64},
                        Base.Dict{Int64, Array{Float64, 1}},
                        Base.Dict{Int64, Array{Float64, 1}},
                        Array{Int64, 1},
                        Base.Dict{String, Float64},
                        Base.Dict{String, String},
                        Array{Base.Complex{Float64}, 2},
                        Array{Base.Complex{Float64}, 2},
                        Vararg{Nothing, 5},
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :native,
                        :metric,
                        :rotations,
                        :hamiltonians,
                        :maximum_before,
                        :maximum_after,
                        :worst_context,
                    ),
                    Tuple{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Float64,
                        String,
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (:payload, :records, :reused),
                    Tuple{
                        NamedTuple{
                            (
                                :solution,
                                :maxima,
                                :contexts,
                                :representative,
                                :authority_indices,
                                :authority_indices_by_kpoint,
                                :symmetrized_hamiltonians,
                                :selected_raw,
                                :extra_bands,
                            ),
                            Tuple{
                                NamedTuple{
                                    (
                                        :completed_energies,
                                        :shifts,
                                        :points,
                                        :parent_points,
                                        :rotations,
                                        :canonical_operations,
                                        :parent_rotations,
                                        :parent_rotations_lowdin,
                                        :parent_assignments,
                                        :target_principal_angles,
                                        :target_projector_operator,
                                        :target_projector_frobenius,
                                        :parent_energy_shifts,
                                        :parent_eigenvalues,
                                        :selected_indices,
                                        :maxima,
                                        :maximum_contexts,
                                        :workspace_eigenvectors,
                                        :selected_vectors,
                                        :target_anchor_sha256,
                                        :complement_basis,
                                        :complement_rotation,
                                        :target_complement_hamiltonian,
                                        :complement_hamiltonian,
                                    ),
                                    Tuple{
                                        Array{Float64, 1},
                                        Array{Float64, 1},
                                        Base.Dict{
                                            Int64,
                                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        },
                                        Base.Dict{
                                            Int64,
                                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        },
                                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                                        Base.Dict{Int64, Int64},
                                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                                        Base.Dict{Int64, Array{Int64, 1}},
                                        Base.Dict{Int64, Array{Float64, 1}},
                                        Base.Dict{Int64, Float64},
                                        Base.Dict{Int64, Float64},
                                        Base.Dict{Int64, Array{Float64, 1}},
                                        Base.Dict{Int64, Array{Float64, 1}},
                                        Array{Int64, 1},
                                        Base.Dict{String, Float64},
                                        Base.Dict{String, String},
                                        Array{Base.Complex{Float64}, 2},
                                        Array{Base.Complex{Float64}, 2},
                                        Vararg{Nothing, 5},
                                    },
                                },
                                Base.Dict{String, Float64},
                                Base.Dict{String, String},
                                Int64,
                                Array{Int64, 1},
                                Base.Dict{Int64, Array{Int64, 1}},
                                Nothing,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Int64,
                            },
                        },
                        Array{Any, 1},
                        Bool,
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (:representation, :construction_diagnostics),
                    Tuple{WannierNLQG.SymmetryFoundation.BandRepresentation, Array{Any, 1}},
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :solution,
                        :maxima,
                        :contexts,
                        :representative,
                        :authority_indices,
                        :authority_indices_by_kpoint,
                        :symmetrized_hamiltonians,
                        :selected_raw,
                        :extra_bands,
                    ),
                    Tuple{
                        NamedTuple{
                            (
                                :completed_energies,
                                :shifts,
                                :points,
                                :parent_points,
                                :rotations,
                                :canonical_operations,
                                :parent_rotations,
                                :parent_rotations_lowdin,
                                :parent_assignments,
                                :target_principal_angles,
                                :target_projector_operator,
                                :target_projector_frobenius,
                                :parent_energy_shifts,
                                :parent_eigenvalues,
                                :selected_indices,
                                :maxima,
                                :maximum_contexts,
                                :workspace_eigenvectors,
                                :selected_vectors,
                                :target_anchor_sha256,
                                :complement_basis,
                                :complement_rotation,
                                :target_complement_hamiltonian,
                                :complement_hamiltonian,
                            ),
                            Tuple{
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Base.Dict{Int64, WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                                Base.Dict{Int64, WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                                Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                                Base.Dict{Int64, Int64},
                                Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                                Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                                Base.Dict{Int64, Array{Int64, 1}},
                                Base.Dict{Int64, Array{Float64, 1}},
                                Base.Dict{Int64, Float64},
                                Base.Dict{Int64, Float64},
                                Base.Dict{Int64, Array{Float64, 1}},
                                Base.Dict{Int64, Array{Float64, 1}},
                                Array{Int64, 1},
                                Base.Dict{String, Float64},
                                Base.Dict{String, String},
                                Array{Base.Complex{Float64}, 2},
                                Array{Base.Complex{Float64}, 2},
                                Vararg{Nothing, 5},
                            },
                        },
                        Base.Dict{String, Float64},
                        Base.Dict{String, String},
                        Int64,
                        Array{Int64, 1},
                        Base.Dict{Int64, Array{Int64, 1}},
                        Nothing,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Int64,
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 2}},
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 3}},
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
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
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.MagneticSymmetryInventory,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{typeof(Base.getproperty), WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, Symbol},
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.FixedGapPAWBlockPartition,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{String, String},
                Base.Generator{
                    Base.Dict{String, String},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#701#709",
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#385#386"{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    },
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Float64,
                    Tuple{Int64, Int64, Int64},
                },
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.indexed_iterate),
                Tuple{
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Float64,
                    Tuple{Int64, Int64, Int64},
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.iterate),
                Base.Generator{
                    Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#604#607",
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.iterate),
                Base.Generator{
                    Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#604#607",
                },
            },
        )
        _record_precompile(
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
        _record_precompile(
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
        _record_precompile(
            Tuple{
                typeof(Base.iterate),
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#703#711"{
                        WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                    },
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.iterate),
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#703#711"{
                        WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
                Tuple{Int64, Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
                Tuple{Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{
                    WannierNLQG.IO.PreparationDiskVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    },
                },
                Tuple{Int64, Tuple{Base.OneTo{Int64}, Int64}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{
                    WannierNLQG.IO.PreparationDiskVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    },
                },
                Tuple{Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{
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
                Tuple{Int64, Tuple{Base.OneTo{Int64}, Int64}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{
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
                Tuple{Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.iterate),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
                Tuple{Base.OneTo{Int64}, Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.iterate),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        _record_precompile(
            Tuple{typeof(Base.length), Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
        )
        _record_precompile(
            Tuple{typeof(Base.length), Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1}},
        )
        _record_precompile(
            Tuple{
                typeof(Base.length),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 3}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.length),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.lock),
                WannierNLQG.IO.var"#9#10"{
                    WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 2}},
                },
                Base.ReentrantLock,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.lock),
                WannierNLQG.IO.var"#9#10"{
                    WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 3}},
                },
                Base.ReentrantLock,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.lock),
                WannierNLQG.IO.var"#9#10"{
                    WannierNLQG.IO.PreparationDiskVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    },
                },
                Base.ReentrantLock,
            },
        )
        _record_precompile(
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
        _record_precompile(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                typeof(Base.hcat),
                Base._InitialValue,
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#404#408"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
                },
            },
        )
        _record_precompile(
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
        _record_precompile(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                typeof(Base.vcat),
                Base._InitialValue,
                Base.Generator{
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
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#679#690",
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.maximum),
                Base.Generator{
                    WannierNLQG.IO.PreparationDiskVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#420#423",
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.reduce),
                Function,
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#404#408"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
                },
            },
        )
        _record_precompile(
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
        _record_precompile(
            Tuple{
                typeof(Base.reduce),
                Function,
                Base.Generator{
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
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#679#690",
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(Base.repr),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
            },
        )
        _record_precompile(
            Tuple{typeof(Base.repr), WannierNLQG.Wannierization.AugmentationAwareSewing},
        )
        _record_precompile(
            Tuple{typeof(Base.repr), WannierNLQG.Wannierization.NativeDFTHamiltonian},
        )
        _record_precompile(
            Tuple{typeof(Base.repr), WannierNLQG.Wannierization.StarCovariantPAWGauge},
        )
        _record_precompile(
            Tuple{
                typeof(Base.task_local_storage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#413#415"{
                    WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                    WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                },
                Symbol,
                Base.Dict{String, Tuple{Tuple, String}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :band_range,
                        :spin_channel,
                        :representation_cutoff_ev,
                        :include_time_reversal,
                        :magnetic_moments_cartesian,
                    ),
                    Tuple{Nothing, Symbol, Nothing, Bool, Nothing},
                },
                Type{WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource},
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:context,), Tuple{String}},
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._paw_sewing_quality_gate!),
                Array{Base.Dict{String, Any}, 1},
                Bool,
                String,
                Float64,
                Float64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:include_time_reversal, :symmetry_tolerance), Tuple{Bool, Float64}},
                typeof(WannierNLQG.SymmetryFoundation.detect_magnetic_symmetry_inventory),
                WannierNLQG.SymmetryFoundation.CrystalStructure,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:normalize_coefficients,), Tuple{Bool}},
                Type{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                Array{Float64, 1},
                Array{Int64, 2},
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
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
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :source_band_gauge,
                        :target_band_gauge,
                        :source_identity_sha256,
                        :physical_isometry_tolerance,
                        :replay_tolerance,
                        :replay_evidence,
                    ),
                    Tuple{String, String, String, Float64, Float64, Nothing},
                },
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._build_band_frame_transform_contract,
                ),
                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                Array{Base.Complex{Float64}, 3},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :strict_metric,
                        :block_partition_policy,
                        :enforce_thresholds,
                        :diagnostic_outer_masks,
                        :diagnostic_frozen_masks,
                    ),
                    Tuple{
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        WannierNLQG.Wannierization.FixedGapPAWBlockPartition,
                        Bool,
                        Nothing,
                        Nothing,
                    },
                },
                typeof(
                    WannierNLQGWannierizationExt.WannierizationInternalSupport.build_augmentation_aware_band_representation,
                ),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                Array{Float64, 2},
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Float64,
                WannierNLQG.Wannierization.AugmentationAwareSewing,
            },
        )
        _record_precompile(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.PAWMatrixElements._StarBlockPartitionDecision,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQG.IO.preparation_compact_workspace!),
                WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQG.IO.write_preparation_checkpoint),
                String,
                String,
                NamedTuple{
                    (:payload, :records, :reused),
                    Tuple{
                        NamedTuple{
                            (
                                :solution,
                                :maxima,
                                :contexts,
                                :representative,
                                :authority_indices,
                                :authority_indices_by_kpoint,
                                :symmetrized_hamiltonians,
                                :selected_raw,
                                :extra_bands,
                            ),
                            Tuple{
                                NamedTuple{
                                    (
                                        :completed_energies,
                                        :shifts,
                                        :points,
                                        :parent_points,
                                        :rotations,
                                        :canonical_operations,
                                        :parent_rotations,
                                        :parent_rotations_lowdin,
                                        :parent_assignments,
                                        :target_principal_angles,
                                        :target_projector_operator,
                                        :target_projector_frobenius,
                                        :parent_energy_shifts,
                                        :parent_eigenvalues,
                                        :selected_indices,
                                        :maxima,
                                        :maximum_contexts,
                                        :workspace_eigenvectors,
                                        :selected_vectors,
                                        :target_anchor_sha256,
                                        :complement_basis,
                                        :complement_rotation,
                                        :target_complement_hamiltonian,
                                        :complement_hamiltonian,
                                    ),
                                    Tuple{
                                        Array{Float64, 1},
                                        Array{Float64, 1},
                                        Base.Dict{
                                            Int64,
                                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        },
                                        Base.Dict{
                                            Int64,
                                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        },
                                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                                        Base.Dict{Int64, Int64},
                                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                                        Base.Dict{Int64, Array{Int64, 1}},
                                        Base.Dict{Int64, Array{Float64, 1}},
                                        Base.Dict{Int64, Float64},
                                        Base.Dict{Int64, Float64},
                                        Base.Dict{Int64, Array{Float64, 1}},
                                        Base.Dict{Int64, Array{Float64, 1}},
                                        Array{Int64, 1},
                                        Base.Dict{String, Float64},
                                        Base.Dict{String, String},
                                        Array{Base.Complex{Float64}, 2},
                                        Array{Base.Complex{Float64}, 2},
                                        Vararg{Nothing, 5},
                                    },
                                },
                                Base.Dict{String, Float64},
                                Base.Dict{String, String},
                                Int64,
                                Array{Int64, 1},
                                Base.Dict{Int64, Array{Int64, 1}},
                                Nothing,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Int64,
                            },
                        },
                        Array{Any, 1},
                        Bool,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQG.Wannierization.prepare_symmetry_covariant_wavefunctions),
                WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
            },
        )
        _record_precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._merge_preparation_star_diagnostics!,
                ),
                WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                Base.Dict{String, Float64},
                Base.Dict{String, String},
                NamedTuple{
                    (:payload, :records, :reused),
                    Tuple{
                        NamedTuple{
                            (
                                :solution,
                                :maxima,
                                :contexts,
                                :representative,
                                :authority_indices,
                                :authority_indices_by_kpoint,
                                :symmetrized_hamiltonians,
                                :selected_raw,
                                :extra_bands,
                            ),
                            Tuple{
                                NamedTuple{
                                    (
                                        :completed_energies,
                                        :shifts,
                                        :points,
                                        :parent_points,
                                        :rotations,
                                        :canonical_operations,
                                        :parent_rotations,
                                        :parent_rotations_lowdin,
                                        :parent_assignments,
                                        :target_principal_angles,
                                        :target_projector_operator,
                                        :target_projector_frobenius,
                                        :parent_energy_shifts,
                                        :parent_eigenvalues,
                                        :selected_indices,
                                        :maxima,
                                        :maximum_contexts,
                                        :workspace_eigenvectors,
                                        :selected_vectors,
                                        :target_anchor_sha256,
                                        :complement_basis,
                                        :complement_rotation,
                                        :target_complement_hamiltonian,
                                        :complement_hamiltonian,
                                    ),
                                    Tuple{
                                        Array{Float64, 1},
                                        Array{Float64, 1},
                                        Base.Dict{
                                            Int64,
                                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        },
                                        Base.Dict{
                                            Int64,
                                            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                                        },
                                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                                        Base.Dict{Int64, Int64},
                                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                                        Base.Dict{Int64, Array{Int64, 1}},
                                        Base.Dict{Int64, Array{Float64, 1}},
                                        Base.Dict{Int64, Float64},
                                        Base.Dict{Int64, Float64},
                                        Base.Dict{Int64, Array{Float64, 1}},
                                        Base.Dict{Int64, Array{Float64, 1}},
                                        Array{Int64, 1},
                                        Base.Dict{String, Float64},
                                        Base.Dict{String, String},
                                        Array{Base.Complex{Float64}, 2},
                                        Array{Base.Complex{Float64}, 2},
                                        Vararg{Nothing, 5},
                                    },
                                },
                                Base.Dict{String, Float64},
                                Base.Dict{String, String},
                                Int64,
                                Array{Int64, 1},
                                Base.Dict{Int64, Array{Int64, 1}},
                                Nothing,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Int64,
                            },
                        },
                        Array{Any, 1},
                        Bool,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._paw_sewing_required_polar_rank,
                ),
                Array{Float64, 1},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._preparation_cached_stage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#680#691"{
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                },
                WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                String,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._preparation_cached_stage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#681#692"{
                    Bool,
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    WannierNLQG.Wannierization.StarCovariantPAWGauge,
                },
                WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                String,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._preparation_cached_stage),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#704#712"{
                    WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                    Array{Float64, 2},
                    Bool,
                    WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                    Nothing,
                    Nothing,
                },
                WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                String,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._preparation_contract),
                WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                NamedTuple{
                    (:raw_native,),
                    Tuple{NamedTuple{(:input_sha256,), Tuple{Base.Dict{String, String}}}},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._preparation_star_execution),
                WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                NamedTuple{
                    (
                        :config,
                        :gauge,
                        :target_range,
                        :target_count,
                        :parent_count,
                        :parent_range,
                        :parent_source,
                        :output_target_indices,
                        :raw_native,
                        :raw_metric,
                        :native,
                        :metric,
                        :lowdin,
                        :operations,
                        :kpoint_map,
                        :reciprocal_shifts,
                        :symmetrized_authority,
                        :target_scope_active,
                        :symmetrized_target_authority,
                        :initial_maxima,
                        :initial_contexts,
                    ),
                    Tuple{
                        WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                        WannierNLQG.Wannierization.StarCovariantPAWGauge,
                        Base.UnitRange{Int64},
                        Int64,
                        Int64,
                        Base.UnitRange{Int64},
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        Base.UnitRange{Int64},
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        NamedTuple{
                            (
                                :native,
                                :metric,
                                :rotations,
                                :hamiltonians,
                                :maximum_before,
                                :maximum_after,
                                :worst_context,
                            ),
                            Tuple{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Float64,
                                Float64,
                                String,
                            },
                        },
                        Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                        Array{Int64, 2},
                        Array{Int64, 3},
                        Bool,
                        Bool,
                        Bool,
                        Base.Dict{String, Float64},
                        Base.Dict{String, String},
                    },
                },
                Array{Array{Int64, 1}, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._preparation_star_result!),
                NamedTuple{
                    (
                        :config,
                        :common,
                        :stars,
                        :indices,
                        :workers,
                        :directory,
                        :contract,
                        :pending,
                        :launched,
                    ),
                    Tuple{
                        WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                        NamedTuple{
                            (
                                :config,
                                :gauge,
                                :target_range,
                                :target_count,
                                :parent_count,
                                :parent_range,
                                :parent_source,
                                :output_target_indices,
                                :raw_native,
                                :raw_metric,
                                :native,
                                :metric,
                                :lowdin,
                                :operations,
                                :kpoint_map,
                                :reciprocal_shifts,
                                :symmetrized_authority,
                                :target_scope_active,
                                :symmetrized_target_authority,
                                :initial_maxima,
                                :initial_contexts,
                            ),
                            Tuple{
                                WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                                WannierNLQG.Wannierization.StarCovariantPAWGauge,
                                Base.UnitRange{Int64},
                                Int64,
                                Int64,
                                Base.UnitRange{Int64},
                                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                                Base.UnitRange{Int64},
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                                NamedTuple{
                                    (
                                        :native,
                                        :metric,
                                        :rotations,
                                        :hamiltonians,
                                        :maximum_before,
                                        :maximum_after,
                                        :worst_context,
                                    ),
                                    Tuple{
                                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                                        Array{Array{Base.Complex{Float64}, 2}, 1},
                                        Array{Array{Base.Complex{Float64}, 2}, 1},
                                        Float64,
                                        Float64,
                                        String,
                                    },
                                },
                                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                                Array{Int64, 2},
                                Array{Int64, 3},
                                Bool,
                                Bool,
                                Bool,
                                Base.Dict{String, Float64},
                                Base.Dict{String, String},
                            },
                        },
                        Array{Array{Int64, 1}, 1},
                        Array{Int64, 1},
                        Int64,
                        String,
                        String,
                        Base.Dict{Int64, Task},
                        Base.Set{Int64},
                    },
                },
                Int64,
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._star_array_sha256),
                Array{Float64, 4},
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._star_array_sha256),
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._star_authoritative_hamiltonian_metadata,
                ),
                WannierNLQG.Wannierization.NativeDFTHamiltonian,
            },
        )
        _record_precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._star_first_star_strict_gate!,
                ),
                WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                NamedTuple{
                    (
                        :gauge,
                        :construction_policy,
                        :star_index,
                        :star,
                        :representative,
                        :representative_energies,
                        :target_indices,
                        :target_count,
                        :workspace,
                        :hamiltonian_average,
                        :symmetrized_hamiltonians,
                        :formal_target_actions,
                        :formal_target_indices,
                        :authoritative_hamiltonian,
                        :target_subspace_contract,
                        :target_projector,
                        :selected_raw,
                        :transports,
                        :operations,
                        :native,
                        :raw_native,
                        :raw_metric,
                        :metric,
                        :lowdin,
                        :kpoint_map,
                        :reciprocal_shifts,
                    ),
                    Tuple{
                        WannierNLQG.Wannierization.StarCovariantPAWGauge,
                        Symbol,
                        Int64,
                        Array{Int64, 1},
                        Int64,
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Int64,
                        Base.UnitRange{Int64},
                        Array{Base.Complex{Float64}, 2},
                        Nothing,
                        Nothing,
                        Nothing,
                        WannierNLQG.Wannierization.NativeDFTHamiltonian,
                        Nothing,
                        Array{Base.Complex{Float64}, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                        Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        NamedTuple{
                            (
                                :native,
                                :metric,
                                :rotations,
                                :hamiltonians,
                                :maximum_before,
                                :maximum_after,
                                :worst_context,
                            ),
                            Tuple{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Float64,
                                Float64,
                                String,
                            },
                        },
                        Array{Int64, 2},
                        Array{Int64, 3},
                    },
                },
                NamedTuple{
                    (
                        :completed_energies,
                        :shifts,
                        :points,
                        :parent_points,
                        :rotations,
                        :canonical_operations,
                        :parent_rotations,
                        :parent_rotations_lowdin,
                        :parent_assignments,
                        :target_principal_angles,
                        :target_projector_operator,
                        :target_projector_frobenius,
                        :parent_energy_shifts,
                        :parent_eigenvalues,
                        :selected_indices,
                        :maxima,
                        :maximum_contexts,
                        :workspace_eigenvectors,
                        :selected_vectors,
                        :target_anchor_sha256,
                        :complement_basis,
                        :complement_rotation,
                        :target_complement_hamiltonian,
                        :complement_hamiltonian,
                    ),
                    Tuple{
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Base.Dict{Int64, WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                        Base.Dict{Int64, WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                        Base.Dict{Int64, Int64},
                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                        Base.Dict{Int64, Array{Int64, 1}},
                        Base.Dict{Int64, Array{Float64, 1}},
                        Base.Dict{Int64, Float64},
                        Base.Dict{Int64, Float64},
                        Base.Dict{Int64, Array{Float64, 1}},
                        Base.Dict{Int64, Array{Float64, 1}},
                        Array{Int64, 1},
                        Base.Dict{String, Float64},
                        Base.Dict{String, String},
                        Array{Base.Complex{Float64}, 2},
                        Array{Base.Complex{Float64}, 2},
                        Vararg{Nothing, 5},
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._star_hamiltonian_correction_sha256,
                ),
                WannierNLQG.Wannierization.NoDiscreteHamiltonianCorrection,
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._star_merge_strict_maxima!),
                WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        _record_precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._star_partition_candidate_solution,
                ),
                Array{Array{Int64, 1}, 1},
                NamedTuple{
                    (
                        :gauge,
                        :construction_policy,
                        :star_index,
                        :star,
                        :representative,
                        :representative_energies,
                        :target_indices,
                        :target_count,
                        :workspace,
                        :hamiltonian_average,
                        :symmetrized_hamiltonians,
                        :formal_target_actions,
                        :formal_target_indices,
                        :authoritative_hamiltonian,
                        :target_subspace_contract,
                        :target_projector,
                        :selected_raw,
                        :transports,
                        :operations,
                        :native,
                        :raw_native,
                        :raw_metric,
                        :metric,
                        :lowdin,
                        :kpoint_map,
                        :reciprocal_shifts,
                    ),
                    Tuple{
                        WannierNLQG.Wannierization.StarCovariantPAWGauge,
                        Symbol,
                        Int64,
                        Array{Int64, 1},
                        Int64,
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Int64,
                        Base.UnitRange{Int64},
                        Array{Base.Complex{Float64}, 2},
                        Nothing,
                        Nothing,
                        Nothing,
                        WannierNLQG.Wannierization.NativeDFTHamiltonian,
                        Nothing,
                        Array{Base.Complex{Float64}, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                        Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        NamedTuple{
                            (
                                :native,
                                :metric,
                                :rotations,
                                :hamiltonians,
                                :maximum_before,
                                :maximum_after,
                                :worst_context,
                            ),
                            Tuple{
                                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Float64,
                                Float64,
                                String,
                            },
                        },
                        Array{Int64, 2},
                        Array{Int64, 3},
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._star_partition_candidate_violations,
                ),
                NamedTuple{
                    (
                        :completed_energies,
                        :shifts,
                        :points,
                        :parent_points,
                        :rotations,
                        :canonical_operations,
                        :parent_rotations,
                        :parent_rotations_lowdin,
                        :parent_assignments,
                        :target_principal_angles,
                        :target_projector_operator,
                        :target_projector_frobenius,
                        :parent_energy_shifts,
                        :parent_eigenvalues,
                        :selected_indices,
                        :maxima,
                        :maximum_contexts,
                        :workspace_eigenvectors,
                        :selected_vectors,
                        :target_anchor_sha256,
                        :complement_basis,
                        :complement_rotation,
                        :target_complement_hamiltonian,
                        :complement_hamiltonian,
                    ),
                    Tuple{
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Base.Dict{Int64, WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                        Base.Dict{Int64, WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                        Base.Dict{Int64, Int64},
                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                        Base.Dict{Int64, Array{Base.Complex{Float64}, 2}},
                        Base.Dict{Int64, Array{Int64, 1}},
                        Base.Dict{Int64, Array{Float64, 1}},
                        Base.Dict{Int64, Float64},
                        Base.Dict{Int64, Float64},
                        Base.Dict{Int64, Array{Float64, 1}},
                        Base.Dict{Int64, Array{Float64, 1}},
                        Array{Int64, 1},
                        Base.Dict{String, Float64},
                        Base.Dict{String, String},
                        Array{Base.Complex{Float64}, 2},
                        Array{Base.Complex{Float64}, 2},
                        Vararg{Nothing, 5},
                    },
                },
                WannierNLQG.Wannierization.PAWGaugeThresholds,
                WannierNLQG.Wannierization.FixedGapPAWBlockPartition,
                WannierNLQG.Wannierization.NativeDFTHamiltonian,
                Bool,
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._star_target_contract_masks),
                WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._star_transport),
                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                Int64,
                Int64,
                Int64,
                Base.SubArray{
                    Int64,
                    1,
                    Array{Int64, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Int64, Int64},
                    true,
                },
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._star_update_maximum!),
                Base.Dict{String, Float64},
                Base.Dict{String, String},
                String,
                Float64,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._strict_reconstruction_diagnostics,
                ),
                WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._strict_scoped_diagnostics!),
                Array{Any, 1},
                Array{Base.Complex{Float64}, 2},
                Tuple{
                    NamedTuple{
                        (:scope, :source_indices, :target_indices),
                        Tuple{Symbol, Base.UnitRange{Int64}, Base.UnitRange{Int64}},
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._strict_update_maximum!),
                Base.Dict{String, Float64},
                Base.Dict{String, String},
                String,
                Float64,
                NamedTuple{
                    (
                        :operation,
                        :source_kpoint,
                        :target_kpoint,
                        :antiunitary,
                        :translation_fractional,
                    ),
                    Tuple{Int64, Int64, Int64, Bool, Tuple{Float64, Float64, Float64}},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._strict_update_maximum!),
                Base.Dict{String, Float64},
                Base.Dict{String, String},
                String,
                Float64,
                NamedTuple{
                    (
                        :operation,
                        :source_kpoint,
                        :target_kpoint,
                        :antiunitary,
                        :translation_fractional,
                        :block_label,
                        :block_start,
                        :block_stop,
                    ),
                    Tuple{
                        Int64,
                        Int64,
                        Int64,
                        Bool,
                        Tuple{Float64, Float64, Float64},
                        Int64,
                        Int64,
                        Int64,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._strict_update_maximum!),
                Base.Dict{String, Float64},
                Base.Dict{String, String},
                String,
                Float64,
                NamedTuple{
                    (
                        :operation,
                        :source_kpoint,
                        :target_kpoint,
                        :antiunitary,
                        :translation_fractional,
                        :target_band,
                        :source_band,
                    ),
                    Tuple{
                        Int64,
                        Int64,
                        Int64,
                        Bool,
                        Tuple{Float64, Float64, Float64},
                        Int64,
                        Int64,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements.prepare_symmetry_covariant_wavefunctions,
                ),
                WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig,
            },
        )
        _record_precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WannierizationInternalSupport.atomic_hdf5_write,
                ),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#623#625"{
                    Symbol,
                    Symbol,
                    Array{String, 1},
                    String,
                    WannierNLQGWannierizationExt.PAWMatrixElements._StarCovariantPAWPayload,
                    Symbol,
                    String,
                    NTuple{15, String},
                },
                String,
            },
        )
        @assert !MPI.Initialized()
    end
end
