# Quantum Metric

## 1. Definition and representation convention

The quantum metric measures the infinitesimal distance between neighboring
Bloch-state rays. Cartesian indices $a,b$ refer to momentum derivatives
$\partial_a=\partial/\partial k_a$. Throughout this document, superscripts
$(W)$ and $(H)$ mean the Wannier frame and Hamiltonian eigenframe, as in
[Subspace position matrix elements](../SubspacePositionMatrixElements.md).
The corresponding position connection and diagonalization are

$$
A^{a,(W)}=iW^\dagger\partial_aW,
\qquad
H^{(W)}U=U\varepsilon,
\qquad
A^{a,(H)}=U^\dagger A^{a,(W)}U+iU^\dagger\partial_aU.
$$

For distinct eigenstates, $r_{nm}^{a,(H)}=A_{nm}^{a,(H)}$ is the physical
interband position matrix element. Its strict and Conventional-regularized
construction, including the meaning of $\eta$, is derived in the linked
position-matrix document.

## 2. Isolated-band and target-subspace metric

For an isolated eigenstate $|u_n\rangle$, define the quantum geometric tensor
and its real symmetric part by

$$
Q_n^{ab}
=\langle\partial_a u_n|
(1-|u_n\rangle\langle u_n|)
|\partial_bu_n\rangle,
\qquad
g_n^{ab}=\operatorname{Re}Q_n^{ab}.
$$

In a complete Hilbert-space basis, this can be written as

$$
g_n^{ab}
=\operatorname{Re}\sum_{m\ne n}
r_{nm}^{a,(H)}r_{mn}^{b,(H)},
\qquad
ds^2=g_n^{ab}dk_a dk_b.
$$

Let $S$ be a target subspace, $T$ its complement *inside* the Wannier
window, and $R^{(W)}=U_SU_S^\dagger$. For an isolated target subspace,
the complete metric is a trace over the target, with no rank division:

$$
g_S^{ab}=g_{S,\mathrm{internal}}^{ab}
+g_{S,\mathrm{external}}^{ab}.
$$

The internal term resolves transitions to $T$:

$$
g_{S,\mathrm{internal}}^{ab}
=\operatorname{Re}\operatorname{Tr}_S(X_a^\dagger X_b)
=\operatorname{Re}\sum_{I\in S,\,J\in T}
r_{IJ}^{a,(H)}r_{JI}^{b,(H)},
\qquad
X_a=(D_a^{(H)}R^{(H)})_{TS}.
$$

The cross-block derivative $X_a$ and its Sylvester equation are defined
in the position-matrix document. Intra-subspace transitions are excluded:
rotating a complete $S$ changes its basis but not $g_S^{ab}$. A single-band
metric and the metric of a composite subspace are therefore different
objects when the composite space has internal transitions.

## 3. Geometry outside the Wannier window

Let $P_W=WW^\dagger$ project onto the Wannier window in the full
Hilbert space. The full physical derivative overlap is the Wannier-frame
matrix

$$
[F_{\partial}^{ab,(W)}]_{\alpha\beta}
=\langle\partial_a u_\alpha^{(W)}
|\partial_bu_\beta^{(W)}\rangle.
$$

With matrix multiplication in the Wannier frame, define

$$
K^{ab,(W)}
=F_{\partial}^{ab,(W)}
-A^{a,(W)}A^{b,(W)}.
$$

Its matrix elements explicitly resolve directions outside that window:

$$
[K^{ab,(W)}]_{\alpha\beta}
=\langle\partial_a u_\alpha^{(W)}
|(1-P_W)|\partial_bu_\beta^{(W)}\rangle.
$$

The missing term in a finite-window interband sum is thus

$$
g_{S,\mathrm{external}}^{ab}
=\operatorname{Re}\operatorname{Tr}
\bigl[R^{(W)}K^{ab,(W)}\bigr].
$$

For one band, this becomes the corresponding diagonal entry of
$U^\dagger K^{ab,(W)}U$. The real symmetric part of the complete result
is positive semidefinite. Numerical clipping of negative eigenvalues
would conceal an input or convention error rather than supply missing
geometry.

