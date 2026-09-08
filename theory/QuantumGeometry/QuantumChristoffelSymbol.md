# Quantum Christoffel Symbol

## 1. Definition and physical picture

The quantum Christoffel symbol (QCS) is the Christoffel symbol of the first kind constructed from the Bloch quantum metric. It describes how straight trajectories on the quantum-state manifold bend because of the metric texture and combines three quantum metric dipoles into an affine-geometric quantity.

## 2. Core theoretical formulas

For a target subspace $S$, the release defines

$$
\Gamma_S^{rlj}
=\frac12\left(
\partial_{k_j}g_S^{lr}
+\partial_{k_l}g_S^{rj}
-\partial_{k_r}g_S^{lj}
\right).
$$

Writing the QMD as $D_S^{ab;c}=\partial_{k_c}g_S^{ab}$ gives

$$
\Gamma_S^{rlj}
=\frac12\left(D_S^{lr;j}+D_S^{rj;l}-D_S^{lj;r}\right).
$$

## 3. Relation to the Levi-Civita connection

The expression above is the Christoffel symbol of the first kind. If the metric is invertible in the selected region, the symbol of the second kind is

$$
\Gamma^{r}{}_{lj}=g^{rs}\Gamma_{slj}.
$$

The release reports the first-kind, equivalently all-lower-index, form and does not contract it with $g^{-1}$. A Christoffel symbol is not a tensor; only a covariant derivative or complete response assembled with the other required terms has coordinate-covariant meaning.

## 4. Symbols, tensor indices, and subspace normalization

The labels $r,l,j$ are all Cartesian directions in momentum space. Since $g^{ab}=g^{ba}$, one has $\Gamma^{rlj}=\Gamma^{rjl}$, so the last two indices are symmetric. The metric $g_S$ excludes intra-subspace transitions and uses an ordinary sum. The QCS contains only the internal metric contribution within the finite window of the release.

## 5. Key limits, symmetries, and relations

- If the metric is constant in momentum space, the QCS vanishes.
- The QCS can control second-order orbital magnetization. That response is not equal to an individual $\Gamma$ component and also contains occupation and energy weights.
- A Christoffel symbol of the first kind has an inhomogeneous term under coordinate transformations, so an individual component must not be interpreted as a coordinate-independent scalar.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Quantum Christoffel symbol | Qiang et al. (2026), Eq. (3) | Fix the index order as $\Gamma^{rlj}$ and use the release metric $g_S$ |
| Physical picture of nonlinear magnetization | Qiang et al. (2026), main response equations | Retain only the local QCS, without the complete magnetization weights |
| Geometric foundation of the metric | Provost–Vallée (1980) | Take the parameter space to be the BZ and use the first-kind rather than second-kind Christoffel symbol |

## 7. References

1. X.-B. Qiang, X. Liu, H.-Z. Lu, and X. C. Xie, “Quantum Christoffel Nonlinear Magnetization,” *Phys. Rev. Lett.* **136**, 056302 (2026). [DOI](https://doi.org/10.1103/4kmy-59l9)
2. J. P. Provost and G. Vallée, “Riemannian structure on manifolds of quantum states,” *Commun. Math. Phys.* **76**, 289–301 (1980). [DOI](https://doi.org/10.1007/BF02193559)
