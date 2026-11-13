# Strict CI same-start setsid reproof

Only declared CI scheduler self-tests can reprove a same-PID/start child group
leader. Fresh executable, complete literal scheduler argv, exact private fake
bytes, source pins, session, and full owned ancestry are rechecked and bracketed
by identity/snapshot checks. Root transitions and nonleader escapes are rejected.
Tracking is committed transactionally only after final LIVE reads. The original
0.5-second driver exec transition timer remains; existing MPI reproof is unchanged.
No query retry/grace or generic PASS is added.

The closed engineering-matrix fixture schema
`wanniernlqg.ci-owned-group-fixture-contract/1` supports only profile
`targeted_and_native` and the exact single CIControlledGroupLifecycle selector.
It exercises synthetic controls and a real fork/setsid/exec of the unchanged
pinned FAKE bytes with a parent wait. All evidence stays outside the source.
The fixture is ENGINEERING only, never scientific/publication acceptance.
Original source011 Fast2 remains FAIL; its raw record lacks argv/parent chain,
so the legality of the original PID95074 cannot be reconstructed.
No Linux, complete kernel containment, or new science validation is claimed.

Successor003 also repeats fresh literal proof for each subsequent CI group
observation. Only the pinned interrupt-test child with exactly derived
Python -c text, interpreter, session and direct owned parent is supported.
Unknown children and subsequent changed argv are rejected. No new timer grace.
