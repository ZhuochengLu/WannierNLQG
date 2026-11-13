using PrecompileTools: @setup_workload, @compile_workload
import WannierNLQG

# The real native BandRepresentation API activates this three-trigger owner.
# Capturing it only in the five-trigger composite image left its cold call cold.
# The shared helper defines only tiny synthetic input bytes, no W extension API.

@setup_workload let
    root = mktempdir()
    try
        @compile_workload begin
            sf = WannierNLQG.SymmetryFoundation
            (; poscar, wavecar, eig) =
                WannierNLQG.TinyVASPNativeInputs.tiny_vasp_native_inputs(root)
            # A generic magnetic direction leaves a minimal real symmetry
            # inventory. This still uses actual public native construction.
            representation, validation, representation_file, _ =
                sf.generate_vasp_band_representation(
                    sf.VASPBandRepresentationConfig(
                        poscar_file = poscar,
                        wavecar_file = wavecar,
                        eig_file = eig,
                        output_hdf5_file = joinpath(root, "representation.h5"),
                        output_json_file = joinpath(root, "representation.json"),
                        band_range = 1:2,
                        representation_cutoff_ev = 5.0,
                        spinor = true,
                        spin_basis_saxis = (0.0, 0.0, 1.0),
                        include_time_reversal = false,
                        magnetic_moments_cartesian = reshape([0.123, 0.234, 0.345], 3, 1),
                        require_oracle = false,
                    ),
                )
            @assert validation.passed && all(isfinite, representation.sewing_matrices)
            @assert isequal(
                sf.read_band_representation_hdf5(representation_file).sewing_matrices,
                representation.sewing_matrices,
            )

            @assert WannierNLQG.Runtime.ACTIVE_PROGRESS[] === nothing
        end
    finally
        rm(root; recursive = true)
    end
end
