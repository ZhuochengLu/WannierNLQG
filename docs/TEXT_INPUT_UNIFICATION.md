# Unified scientific TOML input

The two obsolete workflow outer namespaces are removed from the core resolver.
All supported text-expressible constructor options remain available, including
advanced nested solver controls, native provider thresholds, auxiliary projection
inputs and all nine formerly unmapped projection settings. Constructor defaults
remain authoritative. Functions and owned in-memory objects remain Julia-only.

The external converter is the only historical decoder. Its current-format mode
maps a complete typed configuration, retaining supported defaults and overrides;
its historical mode requires explicit new stopping/output policy. It performs no
solver work. An actual WIN is required where geometry was previously WIN-owned.
Unknown or obsolete modes/settings raise errors. Files cannot silently mix schemas.

Response task sections and APIs are preserved. This change does not remove task
wrappers, scientific kernels, checkpoint APIs, time-domain JSON, preferences or
environment variables. Three-file model delivery is a separate change.
