# Precompilation, extension preparation, and cache rebuilding

This guide applies to WannierNLQG 1.2.0. Run the commands from the package root containing `Project.toml` and `Manifest.toml`, not from `docs/`. Commands use a POSIX shell (macOS/Linux). They prepare software caches; they do not run a material calculation or establish numerical, physical, solver-quality, or production qualification.

## 1. Environment and complete package precompilation

Use an installed Julia satisfying [Project.toml](../Project.toml): Julia 1.10, 1.11, or exactly 1.13.0. The shipped [Manifest.toml](../Manifest.toml) records Julia 1.13.0. Historical first-use fixtures were captured with Julia 1.11.2; they do not establish timing on the current package or another Julia build. Check the chosen executable with `julia --version`. See the [contributor guide](DEVELOPMENT.md) for the current workflow. The maintained implementation uses real, small public-API workloads captured by PrecompileTools and a small residual declaration layer. It no longer loads the historical generated trace-signature files. Version compatibility alone does not qualify first-call performance on another Julia build. Ensure the depot is writable and enough disk/RAM is available. Initial dependency and artifact acquisition may require network access and working MPI/HDF5 binary artifacts. Do not change or resolve the shipped Manifest merely to rebuild caches.

Prepare dependencies and then explicitly precompile the active package environment:

```sh
JULIA_PKG_PRECOMPILE_AUTO=0 julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
julia --startup-file=no --project=. -e 'using Pkg; Pkg.precompile(; strict=true, timing=true)'
```

`instantiate` installs the environment recorded by the Manifest. It normally can also trigger automatic precompilation; the first command disables that automatic step for that process so the second command reports it explicitly. `precompile` also instantiates if necessary, schedules the project/dependency and eligible extension caches, and reuses valid existing caches. It is not a force-rebuild command. `strict=true` reports dependency precompilation errors as failures; `timing=true` reports build timing. Start a new process to check ordinary loading:

```sh
julia --startup-file=no --project=. -e 'using WannierNLQG; println("WannierNLQG loaded")'
```

The parent executes small deterministic public tasks during precompilation. Representative families cover shared response, geometry, spectral and band-path call trees. Additional Mixed FFT and TOML-input workloads address measured residuals. Eligible extension owners capture their supported small workloads and persistence readers. Composite SF + W, symmetrization and PAW maintenance helpers remain lazy in standard package precompilation; their cross-extension calculations execute only when explicitly requested. Workload temporary outputs are cleaned automatically; package precompilation does not launch `mpiexec`. See [the maintained architecture](DEVELOPMENT.md) for the coverage rationale and residual policy.

Automatic Band geometry has representative 3D and explicit-plane planning in the symmetry image. The same three-trigger image additionally exercises actual TOML resolution and public Band execution with a Hermitian two-band, three-R synthetic model. One input supplies endpoint-inclusive counts; the other omits them and uses the ordinary Cartesian-density default. Its larger synthetic cell keeps the default path small. These are compiler workloads, not material models or first-use timing evidence; extension activation and fresh automatic-path calls still require measurement.

These workloads do not cover every possible model, type or execution mode. A later first call can still compile or recompile. `using WannierNLQG` alone is not a check that every expert extension is active. MPI launcher startup, communicator initialization and external library initialization require separate runtime measurements.

## 2. Prepare the extensions needed by the workflow

The trigger matrix below is taken directly from `[extensions]` in [Project.toml](../Project.toml). These trigger packages are currently declared in `[deps]`; “optional” here describes activation and use, not an instruction to add new packages or edit the project.

| Extension | All required trigger packages |
| --- | --- |
| `WannierNLQGOperatorBundleExt` | `MPI`, `HDF5`, `JSON3` |
| `WannierNLQGSymmetryFoundationExt` | `Spglib`, `HDF5`, `JSON3` |
| `WannierNLQGSymmetrizationExt` | `HDF5`, `JSON3`, `EzXML` |
| `WannierNLQGWannierizationExt` | `MPI`, `HDF5`, `JSON3`, `EzXML` |
| `WannierNLQGWannierizationPrecompileExt` | `MPI`, `HDF5`, `JSON3`, `EzXML`, `Spglib` |

