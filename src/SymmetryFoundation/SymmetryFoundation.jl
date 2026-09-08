module SymmetryFoundation

using LinearAlgebra
using SHA
using ..Core

include("SymmetryDetectionContracts.jl")
include("SymmetryModels.jl")
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
include("SymmetryFoundationIntegrationContracts.jl")

export CrystalStructure, SymmetryOperation, MagneticSymmetryInventory, WannierSymmetryPlan
export BandRepresentation, VASPBandRepresentationConfig
export RepresentationRawDiagnostic, BandRepresentationQualificationScope
export AbstractWavefunctionSource, VASPWavefunctionSource, QuantumEspressoWavefunctionSource
export PlaneWaveKPoint, NativeWavefunctionData
export RealSpaceSymmetrizationResult, RealSpaceProjectionContext
export detect_symmetry_operations, detect_magnetic_symmetry_inventory
export read_band_representation_hdf5, write_band_representation_hdf5
export generate_vasp_band_representation
export symmetrize_real_space_operator, maximum_real_space_covariance_error

end
