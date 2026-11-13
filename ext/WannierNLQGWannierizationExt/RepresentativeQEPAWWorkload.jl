using PrecompileTools: @setup_workload, @compile_workload
import WannierNLQG, MPI

# Tiny native QE data enters the spin and overlap/projection trees through public
# APIs. These trees share native PAW input but produce different matrix fields.
@setup_workload let
    assets = normpath(
        joinpath(
            @__DIR__,
            "..",
            "..",
            "test",
            "fixtures",
            "first_use_portable",
            "assets",
            "group_23",
        ),
    )
    source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
        joinpath(assets, "fixture.save");
        include_time_reversal = false,
    )
    output = mktempdir()
    try
        @compile_workload begin
            WannierNLQG._first_use_require_serial()
            w = WannierNLQG.Wannierization
            result = w.generate_qe_paw_spn(
                source,
                joinpath(assets, "fixture.nnkp");
                output_spn_file = joinpath(output, "qe.spn"),
                provenance_json = joinpath(output, "qe.json"),
                max_cached_wavefunction_kpoints = 2,
            )
            @assert result.passed
            overlaps = w.generate_qe_paw_matrix_elements(
                source,
                joinpath(assets, "fixture.nnkp");
                artifact_dir = joinpath(output, "overlaps"),
                require_oracle = false,
            )
            @assert all(isfinite, overlaps.mmn.data) && all(isfinite, overlaps.amn.data)
            @assert isequal(
                WannierNLQG.IO.read_wannier_mmn(overlaps.artifacts["mmn"]).data,
                overlaps.mmn.data,
            )
            @assert isequal(
                WannierNLQG.IO.read_wannier_amn(overlaps.artifacts["amn"]).data,
                overlaps.amn.data,
            )
            # Enter the string-oracle readback branch too. This is compiler
            # coverage against the tiny generated files, not an independent
            # scientific oracle or a material qualification claim.
            readback = w.generate_qe_paw_matrix_elements(
                source,
                joinpath(assets, "fixture.nnkp");
                artifact_dir = joinpath(output, "readback"),
                oracle_mmn_file = overlaps.artifacts["mmn"],
                oracle_amn_file = overlaps.artifacts["amn"],
                require_oracle = true,
            )
            @assert all(isfinite, readback.mmn.data) && all(isfinite, readback.amn.data)
            @assert !MPI.Initialized()
            @assert WannierNLQG.Runtime.ACTIVE_PROGRESS[] === nothing
        end
    finally
        rm(output; recursive = true)
    end
end

# The real audit workload belongs to the five-trigger sibling extension. Actual
# cold traces show this registered public target still compiling in its owner.
# An owner-local stable API declaration is the bounded residual experiment.
precompile(
    resolve_wannierization_entrypoint(:audit_paw_block_partitions),
    (WannierNLQG.Wannierization.PAWBlockPartitionAuditConfig,),
)
