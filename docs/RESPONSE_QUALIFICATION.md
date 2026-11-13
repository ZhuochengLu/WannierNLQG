# Response execution and retained qualification records

The [ordinary calculation policy](ORDINARY_CALCULATION_POLICY.md) governs current
calculation, validation and provenance. Every successful `run` returns a typed
`ResponseQualificationResult` in `RunResult.qualification`.

`execution_eligible` records whether required arrays, components, schemas,
dimensions, units, finite values, frames and mathematical parameters are
sufficient and mutually consistent. Current ordinary results use
`qualification_status="COMPUTATION_READY"` and `production_eligible=false`.
Execution does not establish independent scientific or publication qualification.
Actual numerical warnings determine `quality_review_recommended`; an input's
historical producer or production flag does not by itself demote the calculation.

The backward-compatible seven-argument `RunResult` constructor uses
`NOT_EVALUATED`, `production_eligible=false`, and
`LEGACY_CONSTRUCTOR_NO_QUALIFICATION`. Readers retain recorded historical
`PASS` and `DIAGNOSTIC_ONLY` meanings and do not upgrade historical FAIL.

| Input state | Current execution and record |
|---|---|
| Missing operator, malformed/nonfinite payload, incompatible shape or units | hard error |
| Unsupported schema/algorithm, digest or read-safety failure | hard error |
| Explicit source/gauge/frame/band-frame/component or Hamiltonian-authority conflict | `RESPONSE_QUALIFICATION_CONFLICT`; structured failure retains conflicting contracts |
| Projector Shift Current lacks required compatible derivative overlaps | existing hard error |
| Singular metric or mathematically undefined parameters | existing hard error |
| Material comparison, publication evidence or optional qualification record is absent | compute when formula inputs are defined; retain missing contracts |
| Finite numerical residual exceeds a reporting tolerance | compute and report residual, tolerance and warning |
| All required execution contracts are consistent | `COMPUTATION_READY`; independent science and release gates remain separate |

Structured `reasons`, `verified_contracts`, `unverified_contracts`,
`conflicting_contracts` and `input_qualification` retain source records and actual
measurements. Symmetry execution readiness does not upgrade covariance
`NOT_RUN` or `FAIL` to verified. Human output reports inputs, measurements and
warnings; hashes remain in structured provenance. Parent results aggregate
ordinary execution and actual warnings; numerical `.dat` layouts and formulas
are unchanged.

Missing evidence permits execution when required inputs are present. An explicit
contradiction raises `RESPONSE_QUALIFICATION_CONFLICT`; no policy disables
confirmed integrity, frame or component identity conflicts.
