# Independent storage formats and retained contracts

The first public software version remains `1.0.0`. Independently written
scientific artifacts use wire identifiers `1.0`, preserving their numerical
payloads and current qualification contracts. Band-representation HDF5 retains
`schema="WannierNLQG.band_representation"` and writes
`schema_version="1.0"`; no new attributes are added. Its three readers accept
only this wire version and reject non-`1.0` files, including historical
`1.1–1.17`, without migration.

## Independent artifact identifiers

This table describes current writer identifiers, not an instruction to relabel
historical files. An older format is readable only where its existing reader
supports it, with the original field, digest, and qualification requirements.

| Independent artifact | Current wire identifier | Preserved contract / previous writer |
| --- | --- | --- |
| Wannierization checkpoint HDF5 | `1.2` | Complete 2.28 numerical layout (internal contract 2.29) plus the `standard_construction_v1` policy, gate-evidence seal, and typed `WannierizationEligibility` block; the previous wire `1.1` remains readable with unchanged readback, and older files require external migration |
| Packed real-space operator bundle HDF5 | `1.1` | Complete 6.3 numerical layout with Standard availability and quality-review fields; older files require external migration |
| Band-representation HDF5 | `1.0` | Current complete contract; non-`1.0` versions rejected by all three readers; no migration or qualification upgrade |
| Band-representation JSON summary | `1.0` | Existing summary layout |
| Projection-representation search HDF5 and canonical JSON summary | `1.0` | Complete 2.1 canonical payload and typed mirror |
| Star-covariant PAW gauge HDF5 | `1.0` | Complete 1.11 physical-frame and replay contract |
| SAWF fixed-subspace HDF5 | `2.0` | Capsule sourced from `source_sha256["z_seal_class"] == "CONVERGED"`; the reader also accepts wire `1.0` and `1.1` |
| SAWF U-convergence diagnostics HDF5 | `1.0` | Complete 1.5 diagnostics contract |
| Response-symmetry input artifact | `/1.0` | Complete former 1.1 rotation, tolerance, seal, and qualification contract; input schema unchanged |
| Response-symmetry runtime summary JSON | `/1.0` | Keeps the 1.0 marker while carrying full/active operation-digest identities, display-only symbols, exact basis transforms, deterministic generators, and Spglib catalogue provenance |
| Response-symmetry qualification JSON | `/1.0` | Existing qualification-report wrapper |
| Symmetrization report JSON | `1.0` | Former 3.0 report content |
| Gauge-aware validation HDF5 | `1.0` | Existing complete validation content |
| VASP PAW matrix-element HDF5 | `1.0` | Former 1.3 source, frame, and matrix-element contract |
| VASP / QE PAW SPN provenance | `1.0` | Former 1.2 spin/source/frame contract |
| QE PAW matrix-element HDF5, oracle provenance, completed matrix-element HDF5 | `1.0` | Existing complete contracts |
| PAW SCDM input HDF5 | `1.0` | Existing input contract |
| PAW block-partition audit HDF5 | `1.0` | Former 1.1 audit content |
| Wannier uIu generation provenance / partial JSON | `1.1` | Target-scoped qualification plus parent audit; legacy 1.0 remains readable |
| Wannier Hamiltonian-operator provenance JSON | `1.1` | Target-scoped closure and explicit generation/delivery gauge evidence; legacy 1.0 remains readable |
| VASP/QE PAW SPN provenance JSON | `1.1` | Target hard gate, complete-parent audit, mask digests, and target-contract binding |
| QE direct PAW MMN/AMN provenance JSON | `1.1` | Target hard gate and complete-parent audit; legacy 1.0 remains readable |
| Wannier gauge-chain diagnostic HDF5 / JSON | `1.0` | Existing diagnostic contract |
| AMN provenance and native VASP symmetry-gauge HDF5 | `1.0` | Existing provenance contracts |
| Band-structure JSON; plot sidecars, lattice probes, panel manifests | `1.0` | Existing output contracts |
| Linear Transport integral tables | `wanniernlqg.linear-transport-vector/2.0` | Ordered μ axis plus `drude`, `quantum_metric`, `berry_curvature`, `total` tensors in S/m; strict four-file reader; historical `/1.0` is not accepted |
| Orbital Magnetization integral tables | `wanniernlqg.orbital-magnetization-vector/1.0` | Ordered μ axis plus SRocc/CMocc/total `N_mu x 3` complex vectors in muB/cell; strict provenance reader |

