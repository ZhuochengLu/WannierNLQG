using PrecompileTools: @setup_workload, @compile_workload, workload_enabled
import MPI, LinearAlgebra, Serialization

const FIRST_USE_WORKLOAD_ENABLED = workload_enabled(@__MODULE__)

# Real calculations describe the ordinary call trees. The independent path
# registry and cold qualification remain broader than this implementation.
include("FirstUse/TinyVASPNativeInputs.jl")
include("FirstUse/RepresentativePublicWorkloads.jl")
include("FirstUse/RepresentativeStaticHallAndMultipoleWorkloads.jl")
include("FirstUse/RepresentativeNativeWorkloads.jl")
include("FirstUse/RepresentativeExecutionWorkloads.jl")
include("FirstUse/RepresentativeSetupSerializationWorkload.jl")
include("FirstUse/RepresentativeSymmetryProjectionWorkload.jl")
include("ProjectionConfigurationFirstUseWorkload.jl")

# Checkpoint facade declaration ablation: the real owner reader workload is
# independently qualified through this same canonical public facade.

# Actual clean-cache PAW traces retain the stable public facade after the sibling
# workload. Keep only this public boundary residual, not its internal signatures.
precompile(
    Wannierization.audit_paw_block_partitions,
    (Wannierization.PAWBlockPartitionAuditConfig,),
)
