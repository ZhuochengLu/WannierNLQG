# Geometry defaults and Wannier mesh input

This internal successor changes two defaults deliberately. It does not change optical linewidths, SHG intermediate-state prescriptions, spin-current regularization, position bare-vertex cutoffs, or the meanings of band/subspace sums. Existing frozen calculations retain their own code and settings.

## Geometry regularization

The Conventional scalar Berry curvature, interband Berry curvature, interband quantum metric, ordinary quantum metric, Berry-curvature dipole/quadrupole, quantum-metric dipole/quadrupole and quantum Christoffel tasks default to `denominator_regularization = 0.0` eV. Omission and explicit zero have the same numerical meaning, with separate DEFAULT/USER provenance. Shared response numerics count as supplied values; local task controls override them.

For these geometries, zero means an explicit unregularized inverse gap, with zero diagonal eigenvector correction. The response checks the applicable spectral-isolation domain before consuming the result, at every consumed finite-difference point. Zero never means a hidden positive floor or an arbitrary choice of individual states inside a degenerate block. The initial scalar implementation conservatively requires the full eigenframe to be isolated at its spectral error threshold; an isolated selected composite group alone does not guarantee admission. The existing analytic BCD/BCQ recurrence retains its same full-eigenframe restriction.

A finite positive supplied width retains the regularized geometry `Delta/(Delta^2+eta^2)`. For tasks with a geometric derivative it uses the existing finite-difference expression. Analytic BCD/BCQ plus a positive width is an error; an explicit analytic backend is never silently replaced. An explicit finite-difference backend accepts zero. Zero by itself does not request an analytic implementation of a task that only has finite differences. A static metric/curvature has no outer derivative to switch. Negative/nonfinite widths are errors. Finite-difference steps remain finite and strictly positive.

BCD/BCQ conductivity keeps its supported expression/model restrictions. Its analytic derivative default remains analytic at zero; an applicable positive width selects finite differences when no backend was explicitly supplied. The BCD Fermi-surface expression with no local geometric derivative retains zero regularization and does not acquire a fictitious finite-difference step.

## External metric completion

Ordinary Quantum Metric and its dipole, quadrupole and Christoffel tasks accept an optional task physical control, `include_external`, defaulting to `false`:

```toml
[response.tasks.metric]
kind = "QMK"
include_external = false
# Supply the usual observable and sampling settings.

[response.tasks.metric.numerics]
denominator_regularization = 0.0
```

A shared `response.include_external` is also supported for applicable tasks; a task-local value takes precedence. This is a Boolean, not a numerical width.

With `false`, the primary result is the metric internal to the retained model space. Orthogonal Wannier input needs H/r. Nonorthogonal localized input needs H/S/r; their Cartesian derivatives follow from the real-space coefficients. No full derivative-overlap matrix F is read, validated, allocated or fabricated for the external completion, and no external-component result file is written. Other responses in the same task bundle retain their independent operator requirements: disabling metric completion does not remove F needed by orbital magnetization or projector responses. The primary filename and numerical column layout remain unchanged; per-task metadata identifies the changed metric definition.

For orthogonal input, `true` computes the total metric and the existing internal and external component files. It requires the same qualified complete F input as before; no energy-weighted orbital-magnetization operator is required. For nonorthogonal input, `true` fails before output creation with `NONORTHOGONAL_EXTERNAL_METRIC_UNSUPPORTED`. It never silently becomes internal. Specified interband-pair metrics keep their own pair average and do not gain an ordinary single-band external term.

This response option does not reinterpret existing task-derived bundle manifests or the Wannierization producer's `operator_tasks` declarations. Those retain their recorded full-geometry operator contracts. The ordinary Hamiltonian/position output profile supplies the minimal orthogonal model for internal metric runs.

To reproduce the old regularized total metric settings, explicitly select the old positive width and `include_external = true`. Preserving those settings is not a claim of equality until their affected regression checks have passed. Old TOML files omitting either setting can change numerical results or now fail spectral-isolation checks. Results are not silently interpreted using the old defaults. Effective TOML writes the resolved values. Configuration records and per-task metadata retain effective settings and origins. The geometry option identity includes the metric definition, method, numerical controls and observable; a changed definition must not be treated as the same result. K-slice execution currently has no persisted numerical checkpoint to resume.

## Wannierization mesh sources

The normalized mesh adapter accepts:

```toml
[kmesh]
source_file = "KPOINTS"
source_format = "vasp_kpoints" # or vasp_xml / qe_input / qe_xml
```

Explicit `dimensions` and `points_fractional` remain supported. Dimensions can come from a declared regular generating grid. Actual point order always belongs to the wavefunctions or to the external matrix-file point list, not to a newly generated/sorted grid. Conflicting declarations are errors.

Native QE continues to use saved `data-file-schema.xml` MP dimensions/offsets and actual saved-wavefunction headers. Native grid declarations are read without requiring XML coordinate conversion or `alat`; the actual ordered coordinates still come from the wavefunction reader. A designated `qe_xml` actual point list retains the full geometry reader's unit/`alat` requirements. A designated QE `K_POINTS automatic`, `gamma` or `crystal` input can supply additional declarations. Cartesian input cards and band paths are rejected rather than guessing alat or path semantics.

Native VASP can use a designated `vasprun.xml` or `KPOINTS`. If an explicit mesh source is absent, it checks only same-WAVECAR-directory `vasprun.xml`, then `KPOINTS`, deterministically. Saved actual WAVECAR points remain authoritative. The reader supports labelled Gamma/Monkhorst-Pack three-division meshes and their grid-step shifts. It does not derive dimensions from KSPACING, a one-number automatic request, a path, or an irreducible list. Use saved XML or explicit dimensions for those input-declaration cases. With explicit dimensions, native automatic discovery can treat a valid scalar Automatic request or absent/unsupported XML generation as unspecified; actual wavefunction points still determine order and complete-grid admission. Recognized regular declarations with invalid values or conflicting dimensions/offsets remain errors. A designated `source_file` retains strict format admission.

For external EIG/MMN/AMN matrices, a generating grid never establishes matrix point order. Both dimensions and an actual point list are required: either explicitly or via a designated supported point-list file. Completeness, uniqueness, periodic grid membership, offset and native point order are checked; no symmetry expansion invents missing wavefunctions. Effective geometry stores the resolved dimensions and ordered coordinates for replay.
