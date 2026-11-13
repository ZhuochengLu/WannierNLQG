# Synthetic Runtime Fixture

This four-orbital fixture is the common, self-contained input for public task examples and release tests. It is deliberately synthetic and is not a physical material model.

- `synthetic_tb.dat` uses two real-space records with ordinary Wannier degeneracies `2` and `4`.
- `synthetic_wsvec.dat` supplies the pair-dependent minimum-distance replicas for an MP grid of `(2, 1, 1)`.
- `synthetic_operators.h5` contains the complete Packed operator inventory, including spin-family and derivative-overlap operators.
- `SHA256SUMS` binds all generated payloads.

The Packed fixture uses current mathematical model format 2.0. Machine-local publication receipts do
not ship with copied assets. Before using this declared fixture, copy it into a
caller-owned directory and call
`WannierNLQG.IO.adopt_real_space_operator_bundle(copied_path)`. The adoption
validates the complete format and finite payload, then publishes a local receipt;
it grants no numerical or physical qualification. The Runtime fixture test
support performs this explicit step only when a Packed input is requested.

Regenerate from the package environment with:

```bash
julia --project=. examples/fixtures/synthetic_runtime/generate_fixture.jl
```

The example outputs are diagnostic demonstrations only. They are not numerical or physical qualification evidence.
