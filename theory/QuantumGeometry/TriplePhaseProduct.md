# Triple Phase Product

## 1. Definition and physical picture

The triple phase product (TPP) is a closed triangular loop formed by three interband transition matrix elements. Each edge depends on the phases of the Bloch states, but the gauge phases cancel exactly when the three edges close head to tail. The magnitude measures the strength of the three-state coupling, while the complex phase is an irreducible three-state geometric phase.

## 2. Core theoretical formulas

For three pairwise disjoint subspaces $A,B,C$, the release defines

$$
T_{A,B,C}^{abc}
=\frac{1}{N_AN_BN_C}
\sum_{I\in A,J\in B,L\in C}
r_{JI}^{a}r_{LJ}^{b}r_{IL}^{c}.
$$

For an isolated-band triangle, the gauge transformation $|u_n\rangle\to e^{i\phi_n}|u_n\rangle$ gives

$$
r_{JI}^{a}r_{LJ}^{b}r_{IL}^{c}
\to
e^{i(\phi_I-\phi_J+\phi_J-\phi_L+\phi_L-\phi_I)}
r_{JI}^{a}r_{LJ}^{b}r_{IL}^{c},
$$

so the product is invariant.

## 3. Magnitude and phase representation

$$
T^{abc}=|T^{abc}|e^{i\Phi^{abc}},
\qquad
\Phi^{abc}=\arg T^{abc}.
$$

The magnitude $|T|$ controls the joint oscillator strength of the three-state closed loop, while $\Phi$ encodes a loop geometry that cannot be determined from the phase of any individual transition. For multiband subspaces, the complete block contraction must be performed before the phase is taken. Averaging phases obtained from individual band triangles is not equivalent.

## 4. Symbols, tensor indices, and subspace normalization

The indices $a,b,c$ correspond to the three oriented edges $A\to B$, $B\to C$, and $C\to A$, respectively. The result is divided by $N_AN_BN_C$. A cyclic permutation $(A,a)\to(B,b)\to(C,c)$ preserves the loop orientation. Exchanging two vertices generally produces the complex conjugate together with an index rearrangement.

## 5. Key limits, symmetries, and relations

- If the optical matrix element on any edge vanishes, the corresponding triangular channel vanishes.
- Under time reversal or mirror symmetry, $T(\mathbf k)$ and $T(-\mathbf k)^*$ are related by a sign determined by the parities of the indices.
- The TPP enters gauge-invariant semiconductor Bloch equations, strong-field high-harmonic generation, and multistate geometric current driven by bicircular light. The K-slice output itself contains neither time evolution nor optical-field weights.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| Closed triple-dipole product | Liebscher et al. (2021), Sec. III discussion of gauge-invariant triple products | Standardize the dipole notation as $r_{JI}^{a}r_{LJ}^{b}r_{IL}^{c}$ |
| TPP in gauge-invariant SBEs | Parks–Moloney–Brabec (2023), principal gauge-invariant variables and equations | Retain only the static local triangle, without time evolution |
| Multistate geometric current | Guo et al. (2025), multistate TPP response sections | Generalize to three subspaces and divide by $N_AN_BN_C$ |

## 7. References

1. S. C. Liebscher, M. K. Hagen, J. Hader, J. V. Moloney, and S. W. Koch, “Microscopic theory for the incoherent resonant and coherent off-resonant optical response of tellurium,” *Phys. Rev. B* **104**, 165201 (2021). [DOI](https://doi.org/10.1103/PhysRevB.104.165201)
2. A. M. Parks, J. V. Moloney, and T. Brabec, “Gauge Invariant Formulation of the Semiconductor Bloch Equations,” *Phys. Rev. Lett.* **131**, 236902 (2023). [DOI](https://doi.org/10.1103/PhysRevLett.131.236902)
3. Z. Guo, Z. Lu, H. Wang, and K. Chang, “Bicircular light-induced multistate geometric current,” *Phys. Rev. B* **112**, 035162 (2025). [DOI](https://doi.org/10.1103/7ytw-vyb7)
