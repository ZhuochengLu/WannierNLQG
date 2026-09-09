# Shift Vector

## 1. Definition and physical picture

The shift vector is the gauge-invariant real-space displacement associated with an optical transition. It combines the phase gradient of the transition matrix element with the difference between the Berry connections of the final and initial states. Each term separately depends on the Bloch gauge; only their combination is observable.

## 2. Core theoretical formula

For a transition $n\to m$ with polarization $b$, the shift vector along direction $a$ is

$$
R_{mn}^{b;a}
=i\partial_{k_a}\log r_{mn}^{b}
+r_{mm}^{a}-r_{nn}^{a}.
$$

Equivalently,

$$
iD_a r_{mn}^{b}=r_{mn}^{b}R_{mn}^{b;a},
\qquad
D_a r_{mn}^{b}
=\partial_{k_a}r_{mn}^{b}-i(r_{mm}^{a}-r_{nn}^{a})r_{mn}^{b}.
$$

At a node where $r_{mn}^{b}=0$, the isolated quantity $R$ can diverge, while the physical combination $|r_{mn}^{b}|^2R$ can remain finite.

## 3. Wilson Loop and Geometric Loop formulations

The Wilson formulation defines the shift vector through the phase of a four-point closed loop:

$$
R_{mn}^{b;a}
=\lim_{p\to0}\frac{1}{p}\mathrm{Im}\log W_{mn}^{b;a}(p),
$$

where $W$ contains the optical matrix element at the central point, its conjugate at the neighboring point, and two overlap links connecting bands $n,m$ separately. The Geometric Loop formulation instead constructs $\mathcal L$ from velocity vertices:

$$
R_{mn}^{b;a}
=\left.D_p\log\mathcal L_{mn}^{b;a}(p)\right|_{p=0},
\qquad D_p=i\partial_p.
$$

In both cases, the complete loop cancels the gauge phases point by point. At $q=0$ and on the resonant shell, the velocity- and length-gauge definitions are equivalent.

## 4. Symbols, tensor indices, and subspace boundary

The index $b$ denotes the transition polarization, and $a$ denotes the displacement direction. For isolated bands, $R_{mn}^{b;a}$ is real on a continuous branch modulo $2\pi/p$. When bands are degenerate, individual band phases are not meaningful. One must use the logarithmic derivative of the complete block loop rather than average phases obtained band by band within a subspace.

## 5. Key symmetries and relations

- The quantity $R$ has dimensions of length and represents the displacement of the wave-packet center during the transition.
- Inversion maps the contribution at $\mathbf k$ to a canceling contribution at $-\mathbf k$, so $q=0$ shift current vanishes in a centrosymmetric system.
- The shift vector itself contains no transition probability. Shift current additionally requires the optical weight, occupation difference, and resonance condition.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Shift-vector definition | Sipe–Shkrebtii (2000), shift-current/shift-vector equations | Standardize the Berry connection as $i\langle u\vert\partial u\rangle$; the electron charge does not enter $R$ |
| Generalized Wilson loop | Wang et al. (2022), Eqs. (1)–(4) | Orient the loop as $n\to m$ and specify the continuous branch through $p\to0$ |

## 7. References

1. J. E. Sipe and A. I. Shkrebtii, “Second-order optical response in semiconductors,” *Phys. Rev. B* **61**, 5337–5352 (2000). [DOI](https://doi.org/10.1103/PhysRevB.61.5337)
2. H. Wang, X. Tang, H. Xu, J. Li, and X. Qian, “Generalized Wilson loop method for nonlinear light-matter interaction,” *npj Quantum Materials* **7**, 61 (2022). [DOI](https://doi.org/10.1038/s41535-022-00472-4)
