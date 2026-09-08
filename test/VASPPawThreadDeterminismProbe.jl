using EzXML
using HDF5
using JSON3
using LinearAlgebra
using SHA
using Spglib
using WannierNLQG

parent_extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
extension = parent_extension.PAWMatrixElements
preparation = parent_extension.RepresentationPreparation
extension === nothing && error("wannierization extension did not load")

radial_grid = [0.1, 0.2, 0.4, 0.8, 1.6]
pseudo_wave = [0.10, 0.18, 0.24, 0.16, 0.02]
all_electron_wave = [0.12, 0.20, 0.27, 0.17, 0.02]
reciprocal_grid = collect(-1:99) .* 20.0 ./ 100.0
reciprocal_values = exp.(-0.03 .* reciprocal_grid .^ 2)
spline = preparation._paw_cubic_spline(reciprocal_grid, reciprocal_values)
dataset = extension.VASPPawDataset(
    "X",
    radial_grid,
    [pseudo_wave],
    [all_electron_wave],
    [reciprocal_values],
    [spline],
    [copy(pseudo_wave)],
    [0],
    reshape([0.05], 1, 1),
    20.0,
)
channel = extension.VASPPawChannel(1, 0, 1)
atom = extension.VASPPawAtomLayout("X", (0.2, 0.0, 0.0), 1:1, [channel])
paw = extension.VASPPawSystem(Dict("X" => dataset), ["X"], [atom], 1, reshape([0.05], 1, 1), 1.0)
structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
    Matrix{Float64}(I, 3, 3),
    ["X"],
    reshape([0.2, 0.0, 0.0], 3, 1),
)
g_vectors = [-1 0 0; 0 0 0; 1 0 0]
coefficients_one = reshape(
    ComplexF64[
        0.30 + 0.10im,
        0.50 - 0.20im,
        0.40 + 0.30im,
        -0.20 + 0.40im,
        0.60 + 0.10im,
        0.10 - 0.50im,
    ],
    2,
    3,
    1,
)
coefficients_two = coefficients_one .* cis(0.17)
points = [
    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint(
        [0.0, 0.0, 0.0],
        g_vectors,
        coefficients_one,
        [-1.0, 1.0];
        normalize_coefficients = false,
    ),
    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint(
        [0.5, 0.0, 0.0],
        g_vectors,
        coefficients_two,
        [-0.8, 1.2];
        normalize_coefficients = false,
    ),
]
native = WannierNLQG.SymmetryFoundation.NativeWavefunctionData(
    :vasp,
    structure,
    2.0pi .* Matrix{Float64}(I, 3, 3),
    (2, 1, 1),
    false,
    points,
    Dict("fixture" => repeat("0", 64)),
    Dict("coefficient_normalization" => "vasp_raw"),
)
projectors = extension._paw_projectors(native, paw)
topology = WannierNLQG.IO.WannierMMNTopology(2, 2, 1, reshape([2, 1], 1, 2), zeros(Int, 3, 1, 2))
mmn, _ = extension._paw_generate_mmn(native, paw, projectors, topology)
block = WannierNLQG.WannierProjection.WannierProjectionBlock(
    "X",
    "s",
    reshape([0.7, 0.0, 0.0], 3, 1),
    reshape([1], 1, 1),
    reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
    false,
)
basis = WannierNLQG.WannierProjection.WannierProjectionBasis([block], 1, false)
entry = extension.VASPProjectionEntry(
    1,
    0,
    1,
    inv(extension.VASP_PROJECTION_BOHR_ANGSTROM),
    (-0.3, 0.0, 0.0),
    (-1, 0, 0),
    (1.0, 0.0, 0.0),
    (0.0, 0.0, 1.0),
    1,
    (0.0, 0.0, 1.0),
    1,
)
contract = extension.VASPProjectionContract(v"6.3.0", 150.0, :vasp_log_simpson_spline, [entry])
integrated_metric = extension._paw_integrated_q0_metric(paw)
amn, _, normalization = extension._paw_generate_amn(
    native,
    paw,
    projectors,
    basis,
    contract;
    use_wrapped_centers = true,
    rotate_trial_spinors = true,
    normalize_trials = true,
    radial_backend = :vasp_compatible,
    trial_metric = integrated_metric,
    augmentation_metric = integrated_metric,
)
kpoints_fractional = reduce(vcat, (transpose(point.k_fractional) for point in native.kpoints))
solver_amn, gauge_diagnostics =
    extension._canonicalize_vasp_amn_for_wannierization(amn, kpoints_fractional, basis, contract)

buffer = IOBuffer()
for values in (projectors..., mmn.data, amn.data, solver_amn.data, normalization.factors)
    write(buffer, join(size(values), "x"), '\n')
    write(buffer, reinterpret(UInt8, vec(values)))
end
write(
    buffer,
    reinterpret(
        UInt8,
        [
            gauge_diagnostics.maximum_unitarity_residual,
            gauge_diagnostics.maximum_roundtrip_absolute,
            gauge_diagnostics.maximum_projector_absolute,
            gauge_diagnostics.maximum_raw_solver_absolute,
        ],
    ),
)
println(bytes2hex(SHA.sha256(take!(buffer))))
