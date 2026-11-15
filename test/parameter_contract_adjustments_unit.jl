module ParameterContractAdjustmentsTests
using Test, LinearAlgebra, Printf, WannierNLQG
const R = WannierNLQG.Runtime
const F = WannierNLQG.IO
const W = WannierNLQG.Wannierization
const RESULTS = NamedTuple[]
function case!(f, label)
    get(ENV, "WANNIERNLQG_PARAMETER_TEST_PHASE", "all") == "readback" &&
        label ∉ ("static_axis_public_output_and_precision", "declared_text_precision_readback") &&
        return nothing
    result = @testset "$label" begin
        f()
    end
    counts = Test.get_test_counts(result)
    push!(
        RESULTS,
        (;
            label,
            passed = counts.passes + counts.cumulative_passes,
            failed = counts.fails + counts.cumulative_fails,
            errored = counts.errors + counts.cumulative_errors,
        ),
    )
end

case!("explicit_precision_and_family_defaults") do
    @test OutputOptions().response_output_digits === nothing
    defaults = (
        (:shift_current, :integral, 7),
        (:second_harmonic_generation, :integral, 12),
        (:jerk_current, :integral, 16),
        (:third_harmonic_generation, :kslice, 16),
        (:linear_optical_response, :integral, 14),
        (:intrinsic_ahc, :integral, 16),
        (:orbital_magnetization, :kslice, 14),
    )
    for (quantity, calculation, default) in defaults
        spec = (; quantity, calculation)
        @test R.response_output_family_default(spec) == default
        @test R.resolved_response_output_digits(OutputOptions(), default) == default
        for digits in (7, 12, 17)
            @test R.resolved_response_output_digits(
                OutputOptions(; response_output_digits = digits),
                default,
            ) == digits
        end
    end
    mktempdir() do directory
        value = complex(1 / 3, -2 / 7)
        for digits in (7, 12, 17)
            file = joinpath(directory, "precision-$digits.dat")
            F.write_spectral_response_table(
                file,
                reshape([0.125], 1, 1),
                ["axis"],
                reshape([value], 1, 1),
                ["x"];
                units = "test",
                digits,
            )
            fields = split(last(readlines(file)))
            @test length(fields) == 3
            @test all(
                length(first(split(last(split(field, '.')), 'e'))) == digits for field in fields
            )
            @test abs(parse(Float64, fields[2]) - real(value)) <= 0.5 * 10.0^(-digits - 1)
            @test abs(parse(Float64, fields[3]) - imag(value)) <= 0.5 * 10.0^(-digits - 1)
        end
    end
end

include(joinpath(@__DIR__, "SpectralResponseTestSupport.jl"))
function input_model()
    base = spectral_test_model()
    return RealSpaceTBInput(
        lattice = base.lattice,
        r_vectors = base.r_vectors,
        hamiltonian_r = base.hamiltonian_r,
        orbital_positions = zeros(3, 2),
        position_model = :point_orbitals,
    )
end

function static_document(quantity)
    row = Dict{String, Any}("kind" => quantity, "method" => "Conventional")
    quantity == "LT" &&
        (row["relaxation"] = Dict("gamma_intra_ev" => 0.02, "gamma_inter_ev" => 0.03))
    quantity == "OM" && (row["input_semantics"] = "defined_finite_model")
    quantity in ("BCDC", "BCQC") && (row["relaxation_time_fs"] = 10.0)
    quantity in ("LT", "BCDC", "BCQC") &&
        (row["numerics"] = Dict("fs_kind" => "gaussian", "eta_fs_ev" => 0.02))
    return Dict{String, Any}(
        "model" => Dict("source" => "julia", "identity" => "axis-fixture"),
        "response" => Dict{String, Any}(
            "temperature_k" => 0.0,
            "sampling" =>
                Dict("kind" => "bz_mesh", "k_mesh" => [1, 1, 1], "spatial_dimension" => 3),
            "execution" => Dict("fourier_backend" => "direct"),
            "tasks" => Dict("value" => row),
        ),
        "output" => Dict("output_root" => mktempdir(), "progress_enabled" => false),
    )
end

