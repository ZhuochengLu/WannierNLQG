# Modern orbital magnetization

## 1. Definition and physical picture

The implemented observable is modern orbital magnetization (magnetic moment per primitive cell after Brillouin-zone integration), not an on-site orbital-angular-momentum matrix. The release resolves occupied-space self-rotation (`srocc`), center-motion (`cmocc`), and `total = srocc + cmocc`. The total is the target physical moment; the release's component names are a specified decomposition and should not be equated to other LC/IC conventions without an explicit map. A chemical potential never cuts an exact degenerate spectral block.

## 2. Core theoretical formula

At one $\mathbf k$, let $p$ contain all states below a zero-temperature chemical potential $\mu$, and let $q=1-p$. In the Hamiltonian frame, $r^a_{nm}$ is the cross-block physical connection, and $\widetilde F_{ab}$, $\widetilde B_a$, $\widetilde C_{ab}$ are the external-completion matrices defined in Sec. 3. The **implemented Conventional traces** are

$$
\mathcal F_{ab}=\sum_{n\in p}\left[\widetilde F_{nn,ab}+\sum_{m\notin p}r^a_{nm}r^b_{mn}\right],
$$

$$
\mathcal G_{ab}=\sum_{n\in p}\left[\widetilde C_{nn,ab}+\sum_{m\notin p}\left(\widetilde B^*_{mn,a}r^b_{mn}+r^a_{nm}\widetilde B_{mn,b}+E_mr^a_{nm}r^b_{mn}\right)\right],
$$

$$
\mathcal K_{ab}=\sum_{n\in p}E_n\left[\widetilde F_{nn,ab}+\sum_{m\notin p}r^a_{nm}r^b_{mn}\right].
$$

For axial component $i\leftrightarrow(a,b)=(y,z),(z,x),(x,y)$, define $\mathscr A_{ab}[X]=\mathrm{Im}(X_{ab}-X_{ba})$ and $g=e^2 10^{-20}/(2\hbar\mu_{\rm B})$ in the implementation's eV–Å units. At zero temperature the point moment in $\mu_{\rm B}$ is

$$
M^{i}_{\rm SRocc}=g\,\mathscr A_{ab}[\mathcal G-\mathcal K],\qquad
M^{i}_{\rm CMocc}=2g\,\mathscr A_{ab}[\mathcal K-\mu\mathcal F],\qquad
M^{i}_{\rm total}=M^{i}_{\rm SRocc}+M^{i}_{\rm CMocc}.
$$

This displays the program's sign, factor of two, Cartesian ordering, and occupied-space convention; it does not claim that every published LC/IC decomposition uses these labels.

## 3. Equivalent and Projector formulation

López *et al.* (2012), Eqs. (6)–(8), write the **full-Hilbert-space**
occupied-projector objects, using their $P$, $Q=1-P$, and Bloch Hamiltonian
$\widehat H$, as

$$
F^{\rm Lopez}_{ab}=\mathrm{Tr}[(\partial_aP)Q(\partial_bP)],\quad
G^{\rm Lopez}_{ab}=\mathrm{Tr}[(\partial_aP)Q\widehat H Q(\partial_bP)],\quad
H^{\rm Lopez}_{ab}=\mathrm{Tr}[\widehat H(\partial_aP)Q(\partial_bP)].
$$

Those are published projector identities. Their Eqs. (4)–(5) combine them
with the Fermi energy for the local- and itinerant-circulation tensors; their
Eqs. (71)–(72) are Wannier-space trace rearrangements. The following
**finite-Wannier-space external-completion implementation** is not any of
those equations copied verbatim. In particular, a $q$ restricted to finite
Wannier states is not the full-Hilbert $Q$ above.

In a **common uncentered periodic Wannier frame**, the supplied complete operator matrices $A_a$, $H$, $F_{ab}$, $B_a$, and $C_{ab}$ enter through

$$
\widetilde F_{ab}=F_{ab}-A_aA_b,\quad
\widetilde B_a=B_a-HA_a,\quad
\widetilde C_{ab}=C_{ab}-A_aB_b-B_a^\dagger A_b+A_aHA_b.
$$

After rotating all operators to the common orbital frame, form $p=U_{\rm occ}U_{\rm occ}^\dagger$, $q=1-p$, $h=U\mathrm{diag}(E)U^\dagger$, and $Z_a=q(D_ap)p$. The exact zero-width reference has cross-block matrix elements:

$$
(U^\dagger Z_aU)_{mn}=\frac{V^a_{mn}}{E_n-E_m},\quad m\notin p,\ n\in p;
\qquad (U^\dagger Z_aU)_{mn}=0\ \text{otherwise}.
$$

The independently implemented **Projector traces**, rather than a call to the Conventional result, are exactly

$$
\begin{aligned}
\mathcal F^{P}_{ab}&=\mathrm{Tr}\!\left[Z_a^\dagger Z_b+p\widetilde F_{ab}p\right],\\
\mathcal G^{P}_{ab}&=\mathrm{Tr}\!\left[Z_a^\dagger hZ_b
 +ip\widetilde B_a^\dagger Z_b-iZ_a^\dagger\widetilde B_b p
 +p\widetilde C_{ab}p\right],\\
