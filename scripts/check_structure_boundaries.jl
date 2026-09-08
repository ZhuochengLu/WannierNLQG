#!/usr/bin/env julia

using TOML

include(joinpath(@__DIR__, "ArchitectureContracts.jl"))
using .ArchitectureContracts

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SRC = joinpath(ROOT, "src")
const EXT = joinpath(ROOT, "ext")

fail(message::AbstractString) = error("structure check failed: " * message)

function source_files(directory::AbstractString)
    files = String[]
    for (root, _, names) in walkdir(directory)
        for name in names
            endswith(name, ".jl") && push!(files, joinpath(root, name))
        end
    end
    return sort(files)
end

function active_code_files(directory::AbstractString)
    files = String[]
    for (root, _, names) in walkdir(directory)
        for name in names
            any(extension -> endswith(name, extension), (".jl", ".py")) &&
                push!(files, joinpath(root, name))
        end
    end
    return sort(files)
end

function assert_absent(path::AbstractString, pattern)
    text = read(path, String)
    occursin(pattern, text) && fail("$(relpath(path, ROOT)) contains forbidden pattern $(pattern)")
end

function assert_complete_composition(
    implementation_root::AbstractString,
    composition_file::AbstractString,
)
    included = Set{String}()
    active = Set{String}()
    function visit(path::AbstractString)
        normalized_path = normpath(path)
        normalized_path in active &&
            fail("recursive include cycle reaches $(relpath(normalized_path, ROOT))")
        push!(active, normalized_path)
        composition = read(normalized_path, String)
        for matched in eachmatch(r"include\(\"([^\"]+)\"\)", composition)
            target = normpath(joinpath(dirname(normalized_path), matched.captures[1]))
            relative_target = replace(relpath(target, implementation_root), '\\' => '/')
            startswith(relative_target, "../") && fail(
                "$(relpath(normalized_path, ROOT)) includes outside its implementation root: " *
                "$(matched.captures[1])",
            )
            isfile(target) ||
                fail("$(relpath(normalized_path, ROOT)) includes missing file $(relative_target)")
            relative_target in included &&
                fail("$(relpath(composition_file, ROOT)) reaches $(relative_target) more than once")
            push!(included, relative_target)
            visit(target)
        end
        delete!(active, normalized_path)
        return nothing
    end
    visit(composition_file)
    implemented = Set(
        replace(relpath(path, implementation_root), '\\' => '/') for
        path in source_files(implementation_root) if path != composition_file
    )
    included == implemented || fail(
        "$(relpath(composition_file, ROOT)) include set differs from implementations: " *
        "missing=$(sort!(collect(setdiff(implemented, included)))) " *
        "extra=$(sort!(collect(setdiff(included, implemented))))",
    )
end

function assert_include_only_composition(path::AbstractString)
    source = read(path, String)
    declaration =
        r"(?m)^\s*(?:function|struct|mutable\s+struct|abstract\s+type|@enum|const|using|import|export)\b"
    occursin(declaration, source) &&
        fail("$(relpath(path, ROOT)) must remain an include-only component root")
end

