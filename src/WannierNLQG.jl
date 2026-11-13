module WannierNLQG

# Captured compiler signatures and anonymous bindings belong to the 1.1.1 trace.
# The merged 1.2.0 semantic/API layout requires a fresh capture before activation.
# Other supported Julia versions retain portable bounded workloads and normal JIT.
const FIRST_USE_TRACE_COMPATIBLE = VERSION == v"1.11.2" && Base.pkgversion(@__MODULE__) == v"1.1.1"
const FIRST_USE_WORKLOAD_ARCHITECTURE = :public_representative

include(joinpath(@__DIR__, "Core", "Core.jl"))
include(joinpath(@__DIR__, "IO", "IO.jl"))
include(joinpath(@__DIR__, "SymmetryFoundation", "SymmetryFoundation.jl"))
include(joinpath(@__DIR__, "WannierProjection", "WannierProjection.jl"))
include(joinpath(@__DIR__, "MatrixElements", "MatrixElementsModule.jl"))
include(joinpath(@__DIR__, "Symmetrization", "Symmetrization.jl"))
include(joinpath(@__DIR__, "Wannierization", "Wannierization.jl"))
include(joinpath(@__DIR__, "Responses", "Responses.jl"))
include(joinpath(@__DIR__, "Runtime", "Runtime.jl"))

using .IO: read_linear_transport_result, read_orbital_magnetization_result

using .Runtime:
    TaskInputResolution,
    read_task_input,
    resolve_task_input,
    explain_task_input,
    write_task_input_template,
    write_task_input_resolution,
    run_task_input,
    TaskConfig,
    TaskSpec,
    Numerics,
    JerkParameters,
    THGParameters,
    TensorComponents,
    RunResult,
    ResponseQualificationResult,
    run,
    ModelInput,
    RealSpaceTBInput,
    AnalyticKInput,
    PointOrbitalSymmetryOperation,
    write_native_response_symmetry,
    BZMesh,
    KRegion,
    KSlice,
    KPath,
    automatic_kpath,
    UniformIntegration,
    HAdaptiveCubature,
    IntegrationDomain,
    IntegrationDomain2D,
    integrate_response,
    ExecutionOptions,
    OutputOptions,
    OpticalParameters,
    SeparateRelaxation,
    IntrinsicHallParameters,
    BerryMultipoleParameters,
    LinearTransportParameters,
    LinearOpticalResponseParameters,
    OrbitalMagnetizationParameters,
    SHGParameters,
    FiniteQOpticalParameters,
    GeometryParameters,
    BandParameters,
    BandTargets,
    Subspace,
    Subspaces,
    OccupiedBands,
    AllBands,
    Transition,
    InterbandGroups,
    TripleGroups,
    TensorComponent,
    FullTensor,
    KSliceSelection

export TaskConfig,
    TaskInputResolution,
    read_task_input,
    resolve_task_input,
    explain_task_input,
    write_task_input_template,
    write_task_input_resolution,
    run_task_input,
    TaskSpec,
    Numerics,
    JerkParameters,
    THGParameters,
    TensorComponents,
    RunResult,
    ResponseQualificationResult,
    run,
    ModelInput,
    RealSpaceTBInput,
    AnalyticKInput,
    PointOrbitalSymmetryOperation,
    write_native_response_symmetry,
    BZMesh,
    KRegion,
    KSlice,
    KPath,
    automatic_kpath,
    UniformIntegration,
    HAdaptiveCubature,
    IntegrationDomain,
    IntegrationDomain2D,
    integrate_response,
    ExecutionOptions,
    OutputOptions,
    OpticalParameters,
    SeparateRelaxation,
    IntrinsicHallParameters,
    BerryMultipoleParameters,
    LinearTransportParameters,
    LinearOpticalResponseParameters,
    OrbitalMagnetizationParameters,
    SHGParameters,
    FiniteQOpticalParameters,
    GeometryParameters,
    BandParameters,
    BandTargets,
    Subspace,
    Subspaces,
    OccupiedBands,
    AllBands,
    Transition,
    InterbandGroups,
    TripleGroups,
    TensorComponent,
    FullTensor,
    KSliceSelection
export read_linear_transport_result, read_orbital_magnetization_result

include("FirstUsePrecompileWorkload.jl")

end
