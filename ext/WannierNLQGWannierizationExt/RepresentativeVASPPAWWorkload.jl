using PrecompileTools: @setup_workload, @compile_workload
import WannierNLQG, MPI

# PAW overlap/projection and nonzero spin share one two-band/two-k native input
# family. Their public APIs activate W's four triggers without Spglib. Keep the
# capture in that image, so the actual first user call can load its compiled tree.

@setup_workload let
    root = mktempdir()
    try
        @compile_workload begin
            WannierNLQG._first_use_require_serial()
            sf = WannierNLQG.SymmetryFoundation
            w = WannierNLQG.Wannierization
            iow = WannierNLQG.IO
            (; poscar, wavecar) = WannierNLQG.TinyVASPNativeInputs.tiny_vasp_native_inputs(root)
            # Zero augmentation is a native overlap/projection fixture, not an
            # augmentation-strength oracle. The separate spin input below has
            # the actual nonzero radial integral of the shipped PAW fixture.
            potcar = joinpath(root, "POTCAR-overlap")
            write(
                potcar,
                replace(
                    WannierNLQG.TinyVASPNativeInputs.synthetic_potcar_block("X"; q0 = 0.0),
                    "0.12 0.22 0.32" => "0.10 0.20 0.30",
                ),
            )
            incar = joinpath(root, "INCAR")
            write(incar, "LNONCOLLINEAR = .TRUE.\nSAXIS = 0 0 1\n")
            outcar = joinpath(root, "OUTCAR")
            write(
                outcar,
                "vasp.6.3.0 synthetic\nNKPTS = 2 k-points in BZ NBANDS= 2\nENCUT = 5.000 eV\ndirect lattice vectors                 reciprocal lattice vectors\n5.0 0.0 0.0 0.2 0.0 0.0\n0.0 5.0 0.0 0.0 0.2 0.0\n0.0 0.0 5.0 0.0 0.0 0.2\nLOCPROJ orbitals\n1 0 1 1.890 0 0 0 1 0 0 0 0 1 1 0 0 1\n1 0 1 1.890 0 0 0 1 0 0 0 0 1 2 0 0 1\nComputing AMN\n",
            )
            source = sf.VASPWavefunctionSource(
                poscar,
                wavecar;
                potcar_file = potcar,
                incar_file = incar,
                outcar_file = outcar,
                band_range = 1:2,
                spinor = true,
                spin_basis_saxis = (0.0, 0.0, 1.0),
                include_time_reversal = false,
            )
            topology = joinpath(root, "topology.mmn")
            iow.write_wannier_mmn(
                topology,
                iow.WannierMMN(
                    2,
                    2,
                    1,
                    zeros(ComplexF64, 2, 2, 1, 2),
                    reshape([1, 2], 1, 2),
                    zeros(Int, 3, 1, 2),
                ),
            )
            win = joinpath(root, "tiny.win")
            write(
                win,
                "num_wann=2\nspinors=true\nmp_grid=2 1 1\nbegin unit_cell_cart\n5 0 0\n0 5 0\n0 0 5\nend unit_cell_cart\nbegin atoms_frac\nX 0 0 0\nend atoms_frac\nbegin kpoints\n0 0 0\n0.5 0 0\nend kpoints\nbegin projections\nX:s\nend projections\n",
            )
            basis = WannierNLQG.WannierProjection.build_wannier_projection_basis(win)
            overlaps = w.generate_vasp_paw_matrix_elements(
                source,
                basis,
                topology;
                output_mmn_file = joinpath(root, "tiny.mmn"),
                output_amn_file = joinpath(root, "tiny.amn"),
                provenance_hdf5 = joinpath(root, "overlaps.h5"),
                require_oracle = false,
            )
            @assert overlaps.passed
            @assert all(isfinite, iow.read_wannier_mmn(joinpath(root, "tiny.mmn")).data)
            @assert all(isfinite, iow.read_wannier_amn(joinpath(root, "tiny.amn")).data)
            spin_potcar = joinpath(root, "POTCAR-spin")
            radial_integral = reinterpret(Float64, UInt64(0x3f66f0af75511c09))
            write(
                spin_potcar,
                WannierNLQG.TinyVASPNativeInputs.synthetic_potcar_block("X"; q0 = radial_integral),
            )
            spin_source = sf.VASPWavefunctionSource(
                poscar,
                wavecar;
                potcar_file = spin_potcar,
                band_range = 1:2,
                spinor = true,
                spin_basis_saxis = (0.0, 0.0, 1.0),
                include_time_reversal = false,
            )
            spin = w.generate_vasp_paw_spn(
                spin_source;
                output_spn_file = joinpath(root, "tiny.spn"),
                provenance_hdf5 = joinpath(root, "spin.h5"),
                spin_channel = 1,
                execution = w.WavefunctionPreparationExecutionConfig(
                    mode = :streaming_threads,
                    max_workers = 1,
                    checkpoint_directory = joinpath(root, "spin-checkpoint"),
                ),
            )
            @assert spin.passed && spin.radial_q_max_absolute <= 5.0e-7
            @assert spin.component_norms["augmentation_max_absolute"] > 0
            @assert all(isfinite, iow.read_wannier_spn(joinpath(root, "tiny.spn")).data)
            @assert !MPI.Initialized()
            @assert WannierNLQG.Runtime.ACTIVE_PROGRESS[] === nothing
        end
    finally
        rm(root; recursive = true)
    end
end
