# Injection Current

## 1. Definition and physical picture

Injection current arises when photoexcited carriers are injected at unequal rates in opposite directions. Microscopically, its weight is the optical transition probability multiplied by the group-velocity difference between the initial and final states. In an ideal system without scattering, the current grows with illumination time; momentum relaxation truncates this growth and establishes a steady state.

## 2. Core theoretical formula

The release reports the injection-rate tensor using ordered fields and a complete band-pair sum:

$$
\eta_{\mathrm{IC}}^{abc}(\omega)=
\frac{\pi e^3}{\hbar^2}
\int_{\mathrm{BZ}}[d\mathbf k]
\sum_{nm} f_{nm}\delta(\omega_{mn}-\omega)
\left(v_{mm}^{a}-v_{nn}^{a}\right)
r_{nm}^{c}r_{mn}^{b},
$$

with the scattering-free interpretation

$$
\frac{d j^a}{dt}
=2\sum_{bc}\eta_{\mathrm{IC}}^{abc}(\omega)
E^b(\omega)E^c(-\omega).
$$

Here $\eta_{\mathrm{IC}}^{abc}$ is one ordered-field contribution. The outer factor $2$ combines $(\omega,-\omega)$ with its conjugate ordering $(-\omega,\omega)$; it is not a $b\leftrightarrow c$ symmetrization. In the single-relaxation-time approximation,

$$
\sigma_{\mathrm{IC}}^{abc}=\tau\eta_{\mathrm{IC}}^{abc},
\qquad
j_{\mathrm{dc}}^a
=2\sum_{bc}\sigma_{\mathrm{IC}}^{abc}(\omega)
E^b(\omega)E^c(-\omega).
$$

The release therefore reports the $\tau$-free ordered contribution $\eta_{\mathrm{IC}}$. Formulas that absorb the conjugate ordering and relaxation time into a single displayed coefficient can instead show $2\tau\pi e^3/\hbar^2$; they give the same physical current only after all conventions are aligned.

## 3. Equivalent formulation

Using $v_{nm}^{a}=i(\epsilon_n-\epsilon_m)r_{nm}^{a}/\hbar$, the response can also be written in the velocity gauge:

$$
\eta_{\mathrm{IC}}^{abc}=
\frac{\pi e^3}{\hbar^2\omega^2}
\int_{\mathrm{BZ}}[d\mathbf k]
\sum_{nm} f_{nm}\delta(\omega_{mn}-\omega)
\left(v_{mm}^{a}-v_{nn}^{a}\right)
v_{nm}^{c}v_{mn}^{b},
$$

where $\omega_{mn}=\omega$ has been used on the resonant shell. The two forms express the transition strength in terms of position or velocity matrix elements, respectively.

## 4. Symbols and tensor indices

The index $a$ denotes the injection-current direction, while $b,c$ denote the ordered optical-field directions. The difference $v_{mm}^{a}-v_{nn}^{a}$ measures the group-velocity asymmetry of a transition from $n$ to $m$, and $r_{nm}^{c}r_{mn}^{b}$ determines the polarization selection rule. The symmetric part in $b,c$ primarily describes linearly polarized injection, whereas circular injection current is associated with the antisymmetric imaginary part.

## 5. Key limits, symmetries, and relations

- A time-reversal-symmetric system can support circular injection current, whereas its linearly polarized symmetric component is more strongly constrained.
- Spatial inversion forbids the second-order electric-dipole response.
- If $v_{mm}^{a}=v_{nn}^{a}$ for every resonant transition, the corresponding tensor component vanishes even when optical absorption is finite.
- The relaxation time $\tau$ is an external dynamical parameter that converts an injection rate into a steady-state current; it is not part of the local optical-transition geometry.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Second-order injection-rate tensor | Sipe–Shkrebtii (2000), injection-current part of Sec. III | Set the electron charge to $e<0$, rewrite the band indices as $f_{nm}\delta(\omega_{mn}-\omega)$, and keep the conjugate field ordering as the outer factor $2$ in the current |
| Length/velocity-gauge relation | Wang et al. (2017), nonlinear-response formula section | Use $v_{nm}=-i\omega_{nm}r_{nm}$ on the resonant shell |
| Steady-state $\tau$ form | Sipe–Shkrebtii (2000), relaxation discussion | The release stores one ordered injection-rate contribution; multiply separately by $\tau$ for $\sigma_{\mathrm{IC}}=\tau\eta_{\mathrm{IC}}$ |

## 7. References

1. J. E. Sipe and A. I. Shkrebtii, “Second-order optical response in semiconductors,” *Phys. Rev. B* **61**, 5337–5352 (2000). [DOI](https://doi.org/10.1103/PhysRevB.61.5337)
2. C. Wang, X. Liu, L. Kang, B.-L. Gu, Y. Xu, and W. Duan, “First-principles calculation of nonlinear optical responses by Wannier interpolation,” *Phys. Rev. B* **96**, 115147 (2017). [DOI](https://doi.org/10.1103/PhysRevB.96.115147)
