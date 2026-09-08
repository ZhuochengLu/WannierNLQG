using SHA
using WannierNLQG

include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
using .QEPAWMatrixElementsTestSupport

const PROBE_W = WannierNLQG.Wannierization
const PROBE_IO = WannierNLQG.IO
const PROBE_S = WannierNLQG.Symmetrization

mktempdir() do directory
    fixture = write_qe_paw_fixture(
        directory;
        metric_kind = :paw,
        spinor = true,
        spinorbit = true,
        num_kpoints = 3,
    )
    source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
        fixture.save_directory;
        include_time_reversal = false,
    )
    eig_file = joinpath(directory, "fixture.eig")
    PROBE_IO.write_wannier_eig(eig_file, PROBE_IO.WannierEIG(1, 3, reshape([1.0, 2.0, 3.0], 1, 3)))
    spn_file = joinpath(directory, "fixture.spn")
    spn = PROBE_W.generate_qe_paw_spn(
        source,
        fixture.nnkp_file;
        output_spn_file = spn_file,
        provenance_json = spn_file * ".json",
        max_cached_wavefunction_kpoints = 2,
    )
    spn.passed || error("QE SPN generation failed")
    output_paths = String[spn_file]
    for (suffix, generator, needs_spn) in (
        ("uHu", PROBE_W.generate_wannier_uhu, false),
        ("sHu", PROBE_W.generate_wannier_shu, true),
        ("sIu", PROBE_W.generate_wannier_siu, true),
    )
        output = joinpath(directory, "fixture.$(suffix)")
        config = PROBE_W.WannierHamiltonianOperatorGenerationConfig(
            source = source,
            topology_file = fixture.nnkp_file,
            eig_file = eig_file,
            output_file = output,
            spn_file = needs_spn ? spn_file : nothing,
            spn_provenance_file = needs_spn ? spn.provenance_json : nothing,
            max_cached_wavefunction_kpoints = 2,
        )
        result = generator(config)
        result.passed || error("$(suffix) generation failed")
        push!(output_paths, output)
    end
    digest_buffer = IOBuffer()
    for path in output_paths
        write(digest_buffer, basename(path), '=', bytes2hex(SHA.sha256(read(path))), '\n')
    end
    println("WANNIER_HAMILTONIAN_OPERATOR_DIGEST=" * bytes2hex(SHA.sha256(take!(digest_buffer))))
end
