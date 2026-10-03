# Precompilation, extension preparation, and cache rebuilding

This guide applies to the locally maintained WannierNLQG 1.1.1 package.
Run the commands from the package root containing `Project.toml` and
`Manifest.toml`, not from `docs/`. Commands use a POSIX shell (macOS/Linux).
They prepare software caches; they do not run a material calculation or establish
numerical, physical, solver-quality, or production qualification.

## 1. Environment and complete package precompilation

Use an installed Julia satisfying [Project.toml](../Project.toml) (`julia = "1.10"`,
which admits compatible Julia 1.x versions). The shipped
[Manifest.toml](../Manifest.toml) records Julia 1.10.12. The frozen first-use
fixture and attribution campaign used Julia 1.11.2, as recorded in
[first-use maintenance](FIRST_USE_PRECOMPILE_MAINTENANCE.md). Those are different
identities: compatibility does not transfer a cache or timing qualification
between Julia builds. Check the chosen executable with `julia --version`.
Captured compiler declarations and anonymous bindings are now evaluated only
on their originating Julia 1.11.2 version. Other supported versions retain the
portable bounded matrix/configuration workloads and normal JIT compilation;
their first-call timings are not covered by the frozen trace evidence. This
compatibility guard revision has not been run or precompiled on any version.
Ensure the depot is writable and enough disk/RAM is available. Initial dependency
and artifact acquisition may require network access and working MPI/HDF5 binary
artifacts. Do not change or resolve the shipped Manifest merely to rebuild caches.

Prepare dependencies and then explicitly precompile the active package environment:

```sh
JULIA_PKG_PRECOMPILE_AUTO=0 julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
julia --startup-file=no --project=. -e 'using Pkg; Pkg.precompile(; strict=true, timing=true)'
```

`instantiate` installs the environment recorded by the Manifest. It normally can
also trigger automatic precompilation; the first command disables that automatic
step for that process so the second command reports it explicitly. `precompile`
also instantiates if necessary, schedules the project/dependency and eligible
extension caches, and reuses valid existing caches. It is not a force-rebuild
command. `strict=true` reports dependency precompilation errors as failures;
`timing=true` reports build timing. Start a new process to check ordinary loading:

```sh
julia --startup-file=no --project=. -e 'using WannierNLQG; println("WannierNLQG loaded")'
```

The parent includes bounded PrecompileTools workloads and compiler declarations.
They cover selected matrix assembly, configuration and expert signatures;
precompilation does not compile every possible type/parameter specialization.
A later first call may still compile or recompile. `using WannierNLQG` alone
is not a check that every expert extension is active.

The internal `WannierNLQG.FIRST_USE_TRACE_COMPATIBLE` flag reports whether the
running version matches the captured trace. It does not report successful cache
creation, runtime compatibility, or scientific qualification.

## 2. Prepare the extensions needed by the workflow

The trigger matrix below is taken directly from `[extensions]` in
[Project.toml](../Project.toml). These trigger packages are currently declared
in `[deps]`; “optional” here describes activation and use, not an instruction to
add new packages or edit the project.

| Extension | All required trigger packages |
| --- | --- |
| `WannierNLQGOperatorBundleExt` | `MPI`, `HDF5`, `JSON3` |
| `WannierNLQGSymmetryFoundationExt` | `Spglib`, `HDF5`, `JSON3` |
| `WannierNLQGSymmetrizationExt` | `HDF5`, `JSON3`, `EzXML` |
| `WannierNLQGWannierizationExt` | `MPI`, `HDF5`, `JSON3`, `EzXML` |
| `WannierNLQGWannierizationPrecompileExt` | `MPI`, `HDF5`, `JSON3`, `EzXML`, `Spglib` |

Public expert calls activate their owned extensions lazily. The loading behavior
is implemented in the [Foundation loader](../src/SymmetryFoundation/SymmetryFoundationExtensionLoading.jl),
[Symmetrization loader](../src/Symmetrization/SymmetrizationExtensionLoading.jl), and
[Wannierization loader](../src/Wannierization/WannierizationExtensionLoading.jl).
For preparation without running an expert solver, use Julia's public package
imports and `Base.get_extension` to load the required triggers and check activation.
For example, prepare the Wannierization extension:

```sh
julia --startup-file=no --project=. -e 'using WannierNLQG, MPI, HDF5, JSON3, EzXML; @assert Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt) !== nothing; println("Wannierization extension active")'
```

If the intended workflow needs every extension in the current matrix, explicitly
load the union and check each declared extension:

```sh
julia --startup-file=no --project=. -e 'using WannierNLQG, MPI, HDF5, JSON3, EzXML, Spglib; for name in (:WannierNLQGOperatorBundleExt, :WannierNLQGSymmetryFoundationExt, :WannierNLQGSymmetrizationExt, :WannierNLQGWannierizationExt, :WannierNLQGWannierizationPrecompileExt); @assert Base.get_extension(WannierNLQG, name) !== nothing name; println(name, " active"); end'
```