Public expert calls activate their owned extensions lazily. The loading behavior is implemented in the [Foundation loader](../src/SymmetryFoundation/SymmetryFoundationExtensionLoading.jl), [Symmetrization loader](../src/Symmetrization/SymmetrizationExtensionLoading.jl), and [Wannierization loader](../src/Wannierization/WannierizationExtensionLoading.jl). For preparation without running an expert solver, use Julia's public package imports and `Base.get_extension` to load the required triggers and check activation. For example, prepare the Wannierization extension:

```sh
julia --startup-file=no --project=. -e 'using WannierNLQG, MPI, HDF5, JSON3, EzXML; @assert Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt) !== nothing; println("Wannierization extension active")'
```

If the intended workflow needs every extension in the current matrix, explicitly load the union and check each declared extension:

```sh
julia --startup-file=no --project=. -e 'using WannierNLQG, MPI, HDF5, JSON3, EzXML, Spglib; for name in (:WannierNLQGOperatorBundleExt, :WannierNLQGSymmetryFoundationExt, :WannierNLQGSymmetrizationExt, :WannierNLQGWannierizationExt, :WannierNLQGWannierizationPrecompileExt); @assert Base.get_extension(WannierNLQG, name) !== nothing name; println(name, " active"); end'
```

This is an explicit trigger-import/activation check, not a new WannierNLQG “precompile all modules” API. Loading may create a missing cache or perform JIT work. It does not initialize an MPI communicator via `MPI.Init`, run a solver, or measure first-call coverage. An overlapping trigger set may activate additional extensions; it does not isolate one internal module. There is no public `--module` or `--modules` precompile selector. `Core`, `IO`, `MatrixElements`, `Responses` and `Runtime` are submodules of one parent package, not independent Pkg precompile targets. `Pkg.build` is a separate dependency build-hook operation, not a substitute for `Pkg.precompile` or cold-call qualification.

## 3. Keep ordinary workload defaults enabled

The default PrecompileTools workload policy is enabled. Its implementation reads both the global `precompile_workloads` preference for PrecompileTools and the parent package's `precompile_workload` preference. For clarity, their local preference forms are:

```toml
[PrecompileTools]
precompile_workloads = false

[WannierNLQG]
precompile_workload = false
```

These are disabling examples, not recommended user configuration. Do not paste them into the normal environment. The first disables PrecompileTools workloads across packages that consult that global policy; the second disables this package's guarded first-use coverage, including extensions. Neither switches ordinary Julia package caching off or selects an internal module. Existing preferences, including inherited preferences, should be inspected before a rebuild.

The maintenance workflow deliberately uses the first setting only in an independent diagnostic source/environment to observe compilation with workloads off. Keep the normal source and its preferences separate. After changing preferences, use a new Julia process and precompile again; Julia tracks consumed compile-time preferences when validating caches. Removing a disabling setting restores the default only if no other applicable preference still disables it.

## 4. Rebuild safely with an isolated depot

A Julia build/version, platform/CPU target, dependency/Manifest, package source, compile-time preference or compilation-option change can invalidate cache reuse. Julia checks cache compatibility automatically. For a reproducible rebuild or to isolate a suspected stale-cache problem, use a newly created writable depot rather than deleting the existing user depot. The following subshell preserves the caller's environment and retains the new directory afterward:

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

The trailing `:` in Julia 1.11 expands the bundled system depot entries while excluding the default user depot when a nonempty first depot is specified. Windows uses `;` as its depot separator and needs equivalent PowerShell syntax. The fresh directory is empty initially: this command has no old user-depot fallback for package caches, package sources or artifacts. Bundled system caches remain available, so “fresh” here means fresh external package/dependency caches, not rebuilding Julia or its bundled standard libraries. Downloads, dependency precompilation and extension workloads can be expensive; a temporary depot also may later be removed by the operating system. Keep the printed path if you want to reuse it, or choose a new persistent external directory instead. Do not place the depot inside the release package.

