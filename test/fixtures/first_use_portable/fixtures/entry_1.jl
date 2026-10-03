using Test
include(Main.FirstUsePortableSupport.input("fixtures/support_1.jl"))

const AUDIT_W = WannierNLQG.Wannierization
directory = joinpath(dirname(Main.RECEIPT), "two_band_fixture")
source = two_band_paw_audit_source(directory; metric_kind = :paw)
result = AUDIT_W.audit_paw_block_partitions(
    AUDIT_W.PAWBlockPartitionAuditConfig(
        source = source,
        output_hdf5 = joinpath(directory, "audit.h5"),
        output_csv = joinpath(directory, "audit.csv"),
        output_json = joinpath(directory, "audit.json"),
        target_band_count = 1,
        kpoint_indices = [1],
        block_partition_policy = AUDIT_W.HamiltonianWeightedPAWBlockPartition(),
    ),
)
@test result.status == :STANDARD
@test result.maximum_gap_ev > 0.0
@test isfinite(result.maximum_coupling)
@test all(isfile, (result.output_hdf5, result.output_csv, result.output_json))
payload = JSON3.read(read(result.output_json, String), Dict{String, Any})
@test payload["block_partition_policy"] == "hamiltonian_weighted_far_band"
@test payload["fixed_gap_physics_metrics_status"] == "PARTITION_GRAPH_AND_NATIVE_PREGAUGE_ONLY"
println("TWO_BAND_PAW_AUDIT_WEIGHTED_GAP_EV ", result.maximum_gap_ev)
