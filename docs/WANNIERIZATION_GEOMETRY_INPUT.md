# Normalized geometry migration (development candidate)

`WannierNLQG.Wannierization.WannierizationGeometry(structure, dimensions, kpoints)`
is the owned geometry carrier for the new input execution chain. Lattice vectors
are rows in Angstrom; atomic fractional coordinates are columns; actual ordered
k points are rows in reciprocal fractional coordinates. The constructor copies
caller arrays and validates a complete unique diagonal grid without reordering.
No physical wavefunction data are constructed from an irreducible list.

The internal preparation/input configurations accept exactly one of `geometry`
or the explicit legacy `win_file`. Normalized input requires an already expanded
projection basis. `build_wannier_projection_basis(lines; structure, ...)` uses the
same ProjectionSpec numbering and orbital kernels as the legacy reader. The new
carrier is used by identity representation and ordinary post-export geometry
checks. Source hashes distinguish `GEOMETRY` content from legacy `WIN` bytes.
No temporary WIN is written. Source backend and matrix source contracts remain
separate; geometry alone is not PAW, gauge, sewing or SAWF qualification.

This is an implementation-stage expert contract, not the final user TOML schema.
The new TOML dispatcher, ordinary solve/restart end-to-end tests, full native
SAWF migration, API inventories and complete applicable engineering checks remain
pending. Source254 failed before tests at an old configuration field-count
assertion; source255 corrects that schema count and preserves legacy constructors.
There is no new numerical qualification until its actual test result is recorded.

## Persistent identity and restart boundary

Normalized ordinary representations carry `normalized_geometry_contract=1` and
`normalized_geometry_sha256` in their conventions, as well as the GEOMETRY source
hash. Existing HDF5 representation serialization preserves both maps. The
current complete restart representation definition already compares conventions
byte-for-byte; it therefore binds the geometry identity without changing solver
arrays or silently accepting old WIN provenance. Legacy checkpoints keep their
old authority; legacy-to-normalized checkpoint conversion is an explicit pending
migration, not an automatic equivalence claim.


## New TOML adapter under migration (not yet qualified)

`Runtime._workflow_explicit_wannier_geometry` consumes `structure` and
`kmesh.dimensions` / `kmesh.points_fractional`. The point rows retain the exact
EIG/MMN/AMN ordering; neither a generated order nor an irreducible grid may replace
those rows. The shared owned geometry constructor checks the full-grid contract.

`Runtime._workflow_external_wannier_input` constructs the existing typed input
from that geometry, projection strings, all three external basic matrix paths,
and windows. Relative paths resolve against the TOML directory. It does not probe
for a file and switch to a native source, generate a WIN, or load coefficients.
This helper is a component of the migration, not a complete new TOML dispatcher.
Native metadata adapters and the independent Z/U solver parser are still pending.

Coverage evidence: geometry preparation/HDF persistence passed in 256; ordinary
old/new execution passed the separate 257 test (42 checks including caller MPI). Adapter tests in candidate258 are
written but not run. No default, source235/AHC246, or fixed dependency changed.
