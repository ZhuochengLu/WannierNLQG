# Shift Spin Current

## 1. Definition and physical picture

Shift spin current (SSC) is a displacement-type Pauli current generated during an optical transition. It is not obtained by calculating the charge shift current and multiplying it by a spin expectation value: the spin-current vertex does not commute with the velocity, and the generalized derivative also contains a one-photon Pauli-current vertex, a two-photon vertex, and intermediate-band terms.

## 2. Core theoretical formula

The Pauli-current operator remains

$$
J_{\sigma}^{as}=\frac12\{v^a,\sigma^s\}.
$$

Under the ordered-field, complete-band-pair convention of the release, the Pauli-normalized SSC is

$$
\sigma_{\mathrm{SSC}}^{asbc}(\omega)=
\frac{i\pi |e|^2}{2\hbar^2\omega^2}
\int_{\mathrm{BZ}}[d\mathbf k]
\sum_{nm}f_{nm}\delta(\omega_{mn}-\omega)
\left(
d_{\sigma,mn}^{s,b;a}v_{nm}^{c}
-d_{\sigma,nm}^{s,c;a}v_{mn}^{b}
\right).
$$

## 3. Generalized Pauli-current derivative

In the conventions used here, the gauge-covariant combination of Lihm and Park is

$$
d_{\sigma,mn}^{s,b;a}
=j_{\sigma,mn}^{s,ab}
+\sum_{p\ne m}\frac{J_{\sigma,mp}^{sa}v_{pn}^{b}}{\omega_{mp}}
+\sum_{p\ne n}\frac{v_{mp}^{b}J_{\sigma,pn}^{sa}}{\omega_{np}},
$$

where the two-photon Pauli-current vertex is

$$
j_{\sigma}^{s,ab}=\frac{1}{2\hbar}\{\sigma^s,\mathcal M^{ab}\},
\qquad
\mathcal M^{ab}=\langle u|\partial_{k_a}\partial_{k_b}H|u\rangle_{\mathrm{cov}}.
$$

The quantity $\mathcal M^{ab}$ is the covariant second-order Hamiltonian, or effective-mass, vertex rather than the bare $\partial_a\partial_bH$. The matrix-multiplication order in the two intermediate-band terms cannot be exchanged.

## 4. Conversion from Lihm--Park Eq. (11) to the release convention

### 4.1 Frequency slots and resonant band labels in the paper

Lihm and Park define the general second-order tensor as
$\sigma_{\mathrm{LP}}^{s,a;bc}(\omega_{\mathrm{dc}};\omega_1,\omega_2)$.
Their Appendix B, Eq. (B12), then takes

$$
\omega_1=-\Omega,
\qquad
\omega_2=\Omega+\omega_{\mathrm{dc}},
\qquad
\omega_{\mathrm{dc}}\to0.
$$

Consequently, in their displayed dc tensor
$\sigma_{\mathrm{LP}}^{s,a;bc}(\Omega)$, the first optical index $b$ is attached
to the negative-frequency field $-\Omega$, while the second optical index $c$
is attached to the positive-frequency field $+\Omega$. With
$q=-|e|$, $f_{mn}=f_m-f_n$, and
$\omega_{mn}=(\epsilon_m-\epsilon_n)/\hbar$, their Eq. (11) is

$$
\begin{aligned}
\sigma_{\mathrm{LP}}^{s,a;bc}(\Omega)
={}&
\frac{i\pi q^3}{2\hbar^2V\Omega^2}
\sum_{\mathbf k,m,n}
f_{mn}\delta(\Omega+\omega_{mn})
B_{\mathrm{LP}}^{s,a;bc}(m,n),\\
B_{\mathrm{LP}}^{s,a;bc}(m,n)
={}&
d_{mn}^{s,b;a}v_{nm}^{c}
-d_{nm}^{s,c;a}v_{mn}^{b}.
\end{aligned}
$$

