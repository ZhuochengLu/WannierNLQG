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