required_files = [
    "docs/ARCHITECTURE_IMPLEMENTATION_INVENTORY.md",
    "src/Core/Core.jl",
    "src/Core/Constants.jl",
    "src/Core/Models.jl",
    "src/Core/RealSpaceOperators.jl",
    "src/Core/Coordinates.jl",
    "src/Core/CalculationUtils.jl",
    "src/IO/IO.jl",
    "src/IO/WannierTB.jl",
    "src/IO/WannierTBWriter.jl",
    "src/IO/WannierHR.jl",
    "src/IO/SpinReaders.jl",
    "src/IO/SpinVelocityReaders.jl",
    "src/IO/RealSpaceOperatorBundles.jl",
    "src/IO/ResultWriters.jl",
    "src/IO/BandStructureWriters.jl",
    "src/MatrixElements/MatrixElementsModule.jl",
    "src/MatrixElements/Interpolated/MatrixElementPlan.jl",
    "src/MatrixElements/Interpolated/MatrixElementWorkspace.jl",
    "src/MatrixElements/Interpolated/MixedFourierMatrixElements.jl",
    "src/MatrixElements/Interpolated/HamiltonianMatrixElements.jl",
    "src/MatrixElements/Interpolated/PositionMatrixElements.jl",
    "src/MatrixElements/Interpolated/SpinMatrixElements.jl",
    "src/MatrixElements/Interpolated/SpinVelocityMatrixElements.jl",
    "src/MatrixElements/Interpolated/WannierPairWignerSeitzTransforms.jl",
    "src/MatrixElements/Interpolated/WannierDerivativeOperators.jl",
    "src/MatrixElements/ModelTransforms.jl",
    "src/MatrixElements/ProjectorMatrixElements.jl",
    "src/MatrixElements/GeometricLoopMatrixElements.jl",
    "src/MatrixElements/Interfaces.jl",
    "src/SymmetryFoundation/SymmetryFoundation.jl",
    "src/SymmetryFoundation/SymmetryDetectionContracts.jl",
    "src/SymmetryFoundation/SymmetryModels.jl",
    "src/SymmetryFoundation/BandRepresentationModels.jl",
    "src/SymmetryFoundation/BandRepresentationContracts.jl",
    "src/SymmetryFoundation/SpinSymmetryActions.jl",
    "src/SymmetryFoundation/NativeWavefunctionModels.jl",
    "src/SymmetryFoundation/VASPWavefunctions.jl",
    "src/SymmetryFoundation/CanonicalBandRepresentationBuilder.jl",
    "src/SymmetryFoundation/RealSpaceSymmetryProjectors.jl",
    "src/SymmetryFoundation/SymmetryFoundationExtensionLoading.jl",
    "src/SymmetryFoundation/SymmetryFoundationExpertInterfaces.jl",
    "src/SymmetryFoundation/SymmetryFoundationIntegrationContracts.jl",
    "src/WannierProjection/WannierProjection.jl",
    "src/WannierProjection/ProjectionModels.jl",
    "src/WannierProjection/WannierInputParsingHelpers.jl",
    "src/WannierProjection/WannierWinData.jl",
    "src/WannierProjection/WannierProjectionRepresentations.jl",
    "src/WannierProjection/WannierProjectionIntegrationContracts.jl",
    "src/Symmetrization/Symmetrization.jl",
    "src/Symmetrization/GaugeAwareSymmetrizationModels.jl",
    "src/Symmetrization/SymmetrizationConfigs.jl",
    "src/Symmetrization/SymmetrizationExtensionLoading.jl",
    "src/Symmetrization/SymmetrizationExpertInterfaces.jl",
    "src/Wannierization/Wannierization.jl",
    "src/Wannierization/models/ConfigurationsContracts.jl",
    "src/Wannierization/models/OptimizerStates.jl",
    "src/Wannierization/models/DiagnosticsQualification.jl",
    "src/Wannierization/models/ResultsArtifacts.jl",
    "src/Wannierization/WannierizationExtensionLoading.jl",
    "src/Wannierization/WannierizationExpertInterfaces.jl",
    "ext/WannierNLQGSymmetrizationExt/WannierNLQGSymmetrizationExt.jl",
    "ext/WannierNLQGSymmetrizationExt/MagneticMomentReaders.jl",
    "ext/WannierNLQGOperatorBundleExt/WannierNLQGOperatorBundleExt.jl",
    "ext/WannierNLQGSymmetrizationExt/WannierMeshScreening.jl",
    "ext/WannierNLQGSymmetrizationExt/components/ValidationComponent.jl",
    "ext/WannierNLQGSymmetrizationExt/components/SewingComponent.jl",
    "ext/WannierNLQGSymmetrizationExt/components/ProjectionComponent.jl",
    "ext/WannierNLQGSymmetrizationExt/components/PersistenceComponent.jl",
    "ext/WannierNLQGSymmetrizationExt/components/WorkflowComponent.jl",
    "ext/WannierNLQGSymmetrizationExt/components/validation/OperatorWorkflowValidation.jl",
    "ext/WannierNLQGSymmetrizationExt/components/validation/GaugeAwareValidation.jl",
    "ext/WannierNLQGSymmetrizationExt/components/sewing/GaugeAwareSewing.jl",
    "ext/WannierNLQGSymmetrizationExt/components/projection/OperatorProjection.jl",
    "ext/WannierNLQGSymmetrizationExt/components/projection/GaugeAwareProjection.jl",
    "ext/WannierNLQGSymmetrizationExt/components/persistence/OperatorPersistence.jl",
    "ext/WannierNLQGSymmetrizationExt/components/persistence/GaugeAwarePersistence.jl",
    "ext/WannierNLQGSymmetrizationExt/components/workflow/OperatorWorkflow.jl",
    "ext/WannierNLQGSymmetrizationExt/components/workflow/GaugeAwareWorkflow.jl",
    "ext/WannierNLQGSymmetryFoundationExt/WannierNLQGSymmetryFoundationExt.jl",
    "ext/WannierNLQGSymmetryFoundationExt/SymmetryOperationDetection.jl",
    "ext/WannierNLQGSymmetryFoundationExt/TBSymmetryDetectionCompatibility.jl",
    "ext/WannierNLQGSymmetryFoundationExt/VASPBandRepresentationBuilder.jl",
    "ext/WannierNLQGSymmetryFoundationExt/BandRepresentationPersistence.jl",
    "ext/WannierNLQGWannierizationExt/WannierNLQGWannierizationExt.jl",
    "ext/WannierNLQGWannierizationExt/components/WannierizationInternalSupport.jl",
    "ext/WannierNLQGWannierizationExt/components/RepresentationPreparation.jl",
    "ext/WannierNLQGWannierizationExt/components/ProjectionSearch.jl",
    "ext/WannierNLQGWannierizationExt/components/PAWMatrixElements.jl",
    "ext/WannierNLQGWannierizationExt/components/SolverCheckpoint.jl",
    "ext/WannierNLQGWannierizationExt/components/OperatorExport.jl",
    "ext/WannierNLQGWannierizationExt/components/WorkflowOrchestration.jl",
    "ext/WannierNLQGWannierizationExt/support/HDF5Operations.jl",
    "ext/WannierNLQGWannierizationExt/support/SupportLinearAlgebra.jl",
    "ext/WannierNLQGWannierizationExt/support/RepresentationHelpers.jl",
    "ext/WannierNLQGWannierizationExt/support/BackendPorts.jl",
    "ext/WannierNLQGWannierizationExt/support/ResultHelpers.jl",
    "ext/WannierNLQGWannierizationExt/support/GaugeFrameProvenance.jl",
    "ext/WannierNLQGWannierizationExt/QuantumEspressoWavefunctions.jl",
    "ext/WannierNLQGWannierizationExt/BandRepresentationBuilder.jl",
    "ext/WannierNLQGWannierizationExt/RepresentationDiagnostics.jl",
    "ext/WannierNLQGWannierizationExt/RepresentationGroupLaw.jl",
    "ext/WannierNLQGWannierizationExt/SewingMatrixAlignment.jl",
    "ext/WannierNLQGWannierizationExt/AntiunitaryCompatibility.jl",
    "ext/WannierNLQGWannierizationExt/WannierGaugeDiagnostics.jl",
    "ext/WannierNLQGWannierizationExt/NativeSourceDispatch.jl",
    "ext/WannierNLQGWannierizationExt/SMVFletcherReevesAudit.jl",
    "ext/WannierNLQGWannierizationExt/solver/LinearAlgebra.jl",
    "ext/WannierNLQGWannierizationExt/solver/SymmetryFrames.jl",
    "ext/WannierNLQGWannierizationExt/solver/Initialization.jl",
    "ext/WannierNLQGWannierizationExt/solver/Localization.jl",
    "ext/WannierNLQGWannierizationExt/solver/Optimizer.jl",
    "ext/WannierNLQGWannierizationExt/solver/RestartContract.jl",
    "ext/WannierNLQGWannierizationExt/solver/RestartWorkflow.jl",
    "ext/WannierNLQGWannierizationExt/solver/SolverPreparation.jl",
    "ext/WannierNLQGWannierizationExt/solver/SolverInitialization.jl",
    "ext/WannierNLQGWannierizationExt/solver/SolverProposal.jl",
    "ext/WannierNLQGWannierizationExt/solver/SolverAcceptance.jl",
    "ext/WannierNLQGWannierizationExt/solver/SolverTermination.jl",
    "ext/WannierNLQGWannierizationExt/solver/SolverIteration.jl",
    "ext/WannierNLQGWannierizationExt/WannierizationConfigValidation.jl",
    "ext/WannierNLQGWannierizationExt/hdf5/FixedSubspace.jl",
    "ext/WannierNLQGWannierizationExt/hdf5/CheckpointDigests.jl",
    "ext/WannierNLQGWannierizationExt/hdf5/Writer.jl",
    "ext/WannierNLQGWannierizationExt/hdf5/LegacyMigration.jl",
    "ext/WannierNLQGWannierizationExt/hdf5/Reader.jl",
    "ext/WannierNLQGWannierizationExt/star_gauge/FrameContract.jl",
    "ext/WannierNLQGWannierizationExt/star_gauge/StarTransport.jl",
    "ext/WannierNLQGWannierizationExt/star_gauge/PartitionReynolds.jl",
    "ext/WannierNLQGWannierizationExt/star_gauge/Persistence.jl",
    "ext/WannierNLQGWannierizationExt/star_gauge/ConstructionWorkflow.jl",
    "ext/WannierNLQGWannierizationExt/TightBindingConstruction.jl",
    "ext/WannierNLQGWannierizationExt/WannierizationWorkflow.jl",
    "test/contracts/wannierization_components.toml",
    "scripts/ArchitectureContracts.jl",
    "src/Responses/Responses.jl",
    "src/Responses/Shared/ResponseFrequencyContraction.jl",
    "src/Responses/Shared/ResponseWorkspaces.jl",
    "src/Responses/Shared/ResponseKernelHelpers.jl",
    "src/Responses/Shared/LoopCurrentSharedKernels.jl",
    "src/Responses/Shared/WilsonLoopResponseKernels.jl",
    "src/Responses/ShiftCurrent/ConventionalShiftCurrent.jl",
    "src/Responses/ShiftCurrent/ProjectorShiftCurrent.jl",
    "src/Responses/ShiftCurrent/GeometricLoopShiftCurrent.jl",
    "src/Responses/ShiftCurrent/WilsonLoopShiftCurrent.jl",
    "src/Responses/PhotonDragShiftCurrent/GeometricLoopPhotonDragShiftCurrent.jl",
    "src/Responses/ShiftSpinCurrent/ConventionalShiftSpinCurrent.jl",
    "src/Responses/InjectionCurrent/ConventionalInjectionCurrent.jl",
    "src/Responses/InjectionSpinCurrent/ConventionalInjectionSpinCurrent.jl",
    "src/Responses/PhotonDragInjectionCurrent/ConventionalPhotonDragInjectionCurrent.jl",
    "src/Responses/QuantumGeometry/ConventionalQuantumGeometry.jl",
    "src/Responses/QuantumGeometry/QuantumGeometryDerivatives.jl",
    "src/Responses/QuantumGeometry/ProjectorQuantumGeometry.jl",
    "src/Responses/QuantumGeometry/GeometricLoopQuantumGeometry.jl",
    "src/Responses/QuantumGeometry/WilsonLoopQuantumGeometry.jl",
    "src/Responses/QuantumGeometry/GeometricLoopShiftVector.jl",
    "src/Responses/QuantumGeometry/WilsonLoopShiftVector.jl",
    "src/Runtime/Runtime.jl",
    "src/Runtime/Config.jl",
    "src/Runtime/Planning/TaskRegistry.jl",
    "src/Runtime/Planning/BundlePlans.jl",
    "src/Runtime/Validation.jl",
    "src/Runtime/MPI.jl",
    "src/Runtime/Progress.jl",
    "src/Runtime/Paths.jl",
    "src/Runtime/Setup/ExecutionState.jl",
    "src/Runtime/OperatorBundleSetup.jl",
    "src/Runtime/Setup/BundleAssembly.jl",
    "src/Runtime/Setup/FourierExecutionPlan.jl",
    "src/Runtime/Execution/TransitionScreening.jl",
    "src/Runtime/Execution/IntegralFamilies.jl",
    "src/Runtime/Execution/KSliceFamilies.jl",
    "src/Runtime/Execution/IntegralDriver.jl",
    "src/Runtime/Execution/KSliceDriver.jl",
    "src/Runtime/Execution/KPathDriver.jl",
    "src/Runtime/Execution/BandStructureKernel.jl",
    "src/Runtime/Execution/BundleDispatch.jl",
    "src/Runtime/BandStructure.jl",
    "src/Runtime/Reduction/DeterministicReduction.jl",
    "src/Runtime/Output/ResponseOutput.jl",
]
for relative_path in required_files
    isfile(joinpath(ROOT, relative_path)) || fail("$(relative_path) is missing")
end

for removed_path in (
    "src/Core/SymmetryModels.jl",
    "src/IO/WannierInput.jl",
    "src/IO/MagneticMomentReaders.jl",
    "src/IO/SymmetrizedWannierTB.jl",
    "src/IO/RealSpaceOperatorDependencyLoading.jl",
    "src/IO/Cache.jl",
    "src/MatrixElements/OrbitalOperatorConstruction.jl",
    "src/Symmetrization/SymmetryOperationDetection.jl",
    "src/Symmetrization/WannierProjectionRepresentations.jl",
    "src/Symmetrization/RealSpaceSymmetryProjectors.jl",
    "src/Symmetrization/WannierMeshScreening.jl",
    "src/Symmetrization/SymmetrizationWorkflows.jl",
    "src/Symmetrization/SymmetryBackendDependencyLoading.jl",
    "ext/WannierNLQGSymmetrizationExt/WannierInput.jl",
    "ext/WannierNLQGSymmetrizationExt/OrbitalOperatorConstruction.jl",
    "ext/WannierNLQGSymmetrizationExt/SymmetrizationWorkflows.jl",
    "ext/WannierNLQGSymmetrizationExt/SymmetrizedWannierTB.jl",
    "ext/WannierNLQGSymmetrizationExt/WannierPairWignerSeitzTransforms.jl",
    "ext/WannierNLQGSymmetrizationExt/WannierDerivativeOperators.jl",
    "ext/WannierNLQGSymmetrizationExt/ReplicaPolicyCompatibility.jl",
    "ext/WannierNLQGSymmetrizationExt/InputParsingHelpers.jl",
    "ext/WannierNLQGSymmetrizationExt/TBSymmetryOperationDetectionCompatibility.jl",
    "ext/WannierNLQGSymmetrizationExt/WannierOperatorSymmetrization.jl",
    "ext/WannierNLQGSymmetrizationExt/GaugeAwareWannierSymmetrization.jl",
    "src/Wannierization/WannierizationModels.jl",
    "ext/WannierNLQGWannierizationExt/SymmetryAdaptedSolver.jl",
    "ext/WannierNLQGWannierizationExt/StarCovariantPAWWavefunctionGauge.jl",
    "ext/WannierNLQGWannierizationExt/WannierizationHDF5.jl",
    "src/MatrixElements/Interpolated/SpinRealSpace.jl",
    "src/MatrixElements/Interpolated/SpinVelocityRealSpace.jl",
    "src/Runtime/SpinVelocitySetup.jl",
    "src/Runtime/Bundle",
    "src/Responses/ShiftCurrent.jl",
    "src/Responses/QuantumGeometry.jl",
    "src/Responses/InjectionCurrent.jl",
    "src/Responses/ShiftSpinCurrent.jl",
    "src/MatrixElements/Projector.jl",
    "src/MatrixElements/GeometricLoop.jl",
)
    !ispath(joinpath(ROOT, removed_path)) || fail("$(removed_path) must remain removed")
