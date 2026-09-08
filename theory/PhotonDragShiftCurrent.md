# Photon-Drag Shift Current

## 1. Definition and physical picture

Photon-drag shift current (PDSC) is a displacement-type dc photocurrent driven by finite photon crystal momentum $\mathbf q$. The optical transition connects $\mathbf k-\mathbf q/2$ and $\mathbf k+\mathbf q/2$. The momentum $\mathbf q$ therefore participates in momentum conservation and also supplies an additional polar vector, allowing channels that are forbidden by inversion symmetry at $q=0$.

## 2. Finite-momentum shift-vector formula

Define

$$
\alpha=(n_\alpha,\mathbf k-\mathbf q/2),
\qquad
\beta=(n_\beta,\mathbf k+\mathbf q/2).
$$

Under the ordered-field convention of the release,

$$
\sigma_{\mathrm{PDSC}}^{abc}(\mathbf q,\omega)=
\frac{\pi e^3}{2\hbar^2\omega^2}
\int_{\mathrm{BZ}}[d\mathbf k]
\sum_{\alpha\beta}f_{\alpha\beta}
\delta(\omega_{\beta\alpha}-\omega)
v_{\beta\alpha}^{b}v_{\alpha\beta}^{c}
\left(R_{\beta\alpha}^{b;a}-R_{\alpha\beta}^{c;a}\right),
$$

$$
R_{\beta\alpha}^{b;a}
=i\partial_{k_a}\log v_{\beta\alpha}^{b}
+r_{\beta\beta}^{a}-r_{\alpha\alpha}^{a}.
$$

The finite-momentum velocity vertex can be written abstractly as

$$
v_{\alpha\beta}^{b}
=\langle u_\alpha|\hat v_{\alpha\beta}^{b}|u_\beta\rangle,
\qquad
\hat v_{\alpha\beta}^{b}
=\frac{\hat v_{\mathbf k_\alpha}^{b}+\hat v_{\mathbf k_\beta}^{b}}{2}.
$$

## 3. Geometric-loop formulation

Define a closed loop in which both endpoints are displaced along direction $a$:

$$
\mathcal L_{\beta\alpha}^{abc}(p)=
\langle u_\beta|
P_{\beta'}\hat v_{\beta'\alpha'}^{b}P_{\alpha'}
P_\alpha\hat v_{\alpha\beta}^{c}P_\beta
|u_\beta\rangle,
$$

where $\alpha'=(n_\alpha,\mathbf k_\alpha+p\hat{\mathbf e}_a)$, $\beta'=(n_\beta,\mathbf k_\beta+p\hat{\mathbf e}_a)$, and $D_p=i\partial_p$. Then

$$
\sigma_{\mathrm{PDSC}}^{abc}=
\frac{\pi e^3}{2\hbar^2\omega^2}
\int_{\mathrm{BZ}}[d\mathbf k]
\sum_{\alpha\beta}f_{\alpha\beta}
\delta(\omega_{\beta\alpha}-\omega)
\left[D_p\mathcal L_{\beta\alpha}^{abc}
-D_p\mathcal L_{\alpha\beta}^{acb}\right]_{p\to0^+}.
$$

Because the phases cancel point by point around the complete closed loop, its derivative is gauge invariant and obeys

$$
\left.D_p\mathcal L_{\beta\alpha}^{abc}\right|_{p=0}
=v_{\beta\alpha}^{b}v_{\alpha\beta}^{c}R_{\beta\alpha}^{b;a}.
$$

This identity establishes the equivalence between the finite-momentum shift-vector and Geometric Loop formulations.

## 4. Symbols, tensor indices, and subspace normalization

The index $a$ denotes both the output-current direction and the loop-derivative direction, while $b,c$ denote the two ordered optical polarizations. The labels $\alpha,\beta$ are composite indices consisting of a band and a displaced crystal momentum. In the degenerate case, $P_\alpha,P_\beta$ are replaced by the corresponding subspace projectors, and scalar products are replaced by complete block contractions. An independent finite-$q$ shift vector cannot be assigned to an arbitrary eigenvector within a band group.

## 5. Key limits and symmetries

- The limit $\mathbf q\to0$ recovers the $q=0$ geometric-loop shift current.
- Inversion simultaneously sends $\mathbf q\to-\mathbf q$. A centrosymmetric system can therefore support a PDSC component that is odd in $q$, even though conventional shift current vanishes at $q=0$.
- For $b\ne c$, the exchanged difference of the two loops cannot be omitted.
- A literature convention based on absorption transitions and real-field symmetrization has an explicit prefactor twice as large as the one used here.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Finite-$q$ shift vector and geometric loop | Shi et al. (2021), main-text geometric photon-drag construction | Rewrite the composite indices using the symmetric displacement $\mathbf k\mp\mathbf q/2$ and set the electron charge to $e<0$ |
| Quantum-geometric interpretation of PDSC | Xie–Nagaosa (2025), photon-drag BPVE theory sections | Standardize the field ordering to the ordered $(b,c)$ kernel |
| Velocity-gauge PDSC response | Lu et al. (2025), response-formula section, arXiv v2 | Retain the factor $1/2$ for the complete band-pair sum of the release and use the symmetrized velocity operator for the finite-$q$ vertex |

## 7. References

1. Z. Lu, Z. Qian, Z. Guo, L. Shi, S. Liu, H. Wang, and K. Chang, “Giant Nonlinear Photon-Drag Currents in Moiré Bilayers,” arXiv:2511.16987v2 (2026 update), preprint. [arXiv](https://arxiv.org/abs/2511.16987)
