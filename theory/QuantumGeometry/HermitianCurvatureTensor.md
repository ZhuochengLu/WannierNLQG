# Hermitian Curvature Tensor

## 1. Definition and physical picture

The Hermitian curvature tensor (HCT) measures the noncommutativity of covariantly transporting an optical-transition tangent vector along two momentum directions. It is the curvature of the transition space: Berry curvature describes the holonomy of a state subspace itself, whereas the HCT describes how the optical matrix connecting two subspaces rotates under those holonomies.

## 2. Core theoretical formula

Let $R_{NM}^{a}$ be the interband position-matrix block from subspace $M$ to subspace $N$, and let $F_{dc}^{M,N}$ denote the non-Abelian Berry curvature of the corresponding subspaces. The release defines

$$
K_{badc}^{MN}
=-i\mathrm{Tr}_{N}\!\left[
R_{NM}^{b}
\left(F_{dc}^{M}R_{MN}^{a}-R_{MN}^{a}F_{dc}^{N}\right)
\right].
$$

The non-Abelian curvature is

$$
F_{dc}^{S}=\partial_d A_c^{S}-\partial_c A_d^{S}-i[A_d^{S},A_c^{S}],
$$

where $A_a^{S}$ is the Berry connection of subspace $S$.

## 3. Equivalent geometric formulation

Viewing $R_{MN}^{a}$ as a vector-bundle homomorphism from $N$ to $M$, its covariant derivative is

$$
\nabla_d R_{MN}^{a}
=\partial_dR_{MN}^{a}-iA_d^{M}R_{MN}^{a}+iR_{MN}^{a}A_d^{N}.
$$

The Ricci identity then gives

$$
[\nabla_d,\nabla_c]R_{MN}^{a}
=-i\left(F_{dc}^{M}R_{MN}^{a}-R_{MN}^{a}F_{dc}^{N}\right),
$$

so the HCT is the Hermitian-inner-product trace of this curvature action with the second optical leg $R_{NM}^{b}$.

## 4. Symbols, tensor indices, and trace normalization

The index order is fixed as $(b,a,d,c)$: $a,b$ denote the two optical legs, and $d,c$ denote the curvature-plane directions. The subspaces $M,N$ must be disjoint. The release uses the ordinary trace $\mathrm{Tr}_{N}$, with no division by $N_M$ or $N_N$. Enlarging a subspace can therefore increase the total oscillator-strength weight. This differs from the Cartesian-product average used for the QHC and interband QGT.

## 5. Key limits, symmetries, and relations

- $K_{badc}^{MN}=-K_{bacd}^{MN}$ because $F_{dc}=-F_{cd}$.
- If the curvatures of both subspaces vanish, the HCT vanishes even when the interband optical matrix element is nonzero.
- The HCT can enter the resonant third-order photovoltaic Hall response; its real and imaginary parts correspond to different polarization combinations.
- For isolated bands, the non-Abelian matrix expression reduces to the difference of two U(1) Berry curvatures multiplied by the optical-transition intensity.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Hermitian-curvature definition | Ahn et al. (2022), main-text Eq. (9) and geometric identities in Methods | Label the band groups by $M,N$ and fix the index order as $(b,a,d,c)$ |
| Ricci-identity formulation | Ahn et al. (2022), Riemannian-geometry construction | Use the Berry-connection convention $r=i\langle u\vert\partial u\rangle$, which fixes the covariant derivative and the sign $-i$ shown above |
| Release subspace contract | Block trace of the same multiband formula | Retain the ordinary trace without averaging over subspace dimensions |

## 7. References

1. J. Ahn, G.-Y. Guo, N. Nagaosa, and A. Vishwanath, “Riemannian geometry of resonant optical responses,” *Nature Physics* **18**, 290–295 (2022). [DOI](https://doi.org/10.1038/s41567-021-01465-z)
