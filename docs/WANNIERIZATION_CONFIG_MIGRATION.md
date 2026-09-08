# Wannierization configuration reference

WannierNLQG 1.0.0 establishes the public Wannierization configuration baseline.
`SymmetryAdaptedWannierizationConfig` owns exactly five immutable groups. The
group types are expert API and are referenced through the qualified
`WannierNLQG.Wannierization` namespace.

```julia
import WannierNLQG.Wannierization as W

config = W.SymmetryAdaptedWannierizationConfig(
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
| `solver` | Algorithm profile, initialization, mixing and acceleration, numerical thresholds, iteration limits, localization, parallel mode, and deterministic seed. |
| `checkpoint` | Restart input, fixed-subspace input, checkpoint output, and checkpoint interval. |
| `runtime` | Progress interval and the cold-path iteration observer. |
| `output` | Band-representation, TB, SPN, uIu, uHu, sIu, and sHu outputs; formats, provenance paths, and export qualification tolerances. |

The complete leaf-field definitions and mode-specific requirements are in the
[Wannierization guide](WANNIERIZATION.md). Invalid combinations fail at the
configuration or workflow preflight boundary.

## Qualified leaf-field paths

The following table is the public 1.0.0 reference from each constructor leaf
name to its owning configuration group.

| Leaf name | Qualified field |
| --- | --- |
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
| `construction_policy` | `input.construction_policy` |
| `algorithm_profile` | `solver.algorithm_profile` |
| `smv_fletcher_reeves_two_stage_audit_thresholds` | `solver.smv_fletcher_reeves_two_stage_audit_thresholds` |
| `smv_fletcher_reeves_two_stage_audit_manifest` | `solver.smv_fletcher_reeves_two_stage_audit_manifest` |
| `initialization` | `solver.initialization` |
| `z_mix_ratio` | `solver.z_mix_ratio` |
| `u_mix_ratio` | `solver.u_mix_ratio` |
| `acceleration` | `solver.acceleration` |
| `numerical_thresholds` | `solver.numerical_thresholds` |
| `initialization_backend` | `solver.initialization_backend` |
| `paw_scdm_input_hdf5` | `solver.paw_scdm_input_hdf5` |
| `multi_start` | `solver.multi_start` |
| `max_iterations` | `solver.max_iterations` |
| `convergence_tolerance` | `solver.convergence_tolerance` |
| `convergence_window` | `solver.convergence_window` |
| `little_group_tolerance` | `solver.little_group_tolerance` |
| `little_group_max_iterations` | `solver.little_group_max_iterations` |
| `localize` | `solver.localize` |
| `symmetrize_z` | `solver.symmetrize_z` |
| `parallel` | `solver.parallel` |
| `random_seed` | `solver.random_seed` |
| `restart_hdf5` | `checkpoint.restart_hdf5` |
| `fixed_subspace_hdf5` | `checkpoint.fixed_subspace_hdf5` |
| `checkpoint_hdf5` | `checkpoint.checkpoint_hdf5` |
| `checkpoint_interval` | `checkpoint.checkpoint_interval` |
| `progress_interval` | `runtime.progress_interval` |
| `iteration_observer` | `runtime.iteration_observer` |
| `band_representation_output_hdf5` | `output.band_representation_output_hdf5` |
| `tb_output_formats` | `output.tb_output_formats` |
| `write_wannier90_tb` | `output.write_wannier90_tb` |
| `profile` | `output.profile` |
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

## Construction policy

`WannierizationInputConfig` defaults to `construction_policy=:diagnostic`.
Diagnostic construction can continue from a finite, dimensionally valid state
while recording unmet quality gates for manual review. It does not relax
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
