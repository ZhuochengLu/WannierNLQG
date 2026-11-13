# Dependency reuse and launch readiness

Project configuration and dependency storage have different lifetimes. Preserve
the selected Project.toml, Manifest.toml, native preferences and their identities
for each request. Do not resolve newer versions to repair a missing local file.
Use Julia's existing package, artifact and compiled-cache resolver rather than a
second installer, a vendored dependency tree or a global PATH change.

## Existing launcher and caches

The workspace lifecycle facade forwards to the frozen package's original typed
development runner. Its canonical lifecycle implementation already supports
qualified read-only dependency depots with an owner-exclusive writable overlay,
and a qualified owner-private dependency depot with zero other writers. Reuse
that implementation. Keep the portable package entry unchanged.

For ordinary successors with the same qualified ABI/preferences/compiler context,
reuse the existing owner depot and compiled caches. Source differences alone do
not justify copying the depot. New package/artifact/cache contents belong only in
the selected writable overlay. Julia may read fallback standard depots; do not
run an installer or change their preferences. A mutable standard depot must not
be advertised as an OS-read-only qualified closure. If such sharing is not
qualified, use the existing lifecycle preserve_isolation mode with a concrete
reason and bind the complete actual JULIA_DEPOT_PATH in the request. ABI, cold
measurement and concurrent-writer isolation remain valid reasons; they do not
require downloading an already present compatible dependency again.

## Required launch sequence

1. Inspect the existing launcher/environment and current qualified caches. Bind
   Project/Manifest/preferences, actual source paths, depot order and compiler/
   native ABI. Inventory missing sources and selected platform artifacts before
   the expensive workload. Use Pkg.dependencies and the standard Artifacts APIs;
   never call update/resolve/instantiate implicitly or substitute a system Qhull
   executable for Qhull_jll's pinned shared library.
   Offline mode does not require an empty JULIA_PKG_SERVER. Julia 1.11 ignores
   compressed registry caches when that variable is empty. If standard General
   metadata is already installed in compressed form, keep the official default
   server identifier while retaining JULIA_PKG_OFFLINE=true, verify registry
   visibility before Pkg.test, and pin/reuse those existing files. Do not clone
   another registry or unpack a second copy merely to repair that setting.
2. Reuse matching installed content. A newly authorized download must match the
   locked archive SHA256 and extracted git-tree SHA1, within its declared byte
   limits. Report any additional substantive missing dependency before obtaining
   it. Neither archive availability nor static inventory is a package-load PASS.
3. On a new native context, run the original registered native-context diagnostic
   with its actual Pkg.test sandbox and unchanged 85 predicates. Retain failures
   and close the full registered identity union. This establishes engineering
   compatibility only; kernel containment and unobserved rank exits retain their
   explicit limits. Never reuse a different host's native context by relabeling.
4. Before production, execute a small real public consumer on the intended model
   input, including full-position reader, metric and occupation checks. Keep
   physical boundary metadata separate from the API's tensor dimension. Admit
   the large mesh only after actual native and consumer checks pass under the
   existing typed runner and fresh resource coordination.

## Geometry is loaded when requested

Fixed BZMesh/KRegion response sampling constructs its declared uniform points
without requesting a Wigner-Seitz cell or a high-symmetry path. The base package
therefore does not import Brillouin. The existing structural-band entry loads
the same locked Brillouin package through Base.require, then uses the existing
world-age bridge to execute the unchanged catalogue/coordinate implementation.
DirectQhull and Qhull_jll remain dependencies of that package. Their versions,
geometry algorithms, public parameters and provenance are unchanged. Missing
geometry dependencies still fail when geometry is requested; there is no silent
fallback, fake catalogue or approximate replacement.

In fresh processes, validate the actual tiny fixed-grid response without any
geometry module loaded, then the public 3D and 2D automatic paths and repeated
calls. The targeted runner is test/support/optional_band_geometry_loading_runner.jl;
also retain the existing automatic_band_path_unit.jl geometry contracts. Only
after these checks pass should the frozen candidate receive its precompile
check. Do not repeat complete Fast/Full campaigns after each edit. Internal
promotion and publication still require their declared applicable gates.

## Current implementation boundary

This document and lazy-load change are a candidate, not a promoted source or a
native qualification. Original stable288, source247, native283 FAIL/HOLD and
running HPC payloads remain untouched. Dynamic checks, formatter/compiler checks
and precompile validation must be recorded against the final candidate before
promotion; a staged test file is not an executed test.
