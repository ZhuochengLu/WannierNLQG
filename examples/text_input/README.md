# Text input examples

Run from any working directory with the package project selected:

```sh
julia --project=PACKAGE PACKAGE/scripts/wanniernlqg.jl check INPUT.toml
julia --project=PACKAGE PACKAGE/scripts/wanniernlqg.jl explain INPUT.toml
julia --project=PACKAGE PACKAGE/scripts/wanniernlqg.jl run INPUT.toml --records RECORDS
```

The three response files use the existing synthetic TB. The step example expands
to 0, 0.3, 0.6, 0.9 eV; the Fermi example is a three-point LT scan. Column Band
nodes preserve a nonadjacent repeated point and an out-of-BZ point.

The four preparation templates are produced by the public init function. Their
seed/source files are placeholders to replace with qualified actual inputs;
they are not material benchmarks. SAWF requires its existing representation.
Projection and gauge-aware workflows remain separate, with their original
operator, gauge, threshold and HOLD contracts. No implicit pipeline is run.

See [the full input contract](../../docs/TEXT_INPUT.md) for defaults, units,
explicit native PAW provider selection and effective-file replay.

## Current preparation workflows

Use `{ordinary,sawf,projection,mesh}-{qe,vasp}.toml` for the four current workflows.
These are templates requiring one consistent native dataset, not material results.
`wannierization-ordinary.toml` is the explicit external-basic EIG/MMN/AMN route.
See `docs/PLAN_FINISHING_GUIDE.md` for source demands, canonical Julia stage controls,
explicit migration and qualification boundaries. QE full requires spinor coefficients.
