const MPI_RANK_ENV_KEYS = ("OMPI_COMM_WORLD_RANK", "PMIX_RANK", "PMI_RANK", "SLURM_PROCID")

const MPI_SIZE_ENV_KEYS = ("OMPI_COMM_WORLD_SIZE", "PMIX_SIZE", "PMI_SIZE", "SLURM_NTASKS")

"""Return whether any named environment variable explicitly enables MPI."""
function mpi_env_truthy(names::String...)
    for name in names
        value = lowercase(strip(get(ENV, name, "")))
        if value in ("1", "true", "yes", "on")
            return true
        end
    end
    return false
end

"""Parse an optional launcher integer; missing, blank or malformed values return nothing."""
function _mpi_env_int(name::String)
    value = strip(get(ENV, name, ""))
    isempty(value) && return nothing
    parsed = tryparse(Int, value)
    return isnothing(parsed) ? nothing : parsed
end

"""Read the first recognized launcher rank; return zero outside a launcher."""
function mpi_process_rank()
    for name in MPI_RANK_ENV_KEYS
        value = _mpi_env_int(name)
        isnothing(value) || return value
    end
    return 0
end

"""Read the first positive launcher size; return one for serial execution."""
function mpi_process_size()
    for name in MPI_SIZE_ENV_KEYS
        value = _mpi_env_int(name)
        if !isnothing(value) && value > 0
            return value
        end
    end
    return 1
end

"""Detect launcher rank/size variables independently of package-specific opt-in."""
function mpi_launcher_requested()
    mpi_process_size() > 1 && return true
    return any(name -> haskey(ENV, name), MPI_RANK_ENV_KEYS) ||
           any(name -> haskey(ENV, name), MPI_SIZE_ENV_KEYS)
end

"""Identify rank zero from launcher metadata, including ordinary serial processes."""
mpi_is_root_process() = mpi_process_rank() == 0
"""Check whether diagnostic output from non-root ranks was explicitly enabled."""
mpi_log_all_ranks() = mpi_env_truthy("WANNIERNLQG_LOG_ALL_RANKS")

"""Serialize progress-aware diagnostic output, suppressing non-root ranks by default."""
function mpi_ranked_debug_log(
    debug_lock::ReentrantLock,
    message::AbstractString,
    rank::Integer = mpi_process_rank(),
)
    if rank != 0 && !mpi_log_all_ranks()
        return nothing
    end

    Base.lock(debug_lock)
    try
        handled = progress_record_debug_message!(message, rank)
        if !handled && mpi_log_all_ranks()
            text = mpi_launcher_requested() ? "[rank $(rank)] $(message)" : message
            println(text)
            flush(stdout)
        end
    finally
        Base.unlock(debug_lock)
    end
    return nothing
end

"""Track MPI availability and whether this context owns MPI initialization/finalization."""
mutable struct MPIExecutionContext
    has_mpi::Bool
    started::Bool
end

const MPI_BUNDLE_ACTIVE = Ref(false)
const _MPI_CONTEXT_ENV_NAMES = IdDict{MPIExecutionContext, Tuple{Vararg{String}}}()
const _MPI_CONTEXT_LOCK = ReentrantLock()

"""Resolve a lazy MPI global in the latest world, including first imports inside Julia 1.12 calls."""
_mpi_binding(name::Symbol) = Base.invokelatest(() -> getproperty(MPI, name))

"""Load MPI.jl on explicit demand and report a missing dependency without swallowing other errors."""
function load_mpi_or_error()
    try
        @eval using MPI
        return true
    catch err
        if err isa ArgumentError || err isa LoadError
            error(
                "MPI execution was requested, but MPI.jl could not be loaded. Install MPI.jl or run without an MPI launcher.",
            )
        end
        rethrow(err)
    end
end

"""Register request-variable names with a context; re-evaluate their values when execution starts."""
function make_mpi_context(env_names::String...)
    requested = mpi_env_truthy(env_names...) || mpi_launcher_requested()
    context = MPIExecutionContext(requested ? load_mpi_or_error() : false, false)
    lock(_MPI_CONTEXT_LOCK) do
        _MPI_CONTEXT_ENV_NAMES[context] = env_names
    end
    return context
end

