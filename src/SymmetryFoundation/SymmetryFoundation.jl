module SymmetryFoundation

using LinearAlgebra
using SHA
using ..Core
import ..IO

include("SymmetryDetectionContracts.jl")
include("SymmetryModels.jl")
include("DiagonalMeshScreening.jl")
include("MagneticPointGroupCanonicalization.jl")
include("GeneratedMagneticPointGroupCatalog.jl")
include("ResponseSymmetryGroupReporting.jl")
include("ResponseSymmetryGroupGenerators.jl")
include("BandRepresentationModels.jl")
include("BandRepresentationContracts.jl")
include("SpinSymmetryActions.jl")
include("NativeWavefunctionModels.jl")
include("VASPWavefunctions.jl")
include("CanonicalBandRepresentationBuilder.jl")
include("RealSpaceSymmetryProjectors.jl")
include("SymmetryFoundationExtensionLoading.jl")
include("SymmetryFoundationExpertInterfaces.jl")
include("HighSymmetryBandPaths.jl")
include("SymmetryFoundationIntegrationContracts.jl")

export CrystalStructure, SymmetryOperation, MagneticSymmetryInventory, WannierSymmetryPlan
export DiagonalKMesh,
    diagonal_mesh_closure, enumerate_diagonal_mesh_closure, recommend_diagonal_mesh
export classify_diagonal_mesh_points
export BandRepresentation, VASPBandRepresentationConfig
export RepresentationRawDiagnostic, BandRepresentationQualificationScope
export AbstractWavefunctionSource, VASPWavefunctionSource, QuantumEspressoWavefunctionSource
export PlaneWaveKPoint, NativeWavefunctionData
export RealSpaceSymmetrizationResult, RealSpaceProjectionContext
export detect_symmetry_operations, detect_magnetic_symmetry_inventory
export high_symmetry_band_path
export read_band_representation_hdf5, write_band_representation_hdf5
export generate_vasp_band_representation
export symmetrize_real_space_operator, maximum_real_space_covariance_error

# First-use compilation is driven by the public workloads.

end
