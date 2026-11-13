# Normalized inputs and checkpoints

Use `workflow = "wannierization"` with mode `"ordinary"` or `"symmetry_adapted"`,
`workflow = "symmetrization"` for projection, or `workflow = "mesh_screening"`.
Files resolve relative to the TOML file. Unknown fields and mixed matrix sources
are rejected. See [Wannierization](WANNIERIZATION.md) and the synthetic templates.

Projection accepts the documented H/r inventory. Unsupported spin and derivative
reprojection inventories are rejected; no operator is silently dropped or rebuilt.
Geometry input does not imply wavefunction input or supply atomic magnetic moments.
Magnetic configurations require explicit Cartesian moments.

Checkpoint wire `3.0` embeds its inputs. Referenced wire `3.1` additionally requires
an explicit source root and the retained source objects. Readers require the current
wire and its physical continuation definitions. Relocation uses the explicit
current-format adoption API; it does not convert an older schema or invent missing
physical inputs. Checkpoints record accepted solver state and do not establish
material-specific convergence or production qualification.
