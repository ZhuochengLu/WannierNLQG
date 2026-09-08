# Shift Current

## 1. Definition and physical picture

Shift current is a dc current generated at the instant of an optical transition in a noncentrosymmetric system. The optical matrix element determines the transition probability, while the shift vector gives the real-space displacement of the electronic wave packet. Because the effect is not an accumulation of asymmetric carrier velocities, no relaxation time is required to sustain it.

## 2. Core theoretical formula

Under the ordered-field, complete-band-pair convention of this release, the length-gauge expression is

$$
\sigma_{\mathrm{SC}}^{abc}(\omega)=
\frac{\pi e^3}{2\hbar^2}
\int_{\mathrm{BZ}}[d\mathbf k]
\sum_{nm}f_{nm}\delta(\omega_{mn}-\omega)
r_{mn}^{b}r_{nm}^{c}
\left(R_{mn}^{b;a}-R_{nm}^{c;a}\right),
$$

where

$$
R_{mn}^{b;a}
=i\partial_{k_a}\log r_{mn}^{b}+r_{mm}^{a}-r_{nn}^{a}.
$$

If only absorption transitions are retained and the conjugate field ordering is combined into the same real-field tensor, a common literature convention has the prefactor $\pi e^3/\hbar^2$. The two expressions cannot be mixed without simultaneously changing the summation domain and field ordering.

## 3. Alternative and equivalent formulations

### Conventional: generalized derivative

Define the covariant generalized derivative

$$
r_{mn;a}^{b}
=\partial_{k_a}r_{mn}^{b}
-i(r_{mm}^{a}-r_{nn}^{a})r_{mn}^{b},
\qquad
i r_{mn;a}^{b}=r_{mn}^{b}R_{mn}^{b;a}.
$$

The shift-vector kernel is therefore equivalent to

$$
r_{mn}^{b}r_{nm}^{c}
(R_{mn}^{b;a}-R_{nm}^{c;a})
=-i\left(r_{nm;a}^{b}r_{mn}^{c}-r_{mn;a}^{c}r_{nm}^{b}\right),
$$

where the band indices and optical-field indices on the right-hand side must be exchanged as a single unit.

### Projector

Let $P_n=|u_n\rangle\langle u_n|$ and define the quantum Hermitian connection block

$$
C_{nm}^{a;bc}=\mathrm{Tr}\!\left[
P_m(\partial_bP_n)
\left(\partial_a\partial_cP_m+(\partial_aP_n)(\partial_cP_m)\right)
\right].
$$

Then

$$
\sigma_{\mathrm{SC}}^{abc}
=-\frac{i\pi e^3}{2\hbar^2}
\int_{\mathrm{BZ}}[d\mathbf k]
\sum_{nm}f_{nm}\delta(\omega_{mn}-\omega)
\left(C_{mn}^{a;cb}-C_{nm}^{a;bc}\right).
$$

For isolated bands,

$$
C_{nm}^{a;bc}=i r_{mn}^{b}r_{nm}^{c}R_{nm}^{c;a},
$$

which recovers the length-gauge expression term by term. In the degenerate case, $P_n,P_m$ are promoted to subspace projectors, and the complete trace is invariant under unitary rotations within each subspace.

### $q=0$ Wilson loop

The Wilson formulation uses overlap links between $\mathbf k$ and $\mathbf k+p\hat{\mathbf e}_a$ to parallel transport the optical matrix element. If $\widetilde r_{mn}^{b}(p)$ denotes the matrix element transported back to the central point, then

$$
r_{mn;a}^{b}
=\lim_{p\to0}\frac{\widetilde r_{mn}^{b}(p)-\widetilde r_{mn}^{b}(-p)}{2p}.
$$

A general $abc$ component requires two generalized Wilson loops with opposite orientations and the simultaneous exchange $b\leftrightarrow c$. The imaginary part of a single loop is sufficient only under additional symmetry conditions, including some cases with $b=c$. The continuum limit is precisely the covariant-derivative expression of the Conventional formulation.

### $q=0$ geometric loop

Taking the $\mathbf q\to0$ limit of the $\alpha,\beta$ endpoints of the finite-momentum geometric loop and using $v_{mn}^{b}=i(\epsilon_m-\epsilon_n)r_{mn}^{b}/\hbar$ gives the velocity-gauge closed loop

$$
\left[D_p\mathcal L_{mn}^{abc}(p)-D_p\mathcal L_{nm}^{acb}(p)\right]_{p\to0},
\qquad D_p=i\partial_p.
$$

On the resonant shell $\omega_{mn}=\omega$, the factor $\omega^{-2}$ in the velocity gauge is canceled by the factor $\omega_{mn}^{2}$ from the two velocity vertices, recovering the same length-gauge response.

## 4. Symbols, tensor indices, and subspace normalization

The index $a$ is the current direction, while $b,c$ are the ordered optical-field directions. The index after the semicolon in $R_{mn}^{b;a}$ denotes the momentum-derivative direction. Isolated-band quantities can acquire phases under gauge transformations, but the two-term combination above, the projector trace, and the closed loop are all gauge invariant. A degenerate band group must be contracted as a whole; a shift vector cannot be assigned independently to an arbitrarily selected eigenvector within that group.

## 5. Key limits, symmetries, and relations

- Electric-dipole $q=0$ shift current is odd under spatial inversion and therefore vanishes in a centrosymmetric bulk crystal.
- Time-reversal symmetry alone does not forbid linearly polarized shift current.
- For $b=c$, the two terms reduce to the familiar “transition intensity times shift vector” form. For $b\ne c$, the complex matrix elements and both field orderings must be retained.
- The Projector, Wilson-loop, and geometric-loop formulations describe the same gauge-invariant response, not distinct physical effects.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Length-gauge shift current and generalized derivative | Sipe–Shkrebtii (2000), Secs. II–III; Wang et al. (2017), shift-current section; Ibañez-Azpiroz et al. (2018), Sec. II | Standardize to $e<0$, $f_{nm}$, and $\omega_{mn}>0$; retain $1/2$ for the ordered-field/complete-band-pair convention of the release |
| Generalized Wilson loop | Wang et al. (2022), Eqs. (1)–(4) | Write a general $abc$ component as the difference of two exchanged loops; its continuum limit gives $r_{;a}$ |
| Projector block and response | Guo–Lu–Wang (2025), projector-QHC/shift-current equations; Avdoshkin–Mitscherling–Moore (2025), multistate formulation | Rearrange the notation as $C_{mn}^{a;cb}-C_{nm}^{a;bc}$ and promote the ordinary trace to band subspaces |
| $q=0$ geometric loop | Shi et al. (2021), geometric-loop construction | Construct the closed loop at finite $q$, then take $q\to0$ and use the resonance relation to return to the length gauge |

## 7. References

1. H. Wang, X. Tang, H. Xu, J. Li, and X. Qian, “Generalized Wilson loop method for nonlinear light-matter interaction,” *npj Quantum Materials* **7**, 61 (2022). [DOI](https://doi.org/10.1038/s41535-022-00472-4)
2. Z. Guo, Z. Lu, and H. Wang, “Projector method for nonlinear light-matter interactions and quantum geometry,” *Phys. Rev. B* **112**, 235115 (2025). [DOI](https://doi.org/10.1103/qd9q-hnfp)
