module WannierNLQGWannierizationPrecompileExt

import WannierNLQG
import MPI
import HDF5
import JSON3
import EzXML
import Dates
import LinearAlgebra
import Printf
import Serialization
using PrecompileTools: @compile_workload

# No solver execution: the owned bridge anchors compiler work after all optional
# backends are loaded. It stores no handles, communicators, or scientific state.
_first_solve_compile_call(f::F, args::Vararg{Any, N}) where {F, N} = Base.@noinline f(args...)
# Cross-extension compiler anchors and captured signatures belong to this trace version.
if WannierNLQG.FIRST_USE_TRACE_COMPATIBLE
    const WannierNLQGWannierizationExt =
        Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
    const WannierNLQGOperatorBundleExt =
        Base.get_extension(WannierNLQG, :WannierNLQGOperatorBundleExt)
    const WannierNLQGSymmetrizationExt =
        Base.get_extension(WannierNLQG, :WannierNLQGSymmetrizationExt)
    # Establish the final backend method world through its owner only while building
    # the cache. No solver, output writer, or MPI initialization is executed here.
    if ccall(:jl_generating_output, Cint, ()) == 1 && WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        WannierNLQG.SymmetryFoundation.symmetry_detection_backend_provenance()
    end
    const WannierNLQGSymmetryFoundationExt =
        Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)
    const StructTypes = JSON3.StructTypes

    const PRECOMPILE_CONTEXT = Dict{String, Any}()
    const PRECOMPILE_RESULTS = Bool[]
    # Retain compiler success flags for observed first-use signatures.
    function _record_precompile(signature)
        ok = precompile(signature)
        push!(PRECOMPILE_RESULTS, ok)
        return ok
    end

    include("Generated/SolverBridgeSignatures.jl")
    include("Generated/DirectEntrySignatures.jl")
    include("Generated/PostBackendSignatures.jl")
    include("ColdSolverFirstUseCoverage.jl")

    include("SymmetryNativeFirstUseCoverage.jl")

    include("LocalizationFirstUseCoverage.jl")

    include("OrdinaryLateWorldCoverage.jl")

    include("RestartFirstUseCoverage.jl")

    include("RestartReadFirstUseWorkload.jl")

    include("FixedSubspaceFirstUseCoverage.jl")

    include("FinalizerEntryInitialization.jl")

    include("StarGaugeFirstUseCoverage.jl")

    include("StarGaugeMetadataFirstUseWorkload.jl")
    include("StarGaugeSerializationFirstUseCoverage.jl")
    include("StarGaugeResidualMetadataWorkload.jl")
    include("StarGaugePrintfFirstUseWorkload.jl")
    include("StarGaugeMultiStandardCoverage.jl")

    include("Generated/PAWAuditSignatures.jl")
    include("Generated/GaugeChainSignatures.jl")

    include("MultiStarExternalFirstUseCoverage.jl")

    # Measured post-backend residuals for three public expert calls.
    include("Generated/ExpertResidualSignatures.jl")
end

end
