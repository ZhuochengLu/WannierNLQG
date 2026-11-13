# Focused scientific regression contracts

These tests preserve already-authorized repairs. They do not define new response
formulas, defaults, reference values or numerical acceptance tolerances. They are
registered in the ordinary Fast inventory through `SCIENTIFIC_REPAIR_FAST_TEST_FILES`.

| Contract | Independent reference and gate | Implementation and public path | Fast file |
| --- | --- | --- | --- |
| External transition selection | Independently enumerated selected forward pairs; shared screen and virtual intermediate domain unchanged; exact masks, zero hot-call allocation; malformed indices rejected | `Runtime/Execution/ConventionalCurrentKSliceExecution.jl`, `Runtime/Execution/TransitionScreening.jl`; Conventional SC/IC/SSC/ISC KSlice | `conventional_kslice_band_selection_unit.jl` |
| Spin degenerate-block derivative | Analytic `(S*V + V*S)/2`, degenerate/nondegenerate levels and nonidentity block rotation; existing absolute gate `2e-12` | `MatrixElements/Interpolated/SpinVelocityMatrixElements.jl`; conventional spin-current consumers | `spin_velocity_degenerate_block_unit.jl` |
| Wilson response grouping | Independent two-channel tensor-product response equals two copies of the original chain; existing `atol=1e-6, rtol=1e-4`; nondegenerate kernel exactly unchanged; input boundary/zero allocation checks | `MatrixElements/GeometricLoopMatrixElements.jl`, `Responses/Shared/WilsonLoopResponseKernels.jl`; Wilson SC | `wilson_response_groups_unit.jl` |

The factorization tolerance concerns the raw finite-difference synthetic kernel,
not a material error bound. It does not replace the independent exact spectral
reconstruction guard or authorize GeS/Fe production qualification. The original
standalone GeS observation script is retained separately; CI does not require a
large material input, command-line ARGS, an external solver or a file-copy chain.

`scientific_repair_ci_contract_unit.jl` validates actual Fast registration and
rejects a missing or duplicated member. Existing Fast order/digest, Full and MPI
inventories remain separately fixed; adding these tests removes no previous gate.

The already-recorded SHG finite-eta/cell-label discrepancy is an open diagnostic.
No failing response is made a new correct reference merely to make CI green.
Changes to confirmed numerical semantics follow the user-confirmation boundary
in `ORDINARY_CALCULATION_POLICY.md`. Focused success is not complete Fast/Full/MPI,
release, material or production qualification.
