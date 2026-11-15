# Orthogonal Wannier optical momentum links

The existing file/packed Wannier Hamiltonian and raw position-connection route uses the first-order orbital optical link by default for PDIC and PDSC. No new input switch or duplicate position declaration is required. This change does not extend nonorthogonal finite-q support.

For R-only Convention II, with the oriented momentum `q = k_left - k_right`,

```math
\begin{aligned}
F_R(k,q) &= I + i\sum_d q_{\mathrm{cartesian},d} A_{W,R,d}(k),\\
M(\mathrm{left},\mathrm{right}) &= U_{\mathrm{source}}(\mathrm{left})^\dagger F_R(k,q) U_{\mathrm{source}}(\mathrm{right}),\\
k &= (k_{\mathrm{left}}+k_{\mathrm{right}})/2.
\end{aligned}
```

`A_W_R` is the raw orbital-basis position connection in Angstrom, not the band Berry connection. Cartesian q is in inverse Angstrom. Fractional reciprocal coordinates use the existing row-lattice relation `q_frac = lattice*q_cart/(2pi)`. The production path consumes the original Cartesian momentum, including each paired-momentum row. Every nonzero q direction is included in raw-A preparation, independently of the requested optical tensor indices and response dimension. For the Wannier raw-connection route, the input must provide the connection for every nonzero Cartesian q component. A required connection or direction that was not prepared is an error; there is no zero-A or center-only fallback.

For Convention I let `D(k) = diag(exp(2pi*i*k_frac*tau_frac))`. The implementation restores `A_R = D(k)*(A_I + tau_cart)*D(k)'` and constructs `F_I = D(k_left)'*F_R*D(k_right)`. This avoids subtracting orbital centers twice. It is an endpoint transform of the same R-only first-order input; independently expanded representations need agree only to their stated order. No exponential of A, polar normalization or automatic q extrapolation is used.

PDIC prepares valence-to-conduction `M(k_v,k_c)` with `-q` and its reverse with `+q`, before either scalar or BLAS contractions. Both Integral and KSlice use the same runtime preparation. The full existing endpoint velocity provider and the original factors, all intermediate bands, occupations and normalization remain. The expert kernel requires prepared physical links for nonzero q. Its explicitly named historical-center reference argument exists for old arbitrary-frame tests; it is not a task/input option or a production default.

PDSC replaces only its optical q links: the central conduction-to-valence link, and the valence-to-conduction links centered at `k+p` and `k-p`. Each uses A at its own center. The auxiliary p links, their convention connector and the matched explicit residual connection remain unchanged. Mixed/cache offset graphs include these three centers separately from the `k±p±q/2` endpoint slots. Common overlap and projector transport helpers retain their existing meanings.

Declared point-orbital native inputs retain their exact diagonal phase link; fixed orthonormal analytic inputs retain the identity basis link. The existing native basis declaration is carried into the runtime model. A zero or diagonal raw A array does not turn a Wannier model into either analytic contract. Ordinary q=0 response construction retains its prior path.

The named PDSC expert entry uses the same complete optical default as public Runtime. Its retained compatibility keyword accepts true; explicitly selecting the historical center-only mode is rejected. The separately named shared bare q=0 Geometric kernel keeps its original role. No task/input switch is added.

Only the optical input is first order. The complete existing finite-q response expression is retained, including its higher-order products; their microscopic accuracy is not implied by a first-order input. Outside-subspace remainders, spin-magnetic couplings, nonorthogonal finite q and material qualification remain separate obligations. Figure 4 diagnostic/material holds are not lifted by this repair. Result metadata records the optical strategy, orientation and scope along with the package version, declared source-manifest SHA, actual optical-provider file SHA and existing input identity. The manifest identifier is explicitly labelled as declared; metadata does not trigger a full-tree installation audit or hash scientific input bodies. Historical center-only finite-q results do not qualify the repaired strategy automatically.

Finite-q construction costs changed. Existing Auto selector rules and numerical parameters remain intact; older finite-q performance calibrations are not automatically qualified for this strategy. Forced Direct/Mixed correctness evidence does not establish new Auto performance calibration.

The Cartesian photon direction is independent of the sampling/response dimension. For a two-dimensional response with nonzero Cartesian q_z, the Wannier plan prepares raw A_z at all optical centers without requesting z response components or z derivatives. Ordered-pair channel masks retain their original axes when preparation storage grows. Explicit fixed-basis and native point-orbital contracts continue to use their own links and do not acquire a raw-A input requirement.

## Current photon-drag k-slice scope and normalization

The current PDSCK and PDICK contractions consume the screened complete finite model. Both Integral and KSlice use total-response selection, `BandSelection()`; explicit groups are rejected. A finite-q per-transition decomposition is not defined by the q=0 source/target selector. Historical inputs carrying an unused `Transition` do not establish a selected-band-pair result.

Their current prefactors include `1/Nk`, and the k-slice writer does not multiply this factor away. These arrays therefore carry that mesh-dependent factor; they are not unweighted local-density maps. Mesh-size comparisons must retain this normalization explicitly. This documents the existing implementation and does not rescale outputs or establish the semantics of a historical source version.

The relevant owners are [photon-drag injection execution](../src/Runtime/Execution/PhotonDragInjectionExecution.jl), [geometric shift execution](../src/Runtime/Execution/GeometricShiftCurrentExecution.jl), and the [k-slice driver](../src/Runtime/Execution/KSliceDriver.jl).
