# First-use precompile maintenance

For ordinary package precompilation, extension preparation and isolated cache
rebuilding, use [the user precompilation guide](PRECOMPILATION.md). The tools below
maintain or qualify first-use coverage; they are not a module-selective user
precompile command.

Small core and extension workloads preserve the existing physical algorithms,
owner guards and include order. Generated compiler declarations are tied to the
Julia build, Manifest and computation source. Anonymous names (`var"#…"`) and
non-parseable NamedTuple field printers require actual Type evidence; matching
similar printed text does not establish a specialization's origin.

The current static release revision guards captured declarations with an exact
Julia 1.11.2 version match. Other supported Julia versions keep the portable
bounded workloads and normal JIT, without the captured anonymous/internal
signature coverage. The guard also uses an explicit parent-module binding at
the affected workload boundary. Tests, explicit precompilation, source
re-attribution, cold measurements and scientific execution remain `NOT_RUN`
for this revision; the 069 measurements remain bound to their original source.

Three bundled HDF5 files were physically repacked after their active locators
had already been made relative. Repacking removes unreachable private path
bytes and preserves every active field, dtype, shape, storage property and
numeric bit pattern, including signed zero. Logical digest attributes remain
unchanged. The fixture manifest binds the new physical bytes; sealed historical
native goldens retain their original input bindings. Official scientific Julia readback
and new runtime transport qualification have not been run on this revision.

Three serialized preparation caches under
`assets/native_directory_2/.wannier_preparation` were migrated in an external
copy with Julia 1.11.2 and their actual Serialization types. Only allowlisted
metadata strings changed. The band-frame filename follows the SHA-256 of its
new contract; relative locators resolve from the portable fixture root, and
the expert probe selects that root as its working directory. UPF/SPN blocks,
scientific bits, status fields and scientific input hashes remain unchanged. The outer SPN
provenance-file digest is rebound to the existing portable JSON bytes; cache
sidecars and manifest bindings are updated to the migrated physical bytes.

This data-only migration loaded modules and could perform normal JIT work to
deserialize and serialize the stored objects. It did not run tests, explicit
precompilation, a scientific calculation or runtime qualification. Historical
code and input bindings remain historical: this migration does not establish
current runtime cache hits, cold performance or scientific eligibility.
Fail-closed identity checks remain in force; official scientific readers for
the repacked HDF5 inputs have not been run. No public release is asserted.

The task table in `scripts/first_use/path_registry.json` contains 52 legal
`run(cfg)` paths. `scripts/first_use/expert_paths.json` now declares 68 independent
expert scenes, including the original eight-iteration serial and MPI12
localization fixtures. Model, seed, solver, tolerances and iteration limits are
frozen. Legal `MAX_ITERATIONS` does not establish solver quality. The summary
writer receives its extension-owned result from a separately measured first
public validation call; the writer's backend is necessarily present afterward.
All other required backends must remain absent until their first public call.

`test/fixtures/first_use_portable` contains a manifest-bound transport bundle:
27 serialized Root-owned argument graphs and all declared native dependencies.
Only explicit input/output locators and their official coupled integrity digests
change during relocation. Original numerical data, types, references, arrays and
positive/negative zero bits remain fixed. The owned IO adapter does not add
methods to unrelated IO or rewrite arbitrary serialized byte patterns. Every
file and ancestor path is checked before loading; symlinks, escapes, missing
inputs and digest mismatches fail. Native files with path-bound digests are
validated by their official reader/digest contract. Complete raw evidence and original inputs remain outside the release payload;
small selected comparator goldens carry their captured artifact bytes and
explicit test-only metadata relocation, with original report digests.

```sh
python scripts/first_use/fixture_bundle.py check test/fixtures/first_use_portable
python scripts/first_use/fixture_bundle.py restore test/fixtures/first_use_portable /external/fresh-fixtures
python scripts/first_use/test_maintenance_tools.py
python scripts/first_use/test_native_science_contract.py
python scripts/first_use/test_expert_qualification.py
python scripts/first_use/test_registered_qualification.py
python scripts/first_use/test_localization_contract.py
```

