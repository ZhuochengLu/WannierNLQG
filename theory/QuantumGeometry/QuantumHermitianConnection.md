# Quantum Hermitian Connection

## 1. Definition and physical picture

The quantum Hermitian connection (QHC) is a complex third-rank geometric quantity that describes how optical transition matrix elements change under parallel transport in momentum space. It treats a transition dipole as a tangent vector connecting two bands or subspaces. Its real and imaginary parts encode the covariant variation of transition intensity and phase texture, respectively. Shift current is obtained from an antisymmetric combination of two exchanged QHC components.

## 2. Conventional formulation

Define

$$
D_a r_{mn}^{b}
=\partial_{k_a}r_{mn}^{b}
-i(r_{mm}^{a}-r_{nn}^{a})r_{mn}^{b}.
$$

For two band groups $C,V$, the Conventional K-slice quantity in the release is

$$
\mathcal C_{CV}^{a;bc}
=\frac{1}{N_CN_V}
\sum_{n\in C,m\in V}
(D_a r_{mn}^{b})r_{nm}^{c}.
$$

This quantity is complex, is not symmetrized in $b,c$, and contains no occupation factor, resonant delta function, or Brillouin-zone integral.

## 3. Projector, Wilson Loop, and Geometric Loop formulations

### Native orientation of the Projector formulation

The projector block in the source literature is defined as

$$
C_{nm}^{a;bc}=\mathrm{Tr}\!\left[
P_m(\partial_bP_n)
\left(\partial_a\partial_cP_m
+(\partial_aP_n)(\partial_cP_m)\right)
\right].
$$

For isolated bands,

$$
C_{nm}^{a;bc}=i r_{mn}^{b}r_{nm}^{c}R_{nm}^{c;a},
\qquad
\mathcal C_{nm}^{a;bc}=-C_{mn}^{a;cb}.
$$

Thus, the native Projector quantity $C_{CV}^{a;bc}$ corresponds to the Conventional quantity $\mathcal C_{CV}^{a;bc}$ only after the band groups and the pair $(b,c)$ are exchanged together. This orientation must be standardized before different methods are compared. For degenerate bands, $P_n$ is replaced by a band-group projector, and the trace automatically removes the gauge freedom within that group.

### $q=0$ Wilson Loop

Let $\widetilde r_{mn}^{b}(\pm p)$ denote matrix elements parallel transported back to the central point using Wilson links. Then

$$
\mathcal C_{nm}^{a;bc}
=\lim_{p\to0}
\frac{\widetilde r_{mn}^{b}(p)-\widetilde r_{mn}^{b}(-p)}{2p}
r_{nm}^{c}.
$$

For band groups, scalar links are replaced by subspace-overlap blocks. This expression is a covariant finite difference in the length gauge, and its continuum limit is the Conventional QHC.

### $q=0$ Geometric Loop

A closed loop $\mathcal L_{nm}^{abc}(p)$ is formed from two optical velocity vertices and two displaced overlaps, and

$$
\mathcal C_{nm,\mathrm{vel}}^{a;bc}
=\left.D_p\mathcal L_{nm}^{abc}(p)\right|_{p=0},
\qquad D_p=i\partial_p.
$$

After division by the resonance factors that convert the two velocity vertices into position matrix elements, this expression corresponds to the length-gauge $\mathcal C$. Gauge invariance belongs to the complete closed Geometric Loop, not to any individual link.

## 4. Symbols, tensor indices, and subspace normalization

The index $a$ denotes the covariant-derivative direction, while $b,c$ denote the two ordered optical legs. The two band groups must be disjoint, and the result is divided by $N_CN_V$. This normalization differs from the ordinary trace used for the HCT. Although the native band/field orientations of the Projector and Conventional quantities differ, they give the same exchanged difference when inserted into shift current.

## 5. Key relations and symmetries

$$
\sigma_{\mathrm{SC}}^{abc}
\propto -i\left(\mathcal C_{nm}^{a;bc}-\mathcal C_{mn}^{a;cb}\right).
$$

An individual QHC is generally neither real nor independently measurable as a conductivity. Its gauge-invariant exchanged combination enters shift current. Time reversal, inversion, and mirror symmetries impose different $\mathbf k\leftrightarrow-\mathbf k$ relations on the real and imaginary parts of the QHC.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| $(D_ar^b)r^c$ QHC | Sipe–Shkrebtii (2000), generalized-derivative shift-current structure | Remove the resonance, occupation, and BZ integral and retain only the local complex geometric block |
| Generalized Wilson QHC | Wang et al. (2022), generalized Wilson-loop definitions | Express the continuum limit as a covariant derivative and use block links for band groups |
| Projector QHC | Guo–Lu–Wang (2025), QHC/projector equations | Explicitly retain the source-native $C_{nm}^{a;bc}$ and give its exchanged mapping to $\mathcal C$ |
| Multistate/subspace extension | Avdoshkin–Mitscherling–Moore (2025), multistate geometry sections | Promote single-band projectors to subspace projectors and average the QHC over $N_CN_V$ |

## 7. References

1. J. E. Sipe and A. I. Shkrebtii, “Second-order optical response in semiconductors,” *Phys. Rev. B* **61**, 5337–5352 (2000). [DOI](https://doi.org/10.1103/PhysRevB.61.5337)
2. H. Wang, X. Tang, H. Xu, J. Li, and X. Qian, “Generalized Wilson loop method for nonlinear light-matter interaction,” *npj Quantum Materials* **7**, 61 (2022). [DOI](https://doi.org/10.1038/s41535-022-00472-4)
3. Z. Guo, Z. Lu, and H. Wang, “Projector method for nonlinear light-matter interactions and quantum geometry,” *Phys. Rev. B* **112**, 235115 (2025). [DOI](https://doi.org/10.1103/qd9q-hnfp)
4. A. Avdoshkin, J. Mitscherling, and J. E. Moore, “Multistate Geometry of Shift Current and Polarization,” *Phys. Rev. Lett.* **135**, 066901 (2025). [DOI](https://doi.org/10.1103/w761-8nf7)
