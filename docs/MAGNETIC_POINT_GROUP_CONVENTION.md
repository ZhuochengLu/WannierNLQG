# WannierNLQG Spglib-canonical H-M convention 1.0

This document defines the project-owned display convention
`wanniernlqg.spglib-canonical/1.0` and the machine-identity contract
`wanniernlqg.magnetic-point-group-operations/1.0`. The two contracts are
deliberately separate: a Hermann--Mauguin (H-M) string is for display, while a
normalized colored-operation digest identifies the magnetic point group.

The implementation and generated catalog use only the locked Spglib magnetic
database and `spg_get_pointgroup`. No external magnetic point-group symbol table,
ordering, lookup dictionary, or generated result is an input.

## Machine identity

For one magnetic space group, translations are removed and duplicate point
operations are collapsed. Every remaining operation is the pair `(W, a)`, where
`W` is a 3 by 3 unimodular integer fractional rotation and `a` is `0` for a
unitary operation or `1` for an antiunitary operation. Group equality is the pair

```text
(magnetic_point_group_number, operation_digest)
```

The UNI number and MSG type identify the source magnetic space group. They do not
replace the point-group identity. H-M strings never participate in equality,
caching, or scientific acceptance tests.

### Digest normalization

1. Call Spglib `spg_get_pointgroup` on the distinct spatial rotations. Let its
   ordinary point-group number be `N`, its display symbol be `H`, and its integer
   standardization transform be `P`, with
   `W_standard = inv(P) * W_input * P`. Only `N`, `P`, and the operations enter
   machine normalization; `H` is passed solely to the display renderer.
2. Build a finite, deterministic integer normalizer search. Start from the
   standard basis and all primitive axes of the standardized operations, ordered
   by squared norm and then by integer tuple. For tetragonal, trigonal, and
   hexagonal groups, enumerate primitive basal vectors with components in
   `-2:2` and retain `z` as the third vector. For other systems, enumerate all
   nonsingular triples from the ordered axis set. Order candidate matrices by
   absolute determinant, squared Frobenius norm, and row-major entries.
3. Keep exactly those candidates `Q` for which every
   `inv(Q) * W_standard * Q` is integral and the transformed spatial-operation
   set is exactly the standardized spatial-operation set. This is the convention
   1.0 finite integer normalizer.
4. For each valid candidate, transform the complete colored set, remove exact
   duplicates, and sort pairs by `(a, r11, r12, ..., r33)`, with `0 < 1`.
5. Serialize using LF newlines and a final LF:

   ```text
   wanniernlqg.magnetic-point-group-operations/1.0
   0:r11,r12,r13,r21,r22,r23,r31,r32,r33
   1:r11,r12,r13,r21,r22,r23,r31,r32,r33
   ```

6. Choose the lexicographically smallest complete serialization and take its
   lowercase SHA-256. When several normalizers produce the same serialization,
   choose the one with the lexicographically smallest row-major `Q` for the
   reported basis. Operation order, duplicated database operations, and any
   allowed input basis therefore do not change the digest.
7. Assign class numbers by the minimum UNI number carrying each previously unseen
   digest. On the locked database this reproduces the stable class range 1--122.

The exact basis reported with an identity is `B = P * Q` for the winning digest
candidate and obeys

```text
v_input = B * v_canonical
W_input = B * W_canonical * inv(B)
```

It is serialized as `shape = [3,3]`, reduced `numerator_rows`, and one positive
common `denominator`. Generation and runtime classification both require an exact
bijection between the input and reconstructed colored-operation sets.

When time reversal is disabled, the active unitary subgroup is canonicalized as
its own Type-I colored group. It must not inherit the full magnetic group's digest
or class number.

## Display convention

The H-M display value is generated from the colored operations and is never read
from a magnetic point-group table.

- Type I uses Spglib's ordinary point-group H-M symbol.
- A gray group appends `1'` to the ordinary symbol. The trivial gray group is
  exactly `1'`, never `11'`.
- A black-white group colors the ordinary H-M slots. Slot axes are determined from
  exact integer eigenaxes and the ordinary crystal system. Every convention-1.0
  normalizer basis is rendered, producing the full equivalent-axis symbol orbit.
- A structured `(slot, color)` tuple selects the display. Primed slots sort before
  unprimed slots. The slot priority is the written H-M order except for
  proper-rotation-only orthorhombic and tetragonal three-slot symbols, whose
  secondary-axis priority is `(first, third, second)`. The raw symbol breaks any
  remaining tie. This rule is uniform by crystal system and slot type; it has no
  UNI-, class-, or symbol-specific exception.
- `equivalent_axis_notation` is true exactly when the permitted normalizer orbit
  produces more than one distinct display string.

The display convention changes five operation classes (49 UNI records) relative
to the earlier release display:

| Class | Convention 1.0 display |
| ---: | :--- |
| 19 | `2'22'` |
| 89 | `6'2'2` |
| 93 | `6'm'm` |
| 103 | `6'/mm'm` |
| 104 | `6'/m'm'm` |

These are display migrations only. The complete colored operations, projector,
allowed tensor subspace, and scientific arrays remain the acceptance authority.

## Reference pseudocode

```text
for UNI in 1:1651
    rotations, translations, antiunitary = spglib_magnetic_database(UNI)
    point_ops = unique(rotations, antiunitary)       # translations discarded
    N, H, P = spg_get_pointgroup(unique(rotations))
    candidates = []
    for Q in finite_integer_normalizer(point_ops, N, P)
        colored = conjugate(point_ops, inv(Q) * inv(P))
        serialized = serialize_sorted(colored, digest_contract)
        display = render_structured_slots(colored, H)
        push!(candidates, (serialized, display, B=P*Q))
    end
    digest_candidate = minimum(candidates, by=serialized)
    display_candidate = minimum(candidates, by=structured_slot_color_key)
    verify_exact_bijection(point_ops, digest_candidate.colored, digest_candidate.B)
    record(UNI, SHA256(digest_candidate.serialized), display_candidate.display)
end
number_classes_by_minimum_UNI()
```

## Test vectors

The focused gate covers Type I--IV representatives and both ends of the UNI
range. Required display vectors include UNI 1 -> `1`, UNI 2 -> `1'`, the Type-III
class-19 representative UNI 101 -> `2'22'`, and UNI 1651 -> `m'-3'm'`.
Reversing or randomly shuffling operation order must leave the class, digest,
display, and basis payload unchanged. Conjugating by every permitted basis must
leave class and digest unchanged and must reconstruct the original input
operations exactly through the reported rational transform.