The restore command rehydrates the frozen transport bundle. It does not rerun a
solver or create new scientific inputs. New inputs need a new capture and new
qualification. Serialized inputs are qualified with Julia 1.11.2 and the frozen
Manifest recorded in `docs/first_use_source_qualification.json`.

## Actual source recapture and reproducible attribution

Make an independent diagnostic source copy and add only this preference there:

```toml
[PrecompileTools]
precompile_workloads = false
```

Use a separate depot and external output directory. Collect both serial and real
MPI12 task traces with `scripts/first_use/collect_traces.py`; use its `--project`,
`--candidate`, `--registry`, `--depot`, `--output` and `--ranks` arguments. An
optional `--readonly-depot` supplies dependency caches. The runner uses the
frozen 4x4 small responses and the immutable nonzero Pauli input for both Zeeman
paths; it never invokes material-scale demonstration defaults.

Run `scripts/first_use/collect_expert_traces.py` with the same project/candidate,
depot and external output arguments. Its complete scope has 72 actual source
observations: 68 scene calls, the actual writer validation prerequisite, and
three verified native-cache-hit supplements. Cache bytes come from the same
source's completed native generation, are copied with hashes before a new
process starts, and must produce real `CACHE_HIT` events and exact native
readback. Cache-hit source observations do not count as first-call speed
qualification. `--cases` is for affected local diagnostics. A new numbered
partial controller may use `--reuse-main-index` only after checking all original
artifact/source/runner hashes; successful calls are not resampled.

All collectors retain exit status, resource samples, untouched raw rank traces,
actual first-call byte intervals, inference observations and original
`MethodInstance.specTypes` graphs. Real MPI uses all ranks. No checkpoint resume
shortcut is accepted. Unparseable trace expressions remain diagnostics; they
are not silently filtered. Exact actual-Type fallback requires the original
capture, inference order, declared printer-failure scope and lossless reduction
proof to agree. Runtime anonymous thread bindings require their actual method
and field-layout proof.

Use `describe_runtime_bindings.jl output.json` separately in the ordinary
candidate and identity-matched workload-off project. Assemble the descriptor
proof with `source_proofs.py threads --candidate PROJECT --current-descriptors
FILE --traced-descriptors FILE --output FRESH_FILE`. Both descriptors must come
from the same computation source and Julia build. Descriptor hashes, four
required unique method/field-layout matches and actual Type equality remain
required by the audit.

For non-parseable captured Types, first run `capture_type_printer_failures.jl
PROJECT CAPTURE INFERENCE REQUIRED_KEYS OBSERVATION FRESH_DIRECTORY` against
the actual new capture. It verifies frame order, original Type identity and
actual printer failures for the declared scope; unmatched failures remain
diagnostics. Then run `reduce_actual_types.jl CAPTURE INFERENCE
REQUIRED_KEYS FRESH_DIRECTORY`, then `source_proofs.py types --candidate PROJECT
--index EXPERT_INDEX --observation SCENE_ID --projection DIRECTORY --failures
PRINTER_FAILURES --output FRESH_FILE`. The reducer checks actual frame order and
Type identity and writes a lossless exact projection. The assembler binds every
original artifact digest and the declared printer-failure scope. Proof paths
are relative to their proof file, so relocating an evidence tree does not
require hardcoded developer paths. `test_source_proofs.jl TYPE_PROOF
THREAD_PROOF FRESH_DIRECTORY` checks the eight required actual Types and four
thread bindings, including fifteen rejection cases.

