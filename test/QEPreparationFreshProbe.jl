# Test-only process boundary. This calls the real preparation API; no copied kernels.
using WannierNLQG, HDF5, JSON3, EzXML, Spglib, Serialization
length(ARGS) == 5 || error("QE preparation probe requires source, topology, cache, reference, mode")
E = first(WannierNLQG.Wannierization._load_wannierization_extension!()).PAWMatrixElements
source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
    ARGS[1];
    include_time_reversal = false,
)
reference = open(Serialization.deserialize, ARGS[4])
mode = ARGS[5]
mode in ("norm", "overlap") || error("unsupported QE preparation probe mode")
E._with_qe_operator_preparation(
    source,
    ARGS[2],
    2;
    checkpoint_directory = ARGS[3],
    implementation_contract = "complete-source-fixture-v1",
) do
    state = E._uiu_qe_state(source, ARGS[2], 2)
    @assert state.normalization_points[] == 3
    @assert !isempty(state.wavefunction_cache.load_counts)
    if mode == "norm"
        @assert state.generalized_norm == reference.norm
        @assert [state.spn_block(k) for k in 1:3] == reference.spn
        @assert state.beta_contractions[] == 3
    else
        @assert E._uiu_center_neighbor_block(state, 1, 1) == reference
        @assert state.overlap_contractions[] == 1
        @assert E._uiu_center_neighbor_block(state, 1, 1) == reference
        @assert state.overlap_contractions[] == 2
    end
    @assert E._uiu_qe_state(source, ARGS[2], 2).wavefunction_cache === state.wavefunction_cache
end
@assert get(task_local_storage(), :wannier_preparation_artifact_cache, nothing) === nothing
@assert get(task_local_storage(), :wannier_qe_operator_preparation, nothing) === nothing
println("FRESH_QE_RECOMPUTE_PASS")
