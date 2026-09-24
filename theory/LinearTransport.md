# Linear transport: three conductivity mechanisms

## 1. Definition and physical picture

The strict dc length-gauge model exports **Drude**, **Quantum-Metric
Contribution**, **Berry-Curvature Contribution**, and `total`. The last
contribution is the conductivity mechanism called the **anomalous Hall effect
(AHE)** in this decomposition: it combines ambient position-curvature contact
and interband Hall terms. It is not a separately computed or necessarily
unbroadened Berry-curvature map.

The Drude term follows Fermi-surface carriers; the quantum-metric term weights
symmetric interband geometry and dissipation; the Berry-curvature term weights
antisymmetric geometry and ambient contact. These are response-model channels,
not independently observable conductivities in arbitrary truncated models.

## 2. Core theoretical formula: Conventional bands

The electron charge is $q_e=-e$, with $e>0$, and time dependence is
$\exp(-i\omega t)$. Energies, chemical potential $\mu$, the two relaxation
widths $\Gamma_{\rm intra}$ and $\Gamma_{\rm inter}$, and the distinct
Fermi-surface regularizer $\eta_{\rm FS}$ are in eV. Cartesian position
matrix elements are in Å. For one unweighted $k$ point set

$$
c=\frac{e^2}{\hbar}10^{-20},\quad
f_n=f(E_n-\mu),\quad f_{nm}=f_n-f_m,\quad
\Delta_{nm}=E_m-E_n>0\quad(E_n<E_m).
$$

The physical Hamiltonian vertex and cross-energy position matrix element are

$$
V^a_{nm}=H^a_{nm}+i(E_n-E_m)A^a_{nm},\qquad
r^a_{nm}=-\frac{iV^a_{nm}}{E_n-E_m},\qquad
Q^{ab}_{nm}=r^a_{nm}r^b_{mn}.
$$

Let $|u_i^{\rm W}(\mathbf k)\rangle$ span the retained Wannier (orbital)
frame, and let $U(\mathbf k)$ diagonalize its Hamiltonian,
$U^\dagger H^{\rm W}U=\operatorname{diag}(E_n)$. With
$A^{\rm W}_{a,ij}=i\langle u_i^{\rm W}|\partial_{k_a}u_j^{\rm W}\rangle$,
the $A^a_{nm}$ in the vertex above is
$(U^\dagger A_a^{\rm W}U)_{nm}$. Define the supplied **ambient covariant
curvature** by

$$
\mathcal F_{ab}^{\rm W}
=\partial_{k_a}A_b^{\rm W}-\partial_{k_b}A_a^{\rm W}
-i[A_a^{\rm W},A_b^{\rm W}],\qquad
\mathcal F_{ab}^{\rm H}=U^\dagger\mathcal F_{ab}^{\rm W}U.
$$

Here $[X,Y]=XY-YX$; both the derivatives and the connection use the same
position-operator and orbital-embedding convention. The code supplies
$\mathcal F_{ab}^{\rm H}$ as `geometry.curvature`. It is **not** the full
band Berry curvature. For a nondegenerate band in that same model,

$$
B_n^{ab}=\operatorname{Re}(\mathcal F_{ab}^{\rm H})_{nn},\qquad
\Omega_n^{ab}=B_n^{ab}-2\sum_{m\ne n}\operatorname{Im}Q_{nm}^{ab}.
$$

Thus $B_n^{ab}$ alone is not $\Omega_n^{ab}$. The two terms on the right
correspond to the ambient-curvature contact and the interband contribution;
the sign and Cartesian order $(a,b)$ match the code's Berry-curvature
convention.

The Conventional nondegenerate expressions are