To reuse the new cache for another shell command, set `JULIA_DEPOT_PATH` to that printed path plus `:` before launching Julia. Run section 2's extension preparation commands with the same depot if needed. Run them within the subshell above, or export that depot in a separate subshell; leaving it loses the temporary environment selection, not the directory's cache files.

A layered path such as `NEW_DEPOT:EXISTING_DEPOT:` writes new caches to the first layer but can reuse valid compiled caches, sources and artifacts from the existing layer. It is useful for a light preparation, but is not a strictly fresh external cache measurement. Making the fallback read-only does not prevent reads or cache reuse. A truly fresh comparison must exclude fallback layers containing the old compiled caches. This guide performs no cache deletion; retain the previous depot for rollback and do not recursively clear the user depot.

## 5. Scope of precompile evidence

The public package contains representative compiler workloads and contributor tests. It does not ship private timing campaigns or trace-collection tools. Historical synthetic first-use fixtures remain numerical references; their recorded versions and qualifications do not transfer to a changed package. See the [contributor guide](DEVELOPMENT.md) and [numerical infrastructure](NUMERICAL_INFRASTRUCTURE.md).

An explicit strict precompile verifies that the cache build completes. A fresh process must still check loading and the first call required by a workflow. Timing depends on the Julia build, platform, source, depot and exact inputs. Successful cache construction does not establish numerical or material qualification, or a universal first-call latency promise.

## Release timing acceptance

For the current 1.2.0 release, the original 0.5-second compilation threshold applies to the ordinary registered calculation paths. PAW expert first-call timings are recorded together with functional verification; exceeding that threshold does not block promotion. Installation, numerical correctness and resource/safety checks remain required. Historical expert timing failures keep their original status and source identity.

## Current finite-metric spectral capture and supported path inventory

The existing native-metric workload additionally enters Conventional LT/LOR and finite-model OM through the existing public spectral task builder. The existing SC/SHG Direct/Mixed workloads capture the optional cutoff optical source jet. No scientific formula or normal-input default changes here; compiler coverage needs independent fresh-process verification after the strict package build.

The current supported ordinary timing inventory has 59 paths. Geometric Loop QHC remains an unsupported-error case, not a successful timed calculation. The existing two-sample protocol and 0.5-second ordinary compilation gate remain unchanged. PAW expert timing is informational with functional validation, under the separate user decision. Earlier 55- and 56-path inventories retain their historical scope and do not qualify the current inventory.


## Optional local system-image build

This advanced workflow is optional. Use the normal installation above first; ordinary calculations do not require PackageCompiler. The currently exercised configuration is macOS arm64, Julia 1.13.0, PackageCompiler 2.4.4, native CPU, and explicit matching system MPI/HDF5 libraries. The package's Julia compatibility range is unchanged. Other platforms, runtimes, artifact-default native profiles and cross-machine images have not been qualified by this build profile.

### Prepare the compiler environment

The builder's help works without PackageCompiler:

```sh
julia --startup-file=no scripts/build_sysimage.jl --help
```

Keep compiler tooling separate from both the source project and ordinary consumer environments. If an existing environment already provides PackageCompiler 2.4.4, use it. Otherwise, the following is an explicit user installation step, requiring locally available packages or network access; the builder never performs it:

```sh
julia --startup-file=no -e 'using Pkg; Pkg.activate("/absolute/new-compiler-environment"); Pkg.add(PackageSpec(name="PackageCompiler", version="2.4.4")); Pkg.precompile(; strict=true)'
julia --startup-file=no --project=/absolute/new-compiler-environment -e 'using PackageCompiler; @assert Base.pkgversion(PackageCompiler) == v"2.4.4"'
```

Retain that environment's Project and Manifest. The builder checks its tool and Julia versions explicitly. It does not add the tool as a runtime dependency, resolve versions, or modify the source Project/Manifest.

### Select matching native libraries

Prepare an explicit preferences file outside the source. The following is the configuration shape used by the tested macOS arm64 profile. Replace every absolute path with the actual installed matching file; these versioned paths are an example, not an instruction to install or upgrade software:

