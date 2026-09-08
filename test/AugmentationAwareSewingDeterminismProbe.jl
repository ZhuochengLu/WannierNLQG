using LinearAlgebra
using SHA
using WannierNLQG

include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
using .QEPAWMatrixElementsTestSupport

const W = WannierNLQG.Wannierization
const S = WannierNLQG.Symmetrization

parent_extension = first(W._load_wannierization_extension!())
paw = parent_extension.PAWMatrixElements
preparation = parent_extension.RepresentationPreparation
mktempdir() do directory
    fixture = write_qe_paw_fixture(directory; metric_kind = :paw, spinor = true, spinorbit = true)
    source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
        fixture.save_directory;
        include_time_reversal = false,
    )
    native = Base.invokelatest(paw._read_augmentation_aware_native_source, source)
    identity = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    representation = Base.invokelatest(
        preparation._build_band_representation,
        native,
        reshape(copy(only(native.kpoints).energies_ev), 1, 1),
        [identity],
        1.0e-8;
        source,
        sewing_backend = W.AugmentationAwareSewing(),
        diagnostic_outer_masks = [trues(1)],
        diagnostic_frozen_masks = [trues(1)],
    )
    buffer = IOBuffer()
    write(buffer, reinterpret(UInt8, vec(representation.sewing_matrices)))
    for key in sort!(collect(keys(representation.conventions)))
        startswith(key, "strict_") ||
            startswith(key, "raw_") ||
            key in ("sewing_backend", "sewing_metric", "augmentation_backend") ||
            continue
        write(buffer, key, '\0', representation.conventions[key], '\n')
    end
    println("AUGMENTATION_AWARE_SEWING_DIGEST=" * bytes2hex(SHA.sha256(take!(buffer))))
end