For $\Omega>0$, the resonance condition $\Omega+\omega_{mn}=0$ selects
$m$ as the lower-energy state and $n$ as the upper-energy state. The release
uses the opposite names for an absorption pair: its array element $(n,m)$ has
$n$ lower and $m$ upper, and its transition screen uses

$$
f_{nm}=f_n-f_m,
\qquad
\delta(\omega_{mn}-\omega),
\qquad
\omega_{mn}=\frac{\epsilon_m-\epsilon_n}{\hbar}>0.
$$

### 4.2 Simultaneous field-slot and band-pair conversion

The release stores the ordered contribution
$E^b(+\omega)E^c(-\omega)$. Therefore, matching a release component $(b,c)$ to
the paper requires both of the following substitutions. The change from the
paper's tensor layout $(s,a;b,c)$ to the release array layout $(a,s,b,c)$ is
only a storage permutation and contributes no sign.

$$
m_{\mathrm{LP}}=n_{\mathrm{rel}},
\qquad
n_{\mathrm{LP}}=m_{\mathrm{rel}},
\qquad
b_{\mathrm{LP}}=c_{\mathrm{rel}},
\qquad
c_{\mathrm{LP}}=b_{\mathrm{rel}},
\qquad
\Omega=\omega.
$$

The occupation and resonance factors then transform without an additional
sign:

$$
f_{m_{\mathrm{LP}}n_{\mathrm{LP}}}
=f_{n_{\mathrm{rel}}m_{\mathrm{rel}}},
\qquad
\delta\!\left(
\Omega+\omega_{m_{\mathrm{LP}}n_{\mathrm{LP}}}
\right)
=
\delta\!\left(
\omega_{m_{\mathrm{rel}}n_{\mathrm{rel}}}-\omega
\right).
$$

The matrix-element bracket does acquire a minus sign:

$$
\begin{aligned}
&B_{\mathrm{LP}}^{s,a;c_{\mathrm{rel}}b_{\mathrm{rel}}}
\left(
m_{\mathrm{LP}}=n_{\mathrm{rel}},
n_{\mathrm{LP}}=m_{\mathrm{rel}}
\right)\\
&\quad=
d_{n_{\mathrm{rel}}m_{\mathrm{rel}}}^{s,c_{\mathrm{rel}};a}
v_{m_{\mathrm{rel}}n_{\mathrm{rel}}}^{b_{\mathrm{rel}}}
-
d_{m_{\mathrm{rel}}n_{\mathrm{rel}}}^{s,b_{\mathrm{rel}};a}
v_{n_{\mathrm{rel}}m_{\mathrm{rel}}}^{c_{\mathrm{rel}}}\\
&\quad=
-K_{\mathrm{rel}}^{asb_{\mathrm{rel}}c_{\mathrm{rel}}}
(n_{\mathrm{rel}},m_{\mathrm{rel}}),
\end{aligned}
$$

where

$$
K_{\mathrm{rel}}^{asbc}(n,m)
=
d_{mn}^{s,b;a}v_{nm}^{c}
-
d_{nm}^{s,c;a}v_{mn}^{b}.
$$

Thus, the conversion is not a band-index exchange by itself. The resonant
band-pair relabeling and the optical-field-slot exchange must be performed
together.

### 4.3 Charge and Pauli-current normalization

Equation (B10) of Lihm and Park includes an output factor $q$ in the definition
of their charge-weighted spin current, so Eq. (11) contains $q^3$. The release
returns an uncharged, dimensionless Pauli-current response and therefore contains
only the two optical-coupling charge factors, $|e|^2=q^2$. After replacing the
paper's spin operator by the same dimensionless Pauli operator used by the
release, define

$$
\overline{\sigma}_{\mathrm{LP}}^{s,a;bc}
=
\frac{\sigma_{\mathrm{LP}}^{s,a;bc}}{q}.
$$

Combining this normalization with the band and field-slot conversion gives the
coefficient-level relation

