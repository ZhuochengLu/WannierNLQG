# BCD and BCQ geometry and DC Hall integrals

`BCDK` and `BCQK` remain Conventional K-slice tasks. Omitting
`derivative_backend` preserves their finite-difference defaults: step
`1e-4 Å⁻¹`, positive denominator regularization `0.001 eV`. An explicit
`derivative_backend=:analytic` selects central operator jets instead, with zero
denominator regularization. Explicit nonzero regularization or a supplied
finite-difference step is rejected in that analytic mode. There is no automatic
backend fallback.

The analytic implementation differentiates smooth raw H and position-connection
operators, never eigenvector phases or band sorting. TB derivatives use actual
Cartesian real-space displacements and the selected center convention.
`AnalyticKInput` supplies explicit derivatives or automatic derivatives of raw
callbacks. Missing position data are not filled with zero; only declared
point-orbital/fixed-orthonormal semantics justify a constant connection. General
nonzero connections consume A derivatives through order two for BCD and order
three for BCQ. Every required channel has a checked shape and finite/Hermitian
values.

The first analytic scope is orthogonal, isolated individual bands under Direct
evaluation, including complex spinor states with one contribution per explicit
state. Nonorthogonal high-order geometry, Projector registration, degenerate
subspace derivatives and band-crossing treatment are outside this extension.
The dense eigenframe recurrence additionally rejects a degenerate complementary
spectrum rather than silently dividing by zero; it does not establish general
isolated-target support in such a complementary block. Existing finite-difference
tasks retain their previous supported band/group behavior.

## Separate DC tasks

Use `BerryMultipoleParameters(fermi_energies=[...], temperature=...,
relaxation_time_fs=..., integral_form=...)`, a positive finite lifetime in fs,
temperature in K and chemical potentials in eV. `BCDC` and `BCQC` are independent
Conventional Integral tasks. `FullTensor()` or explicit rank-three/rank-four
`TensorComponents` selects the actual output channels.

| Task | Expression | Geometry consumed | Default backend |
| --- | --- | --- | --- |
| BCDC | `:fermi_surface` | Ω and ∂E | none; an explicit derivative backend is inapplicable |
| BCDC | `:fermi_sea` | local BCD | analytic; explicit finite differences remain available |
| BCQC | `:fermi_surface` | local BCD, once integrated by parts | analytic; explicit finite differences remain available |
| BCQC | `:fermi_sea` | local BCQ | analytic; explicit finite differences remain available |

The moments are D[ab;c]=∫f∂cΩ[ab] and Q[ab;cd]=∫f∂c∂dΩ[ab]. The BCDC
surface integrand is −f′Ω[ab]∂cE. BCQC surface uses
−f′((∂cE)∂dΩ[ab]+(∂dE)∂cΩ[ab])/2. A twice-integrated-by-parts expression
is an independent test oracle, not another public mode.

For positive temperature, surface tasks use the actual Fermi–Dirac derivative;
an explicit FS width is rejected. Zero-temperature surface tasks require
`Numerics(fs_kind=:gaussian, eta_fs_ev=...)` with an explicit positive width.
No width or contribution floor is inserted. Sea tasks at zero temperature use
the existing strict step occupation, including half occupation at exact equality.
Finite-width surface results need not equal strict-step sea results on a finite
grid. Width, denominator regularization, temperature and physical lifetime are
independent controls.

With e positive, current-last outputs obey

σ[bc;a] = e³τ(D[ab;c]+D[ac;b])/(2ℏ²),

σ[bcd;a] = −e⁴τ²(Q[ab;cd]+Q[ac;bd]+Q[ad;bc])/(3ℏ³).

These are DC Hall contributions only, not complete AC/Drude nonlinear responses.
The sign is tied to the existing negative linear-Hall prefactor.

## Domains, outputs and interpretation

BZMesh uses the actual unit-cell volume or sheet area. KRegion boxes and affine
regions use their actual Cartesian volume/area divided by (2π)^d. Tensor axes
remain three-dimensional independently of the integration dimension. Two-
dimensional conductivities are sheet values: BCDC A·m/V², BCQC A·m²/V³;
three-dimensional values are A/V² and A·m/V³. Moments use Å^(3−d) and Å^(4−d).
No effective thickness or spin factor two is inferred.

Finite regions are accepted without added boundary terms. Their files explicitly
warn that the finite-region integral contains no boundary correction, that
different integration-by-parts expressions need not agree within that region,
and that truncation and contributions outside the region require assessment. Periodic Cartesian regions are not silently folded or
renormalized to one Brillouin zone. Uniform integration reuses deterministic
lanes; box adaptive integration reuses the existing shared-budget cubature.
Affine adaptive integration remains unsupported by the common domain contract.
The research branch's separate coarse/broad/core local-refinement mesh and
refinement-file option are deliberately excluded from this interface. Global
`k_mesh`, derivative finite-difference steps and K-slice sampling remain separate
controls; none implicitly enables that local-refinement scheme.

Each task writes `<system>_bcdc_moments.dat` / `_conductivity.dat` or the BCQC
equivalents under its own task directory. Columns identify μ, T, tensor axes,
and values; conductivity rows also state τ. Headers retain units, expression,
requested/effective backend, derivative sources, width, regularization, measured
gap, domain/measure and the finite-region warning. Only computed channels are
written. Files and task IDs are not scientific qualification labels.

Examples are in `examples/tasks/integral/berry_curvature_*_conductivity_conventional.jl`.
The main named TOML task boundary uses these same parameters. Effective replay
explicitly records resolved defaults; original provenance continues to distinguish
omitted defaults from user-supplied values.

## Local conductivity slices

`BCDCK` and `BCQCK` select the conductivity slices; `BCDK` and `BCQK` continue to select local geometric derivatives. Use the existing `BerryMultipoleParameters` and `KSliceSelection(component=TensorComponent(...), bands=BandSelection())`. Components keep the field-first/current-last order. Direct Fourier evaluation and the existing orthogonal model, isolation and derivative-backend requirements apply. Multiple chemical potentials remain explicit in the output rows.

The slice reuses the selected Fermi-surface or Fermi-sea expression, occupations, lifetime and component contraction. It includes no mesh weight, cell division, plane area or `(2pi)^(-d)` factor. Local moment units are `Angstrom^3` for BCD and `Angstrom^4` for BCQ. Conductivity densities are `A*m^3/V^2` and `A*m^4/V^3`. Integrating with `d^d k_SI/(2pi)^d` gives the corresponding bulk/sheet units. For a complete periodic grid, use the weighted mean divided by the physical cell volume or sheet area in SI. The plane's two sample counts alone do not define that physical measure.

Files are `<system>_bcdck_moments.dat` / `_conductivity.dat` and the BCQ equivalents. Rows contain fractional `kx ky kz`, chemical potential, temperature, lifetime, explicit tensor axes and value. No pointwise FS/sea equality or finite-domain boundary correction is implied.