Outputs that have no schema field, including block-audit CSV and its unversioned
JSON summary, keep their existing structure. This numbering change does not add
version fields to such outputs.

### Vector chemical-potential response tables

Each vector response file starts with the schema, quantity, term, method,
temperature, μ count/SHA-256, task SHA-256, full release-tree SHA-256, MPI/thread
shape, input identity, qualification, and relevant source/gauge/target fields.
The first data column is `mu_eV`. Transport columns follow
`xx,xy,xz,yx,yy,yz,zx,zy,zz`, each as adjacent Re/Im values. Orbital columns
follow `x,y,z`, also as Re/Im pairs. The four transport files are `drude`,
`quantum_metric`, `berry_curvature`, and `total`; the three magnetic files are
`srocc`, `cmocc`, and `total`.

The strict readers reject incomplete sets, scalar-era tables, changed order,
shape, unit, μ value, μ/task/source hash, metadata identity, or decomposition.
These schemas are new artifacts. Relabelling old scalar files, including old
muB/cell or A/m magnetic outputs, is not a migration.

## Internal identities that retain their versions

| Identity | Retained version | Why it is separate |
| --- | --- | --- |
| `standard_construction_v1` | `v1` | Embedded checkpoint construction policy, quality-review status, and complete diagnostic contexts |
| `wanniernlqg.construction-evidence` | `1.0` | Optional Packed sub-contract sealing construction policy, full original gate JSON, quality review, model availability and eligibility flags |
| `operator-qualification` | `1.3` | Embedded target/parent metrics and generation/delivery gauges; legacy 1.2 remains readable without qualification upgrade |
| `tb_symmetry_qualification` | `1.7` | One qualification payload shared by HDF5 and its JSON mirror |
| `EvidenceHashing` | `2.1` | Engineering evidence/manifest hashing specification |
| `projection_search_hdf5_mirror` | `/2.1` | Internal typed-view hash domain, not a file-format identifier |
| Packed `compatibility.minimum_reader_schema` | `1.1` | Minimum in-process reader wire schema; older bundles require external migration |
| Formula hashes, algorithms, band-frame and projector contracts | Existing identifiers | Physical and numerical evidence contracts are unchanged |
| Source-schema references and historical digest domains | Recorded original values | Preserve provenance and verify old files with their original rules |

The TB-symmetry JSON mirror deliberately retains qualification schema `1.7`:
its content is the same digest-bound internal qualification payload, rather than
a separately versioned storage wrapper. Renumbering only that mirror would
contradict the embedded HDF5 qualification evidence.

## Reading and migration

Readers use explicit wire-to-contract decisions, never numeric comparisons such
as `1.0 < 6.3`. Band readers do not infer file age or distinguish a historical
`1.0` collision; every accepted Band file must satisfy the current complete
contract and its strict/diagnostic eligibility restrictions. Historical Band
fixtures retain their original labels as rejection evidence. A combined workflow
that references a non-`1.0` Band file fails explicitly, even if its checkpoint
or other artifacts are otherwise readable.

For other formats with supported historical reads, where a historical `1.0`
existed, current files must satisfy the
complete intended contract; modern metadata followed by a validation failure
must not trigger a fallback to weaker legacy rules. A wire label alone cannot
establish restart or production eligibility.

Formats that retain historical-read support validate old files with their
original digests and write a separate new-format file. Wannierization
checkpoints and Packed HDF5 bundles are explicit exceptions. The checkpoint
reader accepts wire `1.1` and `1.2`, where `1.2` adds the typed
`WannierizationEligibility` block and maps internally to numerical contract
`2.29` while preserving the `1.1` numerical readback. The Packed HDF5 bundle
reader accepts only `1.1`. Conversion beyond the readable set must occur in an
external migration tool. Historical fixtures retain their original labels and
digests. See the
[public API overview](MIGRATION_1.0.0.md) and each format's workflow documentation.

### Packed construction evidence

