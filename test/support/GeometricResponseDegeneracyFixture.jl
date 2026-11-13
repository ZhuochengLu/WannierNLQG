# Targeted Geometric SC/PDSC averaging contract in the actual eigenframe.
using Test, LinearAlgebra, WannierNLQG, TOML
const DG_ME = WannierNLQG.MatrixElements
const DG_RESP = WannierNLQG.Responses
const DG_RUNTIME = WannierNLQG.Runtime

@testset "Geometric response threshold and split-level weights" begin
    ws = DG_RESP.make_geometric_loop_response_workspace(4, 0, 2, 1)
    v, c = ws.valence_central_data, ws.conduction_central_data
    energies = [0.0, 0.0625, 0.125, 1.0]
    v.spectrum.energies .= energies
    DG_ME.mark_geometric_response_groups!(v, 0.09375)
    @test v.degeneracy_group_starts == [1, 1, 1, 4]
    @test v.degeneracy_group_stops == [3, 3, 3, 4]
    @test v.degeneracy_weights == [1/3, 1/3, 1/3, 1.0]
    @test v.spectrum.energies == energies
    DG_ME.mark_geometric_response_groups!(v, 0.0625)
    @test v.degeneracy_group_starts == [1, 2, 3, 4]
    DG_ME.mark_geometric_response_groups!(v, nextfloat(0.0625))
    @test v.degeneracy_group_starts == [1, 1, 1, 4]
    DG_ME.mark_geometric_response_groups!(v, prevfloat(0.0625))
    @test v.degeneracy_group_starts == [1, 2, 3, 4]
    v.spectrum.energies .= [0.0, 0.0, 1.0, 1.0]
    DG_ME.mark_geometric_response_groups!(v, 0.0)
    @test v.degeneracy_group_starts == [1, 1, 3, 3]
    @test v.degeneracy_weights == fill(0.5, 4)
    for bad in (-1.0, Inf, NaN)
        @test_throws ArgumentError DG_ME.mark_geometric_response_groups!(v, bad)
    end
    v.spectrum.energies .= [0.0, 1e-12, 1.0, 2.0]
    DG_ME.mark_geometric_response_groups!(v, 1e-3)
    @test v.degeneracy_group_starts == [1, 1, 3, 4]
    # A response averaging threshold does not authorize relaxing the spectral solve.
    @test_throws ErrorException DG_ME.spectral_subspace_blocks(v.spectrum.energies)
    ev = [-0.5, -0.49, 0.5, 0.52]
    ec = [-0.51, -0.485, 0.505, 0.525]
    v.spectrum.energies .= ev
    c.spectrum.energies .= ec
    DG_ME.mark_geometric_response_groups!(v, 0.04)
    DG_ME.mark_geometric_response_groups!(c, 0.04)
    @test v.degeneracy_group_starts == [1, 1, 3, 3]
    @test c.degeneracy_group_starts == [1, 1, 3, 3]
    # Operators are evaluated in the true split-level eigenframe. Do not rotate
    # unequal energies as though their Hamiltonian block were proportional to I.
    spectral = DG_ME.spectral_subspace_blocks(ev)
    @test spectral == [1:1, 2:2, 3:3, 4:4]
    vertex = reshape(ComplexF64.(1:48), 4, 4, 3)
    connection = zeros(ComplexF64, 4, 4, 3)
    DG_ME.solve_subspace_position!(connection, ev, vertex, spectral)
    @test connection[1, 2, 1] == -im * vertex[1, 2, 1] / (ev[1]-ev[2])
    @test connection[1, 2, 1] != 0
    # Independent pair-weight reference: unequal occupations and all real gaps.
    gamma, width, omega = 0.03, 0.06, 1.01
    fv, fc = [0.95, 0.73, 0.15, 0.02], [0.97, 0.78, 0.17, 0.04]
    gaps = [ec[m]-ev[n] for n in 1:4, m in 1:4]
    occupations = [fv[n]-fc[m] for n in 1:4, m in 1:4]
    weighted = similar(occupations)
    DG_RESP.photon_drag_weighted_occupations!(weighted, occupations, gaps, gamma)
    delta = exp.(-((gaps .- omega) ./ width) .^ 2) ./ (sqrt(pi)*width)
    independent = [
        occupations[n, m] *
        (gaps[n, m]/(gaps[n, m]^2+gamma^2))^2 *
        exp(-((gaps[n, m]-omega)/width)^2)/(sqrt(pi)*width) for n in 1:4, m in 1:4
    ]
    @test weighted .* delta ≈ independent atol=1e-13 rtol=1e-13
    fill!(ws.covariant_derivative_valid, true)
    for n in 1:4, m in 1:4, a in 1:2
        ws.covariant_insertion_derivatives[n, m, a] = complex(n+2m+a, n-m)
        ws.central_second_insertions[m, n, a] = complex(2n-m+a, m+n)
    end
    fill!(ws.response_kernel, 0)
    for vr in (1:2, 3:4), cr in (1:2, 3:4)
        trace_reference = sum(
            ws.covariant_insertion_derivatives[n, m, 2] * ws.central_second_insertions[m, n, 1]
            for n in vr, m in cr
        )
        normalized =
            DG_RESP.geometric_loop_covariant_block_contraction(ws, first(vr), first(cr), 1, 2)
        @test normalized ≈ trace_reference / (length(vr)*length(cr)) atol=1e-13
        for n in vr, m in cr
            ws.response_kernel[n, m, 1, 1, 2] = normalized
        end
    end
    reference = sum(
        sum(
            ws.covariant_insertion_derivatives[n, m, 2] * ws.central_second_insertions[m, n, 1]
            for n in vr, m in cr
        ) * sum(independent[n, m] for n in vr, m in cr)/(length(vr)*length(cr)) for
        vr in (1:2, 3:4), cr in (1:2, 3:4)
    )
    actual = DG_RESP.geometric_loop_sck_component(
        ws.response_kernel,
        weighted,
        delta,
        1.0,
        1.0,
        [1, 1, 2],
        4,
    )
    @test actual ≈ reference atol=1e-11 rtol=1e-13
    accumulator = zeros(ComplexF64, 1, 2, 2, 2)
    DG_RESP.accumulate_geometric_loop_shift_current_response!(
        accumulator,
        ws.response_kernel,
        reshape(weighted, 1, 4, 4),
        reshape(delta, 1, 4, 4),
        [1.0],
        1.0,
        4,
        2,
    )
    @test accumulator[1, 1, 1, 2] == actual
    # Replacing pair gaps/occupations with mean-block energies must fail this oracle.
    mean_gap = sum(ec[3:4])/2 - sum(ev[1:2])/2
    wrong_weight =
        sum(occupations[1:2, 3:4])/4 *
        (mean_gap/(mean_gap^2+gamma^2))^2 *
        exp(-((mean_gap-omega)/width)^2)/(sqrt(pi)*width)
    @test abs(wrong_weight - sum(independent[1:2, 3:4])/4) > 1e-4
    @test ev == v.spectrum.energies && ec == c.spectrum.energies
    grouped = DG_RESP.geometric_loop_covariant_block_contraction(ws, 1, 3, 1, 2)
    DG_ME.mark_geometric_response_groups!(v, 0.0)
    DG_ME.mark_geometric_response_groups!(c, 0.0)
    singleton = DG_RESP.geometric_loop_covariant_block_contraction(ws, 1, 3, 1, 2)
    @test singleton != grouped
    @test v.degeneracy_weights == ones(4)