"""Resolve live MPI requests after loading cached code and initialize MPI only when requested.

Only a context that calls MPI.Init owns finalization. Caller-owned sessions remain
active, and attempting to reuse a finalized process raises an explicit error.
"""
function mpi_context_initialize!(context::MPIExecutionContext)
    lock(_MPI_CONTEXT_LOCK) do
        env_names = get(_MPI_CONTEXT_ENV_NAMES, context, nothing)
        requested =
            mpi_launcher_requested() ||
            (env_names === nothing ? context.has_mpi : mpi_env_truthy(env_names...))
        if !context.started
            context.has_mpi = requested ? load_mpi_or_error() : false
        end
        if context.has_mpi
            Base.invokelatest(_mpi_binding(:Finalized)) && error(
                "MPI has already been finalized in this process; start a new process for another MPI run.",
            )
            if !Base.invokelatest(_mpi_binding(:Initialized))
                Base.invokelatest(_mpi_binding(:Init))
                context.started = true
            end
        end
    end
    return nothing
end

"""Finalize MPI owned by this context unless a fused task bundle still owns the lifecycle."""
function mpi_context_finalize!(context::MPIExecutionContext)
    MPI_BUNDLE_ACTIVE[] && return nothing
    if context.has_mpi && context.started && !Base.invokelatest(_mpi_binding(:Finalized))
        Base.invokelatest(_mpi_binding(:Finalize))
    end
    return nothing
end

"""Finalize only MPI initialized by this context; preserve caller-owned MPI sessions."""
function mpi_context_force_finalize!(context::MPIExecutionContext)
    if context.has_mpi && context.started && !Base.invokelatest(_mpi_binding(:Finalized))
        Base.invokelatest(_mpi_binding(:Finalize))
    end
    return nothing
end

"""Return the world communicator for an active MPI context, or nothing in serial mode."""
mpi_context_comm_world(context::MPIExecutionContext) =
    context.has_mpi ? _mpi_binding(:COMM_WORLD) : nothing
"""Return the communicator rank, or zero for a serial context."""
mpi_context_comm_rank(context::MPIExecutionContext, comm) =
    context.has_mpi ? Base.invokelatest(_mpi_binding(:Comm_rank), comm) : 0
"""Return the communicator size, or one for a serial context."""
mpi_context_comm_size(context::MPIExecutionContext, comm) =
    context.has_mpi ? Base.invokelatest(_mpi_binding(:Comm_size), comm) : 1
"""Sum local values to the chosen root through MPI.Reduce!; return the input in serial mode."""
mpi_context_reduce_sum(context::MPIExecutionContext, local_value, root, comm) =
    context.has_mpi ? Base.invokelatest(_mpi_binding(:Reduce!), local_value, +, root, comm) :
    local_value

"""Read a live communicator rank when available, otherwise use launcher metadata."""
function mpi_context_log_rank(context::MPIExecutionContext)
    if context.has_mpi &&
       Base.invokelatest(_mpi_binding(:Initialized)) &&
       !Base.invokelatest(_mpi_binding(:Finalized))
        return Base.invokelatest(_mpi_binding(:Comm_rank), _mpi_binding(:COMM_WORLD))
    end
    return mpi_process_rank()
end

"""Route a context diagnostic through rank filtering and the progress-output lock."""
function mpi_context_debug_log(
    context::MPIExecutionContext,
    debug_lock::ReentrantLock,
    message::AbstractString,
)
    return mpi_ranked_debug_log(debug_lock, message, mpi_context_log_rank(context))
end

const CONVENTIONAL_SC_MPI_CONTEXT = make_mpi_context("WANNIERNLQG_CONVENTIONAL_USE_MPI")
const CONVENTIONAL_GEOMETRY_MPI_CONTEXT = make_mpi_context(
    "WANNIERNLQG_CONVENTIONAL_GEOMETRY_USE_MPI",
    "WANNIERNLQG_CONVENTIONAL_USE_MPI",
)
const BUNDLE_MPI_CONTEXT = make_mpi_context("WANNIERNLQG_USE_MPI")
const INJECTION_CURRENT_MPI_CONTEXT =
    make_mpi_context("WANNIERNLQG_USE_MPI", "WANNIERNLQG_INJECTION_CURRENT_USE_MPI")
const PROJECTOR_MPI_CONTEXT =
    make_mpi_context("WANNIERNLQG_USE_MPI", "WANNIERNLQG_PROJECTOR_USE_MPI")