end

retired_phase_keyword = "include_wannier" * "_center_phase"
retired_phase_environment = "WANNIERNLQG_DIAGNOSTIC" * "_SPIN_WCC_PHASE"
for path in vcat(source_files(SRC), source_files(EXT), active_code_files(joinpath(ROOT, "scripts")))
    if path == abspath(@__FILE__)
        continue
    end
    assert_absent(path, retired_phase_keyword)
    assert_absent(path, retired_phase_environment)
end

for path in source_files(SRC)
    source = read(path, String)
    occursin("_projector_restore_common_source_basis!", source) &&
        fail("$(relpath(path, ROOT)) restores a common-source projector basis")
    occursin("overlap_phase_factors", source) &&
        fail("$(relpath(path, ROOT)) retains loop-level overlap phase scratch")
    if path != joinpath(SRC, "Runtime", "Config.jl")
        occursin("basis_correction_enabled", source) &&
            fail("$(relpath(path, ROOT)) retains the retired public basis switch")
    end
end

for relative_path in (
    joinpath("Responses", "Shared", "ResponseKernelHelpers.jl"),
    joinpath("Responses", "QuantumGeometry", "ProjectorQuantumGeometry.jl"),
)
    assert_absent(joinpath(SRC, relative_path), "wannier_centers_fractional")
end

for relative_path in (
    joinpath("MatrixElements", "ConventionCovariantTransport.jl"),
    joinpath("Responses", "Shared", "GeometricLoopCovariantKernels.jl"),
    joinpath("Responses", "Shared", "LoopCurrentSharedKernels.jl"),
    joinpath("Responses", "QuantumGeometry", "GeometricLoopQuantumGeometry.jl"),
    joinpath("Responses", "QuantumGeometry", "GeometricLoopShiftVector.jl"),
)
    source = read(joinpath(SRC, relative_path), String)
    occursin("wannier_centers_fractional", source) ||
        fail("$(relative_path) must consume ordered Wannier centers for covariant transport")
end

geometric_transport_source =
    read(joinpath(SRC, "Responses", "Shared", "GeometricLoopCovariantKernels.jl"), String)
occursin("compute_geometric_loop_covariant_insertion_derivative!", geometric_transport_source) ||
    fail("Geometric transport must complete the transported derivative in one shared kernel")
occursin("WannierCenterConventionFrameConnector", geometric_transport_source) ||
    fail("Geometric transport must dispatch through the typed Convention-II frame connector")
occursin("svd", lowercase(geometric_transport_source)) &&
    fail("Geometric transport must not add polar/SVD link normalization")

wilson_transport_source =
    read(joinpath(SRC, "Responses", "Shared", "WilsonLoopResponseKernels.jl"), String)
occursin("wannier_centers_fractional", wilson_transport_source) ||
    fail("Wilson transport must consume ordered Wannier centers for its frame connector")
occursin("WannierCenterWilsonFrameConnector", wilson_transport_source) ||
    fail("Wilson transport must dispatch through the typed Convention-II frame connector")
occursin("compute_loop_overlap!", wilson_transport_source) &&
    fail("Wilson transport must not fall back to the Geometric bare-overlap primitive")

bundle_composition = read(joinpath(SRC, "Runtime", "BundleKLoop.jl"), String)
count(==('\n'), bundle_composition) <= 24 ||
    fail("Runtime/BundleKLoop.jl must remain a small bundle composition root")
for layer in (
    "Setup/ExecutionState",
    "Planning/BundlePlans",
    "Execution/TransitionScreening",
    "Setup/BundleAssembly",
    "Setup/FourierExecutionPlan",
    "Execution/IntegralFamilies",
    "Execution/KSliceFamilies",
    "Reduction/DeterministicReduction",
    "Output/ResponseOutput",
    "Execution/IntegralDriver",
    "Execution/KSliceDriver",
    "Execution/BundleDispatch",
)
    occursin("$(layer).jl", bundle_composition) ||
        fail("Runtime bundle composition is missing $(layer)")
end

responses_root = joinpath(SRC, "Responses")
response_composition = read(joinpath(responses_root, "Responses.jl"), String)
for pattern in (r"\bfunction\b", r"\bstruct\b", r"\bmutable\s+struct\b", r"@enum")
    occursin(pattern, response_composition) &&
        fail("Responses/Responses.jl must remain an include/export-only composition root")
end
included_response_files = Set{String}()
for matched in eachmatch(r"include\(\"([^\"]+)\"\)", response_composition)
    push!(included_response_files, matched.captures[1])
end
implemented_response_files = Set(
    replace(relpath(path, responses_root), '\\' => '/') for
    path in source_files(responses_root) if basename(path) != "Responses.jl"
)
included_response_files == implemented_response_files || fail(
    "Responses/Responses.jl include set differs from implementation files: " *
    "missing=$(sort!(collect(setdiff(implemented_response_files, included_response_files)))) " *
    "extra=$(sort!(collect(setdiff(included_response_files, implemented_response_files))))",
)
assert_complete_composition(responses_root, joinpath(responses_root, "Responses.jl"))

symmetry_foundation_root = joinpath(SRC, "SymmetryFoundation")
symmetry_foundation_composition = joinpath(symmetry_foundation_root, "SymmetryFoundation.jl")
wannier_projection_root = joinpath(SRC, "WannierProjection")
wannier_projection_composition = joinpath(wannier_projection_root, "WannierProjection.jl")
symmetrization_root = joinpath(SRC, "Symmetrization")
symmetrization_composition = read(joinpath(symmetrization_root, "Symmetrization.jl"), String)
extension_root = joinpath(EXT, "WannierNLQGSymmetrizationExt")
extension_composition = read(joinpath(extension_root, "WannierNLQGSymmetrizationExt.jl"), String)
foundation_extension_root = joinpath(EXT, "WannierNLQGSymmetryFoundationExt")
foundation_extension_composition =
    read(joinpath(foundation_extension_root, "WannierNLQGSymmetryFoundationExt.jl"), String)
for (path, text) in (
    ("src/Symmetrization/Symmetrization.jl", symmetrization_composition),
    ("ext/WannierNLQGSymmetrizationExt/WannierNLQGSymmetrizationExt.jl", extension_composition),
)
    for pattern in (r"\bfunction\b", r"\bstruct\b", r"\bmutable\s+struct\b", r"@enum")
        occursin(pattern, text) &&
            fail("$(path) must remain an include/export-only composition root")
    end
end
assert_complete_composition(symmetry_foundation_root, symmetry_foundation_composition)
assert_complete_composition(wannier_projection_root, wannier_projection_composition)
assert_complete_composition(symmetrization_root, joinpath(symmetrization_root, "Symmetrization.jl"))
assert_complete_composition(
    foundation_extension_root,
    joinpath(foundation_extension_root, "WannierNLQGSymmetryFoundationExt.jl"),
)
assert_complete_composition(
    extension_root,
    joinpath(extension_root, "WannierNLQGSymmetrizationExt.jl"),
)
symmetrization_extension_contract =
    TOML.parsefile(joinpath(ROOT, "test", "contracts", "symmetrization_extension.toml"))
get(symmetrization_extension_contract, "schema_version", nothing) == "1.0" ||
    fail("symmetrization extension contract must use schema_version = 1.0")
actual_symmetrization_files = Set(
    replace(relpath(path, extension_root), '\\' => '/') for path in source_files(extension_root)
)
symmetrization_file_errors = exact_allowlist_violations(
    "Symmetrization extension files",
    actual_symmetrization_files,
    Set(String.(symmetrization_extension_contract["files"])),
)
isempty(symmetrization_file_errors) || fail(join(symmetrization_file_errors, ", "))

expected_symmetrization_component_roots =
    String.(symmetrization_extension_contract["component_roots"])
length(expected_symmetrization_component_roots) ==
length(unique(expected_symmetrization_component_roots)) ||
    fail("Symmetrization component_roots contain duplicates")
for component in expected_symmetrization_component_roots
    startswith(component, "components/") ||
        fail("Symmetrization component root must remain below components/: $(component)")
    assert_include_only_composition(joinpath(extension_root, component))
