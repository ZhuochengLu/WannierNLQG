# Injection Spin Current

## 1. Definition and physical picture

Injection spin current (ISC) describes an imbalance in the injection rate, along direction $`a`$, of photoexcited carriers with a specified Pauli polarization. It replaces the velocity vertex of ordinary injection current by a Pauli-current vertex and therefore probes group velocity, optical selection rules, and spin texture simultaneously.

## 2. Pauli-current definition and core formula

The release uses the dimensionless Pauli operator $`\sigma^s`$ and defines

```math
J_{\sigma}^{as}=\frac12\{v^a,\sigma^s\}.
```

With ordered fields and a complete band-pair sum, the injection-rate tensor is

```math
\eta_{\mathrm{ISC}}^{asbc}(\omega)=
\frac{\pi |e|^2}{\hbar^2}
\int_{\mathrm{BZ}}[d\mathbf k]
\sum_{nm}f_{nm}\delta(\omega_{mn}-\omega)
\left(J_{\sigma,mm}^{as}-J_{\sigma,nn}^{as}\right)
r_{nm}^{c}r_{mn}^{b}.
```

For a steady-state Pauli current, multiply this rate by $`\tau`$ in the single-relaxation-time approximation. To obtain the physical angular-momentum current, apply the final conversion

```math
J_{\mathrm{phys}}^{as}=\frac{\hbar}{2}J_{\sigma}^{as}.
```

## 3. Equivalent formulation and identity channel

On the resonant shell, the factor $`r_{nm}^{c}r_{mn}^{b}`$ can be replaced by two velocity vertices, producing an explicit factor $`\omega^{-2}`$. The most important normalization check is the formal substitution $`\sigma^s\to\mathbb 1`$:

```math
J_{\sigma}^{a1}=v^a,
\qquad
(-|e|)\,\eta_{\mathrm{ISC}}^{a1bc}
=\eta_{\mathrm{IC}}^{abc}.
```

The identity-channel kernel equals the ordinary injection-current kernel transition by transition. The release prefactors now preserve that equality after multiplication by the signed output charge $`-|e|`$. The identity channel is an operator-normalization check, not a physical Pauli direction, and it does not include the factor $`\hbar/2`$.

## 4. Symbols, tensor indices, and normalization

The four indices have the fixed order

```math
(a,s,b,c)=(\text{flow direction},\text{Pauli direction},\text{optical-field direction},\text{optical-field direction}),
```

where $`s=x,y,z`$; in particular, $`s=z`$ remains meaningful even for a system with only two-dimensional crystal momentum. The factor $`|e|^2`$ comes from the two optical-field couplings, while the Pauli-current operator itself carries no output charge. The conversion factor $`\hbar/2`$ for a physical spin current must not be folded into this prefactor.

## 5. Key limits, symmetries, and relations

- Constraints imposed by $`\mathcal PT`$ or crystal mirrors differ from those for charge injection because $`s`$ is an axial-vector index.
- Spin–orbit coupling generally makes $`J_{\sigma}^{as}`$ nonconserved. The present definition is the conventional anticommutator Pauli current and contains no additional torque-dipole correction.
- The kernel-level identity holds transition by transition, and the released tensors obey $`(-|e|)\eta_{\mathrm{ISC}}^{a1bc}=\eta_{\mathrm{IC}}^{abc}`$.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Classification of second-order spin photocurrents and ISC | Lihm–Park (2022), response decomposition and Eqs. (7), (11) | Replace the general spin operator by dimensionless $`\sigma^s`$ and exchange band labels to obtain $`f_{nm}\delta(\omega_{mn}-\omega)`$ |
| Pauli-current vertex | Qiao et al. (2018), Eqs. (22)–(51) | Rewrite the physical-spin/spin-Hall units of the original work as $`J_\sigma=\{v,\sigma\}/2`$ |
| Identity channel | Follows directly from the operator definition above | The kernels coincide before global prefactors; the release prefactors preserve equality after multiplication by $`-\lvert e\rvert`$ |

## 7. References

