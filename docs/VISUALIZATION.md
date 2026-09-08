# Audited presentation-only visualization

WannierNLQG provides three post-processing entry points that are independent of
the numerical solvers:

- `scripts/plot_band_structure.jl`
- `scripts/plot_response_integral.jl`
- `scripts/plot_kslice.jl`

They share the style, parsing, rendering, and audit implementation under
`scripts/visualization/`. The default products are PDF, 600-dpi PNG, and a
`*.plot.json` sidecar. Every visualization product has
`qualification=PRESENTATION_ONLY`; plotting does not recompute a response or
promote the numerical, physical, or production qualification of its inputs.

## Configuration and style

Configuration precedence is command line, then `--config CONFIG.json`, then the
built-in defaults. Every entry point accepts:

```bash
--config CONFIG.json
--style STYLE.json
--set style.axis_font_size=8
--curve 'dataset.marker="o"'
```

`--style` may override only fields already present in the style schema. JSON can
select fonts, LaTeX, sizes, canvas, DPI, margins, subplot spacing, ticks, and
legend placement. A `curves` object may select `color`, `linestyle`,
`linewidth`, `marker`, `markevery`, `zorder`, `markerfacecolor`,
`markeredgecolor`, and `markersize` by dataset id or label. Unknown fields fail
closed.

The default publication profile requires Times New Roman, `pdflatex`,
`newtxtext/newtxmath`, `bm`, and `textgreek`. Missing dependencies fail closed;
the renderer does not silently substitute a font or Mathtext. Minor ticks are
off by default. Major ticks use a 3.5-point length unless explicitly overridden.
`style.legend.bbox_to_anchor` may be null or a finite two- or four-element
array.

## Band structures

Band plotting accepts a shared JSON configuration only:

```bash
julia --project=. scripts/plot_band_structure.jl --config band_plot.json
```

The old positional interface, `--bands/--path`, and the internal band-manifest
bridge are intentionally rejected. Single and comparison modes use the same
strict configuration contract.

```json
{
  "mode": "single",
  "datasets": [{
    "type": "wanniernlqg",
    "id": "demo",
    "label": "Synthetic model",
    "bands": "results/synthetic_bands.dat",
    "path": "results/synthetic_kpath.json"
  }],
  "output": {"stem": "results/synthetic_bands", "formats": ["pdf", "png"]}
}
```

Supported dataset types are `wanniernlqg`, explicitly described `table`,
`qe_xml`, `vasprun_xml`, and native VASP `EIGENVAL` plus `KPOINTS` and `POSCAR`.
Every table or XML input requires a
`wanniernlqg.visualization-band-path` sidecar containing ordered fractional
k-points, cumulative distance, nodes, and a common energy reference. Energy
units and absolute or relative conventions must be explicit. XML and path
sidecars must declare
`kpoint_coordinate_convention=fractional_crystal`; VASP data must select a
spin channel.

Comparison mode requires identical ordered paths, distances, nodes, and energy
reference. It performs no interpolation, energy fitting, or implicit band
discarding. `comparison_audit=equal_bandwise` requires explicitly selected
equal-sized sets. `comparison_audit=display_only` permits overlays with
different band counts, records both counts, and computes no column-wise error.
Each dataset type accepts only its documented fields. An optional
`expected_sha256` object binds the relevant `bands`, `path`, `data`, or native
input files before parsing; actual input hashes are always written to the
sidecar.

### Native VASP input

A native VASP dataset uses `EIGENVAL` as the authority for ordered k-points and
eigenvalues. `KPOINTS` must be explicit line mode and supplies only segment
endpoints, labels, and point counts. Both endpoints of every segment are
retained, including repeated endpoints between neighboring segments. The
parser checks `NKPTS`, `NBANDS`, consecutive band indices, `ISPIN`, selected
spin channel, finite values, trailing data, and ordered-k parity.

`POSCAR` supplies row-lattice vectors. Distances use
$B=2\pi A^{-T}$. Reciprocal line mode uses fractional crystal coordinates.
Cartesian line mode follows the VASP $2\pi/a$ convention and therefore accepts
only one positive scale; negative-volume and three-component scales are
rejected because they do not define a unique $a$.

### Complete reference/model display sets

`comparison_audit=full_display_sets` is the strict route for unequal band
counts. The reference loads its complete display set, the model loads the
complete TB set, and neither may use `band_indices_zero_based`. The reference
uses `fitted_band_indices_zero_based` only to style the fitted pool; it does not
remove other reference bands.

`display_window_policy.mode=full_model_with_reference_context` constructs or
checks a window that contains the complete dispersion of every model band plus
the requested numbers of neighboring unfitted reference bands. Other reference
bands remain loaded and are clipped only by the axes. An explicit window that
clips a complete model band or requested context fails closed.

```json
{
  "mode": "compare",
  "comparison_audit": "full_display_sets",
  "reference": {
    "type": "table", "id": "reference", "label": "Reference",
    "data": "reference.dat", "path": "path.json", "x_column": 0,
    "energy_columns": {"start": 1, "stop": 33},
    "energy_unit": "ev", "energy_convention": "absolute",
    "fitted_band_indices_zero_based": [8, 9, 10, 11]
  },
  "models": [{
    "type": "table", "id": "model", "label": "Complete TB",
    "data": "tb.dat", "path": "path.json", "x_column": 0,
    "energy_columns": {"start": 1, "stop": 5},
    "energy_unit": "ev", "energy_convention": "absolute"
  }],
  "display_window_policy": {
    "mode": "full_model_with_reference_context", "padding_ev": 0.05,
    "unfitted_reference_bands_below": 1,
    "unfitted_reference_bands_above": 1,
    "minimum_unmatched_reference_states_per_k": 0,
    "maximum_unmatched_reference_states_per_k": null
  }
}
```