end
actual_symmetrization_component_roots = sort!(
    String[
        replace(relpath(path, extension_root), '\\' => '/') for
        path in source_files(joinpath(extension_root, "components")) if
        dirname(path) == joinpath(extension_root, "components")
    ],
)
component_root_errors = exact_allowlist_violations(
    "Symmetrization include-only component roots",
    actual_symmetrization_component_roots,
    expected_symmetrization_component_roots,
)
isempty(component_root_errors) || fail(join(component_root_errors, ", "))

symmetrization_dependency_categories = Dict(
    "stdlib" => String.(symmetrization_extension_contract["stdlib_dependencies"]),
    "external" => String.(symmetrization_extension_contract["external_dependencies"]),
    "project" => String.(symmetrization_extension_contract["project_dependencies"]),
    "root" => String.(symmetrization_extension_contract["root_dependencies"]),
)
symmetrization_provider_owners = Dict{String, Vector{String}}()
for (category, providers) in symmetrization_dependency_categories, provider in providers
    push!(get!(symmetrization_provider_owners, provider, String[]), category)
end
ambiguous_symmetrization_providers = sort!(
    String[
        provider for (provider, owners) in symmetrization_provider_owners if length(owners) != 1
    ],
)
isempty(ambiguous_symmetrization_providers) || fail(
    "Symmetrization dependency categories overlap: " *
    join(ambiguous_symmetrization_providers, ", "),
)
declared_symmetrization_providers = Set(keys(symmetrization_provider_owners))
expected_symmetrization_imports = Dict(
    String(provider) =>
        (module_binding = Bool(record["module_binding"]), symbols = String.(record["symbols"]))
    for (provider, record) in symmetrization_extension_contract["imports"]
)
symmetrization_provider_errors = exact_allowlist_violations(
    "Symmetrization dependency providers",
    keys(expected_symmetrization_imports),
    declared_symmetrization_providers,
)
isempty(symmetrization_provider_errors) || fail(join(symmetrization_provider_errors, ", "))
symmetrization_import_errors = import_record_violations(
    "Symmetrization direct imports",
    direct_import_records(extension_composition),
    expected_symmetrization_imports,
)
isempty(symmetrization_import_errors) || fail(join(symmetrization_import_errors, ", "))
symmetrization_using_providers = direct_using_providers(extension_composition)
isempty(symmetrization_using_providers) || fail(
    "Symmetrization extension must use exact import statements, found using " *
    join(symmetrization_using_providers, ", "),
)
for path in source_files(extension_root)
    path == joinpath(extension_root, "WannierNLQGSymmetrizationExt.jl") && continue
    child_imports = direct_import_records(read(path, String))
    isempty(child_imports) || fail(
        "$(relpath(path, ROOT)) bypasses the extension-root import contract: " *
        join(sort!(collect(keys(child_imports))), ", "),
    )
end
symmetrization_root_usage_errors = root_module_usage_violations(
    join((read(path, String) for path in source_files(extension_root)), "\n");
    allowed_functions = ("pkgversion", "pkgdir"),
)
isempty(symmetrization_root_usage_errors) ||
    fail("Symmetrization extension uses the WannierNLQG root outside version/path provenance")
symmetrization_api = String.(symmetrization_extension_contract["integration_api"])
symmetrization_test_api = String.(symmetrization_extension_contract["test_api"])
available_symmetrization_symbols = declared_imported_symbols(
    join((read(path, String) for path in source_files(extension_root)), "\n"),
)
symmetrization_api_errors = integration_api_violations(
    "Symmetrization integration API",
    String.(exported_symbols(extension_composition)),
    symmetrization_api,
    available_symmetrization_symbols,
)
isempty(symmetrization_api_errors) || fail(join(symmetrization_api_errors, ", "))
symmetrization_test_api_errors = test_api_violations(
    "Symmetrization test API",
    symmetrization_test_api,
    symmetrization_test_api,
    available_symmetrization_symbols,
)
isempty(symmetrization_test_api_errors) || fail(join(symmetrization_test_api_errors, ", "))
isempty(intersect(Set(symmetrization_api), Set(symmetrization_test_api))) ||
    fail("Symmetrization integration and test APIs overlap")

wannierization_root = joinpath(SRC, "Wannierization")
wannierization_composition = read(joinpath(wannierization_root, "Wannierization.jl"), String)
wannierization_extension_root = joinpath(EXT, "WannierNLQGWannierizationExt")
wannierization_extension_composition =
    read(joinpath(wannierization_extension_root, "WannierNLQGWannierizationExt.jl"), String)
for (path, text) in (
    ("src/Wannierization/Wannierization.jl", wannierization_composition),
    (
        "ext/WannierNLQGWannierizationExt/WannierNLQGWannierizationExt.jl",
        wannierization_extension_composition,
    ),
)
    for pattern in (r"\bfunction\b", r"\bstruct\b", r"\bmutable\s+struct\b", r"@enum")
        occursin(pattern, text) &&
            fail("$(path) must remain an include/export-only composition root")
    end
end
assert_complete_composition(wannierization_root, joinpath(wannierization_root, "Wannierization.jl"))
assert_complete_composition(
    wannierization_extension_root,
    joinpath(wannierization_extension_root, "WannierNLQGWannierizationExt.jl"),
)
component_contract =
    TOML.parsefile(joinpath(ROOT, "test", "contracts", "wannierization_components.toml"))
get(component_contract, "schema_version", nothing) == "2.0" ||
    fail("wannierization component contract must use schema_version = 2.0")
expected_components = component_contract["components"]
actual_component_files = Dict{String, Vector{String}}()
component_sources = Dict{String, String}()
component_graph = Dict{String, Set{String}}()
component_integration_apis = Dict{String, Vector{String}}()
component_test_apis = Dict{String, Vector{String}}()
for component in sort!(collect(keys(expected_components)))
    root_path = joinpath(wannierization_extension_root, "components", "$(component).jl")
    source = read(root_path, String)
    occursin(Regex("(?m)^module\\s+$(component)\\s*\$"), source) ||
        fail("components/$(component).jl must declare module $(component)")
    files = sort!(
        String[
            replace(
                relpath(
                    normpath(joinpath(dirname(root_path), matched.captures[1])),
                    wannierization_extension_root,
                ),
                '\\' => '/',
            ) for matched in eachmatch(r"include\(\"([^\"]+)\"\)", source)
        ],
    )
    actual_component_files[component] = files
    component_sources[component] =
        join((read(joinpath(wannierization_extension_root, file), String) for file in files), "\n")
    dependencies = Set(String.(relative_module_dependencies(source)))
    component_graph[component] = dependencies
    dependency_errors = exact_allowlist_violations(
        "$(component) dependencies",
        dependencies,
        Set(String.(expected_components[component]["dependencies"])),
    )
    isempty(dependency_errors) || fail(join(dependency_errors, ", "))

    declared_providers = Set(
        vcat(
            String.(expected_components[component]["component_dependencies"]),
            String.(expected_components[component]["stdlib_dependencies"]),
            String.(expected_components[component]["external_dependencies"]),
            String.(expected_components[component]["project_dependencies"]),
            String.(expected_components[component]["root_dependencies"]),
        ),
    )
    provider_errors = [
        "$(component) direct imports: unexpected $(provider)" for provider in
        sort!(collect(setdiff(Set(direct_import_providers(source)), declared_providers)))
    ]
    isempty(provider_errors) || fail(join(provider_errors, ", "))
    expected_import_records = Dict(
        String(provider) => (
            module_binding = Bool(record["module_binding"]),
            symbols = String.(record["symbols"]),
        ) for (provider, record) in expected_components[component]["imports"]
    )
    import_errors = import_record_violations(
        "$(component) direct imports",
        direct_import_records(source),
        expected_import_records,
    )
    isempty(import_errors) || fail(join(import_errors, ", "))
    using_providers = direct_using_providers(source)
    isempty(using_providers) || fail(
        "components/$(component).jl must use exact import statements, found using " *
        join(using_providers, ", "),
    )
    root_usage_errors = root_module_usage_violations(component_sources[component])
    isempty(root_usage_errors) ||
        fail("components/$(component).jl uses the WannierNLQG root outside pkgversion provenance")

    api_match = match(r"(?ms)const\s+[A-Z_]+_INTEGRATION_API\s*=\s*\((.*?)\)", source)
    api_match === nothing && fail("components/$(component).jl lacks an integration API tuple")
    actual_api = String[
        matched.captures[1] for
        matched in eachmatch(r":([A-Za-z_][A-Za-z0-9_]*(?:!)?)", api_match.captures[1])
    ]
    component_integration_apis[component] = actual_api
    available_symbols = declared_imported_symbols(source * "\n" * component_sources[component])
    api_errors = integration_api_violations(
        "$(component) integration API",
        actual_api,
        String.(expected_components[component]["integration_api"]),
        available_symbols,
    )
    isempty(api_errors) || fail(join(api_errors, ", "))

    test_api_match = match(r"(?ms)const\s+[A-Z_]+_TEST_API\s*=\s*\((.*?)\)", source)
    test_api_match === nothing && fail("components/$(component).jl lacks a test API tuple")
    actual_test_api = String[
        matched.captures[1] for
        matched in eachmatch(r":([A-Za-z_][A-Za-z0-9_]*(?:!)?)", test_api_match.captures[1])
    ]
    component_test_apis[component] = actual_test_api
    test_api_errors = test_api_violations(
        "$(component) test API",
        actual_test_api,
        String.(expected_components[component]["test_api"]),
        available_symbols,
    )
    isempty(test_api_errors) || fail(join(test_api_errors, ", "))
    isempty(intersect(Set(actual_api), Set(actual_test_api))) ||
        fail("$(component) integration and test APIs overlap")
