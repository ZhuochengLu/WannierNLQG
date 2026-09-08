# Berry Curvature Quadrupole

## 1. Definition and physical picture

The Berry curvature quadrupole (BCQ) is the second-order momentum-space texture of Berry curvature. It characterizes the bending of the curvature distribution rather than its net value or first-order skewness. When crystal symmetries suppress both the monopole and dipole, the BCQ can become the leading geometric moment in a higher-order nonlinear Hall response.

## 2. Core theoretical formulas

The K-slice quantity in the release is defined as

$$
Q_S^{ab;cd}(\mathbf k)
=\partial_{k_c}\partial_{k_d}\Omega_S^{ab}(\mathbf k).
$$

The corresponding Fermi-sea quadrupole moment is

$$
\mathcal Q_S^{ab;cd}
=\int_{\mathrm{BZ}}[d\mathbf k]\,
f_S(\mathbf k)
\partial_{k_c}\partial_{k_d}\Omega_S^{ab}(\mathbf k).
$$

The release reports the local density in the first expression and does not automatically evaluate the second expression.

## 3. Relation to lower-order multipoles

$$
\Omega^{ab}
\xrightarrow{\partial_c}
D^{ab;c}
\xrightarrow{\partial_d}
Q^{ab;cd}.
$$

Consequently, $Q^{ab;cd}=-Q^{ba;cd}$ and, in a smooth region, $Q^{ab;cd}=Q^{ab;dc}$. The target-subspace curvature excludes intra-subspace transitions and includes the external curvature term of the Berry family.

## 4. Symbols, tensor indices, and normalization

The labels $a,b$ denote the Berry-curvature plane, and $c,d$ denote the quadrupole directions. The target-subspace quantity uses an ordinary trace or sum, with no division by the number of bands. The local quantity contains no Fermi distribution, scattering time, or BZ normalization.

## 5. Key symmetries and relations

- Berry curvature is odd under time reversal, and its second derivative remains odd. The equilibrium BCQ moment therefore usually vanishes in a time-reversal-symmetric system.
- Berry curvature is even under inversion, and its second derivative is also even. A magnetic centrosymmetric system can therefore support a BCQ.
- In the two-dimensional pseudoscalar-curvature notation, the BCQ is the symmetric second-rank tensor $Q_{cd}=\int f\,\partial_c\partial_d\Omega^z$.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Berry-curvature multipole hierarchy | Zhang et al. (2023), Sec. II, definition $Q_{\alpha\beta}=\sum_{\mathbf k}f_0\partial_\alpha\partial_\beta\Omega$ | Expand the two-dimensional pseudoscalar $\Omega$ into the general tensor $\Omega^{ab}$ |
| Local K-slice BCQ | Integrand of the definition above | Remove $f_0$ and the BZ sum, retaining only the second momentum derivative |
| Hierarchy relative to the BCD | Add one momentum derivative to the BCD definition of Sodemann–Fu (2015) | Do not misidentify the application paper as the original source of the BCQ definition |

## 7. References

1. C.-P. Zhang, X.-J. Gao, Y.-M. Xie, H. C. Po, and K. T. Law, “Higher-order nonlinear anomalous Hall effects induced by Berry curvature multipoles,” *Phys. Rev. B* **107**, 115142 (2023). [DOI](https://doi.org/10.1103/PhysRevB.107.115142)
2. I. Sodemann and L. Fu, “Quantum Nonlinear Hall Effect Induced by Berry Curvature Dipole in Time-Reversal Invariant Materials,” *Phys. Rev. Lett.* **115**, 216806 (2015). [DOI](https://doi.org/10.1103/PhysRevLett.115.216806)
