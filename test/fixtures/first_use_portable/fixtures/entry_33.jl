using LinearAlgebra
using SHA
using Test
include(Main.FirstUsePortableSupport.input("fixtures/support_5.jl"))

const VASP_SPN_W = WannierNLQG.Wannierization
const VASP_SPN_IO = WannierNLQG.IO

mktempdir() do directory
    poscar, wavecar, _ = write_bounded_vasp_fixture(directory, 2, ComplexF64)
    # Replace the bounded fixture's intentionally unnormalized coefficients
    # with two orthonormal spinors at each k point. Keep actual WAVECAR records.
    open(wavecar, "r+") do io
        for kpoint in 1:2
            ng = kpoint
            header_record = 2 + (kpoint - 1) * 3
            for band in 1:2
                coefficients = zeros(ComplexF64, 2 * ng)
                coefficients[band == 1 ? 1 : ng + 1] = 1.0
                seek(io, 512 * (header_record + band))
                write(io, coefficients)
            end
        end
    end
    potcar = joinpath(directory, "POTCAR")
    # Match the synthetic POTCAR q=0 augmentation to its own radial wavefunctions.
    # The previous arbitrary q0 failed the unchanged strict radial audit.
    write(potcar, synthetic_potcar_block("X"; q0 = 0.0))
    # Exact Float64 radial integral frozen by an independent real PAW preparation.
    # No backend is activated to build this cold-public-entry fixture.
    q0_consistent = reinterpret(Float64, UInt64(0x3f66f0af75511c09))
    q0_consistent > 0 || error("frozen radial augmentation is zero")
    write(potcar, synthetic_potcar_block("X"; q0 = q0_consistent))
    source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
        poscar,
        wavecar;
        potcar_file = potcar,
        band_range = 1:2,
        spinor = true,
        spin_basis_saxis = (0.0, 0.0, 1.0),
        include_time_reversal = false,
    )
    output = joinpath(directory, "native.spn")
    provenance = joinpath(directory, "native.spn.h5")
    result = VASP_SPN_W.generate_vasp_paw_spn(
        source;
        output_spn_file = output,
        provenance_hdf5 = provenance,
        spin_channel = 1,
        execution = VASP_SPN_W.WavefunctionPreparationExecutionConfig(
            mode = :streaming_threads,
            max_workers = 1,
            checkpoint_directory = joinpath(directory, "checkpoint"),
        ),
    )
    data = VASP_SPN_IO.read_wannier_spn(output).data
    @test result.passed
    @test result.radial_q_max_absolute <= 5.0e-7
    @test result.component_norms["augmentation_max_absolute"] > 0
    @test isfile(provenance)
    @test size(data) == (2, 2, 3, 2)
    @test maximum(abs, data) > 0
    @test all(isfinite, data)
    write(
        joinpath(dirname(Main.RECEIPT), "native_vasp_spn_bits.json"),
        JSON3.write((
            shape = size(data),
            bits = bytes2hex(reinterpret(UInt8, vec(data))),
            finite = all(isfinite, data),
            max_abs = maximum(abs, data),
        )),
    )
    cp(output, joinpath(dirname(Main.RECEIPT), "actual_native_generated.spn"); force = false)
    native=Main.FirstUseExpertProbe.native_writer_readback(
        :write_band_representation_hdf5,
        provenance,
    )
    write(joinpath(dirname(Main.RECEIPT), "native_vasp_spn_provenance.json"), JSON3.write(native))
    println("VASP_SPN_VALID_DIGEST ", bytes2hex(SHA.sha256(reinterpret(UInt8, vec(data)))))
end
