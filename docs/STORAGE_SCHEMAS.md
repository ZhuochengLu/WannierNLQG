# Independent storage formats and current mathematical contracts

Software releases and scientific file formats are independently versioned. A
software version is not an artifact wire version or a numerical qualification.
The values below describe the current producers. Never relabel an older file to
make it appear current; use its explicit converter when the required mathematical
data exist, or report the missing data or definition.

## Current format inventory

| Independent artifact | Current wire identifier | Actual scope |
| --- | --- | --- |
| Packed orthonormal real-space model HDF5 | `3.0` | Mathematical model, operator payload/index, units, geometry and needed definitions; ordinary readers accept only this format |
| Wannierization checkpoint HDF5 | `3.0` | Complete solver/state/diagnostic data and native-definition encoding under the publication lifetime; ordinary reading is current-wire only |
| Fixed-subspace internal payload | `2.0` | Arrays persist in the checkpoint; the standalone public fixed-subspace writer/reader is retired |
| SAWF U-convergence diagnostics HDF5 | `1.1` | Actual scalar diagnostics, raw spreads and IBZ frames |
| Band-representation HDF5 and JSON summary | `1.0` | The shared public Band header remains `WannierNLQG.band_representation`; all three public readers accept only wire `1.0` |
| Projection-representation search HDF5 and canonical JSON summary | `4.0` | Complete mathematical definitions, canonical values and redundant typed-view consistency; no content authentication |
| Star-covariant PAW gauge HDF5 | `2.0` | Actual frame, transform, metric, mask and source definitions |
| VASP PAW matrix-element HDF5 | `2.0` | Current mathematical generator layout |
| QE PAW matrix-element HDF5 and oracle provenance | `2.0` | Actual matrix/oracle values and required source/frame definitions |
| Symmetry-completed QE PAW HDF5 | `2.0` | Current completed mathematical payload |
| PAW SCDM input HDF5 | `2.0` | Frames, projectors, metric data and complete Hamiltonian authority definition |
| PAW block-partition audit HDF5 | `2.0` | Actual block audit data |
| Wannier uIu generation provenance / partial JSON | `2.0` | Actual target/frame/operator definitions and numeric generation information |
| Wannier Hamiltonian-operator provenance JSON | `2.0` | Actual Hamiltonian, target/frame and operator definitions |
| VASP/QE PAW SPN provenance | `2.0` | Actual spin-operator/frame definitions |
| Native VASP wavefunction-gauge HDF5 and AMN provenance | `2.0` | Actual source/gauge and projection data; distinct from the public Band header |
| Wannier gauge-chain diagnostic HDF5 / JSON | `2.0` | Actual diagnostic values |
| Native point-orbital response-symmetry JSON | `wanniernlqg.point-orbital-response-symmetry/1.0` | Model-bound operations and orbital representations; runtime checks the actual grid and offsets |
| Response-symmetry input artifact | `/1.0` | Retained artifact-based input format |
| Response-symmetry runtime summary JSON | `/1.0` | Artifact-based summaries retain this marker; the native point-orbital branch uses `/2.0` |
| Response-symmetry qualification JSON | `/1.0` | Retained explicit report wrapper; not a current model credential |
| Symmetrization report JSON | `1.0` | Existing Sym workflow report; its separate output-set limitation is documented in the Symmetrization guide |
| Band-structure `wanniernlqg.kpath` JSON | `2.0` | Branch-aware path; continuous `1.0` sidecars require the explicit kpath converter |
| Model lattice probe JSON | `1.1` | Current mathematical model metadata extraction |
| Other existing plot sidecars / panel manifests | `1.0` | Their existing plotting contracts |
| Cartesian-region spectral tables | `wanniernlqg.cartesian-region-spectral/1.0` | Dimension-aware finite-cutoff response; not a bulk dielectric schema |
| Linear Transport integral tables | `wanniernlqg.linear-transport-vector/2.0` | Ordered mu axis and drude/quantum_metric/berry_curvature/total tensors in S/m |
| Orbital Magnetization integral tables | `wanniernlqg.orbital-magnetization-vector/1.0` | Ordered mu axis and SRocc/CMocc/total vectors in muB/cell |

Unversioned outputs remain unversioned. In particular, the BCD/BCQ DC moment and
conductivity `.dat` writers record explicit axes, units and effective calculation
metadata; this inventory does not invent a new schema field. See [BCD/BCQ](BCD_BCQ.md),
[vector responses](LINEAR_AND_ORBITAL_RESPONSES.md) for their numerical and applicability contracts.

