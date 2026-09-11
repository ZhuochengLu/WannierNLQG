# Changelog

This changelog records user-visible differences between public WannierNLQG
releases. Version 1.0.0 establishes the public baseline; each later entry will
describe changes relative to the preceding public tag.

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
  checkpointing, and qualified diagnostic export.
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
