# WannierNLQG

<p align="center">
  <img src="docs/assets/wanniernlqg-logo-transparent.png" alt="WannierNLQG logo" width="640">
</p>

WannierNLQG is a Julia package for nonlinear responses and quantum-geometric quantities from Wannier tight-binding models.

## Capabilities

- **Wannier tight-binding and analytical k·p models**

  Use supported orthogonal or nonorthogonal Wannier tight-binding models, user-defined hopping models and analytical Hamiltonians within the documented [basis and operator requirements](docs/NATIVE_MODELS.md) and [nonorthogonal input scope](docs/NONORTHOGONAL_LOCALIZED.md).

- **K-point sampling and adaptive integration**

  Select BZ meshes, paths, slices or bounded Cartesian regions, with [adaptive refinement](docs/ADAPTIVE_INTEGRATION.md) for supported integral responses.

- **Symmetry tools**

  Use experimental symmetry-adapted Wannier construction, real-space operator symmetrization and response symmetry analysis or reduction [where supported](docs/RESPONSE_KMESH_SYMMETRY.md).

- **DFT-to-Wannier workflows**

  Construct ordinary or symmetry-adapted Wannier models from supported VASP or Quantum ESPRESSO inputs, with [disentanglement, localization, checkpoints and operator export](docs/WANNIERIZATION.md).

- **Efficient dense-mesh calculations**

  Use Mixed-FFT interpolation, compatible multi-task reuse, selective operator reads and thread/MPI parallelism where supported.

- **Publication-oriented visualization**

  Produce band-structure, integrated-response and k-slice figures as PDF and 600-dpi PNG with [configurable styling and provenance sidecars](docs/VISUALIZATION.md).

## Supported calculations

- **Linear optical responses (Integral and K-slice)**
  - Drude-like, Quantum-Metric, and Berry-Curvature Contributions — Conventional and Projector.

- **Nonlinear optical responses (Integral and K-slice)**
  - Shift Current — Conventional, Projector, Wilson Loop, and Geometric Loop.
  - Injection Current — Conventional.
  - Injection Spin Current — Conventional.
  - Shift Spin Current — Conventional.
  - Photon Drag Shift Current — Geometric Loop.
  - Photon Drag Injection Current — Conventional.
  - Second-Harmonic Generation — Conventional.
  - Jerk Current — Conventional.
  - Third-Harmonic Generation — Conventional.

- **Linear transport (Integral and K-slice)**
  - Drude, Quantum-Metric, and Berry-Curvature Contributions — Conventional and Projector.
  - Independent Intrinsic Anomalous Hall Conductivity — Conventional and Projector.

- **BCD/BCQ DC Hall conductivity (Integral and K-slice)**
  - Berry-Curvature-Dipole and Berry-Curvature-Quadrupole DC Hall Conductivity — Conventional.

- **Modern orbital magnetization (Integral and K-slice)**
  - Orbital Magnetization — Conventional and Projector.

- **Quantum-geometric quantities (K-slice)**
  - Quantum Hermitian Connection — Conventional, Projector, and Wilson Loop.
  - Hermitian Curvature Tensor.
  - Berry Curvature and its dipole and quadrupole.
  - Quantum Metric and its dipole and quadrupole.
  - Interband Berry Curvature and Interband Quantum Metric.
  - Zeeman Interband Berry Curvature and Zeeman Interband Quantum Metric.
  - Quantum Christoffel Symbol.
  - Triple Phase Product.
  - Shift Vector — Wilson Loop and Geometric Loop.

- **Band structures (KPath)**
  - Band interpolation.

## Requirements

- Julia 1.10–1.11 or Julia 1.13.0. The supplied lockfile targets Julia 1.13.0.
- A local checkout of the source tree.
- MPI is optional for distributed execution and the MPI test suite.

## Getting started

Unpack the WannierNLQG 1.2.0 source archive and open a terminal in the directory containing `Project.toml`; use Julia 1.13.0 with the supplied lockfile:

```sh
JULIA_PKG_PRECOMPILE_AUTO=0 julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile(; strict=true)'
julia --startup-file=no --project=. scripts/wanniernlqg.jl check examples/text_input/band-column-nodes.toml
julia --startup-file=no --project=. scripts/wanniernlqg.jl run examples/text_input/band-column-nodes.toml --records band-records
```

The synthetic example writes a Band `.dat` table under `examples/text_input/results/column-band/` and run records under `band-records/`.

Initial dependency downloads may require network access; ordinary use relies on Julia's precompiled package cache, and the example is an interface check rather than a material-convergence calculation. See [precompilation and environment setup](docs/PRECOMPILATION.md), [optional system images](docs/PRECOMPILATION.md#optional-local-system-image-build), [MPI execution](USER_GUIDE.md#7-running-outputs-and-environment-variables), [TOML input](docs/TEXT_INPUT.md) and the [Julia API](docs/PUBLIC_API.md) for details.

## Tutorials

For a practical path from the Quick start example to real-material studies, see the [WannierNLQG tutorials](https://github.com/ZhuochengLu/WannierNLQG-tutorials). The tutorials provide reproducible examples of material inputs, runnable configurations, reference results, and visualization workflows for supported calculations.

## Documentation

- [User guide](USER_GUIDE.md) and [documentation index](docs/README.md)
- [TOML input and CLI](docs/TEXT_INPUT.md)
- [Installation, precompilation and optional system images](docs/PRECOMPILATION.md)
- [Julia API overview](docs/PUBLIC_API.md) and [runnable task examples](examples/tasks/)
- [Development and testing guide](docs/DEVELOPMENT.md)
- [User-defined tight-binding and analytical k·p models](docs/NATIVE_MODELS.md)
- [Nonorthogonal localized-basis inputs](docs/NONORTHOGONAL_LOCALIZED.md)
- [K-point domains and adaptive integration](docs/ADAPTIVE_INTEGRATION.md)
- [Band structures](docs/BAND_STRUCTURE.md)
- [Linear transport, optics and orbital magnetization](docs/LINEAR_AND_ORBITAL_RESPONSES.md)
- [Second-harmonic generation](docs/SECOND_HARMONIC_GENERATION.md)
- [Jerk current and third-harmonic generation](docs/THIRD_ORDER_RESPONSES.md)
- [Quantum-geometry options and Wannier mesh inputs](docs/GEOMETRY_OPTIONS_MIGRATION.md)
- [Finite-q optical links](docs/FINITE_Q_OPTICAL_LINKS.md)
- [Response k-mesh symmetry](docs/RESPONSE_KMESH_SYMMETRY.md)
- [Magnetic point-group conventions](docs/MAGNETIC_POINT_GROUP_GUIDE.md)
- [Tight-binding symmetrization](docs/SYMMETRIZATION.md)
- [Wannier construction](docs/WANNIERIZATION.md)
- [Visualization](docs/VISUALIZATION.md)
- [Release notes](docs/RELEASE_NOTES.md) and [changelog](CHANGELOG.md)

## Citation and community

If you use WannierNLQG in research, cite the software release and the method references relevant to the calculation you performed:

> Zhuocheng Lu, Zhichao Guo, Yuanyuan Xu, Jiacheng Yao, and Hua Wang.
> “[*WannierNLQG: A Julia package for nonlinear optical responses and quantum
> geometry from Wannier tight-binding models*](https://arxiv.org/abs/2609.10411).”
> arXiv:2609.10411 (2026).

- [Citation metadata](CITATION.cff)
- [Contributing guide](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Code of conduct](CODE_OF_CONDUCT.md)
- [Third-party notices](THIRD_PARTY_NOTICE.md)

## Code contributors

WannierNLQG has received code contributions from:

- Zhuocheng Lu
- Zhichao Guo
- Yuanyuan Xu
- Jiacheng Yao
- Hua Wang

## License

This source release is distributed under the [GNU General Public License version 2 only (`GPL-2.0-only`)](LICENSE).
