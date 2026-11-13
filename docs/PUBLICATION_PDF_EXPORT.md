# Native TeX PDF export contract

This candidate changes the publication tooling only. It does not change Julia numerical code, data, units, qualification, the canonical runner, or its process/resource guards. The existing `VisualizationLauncher` already supports an explicit absolute `--python` selection; do not create a second launcher or change the user's global shell configuration.

## One maintained implementation

`scripts/visualization/pdf_validation.py` owns native PDF glyph validation. `style.check_environment()` checks the dependency lock and actual imported Matplotlib identity. `common.save_figure_atomic()` stages outputs, validates the PDF, produces Poppler and Ghostscript readbacks, and publishes only after those checks succeed. `common.seal_plot_sidecar()` verifies the validation proof against the actual PDF hash. The optional `bbox_inches` keyword preserves existing publication-tool tight layouts when a caller delegates saving.

The Type1 check tokenizes only referenced page content streams. PDF text arrays accept literal strings and numbers, so graphics dash arrays cannot consume intervening font selection operators. Each used Type1 code must identify a non-`.notdef` CharString, agree with the PDF Encoding, and be present in the font descriptor CharSet. Native text is required; a whole-page image-only PDF cannot pass as a native vector artifact. Unsupported structures fail explicitly. This is a scoped reader for the classic PDF emitted by Matplotlib, not a general PDF parser.

The minimal negative probe uses an isolated mathematical `$-$` region, positive-number controls and common unit labels. Its PNG oracle comes independently from the TeX/DVI raster chain. Both PDF renderers must show the horizontal stroke. Whole-label ink counts are diagnostic, never the pass criterion. Retain the source PDF/PNG, full readbacks, symbol ROI, commands, tool hashes, interpreter identity and failures. Numerical/physical qualification remains separate.

## Locked interpreter

The candidate lock selects Matplotlib 3.11.1, whose upstream PR 31928 preserves a legitimate Encoding[0] and includes `.notdef` separately in the retained CharStrings work set. The remaining publication requirements are unchanged. An isolated, versioned venv overlays the verified official arm64 CPython 3.11 wheel on read-only existing dependencies. Installation uses no dependency resolver, source build or global uninstall. Record the wheel SHA, package metadata paths and actual imported module path. A metadata/import mismatch is an error.

Use the existing public `--python /absolute/versioned/environment/bin/python3.11` option for the Julia front door, or the same fixed interpreter for the Python CLI. The owned `publication-runtime.json` records this choice; no global default was changed. A selected old environment now fails preflight clearly instead of producing a misleading dependency PASS.

TeX, newtx, installed fonts and renderer executables remain read-only. Record their resolved paths/identities. A/B use distinct MPLCONFIGDIR and generated TeX caches. The existing fontlist may be copied only when the upstream cache schema and font identities are verified compatible; this does not repair PDF glyph subsetting. Never prewarm outside the runner or waive the macOS process-group guard.

## Portable focused regressions and Full integration

`test/visualization/pdf_export_unit.py --output /owned/output` generates its own small native TeX figure, a test-only font-subset fault injection omitting used code 0, and an image-only PDF. It resolves `txsys.pfb` through the actual `kpsewhich`; it has no dependency on a user's Si directory, historical run, venv name or fixed TeX tree. The authentic old 3.11.0 A/B reproduction remains separate historical evidence; the generated negative is explicitly a controlled regression fixture. All requested tools, package metadata, imported module paths and the actual interpreter are recorded.

Missing TeX/newtx/fonts/renderers fail the strict invocation. Standalone callers may explicitly pass `--allow-missing-tex`; its result is `SKIP_DEPENDENCY_UNAVAILABLE`, zero tests, never PASS. The existing Full visualization shard does not pass that flag. Neither a SKIP nor a not-executed Julia test is a release qualification.

The minimal `full-visualization-test-driver.patch` requires `WANNIERNLQG_VISUALIZATION_PYTHON=/absolute/locked/bin/python3.11` in the existing Full/focused test entry, records the requested/actual executable, resolved binary and version, checks the actual selection, and runs both the original environment negatives and the portable export regression. The old missing-TeX assertion is synchronized with the expanded error while preserving its negative-test purpose. This Julia test-driver change is a static proposal only: Julia/Full execution was not authorized in this allocation and is NOT_RUN, pending the unique software owner's integration/qualification window. The existing public `--python` plotting front door remains unchanged.

## Publication skill migration

