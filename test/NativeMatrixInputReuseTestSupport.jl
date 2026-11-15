module NativeMatrixInputReuseTestSupport
isdefined(@__MODULE__, :InternalSolverFixture) ||
    include(joinpath(@__DIR__, "support", "InternalSolverFixture.jl"))
using WannierNLQG, HDF5, LinearAlgebra, SHA, JSON3
include("QEPAWMatrixElementsTestSupport.jl")
const W = WannierNLQG.Wannierization
const S = WannierNLQG.SymmetryFoundation

"""Use the existing six-neighbor native QE fixture, with actual source bytes."""
function fixture(root)
    mkpath(root)
    root = realpath(root)
    f = QEPAWMatrixElementsTestSupport.write_qe_paw_fixture(
        joinpath(root, "source");
        metric_kind = :norm_conserving,
    )
    shifts = [1 -1 0 0 0 0; 0 0 1 -1 0 0; 0 0 0 0 1 -1]
    h5open(joinpath(f.save_directory, "wfc1.hdf5"), "r+") do h
        HDF5.delete_attribute(h, "igwx")
        HDF5.attributes(h)["igwx"] = 7
        attributes = Dict(
            k => read(HDF5.attributes(h["MillerIndices"])[k]) for
            k in keys(HDF5.attributes(h["MillerIndices"]))
        )
        HDF5.delete_object(h, "MillerIndices")
        h["MillerIndices"] = hcat(zeros(Int, 3, 1), shifts)
        for (key, value) in attributes
            HDF5.attributes(h["MillerIndices"])[key] = value
        end
        HDF5.delete_object(h, "evc")
        h["evc"] = reshape(repeat([1/sqrt(7.0), 0.0], 7), :, 1)
    end
    rows = join(["1 1 " * join(shifts[:, j], " ") for j in 1:6], "\n")
    write(
        f.nnkp_file,
        replace(
            read(f.nnkp_file, String),
            r"begin nnkpts.*?end nnkpts"s => "begin nnkpts\n6\n" * rows * "\nend nnkpts",
        ),
    )
    win = joinpath(root, "model.win")
    eig = joinpath(root, "model.eig")
    a = 2*S.BOHR_TO_ANGSTROM
    write(
        win,
        "num_wann=1\nmp_grid=1 1 1\nbegin unit_cell_cart\n$a 0 0\n0 $a 0\n0 0 $a\nend unit_cell_cart\nbegin kpoints\n0 0 0\nend kpoints\nbegin atoms_frac\nX 0 0 0\nend atoms_frac\nbegin projections\nX:s\nend projections\n",
    )
    write(eig, "1 1 $(-.25*S.HARTREE_TO_EV)\n")
    config = W.WannierizationConfig(
        input = W.WannierizationInputConfig(
            wannierization_mode = :ordinary,
            construction_policy = :standard,
            win_file = win,
            eig_file = eig,
            mmn_file = joinpath(root, "matrices", "native_paw.mmn"),
            source = S.QuantumEspressoWavefunctionSource(
                f.save_directory;
                include_time_reversal = false,
            ),
            matrix_elements = W.NativeQEPAWMatrices(
                f.nnkp_file;
                artifact_dir = joinpath(root, "matrices"),
                require_oracle = false,
            ),
            outer_min_ev = -18.0,
            outer_max_ev = 3.5,
            frozen_min_ev = -18.0,
            frozen_max_ev = 0.5,
            num_wannier = 1,
        ),
        solver = InternalSolverFixture.solver_config(
            initialization = :amn,
            stage_controls = W.WannierizationStageControls(dis_num_iter = 1, num_iter = 2),
            acceleration = W.WannierizationAccelerationConfig(
                schedule = :two_stage,
                disentanglement_max_steps = 1,
                localization_max_steps = 2,
            ),
        ),
        checkpoint = W.WannierizationCheckpointConfig(
            checkpoint_hdf5 = joinpath(root, "baseline.wannierization.h5"),
        ),
        runtime = W.WannierizationRuntimeConfig(num_print_cycles = 0),
        output = W.WannierizationOutputConfig(
            model_file = joinpath(root, "baseline.model.h5"),
            tb_output_formats = (:packed_hdf5, :model_tb),
            write_model_tb = true,
        ),
    )
    result = W.construct_wannier_functions(config)
    result.restart_state === nothing &&
        error("Native baseline has no accepted state: $(result.diagnostics)")
    result.status in (W.COMPLETED, W.COMPLETED_WITH_WARNINGS, W.MAX_ITERATIONS) ||
        error("Native baseline failed: $(result.diagnostics)")
    reference =
        JSON3.read(result.input_summary["native_matrix_acceptance_json"], Dict{String, String})
    return (;
        config,
        reference,
        baseline = (
            v_matrix = result.v_matrix,
            spreads = result.spreads_angstrom2,
            centers = result.wannier_centers_cartesian,
            status = result.status,
        ),
        root,
    )
end

"""Observe every file, including the accepted native provider's complete record."""
function inventory(root)
    result = Dict{String, Any}()
    for (directory, _, files) in walkdir(root), name in files
        file = joinpath(directory, name)
        info = stat(file)
        result[relpath(file, root)] = (
            sha = bytes2hex(sha256(read(file))),
            bytes = info.size,
            inode = info.inode,
            mtime = info.mtime,
            ctime = info.ctime,
        )
    end
    return result
end

"""Only execution/storage and fresh output locations differ from the serial reference."""
function reuse_config(f, label; parallel = :serial, mode = :dense_reference)
    root = joinpath(f.root, label)
    return W._replace_wannierization_config(
        f.config;
        input = (;
            preparation_execution = W.WavefunctionPreparationExecutionConfig(
                mode = mode,
                max_workers = 1,
                checkpoint_directory = joinpath(root, "preparation"),
                resume = true,
            )
        ),
        solver = (; parallel),
        checkpoint = (; checkpoint_hdf5 = joinpath(root, "result.wannierization.h5")),
        output = (; model_file = joinpath(root, "result.model.h5")),
    )
end
end
