# Berry Curvature

## 1. Definition and physical picture

Berry curvature is the local holonomy associated with adiabatic parallel transport of Bloch states in momentum space. It acts as a magnetic field in momentum space and governs anomalous velocity, Hall responses, and the surface integral of the Berry phase.

## 2. Core theoretical formulas

For an isolated band, the Berry connection and curvature are

$$
A_n^{a}=i\langle u_n|\partial_a u_n\rangle,
\qquad
\Omega_n^{ab}=\partial_aA_n^{b}-\partial_bA_n^{a}.
$$

In a complete Hilbert space, the interband form is

$$
\Omega_n^{ab}
=-2\mathrm{Im}\sum_{m\ne n}r_{nm}^{a}r_{mn}^{b}.
$$

For a target subspace $S$, the gauge-covariant expression is

$$
\Omega_S^{ab}=\mathrm{Tr}_S F_{ab}^{S}
=-2\mathrm{Im}
\sum_{I\in S,J\notin S}r_{IJ}^{a}r_{JI}^{b}
+\Omega_{S,\mathrm{ext}}^{ab}.
$$

The term $\Omega_{S,\mathrm{ext}}$ is the non-Abelian curvature contribution of the finite basis itself; the Berry family in the release includes this term.

## 3. Non-Abelian formulation

For a multiband subspace,

$$
F_{ab}^{S}=\partial_aA_b^{S}-\partial_bA_a^{S}-i[A_a^{S},A_b^{S}].
$$

Under a unitary transformation within the subspace, $F\to U^\dagger FU$, so $\mathrm{Tr}F$ is invariant. Intra-subspace transitions do not appear in the complementary-space sum; they only change the representation within the subspace.

## 4. Symbols, tensor indices, and normalization

The labels $a,b$ denote the curvature-plane directions, and $\Omega^{ab}=-\Omega^{ba}$. The result for a target subspace is an ordinary sum or trace over $S$, with no division by $N_S$. A companion sum of isolated-band curvatures is likewise a sum, not an average.

## 5. Key limits, symmetries, and relations

- Time reversal gives $\Omega_n^{ab}(\mathbf k)=-\Omega_{\bar n}^{ab}(-\mathbf k)$, while inversion gives a same-sign mapping. When both are present, the curvature of a nondegenerate band vanishes pointwise.
- For an isolated two-dimensional band, $C_n=(2\pi)^{-1}\int_{\mathrm{BZ}}\Omega_n^{xy}d^2k$ is the Chern number.
- Berry curvature is the antisymmetric imaginary part of the quantum geometric tensor; its symmetric real part is the quantum metric.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| U(1) Berry curvature and phase | Berry (1984), equations defining the geometrical phase and curvature | Take the parameter space to be crystal momentum and use the connection $+i\langle u\vert\partial u\rangle$ |
| Non-Abelian curvature | Wilczek–Zee (1984), non-Abelian connection construction | Trace over the selected band group to obtain a gauge-invariant scalar |
| Interband-matrix-element form | Standard first-order perturbative expansion; Wang et al. (2006), AHC formulas | Standardize to $-2\mathrm{Im}r^ar^b$ and exclude transitions within the target group |

## 7. References

1. M. V. Berry, “Quantal phase factors accompanying adiabatic changes,” *Proc. R. Soc. Lond. A* **392**, 45–57 (1984). [DOI](https://doi.org/10.1098/rspa.1984.0023)
2. F. Wilczek and A. Zee, “Appearance of Gauge Structure in Simple Dynamical Systems,” *Phys. Rev. Lett.* **52**, 2111–2114 (1984). [DOI](https://doi.org/10.1103/PhysRevLett.52.2111)
3. X. Wang, J. R. Yates, I. Souza, and D. Vanderbilt, “Ab initio calculation of the anomalous Hall conductivity by Wannier interpolation,” *Phys. Rev. B* **74**, 195118 (2006). [DOI](https://doi.org/10.1103/PhysRevB.74.195118)
