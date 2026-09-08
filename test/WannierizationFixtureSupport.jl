using HDF5
using JSON3
using LinearAlgebra
using Random
using SHA
using Test

const WANNIERIZATION = WannierNLQG.Wannierization
const WANNIER_IO = WannierNLQG.IO
const WANNIERIZATION_IMPLEMENTATION = first(WANNIERIZATION._load_wannierization_extension!())

# Build the smallest two-k-point SAWF fixture with a complete three-dimensional stencil.
function synthetic_wannierization_fixture(; mmn_scale::Float64 = 1.0)
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
    eig = WANNIER_IO.WannierEIG(2, 2, copy(energies))
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
    mmn = WANNIER_IO.WannierMMN(2, 2, 6, mmn_data, neighbors, reciprocal_shifts)
    config = WANNIERIZATION.SymmetryAdaptedWannierizationConfig(
        input = WANNIERIZATION.WannierizationInputConfig(
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
        solver = WANNIERIZATION.WannierizationSolverConfig(
            initialization = :random,
            z_mix_ratio = 0.25,
            u_mix_ratio = 0.75,
            max_iterations = 8,
            convergence_tolerance = 1.0e-10,
            convergence_window = 1,
            random_seed = 0x1234,
        ),
        checkpoint = WANNIERIZATION.WannierizationCheckpointConfig(),
        runtime = WANNIERIZATION.WannierizationRuntimeConfig(),
        output = WANNIERIZATION.WannierizationOutputConfig(),
    )
    return (; representation, basis, plan, eig, mmn, config)
end

# Rebuild the immutable public config while overriding a small named subset.
function modified_wannierization_config(config; keywords...)
    replacements = NamedTuple(keywords)
    unknown = setdiff(keys(replacements), WANNIERIZATION.WANNIERIZATION_CONFIG_LEAF_FIELDS)
    isempty(unknown) || throw(ArgumentError("unknown Wannierization config fields: $(unknown)"))
    select(fields) = begin
        selected = Tuple(name for name in keys(replacements) if name in fields)
        NamedTuple{selected}(Tuple(getfield(replacements, name) for name in selected))
    end
    return WANNIERIZATION._replace_wannierization_config(
        config;
        input = select(WANNIERIZATION.WANNIERIZATION_INPUT_CONFIG_FIELDS),
        solver = select(WANNIERIZATION.WANNIERIZATION_SOLVER_CONFIG_FIELDS),
        checkpoint = select(WANNIERIZATION.WANNIERIZATION_CHECKPOINT_CONFIG_FIELDS),
        runtime = select(WANNIERIZATION.WANNIERIZATION_RUNTIME_CONFIG_FIELDS),
        output = select(WANNIERIZATION.WANNIERIZATION_OUTPUT_CONFIG_FIELDS),
    )
end

# Supply an honest mode contract for diagnostic-only persistence; this does not qualify arrays.
function diagnostic_public_band_representation(representation)
    config = WANNIERIZATION.BandRepresentationPreparationConfig(
        wannierization_mode = :symmetry_adapted,
        win_file = "diagnostic-only.win",
        eig_file = "diagnostic-only.eig",
        band_representation = representation,
        num_wannier = 1,
    )
    workflow = WANNIERIZATION_IMPLEMENTATION.WorkflowOrchestration
    with_mode =
        Base.invokelatest(workflow._representation_with_mode_contract, representation, config)
    return Base.invokelatest(workflow._completed_public_band_representation, with_mode)
end

# Mark completion only after every shared fixture definition has been loaded.
const WANNIERIZATION_FIXTURE_SUPPORT_LOADED = true
