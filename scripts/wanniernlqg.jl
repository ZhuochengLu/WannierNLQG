#!/usr/bin/env julia
using WannierNLQG

using WannierNLQG.Runtime: task_input_cli

if abspath(PROGRAM_FILE) == @__FILE__
    try
        exit(task_input_cli(ARGS))
    catch exception
        exception isa InterruptException && rethrow()
        showerror(stderr, exception)
        println(stderr)
        exit(1)
    end
end
