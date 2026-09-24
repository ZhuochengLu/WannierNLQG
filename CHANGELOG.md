# Changelog

This changelog records user-visible differences between public WannierNLQG
releases. Version 1.0.0 establishes the public baseline; each later entry will
describe changes relative to the preceding public tag.

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
  [rebuild guidance](docs/WANNIERIZATION_CONFIG_MIGRATION.md#neighbor-order-derived-operator-rebuild).

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
  qualification. See [selection and migration details](docs/WANNIERIZATION_CONFIG_MIGRATION.md#task-derived-output-selection-in-110).

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
- Add `SHGParameters` and `SHGNumerics`, with total/seven-term/both output selection.
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
