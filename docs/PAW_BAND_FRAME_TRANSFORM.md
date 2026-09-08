# PAW/USPP band-frame transform contract

## Scope

The sealed map used by the PAW/USPP completed-wavefunction workflow is a band-frame
transform, not in general a Euclidean-unitary gauge rotation.  At each k point it
maps the raw generalized frame into the completed orthonormal frame.  The formal
qualification condition is therefore

```text
T(k)' * S(k) * T(k) = I,
```

within the digest-bound `PAWGaugeThresholds.paw_s_norm` tolerance.  Here `S(k)` is
the physical PAW/USPP band metric reconstructed from the same source wavefunctions
and projectors that produced the sealed artifact.  For norm-conserving input,
`S(k)=I` and the contract reduces to ordinary Euclidean unitarity.

`T(k)'*T(k)-I`, the singular-value interval, and the condition number remain audit
quantities.  They do not decide PAW/USPP production eligibility.  The implementation
must not replace the sealed map with a polar factor: doing so changes the target
frame and invalidates the artifact digest and every matrix element tied to it.

## Hard gates

`BandFrameTransformContract` fails closed unless all of the following agree with
the sealed artifact:

- source identity and input SHA-256 values;
- k-point and band ordering, dimensions, topology, and artifact digest;
- finite, full-rank transforms and a positive-definite physical metric;
- physical isometry `T'*S*T-I` within the artifact threshold;
- raw-source to completed-frame wavefunction/projector replay within
  `wfc_rotation_reconstruction`.

The principal failure classes are `BAND_FRAME_PHYSICAL_ISOMETRY_FAILED`,
`BAND_FRAME_REPLAY_FAILED`, and `BAND_FRAME_SOURCE_MISMATCH`.  A structural failure
publishes neither a final operator nor a packed HDF5 model.  A completed SAWF
solver checkpoint is retained.

Genuine SU(2), sewing, magnetic-transport, and Wannier-gauge matrices remain
Euclidean-unitary objects and retain their existing unitarity gates.

## Operator and Hamiltonian transformations

The same sealed transform is applied by congruence to every operator family:

```text
single point:  O_target(k)       = T(k)'  * O_source(k)       * T(k)
link:          O_target(k,k')    = T(k)'  * O_source(k,k')    * T(k')
two endpoints: O_target(k1,k2)   = T(k1)' * O_source(k1,k2)   * T(k2)
```

Ordinary native Wannierization without a completed-frame artifact continues to
use the original diagonal EIG Hamiltonian byte for byte.  Native-SAWF in a sealed
completed frame uses `T'*H_EIG*T`; it does not require a non-Euclidean `T` to leave
`H_EIG` invariant.  Symmetrized-SAWF uses the sealed Reynolds-projected target-frame
Hamiltonian.  SPN, uIu, uHu, sIu, sHu, TB construction, and all Hamiltonian-weighted
operators bind the same frame-contract and authority digests.

VASP SPN is a k-point-local generator and its public API does not consume a
neighbor-topology file. Its provenance therefore binds the raw physical source,
band count, explicit ordered fractional k points, and SPN payload; a downstream
operator validates those ordered k points against its topology. QE SPN consumes
the topology directly, so its topology digest remains mandatory and exact. If a
VASP SPN provenance does record a topology digest, that optional digest is also
checked exactly rather than ignored.

## Persistence and migration

New formal artifacts use:

- star-gauge wire schema 1.0 with the complete former 1.11 contract;
- SPN/uIu and uHu/sIu/sHu provenance wire schema 1.0, preserving their former
  1.2 and 1.3 contracts, respectively;
- packed operator HDF5 schema 1.0.

Provenance records `band_frame_transform_sha256` and the complete frame-contract
digest.  `band_gauge_rotation_sha256` is retained only as a clearly labelled legacy
alias for diagnostic tooling.  Schema 1.0 records physical-metric type, isometry and
replay residuals and thresholds, source/artifact/contract digests, Euclidean audit
residuals, and per-operator and spin-family production status.

Gauge 1.10, operator provenance 1.1, and packed HDF5 6.1 remain readable for
diagnosis.  A spin/full legacy file involving a nonidentity transform is labelled
`LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED` and cannot silently acquire schema-1.0
production eligibility. Schema-6.2 full files are also diagnostic
`LEGACY_GALERKIN_RISK_CONTRACT_NOT_RECORDED` inputs. Regenerate either class from
its original wavefunction and projector inputs.