case!("static_shared_local_axis_contract") do
    model = input_model()
    resolve(document) = resolve_task_input(document; model)
    axis(document) = only(resolve(document).config.tasks).physics.fermi_energies
    for quantity in ("AHC", "LT", "OM", "BCDC", "BCQC")
        document = static_document(quantity)
        response = document["response"]
        row = response["tasks"]["value"]
        response["fermi_energy_ev"] = 0.125
        @test axis(document) == [0.125]
        resolved = resolve(document)
        @test resolved.provenance["response.tasks.value.fermi_energies_ev"]["origin"] ==
              "response.fermi_energy_ev"
        @test resolved.config.output.response_output_digits === nothing
        directory = mktempdir()
        write_task_input_resolution(resolved, directory)
        # Julia payloads deliberately have no standalone effective-file replay.
        @test !isfile(joinpath(directory, "effective_config.toml"))
        replay_file = joinpath(directory, "effective_with_explicit_model.toml")
        F.write_task_input_file(replay_file, resolved.effective)
        replay = read_task_input(replay_file; model)
        @test only(replay.config.tasks).physics.fermi_energies == [0.125]
        @test replay.config.output.response_output_digits === nothing
        row["fermi_energies_ev"] = [-0.1, 0.2]
        @test axis(document) == [-0.1, 0.2]
        delete!(response, "fermi_energy_ev")
        response["fermi_energies_ev"] = [-0.3, 0.4]
        delete!(row, "fermi_energies_ev")
        row["fermi_energy_ev"] = 0.25
        @test axis(document) == [0.25]
        @test resolve(document).provenance["response.tasks.value.fermi_energies_ev"]["origin"] ==
              "response.tasks.value.fermi_energy_ev"
        row["fermi_energies_ev"] = [0.1]
        @test_throws ArgumentError resolve(document)
        delete!(row, "fermi_energies_ev")
        response["fermi_energy_ev"] = 0.0
        @test_throws ArgumentError resolve(document)
        delete!(response, "fermi_energy_ev")
        delete!(row, "fermi_energy_ev")
        row["fermi_energy_min_ev"] = -0.1
        row["fermi_energy_max_ev"] = 0.1
        row["fermi_energy_num_points"] = 3
        @test axis(document) == [-0.1, 0.0, 0.1]
        response["fermi_energies_ev"] = [NaN]
        @test_throws ArgumentError resolve(document)
    end
end

case!("static_axis_public_output_and_precision") do
    model = input_model()
    for requested in (nothing, 7, 12, 17)
        document = static_document("AHC")
        axis = [-0.123456789012345, 0.234567891234567]
        document["response"]["fermi_energies_ev"] = axis
        requested === nothing || (document["output"]["response_output_digits"] = requested)
        config = resolve_task_input(document; model).config
        result = only(WannierNLQG.run(config).task_results)
        file = only(filter(path -> endswith(path, "intrinsic_ahc_total.dat"), result.outputs))
        rows = [
            split(line) for
            line in eachline(file) if !isempty(strip(line)) && !startswith(line, '#')
        ]
        @test length(rows) == 2
        actual = something(requested, 16)
        parsed = F._read_vector_table(
            file,
            "wanniernlqg.intrinsic-ahc-vector/2.0",
            "intrinsic_ahc",
            "total",
            [string(a, b) for a in "xyz" for b in "xyz"],
            "S/m",
        )
        @test parsed.axis == axis
        @test parsed.serialized_axis == parse.(Float64, first.(rows))
        @test all(
            length(first(split(last(split(field, '.')), 'e'))) == actual for row in rows for
            field in row
        )
        @test occursin(
            Regex("(?m)^response_output_digits\\s*=\\s*" * string(actual) * "\\s*\$"),
            read(result.metadata_path, String),
        )
    end
end

