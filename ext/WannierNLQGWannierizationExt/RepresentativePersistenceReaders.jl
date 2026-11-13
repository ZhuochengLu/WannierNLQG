using PrecompileTools: @setup_workload, @compile_workload
import WannierNLQG, MPI
include("PrecompileSupport/TinyWannierWorkflowInputs.jl")

# Resolve the registered public names through this four-trigger owner's
# authoritative entrypoint table; no internal component name is needed.
# Their canonical facade and lazy activation are independently cold-qualified.
const _CURRENT_CHECKPOINT_WORKLOAD = normpath(
    joinpath(
        @__DIR__,
        "..",
        "..",
        "test",
        "fixtures",
        "nohash_checkpoint_workload",
        "synthetic.wannierization.h5",
    ),
)

# Preserve legacy search rejection and adopt the actual current checkpoint with
# a private receipt. Current search read/write coverage uses the real search
# result in RepresentativeCheckpointTBWorkload, never invented legacy definitions.
@setup_workload let
    assets =
        normpath(joinpath(@__DIR__, "..", "..", "test", "fixtures", "first_use_portable", "assets"))
    projection = joinpath(assets, "additional_4", "frozen_reader_input.h5")
    checkpoint = _CURRENT_CHECKPOINT_WORKLOAD
    read_projection = resolve_wannierization_entrypoint(:read_projection_representation_search_hdf5)
    workspace = mktempdir()
    try
        @compile_workload begin
            WannierNLQG._first_use_require_serial()
            legacy_rejected = try
                read_projection(projection)
                false
            catch error
                error isa ArgumentError && occursin(
                    "unsupported projection search schema version:",
                    sprint(showerror, error),
                ) || rethrow()
                true
            end
            @assert legacy_rejected
            @assert read_current_checkpoint_asset(checkpoint, workspace) !== nothing
            @assert !MPI.Initialized()
            @assert WannierNLQG.Runtime.ACTIVE_PROGRESS[] === nothing
        end
    finally
        rm(workspace; recursive = true)
    end
end
