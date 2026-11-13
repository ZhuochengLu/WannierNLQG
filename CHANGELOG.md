# Changelog

Current local software identity: **1.2.0**. This is the public source profile; remote publication is separate.


## Input validation and Wannierization reports

- Check every explicit TOML numerical value before resolving legal overrides.
- Keep detailed validation in JSON and summarize human-readable output with
  aligned metric labels, units, visible failures and grouped warnings.

## Geometry and Wannier mesh inputs

- Add direct standard-axis 1D/2D native model inputs with fixed one-Angstrom auxiliary reference directions, shared bulk normalization and unchanged physical sampling dimension. Existing complete 3x3 model inputs retain their original semantics.

- Conventional scalar geometry now defaults to an explicit zero-regularization branch;
  supplied positive widths keep their existing regularized expressions.
- Ordinary Quantum Metric and its derivatives default to internal contributions;
  `include_external=true` retains qualified orthogonal completion and is explicitly
  unsupported for nonorthogonal input. Nonorthogonal internal H/S/r tasks share
  the same configuration framework.
- Read and validate VASP/QE mesh declarations against actual ordered wavefunctions
  or external matrix point lists. Preserve explicit input and reject conflicts.
- See [migration and numerical compatibility](docs/GEOMETRY_OPTIONS_MIGRATION.md).

## Shared response point kernels, integration and slice densities

- Separate worker-owned physical point evaluation from regular-grid, adaptive
  integration and slice consumers across existing charge, spin, geometric,
  spectral, second-order, third-order and Berry-multipole response families.
- Add intrinsic anomalous Hall and BCD/BCQ conductivity slices, and retain the
  declared finite-model Conventional nonorthogonal orbital moment in slices.
- Remove the sample-count integration weight from legacy current slices;
  preserve response-specific physical coefficients and units. Integral weights
  remain in the integration consumer.
- Execute multiple nodes of an adaptive rule concurrently with MPI while retaining
  the global tree, tensor norm, complete-rule budget and summation order.
- Validate periodic direct low-dimensional point-orbital symmetry using the
  existing model, representation, covariance and orbit machinery, with no mixing
  or translation into auxiliary directions. Strictly one-dimensional BCD/BCQ
  uses the existing zero Berry two-form rather than adding transverse dynamics.

## Local 1.2.0: unified Numerics and third-order responses

- Breaking API: all tasks use `Numerics`; retired numerical constructors are removed without aliases. Optical, low-frequency, static-gap and Fermi-surface controls remain independent.
- Add ordered jerk current (`JC/JCK`) and independent optimized THG (`THG/THGK`), complex tensors, terms and observables. Periodic results use reference-cell volume normalization; the retired response-level measure/thickness conversion fields explicitly fail and conversions belong to postprocessing.
- Keep existing response formulas, default values, filenames, column layouts and summation order.
- Jerk acceleration-channel and THG applicability and broadening conventions are
  documented in [third-order responses](docs/THIRD_ORDER_RESPONSES.md); no complete
  degenerate-block extension or material-convergence qualification is asserted.
- Local implementation evidence and reference code are archived separately from the release source.

This changelog records user-visible differences between public WannierNLQG
releases. Version 1.0.0 establishes the public baseline; each later entry will
describe changes relative to the preceding public tag.

## 1.2.0 — Fixed point-orbital model inputs

- Add native Julia real-space hopping and direct analytic Hamiltonian inputs,
  using the ordinary response registry with each basis and operator requirement.
- Require explicit orbital centers and constant local spin matrices; derive
  position, overlap and weighted operators from the finite point-orbital basis.
- Add explicit/ForwardDiff/opt-in finite-difference derivatives with actual-use
  evidence, bounded Cartesian integration and dimension-aware response units.
- Add model-bound periodic symmetry declarations, Bloch representation validation
  and hard covariance checks before supported q=0 response reduction.
- Inherit the latest v1.1.0 three-mechanism linear-response output contract,
  including its transport schema /2.0; unrelated storage schemas are unchanged.

## 1.1.1 — Local maintenance

- Retain multiple operator/offset/block FFT results within the existing
  per-workspace memory limit. Least-recently-used eviction reuses a compatible
  FFT buffer and plan when possible. Integral k-point order, response formulas,
  and deterministic reduction lanes remain unchanged.
- Report Mixed-FFT cache evictions alongside FFT calls, hits, and peak memory.

- Include source-owned first-use precompile coverage and attribution maintenance.
- Guard captured compiler signatures by their originating Julia 1.11.2 version,
  retaining the declared Julia 1.10 support and portable bounded workloads.
  Use an explicit parent-module binding at the affected workload boundary.
