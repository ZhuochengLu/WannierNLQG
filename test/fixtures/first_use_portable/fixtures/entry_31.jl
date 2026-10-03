using Test
include(Main.FirstUsePortableSupport.input("fixtures/support_5.jl"))

const BAND_SF = WannierNLQG.SymmetryFoundation
directory = joinpath(dirname(Main.RECEIPT), "fixture_output")
ispath(directory) && error("fixture output already exists")
mkpath(directory)
poscar, wavecar, _ = write_bounded_vasp_fixture(directory, 2, ComplexF64)
eig_file = joinpath(directory, "synthetic.eig")
open(eig_file, "w") do io
    for kpoint in 1:2, band in 1:2
        println(io, "$(band) $(kpoint) $(band == 1 ? -1.0 : 1.0)")
    end
end
configuration = BAND_SF.VASPBandRepresentationConfig(
    poscar_file = poscar,
    wavecar_file = wavecar,
    eig_file = eig_file,
    output_hdf5_file = joinpath(directory, "band-representation.h5"),
    output_json_file = joinpath(directory, "band-representation.json"),
    band_range = 1:2,
    representation_cutoff_ev = 5.0,
    spinor = true,
    spin_basis_saxis = (0.0, 0.0, 1.0),
    include_time_reversal = false,
    magnetic_moments_cartesian = reshape([0.123, 0.234, 0.345], 3, 1),
    require_oracle = false,
)
representation, validation, hdf5_file, json_file =
    BAND_SF.generate_vasp_band_representation(configuration)
@test validation.passed
@test isfile(hdf5_file)
@test isfile(json_file)
@test size(representation.energies_ev) == (2, 2)
@test maximum(abs, representation.sewing_matrices) > 0
@test all(isfinite, representation.sewing_matrices)
@test representation.schema_version == "1.0"
@test representation.conventions["requested_wannierization_mode"] == "symmetry_adapted"
@test representation.conventions["effective_wannierization_mode"] == "symmetry_adapted"
@test representation.conventions["representation_source"] == "detected"
@test representation.conventions["symmetry_constraints_applied"] == "true"
restored = BAND_SF.read_band_representation_hdf5(hdf5_file)
for field in (
    :real_lattice,
    :reciprocal_lattice,
    :kpoints_fractional,
    :energies_ev,
    :kpoint_map,
    :reciprocal_shifts,
    :sewing_matrices,
    :band_block_labels,
    :irreducible_indices,
    :full_to_irreducible,
    :full_to_operation,
)
    @test getproperty(restored, field) == getproperty(representation, field)
end
@test restored.conventions == representation.conventions
@test restored.input_sha256 == representation.input_sha256

native=Main.FirstUseExpertProbe.native_writer_readback(:write_band_representation_hdf5, hdf5_file)
write(joinpath(dirname(Main.RECEIPT), "native_vasp_band_hdf5.json"), JSON3.write(native))
