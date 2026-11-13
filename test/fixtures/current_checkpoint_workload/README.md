# Current checkpoint reader workload

This wire-1.7 asset is the actual current two-band/two-k-point synthetic
calculation from engineering run1268, source candidate-r49. It is a new
workload, not a relabeled or purported lossless conversion of an older wire.
Actual source EIG/MMN/topology/geometry were checked; the retained archived
wire1.4 is separately decoded and compared to its original numerical oracle.
The archived solver used AMN initialization while the current recipe uses its
recorded random initialization: their phase, center and spread equality failed
and that result remains in1268. No threshold or scientific result was changed.

The portable asset retains current actual target definitions, but removes local
input lifetimes and explicitly disallows optimizer continuation. Its accepted
numerical arrays must match the producing current checkpoint exactly; physical
projector and zero-spread toy identities are independent checks. Package reader
workloads use private temporary receipts; machine receipts are not shipped.
Regeneration is an explicit maintainer operation in `generate_fixture.jl`.
