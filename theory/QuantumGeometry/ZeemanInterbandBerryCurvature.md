# Zeeman Interband Berry Curvature

## 1. Definition and physical picture

Zeeman interband Berry curvature is the antisymmetric quantum geometry of mixed momentum translation and spin rotation. Both tangent vectors of ordinary Berry curvature arise from momentum derivatives; here one leg is a position matrix element and the other is a Pauli matrix element. The quantity therefore characterizes the chiral coupling between orbital motion and spin texture.

## 2. Core theoretical formulas

For $m\in A,n\in B$, define

$$
A_{nm}^{\alpha\beta}=r_{nm}^{\alpha}\sigma_{mn}^{\beta},
\qquad
B_{nm}^{\alpha\beta}=r_{mn}^{\alpha}\sigma_{nm}^{\beta}.
$$

The Zeeman Berry curvature of a single pair is

$$
\Omega_{Z,nm}^{\alpha\beta}
=\mathrm{Re}\!\left[i\left(A_{nm}^{\alpha\beta}-B_{nm}^{\alpha\beta}\right)\right],
$$

and the band-group output is

$$
\Omega_{Z,A,B}^{\alpha\beta}
=\frac{1}{N_AN_B}\sum_{m\in A,n\in B}
\Omega_{Z,nm}^{\alpha\beta}.
$$

## 3. Relation to the Zeeman QGT

The Hermitian and anti-Hermitian combinations of the mixed product $r^\alpha\sigma^\beta$ give the Zeeman metric and Zeeman curvature, respectively:

$$
g_Z\sim\frac{A+B}{2},
\qquad
\Omega_Z\sim i(A-B).
$$

This decomposition is isomorphic to the symmetric-real/antisymmetric-imaginary decomposition of the ordinary QGT, except that the second index $\beta$ belongs to spin space rather than to a second momentum direction.

## 4. Symbols, tensor indices, and Pauli normalization

The index $\alpha=1,\ldots,d$ denotes a spatial direction, and $\beta=x,y,z$ denotes a Pauli direction. The matrix $\sigma^\beta$ is dimensionless and has eigenvalues $\pm1$. Replacing it by physical spin $S^\beta=\hbar\sigma^\beta/2$ multiplies the entire quantity by $\hbar/2$. The two band groups are disjoint, and the result is divided by $N_AN_B$.

## 5. Key symmetries and relations

- $\Omega_Z$ is a real mixed pseudotensor; its spatial and spin indices transform differently under mirrors and time reversal.
- In the absence of spin–orbit coupling, when spin and orbital degrees of freedom are fully separable, many mixed components vanish or factor into a simple spin factor.
- The quantity can enter an intrinsic gyrotropic magnetic current, but the K-slice quantity here is not a complete transport conductivity.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Zeeman QGT | Xiang et al. (2025), Eq. (4) | Standardize the spin matrix to the dimensionless Pauli matrix $\sigma$ |
| Zeeman Berry curvature | Xiang et al. (2025), Eq. (6) | Use $\mathrm{Re}[i(A-B)]$ and state the band-group average explicitly |
| Physical picture of the gyrotropic magnetic current | Xiang et al. (2025), response equations following Eqs. (5)–(6) | Retain only the local geometric factor, without transport weights |

## 7. References

1. L. Xiang, J. Jia, F. Xu, Z. Qiao, and J. Wang, “Intrinsic Gyrotropic Magnetic Current from Zeeman Quantum Geometry,” *Phys. Rev. Lett.* **134**, 116301 (2025). [DOI](https://doi.org/10.1103/PhysRevLett.134.116301)
