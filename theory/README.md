# wannierNLQG v1.0.1 Theory Reference

This directory documents the theoretical definitions, physical pictures, and formula provenance of the public physical quantities in the release. It does not discuss Wannier interpolation, program variables, numerical algorithms, unit conversions, or performance. Formula conventions follow the public physical contract of v1.0.0. When an original paper uses different band indices, optical-field ordering, or transition summation domains, the difference is stated explicitly in the “Formula provenance” table of the corresponding document.

## Document navigation and public quantity mapping

| # | Public quantity | Theory document | method | calculation |
| ---: | --- | --- | --- | --- |
| 1 | `Shift_Current` | [ShiftCurrent](ShiftCurrent.md) | `Conventional`, `Projector`, `Geometric_Loop`, `Wilson_Loop` | `Integral`, `K-slice` |
| 2 | `Photon_Drag_Shift_Current` | [PhotonDragShiftCurrent](PhotonDragShiftCurrent.md) | `Geometric_Loop` | `Integral`, `K-slice` |
| 3 | `Injection_Current` | [InjectionCurrent](InjectionCurrent.md) | `Conventional` | `Integral`, `K-slice` |
| 4 | `Injection_Spin_Current` | [InjectionSpinCurrent](InjectionSpinCurrent.md) | `Conventional` | `Integral`, `K-slice` |
| 5 | `Shift_Spin_Current` | [ShiftSpinCurrent](ShiftSpinCurrent.md) | `Conventional` | `Integral`, `K-slice` |
| 6 | `Photon_Drag_Injection_Current` | [PhotonDragInjectionCurrent](PhotonDragInjectionCurrent.md) | `Conventional` | `Integral`, `K-slice` |
| 7 | `Quantum_Hermitian_Connection` | [QuantumHermitianConnection](QuantumGeometry/QuantumHermitianConnection.md) | `Conventional`, `Projector`, `Geometric_Loop`, `Wilson_Loop` | `K-slice` |
| 8 | `Hermitian_Curvature_Tensor` | [HermitianCurvatureTensor](QuantumGeometry/HermitianCurvatureTensor.md) | `Conventional` | `K-slice` |
| 9 | `Shift_Vector` | [ShiftVector](QuantumGeometry/ShiftVector.md) | `Geometric_Loop`, `Wilson_Loop` | `K-slice` |
| 10 | `Berry_Curvature` | [BerryCurvature](QuantumGeometry/BerryCurvature.md) | `Conventional` | `K-slice` |
| 11 | `Berry_Curvature_Dipole` | [BerryCurvatureDipole](QuantumGeometry/BerryCurvatureDipole.md) | `Conventional` | `K-slice` |
| 12 | `Berry_Curvature_Quadrupole` | [BerryCurvatureQuadrupole](QuantumGeometry/BerryCurvatureQuadrupole.md) | `Conventional` | `K-slice` |
| 13 | `Quantum_Metric` | [QuantumMetric](QuantumGeometry/QuantumMetric.md) | `Conventional` | `K-slice` |
| 14 | `Interband_Berry_Curvature` | [InterbandBerryCurvature](QuantumGeometry/InterbandBerryCurvature.md) | `Conventional` | `K-slice` |
| 15 | `Interband_Quantum_Metric` | [InterbandQuantumMetric](QuantumGeometry/InterbandQuantumMetric.md) | `Conventional` | `K-slice` |
| 16 | `Zeeman_Interband_Berry_Curvature` | [ZeemanInterbandBerryCurvature](QuantumGeometry/ZeemanInterbandBerryCurvature.md) | `Conventional` | `K-slice` |
| 17 | `Zeeman_Interband_Quantum_Metric` | [ZeemanInterbandQuantumMetric](QuantumGeometry/ZeemanInterbandQuantumMetric.md) | `Conventional` | `K-slice` |
| 18 | `Quantum_Metric_Dipole` | [QuantumMetricDipole](QuantumGeometry/QuantumMetricDipole.md) | `Conventional` | `K-slice` |
| 19 | `Quantum_Metric_Quadrupole` | [QuantumMetricQuadrupole](QuantumGeometry/QuantumMetricQuadrupole.md) | `Conventional` | `K-slice` |
| 20 | `Quantum_Christoffel_Symbol` | [QuantumChristoffelSymbol](QuantumGeometry/QuantumChristoffelSymbol.md) | `Conventional` | `K-slice` |
| 21 | `Triple_Phase_Product` | [TriplePhaseProduct](QuantumGeometry/TriplePhaseProduct.md) | `Conventional` | `K-slice` |

The first six quantities have Brillouin-zone integral responses and therefore reside at the root of this directory. The fifteen quantities in `QuantumGeometry/` are defined in this release only as local K-slice geometric quantities at each $\mathbf k$ and have no corresponding `Integral` path. This directory split describes the public task boundary of v1.0.0; it does not imply that these geometric quantities cannot be integrated in other theoretical settings.

## Global conventions

### Band indices, frequencies, and integration measure

The electron charge is