case!("declared_text_precision_readback") do
    # Controlled non-execution arrays independently exercise cancellation and
    # negative cases; they are not model calculations or scientific results.
    mktempdir() do directory
        axis = [0.12345678111, 0.12345678112]
        source = fill(0.20933420473492634, 2, 1)
        complement = fill(-0.20933420473492637, 2, 1)
        for digits in (7, 12, 17)
            results = Dict{Symbol, Any}()
            for (term, values) in
                ((:srocc, source), (:cmocc, complement), (:total, source + complement))
                path = joinpath(directory, "$(term)-$(digits).dat")
                headers = [
                    "schema" => "controlled-text-fixture/1",
                    "quantity" => "fixture",
                    "term" => string(term),
                    "fermi_energies_definition" =>
                        WannierNLQG.Core.fermi_energy_axis_definition(axis),
                    "response_output_digits" => string(digits),
                ]
                F.write_spectral_response_table(
                    path,
                    reshape(axis, :, 1),
                    ["mu_eV"],
                    values,
                    ["x"];
                    units = "test",
                    digits,
                    headers,
                )
                parsed = F._read_vector_table(
                    path,
                    "controlled-text-fixture/1",
                    "fixture",
                    string(term),
                    ["x"],
                    "test",
                )
                @test parsed.axis == axis
                @test all(isfinite, parsed.values)
                results[term] = parsed
            end
            @test F._serialized_decomposition_consistent(
                results,
                (:srocc, :cmocc);
                atol = 1e-20,
                rtol = 2e-12,
            )
            results[:total].values[1] += 1e-3
            @test !F._serialized_decomposition_consistent(
                results,
                (:srocc, :cmocc);
                atol = 1e-20,
                rtol = 2e-12,
            )
            path = joinpath(directory, "srocc-$(digits).dat")
            original = read(path, String)
            write(path, replace(original, "# response_output_digits=$digits\n" => ""; count = 1))
            if digits == 7
                @test_throws ArgumentError F._read_vector_table(
                    path,
                    "controlled-text-fixture/1",
                    "fixture",
                    "srocc",
                    ["x"],
                    "test",
                )
            end
            write(
                path,
                replace(
                    original,
                    "# response_output_digits=$digits" => "# response_output_digits=6";
                    count = 1,
                ),
            )
            @test_throws ErrorException F._read_vector_table(
                path,
                "controlled-text-fixture/1",
                "fixture",
                "srocc",
                ["x"],
                "test",
            )
        end
    end
    # Actual public OM and transport readers consume their own produced files.
    for quantity in ("OM", "LT"), digits in (7, 12, 17)
        document = static_document(quantity)
        axis = [0.12345678111, 0.12345678112]
        document["response"]["fermi_energies_ev"] = axis
        document["response"]["temperature_k"] = 300.0
        quantity == "LT" && delete!(document["response"]["tasks"]["value"], "numerics")
        document["output"]["response_output_digits"] = digits
        result = only(
            WannierNLQG.run(resolve_task_input(document; model = input_model()).config).task_results,
        )
        parsed =
            quantity == "OM" ? read_orbital_magnetization_result(result.run_dir) :
            read_linear_transport_result(result.run_dir)
        @test parsed.fermi_energies == axis
        @test parsed.metadata["response_output_digits"] == string(digits)
        arrays = quantity == "OM" ? parsed.vectors : parsed.tensors
        @test all(all(isfinite, value) for value in values(arrays))
        # Declaring another precision cannot hide a changed format/axis/identity.
        total_file = only(filter(path -> endswith(path, "_total.dat"), result.outputs))
        text = read(total_file, String)
        lines = readlines(total_file)
        row = findfirst(line -> !isempty(strip(line)) && !startswith(strip(line), '#'), lines)
        fields = String.(split(lines[row]))
        scale = maximum(maximum(abs, value) for value in values(arrays))
        fields[2] = Printf.format(
            Printf.Format("%." * string(digits) * "e"),
            parse(Float64, fields[2]) + 100 * max(1.0, scale),
        )
        lines[row] = join(fields, ' ')
        write(total_file, join(lines, '\n') * "\n")
        @test_throws ErrorException (
            quantity == "OM" ? read_orbital_magnetization_result(result.run_dir) :
            read_linear_transport_result(result.run_dir)
        )
        write(
            total_file,
            replace(
                text,
                "# response_output_digits=$digits" => "# response_output_digits=6";
                count = 1,
            ),
        )
        @test_throws ErrorException (
            quantity == "OM" ? read_orbital_magnetization_result(result.run_dir) :
            read_linear_transport_result(result.run_dir)
        )
    end
end

case!("internal_algorithm_and_stage_budget_boundary") do
    for (z_steps, u_steps) in ((0, 0), (2, 3), (11, 7))
        controls = W.WannierizationStageControls(dis_num_iter = z_steps, num_iter = u_steps)
        solver = W.WannierizationSolverConfig(stage_controls = controls)
        expected = W.WannierizationAccelerationConfig(
            schedule = :two_stage,
            strategy = :fixed,
            disentanglement_max_steps = z_steps,
            localization_max_steps = u_steps,
            disentanglement_objective_tolerance = controls.dis_conv_tol,
            z_stability_window = controls.dis_conv_window,
        )
        @test all(
            isequal(getfield(solver.acceleration, name), getfield(expected, name)) for
            name in fieldnames(typeof(expected))
        )
        @test solver.acceleration.disentanglement_max_steps == z_steps
        @test solver.acceleration.localization_max_steps == u_steps
        text_solver =
            R._workflow_stage_solver(Dict("dis_num_iter" => z_steps, "num_iter" => u_steps))
        @test repr(text_solver.acceleration) == repr(solver.acceleration)
        @test !haskey(R._workflow_input_effective_value(text_solver), "acceleration")
        copied = W._replace_wannierization_group(solver, (; random_seed = UInt64(13)))
        @test copied.acceleration === solver.acceleration
        changed = W._replace_wannierization_group(
            solver,
            (; stage_controls = W.WannierizationStageControls(dis_num_iter = 1, num_iter = 4)),
        )
        @test changed.acceleration.disentanglement_max_steps == 1
        @test changed.acceleration.localization_max_steps == 4
        for name in fieldnames(typeof(expected))
            name in (
                :disentanglement_max_steps,
                :localization_max_steps,
                :disentanglement_objective_tolerance,
                :z_stability_window,
            ) && continue
            @test isequal(getfield(changed.acceleration, name), getfield(solver.acceleration, name))
        end
    end
    @test_throws ArgumentError W.WannierizationSolverConfig(
        acceleration = W.WannierizationAccelerationConfig(),
    )
    @test_throws ArgumentError R._workflow_stage_solver(
        Dict("acceleration" => Dict("u_initial_step" => 0.5)),
    )
    @test_throws ArgumentError W._replace_wannierization_group(
        W.WannierizationSolverConfig(),
        (; acceleration = W.WannierizationAccelerationConfig()),
    )
end
end
