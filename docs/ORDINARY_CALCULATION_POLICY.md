# Ordinary calculation, validation and provenance policy

## Ordinary calculation

Band, Wannierization and response calculations accept well-defined finite input
and report measured residuals, convergence and numerical warnings. A finite
Hermiticity, normalization or eigensystem residual above a reporting tolerance,
an unconverged last legally accepted solver iteration, a historical producer
version, or standard/native input provenance does not by itself reject an
ordinary calculation or attach a nonresearch/diagnostic-only label. Report the
actual residual, tolerance, iteration and convergence status. A result is not
scientifically qualified merely because execution succeeds.

Reject genuinely undefined or unsolvable operations and corrupted inputs with a
specific reason: nonfinite values, missing required operators, incompatible
shapes or units, nonpositive/unsolvable metric, an undefined unregularized
zero denominator, or a broken checkpoint/component identity. Unknown failures
remain errors. Do not demote every exception into a warning. Preserve solver
accepted-state, rank and frame integrity rather than exporting an invalid state.
Wannierization `construction_policy=:strict` is an invalid parameter; remove the
argument to use the ordinary default `:standard`. Other strict flags have their
own physical contracts and are not aliases for this removed construction mode.

## Executable finite-domain and integration-by-parts formulas

A finite region, a nonperiodic input, or an unverified boundary/integration-by-
parts assumption does not by itself block a formula that can be executed with
its required operators. Calculate using explicit domain weights and report the
actual domain/periodicity and a warning that periodic-BZ-derived formulas have
not included finite-domain boundary corrections. Users assess omitted external
contributions and truncation. Do not infer a nonresearch/diagnostic-only label,
claim boundary corrections were implemented, or equate different integrands
obtained by integration by parts on each finite patch. Missing mathematical
inputs/algorithms, nonfinite values and genuinely undefined operations remain
specific errors.

Adaptive integration reports its embedded estimate and termination; unmet
requested estimates warn while retaining the result. This is not a rigorous
error bound or a new correctness gate. Do not add automatic Fermi/resonance
probes, narrow-peak detection or mandatory alternative initial-grid reruns to
ordinary software. Example-specific external scientific comparisons remain
separate from the algorithm and ordinary calculation.

## Effective nonorthogonal operators

Keep raw file bytes and raw H/S/r arrays unchanged. Explicitly construct one
consistent effective representation by Hermitian partner projection of H/S and
the position translation identity with that effective S. All spectra, Fourier
derivatives and responses use those same effective operators. Report raw and
effective defects and adjustment size in their physical units, including any
reporting-tolerance exceedance. Do not conceal a large change or describe raw
input diagnostics as residuals of the effective eigenproblem.

Use the configured denominator eta independently of optical broadening; the
ordinary default is 0.001 eV. The regulated nonorthogonal connection and its
derivatives share one D_eta recursion. Record finite-eta closure and
near-degenerate sensitivity as an approximation, not an exact projector/block
formula or PRB2018 Eq.38. Explicit eta=0 retains its actual division-domain
requirements. True physical velocity and approximate connection closure must
be distinguished when finite eta changes their relation.

## IO and provenance boundaries

### Explicit migration tools (user confirmed 2026-10-09)

For WannierNLQG, convert genuinely older operator/input/checkpoint schemas with
an explicit tool into a new file, preserving numerical arrays, units, orbital
and band order, accepted solver state and provenance. The main current reader
has no obsolete-schema fallback. Missing scientific semantics block conversion;
fixtures keep their original independent oracle and qualification level.

An internal API change with an unchanged file schema updates the expert callers
without a converter. Julia expert inputs and TOML are current supported entrances;
different physical models/producer formats remain supported sources. An older
producer/release identity alone does not imply an obsolete schema. Sealed old
sources, readers, results and FAIL evidence remain unchanged.

Human calculation output describes physical inputs, units, measurements and
warnings; hashes belong to structured provenance when needed. Ordinary Band or
response execution and result writing must not implicitly scan the installed
source/release tree. Historical result readers validate the recorded schema,
units, shapes, task/group identity and seals, without matching the producer's
release SHA to the current installation. Truly older data schemas use the
explicit migration path above; historical audit readers and evidence retain
their original meaning, including historical FAIL.

Stream input-file hashes when needed and reuse declared, verified credentials
within one run. File-stat changes require the existing content/identity checks;
model-array/callback mutation checks remain independent. Do not create a second
persistent digest registry, trust a stale credential, or cache undeclared
mutable output files. Explicit release/source audits remain available and must
be requested as audits, not run once per calculation.

## Current numerical behavior and geometry defaults

Behavior-preserving refactors retain the confirmed formulas, effective defaults,
selection domains, gauge and operator conventions, units, normalization, failure
semantics, numerical reference values and acceptance tolerances. Before changing
any of those contracts, present the concrete before/after definition, affected
consumers and data, numerical impact, compatibility plan and relevant evidence
to the user, and obtain explicit consent for that proposed semantic change. A
green test run or a self-written approval flag is not that consent. A broader
change requires consent for its additional scope.

Already-authorized, scoped repairs that restore an established contract may
continue with their old-failure/new-pass evidence and appropriate regression.
The repair label must not conceal a new definition. Ambiguous mathematics may
be investigated in an isolated candidate; it must not silently replace the
confirmed behavior or production defaults. A user's acceptance of one named
residual is limited to that use and never rewrites the original failed gate.

The targeted tests and their existing references, gates and call paths are
listed in [focused regression contracts](FOCUSED_REGRESSION_CONTRACTS.md).
