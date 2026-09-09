# Quantum Metric

## 1. Definition and physical picture

The quantum metric measures the infinitesimal distance between neighboring rays of Bloch states in Hilbert space. Berry curvature describes the phase rotation under parallel transport, whereas the metric describes the rate at which a wave function changes with $\mathbf k$, or equivalently how distinguishable neighboring states are.

## 2. Core theoretical formulas

The quantum geometric tensor of an isolated band is

$$
Q_n^{ab}=\langle\partial_a u_n|
(1-|u_n\rangle\langle u_n|)
|\partial_bu_n\rangle.
$$

Its symmetric real part gives the metric:

$$
g_n^{ab}=\mathrm{Re}Q_n^{ab}
=\mathrm{Re}\sum_{m\ne n}r_{nm}^{a}r_{mn}^{b}.
$$

The distance between neighboring states is

$$
ds^2=g_n^{ab}dk_a dk_b.
$$

## 3. Target-subspace formulation

For a subspace $S$, the local quantity in the release is

```math
g_S^{ab}
=\sum_{\substack{I\in S\\J\notin S}}
\mathrm{Re}\left(r^{a}_{IJ}\,r^{b}_{JI}\right).
```

Intra-subspace transitions are excluded, so the expression measures only the variation between $S$ and its complement and is invariant under unitary rotations within $S$. The release provides the internal contribution within a finite window. If the finite basis itself varies with $\mathbf k$, a symmetric external term requiring additional matrix-element information may also exist; that term is not reconstructed here.

## 4. Symbols, tensor indices, and normalization

The metric satisfies $g^{ab}=g^{ba}$ and $x_ag^{ab}x_b\ge0$ for every real vector $x_a$. A target subspace uses an ordinary sum, with no division by $N_S$. This differs from the interband metric between two distinct band groups, which is divided by $N_AN_B$.

## 5. Key limits, symmetries, and relations

- For an isolated band, $Q_n^{ab}=g_n^{ab}-i\Omega_n^{ab}/2$ with the curvature convention used here.
- The metric is even under both time reversal and spatial inversion, although broken magnetic or inversion symmetry can produce nontrivial parity in its momentum derivatives.
- Flat-band superfluid weight, orbital magnetization, and several nonlinear responses can be controlled by the metric, but the K-slice output here is not itself any of those integral responses.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Riemannian metric on quantum-state space | Provost–Vallée (1980), definition of the metric tensor on rays | Take the parameters to be $\mathbf k$ and project the normalized state derivative perpendicular to the state itself |
| Bloch-band QGT decomposition | Standard band-projector expansion | Write the result as an interband sum using $r=i\langle u\vert\partial u\rangle$ |
| Multiband/finite-window boundary | Wilczek–Zee subspace geometry | Exclude transitions within $S$ and retain only the internal contribution determined by the current finite window |

## 7. References

1. J. P. Provost and G. Vallée, “Riemannian structure on manifolds of quantum states,” *Commun. Math. Phys.* **76**, 289–301 (1980). [DOI](https://doi.org/10.1007/BF02193559)
2. F. Wilczek and A. Zee, “Appearance of Gauge Structure in Simple Dynamical Systems,” *Phys. Rev. Lett.* **52**, 2111–2114 (1984). [DOI](https://doi.org/10.1103/PhysRevLett.52.2111)
