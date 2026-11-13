module Wannierization

using LinearAlgebra
using MPI
using Random
using SHA
using ..Core
import ..IO
import ..IO: resolve_operator_selection, resolved_source_inventory
using ..IO:
    WannierAMN,
    WannierCHK,
    WannierEIG,
    WannierMMN,
    WannierNNKP,
    WannierSPN,
    read_wannier_nnkp,
    owned_wannier_topology,
    ScientificInputDefinition
import ..SymmetryFoundation
import ..WannierProjection

const WANNIERIZATION_JSON3_PKG_ID =
    Base.PkgId(Base.UUID("0f8b85d8-7281-11e9-16c2-39a750bddbf1"), "JSON3")

include("models/ConfigurationsContracts.jl")
include("WannierizationStageControls.jl")
include("models/OptimizerStates.jl")
include("models/WannierizationEligibility.jl")
include("models/DiagnosticsQualification.jl")
include("models/ResultsArtifacts.jl")
include("NativeOperatorOutputPlanning.jl")
include("ProjectionRepresentationSearchModels.jl")
include("WannierizationExtensionLoading.jl")
include("WannierizationExpertInterfaces.jl")

export WannierizationConfig
export WannierizationResult
export construct_wannier_functions

end
