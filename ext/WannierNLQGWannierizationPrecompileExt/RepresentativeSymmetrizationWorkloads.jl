import WannierNLQG, MPI
const SYMMETRIZATION_API = WannierNLQG.Symmetrization

# These public workflows have distinct validation/projection call trees. Their
# canonical public facades are available in this existing composite cache owner.
# The external capture verifies the required sibling extensions before invocation.
# Execute the unchanged representative workflow only after sibling extensions are loaded.
function capture_symmetrization_workflows()
    assets =
        normpath(joinpath(@__DIR__, "..", "..", "test", "fixtures", "first_use_portable", "assets"))
    mktempdir() do output
        mesh = SYMMETRIZATION_API.MeshScreenConfig(
            win_file = joinpath(assets, "group_15", "model.win"),
            density_target = 1.0,
            search_radius = 0,
        )
        operators = SYMMETRIZATION_API.SymmetrizationConfig(
            win_file = joinpath(assets, "additional_43", "synthetic.win"),
            tb_file = joinpath(assets, "additional_44", "synthetic_tb.dat"),
            output_tb_file = joinpath(output, "sym_tb.dat"),
            output_real_space_operator_bundle_file = joinpath(output, "operators.h5"),
            report_json_file = joinpath(output, "operators.json"),
            real_space_replica_policy = :input,
            overwrite = true,
        )
        begin
            WannierNLQG._first_use_require_serial()
            @assert SYMMETRIZATION_API.screen_wannier_mesh(mesh).selected_operation_count > 0
            result = SYMMETRIZATION_API.symmetrize_wannier_operators(operators)
            @assert all(
                isfile,
                (result.output_tb, result.real_space_operator_bundle, result.report_json),
            )
            @assert !MPI.Initialized()
            @assert WannierNLQG.Runtime.ACTIVE_PROGRESS[] === nothing
        end
    end
end