$$
\boxed{
\sigma_{\mathrm{SSC,rel}}^{asbc}(\omega)
=
-\overline{\sigma}_{\mathrm{LP}}^{s,a;cb}(\omega)
=
-\frac{1}{q}\sigma_{\mathrm{LP}}^{s,a;cb}(\omega)
=
\frac{1}{|e|}\sigma_{\mathrm{LP}}^{s,a;cb}(\omega)
}.
$$

This relation assumes the same dimensionless Pauli operator on both sides. The
conversion from the release's Pauli current to a physical angular-momentum
current remains the separate factor $\hbar/2$.

Lihm and Park define the permutation of the two perturbing fields through the
factor $1/2$ and the explicit
$[(b,\omega_1)\leftrightarrow(c,\omega_2)]$ term in Appendix B, Eq. (B14), and
contract the resulting tensor as in their Eq. (14). The release instead declares
each stored $\sigma^{asbc}$ to be the $(+\omega,-\omega)$ ordered contribution
and writes the real-field dc current as

$$
j_{\sigma,\mathrm{dc}}^{as}
=
2\sum_{bc}
\sigma_{\mathrm{SSC,rel}}^{asbc}(\omega)
E^b(+\omega)E^c(-\omega).
$$

The outer factor $2$ belongs to this release-level current assembly. It is not
another factor in the boxed tensor conversion, is not a $b\leftrightarrow c$
symmetrization, and must not be inserted into the response kernel.

### 4.4 Direct correspondence with the implementation

The production kernel stores

```julia
response_kernel[n, m, a, s, b, c] =
    derivative[m, n, s, b, a] * velocity[n, m, c] -
    derivative[n, m, s, c, a] * velocity[m, n, b]
```

which is exactly $K_{\mathrm{rel}}^{asbc}(n,m)$ above. The transition screen
multiplies it by $f_n-f_m$ and by a Gaussian- or Lorentzian-broadened
$\delta(\epsilon_m-\epsilon_n-\hbar\omega)$. The runtime prefactor is

$$
\frac{i\hbar_{\mathrm{eV}}\pi |e|^2}
     {2\hbar_{\mathrm J}^2N_kV},
$$

where the discrete factor $(N_kV)^{-1}\sum_{\mathbf k}$ is the release
quadrature corresponding to the paper's $V^{-1}\sum_{\mathbf k}$, or to the
normalized Brillouin-zone integral used in Sec. 2. The factor
$\hbar_{\mathrm{eV}}/\hbar_{\mathrm J}^2$ implements the energy-delta and SI
unit conversion; it does not modify the index mapping.

The ideal factor $1/\Delta_{mn}^2$ is regularized in the implementation as

$$
\mathcal D_\eta(\Delta_{mn})
=
\frac{\Delta_{mn}^2}
     {(\Delta_{mn}^2+\eta^2)^2},
\qquad
\Delta_{mn}=\epsilon_m-\epsilon_n.
$$

Hence $\mathcal D_\eta\to1/\Delta_{mn}^2$ as $\eta\to0$, and on the resonant
shell this reproduces the $\omega^{-2}$ factor in the ideal formula. Integral
and K-slice calculations call the same kernel, so neither output requires a
subsequent $m\leftrightarrow n$ or $b\leftrightarrow c$ operation.

### 4.5 Identity-channel check against charge shift current

For the formal identity channel $\sigma^s\to\mathbb 1$, the release kernels obey

$$
\frac{K_{\mathrm{SSC,rel}}^{a1bc}(n,m)}
     {\Delta_{mn}^2}
=
-iK_{\mathrm{SC}}^{abc}(n,m).
$$

Using the release SSC prefactor $i\pi|e|^2/(2\hbar^2)$ and multiplying by the
signed output charge $-|e|$ then gives the charge-SC prefactor and the same
ordered component $(a,b,c)$. At finite $\eta$, the pairwise relation contains

