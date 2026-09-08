using Test
using LinearAlgebra
using SHA
using WannierNLQG
import JSON3

# Reuse the diagnostic fixture recipe from check_response_symmetry_mpi.jl.
# Its failed covariance declaration is retained; this tests scheduling, not physics qualification.
function per_task_symmetry_fixture(directory)
    fixture = joinpath(@__DIR__, "..", "examples", "fixtures", "synthetic_runtime")
    bundle = joinpath(fixture, "synthetic_operators.h5")
    matrix_rows(matrix) =
        [[matrix[row, column] for column in axes(matrix, 2)] for row in axes(matrix, 1)]
    rotations = [
        Matrix{Int}(I, 3, 3),
        Matrix(Diagonal(Int[-1, 1, -1])),
        Matrix(Diagonal(Int[-1, 1, 1])),
        Matrix(Diagonal(Int[1, 1, -1])),
    ]
    operations = [
        Dict(
            "rotation_fractional" => matrix_rows(rotation),
            "translation_fractional" => [0.0, 0.0, 0.0],
            "rotation_cartesian" => matrix_rows(Float64.(rotation)),
            "antiunitary" => antiunitary,
        ) for antiunitary in (false, true) for rotation in rotations
    ]
    payload = Dict(
        "schema" => "wanniernlqg.response-symmetry/1.0",
        "provenance" => Dict(
            "model" => Dict("sha256" => bytes2hex(SHA.sha256(read(bundle)))),
            "structure" => Dict("sha256" => repeat("0", 64)),
        ),
        "symmetry" => Dict(
            "point_group_operations" => operations,
            "checks" => Dict(
                "identity" => true,
                "inverse" => true,
                "closure" => true,
                "atom_mapping" => Dict("pass" => true),
            ),
        ),
        "qualification" => Dict(
            "integrand_covariance" => Dict(
                "status" => "FAIL",
                "maximum_relative_residual" => 1.0e-2,
                "tolerance" => 1.0e-10,
            ),
        ),
    )
    artifact = joinpath(directory, "diagnostic_response_symmetry.json")
    write(artifact, JSON3.write(payload))
    model = WannierNLQG.ModelInput(
        model_file = joinpath(fixture, "synthetic_tb.dat"),
        real_space_operator_bundle_file = bundle,
        real_space_replica_policy = "minimum_distance",
        wsvec_file = joinpath(fixture, "synthetic_wsvec.dat"),
        mp_grid = (2, 1, 1),
    )
    return model, artifact
end

# Construct a public Integral instance with explicit physical inputs and its own numerical controls.
function per_task_symmetry_task(id, quantity; changed = false)
    return WannierNLQG.TaskSpec(
        id = id,
        quantity = quantity,
        method = "Conventional",
        physics = WannierNLQG.OpticalParameters(
            photon_energies = changed ? [0.2, 0.75, 1.5] : [0.25, 1.25],
            fermi_energy = changed ? 0.15 : 0.0,
            temperature = changed ? 175.0 : 0.0,
        ),
        numerics = WannierNLQG.OpticalNumerics(
            broadening = changed ? 0.12 : 0.06,
            denominator_regularization = changed ? 0.02 : 0.001,
            band_window_size = -1,
        ),
        observable = WannierNLQG.FullTensor(),
    )
end

# Execute through the new public scheduler with the task-owned reduction and tensor plans enabled.
function per_task_symmetry_run(model, artifact, tasks, directory, backend)
    execution = WannierNLQG.ExecutionOptions(
        fourier_backend = backend,
        NKdiv = backend == "mixed" ? (2, 2) : nothing,
        NKFFT = backend == "mixed" ? (2, 2) : nothing,
        response_symmetry_file = artifact,
        response_symmetry_policy = "diagnostic",
        response_symmetry_kmesh_mode = "reduced",
    )
    return WannierNLQG.run(
        WannierNLQG.TaskConfig(
            model = model,
            sampling = WannierNLQG.BZMesh(k_mesh = (4, 4), spatial_dimension = 2),
            tasks = tasks,
            execution = execution,
            output = WannierNLQG.OutputOptions(
                output_root = directory,
                system_name = "symmetry_tasks",
                response_output_digits = 17,
                progress_enabled = false,
            ),
        ),
    )
end

# Preserve all printed numerical values and row shapes while excluding path and task metadata.
function per_task_symmetry_payload(result)
    return Dict(
        basename(path) => [
            parse.(Float64, split(line)) for
            line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), '#')
        ] for path in result.outputs if endswith(path, ".dat")
    )
end

