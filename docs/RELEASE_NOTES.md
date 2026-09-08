# WannierNLQG 1.0.0 release notes

## Initial public release

WannierNLQG 1.0.0 is the first public release and establishes the public API,
file-format, documentation, and qualification baseline. Future release notes
will describe changes relative to the preceding public tag.

## Calculation and runtime scope

- The grouped response interface separates shared `ModelInput`, sampling,
  execution, and output options from independently parameterized `TaskSpec`
  instances.
- Registered calculations cover nonlinear optical and spin responses,
  finite-photon-momentum responses, band interpolation, and quantum-geometric
  quantities. The complete registry and required inputs are listed in the
  [user guide](../USER_GUIDE.md).
- Integral and K-slice calculations support the registered Direct or Mixed
  Fourier routes. K-path sampling is currently registered for band structure.
- Compatible tasks can reuse interpolation data while retaining independent
  occupations, numerical controls, observables, outputs, and effective metadata.
- Optional thread and MPI execution preserve root-owned publication and explicit
  runtime ownership of MPI initialization and finalization.

## Wannier construction and operator provenance

- Ordinary and symmetry-adapted construction use immutable `input`, `solver`,
  `checkpoint`, `runtime`, and `output` configuration groups. See the
  [current configuration reference](WANNIERIZATION_CONFIG_MIGRATION.md).
- `construction_policy=:diagnostic` permits a finite, dimensionally valid state
  to proceed while preserving quality failures for manual review. Structural,
  rank, metric, identity, and integrity failures remain blocking. Diagnostic
  results are not production-qualified by optimizer convergence.
- Full-profile operator generation binds raw operator-oracle and solver MMN files
  as distinct roles in one target contract. uIu, uHu, sIu, sHu, and SPN inputs
  are checked before wavefunction, overlap, or solver work begins.
- Checkpoints and final exports retain the target-contract digest and repeat the
  validation. Role swaps, stale provenance, and post-preflight replacement fail
  closed without publishing partial scientific output.
- Native VASP PAW AMN generation supports complete `d` projection shells with
  projection-identity and positive-definite metric checks.

## Response-symmetry reporting

- Human-readable and JSON reports identify structural and magnetic space and
  point groups, the active constraint group, deterministic generators, and
  forbidden, related, or independent tensor components.
- The full detected magnetic group is distinct from the active unitary subgroup
  when time reversal is excluded from response constraints.
- Magnetic point-group machine identity is the normalized complete set of
  colored point operations under
  `wanniernlqg.magnetic-point-group-operations/1.0`. Equality and aggregation use
  the magnetic point-group class number and `operation_digest`.
- Hermann--Mauguin text is display-only under
  `wanniernlqg.spglib-canonical/1.0`. Consumers should use UNI, class number, or
  `operation_digest` for stable matching.
- The deterministic catalogue covers 1651 UNI identifiers and 122 magnetic
  point-group classes. It is generated from the pinned Spglib magnetic database
  by the published project-owned algorithm. Exact dependency and output hashes
  are recorded in the [generation receipt](../catalog-generation-receipt.json),
  and the algorithm is specified in the
  [magnetic point-group convention](MAGNETIC_POINT_GROUP_CONVENTION.md).
- The response-symmetry summary writer uses
  `wanniernlqg.response-symmetry-summary/1.0`.

## Reproducible source and testing

- Fast is the default self-contained test level. Full adds thread, MPI,
  fresh-process persistence, supported compatibility paths, registered response
  families, and abnormal-input coverage.
- Examples and package tests use repository-owned synthetic inputs and temporary
  output roots. Material data, performance campaigns, private diagnostics, and
  release evidence are not distributed in the source package.
- `SOURCE_MANIFEST.tsv` and `SHA256SUMS` define the frozen public source
  inventory. The catalogue generator supports deterministic offline replay
  against the locked dependency environment.

## License and third-party sources

WannierNLQG 1.0.0 is distributed under `GPL-2.0-only`. The magnetic catalogue
generation environment pins Spglib.jl 1.2.0, `spglib_jll` 2.7.0+0, and Spglib C
2.7.0. Third-party components retain their own licenses and notices; see
[THIRD_PARTY_NOTICE.md](../THIRD_PARTY_NOTICE.md).

## Qualification limits

- Smoke meshes and synthetic fixtures verify interfaces and regression
  contracts; they are not material-convergence recommendations.
- Package Engineering checks do not establish material-specific Numerical,
  Physics, or Production qualification.
- Diagnostic Wannier construction and manual-review artifacts do not become
  production eligible solely because a numerical solver terminates.
- Hermann--Mauguin strings are descriptive output, not machine identity.
- A local source release does not itself create a remote tag, push, or hosted
  release artifact.