Finite-window products of MMN overlaps do not prove completeness of
$F_{\partial}^{ab,(W)}$. The release requires validated full
uIu-derived derivative-overlap provenance; missing, unknown or
finite-window-only sources are rejected. A validated Packed operator
can be used without retaining its raw upstream file at runtime. This
input is independent of energy-weighted orbital-magnetization operators.
Completeness of the source and convergence of its upstream momentum mesh
are distinct checks.

## 4. Regularization, output definitions and derivatives

The Conventional internal term retains its prescribed
$r^{a,(H)}(\eta)$, so nonzero $\eta$ denotes regularized metric
geometry even after the external term is added. A target-subspace metric
excludes its internal transitions; an occupation-weighted band sum instead
adds $f_n g_n^{ab}$ for each band. A selected interband-pair metric is
a different object and receives no automatic single-band external trace.
At an exact degeneracy an arbitrary individual-band
assignment is not a gauge-invariant observable; the complete-subspace
trace has the appropriate invariance.

The local metric dipole, quadrupole and Christoffel combinations are
formed from the *complete* metric at every shifted momentum:

$$
D_S^{ab;c}=\partial_cg_S^{ab},
\qquad
Q_{g,S}^{ab;cd}=\partial_c\partial_dg_S^{ab}.
$$

The finite-difference implementation differentiates the moving target
and Wannier frame as well as $K^{ab,(W)}$; it does not demand third- or
fourth-order derivative-overlap input. Stencil-step convergence and
upstream-overlap-mesh convergence must be assessed separately. Existing
primary outputs denote internal geometry by default (`include_external=false`).
Orthogonal internal inputs need H/r; nonorthogonal localized inputs need H/S/r.
Full derivative overlaps are required only for external completion, while other
tasks in a mixed bundle retain their independent operator demands. Point-orbital
and fixed-orthonormal native constructors support applicable internal tasks but
cannot provide external completion. Explicit-basis analytic input must declare
`operators.derivative_overlap` and its required connection data. In TOML, task-local `response.tasks.<id>.include_external` overrides
shared `response.include_external`; interband-pair and Zeeman-interband metrics
retain their separate definitions. With `include_external=true`,
the primary result is total and `_internal`/`_external` companion files retain
the same columns and units. Nonorthogonal input currently supports only the
internal setting; requesting external completion is an explicit error.

For example, a moving one-band frame in a two-dimensional Hilbert space,

$$
u(k)=\bigl(\cos(\sin k),\,\sin(\sin k)\bigr),
$$

has zero internal metric and nonzero external metric and derivatives:

$$
g(k)=\cos^2k,
\qquad
\partial_kg=-\sin(2k),
\qquad
\partial_k^2g=-2\cos(2k).
$$

This example detects implementations that return only the finite-window
internal term. A static metric does not encode the energies of all omitted
transitions and is not, by itself, an arbitrary-frequency conductivity.

## 5. Symmetry and related geometry

The metric is real and symmetric, and its quadratic form is nonnegative:

$$
g_S^{ab}=g_S^{ba},
\qquad
x_ag_S^{ab}x_b\ge0
\quad\text{for real }x_a.
$$

For an isolated band and the $A^a=+i\langle u|\partial_a u\rangle$
convention, $Q_n^{ab}=g_n^{ab}-i\Omega_n^{ab}/2$; the imaginary
antisymmetric part is discussed in [Berry curvature](BerryCurvature.md).
The metric is even under the appropriate time-reversal and inversion
momentum mappings, while its momentum derivatives have corresponding
opposite parity. A local metric or its derivatives do not alone determine
a weighted, integrated material response.

## 6. Formula provenance and references

The metric on quantum-state rays follows Provost and Vallée. The
finite-window decomposition above follows directly from inserting
$1=P_W+(1-P_W)$ into the full Hilbert-space projector. The Sylvester
construction of $X_a$ is derived in the linked position-matrix document.

1. J. P. Provost and G. Vallée, “Riemannian structure on manifolds of quantum states,”
   *Commun. Math. Phys.* **76**, 289–301 (1980). [DOI](https://doi.org/10.1007/BF02193559)
2. F. Wilczek and A. Zee, “Appearance of Gauge Structure in Simple Dynamical Systems,”
   *Phys. Rev. Lett.* **52**, 2111–2114 (1984). [DOI](https://doi.org/10.1103/PhysRevLett.52.2111)
