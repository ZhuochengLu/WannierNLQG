# Second-harmonic generation

SHG evaluates the independent-particle length-gauge response at output frequency
2 omega. `SHGParameters` selects complex susceptibility (pm/V), conductivity
(A/V^2), or both. The two quantities use separate finite-broadening expressions;
one is not obtained by multiplying the other by a complex frequency.

```julia
task = TaskSpec(
    id = "shg",
    quantity = "second_harmonic_generation", # SHG for integral, SHGK for a slice
    method = "Conventional",
    physics = SHGParameters(
        photon_energies = 0.0:0.02:2.0,
        fermi_energy = 0.0,
        temperature = 0.0,
        output = :both,       # :total (default), :terms, :both
        response = :both,     # :susceptibility, :conductivity, :both (default)
    ),
    numerics = SHGNumerics(),
    observable = FullTensor(),
)
```

Use this task in the existing `TaskConfig` and `run` API. `BZMesh` integrates;
`KSlice` requires one photon energy and
`KSliceSelection(component=TensorComponent(2,1,1), bands=AllBands())`.
Use `spatial_dimension=3`, including for a two-dimensional sampling plane.
All model bands participate, including every intermediate band of the three-band sum.
The input model contains explicit electronic states: the normalization uses one
electron per state. A spinor model must not receive a further factor of two.

## Numerical controls

| SHGNumerics field | Default | Reference input meaning |
|---|---:|---|
| `broadening` | 0.025 eV | `smr_fixed_en_width` |
| `broadening_type` | `"Gaussian"` | `kubo_smr_type` |
| `low_frequency_broadening` | 0.025 eV | `smr_gamma` |
| `intermediate_regularization` | 0.04 eV | `sc_eta` |
| `eta_correction` | `true` | `sc_use_eta_corr` |
| `degeneracy_threshold` | 1e-4 eV | `degen_thr`, BCD adjacent-band filter |

Gaussian and Lorentzian resonance kernels are supported. Gaussian means
`exp(-(E/width)^2)/(sqrt(pi)*width)`. The low-frequency kernels retain the
principal-value and delta combination of the reference implementation, not a
single analytic complex-frequency denominator. Adaptive resonance smearing is
not part of this interface.

At `temperature <= 1e-7` K, occupations are a step function and both one-band
terms are skipped, exactly as in the reference temperature switch. No positive
surrogate temperature or extrapolation is applied. This is incomplete for a
strictly zero-temperature metal. Above the threshold, occupations are Fermi--Dirac;
one-band occupation derivatives retain the Gaussian approximation with a 5 kBT
cutoff. These numerical approximations require separate material qualification.

## Output contract

Integral writes 18 independent Cartesian components, with incident-field pair order
`xx, yy, zz, yz, xz, xy` for each output axis `x, y, z`. Filenames are
`shg_chi_abc.dat` and `shg_sigma_abc.dat`. Headers identify units and every column.
Integral rows begin with photon energy in eV. Slice rows begin with fractional
`kx ky kz` and photon energy. Each complex value has real and imaginary columns.

The seven terms, in output order, are:

1. `interband_derivative`
2. `interband_velocity`
3. `three_band`
4. `transport_derivative`
5. `transport_velocity`
6. `berry_curvature_dipole`
7. `semiclassical`

Totals are the sum of the same seven contributions. The first five correspond
to the algebraic groups called ter-shift, ter-inject, ter-3bs, tra-shift and
tra-inject in the local reference decomposition. Individual terms are not
asserted to be independent observables.

A slice is the density of the implemented BZ-integrated formula. Some literature
terms have been integrated by parts; their original pointwise integrands need
not equal this density. The arithmetic mean on a complete uniform BZ recovers
the integral. A general plane is not a BZ integral. No slice k-point weight is
included in the written values.

## Reference and qualification

The two- and three-band kernels are compared with an independently compiled
extraction of Wannier90 PR #449, commit
`907008d5aa9cbacf888d470c6b5aad3beb40bc04`. Frozen synthetic numerical outputs
are regression fixtures; the upstream Fortran is not vendored in the package.
The BCD term instead uses full Berry curvature and the antisymmetric Cartesian
contraction required by Eq. (22b), correcting the reference array-index error.

References: Garcia-Goiricelaya et al., PRB **107**, 205101 (2023), corrected
Eq. (22a); Lihm, PRB **103**, 247101 (2021), Eq. (19). Package tests and agreement
with a prior spectrum do not establish k-mesh, broadening, Wannier-window or
near-degeneracy convergence of a material.

`quantity="SHG"` accepts both `BZMesh` and `KSlice`; `SHGK` remains a slice-specific shorthand. Mixed slice interpolation uses logical mesh indices, including for shifted or oblique commensurate planes.