- Repack three HDF5 fixtures to remove unreachable private path bytes while
  preserving all active fields and numerical bits; bind their new physical hashes.
- Migrate three Julia-serialized preparation caches with their actual types in
  an external Julia 1.11.2 copy. Change only allowlisted string locators and the
  coupled band-frame contract filename; root relative paths and the expert
  probe's working directory in the portable fixture. Preserve UPF/SPN blocks,
  scientific bits, status fields, input hashes and historical code/input bindings.
- Extend release privacy checks to raw binary bytes and exclude OS metadata.
- Correct independent storage-format documentation and historical release
  identities; adopt the maintained Release description template.

This maintenance tree is promoted locally; it does not assert publication of
a v1.1.1 tag or release. Earlier documentation-only revisions retain their frozen
runtime acceptance scope. The latest static guard/privacy revision has not run
tests, explicit precompilation, cold qualification or scientific calculations;
official scientific Julia readback of the repacked HDF5 inputs also remains
`NOT_RUN`. The data-only Serialization migration required module loading and
could perform normal JIT work; it does not establish runtime cache hits or
runtime qualification. Fail-closed checks remain intact. Earlier PASS results
remain historical and do not qualify this new source identity.

## 1.1.0 — Second-harmonic generation and Standard Wannierization

- Consolidate linear transport and linear optical exports into three response
  mechanisms plus total: `drude`, `quantum_metric`, and `berry_curvature`.
  The latter combines ambient-curvature contact with interband Hall and is
  interpreted as the anomalous-Hall-effect response mechanism. Physical
  formulas and task inputs are unchanged; native contribution filenames and
  the strict transport schema change to `/2.0`. Old `/1.0` five-file transport
  results require their original reader, not a filename-only migration.

- Replace scalar Linear Transport and Orbital Magnetization task inputs with a
  strict ordered `Vector{Float64}` chemical-potential axis. Integral execution
  shares Fourier, diagonalization, geometry, and material completion work across
  all μ values; new strict vector schemas/readers bind axis, task, source and
  decomposition identities. Linear optical and unrelated quantities retain
  scalar occupation inputs. Existing scalar artifacts are not upgraded.

