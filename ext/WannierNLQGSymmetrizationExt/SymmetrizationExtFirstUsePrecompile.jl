# Compile the retained projection entry without file writes or MPI initialization.
@compile_workload begin
    if workload_enabled(parentmodule(SymmetrizationConfig))
        precompile(symmetrize_wannier_operators, (SymmetrizationConfig,))
    end
end