## Current mathematical model

The active Packed/model implementation is
`ext/WannierNLQGOperatorBundleExt/CurrentModelFormat.jl`, included after the legacy
implementation. Its writer and ordinary reader use mathematical format `3.0`.
The model contains `model`, `geometry`, `payload`, `index`, `operators` and
`definitions`. Required values include the finite nonsingular lattice, positive
support/degeneracies, centers, H and position operators, component extents and
units, replica policy and any source/frame/mask/metric/authority definitions
needed by the selected consumer. Empty or contradictory required mathematical
content cannot be replaced by a label or a historical digest.

The current writer emits no software-version whitelist, compatibility credential,
qualification group or construction-content seal. Ordinary reading validates
actual data and definitions; historical PASS/FAIL labels do not grant admission.
A diagnostic warning also does not prove physical accuracy or convergence.

Unsupported model formats are rejected without modifying the source.
Missing required mathematical definitions must be supplied by authoritative
source data, not by a historical qualification label.

## Task-derived Packed operator selection

Task-derived requests form one canonical union of the mathematical operators
required by the selected task/method pairs. The executable owner is
[`Core/OperatorTaskRequirements.jl`](../src/Core/OperatorTaskRequirements.jl),
shared by generation and Runtime consumption. The current model carries the
actual operator inventory, component layout, units and any needed source/frame
or target definitions. A report label or historical content digest cannot stand
in for an absent operator or definition. See the
[current input guide](WANNIERIZATION.md#task-derived-selection-and-canonical-union).

## Neighbor-order algorithm provenance

Neighbor ordering denotes the actual k-point/neighbor/reciprocal-shift topology
and its associated overlaps and weights. A permutation must carry the numerical
blocks and weights with the corresponding edges; relabelling alone is not a
mathematical conversion. Different neighbor sets cannot be made equivalent by
sorting their names. Generator and model consumers retain their explicit ordering
and frame conventions and reject contradictory actual definitions. Source-file
lifetime observation remains distinct from mathematical ordering and from a
claim of physical accuracy.

## Checkpoints, relocation and archived payloads

The current checkpoint writer/ordinary reader use `3.0`. The writer records
`content_authentication=NOT_PERFORMED`; a legacy checkpoint content certificate
is not accepted as a current input. Actual solver state, masks, authority/input
and frame definitions, diagnostics, stopping state and restore constraints remain
validated. Stored convergence/quality flags are diagnostic values, not proof of
material quality or a substitute for those checks.

Checkpoint publication declarations and local receipts control the immutable
source lifetime. They do not establish byte equality with another file or prior
scientific qualification. Explicit adoption of relocated current data performs
its complete decoder and domain checks before publishing a local receipt. Missing
or inconsistent mathematical content must still fail.

Retained older-wire decoder constants do not make ordinary readers accept those
wires. Explicit older payload reading or migration is separate from optimizer
continuation; digest-only input declarations cannot manufacture the complete
input/mask definitions required to resume. The archived fixed-subspace decoder
retains its explicit `1.0`, `1.1` and `2.0` layouts, while the standalone public
fixed-subspace and gauge-aware-validation outputs remain retired. Current arrays
are stored in the applicable model/checkpoint.

Band remains a distinct strict `1.0` public wire. A legacy non-`1.0` Band header
must not be rewritten to acquire current meaning. Projection search is likewise
current `4.0` only: its canonical values, typed mirror and mathematical constraints
must agree, and unsupported older identity-only records require original
representation/target inputs. A successful format decode alone grants no material
or production qualification.

## Internal names and engineering evidence

| Internal identity | Current value | Meaning |
| --- | --- | --- |
| `standard_construction_v1` | `v1` | Retained construction/solver diagnostic context |
| `operator-qualification` | `1.5` | Retained internal name for target/parent operator diagnostics; not a normal model credential |
| `tb_symmetry_qualification` | `2.0` | Mathematical diagnostic/report representation; not independent physics acceptance |
| `projection_search_hdf5_mirror` | `/3.0` | Typed-view definition tag, separate from search wire `4.0` |
| `EvidenceHashing` | `2.1` | External engineering evidence and source inventory, separate from ordinary mathematical model I/O |

The software version and GPL metadata checks remain independent. Retained
source/publication lifetime checks, explicit archived-data audits and external
engineering inventory hashes are not reintroduced as normal model content
certificates. Model readers enforce the current mathematical data contract; development
receipts and archived qualification labels are not normal reader credentials.
