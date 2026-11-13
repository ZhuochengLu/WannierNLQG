# Wannierization API and checkpoint migration

Use the normalized TOML input described in
[NORMALIZED_WANNIERIZATION_INPUT.md](NORMALIZED_WANNIERIZATION_INPUT.md).
The Julia stage-control interface is described in
[PLAN_FINISHING_GUIDE.md](PLAN_FINISHING_GUIDE.md).

## Solver controls

Ordinary and symmetry-adapted Wannierization use the supported two-stage
SMV–Fletcher–Reeves paths. Configure Z and U budgets and stopping criteria
separately. Removed independent fixed-subspace initialization, free algorithm
selection, adaptive, Anderson, L-BFGS and trust-region options are rejected,
not silently ignored. Internal fixed-Z projectors, descent fallback, line search
and matrix safeguards remain part of the supported solver.

## Current checkpoint boundary

Current embedded checkpoint storage uses wire 3.0; optional referenced storage
uses wire 3.1 and an explicitly bound retained source root. See the normalized
input guide for the storage choice and the public checkpoint readers.

Public readers require current mathematical definitions and state. Incompatible
historical inputs are rejected. Preserve originals and their physical inputs;
create new artifacts with the current writer. No historical compatibility or
migration API is supplied by the public package.

Accepted arrays, cumulative Z/U counts, objective histories and fixed-Z
frames/projectors remain continuation data. Historical initial-frame provenance
must not be removed merely because its stored name refers to an old algorithm.
See [storage schemas](STORAGE_SCHEMAS.md) for the current persisted contracts.

## Scientific definitions and provenance

Current Wannierization input, solver, report, operator-generation and recovery
contracts retain complete scientific definitions or owned input bytes where
identity is consumed. Content authentication reported as `NOT_PERFORMED` is not
a successful checksum verification. Dimensions, basis/gauge, units, ordering,
finite values, accepted-state independence and stopping rules remain enforced.
A cache without sufficient actual input evidence is not reused.

Digest-only historical records are not reauthenticated by changing their labels.
Missing complete input or target-subspace definitions require the original
inputs and an explicit supported conversion. Historical quality measurements
retain their original meaning; conversion does not grant production eligibility.
