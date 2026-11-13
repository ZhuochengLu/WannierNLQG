# Maintained application boundary shared by CLI, capture and independent first use.
# Callers own resource admission and MPI lifetime. No benchmark policy or extra
# output/qualification work belongs here.
"""
    run_wannier_application(config::Wannierization.WannierizationConfig)

Execute the existing Wannierization workflow without changing its result, failure,
checkpoint or MPI ownership contracts. This unexported Runtime entry is also used
by compilation workloads; material parameters remain in their input files.
"""
function run_wannier_application(config::Wannierization.WannierizationConfig; run_record = nothing)
    return Wannierization.construct_wannier_functions(config; run_record)
end

# Resolve a Wannierization task document and execute it through the same maintained application entrypoint.
function run_wannier_application(path::AbstractString)
    input = read_task_input(path)
    input isa WorkflowInputResolution && input.config isa Wannierization.WannierizationConfig ||
        throw(ArgumentError("run_wannier_application requires a Wannierization input"))
    return run_task_input(input)
end

# Native generator files are working data. Explicit checkpoint/restart or a directory retains them.
function _with_workflow_native_scratch(body::F, input::WorkflowInputResolution) where {F}
    config=input.config
    transient=get(input.metadata, "transient_native_artifacts", false)
    transient || return body(config)
    provider=config.input.matrix_elements
    apply = function (scratch)
        T=typeof(provider)
        T in (Wannierization.NativeQEPAWMatrices, Wannierization.NativeVASPPAWMatrices) &&
        provider.topology!==nothing || throw(
            ArgumentError("transient native storage requires an owned supported topology"),
        )
        replacement=T(
            provider.topology;
            artifact_dir = scratch,
            oracle_mmn_file = provider.oracle_mmn_file,
            oracle_amn_file = provider.oracle_amn_file,
            thresholds = provider.thresholds,
            require_oracle = provider.require_oracle,
        )
        old=abspath(provider.artifact_dir)
        relocate(
            value,
        )=value isa String && startswith(abspath(value), old*"/") ?
          joinpath(scratch, relpath(value, old)) : value
        inputs=Dict{Symbol, Any}(:matrix_elements=>replacement)
        for name in (:eig_file, :mmn_file, :amn_file)
            inputs[name]=relocate(getfield(config.input, name))
        end
        outputs=Dict{Symbol, Any}(
            name=>relocate(getfield(config.output, name)) for
            name in fieldnames(typeof(config.output)) if getfield(config.output, name) isa String
        )
        actual=Wannierization.reconfigure_wannierization(
            config;
            input = (; inputs...),
            output = (; outputs...),
        )
        body(actual)
    end
    if config.solver.parallel==:mpi
        mpi=Wannierization.MPI
        mpi.Initialized() || mpi.Init()
        root=mpi.Comm_rank(mpi.COMM_WORLD)==0
        scratch=mpi.bcast(
            root ? mktempdir(; prefix = "wanniernlqg-native-") : nothing,
            0,
            mpi.COMM_WORLD,
        )
        try
            return apply(scratch)
        finally
            mpi.Barrier(mpi.COMM_WORLD)
            root && isdir(scratch) && rm(scratch; recursive = true)
        end
    end
    return mktempdir(apply; prefix = "wanniernlqg-native-")
end
