# Linear transport, linear optics, and modern orbital magnetization

Three independent response submodules provide Conventional and Projector methods
on BZMesh and KSlice. They share first-order spectral geometry and occupation
helpers; they do not share a combined linear-response physics module.

| Quantity | Sampling | Physical output |
|---|---|---|
| `linear_transport` | BZMesh / KSlice | strict dc conductivity / integrand |
| `linear_optical_response` | BZMesh / KSlice | complex conductivity and dielectric response / integrands |
| `orbital_magnetization` | BZMesh / KSlice | modern orbital magnetization / moment integrand |

All three require `spatial_dimension=3`, all model bands, and either
`method="Conventional"` or `method="Projector"`. Unsupported methods and KPath
are rejected. Full BZ integration is used; symmetry-reduced sampling is not
supported. A slice is a section of a three-dimensional material, not a two-dimensional
sheet response. No automatic mesh, temperature, or width convergence scan is performed.

## Public parameters

```julia
rates = SeparateRelaxation(gamma_intra_ev=0.04, gamma_inter_ev=0.05)
dc = LinearTransportParameters(fermi_energies=Float64[0.13], temperature=300.0,
                               relaxation=rates)
optical = LinearOpticalResponseParameters(photon_energies=[0.0, 0.2, 0.43],
    fermi_energy=0.13, temperature=300.0, relaxation=rates)
magnetic = OrbitalMagnetizationParameters(fermi_energies=Float64[0.13], temperature=300.0,
    input_semantics=:defined_finite_model)
```

`fermi_energies` is the only public chemical-potential input for dc transport
and orbital magnetization. It must be an exact, nonempty `Vector{Float64}` whose
finite entries are strictly increasing. The constructor copies it. A scalar,
tuple, range, generator, duplicate axis, descending axis, or the retired
`fermi_energy=` keyword is rejected; write `Float64[mu]` for a single point.
Integral/BZMesh tasks accept any valid axis. KSlice accepts exactly one entry and
rejects a longer axis with a quantity-specific stable error code. Linear optical,
Berry, bands, and other response families retain their scalar `fermi_energy` contract.

Rates are positive finite energies in eV. Singular clean spectra are rejected.
At positive temperature, the exact stable Fermi derivative is used; omit
`fermi_surface`. At zero temperature, supply an explicit choice:

```julia
numerics = LinearResponseNumerics(fermi_surface=FermiSurfaceBroadening(
    kind=:gaussian, eta_fs_ev=0.01))
```

The other supported line shape is `:lorentzian`. The Gaussian definition is
`exp(-(x/eta)^2)/(sqrt(pi)*eta)`; the Lorentzian is
`eta/(pi*(x^2+eta^2))`. Neither width is inferred from a relaxation rate.
`gap_tolerance` in LinearResponseNumerics or OrbitalNumerics is an independent
spectral-resolution threshold, in eV. Numerically equal levels form complete
blocks; close distinct levels are never averaged. Unresolved cross-block gaps
and exact zero-temperature Fermi-surface sampling points for magnetization fail
explicitly. Magnetization has no optical linewidth.

## Contribution and unit contracts

Linear tasks write `drude`, `quantum_metric`, `berry_curvature`, and `total`.
The Berry-curvature contribution is the anomalous-Hall-effect (AHE) response
mechanism: ambient-curvature `contact` plus interband Hall. Contact is evaluated
from the same effective position operator; it is not a reconstruction of omitted
high-energy transitions. At finite width/frequency this channel need not equal
a static SOS Berry-curvature map. `total` sums the three stored mechanisms,
with no extra spin factor.
The dc kernel evaluates zero frequency directly; the optical kernel retains
both resonant and antiresonant poles.

BZ conductivity is in S/m. Slice conductivity is an unweighted integrand in
S m²; multiply by the original normalized BZ weights and divide by the cell
volume in m³ to reconstruct an integral from a complete set of slices.

Optical positive frequencies additionally produce `model_dielectric_tensor`
and contribution increments. The relation is `epsilon=I+i*sigma/(epsilon0*omega)`
with the vacuum background added once, after full BZ integration. Frequencies
are supplied as photon energies in eV and converted to angular frequencies.
A zero-frequency conductivity is retained; dielectric data are omitted at that
index and metadata records `UNDEFINED_ZERO_FREQUENCY`. Slice dielectric
increments have units m³ and never receive an identity background. These are
model responses, not a complete experimental dielectric function including
phonons or omitted electronic bands.

Modern orbital magnetization writes **only `srocc`, `cmocc`, and `total`**.
These are occupied-subspace self rotation and circulation terms. There are no
J, LC/IC, wavepacket OAM, or full OAM-matrix exports. The zero-temperature
contraction uses the F/G/K traces; finite-temperature SRocc and CMocc are
analytic thermal convolutions of their zero-temperature definitions. Their
sum is checked independently against the thermodynamic band-sum formula.

Vectorized integrated magnetic output is provided in muB/cell. The historical
scalar A/m files remain historical artifacts and are not emitted by the vector
schema as a second copy of the same result. Slice output is a local magnetic-moment
integrand in muB. Static tables use `mu_eV`, not a photon-energy axis. A
vacuum-containing cell still uses its actual three-dimensional volume.

## Material operator qualification

A declared `:defined_finite_model` has no external completion and requires a flat
ambient connection. This is an explicit model definition, not a fallback for
missing material operators.