const GEOMETRIC_LOOP_MPI_CONTEXT =
    make_mpi_context("WANNIERNLQG_USE_MPI", "WANNIERNLQG_GEOMETRIC_LOOP_USE_MPI")

# Compatibility snapshots describe context construction only. Live execution uses
# MPIExecutionContext.has_mpi after mpi_context_initialize! resolves requests.
const BUNDLE_HAS_MPI = BUNDLE_MPI_CONTEXT.has_mpi
const CONVENTIONAL_SC_HAS_MPI = CONVENTIONAL_SC_MPI_CONTEXT.has_mpi
const CONVENTIONAL_GEOMETRY_HAS_MPI = CONVENTIONAL_GEOMETRY_MPI_CONTEXT.has_mpi
const INJECTION_CURRENT_HAS_MPI = INJECTION_CURRENT_MPI_CONTEXT.has_mpi
const PROJECTOR_HAS_MPI = PROJECTOR_MPI_CONTEXT.has_mpi
const GEOMETRIC_LOOP_HAS_MPI = GEOMETRIC_LOOP_MPI_CONTEXT.has_mpi

"""Resolve live requests and initialize MPI for the fused response bundle when requested."""
bundle_mpi_initialize() = mpi_context_initialize!(BUNDLE_MPI_CONTEXT)
"""Release MPI owned by the fused response bundle, unless a fused bundle is active."""
bundle_mpi_finalize() = mpi_context_finalize!(BUNDLE_MPI_CONTEXT)
"""Return the world communicator for the fused response bundle, or nothing in serial mode."""
bundle_mpi_comm_world() = mpi_context_comm_world(BUNDLE_MPI_CONTEXT)
"""Return the communicator rank for the fused response bundle, or zero in serial mode."""
bundle_mpi_comm_rank(comm) = mpi_context_comm_rank(BUNDLE_MPI_CONTEXT, comm)
"""Return the communicator size for the fused response bundle, or one in serial mode."""
bundle_mpi_comm_size(comm) = mpi_context_comm_size(BUNDLE_MPI_CONTEXT, comm)
"""Sum values to the selected root for the fused response bundle; serial mode returns the input."""
bundle_mpi_reduce_sum(local_value, root, comm) =
    mpi_context_reduce_sum(BUNDLE_MPI_CONTEXT, local_value, root, comm)
"""Broadcast one serializable small object from a world or leader root."""
bundle_mpi_bcast(value, root, comm) =
    BUNDLE_MPI_CONTEXT.has_mpi ? Base.invokelatest(_mpi_binding(:bcast), value, root, comm) : value
"""Synchronize the bundle communicator; do nothing in serial mode."""
bundle_mpi_barrier(comm) =
    BUNDLE_MPI_CONTEXT.has_mpi ? Base.invokelatest(_mpi_binding(:Barrier), comm) : nothing

"""Execute a small setup call on one MPI root and broadcast success or failure."""
function bundle_mpi_root_call(function_value; root::Int = 0, comm = bundle_mpi_comm_world())
    rank = bundle_mpi_comm_rank(comm)
    packet = if rank == root
        try
            (ok = true, value = function_value(), error = "")
        catch exception
            (ok = false, value = nothing, error = sprint(showerror, exception, catch_backtrace()))
        end
    else
        nothing
    end
    packet = bundle_mpi_bcast(packet, root, comm)
    packet.ok || error("global root setup failed:\n$(packet.error)")
    return packet.value
end
"""Write rank-filtered progress diagnostics for the fused bundle."""
bundle_debug_log(debug_lock::ReentrantLock, message::AbstractString) =
    mpi_context_debug_log(BUNDLE_MPI_CONTEXT, debug_lock, message)

"""Resolve live requests and initialize MPI for conventional shift current when requested."""
conventional_sc_mpi_initialize() = mpi_context_initialize!(CONVENTIONAL_SC_MPI_CONTEXT)
"""Release MPI owned by conventional shift current, unless a fused bundle is active."""
conventional_sc_mpi_finalize() = mpi_context_finalize!(CONVENTIONAL_SC_MPI_CONTEXT)
"""Return the world communicator for conventional shift current, or nothing in serial mode."""
conventional_sc_mpi_comm_world() = mpi_context_comm_world(CONVENTIONAL_SC_MPI_CONTEXT)
"""Return the communicator rank for conventional shift current, or zero in serial mode."""
conventional_sc_mpi_comm_rank(comm) = mpi_context_comm_rank(CONVENTIONAL_SC_MPI_CONTEXT, comm)
"""Return the communicator size for conventional shift current, or one in serial mode."""
conventional_sc_mpi_comm_size(comm) = mpi_context_comm_size(CONVENTIONAL_SC_MPI_CONTEXT, comm)
"""Sum values to the selected root for conventional shift current; serial mode returns the input."""
conventional_sc_mpi_reduce_sum(local_value, root, comm) =
    mpi_context_reduce_sum(CONVENTIONAL_SC_MPI_CONTEXT, local_value, root, comm)