# Read the actual per-task report to verify that a reduced, diagnostic path was exercised.
function per_task_symmetry_summary(result)
    path = joinpath(result.run_dir, "response_symmetry_summary.json")
    @test isfile(path)
    summary = JSON3.read(read(path, String), Dict{String, Any})
    @test summary["policy"] == "diagnostic"
    @test summary["production_eligible"] === false
    @test summary["integrand_covariance"]["status"] == "FAIL"
    @test summary["integrand_covariance"]["tolerance"] == 1.0e-10
    @test summary["kmesh_mode"] == "reduced"
    @test summary["numerical_tensor_projection_applied"] === true
    @test summary["k_mesh"]["full_kpoint_count"] == 16
    @test summary["k_mesh"]["representative_count"] == 9
    return summary
end

# Compare standalone and combined public runs exactly without relaxing response tolerances.
function per_task_symmetry_cases(directory)
    model, artifact = per_task_symmetry_fixture(directory)
    artifact_digest = bytes2hex(SHA.sha256(read(artifact)))
    records = Dict{String, Any}[]
    for backend in ("direct", "mixed")
        @testset "$(backend) public symmetry task isolation" begin
            a = per_task_symmetry_task("a", "SC")
            b = per_task_symmetry_task("b", "ISC")
            changed_b = per_task_symmetry_task("b", "ISC"; changed = true)
            runs = Dict{String, Any}()
            for (name, tasks) in (
                ("a", [a]),
                ("b", [b]),
                ("ab", [a, b]),
                ("ba", [b, a]),
                ("changed_b", [changed_b]),
                ("a_changed_b", [a, changed_b]),
            )
                runs[name] = per_task_symmetry_run(
                    model,
                    artifact,
                    tasks,
                    joinpath(directory, backend, name),
                    backend,
                )
            end
            single_a = only(runs["a"].task_results)
            single_b = only(runs["b"].task_results)
            payload_a = per_task_symmetry_payload(single_a)
            payload_b = per_task_symmetry_payload(single_b)
            @test !isempty(payload_a) && !isempty(payload_b)
            @test all(
                isfinite(value) for rows in values(payload_a) for row in rows for value in row
            )
            @test all(
                isfinite(value) for rows in values(payload_b) for row in rows for value in row
            )
            for (name, reference, actual) in (
                ("A_in_AB", payload_a, runs["ab"].task_results[1]),
                ("A_in_BA", payload_a, runs["ba"].task_results[2]),
                ("B_in_AB", payload_b, runs["ab"].task_results[2]),
                ("B_in_BA", payload_b, runs["ba"].task_results[1]),
                ("A_after_B_changed", payload_a, runs["a_changed_b"].task_results[1]),
                (
                    "changed_B_in_AB",
                    per_task_symmetry_payload(only(runs["changed_b"].task_results)),
                    runs["a_changed_b"].task_results[2],
                ),
            )
                payload = per_task_symmetry_payload(actual)
                @test payload == reference
                push!(
                    records,
                    Dict(
                        "backend" => backend,
                        "comparison" => name,
                        "exact_equal" => payload == reference,
                    ),
                )
            end
            summaries = Dict{String, Any}()
            for (name, result) in runs
                for (id, task_result) in zip(result.task_ids, result.task_results)
                    summaries["$(name)/$(id)"] = per_task_symmetry_summary(task_result)
                end
            end
            a_response = only(values(summaries["ab/a"]["responses"]))
            b_response = only(values(summaries["ab/b"]["responses"]))
            @test length(a_response["component_labels"]) == 8
            @test length(b_response["component_labels"]) == 24
            for (standalone, combined) in (("a/a", "ab/a"), ("b/b", "ab/b"), ("a/a", "ba/a"))
                @test summaries[standalone]["k_mesh"] == summaries[combined]["k_mesh"]
                @test summaries[standalone]["responses"] == summaries[combined]["responses"]
            end
            @test sum(stat.spectrum_hits for stat in runs["ab"].sharing.worker_statistics) > 0
            @test bytes2hex(SHA.sha256(read(artifact))) == artifact_digest
        end
    end
    write(joinpath(directory, "exact-comparisons.json"), JSON3.write(records))
    return nothing
end

@testset "public per-task response-symmetry scheduling" begin
    output_parent = get(ENV, "WANNIERNLQG_PER_TASK_SYMMETRY_OUTPUT_ROOT", "")
    if isempty(output_parent)
        mktempdir(per_task_symmetry_cases)
    else
        mkpath(output_parent)
        directory = mktempdir(output_parent; cleanup = false)
        per_task_symmetry_cases(directory)
        println("PER_TASK_SYMMETRY_EVIDENCE=" * directory)
    end
end
