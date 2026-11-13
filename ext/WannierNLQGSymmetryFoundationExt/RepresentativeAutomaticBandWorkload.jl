using PrecompileTools: @setup_workload, @compile_workload
import TOML
import MPI

# Text resolution, automatic 3D/plane geometry and the real spectrum driver
# share two tiny deterministic inputs. This three-trigger owner is activated
# by the normal automatic Band entrance; no EzXML or MPI initialization is needed.
@setup_workload let
    @assert !MPI.Initialized()
    mktempdir() do directory
        hamiltonian = zeros(ComplexF64, 2, 2, 3)
        hamiltonian[:, :, 1] = [0.2 0.1; 0.1 -0.2]
        hamiltonian[:, :, 2] = [0.3 0.0; 0.0 -0.15]
        hamiltonian[:, :, 3] = hamiltonian[:, :, 2]'
        model = WannierNLQG.Core.TightBindingModel(
            10.0 * Matrix{Float64}(I, 3, 3),
            2,
            3,
            ones(Int, 3),
            [0 1 -1; 0 0 0; 0 0 0],
            hamiltonian,
            zeros(ComplexF64, 2, 2, 3, 3),
        )
        model_file = joinpath(directory, "hermitian_tb.dat")
        WannierNLQG.IO.write_wannier_tb(model_file, model)
        inputs = String[]
        for dimension in (3, 2)
            sampling = Dict{String, Any}(
                "spatial_dimension" => dimension,
                "structure" => Dict(
                    "lattice_angstrom" =>
                        [[10.0, 0.0, 0.0], [0.0, 10.0, 0.0], [0.0, 0.0, 10.0]],
                    "species" => ["X"],
                    "positions_fractional" => [[0.0, 0.0, 0.0]],
                ),
            )
            # One supplied-count case and one default-density case enter distinct
            # config specializations; the synthetic large cell keeps both tiny.
            dimension == 3 && (sampling["kpoints_per_segment"] = 2)
            dimension == 2 && (sampling["periodic_axes"] = [1, 2])
            document = Dict(
                "model" => Dict(
                    "source" => "wannier",
                    "model_file" => model_file,
                    "real_space_replica_policy" => "input",
                ),
                "response" => Dict(
                    "energy_zero" => "synthetic model Hamiltonian reference",
                    "fermi_energy_ev" => 0.0,
                    "sampling" => sampling,
                    "execution" => Dict("fourier_backend" => "direct"),
                    "tasks" => Dict("bands" => Dict("kind" => "Band")),
                ),
                "output" => Dict(
                    "output_root" => joinpath(directory, "output$(dimension)"),
                    "progress_enabled" => false,
                ),
            )
            input = joinpath(directory, "bands$(dimension).toml")
            open(stream -> TOML.print(stream, document), input, "w")
            push!(inputs, input)
        end
        @compile_workload begin
            for (index, input) in enumerate(inputs)
                resolved = WannierNLQG.read_task_input(input)
                @assert isempty(resolved.pending)
                result = WannierNLQG.run_task_input(
                    resolved;
                    record_directory = joinpath(directory, "records$(index)"),
                )
                @assert length(result.outputs) == 2 && all(isfile, result.outputs)
            end
            @assert !MPI.Initialized()
        end
    end
end
