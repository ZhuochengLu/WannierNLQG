# Jerk current and third-harmonic generation

Configure numerical controls with `Numerics(...)`. [Numerical controls](NUMERICAL_CONTROLS.md) describes the available settings. Numerical requests retain explicit keys separately from effective quantity defaults; effective kernels use concrete worker-local settings.

See [Jerk](#jerk-current), [THG](#third-harmonic-generation), [measures and limitations](#measures-boundaries-and-qualification), and [conclusion formulas](#conclusion-formulas-and-conventions).

## Jerk current

Task identifiers: `jerk_current`, `JC` / `JCK`.

Jerk Integral and KSlice share `BandSelection(groups=[[...],[...]])`, ordered source then target. Omitted groups retain the total response in the effective numerical window. Two groups select only positive-energy absorption pairs from the source into the target; the reverse direction is not added. Dipoles, Hessians and all virtual intermediate-state sums still use the full model. For example, `groups=[[1,2],[3,4]]` sums four external pairs, subject to the original energies, occupations and resonance weights; it does not emit four separate response files. The implemented quantity remains the acceleration channel below.

Numerical window boundaries close existing numerically equal levels without a new user threshold. Explicit groups remain unchanged; a selected band outside the effective window is an error suggesting a larger `band_window_size` or `-1`. A partial numerical level is allowed for Conventional Jerk with a basis-dependence warning. Diagnostics record requested/effective windows, selected groups and evaluation counts. This adds no block dynamics or energy averaging. The original `degeneracy_threshold` input remains unsupported for Jerk. THG still rejects explicit groups.

`JerkParameters(photon_energies=[1.0],fermi_energy=0.,temperature=0.)` selects finite nonnegative photon energies and the lifetime-free material coefficient. Zero eV is accepted by the same public runtime; negative, NaN and infinite energies are rejected. This does not introduce a separate metallic Drude or DC transport model. Broadening and denominator regularization remain positive. Defaults are Gaussian optical broadening 0.040 eV, transition window factor 5, `denominator_regularization=0.001` eV and the full optical band window. The fixed ordered slots are `(a,b,c,d)` with `(b:+omega,c:-omega,d:0)`. The complete product of optical dipoles, occupation difference and band-Hessian difference is retained. Integral defaults to 81 complex `G_ordered` components. `projection=:symmetric` or `:antisymmetric` projects the two optical indices; no input permutation average is applied to ordered jerk.

Both dipole eigenvector rotations and the Hessian use the same finite, positive regularization `P_eta(delta)=delta/(delta^2+eta^2)`. The Hessian is `real(C[n,n,a,d])+2real(sum(B[n,l,a]*B[l,n,d]*P_eta(e[n]-e[l])))`, with all other model bands in the sum. An optical `band_window_size` never trims that sum. There is no strict mode. General degeneracies remain diagnostic. The bulk SI prefactor is `2pi*e^4/hbar^3 * 1e-10/volume_angstrom3`; there is no additional spin or conjugate-order factor. A steady-state constant-rate model multiplies this material coefficient externally by `tau_N*tau_J`.

## Third-harmonic generation

Task identifiers: `third_harmonic_generation`, `THG` / `THGK`.

`THGParameters(photon_energies=[0.,1.0],fermi_energy=0.,temperature=300.)` defaults to `formulation=:regrouped`, `response=:both` and `output=:both`. Independent optimized `:unregrouped`, `:regrouped`, and `:both` selections are available. Integral averages the six input permutations and defaults to 30 components; the output direction is fixed. `TensorComponents(TensorComponent(1,1,1,1),...)` selects a nonempty, ordered subset. KSlice requires one energy and one component. KSlice values are the local density of the integrated-by-parts formula, and periodic full-BZ averaging recovers Integral.

Unregrouped terms: `eee`, `iee_group`, `iie_group`, `iii`. Regrouped terms: `regular`, `linear_pole`, `quadratic_pole`, `cubic_pole`. Each total is summed from its own stored terms. The quadratic-pole field is retained, including components for which an input average cancels it. Susceptibility preserves the source conductivity term classification.

The sole current frequency prescription is `:distribution_broadening`. Defaults are Gaussian `broadening=0.025`, `low_frequency_broadening=0.025`, `intermediate_regularization=0.001` eV, `eta_correction=true` and `occupation_derivative_mode=:shg_gaussian`. All applicable matrix and frequency widths are finite and positive. Resonance and low-frequency widths retain their separate meanings. `:fermi_dirac` selects exact FD occupation derivatives; the default retains FD values and the existing Gaussian derivative approximation.

Orthogonal outer vertices use `r0=A+i*h*I0(d)` and intermediate vertices use `r_eta=A+i*h*d/(d^2+eta^2)`, where `d=E_m-E_n`. The bare position inverse is zero strictly for `abs(d)<1e-7` eV and `1/d` otherwise, including equality. The complete literature derivative numerator, including its eta correction once, is combined before the external cutoff: `Gcut=R+I0*Q`. Raw A and finite R remain at the cutoff. Products such as `d*Gcut` retain the `d*I0` mask. This is the explicit numerical vertex approximation, not an exact degenerate derivative or a change to independent physical transition denominators or projector dP.

Frequency-resolvent derivatives use the actual Gaussian/Lorentzian derivative; Gaussian derivatives are not replaced by G^2. Pure pole degree p uses `(P-i*delta)*P^(p-1)`, with no pi in this low-frequency kernel. Susceptibility lowers each degree separately with `i/3` and one extra pure pole. It is not formed by dividing an already broadened spectrum by real frequency. Finite-width and cutoff differences between formulations remain explicit diagnostics; no cross-formulation causal identity is imposed on these numerical rules.

```julia
Numerics(prescription=:distribution_broadening, broadening=0.025,
         low_frequency_broadening=0.025, intermediate_regularization=0.001,
         eta_correction=true, occupation_derivative_mode=:shg_gaussian)
```

New inputs explicitly reject the removed `:causal` and old `:shg_compatible` selectors. Sealed historical requests keep their original source and semantics. The old causal three-band benchmark is retained verbatim as historical fixture text; it does not qualify this prescription. Current tests use uncontracted A4 band sums, the scalar-band Boltzmann coefficient, phase/selection checks and the independent positive-width BCQ limit. Close gaps are diagnostic; no extra amplitude-dependent hard stop is added. General degenerate-subspace dynamics is not implied by the cutoff. Production contractions are cubic in band count, with quadratic worker scratch and no four-band temporary tensor. No extra factor 8 or spin degeneracy is added. Bulk conversion factors are `e^2/hbar*1e-10/volume_angstrom3` (conductivity, A*m/V^3) and `e/epsilon0*1e-10/volume_angstrom3` (susceptibility, m^2/V^2).

## Measures, boundaries and qualification

JC and THG have no response-layer measure selector. TOML and Julia inputs explicitly reject the removed `response_measure`, `sheet_axes` and `effective_thickness_angstrom` fields, including an explicit old bulk selection. Periodic integration and slice densities retain normalization by the original three-dimensional reference-cell volume. The slice contains no sample-count weight. For a periodic sheet, postprocessing multiplies bulk by the normal height `abs(det(L))/norm(cross(ai,aj))` in metres; a chosen effective bulk additionally divides by an explicitly stated physical thickness. Oblique cells use the cross-product area. Convert an adaptive absolute tolerance by the same factor when migrating an old sheet/effective-bulk task; relative tolerance is dimensionless. Each explicit model state is counted once.

Periodic Wannier files, real-space TB and analytic inputs support their existing third-order kernels on selected Cartesian KRegion domains. Nonperiodic continuum integrals execute with a warning: formulas derived using periodic-BZ/integration by parts contain no finite-boundary correction. Actual domain, model periodicity, measure and units are recorded; users assess truncation and outside contributions. Periodic patches use the original BZ fraction and original-cell prefactor. Existing complete 3x3 nonperiodic model declarations retain their original finite-region measure and units. New direct 1D/2D model inputs instead use the model-layer one-Angstrom auxiliary completion and reference-volume normalization, without adding integration axes; see [direct low-dimensional inputs](NATIVE_MODELS.md#direct-low-dimensional-physical-inputs). Automatic third-order symmetry reduction remains unimplemented; region/adaptive execution instead evaluates the full selected domain and discloses an unused artifact. Missing actual operators or an undefined response remain hard errors. See [adaptive integration and Fourier/domain planning](ADAPTIVE_INTEGRATION.md). Scientific model tests, whole-package engineering tests and real-material convergence are separate qualifications. Numerical diagnostic files record gap counts, the minimum gap, velocity/dipole identity residuals, endpoint thresholds and policies.

## Conclusion formulas and conventions

Use the complex field amplitude, without a factor of one half,

```math
 E^b(\mathbf r,t)=E^b(\omega)e^{i\mathbf q\cdot\mathbf r-i\omega t}
                 +E^b(-\omega)e^{-i\mathbf q\cdot\mathbf r+i\omega t},
 \qquad E^b(-\omega)=E^b(\omega)^*.
```

This is the field convention of the [WannierNLQG paper](https://arxiv.org/html/2609.10411v1) and the [photon-drag paper](https://arxiv.org/html/2511.16987v2). The third-order tasks here use spatially uniform fields. The papers' factor collecting the two conjugate second-order frequency orders does not fix a third-order permutation factor. Cartesian tensor indices below are ordered; repeated Cartesian indices denote contraction with the indicated field slots. Each explicit model state is counted once, without an extra spin multiplier. Let $`e>0`$, $`x=\hbar\omega`$ in eV and $`\sum_{\mathbf k}w_{\mathbf k}=1`$ for a full uniform Brillouin-zone average. A restricted domain retains its actual integration weights rather than being renormalized to the full zone.

### Implemented Jerk acceleration channel

For the ordered slots $`(a;b\omega,c{-\omega},d0)`$, the raw coefficient is

```math
 \widetilde G^{abcd}(x)=\sum_{\mathbf k}w_{\mathbf k}
 \sum_{\substack{m,n\ \epsilon_n>\epsilon_m}}
 (f_m-f_n)\,r^b_{nm,\eta}r^c_{mn,\eta}
 (h^{ad}_{n,\eta}-h^{ad}_{m,\eta})
 \delta_\gamma(\epsilon_n-\epsilon_m-x).
```

Here $`r`$ is in Angstrom, $`h^{ad}_{n,\eta}`$ is the regularized band Hessian in eV Angstrom squared, and $`\delta_\gamma`$ has units of inverse eV. The chosen optical band window and transition-screening rule apply to the pair sum; the Hessian retains all model bands. With band-frame first and second source derivatives $`B,C`$, its numerical prescription is

```math
 h^{ad}_{n,\eta}=\mathrm{Re}\,C^{ad}_{nn}
 +2\mathrm{Re}\,\sum_{l\ne n}B^a_{nl}B^d_{ln}
 \frac{\epsilon_n-\epsilon_l}{(\epsilon_n-\epsilon_l)^2+\eta^2},
 \qquad \eta>0.
```

For the bulk cell volume $`V_{\!A}`$ in Angstrom cubed, the output is

```math
 G^{abcd}_{\mathrm{ordered}}=
 \frac{2\pi e^4}{\hbar^3}\frac{10^{-10}}{V_{\!A}}
 \widetilde G^{abcd}.
```

It is the lifetime-free coefficient, in A m V$`^{-3}`$ s$`^{-2}`$. The selected steady-state constant-rate interpretation is $`j^a=\tau_N\tau_JG^{abcd}_{\mathrm{ordered}}E^b(\omega)E^c(-\omega)E^d(0)`$. No additional conjugate-order factor, six-permutation factor or lifetime is applied by the task. Symmetric/antisymmetric output replaces the optical product by its half-sum/half-difference under $`b\leftrightarrow c`$.

[Fregoso, Muniz and Sipe, *Jerk current: A novel bulk photovoltaic effect*, arXiv:1804.03970v2, Eq. (5)](https://arxiv.org/html/1804.03970) contains both acceleration and a velocity-difference times the momentum derivative of the optical-product contribution. The present task evaluates only the acceleration channel displayed above. It must not be identified with the general two-term expression. The paper's Eq. (3) uses a symmetrized tensor and a factor of six; that convention is not an extra multiplier for this ordered output. No missing channel is supplied by the SI conversion or permutation code.

### THG response and finite-width prescription

The macroscopic definitions, with the output direction fixed, are

```math
 j^a(3\omega)=\sigma^{abcd}(3\omega;\omega,\omega,\omega)
 E^b(\omega)E^c(\omega)E^d(\omega),\qquad
 P^a(3\omega)=\epsilon_0\chi^{abcd}(3\omega;\omega,\omega,\omega)
 E^b(\omega)E^c(\omega)E^d(\omega).
```

Only the three input indices are averaged over six permutations, including repeated-index multiplicities. The length-gauge interband/intraband organization is described by [Aversa and Sipe, *Nonlinear optical susceptibilities of semiconductors: Results with a length-gauge analysis*, Phys. Rev. B **52**, 14636 (1995)](https://doi.org/10.1103/PhysRevB.52.14636). This reference supplies the framework, not an assertion that its clean-limit formulas specify every finite-width rule of this implementation.

To state the actual numerical conclusion compactly, let $`C^{a\pi(bcd)}_{\alpha p}(x,\mathbf k)`$ denote the kernel's raw band-sum coefficient for term $`\alpha`$ and pole degree $`p=0,1,2,3`$, before input permutation averaging and SI conversion. The unregrouped term labels are `eee`, `iee_group`, `iie_group`, `iii`; the regrouped labels are `regular`, `linear_pole`, `quadratic_pole`, `cubic_pole`. The two formulations retain their own coefficients and totals. Their implemented contraction and observable conversion are

```math
 \sigma^{abcd}=\frac{e^2}{\hbar}\frac{10^{-10}}{V_{\!A}}
 \sum_{\mathbf k}w_{\mathbf k}\frac{1}{6}
 \sum_{\pi\in S_3}\sum_{\alpha,p}C^{a\pi(bcd)}_{\alpha p}L_p(x),
```
```math
 \chi^{abcd}=\frac{e}{\epsilon_0}\frac{10^{-10}}{V_{\!A}}
 \sum_{\mathbf k}w_{\mathbf k}\frac{1}{6}
 \sum_{\pi\in S_3}\sum_{\alpha,p}
 \frac{i}{3}C^{a\pi(bcd)}_{\alpha p}L_{p+1}(x).
```

These are conductivity in A m/V cubed and susceptibility in m squared/V squared. The coefficients already contain the kernel's factor eight; no further factor eight or spin factor is inserted. For the selected Gaussian or Lorentzian $`\delta_\lambda`$, the pure-frequency pole rule is

```math
 L_0(x)=1,\quad P_\lambda(x)=\frac{x}{x^2+\lambda^2},\quad
 L_p(x)=[P_\lambda(x)-i\delta_\lambda(x)]P_\lambda(x)^{p-1}\quad(p\ge1).
```

Resonant band factors use, for $`y=\Delta-sx`$,

```math
 R_s(x,\Delta)=-\frac{y}{y^2+\gamma^2}-i\pi\delta_\gamma(y),\qquad
 \partial_\Delta R_s=\frac{y^2-\gamma^2}{(y^2+\gamma^2)^2}
                    -i\pi\delta'_\gamma(y),
```
```math
 \delta_\gamma^{\mathrm{Gaussian}}(y)=\frac{e^{-(y/\gamma)^2}}{\sqrt\pi\gamma},
 \qquad
 \delta_\gamma^{\mathrm{Lorentzian}}(y)=\frac{\gamma}{\pi(y^2+\gamma^2)}.
```

Thus `distribution_broadening` lowers susceptibility degree by degree. It does not divide an already broadened conductivity by the real frequency, nor replace Gaussian resolvent derivatives by a squared resolvent. The finite matrix width, resonant width and low-frequency width remain distinct. The positive-width and outer-vertex cutoff prescriptions above are numerical approximations, without a claim of exact degenerate-subspace dynamics or finite-width equality between the two formulations. These formulas describe the current implementation; no derivation or additional independent validation is introduced here.

#### Explicit unregrouped coefficient contractions

The direct band-sum reference is [Hipolito, Taghizadeh and Pedersen, *Nonlinear optical response of doped monolayer and bilayer graphene: Length gauge tight-binding model*, Phys. Rev. B **98**, 205420 (2018), Appendix A4a–d](https://doi.org/10.1103/PhysRevB.98.205420) ([arXiv:1802.01430v3](https://arxiv.org/abs/1802.01430v3)). The reference's causal frequency rule is not the `distribution_broadening` rule below. Its citation does not establish absolute-normalization or finite-width equivalence.

For one ordered kernel component $`(\phi,c,b,a)`$, the following gives the actual unregrouped coefficients without a derivation. Write $`d_{mn}=\epsilon_m-\epsilon_n`$, $`F_{mn}=f_n-f_m`$, $`F^a_{mn}=\partial_a f_n-\partial_a f_m`$, and similarly $`F^{ab}_{mn}`$. Let $`t^a_{mn}=i r^a_{0,mn}`$ off diagonal and zero on diagonal; $`v^\phi`$ and $`\partial_c v^\phi`$ are the prepared velocity and its derivative, $`g_n^a=\partial_a\epsilon_n`$, and $`h_n^{ab}`$ is the prepared Hessian. The following primes on $`R_s`$ mean its actual signed-gap derivative.

```math
 Y_{mn}=t^a_{mn}F_{mn}R_1(x,d_{mn}),
```
```math
 D_{mn}=\big[iF_{mn}G^{ab}_{{\mathrm{cut}},mn}+t^a_{mn}F^b_{mn}\big]R_1
       +t^a_{mn}F_{mn}(g_m^b-g_n^b)R'_1,\quad
 Z_{mn}=R_2D_{mn},\quad J_{mn}=R_2t^b_{mn}F^a_{mn}.
```

Here multiplication by $`F`$ uses the finite-numerator construction of $`G_{\mathrm{cut}}=R+I_0Q`$ specified above; no extra singular division is implied. Define $`B=[t^b,Y]`$, with ordinary matrix commutators, and

```math
 (C_0)_{mn}=(1-\delta_{mn})R_2B_{mn},\qquad
 (C_1)_{mn}=\delta_{mn}B_{mn}/2,
```
```math
 (W_0)_{mn}=(1-\delta_{mn})v^\phi_{nm}R_3,\qquad
 (W_1)_{mn}=\delta_{mn}v^\phi_{nm}/3,
```
```math
 (U_0)_{mn}=(1-\delta_{mn})
 \big[(\partial_c v^\phi)_{nm}R_3+v^\phi_{nm}(g_m^c-g_n^c)R'_3\big],\qquad
 (U_1)_{mn}=\delta_{mn}(\partial_c v^\phi)_{nm}/3.
```

Every $`R_s`$ here has arguments $`(x,d_{mn})`$. For the nonconjugating contraction $`\langle A,B\rangle_0=\sum_{mn}A_{mn}B_{mn}`$, introduce a formal variable $`z`$, $`W(z)=W_0+zW_1`$, $`U(z)=U_0+zU_1`$ and $`C(z)=C_0+zC_1`$. The four conclusion polynomials $`\mathcal C_\alpha(z)=\sum_{p=0}^3C_{\alpha p}z^p`$ are

```math
 \mathcal C_{eee}(z)=-i\langle W(z),[t^c,C(z)]\rangle_0,
```
```math
 \mathcal C_{iee}(z)=-i\langle U(z),C(z)\rangle_0
                    +i\langle W(z),[t^c,Z+zJ]\rangle_0,
```
```math
 \mathcal C_{iie}(z)=i\sum_{m\ne n}
 \left[(U_0)_{mn}R_2D_{mn}
 +z(U_0)_{mn}R_2t^b_{mn}F^a_{mn}
 -\frac{z^2}{2}(W_0)_{mn}t^c_{mn}F^{ab}_{mn}\right],
```
```math
 \mathcal C_{iii}(z)=-\frac{iz^3}{6}\sum_n h_n^{\phi c}\partial_a\partial_b f_n.
```

Extract each coefficient in $`z`$ and use the $`L_p`$, six-permutation and SI formulas above; $`z`$ is a formal collection variable, not a frequency value. The exact implementations are the [vertex definitions](../src/Responses/ThirdHarmonicGeneration/ThirdHarmonicWorkspace.jl), [unregrouped coefficient contractions](../src/Responses/ThirdHarmonicGeneration/ThirdHarmonicUnregrouped.jl), [regrouped contractions](../src/Responses/ThirdHarmonicGeneration/ThirdHarmonicRegrouped.jl), and [permutation and observable conversion](../src/Responses/ThirdHarmonicGeneration/ThirdHarmonicKernels.jl). The [test-only literal band sums](../test/support/ThirdHarmonicLiteralReference.jl) retain the direct A4 labels and the explicitly declared numerical frequency rule. The displayed polynomials specify the unregrouped output; finite-width regrouped outputs keep their own contractions rather than being asserted identical.

## THG worker numerator storage

Band gradients/Hessians are prepared before occupation derivatives. The THG worker then stores finite R and complete Q, rather than full G and iG tensors. The same shared optical producer computes Q and its optional correction once; DG, FG and P-weighted combinations apply the signed factor before the numerator. Zero factors and the I0 cutoff never multiply an unneeded Q by zero after a divergent division. Same-occupation pairs remain available to DW/C0 and third-band terms; there is no global occupation mask on derivative preparation.

The default expert `ThirdOrderGeometry(n)` still has literal G/iG. A `ThirdHarmonicWorkspace` has combined R/Q storage instead; its literal G/iG fields are `nothing`, with no alias to another role. Manual expert consumers call `prepare_third_order_band_geometry!`, compute their occupations, and then `prepare_third_order_combined_geometry!` for the same endpoint and matrix width. Use a separate default expert geometry when literal G is needed for inspection.

Each THG worker owns a bounded scalar cache keyed by ordered energies and the actual static width. Bare position inverses use ket-minus-bra gaps; independent static frequency factors use bra-minus-ket gaps. Consumers pass their actual signed factors explicitly. No occupation or frame-dependent matrix enters this scalar cache, and a failed refill invalidates its old key. Two unused complex scratch matrices are replaced by three real scalar tables; derivative tensor payload remains three arrays in either geometry storage role.

## THG band and numerator preparation

THG prepares band gradients/Hessians, computes occupation derivatives, and only then builds finite R and complete Q with the shared optical producer. Its worker stores R/Q in place of full G/iG, with the same three derivative tensor payloads including DV. The default expert `ThirdOrderGeometry(n)` still exposes literal G/iG; `ThirdHarmonicWorkspace` uses `Val(:combined)` storage with explicit `finite_literature_derivatives` and `literature_derivative_numerators` fields. Its literal G/iG fields are `nothing`, with no semantic aliases.

Each consumer assembles its combination as `factor*R+(factor*I0)*Q`, branching on zero factor/I0 before Q products. Factors include d, occupation differences and signed P_eta times f/f_a. Same-occupation pairs are not masked globally because DW/C0 can couple through a third band. Position gaps are ket-minus-bra; the independent static frequency gap is bra-minus-ket. Consumers pass that actual sign explicitly. PG here is a weighted literature derivative, not d(r_eta).

A bounded scalar cache per worker stores I0 and the independent static P/P' with ordered-energy/static-width keys. Failed refills invalidate the key. It stores no occupations or frame-dependent matrices. Three real scalar tables replace two unused complex scratch matrices. Resonance and occupation changes still recompute their actual prefix factors; finite-width formulations keep separate outputs and diagnostic differences.

Jerk runtime workers store only their regularized dipoles, band gradients and full-band Hessians plus diagnostics in `JerkCurrentGeometry`. They share the same band/Hessian and dipole producers with the literal expert geometry, while avoiding unconsumed G, ratio and velocity-derivative tensors. The default `ThirdOrderGeometry` expert constructor and its literal fields are retained.

## Retired third-order degeneracy parameter

Jerk and THG do not accept `degeneracy_threshold`, including values explicitly inherited from `[response.numerics]`. Such inputs report that the parameter is unsupported for the named third-order task; it is not converted to a width. Task-local uses by SHG, geometric methods and other applicable responses retain their existing meanings. The third-order near-gap counter and threshold metadata are removed. Independent minimum-gap and fixed `abs(gap)<1e-12` diagnostic counts remain descriptive and introduce no response cutoff or block treatment.

Threshold retirement itself does not change dipoles, Hessians, occupations, resonances or selected bands. The independently approved Jerk occupation update is specified below.

## Jerk occupation aligned with ordinary injection current

Jerk now calls the same `Core.fermi_dirac!` as ordinary IC: `theta=kB*T`, with the shared Core constant `kB=8.617333262e-5 eV/K`. If the computed `theta` is zero, `E<=mu` has occupation one and `E>mu` zero. Otherwise `f=1/(1+exp(clamp((E-mu)/theta,-700,700)))`. This includes the existing IC fallback if a positive subnormal temperature makes `kB*T` underflow to zero; there is no newly imposed temperature floor.

The old Jerk `T<=1e-7 K` step is removed. At a positive temperature with nonzero `theta`, an exact Fermi-level state has occupation one half. At strictly zero T its existing occupation remains one. Above the old switch the mathematical FD form is retained, but the shared constant, clamping and arithmetic can change last bits and very small tails. The observable therefore need not be byteequal to old positive-temperature Jerk results. No TOML/API control is added.

THG and SHG retain their existing occupation values, low-temperature switch and derivative modes. Jerk's output metadata identifies `core-fermi-dirac/1` and marks occupation derivatives not applicable. This change adds no block dynamics, energy averaging, new screening, width, lifetime or tensor normalization.
