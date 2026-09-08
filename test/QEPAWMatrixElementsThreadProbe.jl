using WannierNLQG
using SHA

include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
using .QEPAWMatrixElementsTestSupport

const W = WannierNLQG.Wannierization
const S = WannierNLQG.Symmetrization
const IO_API = WannierNLQG.IO

mktempdir() do directory
    digest_buffer = IOBuffer()
    for lane in qe_paw_fixture_lanes()
        lane_directory = joinpath(directory, lane.label)
        fixture = write_qe_paw_fixture(
            lane_directory;
            metric_kind = lane.metric_kind,
            spinor = lane.spinor,
            spinorbit = lane.spinorbit,
        )
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            include_time_reversal = false,
        )
        diagnostic = W.generate_qe_paw_matrix_elements(
            source,
            fixture.nnkp_file;
            artifact_dir = joinpath(lane_directory, "diagnostic"),
            require_oracle = false,
        )
        diagnostic.passed || error("$(lane.label) diagnostic construction failed")
        oracle = copy_qe_paw_oracles(diagnostic, joinpath(lane_directory, "oracle"))
        write_qe_paw_oracle_provenance(dirname(oracle.mmn), diagnostic.input_sha256)
        qualified = W.generate_qe_paw_matrix_elements(
            source,
            fixture.nnkp_file;
            artifact_dir = joinpath(lane_directory, "qualified"),
            oracle_mmn_file = oracle.mmn,
            oracle_amn_file = oracle.amn,
        )
        qualified.passed || error("$(lane.label) oracle qualification failed")
        IO_API.read_wannier_mmn(qualified.artifacts["mmn"]).data == qualified.mmn.data ||
            error("$(lane.label) fresh-process MMN readback differs")
        IO_API.read_wannier_amn(qualified.artifacts["amn"]).data == qualified.amn.data ||
            error("$(lane.label) fresh-process AMN readback differs")
        write(digest_buffer, lane.label, '=', qe_paw_output_digest(qualified), '\n')
    end
    println("QE_PAW_MATRIX_DIGEST=" * bytes2hex(SHA.sha256(take!(digest_buffer))))
end
