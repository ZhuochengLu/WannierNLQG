# Berry Curvature Dipole

## 1. Definition and physical picture

The Berry curvature dipole (BCD) describes the first-order inhomogeneity of Berry curvature in momentum space. Even when time-reversal symmetry makes the total Berry curvature over the Brillouin zone vanish, curvature gradients on opposite sides of the Fermi surface can add with the same sign and drive a second-order nonlinear Hall response.

## 2. Core theoretical formulas

The K-slice output of the release is the local derivative density

$$
D_S^{ab;c}(\mathbf k)=\partial_{k_c}\Omega_S^{ab}(\mathbf k),
$$

not an already integrated transport dipole. A commonly used Fermi-sea definition is

$$
\mathcal D_S^{ab;c}
=\int_{\mathrm{BZ}}[d\mathbf k]\,
f_S(\mathbf k)\partial_{k_c}\Omega_S^{ab}(\mathbf k),
$$

which, after integration by parts over the periodic Brillouin zone, is equivalent to the Fermi-surface form

$$
\mathcal D_S^{ab;c}
=-\int_{\mathrm{BZ}}[d\mathbf k]\,
(\partial_{k_c}f_S)\Omega_S^{ab}.
$$

## 3. Relation to Berry curvature

The tensor $D^{ab;c}$ inherits $\Omega^{ab}=-\Omega^{ba}$. For a target subspace $S$, the curvature $\Omega_S$ excludes intra-subspace transitions and includes the external non-Abelian curvature contribution of the Berry family in the release. Its momentum derivative follows the same physical definition.

## 4. Symbols, tensor indices, and normalization

The labels $a,b$ denote the curvature plane, and $c$ denotes the dipole direction. The local K-slice quantity contains no occupation factor $f$, relaxation time, or Brillouin-zone integral. A target subspace uses an ordinary trace or sum, with no division by $N_S$.

## 5. Key symmetries and relations

- Under time reversal, $\Omega(\mathbf k)=-\Omega(-\mathbf k)$, so $\partial_c\Omega$ is even; time-reversal symmetry does not forbid a BCD.
- Under inversion, $\Omega(\mathbf k)=\Omega(-\mathbf k)$, so $\partial_c\Omega$ is odd; the equilibrium integrated BCD vanishes.
- In two dimensions, the pseudovector notation $\Omega^z=\Omega^{xy}$ is often used, giving $D_c=\int f\,\partial_c\Omega^z$.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Integrated BCD and nonlinear Hall response | Sodemann–Fu (2015), Eq. (8) and nonlinear-conductivity equations | Expand the pseudovector notation of the reference into the antisymmetric tensor indices $ab$ |
| Local K-slice density | Defined by the BCD integrand | Remove the Fermi weight and BZ integral, retaining only $\partial_c\Omega^{ab}$ |
| Subspace curvature | Wilczek–Zee (1984), non-Abelian curvature | Exclude transitions within the target group and take the ordinary subspace trace |

## 7. References

1. I. Sodemann and L. Fu, “Quantum Nonlinear Hall Effect Induced by Berry Curvature Dipole in Time-Reversal Invariant Materials,” *Phys. Rev. Lett.* **115**, 216806 (2015). [DOI](https://doi.org/10.1103/PhysRevLett.115.216806)
2. F. Wilczek and A. Zee, “Appearance of Gauge Structure in Simple Dynamical Systems,” *Phys. Rev. Lett.* **52**, 2111–2114 (1984). [DOI](https://doi.org/10.1103/PhysRevLett.52.2111)
