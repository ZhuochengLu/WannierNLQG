# KPath sampling, Band_Structure tasks, and the official postprocessor

## Numerical task

`KPath` is a reciprocal-space sampling geometry at the same API level as
`BZMesh` and `KSlice`; it is not itself a band observable. The registry currently
provides `Band_Structure` as the only KPath task. Response and quantum-geometry
tasks on KPath remain unregistered and therefore fail closed. KPath accepts only
the direct Fourier backend without `NKdiv` or `NKFFT`:

```julia
using WannierNLQG

result = WannierNLQG.run(TaskConfig(
    model = ModelInput(
        model_file = "seed_tb.dat",
        real_space_replica_policy = "auto",
        wigner_seitz_tolerance = 1.0e-5,
        wigner_seitz_search_size = 3,
    ),
    sampling = KPath(
        nodes = [
            ("Γ", (0.0, 0.0, 0.0)),
            ("M", (0.5, 0.0, 0.0)),
            ("K", (1 / 3, 1 / 3, 0.0)),
            ("Γ", (0.0, 0.0, 0.0)),
        ],
        kpoints_per_segment = [101, 101, 101],
        spatial_dimension = 2,
    ),
    tasks = [TaskSpec(
        id = "bands",
        quantity = "Band",
        physics = BandParameters(fermi_energy = 0.0),
        numerics = BandNumerics(hermiticity_tolerance = 1.0e-10),
    )],
    execution = ExecutionOptions(fourier_backend = "direct"),
    output = OutputOptions(output_root = "results", system_name = "sample"),
))
```

The path is an ordered node chain and fractional coordinates are not folded.
Each segment count includes both endpoints; the common endpoint of adjacent
segments is written once, so the total is `sum(counts)-nsegments+1`. The stored
energies are ascending `E_n-E_ref` in eV, where the Band_Structure task interprets
`fermi_energy` as `E_ref`.

The task calls the same TB parser, real-space replica mapper, Fourier assembly,
and eigensystem implementation as response calculations. For a row-lattice
`A`, path distance is accumulated with `B=2pi*A^(-T)` and is stored in
angstrom inverse. Before diagonalization, every real-space matrix and assembled
Hamiltonian must be finite and
`maximum(abs, Hk-Hk') <= numerics.hermiticity_tolerance`. Failure stops before a
complete Band artifact is published.

The two result files are written under `output_root/<id>/`:

- `<system_name>_bands.dat`: distance, three fractional coordinates, then all
  ascending relative band energies.
- `<system_name>_kpath.json`: `wanniernlqg.kpath` schema, node/segment chain, one-based node
  indices, coordinate/distance/energy conventions, and `E_ref`.

The task-local `metadata.txt` records the input/TB summary, hashes, lattice and Fourier
conventions, maximum Hermiticity residual, and replica provenance. A text TB is
marked `INPUT_QUALIFICATION_NOT_PROVIDED`; an HDF5 operator bundle retains its
manifest production/diagnostic state. Passing numerical checks never promotes
physical or production qualification.

### Replica policy

- `auto`: text TB uses its input R support unless explicit `mp_grid` or
  `wsvec_file` requests minimum distance; current schema-1.0 Packed HDF5 (and supported historical 6.x) inherits the manifest
  policy, while legacy Packed input remains input-only.
- `input`: preserves input R support and rejects an already-materialized HDF5
  minimum-distance bundle because that transformation cannot be reversed.
- `minimum_distance`: text or input-support HDF5 requires an explicit
  `wsvec_file` or `mp_grid`; an already materialized bundle is reused once and
  never transformed again.

`wsvec_file` is an explicit strict Wannier90 source, never a filename guess. If
both it and `mp_grid` are present, their canonical orbital-pair maps must agree.
For HDF5, an explicit `mp_grid` must equal the manifest. Legacy Packed bundles
reject runtime `minimum_distance` and `wsvec_file` because their lifecycle is not
authoritative. Requested/effective policy, source, grid, tolerance, search size,
mapping SHA-256, materialization state, and whether this run transformed the data
are all recorded in root-owned metadata and progress.

The maintained example is
[`examples/tasks/band/band_structure.jl`](../examples/tasks/band/band_structure.jl).

Its default output directory is
`<tempdir>/wanniernlqg-examples/v1.0.0/band_structure/band_structure/`: the first
`band_structure` is the example's output root and the second is its task ID.
`WANNIERNLQG_EXAMPLE_OUTPUT_ROOT` replaces the base before those components.
An explicit `build_config(output_root="...")` replaces the parent output root;
the task ID is still appended. The example explicitly sets the reference energy
to `0.0` eV and uses 101 points per segment. The smoke override of three points
per segment is a separate test setting, not the normal preset or a convergence
recommendation.

## Official plotting tool

The Band_Structure task never creates an image. The separate, presentation-only tool
consumes the two result files through the shared audited configuration contract and does not
recompute energies or distances. For example, `synthetic_band_plot.json` can contain:

```json
{
  "mode": "single",
  "reference": {
    "type": "wanniernlqg", "id": "demo", "label": "Synthetic demo",
    "bands": "results/synthetic_bands.dat",
    "path": "results/synthetic_kpath.json"
  },
  "output": {"stem": "results/synthetic_bands", "formats": ["pdf", "png"]}
}
```

```bash
julia --project=. scripts/plot_band_structure.jl --config synthetic_band_plot.json
```

This writes `synthetic_bands.pdf`, `synthetic_bands.png`, and `synthetic_bands.plot.json`.

The default style is centralized in `scripts/visualization/`: Times New Roman
with the repository LaTeX font stack, fixed sizes/margins, blue band lines,
high-symmetry vertical separators, and a dashed `E-E_ref=0` line. PDF and
600-dpi PNG are the default. Supported command-line overrides are defined by the shared `band`
CLI. The removed positional and `--bands/--path` interfaces are not accepted; every single or
comparison plot must use `--config`. See [`VISUALIZATION.md`](VISUALIZATION.md).

The tool strictly checks the table header/column count, finite values, ascending
energies, JSON schema, k-point count, one-based node indices, node coordinates,
and cumulative distances. Its plot sidecar records input/script/output SHA-256,
script version, energy window, and rendering options with
`qualification=PRESENTATION_ONLY`. It never guesses a Fermi energy, path label,
or energy range from a material name.

---
