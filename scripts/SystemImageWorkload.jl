# Compile one small normal public entry, without a material scan or MPI launcher.
using WannierNLQG, MPI, TOML
source = ENV["WN_IMAGE_SOURCE"]
@assert realpath(Base.pkgdir(WannierNLQG)) == realpath(source)
include(joinpath(source, "examples", "tasks", "integral", "shift_current_conventional.jl"))
mktempdir() do directory
    config = build_config(; k_mesh = (2, 2), output_root = directory, progress_enabled = false)
    result = WannierNLQG.run(config)
    @assert !isempty(result.outputs) && all(isfile, result.outputs)
end
@assert !MPI.Initialized()
open(
    io -> TOML.print(
        io,
        Dict(
            "entry"=>"WannierNLQG.run",
            "case"=>"synthetic SC 2x2",
            "mpi_initialized"=>false,
            "material_calculation"=>false,
        ),
    ),
    joinpath(ENV["WN_IMAGE_ARTIFACT_DIRECTORY"], "workload.toml"),
    "w",
)
