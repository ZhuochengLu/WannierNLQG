# Observed dd-f metadata format; memory-only, not stdout or scientific output.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let
            buffer=IOBuffer()
            format=Printf.Format("%d %d %.12f")
            Base.invokelatest(Printf.format, buffer, format, 1, 2, 0.5)
            close(buffer)
        end
        @assert !MPI.Initialized()
    end
end
