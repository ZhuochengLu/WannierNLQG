# Synthetic symmetrization fixture

This fixture is a deterministic one-orbital, one-k-point cubic model used only
to validate file loading, input-driven profiles, strict schema output, and example
execution. It is not a material model and must not be used for physical
interpretation.

The checked files are:

- `inputs/synthetic.win`: authoritative lattice, atom, projection, spinor, and
  `mp_grid` metadata;
- `inputs/synthetic_tb.dat`: Wannier90-compatible Hamiltonian/position model;
- `inputs/synthetic.chk`: little-endian Fortran-unformatted checkpoint subset
  consumed by WannierNLQG;
- `inputs/synthetic.eig`: Wannier90 eigenvalue table;
- `inputs/synthetic.mmn`: formatted neighbor-overlap table;
- `inputs/synthetic.spn`: little-endian Fortran-unformatted spin matrix.

Regenerate them from the package environment with:

```bash
julia --project=. examples/symmetrization/fixture/generate_fixture.jl
```

`SHA256SUMS` covers all six inputs. Regeneration must reproduce those digests.
