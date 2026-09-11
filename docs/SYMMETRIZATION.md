# Wannier operator symmetrization

WannierNLQG 1.0.x writes one variable-capability model package. Packed HDF5 1.0
stores the complete raw-to-final Wannier-center lifecycle and the single final
real-space replica materialization. Its exact operator inventory is inferred
from explicitly configured input paths. Hamiltonian and position are mandatory.

## 1. Scientific input boundary

Symmetrization always requires both WIN and Wannier90 TB input. TB alone cannot
provide atoms, species, projections, local bases, or the Wannier symmetry
representation, so the public workflow rejects TB-only structural input.

| Explicit inputs | Profile | Operator inventory |
| --- | --- | --- |
| WIN, TB | `hamiltonian_position` | Hamiltonian, position |
| WIN, TB, CHK, SPN | `hamiltonian_position_spin` | Hamiltonian, position, spin |
| WIN, TB, CHK, EIG, MMN | `derivative` | Hamiltonian, position, five derivative operators |
| WIN, TB, CHK, EIG, MMN, SPN | rejected | legacy `full` lacks formal uHu/sHu/sIu evidence; use Wannierization `profile=:full` |

EIG and MMN must be supplied together. Derivative or spin work requires CHK.
CHK alone and every incomplete auxiliary combination fail before scientific
files are read. Paths are never inferred from suffixes. A configured path that
does not exist is an error. `magnetic=nothing` is the nonmagnetic contract and
does not read QE or VASP magnetic moments.

The Symmetrization spin profile validates projection, covariance, idempotence,
and exact serialization, but it does not create the independent spin
source/gauge qualification required by schema 1.0. Its bundle therefore remains
explicitly diagnostic-only. Production spin/full publication belongs to the
Wannierization workflow that owns that qualification evidence.

The derivative family contains Hamiltonian-weighted connection,
Hamiltonian-weighted axial derivative overlap, derivative overlap tensor,
axial derivative overlap, and symmetric derivative overlap. The full profile
also contains spin-times-Hamiltonian, spin-times-position, and
spin-times-Hamiltonian-position.

The TB symmetrization contract is frozen to the verified 2026-08-16 behavior.
Its operation detection, Wannier-center handling, pair-Wigner--Seitz mapping,
real-space projection, and derivative constructor do not accept uIu. The
`SymmetrizationConfig` schema therefore deliberately has no `uiu_file` field.
The EIG/MMN derivative profile retains the historical TB workflow semantics;
it must not be relabelled as a full-Hilbert-space uIu derivative result.

Exact uIu derivatives are a separate, unsymmetrized Wannierization product.
Use `WannierNLQG.Wannierization.prepare_exact_wannier_operator_bundle` with one
sealed TB/CHK/EIG/MMN/uIu gauge chain. That path reuses the stable 2026-08-16
pair-Wigner--Seitz transform contract without injecting uIu into TB symmetry.

Symmetrization depends on `SymmetryFoundation`, `WannierProjection`, and the
non-exported stable integration API of `MatrixElements`, never on
Wannierization. Its extension is activated by `HDF5 + JSON3 + EzXML`. The first
actual operation-detection request calls the qualified Foundation API
`detect_tb_compatibility_symmetry_operations`; only the Foundation loader loads
Spglib. `symmetry_detection_backend_provenance` preserves the existing
`spglib_version` report field without a direct backend dependency. Cross-layer
integration is limited to the explicit Foundation/Projection/MatrixElements
allowlists. Symmetrization imports only named, non-underscored MatrixElements
ports; underscored owner helpers are test-only or private, and the architecture
gate rejects cross-module calls to them.

The extension implementation is split into validation, sewing, projection,
persistence, and workflow components. The component roots are include-only and
the two public workflows remain defined in the original extension namespace;
there is no component-level re-export facade. The split moves complete function
bodies without changing their numerical statements or storage contracts.

## 2. Configuration reference

### 2.1 MagneticMomentConfig

| field | contract |
| --- | --- |
| source | `:qe`, `:vasp`, or `:cartesian` provider |
| file | optional provider file |
| moments_cartesian | optional direct moments in WIN atom order |
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
| win_file | required structural, projection, and mesh authority |
| tb_file | required Hamiltonian and position input |
| output_tb_file | required symmetrized Wannier90 TB output |
| output_real_space_operator_bundle_file | required Packed HDF5 schema-1.0 output for every accepted profile |
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
| wannier_center_policy | `:symmetrize` (default), `:validate`, or diagnostic-only `:keep_input` |
| wannier_center_tolerance | affine covariance and branch-alignment tolerance; default `1e-8` |
| real_space_replica_policy | `:minimum_distance` (default) or `:input` |
| check_roundtrip | default `true` |
| roundtrip_tolerance | default `1e-8` |
| cutoff | optional projection cutoff; default `nothing` |
| covariance_tolerance | default `1e-8` |
| idempotence_tolerance | default `1e-9` |
| check_idempotence | default `true` |
| overwrite | default `false` |

## 3. Minimal run