$$
\begin{aligned}
\sigma^{ab}_{\rm Drude}
 &=c\sum_n\frac{-f'_n}{\Gamma_{\rm intra}}
    \operatorname{Re}[V^a_{nn}V^b_{nn}],\\
\sigma^{ab}_{\rm QM}
 &=2c\sum_{E_n<E_m}f_{nm}
   \frac{\Delta_{nm}\Gamma_{\rm inter}}
        {\Delta_{nm}^2+\Gamma_{\rm inter}^2}
   \operatorname{Re}Q^{ab}_{nm},\\
\sigma^{ab}_{\rm BC}
 &=-c\sum_n f_n B_n^{ab}
   +2c\sum_{E_n<E_m}f_{nm}
   \frac{\Delta_{nm}^2}{\Delta_{nm}^2+\Gamma_{\rm inter}^2}
   \operatorname{Im}Q^{ab}_{nm},\\
\sigma^{ab}_{\rm total}
 &=\sigma^{ab}_{\rm Drude}+\sigma^{ab}_{\rm QM}
   +\sigma^{ab}_{\rm BC}.
\end{aligned}
$$

The first term of $\sigma_{\rm BC}$ is contact; the second is interband
Hall. Only their **sum** is exported as `berry_curvature`. Contact vanishes
for a declared flat complete finite model. For $m\ne n$ set
$\Delta_{nm}=|E_m-E_n|$ and define the response-effective curvature

$$
\widetilde\Omega_n^{ab}(\Gamma_{\rm inter})
=B_n^{ab}-2\sum_{m\ne n}
\frac{\Delta_{nm}^2}{\Delta_{nm}^2+\Gamma_{\rm inter}^2}
\operatorname{Im}Q_{nm}^{ab},\qquad
\sigma_{\rm BC}^{ab}=-c\sum_n f_n\widetilde\Omega_n^{ab}.
$$

Pairing $(n,m)$ with $(m,n)$ gives exactly the preceding implemented
contact-plus-interband expression. After the normalized full-BZ average and
cell-volume conversion, the resolved-gap, zero-interband-width limit takes
the conventional intrinsic-AHE form

$$
\sigma_{\rm AHE,intr}^{ab}
=-\frac{e^2}{\hbar}\int_{\rm BZ}\frac{d^3k}{(2\pi)^3}
\sum_n f_{n\mathbf k}\Omega_{n\mathbf k}^{ab}.
$$

At finite width, $\widetilde\Omega_n$ is a relaxation-model response
kernel, **not** the static geometric $\Omega_n$ or a pointwise SOS-map
identity. The clean limit presumes resolved nonzero cross-block gaps; it
does not by itself establish convergence or physical completeness of a
truncated material model.

For an exact degenerate block $I$, Conventional counts each explicit state
$n\in I$ once in the Drude sum, including the block-internal product
$\sum_{m\in I}\operatorname{Re}(V^a_{nm}V^b_{mn})$. Cross-block sums count
each ordered pair $I<J$ once. Close but distinct bands are not averaged.

## 3. Equivalent and Projector formulation

Let $P_I=U\Pi_IU^\dagger$ project in the orbital frame onto an
**exact-energy** spectral block of energy $E_I$, with $\Pi_I$ its
Hamiltonian-frame diagonal projector.
The derivative $D_aP_I$ uses the complete position operator in the same
orbital frame and embedding. For $I\ne J$ define $Q_{IJ}^{ab}$; define
$W_I^{ab}$ and $B_I^{ab}$ for each block:

$$
Q^{ab}_{IJ}=\operatorname{Tr}[P_I(D_aP_I)P_J(D_bP_I)],\quad
W^{ab}_I=\operatorname{Re}\operatorname{Tr}(P_IV_aP_IV_b),\quad
B^{ab}_I=\operatorname{Re}\operatorname{Tr}(P_I\mathcal F_{ab}^{\rm W}).
$$

The Projector equations are the four Conventional equations above with
$(n,m)$ replaced by $(I,J)$, $Q_{nm}\mapsto Q_{IJ}$,
$\operatorname{Re}(V^a_{nn}V^b_{nn})\mapsto W_I^{ab}$, and
$B_n^{ab}\mapsto B_I^{ab}$, summing each pair only once for $I<J$.
The block-traced static curvature is
$\Omega_I^{ab}=B_I^{ab}-2\sum_{J\ne I}\operatorname{Im}Q_{IJ}^{ab}$;
the finite-width response replaces each interblock summand by the same
$\Delta_{IJ}^2/(\Delta_{IJ}^2+\Gamma_{\rm inter}^2)$ factor. Occupations and widths
remain functions of exact block energies. Traces are invariant under a basis
rotation within an exact degenerate block, but do not make near-degenerate
clustering or incomplete operator/embedding data physically equivalent.

## 4. Symbols, tensor indices, and normalization

These are point conductivities in S m² before BZ weights. The three-dimensional
full-BZ weighted average divided by primitive-cell volume in m³ gives S/m;
 a K-slice is an S m² integrand, not sheet conductivity. At positive temperature
$-f'$ is the exact Fermi derivative. $a,b$ are output-current and applied-field
Cartesian directions. Each explicit spinor state is counted once with no
extra spin factor. Uniform BZ weights sum to one; the volume normalization
applies only to an integral.

## 5. Applicability, limits, and relations

- At zero temperature the chosen Gaussian or Lorentzian $\eta_{\rm FS}$
  approximates the Fermi-surface delta function; it is **not** either
  relaxation width. Positive temperature uses the exact Fermi derivative.
- $\Gamma_{\rm intra}>0$ regularizes intraband response and
  $\Gamma_{\rm inter}>0$ interband response. Finite-width Berry-curvature
  conductivity need not equal a pointwise occupied-band SOS curvature.
- The zero-photon limit of [linear optical response](LinearOpticalResponse.md)
  matches this dc kernel term by term with identical geometry, occupations,
  and widths. A K-slice is not a bulk conductivity.
- Cross-block geometry denominators are unregularized; unresolved small
  distinct gaps are rejected, not merged.

## 6. Formula provenance

| Formula or convention | Source and code correspondence | Attribution boundary |
| --- | --- | --- |
| Band length-gauge Drude, metric, and Hall structures | Aversa–Sipe (1995) for length-gauge organization; LinearTransportKernels.jl, linear_transport_response for exact coefficients | **IMPLEMENTATION_FORMULA**: the release-specific two-width prescription and grouping are not verbatim formulas from that paper. |
| Physical velocity, cross-block position, exact spectral blocks | SpectralResponseGeometry.jl, spectral_response_geometry | The code's exact-block and gap-tolerance policy defines its numerical domain. |
| Ambient $\mathcal F^{\rm W}$, its Hamiltonian-frame transform, and $B_n$ | PositionMatrixElements.jl, compute_position_capabilities!; SpectralResponseGeometry.jl, spectral_response_geometry | The covariant curvature uses the supplied position matrices and their derivatives; it is only one part of the full $\Omega_n$. |
| Cross-block geometry, velocity, curvature Projector traces | SpectralResponseGeometry.jl, projector_spectral_pair, projector_block_velocity, projector_block_curvature | **Project-specific generalization**; trace invariance does not imply near-degenerate averaging. |
| Berry-curvature mechanism and anomalous Hall interpretation | Xiao–Chang–Niu (2010) and Wang *et al.* (2006) for AHE context; linear_transport_response for contact-plus-interband combination | These sources do **not** assert that the broadened channel equals a static SOS map at each $k$. |
| BZ average and SI volume conversion | SpectralResponseDriver.jl and output metadata | Release-specific normalization and serialization contract. |

## 7. References

1. C. Aversa and J. E. Sipe, “Nonlinear optical susceptibilities of semiconductors: Results with a length-gauge analysis,” *Phys. Rev. B* **52**, 14636–14645 (1995). [DOI](https://doi.org/10.1103/PhysRevB.52.14636)
2. D. Xiao, M.-C. Chang, and Q. Niu, “Berry phase effects on electronic properties,” *Rev. Mod. Phys.* **82**, 1959–2007 (2010). [DOI](https://doi.org/10.1103/RevModPhys.82.1959)
3. X. Wang, J. R. Yates, I. Souza, and D. Vanderbilt, “Ab initio calculation of the anomalous Hall conductivity by Wannier interpolation,” *Phys. Rev. B* **74**, 195118 (2006). [DOI](https://doi.org/10.1103/PhysRevB.74.195118)

See the [input and output contract](../docs/LINEAR_AND_ORBITAL_RESPONSES.md).
