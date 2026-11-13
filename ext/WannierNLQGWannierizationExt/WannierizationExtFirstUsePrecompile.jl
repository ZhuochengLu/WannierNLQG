using PrecompileTools: @compile_workload
import WannierNLQG
import HDF5
const FIRST_USE_HDF5_MPI_PRESENT = Base.get_extension(HDF5, :MPIExt) !== nothing

# Compile expert entry signatures without executing file writes or MPI initialization.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        # Solver and preparation are first inferred by the real five-trigger
        # public workload. Pre-inference here can hide runtime-dispatched
        # external callees from PrecompileTools' inference capture.
        # First successful expert calls in the frozen two-k-point fixtures:
        # generate_qe_paw_spn and prepare_full_uiu_derivative_operator_bundle.
        # Compile only; neither native operator nor provenance file is written.
        # Public QE kwcall is covered by the actual two-k-point workload.
        precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :output_spn_file,
                        :provenance_json,
                        :oracle_spn_file,
                        :thresholds,
                        :require_oracle,
                        :formatted,
                        :overwrite,
                        :max_cached_wavefunction_kpoints,
                        :execution,
                    ),
                    Tuple{
                        String,
                        String,
                        Nothing,
                        WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                    },
                },
                typeof(PAWMatrixElements.generate_qe_paw_spn),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                String,
            },
        )
        precompile(
            WannierNLQG.Wannierization.prepare_full_uiu_derivative_operator_bundle,
            (WannierNLQG.Wannierization.FullUIUDerivativeOperatorBundleConfig,),
        )
        precompile(
            OperatorExport.prepare_full_uiu_derivative_operator_bundle,
            (WannierNLQG.Wannierization.FullUIUDerivativeOperatorBundleConfig,),
        )
    end
end

# Portable signatures above use the current public interfaces.
# Historical compiler captures below await same-source 1.2 qualification.
