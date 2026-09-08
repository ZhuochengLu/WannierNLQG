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
| Wannierization checkpoint HDF5 | `1.0` | Complete 2.28 state plus the additive `diagnostic_construction_v1` policy and gate-evidence seal |
| Packed real-space operator bundle HDF5 | `1.0` | Complete 6.3 layout and qualification contract, plus conditional construction-evidence seal |
| Band-representation HDF5 | `1.0` | Current complete contract; non-`1.0` versions rejected by all three readers; no migration or qualification upgrade |
| Band-representation JSON summary | `1.0` | Existing summary layout |
| Projection-representation search HDF5 and canonical JSON summary | `1.0` | Complete 2.1 canonical payload and typed mirror |
| Star-covariant PAW gauge HDF5 | `1.0` | Complete 1.11 physical-frame and replay contract |
| SAWF fixed-subspace HDF5 | `1.0` | Complete 1.1 fixed-subspace contract |
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
| Wannier uIu generation provenance / partial JSON | `1.0` | Former 1.2 source/frame contract |
| Wannier Hamiltonian-operator provenance JSON | `1.0` | Former 1.3 uHu/sIu/sHu source/frame contract |
| Wannier gauge-chain diagnostic HDF5 / JSON | `1.0` | Existing diagnostic contract |
| AMN provenance and native VASP symmetry-gauge HDF5 | `1.0` | Existing provenance contracts |
| Band-structure JSON; plot sidecars, lattice probes, panel manifests | `1.0` | Existing output contracts |

Outputs that have no schema field, including block-audit CSV and its unversioned
JSON summary, keep their existing structure. This numbering change does not add
version fields to such outputs.

## Internal identities that retain their versions

| Identity | Retained version | Why it is separate |
| --- | --- | --- |
| `diagnostic_construction_v1` | `v1` | Embedded checkpoint construction policy, manual-review status, and complete diagnostic contexts; absent legacy policy means strict |
| `wanniernlqg.construction-evidence` | `1.0` | Optional Packed sub-contract sealing construction policy, full original gate JSON, manual review, quality failure, classification and eligibility flags |
| `operator-qualification` | `1.2` | Embedded operator qualification and its payload digest |
| `tb_symmetry_qualification` | `1.7` | One qualification payload shared by HDF5 and its JSON mirror |
| `EvidenceHashing` | `2.1` | Engineering evidence/manifest hashing specification |
| `projection_search_hdf5_mirror` | `/2.1` | Internal typed-view hash domain, not a file-format identifier |
| Packed `compatibility.minimum_reader_schema` | `6.2` | Historical field-contract baseline, not numerical ordering of wire labels |
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

For formats other than Band representation, read supported old files with
their original digests, then write a separate
new-format file. Version-dependent digests and references are regenerated;
scientific arrays and states retain their numerical meaning. Historical
fixtures retain their original labels and digests. See the
[public API overview](MIGRATION_1.0.0.md) and each format's workflow documentation.

### Packed construction evidence

When construction metadata is supplied, the writer emits a
`construction_evidence` group with schema `wanniernlqg.construction-evidence`,
version `1.0`, and a deterministic typed payload SHA-256. The scientific-content
seal includes that SHA-256 under a separate tagged domain. The contract retains
the complete original `construction_gate_records_json`, including stage, code,
value, threshold, original result and action where recorded. It also binds
construction policy, manual-review requirement, sticky quality failure,
diagnostic classification, diagnostic-only and production eligibility flags.

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
