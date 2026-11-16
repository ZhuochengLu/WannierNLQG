# Subspace position matrix elements and the Sylvester contract

## 1. Position matrix elements from Wannier interpolation

Let the columns of $W(\mathbf k)$ be a smooth orthonormal Wannier-gauge
Bloch frame. Superscripts $(W)$ and $(H)$ denote Wannier and Hamiltonian
eigenframes. Cartesian $\partial_a$ differentiates with respect to $k_a$.
Schematically, real-space Hamiltonian and position data interpolate as

$$
H^{(W)}(\mathbf k)=\sum_{\mathbf R}e^{i\mathbf k\cdot\mathbf R}H(\mathbf R),
\qquad
A^{a,(W)}(\mathbf k)=\sum_{\mathbf R}e^{i\mathbf k\cdot\mathbf R}r^a(\mathbf R).
$$

The actual interpolator applies its specified center phases and replica
weights. In the same Fourier convention, the analytic derivative is

$$
\partial_aH^{(W)}(\mathbf k)
=\sum_{\mathbf R}iR_a e^{i\mathbf k\cdot\mathbf R}H(\mathbf R).
$$

$R_a$ is a Cartesian length; $H$ is in eV, $A^a$ and $r^a$ in Å, and
$k_a$ in Å$^{-1}$. The physical connection and projected position are

$$
A^{a,(W)}=iW^\dagger\partial_aW,
\qquad
X^{a,(W)}=i\partial_a+A^{a,(W)}.
$$

Hamiltonian, position, overlap and derivative data must share the source
gauge, center convention and momentum topology. With a unitary diagonalizer,
define

$$
H^{(W)}U=U\varepsilon,
\qquad
H^{(H)}=U^\dagger H^{(W)}U
=\varepsilon=\mathrm{diag}(E_1,\ldots,E_N),
\qquad
\bar A^{a,(H)}=U^\dagger A^{a,(W)}U.
$$

The physical eigenframe connection contains both the transformed Wannier
connection and the eigenvector derivative:

$$
A^{a,(H)}=\bar A^{a,(H)}+iU^\dagger\partial_aU.
$$

For distinct bands its off-diagonal entries are interband position matrix
elements $r_{nm}^{a,(H)}$.

## 2. The internal denominator and Conventional regularization

Differentiate the eigenvalue equation and project between states $n$ and
$m$. Define the derivative vertex and signed gap by

$$
h^{a,(H)}=U^\dagger(\partial_aH^{(W)})U,
\qquad
\Delta_{nm}=E_n-E_m.
$$

For $n\ne m$, orthonormality gives

$$
h_{nm}^{a,(H)}
+\Delta_{nm}(U^\dagger\partial_aU)_{nm}=0.
$$

Provided $\Delta_{nm}\ne0$,

$$
r_{nm}^{a,(H)}
=\bar A_{nm}^{a,(H)}
-i\frac{h_{nm}^{a,(H)}}{\Delta_{nm}}.
$$

The transformed Wannier connection is one contribution to this
position-interpolation formula; the eigenvector derivative is its internal
contribution. These names are distinct from the decomposition defined in
[Quantum metric](QuantumGeometry/QuantumMetric.md). At exact degeneracy,
the eigenvectors within the level are not unique. The projected equation
then yields $h_{nm}^{a,(H)}=0$ within
a complete degenerate level but cannot determine an eigenvector derivative
by division. A small nonzero gap is well defined and may give a large
cross-level matrix element.

The existing Conventional method replaces this inverse gap by

$$
\frac{1}{\Delta_{nm}}
\longrightarrow
\frac{\Delta_{nm}}{\Delta_{nm}^2+\eta^2},
\qquad
r_{nm}^{a,(H)}(\eta)
=\bar A_{nm}^{a,(H)}
-i h_{nm}^{a,(H)}
\frac{\Delta_{nm}}{\Delta_{nm}^2+\eta^2}.
$$

$\eta$ has energy units. At fixed nonzero gap, $\eta\to0$ recovers the
strict expression. At $\Delta_{nm}=0$ and $\eta>0$, a zero internal term
is a regularization convention, not a unique eigenvector derivative or a
gauge-invariant individual-band value. This geometric $\eta$ differs from
physical interband damping in response denominators. Conventional retains
its existing prescription.

## 3. Composite subspaces and the Sylvester equation

Select a target subspace $S$ of the Wannier window and its orthogonal
complement $T$ within that window. The target may contain several different
energies, but each degenerate level must lie entirely on one side of the
boundary. Its Wannier-frame projector is

$$
R^{(W)}=U_SU_S^\dagger.
$$

It obeys the idempotency and Hamiltonian-invariance identities,
respectively:

$$
(R^{(W)})^2=R^{(W)}.
$$

$$
[H^{(W)},R^{(W)}]=0.
$$

Idempotency means that $R^{(W)}$ selects a subspace; commutation means
the selected space is invariant under the Hamiltonian. In a moving
Wannier frame, an operator must be differentiated covariantly:

$$
D_a^{(W)}O^{(W)}
=\partial_aO^{(W)}-i[A^{a,(W)},O^{(W)}].
$$

The commutator accounts for motion of the physical Wannier frame.
Differentiating idempotency with this derivative gives

