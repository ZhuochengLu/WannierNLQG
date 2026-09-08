module ProjectionSearch

import HDF5
import JSON3
import LinearAlgebra: Hermitian, I, dot, eigen, norm, opnorm, svd, svdvals, tr
import SHA
import WannierNLQG.SymmetryFoundation:
    BandRepresentation,
    WannierSymmetryPlan,
    qualification_mask_sha256,
    read_band_representation_hdf5
import WannierNLQG.WannierProjection:
    ProjectionRadialTransformConfig,
    ProjectionSpec,
    WannierProjectionBasis,
    build_wannier_projection_basis,
    build_wannier_symmetry_plan
import WannierNLQG.Wannierization:
    PROJECTION_SEARCH_COMPLETE,
    PROJECTION_SEARCH_INVALID_INPUT,
    PROJECTION_SEARCH_LIMIT_REACHED,
    PROJECTION_SEARCH_NO_SOLUTION,
    PROJECTION_SEARCH_NUMERICAL_UNCERTAIN,
    PROJECTION_VALIDATION_FAILED,
    PROJECTION_VALIDATION_NOT_RUN,
    PROJECTION_VALIDATION_NUMERICAL_UNCERTAIN,
    PROJECTION_VALIDATION_PASSED,
    ProjectionCandidateSpec,
    ProjectionRepresentationCompatibilityInfo,
    ProjectionRepresentationEmbeddingCertificate,
    ProjectionRepresentationProblem,
    ProjectionRepresentationSearchConfig,
    ProjectionRepresentationSearchResult,
    ProjectionRepresentationSearchThresholds,
    ProjectionRepresentationSignature,
    ProjectionRepresentationSolution,
    SymmetryAdaptedWannierizationConfig,
    TargetSubspaceQualificationContract
import ..WannierizationInternalSupport:
    atomic_hdf5_write,
    replace_wannierization_config,
    target_representation,
    window_masks_from_energies
import ..RepresentationPreparation: build_representation_product_table, representation_static_sha256

include("../ProjectionRepresentationGroupAlgebra.jl")
include("../ProjectionRepresentationCorepresentations.jl")
include("../ProjectionRepresentationIntertwiners.jl")
include("../ProjectionRepresentationCompatibility.jl")
include("../ProjectionRepresentationSearch.jl")
include("../ProjectionRepresentationSearchHDF5.jl")
include("../ProjectionRepresentationMaterialization.jl")

const PROJECTION_SEARCH_INTEGRATION_API = (
    :materialize_projection_basis,
    :materialize_symmetry_adapted_wannierization_config,
    :read_projection_representation_search_hdf5,
    :search_projection_representations,
    :write_projection_representation_search_hdf5,
)

const PROJECTION_SEARCH_TEST_API = ()

for name in PROJECTION_SEARCH_INTEGRATION_API
    @eval export $name
end

end
