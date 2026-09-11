# WannierNLQG

<p align="center">
  <img src="docs/assets/wanniernlqg-logo-transparent.png" alt="WannierNLQG logo" width="640">
</p>

WannierNLQG is a Julia package for nonlinear responses and
quantum-geometric quantities from Wannier tight-binding models.

## Highlights

- **Gauge-covariant shift-current framework**

  Conventional sum-over-states,
  projector-trace, generalized Wilson-loop, and geometric-loop formulations,
  including gauge-covariant treatment of degenerate and closely spaced band
  subspaces.

- **Systematic quantum geometry**

  Berry curvature, quantum metric, multipoles,
  higher-order geometric tensors, and mixed momentum-spin quantities in one
  framework.

- **Finite-photon-momentum responses**

  Brillouin-zone-integrated and k-slice
  photon-drag shift and injection currents beyond the spatially uniform
  $q=0$ regime.

- **Symmetry-aware routes**

  Experimental support for
  representation-constrained symmetry-adapted Wannier construction, post-hoc
  symmetrization of real-space Hamiltonians and operators, and irreducible-k-orbit
  integration with invariant-tensor reconstruction for supported $q=0$ Integral
  responses.

- **Response-symmetry reports**

  For supported responses, human-readable
  `.out` and JSON outputs identify structural and magnetic space/point groups,
  the active constraint group and its generators, and real/imaginary tensor
  components that are forbidden, symmetry-related, or independent.

- **Expert DFT-to-Wannier workflows**

  Generate supported Wannier matrix elements
  from VASP or Quantum ESPRESSO wavefunctions and construct ordinary or
  symmetry-adapted Wannier functions with disentanglement, localization,
  versioned checkpoints, and operator export.

- **Independent multi-task workflows**

  Run repeated or heterogeneous tasks with
  task-local physics, numerics, observables, and outputs while reusing only
  dependency-compatible interpolation data.

- **Publication-oriented visualization**

  Produce band-structure,
  integrated-response, and k-slice figures as PDF and 600-dpi PNG with shared
  configurable styling, strict input validation, and provenance-rich plot
  sidecars.

- **Efficient dense-mesh execution**

  Mixed-FFT interpolation, symmetry
  reduction, compatible multi-task interpolation reuse, thread/MPI parallelism
  where supported, and selective memory-mapped operator-bundle reads reduce
  redundant computation and memory traffic.

## Supported calculations

- **Nonlinear optical responses (Integral and K-slice)**
  - Shift Current — Conventional, Projector, Wilson Loop, and Geometric Loop.
  - Injection Current — Conventional.
  - Injection Spin Current — Conventional.
  - Shift Spin Current — Conventional.
  - Photon Drag Shift Current — Geometric Loop.
  - Photon Drag Injection Current — Conventional.
  - Additional nonlinear optical response calculations are under active
    development.

- **Quantum-geometric quantities (K-slice)**
  - Quantum Hermitian Connection — Conventional, Projector, Wilson Loop, and
    Geometric Loop.
  - Hermitian Curvature Tensor.
  - Berry Curvature and its dipole and quadrupole.
  - Quantum Metric and its dipole and quadrupole.
  - Interband Berry Curvature and Interband Quantum Metric.
  - Zeeman Interband Berry Curvature and Zeeman Interband Quantum Metric.
  - Quantum Christoffel Symbol.
  - Triple Phase Product.
  - Shift Vector — Wilson Loop and Geometric Loop.
  - Additional quantum-geometric quantity calculations are under active
    development.

- **Band structures (KPath)**
  - Band interpolation.

- **Many additional features are under active development.**

## Requirements

- Julia 1.10 or later.
- A local checkout of the source tree.
- MPI is optional for distributed execution and the MPI test suite.

## Installation

From the package root:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate(); using WannierNLQG'
```

## Quick start

The repository includes one validated synthetic input for every registered
task. This example runs conventional Shift Current on an explicit 2 by 2 smoke
mesh:

```julia
include("examples/tasks/integral/shift_current_conventional.jl")

config = build_config(
    k_mesh = (2, 2),
    output_root = joinpath(mktempdir(), "readme-smoke"),
    progress_enabled = false,
)

result = WannierNLQG.run(config)
println.(result.outputs)
```

The smoke mesh checks the interface and output path; it is not a convergence
recommendation. Replace the synthetic model, filling, sampling, and numerical
parameters before studying a material.

The grouped response interface separates:

- `ModelInput`: model files, operator sources, and basis conventions.
- `BZMesh`, `KSlice`, or `KPath`: the sampling definition for one run.
- `TaskSpec`: the quantity, method, physics, numerics, and observable.
- `ExecutionOptions`: Fourier backend, execution, and response symmetry.
- `OutputOptions`: output location, naming, precision, and progress reporting.

See the user guide and runnable examples for the complete task registry and
parameter definitions.

## Documentation

- [User guide](USER_GUIDE.md)
- [Runnable task examples](examples/tasks/)
- [Documentation index](docs/README.md)
- [Band structures](docs/BAND_STRUCTURE.md)
- [Visualization](docs/VISUALIZATION.md)
- [Response k-mesh symmetry](docs/RESPONSE_KMESH_SYMMETRY.md)
- [Magnetic point-group identity convention](docs/MAGNETIC_POINT_GROUP_CONVENTION.md)
- [Magnetic catalogue generation receipt](catalog-generation-receipt.json)
- [Tight-binding symmetrization](docs/SYMMETRIZATION.md)
- [Symmetry-adapted Wannierization](docs/WANNIERIZATION.md)
- [Public API overview](docs/MIGRATION_1.0.0.md)
- [Release notes](docs/RELEASE_NOTES.md)
- [Changelog](CHANGELOG.md)

Version 1.0.1 is the current maintenance release. The API documented for
version 1.0.0 remains the public baseline; changelog entries describe
differences from the preceding public tag.

## Testing

Run the default Fast suite:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Run one Full-only shard or the MPI-only suite explicitly:

```bash
WANNIERNLQG_TEST_MODE=full-shard \
WANNIERNLQG_TEST_SHARD=wannier-core \
  julia --project=. -e 'using Pkg; Pkg.test()'
WANNIERNLQG_TEST_MODE=mpi-only \
  julia --project=. -e 'using Pkg; Pkg.test()'
```

The complete static shard inventory and all valid mode names are defined in
`test/CITestPlan.jl`. The GitHub Actions manual dispatch runs every shard.

Package tests use repository-owned synthetic fixtures and establish software
regression coverage. They do not establish convergence, physical validity, or
production qualification for a material-specific calculation.

## Citation and community

If you use WannierNLQG in research, cite the software release and the method
references relevant to the calculation you performed:

> Zhuocheng Lu, Zhichao Guo, Yuanyuan Xu, Jiacheng Yao, and Hua Wang.
> “[*WannierNLQG: A Julia package for nonlinear optical responses and quantum
> geometry from Wannier tight-binding models*](https://arxiv.org/abs/2609.10411).”
> arXiv:2609.10411 (2026).

- [Citation metadata](CITATION.cff)
- [Contributing guide](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Code of conduct](CODE_OF_CONDUCT.md)
- [Third-party notices](THIRD_PARTY_NOTICE.md)

## License

This source release is distributed under the
[GNU General Public License version 2 only (`GPL-2.0-only`)](LICENSE).
