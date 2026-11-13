module WannierProjection

using LinearAlgebra
using ..Core: validate_ordinary_construction_policy
using ..SymmetryFoundation:
    BOHR_TO_ANGSTROM, CrystalStructure, SymmetryOperation, WannierSymmetryPlan, spin_action_matrix

include("ProjectionModels.jl")
include("WannierInputParsingHelpers.jl")
include("WannierWinData.jl")
include("WannierProjectionRepresentations.jl")
include("WannierProjectionIntegrationContracts.jl")

export ProjectionSpec, ProjectionRadialTransformConfig
export WannierProjectionBlock, WannierProjectionBasis
export WannierWinData, read_wannier_win, crystal_structure
export projection_orbital_values, build_wannier_projection_basis, build_wannier_symmetry_plan

# First-use compilation is driven by the public workloads.

end
