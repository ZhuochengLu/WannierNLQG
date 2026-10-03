# Bundled common development runner

This directory is the single canonical implementation. It ships with the complete
WannierNLQG source package; no parent workspace, global skill, installation or
service is required. The package entrypoint is `scripts/development_runner.py`.
Repository `Code/development/common-runner` modules only forward to this source;
they contain no second implementation. The launcher checks seven core hashes and
the integration hash in `scripts/development_runner_identity.json` before use.
After an authorized implementation change, update those pins and the release
inventories together. Never update pins to hide a mismatch in a retained run.

See [the package development guide](../../../docs/DEVELOPMENT.md) for four typed
entrypoints. Full constructs seven task selections and an inherited process group;
MPI/cold/source-audit require a matching qualification contract, explicit argv,
complete env and native/source reference inputs. Exit0 alone is not scientific
PASS. The default limits guard three consecutive RSS-over-limit observations,
any increase in host Swapouts and a 10 GiB disk floor. CPU is a declared budget
implemented in argv/thread settings. RSS is sampled, not an OS high-water mark.

Run `python3 scripts/development/common_runner/smoke.py --output-dir /absolute/new/evidence`
from the package root for seconds-only Python engineering fixtures. It exercises
all four actual typed entrypoints plus raw core failure/recovery paths; it never
executes Julia/MPI or attributes simulated receipts to scientific measurements.
Use a new external directory. All attempts remain there. Host resource sensing
is required and errors fail closed.

Core API: put this directory on sys.path; call `runner.submit(spec, runs_root)`,
`runner.reconcile(run_directory)`, `runner.resume(run_directory)` and
`adapters.qualify(run_directory)`. Requests use `nlqg.local-run/1`, explicit
foreground_owned_group, unique run_id, absolute executable/cwd, complete env,
input hashes, output names and limits. Multi-stage prerequisites need explicit
completion gates and final matching typed qualification in the package submit
entrypoint. Downstream stages do not run after a gate failure.

The independent controller/waiter/monitor persist PID/start/PGID, logs, incremental
resources, real waitpid exit and an atomic final receipt. Same-ID same-spec submit
is idempotent. status is read-only; reconcile can rebuild the final receipt only
from valid sealed original evidence; missing exit is UNKNOWN. resume advances
never-started pending stages and does not rerun failed/ambiguous/completed stages.
Input/tool/output tampering is rejected. No arbitrary PID cancellation or importing
foreign processes exists. Signals use owned start identities and verified ancestry.

Supported contract: foreground tasks that retain their group and wait for children.
Observed daemon/PGID escapes fail; unobserved fast reparent escape cannot be ruled
out on macOS. Kernel complete-tree containment remains UNKNOWN. Linux code exists
but execution is not independently qualified. Simultaneous waiter/monitor loss,
power loss, instantaneous RSS spikes and disk exhaustion cannot yield invented
PASS or guessed exits. Evidence is retained; a repeat check is explicit, never automatic.

The last sentence means an explicit new request is required to repeat a failed
or ambiguous stage. These engineering limits do not change package science,
solver-quality or production qualification.

`package_release.py` assembles a deterministic source zip strictly from the
verified positive SOURCE_MANIFEST plus SHA256SUMS/SOURCE_MANIFEST. It excludes
Git metadata and requires output outside the package. Repeated builds must have
identical archive hashes. No publication is performed.

## Typed request examples

Full uses the package guide's `full` command and constructs its seven task gates.
For the other families, save an argv JSON array, an output-name JSON array and
one qualification JSON object, then invoke this from the package root:

```sh
python3 scripts/development_runner.py mpi --run-id mpi001 --runs-root /absolute/runs --request-out /absolute/mpi001.request.json --argv-json /absolute/argv.json --cwd /absolute/work --env-json /absolute/env.json --outputs-json /absolute/outputs.json --qualification-json /absolute/qualification.json --cpu-budget 2 --timeout 60 --input /absolute/reference.dat
```

Replace `mpi` with `cold` or `source-audit` as appropriate. Use absolute real paths,
complete environment values and explicit thread settings. `--input` may repeat.
Reference/certificate files must exist before submission; the integration pins
these files plus the complete current package inventory. Qualification paths below
are relative to the stage directory unless absolute. Replace every placeholder;
these examples describe contracts, not scientific observations.

MPI requires one native first-call receipt per rank, the expected backend/library
and thread state, and output comparison pairs. The `outputs.json` array must include
all rank receipts and native output files. Example `qualification.json`:

