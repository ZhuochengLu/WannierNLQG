# Release procedure

This document defines the reusable public release procedure used for the
WannierNLQG 1.0.0 release line. It is not a
historical checklist and does not assert that an unfinished candidate has
passed any gate.

## Identities

Record software version, all independent storage identifiers from
[the schema inventory](STORAGE_SCHEMAS.md), retained internal contract identifiers,
source digest, test-contract digest, and campaign-tool digest separately. Never
mechanically change scientific schema or provenance versions when changing the
software version.

## Candidate gate

1. Work in an isolated candidate copied from a frozen formal source tree.
2. Require every independent writer to use schema `1.0` and all three Band
   readers to reject non-`1.0` input. Keep supported historical reads for other
   formats and retain Band historical fixtures as rejection evidence. Run the
   formatter, architecture contracts, documentation audit, version
   consistency, and exact release whitelist.
3. Run the default self-contained Fast suite.
4. Run every self-contained Full-only shard and the independent MPI-only suite.
   The local `python3 scripts/run_tests.py full --cpu-budget 17 --output-dir /tmp/wnlqg-release`
   combines Fast, all Full-only shards, and MPI-only exactly once; use this in
   place of steps 3 and 4 when running the aggregate entry point.
5. Record performance observations independently. Performance measurements are
   evidence, not a hard promotion gate for this release line.
6. Freeze the unchanged candidate and regenerate `SOURCE_MANIFEST.tsv` and
   `SHA256SUMS`.
7. Scan for secrets, private absolute paths, material data, oversized files,
   and prohibited licensing content.

Recommended commands are:

```bash
julia --project=. scripts/check_format.jl
julia --project=. scripts/check_structure_boundaries.jl
julia --project=. scripts/check_documentation.jl
julia --project=. scripts/check_release_whitelist.jl
julia --project=. -e 'using Pkg; Pkg.test()'
for shard in interfaces-and-symmetry wannier-core scientific-contracts \
  thread-determinism star-gauge-thread; do
  WANNIERNLQG_TEST_MODE=full-shard WANNIERNLQG_TEST_SHARD="$shard" \
    julia --project=. -e 'using Pkg; Pkg.test()'
done
WANNIERNLQG_TEST_MODE=mpi-only julia --project=. -e 'using Pkg; Pkg.test()'
```

## Qualification reporting

Report Engineering, Numerical, Physics, and Production independently. A package
test pass does not qualify a material, a physical model, or production use.
`NOT_RUN`, environment invalidity, retained holds, and user waivers must remain
explicit and must not be rewritten as PASS.

## Promotion and remote publication

Before local promotion, present the exact scoped diff, frozen hashes, complete
test evidence, qualification matrix, backup destination, and rollback command.
Before any tag, push, or GitHub Release, present the exact tag, release notes,
remote commands, repository status, and formal-source digest and wait for
explicit approval. Preserve the previous formal source and its evidence.
