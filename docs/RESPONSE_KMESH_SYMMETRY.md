# Response-integral magnetic k-mesh reduction

This document defines the v1.0.0 q=0 response-symmetry
contract. It reduces response-integration work only. It neither symmetrizes the
input TB model nor promotes an unqualified model to production.

## Runtime policy

```julia
ExecutionOptions(
    fourier_backend = "direct",
    response_symmetry_file = "response_symmetry.json",
    response_symmetry_policy = "strict", # or "diagnostic"
    response_symmetry_kmesh_mode = "reduced", # or "full"
    response_symmetry_report_enabled = false, # controls full mode only
)
```

`response_symmetry_file=nothing` remains the frozen v2.2.0 compatibility path.
Both policies require an exact fractional point group, a matching model SHA-256,
an exact permutation of the Gamma-centred mesh, and a supported q=0 Integral or
K-slice charge/spin shift/injection task. Finite-q tasks remain out of scope.

- `response_symmetry_kmesh_mode="reduced"` keeps the existing Integral orbit
  reduction and final projector. For K-slice it is explanation-only: the slice
  data are not projected or reduced.
- `response_symmetry_kmesh_mode="full"` always evaluates the full Integral mesh
  and never projects the numerical tensor. With
  `response_symmetry_report_enabled=true`, a nonempty artifact is mandatory and
  the complete explanation is written. With the default `false`, the artifact
  must be absent, no symmetry summary JSON is created, and no allowed/forbidden
  component discussion is written. K-slice follows the same explanation-only
  switch.
- In reduced mode, supplying the artifact continues to enable both reduction and
  its mandatory report; the new tag does not disable that report.
- With neither an enabled full-mode report nor a reduced-mode artifact, the
  configuration summary records only `response symmetry report: DISABLED`.
- Group classification and generator reporting uses the same enablement rules.
  It introduces no additional runtime tag and does not alter mesh reduction,
  tensor projection, normalization, or any response formula.

- `strict` accepts only a sealed complete-contract artifact (current wire 1.0; historical 1.1) with
  `production_eligible=true` and all six formal gates at `PASS`.
- `diagnostic` may consume the historical schema-1.0 layout, an unsealed complete-contract artifact,
  or a failed physical gate. Its outputs are always `DIAGNOSTIC_ONLY` unless the
  same artifact would also satisfy strict policy.
- The historical schema-1.0 field contract remains readable but can never receive
  production eligibility. A manually written integrand `PASS` in a historical 1.0 artifact or
  in a current writer call is only an external claim.

Malformed data, a hash mismatch, fractional identity/inverse/closure failure,
non-bijective atom mapping, a non-permutation mesh action, or a non-finite value
is fatal under either policy.

## Group classification and generators

When response-symmetry reporting is enabled, the human `.out` file inserts
`GROUP CLASSIFICATION` and `POINT-GROUP GENERATORS` after `OVERVIEW` and before
the tensor tables. Classification has three deliberately separate layers:

- the atomic structure records the international Hermann-Mauguin space-group
  symbol and number, Hall symbol and number, coordinate setting, and ordinary
  point-group symbol;
- the magnetic structure records magnetic-space-group Type I--IV and UNI and
  BNS/OG identifiers; its magnetic-point-group machine identity is the class
  number plus normalized colored-operation digest, while the Hermann-Mauguin
  symbol is explicitly display-only;
- the active constraint group records whether time reversal was included, the
  independently canonicalized ordinary or magnetic point group actually
  applied to the response, its class and digest, display symbol and convention,
  exact rational transform from canonical to input basis, order, unitary and
  antiunitary operation counts, the Spglib version, `symprec`, and the
  tolerance-stability result.

These layers must not be conflated. In particular, when
`include_time_reversal=false`, the detected complete magnetic group remains
reported as structural provenance while the active group is explicitly the
unitary subgroup used by the response calculation.

