# Architecture

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
higher layer.

The recursive, machine-checked file inventory for the shared and expert layers
is maintained in [ARCHITECTURE_IMPLEMENTATION_INVENTORY.md](ARCHITECTURE_IMPLEMENTATION_INVENTORY.md).

### Project extension triggers versus source dependencies

`Project.toml` extension triggers are activation conditions, not complete source
dependency declarations:

| Extension | Project extension triggers | Additional direct source dependencies |
|---|---|---|
| `WannierNLQGOperatorBundleExt` | `HDF5`, `JSON3` | `Dates`, `SHA`, `WannierNLQG`, `Core`, `IO` |
| `WannierNLQGSymmetryFoundationExt` | `Spglib`, `HDF5`, `JSON3` | `Dates`, `LinearAlgebra`, `Printf`, `SHA`, `WannierNLQG`, `Core`, `IO`, `SymmetryFoundation` |
| `WannierNLQGSymmetrizationExt` | `HDF5`, `JSON3`, `EzXML` | `Dates`, `EzXML`, `LinearAlgebra`, `Printf`, `SHA`, `WannierNLQG`, `Core`, `IO`, `MatrixElements`, `Symmetrization`, `SymmetryFoundation`, `WannierProjection` |
| `WannierNLQGWannierizationExt` | `HDF5`, `JSON3`, `EzXML` | `Dates`, `FFTW`, `LinearAlgebra`, `MPI`, `Printf`, `Random`, `SHA`, `WannierNLQG`, `Core`, `IO`, `MatrixElements`, `SymmetryFoundation`, `WannierProjection`, `Wannierization` |

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

### IO

`IO` owns parsers and writers: the Wannier TB/SPN/CHK/EIG/MMN/uIu formats,
streaming Fortran records, response tensors, K-slice files, and atomic Band tables. It constructs data-transfer
objects but never diagonalizes a Hamiltonian or builds k-point matrix elements.
`WannierTBWriter.jl` is the unique `_tb.dat` production writer.

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
These ports preserve the public export list and representation fields. The extension is triggered only by `HDF5`, `JSON3`, and
`EzXML`. Its loader checks `Base.get_extension` without a lock, rechecks under one
`ReentrantLock`, imports those triggers in the fixed order, and bridges facade
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

The extension depends on `Core`, `IO`, `MatrixElements`, `SymmetryFoundation`,
`WannierProjection`, and its own facade. It cannot depend on `Wannierization`,
`Responses`, or `Runtime`. Spglib detection, representation building/persistence,
projection parsing/materialization, TB writing, replica mapping, and derivative
construction are consumed from their unique lower-layer owners rather than
reimplemented here. MatrixElements capabilities cross this boundary only through
its named, non-exported integration API; the structure contract rejects direct
calls to underscored MatrixElements helpers. `SymmetrizationConfig` has no uIu field, and this
extension does not own exact uIu derivative construction.

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
`src/Wannierization`; little-group algebra, the pinned upstream-compatibility
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
├── ProjectionRepresentationCompatibility.jl
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
`SymmetryAdaptedWannierizationConfig`, `WannierizationResult`, and
`construct_symmetry_adapted_wannier_functions`. Other supported expert names
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
├── WannierUIUGeneration.jl
├── WannierHamiltonianOperatorGeneration.jl
├── QEPAWSpinMatrixElements.jl
├── AuthoritativeBandHamiltonian.jl
├── OperatorProfileAssembly.jl
├── ExactWannierDerivativeOperators.jl
├── ExactWannierOperatorBundle.jl
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

