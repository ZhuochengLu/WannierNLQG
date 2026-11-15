# Wannierization configuration reference

The public Wannierization configuration uses explicit immutable groups.
`WannierizationConfig` owns exactly five immutable groups. The
group types are expert API and are referenced through the qualified
`WannierNLQG.Wannierization` namespace.

```julia
import WannierNLQG.Wannierization as W

config = W.WannierizationConfig(
    input = W.WannierizationInputConfig(
        win_file = "seed.win",
        eig_file = "seed.eig",
        mmn_file = "seed.mmn",
    ),
    solver = W.WannierizationSolverConfig(),
    checkpoint = W.WannierizationCheckpointConfig(),
    runtime = W.WannierizationRuntimeConfig(),
    output = W.WannierizationOutputConfig(),
)
```

## Configuration groups

| Group | Responsibility |
| --- | --- |
| `input` | Wavefunction and matrix-element sources, representations, band windows, target dimension, symmetry tolerances, compatibility policy, construction policy, gauge backend, and Hamiltonian authority. |
| `solver` | Initialization, stage controls, numerical thresholds, parallel mode, and deterministic seed. Internal optimization constants are not user settings. |
| `checkpoint` | Restart input, checkpoint output/cadence, recovery mode, and storage/reference settings. |
| `runtime` | Print cadence, detailed progress, and the cold-path iteration observer. |
| `output` | Band-representation, TB, SPN, uIu, uHu, sIu, and sHu outputs; formats, provenance paths, and export qualification tolerances. |

The complete leaf-field definitions and mode-specific requirements are in the
[Wannierization guide](WANNIERIZATION.md). Invalid combinations fail at the
configuration or workflow preflight boundary.

## Qualified leaf-field paths

This table lists the expert Julia constructor fields. Nested algorithm and
threshold objects retain their own constructor contracts; this table does not
make every Julia object directly expressible in TOML. `acceleration` is internal
and is rejected by public solver input. The unused
`smv_fletcher_reeves_two_stage_audit_manifest` solver input is also rejected;
explicit development audits use their independent API. Historical checkpoint
storage remains readable.

| Leaf name | Qualified Julia field |
| --- | --- |
| `construction_policy` | `input.construction_policy` |
| `wannierization_mode` | `input.wannierization_mode` |
| `source` | `input.source` |
| `sewing_backend` | `input.sewing_backend` |
| `wavefunction_gauge_backend` | `input.wavefunction_gauge_backend` |
| `authoritative_hamiltonian` | `input.authoritative_hamiltonian` |
| `wavefunction_gauge_hdf5` | `input.wavefunction_gauge_hdf5` |
| `win_file` | `input.win_file` |
| `eig_file` | `input.eig_file` |
| `mmn_file` | `input.mmn_file` |
| `amn_file` | `input.amn_file` |
| `matrix_elements` | `input.matrix_elements` |
| `projection_basis` | `input.projection_basis` |
| `band_representation` | `input.band_representation` |
| `band_representation_hdf5` | `input.band_representation_hdf5` |
| `outer_min_ev` | `input.outer_min_ev` |
| `outer_max_ev` | `input.outer_max_ev` |
| `frozen_min_ev` | `input.frozen_min_ev` |
| `frozen_max_ev` | `input.frozen_max_ev` |
| `frozen_states` | `input.frozen_states` |
| `num_wannier` | `input.num_wannier` |
| `symmetry_tolerance` | `input.symmetry_tolerance` |
| `degeneracy_tolerance_ev` | `input.degeneracy_tolerance_ev` |
| `representation_tolerance` | `input.representation_tolerance` |
| `empirical_covariance_budget` | `input.empirical_covariance_budget` |
| `target_center_matching_tolerance` | `input.target_center_matching_tolerance` |
| `compatibility_policy` | `input.compatibility_policy` |
| `preparation_execution` | `input.preparation_execution` |
| `geometry` | `input.geometry` |
| `operation_indices` | `input.operation_indices` |
| `smv_fletcher_reeves_two_stage_audit_thresholds` | `solver.smv_fletcher_reeves_two_stage_audit_thresholds` |
| `initialization` | `solver.initialization` |
| `z_mix_ratio` | `solver.z_mix_ratio` |
| `u_mix_ratio` | `solver.u_mix_ratio` |
| `stage_controls` | `solver.stage_controls` |
| `numerical_thresholds` | `solver.numerical_thresholds` |
| `initialization_backend` | `solver.initialization_backend` |
| `paw_scdm_input_hdf5` | `solver.paw_scdm_input_hdf5` |
| `multi_start` | `solver.multi_start` |
| `little_group_tolerance` | `solver.little_group_tolerance` |
| `little_group_max_iterations` | `solver.little_group_max_iterations` |
| `symmetrize_z` | `solver.symmetrize_z` |
| `parallel` | `solver.parallel` |
| `random_seed` | `solver.random_seed` |
| `restart_hdf5` | `checkpoint.restart_hdf5` |
| `checkpoint_hdf5` | `checkpoint.checkpoint_hdf5` |
| `num_dump_cycles` | `checkpoint.num_dump_cycles` |
| `recovery` | `checkpoint.recovery` |
| `storage` | `checkpoint.storage` |
| `reference_root` | `checkpoint.reference_root` |
| `num_print_cycles` | `runtime.num_print_cycles` |
| `detailed_progress` | `runtime.detailed_progress` |
| `iteration_observer` | `runtime.iteration_observer` |
| `model_file` | `output.model_file` |
| `band_representation_output_hdf5` | `output.band_representation_output_hdf5` |
| `tb_output_formats` | `output.tb_output_formats` |
| `write_model_tb` | `output.write_model_tb` |
| `profile` | `output.profile` |
| `operator_tasks` | `output.operator_tasks` |
| `spn_file` | `output.spn_file` |
| `spn_provenance_file` | `output.spn_provenance_file` |
| `uiu_file` | `output.uiu_file` |
| `uhu_file` | `output.uhu_file` |
| `siu_file` | `output.siu_file` |
| `shu_file` | `output.shu_file` |
| `uiu_provenance_json` | `output.uiu_provenance_json` |
| `uhu_provenance_json` | `output.uhu_provenance_json` |
| `siu_provenance_json` | `output.siu_provenance_json` |
| `shu_provenance_json` | `output.shu_provenance_json` |
| `spn_formatted` | `output.spn_formatted` |
| `operator_files_formatted` | `output.operator_files_formatted` |
| `operator_closure_tolerance` | `output.operator_closure_tolerance` |
| `spin_family_covariance_tolerance` | `output.spin_family_covariance_tolerance` |
| `spin_family_idempotence_tolerance` | `output.spin_family_idempotence_tolerance` |
| `final_tb_symmetry_report_enabled` | `output.final_tb_symmetry_report_enabled` |

