using WannierNLQG, LinearAlgebra, MPI, JSON3, Test
include(joinpath(@__DIR__, "TestCountCompatibilitySupport.jl"))
BLAS.set_num_threads(1)
output, case=ARGS
MPI.Initialized() || MPI.Init()
rank=MPI.Comm_rank(MPI.COMM_WORLD)
ranks=MPI.Comm_size(MPI.COMM_WORLD)

function multipole_input(; crossing = false)
    sx=ComplexF64[0 1; 1 0];
    sy=ComplexF64[0 -im; im 0];
    sz=ComplexF64[1 0; 0 -1]
    ident=Matrix{ComplexF64}(I, 2, 2)
    vectors=[0 1 -1 0 0; 0 0 0 1 -1; 0 0 0 0 0]
    h=zeros(ComplexF64, 2, 2, 5)
    if crossing
        h[:, :, 2]=sx/(2im);
        h[:, :, 3]=h[:, :, 2]'
        h[:, :, 4]=sy/(2im);
        h[:, :, 5]=h[:, :, 4]'
    else
        h[:, :, 1]=1.3sz
        h[:, :, 2]=0.15sz+(sx+0.2ident)/(2im);
        h[:, :, 3]=h[:, :, 2]'
        h[:, :, 4]=0.1sz+0.05ident+sy/(2im);
        h[:, :, 5]=h[:, :, 4]'
    end
    RealSpaceTBInput(
        lattice = Matrix{Float64}(I, 3, 3),
        r_vectors = vectors,
        hamiltonian_r = h,
        orbital_positions = zeros(3, 2),
        source_file = @__FILE__
    )
end
function multipole_config(destination, mesh; crossing = false)
    tasks=TaskSpec[]
    for (quantity, component) in
        (("BCDC", TensorComponent(2, 1, 1)), ("BCQC", TensorComponent(2, 1, 1, 1))),
        form in (:fermi_surface, :fermi_sea)

        push!(
            tasks,
            TaskSpec(
                id = lowercase(quantity)*"_"*String(form),
                quantity = quantity,
                method = "Conventional",
                physics = BerryMultipoleParameters(
                    fermi_energies = [-1.2, 0.1],
                    temperature = 800.0,
                    relaxation_time_fs = 7.0,
                    integral_form = form,
                ),
                observable = TensorComponents(component),
            ),
        )
    end
    TaskConfig(
        model = multipole_input(; crossing),
        sampling = BZMesh(k_mesh = mesh, spatial_dimension = 3),
        tasks = tasks,
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(
            output_root = destination,
            progress_enabled = false,
            response_output_digits = 16,
        ),
    )
end

probe_tests=@testset "actual rank lifecycle and complete four-task execution" begin
    @test 0<=rank<ranks
    @test BLAS.get_num_threads()==1
    if case=="success"
        for mesh in ((1, 1), (3, 3))
            # One point gives truly empty owners for ranks 2/3. Nine points
            # exercise multiple deterministic lanes and threaded worker slots.
            destination=joinpath(output, "mesh_"*join(mesh, "x"))
            result=WannierNLQG.run(multipole_config(destination, mesh))
            if rank==0
                @test length(filter(p->endswith(p, "_moments.dat"), result.outputs))==4
                @test length(filter(p->endswith(p, "_conductivity.dat"), result.outputs))==4
            end
        end
    elseif case=="spectral_failure"
        failure=nothing
        try
            WannierNLQG.run(multipole_config(joinpath(output, "rejected"), (3, 3); crossing = true))
        catch exception
            failure=sprint(showerror, exception)
        end
        @test failure!==nothing
        @test occursin("GEOMETRY_SINGLE_BAND_SPECTRUM_NOT_ISOLATED", something(failure, ""))
    else
        error("unknown multipole parallel probe case")
    end
end
MPI.Barrier(MPI.COMM_WORLD)
counts=test_result_totals(probe_tests)
MPI.Barrier(MPI.COMM_WORLD)
MPI.Finalize()
open(joinpath(output, "rank_$(rank).json"), "w") do io
    write(
        io,
        JSON3.write((;
            rank,
            ranks,
            threads = Threads.nthreads(),
            case,
            completed = true,
            mpi_finalized = MPI.Finalized(),
            passed = counts.passed,
            failed = counts.failed,
            errored = counts.errored,
            broken = counts.broken,
        )),
    )
end