end
ownership_errors = component_file_ownership_violations(
    actual_component_files,
    Dict(component => String.(contract["files"]) for (component, contract) in expected_components),
)
isempty(ownership_errors) || fail(join(ownership_errors, ", "))
cycle_errors = dependency_cycle_violations(component_graph)
isempty(cycle_errors) || fail("Wannierization component cycle: " * join(cycle_errors, ", "))
private_component_errors = component_private_reference_violations(component_sources)
isempty(private_component_errors) ||
    fail("Wannierization cross-component private calls: " * join(private_component_errors, ", "))
qualified_component_errors = component_qualified_reference_violations(component_sources)
isempty(qualified_component_errors) || fail(
    "Wannierization component implementations must use exact imported symbols: " *
    join(qualified_component_errors, ", "),
)

wannierization_extension_source =
    read(joinpath(wannierization_extension_root, "WannierNLQGWannierizationExt.jl"), String)
occursin(
    r"(?m)^\s*using\s+\.(?:WannierizationInternalSupport|RepresentationPreparation|ProjectionSearch|PAWMatrixElements|SolverCheckpoint|OperatorExport|WorkflowOrchestration)\s*$",
    wannierization_extension_source,
) && fail("Wannierization parent extension retains a catch-all component using")
expected_entrypoint_owners = Dict{Symbol, Symbol}()
expected_test_entrypoint_owners = Dict{Symbol, Symbol}()
for component in sort!(collect(keys(expected_components)))
    facade_entrypoints = String.(expected_components[component]["facade_entrypoints"])
    length(facade_entrypoints) == length(unique(facade_entrypoints)) ||
        fail("$(component) facade_entrypoints contain duplicates")
    for name in facade_entrypoints
        name in component_integration_apis[component] ||
            fail("$(component) facade entrypoint $(name) is not in its integration API")
        symbol = Symbol(name)
        haskey(expected_entrypoint_owners, symbol) &&
            fail("Wannierization facade entrypoint $(name) has duplicate contract owners")
        expected_entrypoint_owners[symbol] = Symbol(component)
    end
    test_entrypoints = String.(expected_components[component]["test_api"])
    length(test_entrypoints) == length(unique(test_entrypoints)) ||
        fail("$(component) test_api contains duplicates")
    for name in test_entrypoints
        name in component_test_apis[component] ||
            fail("$(component) test entrypoint $(name) is not in its test API")
        symbol = Symbol(name)
        haskey(expected_test_entrypoint_owners, symbol) &&
            fail("Wannierization test entrypoint $(name) has duplicate contract owners")
        expected_test_entrypoint_owners[symbol] = Symbol(component)
    end
end
actual_entrypoint_owners = entrypoint_owner_map(wannierization_extension_source)
entrypoint_errors = entrypoint_owner_violations(
    "Wannierization facade",
    actual_entrypoint_owners,
    expected_entrypoint_owners,
)
isempty(entrypoint_errors) || fail(join(entrypoint_errors, ", "))
actual_test_entrypoint_owners =
    entrypoint_owner_map(wannierization_extension_source, "TEST_ENTRYPOINT_OWNERS")
test_entrypoint_errors = entrypoint_owner_violations(
    "Wannierization test bridge",
    actual_test_entrypoint_owners,
    expected_test_entrypoint_owners,
)
isempty(test_entrypoint_errors) || fail(join(test_entrypoint_errors, ", "))
expert_interface_source =
    read(joinpath(wannierization_root, "WannierizationExpertInterfaces.jl"), String)
bridge_errors = bridge_ownership_violations(
    "Wannierization parent bridge",
    wannierization_bridge_symbols(expert_interface_source),
    actual_entrypoint_owners,
    actual_test_entrypoint_owners,
)
isempty(bridge_errors) || fail(join(bridge_errors, ", "))
occursin("get(BRIDGE_ENTRYPOINT_OWNERS, name)", wannierization_extension_source) ||
    fail("Wannierization resolver must use the explicit combined bridge owner map")
occursin(r"\b(?:isdefined|names)\s*\(", wannierization_extension_source) &&
    fail("Wannierization resolver must not search component symbols at runtime")
photon_drag_shift_entry = read(
    joinpath(responses_root, "PhotonDragShiftCurrent", "GeometricLoopPhotonDragShiftCurrent.jl"),
    String,
)
occursin("compute_geometric_loop_photon_drag_shift_current_kernel! =", photon_drag_shift_entry) ||
    fail("photon-drag shift-current entry must retain its explicit physical-effect name")
integral_families = read(joinpath(SRC, "Runtime", "Execution", "IntegralFamilies.jl"), String)
occursin("Responses.compute_geometric_loop_photon_drag_shift_current_kernel!", integral_families) ||
    fail("Runtime must use the non-exported photon-drag shift-current entry by qualification")

allowed_response_directories = Set([
    "Shared",
    "ShiftCurrent",
    "PhotonDragShiftCurrent",
    "InjectionCurrent",
    "PhotonDragInjectionCurrent",
    "ShiftSpinCurrent",
    "InjectionSpinCurrent",
    "QuantumGeometry",
])
actual_response_directories =
    Set(name for name in readdir(responses_root) if isdir(joinpath(responses_root, name)))
actual_response_directories == allowed_response_directories || fail(
    "Responses physical domains differ from the architecture contract: " *
    "$(sort!(collect(actual_response_directories)))",
)
for name in readdir(responses_root)
    path = joinpath(responses_root, name)
    isfile(path) &&
        name != "Responses.jl" &&
        fail("Responses root may contain only Responses.jl; found $(name)")
end

source_basenames = Dict{String, Vector{String}}()
for path in vcat(source_files(SRC), source_files(EXT))
    push!(get!(source_basenames, basename(path), String[]), relpath(path, ROOT))
end
for (name, paths) in source_basenames
    length(paths) == 1 ||
        fail("source basename $(name) is duplicated at $(join(sort!(paths), ", "))")
end
ambiguous_source_names = Set([
    "Spin.jl",
    "Conventional.jl",
    "Projector.jl",
    "GeometricLoop.jl",
    "WilsonLoop.jl",
    "Plan.jl",
    "Workspace.jl",
])
for path in vcat(source_files(SRC), source_files(EXT))
    basename(path) in ambiguous_source_names &&
        fail("ambiguous source filename remains: $(relpath(path, ROOT))")
end

facade = read(joinpath(SRC, "WannierNLQG.jl"), String)
include_order = [
    "Core",
    "SymmetryFoundation",
    "WannierProjection",
    "IO",
    "MatrixElements",
    "Symmetrization",
    "Wannierization",
    "Responses",
    "Runtime",
]
positions = [findfirst("\"$(name)\"", facade) for name in include_order]
any(isnothing, positions) && fail("facade does not include every architectural submodule")
issorted(first.(positions)) ||
    fail("facade submodule include order does not follow the dependency DAG")
Set(exported_symbols(facade)) == Set([
    :TaskConfig,
    :TaskSpec,
    :RunResult,
    :run,
    :ModelInput,
    :BZMesh,
    :KSlice,
    :KPath,
    :ExecutionOptions,
    :OutputOptions,
    :OpticalParameters,
    :FiniteQOpticalParameters,
    :GeometryParameters,
    :BandParameters,
    :OpticalNumerics,
    :GeometryNumerics,
    :BandNumerics,
    :BandTargets,
    :Subspace,
    :Subspaces,
    :OccupiedBands,
    :AllBands,
    :Transition,
    :InterbandGroups,
    :TripleGroups,
    :TensorComponent,
    :FullTensor,
    :KSliceSelection,
]) || fail("facade export set differs from the grouped response API contract")
Set(exported_symbols(wannierization_composition)) == Set((
    :SymmetryAdaptedWannierizationConfig,
    :WannierizationResult,
    :construct_symmetry_adapted_wannier_functions,
)) || fail("Wannierization facade export set differs from its three-symbol allowlist")

project = TOML.parsefile(joinpath(ROOT, "Project.toml"))
extensions = project["extensions"]
expected_extensions = component_contract["extensions"]
for extension_name in sort!(collect(keys(expected_extensions)))
    contract = expected_extensions[extension_name]
    expected_triggers = String.(contract["triggers"])
    get(extensions, extension_name, nothing) == expected_triggers ||
        fail("Project.toml trigger set for $(extension_name) differs from $(expected_triggers)")
    actual_dependencies = Set{String}()
    for path in source_files(joinpath(EXT, extension_name))
        source = read(path, String)
        for matched in eachmatch(r"(?m)^\s*(?:using|import)\s+([A-Za-z][A-Za-z0-9_.]*)", source)
            push!(actual_dependencies, matched.captures[1])
        end
    end
    expected_source_dependencies =
        extension_name == "WannierNLQGSymmetrizationExt" ? declared_symmetrization_providers :
        Set(String.(contract["source_dependencies"]))
    dependency_errors = exact_allowlist_violations(
        "$(extension_name) source dependencies",
        actual_dependencies,
        expected_source_dependencies,
    )
    isempty(dependency_errors) || fail(join(dependency_errors, ", "))
end

