# WannierNLQG v1.0.0 User Guide

[Task examples](examples/tasks/) | [Bundle examples](examples/bundles/) | [Architecture](docs/ARCHITECTURE.md) | [Documentation index](docs/README.md)

The response API separates shared model/sampling configuration from independently
parameterized tasks. `TaskConfig` owns `model`, `sampling`, `tasks`, `execution`,
and `output`. Every `TaskSpec` owns a unique `id`, a registered `quantity` and
`method`, and its own `physics`, `numerics`, and `observable`. The 38 registered
quantity/method/calculation combinations are listed in section 6.

> **Scope of numerical examples.** All maintained examples use repository-owned
> synthetic inputs. The ordinary presets use 100 by 100 Integral meshes, 200 by
> 200 K-slice meshes, and 200 optical energies for Integral responses. These are
> demonstrations, not material-independent convergence recommendations. The
> automated smoke runs explicitly override the mesh to 2 by 2 (or three points
> per Band segment). Recheck every physical parameter for scientific work.

## 1. Configuration ownership and parameter reference

There is no fixed input filename. Import `WannierNLQG`, build a grouped
`TaskConfig`, and call `WannierNLQG.run(config)`. Flat keywords such as
`TaskConfig(fermi_energy=...)` and tuple entries in `tasks` are not part of the
public API. See the [public API overview](docs/MIGRATION_1.0.0.md).

### 1.1 Shared groups

| Owner | Fields | Required values and meaning |
| --- | --- | --- |
| `TaskConfig` | `model`, `sampling`, `tasks`, `execution`, `output` | The first four are explicit. `output` defaults to `OutputOptions()`. Each run has one shared sampling object. |
| `ModelInput` | `model_file`, `real_space_operator_bundle_file`, `seedname`, `case_root` | Supply the selected model route explicitly. Packed HDF5 may be used alone; a simultaneous TB must match its paired digest. Legacy seed input applies to supported spin-current routes. Relative paths resolve from `case_root`. |
| `ModelInput` | `wannier_center_convention` | `"Convention_II"` by default; `"Convention_I"` selects centered Bloch sums. Disk storage remains Convention II. |
| `ModelInput` | `real_space_replica_policy`, `wsvec_file`, `mp_grid`, `wigner_seitz_tolerance`, `wigner_seitz_search_size` | Default policy `"auto"`; explicit `"input"` or `"minimum_distance"`. Mapping inputs default to `nothing`, tolerance to `1e-5` angstrom and search size to `3`. Materialized support is reused once; inconsistent lifecycles fail. |
| `ModelInput` | `spin_enabled`, `spin_file`, `checkpoint_file`, `spin_file_formatted` | Explicit legacy spin input. Defaults: `false`, empty paths, `false`. Do not combine legacy operator inputs with Packed HDF5. |
| `BZMesh` | `k_mesh`, `spatial_dimension` | Explicit positive 2- or 3-entry mesh for Integral responses; dimension defaults to mesh length. |
| `KSlice` | `k_mesh`, `spatial_dimension`, `origin`, `vector_1`, `vector_2` | Explicit positive 2-entry mesh and an explicit plane in reciprocal fractional coordinates. Spatial dimension sets Cartesian index limits. |
| `KPath` | `nodes`, `kpoints_per_segment`, `spatial_dimension` | Task-independent connected reciprocal-space path and segment counts; at least two points per segment. Spatial dimension defaults to `3`. |
| `ExecutionOptions` | `fourier_backend`, `NKdiv`, `NKFFT` | Backend is required: `"direct"`, `"mixed"`, or `"auto"`. Factors default to `nothing`. |
| `ExecutionOptions` | `response_symmetry_file`, `response_symmetry_policy`, `response_symmetry_kmesh_mode`, `response_symmetry_report_enabled` | Defaults: `nothing`, `"strict"`, `"reduced"`, `false`. See [response symmetry](docs/RESPONSE_KMESH_SYMMETRY.md). |
| `OutputOptions` | `output_root`, `system_name`, `response_output_digits` | Defaults: empty output root, inferred system name, `7` response digits. Keep generated output outside the source package. |
| `OutputOptions` | `progress_enabled`, `progress_percent_interval`, `progress_verbosity` | Defaults: `true`, `nothing`, `"normal"`; verbosity also accepts `"quiet"` and `"diagnostic"`. `nothing` reads `WANNIERNLQG_PROGRESS_PERCENT_INTERVAL` and otherwise uses 5%; explicit values must be integers from 1 through 100. |

