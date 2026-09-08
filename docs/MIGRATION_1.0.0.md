# WannierNLQG 1.0.0 public API overview

WannierNLQG 1.0.0 is the initial public release, so there is no preceding public
version to migrate from. This page summarizes the public configuration and
namespace boundaries established by 1.0.0. Future migration notes will compare
each release with the preceding public tag.

## Response configuration and task instances

`TaskConfig` combines shared `model`, `sampling`, `execution`, and `output`
groups with one or more independently parameterized `TaskSpec` instances:

```julia
TaskConfig(
    model = ModelInput(model_file="seed_tb.dat", case_root=@__DIR__),
    sampling = BZMesh(k_mesh=(100, 100), spatial_dimension=2),
    tasks = [TaskSpec(
        id="sc_reference",
        quantity="SC",
        method="Conventional",
        physics=OpticalParameters(
            photon_energies=collect(range(0.0, 4.0; length=200)),
            fermi_energy=0.0,
            temperature=0.0,
        ),
        numerics=OpticalNumerics(broadening=0.06),
        observable=FullTensor(),
    )],
    execution = ExecutionOptions(fourier_backend="direct"),
    output = OutputOptions(output_root="results", system_name="sample"),
)
```

Each task has a unique ID and owns its physical inputs, numerical controls, and
observable. `BZMesh` selects Integral execution, `KSlice` selects K-slice, and
`KPath` selects the K-path domain. The current K-path registry exposes band
structure. See the [user guide](../USER_GUIDE.md) for the full task registry and
the [examples](../examples/tasks/) for runnable synthetic configurations.

## Public namespaces

The top-level facade exports grouped response configuration types, typed
observable selectors, `RunResult`, and `run`. Expert functionality is accessed
through its owning qualified namespace:

- `WannierNLQG.SymmetryFoundation` owns crystal and magnetic symmetry,
  representations, detection, persistence, and real-space symmetry kernels.
- `WannierNLQG.WannierProjection` owns projection specifications, radial
  transforms, projection bases, WIN parsing, and symmetry-plan construction.
- `WannierNLQG.Symmetrization` owns existing-model symmetrization workflows.
- `WannierNLQG.Wannierization` owns ordinary and symmetry-adapted construction
  workflows.

The facade and expert namespace inventories are enforced by the API and
structure checks.

## Wannierization configuration

`SymmetryAdaptedWannierizationConfig` contains exactly five immutable groups:
`input`, `solver`, `checkpoint`, `runtime`, and `output`. Construct the group
types through `WannierNLQG.Wannierization`; see the
[configuration reference](WANNIERIZATION_CONFIG_MIGRATION.md) and
[Wannierization guide](WANNIERIZATION.md).

For a persistent symmetry-adapted run, select the canonical checkpoint suffix
explicitly in the checkpoint group:

```julia
checkpoint_hdf5 = "checkpoint.wannierization.h5"
```

## Model, sampling, and outputs

- `ModelInput` selects one explicit model or Packed-operator route and records
  basis and real-space replica conventions.
- `BZMesh`, `KSlice`, and `KPath` are distinct sampling domains.
- Every response task writes under `output_root/<id>/`; root metadata indexes
  task results and compatible-data reuse.
- Public examples use synthetic inputs and write to temporary or explicit output
  roots. Their smoke meshes demonstrate the interface, not material convergence.

## Storage and validation boundaries

Readers validate the declared wire contract, payload shape, identity digests,
and qualification metadata before use. Unsupported or inconsistent artifacts
fail closed; changing a label cannot upgrade an artifact's qualification.
Version-dependent storage behavior is documented in the
[storage schema inventory](STORAGE_SCHEMAS.md) and the relevant workflow guide.

Package tests establish software regression coverage. They do not establish
material-specific Numerical, Physics, or Production qualification.
