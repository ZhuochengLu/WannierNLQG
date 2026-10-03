# Actual residual container and slice types; deterministic memory-only execution.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let
            key=(1, 0, 0, 0, 1, 0, 0, 0, 1)
            seen=Set{Tuple}([key])
            Base.invokelatest(in, key, seen)
            Base.invokelatest(haskey, Dict(key=>1), key)
            metadata=Dict("source"=>"precompile")
            Base.invokelatest(repr, (metadata, metadata, metadata, metadata))
            Base.invokelatest(repr, (1, 2, 3))
            Base.invokelatest(repr, (operation = 1, source_kpoint = 1, target_kpoint = 1))
            Base.invokelatest(
                Dict,
                (
                    "source"=>"precompile",
                    "status"=>"checked",
                    "size"=>1,
                    "count"=>1,
                    "metrics"=>Dict("a"=>1.0),
                    "metadata"=>metadata,
                ),
            )
            Base.invokelatest(join, (1.0, 2.0, 3.0, 4.0), ",")
            io=IOBuffer()
            Base.invokelatest(join, io, (1.0, 2.0, 3.0, 4.0), ",")
            Base.invokelatest(join, io, (1.0, 2.0, 3.0), ',')
            Base.invokelatest(join, io, ("a", "b", "c", "d", "e", "f", "g"), ',')
            close(io)
            complex4=reshape(ComplexF64[1, 0.2im, -0.2im, 2], 2, 2, 1, 1)
            complex3=reshape(copy(vec(complex4)), 2, 2, 1)
            values=ComplexF64[1 0.2im; -0.2im 2]
            Base.invokelatest(
                Base.Broadcast.materialize!,
                view(complex4,:,:,1,1),
                Base.Broadcast.broadcasted(identity, values),
            )
            Base.invokelatest(
                Base.Broadcast.materialize!,
                view(complex3,:,:,1),
                Base.Broadcast.broadcasted(identity, values),
            )
            real2=[1.0 2.0; 3.0 4.0]
            Base.invokelatest(
                Base.Broadcast.materialize!,
                view(real2, 1, :),
                Base.Broadcast.broadcasted(identity, [1.0, 2.0]),
            )
            Base.invokelatest(
                Base.Broadcast.materialize!,
                view(real2, :, 1),
                Base.Broadcast.broadcasted(identity, [1.0, 2.0]),
            )
        end
        @assert !MPI.Initialized()
    end
end
