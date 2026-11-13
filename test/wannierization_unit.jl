include(joinpath(@__DIR__, "WannierizationPrimitivesContracts.jl"))

include(joinpath(@__DIR__, "WannierizationOrdinaryContracts.jl"))
include(joinpath(@__DIR__, "WannierizationWinMeshSyntaxContracts.jl"))

include(joinpath(@__DIR__, "WannierizationCurrentOptimizerContracts.jl"))

include(joinpath(@__DIR__, "WannierizationStageAcceptanceContracts.jl"))

include(joinpath(@__DIR__, "WannierizationRepresentationContracts.jl"))

include(joinpath(@__DIR__, "WannierizationStatusContracts.jl"))

include(joinpath(@__DIR__, "WannierizationPersistenceContracts.jl"))

include(joinpath(@__DIR__, "WannierizationRecoveryMathContracts.jl"))

# These lifecycle cases were formerly syntax-audited only. Exercise their real
# public solve/save/restart consumers, including optional referenced storage.
module WannierCheckpointLifecycleExecutionTests
using WannierNLQG
include(joinpath(@__DIR__, "WannierStageRestartLifecycleTests.jl"))
end

include(joinpath(@__DIR__, "NativeMatrixInputReuseTests.jl"))