```julia
using WannierNLQG
using WannierNLQG.Symmetrization

result = symmetrize_wannier_operators(
    SymmetrizationConfig(
        win_file = "wannier90.win",
        tb_file = "wannier90_tb.dat",
        output_tb_file = "symmetrized_tb.dat",
        output_real_space_operator_bundle_file = "wannierNLQG_tb.h5",
        magnetic = nothing,
    ),
)
```

This run produces the `hamiltonian_position` profile. Add the exact auxiliary
fields from the inference table for another complete profile. Selection of an
arbitrary subset is not a public file-workflow option.

Every successful run writes the paired TB file, `wannierNLQG_tb.h5`, a JSON
report, and `SHA256SUMS`. `SymmetrizationResult` returns those paths plus the
profile, complete inventory, and validation evidence. No CHK, EIG, MMN, SPN, or
durable cache copy is generated.

## 4. Wannier-center and replica policies

`wannier_center_policy=:symmetrize` aligns input centers to the projection
branches and applies the affine finite-group projector. Position is first split
as

```text
A_centerless(R) = A(R) - delta(R,0) delta(a,b) tau_raw(a),
```

then only `A_centerless` is projected; the final center is restored exactly
once. `:validate` preserves the input centers only when every selected operation
satisfies the configured affine covariance tolerance. `:keep_input` always marks
the model `production_eligible=false`, even if its centers happen to pass.

After all selected operators have been normalized and projected,
`real_space_replica_policy=:minimum_distance` applies one shared orbital-pair map.
For each `(a,b,R)`, it searches `R + n .* mp_grid` using the final centers,
retains every tied minimum in deterministic order, divides the matrix element
equally between ties, builds one global R support, and writes unit degeneracies.
`:input` preserves the normalized projected input support. This workflow writes
the materialization state into the bundle and never repeats it itself.

## 5. Packed HDF5 1.0

The writer schema is `wanniernlqg.real-space-operators/1.0`. Its only large dataset is
one contiguous, uncompressed, one-dimensional ComplexF64 payload. A versioned
index records the stable operator ID, canonical name, Cartesian component,
zero-based element offset, length, logical `(num_wannier,num_wannier,num_R)`
shape, and component digest. Metadata groups store model, symmetry,
diagnostics, provenance, compatibility, and geometry contracts. Geometry stores
the MP grid, both policies, tolerances, raw/aligned/final centers, branch shifts,
operation residuals, idempotence, replica statistics, algorithm identifiers,
and a geometry SHA-256. Schema 1.0 also stores a digest-sealed qualification
record for every operator under `/qualification/operators`, plus the aggregate
spin-family status under `/qualification/families/spin` and at the root. A root
band-frame summary binds the transform, physical metric, replay, source/artifact,
and contract digests; every operator repeats its applicable frame evidence. Full
profiles additionally record the non-vetoing finite-band Galerkin risk family,
final-Wannier-projector leakage, and cancellation audits.

All stored operators use real-space-last layout and the normalization

```text
X(k) = sum_R exp(i*2*pi*k.R) * X_stored(R) / degeneracy(R).
```

Hamiltonian and position are written to TB, read back with the formal reader,
then put into HDF5. Their HDF5/TB comparison is bit exact. Other projected
operators retain the existing `1e-12` text/serialization gate.

The strict reader rejects missing Hamiltonian or position, profile/inventory
disagreement, unknown IDs, gaps, overlaps, trailing payload, wrong shapes,
non-finite values, geometry inconsistencies, and digest failures. It reads
schema 3/4 for compatibility (schema-3 derivative families remain rejected
because their center convention is ambiguous); the writer only creates public
schema 1.0 with the complete former 6.3 contract. Legacy 6.3 remains readable
with its original recorded-version digest. Public 1.0 requires all current
fields and sealed qualification metadata; a version-label edit cannot upgrade
a historical file.
Schema 2 and historical cache files are not converted. Earlier readable 5.x
artifacts retain their recorded capabilities; read compatibility does not
retroactively add full-uIu provenance. Spin-bearing schema-6.0 artifacts are
readable only as `LEGACY_NOT_RECORDED` diagnostic input and never acquire
schema-1.0 spin-family production qualification. Spin/full schema-6.1 files with
a nonidentity transform are diagnostic
`LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED` inputs. Schema-6.2 full files are
diagnostic `LEGACY_GALERKIN_RISK_CONTRACT_NOT_RECORDED` inputs.

## 6. Runtime use

Set `real_space_operator_bundle_file` in `ModelInput`. If `model_file` is also
set, its exact SHA-256 must equal the paired TB digest embedded in HDF5; the
calculation still consumes only HDF5. HDF5 input cannot be mixed with seedname,
SPN, CHK, EIG, or MMN runtime sources.

Runtime compiles an operator-demand plan from the TaskRegistry before loading
data. Integral tasks load all required Cartesian directions; K-slice tasks load
only requested components. Missing capabilities fail with the task name,
required operators, current profile, and regeneration inputs.
Convention I phases use only the final centers stored in the package. A
diagnostic `:keep_input` package emits an explicit runtime warning.