Direct Fourier forbids `NKdiv` and `NKFFT`. Mixed requires at least one factor;
the other is inferred by exact division. If both are supplied, their
componentwise product must equal `k_mesh`. Auto uses Direct without factors and
tries the requested factorization with factors, subject to capability and memory
checks; it never searches for new factors. Band permits only Direct.

`WannierNLQG.out` shows one Fourier summary per Integral or K-slice execution
plan: task, backend, grid, local kpoints, and reduction lanes. Actual fallback
reasons remain visible; Direct does not report an unused FFT workspace as zero.
Use the existing `OutputOptions(progress_verbosity="diagnostic")` setting for
expanded progress details. The existing `progress.jsonl` retains the complete
Fourier fields, with additive display context and no schema-version change.
Stage timings distinguish individual tasks from the complete task bundle;
throughput is reported in `points/s`.

For multiple public tasks, the per-rank Mixed provider budget is divided across
the task instances. Auto first applies the existing single-task backend-selection
rule. If that selected Mixed plan cannot fit its additional multi-task provider
share, the run fails preflight; adding a task does not silently change another
task's selected backend to Direct. This budget covers the existing FFT provider
buffers only. The raw interpolation snapshot cache is separately bounded by the
current central k point, task count and requested offsets; it is not included in
that provider budget. Neither budget is a total process-RSS limit.

Replica preparation occurs after model/operator input and before Fourier
planning. One canonical mapping is applied to all required operators. Requested
and effective policies, source hashes, support counts and mapping digest are
retained in metadata. No adjacent model or wsvec filename is guessed.

### 1.2 Task identity and physical inputs

`TaskSpec(id="sc_narrow", quantity="SC", method="Conventional", ...)` defines
one task instance. Its calculation family is inferred from the shared sampling:
`BZMesh` selects Integral, `KSlice` selects K-slice, and `KPath` selects the K-path calculation domain. Sampling does not select the observable: the registry currently exposes `Band_Structure` as the only KPath task, while unregistered KPath response/geometry combinations fail closed. The
method may be omitted only when the quantity/calculation pair has one registered
method. IDs distinguish repeated instances of the same response and must be
unique ignoring case; an ID starts with an ASCII letter or digit and then uses
only ASCII letters, digits, underscores or hyphens. Canonical quantity names and calculation-specific short labels remain
supported; use `SC` for Integral and `SCK` for K-slice, for example.

| `physics` type | Explicit physical inputs | Meaning |
| --- | --- | --- |
| `OpticalParameters` | `photon_energies`, `fermi_energy`, `temperature` | Photon energy and chemical potential in eV; electronic temperature in K. All three are required. Integral accepts a nonempty energy array; current K-slice requires one energy. |
| `FiniteQOpticalParameters` | The three optical inputs plus `photon_momentum` | Photon momentum in inverse angstrom, explicit Cartesian momentum for the registered photon-drag responses; zero is an allowed limiting case. |
| `GeometryParameters` | No optical input; conditional `fermi_energy`, `temperature`, `photon_momentum` | Explicit subspace geometry needs no dummy frequency or broadening. Occupied-band selection requires chemical potential and temperature. Momentum is only accepted for a registered method that consumes it. |
| `BandParameters` | `fermi_energy` | Explicit reference energy in eV; exported energies are `E_n - E_ref`. |

Physical inputs do not inherit hidden material defaults from another task or
from environment variables. A q=0 task does not become a photon-drag calculation
by adding a momentum: select the registered photon-drag quantity and its physics
type. Irrelevant physical inputs fail rather than being silently ignored.

### 1.3 Numerical controls

| `numerics` type | Field | Default | Meaning |
| --- | --- | --- | --- |
| `OpticalNumerics` | `broadening`, `broadening_type` | `0.04`, `"Gaussian"` | Positive spectral width in eV and `"Gaussian"` or `"Lorentzian"` lineshape. |
| `OpticalNumerics` | `transition_window_factor` | `5.0` | Finite screening half-window factor in units of broadening; nonpositive values preserve the existing disabled-screening route. |
| `OpticalNumerics`, `GeometryNumerics` | `denominator_regularization` | `0.001` | Finite nonnegative interband denominator regularization in eV; SSC requires a positive value. |
| `OpticalNumerics`, `GeometryNumerics` | `degeneracy_threshold` | `0.002` | Nonnegative energy tolerance in eV; explicit values apply to non-Conventional, spin or photon-drag tasks. Other Conventional tasks reject this control. |
| `OpticalNumerics`, `GeometryNumerics` | `finite_difference_step` | `nothing` | Positive inverse-angstrom step for an applicable derivative/loop method; resolved default is `1e-4` when needed. Supplying it to an inapplicable method fails. |
| `OpticalNumerics` | `band_window_size` | `-1` | Calculation band window, with `-1` denoting all bands. This does not select output bands. |
| `GeometryNumerics` | `band_window_size` | `nothing` | Not an active geometry control: explicit values are rejected; choose output bands/subspaces through the observable. |
| `BandNumerics` | `hermiticity_tolerance` | `1e-10` | Nonnegative eV tolerance for `maximum(abs, H(k)-H(k)')` before diagonalization. |

