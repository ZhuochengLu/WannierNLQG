# Linear optical response: three frequency-dependent mechanisms

## 1. Definition and physical picture

The optical calculation exports complex `drude`, `quantum_metric`,
`berry_curvature`, and `total` conductivities. The Berry-curvature-named
channel is the frequency-dependent **anomalous-Hall-effect mechanism** of this
length-gauge model: ambient-curvature contact plus interband Hall response.
At nonzero frequency or relaxation width it is not a static Berry-curvature
field. Conventions, position operator, and SI prefactor $c$ are defined in
[linear transport](LinearTransport.md).

The Drude-like channel describes intraband current relaxation; the
frequency-dependent quantum-metric channel is the symmetric interband
geometric response. The frequency-dependent Berry-curvature channel is the
Hall-antisymmetric mechanism, composed of ambient contact plus dispersive
interband Hall response. It is an anomalous-Hall-effect (AHE) response
mechanism, not a pointwise static curvature field.

## 2. Core theoretical formula: Conventional bands

Write photon energy as $x=\hbar\omega$ in eV and
$z=x+i\Gamma_{\rm inter}$. For each ordered pair $E_n<E_m$, use
$f_{nm}$, $\Delta_{nm}$, and $Q^{ab}_{nm}=r^a_{nm}r^b_{mn}$ from the dc note.
For clarity, the ambient curvature is defined from the retained Wannier
(orbital) frame $|u_i^{\rm W}\rangle$ and its position connection
$A^{\rm W}_{a,ij}=i\langle u_i^{\rm W}|\partial_{k_a}u_j^{\rm W}\rangle$.
If $U^\dagger H^{\rm W}U=\operatorname{diag}(E_n)$, then

$$
\mathcal F_{ab}^{\rm W}
=\partial_{k_a}A_b^{\rm W}-\partial_{k_b}A_a^{\rm W}
-i[A_a^{\rm W},A_b^{\rm W}],\qquad
\mathcal F_{ab}^{\rm H}=U^\dagger\mathcal F_{ab}^{\rm W}U,\qquad
B_n^{ab}=\operatorname{Re}(\mathcal F_{ab}^{\rm H})_{nn}.
$$

Here $[X,Y]=XY-YX$, and the same position-operator and orbital-embedding
convention is used throughout. $B_n^{ab}$ is only the ambient contribution;
the full **static** band Berry curvature is
$\Omega_n^{ab}=B_n^{ab}-2\sum_{m\ne n}\operatorname{Im}Q_{nm}^{ab}$,
with the same $(a,b)$ and sign convention as the dc note.
The independent optical kernel retains resonant and antiresonant poles:

$$
\begin{aligned}
\sigma^{ab}_{\rm Drude}(x)
 &=c\sum_n\frac{-f'_n}{\Gamma_{\rm intra}-ix}
   \operatorname{Re}[V^a_{nn}V^b_{nn}],\\
\sigma^{ab}_{\rm QM}(x)
 &=-2ic\sum_{E_n<E_m}f_{nm}
   \frac{\Delta_{nm}z}{\Delta_{nm}^2-z^2}
   \operatorname{Re}Q^{ab}_{nm},\\
\sigma^{ab}_{\rm BC}(x)
 &=-c\sum_n f_n B_n^{ab}
   +2c\sum_{E_n<E_m}f_{nm}
   \frac{\Delta_{nm}^2}{\Delta_{nm}^2-z^2}
   \operatorname{Im}Q^{ab}_{nm},\\
\sigma^{ab}_{\rm total}(x)
 &=\sigma^{ab}_{\rm Drude}(x)+\sigma^{ab}_{\rm QM}(x)
   +\sigma^{ab}_{\rm BC}(x).
\end{aligned}
$$

The first summand of $\sigma_{\rm BC}$ is the frequency-independent ambient
contact term. The second is the complex, frequency-dependent interband Hall
term. Equivalently, with $\Delta_{nm}=|E_m-E_n|$ for $m\ne n$,

$$
\widetilde\Omega_n^{ab}(x,\Gamma_{\rm inter})
=B_n^{ab}-2\sum_{m\ne n}
\frac{\Delta_{nm}^2}{\Delta_{nm}^2-(x+i\Gamma_{\rm inter})^2}
\operatorname{Im}Q_{nm}^{ab},\qquad
\sigma_{\rm BC}^{ab}(x)=-c\sum_n f_n\widetilde\Omega_n^{ab}(x,\Gamma_{\rm inter}).
$$

Pairing the two directions of each interband pair recovers the preceding
implemented formula. Only this combined channel is exported as
`berry_curvature`. At $x=0$ it is the broadened dc response; only when
$x\to0$ and $\Gamma_{\rm inter}\to0^+$ for resolved gaps does
$\widetilde\Omega_n^{ab}\to\Omega_n^{ab}$ and the integrated conductivity
take the [usual intrinsic-AHE form](LinearTransport.md). At finite frequency
or width, $\widetilde\Omega_n$ is a possibly complex **AHE response kernel**,
not the static geometric Berry curvature. No resonance-only transition
window is imposed; a different
absorptive smearing prescription need not reproduce the same finite-width
complex spectrum. Exact degenerate blocks retain every intrablock velocity
product and every ordered cross-block pair; close distinct energies are not
averaged. With the same inputs, $x=0$ reduces to the
[strict dc expressions](LinearTransport.md) term by term.

## 3. Equivalent and Projector formulation

For each exact-energy spectral projector $P_I$, use block velocity trace
$W_I^{ab}$, ambient-curvature trace $B_I^{ab}$, and cross-block geometry
$Q_{IJ}^{ab}$ defined in the dc note. Replace the band sums above by
$\sum_I$ and $\sum_{I<J}$, with $E_I$, $f(E_I)$, and
$\Delta_{IJ}=E_J-E_I$. In particular,

$$
\sigma^{ab}_{\rm BC,Projector}(x)
=-c\sum_I f(E_I)B_I^{ab}
 +2c\sum_{I<J}[f(E_I)-f(E_J)]
 \frac{\Delta_{IJ}^2}{\Delta_{IJ}^2-z^2}
 \operatorname{Im}Q_{IJ}^{ab}.
$$

Drude and quantum-metric equations use the identical replacements. The
full-projector trace removes arbitrary rotations within an exact degenerate
block, but does not license near-degenerate averaging or silently fill
missing position-operator or embedding information.

## 4. Symbols, indices, and dielectric normalization

For positive photon energy, the unique fully integrated model dielectric
tensor is

$$
\epsilon^{ab}(x)=\delta_{ab}+
\frac{i\sigma^{ab}_{\rm total}(x)}{\epsilon_0\omega},\qquad
\omega=x/\hbar_{\rm eV\,s}.
$$

Each mechanism produces only its increment
$\Delta\epsilon_t=i\sigma_t/(\epsilon_0\omega)$; the unit background is
added **once**, to the integrated total. K-slice increments have units m³ and
no background. At $x=0$ conductivity is defined and compared with dc, but
dielectric files are omitted and metadata records `UNDEFINED_ZERO_FREQUENCY`.
Conductivity is in S/m after full-BZ integration and S m² as a K-slice
integrand. $a,b$ are current and applied-field Cartesian directions;
the photon argument $x=\hbar\omega$ and the two widths are in eV.
The optical table reports complex conductivity in a fixed column order
and has no additional spin factor for a spinor model.

## 5. Applicability, limits, and relations

- The optical kernel keeps **both resonant and antiresonant poles**. Its
  positive-frequency dielectric increment follows from conductivity only
  after the correct full-BZ SI normalization; it is not a second independent
  electronic-response approximation.
- The zero-frequency conductivity agrees with strict dc under identical
  geometry, occupations, and widths. The dielectric expression is undefined
  at zero frequency; it is omitted rather than assigned a finite value.
- The finite-frequency, finite-width Berry-curvature channel has a complex
  interband dispersive contribution. It need not resemble a static
  occupied-band SOS Berry-curvature map point by point.
- Exact blocks are retained whole; near-degenerate distinct levels and
  absent operator/embedding evidence are not resolved by the trace notation.

## 6. Formula provenance

| Formula or convention | Source and code correspondence | Attribution boundary |
| --- | --- | --- |
| Length-gauge optical response with intraband/interband structures | Aversa–Sipe (1995) for length-gauge context; LinearOpticalResponseKernels.jl, linear_optical_response for the exact complex expressions | **IMPLEMENTATION_FORMULA**: the present two-width, finite-model decomposition is release-specific, not quoted verbatim from the paper. |
| Velocity and exact cross-block geometry | SpectralResponseGeometry.jl, spectral_response_geometry, conventional_spectral_pair | Energy denominators are not artificially regularized in the geometric vertex. |
| Ambient $\mathcal F^{\rm W}$, its Hamiltonian-frame transform, and $B_n$ | PositionMatrixElements.jl, compute_position_capabilities!; SpectralResponseGeometry.jl, spectral_response_geometry | The contact input is the covariant curvature of the supplied position connection, not the full static band $\Omega_n$. |
| Exact-block Projector optical generalization | SpectralResponseGeometry.jl, projector_spectral_pair, projector_block_velocity, projector_block_curvature | **Project-specific generalization**; it does not assert near-degenerate averaging. |
| Berry-curvature/AHE interpretation | Xiao–Chang–Niu (2010) and Wang *et al.* (2006) for the intrinsic AHE connection; linear_optical_response for contact-plus-interband optical implementation | These references do not derive this precise broadened optical output label or assert static-map equality. |
| Dielectric increments and unit background | LinearOpticalResponseKernels.jl, model_dielectric_response | The unit background is included once, in integrated total; it is a release output contract. |

## 7. References

1. C. Aversa and J. E. Sipe, “Nonlinear optical susceptibilities of semiconductors: Results with a length-gauge analysis,” *Phys. Rev. B* **52**, 14636–14645 (1995). [DOI](https://doi.org/10.1103/PhysRevB.52.14636)
2. D. Xiao, M.-C. Chang, and Q. Niu, “Berry phase effects on electronic properties,” *Rev. Mod. Phys.* **82**, 1959–2007 (2010). [DOI](https://doi.org/10.1103/RevModPhys.82.1959)
3. X. Wang, J. R. Yates, I. Souza, and D. Vanderbilt, “Ab initio calculation of the anomalous Hall conductivity by Wannier interpolation,” *Phys. Rev. B* **74**, 195118 (2006). [DOI](https://doi.org/10.1103/PhysRevB.74.195118)

See the [input and output contract](../docs/LINEAR_AND_ORBITAL_RESPONSES.md).
