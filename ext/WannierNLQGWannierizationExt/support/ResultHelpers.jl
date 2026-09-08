"""Rebuild a Wannierization result while preserving every unspecified field."""
function updated_wannierization_result(
    result::WannierizationResult;
    status = result.status,
    diagnostics = result.diagnostics,
    input_summary = result.input_summary,
    checkpoint_file = result.checkpoint_file,
    restart_state = result.restart_state,
    artifacts = result.artifacts,
    initialization_report = result.initialization_report,
    tb_symmetry_qualification = result.tb_symmetry_qualification,
)
    return WannierizationResult(
        status,
        result.v_matrix,
        result.wannier_centers_cartesian,
        result.spreads_angstrom2,
        result.history,
        WannierizationDiagnostic[diagnostics...],
        Dict{String, String}(input_summary),
        result.wannier_chk,
        checkpoint_file,
        restart_state,
        artifacts,
        initialization_report,
        tb_symmetry_qualification,
    )
end