`scripts/first_use/audit_signatures.jl --write|--check` takes the frozen 52-row
registry, serial traces, MPI12 traces, diagnostic source, external canonical TSV
and expert index. Supply `FIRSTUSE_EXPERT_REGISTRY`,
`FIRSTUSE_THREAD_BINDING_PROOF` and `FIRSTUSE_AUDIT_ACTUAL_TYPED_INDEX` when those
proofs are needed. The source and Manifest must match. `--check` independently
reconstructs every retained declaration's attribution and requires exact TSV
bytes and zero unowned declarations. Source attribution does not establish a
speed or scientific PASS.

The historical source069 audit records 9716 retained declarations and zero
unowned declarations after independent reconstruction in its recorded Type world.
Unchanged original source063 raw observations retain their original identities
and are accepted only through the strict compiler-only equivalence certificate;
two affected public MPI12 origins were captured freshly on source069.
This attribution does not establish final speed, science, or engineering PASS.
The declared module binding and compiler ownership repairs preserve all 1048
affected actual compiler Type requests and workload preferences.
Its four exact shards are in
`docs/first_use_signature_provenance/`; each file stays below the existing 5 MiB
release limit. The canonical SHA and qualification boundary are recorded in
`index.json` and `docs/first_use_source_qualification.json`.

```sh
python scripts/first_use/provenance_shards.py check docs/first_use_signature_provenance
python scripts/first_use/provenance_shards.py restore docs/first_use_signature_provenance /external/provenance.tsv
python scripts/first_use/provenance_shards.py write /external/new-provenance.tsv /external/new-shards
```

Run an independent fresh-process audit check against the restored canonical
file before a release. Any computation-source or Julia change that can rename
anonymous types requires fresh source capture and cold qualification. Raw
traces and intermediate results stay external, including every failure and
interruption.

## Cold and engineering qualification

`campaign.py --candidate PROJECT --depot DEPOT --evidence DIRECTORY --name
FRESH_NAME --ranks 1|12` measures the 52 registered paths in two predeclared,
independent guarded processes per path. Serial and MPI12 are separate complete
runs. Each attempt must pass before the controller advances; a failed sample is
retained and is never replaced by a faster sample. `--cases` selects affected
local checks and cannot establish the complete 52-path gate.

The portable registered science index seals 104 original serial/MPI12 native
records as scientific references. Every numeric value is compared through its
float64 bits, including signed zero; per-rank output ownership, table shapes, column layouts, labels and
scientific metadata are exact. Nonzero checks count physical response columns,
excluding energy and reciprocal-space axes. Written files are read back by the
comparator; serial repeat outputs must reproduce the same scientific record.
For spectral provenance, source and release-tree digests are checked against the
actual computation source and exact manifest-bound inventory. The task digest
is rebuilt in the official IO writer's field order, and DAT headers must agree
with their TXT metadata before those three attested producer fields can be
transported. No numeric or scientific metadata field is waived. The 104-roundtrip
comparator qualification includes 32 rejection cases covering digest tampering,
field binding, signed zero, malformed native outputs, cold observations and exact release inventories. It
executes no scientific model and is not a final timing measurement.


`expert_campaign.py --candidate PROJECT --depot DEPOT --evidence DIRECTORY
--name FRESH_NAME` measures all 68 scenes with two predeclared fresh-process
samples. It requires each sample's cold, execution and exact scientific
qualification before advancing; a failure remains in its numbered directory.
The sealed reference index contains 68 original scenes and 79 rank records,
plus 28 additional native scientific reports. Official coupled digest readers
run after the measured process and bind their exact verified fields to that
artifact SHA. No numeric, shape, status or tolerance field is excluded. Selected
comparator tests include 28 real native positive records and 16 tampering
negatives, in addition to sixteen captured cold records and fourteen cold negatives.
GC is observed at
the actual public timer. `compile_time` already includes `recompile_time`; the
latter is a reported subset, not an added cost. Every first-call compile value
must be at most 0.5 seconds; MPI compilation is the maximum across actual ranks.
Expected nonzero fixtures must execute successfully. Scientific/native,
readback, thread, MPI and checkpoint comparisons use exact bits, including both
signs of zero. Only explicitly declared transport/cost/time metadata differs.

