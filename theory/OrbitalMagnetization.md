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

For axial component $i\leftrightarrow(a,b)=(y,z),(z,x),(x,y)$, define $\mathscr A_{ab}[X]=\operatorname{Im}(X_{ab}-X_{ba})$ and $g=e^2 10^{-20}/(2\hbar\mu_{\rm B})$ in the implementation's eV–Å units. At zero temperature the point moment in $\mu_{\rm B}$ is

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
F^{\rm Lopez}_{ab}=\operatorname{Tr}[(\partial_aP)Q(\partial_bP)],\quad
G^{\rm Lopez}_{ab}=\operatorname{Tr}[(\partial_aP)Q\widehat H Q(\partial_bP)],\quad
H^{\rm Lopez}_{ab}=\operatorname{Tr}[\widehat H(\partial_aP)Q(\partial_bP)].
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

After rotating all operators to the common orbital frame, form $p=U_{\rm occ}U_{\rm occ}^\dagger$, $q=1-p$, $h=U\operatorname{diag}(E)U^\dagger$, and $Z_a=q(D_ap)p$. Its cross-block matrix elements are **unregularized**:

$$
(U^\dagger Z_aU)_{mn}=\frac{V^a_{mn}}{E_n-E_m},\quad m\notin p,\ n\in p;
\qquad (U^\dagger Z_aU)_{mn}=0\ \text{otherwise}.
$$

The independently implemented **Projector traces**, rather than a call to the Conventional result, are exactly

$$
\begin{aligned}
\mathcal F^{P}_{ab}&=\operatorname{Tr}\!\left[Z_a^\dagger Z_b+p\widetilde F_{ab}p\right],\\
\mathcal G^{P}_{ab}&=\operatorname{Tr}\!\left[Z_a^\dagger hZ_b
 +ip\widetilde B_a^\dagger Z_b-iZ_a^\dagger\widetilde B_b p
 +p\widetilde C_{ab}p\right],\\
\mathcal K^{P}_{ab}&=\operatorname{Tr}\!\left[h\left(Z_a^\dagger Z_b+p\widetilde F_{ab}p\right)\right].
\end{aligned}
$$

The same SRocc/CMocc contractions of Sec. 2 apply to these traces. External terms cannot be discarded for a material calculation. A declared complete, flat finite model may have zero external completion; missing material data are **not** zero completion.

At $T>0$ the code thermally convolves the zero-temperature occupied-subspace traces over intervals $(E_j,E_{j+1})$. With fixed $p_j$ on an interval, $w_j=\int_{E_j}^{E_{j+1}}[-f'(x)]\,dx$ and $m_j=\int_{E_j}^{E_{j+1}}x[-f'(x)]\,dx$ are evaluated analytically. The SRocc term uses $w_j\mathscr A[\mathcal G_j-\mathcal K_j]$ and CMocc uses $2\mathscr A[w_j\mathcal K_j-m_j\mathcal F_j]$. A smoothed density matrix is never substituted for an idempotent projector.

## 4. Symbols, indices, and normalization

$a,b$ are Cartesian directions and $i$ follows `yz, zx, xy`; $n,m$ denote Hamiltonian eigenstates, whereas $p$ is a **complete occupied exact-spectral-block projector**. $U$ is the eigenvector matrix; $V^a$ is the physical covariant Hamiltonian derivative in eV Å. $F$, $B$, and $C$ represent derivative-overlap, Hamiltonian-weighted connection, and energy-weighted derivative-overlap input; tilded forms subtract internal products. The axial part of $C$ suffices for the antisymmetric contraction. The point kernel is in $\mu_{\rm B}$ before normalized BZ weights; the integrated result is $\mu_{\rm B}$/cell. A spinor model has no automatic factor of two.

## 5. Applicability, limits, and qualification

- At $T=0$, a Fermi energy exactly on an eigenvalue is rejected (`ORBITAL_FERMI_SURFACE_POINT_UNRESOLVED`); no half-filled block is invented.
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
