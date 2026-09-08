# Quantum Metric Dipole

## 1. Definition and physical picture

In this release, the quantum metric dipole (QMD) is the local first momentum derivative of the quantum metric. It characterizes the skewness of Hilbert-space distance across the Brillouin zone: if the wave-function variation rates near $+\mathbf k$ and $-\mathbf k$ differ, the metric texture has a nonzero first gradient.

## 2. Core theoretical formulas

The K-slice quantity in the release is defined as

$$
D_S^{ab;c}(\mathbf k)=\partial_{k_c}g_S^{ab}(\mathbf k),
$$

where

$$
g_S^{ab}
=\sum_{I\in S,J\notin S}
\mathrm{Re}\left(r_{IJ}^{a}r_{JI}^{b}\right).
$$

If a Fermi-sea moment is desired, one may separately define

$$
\mathcal D_{g,S}^{ab;c}
=\int_{\mathrm{BZ}}[d\mathbf k]\,
f_S(\mathbf k)\partial_{k_c}g_S^{ab}(\mathbf k),
$$

but this integral is not part of the K-slice quantity.

## 3. Distinction from other “QMD” definitions in the literature

The term “quantum metric dipole” does not denote a unique tensor throughout the literature. Gao–Xiao (2019) use the velocity-weighted object $G^{ijk}=v^i g^{jk}$ for nonreciprocal directional dichroism. Some nonlinear Hall studies use a Berry-connection polarizability containing energy denominators. Ulrich et al. (2026), by contrast, explicitly identify an intraband QMD of the form $\partial_{k_a}g_n^{bb}$. In this release, QMD strictly means $\partial g$ without an additional velocity, energy denominator, or Fermi weight.

## 4. Symbols, tensor indices, and normalization

The labels $a,b$ are the symmetric metric indices, and $c$ is the dipole direction, so $D^{ab;c}=D^{ba;c}$. The target subspace excludes intra-subspace transitions and uses an ordinary sum without division by $N_S$. This family contains only the internal metric contribution within the finite window.

## 5. Key symmetries and relations

- The ordinary metric is generally even under time-reversal or inversion mappings, so its first derivative is odd. A nonzero equilibrium integral therefore requires the appropriate symmetry or weight to be broken.
- QMD is a basic constituent of the quantum Christoffel symbol, which is a specific linear combination of three metric-dipole components.
- The local $\partial g$ can be large near a band crossing, but a large K-slice peak does not by itself equal a measurable transport coefficient.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| $\partial g$ intraband QMD | Ulrich et al. (2026), geometric decomposition and Table I | Remove the Fermi-surface and energy weights of the response, retaining only the local $\partial_{k_c}g^{ab}$ |
| Basic definition of the quantum metric | Provost–Vallée (1980), Riemannian metric definition | Take the parameter space to be Bloch momentum and exclude transitions within the target group |
| Velocity-weighted QMD for comparison | Gao–Xiao (2019), Eqs. (7) and (10) | Included only to distinguish terminology; their $v^ig^{jk}$ is not the $\partial g$ defined here |

## 7. References

1. Y. Ulrich, J. Mitscherling, L. Classen, and A. P. Schnyder, “Quantum geometric origin of the intrinsic nonlinear Hall effect,” *Phys. Rev. B* **113**, L201107 (2026). [DOI](https://doi.org/10.1103/4z8z-4kch)
2. J. P. Provost and G. Vallée, “Riemannian structure on manifolds of quantum states,” *Commun. Math. Phys.* **76**, 289–301 (1980). [DOI](https://doi.org/10.1007/BF02193559)
3. Y. Gao and D. Xiao, “Nonreciprocal Directional Dichroism Induced by the Quantum Metric Dipole,” *Phys. Rev. Lett.* **122**, 227402 (2019). [DOI](https://doi.org/10.1103/PhysRevLett.122.227402)