$$
e=-|e|<0,
$$

and

$$
f_{nm}=f_n-f_m,
\qquad
\omega_{mn}=\frac{\epsilon_m-\epsilon_n}{\hbar},
\qquad
\int_{\mathrm{BZ}}[d\mathbf k]
\equiv
\int_{\mathrm{BZ}}\frac{d^d\mathbf k}{(2\pi)^d}.
$$

The Hamiltonian-gauge Berry connection, or interband position matrix element, is

$$
r_{nm}^{a}=i\langle u_{n\mathbf k}|\partial_{k_a}u_{m\mathbf k}\rangle,
\qquad
v_{nm}^{a}=\frac{i}{\hbar}(\epsilon_n-\epsilon_m)r_{nm}^{a}\quad(n\ne m),
$$

with $v_{nn}^{a}=\hbar^{-1}\partial_{k_a}\epsilon_n$. The labels $a,b,c,d$ are Cartesian indices; $n,m,p$ are band indices; and $A,B,C,M,N,S$ label band subspaces.

### Optical fields, ordered contributions, and effect-specific prefactors

At $q=0$, the field convention is

$$
\mathbf E(t)=\mathbf E(\omega)e^{-i\omega t}
+\mathbf E(-\omega)e^{i\omega t},
\qquad
j_{\mathrm{dc}}^a
=2\sum_{bc}\sigma^{abc}(\omega)E^b(\omega)E^c(-\omega).
$$

At finite $\mathbf q$, the convention is

$$
\mathbf E(\mathbf r,t)=
\mathbf E(\mathbf q,\omega)e^{i\mathbf q\cdot\mathbf r-i\omega t}+\mathrm{c.c.},
\qquad
j_{\mathrm{dc}}^a(\mathbf q)
=2\sum_{bc}\sigma^{abc}(\mathbf q,\omega)
E^b(\mathbf q,\omega)E^c(-\mathbf q,-\omega),
$$

and the two endpoints connected by the photon momentum are denoted by $\mathbf k_\alpha=\mathbf k-\mathbf q/2$ and $\mathbf k_\beta=\mathbf k+\mathbf q/2$.

Each $\sigma^{abc}$ above is one ordered-field contribution. The outer factor $2$ combines $(\omega,-\omega)$ with $(-\omega,\omega)$; at finite momentum these are paired with $(\mathbf q,-\mathbf q)$ and $(-\mathbf q,\mathbf q)$. The sum over $(b,c)$ remains an ordered Cartesian-index sum, so the outer factor is neither a $b\leftrightarrow c$ symmetrization nor an odd-$q$ postprocessing factor.

The release also retains the complete ordered band-pair sum. Prefactors are effect-specific: the IC and PDIC injection-rate tensors have the $\pi e^3/\hbar^2$ and $\pi e^3/(\hbar^2\omega^2)$ normalizations documented in their chapters, whereas charge SC and PDSC retain their documented factor $1/2$. The Pauli-normalized ISC and SSC tensors use $\pi |e|^2/\hbar^2$ and $i\pi |e|^2/(2\hbar^2\omega^2)$, respectively. Multiplying the formal identity channel by the signed output charge $-|e|$ therefore gives the same ordered Cartesian component $(a,b,c)$ of the corresponding charge-current tensor, without output-level band or Cartesian index exchange; the SSC equality additionally requires the nondegenerate resonant $\eta\to0$ limit. For IC, PDIC, and ISC, the release reports the $\tau$-free rate $\eta$ and the steady-state conversion is $\sigma=\tau\eta$. Prefactors can be compared only after the band-pair domain, field ordering, spin normalization, and inclusion or exclusion of $\tau$ have all been aligned.

### Subspace normalization

- The QHC, ordinary interband QGT, and Zeeman interband QGT use the Cartesian-product average over $A\times B$, namely division by $N_A N_B$.
- Berry curvature and quantum metric for a target subspace retain only transitions from that subspace to its complement and exclude intra-subspace transitions. This makes the result invariant under basis rotations within the subspace.
- The HCT uses an ordinary trace, with no division by $N_M$ or $N_N$.
- Degenerate band groups in the Projector, Wilson-loop, and geometric-loop formulations use closed block contractions. QHC diagnostics use the Cartesian-product average over band groups, whereas response quantities retain the complete physical trace or band-pair normalization of their respective references.
- Spin quantities use the dimensionless Pauli matrix $\sigma^s$, whose eigenvalues are $\pm1$, rather than $S^s=\hbar\sigma^s/2$. Multiply the final result by $\hbar/2$ to obtain a physical spin current in angular-momentum units.

## Scope

The K-slice formulas in this directory define local geometric textures. They do not automatically include Fermi occupations, an energy shell, or a Brillouin-zone integral. The Berry-curvature family includes the external non-Abelian curvature terms available within the finite window of the release. The quantum-metric family contains the internal contribution of that finite window and omits the symmetric external contribution that requires additional $uIu/FF_R$-type information. Each document states this physical boundary without discussing how the quantity is computed.
