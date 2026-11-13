# Native metadata during the normalized-input migration

`mesh_screening` can consume POSCAR structure and an optional OUTCAR point
inventory without reading WAVECAR or POTCAR:

```toml
workflow = "mesh_screening"
[source]
kind = "vasp"
poscar_file = "POSCAR"
outcar_file = "OUTCAR"
[kmesh]
dimensions = [4, 4, 4]
[output]
report_json_file = "mesh.json"
```

Dimensions are explicit: an irreducible saved list cannot determine a unique
complete grid. The labelled reciprocal-lattice point table is retained in its
original order. Weights are recorded, not used to invent missing wavefunctions.
Conflicting repeated tables or headers, malformed/truncated/nonfinite rows and
negative weights are rejected. OUTCAR changes between resolution and execution
are rejected. Effective TOML retains absolute POSCAR and OUTCAR paths.

ISPIN, LNONCOLLINEAR and LSORBIT are metadata, not atomic magnetic moments.
Magnetic or unspecified spin metadata requires explicit structure magnetic
moments; local PAW moment summaries are not silently interpreted as the magnetic
structure. Explicit and POSCAR structures must agree in atom order and geometry.
This does not replace native physical PAW validation or prove a symmetry of a
wavefunction calculation.

The QE XML reader similarly preserves actual saved point order without loading
UPF or coefficients. These metadata routes are separate from full native
Wannierization, whose metric, coefficients, EIG/MMN/AMN and projection definitions
must originate from one consistent generation chain. That normalized native
execution adapter is still under development; this metadata support does not
claim SAWF or extended-operator completion.
