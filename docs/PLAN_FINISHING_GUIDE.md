# Workflow templates and explicit API migration

The examples in `examples/text_input/{ordinary,sawf,projection,mesh}-{qe,vasp}.toml`
are complete configuration templates, not bundled material calculations. Supply the
native files from a single calculation, edit the species/projections and full grid,
and use `scripts/wanniernlqg.jl check INPUT.toml` before `run INPUT.toml --records DIR`.
Use a new output directory; preserve inputs and checkpoints. Ordinary external basic
matrices have a separate `wannierization-ordinary.toml` example. No template creates
or consumes a temporary WIN.

| Route | Input consumed | Numerical evidence |
|---|---|---|
| ordinary | native QE/VASP or explicit external EIG/MMN/AMN | normalized zero/nonzero stages and accepted-state continuation |
| SAWF | same-source native matrices and closed projection representation | native Z/U, zero steps, intermediate continuation, operation subgroup checks |
| projection | existing TB/packed model, structure and basis | existing H/r engineering comparisons; unsupported extra packed operators reject |
| mesh | native geometry/point metadata, no wavefunction requirement | closure/offset/minimum density fixtures; no synthetic completion of irreducible wavefunctions |

Templates are syntax/contract examples; executing one requires its actual input
files. QE UPF and VASP PAW data remain required where the native physical generator
needs them. VASP independent PAW parity with an external oracle is NOT established
by the synthetic fixtures. No default, dependency, MPI or release change is implied.

## Canonical low-level configuration

`WannierizationSolverConfig(stage_controls=WannierizationStageControls(...))` is
the current Julia interface. The six independent Z/U controls are its authority.
The removed `max_iterations`, `convergence_tolerance`, `convergence_window` and
`localize` constructor keywords are not aliases. Translate the intended Z and U
budgets explicitly: a single old total cannot uniquely determine two budgets.
`num_iter=0` skips U; both budgets zero still permit explicitly requested export.
Internal U fixed-Z and line-search safeguards remain.

Checkpoint and runtime constructors use `num_dump_cycles` (default100) and
`num_print_cycles` (default1). A value0 disables periodic actions, not final or
stage-boundary saves. Normalized TOML spelling and semantics are unchanged.
Old config files use the existing explicit input converter. Old checkpoint bytes
are never rewritten by this migration; the existing explicit checkpoint converter
preserves the original and rejects insufficient state. Current disk/report keys
and accepted-state identity remain separate from these Julia field names.

## Evidence boundary

Tests of these templates establish their declared input and execution contracts;
they do not independently qualify a material or an untested native-data combination.

QE full includes spin operators and therefore requires actual noncollinear spinor coefficients. Scalar input is rejected by QE_PAW_SPN_SPINOR_REQUIRED; that rejection is not a full-output PASS. Orbital-only tasks do not silently request spin. The dedicated spinor engineering fixture validates the supported full branch, not independent material accuracy.
