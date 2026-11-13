# Normalized Wannierization input (development candidate)

The new ordinary external-matrix entry resolves TOML directly into owned crystal
geometry, the supplied ordered full k mesh, projections and solver configuration.
It does not generate or read a temporary WIN file. All paths are relative to the
input TOML, including checkpoint paths. `check`/`explain` validates configuration;
it does not certify numerical convergence or material physics.

The external route requires EIG/MMN and AMN when the chosen initializer consumes
AMN. Explicit supported matrix providers and native QE/VASP routes retain their
existing typed semantics and validation. Advanced input/solver/output controls are
available in normalized sections; source selection never supplies absent operators.
Old workflow outer namespaces are rejected; see [TEXT_INPUT_UNIFICATION.md](TEXT_INPUT_UNIFICATION.md).

```toml
workflow = "wannierization"
mode = "ordinary"

[structure]
lattice_angstrom = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
species = ["X"]
positions_fractional = [[0.0, 0.0, 0.0]]

[kmesh]
dimensions = [2, 1, 1]
points_fractional = [[0.0, 0.0, 0.0], [0.5, 0.0, 0.0]]

[basis]
projections = ["X:s"]

[matrices]
eig_file = "tiny.eig"
mmn_file = "tiny.mmn"
amn_file = "tiny.amn"

[windows]
outer_min_ev = -2.0
outer_max_ev = 2.0

[solver]
initialization = "amn"
dis_num_iter = 200
dis_conv_tol = 1.0e-10
dis_conv_window = 3
num_iter = 500
conv_tol = 1.0e-10
conv_window = 3

[output]
checkpoint_hdf5 = "results/tiny.wannierization.h5"
num_print_cycles = 1
num_dump_cycles = 100
```

This example specifies a synthetic geometry, not a material model. The executable
test fixture constructs matching tiny matrix files; users must supply matrices
with the declared actual band/k/projection order.

The solver controls above are optional and show the authoritative defaults.
Z tests consecutive relative objective changes. U tests consecutive absolute
total-spread changes in Å²; `conv_window <= 1` disables U early stopping.
The first accepted objective has no preceding value and cannot count as a stable
change. A zero previous Z objective is stable only against another exact zero.
Numerical admissibility checks retain their independent thresholds.

Zero stage limits skip that optimization stage. Both zero retains initialization
and performs the requested output work. Print/dump intervals count accepted
stage steps; zero disables periodic actions, not final output or stage-boundary
checkpointing. Rejected trial steps must not become accepted checkpoints.

For explicit restart, select `initialization = "restart"` and add
`[checkpoint] restart_hdf5 = "previous.wannierization.h5"`. The physical input,
projection and window definition must remain compatible. A new output filename
avoids replacing the source checkpoint. Cumulative continuation, changed stopping
controls and export-only restart are under focused validation; a successful fresh
solve alone is not evidence for those paths.

Checkpoint storage defaults to `storage = "embedded"` (wire 3.0). Optional
`storage = "referenced"` writes wire 3.1 and requires an explicit
`reference_root` in `[checkpoint]`. This root must contain the retained source
objects and private definition files. The checkpoint stores relative source
locations, sizes, digests and byte slices instead of another full copy. Retain
that source bundle with the checkpoint. Reading or adopting a referenced
checkpoint also requires the caller's explicit root; a relocated complete bundle
may be rebound, while missing, changed or redirected objects are rejected. The
publication receipt and complete mathematical input comparisons remain required.
This option does not change the final model H5/TB formats or solver parameters.

Old nested TOML/Julia interfaces remain only during this isolated implementation
sequence. They are not the final compatibility promise. The planned converter is
explicit and writes a new file; old checkpoints must not be relabeled as the new
stopping contract. SAWF, native operator generation, projection symmetrization and
legacy conversion are tracked separately in the development scope record.