- Correct source-file/internal-neighbor index mapping in direct uIu/uHu tensor
  assembly and add per-operator reconstruction receipts. Affected derived tensors/bundles need rebuilding with
  a corrected assembler; raw inputs remain reusable subject to their own checks.
  Remaining OAM differences are open. Legacy receipt absence stays readable as
  `LEGACY_UNVERIFIED`; construction receipts do not establish production qualification. See the
  [rebuild guidance](docs/WANNIERIZATION_CONFIG.md#neighbor-order-derived-operator-rebuild).

- Add task-derived Wannierization output through `profile=nothing` and typed
  `operator_tasks`, using the shared Core requirement registry before source
  generation. New fixed profiles are only `:hamiltonian_position` and `:full`;
  existing spin-profile bundles retain their supported reader path. OAM export
  defaults to five operators, with no spin-family source requirement.
- Seal requested task pairs (retaining `:all`), expanded dependency closures,
  canonical operator/source unions, registry version and selection digest in
  Packed 1.1 provenance. Fresh readers re-resolve the selection and validate
  authority backend/digest/input hashes and final delivery gauge. Runtime's
  explicit finite-model OAM reconstruction does not confer five-operator export
  qualification. See [selection and migration details](docs/WANNIERIZATION_CONFIG.md#task-derived-output-selection-in-110).

- Consolidate Wannierization qualification into one typed `WannierizationEligibility`
  block. The checkpoint summary keys `qualified_z_seal`, `route_selection_eligible`,
  `standard_tb_export_eligible`, and `accepted_state_tb_export_eligible`, together
  with the `production_eligible` key previously written into the checkpoint
  `input_summary` group, are removed. The block is persisted into `input_summary`
  and as `wannierization_eligibility_*` HDF5 attributes, and it reports
  `execution_eligible`, `export_eligible`, `production_eligible`,
  `qualification_status`, `quality_review_recommended`, `strictly_converged_z_seal`,
  and the `reasons`, `verified_contracts`, `unverified_contracts`, and
  `conflicting_contracts` lists. `strictly_converged_z_seal` retains the former
  `qualified_z_seal` meaning. Bundle-level `production_eligible` booleans in
  operator-bundle status metadata are unchanged.
- Narrow the accepted-state TB export gate to structural reasons: terminal solver
  status classes no longer block export by themselves, an absent optimizer schedule
  reports `SOLVER_NOT_REACHED` instead of `SOLVER_SCHEDULE_IDENTITY_MISMATCH`, a
  true primary failure reason is no longer overwritten by a secondary gate, and
  `HARD_ERROR_PRESENT` is narrowed to identity, provenance, and
  contract-inconsistency codes. The hard blockers (no accepted state,
  checkpoint/restart identity mismatch, non-finite arrays, illegal dimensions,
  per-k rank deficiency, non-finite residual, Hamiltonian authority mismatch,
  TB/Packed round-trip inconsistency, and refusing to overwrite existing outputs)
  and the `:strict` route behavior are unchanged. Failure receipts now also record
  `stage`, `substage_id`, `current_iteration`, and `last_successful_operation`.
- The `disentanglement_limit_policy=:standard_continue` semantics, the behavior that
  keeps an obviously stalled task running to `disentanglement_max_steps`, the
  `1e-10` thresholds, and input-gate strictness are unchanged.
- Add SHG susceptibility and conductivity for BZ meshes and reciprocal-space slices.
- Add `SHGParameters` and `Numerics`, with total/seven-term/both output selection.
- Preserve independent resonance, low-frequency and intermediate-state regularizations.
- Correct the Berry-curvature-dipole tensor contraction. Retain the legacy zero-temperature
  switch: one-band terms are omitted at temperatures at or below 1e-7 K.
- Use the neutral `construction_policy=:standard` Wannierization route by default;
  retain `:strict` as an explicit production-qualification route and keep model
  availability separate from production eligibility.
- Improve stage-aware Wannierization output for disentanglement, the Z-to-U
  boundary, localization, and runs where localization was not evaluated.
- Raise the Wannierization checkpoint wire schema to `1.2`, which maps internally
  to numerical contract `2.29`, and the SAWF fixed-subspace capsule wire schema to
  `2.0`. Current readers still read checkpoint `1.1` and fixed-subspace `1.0` and
  `1.1`, so existing files, including the Fe `*.wannierization.h5` artifacts,
  remain readable with unchanged readback. The packed operator-bundle wire schema
  remains `1.1`. Older wire identifiers still require an external migration tool
  and are not read or relabelled by current readers.
- Retain existing response interfaces. SHG slice densities use three Cartesian
  axes and sum all model bands.

## 1.0.1 — Maintenance release

WannierNLQG 1.0.1 synchronizes the versioned release with the maintained v1
source while preserving the public API and storage-schema baseline established
by version 1.0.0.

### Changed

- Improved Integral and K-slice progress output with clearer Fourier-plan,
  timing, throughput, table, and external-path presentation while retaining the
  complete structured progress record.
- Improved ordinary and symmetry-adapted Wannierization reports with neutral
  filenames, compact qualification summaries, artifact hashes, and an atomic
  diagnostic JSONL sidecar.
- Reorganized local and GitHub test orchestration into explicit Fast,
  Full-only-shard, and MPI-only modes with resource-aware scheduling and
  auditable interruption handling.
- Added a tag gate that requires an exact successful `main` CI run before a
  version tag can qualify for release.
- Updated public documentation, theory descriptions, citation guidance, and
  project logo assets.

### Compatibility and qualification

- The package software version is 1.0.1; public storage schemas remain at 1.0.
- Operator bundles record the 1.0.1 writer version and retain the documented
  historical reader compatibility.
- Package regression tests do not establish material-specific numerical,
  physics, or production qualification.

## 1.0.0 — Initial public release

WannierNLQG 1.0.0 is the first public release.

### Included

- Grouped, task-local response configuration for Integral, K-slice, and K-path
  calculations, with repository-owned runnable examples.
- Nonlinear optical, spin-current, finite-photon-momentum, band-structure, and
  quantum-geometric calculation families documented in the
  [user guide](USER_GUIDE.md).
- Ordinary and symmetry-adapted Wannier construction, operator generation,
  checkpointing, and qualified standard export.
- Response-symmetry classification, tensor constraints, deterministic reports,
  and magnetic point-group identities based on normalized colored operations.
- Direct and Mixed Fourier execution, task-compatible interpolation reuse,
  thread support, and optional MPI execution where registered.
- Publication-oriented plotting tools with deterministic sidecar metadata.

### Reproducibility and identity contracts

- Magnetic point-group equality uses class number and `operation_digest` under
  `wanniernlqg.magnetic-point-group-operations/1.0`; Hermann--Mauguin symbols
  are display fields under `wanniernlqg.spglib-canonical/1.0`.
- The 1651-to-122 magnetic catalogue is generated from the pinned Spglib
  database by a project-owned deterministic algorithm. See the
  [convention](docs/MAGNETIC_POINT_GROUP_CONVENTION.md) and
  [generation receipt](catalog-generation-receipt.json).
- Full-profile Wannier operator workflows bind operator-oracle and solver MMN
  roles through an authoritative target contract and validate provenance before
  expensive work and again before export.
- Public test fixtures are synthetic. Package regression results do not establish
  convergence or material-specific physical or production qualification.

### License

WannierNLQG is distributed under `GPL-2.0-only`. Third-party software and data
retain their own licenses; see [THIRD_PARTY_NOTICE.md](THIRD_PARTY_NOTICE.md).

## Geometric Loop QHC support removal

- **Unsupported method**: Quantum Hermitian Connection with Geometric Loop is no longer supported. Normal task requests and retained expert entry points return an explicit unsupported-method error; no automatic fallback is selected.
- **Other GL responses**: Shift current, photon-drag shift current and shift vector retain their numerical implementations.



## Smooth spin-current matrix elements

- **Positive regularization:** ISC and SSC use the shared smooth connection and complementary Hamiltonian-derivative weight. `denominator_regularization` remains in eV with default 0.001 and must be finite and positive. Near-degenerate and finite-gap values can change.
- **Retired spin threshold:** Explicit `degeneracy_threshold` in an ISC/SSC task raises a migration error instructing removal from that task. Other responses retain their threshold roles. No parameter conversion is implied.
- **Theory and cache:** The spin-current theory documents the operator derivation, units and finite-subspace limits. Width changes rebuild the shared connection and raw-spin prerequisites before reusing a vertex. This note alone does not establish release or material qualification.


## Regularized orbital magnetization

- **Consistent OM vertices:** Conventional and orthogonal Projector OM use a common positive-width complete-velocity Sylvester tangent. The eV width remains `denominator_regularization`, default 0.001. Finite-width numerical results change; other response vertices retain their roles.
- **Zero-temperature boundaries:** A chemical potential at a spectral interval boundary uses equal weights of the two complete occupied-subspace responses at that same chemical potential. Positive-temperature convolution is unchanged; no fractional density matrix is used as a projector.
- **Unsupported OM gap parameter:** Explicit `gap_tolerance`, including shared TOML inheritance, reports that OM does not support it. Other responses retain the parameter. No nonorthogonal Projector or material-completion support is added.
- **Output provenance:** OM tables retain their columns and bind the effective width, vertex prescription and zero-T convention in task identity headers. This entry alone does not assert promotion or material qualification.

- **Jerk/THG parameter cleanup:** Removed the unused third-order `degeneracy_threshold` input and its near-gap counter/metadata. Explicit old inputs report unsupported. Positive regularization, independent fixed diagnostics, occupations and tensor contractions retain their previous numerical behavior.

- **Jerk occupation alignment:** Jerk now uses the ordinary injection-current Fermi--Dirac helper, removing its former small-positive-temperature step. Zero-temperature equality remains occupied; positive-temperature boundary values, last bits and tails may change. SHG/THG occupations and all response kernels outside this update remain unchanged.

- **Metric optical regularization:** Normal nonorthogonal Conventional linear optics now accepts denominator_regularization and defaults to 0.001 eV, matching orthogonal optics; explicit values must be finite and positive. Existing finite-eta geometry is forwarded unchanged. Other eta=0 routes are unaffected.

- **SHG bounded backend alignment:** SHG metric BCD now shares adjacent-gap isolated-band filtering and bare isolated curvature with orthogonal SHG. Metric outer inverses use the existing 1e-7 eV bare cutoff. Finite metric dipoles/generalized derivatives and all unrelated responses are unchanged.

### Optional metric optical cutoff vertices

Metric SHG now uses optional MatrixElements r0/r_eta/Gcut vertices prepared from
normalized local H/S/r source derivatives. Its first five terms can change at
finite geometry regularization. BCD and semiclassical Hessian prescriptions,
other responses, independent positive widths and defaults remain unchanged.
The existing metric optical_position_vertices expert API retains r_eta/G_Deta;
new cutoff_optical_position_vertices requires OPTICAL_CUTOFF_VERTICES in the
metric plan. No new TOML mode, model operator or dependency is required.

### Intrinsic Hall occupation and bare gaps

- Use zero-temperature real-energy `E <= mu` occupation, complete physical
  velocity and ambient curvature on both Matrix routes and orthogonal Projector.
- Use direct velocity/gap ratios for every nonzero floating gap; report nonfinite
  operations explicitly. Remove AHC occupation grouping and its threshold/API.
- Preserve nonorthogonal overlap and connection terms; nonorthogonal Projector
  remains unsupported. Other responses retain their numerical contracts.