When a sealed match map is supplied, the minimum and maximum unmatched-state
fields are checked at every k-point. Without a match map they must remain zero
and null, respectively.

### Error plots from a sealed match map

Set `error_assessment.mode=precomputed_match_map` to audit an upstream match.
The renderer never computes or optimizes a Hungarian assignment. Instead, it
validates the CSV hash, indices, uniqueness, full coverage, reference and model
energies, signed errors, and cluster mismatch. It then recomputes per-k RMS and
maximum absolute errors, plus global RMS, P95, and maximum values, from the
currently loaded arrays. Each model must have exactly one map.

One invocation writes the ordinary plot triplet and an `_errors` plot triplet.
Both remain presentation-only evidence and cannot promote the upstream match.

## Integral responses

The response parser requires each tensor component exactly once in the header;
columns alternate as real and imaginary parts of each component.

```bash
julia --project=. scripts/plot_response_integral.jl \
  --mode compare \
  --input conventional.dat --label Conventional \
  --compare projector.dat --compare-label Projector \
  --components yyy,xyz --part real \
  --unit 'output units' --scale 1.0 \
  --output response_compare
```

`--components all` paginates the tensor. `--panel-columns` and
`--panels-per-page` control layout. A panel defaults to 2.4 by 1.8 inches and a
page is limited to 32,000,000 pixels at the final DPI. If necessary, the
renderer reduces panels per page and records the effective capacity. Multipanel
pages use shared axis labels and one shared legend. Component identity belongs
in the panel title; part and units belong in the shared y label. Single-panel
plots retain the complete component label.

`--part` accepts `real`, `imag`, `abs`, or `phase`. Comparison requires exact
array equality for Fermi energy, photon-energy grid, and component order. No
interpolation is implemented. `--unit` and `--scale` apply only a declared
display scaling; the renderer does not infer dimensionality, thickness,
lifetime, or unit conversions.

The x range is explicit. Without `x_window`, each panel uses the finite data
range. An explicit window must contain two finite increasing values. A
single-point or zero-width photon-energy grid fails closed. The default x label
is `$\hbar\omega\ \mathrm{(eV)}$`. Explicit labels override generated labels.

Legend fields may be set through `style.legend` or response-specific top-level
overrides. Without a bounding-box anchor, a single legend is placed inside the
first visible axes. With an anchor, figure-coordinate placement and compatible
margins are used. The sidecar records the source and resolved placement, target
panel, bounding box, whether it lies inside the axes, and sampled curve overlap.

## K-slice maps

A raw two-dimensional matrix is insufficient. Supply the `metadata.txt` from
the same run:

```bash
julia --project=. scripts/plot_kslice.jl --config kslice_plot.json
```

The parser checks calculation type, k mesh, origin, both slice vectors,
quantity, method, matrix shape, and the declared output inventory. `single-map`
accepts one real dataset and an optional paired imaginary dataset. `grid`
requires explicit inline panels or an explicit manifest; outputs are never
guessed from the metadata inventory.

Each panel may select `part`, `norm`, `vmin`, `vmax`, `linthresh`, `percentile`,
`cmap`, `colorbar_label`, title, unescaped math title, label, and order. One page
may combine diverging, positive-log, signed-log, and phase normalization.
Imaginary, magnitude, and phase views require an explicit imaginary partner.

Fractional mode does not alter the matrix. Centered mode requires the explicit
periodic-centered option and then applies `fftshift` and transpose, recording
both operations. Supported normalization modes are `linear`, `diverging`,
`positive-log`, `signed-log`, `phase`, and `auto`.

Cartesian mode reads `case_root`, `model_file`, `model_sha256`, and
`model_input_mode` from metadata. Legacy TB supplies a row lattice; Packed HDF5
is inspected read-only for schema, scientific digest, and `/model/lattice`.
The outer reader also verifies the full-file hash stored in metadata. A model
override must still match that hash. The fixed convention is row-lattice
$A$ in angstrom, $B=2\pi A^{-T}$, and
$k_{\mathrm{cart}}=B^T k_{\mathrm{frac}}$.

Projection modes are `intrinsic-plane`, `kx-ky`, `kx-kz`, `ky-kz`, and
`explicit`. The explicit route requires two orthogonal Cartesian directions.
Skew lattices use the actual cell-edge grid with `pcolormesh`; they are not
presented as a rectangular extent. Matrix storage is
`matrix[u_index,v_index]`, corresponding to runtime samples
$u=i/n_u$ and $v=j/n_v$. Each colorbar uses an explicit axes whose vertical
bounds are audited against the corresponding main axes at final output DPI.

## Sidecar audit contract

Every `*.plot.json` records at least:

- entry script and input/output paths, hashes, and byte counts;
- resolved configuration, input types, array shapes, components, units, and
  energy reference;
- scaling, complex part, transpose, FFT shift, normalization, and percentile
  transformations;
- VASP line-mode authority, repeated endpoints, spin channel, and reciprocal
  convention;
- K-slice model hash, direct and reciprocal lattices, Cartesian projection, and
  `pcolormesh` geometry;
- pagination capacity and final page pixel count;
- resolved x ranges, labels, font sizes, legend placement, axes bounding boxes,
  and overlap checks;
- comparison `max_abs` and `relative_l2` values;
- `qualification=PRESENTATION_ONLY` and `production_eligible=false`.

When the input has a limited physical qualification, set
`diagnostic_banner` or `--diagnostic-banner`. `DIAGNOSTIC ONLY` then appears in
both the figure and the sidecar. Rendering alone never removes an upstream hold.