```json
{
  "kind": "mpi",
  "source_manifest": "/absolute/package/SOURCE_MANIFEST.tsv",
  "source_manifest_sha256": "CURRENT_MANIFEST_SHA256",
  "package_root": "/absolute/package",
  "rank_files": ["rank_0.json", "rank_1.json"],
  "rank_count": 2,
  "path": "EXPECTED_MEASURED_PATH",
  "compile_limit_seconds": 0.5,
  "mpi_library_contains": ["EXPECTED_MPI_LIBRARY"],
  "julia_version": "EXPECTED_JULIA_VERSION",
  "task_labels": ["EXPECTED_TASK"],
  "output_inventory": {"0": ["native.dat"], "1": ["native.dat"]},
  "science_pairs": [{"actual": "native.dat", "reference": "/absolute/reference.dat", "format": "bytes"}]
}
```

Cold-call qualification compares a retained native first-call receipt with an
independent reference, including return payload and requested semantic fields:

```json
{
  "kind": "cold",
  "source_manifest": "/absolute/package/SOURCE_MANIFEST.tsv",
  "source_manifest_sha256": "CURRENT_MANIFEST_SHA256",
  "package_root": "/absolute/package",
  "receipt": "cold.json",
  "reference": "/absolute/reference.json",
  "contract": {
    "required_absent_backends": ["WannierNLQGWannierizationPrecompileExt", "WannierNLQGWannierizationExt", "WannierNLQGOperatorBundleExt", "WannierNLQGSymmetryFoundationExt", "WannierNLQGSymmetrizationExt"],
    "excluded_return_fields": [],
    "native_kind": "reader",
    "compile_limit_seconds": 0.5,
    "compare_semantic_return": true,
    "ignored_json_top_level_metadata": []
  },
  "science_pairs": [{"actual": "cold.json", "reference": "/absolute/reference.json", "format": "native_return"}]
}
```

Select the actual required absent backends and native kind for the task; the
example does not authorize omitting other required backend checks. Source audit
requires separately retained preflight/write/check records, provenance TSVs and
an independently established source-equivalence certificate:

```json
{
  "kind": "source_audit",
  "source_manifest": "/absolute/package/SOURCE_MANIFEST.tsv",
  "source_manifest_sha256": "CURRENT_MANIFEST_SHA256",
  "source_root": "/absolute/package",
  "source_sha256": "EXPECTED_SOURCE_SHA256",
  "certificate_file": "/absolute/certificate.json",
  "certificate_sha256": "EXPECTED_CERTIFICATE_SHA256",
  "preflight": "preflight.json",
  "write": "write.json",
  "check": "check.json",
  "write_tsv": "write.tsv",
  "check_tsv": "check.tsv",
  "expected_counts": {"retained": 2, "legacy_retained": 1, "additional_retained": 1, "additional_actual_type_sources": 1}
}
```

Use measured expected counts, not the illustrative numbers. The executable
[smoke fixtures](smoke.py) generate complete synthetic contracts and matching
native-shaped receipts for all four families in the requested evidence directory.
They are engineering examples only. Adapter field checks are implemented in
[adapters.py](adapters.py); review a real task's native receipt against those
checks before migrating its producer. Query with `status`, rebuild sealed evidence
with `reconcile`, advance pending stages with `resume`, then call `qualify`.

## Explicit local OpenMPI ownership

The optional `--mpi-ownership-json PATH` selects `foreground_owned_mpi`. It composes
with the exact pinned CI scheduler self-test exception, without accepting arbitrary
process groups. Its `local_openmpi/1` policy contains resolved SHA-pinned `launcher`
(`mpirun`), PRTE `runtime`, all non-Apple mandatory
linked `runtime_inputs` and an exact `applications` rank-argv catalogue with allowed
rank counts. Each variable argument must be an absolute path under its declared
`path_under` root. Relative existing scripts/inputs must also be pinned.

Only single-program `-n/-np N` launches, optionally `--bind-to none`, are supported.
Ranks must be direct children of the observed pinned embedded PRTE launcher, in the
original task session, with valid local/world rank metadata and exact launcher-bound
argv. Fork/exec transitions have a 0.5 second bound. A different session, new rank
child group, unowned/reused identity, remote allocation or runtime/loader/MCA override
is rejected. Active user/site MCA parameter files are unsupported; they are only read.
Detached/persistent PRTE daemons, remote nodes, MPI dynamic spawn/MPI-in-MPI launch,
multiple app contexts and complete kernel containment are not supported. Local embedded
PRTE uses no separate daemon; its launcher and all observed rank groups are tracked.

Waiter and monitor both prove the groups; retained observed identities contribute to
sampled RSS even after reparenting and receive only identity-checked individual signals.
The sealed `mpi_terminal.json` records every observed rank/launcher identity and cleanup.
The root's actual waitpid exit remains authoritative. Rank and nested launcher exit codes
are explicitly NOT_OBSERVED_BY_CORE; disappearance is never presented as a wait status.
Residual ranks or missing process terminal fail closed. No receipt survives source/input
tampering; absent actual waiter exit remains UNKNOWN. Linux MPI contract is rejected
until qualified; current validation is Darwin OpenMPI5.0.9/PRTE4.1 only.

