# Documentation

This index covers WannierNLQG 1.2.0. Start with the user guide and input reference, then choose a workflow or calculation guide below.

## Get started

- [Installation and precompilation](PRECOMPILATION.md)
- [User guide](../USER_GUIDE.md): task configuration, execution and output
- [TOML input and CLI](TEXT_INPUT.md)
- [Julia API](PUBLIC_API.md) and [task examples](../examples/tasks/)

## Models and sampling

- [User-defined tight-binding and analytical models](NATIVE_MODELS.md)
- [Nonorthogonal localized inputs](NONORTHOGONAL_LOCALIZED.md)
- [K-point domains and adaptive integration](ADAPTIVE_INTEGRATION.md)
- [Geometry options and Wannier mesh inputs](GEOMETRY_OPTIONS_MIGRATION.md)

## Calculations and workflows

- [Band structures](BAND_STRUCTURE.md)
- [Linear transport, optics and orbital magnetization](LINEAR_AND_ORBITAL_RESPONSES.md)
- [Second-harmonic generation](SECOND_HARMONIC_GENERATION.md)
- [Jerk current and third-harmonic generation](THIRD_ORDER_RESPONSES.md)
- [Finite-q optical links](FINITE_Q_OPTICAL_LINKS.md)
- [Response k-mesh symmetry](RESPONSE_KMESH_SYMMETRY.md)
- [Wannier construction](WANNIERIZATION.md) and [configuration reference](WANNIERIZATION_CONFIG.md)
- [Wannier operator symmetrization](SYMMETRIZATION.md)
- [Projection-representation search](PROJECTION_REPRESENTATION_SEARCHER.md)
- [PAW/USPP band-frame transform](PAW_BAND_FRAME_TRANSFORM.md)
- [Visualization](VISUALIZATION.md)
- [Theory and conventions](../theory/README.md)

## Reference and development

- [Storage schemas](STORAGE_SCHEMAS.md)
- [Magnetic point-group convention](MAGNETIC_POINT_GROUP_GUIDE.md)
- [Release notes](RELEASE_NOTES.md) and [changelog](../CHANGELOG.md)
- [Contributor guide](DEVELOPMENT.md), [architecture](ARCHITECTURE.md), [implementation inventory](ARCHITECTURE_IMPLEMENTATION_INVENTORY.md), and [release procedure](RELEASING.md)

Material-specific campaigns, private diagnostics, and release evidence are not part of the public source tree. Public package tests and examples use repository-owned synthetic fixtures.