"""Write rank-filtered progress diagnostics for conventional shift current."""
conventional_debug_log(debug_lock::ReentrantLock, message::AbstractString) =
    mpi_context_debug_log(CONVENTIONAL_SC_MPI_CONTEXT, debug_lock, message)

"""Resolve live requests and initialize MPI for conventional quantum geometry when requested."""
conventional_geometry_mpi_initialize() = mpi_context_initialize!(CONVENTIONAL_GEOMETRY_MPI_CONTEXT)
"""Release MPI owned by conventional quantum geometry, unless a fused bundle is active."""
conventional_geometry_mpi_finalize() = mpi_context_finalize!(CONVENTIONAL_GEOMETRY_MPI_CONTEXT)
"""Return the world communicator for conventional quantum geometry, or nothing in serial mode."""
conventional_geometry_mpi_comm_world() = mpi_context_comm_world(CONVENTIONAL_GEOMETRY_MPI_CONTEXT)
"""Return the communicator rank for conventional quantum geometry, or zero in serial mode."""
conventional_geometry_mpi_comm_rank(comm) =
    mpi_context_comm_rank(CONVENTIONAL_GEOMETRY_MPI_CONTEXT, comm)
"""Return the communicator size for conventional quantum geometry, or one in serial mode."""
conventional_geometry_mpi_comm_size(comm) =
    mpi_context_comm_size(CONVENTIONAL_GEOMETRY_MPI_CONTEXT, comm)
"""Sum values to the selected root for conventional quantum geometry; serial mode returns the input."""
conventional_geometry_mpi_reduce_sum(local_value, root, comm) =
    mpi_context_reduce_sum(CONVENTIONAL_GEOMETRY_MPI_CONTEXT, local_value, root, comm)
"""Write rank-filtered progress diagnostics for conventional quantum geometry."""
conventional_geometry_debug_log(debug_lock::ReentrantLock, message::AbstractString) =
    mpi_context_debug_log(CONVENTIONAL_GEOMETRY_MPI_CONTEXT, debug_lock, message)

"""Resolve live requests and initialize MPI for injection current when requested."""
injection_current_mpi_initialize() = mpi_context_initialize!(INJECTION_CURRENT_MPI_CONTEXT)
"""Release MPI owned by injection current, unless a fused bundle is active."""
injection_current_mpi_finalize() = mpi_context_finalize!(INJECTION_CURRENT_MPI_CONTEXT)
"""Return the world communicator for injection current, or nothing in serial mode."""
injection_current_mpi_comm_world() = mpi_context_comm_world(INJECTION_CURRENT_MPI_CONTEXT)
"""Return the communicator rank for injection current, or zero in serial mode."""
injection_current_mpi_comm_rank(comm) = mpi_context_comm_rank(INJECTION_CURRENT_MPI_CONTEXT, comm)
"""Return the communicator size for injection current, or one in serial mode."""
injection_current_mpi_comm_size(comm) = mpi_context_comm_size(INJECTION_CURRENT_MPI_CONTEXT, comm)
"""Sum values to the selected root for injection current; serial mode returns the input."""
injection_current_mpi_reduce_sum(local_value, root, comm) =
    mpi_context_reduce_sum(INJECTION_CURRENT_MPI_CONTEXT, local_value, root, comm)
"""Write rank-filtered progress diagnostics for injection current."""
injection_current_debug_log(debug_lock::ReentrantLock, message::AbstractString) =
    mpi_context_debug_log(INJECTION_CURRENT_MPI_CONTEXT, debug_lock, message)

