# ProjectionRepresentationSearcher

## Qualification boundary

`ProjectionRepresentationSearcher` is an expert-only Wannierization analysis.
It searches explicitly positioned `ProjectionSpec` candidates whose induced
representations fit between the authoritative frozen and outer subspaces. It
does not enumerate chemical guesses, optimize symbolic Wyckoff parameters,
generate AMN matrices, run the SAWF Z/U solver, build a tight-binding model, or
evaluate a response.

A completed search establishes representation-signature compatibility only.
Each retained solution records frozen-to-target and target-to-outer intertwiner
validation separately. Neither state establishes topological triviality, SAWF
convergence, TB accuracy, physics validity, or production eligibility.

## Inputs and compatibility scope

`ProjectionRepresentationSearchConfig` accepts exactly one in-memory or HDF5
`BandRepresentation`, one authoritative `TargetSubspaceQualificationContract`,
and an ordered set of explicit `ProjectionCandidateSpec` objects. Candidate
specs must provide fractional positions and leave global Wannier indices unset.
The default candidate multiplicity is at most one; repeated use requires an
explicit upper bound.

The `:spinless_unitary` scope applies only to spinless, nonmagnetic
representations whose operations are all unitary. The `:generalized_symmetry`
scope applies to spinor inputs, any antiunitary or time-reversal operation, and
magnetic structures. The route names are implementation-neutral. Adapter-boundary
provenance still pins the comparison profile to its upstream package, version,
commit, source SHA-256, and radial compatibility algorithm.

The target contract supplies the exact `num_wannier`, outer mask, and frozen
mask. A coefficient vector is compatible only when

```math
\sum_p c_p d_p=N_W,\qquad
m^\mathrm{frozen}_\alpha(\mathbf{k})\leq
\sum_p A_{\alpha p}(\mathbf{k})c_p\leq
m^\mathrm{outer}_\alpha(\mathbf{k}).
```

## Search and independent validation

The search is serial and deterministic. Candidate coefficients are enumerated
in input order and ranked lexicographically after the exact dimension gate.
`max_results` limits only retained solutions; enumeration continues to record
the total compatible-solution count. Reaching `max_search_nodes` returns an
incomplete limit status even when partial solutions were retained.

Retained solutions are validated, by default, with full-rank frozen-to-target
and target-to-outer intertwiners at every IBZ representative. A failed or
numerically uncertain validation does not remove a signature-compatible
combination or change the compatible-solution count. Both materializers require
a complete search and a solution whose validation status is `PASSED`.

## Persistence and SAWF handoff

HDF5 schema `WannierNLQG.projection_representation_search` version `1.0` is the
authoritative readback artifact. Its canonical logical SHA excludes absolute
paths, timestamps, and HDF5 container layout. Complete historical `2.1` files
remain readable with their original canonical and mirror digests. The historical
`1.0` layout and schema `2.0` remain unsupported. Reused wire `1.0` requires the
complete canonical-payload, typed-mirror, and pinned-compatibility contract; a
missing field or failed digest cannot fall back to legacy parsing. The internal
`projection_search_hdf5_mirror/2.1` hash domain remains unchanged.
The optional canonical JSON is a deterministic human-readable summary.

`materialize_projection_basis` expands candidates in candidate-ID,
multiplicity-copy, and spec order and delegates canonical numbering to the
existing projection-basis builder.
`materialize_symmetry_adapted_wannierization_config` additionally verifies the
representation, target contract, masks, windows, and dimension before replacing
only the immutable SAWF configuration's `projection_basis`. Neither function
runs Wannierization.