Material modes `:direct_energy_overlap` and `:projected_energy_overlap` require
a Packed operator bundle containing H, position A, energy-weighted connection B,
full derivative overlap F, and Hamiltonian-weighted axial derivative overlap.
The existing operator inventory and packed schema are reused. The C tensor's
antisymmetric part is sufficient for the axial magnetization contraction.
Completion is built in the original frame before applying center similarities.
The extra orbital operator Fourier sums are direct, including in a Mixed run;
Hamiltonian and position interpolation use the selected backend.

An optional hashed `operator_qualification.orbital_response` record may retain
the following historical/additional evidence:

- `input_semantics`: the explicitly selected material mode;
- `frame_status` and `window_status`: `PASS` with supporting source evidence;
- `derivative_frame`: `uncentered_periodic_wannier`, matching the raw H and position frame;
- `validated_energy_window_ev`: the lower and upper validated energy bounds;
- `operator_source_sha256`: source hashes for each of the five required operators.

This record is no longer a prerequisite for numerical execution and is never
the sole source of frame or hash identity. Runtime first uses the generic
per-operator qualification, root band-frame contract, manifest authority, and
their hashes. If all five formula operators and components are present and
those records do not conflict, a missing `orbital_response` record continues as
`DIAGNOSTIC_ONLY` with
`ORBITAL_RESPONSE_QUALIFICATION_NOT_RECORDED`. Unproved common frame, material
energy window, or thermal support is reported as
`ORBITAL_COMMON_FRAME_UNVERIFIED`, `ORBITAL_ENERGY_WINDOW_UNVERIFIED`, or
`ORBITAL_THERMAL_TAIL_UNVERIFIED`; production eligibility remains false.

If the optional record exists, its semantics, frame, hashes, and Hamiltonian
authority must agree with generic manifest evidence. A recorded disagreement is
a hard `RESPONSE_QUALIFICATION_CONFLICT`. Missing one of the five actual
operators or a required Cartesian component remains a structural hard error.
The declaration remains evidence, not an algorithmic proof of material
completeness. Finite-band Galerkin qualification and source records are retained
in output metadata.

For a full bundle, H, position A, energy-weighted connection B, derivative
overlap F, and Hamiltonian-weighted axial derivative overlap must share the
same target-contract SHA-256 and the delivered `final_wannier_gauge`. Their
generation records retain the raw generator gauge, source sidecar, transform
SHA-256, and source payload SHA-256. The bundle writer assigns the delivered
gauge only after replaying the actual checkpoint/Wannier transform and passing
the q-to-R roundtrip check. A common-gauge label without that transform evidence
is a hard qualification conflict.

At positive temperature a verified material qualification requires the chemical
potential and thermal support to remain inside the validated window. The
existing exponential occupation-tail target remains `1e-12`; failure to prove
that material coverage degrades qualification but does not alter the finite
model formula or silently set material completion to zero.

## Execution and evidence

Each method/temperature/input-semantics combination is one task. At every k point,
Fourier interpolation, diagonalization, spectral geometry, and material OAM
completion are constructed once. Only occupations, Fermi-surface weights, and
small tensor contractions iterate over the chemical-potential axis. Transport
uses an `N_mu x 3 x 3 x 4` accumulator; orbital magnetization uses
`N_mu x 3 x 3` for Cartesian axis and term. Workspaces and completion objects
are owned per thread and do not replicate with `N_mu`.

Integral files use `wanniernlqg.linear-transport-vector/2.0` or
`wanniernlqg.orbital-magnetization-vector/1.0`. Every row begins with `mu_eV`,
followed by labelled real/imaginary Cartesian values. The public strict readers
`read_linear_transport_result(directory)` and
`read_orbital_magnetization_result(directory)` require the complete four-file or
three-file set and validate schema, columns, units, ordered axis and SHA-256,
task identity, full release-tree SHA-256, model/bundle identity, common
provenance, finite values, and the term decomposition. Material OAM readback
also requires the exact five-operator inventory plus target, authority,
selection, and common-frame hashes. Old scalar and five-file transport results
are not upgraded or accepted by the new transport reader.

The canonical μ SHA-256 domain is `wanniernlqg.fermi-energy-axis/1.0`; its input
is the entry count followed by each ordered Float64 IEEE-754 hexadecimal bit
pattern. The release-tree SHA-256 verifies `SOURCE_MANIFEST.tsv` and hashes each
sorted `relative_path + NUL + file_bytes`, excluding the two generated manifests.

Each task owns its accumulators, including when interpolation is shared.
The fixed lane order provides deterministic Threads/MPI reductions. Slice
files retain exact energy indices (`E00001`, etc.), avoiding rounded-energy
filename collisions. Large requested slice buffers are rejected before allocation
with a request to split the energy axis into separate tasks.

Run the self-contained example from the package root:

```sh
julia --project=. examples/linear_orbital_responses.jl /tmp/spectral-example
```

Pure tests include independent Liouville and finite-temperature band-sum oracles,
exact degeneracy, source-conflict errors, missing-evidence diagnostics, embedding completion, and finite-difference
projector checks. Vector tests compare both kernels against scalar results frozen
from the preceding formal tree, including the five-operator assembly route.
Runtime tests exercise all twelve combinations, center conventions, and
Direct/Mixed equality; separate tests check multi-μ Threads/MPI determinism.
Passing these tests does not establish material completeness or production qualification.

Formula definitions: [transport](../theory/LinearTransport.md), [optical](../theory/LinearOpticalResponse.md), and [orbital magnetization](../theory/OrbitalMagnetization.md).
