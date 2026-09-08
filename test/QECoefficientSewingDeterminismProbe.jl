using LinearAlgebra
using SHA
using WannierNLQG

include(joinpath(@__DIR__, "QECoefficientSewingTestSupport.jl"))
using .QECoefficientSewingTestSupport

const W = WannierNLQG.Wannierization
const S = WannierNLQG.Symmetrization

W._load_wannierization_extension!()
extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).RepresentationPreparation
extension === nothing && error("Wannierization extension did not load")

mktempdir() do directory
    save_directory = write_qe_coefficient_sewing_fixture(directory, :paw)
    source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
        save_directory;
        band_range = 1:1,
        include_time_reversal = false,
    )
    native =
        Base.invokelatest(extension._read_qe_wavefunctions, source; purpose = :band_representation)
    operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    energies = reshape(copy(only(native.kpoints).energies_ev), 1, 1)
    representation = Base.invokelatest(
        extension._build_band_representation,
        native,
        energies,
        [operation],
        1.0e-8,
    )
    buffer = IOBuffer()
    write(buffer, reinterpret(UInt8, vec(only(native.kpoints).coefficients)))
    write(buffer, reinterpret(UInt8, vec(representation.sewing_matrices)))
    for key in sort!(collect(keys(representation.conventions)))
        write(buffer, key, '\0', representation.conventions[key], '\n')
    end
    println("QE_PAW_COEFFICIENT_SEWING_DIGEST=" * bytes2hex(SHA.sha256(take!(buffer))))
end
