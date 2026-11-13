# Scientific input and model ownership

## Adopted inputs

`read_scientific_source` reads a regular source once and checks its local file
state before and after that read. `read_task_input_file` parses the adopted bytes.
Parsed values remain valid objects after the source changes; a saved observation
is not refreshed to describe another file. TOML paths resolve relative to the
input file. Photon-momentum CSV inputs use the same read boundary.

Text frontend provenance uses `wanniernlqg.task-input-provenance/3.0`.
File-backed requests record an observed file identity; programmatic documents
retain their actual parsed values. A file-state observation is a local lifetime
check. It is not portable content authentication or physical qualification.

## Live model generations

`Core.ScientificDataOwner` identifies a live adopted payload without traversing
scientific arrays. `scientific_data_generation` rejects a retired owner.
`invalidate_scientific_data!` retires a model before replacement; a label is
neither a mathematical definition nor a content certificate.

Adopted arrays and callback captures are logically read-only. Do not mutate them
during a calculation. To change values, retire the previous model and construct
a replacement through its supported constructor. Required physical validation
still applies. Analytic callbacks remain pure functions.

Fourier and response caches retain their numerical selection and the live model
generation. A replacement model requires a new workspace. Prepared real-space
buffers belong to the model that created them. Caller mutation of adopted data
is outside the ownership contract.

## Mathematical equality and MPI

Scientific equality uses the applicable complete input/model/task definitions,
including ordered values, shapes, units, basis/gauge and source ordering.
Native collective admission compares complete definition bytes; rank-local
owner labels and filesystem observations are not cross-rank equality oracles.

Source-lifetime checks bound loading and callbacks. A changed or retired source
is rejected. These checks do not replace mathematical equality, operator
validation, symmetry/covariance checks, finiteness or scientific convergence.
Content authentication reported as `NOT_PERFORMED` is not a successful checksum
verification. External release inventory checks remain independent.

## Caches, publication and persistence

Preparation caches retain complete definitions, owned payloads and bounded
storage. Publication generations and file observations check local lifetime;
they do not establish portable content equality or material qualification.
Unsupported or stale cache envelopes require a new private workspace rather
than silent relabelling. Publication and persistence failures remain errors.

Persisted model, checkpoint and result schemas retain their own explicit
producer/consumer contracts. See [storage schemas](STORAGE_SCHEMAS.md) and
[checkpoint migration](WANNIERIZATION_PLAN_MIGRATION.md) for current formats and
supported conversions. Copies and relocations must satisfy the relevant
adoption/reader contract; copying a label does not qualify the payload.

Preserve historical inputs and accepted checkpoints. A successful read,
conversion, local lifetime check or metadata update alone establishes no new
material or production qualification.