An omitted `numerics` group selects the corresponding numerical defaults, which
are expanded in the effective configuration. They are numerical starting points,
not convergence recommendations. Methods using finite differences include
Projector/Geometric/Wilson methods and conventional BC/QM dipoles, quadrupoles,
and Quantum Christoffel Symbol; conventional HCT does not use that step.

## 2. Independent tasks and shared execution

Use `OpticalParameters` with q=0 charge/spin-current tasks,
`FiniteQOpticalParameters` with PDSC/PDIC, `GeometryParameters` with pure geometry,
and `BandParameters` with the Band_Structure task. The registry validates method, calculation,
physics type and observable together before execution.

Each task is compiled into a complete effective configuration. Single-task runs
perform the original interpolation calculations without snapshot reuse.
Multi-task runs may share
execution only when their required inputs and numerical dependencies are
compatible. Different frequency arrays, broadening or occupations retain their
own weights and screening; a task must never prune transitions required by
another. Incompatible configurations execute separately. Execution grouping is
an internal optimization, not a change in a task's physical meaning.

A run shares one sampling object. It does not mix Integral, K-slice and Band
sampling. Within that constraint, two copies of the same response may have
different parameters, and K-slice tasks may specify their own components and
band/subspace selections. The maintained independent-broadening example is
[`shift_current_broadenings.jl`](examples/bundles/shift_current_broadenings.jl).

## 3. Explicit band and subspace selectors

All band indices are Julia **1-based**. Put the selector in
`TaskSpec.observable = KSliceSelection(component=..., bands=...)`; raw legacy
`band_selection` tuples are not public task input.

| Selector | Meaning and compatible quantities |
| --- | --- |
| `Transition(conduction=[3,4], valence=[1,2])` | A conduction/valence pair or pair of subspaces for SCK, QHCK, SVK, ICK, ISCK, SSCK, PDSCK and PDICK. |
| `BandTargets([1,2])` | Two separate singleton targets for conventional BC/QM and supported target-geometry derivatives. |
| `Subspace([1,2])` | One two-band subspace. Internal transitions are excluded before the applicable geometric construction. |
| `Subspaces([[1,2],[3,4]])` | Several explicit nonoverlapping target subspaces, preserving their order. |
| `AllBands()` | All singleton BC/QM bands; no occupied-sum companion by default. |
| `OccupiedBands()` | Occupation-dependent sum for conventional BC/QM; supply `fermi_energy` and `temperature` in `GeometryParameters`. |
| `InterbandGroups(first=[3,4], second=[1,2])` | Two nonoverlapping groups for IBC, IQM, ZIBC, ZIQM and HCT. |
| `TripleGroups(first=[3], second=[4], third=[1,2])` | Three pairwise-disjoint groups for TPP. |

`BandTargets([1,2])` and `Subspace([1,2])` have different physical meanings.
To retain the old singleton-plus-sum output, use
`BandTargets([1,2]; include_occupied_sum=true)` or
`AllBands(include_occupied_sum=true)` and explicitly supply chemical potential
and temperature. The default `false` requests singleton outputs only.
Groups must be nonempty, duplicate-free and in bounds, with disjointness where
the selected policy requires it. Validation preserves the existing band/subspace
formula and file semantics. Integral uses `FullTensor()` and does not accept a
K-slice output selector. The calculation band window remains independent of the
observable's selected bands.

## 4. Tensor component conventions

Use `TensorComponent(2,2,2)` inside `KSliceSelection`. Cartesian axes are
`1:x`, `2:y`, `3:z` and restricted to the sampling's `spatial_dimension`;
a spin axis is always in `1:3`.

| Quantity family | Component order | Meaning |
| --- | --- | --- |
| BC, QM, IBC, IQM | `(a,b)` | Rank-2 Cartesian geometry |
| ZIBC, ZIQM | `(a,s)` | Spatial/dipole direction and spin direction |
| SC, PDSC, Shift Vector, IC, PDIC, QHC | `(a,b,c)` | Current/output direction followed by optical/geometric directions |
| ISC, SSC | `(a,s,b,c)` | Current, spin polarization, optical directions |
| BCD, QMD | `(a,b,c)` | Rank-2 geometry differentiated along `c` |
| BCQ, QMQ | `(a,b,c,d)` | Rank-2 geometry differentiated along `c,d` |
| QCS | `(r,l,j)` | Christoffel component |
| HCT | `(b,a,d,c)` | Implementation's Hermitian-curvature order |
| TPP | `(a,b,c)` | Three ordered vertex/direction indices |