This is an explicit trigger-import/activation check, not a new WannierNLQG
“precompile all modules” API. Loading may create a missing cache or perform JIT
work. It does not initialize an MPI communicator via `MPI.Init`, run a solver,
or measure first-call coverage. An overlapping trigger set may activate additional
extensions; it does not isolate one internal module. There is no public
`--module` or `--modules` precompile selector. `Core`, `IO`, `MatrixElements`,
`Responses` and `Runtime` are submodules of one parent package, not independent
Pkg precompile targets. `Pkg.build` is a separate dependency build-hook operation,
not a substitute for `Pkg.precompile` or cold-call qualification.

## 3. Keep ordinary workload defaults enabled

The default PrecompileTools workload policy is enabled. Its implementation reads
both the global `precompile_workloads` preference for PrecompileTools and the
parent package's `precompile_workload` preference. For clarity, their local
preference forms are:

```toml
[PrecompileTools]
precompile_workloads = false

[WannierNLQG]
precompile_workload = false
```

These are disabling examples, not recommended user configuration. Do not paste
them into the normal environment. The first disables PrecompileTools workloads
across packages that consult that global policy; the second disables this
package's guarded first-use coverage, including extensions. Neither switches
ordinary Julia package caching off or selects an internal module. Existing
preferences, including inherited preferences, should be inspected before a rebuild.

The maintenance workflow deliberately uses the first setting only in an
independent diagnostic source/environment to observe compilation with workloads
off. Keep the normal source and its preferences separate. After changing
preferences, use a new Julia process and precompile again; Julia tracks consumed
compile-time preferences when validating caches. Removing a disabling setting
restores the default only if no other applicable preference still disables it.

## 4. Rebuild safely with an isolated depot

A Julia build/version, platform/CPU target, dependency/Manifest, package source,
compile-time preference or compilation-option change can invalidate cache reuse.
Julia checks cache compatibility automatically. For a reproducible rebuild or to
isolate a suspected stale-cache problem, use a newly created writable depot
rather than deleting the existing user depot. The following subshell preserves
the caller's environment and retains the new directory afterward:

```sh
(
  wnlqg_fresh_depot=$(mktemp -d "${TMPDIR:-/tmp}/wanniernlqg-depot.XXXXXX") || exit 1
  export JULIA_DEPOT_PATH="$wnlqg_fresh_depot:"
  export JULIA_PKG_PRECOMPILE_AUTO=0
  printf 'New depot: %s\n' "$wnlqg_fresh_depot"
  julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()' &&
  julia --startup-file=no --project=. -e 'using Pkg; Pkg.precompile(; strict=true, timing=true)'
)
```

The trailing `:` in Julia 1.11 expands the bundled system depot entries while
excluding the default user depot when a nonempty first depot is specified.
Windows uses `;` as its depot separator and needs equivalent PowerShell syntax.
The fresh directory is empty initially: this command has no old user-depot
fallback for package caches, package sources or artifacts. Bundled system caches
remain available, so “fresh” here means fresh external package/dependency caches,
not rebuilding Julia or its bundled standard libraries. Downloads, dependency
precompilation and extension workloads can be expensive; a temporary depot also
may later be removed by the operating system. Keep the printed path if you want
to reuse it, or choose a new persistent external directory instead. Do not place
the depot inside the release package.

To reuse the new cache for another shell command, set `JULIA_DEPOT_PATH` to that
printed path plus `:` before launching Julia. Run section 2's extension preparation
commands with the same depot if needed. Run them within the subshell above, or
export that depot in a separate subshell; leaving it loses the temporary environment
selection, not the directory's cache files.

A layered path such as `NEW_DEPOT:EXISTING_DEPOT:` writes new caches to the first
layer but can reuse valid compiled caches, sources and artifacts from the existing
layer. It is useful for a light preparation, but is not a strictly fresh external
cache measurement. Making the fallback read-only does not prevent reads or cache
reuse. A truly fresh comparison must exclude fallback layers containing the old
compiled caches. This guide performs no cache deletion; retain the previous depot
for rollback and do not recursively clear the user depot.

## 5. What maintenance and timing tools establish

See [First-use precompile maintenance](FIRST_USE_PRECOMPILE_MAINTENANCE.md) for
source trace recapture, signature regeneration/attribution, portable fixtures,
and cold/scientific acceptance. `collect_traces.py`, `collect_expert_traces.py`
and `audit_signatures.jl --write|--check` are source-maintenance tools.
`campaign.py`, `expert_campaign.py`, `source_supplements.py` and
`localization_campaign.py` measure or qualify declared scenes. Their `--cases`
option, where provided, selects diagnostics or acceptance scenes, not modules to
precompile; partial runs do not establish the complete gate.

The campaign's 0.5-second first-call compile threshold belongs to its frozen
Julia/platform/source/depot/fixture contract. It is not a universal latency
promise, a package-build duration limit, or evidence that every machine will
meet it. A successful package cache build and extension activation check do not
replace measured cold first-call tests or qualify new scientific inputs.
