# Independent jerk Eq. (9.20) fixture

`jerk_input.dat` contains column-major complex (real imaginary) values of B, A,
and C with shapes (4,4,3), (4,4,3), (4,4,3,3), respectively. B and A are Hermitian;
C is Hermitian in band indices and symmetric in Cartesian indices. This is an
algebra fixture, not a material or complete Hamiltonian model.

Energies: [-1.5,-0.4,0.7,1.8] eV; photon energies [1.1,2.2,3.3] eV; mu=0 eV;
T=0 K; Gaussian width 0.04 eV; transition window factor 5; P_eta eta=0.001 eV.
All bands are included in Hessians and absorption. No lifetime, SI coefficient,
BZ weight, spin factor or conjugate-order factor is included.

`jerk_reference.dat` contains column-major (3,81) complex ordered coefficients.
Components enumerate a,b,c,d in axis-major order (d fastest). Values were generated
by an independent literal Eq. (9.20) scalar loop, not the optimized jerk kernel.
The full reference generator, input note hashes, scientific checks and provenance
are retained in the local implementation evidence archive outside the formal
package. Frozen input values avoid dependence on a random generator's version.
