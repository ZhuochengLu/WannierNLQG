using WannierNLQG, MPI
@assert !MPI.Initialized()
for path in readlines(only(ARGS))
    original=WannierNLQG.IO.read_task_input_file(path).document
    resolved=read_task_input(path)
    @assert isempty(resolved.pending)
    @assert resolved.effective==original
    @assert !haskey(resolved.effective, "schema_version")
    @assert !MPI.Initialized()
end
println("WORKFLOW_EFFECTIVE_FRESH_PROCESS_PASS")
