using LinearAlgebra
using Test
include(Main.FirstUsePortableSupport.input("fixtures/support_5.jl"))

const VASP_PAW_W = WannierNLQG.Wannierization
const VASP_PAW_IO = WannierNLQG.IO
const VASP_PAW_SF = WannierNLQG.SymmetryFoundation
root = joinpath(dirname(Main.RECEIPT), "fixture_output")
ispath(root) && error("fixture output already exists")
mkpath(root)
poscar, wavecar, _ = write_bounded_vasp_fixture(root, 2, ComplexF64)
potcar = joinpath(root, "POTCAR")
# The existing native-resolver test uses matching AE/pseudo radial waves and q0=0.
# This is a zero-augmentation PAW fixture, not an augmentation-strength test.
write(potcar, replace(synthetic_potcar_block("X"; q0 = 0.0), "0.12 0.22 0.32" => "0.10 0.20 0.30"))
open(wavecar, "r+") do stream
    for k in 1:2, band in 1:2
        coefficients = zeros(ComplexF64, 2k)
        coefficients[1 + (band - 1) * k] = 1
        seek(stream, 512 * (2 + (k - 1) * 3 + band))
        write(stream, coefficients)
    end
end
incar = joinpath(root, "INCAR")
write(incar, "LNONCOLLINEAR = .TRUE.\nSAXIS = 0 0 1\n")
outcar = joinpath(root, "OUTCAR")
write(
    outcar,
    """
vasp.6.3.0 synthetic
NKPTS = 2 k-points in BZ NBANDS= 2
ENCUT = 5.000 eV
direct lattice vectors                 reciprocal lattice vectors
5.0 0.0 0.0 0.2 0.0 0.0
0.0 5.0 0.0 0.0 0.2 0.0
0.0 0.0 5.0 0.0 0.0 0.2
LOCPROJ orbitals
1 0 1 1.890 0 0 0 1 0 0 0 0 1 1 0 0 1
1 0 1 1.890 0 0 0 1 0 0 0 0 1 2 0 0 1
Computing AMN
""",
)
source = VASP_PAW_SF.VASPWavefunctionSource(
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
VASP_PAW_IO.write_wannier_mmn(
    topology,
    VASP_PAW_IO.WannierMMN(
        2,
        2,
        1,
        zeros(ComplexF64, 2, 2, 1, 2),
        reshape([1, 2], 1, 2),
        zeros(Int, 3, 1, 2),
    ),
)
win = joinpath(root, "model.win")
write(
    win,
    "num_wann=2\nspinors=true\nmp_grid=2 1 1\nbegin unit_cell_cart\n5 0 0\n0 5 0\n0 0 5\nend unit_cell_cart\nbegin atoms_frac\nX 0 0 0\nend atoms_frac\nbegin kpoints\n0 0 0\n0.5 0 0\nend kpoints\nbegin projections\nX:s\nend projections\n",
)
basis = WannierNLQG.WannierProjection.build_wannier_projection_basis(win)
Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)===nothing ||
    error("VASP_MATRIX_BACKEND_PREACTIVATED")
generated = VASP_PAW_W.generate_vasp_paw_matrix_elements(
    source,
    basis,
    topology;
    output_mmn_file = joinpath(root, "generated.mmn"),
    output_amn_file = joinpath(root, "generated.amn"),
    provenance_hdf5 = joinpath(root, "generated.h5"),
    require_oracle = false,
)
@test generated.passed
@test Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).WorkflowOrchestration.build_wannier_projection_basis ===
      WannierNLQG.WannierProjection.build_wannier_projection_basis
@test isfile(joinpath(root, "generated.h5"))
@test maximum(abs, VASP_PAW_IO.read_wannier_mmn(joinpath(root, "generated.mmn")).data) > 0
@test maximum(abs, VASP_PAW_IO.read_wannier_amn(joinpath(root, "generated.amn")).data) > 0
mmn=VASP_PAW_IO.read_wannier_mmn(joinpath(root, "generated.mmn"))
amn=VASP_PAW_IO.read_wannier_amn(joinpath(root, "generated.amn"))
write(
    joinpath(dirname(Main.RECEIPT), "native_vasp_matrix_bits.json"),
    JSON3.write((
        mmn_shape = size(mmn.data),
        mmn_bits = bytes2hex(reinterpret(UInt8, vec(mmn.data))),
        amn_shape = size(amn.data),
        amn_bits = bytes2hex(reinterpret(UInt8, vec(amn.data))),
        mmn_finite = all(isfinite, mmn.data),
        amn_finite = all(isfinite, amn.data),
    )),
)
native=Main.FirstUseExpertProbe.native_writer_readback(
    :write_band_representation_hdf5,
    joinpath(root, "generated.h5"),
)
write(joinpath(dirname(Main.RECEIPT), "native_vasp_matrix_provenance.json"), JSON3.write(native))