Integral current tasks return the complete tensor. K-slice tasks independently
select a supported component; the execution planner separates incompatible
requirements instead of forcing all tasks to use one selector.

## 5. Self-contained synthetic examples

The 38 task files expose `build_config()` without executing on import. Their
physical inputs are written in each example, not hidden in `ExampleSupport`.
The helper resolves repository fixtures and output locations. Direct execution
uses the ordinary preset and is guarded by `PROGRAM_FILE`:

```bash
julia --project=. examples/tasks/integral/shift_current_conventional.jl
```

For an explicit **2 by 2 smoke run**:

```julia
include("examples/tasks/integral/shift_current_conventional.jl")
config = build_config(k_mesh=(2,2), output_root=mktempdir(), progress_enabled=false)
result = WannierNLQG.run(config)
```

Band smoke tests use `kpoints_per_segment=[3,3,3,3]`. Passing these checks
verifies runnable interfaces, not convergence of a material response. Copy a
configuration to your working directory, supply explicit scientific inputs and
choose convergence parameters before production. The package supplies neither
a fixed root `Input.jl` nor a cluster-specific `run.jo`; write a submission script
for your site's launcher and resource policy.

The shipped examples resolve `ExampleSupport.jl` relative to their original
package location. When adapting one into a separate case script, replace that
helper import with `using WannierNLQG` and replace the fixture/output helper calls
with your explicit case paths. Keep the package project active, for example
`julia --project=/path/to/package /path/to/case/calculate.jl`. Moving an unchanged
example file alone does not make its relative helper include portable.

Choose a fresh `output_root` for each run. An existing root or task metadata file
causes the public run to stop rather than overwrite a previous result.

### Explicit Mixed-FFT variants

Place factorization in `ExecutionOptions` and the mesh in sampling:

```julia
sampling = BZMesh(k_mesh=(100,100), spatial_dimension=2)
execution = ExecutionOptions(fourier_backend="mixed", NKdiv=(5,5), NKFFT=(20,20))
```

For a 200 by 200 K-slice, an illustrative factorization is `NKdiv=(10,10)` and
`NKFFT=(20,20)`. Acceptance depends on task capability and memory preflight.
Compare Direct/Mixed output and measure resource use before adoption.

## 6. Complete task catalog and input files

“Active controls” names only the task-specific controls beyond the common model/grid/numerical/output fields. Every linked file contains the complete `TaskConfig`. Complex K-slices normally produce `*_r_<method>.dat` and `*_i_<method>.dat`; band/group-real quantities produce the labelled real file(s) described in §3.

