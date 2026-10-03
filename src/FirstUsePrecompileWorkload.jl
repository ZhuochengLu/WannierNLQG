using PrecompileTools: @setup_workload, @compile_workload, workload_enabled
using MPI
using Printf
import Serialization, Dates, FFTW, LinearAlgebra

const FIRST_USE_WORKLOAD_ENABLED = workload_enabled(@__MODULE__)
include("FirstUseWorkspaceTypes.jl")
include("FirstUseThreadTypes.jl")

# Compile bounded, in-memory matrix assembly without executing Runtime.run or MPI.
@setup_workload let
    fixture =
        joinpath(@__DIR__, "..", "examples", "fixtures", "synthetic_runtime", "synthetic_tb.dat")
    @compile_workload begin
        model = IO.read_wannier_tb(fixture)
        for dimension in (2, 3)
            request = MatrixElements.MatrixElementRequest(
                MatrixElements.VELOCITY_VERTICES,
                MatrixElements.INTERNAL_CONNECTION_DERIVATIVES,
                MatrixElements.HAMILTONIAN_SECOND_DERIVATIVES;
                spatial_dimension = dimension,
            )
            plan = MatrixElements.compile_matrix_plan(request)
            workspace = MatrixElements.MatrixElementWorkspace(model, plan)
            MatrixElements.prepare_real_space!(workspace, model)
            MatrixElements.compute_kpoint!(workspace, model, [0.13, 0.21, 0.07])
        end
        # Cover the public normalization calls observed missing from the first trace.
        for method in ("Conventional", "Projector", "Geometric_Loop", "Wilson_Loop")
            config = Runtime.TaskConfig(
                model = Runtime.ModelInput(model_file = fixture),
                sampling = Runtime.BZMesh(k_mesh = (2, 2), spatial_dimension = 2),
                tasks = [
                    Runtime.TaskSpec(
                        id = "precompile_shift",
                        quantity = "SC",
                        method = method,
                        physics = Runtime.OpticalParameters(
                            photon_energies = [0.5],
                            fermi_energy = 0.0,
                            temperature = 0.0,
                        ),
                        observable = Runtime.FullTensor(),
                    ),
                ],
                execution = Runtime.ExecutionOptions(fourier_backend = "direct"),
            )
            for effective in Runtime.compile_task_configs(config)
                Runtime.validate_config(effective)
            end
        end
        # Compile public orchestration signatures; do not execute their I/O or MPI lifecycle.
        precompile(Runtime.run, (Runtime.TaskConfig,))
        false
        false
        # Compile strict public result readers without opening any result directory.
        false
        false
        precompile(Wannierization.read_wannierization_checkpoint_hdf5, (String,))
    end
end

# Frozen compiler declarations are evaluated only on their originating Julia version.
if FIRST_USE_TRACE_COMPATIBLE
    include("FirstUse/Generated/RegistrySignatures.jl")
    include("FirstUse/Generated/NativeBackedges.jl")
    include("FirstUse/Generated/CoreEntryCoverage.jl")
    include("FirstUseMPICoverage.jl")

    include("FirstUseCallBoundaryCoverage.jl")

    include("FirstUse/Generated/ColdSolverNativeGaps.jl")
    include("FirstUse/Generated/ColdSolverStdlib.jl")
end

include("ProjectionConfigurationFirstUseWorkload.jl")

if FIRST_USE_TRACE_COMPATIBLE
    include("MultiStarCoreFirstUseCoverage.jl")

    include("FirstUse/Generated/KPathMeasuredResidual.jl")

    include("FirstUse/Generated/ValidZeemanMeasuredResidual.jl")
end
