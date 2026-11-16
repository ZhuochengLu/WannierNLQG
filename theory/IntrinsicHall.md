# Intrinsic Hall response at zero temperature

For each momentum and requested Fermi energy, define the occupied indices by
$O(\mu)=\{n:E_n\le\mu\}$ and the empty indices by its complement. The actual
floating-point eigenvalues determine occupation. No group mean, degeneracy
threshold, or lifetime parameter enters this rule. Exactly equal eigenvalues
always have the same occupation, including equality with the Fermi energy.

The complete physical velocity vertex $V^a_{nm}$ has units eV Å. Only pairs
with opposite occupations require the bare position

$$
r^a_{nm}=-i\,\frac{V^a_{nm}}{E_n-E_m}.
$$

Every nonzero floating energy difference is used directly, including a gap below
an exact-spectrum diagnostic tolerance. Compute the velocity/gap ratio directly;
forming the reciprocal first can overflow even when the ratio is finite. There
is no small-gap cutoff, artificial grouping, finite-eta substitution, or omitted
pair. Nonfinite differences, ratios, contractions, or responses raise an explicit
error. This prescription does not guarantee that an arbitrarily large response
fits the floating-point representation.

For the admitted ambient curvature $F^{ab}$, the Matrix contraction is

$$
\Omega^{ab}_O=\sum_{n\in O}\mathrm{Re}\,F^{ab}_{nn}
-\mathrm{Im}\,\sum_{n\in O,m\notin O}
\left(r^a_{nm}r^b_{mn}-r^b_{nm}r^a_{mn}\right).
$$

Both ordered products are retained. Ambient curvature and the complete velocity
must come from the same admitted basis convention. In a nonorthogonal basis,
$C^\dagger SC=I$, $B_a=r_a+iS_a$, and

$$
V^a_{nm}=(C^\dagger H_aC)_{nm}
-E_m(C^\dagger S_aC)_{nm}
+i(E_n-E_m)(C^\dagger B_aC)_{nm}.
$$

The existing metric connection supplies $C^\dagger F_{\rm lower}C$. Neither
$S$ nor its derivatives or basis-connection terms may be dropped.

For an orthogonal orbital frame, the Projector route independently evaluates

$$
\mathrm{Re}\{\mathrm{tr}(PF^{ab})+i\mathrm{tr}(P[\nabla_aP,\nabla_bP])\}.
$$

with the complete occupied
projector and the same opposite-occupation bare links. The nonorthogonal
Projector route is unsupported. Rotations within an exactly equal, completely
occupied or completely empty eigenspace do not change the response. No such
rotation is prescribed between distinct energies.

After integration, the conductivity prefactor is $-e^2/\hbar$, with the
existing Å-to-SI conversion and momentum measure. The geometry constructor owns
velocity and ambient arrays; it does not prepare all-band position ratios.
Multiple Fermi energies preserve input order and can reuse a contraction for
consecutive equal occupation sets. Independent calls share no mutable response
scratch. The other response families retain their own spectral safeguards.

AHC accepts no `degeneracy_threshold`. The former occupation-group API is
removed, together with its callers and API snapshot entry. An explicitly supplied
unsupported numerical parameter is rejected; no input migration is provided.
