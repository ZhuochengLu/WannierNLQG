# Wannier operator symmetrization

This guide describes the current projection workflow and its existing expert API. The mathematical model wire format is 3.0. Its model data, not a software-version label, report status or checksum, determine what a reader can calculate.

## 1. Scientific input boundary

Projection requires exactly one explicit TB input or Packed Hamiltonian/position input. Packed input cannot be mixed with CHK/EIG/MMN/SPN regeneration inputs. Unsupported Packed operator inventories are rejected rather than silently reduced. Geometry comes either from the explicit legacy WIN adapter or from owned `structure`, `projection_basis` and positive `mp_grid` values. All three owned values are required for a WIN-free call and cannot be mixed with WIN geometry. The normalized TOML resolver obtains those values from the explicit structure, basis and native-source declarations; missing mathematical input is not inferred from filenames. A native geometry source does not implicitly read wavefunctions.

The expert auxiliary-input routes retain their existing pair-Wigner--Seitz and operator-generation conventions. EIG/MMN are a pair, and spin/derivative inputs require their matching CHK/gauge data. These interfaces do not qualify arbitrary spinor or augmentation-aware material data. Full uIu generation is the separate Wannierization workflow; projection does not invent missing source operators.

The Symmetrization extension activates through `HDF5 + JSON3 + EzXML`. Operation detection calls the qualified Foundation port `detect_tb_compatibility_symmetry_operations`; its loader owns Spglib access. `symmetry_detection_backend_provenance` reports the backend without introducing a direct upward dependency. Projection uses named Foundation, WannierProjection and MatrixElements integration ports. Its include-only validation, sewing, projection, persistence and workflow components retain their numerical ownership boundaries.

## 2. Configuration reference

### 2.1 MagneticMomentConfig

| field | contract |
| --- | --- |
| source | `:qe`, `:vasp`, or `:cartesian` provider |
| file | optional provider file |
| moments_cartesian | optional direct moments in the declared atom order |
| collinear_axis_cartesian | optional Cartesian collinear axis |
| mapping_tolerance | atom mapping tolerance; default `1e-7` |

### 2.2 MeshScreenConfig

| field | contract |
| --- | --- |
| win_file | required WIN path |
| include_time_reversal | include time reversal; default `true` |
| symmetry_tolerance | symmetry tolerance; default `1e-5` |
| operation_indices | optional explicit symmetry-operation subset |
| dimension | `2` or `3`; default `3` |
| density_target | mesh density target; default `55.0` |
| search_radius | integer mesh-search radius; default `10` |

### 2.3 SymmetrizationConfig

| field | contract |
| --- | --- |
| win_file | optional explicit legacy WIN geometry; mutually exclusive with owned structure/basis/grid |
| tb_file | TB Hamiltonian/position input; exactly one of this and input_operator_bundle_file |
| output_tb_file | required symmetrized Wannier TB output |
| output_real_space_operator_bundle_file | required mathematical model wire-3.0 output; ordinary readers require the current format |
| chk_file | optional; required by derivative or `hamiltonian_position_spin` profiles |
| eig_file | optional; must be paired with MMN |
| mmn_file | optional; must be paired with EIG |
| spn_file | optional spin input; requires CHK |
| report_json_file | optional path; defaults beside the bundle |
| include_time_reversal | default `true` |
| symmetry_tolerance | default `1e-5` |
| projection_tolerance | default `1e-7` |
| representation_tolerance | default `1e-7` |
| operation_indices | optional explicit operation subset |
| magnetic | magnetic provider or `nothing` for nonmagnetic input |
| support_tolerance | default `1e-12` |
| wigner_seitz_tolerance | default `1e-5` |
| wigner_seitz_search_size | default `3` |
| wannier_center_policy | `:symmetrize` (default), `:validate`, or standard `:keep_input` |
| wannier_center_tolerance | affine covariance and branch-alignment tolerance; default `1e-8` |
| real_space_replica_policy | `:minimum_distance` (default) or `:input` |
| check_roundtrip | default `true` |
| roundtrip_tolerance | default `1e-8` |
| cutoff | optional projection cutoff; default `nothing` |
| covariance_tolerance | default `1e-8` |
| idempotence_tolerance | default `1e-9` |
| check_idempotence | default `true` |
| overwrite | default `false` |
| structure | owned CrystalStructure; required for WIN-free projection |
| projection_basis | owned WannierProjectionBasis matching the declared orbitals |
| mp_grid | explicit positive three-entry mesh for WIN-free projection |
| input_operator_bundle_file | Packed Hamiltonian/position input, mutually exclusive with tb_file and auxiliary regeneration files |
| geometry_source_states | internal actual source-lifetime observations captured by the resolver; not a TOML qualification credential |

## 3. Entry and actual outputs

For normalized TOML use `Runtime.read_task_input` and `Runtime.run_task_input` with an explicit fresh `record_directory`. Relative input paths are resolved from the TOML document. The selected workflow is projection-only `symmetrization`; `gauge_aware` configuration, execution and templates have been removed and are not silently reinterpreted as projection.

The existing expert workflow writes the configured projected Wannier TB file, mathematical Packed model, an ancillary report (the default is `wannier_symmetrization.json`) and `SHA256SUMS`. The normalized Sym entry still calls that workflow and also writes its explicit resolution/provenance records. This is the actual current behavior, not a claim that Sym already implements the normal Wannierization `model.h5` / `model.out` / `model.json` output set. Reports and transport checksums do not grant mathematical model admission or physical qualification. Explicit scientific exports are distinct from ordinary workflow bookkeeping; no output API is changed by this documentation update.

## 4. Centers, replicas and validation

The configured center policy aligns projection branches, projects the centerless position field and restores the selected centers once. Validation keeps its actual affine covariance, Hermiticity, roundtrip and idempotence tolerances. The minimum-distance replica policy uses the final centers, preserves tied images in deterministic order and shares their matrix weights; the input policy retains the supplied replica support. These conventions are persisted as mathematical geometry data and are not runtime response switches.

Retained response-symmetry qualification uses the shared Fourier reconstruction and MMN-edge mapping in `ResponseQualificationKernels.jl`; removing the separate GaugeAware workflow does not remove those live numerical consumers. Missing operators, contradictory frames, invalid source lifetimes and inconsistent masks remain errors. A diagnostic warning or a successful serialization is not a material-validation result.

See [current Wannierization inputs](WANNIERIZATION.md#operators-symmetry-and-migration), [the normalized input contract](NORMALIZED_INPUTS.md), and [current storage formats](STORAGE_SCHEMAS.md).