`SymmetryAdaptedWannierizationConfig` now contains exactly five groups:
`input` (26 fields), `solver` (20), `checkpoint` (4), `runtime` (2), and
`output` (19). The 71 old constructor keywords have no compatibility constructor;
the complete migration map is in `WANNIERIZATION_CONFIG_MIGRATION.md`. The five
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
canonical trajectory representation, current digest, and every accepted legacy
digest. Public checkpoint schema 1.0 retains the former 2.28 persisted HDF5
fields, `input_summary` keys, scientific restart identity and legacy acceptance
rules. Storage digest selection uses the file's recorded wire version; version-
dependent storage digests are regenerated only when writing a new file.

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
Hamiltonian to TB and every weighted operator. `ExactWannierDerivativeOperators.jl` computes the
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
an old Band artifact fails explicitly even if its other formats remain readable. The default plane-wave adapters
normalize source data and delegate to the canonical coefficient-map builder;
the expert strict adapter retains full-cutoff raw coefficients and delegates to
`AugmentationAwareBandSewing.jl`.
The split `hdf5/` implementation writes public checkpoint schema 1.0 with the
complete legacy 2.28 contract; schemas 2.0--2.28 remain readable under their
declared compatibility policy, while 2.0--2.3 are restart-semantics incompatible. Schema 2.5 binds
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
diagnostic-only and reset U/CG history. Their symmetry-expanded U frames are
conditioned-polar restored inside the sealed projector, preserving the fixed-Z
ablation contract without touching the default full-Type-IV path.
`WannierGaugeChainDiagnostics.jl`
separates projector, link/gauge, replica-policy, and finite-mesh Fourier
evidence in read-only versioned JSON/HDF5 artifacts. A 2.4--2.9 restart preserves accepted physical state but clears
formula-dependent U/CG/L-BFGS history with an explicit non-bitwise compatibility
record. Schema-2.7 joint restarts preserve accepted physical arrays while
resetting legacy joint/CG history; diagnostic two-stage seals are never
promoted. The extension also owns the
`wanniernlqg.wannierization-fixed-subspace` wire-`1.0` boundary, retaining the
complete former `1.1` contract and read-only compatibility with historical
`wanniernlqg.sawf-fixed-subspace` capsules. Periodic and terminal solver states atomically
replace one fixed checkpoint path; `.wannierization.validated.h5` separately retains the
latest converged, representation-compatible, finite, TB-roundtrip-validated
checkpoint. Checkpoint and Packed HDF5 manifests retain independent scientific
and input digests; production eligibility is independent of center policy while
the geometry contract remains strict.
Terminal persistence distinguishes attempted, accepted, and persisted
iterations. Every numerical termination retains only the last finite,
invariant-valid accepted state; rejected trials remain diagnostics and never
replace restart arrays. Packed-HDF5 schema 1.0 records the selected operator
profile, solver convergence, Hamiltonian authority, formal source hashes,
closure qualification, per-operator source/gauge/symmetry qualification,
physics qualification, TB usability, and the same final-TB qualification
payload independently. The physical-metric band-frame summary binds sealed
PAW/USPP transforms and replay evidence. Schema-6.0 spin/full packages are
`LEGACY_NOT_RECORDED` and diagnostic-only; schema-5.x non-spin packages likewise
cannot be promoted to schema-1.0 formal status. Nonidentity-frame schema-6.1
spin/full packages are `LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED`; schema-6.2
full packages are `LEGACY_GALERKIN_RISK_CONTRACT_NOT_RECORDED`.
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
BandRepresentation wire schema 1.0 and public checkpoint schema 1.0 digests
(with legacy checkpoint digest verification retained).

1. `VASPWavefunctions.jl` reads full-cutoff, unnormalized WAVECAR coefficients.
2. `VASPPawData.jl` parses typed POTCAR radial channels, projectors, partial
   waves, and the atom/channel layout.
3. `VASPPawMatrixElements.jl` constructs shared projectors and
   operator-specific pseudo-plus-augmentation matrices. It never constructs a
   three-dimensional all-electron wavefunction.
4. `WannierMMNTopology` admits only neighbour indices and reciprocal shifts to
   native generation. Oracle values enter only post-generation qualification.
5. A failed native parity result is diagnostic-only and fails before SAWF, TB
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
to the SAWF initializer; external Wannier90/legacy AMN bypasses this adapter.
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

The public source types are `ExternalWannier90Matrices` and
`NativeVASPPAWMatrices`. Legacy `mmn_file` plus `amn_file` configuration maps to
the external type. Public pseudo-only VASP AMN generation is disabled.

The QE native reader retains two private purposes. The default
`:band_representation` admits
norm-conserving, PAW, and USPP coefficients into the source-neutral canonical
coefficient-mapping builder and records the metric/gauge limitation in
`BandRepresentation.conventions`. The generic `:physical_overlap` purpose
retains its NC-only native-AMN contract; the strict sewing beta/Q path is not an
implicit AMN fallback. QE PAW/USPP MMN and AMN therefore enter through
`ExternalWannier90Matrices`; native AMN generation
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
eigenvectors. Geometric Shift Current, finite-q Photon Drag Shift Current, and QHC
form the complete shifted velocity insertion before projection. Their expert
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
fail before backend dispatch. Operator HDF5 uses strict semantic writer
schema `wanniernlqg.real-space-operators/1.0`: one packed payload with a stable
component index, hashed raw-to-final geometry lifecycle, exact profile inventory,
Hamiltonian authority, formal full-profile source/risk provenance, and
digest-bound `/qualification/operators`, `/qualification/families/spin`, and
`/qualification/families/finite_band_galerkin` records. Schema 5.x and
spin-bearing schemas 6.0/6.1 remain diagnostic readback only
when their required physical band-frame contract was not recorded;
schema-6.2 full packages remain diagnostic when the Galerkin risk contract was
not recorded;
Runtime never reapplies replica materialization.
Wannier90 TB remains unchanged; historical response caches are not part of the
v2 architecture.

## Data model

- `Core.TightBindingModel`: lattice, R vectors and degeneracies, Hamiltonian, and
  position matrices.
- `Core.KPointSpectrum`: energies, the public canonical Hamiltonian-gauge
  eigenvector pair, and a private source-gauge pair for legacy-stable transport.
- `RealSpaceOperatorKind` and `RealSpaceOperator`: Core-owned stable identities,
  symmetry metadata, R support, and real-space-last array contract.
- `OperatorBundleManifest`, `PackedCartesianOperator`, and selected component
  views: IO-owned validated access to Packed HDF5 1.0, supported legacy 6.3 and diagnostic legacy 5.x/6.0/6.1/6.2
  without reconstructing a
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
