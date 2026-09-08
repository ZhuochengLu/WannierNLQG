# Zeeman Interband Quantum Metric

## 1. Definition and physical picture

The Zeeman interband quantum metric is the Hermitian part of mixed momentum–spin geometry. It measures the correlation between the momentum variation of a Bloch state and a Pauli-spin rotation and is the counterpart of the ordinary quantum metric in a space with one momentum leg and one spin leg.

## 2. Core theoretical formulas

For $m\in A,n\in B$, define

$$
A_{nm}^{\alpha\beta}=r_{nm}^{\alpha}\sigma_{mn}^{\beta},
\qquad
B_{nm}^{\alpha\beta}=r_{mn}^{\alpha}\sigma_{nm}^{\beta}.
$$

The single-pair Zeeman metric and the band-group average are

$$
g_{Z,nm}^{\alpha\beta}
=\frac12\mathrm{Re}\left(A_{nm}^{\alpha\beta}+B_{nm}^{\alpha\beta}\right),
$$

$$
g_{Z,A,B}^{\alpha\beta}
=\frac{1}{N_AN_B}\sum_{m\in A,n\in B}g_{Z,nm}^{\alpha\beta}.
$$

## 3. Relation to Zeeman Berry curvature

The Hermitian and anti-Hermitian parts of the same mixed geometric product give

$$
g_Z\sim\frac{A+B}{2},
\qquad
\Omega_Z\sim i(A-B).
$$

The two quantities must therefore use the same band order, Pauli convention, and $N_AN_B$ normalization.

## 4. Symbols, tensor indices, and Pauli normalization

The index $\alpha$ denotes a spatial direction, while $\beta$ denotes one of the three Pauli directions. This object is not the ordinary $g^{\alpha\beta}$ and need not be symmetric under $\alpha\leftrightarrow\beta$. The Pauli matrix $\sigma$ is dimensionless; using physical spin multiplies the result by $\hbar/2$. The two band groups must be disjoint, and the Cartesian-product average is used.

## 5. Key limits, symmetries, and relations

- $g_Z$ is a real mixed tensor, but unlike an ordinary metric it is not guaranteed to be positive definite in all mixed directions.
- In the limit of no spin–orbit coupling and a spin texture independent of $\mathbf k$, most nontrivial mixed components vanish.
- Together with Zeeman Berry curvature, it characterizes the local geometric origin of the gyrotropic magnetic response.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Zeeman QGT | Xiang et al. (2025), Eq. (4) | Standardize the position-matrix-element convention to $r=i\langle u|\partial u\rangle$ |
| Zeeman quantum metric | Xiang et al. (2025), Eq. (5) | Use the dimensionless Pauli matrix, take the real part, and average over $A\times B$ |
| Decomposition relative to ZBC | Xiang et al. (2025), Eqs. (5)–(6) | Preserve the same band and index order |

## 7. References

1. L. Xiang, J. Jia, F. Xu, Z. Qiao, and J. Wang, “Intrinsic Gyrotropic Magnetic Current from Zeeman Quantum Geometry,” *Phys. Rev. Lett.* **134**, 116301 (2025). [DOI](https://doi.org/10.1103/PhysRevLett.134.116301)
