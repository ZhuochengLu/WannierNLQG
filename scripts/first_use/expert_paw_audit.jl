#!/usr/bin/env julia

# The one-k-point fixture is shared with star_covariant_paw_gauge_unit.jl.
# It tests the actual public audit path, not a mocked backend or a result reader.
length(ARGS) == 2 || error("usage: expert_paw_audit.jl fixed|weighted output_dir")
mode = first(ARGS)
mode in ("fixed", "weighted") || error("unknown PAW audit mode: $(mode)")
root = abspath(last(ARGS))
ispath(root) && error("expert output already exists: $(root)")
mkpath(root)

import_started = time_ns()
import_timed = @timed Core.eval(Main, :(using HDF5, JSON3, WannierNLQG))
import_wall = (time_ns() - import_started) / 1.0e9

include(joinpath(@__DIR__, "..", "..", "test", "QEPAWMatrixElementsTestSupport.jl"))
using .QEPAWMatrixElementsTestSupport

fixture_started = time_ns()
fixture = write_qe_paw_fixture(
    root;
    metric_kind = mode == "weighted" ? :paw : :norm_conserving,
    spinor = false,
    spinorbit = false,
)
source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
    fixture.save_directory;
    band_range = 1:1,
    include_time_reversal = false,
)
fixture_wall = (time_ns() - fixture_started) / 1.0e9

const W = WannierNLQG.Wannierization
policy =
    mode == "weighted" ? (block_partition_policy = W.HamiltonianWeightedPAWBlockPartition(),) :
    NamedTuple()
audit_started = time_ns()
audited = @timed W.audit_paw_block_partitions(
    W.PAWBlockPartitionAuditConfig(;
        source = source,
        output_hdf5 = joinpath(root, "audit.h5"),
        output_csv = joinpath(root, "audit.csv"),
        output_json = joinpath(root, "audit.json"),
        target_band_count = 1,
        kpoint_indices = [1],
        policy...,
    ),
)
audit_wall = (time_ns() - audit_started) / 1.0e9
result = audited.value
result.status == :STANDARD || error("PAW audit status $(result.status)")
result.violation_count == 0 || error("PAW audit violations $(result.violation_count)")
payload = JSON3.read(read(joinpath(root, "audit.json"), String), Dict{String, Any})
expected_policy = mode == "weighted" ? "hamiltonian_weighted_far_band" : "fixed_gap"
payload["block_partition_policy"] == expected_policy || error("PAW policy output mismatch")
payload["fixed_gap_physics_metrics_status"] == "PARTITION_GRAPH_AND_NATIVE_PREGAUGE_ONLY" ||
    error("PAW physics metrics missing")
record = (
    mode = mode,
    status = string(result.status),
    violation_count = result.violation_count,
    import_wall = import_wall,
    import_compile_time = import_timed.compile_time,
    fixture_wall = fixture_wall,
    audit_wall = audit_wall,
    audit_compile_time = audited.compile_time,
    audit_recompile_time = audited.recompile_time,
    audit_gc_time = audited.gctime,
    audit_allocated_bytes = audited.bytes,
    fixed_gap_physics_metrics_status = payload["fixed_gap_physics_metrics_status"],
    block_partition_policy = payload["block_partition_policy"],
)
write(joinpath(root, "result.json"), JSON3.write(record))
println("EXPERT_PAW_AUDIT_OK compile=$(audited.compile_time)")
