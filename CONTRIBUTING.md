# Contributing

Contributions are welcome after the public repository is opened. By submitting
a contribution, you agree that it may be distributed under the repository's
GNU General Public License version 2 only (`GPL-2.0-only`).

Before proposing a change:

1. Open an issue describing the scientific and software contract affected.
2. Keep physics formulas, conventions, floating-point order, deterministic
   parallel behavior, schemas, and restart compatibility explicit.
3. Add focused tests and report max-abs, max-rel, relative-L2, and NaN/Inf
   counts for numerical changes.
4. Run the public test level, formatting, structure, documentation, and release
   gates described in [development guidance](docs/DEVELOPMENT.md).

Do not commit proprietary potentials, wavefunctions, credentials, machine-local
paths, or generated calculation outputs.