| # | Quantity | Method | Calculation | Physical/method summary | Required inputs | Active task-specific controls | Band/tensor meaning | q, spin, and Fourier limits | Typical output | Example |
| ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Shift Current | Conventional | Integral | Length-gauge q=0 second-order charge current | `_tb.dat` | Optical/occupation/smearing controls and band window | Full rank-3 tensor; no output-band selector | q=0; no spin; Direct example, explicit Mixed only after capability preflight | `synthetic_demo_sc_conv.dat` | [input](examples/tasks/integral/shift_current_conventional.jl) |
| 2 | Shift Current | Projector | Integral | Projector q=0 shift current | `_tb.dat` | Optical controls, band window, finite-difference/convention/degeneracy controls | Full rank-3 tensor; no output-band selector | q=0; no spin; Direct/Mixed subject to Projector capability | `synthetic_demo_sc_proj.dat` | [input](examples/tasks/integral/shift_current_projector.jl) |
| 3 | Shift Current | Geometric Loop | Integral | Native geometric-loop q=0 formulation | `_tb.dat` | Optical controls, loop step, convention, degeneracy threshold | Full rank-3 tensor; no output-band selector | q=0; no spin; explicit Mixed requires capability/memory preflight | `synthetic_demo_sc_geo.dat` | [input](examples/tasks/integral/shift_current_geometric_loop.jl) |
| 4 | Shift Current | Wilson Loop | Integral | Wilson-loop q=0 formulation | `_tb.dat` | Optical controls, loop step, degeneracy threshold, band window | Full rank-3 tensor; no output-band selector | q=0; no spin; explicit Mixed requires Wilson capability | `synthetic_demo_sc_wilson.dat` | [input](examples/tasks/integral/shift_current_wilson_loop.jl) |
| 5 | Shift Current | Conventional | K-slice | Momentum-resolved conventional shift current | `_tb.dat` | One energy, occupations/smearing, slice plane | Pair/subspaces; `(a,b,c)` | q=0; no spin; Direct example, explicit Mixed preflight | `synthetic_demo_sck_{r,i}_conv.dat` | [input](examples/tasks/kslice/shift_current_conventional.jl) |
| 6 | Shift Current | Projector | K-slice | Momentum-resolved Projector shift current | `_tb.dat` | One energy, slice, projector step/convention/degeneracy controls | Pair/subspaces; `(a,b,c)` | q=0; no spin; Projector Fourier capability applies | `synthetic_demo_sck_{r,i}_proj.dat` | [input](examples/tasks/kslice/shift_current_projector.jl) |
| 7 | Shift Current | Geometric Loop | K-slice | Momentum-resolved geometric-loop shift current | `_tb.dat` | One energy, slice, loop step/convention/degeneracy controls | Pair/subspaces; `(a,b,c)` | Example is q=0; no spin; explicit Mixed preflight | `synthetic_demo_sck_{r,i}_geo.dat` | [input](examples/tasks/kslice/shift_current_geometric_loop.jl) |
| 8 | Shift Current | Wilson Loop | K-slice | Momentum-resolved Wilson-loop shift current | `_tb.dat` | One energy, slice, loop step/degeneracy controls | Pair/subspaces; `(a,b,c)` | q=0 example; no spin; Wilson Fourier capability applies | `synthetic_demo_sck_{r,i}_wilson.dat` | [input](examples/tasks/kslice/shift_current_wilson_loop.jl) |
| 9 | Quantum Hermitian Connection | Conventional | K-slice | Conventional QHC geometric tensor | `_tb.dat` | Slice plane and denominator/numerical controls | Pair/subspaces; `(a,b,c)` | q=0 example; no spin; explicit Mixed preflight | `synthetic_demo_qhck_{r,i}_conv.dat` | [input](examples/tasks/kslice/quantum_hermitian_connection_conventional.jl) |
| 10 | Quantum Hermitian Connection | Projector | K-slice | Projector QHC | `_tb.dat` | Slice, step, convention, degeneracy threshold | Pair/subspaces; `(a,b,c)` | q=0; no spin; Projector capability applies | `synthetic_demo_qhck_{r,i}_proj.dat` | [input](examples/tasks/kslice/quantum_hermitian_connection_projector.jl) |
| 11 | Quantum Hermitian Connection | Geometric Loop | K-slice | Geometric-loop QHC | `_tb.dat` | Slice, loop step, convention, degeneracy threshold | Pair/subspaces; `(a,b,c)` | Registered q=0 path; no spin; explicit Mixed preflight | `synthetic_demo_qhck_{r,i}_geo.dat` | [input](examples/tasks/kslice/quantum_hermitian_connection_geometric_loop.jl) |
| 12 | Quantum Hermitian Connection | Wilson Loop | K-slice | Wilson-loop QHC | `_tb.dat` | Slice, loop step, degeneracy threshold | Pair/subspaces; `(a,b,c)` | **Finite q forbidden**; no spin; Wilson capability applies | `synthetic_demo_qhck_{r,i}_wilson.dat` | [input](examples/tasks/kslice/quantum_hermitian_connection_wilson_loop.jl) |
| 13 | Hermitian Curvature Tensor | Conventional | K-slice | Inter-subspace Hermitian-curvature tensor | `_tb.dat` | Slice and high-order derivative/regularization controls | Two disjoint groups; `(b,a,d,c)` | q=0; no spin; High-order Fourier capability applies | `synthetic_demo_hctk_{r,i}_conv.dat` | [input](examples/tasks/kslice/hermitian_curvature_tensor_conventional.jl) |
| 14 | Berry Curvature | Conventional | K-slice | Band/subspace-resolved Berry curvature | `_tb.dat` | Slice, selected bands/subspaces | `-1`, `0`, or targets; `(a,b)` | q=0; no spin; Conventional geometry Fourier capability | `synthetic_demo_bck_<band/group>_conv.dat` plus optional sum | [input](examples/tasks/kslice/berry_curvature_conventional.jl) |
| 15 | Berry Curvature Dipole | Conventional | K-slice | First k derivative of target-group Berry curvature | `_tb.dat` | Slice, target groups, finite-difference step | One/more target groups; `(a,b,c)` | q=0; no spin; High-order capability applies | `synthetic_demo_bcdk_<group>_conv.dat` | [input](examples/tasks/kslice/berry_curvature_dipole_conventional.jl) |
| 16 | Berry Curvature Quadrupole | Conventional | K-slice | Second k derivative of target-group Berry curvature | `_tb.dat` | Slice, target groups, finite-difference step | One/more target groups; `(a,b,c,d)` | q=0; no spin; High-order capability applies | `synthetic_demo_bcqk_<group>_conv.dat` | [input](examples/tasks/kslice/berry_curvature_quadrupole_conventional.jl) |
| 17 | Quantum Metric | Conventional | K-slice | Band/subspace-resolved quantum metric | `_tb.dat` | Slice and selected bands/subspaces | `-1`, `0`, or targets; `(a,b)` | q=0; no spin; Conventional geometry capability | `synthetic_demo_qmk_<band/group>_conv.dat` plus optional sum | [input](examples/tasks/kslice/quantum_metric_conventional.jl) |
| 18 | Interband Berry Curvature | Conventional | K-slice | Berry-curvature channel between two subspaces | `_tb.dat` | Slice and interband groups | Two disjoint groups; `(a,b)` | q=0; no spin; Conventional geometry capability | `synthetic_demo_ibck_conv.dat` | [input](examples/tasks/kslice/interband_berry_curvature_conventional.jl) |
| 19 | Interband Quantum Metric | Conventional | K-slice | Quantum-metric channel between two subspaces | `_tb.dat` | Slice and interband groups | Two disjoint groups; `(a,b)` | q=0; no spin; Conventional geometry capability | `synthetic_demo_iqmk_conv.dat` | [input](examples/tasks/kslice/interband_quantum_metric_conventional.jl) |
| 20 | Zeeman Interband Berry Curvature | Conventional | K-slice | Spin-inserted interband Berry-like geometry | Legacy TB/SPN/CHK or profile `hamiltonian_position_spin` | Slice, interband groups, spin capability | Two disjoint groups; `(a,s)` | q=0; Spin Fourier capability | `synthetic_demo_zibck_conv.dat` | [input](examples/tasks/kslice/zeeman_interband_berry_curvature_conventional.jl) |
| 21 | Zeeman Interband Quantum Metric | Conventional | K-slice | Spin-inserted interband metric-like geometry | Legacy TB/SPN/CHK or profile `hamiltonian_position_spin` | Slice, interband groups, spin capability | Two disjoint groups; `(a,s)` | q=0; Spin Fourier capability | `synthetic_demo_ziqmk_conv.dat` | [input](examples/tasks/kslice/zeeman_interband_quantum_metric_conventional.jl) |
| 22 | Quantum Metric Dipole | Conventional | K-slice | First k derivative of target-group quantum metric | `_tb.dat` | Slice, target groups, finite-difference step | One/more target groups; `(a,b,c)` | q=0; no spin; High-order capability applies | `synthetic_demo_qmdk_<group>_conv.dat` | [input](examples/tasks/kslice/quantum_metric_dipole_conventional.jl) |
| 23 | Quantum Metric Quadrupole | Conventional | K-slice | Second k derivative of target-group quantum metric | `_tb.dat` | Slice, target groups, finite-difference step | One/more target groups; `(a,b,c,d)` | q=0; no spin; High-order capability applies | `synthetic_demo_qmqk_<group>_conv.dat` | [input](examples/tasks/kslice/quantum_metric_quadrupole_conventional.jl) |
| 24 | Quantum Christoffel Symbol | Conventional | K-slice | Metric-derived Christoffel-like geometry | `_tb.dat` | Slice, target groups, finite-difference step | One/more target groups; `(r,l,j)` | q=0; no spin; High-order capability applies | `synthetic_demo_qcsk_<group>_conv.dat` | [input](examples/tasks/kslice/quantum_christoffel_symbol_conventional.jl) |
| 25 | Triple Phase Product | Conventional | K-slice | Ordered three-subspace phase product | `_tb.dat` | Slice and three interband groups | Three pairwise-disjoint groups; `(a,b,c)` | q=0; no spin; Conventional geometry capability | `synthetic_demo_tppk_{r,i}_conv.dat` | [input](examples/tasks/kslice/triple_phase_product_conventional.jl) |
| 26 | Photon Drag Shift Current | Geometric Loop | Integral | Finite-q geometric-loop shift current | `_tb.dat` | Optical controls, physical q, loop step/basis/degeneracy | Full rank-3 tensor; no output-band selector | **Explicit physical q required**; no spin; finite-q Fourier capability | `synthetic_demo_pdsc_geo.dat` | [input](examples/tasks/integral/photon_drag_shift_current_geometric_loop.jl) |
| 27 | Photon Drag Shift Current | Geometric Loop | K-slice | Momentum-resolved finite-q shift current | `_tb.dat` | One energy, slice, physical q, loop controls | Pair/subspaces; `(a,b,c)` | **Explicit physical q required**; no spin; finite-q capability | `synthetic_demo_pdsck_{r,i}_geo.dat` | [input](examples/tasks/kslice/photon_drag_shift_current_geometric_loop.jl) |
| 28 | Shift Vector | Geometric Loop | K-slice | Geometric-loop shift vector | `_tb.dat` | Slice, loop step/basis/degeneracy | Pair/subspaces; `(a,b,c)` | Example q=0; no spin; Geometric Fourier capability | `synthetic_demo_svk_{r,i}_geo.dat` | [input](examples/tasks/kslice/shift_vector_geometric_loop.jl) |
| 29 | Shift Vector | Wilson Loop | K-slice | Wilson-loop shift vector | `_tb.dat` | Slice, loop step/degeneracy | Pair/subspaces; `(a,b,c)` | **Finite q forbidden**; no spin; Wilson capability | `synthetic_demo_svk_{r,i}_wilson.dat` | [input](examples/tasks/kslice/shift_vector_wilson_loop.jl) |
| 30 | Injection Current | Conventional | Integral | q=0 injection charge current | `_tb.dat` | Optical/occupation/smearing controls and band window | Full rank-3 tensor; no output-band selector | q=0; nonzero q rejected; no spin | `synthetic_demo_ic_conv.dat` | [input](examples/tasks/integral/injection_current_conventional.jl) |
| 31 | Injection Current | Conventional | K-slice | Momentum-resolved injection charge current | `_tb.dat` | One energy, occupations/smearing, slice | Pair/subspaces; `(a,b,c)` | q=0; nonzero q rejected; no spin; q0 Fourier capability | `synthetic_demo_ick_{r,i}_conv.dat` | [input](examples/tasks/kslice/injection_current_conventional.jl) |
| 32 | Injection Spin Current | Conventional | Integral | q=0 injection current with spin-current vertex | Legacy seed or profile `full` | Optical controls and full spin-velocity capability | Full rank-4 tensor; no output-band selector | q=0; nonzero q rejected; Spin Fourier capability | `synthetic_demo_isc_conv.dat` | [input](examples/tasks/integral/injection_spin_current_conventional.jl) |
| 33 | Injection Spin Current | Conventional | K-slice | Momentum-resolved injection spin current | Legacy seed or profile `full` | One energy, slice, demanded spin components | Pair/subspaces; `(a,s,b,c)` | q=0; nonzero q rejected; Spin Fourier capability | `synthetic_demo_isck_{r,i}_conv.dat` | [input](examples/tasks/kslice/injection_spin_current_conventional.jl) |
| 34 | Shift Spin Current | Conventional | Integral | q=0 shift spin current with regularized denominator | Legacy seed or profile `full` | Optical controls, full spin vertices, positive regularization | Full rank-4 tensor; no output-band selector | q=0; nonzero q rejected; Spin Fourier capability | `synthetic_demo_ssc_conv.dat` | [input](examples/tasks/integral/shift_spin_current_conventional.jl) |
| 35 | Shift Spin Current | Conventional | K-slice | Momentum-resolved shift spin current | Legacy seed or profile `full` | One energy, slice, demanded spin components, regularization `>0` | Pair/subspaces; `(a,s,b,c)` | q=0; nonzero q rejected; Spin Fourier capability | `synthetic_demo_ssck_{r,i}_conv.dat` | [input](examples/tasks/kslice/shift_spin_current_conventional.jl) |
| 36 | Photon Drag Injection Current | Conventional | Integral | Finite-q injection current | `_tb.dat` | Optical controls, physical q, convention and transition window | Full rank-3 tensor; no output-band selector | **Explicit physical q required**; no spin; finite-q capability | `synthetic_demo_pdic_conv.dat` | [input](examples/tasks/integral/photon_drag_injection_current_conventional.jl) |
| 37 | Photon Drag Injection Current | Conventional | K-slice | Momentum-resolved finite-q injection current | `_tb.dat` | One energy, slice, physical q, basis/transition controls | Pair/subspaces; `(a,b,c)` | **Explicit physical q required**; no spin; finite-q capability | `synthetic_demo_pdick_{r,i}_conv.dat` | [input](examples/tasks/kslice/photon_drag_injection_current_conventional.jl) |
| 38 | Band Structure | Conventional | K-path | Spectrum along an explicit connected high-symmetry path | `_tb.dat` or Packed HDF5 operator bundle | Path nodes, points per segment, `E_ref`, replica policy, Hermiticity tolerance | All bands in ascending order; no tensor selector | Direct Fourier only; task semantics selected by registry executor; no response qualification promotion | `<system>_bands.dat`, `<system>_kpath.json` | [input](examples/tasks/band/band_structure.jl) |

