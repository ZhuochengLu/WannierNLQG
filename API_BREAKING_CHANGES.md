# Public interface and numerical contracts

WannierNLQG 1.2.0 provides the grouped task API described in
[Public API](docs/PUBLIC_API.md), the [TOML contract](docs/TEXT_INPUT.md), and
[numerical controls](docs/NUMERICAL_CONTROLS.md). Unknown or inapplicable inputs
are errors. Removed interfaces have no compatibility aliases or automatic input
conversion. Supported external file formats retain their actual adapter contracts.

## Physical and algorithm names

The Wannierization expert API uses `ExternalOverlapProjectionMatrices` and
`ProjectionRepresentationAlgorithmInfo`. Symmetrization exposes
`qualify_response_symmetry_wannier_frame`. Text TB output uses the boolean
`WannierizationOutputConfig.write_model_tb` option or `:model_tb` in
`tb_output_formats`; the shared file writer is `IO.write_wannier_tb`.
The character-reduction profile records its algorithm name, parameters and owned
implementation identity. An identity does not establish material qualification.

## Current mathematical data

Packed real-space models use schema `3.0`. Embedded and referenced Wannierization
checkpoints use `3.0` and `3.1`; referenced checkpoints require their explicit source
root. Projection-search data use `4.0`. These identifiers are independent of the
software version. Ordinary readers require the documented current contract and
complete mathematical definitions. Unsupported data are not relabeled or silently
converted. See [storage contracts](docs/STORAGE_SCHEMAS.md).

## Occupation and degeneracy

Intrinsic Hall response uses the actual zero-temperature occupation `E <= mu`.
Occupied/empty links use every nonzero floating-point energy difference directly;
no occupation grouping, group-mean energy, geometric width or threshold substitutes
for that gap. Nonfinite operations are explicit errors. AHC does not accept
`degeneracy_threshold`. The orthogonal Conventional and Projector routes and the
nonorthogonal Conventional route retain their supported model scopes.

ISC/SSC and orbital magnetization require a finite positive
`denominator_regularization`. Their smooth vertices and complementary contributions
are documented in their theory chapters. ISC/SSC reject an explicit
`degeneracy_threshold`; OM rejects `gap_tolerance`. At a zero-temperature OM Fermi
boundary, the two complete occupied-subspace limits receive equal weight. This is
not a fractional projector. Nonorthogonal Projector OM remains unsupported.

Jerk and THG reject `degeneracy_threshold`. Jerk uses the same occupation helper
as ordinary injection current, including the established zero-temperature equality
convention. Positive-temperature results near the Fermi level can differ from the
former low-temperature step approximation.

## Geometric and optical scopes

Quantum Metric defaults to internal contributions. `include_external=true` requires
the documented additional orthogonal-model operators; it is unsupported for the
nonorthogonal route. Applicable zero-width scalar-geometry tasks use their explicit
supported branch; this does not open a zero-width mode for every response.

Conventional nonorthogonal linear optics requires positive geometric regularization.
SHG requires finite positive geometry and intermediate widths. Its nonorthogonal
widths remain independent, and nonorthogonal `eta_correction=true` is unsupported.
The optional cutoff optical vertices preserve the separate roles of the bare and
regularized endpoints and generalized derivative. Other consumers retain their
existing shared-geometry prescription.

Geometric Loop Quantum Hermitian Connection is unsupported and reports an error.
Geometric Loop shift current, photon-drag shift current and shift vector retain
their supported implementations. No fallback between methods is implied.

These changes require new result identity metadata. Preserved filenames, units and
columns do not imply equality with older numerical results. Software regression,
mathematical validation and material qualification remain separate.