The bundled 1651-record catalogue is generated only from the pinned Spglib
magnetic database and the published project convention. Runtime identity uses
`(magnetic_point_group_number, operation_digest)` under
`wanniernlqg.magnetic-point-group-operations/1.0`; UNI and MSG type identify the
source magnetic space group. The display field `hermann_mauguin` uses
`wanniernlqg.spglib-canonical/1.0` and never participates in equality, caching,
or acceptance. Runtime recomputes identity from the actual colored operation
set and requires it to agree with the generated UNI record. A current complete
artifact with inconsistent Hall/UNI metadata, operation identity, exact basis
bijection, or operation closure is a pre-calculation error under `strict`. A
readable legacy or diagnostic artifact that did not record the necessary fields reports
`NOT_RECORDED` or `UNRESOLVED`, emits a warning, and remains
`DIAGNOSTIC_ONLY`; the reporter does not invent a group name.

Both `full_magnetic_point_group` and `active_constraint_group` record
`magnetic_point_group_number`, `operation_digest`,
`operation_digest_contract`, `hermann_mauguin`, `symbol_convention`,
`equivalent_axis_notation`, and `basis_transform_to_input`. The exact rational
basis object defines `v_input = B*v_canonical` and
`W_input = B*W_canonical*inv(B)`. With time reversal disabled, the active
unitary subgroup receives its own Type-I identity rather than inheriting the
full magnetic-group digest. Bundle aggregation compares full and active class
and digest by role; equivalent identities expressed in multiple input bases are
reported as `MULTIPLE_INPUT_BASES`, not `MULTIPLE_TASK_GROUPS`.

The compact human generator list covers only the active point group. Each
entry carries a stable index, `UNITARY` or `ANTIUNITARY`, an exact fractional
rotation matrix, and a conventional operation symbol. Selection is
deterministic under input-operation reordering: operations are canonically
sorted, a greedy irredundant set is selected, and exact closure must reconstruct
the complete active point group. “Irredundant” means that no reported generator
can be removed from that selected set while retaining closure; it does not claim
the globally minimum possible number of generators.

The per-task `response_symmetry_summary.json` continues to use schema
`wanniernlqg.response-symmetry-summary/1.0`. It preserves every existing
field and carries `group_classification`, `active_constraint_group`, `generators`,
and classification-source provenance. It contains no legacy `catalog_sha256`
identity field; any `display_catalog_sha256` provenance is explicitly
display-only. The machine-readable generator payload
includes the full generator sets for the structural space group, structural
point group, magnetic space group, and active magnetic point group. A space
group generator is a finite Seitz operation modulo lattice translations and
records its exact fractional rotation `W`, fractional translation `tau`,
antiunitary parity, original operation index, reconstructed order, and closure
status. Point-group and Seitz identity, inverse, closure, and complete
reconstruction checks are mandatory before a current strict artifact can be
used.

Group names and generators explain the already validated operation set. They
do not improve or replace Hamiltonian, response-integrand, numerical, or
production qualification evidence.

## Artifact generation and tolerance units

Artifact construction is deliberately separate from response execution:

```julia
using WannierNLQG

WannierNLQG.Symmetrization.write_response_symmetry_artifact(
    "response_symmetry.json";
    structure_file = "POSCAR",
    structure_format = :poscar,
    model_file = "wannier90_tb.dat",
    vasp_magnetic_input_file = "INCAR",
    spglib_symprec_angstrom = 5.0e-5,
    spglib_stability_scan_angstrom = [2.5e-5, 5.0e-5, 1.0e-4],
    fractional_mapping_tolerance = 1.0e-5,
    cartesian_rotation_policy = :group_invariant_metric,
)
```

`spglib_symprec_angstrom` is always measured in Angstrom. The compatibility
keyword `symmetry_tolerance` has the same Angstrom meaning; supplying both with
different values is an error. If neither is present, the default remains
`1e-5 Angstrom`. A fractional-coordinate atom residual is recorded separately
and is never compared to the Spglib distance without conversion.