When construction metadata is supplied, the writer emits a
`construction_evidence` group with schema `wanniernlqg.construction-evidence`,
version `1.0`, and a deterministic typed payload SHA-256. The scientific-content
seal includes that SHA-256 under a separate tagged domain. The contract retains
the complete original `construction_gate_records_json`, including stage, code,
value, threshold, original result and action where recorded. It also binds
construction policy, quality-review recommendation, sticky quality failure,
model availability, standard eligibility, and production eligibility flags.

All public manifest, payload, component and full-bundle readers verify this
contract before returning. Missing payloads or seals, malformed records, modified
records, and inconsistent root or diagnostics duplicates are rejected. Removing
the whole sub-contract without changing the scientific seal also fails. A
checkpoint reference alone does not validate a separately distributed Packed
file; the construction sub-contract supplies its local integrity check.

Supported historical files without this sub-contract retain exactly their old
scientific-content digest layout. Their free diagnostic metadata does not acquire
new integrity or qualification guarantees. Re-export writes a separate artifact
with the new seal; numerical arrays may remain byte-identical while the scientific
identity changes to include the construction evidence. This does not change the
public file schema or imply physics or production qualification.

### Operator target qualification and delivery gauge

`WannierOperatorTargetContract` hash domain `1.1` binds the unique
`BandRepresentationQualificationScope`, outer and frozen masks and their
SHA-256 values, `target_authority=outer_window`, and
`parent_audit_policy=audit_only`. Generalized norm, oracle parity, identity,
and operator-closure tolerances are hard gates on the outer target. The same
finite metrics over the complete parent space are retained as `AUDIT_PASS` or
`AUDIT_EXCEEDED`; parent exceedance alone cannot be interpreted as target
failure. Parent dimensions, finite values, topology, source hashes, spin
basis, radial-q integrity, and SPN Hermiticity remain structural hard gates.

Legacy target contracts remain readable as `full_parent/legacy_hard_gate`.
Readers never relabel them as target-scoped qualification. Full-bundle delivery
records also distinguish the raw generation gauge from the delivered gauge.
Only an actual checkpoint/Wannier transform with replay and roundtrip evidence
may record `delivery_target_band_gauge=final_wannier_gauge`; changing a label
without the corresponding transform is rejected.

### Task-derived Packed operator selection

Packed wire `1.1` supports a task-derived selection contract without changing the
numerical layout. `operator_selection_mode` is `profile` or `tasks`;
`operator_profile=task_derived` is a persisted result of task resolution, never a
public fixed Wannierization profile or permission to store arbitrary operators.

| Metadata | Meaning |
| --- | --- |
| `requested_tasks` | Original `quantity:method` request tokens |
| `normalized_tasks` | Canonical sorted, deduplicated requested pairs; `:all` is retained |
| `task_dependency_closure` | Per requested pair, expanded registered methods and exact operator/source union |
| `resolved_operator_inventory` | Exact canonical union in Core real-space registry order |
| `resolved_source_inventory` | Exact canonical source union in Core source-registry order |
| `operator_requirement_registry_version` | Shared Core requirement registry version, currently `1.0` |
| `operator_selection_sha256` | Deterministic seal of registry version, normalized requested pairs, operators and sources |
| `operator_target_contract_sha256` | Bound target contract for selected sources that require it; not a demand for a target contract on geometry-only selection |
| `authoritative_hamiltonian` | Selected native or symmetrized authority backend identity |
| `authoritative_hamiltonian_sha256` | Packed root materialized Hamiltonian authority digest; qualification records also bind `authoritative_hamiltonian_digest` in their own contract |
| `authoritative_hamiltonian_input_sha256` | Complete authority input hash map in provenance/qualification |

The authority source is a semantic closure over backend, digest and input hashes.
The representation-side authority contract digest and materialized Hamiltonian
digest have distinct roles and must not substitute for each other. Weighted
operators must use the same authority and final Wannier gauge as the Hamiltonian.
Source-file and sidecar hashes and the target-contract digest remain independently
validated; the selection SHA-256 alone is not a seal of matrix payloads or inputs.

