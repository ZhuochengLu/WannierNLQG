using SHA
using WannierNLQG

length(ARGS) in (3, 4) ||
    error("usage: StarGaugeThreadProbe.jl SAVE_DIR NNKP OUTPUT_DIR [adaptive|weighted|target]")
save_directory, nnkp_file, output_directory = abspath.(ARGS[1:3])
policy_key = length(ARGS) == 4 ? ARGS[4] : "adaptive"
block_partition_policy =
    policy_key == "adaptive" ? WannierNLQG.Wannierization.AdaptiveEvidencePAWBlockPartition() :
    policy_key in ("weighted", "target") ?
    WannierNLQG.Wannierization.HamiltonianWeightedPAWBlockPartition() :
    error("unsupported policy $(policy_key)")
correction =
    policy_key == "target" ? WannierNLQG.Wannierization.FarBandCovarianceCorrection() :
    WannierNLQG.Wannierization.NoDiscreteHamiltonianCorrection()
mkpath(output_directory)
source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
    save_directory;
    band_range = 1:1,
    include_time_reversal = false,
)
authority =
    policy_key == "target" ? WannierNLQG.Wannierization.SymmetrizedDFTHamiltonian() :
    WannierNLQG.Wannierization.NativeDFTHamiltonian()
target_subspace_contract = if policy_key == "target"
    scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        trues(1, 1),
        trues(1, 1),
    )
    WannierNLQG.Wannierization.TargetSubspaceQualificationContract(
        scope;
        outer_min_ev = -18.0,
        outer_max_ev = 3.5,
        frozen_min_ev = -18.0,
        frozen_max_ev = 0.5,
        num_wannier = 1,
    )
else
    nothing
end
gauge_hdf5 = joinpath(output_directory, "star_gauge.h5")
result = WannierNLQG.Wannierization.prepare_symmetry_covariant_wavefunctions(
    WannierNLQG.Wannierization.SymmetryCovariantWavefunctionPreparationConfig(
        construction_policy = :strict,
        source = source,
        wavefunction_gauge_backend = WannierNLQG.Wannierization.StarCovariantPAWGauge(
            buffer_policy = WannierNLQG.Wannierization.ClosureDrivenBandBuffer(max_extra_bands = 0),
            block_partition_policy = block_partition_policy,
            hamiltonian_correction = correction,
        ),
        authoritative_hamiltonian = authority,
        target_subspace_contract = target_subspace_contract,
        output_hdf5 = gauge_hdf5,
        target_band_count = 1,
    ),
)
result.status == :PASS || error("star-gauge preparation did not pass")
matrices = WannierNLQG.Wannierization.generate_symmetry_completed_qe_paw_matrix_elements(
    source,
    gauge_hdf5,
    nnkp_file;
    artifact_dir = joinpath(output_directory, "matrices"),
)
matrices.passed || error("completed matrix parity did not pass")
extension = first(WannierNLQG.Wannierization._load_wannierization_extension!()).PAWMatrixElements
restored = Base.invokelatest(extension._read_star_covariant_paw_gauge_hdf5, gauge_hdf5; source)
buffer = IOBuffer()
write(buffer, Base.invokelatest(extension._star_payload_sha256, restored.payload), '\n')
write(buffer, reinterpret(UInt8, vec(matrices.mmn.data)))
write(buffer, reinterpret(UInt8, vec(matrices.amn.data)))
write(buffer, reinterpret(UInt8, vec(restored.payload.rotations)))
println("STAR_GAUGE_THREAD_DIGEST=" * bytes2hex(SHA.sha256(take!(buffer))))
