# Source distribution

The maintained software line is 1.2, with software identity
`1.2.0` and the unchanged WannierNLQG UUID. Package versions and persisted
schema versions are independent. This is the public source profile; a source export does not publish a remote release.

`scripts/source_distribution.json` is the authoritative feature classification.
Every payload file has an explicit feature owner. Private membership takes
precedence, unknown new paths reject export, and context-bound projections remove
private attachments from shared owners. Changing an attachment requires reviewing
its projection; export never guesses a new include or API boundary.

To add a feature, record its source, entrypoints, dependencies, tests, documentation,
examples, assets, precompile coverage and public status in that file. Public code
must not depend on a private feature. Retained shared interpolation, nonorthogonal,
MPI, HDF5 and native-input facilities keep their own contracts. Test-plan and
extension contract projections belong to the same classification as source code.

From a clean committed source package, export to a new external directory:

```bash
python3 -B scripts/export_public_source.py --audit
python3 -B test/source_distribution_unit.py
python3 -B scripts/export_public_source.py --output /absolute/new/public-source
```

Export derives `PUBLIC_FEATURES.md`, the public classification and exact source manifests. It never copies Git history, overwrites a
destination, clears installed depots or publishes. Use the existing
`scripts/export_public_source.py` in the exported tree to
assemble a committed source export. Record the returned input commit, classification
SHA, public manifest/tree SHA and archive SHA outside the package.

Static export checks establish source boundaries only. Installation/loading,
precompile and declared public tests run independently in a clean exported path
with a private compiled cache and verified installed dependencies. Their outcomes
and environment assumptions must be recorded separately. Earlier numerical,
performance and material qualifications retain their original source identities.
