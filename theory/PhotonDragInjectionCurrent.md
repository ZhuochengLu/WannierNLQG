# Photon-Drag Injection Current

## 1. Definition and physical picture

Photon-drag injection current (PDIC) is the asymmetric injection of carriers at finite photon momentum. Unlike the transition displacement underlying PDSC, PDIC is controlled by the group-velocity difference between the two states after photoexcitation. The photon momentum $\mathbf q$ connects states at different crystal momenta and can relax some of the symmetry restrictions present at $q=0$.

## 2. Core theoretical formula

Define

$$
\alpha=(n_\alpha,\mathbf k-\mathbf q/2),
\qquad
\beta=(n_\beta,\mathbf k+\mathbf q/2).
$$

The injection-rate tensor in the ordered-field normalization of the release is

$$
\eta_{\mathrm{PDIC}}^{abc}(\mathbf q,\omega)=
\frac{\pi e^3}{\hbar^2\omega^2}
\int_{\mathrm{BZ}}[d\mathbf k]
\sum_{\alpha\beta}f_{\alpha\beta}
\delta(\omega_{\beta\alpha}-\omega)
\left(v_{\beta\beta}^{a}-v_{\alpha\alpha}^{a}\right)
v_{\alpha\beta}^{c}v_{\beta\alpha}^{b}.
$$

The scattering-free limit satisfies

$$
\frac{dj^a(\mathbf q)}{dt}
=2\sum_{bc}\eta_{\mathrm{PDIC}}^{abc}(\mathbf q,\omega)
E^b(\mathbf q,\omega)E^c(-\mathbf q,-\omega),
$$

where $\eta_{\mathrm{PDIC}}^{abc}$ is one ordered-field contribution. The outer factor $2$ combines $(\mathbf q,\omega)$ with the conjugate ordering $(-\mathbf q,-\omega)$; it is neither a $b\leftrightarrow c$ symmetrization nor the odd-$q$ postprocessing factor. In the single-relaxation-time approximation,

$$
\sigma_{\mathrm{PDIC}}^{abc}=\tau\eta_{\mathrm{PDIC}}^{abc},
\qquad
j_{\mathrm{dc}}^a(\mathbf q)
=2\sum_{bc}\sigma_{\mathrm{PDIC}}^{abc}(\mathbf q,\omega)
E^b(\mathbf q,\omega)E^c(-\mathbf q,-\omega).
$$

The release reports the $\tau$-free ordered contribution $\eta_{\mathrm{PDIC}}$.

## 3. Finite-momentum optical vertex

The finite-$q$ velocity vertex is a matrix element between states at two different crystal momenta:

$$
v_{\alpha\beta}^{b}
=\langle u_\alpha|\hat v_{\alpha\beta}^{b}|u_\beta\rangle,
\qquad
\hat v_{\alpha\beta}^{b}
=\frac{\hat v_{\mathbf k_\alpha}^{b}+\hat v_{\mathbf k_\beta}^{b}}{2}.
$$

Thus, $v_{\alpha\beta}^{c}v_{\beta\alpha}^{b}/\omega^2$ is the finite-$q$ transition intensity, while $v_{\beta\beta}^{a}-v_{\alpha\alpha}^{a}$ is the injection-velocity imbalance. In the $q\to0$ limit, the resonance relation recovers the length-gauge structure of ordinary injection current.

## 4. Symbols and tensor indices

The index $a$ denotes the output-current direction, and $b,c$ denote the ordered optical-field directions. Each of $\alpha,\beta$ includes a band and a displaced momentum. The definitions are $f_{\alpha\beta}=f_\alpha-f_\beta$ and $\omega_{\beta\alpha}=(\epsilon_\beta-\epsilon_\alpha)/\hbar$. No subspace average is taken: the sum represents the total over physical transition channels.

## 5. Key limits and symmetries

- The limit $\mathbf q\to0$ gives the velocity-gauge limit of ordinary injection current.
- In an inversion-symmetric system, an odd-$q$ channel satisfying $\eta(\mathbf q)=-\eta(-\mathbf q)$ can be nonzero.
- If the group velocities at the two endpoints of every resonant finite-$q$ transition are equal, PDIC vanishes, whereas PDSC need not vanish.
- Steady-state formulas that absorb both the conjugate ordering and $\tau$ into the displayed coefficient often contain $2\tau\pi e^3/(\hbar^2\omega^2)$. They give the same physical current after the field-ordering and relaxation-time conventions are aligned.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Finite-$q$ injection kernel | Lu et al., arXiv:2511.16987v2, photon-drag response equations | Write the composite indices as $\mathbf k\mp\mathbf q/2$, remove the external factor $\tau$, and keep the conjugate field ordering as the outer factor $2$ in the current |

## 7. References

1. Z. Lu, Z. Qian, Z. Guo, L. Shi, S. Liu, H. Wang, and K. Chang, “Giant Nonlinear Photon-Drag Currents in Moiré Bilayers,” arXiv:2511.16987v2 (2026 update), preprint. [arXiv](https://arxiv.org/abs/2511.16987)
