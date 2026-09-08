# Changelog

This changelog records user-visible differences between public WannierNLQG
releases. Version 1.0.0 establishes the public baseline; each later entry will
describe changes relative to the preceding public tag.

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
