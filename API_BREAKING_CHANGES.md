# WannierNLQG 1.0.0 public API baseline

WannierNLQG 1.0.0 is the initial public release. There is no preceding public
API to migrate from. This document records boundaries that public callers can
rely on for the 1.0.0 line.

## Response task configuration

Construct `TaskConfig` from `model`, `sampling`, `tasks`, `execution`, and
optional `output` groups. Each `TaskSpec` has a unique ID and explicit `physics`,
`numerics`, and typed `observable`. Task output is written under
`output_root/<id>/`, and root metadata indexes all task results.

`BZMesh`, `KSlice`, and `KPath` select distinct sampling domains. The public
registry currently exposes `Band_Structure` on `KPath`; unregistered response or
quantum-geometry K-path requests fail at the registry boundary.

## Public and expert namespaces

The top-level facade exports grouped response configuration types, observable
selectors, `RunResult`, and `run`. Symmetry, projection, symmetrization, and
Wannierization expert APIs are accessed through their qualified owner modules.
The exact facade and qualified integration inventories are enforced by the API
and structure checks.

## Wannierization configuration and output

`SymmetryAdaptedWannierizationConfig` contains the immutable `input`, `solver`,
`checkpoint`, `runtime`, and `output` groups. See the
[configuration reference](docs/WANNIERIZATION_CONFIG_MIGRATION.md).

Ordinary and symmetry-adapted runs use the `.wannierization.*` output family.
Checkpoint, text TB, Packed TB, operator, and qualification outputs are selected
through the owning output group. Full-profile operator generation requires a
target contract that binds the operator-oracle and solver MMN roles and their
source, gauge, frame, and Hamiltonian authority.

## Real-space replica policy

`ModelInput` exposes `real_space_replica_policy`, `wsvec_file`, `mp_grid`,
`wigner_seitz_tolerance`, and `wigner_seitz_search_size`. Minimum-distance
selection requires an explicit mapping source. If `wsvec_file` and reconstructed
mapping data are both supplied, their canonical maps must agree. A materialized
Packed model is reused without applying the transformation a second time.

## Storage and qualification

Writers and readers validate their declared wire contract, payload, identity
digests, linked provenance, and qualification metadata. Unsupported or
inconsistent inputs fail closed. Details are maintained in the
[storage schema inventory](docs/STORAGE_SCHEMAS.md).

Scientific formulas, units, tensor-index order, numerical filenames and column
layouts are governed by their calculation documentation. Package tests use
synthetic inputs and do not confer material-specific Physics or Production
qualification.

## 1.1.0 operator-selection update

The original public baseline above is retained. New Wannierization output accepts
only `:hamiltonian_position` and `:full` fixed profiles. Task-derived export uses
`WannierizationOutputConfig(profile=nothing, operator_tasks=(... ,))` with qualified
`WannierNLQG.Core.OperatorTask` values. The default method is `:all`; normalized
requested pairs retain it and the per-task closure records expansion. No arbitrary
operator-name export API is introduced. Existing `hamiltonian_position_spin`
bundles remain readable within supported wire versions, but that profile is no
longer accepted for new Wannierization output. See the
[1.1.0 migration](docs/WANNIERIZATION_CONFIG_MIGRATION.md#task-derived-output-selection-in-110)
and [complete API/dependency reference](docs/WANNIERIZATION.md#task-derived-selection-and-canonical-union).

## 1.1.0 chemical-potential vector migration

`LinearTransportParameters` and `OrbitalMagnetizationParameters` no longer
accept `fermi_energy=`. Use an exact `Vector{Float64}`:

```julia
LinearTransportParameters(fermi_energies=Float64[mu], ...)
OrbitalMagnetizationParameters(fermi_energies=Float64[mu], ...)
```

Multiple strictly increasing values are evaluated in one Integral task. A
KSlice requires a one-element vector. Scalar, range, tuple, generator, empty,
nonfinite, duplicate, or non-increasing inputs fail instead of being collected
or sorted. Linear optical and all unrelated quantities retain their existing
scalar occupation inputs.

Integral results use the new vector schemas and are read through
`read_linear_transport_result` or `read_orbital_magnetization_result`. Old
scalar directories are not accepted by these readers and must be recomputed;
renaming or editing headers is not a migration. The three-mechanism linear
response contract writes `drude`, `quantum_metric`, `berry_curvature`, and
`total`; `berry_curvature` combines the former contact and interband Hall
summands and represents the anomalous-Hall-effect mechanism. The strict DC
reader accepts only `wanniernlqg.linear-transport-vector/2.0` four-file
results, not historical `/1.0` five-file results.
