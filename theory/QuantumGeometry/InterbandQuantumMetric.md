# Interband Quantum Metric

## 1. Definition and physical picture

The interband quantum metric measures wave-function variability between two specified band groups. It resolves the total Hilbert-space distance into contributions from selected virtual transitions and therefore identifies which conduction/valence-band channels dominate the local quantum metric.

## 2. Core theoretical formulas

Define

$$
Q_{A,B}^{ab}
=\frac{1}{N_AN_B}
\sum_{m\in A,n\in B}r_{mn}^{a}r_{nm}^{b}.
$$

The interband metric in the release is

$$
g_{A,B}^{ab}
=\frac12\mathrm{Re}\left(Q_{A,B}^{ab}+Q_{A,B}^{ba}\right).
$$

For $a=b$,

$$
g_{A,B}^{aa}
=\frac{1}{N_AN_B}\sum_{m\in A,n\in B}|r_{mn}^{a}|^2\ge0.
$$

## 3. Relation to the target-subspace metric

If $A$ is the target subspace and $B$ spans its complete complement, the internal contribution to $g_A^{ab}$ can be reconstructed after removing the average and summing with the physical trace. The interband quantity in the release always uses the $N_AN_B$ average, so its numerical magnitude cannot be compared directly with an ordinary target-subspace sum.

## 4. Symbols, tensor indices, and subspace normalization

The metric satisfies $g_{A,B}^{ab}=g_{A,B}^{ba}$ and is real. The subspaces $A,B$ must be disjoint, and the result is divided by $N_AN_B$ over $A\times B$. The object contains only the internal interband contribution of the selected groups and no symmetric external term associated with the finite window.

## 5. Key symmetries and relations

- Diagonal components are nonnegative, while off-diagonal components can have either sign.
- Interband quantum metric and interband Berry curvature are the symmetric real and antisymmetric imaginary parts, respectively, of the same $Q_{A,B}$.
- Time reversal and inversion generally map the metric evenly between the corresponding subspaces but do not require its momentum derivative to vanish.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Quantum-state metric | Provost–Vallée (1980), metric definition | Take the parameter to be Bloch momentum and project onto the specified complementary-space channel |
| Interband QGT block | Wilczek–Zee (1984), subspace gauge structure | Contract the blocks of two disjoint band groups and divide by $N_AN_B$ |
| Symmetric real part | Standard QGT decomposition | Explicitly symmetrize $a,b$ and retain only the real part |

## 7. References

1. J. P. Provost and G. Vallée, “Riemannian structure on manifolds of quantum states,” *Commun. Math. Phys.* **76**, 289–301 (1980). [DOI](https://doi.org/10.1007/BF02193559)
2. F. Wilczek and A. Zee, “Appearance of Gauge Structure in Simple Dynamical Systems,” *Phys. Rev. Lett.* **52**, 2111–2114 (1984). [DOI](https://doi.org/10.1103/PhysRevLett.52.2111)
