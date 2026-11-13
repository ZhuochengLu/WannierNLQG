# Numerical controls

Every task uses `Numerics(...)`. Compilation resolves quantity-specific defaults
before model IO and records explicit and effective values separately. Unknown,
invalid and inapplicable controls are rejected for the actual task and method.
A shared request does not override each response's own supported parameter set.

```julia
Numerics(broadening=0.06, denominator_regularization=0.001)
Numerics(broadening=0.025, low_frequency_broadening=0.025,
         intermediate_regularization=0.04, eta_correction=true)
```

Optical resonance width, low-frequency resolution, geometric regularization,
intermediate-state regularization and Fermi-surface quadrature have distinct
roles. Physical `SeparateRelaxation` belongs to the physical response parameters.
Use the task-specific documentation rather than applying one width or threshold
to every formula. In a mixed task input, an explicitly inherited unsupported
parameter is still an error for the affected task.

## Response-specific rules

- AHC uses each real level with `E <= mu` and the direct bare `V / delta` ratio for
  every nonzero gap. It has no occupation-group threshold and rejects
  `degeneracy_threshold`; nonfinite arithmetic is reported.
- ISC and SSC require positive finite `denominator_regularization` in eV, default
  `0.001`. The matrix-element layer prepares the smooth connection and its
  complementary Hamiltonian-derivative weight together. Explicit
  `degeneracy_threshold` is unsupported for these tasks.
- OM requires positive finite `denominator_regularization`, default `0.001` eV,
  and rejects `gap_tolerance`. Actual energies and occupations are retained.
  A zero-temperature Fermi boundary averages the two complete occupied-subspace
  limits; positive-temperature thermal convolution keeps its own contract.
- Jerk and THG reject `degeneracy_threshold`. Jerk shares the ordinary injection
  occupation helper at every computed nonzero thermal energy. At exactly zero
  temperature, equality with the Fermi energy remains occupied.
- Conventional nonorthogonal linear optics uses positive geometric regularization,
  default `0.001` eV; this is independent of optical relaxation.
- SHG uses positive finite geometry/intermediate widths. Nonorthogonal geometry
  and three-band intermediate widths remain independent. Nonorthogonal
  `eta_correction=true` is unsupported. BCD isolated-band selection affects BCD
  only, not all terms for that band.
- Applicable scalar-geometry zero-width branches and the internal Quantum Metric
  default are limited to their documented tasks and operator requirements.

## Expert third-order storage

`ThirdOrderGeometry(n)` owns literal G/iG. THG workers use
`ThirdOrderGeometry(n, Val(:combined))`, retaining finite R and complete Q without
allocating full G/iG. These storage roles do not reinterpret a derivative of the
regularized position as the cutoff generalized derivative.

Manual consumers prepare band geometry, occupation derivatives and combined
optical geometry in that order using `prepare_third_order_band_geometry!` and
`prepare_third_order_combined_geometry!` for the same endpoint and width. A THG
worker's `dipole_derivatives` and `ratio_derivatives` are `nothing`; consumers
needing literal G use a separate default geometry. Ordered-energy/width changes
refresh the scalar-gap cache; occupation and resonance have separate roles.

Positive-width inverse and complementary factors retain their prescribed
arithmetic. Scaled evaluation handles underflow or overflow of intermediate
squares where the final value is representable; widths are not floored. This
cannot make an unrepresentable higher derivative finite.

See the response theory chapters and [interface contracts](../API_BREAKING_CHANGES.md)
for physical limits and output identity requirements. Package checks do not
establish material convergence or production qualification.