$$
(D_a^{(W)}R^{(W)})R^{(W)}
+R^{(W)}(D_a^{(W)}R^{(W)})
=D_a^{(W)}R^{(W)}.
$$

Multiplying on both sides first by $R^{(W)}$ and then by $1-R^{(W)}$
shows that the derivative has no block-diagonal parts:

$$
R^{(W)}(D_a^{(W)}R^{(W)})R^{(W)}=0,
\qquad
(1-R^{(W)})(D_a^{(W)}R^{(W)})(1-R^{(W)})=0.
$$

In an eigenframe ordered as $S,T$, write the cross-block part as

$$
D_a^{(H)}R^{(H)}
=\begin{pmatrix}0&X_a^\dagger\\X_a&0\end{pmatrix},
\qquad
X_a=(D_a^{(H)}R^{(H)})_{TS}.
$$

Next covariantly differentiate the commutation identity:

$$
[D_a^{(W)}H^{(W)},R^{(W)}]
+[H^{(W)},D_a^{(W)}R^{(W)}]=0.
$$

Its $TS$ block is

$$
(D_a^{(H)}H^{(H)})_{TS}
+H_T^{(H)}X_a-X_aH_S^{(H)}=0.
$$

The Hamiltonian-frame covariant vertex is the unitary transform of the
Wannier-frame one. It need not vanish even though $H^{(H)}$ is diagonal
at the evaluation point:

$$
V_{TS}^a
:=(D_a^{(H)}H^{(H)})_{TS}
=\bigl[U^\dagger(D_a^{(W)}H^{(W)})U\bigr]_{TS}.
$$

The Sylvester equation for the projector derivative follows:

$$
\boxed{H_T^{(H)}X_a-X_aH_S^{(H)}=-V_{TS}^a.}
$$

In the moving eigenframe $R^{(H)}$ is constant. Its covariant derivative
therefore has $TS$ block $-iA_{TS}^{a,(H)}$. Consequently the physical
cross-block position is

$$
r_{TS}^{a,(H)}=iX_a.
$$

The equivalent position-matrix Sylvester equation is

$$
\boxed{
H_T^{(H)}r_{TS}^{a,(H)}
-r_{TS}^{a,(H)}H_S^{(H)}=-iV_{TS}^a.
}
$$

The same identity holds for any pair of disjoint spectral or composite
blocks $A,B$. In the energy eigenbasis it becomes

$$
r_{nm}^{a,(H)}=-i\frac{V_{nm}^a}{E_n-E_m},
\qquad n\in B,\quad m\in A.
$$

The vertex can be written in terms of the interpolated ingredients of
Section 2:

$$
V_{nm}^a
=h_{nm}^{a,(H)}
+i(E_n-E_m)\bar A_{nm}^{a,(H)}.
$$

Substitution reproduces the strict Wannier-interpolated position
matrix element. The Sylvester formulation only asks for cross-block
derivatives of complete, separated subspaces; it never divides between
arbitrarily chosen eigenvectors *inside* a degenerate level.

The map $X\mapsto H_B^{(H)}X-XH_A^{(H)}$ is invertible precisely when
the spectra of $H_A^{(H)}$ and $H_B^{(H)}$ do not intersect. In an
energy eigenbasis, each entry uses its actual gap; no dense Sylvester
solver is needed. Exact degeneracy within a block is harmless. Splitting
one degenerate level across blocks destroys uniqueness. Near a gap
closing, the solution can still become large. The numerical
spectral-gap tolerance rejects unresolved boundaries; it does not smooth
or average nearby but distinct energies.

Under independent changes of basis inside $A$ and $B$, the complete
matrices transform as

$$
H_A^{(H)}\mapsto G_A^\dagger H_A^{(H)}G_A,
\qquad
H_B^{(H)}\mapsto G_B^\dagger H_B^{(H)}G_B,
\qquad
r_{BA}^{a,(H)}\mapsto G_B^\dagger r_{BA}^{a,(H)}G_A.
$$

The vertex has the same cross-block transformation, so the equation
remains covariant even when a rotated composite-block basis is not an
energy eigenbasis. The equation does not determine block-interior
connections $A_{AA}^{a,(H)}$ or $A_{BB}^{a,(H)}$. They retain their
native position/overlap inputs and inhomogeneous gauge transformation.

For an analytic check, take two states in each block and choose

$$
H_A^{(H)}=0\,I_2,
\qquad
H_B^{(H)}=\Delta I_2,
\qquad
V_{BA}^a=V,
\qquad
\Delta\ne0.
$$

Then

$$
r_{BA}^{a,(H)}=-\frac{i}{\Delta}V,
\qquad
H_B^{(H)}r_{BA}^{a,(H)}
-r_{BA}^{a,(H)}H_A^{(H)}+iV=0.
$$

Independent non-diagonal unitary rotations of the blocks preserve
the residual and gauge-invariant contractions.

## References

1. J. Ibañez-Azpiroz, S. S. Tsirkin and I. Souza, Phys. Rev. B 97, 245143 (2018),
   https://doi.org/10.1103/PhysRevB.97.245143.
2. J. Mitscherling, A. Avdoshkin and J. E. Moore, Gauge-invariant projector calculus
   for quantum state geometry and applications to observables in crystals,
   https://arxiv.org/abs/2412.03637.
