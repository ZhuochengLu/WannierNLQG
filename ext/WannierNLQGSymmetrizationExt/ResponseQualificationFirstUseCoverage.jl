# Exact public and extension signatures from the first successful square
# Wannier90 qualification call. This compiles code only; it never reads files
# or performs a qualification during package precompilation.
# Trace: response_w90_candidate022_pilot_v4/target_call_trace.jl
@compile_workload begin
    if workload_enabled(parentmodule(Symmetrization))
        keywords = NamedTuple{
            (:win_file, :amn_file, :chk_file, :mmn_file, :tb_file, :diagnostic_continue),
            Tuple{String, String, String, String, String, Bool},
        }
        precompile(
            Tuple{
                typeof(Core.kwcall),
                keywords,
                typeof(Symmetrization.qualify_response_symmetry_wannier90),
                String,
            },
        )
        precompile(
            Tuple{
                typeof(Core.kwcall),
                keywords,
                typeof(qualify_response_symmetry_wannier90),
                String,
            },
        )
    end
end