```toml
[MPIPreferences]
_format = "1.0"
binary = "system"
abi = "OpenMPI"
libmpi = "/opt/homebrew/Cellar/open-mpi/5.0.9_1/lib/libmpi.40.dylib"
mpiexec = "/opt/homebrew/Cellar/open-mpi/5.0.9_1/bin/mpirun"
preloads = []

[HDF5]
libhdf5 = "/opt/homebrew/Cellar/hdf5-mpi/2.2.0/lib/libhdf5.320.2.0.dylib"
libhdf5_hl = "/opt/homebrew/Cellar/hdf5-mpi/2.2.0/lib/libhdf5_hl.320.0.3.dylib"

[FFTW]
provider = "fftw"
```

Use the base and high-level HDF5 libraries from the same installation, compiled against the selected MPI ABI. A correct-looking filename does not establish ABI compatibility. Check files before building, and check actual bindings in new serial and MPI processes afterward. An image built with one profile cannot be used to prove another profile works. Do not mix an artifact base HDF5 library with a different system high-level library.

### Build in a new output directory

Finish all source and documentation edits before building: the image is bound to the complete source inventory, including the README. Prepare the ordinary locked dependencies first. From the package root:

```sh
JULIA_NUM_THREADS=1 JULIA_NUM_GC_THREADS=1,0 JULIA_IMAGE_THREADS=1 \
JULIA_NUM_PRECOMPILE_TASKS=1 JULIA_PKG_OFFLINE=true \
julia --startup-file=no --project=/absolute/new-compiler-environment \
  scripts/build_sysimage.jl "$PWD" /absolute/new-image-directory \
  /absolute/LocalPreferences.toml
```

The output directory must not exist. The builder creates a separate consumer environment containing the source's locked dependencies and explicit preferences. The compiler calls `Pkg.instantiate` on that isolated environment, but parent and children remain offline: only already available locked packages and artifacts can be reused. Missing packages must be prepared explicitly before retrying; the builder does not download or install them automatically. It preserves failed partial output; choose a new directory for a retry.

All direct dependencies remain explicit image roots; actually imported transitive dependencies load normally. Unused native backends are not forced into the image. The writer enters a small synthetic public task and checks source identity and an empty MPI handle. It does not launch MPI ranks, save a live communicator, or establish material or numerical qualification. `image.toml` records source, Julia binary, native CPU/platform, dependency lock, preferences and library file identities. Build success alone does not validate startup, ABI or performance.

### Use the checked launcher

For a serial Band smoke run, use the launcher rather than a bare `-J`:

```sh
julia --startup-file=no --project=. scripts/run_with_sysimage.jl \
  /absolute/new-image-directory /absolute/LocalPreferences.toml \
  run examples/text_input/band-column-nodes.toml --records /absolute/new-image-band-records
```

Expected output and the Band table are as in the README's ordinary example. To exercise distributed use, select an input supporting MPI and start the same launcher with the MPI executable matching the preferences, for example two ranks:

```sh
/absolute/matching/mpirun -n 2 julia --startup-file=no --project=. \
  scripts/run_with_sysimage.jl /absolute/new-image-directory \
  /absolute/LocalPreferences.toml run /absolute/mpi-enabled-input.toml \
  --records /absolute/new-mpi-records
```

The selected MPI input and its ownership must support that rank count. Do not infer distributed correctness from the serial Band example. Validate representative serial and actual MPI runs with the final source and preferences.

The launcher rejects changed source paths or bytes, Julia binaries, CPUs, native files, preferences, build environments and incomplete image files. Correct the specific mismatch and rebuild; it never silently accepts an old image, installs software or loosens a check. Moving the source or changing documentation also requires a rebuild. Retain the previous image for rollback, with its own identity. Direct `-J` bypasses these cold provenance checks. The checked launcher reads the image and source before starting a new process; include both processes and that work in end-to-end startup timing. Neither image use nor successful precompilation is a universal first-call latency promise.
