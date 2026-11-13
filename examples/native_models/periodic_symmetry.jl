include("periodic_analytic.jl")

"""Build a spinless time-reversal reduction example without running it on import."""
function build_symmetry_config(; smoke = false, output_root = mktempdir())
    model=build_model()
    operations=[
        PointOrbitalSymmetryOperation(
            rotation_fractional = Matrix{Int}(I, 3, 3),
            representation = Matrix{ComplexF64}(I, 2, 2),
        ),
        PointOrbitalSymmetryOperation(
            rotation_fractional = Matrix{Int}(I, 3, 3),
            antiunitary = true,
            representation = Matrix{ComplexF64}(I, 2, 2),
        ),
    ]
    mkpath(output_root)
    artifact=write_native_response_symmetry(
        joinpath(output_root, "point_symmetry.json"),
        model,
        operations,
    )
    template=shift_config(model, BZMesh(k_mesh = smoke ? (3, 3) : (31, 31)), output_root)
    return TaskConfig(
        model = model,
        sampling = template.sampling,
        tasks = template.tasks,
        execution = ExecutionOptions(
            fourier_backend = "direct",
            response_symmetry_file = artifact,
            response_symmetry_kmesh_mode = "reduced",
            response_symmetry_report_enabled = true,
        ),
        output = template.output,
    )
end

if abspath(PROGRAM_FILE)==@__FILE__
    result=WannierNLQG.run(build_symmetry_config(smoke = "--smoke" in ARGS))
    println(result.run_dir)
end
