# Native finite-model inputs

WannierNLQG 1.2 supports orthogonal point-orbital finite models and explicitly declared fixed orthonormal analytic bases. The localized nonorthogonal contract is described separately below; no Python object bridge is provided.

Find [input conventions](#entry-points-and-conventions), [finite-q support](#photon-drag-finite-q-contract), [sampling](#periodic-and-bounded-sampling), [examples](#runnable-examples), and [affine regions](#two-dimensional-parallelogram-region).

## Entry points and conventions

`TaskConfig(model=RealSpaceTBInput(...), ...)` and `TaskConfig(model=AnalyticKInput(...), ...)` use the ordinary task registry. `ModelInput`, `TaskSpec`, and `run` keep their existing meaning. Per-input capabilities are defined by the current task registry. Ordinary Quantum Metric, metric dipole, metric quadrupole, and Christoffel default to internal geometry (`include_external=false`), including applicable point-orbital/fixed-basis native tasks with their existing derivative capabilities. Explicit external completion requires qualified full derivative overlaps: point-orbital and fixed-orthonormal constructors cannot provide them. The explicit-basis `AnalyticKInput` can declare `operators.derivative_overlap` together with its position connection and the task-required derivatives. Nonorthogonal external completion is unsupported. See [the option contract](GEOMETRY_OPTIONS_MIGRATION.md#external-metric-completion).

### Direct low dimensional physical inputs

Native orthogonal model constructors also accept a positive-orientation 1x1 or 2x2 physical row lattice in Angstrom. The physical dimension comes from this input itself. A line lies along x and a plane lies in xy; arbitrary rotated embeddings are not supported by this interface. Each missing reference direction is completed internally with a perpendicular vector of length **1 Angstrom**. Users supply no auxiliary vector, thickness or separate dimension marker. Existing 3x3 inputs retain their original three-coordinate semantics and numerical behavior; neither a smaller KRegion nor a Hamiltonian that happens to ignore an axis reclassifies them.

For `RealSpaceTBInput`, supply physical `d x num_R` integer translations and `d x num_orbitals` Cartesian centers. For `AnalyticKInput`, callbacks receive a d-component Cartesian k vector in inverse Angstrom. Hamiltonians remain orbital matrices; an explicit derivative of order m has m trailing axes of length d. The three derivative slots still mean orders one, two and three. Position/connection callbacks and their derivatives use the corresponding physical axes; the internal adapter pads these Cartesian slots without inventing missing physical derivatives. Spin always has three laboratory Cartesian components. A two-dimensional orbital moment can have its existing normal z component.

`periodic=false` remains nonperiodic and uses the declared physical KRegion without folding. Periodic grids and adaptive rules use only d physical coordinates; auxiliary directions add no nodes, quadrature axes, periodicity or symmetry. A planar KSlice applies to a direct 2D model and may use two-coordinate xy vectors. A 1D model uses Integral or a physical path, not a fabricated planar KSlice. Actual operator, basis, width and response restrictions remain. Periodic point-orbital direct inputs can use the existing native symmetry artifact after validation of the physical subspace: operations must not mix physical and auxiliary axes or translate in auxiliary directions. Model-definition binding, orbital-group closure and actual-grid Hamiltonian/spin covariance are checked by the existing machinery. Nonperiodic models and fixed-orthonormal bases retain their original symmetry restrictions.

Conductivity-like coefficients for these new direct inputs use the completed three-dimensional reference volume. For a Cartesian region, the physical measure is `d^d k/(2pi)^d` divided by the reference transverse measure: 1 Angstrom in 2D or 1 square Angstrom in 1D. There is no auxiliary integration. JC/THG and linear conductivity retain their bulk output units; orbital integrals retain their response-specific reference-cell moment convention. Sheet/line conversion belongs to postprocessing. Local geometry, moment and conductivity-density units remain distinct and KSlice values contain no mesh weight. BCD/BCQ retains its original raw-moment adaptive error norm before the later DC conversion. A direct one-dimensional model has no nonzero Berry two-form, so its existing padded BCD/BCQ conductivity kernel returns zero; no transverse dynamics or new one-dimensional Hall mechanism is inferred.

See [the direct line example](../examples/native_models/direct_low_dimensional.jl). TOML continues to use `model.source="julia"` with an existing typed payload supplied by the caller; it does not serialize or evaluate Hamiltonian code. `explain` and run metadata record the derived physical dimension and completion convention. To adopt automatic completion for a genuinely low-dimensional legacy model, supply its physical 1D/2D data through this new interface; existing complete 3x3 model declarations are not rewritten.

Lattice vectors are rows in Angstrom. For a complete 3x3 declaration, orbital positions are a 3 by N matrix in Cartesian Angstrom; direct low-dimensional declarations use the d by N physical matrix above. Real-space arrays have orbital indices first and R last. Supply the home cell and every Hermitian R/-R partner; no partner is inferred. Native hopping weights are one and replicas are used as supplied. No automatic minimum-distance redistribution is performed.

All input Hamiltonians are declared in Convention II (R-only phase). Choosing `wannier_center_convention="Convention_I"` selects the existing runtime change of representation; do not insert the center phase yourself. Point-orbital inputs require explicit orbital centers, including an all-zero array. `RealSpaceTBInput(position_model=:point_orbitals)` and `AnalyticKInput(basis=:point_orbitals)` retain this contract: centers define the connection exactly once. Position, derivative-overlap, cross-point transport and weighted-operator overrides are rejected at construction.

`AnalyticKInput(basis=:fixed_orthonormal)` declares one k-independent orthonormal finite basis, such as a fixed plane-wave coefficient basis. Omit `orbital_positions`; they remain `nothing`, not fictitious zero-valued Wannier centers. The declared basis connection is zero and its cross-point basis transport is identity, so eigenstate overlap is `U(k1)' * U(k2)`. This declaration applies to that finite model only. Convention I and point-orbital symmetry artifacts are rejected for this basis. Unknown, k-dependent or nonorthogonal analytic transport is unsupported. Complete derivative overlaps are not inferred from this declaration; the four complete-geometry native task guards remain in force.

For a complete 3x3 declaration, analytic callbacks take `(k, parameters)` with a three-component Cartesian k in inverse Angstrom. H is in eV. Derivative arrays have shape `(N,N,3,...)`; direct low-dimensional declarations instead use the d-component arguments and axes specified above. Each trailing derivative axis differentiates with respect to Cartesian k. The three derivative slots correspond to orders one, two and three. A supplied derivative is preferred to automatic differentiation. ForwardDiff differentiates real and imaginary matrix components before diagonalization; callback arithmetic must preserve generic numeric types. An AD error is an error, not permission to use differences. Explicit `derivative_method=:finite_difference` checks central differences at h, h/2 and h/4. Out-of-domain stencil points are rejected.

Analytic input requires `source_file` when executed. Model parameters, callback identity, captured values, arrays and source bytes contribute to a content hash. Callbacks are never stored as executable serialized objects. Keep all model code in the declared source file and parameters; external global state is not a reproducible model definition. Callbacks must be deterministic and must not mutate shared state. MPI ranks must agree on the model hash.

## Photon-drag finite-q contract

PDIC and PDSC sum response and intermediate bands over every band of the declared finite model. A positive `band_window_size` is rejected; omit it or supply `-1`. Occupation, resonance screening and degeneracy groups retain their distinct roles. Full finite-model bands do not establish convergence of a plane-wave truncation. Other response families retain their own band-window contracts.

PDIC uses a complete current-matrix trace in exact spectral subspaces, including intrablock off-diagonal current elements. Singleton blocks retain the ordered pair contraction. Numerically split levels follow the shared spectral-gap error policy; a near-degeneracy smoothing scale is not introduced. External occupations, resonance factors and transition weights remain outside the block trace.

Both photon-drag families use the unique transition-denominator weight `[DeltaE/(DeltaE^2+gamma^2)]^2`, with `DeltaE=epsilon_m(k+q/2)-epsilon_n(k-q/2)` in eV and `gamma` the existing `denominator_regularization`. The weight multiplies occupations outside the geometric finite-difference kernel. It is not a denominator in photon frequency. For a fixed orthonormal analytic basis, PDIC velocity vertices use the complete Cartesian Hamiltonian derivatives, including diagonal entries.

Paired photon-energy/momentum rows support Uniform Direct evaluation on `BZMesh` or `KRegion` for qualified orthogonal real-space or point/fixed-basis analytic inputs. Nonperiodic models require `KRegion` and receive unfolded endpoints. Shared endpoint caches retain their bounded capacity; occupation, broadening, transition weights and response-specific traces are evaluated by each task. Task metadata records band scope, gap definition, denominator and basis provenance. A generic analytic payload is supplied by the Julia caller, including when the text input declares `source="julia"`; standalone CLI payload construction is not provided, and no material-specific text schema is introduced.

## Operators and qualification

Spin must be supplied explicitly in Pauli normalization through a constant `operators.spin` array of shape `(N,N,3)` for either input. Each component must be finite, Hermitian and commute with every diagonal position matrix. Spin partners may mix at the same center; spin matrix elements between distinct centers are rejected. Neither matrix dimension nor H determines spin. H may include SOC and need not commute with spin. Spin callbacks and real-space spin hopping overrides are unsupported. Weighted operators and derivative overlaps follow from the finite point-orbital definition. Old file inputs retain their existing operators.

Orbital response requires `orbital_input_semantics=:defined_finite_model`. A successful ordinary run is a finite-model result with `COMPUTATION_READY` eligibility. Material completeness and independent qualification remain separate evidence; numerical execution does not establish them. See the canonical [ordinary calculation policy](ORDINARY_CALCULATION_POLICY.md).

## Derivative evidence

A successful analytic response run writes `native_derivatives.tsv` at its run root. It records actual derivative orders and their explicit, ForwardDiff or finite-difference source across the shared run. Unused orders are `NOT_EVALUATED`. Finite differences record the three steps, adopted h/4, convergence differences, criterion and a deterministic worst Cartesian point. These are convergence estimates, not certified errors. Non-difference methods never report zero as a measured finite-difference error. Model-local worker records are merged separately from response reductions. No AD failure silently changes the derivative strategy.

## Periodic response symmetry

`PointOrbitalSymmetryOperation` declares a fractional rotation and translation, an antiunitary flag and a constant orbital representation matrix. `write_native_response_symmetry(path, model, operations)` writes a native artifact bound to the complete model digest. It validates the representation group; covariance on the actual grid and exact task offsets is checked afresh when the artifact is consumed through `ExecutionOptions(response_symmetry_file=...)`. No qualification cache is reused.

The local representation maps orbital j into i only when the transformed center matches i plus a lattice vector. Cell shifts determine the Convention-II sewing phases. Representations must close up to allowed scalar projective phases; Hamiltonian derivatives and the axial, time-odd spin transformation are checked. Covariance or grid-closure failures reject reduction, even for diagnostic models.

Supported quantities and methods match the legacy q=0 charge/spin shift and injection registry. Periodic Integral runs can reduce the grid. K-slice retains its full grid and provides symmetry interpretation. Nonperiodic KRegion, finite-q and other response families do not gain symmetry reduction. A native artifact never certifies real-material completeness or production eligibility.

## Periodic and bounded sampling

Periodic analytic H must be periodic in the declared Convention-II reciprocal lattice. Evaluation is direct, including offset points; Mixed/FFT requests are rejected. Convention-I center sewing follows the existing representation change.

Nonperiodic integration requires `KRegion(lower=(...), upper=(...), k_mesh=(...))`. One to three leading Cartesian axes are active; inactive coordinates are zero. The deterministic midpoint rule uses d^d k/(2 pi)^d. Explicit `ExecutionOptions(integration_algorithm=UniformIntegration(region_quadrature=:left_endpoint))` selects half-open nodes `i/N`, `i=0:N-1`, on the same box or affine region. The first parameter varies fastest; `N=1` samples its lower endpoint. The domain, equal weights and finite-domain normalization stay unchanged. The callback's optional three-dimensional `evaluation_bounds` is separate from the integration box and must include every finite-q and derivative stencil point. No periodic folding is performed. Mesh convergence and cutoff dependence are separate tests.

Region response densities carry the dimensional factor m^(3-d) relative to bulk units. Spin-current outputs retain Pauli normalization (the hbar/2 conversion is external). Orbital region results are in muB/m^d. A finite-region optical response has no identity dielectric background added. Region spectral tables have a separate schema; existing full-BZ vector readers deliberately reject them. No vacuum thickness is introduced.

## Runnable examples

Importing the following files only defines constructors. Execute with `--smoke` for a small diagnostic calculation:

```
julia --project=. examples/native_models/real_space_tb.jl --smoke
julia --project=. examples/native_models/periodic_analytic.jl --smoke
julia --project=. examples/native_models/nonperiodic_kp.jl --smoke
julia --project=. examples/native_models/periodic_symmetry.jl --smoke
```

The first two examples describe the same Rice-Mele hopping Hamiltonian. Their periodic geometry retains the reference cell convention; the third example uses a physical one-dimensional Cartesian integration measure. None of these small grids establishes production convergence.

## Acceptance boundary

Unit, cross-input, symmetry and region tests cover distinct parts of the implementation. Derivative-sensitive fixtures and full-overlap fixtures provide separate convergence checks. Passing these tests does not establish convergence or physical qualification for a particular material or model.

## Convention comparisons and numerical limits

Convention I and II describe the same point-orbital model. Their raw Hamiltonian derivatives and basis connections differ and must be transformed together. Legacy regularized response formulas are retained: finite denominator or SHG intermediate-state regularization can leave a convention-dependent residual. Compare physical results with an independently resolved regularization and loop step convergence study; a same-backend or cross-input agreement at one finite regularization is not by itself a convention-invariance proof. The optical resonance linewidth is a separate parameter and must not be removed merely to obtain numerical agreement.

## Nonorthogonal localized inputs

The `RealSpaceTBInput`/`AnalyticKInput` point-orbital contracts above retain their orthogonal specialized route. WannierNLQG also provides `Core.NonorthogonalLocalizedModel`/`Core.NonorthogonalLocalizedInput` with explicit localized H/S/r. Its generalized eigensolver and metric-aware scalar matrix elements use a separate backend behind the shared physical response interface. Read [NONORTHOGONAL_LOCALIZED.md](NONORTHOGONAL_LOCALIZED.md) for the admitted Band, Conventional SC/IC/SHG, scalar geometry and finite-model orbital scopes; explicit localized spin/SOC states and Convention I/II; Fourier execution; OpenMX formats; and numerical limitations. Existing native derivative-overlap, Wilson/projector, spin-current operator and response-symmetry-reduction contracts do not extend to that backend.

## Two-dimensional parallelogram region

The `KRegion` interface also accepts `origin`, `vector_1`, `vector_2` and two mesh counts:

```julia
region = KRegion(origin=(4.0, 0.2), vector_1=(0.4, 0.08),
                 vector_2=(0.12, 0.36), k_mesh=(8, 8))
```

All three vectors use Cartesian inverse Angstrom, unlike reciprocal-fractional KSlice vectors. The points are `origin + u*vector_1 + v*vector_2`, where `u=(i+0.5)/n1`, `v=(j+0.5)/n2`, and the first parameter varies fastest. There are `n1*n2` nodes, no duplicated boundary, and each has physical weight `area/(n1*n2)`. Here `area=0.1344 A^-2`. For existing complete 3x3 nonperiodic inputs, response integration uses the existing continuum measure `d²k/(2π)²`; new direct 2D inputs divide that measure by the 1 Angstrom reference transverse length as described above. Area enters once through the response prefactor and node average. The enclosing box in diagnostics is not the area.

Two or three components are accepted consistently across the vectors. Three components embed a two-dimensional plane in Cartesian space; its area is the norm of the three-dimensional cross product, and its response tensor retains three Cartesian axes. The integration dimension remains two. Reversing a basis changes orientation but not the positive area weight. Zero/collinear bases, nonfinite coordinates and incompatible dimensions are rejected. Box keywords and the existing box grid remain available. The affine form currently supports uniform Direct/Auto evaluation; adaptive cubature and Mixed/FFT are rejected.

See `examples/native_models/nonperiodic_parallelogram.jl` for a small two-band `AnalyticKInput(periodic=false)` and public `PDSC`/`PDIC` tasks. Importing the example defines builders and performs no calculation. Its companion TOML file uses the same region and finite-q parameters; supply `build_model()` through the existing Julia model keyword and replace its external output path before run. The example is a diagnostic finite model; its nonzero tensors, convergence and latency require separate assessment; they cannot be assumed from the file.

`periodic=false` passes unfolded Cartesian points to callbacks, including `k±q/2` and derivative stencils beyond the integration boundary. The nominal reciprocal cell is a coordinate frame, not a wrapping boundary. Make the declared evaluation bounds large enough for all legs. No response formula, finite-q sewing rule, orbital embedding or material qualification is added by the region. For periodic inputs, the finite region retains the original-cell prefactor convention, with its two-dimensional reference area from the first two original reciprocal rows. Choosing a tilted region does not define a new periodic cell or prove cross-boundary sewing. Translation/basis invariance applies only to appropriate periodic functions; different finite grids require convergence.

## Three-dimensional parallelepiped region

The same `KRegion` accepts `vector_3` and three mesh counts:

```julia
region = KRegion(origin=(4.0, 0.2, 0.1), vector_1=(0.4, 0.08, 0.02),
                 vector_2=(0.12, 0.36, -0.01), vector_3=(0.03, 0.02, 0.2),
                 k_mesh=(4, 4, 4))
```

Every coordinate is Cartesian inverse Angstrom. The half-open parameter domain has uniform midpoints `k=k0+u*b1+v*b2+w*b3`. The first parameter varies fastest; `n1*n2*n3` nodes each represent `abs(det([b1 b2 b3]))/(n1*n2*n3)` inverse-cubic Angstrom. The existing continuum `d³k/(2π)³` or periodic BZ convention consumes this volume once, through the existing prefactor and node average. The enclosing Cartesian box does not set the volume. A negative determinant changes orientation and retains positive weight; zero, coplanar, nonfinite and dimension-mismatched bases are rejected. The two-vector form embedded in three Cartesian coordinates still has physical dimension two and cross-product area.

Old `lower`/`upper` rectangle and cuboid construction remain available. Affine regions use the same Direct/Auto uniform execution restrictions. See `examples/native_models/nonperiodic_parallelepiped.jl` and its companion TOML; importing the example only defines builders. Supply its `build_model()` through the existing model keyword and choose a private output directory. Callbacks stay unfolded, including the finite-q legs and derivative stencils. This diagnostic model does not qualify material vertices or finite-boundary physics. The example does not establish three-dimensional convergence or material qualification.


Omitting `orbital_positions` is supported only for `basis=:fixed_orthonormal`. The default `basis=:point_orbitals` retains its required-keyword `UndefKeywordError(:orbital_positions)`. Supplying `nothing` explicitly for that point-orbital basis fails position validation with `ArgumentError`; it does not silently select the center-free basis.
