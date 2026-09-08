# Third-party notices and research data

WannierNLQG source code is distributed under the GNU General Public License
version 2 only (`GPL-2.0-only`). Julia packages listed in `Project.toml` and
`Manifest.toml` remain under their respective licenses; their source code is
not vendored here.

Wannier90, Quantum ESPRESSO, VASP, WannierBerri, MPI implementations, and
other external programs or libraries mentioned by the documentation are not
redistributed by this repository. Users must obtain them separately and follow
their licenses.

## Spglib-generated magnetic-point-group catalogue

The 1651-to-122 magnetic-point-group records distributed with WannierNLQG are
generated solely from the magnetic symmetry operations supplied by the pinned
Spglib dependency. The project-owned classification and display algorithm is
published with the generator and its deterministic receipt. No ISO-MAG or
PythMPG data, source code, dictionary, ordering, or generated result is used by
the active generation chain or included as an active runtime oracle.

The release environment pins Spglib.jl 1.2.0 and its `spglib_jll` 2.7.0+0
dependency, which wraps Spglib C 2.7.0. Exact commits, package and artifact
trees, database-source hashes, license hashes, and generated-output hashes are
recorded in the catalogue-generation receipt.

Please cite:

- A. Togo and I. Tanaka, *Spglib: a software library for crystal symmetry
  search*, arXiv:1808.01590, DOI 10.48550/arXiv.1808.01590.
- K. Shinohara, A. Togo, and I. Tanaka, *Algorithms for magnetic symmetry
  operation search and identification of magnetic space group from magnetic
  crystal structure*, Acta Crystallographica Section A, DOI
  10.1107/S2053273323005016.

### Spglib.jl license

MIT License

Copyright (c) 2024 singularitti <singularitti@outlook.com> and contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

### spglib_jll wrapper license

The Julia source code within the `spglib_jll` wrapper is released under the MIT
"Expat" License. This license does not apply to the Spglib binary package
wrapped by it; the binary package's BSD-3-Clause license is reproduced below.

MIT License

Copyright (c) 2019 JuliaBinaryWrappers

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

### Spglib C library and database license

Copyright (c) 2024, Spglib team

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
* Neither the name of the <organization> nor the names of its contributors may
  be used to endorse or promote products derived from this software without
  specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Synthetic parser fixtures and research data

The repository contains no real or third-party pseudopotentials. It contains
only self-generated synthetic analytic fixtures that exercise UPF and related
parser contracts. Derived regression fixtures are accompanied by
capsule/provenance manifests and exclude wavefunctions and real
pseudopotentials. These files are not reference-material datasets. Do not add
third-party or proprietary research data without an explicit redistribution
review.
