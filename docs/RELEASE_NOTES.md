# WannierNLQG 1.0.1 release notes

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

- The Julia package software version is 1.0.1.
- Public storage schemas remain at version 1.0; software versioning does not
  mechanically change wire-format, evidence, or qualification identifiers.
- Operator bundles record the 1.0.1 writer version. Readers retain the listed
  historical writer-version compatibility and continue to reject unknown
  versions.
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
- Diagnostic Wannier construction and manual-review artifacts do not become
  production eligible solely because a software gate succeeds.