The six stage settings are constructed in Julia as
`solver = W.WannierizationSolverConfig(stage_controls = W.WannierizationStageControls(...))`.
Normalized TOML places these same settings directly in `[solver]`:

```toml
[solver]
dis_num_iter = 200
dis_conv_tol = 1e-10
dis_conv_window = 3
num_iter = 500
conv_tol = 1e-10
conv_window = 3
```

These values are the constructor defaults, not a replacement for explicit
settings in an existing calculation. Former `max_iterations`,
`convergence_tolerance`, `convergence_window`, and `localize` inputs are not
aliases. The iteration budgets are `dis_num_iter` and `num_iter`.

Normalized TOML uses `[checkpoint]` for `restart_hdf5`, `recovery`, `storage`,
and `reference_root`; `checkpoint_hdf5` and `num_dump_cycles` are in `[output]`.
The output table also accepts `num_print_cycles` and `detailed_progress` for
runtime reporting. In Julia these remain in their owning groups above.
`iteration_observer` is a Julia callback, not a TOML value. See the
[normalized input guide](TEXT_INPUT.md) for source and path syntax.

## Construction policy

`WannierizationInputConfig` defaults to `construction_policy=:standard`.
Standard construction can continue from a finite, dimensionally valid state
while recording unmet quality gates and recommending quality review. It does not relax
missing-data, rank, positive-metric, source-identity, or persistence-integrity
requirements, and it does not grant production eligibility.

Set `construction_policy=:strict` to require every configured quality gate to
pass before continuation. The policy is part of restart identity and is
recorded in checkpoint and export evidence.

## Modes and authority

`wannierization_mode` accepts `:auto`, `:ordinary`, or `:symmetry_adapted`.
Expert source, sewing, gauge, and authoritative-Hamiltonian choices must be
mutually compatible.

For a full-profile symmetry-adapted workflow, construct operator-generation
configuration from the target contract. The contract distinguishes the raw
operator-oracle MMN from the solver MMN, binds their SHA-256 identities and
gauge/frame authority, and is validated before expensive work and before final
export. Explicit duplicate parameters must agree with the contract; the workflow
does not guess or silently fall back.

## Outputs and qualification

Ordinary and symmetry-adapted construction publish the neutral
`.wannierization.*` output family. Output profiles determine the required
auxiliary inputs and operator capabilities. Checkpoint and Packed artifacts bind
their declared schema, scientific content, provenance, and qualification
metadata; relabeling does not change qualification.

Package examples and tests use synthetic data. Their successful execution is a
software regression result, not a material-specific Physics or Production
qualification.

## Task-derived output selection in 1.1.0

New Wannierization exports accept only `output.profile=:hamiltonian_position`
(the unchanged default) or `:full`. To select by task, set `output.profile=nothing`
and supply a nonempty tuple of `WannierNLQG.Core.OperatorTask` in
`output.operator_tasks`. These are mutually exclusive; leaving the default profile
while adding tasks is an error. `operator_tasks` is a new field, not a historical
flat-config compatibility alias. Both selectors are excluded from the solver restart digest.

