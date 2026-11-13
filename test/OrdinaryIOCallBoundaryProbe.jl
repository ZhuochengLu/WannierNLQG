# Execute only in a fresh process: audit spies must never alter the parent suite.
using Test, LinearAlgebra, WannierNLQG
BLAS.set_num_threads(1)
include(joinpath(@__DIR__, "SpectralResponseTestSupport.jl"))
const ORDINARY_TREE_AUDIT_CALLS = Ref(0)
@eval WannierNLQG.IO begin
    function release_tree_sha256()
        $(ORDINARY_TREE_AUDIT_CALLS)[] += 1
        error("ORDINARY_PATH_CALLED_RELEASE_TREE_AUDIT")
    end
    function spectral_response_source_digest()
        $(ORDINARY_TREE_AUDIT_CALLS)[] += 1
        error("ORDINARY_PATH_CALLED_SOURCE_TREE_AUDIT")
    end
end
@testset "Ordinary IO call boundary without installed-tree auditing" begin
    mktempdir() do directory
        model=joinpath(directory, "finite_model.dat")
        WannierNLQG.IO.write_wannier_tb(model, spectral_test_model())
        band=TaskConfig(
            model = ModelInput(model_file = model),
            sampling = KPath(
                nodes = [("G", (0.0, 0.0, 0.0)), ("X", (0.2, 0.0, 0.0))],
                kpoints_per_segment = [3],
            ),
            execution = ExecutionOptions(fourier_backend = "Direct"),
            output = OutputOptions(
                output_root = joinpath(directory, "band"),
                progress_enabled = false,
            ),
            tasks = [
                TaskSpec(
                    id = "band",
                    quantity = "Band",
                    physics = BandParameters(fermi_energy = 0.0),
                ),
            ],
        )
        band_result=WannierNLQG.run(band)
        @test !isempty(band_result.outputs)
        @test band_result.qualification.qualification_status == "COMPUTATION_READY"
        rates=SeparateRelaxation(gamma_intra_ev = 0.04, gamma_inter_ev = 0.05)
        for quantity in ("linear_transport", "orbital_magnetization")
            physics=quantity=="linear_transport" ?
                    LinearTransportParameters(
                fermi_energies = [0.13],
                temperature = 300.0,
                relaxation = rates,
            ) :
                    OrbitalMagnetizationParameters(
                fermi_energies = [0.13],
                temperature = 300.0,
                input_semantics = :defined_finite_model,
            )
            config=TaskConfig(
                model = ModelInput(model_file = model),
                sampling = BZMesh(k_mesh = (1, 1, 1)),
                execution = ExecutionOptions(fourier_backend = "Direct"),
                output = OutputOptions(
                    output_root = joinpath(directory, quantity),
                    progress_enabled = false,
                ),
                tasks = [
                    TaskSpec(
                        id = quantity,
                        quantity = quantity,
                        method = "Conventional",
                        physics = physics,
                        observable = FullTensor(),
                    ),
                ],
            )
            result=WannierNLQG.run(config)
            @test result.qualification.execution_eligible
            @test result.qualification.qualification_status == "COMPUTATION_READY"
            @test !result.qualification.production_eligible
            @test !result.qualification.quality_review_recommended
            task_directory=only(result.task_results).run_dir
            parsed=quantity=="linear_transport" ? read_linear_transport_result(task_directory) :
                   read_orbital_magnetization_result(task_directory)
            @test parsed !== nothing
            @test all(isfile, result.outputs)
        end
        @test ORDINARY_TREE_AUDIT_CALLS[] == 0
    end
end
println("ORDINARY_IO_CALL_BOUNDARY_PASS")