$$
W(\Delta_{mn},\eta)
=
\Delta_{mn}^2\mathcal D_\eta(\Delta_{mn})
=
\frac{\Delta_{mn}^4}
     {(\Delta_{mn}^2+\eta^2)^2}.
$$

Therefore, for a multiband calculation the SSC--SC comparison is a sum of
pairwise SC contributions weighted by their own $W(\Delta_{mn},\eta)$; no single
global $W$ can generally be factored out. Only in the nondegenerate resonant
$\eta\to0$ limit does the same-component identity become exact.

## 5. Symbols, tensor indices, and Pauli normalization

The index order is fixed as $(a,s,b,c)$. The label $s=x,y,z$ denotes a dimensionless Pauli direction; the physical angular-momentum current is $\hbar\sigma_{\mathrm{SSC}}/2$. Near-degenerate energy denominators should be understood as a regularized limit involving finite bandwidth, disorder, or lifetime broadening. A divergence associated with a single band must not be interpreted as an observable.

The formal identity channel $\sigma^s\to\mathbb 1$ gives

$$
(-|e|)\,\sigma_{\mathrm{SSC}}^{a1bc}
=\sigma_{\mathrm{SC}}^{abc}
\qquad
(\text{nondegenerate resonant limit},\ \eta\to0).
$$

This is a same-component identity: both sides carry the same ordered Cartesian slots $(a,b,c)$. It uses the release's ordered-field convention and the signed output charge $-|e|$. At finite denominator regularization, each transition contains the factor

$$
W(\Delta,\eta)=\frac{\Delta^4}{(\Delta^2+\eta^2)^2},
\qquad
W\to1\quad(\eta\to0),
$$

so strict equality is asserted only in the stated formal limit. For a multiband response, $W(\Delta,\eta)$ remains inside the band-pair sum and is not generally a single overall scale factor. This regularization factor is unrelated to the Pauli-to-physical-spin conversion factor $\hbar/2$.

## 6. Key limits, symmetries, and relations

- Nonconservation of $J_\sigma$ does not prevent the conventional SSC from being defined, although alternative definitions of a “conserved spin current” may yield different responses.
- When $\sigma^s$ commutes with $H$ and the band states have definite Pauli polarization, SSC can be interpreted intuitively as the difference between the shift currents of two spin channels.
- The identity channel simultaneously checks the number of charge factors, field ordering, the full release prefactor, and the signs of the two intermediate-band terms.

## 7. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| $d^{s,b;a}$ and the two-photon vertex | Lihm–Park (2022), Eqs. (5)–(7) | Apply $S^s\to\sigma^s$ while preserving the ordered matrix products in the intermediate-band terms |
| SSC response | Lihm–Park (2022), Eq. (11) and Appendix B, Eqs. (B10), (B12), (B14), and (B44) | Apply the simultaneous band-pair and optical-slot conversion derived in Sec. 4, divide the paper's charge-weighted tensor by $q=-|e|$, and keep the release's outer ordered-field factor $2$ outside the response kernel |
| One-photon Pauli-current vertex | Qiao et al. (2018), Eqs. (22)–(51) | Use $J_\sigma=\{v,\sigma\}/2$ without an additional factor $\hbar/2$ |
| Identity channel | Comparison of Lihm–Park Eq. (11) with the charge shift-current expression | Multiply by the output charge $-|e|$; the same $(a,b,c)$ component equals SC in the nondegenerate resonant $\eta\to0$ limit, with no output-level index exchange |

## 8. References

1. J.-M. Lihm and C.-H. Park, “Comprehensive theory of second-order spin photocurrents,” *Phys. Rev. B* **105**, 045201 (2022). [DOI](https://doi.org/10.1103/PhysRevB.105.045201)
2. J. Qiao, J. Zhou, Z. Yuan, and W. Zhao, “Calculation of intrinsic spin Hall conductivity by Wannier interpolation,” *Phys. Rev. B* **98**, 214402 (2018). [DOI](https://doi.org/10.1103/PhysRevB.98.214402)