For Full, preserve the seven-task scheduler argv and its CI policy; pass this additional
MPI catalogue. Capture exact Base.julia_cmd().exec under the actual MPI-only parent's
Julia flags, and derive literal scripts/rank counts from the current pinned test source.
An integration helper is delivered alongside the patch for this closure; no scientific
commands run while preparing it. Keep the scheduler's per-task TMPDIR owned and bind
variable paths to that root. Use CPU17 for the declared Full16-rank closure; MPI2 short
contract tests use CPU2/RSS3GiB. Typed scientific qualification remains unchanged.

Darwin KERN_PROCARGS2 EIO during exec is retried by re-reading the entire snapshot
at most six times (five 1ms delays), with the same start identity on each attempt.
No cached argv or ownership grace is admitted: persistent EIO, other errno and
PID reuse remain missing evidence/rejection. CI admission uses the single resulting
leader argv consistently. `snapshot_selftest.py --output-dir /ABS/OWNED/NEW`
replays query/copy EIO and admission negatives without scientific computation.

## Private MPI preferences and measured catalogue

Root and test projects directly declare MPIPreferences so an explicit private
preference project can supply the same MPI selection to root, Pkg.test sandbox,
and ranks. Keep its Project.toml, LocalPreferences.toml, depot, environment,
expected runtime identities and all receipts outside the source. Use the complete
explicit environment with JULIA_LOAD_PATH=@:/absolute/private/project:@stdlib;
never rely on global versioned environments or edit global preferences.

`scripts/check_mpi_context.jl EXPECTED_JSON OUTPUT_JSON` measures the effective
preferences, binary/ABI, loaded MPI library, MPI.mpiexec argv and file hashes.
Mismatch throws before MPI initialization or a rank launch. The expected JSON
contains binary, abi, launcher, launcher_sha256, library, library_sha256 and
library_version_contains, plus hdf5, hdf5_sha256, hdf5_hl, hdf5_hl_sha256 and
hdf5_version. Host bindings are private inputs, never source assets. Supply both
HDF5 library preferences in the private project when the default HDF5 selection
does not bind to the same MPI library. The checker loads HDF5 before declaring a
match: it requires one MPI object, the expected parallel HDF5/HL pair and identical
MPI_Init, MPI_Comm_rank and MPI_File_open addresses through all three handles
within each process. Addresses may differ between processes. An artifact runtime
prefix or mixed library/symbol binding is rejected; no prefix is cleared.

The catalogue checks the selected HDF5 dependency closure separately from the
unchanged MPI ownership core. A high-level @rpath reference is supported only
when its sibling resolves to the measured HDF5 library and the actual loaded
handle proves the same MPI symbols. Pin that complete native closure in the
preflight; Full preparation and raw submission retain those pins and all sealed
context inputs. The catalogue preserves the final project separator for the three
test commands using Julia's normpath ROOT; the other literal paths stay exact.

Before building a Full catalogue, retain one actual root/Pkg.test sandbox/MPI2
context engineering run with four declared context outputs, actual root wait
exit, resource and cleanup evidence, current source inputs and private preference
files pinned. `full_mpi_catalog.py --preflight-run /absolute/sealed/run` requires
that same-source proof, matching measured sandbox Base.julia_cmd().exec and an
explicit --runtime matching that preflight. Full also requires --mpi-context-run
with the same private preference/depot environment; raw Full submission checks
the pinned context evidence too. It derives the launcher and library from those measurements;
there is no Homebrew launcher/library default. Rebuild after source, environment,
preferences or parent flags change. Python MPI fixtures prove process ownership
only; they do not prove Julia or Pkg.test MPI selection. Neither this context proof
nor catalogue preparation grants scientific or publication qualification.

The canonical Full scheduler launches the native Julia executable with its default
compiled-module flags. Its typed request therefore requires a preflight under
those same parent flags. A private execution request using compiled-modules=existing
can still prove library coherence and its own exact argv; it cannot qualify that
different Full parent. A task-private Julia wrapper is not accepted as the native
typed Full executable. Keep such execution evidence separate and remeasure the
actual scheduler parent before preparing Full; no mismatched flag request is launched.

Changing native HDF5 or MPI preferences is an environment change, even with the
same Julia source and dependency graph. Retain its original evidence separately,
verify focused HDF5 IO and actual MPI comparisons in the selected environment,
and do not relabel an earlier scientific PASS. No HDF5 version or host library
path is selected by this public helper. Complete package loading, the original
MPI smoke and scientific contracts remain separate validation gates.