module_sources = Dict(
    :Core => read(joinpath(SRC, "Core", "Core.jl"), String),
    :SymmetryFoundation =>
        read(joinpath(SRC, "SymmetryFoundation", "SymmetryFoundation.jl"), String),
    :WannierProjection =>
        read(joinpath(SRC, "WannierProjection", "WannierProjection.jl"), String),
    :IO => read(joinpath(SRC, "IO", "IO.jl"), String),
    :MatrixElements => read(joinpath(SRC, "MatrixElements", "MatrixElementsModule.jl"), String),
    :Symmetrization => read(joinpath(SRC, "Symmetrization", "Symmetrization.jl"), String),
    :Wannierization => read(joinpath(SRC, "Wannierization", "Wannierization.jl"), String),
    :Responses => read(joinpath(SRC, "Responses", "Responses.jl"), String),
    :Runtime => read(joinpath(SRC, "Runtime", "Runtime.jl"), String),
)
occursin("using ..", module_sources[:Core]) && fail("Core must not depend on project submodules")
occursin("using ..Core", module_sources[:SymmetryFoundation]) ||
    fail("SymmetryFoundation must depend on Core")
occursin("using ..SymmetryFoundation", module_sources[:WannierProjection]) ||
    fail("WannierProjection must depend on SymmetryFoundation")
occursin("using ..Core", module_sources[:IO]) || fail("IO must depend on Core")
occursin("using ..IO", module_sources[:IO]) && fail("IO cannot depend on itself")
for forbidden in ("..MatrixElements", "..Responses", "..Runtime")
    occursin(forbidden, module_sources[:IO]) && fail("IO has an upward dependency $(forbidden)")
end
for required in ("using ..Core", "using ..IO")
    occursin(required, module_sources[:MatrixElements]) ||
        fail("MatrixElements is missing dependency $(required)")
end
for forbidden in ("..Responses", "..Runtime")
    occursin(forbidden, module_sources[:MatrixElements]) &&
        fail("MatrixElements has an upward dependency $(forbidden)")
end
for required in ("using ..Core", "import ..SymmetryFoundation", "import ..WannierProjection")
    occursin(required, module_sources[:Symmetrization]) ||
        fail("Symmetrization is missing dependency $(required)")
end
for forbidden in ("..IO", "..MatrixElements", "..Responses", "..Runtime")
    occursin(forbidden, module_sources[:Symmetrization]) &&
        fail("the Symmetrization facade has an upward dependency $(forbidden)")
end
for required in
    ("using ..Core", "using ..IO", "import ..SymmetryFoundation", "import ..WannierProjection")
    occursin(required, module_sources[:Wannierization]) ||
        fail("Wannierization is missing dependency $(required)")
end
for forbidden in ("..MatrixElements", "..Responses", "..Runtime")
    occursin(forbidden, module_sources[:Wannierization]) &&
        fail("Wannierization has an upward dependency $(forbidden)")
end
for required in ("using ..Core", "using ..MatrixElements")
    occursin(required, module_sources[:Responses]) ||
        fail("Responses is missing dependency $(required)")
end
for forbidden in ("using ..IO", "using ..Runtime")
    occursin(forbidden, module_sources[:Responses]) &&
        fail("Responses has a forbidden dependency $(forbidden)")
end
for required in (
    "using ..Core",
    "using ..IO",
    "using ..MatrixElements",
    "using ..Responses",
    "using ..SymmetryFoundation: response_symmetry_group_report",
)
    occursin(required, module_sources[:Runtime]) ||
        fail("Runtime is missing dependency $(required)")
end

allowed_dependencies = Dict(
    "Core" => Set{String}(),
    "SymmetryFoundation" => Set(["Core"]),
    "WannierProjection" => Set(["SymmetryFoundation"]),
    "IO" => Set(["Core"]),
    "MatrixElements" => Set(["Core", "IO"]),
    "Symmetrization" => Set(["Core", "SymmetryFoundation", "WannierProjection"]),
    "Wannierization" => Set(["Core", "IO", "SymmetryFoundation", "WannierProjection"]),
    "Responses" => Set(["Core", "MatrixElements"]),
    "Runtime" => Set(["Core", "IO", "MatrixElements", "Responses", "SymmetryFoundation"]),
)
for (layer, allowed) in allowed_dependencies
    for path in source_files(joinpath(SRC, layer))
        text = read(path, String)
        for matched in eachmatch(r"\b(?:using|import)\s+\.\.([A-Za-z][A-Za-z0-9_]*)", text)
            dependency = matched.captures[1]
            dependency in allowed ||
                fail("$(relpath(path, ROOT)) has forbidden dependency $(dependency)")
        end
    end
end

for path in vcat(
    source_files(joinpath(SRC, "Symmetrization")),
    source_files(joinpath(EXT, "WannierNLQGSymmetrizationExt")),
)
    assert_absent(path, r"\b(?:using|import)\s+(?:\.\.|WannierNLQG\.)Wannierization\b")
    assert_absent(path, r"\bWannierNLQG\.Wannierization\.")
end
for path in vcat(
    source_files(joinpath(SRC, "Wannierization")),
    source_files(joinpath(EXT, "WannierNLQGWannierizationExt")),
)
    assert_absent(path, r"\b(?:using|import)\s+(?:\.\.|WannierNLQG\.)Symmetrization\b")
    assert_absent(path, r"\bWannierNLQG\.Symmetrization\.")
end
for forbidden in ("WannierNLQG.Responses", "WannierNLQG.Runtime")
    occursin(forbidden, wannierization_extension_composition) &&
        fail("Wannierization extension has forbidden dependency $(forbidden)")
end
for path in source_files(wannierization_extension_root)
    for forbidden in
        (r"\busing\s+PyCall\b", r"\busing\s+PythonCall\b", r"\bimport\s+wannierberri\b")
        assert_absent(path, forbidden)
    end
end

all_architecture_sources = vcat(source_files(SRC), source_files(EXT))
boundary_scan_roots = ("src", "ext", "scripts", "test", "examples")
boundary_sources = Dict{String, String}()
for relative_root in boundary_scan_roots
    root = joinpath(ROOT, relative_root)
    isdir(root) || continue
    for path in active_code_files(root)
        boundary_sources[replace(relpath(path, ROOT), '\\' => '/')] = read(path, String)
    end
end
production_sources = Dict(
    path => source for
    (path, source) in boundary_sources if startswith(path, "src/") || startswith(path, "ext/")
)
results_artifacts_source =
    read(joinpath(SRC, "Wannierization", "models", "ResultsArtifacts.jl"), String)
sawf_leaf_fields = Set{Symbol}()
for group in (
    "WannierizationInputConfig",
    "WannierizationSolverConfig",
    "WannierizationCheckpointConfig",
    "WannierizationRuntimeConfig",
    "WannierizationOutputConfig",
)
    matched = match(Regex("(?s)struct " * group * "(.*?)\\nend"), results_artifacts_source)
    matched === nothing && fail("cannot derive SAWF leaf fields for $(group)")
    for field in eachmatch(r"(?m)^    ([A-Za-z_][A-Za-z0-9_]*)::", matched.captures[1])
        push!(sawf_leaf_fields, Symbol(field.captures[1]))
    end
end
length(sawf_leaf_fields) == 73 ||
    fail("Wannierization grouped configuration must retain 73 leaf fields")
sawf_flat_reads = typed_sawf_flat_config_reads(boundary_sources, sawf_leaf_fields)
expected_negative_sawf_flat_reads =
    Set(("test/wannierization_config_architecture_unit.jl: ordinary_default.win_file",))
sawf_flat_read_errors = exact_allowlist_violations(
    "typed SAWF top-level leaf reads",
    Set(sawf_flat_reads),
    expected_negative_sawf_flat_reads,
)
isempty(sawf_flat_read_errors) || fail(join(sawf_flat_read_errors, ", "))
spglib_violations = production_spglib_violations(production_sources)
isempty(spglib_violations) ||
    fail("Spglib ownership violations remain: " * join(spglib_violations, ", "))
private_boundary_violations = private_shared_boundary_violations(boundary_sources)
isempty(private_boundary_violations) ||
    fail("shared-layer private references remain: " * join(private_boundary_violations, ", "))
private_module_violations = private_module_boundary_violations(production_sources)
isempty(private_module_violations) || fail(
    "production module-private cross-owner references remain: " *
    join(private_module_violations, ", "),
)
semantic_type_violations = semantic_duplicate_type_violations(production_sources)
isempty(semantic_type_violations) ||
    fail("semantic duplicate types remain: " * join(semantic_type_violations, ", "))

