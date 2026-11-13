"""Interpolate full external QGT in the common Hamiltonian frame.

F and A are combined in their original orbital frame before the center transformation.
The full-overlap source is validated by Runtime; this layer checks dimensions and never
substitutes an absent F with zero. No energy-weighted OAM operator is required.
"""
function prepare_quantum_metric_completion!(workspace::MatrixElementWorkspace, model)
    source = workspace.sources.derivative_overlap
    source === nothing && error("QUANTUM_METRIC_FULL_DERIVATIVE_OVERLAP_REQUIRED")
    data = workspace.data
    data.metric_external_generation == data.generation && return data.metric_external
    n = model.num_orbitals
    f_r = source.derivative_overlap_r
    size(f_r) == (n, n, 3, 3, model.num_r_vectors) ||
        throw(DimensionMismatch("Full derivative overlap/model mismatch"))
    a = zeros(ComplexF64, n, n, 3)
    f = zeros(ComplexF64, n, n, 3, 3)
    for r in eachindex(data.fourier_factors)
        factor = data.fourier_factors[r]
        @views a .+= factor .* model.position_r[:, :, :, r]
        @views f .+= factor .* f_r[:, :, :, :, r]
    end
    data.metric_external === nothing && (data.metric_external = similar(f))
    u = Diagonal(workspace.scratch.center_phase_factors) * data.spectrum.eigenvectors
    for b in 1:3, a_index in 1:3
        @views data.metric_external[:, :, a_index, b] .=
            u' * (f[:, :, a_index, b] - a[:, :, a_index]*a[:, :, b]) * u
    end
    all(isfinite, data.metric_external) || error("QUANTUM_METRIC_NONFINITE_EXTERNAL")
    data.metric_external_generation = data.generation
    return data.metric_external
end