\mathcal K^{P}_{ab}&=\mathrm{Tr}\!\left[h\left(Z_a^\dagger Z_b+p\widetilde F_{ab}p\right)\right].
\end{aligned}
$$

The same SRocc/CMocc contractions of Sec. 2 apply to these traces. External terms cannot be discarded for a material calculation. A declared complete, flat finite model may have zero external completion; missing material data are **not** zero completion.

At $T>0$ the code thermally convolves the zero-temperature occupied-subspace traces over intervals $(E_j,E_{j+1})$. With fixed $p_j$ on an interval, $w_j=\int_{E_j}^{E_{j+1}}[-f'(x)]\,dx$ and $m_j=\int_{E_j}^{E_{j+1}}x[-f'(x)]\,dx$ are evaluated analytically. The SRocc term uses $w_j\mathscr A[\mathcal G_j-\mathcal K_j]$ and CMocc uses $2\mathscr A[w_j\mathcal K_j-m_j\mathcal F_j]$. A smoothed density matrix is never substituted for an idempotent projector.

## 4. Symbols, indices, and normalization

$a,b$ are Cartesian directions and $i$ follows `yz, zx, xy`; $n,m$ denote Hamiltonian eigenstates, whereas $p$ is a **complete occupied exact-spectral-block projector**. $U$ is the eigenvector matrix; $V^a$ is the physical covariant Hamiltonian derivative in eV Å. $F$, $B$, and $C$ represent derivative-overlap, Hamiltonian-weighted connection, and energy-weighted derivative-overlap input; tilded forms subtract internal products. The axial part of $C$ suffices for the antisymmetric contraction. The point kernel is in $\mu_{\rm B}$ before normalized BZ weights; the integrated result is $\mu_{\rm B}$/cell. A spinor model has no automatic factor of two.

## 5. Applicability, limits, and qualification

- At $T=0$, a chemical potential exactly at a spectral interval boundary uses the symmetric average of the two complete occupied-subspace responses. No fractional density matrix is inserted as a projector.
- Exact degeneracies belong to one occupied block. Near but distinct energies are not silently merged. A material result requires common source, gauge, frame, operator-window, and thermal-tail evidence.
- Raw uIu finite differences and derivatives of an interpolated connection can differ on a coarse source mesh. Source-neighbor order, center phases, and discretization must be audited before comparison.
- The Projector trace above includes this project's **external-completion generalization**. Its implementation identity alone does not establish material convergence or production eligibility.

## 6. Formula provenance

| Formula or claim | Published source / implementation source | Attribution boundary |
| --- | --- | --- |
| Full-Hilbert projector objects and Wannier trace organization | López *et al.* (2012), Eqs. (4)–(8), (71)–(72) | Published $F,G,H$ and LC/IC formulas, distinct from the finite-Wannier external-completion equations below. |
| Conventional $\mathcal F,\mathcal G,\mathcal K$ and SRocc/CMocc contractions | `src/Responses/OrbitalMagnetization/OrbitalMagnetizationKernels.jl`, `conventional_magnetization_traces`, `orbital_magnetization_response` | **IMPLEMENTATION_FORMULA**; not attributed equation-by-equation to López *et al.* |
| $\widetilde F,\widetilde B,\widetilde C$ and Projector trace with $Z_a$ | `src/MatrixElements/Interpolated/OrbitalResponseOperators.jl`, `orbital_completion`; `src/Responses/OrbitalMagnetization/OrbitalMagnetizationKernels.jl`, `projector_magnetization_traces` | **Project-specific external-completion generalization** of the occupied-projector approach; not directly claimed as a 2012 formula. |
| Thermal interval convolution and exact-block gate | `orbital_magnetization_kernel`, `orbital_magnetization_response`; `spectral_response_geometry` | Release-specific numerical prescription. |

## 7. References

