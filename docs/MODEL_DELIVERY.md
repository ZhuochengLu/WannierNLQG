# Mathematical model and live scientific reports

Normal normalized Wannierization writes model.h5, model.out and model.json.
The filename stem can be selected with output.model_file. The HDF5 schema is 3.0:
model (lattice/orbital centers/R/degeneracies), packed complex payload/component
index, operator parity/rank/units, replica/grid definitions, and the actual
Hamiltonian/gauge/completeness/source definitions required by algorithms.
The Wannier basis is orthonormal; there is no independent overlap S dataset.
No eligibility groups, content certificates, commit receipts or production labels
are stored. Missing required operators, invalid dimensions/nonfinite matrices,
unsupported units/phases, incomplete full-derivative semantics and IO errors remain
errors. The core reader accepts only the current mathematical format.
An unsupported schema is reported before calculation.

The existing observer appends and flushes one compact English row per accepted
step by default (output.num_print_cycles=1), with stage-appropriate columns.
Detailed progress remains optional. Final centers/spreads, convergence and measured
checks/warnings share one in-memory report with the end JSON snapshot. Scientific
histories are retained in JSON. Files are closed on failure; rank zero alone writes
reports and report failures are propagated collectively. No JSON rewrite per step,
content hashing or payload readback is added to ordinary reporting.

output.final_tb_symmetry_report_enabled defaults false. true runs the existing
additional calculation and reports its measured metrics and applicability.
An unrequested or incomplete check is never represented as passed.
Explicit checkpoint/restart and scientific text/plot outputs remain separate,
requested facilities. Native-generated matrix intermediates use a temporary
lifetime for normal text runs; explicit checkpoint/restart or a
native_matrix_directory retains the working data needed by that request.
The direct Julia API keeps explicit artifact ownership. No additional dependencies
or scientific solver formulas are introduced.

A selected current HDF5 is the numerical authority. A redundant text model path
is not read, authenticated or enrolled in its source lifetime; the legacy text
route remains available when no HDF5 is selected.
