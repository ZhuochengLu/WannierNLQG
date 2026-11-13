# TOML task input

The text frontend constructs the existing public TaskConfig and calls its public run. It does not implement response formulas, a separate task registry, or an MPI launcher. File parsing and record writing belong to IO; configuration resolution belongs to Runtime.

Run the Julia user entrypoint with the package environment:

```bash
julia --project=/path/to/package /path/to/package/scripts/wanniernlqg.jl init input.toml
julia --project=/path/to/package /path/to/package/scripts/wanniernlqg.jl check input.toml
julia --project=/path/to/package /path/to/package/scripts/wanniernlqg.jl explain input.toml --verbose
julia --project=/path/to/package /path/to/package/scripts/wanniernlqg.jl run input.toml --records records
```

The template deliberately omits model files, occupation, temperature, photon energies and sampling dimensions. Fill these physical parameters before running. check returns exit 2 for pending required input, exit 1 for invalid input, and exit 0 for validated configuration. Configuration validation does not establish scientific convergence or complete payload qualification. It performs no matrix integration or MPI initialization.

User TOML has no `schema_version` field; providing it is an unknown-key error. Record, checkpoint and operator-model schemas are independent and validated by their own consumers. `model`, `response` and `output` are tables, and each `[response.tasks.<name>]` table defines one task. The table name is its task ID; a redundant internal `id` is rejected. All 63 registered method/calculation combinations across the response/Band families are expressible through the same public typed configuration. Registration does not grant missing model operators, extra algorithms or material qualification. Sampling is shared BZMesh, KSlice, KRegion or KPath. Unknown fields and per-task sampling/execution overrides are rejected.

An omitted method selects Conventional when registered for the actual sampling, otherwise the unique registered method. Multiple remaining methods require an explicit choice. An omitted backend requests auto; Band paths and paired photon paths resolve that request to their supported Direct evaluator with DERIVED provenance. Explicit invalid factors still fail. Auto does not search for an optimal FFT layout. Only all-Integral tasks without slice/path/region intent can default `sampling.kind` to `bz_mesh`; meshes and physical geometry remain explicit. For a KSlice single component, Cartesian axis bounds follow the component; an omitted `spatial_dimension` does not block yz/xz observations. FullTensor Integral axis counts and Band periodic axes retain their own meaning.

An explicit `output.system_name` wins. Otherwise its prefix comes from the actual Packed/TB file or seed, or the supplied native identity, with filename characters sanitized. It is not a guessed material name. Task-ID directories and existing output protection remain in effect.

LT uses `fermi_energies_ev`, `temperature_k` and a `relaxation` table containing positive `gamma_intra_ev` and `gamma_inter_ev`. LOR uses the photon-energy axis, single Fermi energy, temperature and the same relaxation table. OM uses `fermi_energies_ev`, temperature and explicit `input_semantics`. Existing spectral FS controls and the KSlice single-Fermi-axis constraint remain mandatory. SHG accepts `output`/`response`; THG additionally accepts `formulation`. JC accepts `projection`. The removed `response_measure`, `sheet_axes` and `effective_thickness_angstrom` fields are rejected at both shared and task-local input boundaries; perform sheet/line/effective-thickness conversions in postprocessing. Defaults come from those existing constructors. Numerics accepts its current public names; symbolic selectors `fs_kind`, `prescription` and `occupation_derivative_mode` are TOML strings.

