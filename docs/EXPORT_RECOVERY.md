# Explicit failed-export recovery

Development candidate; execution qualification is tracked outside this frozen source.

The normalized TOML entry accepts `checkpoint.recovery="export"` together with
`checkpoint.restart_hdf5`, `solver.initialization="restart"`, and both stage limits
set to zero. The default `recovery="continue"` retains ordinary restart semantics.

An export retry accepts only a checkpoint whose active errors are exclusively
`TB_EXPORT_FAILED`, with no recorded successful exported artifact. All accepted-state,
source, physical-input, projection, window and matrix checks remain active. Existing
output paths are rejected before logs or terminal checkpoints are opened. Choose a
new output stem for each attempt; repeating the same destination is a refusal, not
an overwrite. Previously generated native matrices remain bound to the accepted
checkpoint and are reused only through the existing validated cache path.

The source checkpoint is immutable. The new result retains each prior error as
`PREVIOUS_TB_EXPORT_FAILED`, including its complete message, original severity/code,
context and source-checkpoint SHA. This historical record is not a declaration that
the prior export passed. The current attempt independently rechecks accepted-state
and export gates, and records `EXPORTED` or `FAILED`. Unrelated errors cannot be
reclassified by this option. A successful retry does not grant material qualification.

Zero-step numeric convergence metadata uses the existing NaN/missing convention;
the packed reader remains strict. Human optimization status still distinguishes
skipped stages from convergence.
