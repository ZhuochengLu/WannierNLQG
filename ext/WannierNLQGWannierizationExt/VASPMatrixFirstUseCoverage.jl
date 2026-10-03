# Native VASP PAW MMN and AMN generation signatures from qualified cold calls.
# Signatures only: no wavefunction loading, operator writing, or MPI initialization here.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        false
        _record_early_prepare(
            Tuple{Type{WannierNLQG.Wannierization.VASPPAWParityThresholds}, Vararg{Float64, 10}},
        )
        false
        _record_early_prepare(Tuple{typeof(Base.collect), Tuple{Float64, Float64, Float64}})
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(-)),
                Array{Float64, 1},
                Array{Float64, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.:(-)),
                    Tuple{Array{Float64, 1}, Array{Float64, 1}},
                },
            },
        )
        _record_early_prepare(
            Tuple{Type{Array{Array{Base.Complex{Float64}, 3}, 1}}, UndefInitializer, Int64},
        )
        _record_early_prepare(Tuple{typeof(Base.trues), Int64, Int64})
        _record_early_prepare(Tuple{typeof(Base.ones), Type{Float64}, Int64, Int64})
        false
        false
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#84#86"{
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    Array{Base.Complex{Float64}, 2},
                },
                Base.OneTo{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#84#86"{
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Base.Complex{Float64}, 2},
                    },
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.transpose), Array{Base.Complex{Float64}, 2}})
        _record_early_prepare(
            Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                Array{Float64, 2},
                LinearAlgebra.Transpose{Base.Complex{Float64}, Array{Base.Complex{Float64}, 2}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(+)),
                Array{Base.Complex{Float64}, 2},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(+)),
                    Tuple{Array{Base.Complex{Float64}, 2}, Array{Base.Complex{Float64}, 2}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(+)),
                    Tuple{
                        Array{Base.Complex{Float64}, 2},
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{2},
                            Nothing,
                            typeof(Base.:(+)),
                            Tuple{Array{Base.Complex{Float64}, 2}, Array{Base.Complex{Float64}, 2}},
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#98#100"{
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                },
                Base.OneTo{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.reduce),
                Function,
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#98#100"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
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
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#98#100"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                typeof(Base.vcat),
                Base._InitialValue,
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#98#100"{
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    },
                },
            },
        )
        _record_early_prepare(Tuple{Type{Base.Complex{Float64}}, Bool})
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._canonicalize_vasp_amn_for_wannierization,
                ),
                WannierNLQG.IO.WannierAMN,
                Array{Float64, 2},
                WannierNLQG.WannierProjection.WannierProjectionBasis,
                WannierNLQGWannierizationExt.PAWMatrixElements.VASPProjectionContract,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._validate_vasp_solver_gauge_entry,
                ),
                WannierNLQGWannierizationExt.PAWMatrixElements.VASPProjectionEntry,
                NamedTuple{
                    (
                        :principal_quantum_number,
                        :angular_momentum,
                        :magnetic_index,
                        :center_fractional,
                        :center_integer_translation,
                        :local_x_cartesian,
                        :local_z_cartesian,
                        :spin_index,
                        :wannier_index,
                    ),
                    Tuple{
                        Int64,
                        Int64,
                        Int64,
                        Tuple{Float64, Float64, Float64},
                        Tuple{Int64, Int64, Int64},
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        Int64,
                        Int64,
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.merge),
                Base.Dict{String, String},
                Base.Dict{String, String},
                Base.Dict{String, String},
            },
        )
    end
end