## 7. Running, outputs, and environment variables

From the package directory:

```bash
julia --project=. examples/tasks/kslice/berry_curvature_conventional.jl
```

For MPI, launch the same Julia command with the site launcher and enable the public bundle MPI switch, for example:

```bash
WANNIERNLQG_USE_MPI=1 mpiexec -n 4 julia --project=. examples/tasks/integral/shift_current_conventional.jl
```

`run(config)` returns `RunResult` with normalized specs, the root run directory, numerical outputs and metadata/progress paths.

Every public task writes its original numerical filenames under
`output_root/<id>/`, with per-task metadata. One run has a shared progress report located under the
first task directory; root and per-task `RunResult` progress paths all refer to
those actual shared files. Root
`metadata.txt` indexes all task IDs, child metadata and outputs, and records
sharing statistics. `RunResult.outputs` aggregates files; `task_ids`,
`task_results`, and `sharing` expose task identities, individual results and
reuse statistics. This layout also applies to single-task runs.

Each task's `[EffectiveTaskConfiguration]` metadata section is the authoritative
public configuration: it expands numerical defaults and contains only applicable
physics, numerics and observables. Existing numerical/model diagnostic sections
are retained. Sharing counters are rank-local and identify the rank and model
load count. A raw Fourier counter measures operator-group evaluations, not FFT
calls; FFT execution counts remain in each task's Fourier summary.

