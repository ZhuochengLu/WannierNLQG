# Actual fixed-subspace public solver signatures, including MPI ranks.
# Compile only; no solver, file writing, or MPI initialization.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_sequence(
            Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                LinearAlgebra.Adjoint{Base.Complex{Float64}, Array{Base.Complex{Float64}, 2}},
            },
        )
        false
        false
        false
        false
        false
        false
        false
        false
        _record_sequence(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 3}})
        false
        false
        false
        _record_sequence(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (:source_sha256, :invariant_residuals),
                    Tuple{Base.Dict{String, String}, Base.Dict{String, Float64}},
                },
                Type{WannierNLQG.Wannierization.WannierizationFixedSubspace},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Array{Int64, 1},
                Base.BitArray{2},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{:not_atomic, Array{Float64, 1}, Base.Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_sequence(
            Tuple{
                typeof(Base.Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Wannierization.TBSymmetryMetric,
                    Base.Core.AddrSpace{Core}(0x00),
                },
            },
        )
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        false
        _record_sequence(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.SolverCheckpoint.read_wannierization_fixed_subspace_hdf5,
                ),
                String,
            },
        )
    end
end
