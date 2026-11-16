# Berry Curvature

## 1. Definition and representation convention

Berry curvature is the antisymmetric geometry of parallel transport in
momentum space. Cartesian indices $`a,b`$ refer to derivatives
$`\partial_a=\partial/\partial k_a`$. Superscripts $`(W)`$ and $`(H)`$
denote the Wannier and Hamiltonian eigenframes, following
[Subspace position matrix elements](../SubspacePositionMatrixElements.md).
The physical Wannier-frame connection and its Hamiltonian-frame form are

```math
A^{a,(W)}=iW^\dagger\partial_aW,
\qquad
A^{a,(H)}=U^\dagger A^{a,(W)}U+iU^\dagger\partial_aU,
\qquad
H^{(W)}U=U\varepsilon.
```

For an isolated band, the diagonal connection and its curvature are

```math
A_n^a=i\langle u_n|\partial_a u_n\rangle,
\qquad
\Omega_n^{ab}=\partial_aA_n^b-\partial_bA_n^a.
```

The off-diagonal $`r_{nm}^{a,(H)}=A_{nm}^{a,(H)}`$ for $`n\ne m`$ is the
physical interband position element. This sign convention gives

```math
Q_n^{ab}
=\langle\partial_a u_n|
(1-|u_n\rangle\langle u_n|)
|\partial_bu_n\rangle,
\qquad
\Omega_n^{ab}=-2\mathrm{Im}\,Q_n^{ab}.
```

## 2. Wannier-frame derivative overlap and ambient curvature

The physical derivative overlap is distinct from curvature. With
$`P_W=WW^\dagger`$ the full-Hilbert-space projector onto the retained
Wannier window, define

```math
[F_{\partial}^{ab,(W)}]_{\alpha\beta}
=\langle\partial_a u_\alpha^{(W)}
|\partial_bu_\beta^{(W)}\rangle,
\qquad
K^{ab,(W)}=F_{\partial}^{ab,(W)}
-A^{a,(W)}A^{b,(W)}.
```

Equivalently,

```math
[K^{ab,(W)}]_{\alpha\beta}
=\langle\partial_a u_\alpha^{(W)}
|(1-P_W)|\partial_bu_\beta^{(W)}\rangle.
```

The non-Abelian curvature of the Wannier-frame connection is

```math
\mathcal F^{ab,(W)}
=\partial_aA^{b,(W)}-\partial_bA^{a,(W)}
-i[A^{a,(W)},A^{b,(W)}]
=i\bigl(K^{ab,(W)}-K^{ba,(W)}\bigr).
```

This identity follows by differentiating
$`A^{a,(W)}=iW^\dagger\partial_aW`$, canceling the mixed second
derivatives, and separating the intermediate identity into $`P_W`$ and
$`1-P_W`$. It makes clear why $`F_{\partial}^{ab,(W)}`$, the derivative
overlap, is not itself $`\mathcal F^{ab,(W)}`$. The latter is the ambient
curvature associated with the retained physical frame.

In the Hamiltonian eigenframe the ambient curvature is

```math
\mathcal F^{ab,(H)}
=U^\dagger\mathcal F^{ab,(W)}U.
```

## 3. Complete band and target-subspace curvature

The complete isolated-band curvature splits into a finite-window
interband part and an ambient part:

```math
\Omega_n^{ab}
=-2\mathrm{Im}\,\sum_{m\ne n}^{\text{Wannier window}}
r_{nm}^{a,(H)}r_{mn}^{b,(H)}
+[\mathcal F^{ab,(H)}]_{nn}.
```

The sum without the ambient term equals the full result only when the
retained basis is complete for the relevant derivatives. Let $`S`$ be a
target subspace, $`T`$ its complement within the Wannier window, and
$`R^{(W)}=U_SU_S^\dagger`$. The trace curvature of $`S`$ is

