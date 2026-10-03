---
name: wanniernlqg-development-runner
description: Default local WannierNLQG development execution for Full, MPI, cold-call and source-audit tasks, including ordinary short development requests, status and recovery. Use the bundled common runner without a parent workspace.
---

# Package development runner

Find the package root containing Project.toml, AGENTS.md and scripts/development_runner.py.
Read package AGENTS and docs/DEVELOPMENT.md. The entrypoint is
`python3 scripts/development_runner.py`; its sole core implementation is
`scripts/development/common_runner` inside this package. Do not search for another
workspace, global skill or guardian. All code and this skill ship with the source.

Within an authorized ordinary development task, the agent prepares explicit argv,
cwd, complete environment, pinned source/input/reference identity, typed output
contract and limits. The user need not prepare a complex prompt or JSON files.
Use `full`, `mpi`, `cold`, `source-audit` according to the requested task.
Full builds seven selections and passes --owned-group; other actions require their
exact matching typed contract. Unsupported scientific schemas must be reported or
explicitly extended and tested, never downgraded to exit0 or generic PASS.

Queries use status/reconcile; resume only advances eligible never-started stages.
Do not resubmit for a status request or rerun successful stages. Missing real exit
is UNKNOWN. The supported contract is foreground_owned_group, with three RSS
readings, host Swapouts increase guard and 10 GiB disk floor. CPU/thread settings
are explicit; sampled RSS is not a high-water peak. Complete kernel containment
remains UNKNOWN. Engineering fixtures do not qualify numerical/physics/production.

For tool-only checks use the bundled smoke.py with a new output directory outside
the package; it uses seconds-scale Python simulation and no Julia/MPI science.
Keep depots, requests, caches and all evidence outside the package and versioned
source. Preserve earlier failures and unrelated modifications. Read --help and
the bundled README for precise CLI/API and supported adapter boundaries.