shared_type_owners = Dict(
    "CrystalStructure" => joinpath(SRC, "SymmetryFoundation"),
    "SymmetryOperation" => joinpath(SRC, "SymmetryFoundation"),
    "MagneticSymmetryInventory" => joinpath(SRC, "SymmetryFoundation"),
    "WannierSymmetryPlan" => joinpath(SRC, "SymmetryFoundation"),
    "BandRepresentation" => joinpath(SRC, "SymmetryFoundation"),
    "BandRepresentationQualificationScope" => joinpath(SRC, "SymmetryFoundation"),
    "RepresentationRawDiagnostic" => joinpath(SRC, "SymmetryFoundation"),
    "VASPBandRepresentationConfig" => joinpath(SRC, "SymmetryFoundation"),
    "AbstractWavefunctionSource" => joinpath(SRC, "SymmetryFoundation"),
    "VASPWavefunctionSource" => joinpath(SRC, "SymmetryFoundation"),
    "QuantumEspressoWavefunctionSource" => joinpath(SRC, "SymmetryFoundation"),
    "ProjectionSpec" => joinpath(SRC, "WannierProjection"),
    "ProjectionRadialTransformConfig" => joinpath(SRC, "WannierProjection"),
    "WannierProjectionBlock" => joinpath(SRC, "WannierProjection"),
    "WannierProjectionBasis" => joinpath(SRC, "WannierProjection"),
)
for (type_name, owner_root) in shared_type_owners
    declaration = Regex(
        "(?m)^\\s*(?:Base\\.@kwdef\\s+)?(?:abstract\\s+type|mutable\\s+struct|struct|@enum)\\s+" *
        type_name *
        "\\b",
    )
    owners =
        [path for path in all_architecture_sources if occursin(declaration, read(path, String))]
    length(owners) == 1 || fail(
        "shared type $(type_name) must have exactly one owner; found " *
        join((relpath(path, ROOT) for path in owners), ", "),
    )
    startswith(only(owners), owner_root * Base.Filesystem.path_separator) ||
        fail("shared type $(type_name) is outside its declared shared layer")
end

foundation_persistence = joinpath(foundation_extension_root, "BandRepresentationPersistence.jl")
for function_name in ("write_band_representation_hdf5", "read_band_representation_hdf5")
    implementation = Regex("(?m)^function\\s+$(function_name)\\b")
    owners = [path for path in source_files(EXT) if occursin(implementation, read(path, String))]
    owners == [foundation_persistence] || fail(
        "$(function_name) production implementation must be unique to " *
        "ext/WannierNLQGSymmetryFoundationExt/BandRepresentationPersistence.jl",
    )
end
native_vasp_reader = Regex("(?m)^function\\s+read_vasp_wavefunctions\\b")
native_vasp_reader_owners =
    [path for path in all_architecture_sources if occursin(native_vasp_reader, read(path, String))]
native_vasp_reader_owners == [joinpath(SRC, "SymmetryFoundation", "VASPWavefunctions.jl")] ||
    fail("native VASP wavefunction reader must have one SymmetryFoundation implementation")

for path in all_architecture_sources
    assert_absent(path, "_legacy_build_band_representation")
    assert_absent(path, ":wannierberri_native")
    assert_absent(path, ":wanniernlqg_extension")
end
for path in vcat(
    source_files(joinpath(SRC, "Symmetrization")),
    source_files(joinpath(EXT, "WannierNLQGSymmetrizationExt")),
)
    assert_absent(path, r"\bfunction\s+generate_wannier_amn\b")
end
assert_absent(joinpath(SRC, "Wannierization", "WannierizationExpertInterfaces.jl"), r"@eval")

extension_loader = joinpath(SRC, "Symmetrization", "SymmetrizationExtensionLoading.jl")
foundation_extension_loader =
    joinpath(SRC, "SymmetryFoundation", "SymmetryFoundationExtensionLoading.jl")
wannierization_extension_loader =
    joinpath(SRC, "Wannierization", "WannierizationExtensionLoading.jl")
operator_bundle_loader = joinpath(SRC, "IO", "RealSpaceOperatorBundles.jl")
for path in source_files(SRC)
    path in (
        extension_loader,
        foundation_extension_loader,
        wannierization_extension_loader,
        operator_bundle_loader,
    ) && continue
    for dependency in ("Spglib", "HDF5", "JSON3", "EzXML")
        assert_absent(path, Regex("\\b(?:using|import)\\s+$(dependency)\\b"))
    end
end

for layer in ("MatrixElements", "Responses")
    for path in source_files(joinpath(SRC, layer))
        for pattern in (
            r"\bopen\s*\(",
            r"\bread\s*\(",
            r"\breadline\s*\(",
            r"\beachline\s*\(",
            r"\bwrite\s*\(",
            r"\bmkpath\s*\(",
            r"\bread_wannier_[a-z0-9_]+\b",
            r"\b(?:serialize|deserialize)\s*\(",
        )
            assert_absent(path, pattern)
        end
    end
end

for path in source_files(joinpath(SRC, "Responses"))
    for pattern in (
        r"\bMPI\b",
        r"\bENV\b",
        r"Threads\.@threads",
        r"Threads\.@spawn",
        r"\busing\s+Base\.Threads\b",
    )
        assert_absent(path, pattern)
    end
end

for driver in (
    joinpath(SRC, "Runtime", "Execution", "IntegralDriver.jl"),
    joinpath(SRC, "Runtime", "Execution", "KSliceDriver.jl"),
)
    for pattern in (r"\bTASK_DEFINITIONS\b", r"\btask_definition\s*\(", r"\bDict\s*\(")
        assert_absent(driver, pattern)
    end
end

for module_file in
    (joinpath(SRC, "Responses", "Responses.jl"), joinpath(SRC, "Runtime", "Runtime.jl"))
    assert_absent(module_file, r"for\s+symbol\s+in\s+names\s*\(")
end

architecture = read(joinpath(ROOT, "docs", "ARCHITECTURE.md"), String)
architecture_inventory =
    read(joinpath(ROOT, "docs", "ARCHITECTURE_IMPLEMENTATION_INVENTORY.md"), String)
documented_implementation_roots = (
    symmetry_foundation_root,
    wannier_projection_root,
    symmetrization_root,
    wannierization_root,
    foundation_extension_root,
    extension_root,
    wannierization_extension_root,
)
documented_implementation_paths = sort!(
    String[
        replace(relpath(path, ROOT), '\\' => '/') for root in documented_implementation_roots
        for path in source_files(root)
    ],
)
undocumented_paths = missing_documented_paths(
    architecture * "\n" * architecture_inventory,
    documented_implementation_paths,
)
isempty(undocumented_paths) || fail(
    "docs/ARCHITECTURE.md implementation inventory is incomplete: " *
    join(undocumented_paths, ", "),
)
for directory in ("Planning/", "Setup/", "Execution/", "Reduction/", "Output/")
    isdir(joinpath(SRC, "Runtime", chop(directory; tail = 1))) ||
        fail("documented Runtime directory $(directory) is missing")
    occursin(directory, architecture) ||
        fail("docs/ARCHITECTURE.md does not describe Runtime/$(directory)")
end
for directory in (
    "Shared/",
    "ShiftCurrent/",
    "PhotonDragShiftCurrent/",
    "InjectionCurrent/",
    "PhotonDragInjectionCurrent/",
    "ShiftSpinCurrent/",
    "InjectionSpinCurrent/",
    "QuantumGeometry/",
)
    isdir(joinpath(SRC, "Responses", chop(directory; tail = 1))) ||
        fail("documented Responses directory $(directory) is missing")
    occursin(directory, architecture) ||
        fail("docs/ARCHITECTURE.md does not describe Responses/$(directory)")
end

include(joinpath(ROOT, "scripts", "SourceDocumentationAudit.jl"))
using .SourceDocumentationAudit
documentation_audit = audit_source_documentation([SRC, EXT])
missing_documentation = filter(record -> !record.documented, documentation_audit.declarations)
for (category, records) in (
    ("public API declarations lack docstrings", documentation_audit.public_api_missing_docstrings),
    ("known documentation templates remain", documentation_audit.filler_declarations),
)
    isempty(records) || fail(
        category *
        ": " *
        join(
            ("$(relpath(record.path, ROOT)):$(record.line) $(record.name)" for record in records),
            ", ",
        ),
    )
end
isempty(documentation_audit.parse_failures) || fail(
    "source documentation audit could not parse: " *
    join(first.(documentation_audit.parse_failures), ", "),
)
isempty(documentation_audit.orphan_docstrings) || fail(
    "orphan top-level docstrings remain: " * join(
        (
            "$(relpath(path, ROOT)):$(line)" for
            (path, line) in documentation_audit.orphan_docstrings
        ),
        ", ",
    ),
)
isempty(missing_documentation) || fail(
    "source declarations lack adjacent documentation: " * join(
        (
            "$(relpath(record.path, ROOT)):$(record.line) $(record.name)" for
            record in missing_documentation
        ),
        ", ",
    ),
)
for path in vcat(source_files(SRC), source_files(EXT))
    for (line_number, line) in enumerate(eachline(path))
        match(r"^\s+", line) !== nothing &&
            strip(line) == "\"\"\"" &&
            fail("function-body docstring remains at $(relpath(path, ROOT)):$(line_number)")
    end
end

for path in source_files(joinpath(SRC, "MatrixElements"))
    assert_absent(path, r"\bnum_photon_energies\b")
end

for removed_file in (
    "src/MatrixElements/Conventional.jl",
    "src/MatrixElements/Spin.jl",
    "src/MatrixElements/SpinVelocity.jl",
)
    ispath(joinpath(ROOT, removed_file)) &&
        fail("removed matrix-element family file still exists: $(removed_file)")
end

for path in source_files(joinpath(SRC, "IO"))
    for pattern in
        (r"\bfunction\s+compute_kpoint!", r"\bfunction\s+prepare_real_space!", r"\beigen\s*\(")
        assert_absent(path, pattern)
    end
end
for path in source_files(joinpath(SRC, "Runtime"))
    for pattern in (
        r"\bfunction\s+compute_kpoint!",
        r"\bfunction\s+prepare_real_space!",
        r"\bstruct\s+[A-Za-z0-9_]*KPointData",
    )
        assert_absent(path, pattern)
    end
end

