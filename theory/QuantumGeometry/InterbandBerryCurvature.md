# Interband Berry Curvature

## 1. Definition and physical picture

Interband Berry curvature decomposes the total Berry curvature into transition channels between two specified band groups. It identifies which virtual transitions provide the dominant curvature and is therefore useful for comparing local geometric couplings between a valence-band group and different conduction-band groups.

## 2. Core theoretical formulas

For two disjoint subspaces $A,B$, first define the averaged interband QGT

$$
Q_{A,B}^{ab}
=\frac{1}{N_AN_B}
\sum_{m\in A,n\in B}r_{mn}^{a}r_{nm}^{b}.
$$

The interband Berry curvature in the release is

$$
\Omega_{A,B}^{ab}
=-\mathrm{Im}\left(Q_{A,B}^{ab}-Q_{A,B}^{ba}\right).
$$

## 3. Relation to isolated-band and subspace curvature

If $A=\{m\}$ and $B$ spans the complete complement of $m$, summing all channels recovers the internal isolated-band curvature $-2\mathrm{Im}\sum_{n\ne m}r_{mn}^{a}r_{nm}^{b}$. A finite $B$ gives only the selected transition channels; it is not the complete Berry curvature and contains neither unselected subspaces nor additional basis curvature.

## 4. Symbols, tensor indices, and subspace normalization

The labels $a,b$ are Cartesian directions, and $\Omega_{A,B}^{ab}=-\Omega_{A,B}^{ba}$. The result is divided by $N_AN_B$, namely it is averaged over the Cartesian product of the two subspaces; it is not $\mathrm{Tr}F_A$. Complete block contraction makes it invariant under unitary rotations within $A$ and within $B$.

## 5. Key symmetries and relations

- The quantity is a real antisymmetric tensor.
- Time reversal maps $(A,\mathbf k)$ to the corresponding Kramers subspace and reverses the curvature.
- Interband Berry curvature and interband quantum metric are the antisymmetric imaginary and symmetric real parts, respectively, of the same $Q_{A,B}^{ab}$.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Interband decomposition of the QGT | Projector expansions of the Provost–Vallée (1980) metric and Berry (1984) curvature | Take the parameter space to be $\mathbf k$ and use $r=i\langle u\vert\partial u\rangle$ |
| Two-subspace block contraction | Wilczek–Zee (1984), non-Abelian subspace geometry | Retain only the $A\leftrightarrow B$ channels and divide by $N_AN_B$ |
| Antisymmetric imaginary part | Standard QGT decomposition | Use the sign convention $\Omega=-\mathrm{Im}(Q^{ab}-Q^{ba})$ adopted here |

## 7. References

1. J. P. Provost and G. Vallée, “Riemannian structure on manifolds of quantum states,” *Commun. Math. Phys.* **76**, 289–301 (1980). [DOI](https://doi.org/10.1007/BF02193559)
2. M. V. Berry, “Quantal phase factors accompanying adiabatic changes,” *Proc. R. Soc. Lond. A* **392**, 45–57 (1984). [DOI](https://doi.org/10.1098/rspa.1984.0023)
3. F. Wilczek and A. Zee, “Appearance of Gauge Structure in Simple Dynamical Systems,” *Phys. Rev. Lett.* **52**, 2111–2114 (1984). [DOI](https://doi.org/10.1103/PhysRevLett.52.2111)
