# Architecture

MatrixElements imports the private Core.ESKernel DenseSpectra, FFTBuffers and WorkspacePlanning for given-operator spectra, bound local FFT execution and checked cold buffer bytes. WN retains physical selections, spin/gauge policy, packing/traversal, thresholds and execution state.

## Dependency direction

```text
Core
  ↑
SymmetryFoundation
  ↑
WannierProjection

Symmetrization ──> SymmetryFoundation + WannierProjection
Wannierization  ──> SymmetryFoundation + WannierProjection

WannierNLQG facade ──> Runtime ──> Responses ──> MatrixElements ──> IO ──> Core
  Responses -> MatrixElements -> IO -> Core
  Responses -> Core
  MatrixElements -> Core
  IO -> Core
  SymmetryFoundation -> IO (declared-input digest integration only)
  WannierProjection -> Core (ordinary-construction parameter contract)
  Runtime -> SymmetryFoundation (response symmetry and structural band-path ports)
  Runtime -> Wannierization + Symmetrization (cold text configuration and explicit public run)
  Runtime -> WannierProjection (WIN atom order for direct magnetic moments)

WannierNLQGSymmetryFoundationExt -> SymmetryFoundation + Core + IO
                                    + Spglib/HDF5/JSON3
WannierNLQGSymmetrizationExt -> Symmetrization + SymmetryFoundation
                             -> WannierProjection + MatrixElements + IO + Core
                             -> HDF5/JSON3/EzXML
WannierNLQGWannierizationExt -> Wannierization + SymmetryFoundation
                             -> WannierProjection + MatrixElements + IO + Core + MPI
                             -> HDF5/JSON3/EzXML
```

The facade only assembles modules in dependency order and re-exports
the grouped response configuration types, typed observable selectors,
`RunResult`, and `run`. A lower layer must never import a
higher layer. IO loads before SymmetryFoundation; the latter retains narrow
forwarding bindings for existing preparation credential ports. Verified input
digests have one IO implementation and callback-scoped task-local lifetime.

The recursive, machine-checked file inventory for the shared and expert layers
is maintained in [ARCHITECTURE_IMPLEMENTATION_INVENTORY.md](ARCHITECTURE_IMPLEMENTATION_INVENTORY.md).

Structural Band planning keeps Brillouin catalogue selection and reciprocal-basis
conversion in `SymmetryFoundation`. Native crystal standardization remains in
`WannierNLQGSymmetryFoundationExt/SymmetryOperationDetection.jl`, reached through
the existing lazy extension bridge. The base module does not import Spglib.
It also defers Brillouin to a requested structural band path through Julia's
normal package resolver. The loaded module is passed through the existing
world-age bridge; fixed-grid response sampling does not activate it. See
[dependency readiness](DEPENDENCY_READINESS.md) for validation and cache reuse.

### Project extension triggers versus source dependencies

`Project.toml` extension triggers are activation conditions, not complete source
dependency declarations:

| Extension | Project extension triggers | Additional direct source dependencies |
|---|---|---|
| `WannierNLQGOperatorBundleExt` | `MPI`, `HDF5`, `JSON3` | `Dates`, `SHA`, `WannierNLQG`, `Core`, `IO` |
| `WannierNLQGSymmetryFoundationExt` | `Spglib`, `HDF5`, `JSON3` | `Dates`, `LinearAlgebra`, `Printf`, `SHA`, `PrecompileTools`, `WannierNLQG`, `Core`, `IO`, `SymmetryFoundation` |
| `WannierNLQGSymmetrizationExt` | `HDF5`, `JSON3`, `EzXML` | `Dates`, `EzXML`, `LinearAlgebra`, `Printf`, `SHA`, `WannierNLQG`, `Core`, `IO`, `MatrixElements`, `Symmetrization`, `SymmetryFoundation`, `WannierProjection` |
| `WannierNLQGWannierizationExt` | `MPI`, `HDF5`, `JSON3`, `EzXML` | `Dates`, `FFTW`, `LinearAlgebra`, `MPI`, `Printf`, `Random`, `SHA`, `WannierNLQG`, `Core`, `IO`, `MatrixElements`, `SymmetryFoundation`, `WannierProjection`, `Wannierization` |

The compiler-only `WannierNLQGWannierizationPrecompileExt` keeps the existing
five triggers for public symmetrization, PAW audit and the tiny SF + W workflow.
Crystal symmetry and completed BandRepresentation persistence workloads live in
the three-trigger `WannierNLQGSymmetryFoundationExt`. Public checkpoint readback
and native-EIG tight-binding construction live in the four-trigger W owner.
Independent full-mesh spread evaluation also belongs to W: its public result
and supplied-frame overloads do not require crystal-symmetry activation. Both
owners reuse one pure deterministic input builder in W's `PrecompileSupport`;
the builder activates no extensions and performs no solver calculation.
Julia image generation permits sibling extensions only when their trigger sets
are strict subsets of the compiling owner's triggers. The SF + W workflow
therefore cannot run in W alone; its composite owner covers both dependencies.
The workflow constructs configs inside the compile block and enters both the
bounded disentanglement-only and actual nonzero-U localization call trees.
The accepted tiny localized checkpoint additionally enters the public gauge-chain
diagnostic's independent Fourier reconstruction and evidence writers. The native
QE workload captures public spin and MMN/AMN construction, including actual file
readback; generated-file self-comparison is compiler coverage, not an independent
scientific oracle or material qualification.
One shared one-band, three-k-point native QE pipeline additionally feeds real
generated spin/overlap artifacts into public Galerkin Hamiltonian, spin-Hamiltonian,
two-link operator and physical projection construction. These are distinct operator
trees sharing one source/preparation pipeline, rather than one workload per
qualification path. Generated-file reuse provides compiler coverage only.
The shared two-band, two-k-point VASP native family follows actual public
activation: BandRepresentation runs in the three-trigger SF image, while PAW
overlap/projection and nonzero spin run in the four-trigger W image. A five-trigger
composite capture was insufficient for calls which do not activate that image.
Both use one pure tiny WAVECAR input builder; the underlying native-byte helpers
retain the shipped qualification support verbatim. Assertions establish finite
construction/readback for compiler coverage; independent science stays external.
The lazy SF and W loaders resolve the same declared dependency UUIDs through
Base.require in their original order, avoiding runtime eval and closed-module
binding mutation. The existing latest-world dispatch boundary is retained.
Workloads call public facades, assert real registration, use deterministic tiny
inputs and local temporary files, and neither launch nor initialize MPI.
The fixed checkpoint/TB and completed BandRepresentation inputs are existing
manifest-pinned miniature public fixtures; no user data or network is needed.
Source113's actual clean failure remains archived. The corrected placement still
requires its own empty-cache precompile and fresh cold qualification.

The exact trigger lists and complete direct-source dependency sets are frozen in
`test/contracts/wannierization_components.toml`; the structure gate rejects both
missing and newly added entries. The Packed operator loader imports both `HDF5`
and `JSON3` before activation. Declaring both triggers prevents recursive extension
activation while parsing sealed construction evidence in a fresh Julia process.

## Module ownership

### Wannierization stage ownership

For `schedule=:two_stage`, disentanglement owns only the sealed projector/frame
field and invariant-spread history. Localization consumes that sealed subspace
and owns centers, gauge-dependent spreads, gradients, and line search. Numerical
spectral/transport/projectability thresholds are independent from representation
tolerances. The contiguous and MPI raw-Z kernels remain subordinate parity
backends until all performance-promotion gates pass.

### Core

`Core` owns physical constants, coordinate conversions, general numerical helpers,
`TightBindingModel`, and `KPointSpectrum`. It has no project-module dependency and performs no file IO.
`TightBindingModel` contains Hamiltonian and position data only; optional physical
operators are peer real-space objects in `MatrixElements`.
`NonorthogonalLocalizedModels.jl` owns the separate `NonorthogonalLocalizedModel`
and `NonorthogonalLocalizedInput`. H/S storage and complete R partners are explicit;
the position operator can be explicitly absent for H/S-only work. IO owns external
protocols and units; Core has no OpenMX format or file-reading dependency.

### Shared operator task requirements

`Core/OperatorTaskRequirements.jl` owns `OperatorTask`,
`OperatorTaskRequirement`, `OPERATOR_TASK_REQUIREMENTS`, source closures and
`resolve_operator_requirements`. Wannierization export and Runtime
`operator_demand_plan()` consume this single registry; neither imports the other
or maintains a parallel task-to-operator mapping. Core resolves pure deterministic
inventories and digests without file IO. IO owns selection serialization and
fresh-read validation; the Wannierization extension resolves actual source files,
authority backend/digest/input hashes, and generation before writing the bundle.

The resolver defaults to `orbital_input_semantics=:unspecified`, preserving the
five-operator OAM export closure. Runtime can explicitly use
`:defined_finite_model` to derive OAM from H/position; that specialization grants
no five-operator export qualification.