### User-facing environment variables

| Category | Variables | Use |
| --- | --- | --- |
| Example output | `WANNIERNLQG_EXAMPLE_OUTPUT_ROOT` | Override the temporary example output root without changing scientific inputs |
| MPI | `WANNIERNLQG_USE_MPI`; method-specific `WANNIERNLQG_CONVENTIONAL_USE_MPI`, `WANNIERNLQG_CONVENTIONAL_GEOMETRY_USE_MPI`, `WANNIERNLQG_INJECTION_CURRENT_USE_MPI`, `WANNIERNLQG_PROJECTOR_USE_MPI`, `WANNIERNLQG_GEOMETRIC_LOOP_USE_MPI` | Enable the registered MPI contexts under an MPI launcher; prefer the bundle switch for normal user runs |
| Progress | `WANNIERNLQG_PROGRESS_PERCENT_INTERVAL`, `WANNIERNLQG_SLOW_K_SECONDS`, `WANNIERNLQG_KSLICE_SLOW_K_SECONDS` | Percentage cadence and slow-k reporting; an explicit `OutputOptions.progress_percent_interval` takes precedence over the cadence environment variable |
| Mixed FFT | `WANNIERNLQG_MIXED_MEMORY_LIMIT_BYTES`, `WANNIERNLQG_FOURIER_TIMING` | Adjust the per-rank FFT-provider buffer budget or emit Fourier timing diagnostics; the budget excludes snapshot caches and total RSS |
| MPI diagnostics | `WANNIERNLQG_LOG_ALL_RANKS` | Include rank-local diagnostic logs |

