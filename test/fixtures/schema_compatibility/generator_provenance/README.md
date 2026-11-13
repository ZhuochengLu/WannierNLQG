# Generator schema compatibility fixtures

These small synthetic inputs are engineering fixtures, not material qualification
or upstream physics oracles. The numerical companion files and numerical HDF5
items retain their original bytes, shapes and dtypes.

The provenance containers are privacy-transported copies of the original schema
1.2/1.3 writer outputs or the explicitly constructed historical-contract fixtures.
Only listed absolute temporary artifact paths were made relative. Historical
embedded provenance/contract seals were not recomputed or re-authenticated; these
copies are not claimed to be untouched historical writer outputs. The current
readers reject these obsolete schemas. New-writer tests independently compare
whole binary SPN/uIu/uHu outputs against the original numerical companions.

The separate frame-semantics migration fixtures retain their own original seals
and migration tests. The root fixture checksums identify the transported bytes;
original files and identities remain in package-external release evidence.
See [privacy transport](../../../../docs/FIXTURE_PRIVACY_TRANSPORT.md).
