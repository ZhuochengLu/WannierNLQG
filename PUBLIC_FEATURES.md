# Public source features

Derived from scripts/source_distribution.json.

## public-core

Electronic responses and quantum geometry, model I/O, preparation workflows, ordinary user tools, contributor tests and CI.

Dependencies: MPI, HDF5, JSON3, FFTW, PrecompileTools, Spglib, EzXML.

## numerical-infrastructure

Project-owned private numerical implementation bundled with WannierNLQG; no standalone package or API

Dependencies: LinearAlgebra, FFTW.

## contributor-test-support

Portable contributor rank selection and source inventory; no internal runtime guardian or recovery commands

Dependencies: Python standard library.

## fixture-privacy-transport

Explicit privacy-only transport of synthetic reference containers; no numerical or qualification reinterpretation

Dependencies: .
