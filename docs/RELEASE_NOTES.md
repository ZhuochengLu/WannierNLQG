# WannierNLQG v1.2.0

WannierNLQG 1.2.0 adds third-order optical responses, user-defined tight-binding, analytical k·p Hamiltonians, nonorthogonal localized-basis inputs, adaptive k-space integration and a TOML-based calculation interface. It also corrects finite-momentum optical links and revises quantum-geometry defaults. Existing users should review the breaking changes below before reusing inputs or comparing results.

## New features

### TOML input and a common command-line workflow

- `scripts/wanniernlqg.jl` offers **`init`, `check`, `explain` and `run`**, so ordinary calculations can be configured without writing a Julia driver.
- The frontend uses the existing typed task API and records explicit inputs, resolved defaults, effective settings and actual execution provenance. Configuration checks do not run response integrations or establish material convergence.

### Nonorthogonal localized-basis support

- `NonorthogonalLocalizedModel` / `NonorthogonalLocalizedInput` accept real-space Hamiltonian, overlap and position matrices and use generalized eigensystems for supported calculations. Input containing only Hamiltonian and overlap matrices is also admitted for operations that do not require the position operator; it does not silently provide a zero position matrix.
- **Supported software input: OpenMX.** The current file-input route supports documented scalar 3.8 and explicitly declared `scfout_v3` scalar, collinear and spinor files. Imported data must satisfy the documented lattice, translation, unit, spin, orbital-ordering and Bloch-convention requirements and provide the operators required by the selected task.
- Nonorthogonal finite-q response and external quantum-metric completion are not supported. Input admission does not imply that every response/model combination or material is qualified.

### User-defined tight-binding and analytical k·p models

- **Real-space tight-binding models:** `RealSpaceTBInput` accepts user-defined hopping arrays and explicit orbital centers.
- **Analytical k·p models:** `AnalyticKInput` accepts a Julia Hamiltonian callback `callback(k, parameters)` directly, with Cartesian k in inverse Angstrom and Hamiltonian matrix elements in eV. Supported basis declarations are fixed orthogonal point orbitals or a fixed, k-independent orthonormal basis. Derivatives can be supplied explicitly, obtained with ForwardDiff, or evaluated by explicitly selected finite differences. Nonperiodic models declare `periodic=false`; the callback must cover all required derivative and finite-q evaluation points. The supplied [nonperiodic k·p example](../examples/native_models/nonperiodic_kp.jl) demonstrates this input route.
- Both model interfaces use the registered task API, subject to each task's operator and basis requirements. Analytic callbacks are supplied by the Julia caller, not constructed from a standalone TOML file; general k-dependent bases are unsupported. Mesh convergence and the k·p integration cutoff must be checked separately.

### Jerk current and third-harmonic generation

- **Jerk current (`JC` / `JCK`)** provides the ordered third-order acceleration-channel material coefficient for Brillouin-zone integrals and k-space slices, with complex tensor output and symmetric or antisymmetric optical-index projections. The reported coefficient excludes relaxation lifetimes; a chosen steady-state model supplies those separately.
- **Third-harmonic generation (`THG` / `THGK`)** provides complex conductivity and susceptibility, with independently implemented regrouped and unregrouped formulations and term-resolved output. Users can select tensor components for integral calculations or one component and energy for a slice.
- Periodic Jerk/THG results use three-dimensional reference-cell volume normalization. Nonperiodic results follow the documented model-level reference geometry and physical integration measure; existing complete 3x3 declarations retain their original continuum convention. Sheet, line and effective-thickness unit conversions belong to postprocessing, and the removed response-layer measure selectors are rejected. Periodic finite regions retain their original Brillouin-zone fraction.

### K-point sampling and adaptive mesh integration

- **Explicit sampling domains:** use `BZMesh` for Brillouin-zone integration, `KPath` and `KSlice` for supported path and slice calculations, and `KRegion` for bounded Cartesian integration, including nonperiodic k·p models. Region quadrature and the physical integration cutoff are explicit. User-defined periodic models can declare symmetry with representation and covariance checks before supported response reduction.
- **Adaptive integration:** `HAdaptiveCubature` refines a one-, two- or three-dimensional physical domain using absolute/relative tolerance and complete-rule evaluation-budget controls. Applicable Integral routes reuse their existing point kernels, with response-specific model, basis and operator requirements. Current adaptive response routes use Direct evaluation at q=0 and require their documented positive temperature and broadening. The independent zero-temperature intrinsic Hall task retains uniform integration; nonorthogonal THG and affine-region adaptive integration remain unsupported. See [adaptive integration](ADAPTIVE_INTEGRATION.md) for supported routes and error conventions.
- **Concurrent MPI rule evaluation:** multiple nodes within one cubature rule can execute concurrently, including THG, while rank zero retains one global refinement tree, error norm and budget. The full supplied domain is evaluated without adaptive symmetry reduction. Embedded error estimates are diagnostics, not convergence guarantees. A budget-limited result is retained with a warning; independent mesh/cutoff and narrow-feature checks remain necessary.

## Fixes and numerical corrections

- **Photon-drag optical links**: PDIC and PDSC on the orthogonal Wannier Hamiltonian/position route now use the first-order optical momentum link built from the raw position connection, including all nonzero momentum directions and the required endpoint convention transforms. This removes the historical center-only treatment from the ordinary finite-q path without adding an input switch.

The existing complete finite-q response expressions remain in use. The repair does not extend nonorthogonal finite-q support or imply accuracy beyond the optical input's stated first-order scope. Historical center-only results should not be treated as validation of the corrected path.

## Breaking changes and migration

- **Replace retired numerical constructors with `Numerics`**: All tasks now use `Numerics(...)`. `OpticalNumerics`, `GeometryNumerics`, `SHGNumerics`, `BandNumerics`, `LinearResponseNumerics`, `OrbitalNumerics` and `FermiSurfaceBroadening` have been removed, with **no compatibility aliases**. Optical linewidth, low-frequency broadening, intermediate-state regularization, spectral-gap tolerance and Fermi-surface controls remain independent.

See [Numerical controls](NUMERICAL_CONTROLS.md) for replacements. THG uses the documented distribution-broadening prescription; removed causal selectors are not silently reinterpreted.

## Scope and known limitations

General k-dependent bases and nonorthogonal finite-q response are not introduced by this release. Jerk/THG degeneracy handling, close-gap diagnostics and supported operator combinations retain their documented restrictions. Software tests do not establish material convergence or production eligibility, and saved tutorial results retain their original calculation identities.

## Documentation and verification

See the package documentation for [third-order responses](THIRD_ORDER_RESPONSES.md), [user-defined models](NATIVE_MODELS.md), [nonorthogonal inputs](NONORTHOGONAL_LOCALIZED.md), [TOML/CLI usage](TEXT_INPUT.md) and [finite-q optical links](FINITE_Q_OPTICAL_LINKS.md).

Use `SOURCE_MANIFEST.tsv` and `SHA256SUMS` for source verification. Full checksums and source-specific validation records belong in the accompanying verification materials, not in this release narrative. Download links will be added when the release is published.