KSlice observations use `component` plus the existing band_targets, subspace, subspaces, occupied_bands, all_bands, transition, interband_groups or triple_groups selection. Integral JC/THG also accept `kind="tensor_components"` and an ordered `components` array of four-index arrays; other Integral tasks use full_tensor. Rank, spin-axis, group and occupied-sum legality is unchanged. Band has no response observable. Geometric-loop ShiftVector can carry their existing optional fixed Cartesian photon momentum; other geometry methods reject it. Ordinary Quantum Metric and its dipole/quadrupole/Christoffel tasks default to `include_external=false` (internal geometry). Explicit `include_external=true` requires qualified full derivative-overlap data for orthogonal input; cold checking rejects insufficient completion declarations and validates Packed manifest demand/provenance. Nonorthogonal external completion is unsupported. Interband metrics keep their own pair definitions. See [the contribution option](GEOMETRY_OPTIONS_MIGRATION.md#external-metric-completion). Operator payload and material gates still apply at run.

Uniform integration remains the default. Existing adaptive controls are a table:

```toml
[response.execution.integration_algorithm]
kind = "h_adaptive_cubature"
atol = 1e-8
rtol = 1e-5
max_evaluations = 100000
initial_divisions = 1
```

This admits only the existing Integral THG and Conventional SC/IC/SHG paths, positive temperature/width, q=0, Direct/auto and a supported actual domain. An affine region is not replaced by its enclosing rectangle. Tolerances and budgets retain the existing complete-rule semantics; acceptance is not convergence.

Energy and broadening are eV; temperature_k is Kelvin. The frontend never infers a chemical potential of zero. KSlice planes use reciprocal fractional coordinates. Paths are relative to the input file directory, including snake_case nkdiv/nkfft mapping to the existing execution fields.

Each parsed value records USER, DEFAULT, INHERITED or DERIVED separately from RESOLVED or PENDING. Defaults come from existing constructors and the existing quantity/method/model-aware resolver. A task occupation override represents postprocessing of a frozen model, not a new self-consistent calculation. Trusted Julia callers may supply inherited physical entries with value, origin, unit and state. Independent files cannot bind an unavailable SCF producer.

The Julia APIs read_task_input and resolve_task_input return a response TaskInputResolution or a preparation WorkflowInputResolution. source="julia" requires an explicitly identified existing native model supplied as the model keyword; arbitrary callbacks are not file-replayable. source="wannier" uses existing Wannier TB or operator-bundle paths. The existing Packed HDF5 bundle does not provide a generic nonorthogonal H/S/r reader.

Records contain config_resolution.toml, config_explanation.md and actual run_provenance.toml. A resolved file model also receives effective_config.toml, which the same reader accepts. An auto backend remains pending before model and layout selection, so checking or explaining it does not emit effective_config. After run, the frontend reads each task's actual backend and factors from the existing runtime metadata and records the metadata SHA alongside the derivation. The original USER auto request remains in the provenance override chain. A shared effective_config is emitted only when all tasks realized the same execution choices. Otherwise the records retain per-task choices and explain why one shared execution table cannot replay them. Missing or malformed runtime readback remains pending; it does not relabel a completed numerical calculation as failed.

Use a new records directory when changing from a resolved request to a pending or non-file-replayable request. An existing effective_config is preserved and such directory reuse is rejected. A Julia model entry requires its Julia payload for replay. Actual qualification warnings and failures retain the existing ordinary calculation semantics.

For a small synthetic example, save the following in a run directory and replace model_file with the absolute path to examples/fixtures/synthetic_runtime/synthetic_tb.dat in your package. Select a new external output directory. These explicitly supplied occupations and energies describe this synthetic model, not a converged material.

```toml
[model]
source = "wannier"
model_file = "/absolute/package/examples/fixtures/synthetic_runtime/synthetic_tb.dat"

[response]
fermi_energy_ev = 0.0
temperature_k = 0.0
photon_energies_ev = [0.25, 0.5]

[response.sampling]
kind = "bz_mesh"
k_mesh = [1, 1]
spatial_dimension = 2

[response.execution]
fourier_backend = "direct"

[response.tasks.shift]
kind = "shift_current"
method = "Conventional"

[output]
output_root = "/absolute/external/results"
progress_enabled = false
```

Task names are the unique IDs: `[response.tasks.shift]` declares the ID `shift`. Several named tasks may use the same `kind` and different task-local physical or numerical parameters. A task-local energy axis replaces the entire shared axis; it does not concatenate with it. An `id` field inside a named task is forbidden, even when it equals the table name. IDs retain the existing ASCII and case-insensitive collision checks and their existing output-directory meaning.

The text reader always orders tasks by full ID in ASCII lexicographic order (for example `shift_1`, `shift_10`, `shift_2`), independently of TOML table order. There is no `task_order` setting. The typed Julia `TaskConfig.tasks` vector keeps its own explicit order. Effective input files use named tables too; resolution provenance uses `response.tasks.<ID>...` paths and records execution IDs separately.

Only named task tables are accepted. Unsupported task layouts are rejected before model loading. Numerical matrix arrays and unrelated Manifest/run record arrays of tables retain their documented meaning.

An effective file explicitly spells out resolved numerical values. Reading it again therefore records those entries as USER values, while retaining the same physical and numerical task. Original default/inheritance origins remain in the separate config_resolution.toml. Compare effective task semantics separately from the original explicit_numerics request.

## Cartesian KRegion and finite photon momentum

Uniform KRegion sampling defaults to midpoints. To select half-open left endpoints on the original declared region, use:

```toml
[response.execution.integration_algorithm]
kind = "uniform"
region_quadrature = "left_endpoint"
```

Parameter nodes are `i/N`, `i=0:N-1`, with the first parameter varying fastest. This leaves the region and equal weights unchanged. The existing `"uniform"` string keeps its default behavior. A nondefault region rule requires an Integral KRegion task; it does not reinterpret BZMesh, KSlice or KPath sampling.

`response.sampling.kind="k_region"` uses the existing public KRegion constructor. Box input supplies `lower`, `upper`, `k_mesh`, and the matching physical `spatial_dimension`. An affine input instead supplies `origin`, `vector_1`, `vector_2`, two mesh counts and `spatial_dimension=2`, even for three-component Cartesian vectors. Coordinates are in inverse Angstrom, and box bounds cannot be combined with affine vectors. `explain` records the USER vectors and their units, and DERIVED geometry, unfolded coordinates, midpoint rule, `nsamples`, domain measure and physical point weight. The effective input retains the same constructor fields; derived explanations are not a second set of input knobs.

Photon-drag shift/injection tasks use the existing `PDSC`/`PDIC` registry and `FiniteQOpticalParameters`. Supply `photon_momentum_A_inverse=[qx,qy,qz]` in the shared response table or override it on the photon-drag task. It is a required physical input, not a numerical default. Task-local momentum on other families is rejected except the existing optional Geometric_Loop ShiftVector input; shared momentum needs an applicable task. Momentum does not imply periodicity or introduce a new finite-q kernel.

For a frequency-dependent photon momentum, replace the scalar input with `photon_momenta_A_inverse`, an array of Cartesian three-vectors. Its length must equal `photon_energies_ev`; row `i` computes only `(energy[i], momentum[i])`, without a Cartesian product. The public Julia equivalent is `FiniteQOpticalParameters(photon_energies=energies, photon_momenta=momenta, fermi_energy=mu, temperature=T)`. Scalar and paired inputs are mutually exclusive, including inherited shared inputs. Energies and momenta are copied at admission; nonfinite values, Boolean values and unequal lengths are rejected.

Two further text sources lower into that same zipped path. Exactly one of fixed, paired, enhancement or CSV must be supplied. Enhancement uses `photon_momentum_enhancement=eta` and an explicit nonzero finite three-vector `photon_momentum_direction`. The direction is normalized and `q=eta*energy_ev/1973.269804` in inverse Angstrom. Eta and energies must be finite and nonnegative; eta=0 is allowed, and reversing direction reverses q.

The CSV form uses `photon_momentum_table_file` plus the same direction. Its exact header is `energy_ev,q_A_inverse`. Both columns must be finite nonnegative real numbers, and energies strictly increasing without duplicates. Exact nodes and in-range endpoints are preserved; intermediate magnitudes are linearly interpolated, with no extrapolation, sorting or query deduplication. Paths are relative to the TOML directory. The cold reader reads each table once and records its absolute path, byte SHA256, normalized direction and actual original-order (E,q) rows. Effective TOML contains the resulting explicit paired axis.

The initial paired mode supports the existing conventional injection and geometric-loop shift families on a uniform BZ mesh, with orthogonal file Wannier or `RealSpaceTBInput` models and explicit `fourier_backend="direct"`. Analytic and nonorthogonal models, slices/regions, Mixed Fourier and symmetry projection are rejected for this mode. The text auto request resolves to Direct. Existing fixed-momentum support is unchanged.

```toml
photon_energies_ev = [0.3, 0.7, 0.3]
photon_momenta_A_inverse = [[0.04, 0.02, 0.0], [-0.04, -0.02, -0.0], [0.04, 0.02, 0.0]]
```

The numerical tensor retains its existing columns. A companion `<response.dat>.photon_momentum_path.toml` records original row indices, energies in eV, momenta in inverse Angstrom, Cartesian coordinates and `pairing="zip"`. Its SHA binds the exact tensor bytes. Qualified IO port `WannierNLQG.IO.read_photon_momentum_path_record(path)` checks this binding and the formatted tensor energy axis. Identical momenta reuse interpolation endpoints; signed zeros retain distinct exact grouping keys. Opposite momenta keep independent response traces; identical endpoint keys may reuse raw interpolation data. Grouping changes neither output row order nor the per-row k-point and band-pair summation order.

Worker-local interpolation reuse defaults to 128 entries and 16 MiB of estimated retained payload per central k point. `WANNIERNLQG_PHOTON_PATH_CACHE_BYTES` accepts 0–268435456 bytes per worker as a request; zero disables reuse. The resolved per-worker allowance is at most 256 MiB divided by the actual Julia worker count, so cache payload allowances sum to at most 256 MiB per rank. The total run RSS budget must also include every rank and worker workspace. The 256 MiB setting is an explicit measured configuration, not the portable default. Entries larger than the selected budget are rejected before dense-array or eigensystem snapshots are copied. The frequency scratch processes at most 32 rows at a time; `WANNIERNLQG_PHOTON_PATH_BLOCK_SIZE` selects 1–32 rows. Frequency blocking and endpoint-cache capacity are independent controls, not automatic process RSS limits. These limits do not cap the final O(N) response array. Paired rows use the scalar frequency contraction; equivalence to the old large-axis GEMM branch requires separate measurement. This implementation does not claim cold, parallel or material qualification from a serial smoke test.

The example `examples/native_models/nonperiodic_parallelogram.toml` is deliberately an identified Julia-model entry rather than serialized callback code. After setting its output path, use the existing chain:

```julia
include("/absolute/package/examples/native_models/nonperiodic_parallelogram.jl")
input = read_task_input("/absolute/path/to/your/input.toml"; model=build_model())
println(explain_task_input(input; verbose=true))
result = run_task_input(input; record_directory="/absolute/external/records")
```

The ordinary CLI can check/explain this file's unresolved model requirement; it cannot evaluate a callback name from TOML. A Julia callback entry requires the same supplied model when replaying the effective configuration. It has no file-only scientific replay claim. Numerical convergence, MPI behavior and cold-start performance require their own assessment.

For a three-dimensional affine `k_region`, set `spatial_dimension=3`, supply three-component `origin`, `vector_1`, `vector_2`, `vector_3`, and three positive `k_mesh` counts. The same resolver records user vectors in `A^-1`, derived absolute-determinant domain measure in `A^-3`, and per-node weight in `A^-3`. `effective.toml` retains these original inputs; `explain_task_input` reports the single resolution chain. A missing third vector stays pending instead of silently using a rectangle or a two-dimensional area. See `examples/native_models/nonperiodic_parallelepiped.toml`; model callbacks are supplied via the existing Julia payload keyword and are never serialized or evaled.


Band text tasks need explicit `fermi_energy_ev`, without photon energy or temperature. A Band-only input can omit `sampling.kind`; missing nodes generate a structural path and missing counts use moderate Cartesian sampling. Manual nodes and explicit endpoint-inclusive counts take precedence. See [BAND_STRUCTURE.md](BAND_STRUCTURE.md#automatic-structure-paths-and-omitted-sampling-controls) for minimal TOML, actual structure requirements, two-dimensional periodic axes, magnetic/time-reversal boundaries and the current branch-aware sidecar.

## Energy axes and consumers

Photon energy accepts exactly one of these complete expressions:

```toml
[response]
photon_energies_ev = [0.0, 0.5, 1.0]
```

```toml
[response]
photon_energy_min_ev = 0.0
photon_energy_max_ev = 4.0
photon_energy_step_ev = 0.02
```

```toml
[response]
photon_energy_min_ev = 0.0
photon_energy_max_ev = 4.0
photon_energy_num_points = 200
```

Use the corresponding `fermi_energies_ev`, `fermi_energy_min_ev`, `fermi_energy_max_ev`, `fermi_energy_step_ev` or `fermi_energy_num_points` for the existing LT/OM scan axis. `fermi_energy_ev` remains a scalar for its existing consumers; it is never automatically subtracted from photon energy. Shared scalar and scan defaults may coexist when different tasks consume them. Each task receives only its own supported axis; irrelevant local fields fail. A shared field with no applicable task fails; a legal default overridden by a local value remains a legal shared declaration.

Point counts include both endpoints and must be positive integers, excluding Bool. One point requires equal endpoints; more than one requires increasing endpoints. Step ranges use indexed generation and preserve the fixed spacing: 0..4 by .02 has 201 points; 0..1 by .3 stops at .9. A rounding-only endpoint excess of at most eight ulps at the endpoint/step scale (also bounded by 1e-9 of one step) is clamped to max. No shortened last interval is appended. Generated axes are limited to 1,000,000 points, finite Float64 values and strict increase; unresolved spacing or count overflow fails before allocation. The axis-expansion layer preserves explicit array order, duplicates and nonuniform spacing; it neither sorts nor deduplicates them. This is not a promise that every task accepts every preserved array. The current public AHC, LT, OM and Berry multipole scan-parameter constructors require their effective `fermi_energies_ev` axis to be nonempty, finite and strictly increasing without duplicates. The spectral result reader also checks its required scan-axis contract. These are consumer contracts, not a universal requirement for photon-energy arrays, every low-level response function or a pending draft configuration. Low-level functions retain their own documented domains and ordering behavior.

A shared explicit Fermi array currently receives finite-element/type checks in axis expansion, while the applicable scan constructor checks the effective array after task-local replacement. This description does not add a new pre-override ordering or emptiness check.

A complete task-local expression replaces the shared axis as a whole. Partial local ranges do not borrow shared endpoints; malformed shared ranges fail even if every task overrides them. Range leaves retain USER provenance, expanded arrays are DERIVED, and effective_config contains standard explicit arrays.

## Columnar Band nodes and Packed-only models

```toml
[response.sampling]
kind = "k_path"
kpoints_per_segment = 21
branches = [[1, 4]]

[response.sampling.nodes]
label = ["G", "X", "M", "G"]
fractional_coordinates = [
    [0.0, 0.0, 0.0],
    [0.5, 0.0, 0.0],
    [0.5, 0.5, 0.0],
    [0.0, 0.0, 0.0],
]
```

Old nodes arrays of tables are rejected without compatibility parsing. Labels must be nonblank strings; coordinates are three finite reals excluding Bool. Order, repeated labels/points and coordinates outside the first BZ are preserved. Counts, branches and density remain in sampling. Omitted counts use the actual model lattice, including a validated Packed bundle's manifest lattice, without requiring an additional TB file. Automatic paths still need real atomic structure from the existing structure input; lattice/orbital centers alone are insufficient. No new response band-interval grammar is introduced in this change.

## Preparation workflows

Each file selects exactly one workflow. The supported preparation workflows are `wannierization` (ordinary or symmetry_adapted), `symmetrization` (projection), and `mesh_screening`. Removed gauge-aware modes and optimizers are not restored.

The reader accepts only the documented normalized tables. Unsupported or mixed configuration layouts raise an error before execution.

Use `init FILE --workflow wannierization --workflow-mode ordinary` or `symmetry_adapted`, or `init FILE --workflow symmetrization --workflow-mode projection`. Meaningful sections remain: `[source]`, `[structure]`, `[kmesh]`, `[basis]`, `[matrices]`, `[windows]`, `[solver]`, `[checkpoint]`, `[output]`. Advanced Wannier input controls live in `[input]`; nested solver controls keep their names. The six independent Z/U stage controls are direct `[solver]` keys. `[matrices.provider]` retains supported explicit matrix providers, `[source]` retains QE/VASP source constructors. Julia callbacks and in-memory objects stay in Julia. Polymorphic controls retain explicit `kind` discriminators.

`[output].final_tb_symmetry_report_enabled` is a Boolean, default `false`. `true` runs the existing final TB check and reports its actual measurements; it is not a display-only switch. `profile` and `operator_tasks` are mutually exclusive. Projection retains `[model]`, `[symmetry]`, `[magnetic]`, `[validation]`, `[output]`, including auxiliary CHK/EIG/MMN/SPN, tolerances, support, cutoff and overwrite.

All paths resolve relative to the TOML file. Effective configuration includes the resolved supported controls and is readable by the same normalized parser. Unknown keys and conflicting ownership are rejected rather than ignored. Meaningful response groups, independent time-domain JSON, LocalPreferences.toml and environment variables are outside this consolidation.

See [NORMALIZED_WANNIERIZATION_INPUT.md](NORMALIZED_WANNIERIZATION_INPUT.md), [TEXT_INPUT_UNIFICATION.md](TEXT_INPUT_UNIFICATION.md), and the generated templates.

## Explicit values and task overrides

Every explicitly supplied shared or task-local value is checked for its type and basic domain before overrides are applied. For example, a negative shared `broadening` is an input error even when a task supplies a positive local value. A legal local value may override a legal shared value; the effective value and its origin remain available in the resolved configuration and provenance. Task applicability and coupled constraints are checked on the merged effective configuration. Zero regularization is not forbidden for every task, and a finite nonpositive `transition_window_factor` retains its existing no-screening meaning where that branch applies.

Direct 1D/2D native physical models are supplied through the existing Julia payload route. Their physical lattice and callback shapes determine dimension; no auxiliary vector or dimension marker is accepted in TOML. Derived completion and normalization appear in explanation metadata. See [direct low-dimensional model inputs](NATIVE_MODELS.md#direct-low-dimensional-physical-inputs).
