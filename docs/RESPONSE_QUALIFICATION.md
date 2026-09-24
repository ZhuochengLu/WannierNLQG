# Response execution and production qualification

Every successful `run` returns a typed `ResponseQualificationResult` in
`RunResult.qualification`. It separates two questions:

1. `execution_eligible`: were the arrays, components, schemas, dimensions,
   units, finite values, topology, hashes, frames, and mathematical parameters
   sufficient and mutually consistent for the formula?
2. `production_eligible`: did every applicable solver, numerical, readback,
   representation, band, symmetry, spin-family, finite-band Galerkin, material
   convergence, and physics gate pass?

`qualification_status` is `PASS` or `DIAGNOSTIC_ONLY` for a completed run.
The backward-compatible seven-argument `RunResult` constructor uses
`NOT_EVALUATED`, `production_eligible=false`, and
`LEGACY_CONSTRUCTOR_NO_QUALIFICATION`; it never invents a pass.

| Input state | Execution | Completed-run qualification |
|---|---|---|
| Missing required operator/component; malformed/non-finite/incompatible payload | hard error | no successful result |
| Unsupported schema/algorithm or digest/read-safety failure | hard error | cannot be bypassed |
| Explicit source/gauge/frame/band-frame/hash/Hamiltonian-authority conflict | `RESPONSE_QUALIFICATION_CONFLICT` | conflict is recorded in the failure event |
| Projector Shift Current lacks complete compatible full-Hilbert-space derivative overlaps | hard error | existing uIu gate is unchanged |
| Singular or mathematically inapplicable parameters | hard error | existing validation is unchanged |
| Qualification record, material comparison, or convergence evidence is absent | continue | `DIAGNOSTIC_ONLY`, production false |
| Input bundle is non-production, standard-policy, or deliberately diagnostic | continue | original input state is retained; never upgraded |
| All applicable execution and production gates pass | continue | `PASS`; production true |

Machine-readable fields are `reasons`, `verified_contracts`,
`unverified_contracts`, `conflicting_contracts`, and `input_qualification`.
The same semantics appear in each task's `[Qualification]` metadata, the human
progress log, structured JSONL events, and parent/child `RunResult`s. A parent
multi-task result is conservative: one diagnostic child makes the parent
diagnostic, and production eligibility is true only when every child is
production eligible. Numerical `.dat` layouts and formulas are unchanged.

Missing evidence and conflicting evidence are intentionally distinct. A
missing contract produces a reason such as
`ORBITAL_RESPONSE_QUALIFICATION_NOT_RECORDED` and permits diagnostic execution
when all formula inputs are present. An explicit contradiction raises
`RESPONSE_QUALIFICATION_CONFLICT`; structured `run_failed` output includes the
specific `conflicting_contracts`. There is no `off` mode for confirmed
integrity, frame, or hash conflicts.