The personal `nlqg-plot-style` tool currently contains its own `fig.savefig` path and a whole-label ink gate. `skill-proposal/nlqg-plot-style.patch` is an explicitly uninstalled bridge proposal against the recorded personal tool snapshot. It delegates saving and mathematical-minus validation to this maintained module. It retains existing style/drawing semantics, uses the shared `bbox_inches="tight"` option, and preserves QA directories.

Select the maintained package with `WANNIERNLQG_VISUALIZATION_ROOT`, the fixed Python interpreter and an owned `WANNIERNLQG_PDF_QA_ROOT` for a campaign. The bridge refuses an absent validator, ambiguous loaded module, wrong dependency version or missing symbol. The global personal skill was not modified. Once the unique software owner integrates this module, adopt the thin bridge and replace the skill's text instructions with that shared contract. Do not copy validator code into each material or retain a second independently patched export backend.

Suggested skill instruction replacement:

> Use the maintained publication package and its pinned interpreter. Run its real mathematical-minus preflight. Save through the shared staged export API. For PDF glyph checks retain the native PDF, independent PNG reference and both renderer readbacks; isolated-symbol checks and Type1 consistency determine acceptance. A raster image container requires an explicitly chosen raster artifact class and cannot pass the native-vector gate.

## Failures and optional raster delivery

Glyph/render failures raise a real error and retain the temporary source in diagnostics; they do not replace the previous main PDF. A known old broken vector PDF, an image-only raster PDF and failed-primary preservation are regression negatives. Raster fallback is never automatic. If explicitly requested, create a separately named, typed raster deliverable with provenance and QA; do not mark native-vector success.

The candidate proof is written only after all requested figure formats have been generated and PDF checks have passed. Each export gets fresh readback storage even when the PDF bytes repeat. Proof schema 2 binds every actual preview SHA/byte count, source PDF SHA, renderer executable SHA/version, exact invocation and configuration. Export checks the copied evidence; sealing repeats those checks. A legacy proof cannot establish current schema-2 acceptance.

The figure set uses multiple filesystem renames. Before publication it backs up all prior primary outputs and the proof, publishes the proof last, and restores prior bytes on ordinary exceptions. Both before- and after-rename failures at every stage are tested. If restoration fails, the error and retained JSON report PARTIAL_PUBLICATION_FAILURE and the exact remaining changed paths; they never claim the primary is unchanged. This is not a power-failure/crash-atomic filesystem transaction. Consumers should publish the sidecar/manifest as the final set identity and verify every referenced hash. Do not infer correctness from a nonempty file or the sidecar's hash alone.

## Integration and rollback

1. Compare the protected formal baseline identity against `baseline-identity.json`; review `public-visualization.patch` and the focused test evidence. No patch is automatically applied to a running or frozen owner checkout.
2. Integrate requirements, environment preflight, save/seal and the shared validator together. Recreate the verified versioned environment and pass its absolute interpreter. Run the focused regression and actual figure readbacks in the canonical resource window. The software owner's normal final qualification/release gates remain its responsibility.
3. Adopt the skill bridge only against its recorded baseline hash and after the maintained package is available. Test `check-env`, manifest `check-glyphs` and representative render/tight layout under that same interpreter.
4. For rollback, select the previously recorded source/runtime profile and retain the new evidence/environment for diagnosis. Restore the previous material report/ZIP snapshot if needed. Do not delete historical evidence or pretend the old 3.11.0 native TeX PDF became valid. Its known failure must remain visible; an old correct raster artifact remains explicitly raster.

No formal software promotion, global environment migration, deployment, Library write or scientific PASS is implied by this candidate.

## Frozen current-candidate acceptance and historical limitation

The early final-001 and si-final-001 requests pinned files in a mutable candidate directory; some same-path input files were subsequently revised. Their contemporaneous outputs and real exits remain retained, but those runs do not establish whole-current-candidate PASS. An explicit historical drift audit lists every mismatch without rewriting old manifests or failures.

Current acceptance uses a new run ID and a separate read-only frozen tree containing all candidate source/tests/docs, tool and material adapter copies, plot inputs/data, cache seed, runtime selection, commands and patches. The immutable input inventory is checked before and after execution. Runtime caches, outputs and logs stay outside that tree. The current Python regressions and three existing-raw figure exports must pass against this exact frozen identity; old evidence is not substituted. Julia driver parse/format/Full entry qualification remains NOT_RUN for the unique software owner. The combined public patch includes the driver change; full-visualization-test-driver.patch is the same hunk for separate review, not a second patch to apply afterward.
