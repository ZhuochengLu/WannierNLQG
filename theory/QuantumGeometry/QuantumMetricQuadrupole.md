# Quantum Metric Quadrupole

## 1. Definition and physical picture

In this release, the quantum metric quadrupole (QMQ) is the local second momentum derivative of the quantum-metric texture. It describes the curvature of the Hilbert-space distance distribution and can retain higher-order spatial structure when symmetry suppresses the first-order metric dipole.

## 2. Core theoretical formulas

The K-slice quantity in the release is defined as

$$
Q_{g,S}^{ab;cd}(\mathbf k)
=\partial_{k_c}\partial_{k_d}g_S^{ab}(\mathbf k),
$$

and the corresponding Fermi-sea moment can be written as

$$
\mathcal Q_{g,S}^{ab;cd}
=\int_{\mathrm{BZ}}[d\mathbf k]\,
f_S(\mathbf k)
\partial_{k_c}\partial_{k_d}g_S^{ab}(\mathbf k),
$$

but the release reports only the local quantity in the first expression.

## 3. Distinction from QMQ in response literature

Third-order nonlinear-transport studies often call the second derivative of an energy-denominator-weighted quantum-metric polarizability $G^{ab}$ a QMQ, for example $\int f\,\partial_c\partial_dG^{ab}$. The object in this release is instead the second derivative of the unweighted Bloch quantum metric $g^{ab}$. The two objects have similar symmetries and geometric interpretations, but their numerical values, dimensions, and response prefactors differ and they cannot be interchanged.

## 4. Symbols, tensor indices, and normalization

The labels $a,b$ are metric indices, while $c,d$ are quadrupole directions. In a smooth region,

$$
Q_g^{ab;cd}=Q_g^{ba;cd}=Q_g^{ab;dc}.
$$

The target subspace excludes intra-subspace transitions and uses an ordinary sum without division by $N_S$. Only the internal metric contribution within the finite window is included.

## 5. Key symmetries and relations

- If $g(\mathbf k)=g(-\mathbf k)$, its second derivative is also even, so the QMQ can be locally nonzero in an inversion- or time-reversal-symmetric system.
- QMQ is the second-order member of the hierarchy $g\to\partial g\to\partial\partial g$.
- Whether a QMQ contributes to a response also depends on Fermi weights, energy denominators, scattering mechanisms, and tensor symmetries. The K-slice geometric texture alone does not determine a complete conductivity.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Basic definition of $g^{ab}$ | Provost–Vallée (1980), Riemannian metric | Take two ordinary derivatives with respect to Bloch momentum to obtain the precise definition used in the release |
| Quantum-geometric quadrupole response | Fang–Cano–Ghorashi (2024), main text and Supplemental Eqs. (80)–(82) | The reference uses the energy-weighted $G^{ab}$; only the multipole hierarchy is adopted here, and $G$ is not identified with $g$ |
| QMQ in an experimental context | Liu et al. (2025), arXiv:2501.12641 | Identify this source as an application preprint, not as the original definition of the local unweighted $\partial\partial g$ used here |

## 7. References

1. J. P. Provost and G. Vallée, “Riemannian structure on manifolds of quantum states,” *Commun. Math. Phys.* **76**, 289–301 (1980). [DOI](https://doi.org/10.1007/BF02193559)
2. Y. Fang, J. Cano, and S. A. A. Ghorashi, “Quantum geometry induced nonlinear transport in altermagnets,” *Phys. Rev. Lett.* **133**, 106701 (2024). [DOI](https://doi.org/10.1103/PhysRevLett.133.106701)
3. X.-Y. Liu, A.-Q. Wang, D. Li, T.-Y. Zhao, X. Liao, and Z.-M. Liao, “Giant Third-Order Nonlinearity Induced by the Quantum Metric Quadrupole in Few-Layer WTe2,” arXiv:2501.12641 (2025), preprint. [arXiv](https://arxiv.org/abs/2501.12641)
