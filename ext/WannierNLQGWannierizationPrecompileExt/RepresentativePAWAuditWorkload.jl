import WannierNLQG, MPI

# The audit has a distinct metric/partition/sewing tree that SPN generation does
# not enter. Fixed NC and weighted PAW policies share this tiny public family.
# Execute the unchanged representative workflow only after sibling extensions are loaded.
function capture_paw_audit_workflow()
    assets =
        normpath(joinpath(@__DIR__, "..", "..", "examples", "fixtures", "precompile_paw_audit"))
    mktempdir() do output
        configs = [
            WannierNLQG.Wannierization.PAWBlockPartitionAuditConfig(;
                source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
                    joinpath(assets, mode, "fixture.save");
                    band_range = 1:1,
                    include_time_reversal = false,
                ),
                target_band_count = 1,
                kpoint_indices = [1],
                output_hdf5 = joinpath(output, "$(mode).h5"),
                output_csv = joinpath(output, "$(mode).csv"),
                output_json = joinpath(output, "$(mode).json"),
                (
                    mode == "weighted" ?
                    (;
                        block_partition_policy = WannierNLQG.Wannierization.HamiltonianWeightedPAWBlockPartition()
                    ) : NamedTuple()
                )...,
            ) for mode in ("fixed", "weighted")
        ]
        begin
            WannierNLQG._first_use_require_serial()
            for config in configs
                result = WannierNLQG.Wannierization.audit_paw_block_partitions(config)
                @assert result.status == :STANDARD && result.violation_count == 0
            end
            @assert !MPI.Initialized()
            @assert WannierNLQG.Runtime.ACTIVE_PROGRESS[] === nothing
        end
    end
end