Normalized requested pairs retain `:all`; method expansion belongs to each task's
dependency closure. Runtime MatrixElements derives internal connection, gauge
correction and Berry connection from persisted Hamiltonian/position. Such
capabilities must not be added to the real-space operator inventory. Source
pruning happens before generation, while Runtime verifies operator/component
coverage at consumption. See [the public dependency table](WANNIERIZATION.md#complete-supported-task-dependencies)
and [the Packed contract](STORAGE_SCHEMAS.md#task-derived-packed-operator-selection).

### IO

`IO` owns parsers and writers: the Wannier TB/SPN/CHK/EIG/MMN/uIu formats,
streaming Fortran records, response tensors, K-slice files, and atomic Band tables. It constructs data-transfer
objects but never diagonalizes a Hamiltonian or builds k-point matrix elements.
`WannierTBWriter.jl` is the unique `_tb.dat` production writer.
`OpenMXLocalizedInput.jl` admits declared spinless 3.8 or binary-version-3 H/S/r
records without paired-block repair. A declared H/S-only import excludes position
capabilities and retains the measured raw position defect in provenance.

### MatrixElements

`MatrixElements` owns Fourier transforms, gauge transforms, finite-difference
stencils, model-to-operator transforms such as Wannier-center extraction,
real-space operator data, k-point data, and scratch objects. `Interpolated/`
organizes the common pipeline by capability instead of by calculation method:
`MatrixElementPlan`, `MatrixElementWorkspace`, `HamiltonianMatrixElements`,
`PositionMatrixElements`, `SpinMatrixElements`, and
`SpinVelocityMatrixElements`. `ProjectorMatrixElements` and
`GeometricLoopMatrixElements` retain only their algorithm-specific data.

```text
MatrixElements/
├── MatrixElementsModule.jl
├── NonorthogonalMatrixElements.jl
├── Interfaces.jl
├── ModelTransforms.jl
├── ProjectorMatrixElements.jl
├── GeometricLoopMatrixElements.jl
└── Interpolated/
    ├── MatrixElementPlan.jl
    ├── MatrixElementWorkspace.jl
    ├── MixedFourierMatrixElements.jl
    ├── HamiltonianMatrixElements.jl
    ├── PositionMatrixElements.jl
    ├── SpinMatrixElements.jl
    ├── SpinVelocityMatrixElements.jl
    ├── WannierPairWignerSeitzTransforms.jl
    └── WannierDerivativeOperators.jl
```

`KPointMatrixData` is the unique owner of `KPointSpectrum`. All response families
at the same structured k-point offset share that object through a worker-local
`KPointBatchWorkspace`. Method implementations share the output-first interface:

The nonorthogonal backend retains this owner and common interface while solving
H C = S C E and storing slot- and generation-bound metric diagnostics. Its explicit
position payload carries metric-aware covariant derivatives; the Conventional
shift-current dispatch consumes them in the existing physical response bracket.
Metric IC uses HF slopes; metric SHG separates shared Deta geometry from PV widths.
Lowered ambient curvature and scalar interband products feed the common Berry
response. Explicitly complete, flat finite models may use Conventional orbital
magnetization through a metric wrapper that rejects Euclidean projector helpers.
The orthogonal Fourier, eigensolver, derivative and response routes retain their
own specialized dispatch. See [the localized metric contract](NONORTHOGONAL_LOCALIZED.md).

```julia
prepare_real_space!(workspace, model)
compute_spectrum!(workspace, model, kpoint)
compute_remaining!(workspace, model)
compute_kpoint!(workspace, model, kpoint)
transform_to_hamiltonian_gauge!(output, spectrum, input, temporary)
```

`MatrixElementRequest` is compiled into a dependency-closed
`MatrixElementPlan`. Unrequested components are `nothing` and allocate no arrays.
`matrix(workspace, kind)` only reads an explicitly requested and already computed
capability; it never triggers calculation.

`RealSpaceReplicaPolicies.jl` owns the unique minimum-distance replica mapping.
`WannierPairWignerSeitzTransforms.jl` and `WannierDerivativeOperators.jl` own
the shared center-aware q-to-R and derivative-operator contracts used by both
expert extensions; neither extension reaches into the other. `HamiltonianMatrixElements.jl` owns the
shared Wannier-degeneracy-weighted Fourier assembly; Band adds finite/Hermiticity
checks around that assembly but does not define a second interpolation formula.

### Runtime Band family

`Runtime/BandStructure.jl` owns path normalization, row-lattice distance,
deterministic global-index work partitioning, qualification propagation, and
root-only publication. It is a spectrum-only executor and cannot be mixed with
Integral/K-slice. `scripts/plot_band_structure.jl` is a separate audited
presentation consumer: it reads the numerical outputs and never participates in
Runtime dispatch or recomputes the path.

### SymmetryFoundation

`SymmetryFoundation` is the unique owner of crystal/magnetic symmetry models,
band representations, wavefunction-source models, spin actions, canonical
representation construction, and pure real-space symmetry kernels. It has no
dependency on either expert workflow.

```text
src/SymmetryFoundation/
├── SymmetryFoundation.jl
├── SymmetryDetectionContracts.jl
├── SymmetryModels.jl
├── MagneticPointGroupCanonicalization.jl
├── GeneratedMagneticPointGroupCatalog.jl
├── ResponseSymmetryGroupReporting.jl
├── ResponseSymmetryGroupGenerators.jl
├── BandRepresentationModels.jl
├── BandRepresentationContracts.jl
├── SpinSymmetryActions.jl
├── NativeWavefunctionModels.jl
├── VASPWavefunctions.jl
├── CanonicalBandRepresentationBuilder.jl
├── RealSpaceSymmetryProjectors.jl
├── SymmetryFoundationExtensionLoading.jl
├── SymmetryFoundationExpertInterfaces.jl
└── SymmetryFoundationIntegrationContracts.jl

ext/WannierNLQGSymmetryFoundationExt/
├── WannierNLQGSymmetryFoundationExt.jl
├── SymmetryOperationDetection.jl
├── ResponseSymmetryGroupClassification.jl
├── TBSymmetryDetectionCompatibility.jl
├── VASPBandRepresentationBuilder.jl
└── BandRepresentationPersistence.jl
```

The foundation extension is the sole production boundary for Spglib detection,
native VASP representation generation, and BandRepresentation wire-schema-1.0
HDF5 persistence/readback. It is also the only production source of
`Spglib.get_dataset`, `Spglib.get_magnetic_dataset`, backend-version lookup,
and Spglib data conversion. The existing schema string is unchanged and no new
attributes are added. All three readers accept only wire 1.0 and reject
non-1.0 input, including historical 1.1–1.17, without migration. They do not
infer file age or distinguish historical 1.0 collisions; the current complete
contract and strict/diagnostic qualification restrictions apply.

Response-symmetry group classification follows the same ownership boundary.
Runtime invokes the qualified `SymmetryFoundation` facade only on the cold
report-assembly path; it does not import Spglib or implement group mathematics.
The first enabled response-symmetry report therefore activates the Foundation
extension and its Spglib/HDF5/JSON3 triggers, while an ordinary run with no
response-symmetry report keeps those optional dependencies unloaded. The pure
Foundation layer owns deterministic point/finite-Seitz generator closure, the
Spglib-generated catalogue, and the normalized colored-operation identity
contract. The extension owns structure and magnetic-group reclassification
from stored artifact records, recomputes full and active identities from the
actual operations, and verifies the exact canonical-to-input basis bijection
before reporting them.

### WannierProjection

`WannierProjection` is the unique owner of projection specifications, radial
contracts, WIN structure/projection parsing, orbital values, projection-basis
materialization, and symmetry-plan construction. It depends on
`SymmetryFoundation`, never on either expert workflow.

```text
src/WannierProjection/
├── WannierProjection.jl
├── ProjectionModels.jl
├── WannierInputParsingHelpers.jl
├── WannierWinData.jl
├── WannierProjectionRepresentations.jl
└── WannierProjectionIntegrationContracts.jl
```

### Symmetrization

`Symmetrization` is a thin parent-package workflow facade. It owns only
symmetrization-specific configurations/results, expert-interface documentation,
and a thread-safe extension loader; shared symmetry/projection types live below it. It does
not import `Spglib`, `HDF5`, or `JSON3`. `Responses` and `Runtime` do not depend
on it, so the existing `run(config)` response path remains unchanged.

```text
src/Symmetrization/
├── Symmetrization.jl
├── GaugeAwareSymmetrizationModels.jl
├── SymmetrizationConfigs.jl
├── SymmetrizationExtensionLoading.jl
└── SymmetrizationExpertInterfaces.jl

ext/WannierNLQGSymmetrizationExt/
├── WannierNLQGSymmetrizationExt.jl
├── MagneticMomentReaders.jl
├── ResponseSymmetryArtifactWriter.jl
├── ResponseSymmetryQualification.jl
├── WannierCenterGeometry.jl
├── WannierMeshScreening.jl
└── components/
    ├── ValidationComponent.jl
    ├── SewingComponent.jl
    ├── ProjectionComponent.jl
    ├── PersistenceComponent.jl
    ├── WorkflowComponent.jl
    ├── validation/OperatorWorkflowValidation.jl
    ├── validation/GaugeAwareValidation.jl
    ├── sewing/GaugeAwareSewing.jl
    ├── projection/OperatorProjection.jl
    ├── projection/GaugeAwareProjection.jl
    ├── persistence/OperatorPersistence.jl
    ├── persistence/GaugeAwarePersistence.jl
    ├── workflow/OperatorWorkflow.jl
    └── workflow/GaugeAwareWorkflow.jl
```

Magnetic readers reuse the qualified parser integration API from
`WannierProjection`; no duplicate parser implementation remains. The explicit
integration allowlists are `SYMMETRY_FOUNDATION_INTEGRATION_API` and
`WANNIER_PROJECTION_INTEGRATION_API`; cross-layer calls to underscored owner
helpers are forbidden. SymmetryFoundation exposes two named, non-exported
validation ports: `validate_public_band_representation_contract` bridges to
the extension's complete current Band contract, while
`validate_unified_representation_mode_contract` reuses the core mode validator.
`SolverCheckpoint` validates the complete public Band contract before treating
`1.0` as a current completion state for compatibility policy selection. Magnetic,
antiunitary and incomplete legacy representations retain their strict policy.
Preparation validates a provided public completion before binding its mode. A
private Boolean records a validated missing-origin fallback and preserves that
absence through mode binding, persistence, readback and repeated preparation.
Explicitly recorded legacy origins retain their previous policy through the same
sequence; raw inputs still receive their original provenance during preparation.
These ports preserve the public export list and representation fields. The symmetry
extension is triggered by `Spglib`, `HDF5`, and `JSON3`. Its loader checks
`Base.get_extension` under one `ReentrantLock`, imports those triggers in the
fixed order, and bridges facade
calls with `Base.invokelatest`. Later calls reuse the activated extension. If a
user imports all triggers first, Julia may activate the extension
before an expert call; that is native extension behavior.

The first operation-detection call crosses the qualified Foundation API. Only
the SymmetryFoundation loader then loads Spglib and activates
`WannierNLQGSymmetryFoundationExt`; Symmetrization never imports or queries the
backend directly. `symmetry_detection_backend_provenance` preserves the existing
`spglib_version` artifact field without weakening that ownership boundary.

The facade does not own or re-export `BandRepresentation`, native-wavefunction
sources, symmetry types, or projection models. Those breaking-migration APIs are
available only from `SymmetryFoundation` or `WannierProjection`.
`IO/WannierHR.jl` owns the independent
standard `_hr.dat` boundary used by the Hamiltonian-only stage.

The shared-layer checker separates literal compiler Type operands from runtime
integration edges using Julia ASTs and actual owner Type bindings. Only known
recorders inside `@compile_workload` can use these operands; runtime calls,
private imports, unverified symbols and arbitrary expressions remain rejected.
Anonymous `var"#..."` Types are parsed as their real symbols, never as `var`.

Compiler declarations use the explicitly imported `Symmetrization` and
`SymmetryFoundation` module bindings, preserving exact function and anonymous
Type identities without routing requests through the root facade. Workload
preferences are queried on the same root package module through the declared
PrecompileTools API. MPI lifecycle observations belong to the independent
package import gate; this extension does not query or import MPI.

The extension depends on `Core`, `IO`, `MatrixElements`, `SymmetryFoundation`,
`WannierProjection`, and its own facade. It cannot depend on `Wannierization`,
`Responses`, or `Runtime`. Spglib detection, representation building/persistence,
projection parsing/materialization, TB writing, replica mapping, and derivative
construction are consumed from their unique lower-layer owners rather than
reimplemented here. MatrixElements capabilities cross this boundary only through
its named, non-exported integration API; the structure contract rejects direct
calls to underscored MatrixElements helpers. `SymmetrizationConfig` has no uIu field, and this
extension does not own full uIu derivative construction.

The gauge-aware entry in `components/workflow/GaugeAwareWorkflow.jl` is a
separate fail-closed path for an existing TB. Native wavefunction reading, VASP representation construction,
and BandRepresentation persistence are foundation-owned. The schema separates band and target group-law
diagnostics, preserves the aggregate field for older consumers, and records the
worst operation pair, k-point, phase, cocycle, singular values, and factors for
each UU/UA/AU/AA channel. The workflow combines that sewing with the CHK
composite gauge, never constructs an ideal orbital projector, and never calls
SAWF, disentanglement, Wannierization, or response kernels. A complete TB is not
published until the link-derived position gates pass.

WIN is the sole structure and projection authority. IO adapters may read QE or
VASP only when an explicit magnetic provider is selected, and QE `K_POINTS` is
never parsed. All supported operators use one `RealSpaceSymmetryProjectors`
implementation for spatial index mapping, unitary/antiunitary basis action,
tensor parity, deterministic missing-block generation, and group averaging.
One internal `RealSpaceProjectionContext` validates the selected group and
caches representation support once per workflow for projection, covariance,
and idempotence. One internal `WannierDerivativeTransformPlan` caches residue
phases, Wannier-center shifts, target-R mappings, and Wigner-Seitz images for
the primitive derivative operators.

Each `KPointMatrixData` also owns its Fourier factors. This is required by the
two-stage screening path: switching from a valence slot to a conduction slot may
replace the active scratch view, so returning to a cached slot must restore that
slot's factors before `compute_remaining!` constructs derivatives or observables.

Every Hamiltonian-gauge eigensystem uses the deterministic canonical phase: the
largest-magnitude eigenvector component (first index on a tie) is made
nonnegative real. No additional rotation is applied inside a degenerate subspace.
Public capability matrices and expert `matrix(...)` results always use this
canonical gauge. `KPointSpectrum` and `PositionMatrixData` additionally retain a
private source-gauge representation derived from the same Fourier operators and
the same single diagonalization. Closed-loop transport and the finite-q injection
kernel use that private representation to preserve the established contraction
path; it is not a second spectrum, is not exposed through `matrix`, and does not
permit another diagonalization.

### Wannierization

`ProjectionRepresentationSearcher` is a cold-path expert subsystem inside the
Wannierization facade and extension. Stable request/result types live in
`src/Wannierization`; little-group algebra, the declared character-reduction
adapter, deterministic integer search, HDF5 persistence, and SAWF configuration
materialization live in `WannierNLQGWannierizationExt`. This subsystem has no
dependency on Responses or Runtime and never enters AMN, SAWF, TB, MPI, or
response execution.

The compatibility adapter owns the fixed character-reduction convention and
the boundary between `:spinless_unitary` and `:generalized_symmetry`. The algebra layer owns factor
systems, irreducible representations, magnetic corepresentations, and
intertwiner residuals. The search layer consumes only canonical integer
signatures and records intertwiner validation independently from signature
compatibility.

```text
src/Wannierization/
└── ProjectionRepresentationSearchModels.jl

ext/WannierNLQGWannierizationExt/
├── ProjectionRepresentationGroupAlgebra.jl
├── ProjectionRepresentationCorepresentations.jl
├── ProjectionRepresentationIntertwiners.jl
├── ProjectionCharacterReduction.jl
├── ProjectionRepresentationSearch.jl
├── ProjectionRepresentationSearchHDF5.jl
└── ProjectionRepresentationMaterialization.jl
```

`Wannierization` is an independent expert namespace for native
symmetry-adapted Wannier-function construction. The parent module owns public
configuration/result types, typed failure states, lightweight constructors,
public facades, and the lazy extension bridge. Configuration validation,
representation diagnostics, Z/U iteration, checkpointing, DFT adapters, TB
construction, and operator generation are extension-owned. The parent depends
on `SymmetryFoundation`, `WannierProjection`, `IO`, and `Core`, never on
`Symmetrization`, `Responses`, or `Runtime`; therefore the existing response
`run(config)` path is unchanged. The heavy extension makes its existing
MatrixElements operator-construction dependency explicit, but has no access to
the Symmetrization extension.
`using WannierNLQG.Wannierization` imports exactly
`WannierizationConfig`, `WannierizationResult`, and
`construct_wannier_functions`. Other supported expert names
remain available only through qualified `WannierNLQG.Wannierization.X` access.

```text
src/Wannierization/
├── Wannierization.jl
├── models/ConfigurationsContracts.jl
├── models/OptimizerStates.jl
├── models/DiagnosticsQualification.jl
├── models/ResultsArtifacts.jl
├── ProjectionRepresentationSearchModels.jl
├── WannierizationExtensionLoading.jl
└── WannierizationExpertInterfaces.jl

ext/WannierNLQGWannierizationExt/
├── WannierNLQGWannierizationExt.jl
├── components/
│   ├── WannierizationInternalSupport.jl
│   ├── RepresentationPreparation.jl
│   ├── ProjectionSearch.jl
│   ├── PAWMatrixElements.jl
│   ├── SolverCheckpoint.jl
│   ├── OperatorExport.jl
│   └── WorkflowOrchestration.jl
├── support/
│   ├── HDF5Operations.jl
│   ├── SupportLinearAlgebra.jl
│   ├── RepresentationHelpers.jl
│   ├── BackendPorts.jl
│   ├── ResultHelpers.jl
│   └── GaugeFrameProvenance.jl
├── solver/LinearAlgebra.jl
├── solver/SymmetryFrames.jl
├── solver/Initialization.jl
├── solver/Localization.jl
├── solver/Optimizer.jl
├── solver/RestartContract.jl
├── solver/RestartWorkflow.jl
├── solver/SolverPreparation.jl
├── solver/SolverInitialization.jl
├── solver/SolverProposal.jl
├── solver/SolverAcceptance.jl
├── solver/SolverTermination.jl
├── solver/SolverIteration.jl
├── WannierizationConfigValidation.jl
├── QuantumEspressoWavefunctions.jl
├── BandRepresentationBuilder.jl
├── OperatorPublicationReuse.jl
├── WannierUIUGeneration.jl
├── WannierHamiltonianOperatorGeneration.jl
├── QEPAWSpinMatrixElements.jl
├── AuthoritativeBandHamiltonian.jl
├── OperatorProfileAssembly.jl
├── FullUIUWannierDerivativeOperators.jl
├── FullUIUDerivativeOperatorBundle.jl
├── hdf5/FixedSubspace.jl
├── hdf5/CheckpointDigests.jl
├── hdf5/Writer.jl
├── hdf5/LegacyMigration.jl
├── hdf5/Reader.jl
├── star_gauge/FrameContract.jl
├── star_gauge/StarTransport.jl
├── star_gauge/PartitionReynolds.jl
├── star_gauge/Persistence.jl
├── star_gauge/ConstructionWorkflow.jl
├── TightBindingConstruction.jl
└── WannierizationWorkflow.jl
```

The component roots are real nested Julia modules. `WannierizationInternalSupport`
owns atomic HDF5 operations, shared linear algebra, representation/window helpers,
the digest-bound gauge-frame provenance contract, backend ports, and result
reconstruction. The five domain modules have the exact dependency DAG below.
`WorkflowOrchestration` depends on every domain module except the independent
`ProjectionSearch` entrypoint.

| Component | Exact component dependencies |
| --- | --- |
| `RepresentationPreparation` | `WannierizationInternalSupport` |
| `ProjectionSearch` | `WannierizationInternalSupport`, `RepresentationPreparation` |
| `PAWMatrixElements` | `WannierizationInternalSupport`, `RepresentationPreparation` |
| `SolverCheckpoint` | `WannierizationInternalSupport`, `RepresentationPreparation`, `PAWMatrixElements` |
| `OperatorExport` | `WannierizationInternalSupport`, `RepresentationPreparation`, `PAWMatrixElements`, `SolverCheckpoint` |
| `WorkflowOrchestration` | `WannierizationInternalSupport`, `RepresentationPreparation`, `PAWMatrixElements`, `SolverCheckpoint`, `OperatorExport` |

```text
WannierizationInternalSupport
  ↑
RepresentationPreparation
  ↑             ↖
ProjectionSearch PAWMatrixElements
                    ↑
              SolverCheckpoint
                    ↑
                OperatorExport
                    ↑
             WorkflowOrchestration
```

The direct provider allowlist is independently frozen from the component DAG:

| Component | Stdlib | External packages | Project modules |
| --- | --- | --- | --- |
| `WannierizationInternalSupport` | `Dates`, `LinearAlgebra`, `SHA` | `EzXML`, `HDF5` | `SymmetryFoundation`, `Wannierization` |
| `RepresentationPreparation` | `LinearAlgebra`, `Random`, `SHA` | `EzXML`, `HDF5` | `Core`, `IO`, `SymmetryFoundation`, `WannierProjection`, `Wannierization` |
| `ProjectionSearch` | `LinearAlgebra`, `SHA` | `HDF5`, `JSON3` | `SymmetryFoundation`, `WannierProjection`, `Wannierization` |
| `PAWMatrixElements` | `LinearAlgebra`, `Printf`, `SHA` | `FFTW`, `HDF5`, `JSON3` | `Core`, `IO`, `SymmetryFoundation`, `WannierProjection`, `Wannierization` |
| `SolverCheckpoint` | `LinearAlgebra`, `Random`, `SHA` | `HDF5`, `JSON3`, `MPI` | `Core`, `IO`, `SymmetryFoundation`, `WannierProjection`, `Wannierization` |
| `OperatorExport` | `Dates`, `LinearAlgebra`, `Printf`, `SHA` | `HDF5`, `JSON3` | `Core`, `IO`, `MatrixElements`, `SymmetryFoundation`, `Wannierization` |
| `WorkflowOrchestration` | `LinearAlgebra`, `SHA` | `HDF5`, `MPI` | `Core`, `IO`, `SymmetryFoundation`, `WannierProjection`, `Wannierization` |

Each provider record also freezes whether the module binding is visible and the
exact imported symbols. Adding or deleting either a provider or a symbol is a
contract violation; a passing component DAG alone is therefore insufficient.

No component integration API contains an underscored name. The parent extension
loads modules in topological order, resolves each established expert entrypoint
to exactly one owner, and rebinds only the existing expert surface. File
ownership, exact provider/symbol imports, integration APIs, forbidden private
edges, and cycles are independently checked against
`test/contracts/wannierization_components.toml`.

`WannierizationConfig` now contains exactly five groups:
`input` (26 fields), `solver` (20), `checkpoint` (4), `runtime` (2), and
`output` (19). The 71 old constructor keywords have no compatibility constructor;
the complete migration map is in `WANNIERIZATION_CONFIG.md`. The five
group types remain qualified names and are not added to the three-symbol parent
export list.

The solver entry delegates qualification and restart preparation to
`SolverPreparation.jl`, state construction to `SolverInitialization.jl`, and the
iteration loop to `SolverIteration.jl`. `SolverProposal.jl` evaluates a candidate;
`SolverAcceptance.jl` retains or rejects it, and `SolverTermination.jl` assembles
the terminal result. Concrete internal records carry stage state. Borrowed
restart arrays and retained accepted arrays keep their previous ownership and
copy boundaries; extraction preserves numerical statement order. These files
remain private to `SolverCheckpoint` and add no public API or component edge.

`SolverCheckpoint.WannierizationRestartContract` is the immutable owner of the
canonical trajectory representation, current digest, and historical migration
digests. Public checkpoint schema 1.1 retains the former 2.28 persisted HDF5
fields, `input_summary` keys, and scientific restart identity. The public reader
rejects every other wire version before returning state.

The extension is triggered only when all of `HDF5`, `JSON3`, and `EzXML` are
present. Its loader imports those packages in that fixed order on the first
expert call. A later real symmetry-detection call delegates to the Foundation
loader, which uniquely loads Spglib. VASP and Quantum Espresso adapters are read-only and
native Julia; no Python runtime is part of the package path.
The shared SymmetryFoundation VASP builder owns VASP plane-wave symmetry actions,
k-star/IBZ maps, sewing matrices, and complete energy blocks. The Wannierization
extension retains its QE Fortran-record/HDF5 adapter, UPF-authoritative
atomic-type normalization, AMN/projection overlaps, restart/checkpoint, and
solver-specific construction code.
The same extension owns configuration semantics, group-law and antiunitary
preflight, sewing diagnostics, the complete deterministic Z/U solver, native
VASP/QE uIu generation, deterministic bounded QE
wavefunction caching, restart/checksum/atomic-publication provenance, and exact
same-gauge operator generators and schema-6 profile bundles.
`AuthoritativeBandHamiltonian.jl` binds native EIG or the actual Reynolds-projected
Hamiltonian to TB and every weighted operator. `FullUIUWannierDerivativeOperators.jl` computes the
full uIu tensor and only calls the frozen pair-Wigner--Seitz transformation
contract; no uIu configuration flows into the Symmetrization facade or its TB
workflows.
Both adapters expose a source-level spin-mode provenance contract. The shared
builder rejects a single collinear channel before any antiunitary sewing action
can incorrectly stand in for the missing partner channel.
`RepresentationGroupLaw.jl` and `AntiunitaryCompatibility.jl` own the static
operation/k/translation/spin/sewing/target/Kramers preflight for Type-I--IV
groups, including complete corepresentation masks and target multiplicity. The preflight is
run once before the numerical solver; the solver reuses only native projector
covariance checks. `SewingMatrixAlignment.jl` is validation-only and cannot be
called as a solver retraction or fallback. Shared SU(2)/time-reversal actions
live in `SymmetryFoundation/SpinSymmetryActions.jl`, so both modules consume the
same improper-rotation and antiunitary convention.
The split `solver/` implementation keeps `z_mix_ratio` and `u_mix_ratio` independent and
uses a full-BZ MV gradient projected through star pullback and magnetic
little-group tangents, followed by rank-gated polar retraction and Armijo search.
`MVLocalizationEvaluation` also accumulates the centered objective, center
increment, and spread on that same full mesh before magnetic property
symmetrization. It deliberately bypasses the legacy IBZ objective shortcut at
the U boundary because `Arg` branch selection and finite-cutoff star averaging
do not commute.
Frozen bands constrain only the Z subspace; U updates never freeze target-space
Wannier orbitals and never apply continuous commutant alignment.
The SymmetryFoundation extension's `BandRepresentationPersistence.jl` is the
unique band-representation wire-schema-1.0 production boundary. Non-1.0
representations are rejected by its full, preparation, and validation-context
readers; neither expert workflow re-exports it. A combined workflow referencing
an old Band artifact fails explicitly even if its other formats have independent migration tools. The default plane-wave adapters
normalize source data and delegate to the canonical coefficient-map builder;
the expert strict adapter retains full-cutoff raw coefficients and delegates to
`AugmentationAwareBandSewing.jl`.
The split `hdf5/` implementation writes public checkpoint schema 1.1 with the
complete former 2.28 numerical contract; schemas 2.0--2.28 require external
migration and are not readable by the public reader. Historical schema 2.5 bound
the canonical final exported-TB symmetry qualification payload; schema 2.6 also
persists Riemannian-CG history and typed Anderson/CG diagnostics. Schema 2.7
binds the unwrapped-center MV localization-gradient contract. Schema 2.8 binds
the transactional Type-IV joint update, Z-limit policy, qualified Z-seal and
route/export eligibility, transport spectra, backtracking, and atomic-acceptance
diagnostics. Newly selected IBZ subspaces are completed over the full k-star
before candidate projectors are formed, so non-IBZ storage never mixes old and
new accepted states. Schema 2.9 adds the parent/effective operation-subgroup
identity, `:full`/`:unitary`/`:identity` constraint scope, and terminal local
link-quality fields. Schema 2.10 binds the centered-residual MV phase chart,
Type-IV Clarke active-orbit state, generalized gradient, polar-retraction
strong-Wolfe diagnostics, and accepted RCG/L-BFGS histories.
Schema 2.11 binds the band-sewing backend, metric, frozen PAW thresholds, and
strict diagnostic digest; cross-backend representation/Z/U/checkpoint reuse is
rejected.
Schema 2.12 additionally binds the independent wavefunction-gauge backend and
the self-contained gauge-artifact SHA-256. The split `star_gauge/` implementation
owns representative-only PAW-S Lowdin frames, bounded closure selection,
unitary/antiunitary Reynolds averaging, Kramers gauge fixing, exact k-star
transport, and schema-1.0 gauge persistence. Every native band remains visible
to leakage tests even though no star may retain more than the configured finite
buffer. `SymmetryCompletedQEPAWMatrixElements.jl` owns the completed-WFC direct
MMN/AMN path and its independent rectangular-parent rotation oracle.
`ConstraintOperationScopes.jl` derives closed subgroup
k-stars without mutating the parent representation; non-full scopes are
standard and reset U/CG history. Their symmetry-expanded U frames are
conditioned-polar restored inside the sealed projector, preserving the fixed-Z
ablation contract without touching the default full-Type-IV path.
`WannierGaugeChainDiagnostics.jl`
separates projector, link/gauge, replica-policy, and finite-mesh Fourier
evidence in read-only versioned JSON/HDF5 artifacts. A 2.4--2.9 restart preserves accepted physical state but clears
formula-dependent U/CG/L-BFGS history with an explicit non-bitwise compatibility
record. Schema-2.7 joint restarts preserve accepted physical arrays while
resetting legacy joint/CG history; diagnostic two-stage seals are never
promoted. Current checkpoint HDF5 wire `3.0` embeds fixed-subspace mathematical
payload `2.0`; standalone fixed-subspace publication is retired. Periodic and
terminal persistence replace the checkpoint through the IO publication lifetime.
Historical wire descriptions do not grant current reader compatibility. See
[the current format inventory](STORAGE_SCHEMAS.md).
Terminal persistence distinguishes attempted, accepted, and persisted
iterations. Every numerical termination retains only the last finite,
invariant-valid accepted state; rejected trials remain diagnostics and never
replace restart arrays. Packed model format `3.0` stores mathematical operator
values, units, geometry and consumed definitions. Ordinary readers require
this current format. See [storage formats](STORAGE_SCHEMAS.md).
`TightBindingConstruction.jl` remains a separate downstream
boundary and reuses the center-aware Wigner-Seitz transform from the lower
`MatrixElements` layer. The final SPN, spin-times-Hamiltonian, sIu, and sHu
payloads use that same orbital-pair-dependent tied-image distribution and bind
their strict q-to-R-to-q residuals into the operator-qualification digest;
the generic scalar-degeneracy Fourier path is not valid for this storage.
`WannierizationOutputs.jl` performs formal TB
write/readback and Packed HDF5 publication. `TBSymmetryQualification.jl` reuses
the shared real-space covariance/projection backend to qualify that exact
readback TB before terminal checkpoint publication. Its identity gate compares
the representation authority-contract digest and gauge-artifact digest against
the digest-bound Hamiltonian qualification inputs, while retaining the distinct
materialized-Hamiltonian data digest at the bundle root. `WannierizationOutputs.jl`
also owns the human-readable progress output and checkpoint-to-packed provenance
binding.

#### PAW band-sewing and Wannier matrix-element boundaries

Band sewing has two explicit contracts. `CoefficientMappingSewing()` preserves
the historical coefficient-space map. `AugmentationAwareSewing()` evaluates
the q=0 physical PAW metric on the symmetry-transformed state, using the target-k
projector basis and `Cdagger C + Pdagger Q0 P`; it never falls back to the first
route. Physical finite-b MMN/AMN remain separate operator-specific paths in the
heavy `WannierNLQGWannierizationExt` PAW backend:

The strict pre-polar audit keeps spectral S-reconstruction and maximum-state
leakage distinct, splits absolute group closure from its fitted projective
cocycle, and seals unitary eigenvalue or antiunitary-square little-group
fingerprints per energy block. These records are bound into the current
BandRepresentation wire schema 1.0 and public checkpoint schema 1.1 digests.

1. `VASPWavefunctions.jl` reads full-cutoff, unnormalized WAVECAR coefficients.
2. `VASPPawData.jl` parses typed POTCAR radial channels, projectors, partial
   waves, and the atom/channel layout.
3. `VASPPawMatrixElements.jl` constructs shared projectors and
   operator-specific pseudo-plus-augmentation matrices. It never constructs a
   three-dimensional all-electron wavefunction.
4. `WannierMMNTopology` admits only neighbour indices and reciprocal shifts to
   native generation. Oracle values enter only post-generation qualification.
5. A failed native parity result is standard and fails before SAWF, TB
   construction, or response evaluation.

Native AMN additionally requires a same-run OUTCAR. A typed projection
contract validates the WIN column order against LOCPROJ, maps centers to
`[-0.5,0.5)`, rotates each local spin through VASP's Euler/SU(2) columns, and
normalizes the complete trial with `g^dagger g+d^dagger Qd`. Its hydrogenic
radial backend reproduces VASP's logarithmic real-space grid, composite Simpson
weights, 1000-point momentum grid, and clamped/natural cubic spline. AMN uses
the integrated AE-minus-PS q=0 `CQIJ` representation for both trial
normalization and augmentation; finite-b MMN remains on the established
POTCAR-tabulated augmentation representation. These are operator-specific
numerical representations of the same PAW identity and are never added again at
the TB layer.

The raw PAW AMN is an immutable oracle-facing boundary. The native workflow
persists it as `native_paw.amn`, then `VASPPawMatrixElements.jl` applies the
solver-only right-column map `D_T(k) U_q^dagger` and persists the result as
`native_paw.wannierization.amn`. `WannierizationWorkflow.jl` passes only that solver AMN
to the SAWF initializer; external Wannier/legacy AMN bypasses this adapter.
The typed result exposes both `amn` and `solver_amn`, while provenance schema
1.2 records independent hashes and invariance diagnostics. This boundary does
not alter the representation, MMN, raw parity, solver objective, retraction, or
Armijo line search.

The finite-b convention established by GeS oracle parity uses the POTCAR radial
grid in Angstrom, reciprocal vectors in inverse Angstrom, and the
`exp(+i G.R)` projector convention. The projector product absorbs the
`k_right-k_left` atomic rephasing; only an integer reciprocal shift contributes
an additional `exp(-i 2pi G_shift.R)` factor. Adding the full-b atomic phase a
second time is forbidden.

The public source types are `ExternalOverlapProjectionMatrices` and
`NativeVASPPAWMatrices`. Legacy `mmn_file` plus `amn_file` configuration maps to
the external type. Public pseudo-only VASP AMN generation is disabled.

The QE native reader retains two private purposes. The default
`:band_representation` admits
norm-conserving, PAW, and USPP coefficients into the source-neutral canonical
coefficient-mapping builder and records the metric/gauge limitation in
`BandRepresentation.conventions`. The generic `:physical_overlap` purpose
retains its NC-only native-AMN contract; the strict sewing beta/Q path is not an
implicit AMN fallback. QE PAW/USPP MMN and AMN therefore enter through
`ExternalOverlapProjectionMatrices`; native AMN generation
and every claimed generalized-overlap operation fail closed with
`QE_AUGMENTATION_METRIC_REQUIRED`. The strict sewing reader is a third,
backend-selected path: it requires full-cutoff raw coefficients, reuses the UPF
beta/Q q=0 metric, records physical pre-polar gates, and writes Band wire schema 1.0.
VASP strict sewing analogously reuses POTCAR projector/Q0 data. This changes
neither the top-level facade nor the ordinary grouped `TaskConfig/run` path.

### Responses

`Responses` owns formula kernels and response workspaces for shift current,
injection current, quantum geometry, and Wilson/geometric-loop quantities. It may
combine matrix-element objects but may not read files, choose output paths, or own
MPI/progress state.

`Responses/Responses.jl` is the only composition root. It contains ordered
`include` statements and the frozen explicit expert export list, but no formula
implementation. Response files are owned by the physical effect named in their
directory:

```text
Responses/
├── Responses.jl
├── Shared/
│   ├── ResponseWorkspaces.jl
│   ├── ResponseKernelHelpers.jl
│   ├── ResponseFrequencyContraction.jl
│   ├── GeometricLoopCovariantKernels.jl
│   ├── LoopCurrentSharedKernels.jl
│   └── WilsonLoopResponseKernels.jl
├── ShiftCurrent/
│   ├── ConventionalShiftCurrent.jl
│   ├── ProjectorShiftCurrent.jl
│   ├── GeometricLoopShiftCurrent.jl
│   └── WilsonLoopShiftCurrent.jl
├── PhotonDragShiftCurrent/
│   └── GeometricLoopPhotonDragShiftCurrent.jl
├── InjectionCurrent/
│   └── ConventionalInjectionCurrent.jl
├── PhotonDragInjectionCurrent/
│   └── ConventionalPhotonDragInjectionCurrent.jl
├── ShiftSpinCurrent/
│   └── ConventionalShiftSpinCurrent.jl
├── InjectionSpinCurrent/
│   └── ConventionalInjectionSpinCurrent.jl
└── QuantumGeometry/
    ├── ConventionalQuantumGeometry.jl
    ├── QuantumGeometryDerivatives.jl
    ├── ProjectorQuantumGeometry.jl
    ├── GeometricLoopQuantumGeometry.jl
    ├── WilsonLoopQuantumGeometry.jl
    ├── GeometricLoopShiftVector.jl
    └── WilsonLoopShiftVector.jl
```

Only genuinely cross-effect formula kernels belong in `Shared/`. Reference,
scratch, block, and fused overloads of the same generic function stay adjacent.
Shift-vector implementations are quantum-geometry responses; photon-drag and
spin-current implementations remain separate from their zero-momentum or charge
counterparts even when they reuse a shared kernel.

MatrixElements owns one typed Convention-frame transport primitive used by thin
Wilson and Geometric wrappers. Its Convention-I connector is the identity, while
Convention II inserts `D_tau(k_left) * D_tau(k_right)'` before the right source
eigenvectors. Geometric Shift Current and finite-q Photon Drag Shift Current
form the complete shifted velocity insertion before projection. Geometric Loop
QHC is unsupported in 1.2 and rejected by ordinary and retained expert entries. Their expert
kernel then restricts both link transport and explicit connection actions to the
requested central degeneracy blocks, takes a centered difference, and adds
`-i*a_VV*J_VC+i*J_VC*a_CC`. A worker-local `BitArray` cache is keyed by the
valence/conduction group starts and insertion direction, with the derivative axis
stored separately. Shift Vector remains a closed complex-log loop and therefore
uses the covariant edges without an additional open-block connection action.
Links, phase scratch, aligned connections, block scratch, and response tensors are
worker-local and preallocated. A single-k-point kernel must not create
Julia threads or retain caches whose size grows with the number of k points or
nominal band pairs.

### Shared interpolation cache

`src/MatrixElements/Interpolated/SharedInterpolationCache.jl` owns a bounded,
run-scoped cache for raw Fourier matrices and compatible eigensystems. Its
qualified internal entrypoints are `SharedInterpolationCache`,
`begin_shared_interpolation!`, `with_shared_interpolation`, and
`shared_interpolation_stats`. Runtime supplies the run lifetime and execution
context; MatrixElements owns numerical keys and interpolation values. Derived
occupation weights, transition screening and response accumulators are not
shared through this cache. Cache hits must reproduce the uncached data exactly.

### Runtime

The TOML frontend is documented in docs/TEXT_INPUT.md. src/IO/TaskInputFiles.jl owns
input byte binding and TOML/record serialization. src/Runtime/TaskInput.jl owns
strict mapping, parse-boundary provenance and resolution through the existing
TaskConfig, task registry and numerical resolver. scripts/wanniernlqg.jl is the
Julia user entrypoint; the Python development runner retains its separate role.
The frontend does not add response formulas, an execution backend or a task registry.

`Runtime` owns grouped `TaskConfig`/`TaskSpec`, shared model/sampling options,
per-task physics/numerics/observable contracts, validation, paths, MPI, progress, metadata,
task bundles, family executors, reductions, result writing orchestration, and
`run`. It compiles each public task into a private `EffectiveTaskConfig` and
`NormalizedTaskSpec` before invoking existing formula drivers. Each task retains
independent physical weights and screening; compatibility is decided from actual
data dependencies, not from the response name alone. Public task results live
under their ID directories, and root metadata indexes them.

Wannier-center convention selection is compiled into the matrix-element plan on
the cold path. Projector stencils consume convention-native projectors and
connections without common-source restoration. Wilson and Geometric workspaces
resolve the same concrete frame connector during construction; their hot link
kernels contain no string or registry branch. The only downstream center-phase
Boolean is private to the Conventional finite-q injection kernel, where it is
derived once during workspace construction.

Planning/TaskRegistry.jl is the single source of truth for legal task triples,
executor and matrix policies, tensor/band/output semantics, Fourier workload
policy, output suffixes, and spin/finite-q requirements. Its immutable
`QUANTITY_SHORT_LABELS` registry owns the unique quantity–calculation labels and
validates complete pair coverage, global label uniqueness, the K-slice terminal
`K`, and `lowercase(short_label) == observable_suffix`. String labels and Symbol
lookup end during validation. NormalizedTaskPlan, IntegralBundlePlan, and
KSliceBundlePlan contain concrete immutable planning data; the execution drivers
do not query the registry.

Bundle orchestration is composed by Runtime/BundleKLoop.jl in this order:

```text
Planning -> Setup -> Execution -> Reduction -> Output
```

Setup/ owns execution state, matrix/workspace assembly, and explicit Fourier
execution planning.
Execution/ owns transition screening, the two method-family sets, and separate
Integral/K-slice drivers. Reduction/ owns deterministic worker/MPI reduction, and
Output/ owns result writing. All files are included into the same Runtime module;
these directories are responsibility boundaries, not Julia submodules.

The two drivers deliberately remain separate and directly readable. Worker-local
mutable state, static outer threading, slot-local Fourier factors, pair/offset
order, and accumulation order are execution invariants.

Response execution separates physical point production from its consumers.
`ResponsePointEvaluator` exposes borrowed worker-owned tensors or selected
observation channels with their declared layout and physical normalization.
`ResponseIntegralPointBuffers` and `ResponseSlicePointBuffers` retain only
worker storage and the original tensor, band/group or metric selection; they
contain no output paths, mesh arrays or local/global reductions. The existing
response-family routines fill these buffers without duplicating their formulas.

`ResponseGridConsumer` owns regular-grid coordinate lookup, prepared Fourier
requests and the destination sink. Integral sinks own quadrature weights and
deterministic lanes; slice sinks retain local values independently of sample
count. `ResponseNodeEvaluator` maps independent adaptive coordinates into the
same point provider. A regular-grid Mixed request remains a real capability
restriction: it does not supply arbitrary-k interpolation. Sampling algorithms
also retain model, operator, temperature, finite-q and physical-expression
requirements. Registering another consumer does not establish missing physics.

The legacy charge/spin/geometry, SHG, JC/THG, spectral and BCD/BCQ drivers use
this common interface while retaining their distinct physical workspace and
output definitions. In particular, total conductivity and a band-selected
geometric observation need not have the same point definition or units. The
JC/THG response-layer measure selectors have been removed. Direct 1x1/2x2 physical inputs complete a three-dimensional reference lattice
with one-Angstrom perpendicular auxiliary vectors in the model layer; the
consumer still samples only physical axes. Existing complete 3x3 declarations
retain their semantics. Periodic low-dimensional point-orbital symmetry uses the
existing representation/covariance/orbit machinery with a physical-subspace and
no-auxiliary-translation check. Model completion does not change true periodicity
or introduce missing model operators.

### Expert API

The package facade exports grouped response configuration types, typed
observable selectors, RunResult, and run. Responses,
Runtime, and the Symmetrization facade use explicit export lists frozen by
test/api_snapshot_unit.jl. Newly introduced planning and setup types are internal
unless an intentional API change updates that snapshot.

The v2 symmetrization expert API is accessed through the full namespace using
typed `MeshScreenConfig`, `SymmetrizationConfig`, `MagneticMomentConfig`, and
`RealSpaceOperatorKind` values. `screen_wannier_mesh` and
`symmetrize_wannier_operators` are the two task-level entry points;
`symmetrize_real_space_operator` is the typed low-level projector interface.
These expert names are not added to the response configuration facade. Stable
real-space operator identities and containers are owned by `Core` and re-exported
by the Symmetrization expert namespace. Packed model-package I/O is owned by
`IO`; `MatrixElements` never owns a file schema.

The workflow uses enum keys throughout and executes inferred complete families in the
fixed order Hamiltonian/position, Wannier derivatives, then spin. Public
configuration calls its general tolerance `symmetry_tolerance`. The response
artifact writer additionally exposes `spglib_symprec_angstrom`; its compatibility
alias `symmetry_tolerance` has the same Angstrom unit and conflicting dual values
fail before backend dispatch. Operator HDF5 uses mathematical model format
`wanniernlqg.real-space-operators/2.0`: one packed payload with a stable component
index, actual operator definitions, units and geometry. Historical qualification
and content-digest protocols do not replace these values. Historical files require
explicit supported migration and are rejected by the ordinary reader.
Runtime never reapplies replica materialization.
Wannier TB remains unchanged; historical response caches are not part of the
v2 architecture.

## Data model

- `Core.TightBindingModel`: lattice, R vectors and degeneracies, Hamiltonian, and
  position matrices.
- `Core.KPointSpectrum`: energies, the public canonical Hamiltonian-gauge
  eigenvector pair, and a private source-gauge pair for legacy-stable transport.
- `RealSpaceOperatorKind` and `RealSpaceOperator`: Core-owned stable identities,
  symmetry metadata, R support, and real-space-last array contract.
- `OperatorBundleManifest`, `PackedCartesianOperator`, and selected component
  views: IO-owned validated access to Packed model format 3.0; historical files
  require external migration and are not reconstructed as a
  durable cache.
- `SpinRealSpaceData` and `SpinVelocityRealSpaceData`: parametric peer
  observables backed by legacy arrays or packed read-only views; neither is
  attached to the model.
- `SpinVelocityMatrixElements.jl`: owns both the seed-to-real-space spin-velocity
  construction and its k-point interpolation. The production `_tb.dat` path is
  fixed to the Convention II `R_only` Bloch basis and never adds a local
  Wannier-center phase.
- `MatrixElementSources`: validates optional operator sources. A
  `SpinVelocityRealSpaceData` composes its `SpinRealSpaceData`; independently
  supplied spin data must be the identical object.
- `OperatorDemandPlan`: Runtime-owned task dependency closure. It validates the
  package inventory before allocation and narrows K-slice Cartesian components
  except for the three position components required by center provenance and
  Convention I assembly.
- `KPointMatrixData`: unique k-point spectrum plus optional Hamiltonian, position,
  spin, and spin-velocity components.
- `ProjectorMatrixData` and `GeometricLoopMatrixData`: algorithm-specific data
  that reference a shared `KPointMatrixData` through `common`.
- `KPointOffset`: an integer finite-difference coefficient tuple plus a photon
  half-step count. It is the cache key; floating-point k arrays are not hashed.

The former Conventional, Spin, and SpinVelocity k-point data/scratch families are
forbidden. `:conventional` remains a Runtime method and output-contract term, not
a matrix-element ownership boundary.

## Source naming and documentation invariants

Every `.jl` basename under `src/` and `ext/` is globally unique. A filename names its
physical effect or technical domain; ambiguous basenames such as `Spin.jl`,
`Conventional.jl`, `Projector.jl`, `GeometricLoop.jl`, `WilsonLoop.jl`, `Plan.jl`,
and `Workspace.jl` are forbidden. Response implementations may only appear in
the matching physical-effect directory, and composition roots may not contain
computational declarations.

Every named top-level function and semantically meaningful type has immediately
preceding documentation. Small internal helpers use a one-line comment. Public
interfaces and functions that encode formulas, gauge, normalization, prefactors,
band/subspace meaning, or tensor indices use a Julia docstring that states the
quantity, conventions, mutation/return contract, normalization owner, and key
invariants. Overload-specific comments describe only their difference. Orphaned
top-level strings, declaration documentation separated by an assignment, and
indented function-body docstrings are rejected by the structure gate.

### Second-harmonic generation

`OpticalPositionDerivatives` owns unregularized endpoint dipoles and finite-eta
generalized derivatives. `SecondHarmonicKernels` owns the seven response terms.
`SecondHarmonicWriters` owns numeric tables. `SecondHarmonicDriver` consumes the
shared sampling scheduler, Fourier planner and deterministic MPI lanes.

### Bounded preparation execution (candidate)

`src/IO/PreparationStorage.jl` implements private, checksum-validated disk vectors and bounded source access. It uses Julia Serialization for process-version-bound workspaces; these files are not a public scientific storage format.

`ext/WannierNLQGWannierizationExt/star_gauge/PreparationExecution.jl` selects dense-oracle or streaming execution, bounds the star launch frontier, owns restart contracts, and reduces diagnostics in canonical order.

`ext/WannierNLQGWannierizationExt/star_gauge/StarPreparationKernel.jl` owns one star's unchanged numerical algebra. Workers return immutable scientific results and own mutable sewing caches; the coordinator writes scientific HDF5 artifacts.

The default expert execution policy is streaming serial. Parallel execution remains opt-in until exact numerical parity and the measured resource/performance gates pass. The outer-window rank remains independent of the final Wannier rank.

`ext/WannierNLQGWannierizationExt/OperatorPublicationReuse.jl` owns compact, input- and implementation-bound receipts for completed native operator publications. Generators validate their target and protected paths before entering this internal reuse layer. Scientific kernels and public result schemas remain owned by the generators.

### First-order spectral response domains

`Responses/LinearTransport/LinearTransport.jl`,
`Responses/LinearOpticalResponse/LinearOpticalResponse.jl`, and
`Responses/OrbitalMagnetization/OrbitalMagnetization.jl` are distinct Julia
submodules. Their kernels share only occupation helpers and the first-order
geometry in MatrixElements. Matrix policy requests reuse existing interpolation
capabilities; the sixteen-capability container does not change. Optional orbital
sources use the existing real-space operator inventory and a separate completion
workspace. Runtime owns shared execution and static/frequency output coordination;
IO owns serialization. See [response contracts](LINEAR_AND_ORBITAL_RESPONSES.md).


### Third-order response domains and numerical request lowering

`Runtime/TaskConfiguration.jl` owns the sole public `Numerics` request, explicit
parameter tracking, applicability checks and quantity defaults. The immutable
private `ThirdOrderSettings` and effective execution fields carry resolved
values; no public old numerical-type names survive outside migration docs and
negative tests. `SeparateRelaxation` remains a physics configuration.

`MatrixElements/Interpolated/ThirdOrderGeometry.jl` owns complete optical
vertices, generalized derivatives and full-band Hessians. It shares the
unchanged SHG rules through a new worker-local output-first routine. The
`Responses/Shared/HarmonicFrequencyKernels.jl` and occupation workspace provide
scalar numerical realization and derivative rules. Physical jerk contractions
live in `Responses/JerkCurrent`; independent THG formulations live in
`Responses/ThirdHarmonicGeneration`. Worker storage is quadratic in band count,
production THG contractions are cubic, and no four-band production tensor is
allocated. `Runtime/Execution/ThirdOrderDriver.jl` uses the existing scheduler,
Fourier plans, deterministic lanes and MPI reduction. SI/measure conversion is
applied once there. `IO/ThirdOrderWriters.jl` owns complex file layout, totals and
numerical diagnostic records. Development reference kernels are archived outside
the formal source tree; physics and material qualification remain separate.

### Representative first-use compilation

`src/FirstUsePrecompileWorkload.jl` composes small deterministic public-API
workloads with PrecompileTools. Ordinary `run(cfg)` workloads cover shared
response trees; native-input workloads enter their distinct derivative,
Fourier and sampling routes. Extension workloads stay in the image owning
those public calls. They use tiny synthetic inputs, bounded temporary output
and serial execution, and never initialize MPI or launch another process.

`src/FirstUse/TinyVASPNativeInputs.jl` owns the pure `TinyVASPNativeInputs`
fixture-builder module. It defines functions without loading optional backends
or writing files. Both native VASP extension workloads call this parent-owned
builder in their own temporary directories. Neither extension includes code
from another extension's implementation tree.

`ext/WannierNLQGSymmetryFoundationExt/RepresentativeVASPBandWorkload.jl`
enters native VASP band construction in the foundation owner.
`ext/WannierNLQGWannierizationExt/RepresentativeVASPPAWWorkload.jl`
enters PAW overlap, projection and nonzero spin construction in the
Wannierization owner. The separate
`ext/WannierNLQGWannierizationExt/RepresentativeQENativeOperatorWorkload.jl`
uses the genuine scalar QE operator-reader call tree.
`ext/WannierNLQGWannierizationExt/PrecompileSupport/TinyWannierWorkflowInputs.jl`
defines the private deterministic two-band/two-k-point workflow input used
within that owner's workloads.

A small explicit residual layer retains measured public boundaries and
foreign method compilation only. Disabled historical trace declarations remain
as historical source evidence; they are not the active implementation. Workload
purposes, residual evidence and independent qualification are documented in
`docs/DEVELOPMENT.md`. Full path qualification remains
separate from workload count. Package-image warmth does not eliminate process,
MPI or native-library initialization; first-call measurements record Julia
compilation separately from total time. Development checks do not establish
publication readiness.


## Explicit Full MPI rank profiles

Full keeps the seven-task inventory and defaults to `legacy16`: raw-Z and U
localization use 1/2/4/8/16 ranks, adaptive uses 1/16, and MPI-only requires
17 slots including its driver. An explicitly approved bounded run may select
`--mpi-profile bounded11 --cpu-budget 12 --jobs 2`: raw-Z/U use 1/2/4/8/11,
adaptive uses 1/11, and all other MPI cases remain unchanged. Numerical cases,
tolerances, exact serial comparisons and collective failure recovery are retained.

The canonical profile file is `scripts/test_support/full_rank_profiles.json`.
The scheduler, Julia MPI test wrappers, literal ownership catalog and typed
qualification use that same declared profile. Requests and summaries record the
rank plan and untested scope. Lowering the budget without changing the selected
profile is rejected. MPI-only remains exclusive; all rank processes plus the
driver count against the profile budget. RSS/swap/disk/ownership guards are unchanged.

A bounded11 result does **not** test the 16-rank scale. It also does not exercise
the original U-localization 12-edge or adaptive 15-node *normal empty-owner*
endpoints at 16 ranks. Raw-Z's two-k-point empty owners and adaptive's root-first
failure with empty peers plus collective recovery remain tested. Do not relabel
these remaining boundaries as covered or transfer old source PASS evidence.


Automatic band geometry lives in `SymmetryFoundation/HighSymmetryBandPaths.jl`,
using Brillouin and Spglib as ordinary dependencies. `Runtime/BandTaskInput.jl`
owns text resolution and public `KPath` construction; IO owns the TB header
lattice reader. The existing Band kernel, Hamiltonian Fourier convention and
thread/MPI evaluation remain unchanged. Connected branch ranges belong to cold
path planning; the spectrum loop still evaluates the same ordered k-point matrix.

The three-trigger symmetry compiler owner includes `RepresentativeAutomaticBandWorkload.jl`:
two minimal text inputs enter the actual public resolution and Band `run` through
3D crystal and explicit2D-plane geometry. Its TOML import is an existing stdlib
dependency; all files and result records live in one cleaned temporary directory.
The same owner also captures geometry planning. It does not initialize or
launch MPI; these workloads remain compiler coverage rather than material qualification.
Measured normal automatic TOML calls activated this owner and the operator owner,
while the five-trigger owner stayed absent. The earlier five-trigger placement
therefore left2.01–2.57s compilation; the moved workload requires a new clean
cache and the independent fresh-entrance qualification before latency PASS.


The public high-symmetry path validates axes and tolerance before loading its
existing symmetry extension. A single world-age-safe handoff then enters the
unchanged geometry implementation after that cache is available. It avoids
inferring the whole geometry subtree while the enclosing TOML resolver still
has not loaded the image that owns its representative workload. Extension
loading stays inside the actual first public call; no benchmark preload is
introduced. Geometry arithmetic and its operation order are unchanged.

The text read facade uses the canonical quantity normalizer only as a cache
activation hint: automatic Band inputs with actual structure and no manual
nodes load their existing symmetry image before a world-age-safe resolver
handoff. Malformed or other requests remain the canonical resolver's authority;
this hint adds no input aliases or validation policy. Other task inputs do not
activate symmetry through this hint. No geometry, model or computation is
pre-warmed, and the public timer includes the actual loading.

Runtime requests this activation through the non-exported integration port
`activate_symmetry_foundation_backend!`, declared by SymmetryFoundation. The
underscored loader remains private to its owner; no structure-check exception
permits sibling imports of it. The port only loads the existing backend and
returns `nothing`, leaving geometry and input-validation authority unchanged.

## Paired photon momentum orchestration

Runtime Planning owns the copied, finite zipped axis and exact momentum groups.
Execution binds original-row views to existing deterministic response lanes and
reuses one finite-q screen/workspace per worker, in frequency blocks of at most
32 rows. The existing MatrixElements shared interpolation cache retains owned
raw matrix/eigensystem snapshots within explicit entry/payload bounds. For bounded
fixed-orthonormal two-dimensional endpoints, optional snapshots may also restore
the complete original canonical/source H-derivative and raw/internal-A capability
set in the exact saved spectral frame. Both numerical stamps and all four arrays
are restored; no partial-ready state is introduced. These optional snapshots are
admitted conservatively and are discarded before original raw/spectrum eviction. Responses
keeps the original finite-q formulas. IO alone writes and reads the tensor-bound
versioned paired-axis record. Fixed-q cache statistics retain their original
metadata field set. These boundaries add no upward dependency or public export.


For a conventional bundle containing ISC but no conventional SC consumer, Runtime
may omit only the SC-specific generalized-derivative buffers, SC kernel and local
SC spectrum from the existing `ShiftCurrentConventionalWorkspace`. Its matrix
workspace/data and frequency-contraction scratch remain unchanged. Mixed SC/ISC
bundles and default/positional expert construction retain complete SC buffers.
This demand is resolved once per request; no lazy shared allocation or new cache
is introduced, and the worker owns every remaining mutable buffer.


### K-slice injection-spin single-component consumption

The K-slice conventional injection-spin family consumes its one selected component
straight from prepared matrix data. It retains the original ordered pair kernel
expression, mask zero contributions and scalar weighted sum, without a rank-six
intermediate response tensor. Integral and the existing Array6 expert kernel and
component methods retain their complete storage contract. Each worker continues
to own its prepared matrix data and slice cells; no shared mutable cache is added.

K-slice conventional-current workspace setup explicitly disables unused frequency
contraction scratch (and SSC pair weights). Omitted fields are `nothing`; the
scalar response component kernels do not read them. Integral and Adaptive retain
full default contraction storage even for a single photon energy.

## Response execution responsibility split

IntegralFamilies.jl and KSliceFamilies.jl are ordered composition roots. Their
existing methods are included without changing mathematical bodies or definition
order from physical-effect execution files:

|Composition root|Included physical owners, in order|
|---|---|
|IntegralFamilies|ConventionalCurrentIntegralExecution, ProjectorShiftCurrentExecution, GeometricShiftCurrentExecution, WilsonShiftCurrentExecution, PhotonDragInjectionExecution|
|KSliceFamilies|ConventionalCurrentKSliceExecution, ConventionalGeometryKSliceExecution, ProjectorQuantumConnectionKSliceExecution, GeometricQuantumConnectionKSliceExecution, WilsonQuantumConnectionKSliceExecution|

Setup/ConventionalCurrentWorkerWorkspaces.jl owns only cold per-worker allocation
mechanisms used by IntegralDriver and KSliceDriver. Both callers explicitly pass
shift-current and frequency-consumer demand; the Responses factories, numerical
kernels and public expert defaults remain unchanged. Every slot borrows the same
declared matrix/data reference and owns its response scratch. Integral and K-slice
retain distinct frequency/full-tensor versus scalar semantics. This adds no task
engine, cache, runtime policy to Responses, or alternate scheduler.

The non-exported MatrixElements integration tuple explicitly declares the existing active-velocity workspace, admission predicate, derivative producer, one-way and paired insertion producers, and complete spectral-subspace partition reader used across Responses and Runtime. Each keeps its own physical contract: worker-private scratch, complete intermediate bands, current-call endpoint reuse, and independent ordered overlaps. Adding an implementation reader requires a named integration contract; the structural checker remains authoritative.

Current W1.4 restart input boundaries are implemented in
`ext/WannierNLQGWannierizationExt/solver/WannierizationRestartInputDefinitions.jl`
and `ext/WannierNLQGWannierizationExt/hdf5/WannierizationRestartInputIO.jl`.
They preserve complete input values separately from accepted output state and
keep raw historical states explicitly unavailable for continuation when their
original inputs were not recorded.

## Text preparation workflow boundary

The cold Runtime TOML facade has direct one-way dependencies on Wannierization
and Symmetrization for their existing configuration constructors, pure validation
and public workflow calls. Those domain modules do not depend on Runtime.
The existing IO task-input reader/writer remains the sole TOML file boundary.
No response kernel, solver, projector or ESKernel implementation is duplicated.

### Explicit composite workload capture

The five-trigger Wannierization precompile extension defines its representative
workflows without executing sibling APIs during package cache creation. The
external matched-image workload explicitly loads and checks the sibling extensions,
then invokes the preparation/localization/restart, symmetrization and PAW audit
workflows. Numerical implementations and normal entrypoints are unchanged.

The non-exported `wannier_pair_wigner_seitz_plan_from_images` MatrixElements port
accepts ownership of nearest-image lists from a single Wannierization export.
Geometry, tolerance and support must match that invocation; no cross-call cache
or public constructor contract is changed.

The non-exported IO port `read_hdf5_attribute_value` is implemented by the
operator-bundle HDF5 extension. WN publication metadata consumers use its scalar
fixed-string runtime buffer path; other types retain HDF5's original reader.
It borrows the attribute and closes only its own datatype/dataspace handles.
No file schema or publication equality check changes.

## Maintained Wannierization application entry

`Runtime.run_wannier_application` is the common, unexported execution boundary
for the existing CLI workflow, explicit capture workloads and fresh-process
first use. It delegates to the existing Wannierization public implementation;
MPI ownership, failures, checkpoint schemas and scientific decisions are unchanged.
The path overload uses the existing text input resolution. CLI resolution records
remain owned by `run_task_input`; the application does not add benchmark reports.
Material parameters, assertions, timers and reference readback stay in external
test workloads. A cached test harness is not evidence that this package entry
was covered: fresh-process checks must verify the actual owner and invocation.
See the shared maintained-precompilation skill contract for cache invalidation.

### Shared HDF5 attribute reading

IO owns the attribute-reading algorithm with an explicit, already imported HDF5
module argument. Its datatype, scalar/string, padding and temporary-handle rules
are shared by the operator-bundle adapter and Wannierization readers. The typed
one-argument operator-bundle port remains available. Wannierization passes its
own HDF5 backend directly so isolated extension precompilation does not depend
on the loading order of a sibling extension. This changes no persisted schema,
operator values or attribute conversion rules.

### Optional normalized metric optical vertices

`src/MatrixElements/NonorthogonalOpticalCutoffVertices.jl` owns the optional
local normalized H/S/r source jet for cutoff optical matrix elements.
`OPTICAL_CUTOFF_VERTICES` allocates it only on request; ordinary metric scalar
geometry and its expert r_eta/G_Deta interface remain independent. SHG consumes
r0/Gcut without replacing the existing BCD or energy Hessian.


## Response points and consumers

The internal response point plan binds a physical evaluator to one worker's matrix-element workspace, response scratch and interpolation generation. Its value contract records shape, the retained density or moment units, and whether arbitrary points are supported. Returned scratch is borrowed; a consumer owns a copy before the next visit. Quadrature weights, domain-coordinate mapping, deterministic accumulation, global reduction and file output belong to consumers. No second physical formula is introduced for adaptive sampling.

The first migration exposes these plans for the existing SC/IC/SHG, orthogonal THG and BCDC/BCQC adaptive routes. The map collector and adaptive consumer can use the same worker plan. Regular-grid Fourier requests retain their grid context and do not acquire arbitrary-point capability. Model/operator/band requirements remain attached to the physical plan; a sampling choice does not supply missing overlap derivatives, spin operators or nonlocal links.

Further uniform and slice migration must preserve each original arithmetic boundary. In particular, SC/IC uniform accumulation adds transition contributions directly to deterministic lanes; replacing that sequence with a sum of pre-accumulated point tensors may change rounding. A compatible accumulation consumer must retain the original order before that route is migrated. Other applicable response families can migrate in stages, using old-path equality, matrix-element/cache ownership, one application of units and reduction, failure recovery and concurrent execution as acceptance checks. Nonlocal observables require their actual multi-point or link contract rather than an invented local density.

MPI adaptive integration keeps one controller-owned tree and global budget. It evaluates a bounded packet of nodes within a numerical rule concurrently, then consumes results through the original rule in its original order. The one-rank route remains the dependency's serial implementation. The controller adapter is tied to the qualified HCubature 1.8.0 implementation; it does not change the norm, rule weights, heap decisions or complete-rule budget. See [adaptive integration](ADAPTIVE_INTEGRATION.md) for numerical and physical limits.
