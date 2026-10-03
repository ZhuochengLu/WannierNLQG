# Small, deterministic, memory-only instances of observed metadata/matrix calls.
# No file is created, no public preparation task runs, and no MPI is initialized.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let
            Base.invokelatest(repr, (nothing, nothing))
            metadata = Dict("source" => "precompile", "status" => "checked")
            buffer = IOBuffer()
            Base.invokelatest(show, buffer, (metadata, metadata, metadata, metadata))
            close(buffer)
            source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
                "precompile-only";
                band_range = 1:1,
                include_time_reversal = false,
            )
            Base.invokelatest(repr, source)
            key = (1, 0, 0, 0, 1, 0, 0, 0, 1)
            seen = Set{Tuple}()
            Base.invokelatest(push!, seen, key)
            matrices = Dict{Tuple, Matrix{Float64}}()
            Base.invokelatest(setindex!, matrices, [1.0 0.0; 0.0 2.0], key)
            Base.invokelatest(getindex, matrices, key)
            Base.invokelatest(-, [1.0, 2.0], reshape([0.5, 0.25], 2, 1))
            values = reshape(ComplexF64[1, 0.2im, -0.2im, 2], 2, 2, 1, 1)
            indices = [1, 2]
            target = Base.invokelatest(view, values, indices, indices, 1, 1)
            Base.invokelatest(
                Base.Broadcast.materialize!,
                target,
                Base.Broadcast.broadcasted(identity, ComplexF64[1 0.2im; -0.2im 2]),
            )
            Base.invokelatest(*, adjoint(Matrix(target)), LinearAlgebra.Diagonal([1.0, 2.0]))
        end
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Base.Dict{Int64, WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
            },
        )
        _record_precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{Base.IOStream},
                Tuple{
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    Float64,
                    Tuple{Int64, Int64, Int64},
                },
            },
        )
        @assert !MPI.Initialized()
    end
end
