# Standalone diagonal mesh screening (development candidate)

The new `workflow = "mesh_screening"` path uses no WIN, TB model, projection
basis, pseudopotential or wavefunction coefficients. The current implementation
accepts an explicit structure or VASP POSCAR, together with an explicit diagonal
grid. QE XML, OUTCAR grid discovery and actual-point-set identification are still
pending; this is not the complete Plan.md delivery.

Run `scripts/wanniernlqg.jl check INPUT.toml`, then
`scripts/wanniernlqg.jl run INPUT.toml --records RECORD_DIRECTORY` with the usual
package project. The self-contained synthetic input is
`examples/mesh_screening/explicit_structure.toml`. It is a mathematical fixture,
not a material or convergence calculation. Relative paths use the input directory.

`structure` has lattice rows in Å, one species label and fractional-position row
per atom, and optional Cartesian magnetic-moment rows. Instead of explicit
structure, use `[source] kind="vasp", poscar_file="POSCAR"`. When both are
supplied, their cell, labels and atom order must agree; no WAVECAR is requested.

`kmesh.dimensions` is three positive integers. Specify either
`offset_fractional` (reciprocal fractional coordinates) or `offset_grid_steps`
(one unit is one mesh step), never both. The default is zero offset. A specified
grid defines a constructed mathematical point set, not proof of complete saved
native wavefunctions. General non-diagonal grids and undocumented fields reject.

The existing TB compatibility symmetry detector is retained. Its actual selected
operations and antiunitary flags are reported. Both the exact rational linear
action and the offset closure are checked; a separate transformed-point
enumeration verifies permutation, periodic shifts and uniqueness.

The density metric is lattice-row length times mesh size. Each active dimension
must meet `density_target` (default 55); this is not a reciprocal-resolution or
convergence guarantee. Search spans the per-axis ceiling minimum through that
minimum plus `search_radius` (default 10), with deterministic minimum-point-count
selection. A no-solution domain is an error. `dimension=2` fixes the original
third size and offset but still tests operations mixing that axis.

The report preserves normalized grid-step offsets for recommendations and does
not claim to reconstruct an original Monkhorst–Pack label. Generation of native
QE/VASP grid-input snippets remains part of the pending metadata integration.
Existing reports are protected unless `output.overwrite=true` is explicit.

Current tests cover algebra versus enumeration, anisotropic/shift/antiunitary
cases, 2D mixed-axis rejection, density floors, input errors, effective replay,
and real CLI execution with no WAVECAR. Test code availability is not a PASS;
see the owner development record for executed evidence.

## QE metadata route (candidate249)

`[source] kind="qe"` and `save_directory` read only `data-file-schema.xml`.
This path does not call the UPF/physical-metric/wavefunction reader.
It uses the output structure if present and otherwise the input structure;
QE schema cell/atom coordinates are in bohr, saved Cartesian k points in
2π/alat. XML atom labels and actual k-point order are retained. Labels are
not claimed to be authoritative chemical-element mappings.

An explicit saved `monkhorst_pack` specification supplies dimensions and
fractional offset. An irreducible point list alone cannot. Explicit TOML
mesh metadata must agree with saved dimensions and periodic grid offset.
The report distinguishes a complete actual point set from a mathematical grid
constructed from its explicit specification; slots retain original point order.
Duplicate/off-grid actual points are rejected.

Automatic magnetic moment interpretation is pending. Spin-polarized XML
requires explicit structure moments; it is not silently treated as nonmagnetic.
OUTCAR integration remains pending. `init --workflow mesh_screening` writes
a QE template without reading data. No wavefunctions are fabricated.
