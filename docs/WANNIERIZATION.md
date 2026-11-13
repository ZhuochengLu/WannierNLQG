# Wannierization

This guide describes the normalized TOML entry in WannierNLQG 1.2.0. Successful execution alone does not qualify a material. The supported construction and continuation contracts are described below.

## Entry and source selection

Use `Runtime.read_task_input(path)` followed by `Runtime.run_task_input(input; record_directory=new_directory)`. Paths inside the TOML resolve relative to that file, not the current working directory. `check/explain` reports normalized requirements. There is no user `schema_version` or temporary WIN. Only the documented normalized configuration keys are accepted. The nested `[wannierization.*]` and `[symmetrization.*]` namespaces are rejected; use the documented top-level tables.

Four workflows are available: `wannierization` with mode `ordinary` or `symmetry_adapted`, projection-only `symmetrization`, and `mesh_screening`. Ordinary H/r may use external EIG/MMN/AMN. Without `[matrices]`, it uses `[source]`. SAWF, full output and extended task dependencies require one complete native source; external and native matrices cannot be mixed or selected by file-existence fallback. See the templates under `examples/text_input/` and [normalized inputs](NORMALIZED_INPUTS.md).

## Solver and accepted state

Ordinary and constrained SAWF use their fixed SMV–Fletcher–Reeves two-stage paths. Initialization is `amn`, `random` or `restart`. Independent `fixed_subspace`, free algorithm profiles, polar optimizer and joint scheduling are removed. Internal U fixed-Z projectors, FR conjugate directions, descent fallback, line search and polar matrix decomposition/retraction safeguards remain.

The normalized `[solver]` defaults are `dis_num_iter=200`, `dis_conv_tol=1e-10`, `dis_conv_window=3`, `num_iter=500`, `conv_tol=1e-10`, `conv_window=3`. Z uses relative objective changes; U uses absolute spread changes in angstrom squared. A U convergence window of at most one disables that early-stop criterion; the Z window must be positive. Zero stage budgets skip the corresponding optimization, not requested export. Skipped, inapplicable, exhausted and converged states remain distinct.

`[output]` defaults to `num_print_cycles=1`, `num_dump_cycles=100`. Intervals count accepted steps separately and cumulatively in Z/U; rejected trials are not checkpoints. Zero disables periodic actions, not stage/final persistence. Restart retains accepted arrays, histories, cumulative counts and physical-input identity. Increasing budgets does not reset counts. Export failure has an explicit recovery path; ordinary continuation is not an implicit export retry.

## Operators, symmetry and migration

### Task-derived selection and canonical union

The task selection denotes required mathematical operators, not permission to run a response during Wannierization. Resolve the requested task/method pairs through the current Core registry and form one deterministic source/operator union. Unsupported requests and missing source data remain errors.

### Complete supported task dependencies

The executable dependency inventory is [`Core/OperatorTaskRequirements.jl`](../src/Core/OperatorTaskRequirements.jl), shared with Runtime consumption and checked against the live response registry. The archived expert guide is a historical reference, not an alternative current TOML namespace or an authority to accept missing operators.


H/r is the default output. `full` and `operator_tasks` are mutually exclusive; task requirements are unioned before native loading/generation, and do not run responses. Accepted native-generation products are validated and reused on continuation, never silently overwritten. A synthetic VASP full/task run is not an independent PAW oracle.

Projection handles its declared TB or Packed H/r inventory. Unsupported Packed operators are rejected, never dropped while claiming the full package was processed. SAWF operation selection requires a closed subgroup and persists parent numbering and representation identity. It does not unify workflow-specific symmetry detection.

The default embedded checkpoint wire is 3.0. Optional referenced storage uses wire 3.1 and an explicitly bound retained source root; see [normalized checkpoint storage](NORMALIZED_WANNIERIZATION_INPUT.md). Public readers require the current checkpoint format. Preserve original inputs and use the current writer to create a new checkpoint; incompatible stored state is rejected. See [checkpoint contracts](WANNIERIZATION_PLAN_MIGRATION.md).

## Human and structured reports

The native `.out` file contains solver progress, centers and spreads, final status and timing. Its `[VALIDATION]` section summarizes PASS, FAIL and unavailable check counts and groups repeated warning/error messages. A FAIL or unavailable result remains visible; successful execution does not turn it into a passing check.

The adjacent `.json` file retains every validation entry at full precision under `validation.checks`, with warning/error messages and contexts under `validation.warnings` and `validation.errors`. Optional final symmetry results, metric conventions, thresholds and recorded statuses remain under `validation.tb_symmetry`. The `.out` summary names this JSON file for detailed inspection; presentation rounding does not alter the JSON values.

When requested, `[TB SYMMETRY]` uses short check names, separate units and aligned Value/Limit/Status columns. A failed symmetry measurement and a nonconverged solver remain separate from execution or file-writing errors.

## Qualification

Tests distinguish entry/solve/save/restart contracts, mathematical checks and physical qualification. Native scalar SAWF and synthetic VASP fixtures do not qualify arbitrary spinor/PAW materials or every MPI layout. Validate the actual source data, requested operators and scientific convergence for each calculation.
