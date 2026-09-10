# wannierNLQG repository rules

These rules are mandatory for changes under this package. Read
`docs/ARCHITECTURE.md` for module ownership and `docs/DEVELOPMENT.md` for the
development and release workflow.

- Preserve formulas, units, summation order, output filenames, and output column
  layouts unless the task explicitly changes a physical contract.
- Dependencies must follow `Runtime -> Responses -> MatrixElements -> IO -> Core`,
  with the additional direct edges documented in `docs/ARCHITECTURE.md`. Never add
  an upward or cyclic dependency.
- File reading, cache serialization, and result writing belong in `IO`. Matrix
  construction belongs in `MatrixElements`. Response formulas belong in
  `Responses`. Configuration, MPI, paths, progress, and orchestration belong in
  `Runtime`.
- Core identifiers must use domain language, not author names or concrete software
  versions. Standard scientific terms such as Berry, Hall, Wilson, and Wannier are
  allowed. External protocol literals and upstream filenames may retain their
  original spelling only at the adapter boundary.
- Types and files use `PascalCase`; functions and variables use `snake_case`;
  constants use `SCREAMING_SNAKE_CASE`; mutating functions end in `!`.
- Cross-function fields must be descriptive. Compact formula symbols are allowed
  only as local variables in a short, documented formula kernel.
- The facade exports the grouped response configuration types and typed
  observable selectors, `RunResult`, and `run`, as frozen in the API snapshot.
  EffectiveTaskConfig and NormalizedTaskSpec are private Runtime details. Expert
  APIs are accessed through `WannierNLQG.Core`, `.IO`, and `.MatrixElements`.
- During implementation, run formatter/static checks and focused tests for the
  reachable Symmetrization, Wannierization, Response, Runtime, or tooling path. Do
  not rerun fast/full after every edit. Freeze the final evidence hashes first and
  run one final complete validation when runtime source or the test contract
  changed: Fast, every Full-only shard, and MPI-only. Individual Full-only
  shards do not include Fast. The local runner combines these without duplication.
- Reuse a sealed prior full PASS only when the dependency-aware runtime and test
  contract hashes are unchanged and the exact file diff is campaign-only. Rerun the
  affected campaign preflight, formatter, determinism, and manifest/SHA checks as
  required by reachability. If the diff cannot be closed, run one final `full`.
- Run exact baseline output comparisons, thread determinism, MPI smoke, and
  allocation checks in proportion to the touched layer. A behavior-preserving refactor requires
  `max_abs == 0.0`; do not waive a nonzero result as floating-point noise. Only an
  explicitly approved gauge-normalization change may use `atol=2e-12` and
  `rtol=2e-12` against the previous version; its new-version thread determinism
  must still satisfy `max_abs == 0.0`. The explicitly approved Geometric/Wilson
  loop algebra optimization campaign is a second, narrowly scoped exception: it
  may compare against its frozen formal baseline with `atol=1e-10`, `rtol=1e-8`,
  and the mixed elementwise error defined in `docs/DEVELOPMENT.md`. This exception
  does not apply to other response methods. Candidate thread-count and MPI-rank
  determinism still require `max_abs == 0.0`.
- Keep engineering tests, numerical validation, and physics or production
  qualification as separate evidence states. Unreachable historical campaign rows
  may be retained with an explicit reachability record; they must not be relabeled
  as measurements on the new runtime digest.