1. J.-M. Lihm and C.-H. Park, “Comprehensive theory of second-order spin photocurrents,” *Phys. Rev. B* **105**, 045201 (2022). [DOI](https://doi.org/10.1103/PhysRevB.105.045201)
2. J. Qiao, J. Zhou, Z. Yuan, and W. Zhao, “Calculation of intrinsic spin Hall conductivity by Wannier interpolation,” *Phys. Rev. B* **98**, 214402 (2018). [DOI](https://doi.org/10.1103/PhysRevB.98.214402)


## Shared one-photon spin-current vertex and regularization

Use the cell-periodic convention $`H_{\mathbf k}=e^{-i\mathbf k\cdot\mathbf r}He^{i\mathbf k\cdot\mathbf r}`$,
$`u=e^{-i\mathbf k\cdot\mathbf r}\psi`$, and $`v_a=\partial_a H_{\mathbf k}/\hbar`$.
For a general Hermitian input spin operator $`s`$, define the Wannier-gauge matrices

```math
S^W_{mn}=\langle u_m^W|s|u_n^W\rangle,\qquad
T^W_{mn}=\langle u_m^W|sH_{\mathbf k}|u_n^W\rangle,
```
```math
R^W_{a,mn}=i\langle u_m^W|s|\partial_a u_n^W\rangle,\qquad
Q^W_{a,mn}=i\langle u_m^W|sH_{\mathbf k}|\partial_a u_n^W\rangle.
```

The operator order in $`T,Q`$ is $`sH`$, without Hermitian symmetrization.
In the unshifted Bloch-sum convention, $`R^W`$ and $`Q^W`$ are the Fourier sums of
$`\langle0m|s(r_a-R_a)|\mathbf Rn\rangle`$ and
$`\langle0m|sH(r_a-R_a)|\mathbf Rn\rangle`$, respectively.
The lattice-vector subtraction and matched center-convention transformation
must be retained. These connections are not generally products of separately
projected spin, Hamiltonian and position matrices.

Let $`u^H=u^WU`$, $`E=U^\dagger H^WU`$, and $`D_a=U^\dagger\partial_aU`$.
Below, $`S,T,R,Q`$ denote $`U^\dagger(\cdot)^WU`$, rather than connections
obtained by differentiating $`u^H`$ directly. Product differentiation gives

```math
\langle u_m^H|s|\partial_a u_n^H\rangle=(-iR_a+SD_a)_{mn},\qquad
\langle u_m^H|sH_{\mathbf k}|\partial_a u_n^H\rangle=(-iQ_a+TD_a)_{mn}.
```

Here $`(SD_a)_{mn}=\sum_l S_{ml}D_{a,ln}`$ and likewise for $`TD_a`$.
Differentiating the full eigen-equation yields, on nondegenerate differentiable
branches,

```math
L_{a,mn}=\langle u_m^H|s\partial_aH_{\mathbf k}|u_n^H\rangle
=S_{mn}\partial_aE_n+E_n\langle u_m^H|s|\partial_a u_n^H\rangle
-\langle u_m^H|sH_{\mathbf k}|\partial_a u_n^H\rangle.
```

Thus $`L_a=B_a+(-iR_a+SD_a)E-(-iQ_a+TD_a)`$, with
$`B_{a,mn}=S_{mn}\partial_aE_n`$ in that nondegenerate limit, and the physical
operator is $`(L_a+L_a^\dagger)/(2\hbar)`$ for physical-spin input.
An exactly degenerate block requires its Hamiltonian derivative as a matrix;
individual diagonal energy derivatives alone are insufficient in a general block frame.

The implemented finite-width prescription uses the single parameter
`numerics.denominator_regularization` in eV, default **0.001 eV**. It must be
finite and strictly positive for every spin-current task and every shared
`SPIN_VELOCITY` request. Zero, negative values, NaN and infinity are unsupported;
there is no implicit floor or zero-width fallback. With
$`G_a=U^\dagger(\partial_a H^W)U`$ and $`\Delta_{ln}=E_l-E_n`$,

```math
(D_{a,\eta})_{ln}=-G_{a,ln}\frac{\Delta_{ln}}{\Delta_{ln}^2+\eta^2},\qquad
w_{ln}=\frac{\eta^2}{\Delta_{ln}^2+\eta^2},\qquad
B_{a,\eta}=S(w\odot G_a).
```

The implementation retains the original real diagonal of $`G_a`$ once and adds
the off-diagonal weighted sum. In particular, $`\Delta=0`$ gives $`D_\eta=0,w=1`$.
The complementary weight restores the Hamiltonian-derivative contribution:

```math
[D_{a,\eta},E]=(1-w)\odot G_a,\qquad
B_{a,\eta}+S[D_{a,\eta},E]=SG_a,
```
```math
L_{a,\eta}=SG_a+i(Q_a-R_aE)-(T-SE)D_{a,\eta}.
```

This is an algebraic identity of the prescribed matrices; finite-width $`D_\eta`$
is not the exact eigenvector derivative. Smoothing changes finite-gap channels
as well as near-degenerate ones. The weight is neither an occupation nor a
multiplier on the entire response. It introduces no energy averaging, new band
grouping, or torque-dipole correction. Existing optical generalized-derivative
and frequency prescriptions retain their separate roles.

The hard spin-current `degeneracy_threshold` is retired. Explicitly supplying it
in a spin-current task raises `SPIN_CURRENT_DEGENERACY_THRESHOLD_REMOVED` and
instructs the user to remove it from that task. It is not presented as a parameter
conversion. Other tasks keep their own threshold semantics, including in a mixed
run. Changing $`\eta`$ invalidates the shared connection, spin-current vertex and
raw-spin prerequisite before reuse.

SPN and matrix-element construction preserve upstream spin units. The raw stored
vertex $`(L+L^\dagger)/2`$ has units input-spin times eV Angstrom. The released
ISC/SSC convention uses dimensionless Pauli input and existing response prefactors;
conversion of the final Pauli current to angular-momentum current uses $`\hbar/2`$
externally. Do not insert this factor a second time in the shared vertex.

The strict eigen-equation derivation does not by itself prove exactness for an
arbitrary truncated or disentangled Wannier subspace. Matrix-source finite
differences, interpolation and energy-window limitations remain. A complete
finite-basis anticommutator test checks algebra and units, not material convergence.
The definitions and real-space signs follow Ryoo, Park and Souza,
[arXiv:1906.07139](https://arxiv.org/abs/1906.07139), Eqs. (2)--(4), (20)--(30), (35).