active_roots = [
    joinpath(ROOT, "src"),
    joinpath(ROOT, "ext"),
    joinpath(ROOT, "scripts"),
    joinpath(ROOT, "test"),
]
const WANNIER90_VERSION_BOUND_IDENTIFIERS = Set([
    "Wannier90Matrices",
    "Wannier90ReferenceDiagnosticSet",
    "Wannier90ReferenceDiagnostics",
    "SMVFletcherReevesTwoStageAuditThresholds",
    "Wannier90ReferenceSupplement",
    "Wannier90References",
    "Wannier90SourceIntegrity",
    "Wannier90StrictPlotAudit",
])
for active_root in active_roots
    for path in active_code_files(active_root)
        filename = basename(path)
        baseline_adapter =
            filename in ("check_fused_kloop_regression.jl", "benchmark_hot_allocations.jl")
        occursin(r"(?i)qiao|wannier90", filename) &&
            fail("active filename contains a forbidden person/version name: $(relpath(path, ROOT))")
        source_text = read(path, String)
        for identifier in eachmatch(r"\bWannier90[A-Za-z_][A-Za-z0-9_]*\b", source_text)
            identifier.match in WANNIER90_VERSION_BOUND_IDENTIFIERS || fail(
                "unapproved Wannier90-bound identifier $(identifier.match) remains in " *
                relpath(path, ROOT),
            )
        end
        for pattern in (
            r"\bQiao[A-Za-z_][A-Za-z0-9_]*\b",
            r"\bqiao_[A-Za-z0-9_]+\b",
            r"\breadWAN90TB\b",
            r"\bTBM\b",
            r"\bTMP\b",
        )
            if baseline_adapter && pattern == r"\breadWAN90TB\b"
                continue
            end
            assert_absent(path, pattern)
        end
    end
end

for path in vcat(source_files(SRC), source_files(EXT))
    occursin(r"\p{Han}", read(path, String)) &&
        fail("$(relpath(path, ROOT)) contains non-English source text")
end

include(joinpath(SRC, "WannierNLQG.jl"))
using .WannierNLQG

symmetrization_provider_apis = Dict(
    "WannierNLQG.Core" => Set(String.(names(WannierNLQG.Core; all = false, imported = false))),
    "WannierNLQG.IO" => Set(String.(names(WannierNLQG.IO; all = false, imported = false))),
    "WannierNLQG.MatrixElements" => union(
        Set(String.(names(WannierNLQG.MatrixElements; all = false, imported = false))),
        Set(String.(WannierNLQG.MatrixElements.MATRIX_ELEMENTS_INTEGRATION_API)),
    ),
    "WannierNLQG.Symmetrization" => union(
        Set(String.(names(WannierNLQG.Symmetrization; all = false, imported = false))),
        Set(("OperatorValidationSummary",)),
    ),
    "WannierNLQG.SymmetryFoundation" => union(
        Set(String.(names(WannierNLQG.SymmetryFoundation; all = false, imported = false))),
        Set(String.(WannierNLQG.SymmetryFoundation.SYMMETRY_FOUNDATION_INTEGRATION_API)),
    ),
    "WannierNLQG.WannierProjection" => union(
        Set(String.(names(WannierNLQG.WannierProjection; all = false, imported = false))),
        Set(String.(WannierNLQG.WannierProjection.WANNIER_PROJECTION_INTEGRATION_API)),
    ),
)
for provider in String.(symmetrization_extension_contract["project_dependencies"])
    imported_symbols = Set(String.(expected_symmetrization_imports[provider].symbols))
    unavailable = sort!(collect(setdiff(imported_symbols, symmetrization_provider_apis[provider])))
    isempty(unavailable) || fail(
        "Symmetrization imports symbols outside $(provider)'s public/integration API: " *
        join(unavailable, ", "),
    )
end

shared_boundary_violations = shared_boundary_reference_violations(
    boundary_sources,
    Dict(
        "SymmetryFoundation" =>
            names(WannierNLQG.SymmetryFoundation; all = false, imported = false),
        "WannierProjection" =>
            names(WannierNLQG.WannierProjection; all = false, imported = false),
    ),
    Dict(
        "SymmetryFoundation" =>
            WannierNLQG.SymmetryFoundation.SYMMETRY_FOUNDATION_INTEGRATION_API,
        "WannierProjection" => WannierNLQG.WannierProjection.WANNIER_PROJECTION_INTEGRATION_API,
    ),
)
isempty(shared_boundary_violations) || fail(
    "shared-layer qualified references bypass integration allowlists: " *
    join(shared_boundary_violations, ", "),
)
matrix_elements_boundary_violations = shared_boundary_reference_violations(
    production_sources,
    Dict("MatrixElements" => names(WannierNLQG.MatrixElements; all = false, imported = false)),
    Dict("MatrixElements" => WannierNLQG.MatrixElements.MATRIX_ELEMENTS_INTEGRATION_API);
    owner_prefixes = Dict("MatrixElements" => ("src/MatrixElements/",)),
)
isempty(matrix_elements_boundary_violations) || fail(
    "MatrixElements qualified references bypass the integration allowlist: " *
    join(matrix_elements_boundary_violations, ", "),
)
integration_allowlist_errors = integration_allowlist_violations(
    Dict(
        "SymmetryFoundation" =>
            names(WannierNLQG.SymmetryFoundation; all = false, imported = false),
        "WannierProjection" =>
            names(WannierNLQG.WannierProjection; all = false, imported = false),
        "MatrixElements" => names(WannierNLQG.MatrixElements; all = false, imported = false),
    ),
    Dict(
        "SymmetryFoundation" =>
            WannierNLQG.SymmetryFoundation.SYMMETRY_FOUNDATION_INTEGRATION_API,
        "WannierProjection" => WannierNLQG.WannierProjection.WANNIER_PROJECTION_INTEGRATION_API,
        "MatrixElements" => WannierNLQG.MatrixElements.MATRIX_ELEMENTS_INTEGRATION_API,
    ),
)
isempty(integration_allowlist_errors) || fail(
    "integration allowlists are mixed or ambiguous: " * join(integration_allowlist_errors, ", "),
)
matrix_elements_test_api_errors = test_api_violations(
    "MatrixElements test API",
    String.(WannierNLQG.MatrixElements.MATRIX_ELEMENTS_TEST_API),
    String.(WannierNLQG.MatrixElements.MATRIX_ELEMENTS_TEST_API),
    String.(names(WannierNLQG.MatrixElements; all = true, imported = true)),
)
isempty(matrix_elements_test_api_errors) ||
    fail("invalid MatrixElements test API: " * join(matrix_elements_test_api_errors, ", "))

expected_fields = Set([:model, :sampling, :tasks, :execution, :output])
Set(fieldnames(WannierNLQG.TaskConfig)) == expected_fields ||
    fail("TaskConfig must contain only shared groups and independent task instances")
fieldnames(WannierNLQG.TaskSpec) == (:id, :quantity, :method, :physics, :numerics, :observable) ||
    fail("TaskSpec fields do not match the independent response contract")
!isdefined(WannierNLQG, :EffectiveTaskConfig) && !isdefined(WannierNLQG, :NormalizedTaskSpec) ||
    fail("effective configuration and normalized task identity must remain private to Runtime")

matrix_elements = WannierNLQG.MatrixElements
for kind in (
    matrix_elements.SPECTRUM,
    matrix_elements.BERRY_CONNECTION,
    matrix_elements.SPIN,
    matrix_elements.SPIN_VELOCITY,
)
    kind isa matrix_elements.MatrixElementKind ||
        fail("$(kind) is not a typed MatrixElementKind capability")
end

:spectrum in fieldnames(matrix_elements.KPointMatrixData) ||
    fail("KPointMatrixData must be the unique owner of KPointSpectrum")
for data_type in (matrix_elements.ProjectorMatrixData, matrix_elements.GeometricLoopMatrixData)
    :common in fieldnames(data_type) ||
        fail("$(data_type) must compose shared KPointMatrixData as `common`")
    :spectrum in fieldnames(data_type) &&
        fail("$(data_type) must not own a duplicate KPointSpectrum")
end

for removed_name in (
    :ConventionalKPointData,
    :ConventionalKPointScratch,
    :SpinKPointData,
    :SpinKPointScratch,
    :SpinVelocityKPointData,
    :SpinVelocityKPointScratch,
    :ProjectorKPointData,
    :ProjectorKPointScratch,
    :GeometricLoopKPointData,
    :GeometricLoopKPointScratch,
)
    isdefined(matrix_elements, removed_name) &&
        fail("removed matrix-element API $(removed_name) is still defined")
end
isdefined(matrix_elements, :ConventionalGeometryKPointData) &&
    fail("duplicate ConventionalGeometryKPointData still exists")
isdefined(matrix_elements, :ConventionalGeometryKPointScratch) &&
    fail("duplicate ConventionalGeometryKPointScratch still exists")
isdefined(WannierNLQG.Core, :ConventionalGeometryTB) &&
    fail("duplicate ConventionalGeometryTB still exists")
hasfield(WannierNLQG.Core.TightBindingModel, :spin_r) &&
    fail("TightBindingModel must not contain optional spin data")

module_text = module_sources[:MatrixElements]
occursin("names(@__MODULE__", module_text) &&
    fail("MatrixElements must use explicit exports instead of exporting names dynamically")
occursin("export MatrixElementKind", module_text) ||
    fail("MatrixElements must explicitly export its expert capability API")

println("structure boundary checks passed")