`localization_campaign.py` uses the same candidate/depot/evidence/name options
and reuses the frozen eight-iteration fixture in serial, MPI1/2/12 and thread2/4
modes. Each has two declared fresh-process samples. The original 435 returned
numeric fields and 581 native checkpoint fields must match exactly, including
signed zero. Only the original explicit cost/time/execution digest metadata
fields differ. Official checkpoint integrity readers run after measurement.
The comparator rejects extra exclusions, changed bits, shapes, semantic fields
and missing official readback. Legal `MAX_ITERATIONS` still grants no solver
quality qualification.

The resource guard waits for external Julia/MPI work and manages only its own
child group. It limits short calls to 180 seconds, stops at 42 GiB owned RSS for
three samples, requires 10 GiB free disk before and during a run, and stops on
any increase in host swapout traffic. Missing actual swap-used is reported as
missing; swapout traffic is not called swap-used. All thread and BLAS settings
are one. Build time, cache size, import time, memory and runtime costs are
reported separately; cache build time and cache size have no fixed hard gate.

`check_no_side_effects.jl [FRESH_DIRECTORY]` obtains an independent
dependency-only HDF5 handle baseline, then checks exact package file contents,
empty isolated working directory, unchanged public names and no MPI
initialization/finalization. It records handle counts at every optional import
and verifies that a deliberately retained file is detected and closed.

Import/build workloads must not initialize MPI, create user results or retain
open runtime handles. Content hashes, isolated working-directory contents,
public namespace inventory and handle observations supplement the lifecycle,
architecture, whitelist, original manifests and test-suite gates. A local
result or historical candidate's evidence cannot be relabeled as the final
candidate's PASS. Promotion requires all gates on one frozen final candidate.

## Compiler file ownership

The residual files now have unique owner names:

| Previous extension-local name | Current basename |
| --- | --- |
| `ext/WannierNLQGSymmetrizationExt/TaskInferenceResidualCoverage.jl` | `SymmetrizationTaskInferenceResidualCoverage.jl` |
| `ext/WannierNLQGSymmetryFoundationExt/TaskInferenceResidualCoverage.jl` | `SymmetryFoundationTaskInferenceResidualCoverage.jl` |
| `ext/WannierNLQGOperatorBundleExt/TaskInferenceResidualCoverage.jl` | `OperatorBundleTaskInferenceResidualCoverage.jl` |
| `ext/WannierNLQGWannierizationExt/TaskInferenceResidualCoverage.jl` | `WannierizationTaskInferenceResidualCoverage.jl` |
| `ext/WannierNLQGSymmetrizationExt/Generated/ResponseWriterSignatures.jl` | `SymmetrizationResponseWriterSignatures.jl` |
| `ext/WannierNLQGSymmetryFoundationExt/Generated/ResponseWriterSignatures.jl` | `SymmetryFoundationResponseWriterSignatures.jl` |

Only file names and include locators change in this migration; declaration order
and actual compiler Type identities remain fixed. Public provenance is rebuilt
against the current owner locators before qualification.

The portable source supplement generator is `scripts/first_use/source_supplements.py`.
It produces inputs from the packaged fixture bundle, not from historical user paths.
Run its `prepare` mode with `--candidate` and a fresh local `--destination`.
The emitted `predeclaration.json` records the generated gauge file, replay source
and exact probe identity. In a separate process, invoke
`scripts/first_use/prepare_replay_string_fixture.jl` with those gauge and replay
paths and `<destination>/replay_preparation_receipt.txt`. Then run the generator's
`seal` mode against the same destination. Preparation must finish before any
source or speed probe starts; do not include it in a measured process.

