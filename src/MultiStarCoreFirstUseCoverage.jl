# Four-star Standard residual on types owned by the core package, from the real public trace.
# Declarations only; no solver, MPI initialization or output writing.
@compile_workload begin
    if FIRST_USE_WORKLOAD_ENABLED
        false
        false
        precompile(
            Tuple{
                typeof(Base.repr),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
            },
        )
        precompile(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:normalize_coefficients,), Tuple{Bool}},
                Type{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                Array{Float64, 1},
                Array{Int64, 2},
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 1},
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
                Symbol,
            },
        )
        precompile(
            Tuple{typeof(Base.getproperty), WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, Symbol},
        )
        precompile(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:include_time_reversal, :symmetry_tolerance), Tuple{Bool, Float64}},
                typeof(WannierNLQG.SymmetryFoundation.detect_magnetic_symmetry_inventory),
                WannierNLQG.SymmetryFoundation.CrystalStructure,
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.MagneticSymmetryInventory,
                Symbol,
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 3}},
                Symbol,
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 2}},
                Symbol,
            },
        )
        precompile(
            Tuple{
                typeof(Base.getindex),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 3}},
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(Base.first),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        precompile(
            Tuple{
                typeof(Base.length),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        precompile(
            Tuple{
                typeof(Base.axes),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        precompile(
            Tuple{
                typeof(Base.getindex),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                Symbol,
            },
        )
        precompile(
            Tuple{typeof(Base.length), Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1}},
        )
        precompile(
            Tuple{
                typeof(Base.getindex),
                WannierNLQG.IO.PreparationDiskVector{Array{Base.Complex{Float64}, 2}},
                Int64,
            },
        )
        precompile(
            Tuple{typeof(Base.length), Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
        )
        precompile(
            Tuple{typeof(Base.first), Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
        )
        precompile(
            Tuple{typeof(Base.axes), Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
        )
        precompile(
            Tuple{
                typeof(Base.getindex),
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(Base.checkbounds),
                Type{Bool},
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(Base.eachindex),
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
            },
        )
        precompile(
            Tuple{
                typeof(Base.eachindex),
                WannierNLQG.IO.PreparationDiskVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                },
            },
        )
        precompile(
            Tuple{
                typeof(Base.getindex),
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (:representation, :construction_diagnostics),
                    Tuple{WannierNLQG.SymmetryFoundation.BandRepresentation, Array{Any, 1}},
                },
                Symbol,
            },
        )
        false
        @assert !MPI.Initialized()
    end
end