Fresh readers reconstruct from `requested_tasks` using the supported Core registry,
then compare normalized pairs, expanded closure, exact inventory, source inventory,
registry version and selection digest. Missing, extra, reordered or tampered
inventory, changed task/method, unsupported registry version, inconsistent source
hashes, target contract, sidecar or Cartesian component indices fail closed.
All selected operators retain complete Cartesian components. Runtime requires
its operator and component demand to be subsets of the validated bundle.
`internal_connection`, `gauge_correction` and `berry_connection` are runtime-derived
capabilities from H/position, never additional persisted operator kinds.

For task-derived artifacts, authority provenance must contain a nonempty input
hash map with valid SHA-256 values and `AUTHORITATIVE_HAMILTONIAN_SHA256`.
Every selected Hamiltonian-dependent operator must match the bundle authority
backend, materialized digest and input hash map. All selected operators record
both `target_band_gauge` and `delivery_target_band_gauge` as `final_wannier_gauge`.
When the selected source closure requires a target contract, its digest must
match provenance and every selected operator; otherwise the selection target is
`NOT_APPLICABLE`. Mismatches fail as `HAMILTONIAN_REFERENCE_MISMATCH`,
`OPERATOR_TARGET_CONTRACT_MISMATCH` or `OPERATOR_DELIVERY_GAUGE_MISMATCH`.

Existing fixed-profile wire-1.1 bundles, including `hamiltonian_position_spin`,
retain their original reader path and digests when no task-selection contract is
present. They acquire no task-derived qualification. This compatibility does not
make the old spin profile available for new Wannierization output, and does not
extend the readable wire-version set. Earlier unsupported schemas still require
external migration. Never rewrite old artifacts in place or upgrade them by
editing a profile label. See the [complete task dependency table](WANNIERIZATION.md#complete-supported-task-dependencies).

### Neighbor-order algorithm provenance

Packed wire `1.1`, operator qualification schema `1.3`, raw-source generation
provenance, and the global `derivative_overlap_algorithm_version` value
`wannier90-get_FF_R-v1` are unchanged by the neighbor-order correction. Corrected
constructors use `operator_profile_assembly_algorithm_version` =
`schema-6.3-pair-wigner-seitz-spin-galerkin-risk-audited-profile-v5-source-neighbor-order`
and exact raw-bundle `operator_construction` =
`raw-same-gauge-schema-6.3-v2-source-neighbor-order`. Raw uIu/uHu generation
provenance remains separate from downstream tensor reconstruction.

An additive `qualification.source_neighbor_order_contract` stores algorithm
`source-to-internal-per-k-both-indices-v1`, `num_neighbors`, `num_kpoints`,
`axis_order=source_neighbor,kpoint;column_major`, the flat integer
`source_to_internal` map, and `source_to_internal_sha256`. Each k-point column is
validated as a complete permutation. The map is flattened source-fast/k-outer;
its SHA-256 hashes `string(num_neighbors,",",num_kpoints,";",join(flat,","))`.

Each rebuilt derivative-overlap tensor, axial/symmetric contraction and
Hamiltonian-weighted axial derivative-overlap record carries a
`source_neighbor_order_contract` receipt. It binds the algorithm, shared map digest,
`operator_kind`, status `REBUILT_SOURCE_TO_INTERNAL`, `source_artifact_sha256`,
`source_input_sha256`, `operator_target_contract_sha256`, `delivery_payload_sha256`
and `delivery_component_sha256`. Component hashes are comma-separated in stored
index order (rank one: axis; rank two: first axis outer, second axis inner).
Existing record and qualification seals cover these additive fields. Writer and
fresh-reader validation recheck map, source/target/payload bindings and actual
component-index hashes; inconsistent evidence fails with
`OPERATOR_NEIGHBOR_ORDER_CONTRACT_MISMATCH`.

Absence of the additive evidence remains readable as `LEGACY_UNVERIFIED`.
Generic readers/writers never manufacture receipts: changing an assembly label
or resealing old bytes does not grant `REBUILT_SOURCE_TO_INTERNAL`. The exact
raw-bundle path records constructor/map provenance but has no qualified
per-operator receipt; its root marker alone does not grant rebuilt status.
A valid receipt establishes construction provenance, not material convergence or
production eligibility. Rebuild affected tensors and dependent bundles from
qualified raw inputs; never upgrade old numerical payloads by relabeling them.