Use `trace` mode with `--project` pointing to the same-source workload-disabled
copy, plus `--evidence`, `--depot`, `--readonly-depot` and `--julia`. It captures
three actual first public calls and rejects matching preparation requests in the
before-target trace. Use `cold` mode against the frozen candidate with a fresh
`--evidence`; it predeclares two samples per scene, uses the existing scientific
contracts and requires every compile time to be at most 0.5 seconds. Each mode
retains all failures. A trace completion is source evidence only; the independent
full source audit and final scientific, parallel and engineering gates remain
separate. The generated source-only scenes do not replace the original 68
expert scenes or their native reference data.

Three additional public-call source observations reproduce compiler declarations
hidden by portable fixture preparation. They supplement the 68 expert speed
scenes and do not replace their measurements.

The generator verifies and rehydrates the complete original payload in a fresh
local output directory. Its generated probe preserves `expert_probe.jl` timing,
GC, first-call interception, inference capture and science checks, while replacing
only the manifest-driven preparation with a Python-verified literal transport
context. It does not parse JSON3 object arrays/objects or index a string-keyed
transport dictionary before the public call. Source capture explicitly rejects
the previously hidden compiler requests in the before-target trace interval.

The QE symmetry-completed case retains a legitimate native replay source whose
HDF5 `source_replay_save_directory` string uses 287 storage bytes. A separate
preparation process copies the unchanged QE source and creates a 287-byte UTF-8
absolute local locator (HDF5.jl uses the string byte length as fixed storage size). Padding is derived from the
chosen fresh output directory; no user name, previous absolute path or external
root is embedded. The generator rejects roots that cannot represent this bounded
case and requests a shorter local output directory. This is an input transport
specialization, not a scientific result or a requirement on normal user paths.
Only the replay locator and its canonical sorted `key=value\n` descriptor digest
change; every other native HDF5 field is compared through exact serialized bytes,
including signed zero, and the actual public call must pass the existing native
science contract. The preparation process is independent of each fresh measured
process and cannot activate that process's target or required backend.

Source capture uses workloads disabled and one predeclared sample per scene.
Speed qualification uses two predeclared independent fresh processes per scene,
GC enabled, required backends absent at the first timer, and compile time at most
0.5 seconds for each. Recompile time is a subfield of compile time. Failures and
unfinished outputs remain numbered and cannot be substituted with later samples.
No private target helper is called to manufacture a trace. Public entries are
`read_projection_representation_search_hdf5`,
`generate_symmetry_completed_qe_paw_matrix_elements` and
`prepare_exact_wannier_operator_bundle`.

Attribute handles are opened and closed through HDF5 read/write APIs. Readback
opens a fresh file after mutation and checks actual datatype storage size287.
The earlier286-plus-terminator assumption was incorrect for this HDF5.jl API;
its failed preparation remains retained and was never used for source or speed
qualification.

The separate native transport preparation uses the official gauge decoder and digest algorithm to reseal exactly three transport fields: replay locator, descriptor digest, and logical payload digest. It checks the original digest before changing any field, verifies every other native field including signed zeros exactly, and verifies the new file through the official reader. No preparation calls contribute traces or cold timing.

Strict raw-origin equivalence uses `FIRSTUSE_SOURCE_EQUIVALENCE` with its sealed external certificate. The audit verifies all original inputs, exact unchanged computational/test/fixture/environment files, append-only literal compiler ASTs, current tooling hashes, original source manifests and actual Types. TSV schema 2 preserves each row’s raw-origin source SHA and certificate SHA independently of the declaration source SHA. This option cannot reuse historical speed samples. Fresh unrelated sources remain rejected.

Strict raw-origin equivalence uses `FIRSTUSE_SOURCE_EQUIVALENCE` with its sealed external certificate. The audit verifies all original inputs, exact unchanged computational/test/fixture/environment files, append-only literal compiler ASTs, current tooling hashes, original source manifests and actual Types. TSV schema 2 preserves each row’s raw-origin source SHA and certificate SHA independently of the declaration source SHA. This option cannot reuse historical speed samples. Fresh unrelated sources remain rejected.
