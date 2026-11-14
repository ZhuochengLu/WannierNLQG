# Contributor guide

## Installation

Use a supported Julia runtime and a separate environment. The package contains its private numerical infrastructure and does not require a separate ESKernel installation. Activate this source directory and run `using Pkg; Pkg.instantiate(); Pkg.precompile()` before testing. Native MPI and HDF5 must use compatible libraries; use MPIPreferences in your own environment when selecting system MPI.

## Tests

Run `julia --project=. -e 'using Pkg; Pkg.test()'` for Fast. The contributor scheduler `python3 scripts/run_tests.py full --julia /absolute/path/to/julia --cpu-budget 17 --jobs 2 --output-dir /absolute/test-output` runs Fast, all five Full shards, and MPI-only. Keep generated outputs outside this source tree. MPI-only is exclusive. Select `--mpi-profile air3` for the complete small-rank profile; its results do not qualify rank16. Rank profiles are declared in `scripts/test_support/full_rank_profiles.json`. Thread and MPI comparisons retain exact numerical oracles and the declared scientific case inventory.


GitHub CI selects `ci8`: raw-Z/U use 1/2/4/8 ranks and adaptive uses 1/2/8.
The original U fixture is retained alongside the two-edge empty-owner fixture,
whose idle ranks receive poisoned frames that must never be read. Adaptive keeps
the original rules and 21 public numerical records; small bounded scalar/tensor
packets check idle packet owners, canonical value replay and collective failure
recovery. Packet-level idle owners do not establish the original 15-node rule's
whole-rule idle-owner boundary at 16 ranks. Scales above 8 and both original
16-rank empty-owner endpoints remain explicitly untested by `ci8`. `legacy16`
remains available for larger environments; software MPI rank support is unchanged.
The contributor scheduler charges 9 slots for `ci8`, including its driver.

## Precompilation

The package's PrecompileTools workloads exercise ordinary public call paths. Normal JIT remains available. Contributor tests check that loading and user workloads preserve numerical behavior; no material qualification or timing claim follows from a successful precompile. Internal performance campaigns and process-recovery controllers are not shipped.

## Change discipline

Preserve formulas, units, Fourier and Wannier-center conventions, band/subspace semantics, degeneracy policies, summation order, public filenames and columns. Run formatter, structure, documentation, version, source-inventory and affected scientific checks before complete regression. The dependency direction is `Runtime -> Responses -> MatrixElements -> IO -> Core`; the private numerical helpers belong to Core. See [architecture](ARCHITECTURE.md), [ordinary calculations](ORDINARY_CALCULATION_POLICY.md), [storage schemas](STORAGE_SCHEMAS.md), and [release procedure](RELEASING.md).

## Source inventory

`scripts/source_distribution.json` is the positive source inventory. Regenerate `SOURCE_MANIFEST.tsv` and `SHA256SUMS` only after freezing changes, then check `python3 -B scripts/export_public_source.py --audit`. Source exports require a clean committed input and a new external destination. No command publishes a remote release automatically.
