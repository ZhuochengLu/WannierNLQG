using LinearAlgebra

# Build a two-k-point state with a nonempty free complement for actual checkpoint continuation.
function storage_schema_restart_fixture(; mmn_scale::Float64 = 1.0)
    w = WannierNLQG.Wannierization
    wannier_io = WannierNLQG.IO
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    energies = [-1.0 -1.0; 1.0 1.0]
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.0",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (2, 1, 1),
        [0.0 0.0 0.0; 0.5 0.0 0.0],
        energies,
        [identity_operation],
        reshape([1, 2], 1, 2),
        zeros(Int, 3, 1, 2),
        reshape(repeat(Matrix{ComplexF64}(I, 2, 2), 1, 1, 2), 2, 2, 1, 2),
        [1 1; 2 2],
        [1, 2],
        [1, 2],
        [1, 1];
        conventions = Dict("fourier" => "H(k)=sum_R exp(+2pi*i*k.R) H(R)"),
        input_sha256 = Dict("fixture" => repeat("0", 64)),
    )
    projection_block = WannierNLQG.WannierProjection.WannierProjectionBlock(
        "X",
        "s",
        zeros(3, 1),
        reshape([1], 1, 1),
        reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
        false,
    )
    basis = WannierNLQG.WannierProjection.WannierProjectionBasis([projection_block], 1, false)
    plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        [identity_operation],
        ones(ComplexF64, 1, 1, 1),
        zeros(Int, 3, 1, 1),
    )
    eig = wannier_io.WannierEIG(2, 2, copy(energies))
    mmn_data = zeros(ComplexF64, 2, 2, 6, 2)
    for kpoint in 1:2, neighbor in 1:6
        mmn_data[:, :, neighbor, kpoint] .= mmn_scale .* Matrix{ComplexF64}(I, 2, 2)
    end
    neighbors = [2 1; 2 1; 1 2; 1 2; 1 2; 1 2]
    reciprocal_shifts = zeros(Int, 3, 6, 2)
    reciprocal_shifts[1, 2, 1] = -1
    reciprocal_shifts[1, 1, 2] = 1
    reciprocal_shifts[2, 3, :] .= 1
    reciprocal_shifts[2, 4, :] .= -1
    reciprocal_shifts[3, 5, :] .= 1
    reciprocal_shifts[3, 6, :] .= -1
    mmn = wannier_io.WannierMMN(2, 2, 6, mmn_data, neighbors, reciprocal_shifts)
    config = w.SymmetryAdaptedWannierizationConfig(
        input = w.WannierizationInputConfig(
            construction_policy = :strict,
            wannierization_mode = :symmetry_adapted,
            win_file = "synthetic.win",
            eig_file = "synthetic.eig",
            mmn_file = "synthetic.mmn",
            projection_basis = basis,
            band_representation = representation,
            num_wannier = 1,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = -0.5,
        ),
        solver = w.WannierizationSolverConfig(
            initialization = :random,
            z_mix_ratio = 0.25,
            u_mix_ratio = 0.75,
            max_iterations = 2,
            localize = false,
            convergence_tolerance = 1.0e-10,
            convergence_window = 20,
            random_seed = 0x1234,
        ),
        checkpoint = w.WannierizationCheckpointConfig(),
        runtime = w.WannierizationRuntimeConfig(),
        output = w.WannierizationOutputConfig(),
    )
    return (; representation, basis, plan, eig, mmn, config)
end
