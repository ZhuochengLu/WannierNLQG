# Quantum Metric Dipole

## 1. Definition and physical picture

In this release, the quantum metric dipole (QMD) is the local first momentum derivative of the quantum metric. It characterizes the skewness of Hilbert-space distance across the Brillouin zone: if the wave-function variation rates near $`+\mathbf k`$ and $`-\mathbf k`$ differ, the metric texture has a nonzero first gradient.

## 2. Core theoretical formulas

The K-slice quantity in the release is defined as

```math
D_S^{ab;c}(\mathbf k)=\partial_{k_c}g_S^{ab}(\mathbf k),
```

where

```math
g_S^{ab}
=\sum_{I\in S,\,J\in T}
\mathrm{Re}\left(r_{IJ}^{a,(H)}r_{JI}^{b,(H)}\right)
+g_{S,\mathrm{external}}^{ab}.
```

Here $`T`$ is the complement of $`S`$ within the Wannier window, and the
external term is the full derivative-overlap contraction defined in
[Quantum metric](QuantumMetric.md). The displayed decomposition is the completed
metric, selected only by explicit `include_external=true`. By default the K-slice
output differentiates its internal finite-window term; the same derivative formula
applies to whichever contribution is selected.

If a Fermi-sea moment is desired, one may separately define

```math
\mathcal D_{g,S}^{ab;c}
=\int_{\mathrm{BZ}}[d\mathbf k]\,
f_S(\mathbf k)\partial_{k_c}g_S^{ab}(\mathbf k),
```

but this integral is not part of the K-slice quantity.

## 3. Distinction from other “QMD” definitions in the literature

The term “quantum metric dipole” does not denote a unique tensor throughout the literature. Gao–Xiao (2019) use the velocity-weighted object $`G^{ijk}=v^i g^{jk}`$ for nonreciprocal directional dichroism. Some nonlinear Hall studies use a Berry-connection polarizability containing energy denominators. Ulrich et al. (2026), by contrast, explicitly identify an intraband QMD of the form $`\partial_{k_a}g_n^{bb}`$. In this release, QMD strictly means $`\partial g`$ without an additional velocity, energy denominator, or Fermi weight.

## 4. Symbols, tensor indices, and normalization

The labels $`a,b`$ are the symmetric metric indices, and $`c`$ is the dipole direction, so $`D^{ab;c}=D^{ba;c}`$. The target subspace excludes intra-subspace transitions and uses an ordinary sum without division by $`N_S`$. The reported quantity defaults to the internal metric derivative; the full-overlap external contribution is included only with `include_external=true`.

## 5. Key symmetries and relations

- The ordinary metric is generally even under time-reversal or inversion mappings, so its first derivative is odd. A nonzero equilibrium integral therefore requires the appropriate symmetry or weight to be broken.
- QMD is a basic constituent of the quantum Christoffel symbol, which is a specific linear combination of three metric-dipole components.
- The local $`\partial g`$ can be large near a band crossing, but a large K-slice peak does not by itself equal a measurable transport coefficient.

## 6. Formula provenance

| Formula in this document | Original source and location | Convention conversion |
| --- | --- | --- |
| $`\partial g`$ intraband QMD | Ulrich et al. (2026), geometric decomposition and Table I | Remove the Fermi-surface and energy weights of the response, retaining only the local $`\partial_{k_c}g^{ab}`$ |
| Basic definition of the quantum metric | Provost–Vallée (1980), Riemannian metric definition | Take the parameter space to be Bloch momentum and exclude transitions within the target group |
| Velocity-weighted QMD for comparison | Gao–Xiao (2019), Eqs. (7) and (10) | Included only to distinguish terminology; their $`v^ig^{jk}`$ is not the $`\partial g`$ defined here |

## 7. References

1. Y. Ulrich, J. Mitscherling, L. Classen, and A. P. Schnyder, “Quantum geometric origin of the intrinsic nonlinear Hall effect,” *Phys. Rev. B* **113**, L201107 (2026). [DOI](https://doi.org/10.1103/4z8z-4kch)
2. J. P. Provost and G. Vallée, “Riemannian structure on manifolds of quantum states,” *Commun. Math. Phys.* **76**, 289–301 (1980). [DOI](https://doi.org/10.1007/BF02193559)
3. Y. Gao and D. Xiao, “Nonreciprocal Directional Dichroism Induced by the Quantum Metric Dipole,” *Phys. Rev. Lett.* **122**, 227402 (2019). [DOI](https://doi.org/10.1103/PhysRevLett.122.227402)


## Complete-overlap contract

The primary output defaults to internal geometry (`include_external=false`), without component companions. With explicit `include_external=true`, admitted orthogonal input supplies the full derivative-overlap correction, the primary output is total, and `_internal`/`_external` companions retain the same columns and units. Only this opt-in requires qualified full F. Orthogonal internal inputs need H/r; nonorthogonal internal inputs need H/S/r and reject external completion. Numerical regularization and spectral guards are unchanged. Momentum derivatives use the selected contribution at every stencil point, with moving-frame transport retained. See [Quantum Metric](QuantumMetric.md) for input capabilities, subspace versus band-sum semantics, frame transformations, and convergence requirements.