Runtime then resolves exactly one replica plan before constructing a Fourier
plan or any `MatrixElementWorkspace`. `ModelInput.real_space_replica_policy`
is `auto`, `input`, or `minimum_distance`; `wsvec_file` is considered only when
explicitly supplied and is never guessed from adjacent files. `auto` preserves
text input support unless `mp_grid` or `wsvec_file` requests minimum distance;
for current schema-1.0 and supported historical 6.x bundles it inherits the recorded lifecycle. An already materialized
bundle is reused without a second transform and cannot be reversed to `input`.
Legacy Packed bundles have no authoritative lifecycle record: they are admitted
only as input support and reject runtime minimum-distance or `wsvec_file` use.
When both `wsvec_file` and `mp_grid` are supplied, their complete canonical maps
and SHA-256 must agree. The same plan materializes every demanded operator
component once, including scalar Wannier90 `N_R` and pair/tie weights.

Serial execution prefers `HDF5.readmmap` and uses read-only reshape/views after
closing the file. Incompatible drivers, byte order, dtype, or filesystems use a
buffered range read with the reason logged. MPI opens HDF5 only on global rank
zero, distributes requested continuous ranges among node leaders, and exposes
node-shared read-only views. A rank-private fallback is explicit and reports its
memory cost. Root alone publishes outputs and metadata; the shared replica
summary is emitted to both root-owned metadata and the run progress record.

## 7. Validation and examples

The workflow enforces covariance, idempotence, reciprocal/real-space roundtrip,
TB/HDF5 roundtrip, finite-value, source-hash, and selected-operation gates. A
failure stops the workflow without changing scientific tolerances.

Runnable examples and a deterministic software-only fixture are under
[`../examples/symmetrization`](../examples/symmetrization). The public API and
storage boundaries are summarized in
[`MIGRATION_1.0.0.md`](MIGRATION_1.0.0.md).

## 8. Existing-TB gauge-aware workflow

`symmetrize_existing_wannier_model(GaugeAwareSymmetrizationConfig(...))` is a
separate expert workflow. It reads a native VASP band representation with wire
version `1.0`; a referenced non-`1.0` Band file, including historical
`1.1–1.17`, is rejected explicitly without migration. It verifies
the frozen IrRep parity artifact without using it as a backend, and constructs
the actual Wannier sewing from the CHK composite matrix. For a unitary operation
it uses `V(gk)' * d(g,k) * V(k)`; the antiunitary branch conjugates the source
CHK matrix. It never builds the ideal projection representation and cannot call
SAWF, disentanglement, Wannierization, or response calculations.

POSCAR, WAVECAR, source/target WIN, EIG, MMN, CHK, TB, representation, and oracle
identities are recorded before projection. K points are matched modulo reciprocal
lattice vectors by a unique deterministic bijection. The band representation,
reciprocal shifts, group law, spin action, time reversal, Kramers relation, CHK
semi-unitarity, target-subspace closure, Wannier-sewing unitarity, and actual
Wannier group law are measured independently.

`threshold_policy=:record_and_continue` is the default for this expert workflow.
Every finite numerical gate is stored as a `GaugeAwareThresholdEvent`; an
exceedance does not modify the measured matrices and does not stop the group
average, position-link projection, or serialization. A complete result with at
least one exceedance is `PASS_WITH_WARNINGS`, has `production_eligible=true`,
and separately records `thresholds_passed=false`. It must not be reported as if
all scientific gates passed. `threshold_policy=:fail_stop` preserves the strict
legacy early-return statuses. Missing or mixed inputs, dimension or k-map
errors, non-finite arrays, impossible replica materialization, and failed
serialization remain fatal under both policies.

The Hamiltonian stage first publishes
`outputs/C00/wannier90_sym_hr.dat`. A deliberately deferred position stage
returns `HOLD_POSITION_PENDING`. A complete run writes the variants selected by
`materialization_variants` (default `(:C00, :C11)`) as paired TB, HR, and
`wannierNLQG_tb.h5` bundles after recording raw MMN-to-TB, endpoint-link,
center, covariance, and Fourier metrics. The four supported variants are C00
(input centers/input replicas), C01 (input centers/minimum distance), C10
(projected centers/input replicas), and C11 (projected centers/minimum distance).
The projected-center variants preserve the established behavior: links are
expanded with the input centers and the unaligned projected centers only replace
the home-cell position diagonal. No link polar normalization, hidden
Hermitianization, branch alignment, or model overwrite is performed. Each HDF5
payload is built from the formal TB readback and checked bit-exactly against its
paired TB.

Every terminal result retains `REPORT.md`, JSON/TSV metrics, structured threshold
events, logs, and SHA-256 manifests; illegal configuration still throws. `PASS`
means all measured thresholds passed. `PASS_WITH_WARNINGS` is eligible only by
the explicitly selected continuation policy and is not broader physical
validation. The self-contained synthetic workflow is:

```bash
julia --project=. examples/symmetrization/run_all.jl
```
