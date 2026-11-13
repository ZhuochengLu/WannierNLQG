# Native topology preparation (isolated candidate)

The actual-point overload of `MatrixElements.build_finite_difference_stencil`
reuses the existing shell selection, SVD completeness and neighbor wrapping.
It does not require a fabricated CHK or WIN and preserves the actual point order,
including a common mesh offset. No new six-axial-neighbor assumption is made.

`IO.owned_wannier_topology` snapshots and validates a complete topology/projection
definition. Its semantic digest is recomputed from owned values, not copied from
an unrelated file hash. Original NNKP file calls keep original byte identities.
Mutating an input after snapshot does not mutate that snapshot; a subsequent
snapshot receives the corresponding new digest. No simultaneous mutation is supported.

The native QE generator accepts that typed definition and uses its existing PAW
normalization, overlap/projection and qualification path. The EIG artifact comes
from exactly the selected native bands used by MMN/AMN, in the same point order,
with roundtrip Float64 serialization. The old EIG writer default is unchanged.

The isolated normalized ordinary QE entry now constructs this contract from
actual saved-point headers and the existing physical-reader structure. It resolves
native matrices before reading the generated EIG. External-file expert calls keep
their original ordering and required-oracle default. Normalized native construction
retains unavailable oracle quality checks as warnings, not PASS.

The native zero-step initialization/checkpoint/replay path has been exercised.
Its zero-step operator export exposed a numeric-status serialization mismatch,
corrected in this candidate at the writer (unmeasured convergence is NaN in the
existing numeric schema, not a string). Export repair is not yet qualified here.
Nonzero native continuation, SAWF constraints, VASP native and extended operator
combinations remain separate gaps; no material or complete Plan qualification.

Generated EIG is an accepted output artifact, never an input to its own preparation
identity. The effective native TOML records output.native_matrix_directory, which
must continue to identify the same accepted artifact set across restart. Existing
source and artifact drift checks remain active. No temporary WIN/NNKP is made.