end

# A fixed orthonormal four-level linear model with resolvable near splittings.
function geometric_degeneracy_hamiltonian(k, parameters)
    return Diagonal([-0.5, -0.49, 0.5, 0.52]) + k[1] .* parameters[1] + k[2] .* parameters[2]
end

@testset "Geometric response input paths and actual runtime grouping" begin
    dx = ComplexF64[
        0.1 0.003 0.12 0.03;
        0.003 0.2 0.04 0.08;
        0.12 0.04 0.3 0.002;
        0.03 0.08 0.002 0.4
    ]
    dy = ComplexF64[
        0.2 0.002im 0.06im 0.01;
        -0.002im 0.3 0.02 0.04im;
        -0.06im 0.02 0.4 0.003im;
        0.01 -0.04im -0.003im 0.5
    ]
    input = AnalyticKInput(
        hamiltonian = geometric_degeneracy_hamiltonian,
        parameters = (dx, dy),
        num_orbitals = 4,
        lattice = Matrix{Float64}(I, 3, 3)*2,
        basis = :fixed_orthonormal,
        periodic = false,
        derivative_method = :automatic,
        source_file = @__FILE__,
        evaluation_bounds = ((-1.0, -1.0, -1.0), (1.0, 1.0, 1.0)),
    )
    model = WannierNLQG.Core.AnalyticKModel(input)
    sampling = KRegion(
        origin = (0.0, 0.0),
        vector_1 = (0.01, 0.0),
        vector_2 = (0.0, 0.01),
        k_mesh = (1, 1),
    )
    mktempdir() do directory
        for threshold in (0.0, 0.04)
            task = TaskSpec(
                id = "pdsc",
                quantity = "PDSC",
                method = "Geometric_Loop",
                physics = FiniteQOpticalParameters(
                    photon_energies = [1.01],
                    photon_momentum = (0.0, 0.0, 0.0),
                    fermi_energy = 0.0,
                    temperature = 0.0,
                ),
                numerics = Numerics(
                    broadening = 0.06,
                    denominator_regularization = 0.03,
                    degeneracy_threshold = threshold,
                    finite_difference_step = 1e-4,
                ),
                observable = FullTensor(),
            )
            config = TaskConfig(
                model = input,
                sampling = sampling,
                tasks = [task],
                execution = ExecutionOptions(fourier_backend = "direct"),
                output = OutputOptions(output_root = directory, progress_enabled = false),
            )
            cfg = only(DG_RUNTIME.compile_task_configs(config))
            doc = Dict(
                "model"=>Dict("source"=>"julia", "identity"=>"geometric-degeneracy-fixture"),
                "response"=>Dict(
                    "energy_zero"=>"Hamiltonian reference",
                    "fermi_energy_ev"=>0.0,
                    "temperature_k"=>0.0,
                    "photon_energies_ev"=>[1.01],
                    "photon_momentum_A_inverse"=>[0.0, 0.0, 0.0],
                    "sampling"=>Dict(
                        "kind"=>"k_region",
                        "spatial_dimension"=>2,
                        "k_mesh"=>[1, 1],
                        "origin"=>[0.0, 0.0],
                        "vector_1"=>[0.01, 0.0],
                        "vector_2"=>[0.0, 0.01],
                    ),
                    "execution"=>Dict("fourier_backend"=>"direct"),
                    "tasks" => Dict{String, Any}(
                        "pdsc" => Dict(
                            "kind"=>"PDSC",
                            "method"=>"Geometric_Loop",
                            "numerics"=>Dict(
                                "broadening"=>0.06,
                                "denominator_regularization"=>0.03,
                                "degeneracy_threshold"=>threshold,
                                "finite_difference_step"=>1e-4,
                            ),
                        ),
                    ),
                ),
                "output"=>Dict("output_root"=>directory, "progress_enabled"=>false),
            )
            path=joinpath(directory, "input.toml")
            open(io->TOML.print(io, doc), path, "w")
            resolved=read_task_input(path; model = input)
            @test isempty(resolved.pending)
            text_cfg=only(DG_RUNTIME.compile_task_configs(resolved.config))
            @test text_cfg.degeneracy_threshold === cfg.degeneracy_threshold === threshold
            for current in (cfg, text_cfg)
                screen=DG_RUNTIME.make_photon_drag_transition_screen_workspace(4, 0, 1)
                DG_ME.prepare_real_space!(screen.matrix_elements, model)
                DG_RUNTIME._prepare_photon_drag_transition_screen!(
                    screen,
                    zeros(3),
                    zeros(3),
                    current,
                    model,
                    4,
                )
                ws=DG_RESP.make_geometric_loop_response_workspace(4, 0, 2, 1)
                DG_ME.prepare_real_space!(ws.scratch.matrix_elements, model)
                ok,
                lo,
                hi=DG_RUNTIME._geometric_loop_prepare_current_kernel_from_photon_drag_transition_screen!(
                    ws,
                    zeros(3),
                    screen,
                    zeros(3),
                    Matrix{Float64}(I, 3, 3)*1e-4,
                    zeros(3, 4),
                    current,
                    model,
                    4,
                    2,
                    2;
                    tensor_indices = [1, 1, 2],
                )
                @test ok && (lo, hi)==(1, 4)
                @test ws.valence_central_data.degeneracy_group_starts ==
                      (threshold==0.0 ? [1, 2, 3, 4] : [1, 1, 3, 3])
                @test ws.valence_central_data.spectrum.energies ≈ [-0.5, -0.49, 0.5, 0.52] atol=1e-14
                @test all(isfinite, ws.response_kernel)
            end
        end
    end
end
