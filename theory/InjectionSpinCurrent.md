# Injection Spin Current

## 1. Definition and physical picture

Injection spin current (ISC) describes an imbalance in the injection rate, along direction $a$, of photoexcited carriers with a specified Pauli polarization. It replaces the velocity vertex of ordinary injection current by a Pauli-current vertex and therefore probes group velocity, optical selection rules, and spin texture simultaneously.

## 2. Pauli-current definition and core formula

The release uses the dimensionless Pauli operator $\sigma^s$ and defines

$$
J_{\sigma}^{as}=\frac12\{v^a,\sigma^s\}.
$$

With ordered fields and a complete band-pair sum, the injection-rate tensor is

$$
\eta_{\mathrm{ISC}}^{asbc}(\omega)=
\frac{\pi |e|^2}{\hbar^2}
\int_{\mathrm{BZ}}[d\mathbf k]
\sum_{nm}f_{nm}\delta(\omega_{mn}-\omega)
\left(J_{\sigma,mm}^{as}-J_{\sigma,nn}^{as}\right)
r_{nm}^{c}r_{mn}^{b}.
$$

For a steady-state Pauli current, multiply this rate by $\tau$ in the single-relaxation-time approximation. To obtain the physical angular-momentum current, apply the final conversion

$$
J_{\mathrm{phys}}^{as}=\frac{\hbar}{2}J_{\sigma}^{as}.
$$

## 3. Equivalent formulation and identity channel

On the resonant shell, the factor $r_{nm}^{c}r_{mn}^{b}$ can be replaced by two velocity vertices, producing an explicit factor $\omega^{-2}$. The most important normalization check is the formal substitution $\sigma^s\to\mathbb 1$:

$$
J_{\sigma}^{a1}=v^a,
\qquad
(-|e|)\,\eta_{\mathrm{ISC}}^{a1bc}
=\eta_{\mathrm{IC}}^{abc}.
$$

The identity-channel kernel equals the ordinary injection-current kernel transition by transition. The release prefactors now preserve that equality after multiplication by the signed output charge $-|e|$. The identity channel is an operator-normalization check, not a physical Pauli direction, and it does not include the factor $\hbar/2$.

## 4. Symbols, tensor indices, and normalization

The four indices have the fixed order

$$
(a,s,b,c)=(\text{flow direction},\text{Pauli direction},\text{optical-field direction},\text{optical-field direction}),
$$

where $s=x,y,z$; in particular, $s=z$ remains meaningful even for a system with only two-dimensional crystal momentum. The factor $|e|^2$ comes from the two optical-field couplings, while the Pauli-current operator itself carries no output charge. The conversion factor $\hbar/2$ for a physical spin current must not be folded into this prefactor.

## 5. Key limits, symmetries, and relations

- Constraints imposed by $\mathcal PT$ or crystal mirrors differ from those for charge injection because $s$ is an axial-vector index.
- Spin–orbit coupling generally makes $J_{\sigma}^{as}$ nonconserved. The present definition is the conventional anticommutator Pauli current and contains no additional torque-dipole correction.
- The kernel-level identity holds transition by transition, and the released tensors obey $(-|e|)\eta_{\mathrm{ISC}}^{a1bc}=\eta_{\mathrm{IC}}^{abc}$.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Classification of second-order spin photocurrents and ISC | Lihm–Park (2022), response decomposition and Eqs. (7), (11) | Replace the general spin operator by dimensionless $\sigma^s$ and exchange band labels to obtain $f_{nm}\delta(\omega_{mn}-\omega)$ |
| Pauli-current vertex | Qiao et al. (2018), Eqs. (22)–(51) | Rewrite the physical-spin/spin-Hall units of the original work as $J_\sigma=\{v,\sigma\}/2$ |
| Identity channel | Follows directly from the operator definition above | The kernels coincide before global prefactors; the release prefactors preserve equality after multiplication by $-|e|$ |

## 7. References

1. J.-M. Lihm and C.-H. Park, “Comprehensive theory of second-order spin photocurrents,” *Phys. Rev. B* **105**, 045201 (2022). [DOI](https://doi.org/10.1103/PhysRevB.105.045201)
2. J. Qiao, J. Zhou, Z. Yuan, and W. Zhao, “Calculation of intrinsic spin Hall conductivity by Wannier interpolation,” *Phys. Rev. B* **98**, 214402 (2018). [DOI](https://doi.org/10.1103/PhysRevB.98.214402)
