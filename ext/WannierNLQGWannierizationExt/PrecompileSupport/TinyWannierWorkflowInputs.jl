# Shared deterministic public inputs. No extension activation or computation.
function tiny_wannier_workflow(directory; localize = false)
    sf = WannierNLQG.SymmetryFoundation
    wp = WannierNLQG.WannierProjection
    w = WannierNLQG.Wannierization
    win, eig, mmn = (joinpath(directory, "tiny." * suffix) for suffix in ("win", "eig", "mmn"))
    write(win, "num_wann = 1\n")
    energies = [-1.0 -1.0; 1.0 1.0]
    open(eig, "w") do io
        for k in 1:2, band in 1:2
            println(io, "$(band) $(k) $(energies[band, k])")
        end
    end
    neighbors = [2 1; 2 1; 1 2; 1 2; 1 2; 1 2]
    shifts = zeros(Int, 3, 6, 2)
    shifts[1, 2, 1] = -1
    shifts[1, 1, 2] = 1
    shifts[2, 3, :] .= 1
    shifts[2, 4, :] .= -1
    shifts[3, 5, :] .= 1
    shifts[3, 6, :] .= -1
    open(mmn, "w") do io
        println(io, "Tiny WannierNLQG public precompile workload\n2 2 6")
        for k in 1:2, neighbor in 1:6
            println(
                io,
                "$(k) $(neighbors[neighbor, k]) $(shifts[1, neighbor, k]) $(shifts[2, neighbor, k]) $(shifts[3, neighbor, k])",
            )
            for source_band in 1:2, target_band in 1:2
                println(io, source_band == target_band ? "1.0 0.0" : "0.0 0.0")
            end
        end
    end
    operation = sf.SymmetryOperation(Matrix{Int}(I, 3, 3), zeros(3), Matrix{Float64}(I, 3, 3))
    representation = sf.BandRepresentation(
        "1.4",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2pi .* Matrix{Float64}(I, 3, 3),
        (2, 1, 1),
        [0.0 0.0 0.0; 0.5 0.0 0.0],
        energies,
        [operation],
        reshape([1, 2], 1, 2),
        zeros(Int, 3, 1, 2),
        reshape(repeat(Matrix{ComplexF64}(I, 2, 2), 1, 1, 2), 2, 2, 1, 2),
        [1 1; 2 2],
        [1, 2],
        [1, 2],
        [1, 1];
        conventions = Dict("magnetic_structure" => "false"),
        input_sha256 = Dict("fixture" => repeat("0", 64)),
    )
    basis = wp.WannierProjectionBasis(
        [
            wp.WannierProjectionBlock(
                "X",
                "s",
                zeros(3, 1),
                reshape([1], 1, 1),
                reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
                false,
            ),
        ],
        1,
        false,
    )
    representation_file = joinpath(directory, "representation.h5")
    prepare = w.BandRepresentationPreparationConfig(
        wannierization_mode = :symmetry_adapted,
        win_file = win,
        eig_file = eig,
        projection_basis = basis,
        band_representation = representation,
        output_hdf5 = representation_file,
        outer_min_ev = -2.0,
        outer_max_ev = 2.0,
        frozen_min_ev = -2.0,
        frozen_max_ev = -0.5,
        num_wannier = 1,
        compatibility_policy = :strict,
    )
    checkpoint = joinpath(directory, "tiny.wannierization.h5")
    solve = w.WannierizationConfig(
        input = w.WannierizationInputConfig(
            wannierization_mode = :symmetry_adapted,
            win_file = win,
            eig_file = eig,
            mmn_file = mmn,
            projection_basis = basis,
            band_representation_hdf5 = representation_file,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = -0.5,
            num_wannier = 1,
            compatibility_policy = :strict,
        ),
        solver = w.WannierizationSolverConfig(
            initialization = :random,
            stage_controls = w.WannierizationStageControls(
                dis_num_iter = 8,
                num_iter = localize ? 8 : 0,
                dis_conv_tol = 1e-8,
                dis_conv_window = 1,
                conv_tol = 1e-8,
                conv_window = 1,
            ),
            random_seed = 0x1234,
        ),
        checkpoint = w.WannierizationCheckpointConfig(
            checkpoint_hdf5 = checkpoint,
            num_dump_cycles = 0,
        ),
        runtime = w.WannierizationRuntimeConfig(num_print_cycles = 0),
        output = w.WannierizationOutputConfig(
            tb_output_formats = (:packed_hdf5, :model_tb),
            write_model_tb = true,
        ),
    )
    return (; prepare, solve, representation, representation_file, checkpoint, eig, mmn)
end

# Shipped current-format assets never acquire machine-local receipts in source.
# The caller owns this small private workspace; no solver or numeric transform runs.
function read_current_checkpoint_asset(filename, workspace)
    w = WannierNLQG.Wannierization
    receipt = joinpath(workspace, "asset-checkpoint.commit.toml")
    w.adopt_wannierization_checkpoint_hdf5(filename; receipt_path = receipt)
    return w.read_wannierization_checkpoint_hdf5(filename; receipt_path = receipt)
end