"""Resolve live requests and initialize MPI for projector responses when requested."""
projector_mpi_initialize() = mpi_context_initialize!(PROJECTOR_MPI_CONTEXT)
"""Release MPI owned by projector responses, unless a fused bundle is active."""
projector_mpi_finalize() = mpi_context_finalize!(PROJECTOR_MPI_CONTEXT)
"""Return the world communicator for projector responses, or nothing in serial mode."""
projector_mpi_comm_world() = mpi_context_comm_world(PROJECTOR_MPI_CONTEXT)
"""Return the communicator rank for projector responses, or zero in serial mode."""
projector_mpi_comm_rank(comm) = mpi_context_comm_rank(PROJECTOR_MPI_CONTEXT, comm)
"""Return the communicator size for projector responses, or one in serial mode."""
projector_mpi_comm_size(comm) = mpi_context_comm_size(PROJECTOR_MPI_CONTEXT, comm)
"""Sum values to the selected root for projector responses; serial mode returns the input."""
projector_mpi_reduce_sum(local_value, root, comm) =
    mpi_context_reduce_sum(PROJECTOR_MPI_CONTEXT, local_value, root, comm)
"""Write rank-filtered progress diagnostics for projector responses."""
projector_debug_log(debug_lock::ReentrantLock, message::AbstractString) =
    mpi_context_debug_log(PROJECTOR_MPI_CONTEXT, debug_lock, message)

"""Resolve live requests and initialize MPI for geometric-loop responses when requested."""
geometric_loop_mpi_initialize() = mpi_context_initialize!(GEOMETRIC_LOOP_MPI_CONTEXT)
"""Release MPI owned by geometric-loop responses, unless a fused bundle is active."""
geometric_loop_mpi_finalize() = mpi_context_finalize!(GEOMETRIC_LOOP_MPI_CONTEXT)
"""Return the world communicator for geometric-loop responses, or nothing in serial mode."""
geometric_loop_mpi_comm_world() = mpi_context_comm_world(GEOMETRIC_LOOP_MPI_CONTEXT)
"""Return the communicator rank for geometric-loop responses, or zero in serial mode."""
geometric_loop_mpi_comm_rank(comm) = mpi_context_comm_rank(GEOMETRIC_LOOP_MPI_CONTEXT, comm)
"""Return the communicator size for geometric-loop responses, or one in serial mode."""
geometric_loop_mpi_comm_size(comm) = mpi_context_comm_size(GEOMETRIC_LOOP_MPI_CONTEXT, comm)
"""Sum values to the selected root for geometric-loop responses; serial mode returns the input."""
geometric_loop_mpi_reduce_sum(local_value, root, comm) =
    mpi_context_reduce_sum(GEOMETRIC_LOOP_MPI_CONTEXT, local_value, root, comm)
"""Write rank-filtered progress diagnostics for geometric-loop responses."""
geometric_loop_debug_log(debug_lock::ReentrantLock, message::AbstractString) =
    mpi_context_debug_log(GEOMETRIC_LOOP_MPI_CONTEXT, debug_lock, message)

"""Reserve MPI lifecycle ownership for one fused run until bundle cleanup completes."""
function mpi_bundle_start!()
    MPI_BUNDLE_ACTIVE[] = true
    return nothing
end

"""Release active runtime storage and finalize owned MPI unless benchmark deferral is explicit."""
function mpi_bundle_finish!()
    isdefined(@__MODULE__, :cleanup_active_runtime_storage!) && cleanup_active_runtime_storage!()
    MPI_BUNDLE_ACTIVE[] = false
    mpi_env_truthy("WANNIERNLQG_BENCHMARK_DEFER_MPI_FINALIZE") && return nothing
    return mpi_benchmark_finalize!()
end

"""
Finalize all runtime MPI contexts after a benchmark session.

The public `run` lifecycle finalizes MPI after one bundle.  Benchmark drivers may
set `WANNIERNLQG_BENCHMARK_DEFER_MPI_FINALIZE=1` to execute repeated warmed
measurements inside one launcher; they must call this function exactly once at
the end.  Normal production behavior is unchanged.
"""
function mpi_benchmark_finalize!()
    MPI_BUNDLE_ACTIVE[] = false
    for context in (
        BUNDLE_MPI_CONTEXT,
        CONVENTIONAL_SC_MPI_CONTEXT,
        CONVENTIONAL_GEOMETRY_MPI_CONTEXT,
        INJECTION_CURRENT_MPI_CONTEXT,
        PROJECTOR_MPI_CONTEXT,
        GEOMETRIC_LOOP_MPI_CONTEXT,
    )
        mpi_context_force_finalize!(context)
    end
    return nothing
end