Replace a former new-export `:hamiltonian_position_spin` request with a supported
Zeeman task selection when that is the intended capability, or `:full` when the
complete inventory is required. Existing spin-profile bundles remain readable
within the reader's supported wire schema. `:spin` has no alias. No old bundle is
upgraded by changing its profile string: task-derived qualification requires a new
export and fresh re-resolution of requested tasks, closure, hashes and inventory.
See [selection examples and the complete dependency table](WANNIERIZATION.md#task-derived-selection-and-canonical-union)
and [storage compatibility](STORAGE_SCHEMAS.md#task-derived-packed-operator-selection).

## Neighbor-order derived-operator rebuild

The former streamed uIu/uHu consumer defect confused source-file neighbor
indices with internal stencil indices. Preserve original input files and their
provenance. Rebuild affected `derivative_overlap_tensor`, its axial/symmetric
contractions, and `hamiltonian_weighted_axial_derivative_overlap` from the same
qualified raw sources using a corrected and validated assembler, then regenerate
the dependent bundle qualification/seals and response results into new artifacts.
Do not reorder raw files, overwrite historical bundles, or obtain corrected status
by changing algorithm/profile labels. Hamiltonian/position-only payloads are not
implicated by this specific F/C assembly defect; other qualification rules remain.

The diagnostic mapping correction is not a complete OAM parity or convergence
result. Remaining real-material kernel, position/curvature, off-grid,
finite-window and subspace differences stay open. Source-schema readability and
Packed wire compatibility are independent of this rebuild requirement. Missing additive neighbor-order receipts
remain readable as `LEGACY_UNVERIFIED`; only validated per-operator receipts confer
`REBUILT_SOURCE_TO_INTERNAL`, which is a construction status, not production
qualification. The global derivative algorithm marker and wire/schema versions
are unchanged; assembly version changes alone do not certify a rebuild. See
[algorithm provenance](STORAGE_SCHEMAS.md#neighbor-order-algorithm-provenance).


## Explicit final symmetry qualification

Normal construction now records final TB symmetry qualification as `NOT_RUN`
with reason `EXPLICIT_QUALIFICATION_NOT_REQUESTED`. This is not a pass and does
not grant production eligibility. Solver convergence, accepted-state numerical
checks, output finite/Hermiticity guards, write failures and checkpoint recovery
remain active. Explicit expert `final_tb_symmetry_report_enabled=true` requests
posthoc qualification; the independent
`Wannierization.qualify_exported_wannierization_tb` entry remains available.
Existing saved qualification results are not rewritten by this change.

Text TB construction sidecars retain the packed publication identity and
construction diagnostics, but no longer produce `model_tb_sha256`. This
unused text digest is distinct from quality-payload and recovery/publication
identities, which remain intact. Stream receipts contain path and byte count;
paired text bytes and original numeric formatting remain unchanged.

## Stage budgets and internal algorithm settings

The public solver input does not accept `acceleration` in either TOML or the Julia keyword constructor. `dis_num_iter` and `num_iter` are the Z and U iteration budgets; the existing stage convergence tolerances/windows remain their stopping controls. Julia uses `WannierizationStageControls(...)` through `solver.stage_controls`. Internal line-search, Fletcher–Reeves and regularization algorithms retain their established defaults; adding an unrelated setting cannot reset the stage budgets. Explicit former acceleration inputs are rejected, rather than silently ignored.

The resolved internal algorithm record remains in checkpoint storage and restart identity checks. Removing a user input table does not authorize substituting different algorithms into an existing checkpoint. `u_mix_ratio` is not a tuning factor for the current U update, but its historical storage and strict restart-identity consumers are retained pending a separately defined migration boundary.

## Additional input boundaries

The normalized Wannier/projection text routes do not consume
`basis.radial_transform`; explicit settings are rejected. Standalone Julia
projection/AMN and representation-search APIs retain their existing radial
configuration. Native VASP production uses its VASP-compatible backend, and
QE PAW AMN uses the NNKP radial definition. These algorithms are not replaced
by a generic basis setting.

`SymmetryCompletedQEPAWMatrices` accepts only its effective `:standard` mode.
The independent low-level completed-QE generator retains its separate strict
interface. Fresh `initialization=:random` combined with `PAWSCDMInitialization`
is rejected; complete accepted-state checkpoint continuation follows the
existing restoration branch. A PAW-only SCDM artifact supplies its initial
frames without an additional AMN or native-wavefunction input. When AMN or a
native source is available with `initialization=:amn`, its existing reference
handling is retained; the SCDM seed and optimizer formulas are unchanged.

`PAWGaugeThresholds.final_s_reconstruction` is retained for historical identity
and is not an active numerical gate. The unused `integer` tuning keyword of
`ProjectionRepresentationSearchThresholds` is rejected; its legacy carrier
layout/default is preserved. No restart identity comparison is relaxed.
