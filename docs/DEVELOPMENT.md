# Development guide

## Source layout

- `src/` contains the package modules and the thin public facade.
- `ext/` contains package extensions and their contract-checked private
  components.
- `test/` contains self-contained synthetic unit and integration tests.
- `examples/` contains runnable synthetic configurations and fixtures.
- `scripts/` contains only public quality/release tools, visualization tools,
  and the VASP PAW SPN generator.
- `docs/` and `theory/` contain public English documentation.

The public tree intentionally has no top-level `data/` directory. Production
inputs, material campaigns, performance campaigns, benchmarks, reports,
diagnostics, and release evidence are separate from the distributable source.
Never infer scientific input paths from a neighboring directory.

## Change discipline

Preserve physical formulas, signs, prefactors, units, gauge and basis
conventions, tensor-index order, broadening, finite-q conventions, floating-point
summation order, and serial/thread/MPI reduction order unless the change is
explicitly scientific and receives its own qualification plan. Structural work
must not silently change schemas, durable metadata, or numerical tolerances.

Keep public APIs narrow and ownership explicit. Cross-module calls use declared
integration ports, not underscored implementation helpers. The extension and
component dependency allowlists are checked by
`scripts/check_structure_boundaries.jl`.

## Tests

The default test level is Fast and uses only repository-owned synthetic data:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Full-only shards add thread paths, fresh-process persistence, historical readers,
all registered response families, and abnormal input/error lifecycles. Run all
five static shards, then run the independent MPI-only suite:

```bash
for shard in interfaces-and-symmetry wannier-core scientific-contracts \
  thread-determinism star-gauge-thread; do
  WANNIERNLQG_TEST_MODE=full-shard WANNIERNLQG_TEST_SHARD="$shard" \
    julia --project=. -e 'using Pkg; Pkg.test()'
done
WANNIERNLQG_TEST_MODE=mpi-only julia --project=. -e 'using Pkg; Pkg.test()'
```

`WANNIERNLQG_TEST_MODE=mpi-only` requires a working MPI launcher. Test modes and
shards are validated fail-closed by `test/CITestPlan.jl`; retired or conflicting
environment variables are errors. An unavailable or invalid environment is
`NOT_RUN` or `INVALID_ENVIRONMENT`, never PASS. Material input unavailability is
reported separately and does not change package-test status.

Full plotting tests require Python 3.11 with the exact packages listed in
`scripts/visualization/requirements.txt`, Times New Roman, a complete LaTeX
installation, and PDF/PNG rendering tools. Install the font through its licensed
system distribution; it is not bundled with the source. The shared CI action
`.github/actions/publication-environment/action.yml` documents the Linux setup.
For a local environment, install the system font and TeX dependencies first:

```bash
python3.11 -m venv /tmp/wanniernlqg-publication
source /tmp/wanniernlqg-publication/bin/activate
python -m pip install -r scripts/visualization/requirements.txt
python scripts/visualization/check_environment.py --output /tmp/wanniernlqg-publication-check
```

Keep this environment first on `PATH` when running Full. Preflight renders PDF
and PNG and records the interpreter, package versions, font and TeX tools.
Missing dependencies fail explicitly; tests do not substitute fonts or Mathtext.
The ordinary test driver stays serial; MPI subtests launch their own processes
with explicit requests. Do not globally enable `WANNIERNLQG_USE_MPI` for the driver.

Run focused checks while editing:

```bash
julia --project=. scripts/check_format.jl
julia --project=. scripts/check_structure_boundaries.jl
julia --project=. scripts/check_documentation.jl
julia --project=. scripts/check_release_whitelist.jl
julia --project=. scripts/check_version_consistency.jl
```

The formatter check is read-only. Use `scripts/format.jl` only when an authorized
source-formatting pass is intended.

## Examples

Every example must be importable without execution and expose a deterministic
`build_config()` function. Direct execution is guarded by `PROGRAM_FILE`.
Examples resolve only package-owned fixtures, write to a temporary or explicit
output directory, expose their ordinary demonstration mesh and an explicit small smoke override,
and state that their numerical parameters are interface demonstrations rather
than convergence recommendations. Root input and scheduler files are not shipped;
users own their case scripts and site-specific launchers.

VASP and Quantum Espresso readers remain production code. Their public tests
use synthetic parser and provenance fixtures; redistribution-restricted or
large first-principles data does not belong in the source tree.

## Documentation

Public readable source is English-only. Markdown uses single-dollar delimiters
for inline math and standalone double-dollar lines for display math. Use
`aligned` only inside a display
block. All local file and anchor links must resolve with exact case. Do not add
private absolute paths, references to removed public test levels, or links to
internal material/evidence trees.

The source auditor reports declaration-explanation presence, actual public API
docstrings and known template residues separately. Passing these mechanical
checks does not establish the scientific quality of prose. Generated declarations
and forwarding exceptions are explicitly enumerated and covered by negative tests.

Version 1.0.0 is the public API baseline documented in
`docs/MIGRATION_1.0.0.md` and
`docs/WANNIERIZATION_CONFIG_MIGRATION.md`. For later releases, document
user-visible migrations only relative to the preceding public tag.

## Evidence and performance

Classify changes by symbol reachability before selecting tests. Bind every PASS
to a source digest, command, exit code, log, and log hash. Preserve failed and
invalid attempts instead of rewriting their status.

Performance runs are observational for this release and do not form a hard
promotion gate. Report workload, environment, raw measurements, allocation and
RSS evidence, regressions, invalid environments, and user waivers exactly. Do
not claim parity or improvement from an unqualified campaign.

Material-specific numerical and physics qualification is performed in the
private internal-validation workspace. Package Engineering results must not be
promoted into Numerical, Physics, or Production results.

## Release preparation

Follow [the release procedure](RELEASING.md). Regenerate
`SOURCE_MANIFEST.tsv` and `SHA256SUMS` only after the final source freeze. Do not
create a tag, push, or GitHub Release without separate explicit approval.
