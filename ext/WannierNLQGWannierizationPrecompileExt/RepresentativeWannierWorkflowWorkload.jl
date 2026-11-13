using LinearAlgebra
import WannierNLQG, MPI

# Two variants of one two-band, two-k-point public workflow cover preparation, the solver,
# checkpoint persistence and tight-binding construction. Schema 1.4 enters the
# current representation contract, matching real public preparation inputs. It exercises actual
# Wannierization with eight iterations, deterministic initialization and no
# physical convergence requirement. The second enters an actual nonzero U update.
# Explicit maintenance execution invokes this helper after sibling activation.
# No serialized types or implementation
# signatures are maintained here. All files belong to the temporary directory.
include("../WannierNLQGWannierizationExt/PrecompileSupport/TinyWannierWorkflowInputs.jl")

# Execute the unchanged representative workflow only after sibling extensions are loaded.
function capture_wannier_workflow()
    @assert Base.get_extension(WannierNLQG, :WannierNLQGWannierizationPrecompileExt) === @__MODULE__
    # Keep the capture macro at top level: placing it in an anonymous tempfile
    # callback can leave runtime-dispatched callees outside its inference capture.
    root = mktempdir()
    try
        begin
            for localize in (false, true)
                directory = mkpath(joinpath(root, string(localize)))
                configs = tiny_wannier_workflow(directory; localize)
                WannierNLQG._first_use_require_serial()
                w = WannierNLQG.Wannierization
                sf = WannierNLQG.SymmetryFoundation
                prepared = w.prepare_band_representation(configs.prepare)
                @assert prepared.status in (:PASS, :PASS_WITH_WARNINGS)
                restored_representation = sf.read_band_representation_hdf5(
                    configs.representation_file;
                    content_authentication = false,
                )
                @assert all(isfinite, restored_representation.sewing_matrices)
                sf.build_band_product_table(
                    restored_representation.operations,
                    restored_representation.spinor,
                )
                solved = WannierNLQG.Runtime.run_wannier_application(configs.solve)
                @assert solved.status in (w.COMPLETED, w.COMPLETED_WITH_WARNINGS, w.MAX_ITERATIONS)
                if localize
                    @assert any(
                        h -> h.diagnostics !== nothing && h.diagnostics.u_inner_sweeps > 0,
                        solved.history,
                    )
                    @assert any(
                        h ->
                            h.diagnostics !== nothing &&
                            h.diagnostics.accepted_u_step_scale > 0 &&
                            (
                                !hasproperty(h.diagnostics, :u_residual) ||
                                h.diagnostics.u_residual > 0
                            ),
                        solved.history,
                    )
                end
                @assert !any(diagnostic -> diagnostic.code == :TB_EXPORT_FAILED, solved.diagnostics) repr([
                    (code = d.code, message = d.message, context = d.context) for
                    d in solved.diagnostics
                ])
                @assert solved.artifacts.packed_hdf5 !== nothing &&
                        isfile(solved.artifacts.packed_hdf5)
                @assert solved.artifacts.model_tb !== nothing && isfile(solved.artifacts.model_tb)
                model = w.build_wannier_tight_binding_model(
                    solved,
                    WannierNLQG.IO.read_wannier_eig(configs.eig),
                    WannierNLQG.IO.read_wannier_mmn(configs.mmn),
                )
                @assert all(isfinite, model.hamiltonian_r) && all(isfinite, model.position_r)
                restored = w.read_wannierization_checkpoint_hdf5(configs.checkpoint)
                @assert isequal(restored.v_matrix, solved.v_matrix)
                @assert all(isfinite, solved.v_matrix)
                if localize
                    # The diagnostic enters independent direct/MP/Wigner-Seitz
                    # Fourier reconstruction and versioned evidence writers. Reuse
                    # this actual accepted checkpoint; do not rerun a third solver.
                    diagnosis = w.diagnose_wannier_gauge_chain(
                        w.WannierGaugeChainDiagnosticConfig(
                            wannierization_checkpoint_hdf5 = configs.checkpoint,
                            eig_file = configs.eig,
                            mmn_file = configs.mmn,
                            band_representation_hdf5 = configs.representation_file,
                            output_json = joinpath(directory, "gauge-chain.json"),
                            output_hdf5 = joinpath(directory, "gauge-chain.h5"),
                        ),
                    )
                    @assert diagnosis.status === :PASS_DIAGNOSTIC
                    @assert diagnosis.summary["input_identity"] == "PASS"
                    @assert isfile(diagnosis.output_json) && isfile(diagnosis.output_hdf5)
                end
                @assert !MPI.Initialized()
                @assert WannierNLQG.Runtime.ACTIVE_PROGRESS[] === nothing
            end
        end
    finally
        rm(root; recursive = true)
    end
end