Set `fourier_backend`, `NKdiv`, and `NKFFT` in `ExecutionOptions` so metadata fully records the Fourier configuration.

Variables containing `BENCHMARK`, test-level/test-MPI selectors, deliberate slow-k injection, and internal regression controls are developer/test facilities, not production input parameters. They must not be used to define scientific results.

## 8. Validation and convergence checklist

1. Build the config without running it: include the example and call `build_config()`.
2. Confirm task, tensor order, 1-based bands/subspaces, model/seed provenance, and output directory.
3. Converge `k_mesh`, `band_window_size`, frequency sampling, broadening, finite-difference step, degeneracy threshold, and (for finite-q work) the physical q model.
4. For Mixed FFT, compare to Direct, then measure memory and timing with the final task bundle.
5. Keep `metadata.txt` and model checksum with outputs; do not merge output directories from distinct configs.
6. Run the documentation audit after edits: `julia --project=. scripts/check_user_guide_examples.jl`.

The example audit checks the grouped public API documentation, all 38 registry
tasks and example links, config compilation, explicit physical inputs, absence
of optical placeholders in geometry, ordinary mesh and frequency presets, Band
path controls, finite-q requirements, and unique output roots. The separate
`check_documentation.jl` gate verifies English text, local links and Markdown
syntax; package tests execute explicit smoke overrides.
