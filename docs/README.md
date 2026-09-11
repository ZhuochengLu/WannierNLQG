# Documentation

This directory contains the public, English-language documentation for
WannierNLQG 1.0.1. The version 1.0.0 documents remain the public API baseline.

## Start here

- [User guide](../USER_GUIDE.md): grouped `TaskConfig` reference, independent task parameters and task catalog.
- [Storage schemas](STORAGE_SCHEMAS.md): wire identifiers and validation contracts.
- [Public API overview](MIGRATION_1.0.0.md): the 1.0.0 configuration and
  namespace baseline.
- [Wannierization configuration reference](WANNIERIZATION_CONFIG_MIGRATION.md):
  the five-group expert configuration.
- [Magnetic point-group identity convention](MAGNETIC_POINT_GROUP_CONVENTION.md):
  operation digests and deterministic display labels.
- [Release notes](RELEASE_NOTES.md): initial public release scope and limits.
- [Changelog](../CHANGELOG.md): public release history.

## Workflows

- [Band structures](BAND_STRUCTURE.md)
- [Visualization](VISUALIZATION.md)
- [Symmetrization](SYMMETRIZATION.md)
- [Wannierization](WANNIERIZATION.md)
- [Projection-representation search](PROJECTION_REPRESENTATION_SEARCHER.md)
- [Response k-mesh symmetry](RESPONSE_KMESH_SYMMETRY.md)
- [PAW/USPP band-frame transform](PAW_BAND_FRAME_TRANSFORM.md)

## Design and maintenance

- [Architecture](ARCHITECTURE.md)
- [Architecture implementation inventory](ARCHITECTURE_IMPLEMENTATION_INVENTORY.md)
- [Development guide](DEVELOPMENT.md)
- [Release procedure](RELEASING.md)

Material-specific campaigns, private diagnostics, and release evidence are not
part of the public source tree. Public package tests and examples use
repository-owned synthetic fixtures.
