# Private numerical infrastructure

WannierNLQG contains project-owned dense-spectrum, FFT plan/buffer and checked
workspace helpers under `WannierNLQG.Core.ESKernel`. These helpers are private
implementation details, not a separately installed or released package and not
part of the facade API.

The original arithmetic, LAPACK calls, FFTW plan execution and ownership
partitions are retained. Physical conventions, tolerances and acceptance
decisions remain with the response and matrix-element consumers.

The integrated source is covered by the root GPL-2.0-only license. Julia
LinearAlgebra and FFTW remain external dependencies under their own licenses.
The focused numerical tests are part of the ordinary contributor test suite.
