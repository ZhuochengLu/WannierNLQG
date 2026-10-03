module WannierNLQG

# Captured compiler signatures and anonymous bindings belong to this trace version.
# Other supported Julia versions retain portable bounded workloads and normal JIT.
const FIRST_USE_TRACE_COMPATIBLE = VERSION == v"1.11.2"

include(joinpath(@__DIR__, "Core", "Core.jl"))
include(joinpath(@__DIR__, "SymmetryFoundation", "SymmetryFoundation.jl"))
include(joinpath(@__DIR__, "WannierProjection", "WannierProjection.jl"))
include(joinpath(@__DIR__, "IO", "IO.jl"))
include(joinpath(@__DIR__, "MatrixElements", "MatrixElementsModule.jl"))
include(joinpath(@__DIR__, "Symmetrization", "Symmetrization.jl"))
include(joinpath(@__DIR__, "Wannierization", "Wannierization.jl"))
include(joinpath(@__DIR__, "Responses", "Responses.jl"))
include(joinpath(@__DIR__, "Runtime", "Runtime.jl"))

using .IO: read_linear_transport_result, read_orbital_magnetization_result

using .Runtime:
    TaskConfig,
    TaskSpec,
    RunResult,
    ResponseQualificationResult,
    run,
    ModelInput,
    BZMesh,
    KSlice,
    KPath,
    ExecutionOptions,
    OutputOptions,
    OpticalParameters,
    SeparateRelaxation,
    FermiSurfaceBroadening,
    LinearTransportParameters,
    LinearOpticalResponseParameters,
    OrbitalMagnetizationParameters,
    LinearResponseNumerics,
    OrbitalNumerics,
    SHGParameters,
    SHGNumerics,
    FiniteQOpticalParameters,
    GeometryParameters,
    BandParameters,
    OpticalNumerics,
    GeometryNumerics,
    BandNumerics,
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
    TaskSpec,
    RunResult,
    ResponseQualificationResult,
    run,
    ModelInput,
    BZMesh,
    KSlice,
    KPath,
    ExecutionOptions,
    OutputOptions,
    OpticalParameters,
    SeparateRelaxation,
    FermiSurfaceBroadening,
    LinearTransportParameters,
    LinearOpticalResponseParameters,
    OrbitalMagnetizationParameters,
    LinearResponseNumerics,
    OrbitalNumerics,
    SHGParameters,
    SHGNumerics,
    FiniteQOpticalParameters,
    GeometryParameters,
    BandParameters,
    OpticalNumerics,
    GeometryNumerics,
    BandNumerics,
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
