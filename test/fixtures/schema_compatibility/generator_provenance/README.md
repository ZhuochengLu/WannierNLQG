# Generator schema compatibility fixtures

All numerical inputs are small synthetic engineering fixtures, not material qualification or upstream physics oracles.

The stored files were produced from the exact synthetic inputs and writer contracts named below. They were not created by relabeling current public writers or by rewriting stored payloads. Their byte identities are sealed by the fixture `SHA256SUMS`; package-external release evidence retains the generation commands and source identities.

| File | Origin |
|---|---|
| vasp_spn.h5 | Original schema-1.2 persistence writer, given a typed two-kpoint synthetic spinor state. This does not execute WAVECAR/POTCAR reconstruction. |
| qe_spn.json | Original public QE PAW-SPN writer, schema 1.2, using the stored three-kpoint synthetic PAW source. |
| uiu.json / fixture.uIu | Original public uIu generator, schema 1.2, with a same-source MMN oracle. |
| hamiltonian.json / fixture.uHu | Original public uHu generator, schema 1.3, with native DFT authority. |
| uiu_partial.json | Original schema-1.2 partial-checkpoint payload builder with an explicit zero-record state; not an interrupted full generator run. |
| vasp_spn_contract_1_0.h5 / vasp_spn_contract_1_1.h5 | Explicit historical-contract fixtures, sealed with the original formal digest function and accepted by the original formal reader. They are not claimed to be historical writer outputs. |
| qe_spn_contract_1_1.json | Explicit historical-contract fixture, sealed with the original formal legacy contract/digest functions and accepted by its reader. It is not claimed to be a historical writer output. |
| qe_source/ | Exact native-input bytes reused by the new writers for numerical comparison. |

`SHA256SUMS` preserves all stored artifact/input bytes. The provenance files keep their original artifact paths and embedded digests; tests read historical seals without rewriting paths, compare stored companion-file hashes, and separately verify new writer outputs with live paths. Legacy VASP fixtures use the relative companion `vasp.spn` and are read with this fixture directory as the working directory.

Package-external release evidence records generation commands and file hashes. These schema-only tests use the stored synthetic inputs solely to validate compatibility, exact scientific-byte preservation, and fail-closed behavior; they do not confer material-level scientific qualification. VASP matrix provenance 1.3-to-1.0 is covered by a source-AST identity check except for the version constant, not a full persistence roundtrip.