```math
\Omega_S^{ab}
=\Omega_{S,\mathrm{internal}}^{ab}
+\Omega_{S,\mathrm{external}}^{ab},
```

where

```math
\Omega_{S,\mathrm{internal}}^{ab}
=-2\mathrm{Im}\,\mathrm{Tr}_S(X_a^\dagger X_b)
=-2\mathrm{Im}\,\sum_{I\in S,\,J\in T}
r_{IJ}^{a,(H)}r_{JI}^{b,(H)},
\qquad
X_a=(D_a^{(H)}R^{(H)})_{TS},
```

and

```math
\Omega_{S,\mathrm{external}}^{ab}
=\mathrm{Tr}[R^{(W)}\mathcal F^{ab,(W)}]
=i\mathrm{Tr}
\bigl[R^{(W)}(K^{ab,(W)}-K^{ba,(W)})\bigr].
```

Because $`K^{ba,(W)}=(K^{ab,(W)})^\dagger`$, this ambient contribution
is real and equals $`-2\mathrm{Im}\,\mathrm{Tr}[R^{(W)}K^{ab,(W)}]`$.
The symmetric real contraction of the same $`K`$ supplies the external
[quantum metric](QuantumMetric.md). The target trace has no division
by its rank. Intra-subspace transitions are excluded, making the trace
invariant under changes of basis within a complete isolated $`S`$.

For a multiband target, the non-Abelian subspace curvature matrix can
be written using its own connection:

```math
A_S^a
=U_S^\dagger A^{a,(W)}U_S
+iU_S^\dagger\partial_aU_S.
```

```math
\mathcal F_S^{ab}
=\partial_aA_S^b-\partial_bA_S^a-i[A_S^a,A_S^b],
\qquad
\Omega_S^{ab}=\mathrm{Tr}_S\mathcal F_S^{ab}.
```

Its matrix changes by conjugation under a unitary change of subspace
frame; its trace is invariant. The ambient term is not the curvature
of an arbitrary individual eigenvector inside an exact degeneracy.

## 4. Static geometry versus frequency-dependent response

The complete static curvature uses the antisymmetric imaginary part
of the same geometric tensor whose real symmetric part is the metric.
Neither static quantity stores the energies of all transitions omitted
outside a finite window. Consequently, adding the ambient curvature
does not reconstruct an arbitrary-frequency material response. The
projected-position contact term and its relation to clean dc transport
are derived in [linear transport](../LinearTransport.md). The exported
frequency-dependent anomalous-Hall mechanism is specified separately
in [linear optical response](../LinearOpticalResponse.md); at finite
frequency or broadening it is not a pointwise static Berry curvature.

## 5. Symmetry, normalization and references

The curvature is antisymmetric in its Cartesian indices:

```math
\Omega_S^{ab}=-\Omega_S^{ba}.
```

Time reversal maps an isolated band to its partner with opposite
curvature at $`-\mathbf k`$; inversion maps it with the same sign.
Where both symmetries constrain the same nondegenerate band, its
curvature vanishes pointwise. A target subspace uses an ordinary
trace rather than an average. The Berry-curvature dipole and
quadrupole differentiate this complete static curvature.

1. M. V. Berry, “Quantal phase factors accompanying adiabatic changes,”
   *Proc. R. Soc. Lond. A* **392**, 45–57 (1984). [DOI](https://doi.org/10.1098/rspa.1984.0023)
2. F. Wilczek and A. Zee, “Appearance of Gauge Structure in Simple Dynamical Systems,”
   *Phys. Rev. Lett.* **52**, 2111–2114 (1984). [DOI](https://doi.org/10.1103/PhysRevLett.52.2111)
3. X. Wang, J. R. Yates, I. Souza, and D. Vanderbilt, “Ab initio calculation of the anomalous Hall conductivity by Wannier interpolation,”
   *Phys. Rev. B* **74**, 195118 (2006). [DOI](https://doi.org/10.1103/PhysRevB.74.195118)
