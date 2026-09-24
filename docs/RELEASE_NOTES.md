# WannierNLQG 1.1.0 release notes

## Vector chemical-potential transport and orbital magnetization

Linear Transport and Orbital Magnetization now require a strict
`fermi_energies::Vector{Float64}`. Integral tasks evaluate the full ordered axis
inside one shared k loop: Fourier interpolation, diagonalization, geometry, and
material OAM completion are independent of the number of μ points. KSlice keeps
its established map layout and accepts a one-element vector only.

New versioned table schemas and strict public readers bind the μ axis, task,
full release tree, input model/bundle, MPI/thread shape, operator inventory,
target/authority/frame identity, qualification, and decomposition. Existing
scalar artifacts stay historical and receive no schema or qualification upgrade.
This Engineering capability does not qualify a material calculation.

## Task-derived Wannierization operators

New exports support only the fixed `:hamiltonian_position` and `:full` profiles,
or `profile=nothing` plus a nonempty tuple of Core `OperatorTask` requests.
The shared Core registry resolves deterministic operator/source unions before
source generation. OAM selects exactly five operators without SPN/sIu/sHu;
Projector geometry adds uIu only where registered. Geometry connections are
runtime-derived from Hamiltonian/position. Existing spin-profile Packed bundles remain
readable under their supported wire contract.

Packed 1.1 task provenance records requested and normalized pairs (retaining
`:all`), expanded closures, registry version, inventories and selection SHA-256.
Fresh readers re-resolve these records and verify source, target and authority
backend/digest/input-hash identity. This adds no material convergence or production
qualification. See [API and dependencies](WANNIERIZATION.md#task-derived-selection-and-canonical-union),
[migration](WANNIERIZATION_CONFIG_MIGRATION.md#task-derived-output-selection-in-110),
and [schema](STORAGE_SCHEMAS.md#task-derived-packed-operator-selection).

## Neighbor-order reconstruction correction

Direct uIu/uHu tensor consumers now map both source-file neighbor indices to
validated internal stencil positions. Affected derived tensors and dependent bundles require
reconstruction with a corrected, validated assembler; raw input files are not
invalidated by this defect. Mapping-only diagnostics do not close remaining OAM
kernel, construction or material-convergence differences. See the
[rebuild boundary](WANNIERIZATION_CONFIG_MIGRATION.md#neighbor-order-derived-operator-rebuild).
The additive neighbor-order receipt distinguishes `REBUILT_SOURCE_TO_INTERNAL`
from readable `LEGACY_UNVERIFIED` artifacts. Profile/exact assembly versions
advance while the global derivative marker and wire/schema versions stay unchanged.
See [receipt semantics](STORAGE_SCHEMAS.md#neighbor-order-algorithm-provenance).
This construction correction does not establish material or production qualification.

## Second-harmonic generation

Adds SHG to the existing task API for BZ integral and K-slice calculations.
Separate complex susceptibility and conductivity kernels provide total or seven-term
output, with corrected Berry-curvature-dipole contraction and the legacy zero-temperature
switch. All intermediate model bands remain included. See
[SHG documentation](SECOND_HARMONIC_GENERATION.md) and
[theory](../theory/SecondHarmonicGeneration.md) for numerical conventions and limits.
No remote release is implied by the local candidate version identifier.

## Standard Wannierization route

`construction_policy=:standard` is now the default and publishes a finite,
identity-checked accepted-state TB even when quality convergence is incomplete.
`construction_policy=:strict` remains explicit. Model availability, quality
review recommendation, and production eligibility are recorded independently.
The Wannierization checkpoint wire schema is now `1.2`; readers retain
checkpoint `1.1` compatibility. The packed operator-bundle wire schema remains
`1.1`. Older unsupported wire identifiers require external migration.

## Target-scoped operator qualification

PAW SPN, uIu, QE direct PAW MMN/AMN, and ordinary native-identity Hamiltonian
operator closure now use the outer-window target as the hard numerical gate and
retain the complete parent as an audit. Parent-only finite residual exceedance
is recorded as `AUDIT_EXCEEDED`; structural parent integrity remains blocking.
The target-contract hash domain is `1.1`, generator provenance writers are
`1.1`, and embedded operator qualification is `1.3`. Historical contracts and
qualification `1.2` remain readable but are not silently promoted.

Full operator bundles now preserve the raw generation gauge separately from the
delivered `final_wannier_gauge`. OAM's five required operators can claim a common
delivery gauge only after transform replay and q-to-R roundtrip validation.

## WannierNLQG 1.0.1 history

## Maintenance release

WannierNLQG 1.0.1 incorporates the public updates accumulated after version
1.0.0 and aligns the versioned release with the maintained v1 source tree.
The version 1.0.0 API and migration documents remain the public baseline.

## Runtime progress and output reports

- Integral and K-slice execution now present one concise Fourier-plan summary
  with task, backend, grid, local-point, decomposition, and fallback context.
  The complete structured values remain available in `progress.jsonl` without
  a schema-version change.
- Human-readable progress tables wrap long values, identify external files
  without exposing absolute local paths, distinguish task and bundle timings,
  and report throughput in `points/s`.
- Ordinary and symmetry-adapted Wannierization use the neutral
  `<seed>.wannierization.out` report name. Artifact rows include SHA-256 and byte
  size when available, and missing outputs remain explicit.
- Complete final Wannierization diagnostics are written atomically to
  `<seed>.wannierization-diagnostics.jsonl`. Compact report grouping does not
  discard warnings, errors, failed gates, or original diagnostic records.

## Test and release orchestration

- Test selection is explicit and fail-closed: Fast, five registered Full-only
  shards, and MPI-only are independent modes with a frozen inventory.
- The standard-library Python runner schedules the same registered tests under
  a declared CPU budget, runs MPI exclusively, records task-level logs and
  resource observations, and marks interrupted work as interrupted rather than
  passed.
- GitHub CI executes the Fast operating-system/Julia matrix, every Full-only
  shard, MPI-only, and an aggregate required-job gate.
- Version tags use a separate gate that accepts only an exact successful
  `main`-push CI run for the tag target.

## Documentation and presentation

- The README and user/developer documentation describe the maintained task
  inventory, progress output, and test entry points more precisely.
- Theory descriptions and calculation labels were corrected without changing
  response kernels or the public physical qualification boundary.
- Project logo assets and citation guidance were added to the public source.

## Compatibility and identities

- The Julia package software version is 1.1.0.
- Wannierization checkpoints and Packed HDF5 operator bundles use wire schema
  `1.1`; readers reject every older schema with an explicit external-migration
  requirement. Unrelated storage schemas retain their existing versions.
- Operator bundles record the 1.1.0 writer version and keep writer identity
  separate from the wire-schema contract.
- The original `v1.0.0` tag and GitHub Release remain unchanged.

## Reproducible source

`SOURCE_MANIFEST.tsv` and `SHA256SUMS` define the public source inventory. After
extracting a release archive, verify its payload with:

```bash
shasum -a 256 -c SHA256SUMS
```

Public tests and examples use repository-owned synthetic fixtures. Private
material inputs, local release evidence, and generated research outputs are not
part of the source release.

## Qualification limits

- Software and package regression checks do not establish material convergence
  or material-specific numerical qualification.
- No physical model or material result is newly qualified by this maintenance
  release.
- Standard Wannier construction and quality-review artifacts do not become
  production eligible solely because a software gate succeeds.