1. M. G. López, D. Vanderbilt, T. Thonhauser, and I. Souza, “Wannier-based calculation of the orbital magnetization in crystals,” *Phys. Rev. B* **85**, 014435 (2012). [DOI](https://doi.org/10.1103/PhysRevB.85.014435)
2. D. Xiao, M.-C. Chang, and Q. Niu, “Berry phase effects on electronic properties,” *Rev. Mod. Phys.* **82**, 1959–2007 (2010). [DOI](https://doi.org/10.1103/RevModPhys.82.1959)

See the [input and output contract](../docs/LINEAR_AND_ORBITAL_RESPONSES.md). Cite the release's Projector external-completion equations as project implementation rather than misattributing them to Ref. 1.


## 8. Positive-width complete-velocity prescription

The normal and expert OM response entries use one finite, strictly positive
`denominator_regularization` in eV, default **0.001 eV**. An expert metric geometry
already carrying an explicitly planned positive width retains that width when no
override is supplied. Normal tasks always pass their own resolved value explicitly.
Zero, negative, NaN and infinite values are unsupported for OM. There is no
bare fallback or width inferred from the entries of a position matrix.

Let $\mathcal V^a=\hbar v^a$ be the complete physical velocity vertex in eV Angstrom,
$p$ a complete occupied spectral projector and $q=1-p$. The new internal tangent is

$$
(Z_{a,\eta})_{mn}=\mathcal V^a_{mn}
\frac{E_n-E_m}{(E_n-E_m)^2+\eta^2},\qquad m\in q,\ n\in p.
$$

It minimizes $\|[H,Z]+q\mathcal V^ap\|_F^2+\eta^2\|Z\|_F^2$ under $Z=qZp$.
Thus $\|Z_{a,\eta}\|_F\le\|q\mathcal V^ap\|_F/(2\eta)$, and the construction is
unitarily covariant in a common physical orthonormal representation. No giant
Kronecker matrix is assembled in production: the existing robust scalar inverse
fills the band-frame connection

$$
(r^{\rm OM}_{a,\eta})_{mn}=-i\mathcal V^a_{mn}
\frac{E_m-E_n}{(E_m-E_n)^2+\eta^2}.
$$

Conventional uses this connection in Sec. 2, while Projector uses
$Z=-iqr^{\rm OM}_{\eta}p$ in the independent Sec. 3 traces. Both use the same
width and external completion. The supplied shared Berry connection is not
modified. The generic position buffer $i\Delta r_\eta$ is not a substitute for
complete $\mathcal V$.

For orthogonal input, write $G_a=U^\dagger(\partial_aH^W)U$,
$D_\eta=-G_a\Delta/(\Delta^2+\eta^2)$ and
$w=\eta^2/(\Delta^2+\eta^2)$. The OM connection is
$(1-w)\odot A+iD_\eta$, whereas the previous generic connection is $A+iD_\eta$.
Simply preserving that old Conventional connection while regularizing the
Projector inverse would define two different finite-width methods. Both OM
methods now change together; finite-width values need not equal old outputs.

For nonorthogonal input, $C^\dagger SC=I$. The existing matrices are
$G_S=C^\dagger S_aC$, $B=C^\dagger(r_a+iS_a)C$,
$A_{\rm eff}=B-iG_S/2$ and
$N_{mn}=(C^\dagger H_aC)_{mn}-(E_m+E_n)(G_S)_{mn}/2$.
They give $\mathcal V_{mn}=N_{mn}+i(E_m-E_n)(A_{\rm eff})_{mn}$.
The symmetric coefficient in $N$ is a generalized-eigenproblem identity; actual
energies and occupation boundaries are not averaged. The same complete-velocity
OM prescription applies in the S-normalized band frame. Nonorthogonal Projector
and material-completion support remain unsupported; Euclidean $CC^\dagger$ is
not introduced as a metric projector.

`gap_tolerance` is no longer an OM input or diagnostic control. Any explicit
value, including one inherited from `[response.numerics]`, reports that OM does
not support this parameter. Other responses and generic exact spectral tools
retain their existing controls. OM retains only the existing machine-precision
recognition of numerical equal-energy blocks, with no refusal for a small
nonzero interblock gap and no merging of physically split levels.

## 9. Zero-temperature spectral boundary

For an existing spectral interval boundary $E_*$, let $p_-$ exclude its whole
numerical equal-energy block and $p_+=p_-+P_*$. At $\mu=E_*$ define

$$
M(E_*)=\tfrac12\big[M_{p_-}(\mu=E_*)+M_{p_+}(\mu=E_*)\big].
$$

Both branches are evaluated analytically at the same chemical potential; no
$\mu\pm\epsilon$, energy averaging or arbitrary half-block band selection is
used. Each branch is an idempotent projector. In particular,
$p_-+P_*/2$ is not inserted into formulas requiring a projector.
For interval boundaries $b_j$, the zero-T weights are
$w_j=f(b_j;\mu,0)-f(b_{j+1};\mu,0)$ with $f(\mu;\mu,0)=1/2$ and
$m_j=\mu w_j$. The two adjacent intervals have weights $1/2$ and first moments
$\mu/2$. Away from a boundary these are the original 0/1 interval weights.
A numerical block member that is not itself an interval boundary creates no
additional artificial occupation jump. Every positive temperature retains the
existing analytic thermal convolution without a small-T switch.

This is the fixed-$\mu$, fixed-positive-$\eta$, $T\to0^+$ convention. It is not a
claim about all canonical fixed-particle-number fillings or joint $T,\eta\to0$
limits. The full original k-point quadrature weight is retained while two
response branches are averaged. Exact hits have finite weight on a finite grid;
flat bands or many such nodes can make the convention consequential. This does
not establish mesh or material convergence.

The finite-width tangent is a numerical regularization inside the supplied
Wannier space, not the exact $\partial P$ or a new disorder/self-energy model.
External-completion operators and their source/window qualification remain
unchanged; there is no uniform full-Hilbert-space eta claim. Exact-width
identities in Secs. 2--3 remain the positive-$\eta\to0$ reference.