POSCAR is the structural authority. INCAR `MAGMOM` values are initial magnetic
moments, not self-consistent local moments. The VASP parser accepts repetition,
Fortran exponents, comments, `LNONCOLLINEAR`, `LSORBIT`, and `SAXIS`, and stores
the Cartesian axial vectors in POSCAR atom order. Explicit moments and INCAR may
be supplied together only when they agree atom by atom.

Every detected Seitz operation is checked with a deterministic, species-local
bipartite atom matching. The selected mapping must be a permutation. The writer
records both the maximum periodic fractional residual and the minimum-image
Cartesian Euclidean residual in Angstrom. Magnetic moments obey

```text
m_target = (-1)^theta det(R) R m_source,
```

with independent absolute and relative tolerances. Full Seitz operations and
the deduplicated magnetic point group receive separate identity, inverse, and
closure checks. Fractional rotations use exact integer algebra; translations
are periodic and tolerance-bounded.

## Group-consistent Cartesian rotations

The literal lattice can make `A W A^-1` slightly non-orthogonal even when `W`
is an exact fractional symmetry. The complete contract (current wire 1.0; former 1.1) preserves that raw matrix but does
not use independent per-operation polar fixes. It forms

```text
G_sym = (1/|G|) sum_g W_g^T G W_g
```

and constructs one orientation-preserving effective lattice metric for the
entire group. All effective Cartesian matrices therefore share one convention.
Their orthogonality and Cartesian group-closure residuals must each be at most
`1e-12`; the maximum raw-to-effective correction must not exceed `1e-6`.
The complete contract (current wire 1.0; former 1.1) records the raw matrix, effective matrix, metric change, correction,
and selected policy for every operation. `:raw_warn` is diagnostic-only.

## Wannier90 physical qualification

The writer emits an unsealed structural artifact. The independent expert tool
checks the actual WIN/AMN/CHK/MMN/TB gauge chain:

```julia
result = WannierNLQG.Symmetrization.qualify_response_symmetry_wannier90(
    "response_symmetry.json";
    win_file = "wannier90.win",
    amn_file = "wannier90.amn",
    chk_file = "wannier90.chk",
    mmn_file = "wannier90.mmn",
    tb_file = "wannier90_tb.dat",
    output_file = "wannier90_qualification.json",
    qualified_artifact_file = "response_symmetry_qualified.json",
    diagnostic_continue = true,
    # Optional outputs of the two Runtime validators described below:
    integrand_covariance_evidence = integrand_evidence,
    full_grid_consistency_evidence = full_grid_evidence,
)
```

It evaluates the declared physical formulas

```text
d_g(k) = A(gk) D_g(k) [A(k)^(*)]^-1,
U_g(k) = V(gk)^dagger d_g(k) V(k)^(*),
```

where `(*)` is applied only on an antiunitary branch. The inverse is not
replaced by an identity metric, truncated SVD, or polar projection. Default
gates are CHK semi-unitarity `1e-10`, AMN minimum singular value `1e-5`, AMN
condition number `1e8`, sewing unitarity/subspace closure `1e-6`, sewing group
law `1e-5`, MMN covariance `1e-6`, and Hamiltonian covariance with
`atol=1e-10 eV`, `rtol=1e-8`. The Hamiltonian gate also reports maximum and RMS
k-star energy errors. The input TB is never symmetrized by this tool.

Formal gates execute in order. After an upstream failure, downstream formal
states are `NOT_RUN_DOWNSTREAM_BLOCKED`. `diagnostic_continue=true` may measure
later residuals for cause localization, but those results are stored in a
separate `INDICATIVE_ONLY` lane. The structure gate is recomputed from the
detailed complete-contract checks rather than copied from a summary flag. A qualified
artifact is sealed and receives `production_eligible=true` only when all six
formal gates pass. PASS integrand and full-grid evidence must carry the input
SHA-256 emitted by the validators; an aggregate seal-evidence SHA-256 is then
stored with the artifact.

The complete production chain is:

1. structural and axial-magnetic symmetry;
2. Wannier90 gauge and sewing;
3. raw TB Hamiltonian covariance;
4. raw MMN covariance;
5. complete streamed response-integrand covariance;
6. same-input full-grid versus reduced-grid numerical consistency.

## Mesh, tensor, and numerical validators

The reciprocal action is exact integer modular arithmetic,

```text
k' = s_g W_g^(-T) k,  s_g = +1 (unitary), -1 (antiunitary).
```

Every operation must be a bijection of the complete mesh. Orbit multiplicities
sum to `N_full`, and integration retains the full-grid normalization:

```text
c_j(omega) = (1/N_full) sum_IBZ m_kappa B_j^T F(kappa, omega),
X_sym = B c.
```

Charge responses use `R tensor R tensor R`; spin responses use
`R tensor (det(R)R) tensor R tensor R`. Antiunitary operations exchange the two
field indices and use response-specific signs: Shift Current `+1`, Injection
Current `-1`, Shift Spin Current `-1`, and Injection Spin Current `+1`. No extra
imaginary-part sign is inserted: the internal field-index exchange projection
produces the different real/imaginary time-reversal behavior.

| response | Real part | Imaginary part |
| --- | --- | --- |
| charge shift | even | odd |
| charge injection | odd | even |
| spin shift | odd | even |
| spin injection | even | odd |

Imaginary entries with `b=c` are identically zero. The user-facing report does
not introduce additional polarization-channel names or display exchange
combination formulas.

`validate_response_integrand_covariance` streams all operations, k points,
frequencies, and tensor components and records the worst operation, k point,
frequency, and component without materializing a full-grid cache. Supply
`input_sha256` when its result will be used as formal sealing evidence.
`validate_response_full_grid_consistency` enforces identical input digests,
an elementwise mixed gate, and nonzero-data relative L2 at `1e-8` by default.
Its `full_input_sha256` and `reduced_input_sha256` arguments must be supplied
together and must agree before the evidence can enter a production seal.

The invariant basis keeps deterministic projected-coordinate ordering but uses
a scale-aware numerical-rank floor. This prevents roundoff-amplified dependent
columns from being counted as physical tensor degrees of freedom. The basis is
required to reconstruct the group projector before response execution.

## Output boundary

Result filenames, units, occupations, broadenings, tensor ordering, formulas,
and BZ normalization are unchanged. Runtime metadata records the artifact
schema, seal, production eligibility, policy, hashes, full and representative
counts, multiplicities, tensor dimension, and every warning. Implementation
tests and speedups are engineering evidence only; they do not clear a failed
Wannier, Hamiltonian, MMN, integrand, or full-grid physical gate.

The human `.out` report begins its response-symmetry section with `OVERVIEW`,
then the group-classification and active-generator blocks described above, and
then one `CARTESIAN COMPONENTS` table with `Real part` and `Imaginary part`
columns. It prints signed, nonzero symmetry relations as readable equations.
Projector zero rows are classified before relation
building, so forbidden components never appear simultaneously as equal and
opposite. A contradictory signed class is classified as forbidden instead of
being printed as an inconsistent equation. For q=0 K-slice, the calculated
`tensor_indices` component is repeated in a separate block only after the
all-component table and relations. The same hierarchy is stored in the
schema-1.0 `response_symmetry_summary.json` with `real_part`,
`imaginary_part`, and `real_imaginary_components` fields. The JSON retains the
complete projector, basis, exchange structure, and qualification evidence.
The serial/MPI determinism gate compares every response `.dat` file, the full
summary JSON, and the complete `RESPONSE SYMMETRY` block byte-for-byte. It does
not compare the whole `.out`, whose startup time, MPI metadata, and timing rows
are intentionally run-dependent.
If the projector contains general constraints that are not exact signed
equivalence classes, the report selects the earliest independent basis rows and
says `general constraints; see JSON`; it never invents pairwise relations.
`candidate raw slots` remains an internal selection count distinct from the
final tensor degree of freedom.
