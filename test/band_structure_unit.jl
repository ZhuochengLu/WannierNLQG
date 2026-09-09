using Test
using JSON3
using Printf
using WannierNLQG

const BAND_CORE = WannierNLQG.Core
const BAND_IO = WannierNLQG.IO
const BAND_ME = WannierNLQG.MatrixElements
const BAND_RUNTIME = WannierNLQG.Runtime
const BAND_SYNTHETIC_TB =
    joinpath(ROOT, "examples", "symmetrization", "fixture", "inputs", "synthetic_tb.dat")
const BAND_STRUCTURE_TEST_MODE = TEST_SELECTION.mode

macro band_testset_if(condition, name, body)
    return esc(:(
        if $condition
            @testset $name $body
        end
    ))
end

# Construct the mandatory Packed-HDF5 geometry contract for a Band fixture.
function band_test_bundle_geometry(
    model;
    real_space_replica_policy = "input",
    minimum_distance_materialized = false,
    replica_mapping_sha256 = repeat("0", 64),
)
    centers = Matrix(transpose(BAND_ME.extract_wannier_centers(model)))
    fractional = Matrix(centers * inv(model.lattice))
    return Dict(
        "wannier_center_policy" => "symmetrize",
        "real_space_replica_policy" => real_space_replica_policy,
        "production_eligible" => true,
        "minimum_distance_materialized" => minimum_distance_materialized,
        "mp_grid" => [1, 1, 1],
        "wannier_center_tolerance" => 1.0e-8,
        "wigner_seitz_tolerance" => 1.0e-5,
        "wigner_seitz_search_size" => 3,
        "raw_wannier_centers_cartesian" => centers,
        "raw_wannier_centers_fractional" => fractional,
        "final_wannier_centers_cartesian" => centers,
        "final_wannier_centers_fractional" => fractional,
        "center_alignment_lattice_shifts" => zeros(Int, size(centers)),
        "replica_mapping_sha256" => replica_mapping_sha256,
    )
end

# Write a Hamiltonian-position bundle paired to the source TB fixture.
function write_band_test_bundle(
    directory,
    model_file;
    geometry = nothing,
    name = "wannierNLQG_tb.h5",
)
    model = BAND_IO.read_wannier_tb(model_file)
    operators = Dict{BAND_CORE.RealSpaceOperatorKind, BAND_CORE.RealSpaceOperator}(
        BAND_CORE.REAL_SPACE_HAMILTONIAN => BAND_CORE.RealSpaceOperator(
            BAND_CORE.RealSpaceOperatorSymmetrySpec(BAND_CORE.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
            model.r_vectors,
            model.hamiltonian_r,
        ),
        BAND_CORE.REAL_SPACE_POSITION => BAND_CORE.RealSpaceOperator(
            BAND_CORE.RealSpaceOperatorSymmetrySpec(BAND_CORE.REAL_SPACE_POSITION, 1, -1, 1),
            model.r_vectors,
            model.position_r,
        ),
    )
    path = joinpath(directory, name)
    return BAND_IO.write_real_space_operator_bundle(
        path,
        model.lattice,
        model.r_degeneracies,
        operators;
        profile = :hamiltonian_position,
        paired_tb_sha256 = BAND_RUNTIME.checksum_file(model_file),
        geometry = something(geometry, band_test_bundle_geometry(model)),
    )
end

# Write a small analytic R=0 model using the standard Wannier90 TB layout.
function write_band_test_tb(path::AbstractString, hamiltonian::Matrix{ComplexF64})
    orbital_count = size(hamiltonian, 1)
    size(hamiltonian, 2) == orbital_count || error("test Hamiltonian must be square")
    open(path, "w") do io
        println(io, "WannierNLQG Band analytic fixture")
        println(io, "1.0 0.0 0.0")
        println(io, "0.0 1.0 0.0")
        println(io, "0.0 0.0 1.0")
        println(io, orbital_count)
        println(io, 1)
        println(io, "1")
        println(io)
        println(io, "0 0 0")
        for column in 1:orbital_count, row in 1:orbital_count
            value = hamiltonian[row, column]
            @printf(io, "%d %d %.17e %.17e\n", row, column, real(value), imag(value))
        end
        println(io)
        println(io, "0 0 0")
        for column in 1:orbital_count, row in 1:orbital_count
            @printf(io, "%d %d 0.0 0.0 0.0 0.0 0.0 0.0\n", row, column)
        end
    end
    return String(path)
end

# Return the common high-symmetry test configuration.
function band_test_config(output_root, model_file; kwargs...)
    parameters = merge(
        (
            tasks = [("Band", "K-path")],
            fourier_backend = "direct",
            model_file = model_file,
            output_root = output_root,
            system_name = "band_test",
            fermi_energy = 0.25,
            kpath_nodes = [("Γ", (0.0, 0.0, 0.0)), ("X", (0.5, 0.0, 0.0)), ("Γ", (0.0, 0.0, 0.0))],
            kpoints_per_segment = [5, 5],
            progress_enabled = false,
        ),
        (; kwargs...),
    )
    return WannierNLQG.Runtime.EffectiveTaskConfig(; parameters...)
end

# Parse only numerical rows of one Band result.
function read_band_test_table(path)
    rows = [
        parse.(Float64, split(line)) for
        line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), '#')
    ]
    return reduce(vcat, permutedims.(rows))
end

@band_testset_if (BAND_STRUCTURE_TEST_MODE == "fast") "Band task validation, path, direct spectrum, and fail-closed output" begin
    valid = band_test_config(mktempdir(), BAND_SYNTHETIC_TB)
    specs = BAND_RUNTIME.validate_config(valid)
    @test only(specs).quantity == :band_structure
    @test only(specs).calculation == :kpath
    model = BAND_IO.read_wannier_tb(BAND_SYNTHETIC_TB)
    path_plan = BAND_RUNTIME.make_kpath_plan(valid, model.lattice)
    @test size(path_plan.kpoints) == (9, 3)
    @test path_plan.node_indices == [1, 5, 9]
    @test path_plan.kpoints[5, :] == [0.5, 0.0, 0.0]
    @test path_plan.cumulative_distances[[1, 5, 9]] ≈ [0.0, π, 2π] atol = 1.0e-14

    @test_throws ErrorException BAND_RUNTIME.validate_config(
        band_test_config(mktempdir(), BAND_SYNTHETIC_TB; kpath_nodes = [("Γ", (0.0, 0.0, 0.0))]),
    )
    @test_throws ErrorException BAND_RUNTIME.validate_config(
        band_test_config(mktempdir(), BAND_SYNTHETIC_TB; kpoints_per_segment = [5]),
    )
    @test_throws ErrorException BAND_RUNTIME.validate_config(
        band_test_config(
            mktempdir(),
            BAND_SYNTHETIC_TB;
            kpath_nodes = [("Γ", (0.0, 0.0, 0.0)), ("X", (0.0, 0.0, 0.0))],
            kpoints_per_segment = [2],
        ),
    )
    @test_throws ErrorException BAND_RUNTIME.validate_config(
        band_test_config(mktempdir(), BAND_SYNTHETIC_TB; fourier_backend = "auto"),
    )
    @test only(
        BAND_RUNTIME.validate_config(
            WannierNLQG.Runtime.EffectiveTaskConfig(
                tasks = [("SC", "Conventional", "Integral")],
                fourier_backend = "direct",
                real_space_replica_policy = "input",
            ),
        ),
    ).calculation == :integral

    mktempdir() do directory
        two_band_file = write_band_test_tb(
            joinpath(directory, "two_band_tb.dat"),
            ComplexF64[-1.0 0.0; 0.0 2.0],
        )
        config = band_test_config(joinpath(directory, "result"), two_band_file)
        result = WannierNLQG.run(config)
        @test length(result.outputs) == 2
        @test basename.(result.outputs) == ["band_test_bands.dat", "band_test_kpath.json"]
        table = read_band_test_table(first(result.outputs))
        @test size(table) == (9, 6)
        @test table[:, 5] == fill(-1.25, 9)
        @test table[:, 6] == fill(1.75, 9)
        path_payload = JSON3.read(read(result.outputs[2], String))
        @test String(path_payload.schema) == "wanniernlqg.kpath"
        @test Int(path_payload.total_kpoints) == 9
        @test !hasproperty(path_payload, :E_ref_eV)
        @test !hasproperty(path_payload, :energy_unit)
        @test !hasproperty(path_payload, :energy_convention)
        @test occursin(
            "# energy_reference_E_ref_eV = 2.50000000000000000e-01",
            read(result.outputs[1], String),
        )
        @test !isfile(joinpath(config.output_root, "band_test_band_path.json"))
        @test Int.(getproperty.(path_payload.node_chain, :point_index_one_based)) == [1, 5, 9]
        @test !isfile(joinpath(config.output_root, "band_test_bands.pdf"))
        metadata = read(result.metadata_path, String)
        @test occursin("[Band]", metadata)
        @test occursin("INPUT_QUALIFICATION_NOT_PROVIDED", metadata)
        @test occursin("exp(2pi*i*R_dot_k)/wannier90_degeneracy", metadata)

        oracle_model = BAND_IO.read_wannier_tb(two_band_file)
        matrix_plan = BAND_ME.compile_matrix_plan(
            BAND_ME.MatrixElementRequest(BAND_ME.SPECTRUM);
            source_gauge_required = false,
        )
        workspace = BAND_ME.MatrixElementWorkspace(oracle_model, matrix_plan)
        BAND_ME.prepare_real_space!(workspace, oracle_model)
        oracle = BAND_ME.compute_spectrum!(workspace, oracle_model, @view(path_plan.kpoints[3, :]))
        @test table[3, 5:end] == oracle.energies .- config.fermi_energy
    end

    mktempdir() do directory
        config = TaskConfig(
            model = ModelInput(model_file = BAND_SYNTHETIC_TB),
            sampling = KPath(
                nodes = [("Γ", (0.0, 0.0, 0.0)), ("X", (0.5, 0.0, 0.0))],
                kpoints_per_segment = [3],
            ),
            execution = ExecutionOptions(fourier_backend = "direct"),
            output = OutputOptions(
                output_root = directory,
                system_name = "multi",
                progress_enabled = false,
            ),
            tasks = [
                TaskSpec(
                    id = "bands_zero",
                    quantity = "Band_Structure",
                    physics = BandParameters(fermi_energy = 0.0),
                ),
                TaskSpec(
                    id = "bands_shifted",
                    quantity = "Band",
                    physics = BandParameters(fermi_energy = 0.25),
                ),
            ],
        )
        result = WannierNLQG.run(config)
        @test length(result.task_results) == 2
        @test all(task_result -> length(task_result.outputs) == 2, result.task_results)
        @test all(task_result -> all(isfile, task_result.outputs), result.task_results)
        @test dirname(first(result.task_results[1].outputs)) !=
              dirname(first(result.task_results[2].outputs))
        @test read(result.task_results[1].outputs[2]) == read(result.task_results[2].outputs[2])
        @test read(result.task_results[1].outputs[1]) != read(result.task_results[2].outputs[1])
    end

    mktempdir() do directory
        bad_file = write_band_test_tb(
            joinpath(directory, "nonhermitian_tb.dat"),
            ComplexF64[0.0 1.0; 0.0 0.0],
        )
        output = joinpath(directory, "failed")
        mkpath(output)
        write(joinpath(output, "band_test_bands.dat"), "stale\n")
        write(joinpath(output, "band_test_kpath.json"), "stale\n")
        @test_throws ErrorException WannierNLQG.run(band_test_config(output, bad_file))
        @test !isfile(joinpath(output, "band_test_bands.dat"))
        @test !isfile(joinpath(output, "band_test_kpath.json"))
    end

    mktempdir() do directory
        nonfinite_file =
            write_band_test_tb(joinpath(directory, "nonfinite_tb.dat"), ComplexF64[NaN+0.0im;;])
        @test_throws ErrorException WannierNLQG.run(
            band_test_config(joinpath(directory, "failed"), nonfinite_file),
        )
    end
end

@band_testset_if (BAND_STRUCTURE_TEST_MODE == "fast") "Band text/HDF5 parity and replica policy provenance" begin
    mktempdir() do directory
        bundle_directory = joinpath(directory, "bundle")
        mkpath(bundle_directory)
        bundle = write_band_test_bundle(bundle_directory, BAND_SYNTHETIC_TB)
        text_result =
            WannierNLQG.run(band_test_config(joinpath(directory, "text"), BAND_SYNTHETIC_TB))
        hdf5_result = WannierNLQG.run(
            band_test_config(
                joinpath(directory, "hdf5"),
                BAND_SYNTHETIC_TB;
                real_space_operator_bundle_file = bundle,
            ),
        )
        @test read(text_result.outputs[1]) == read(hdf5_result.outputs[1])
        @test read(text_result.outputs[2]) == read(hdf5_result.outputs[2])
        manifest = BAND_IO.read_real_space_operator_bundle_manifest(bundle)
        @test manifest.wigner_seitz_tolerance == 1.0e-5
        @test manifest.wigner_seitz_search_size == 3
        @test manifest.replica_mapping_sha256 == repeat("0", 64)
        @test_throws ArgumentError WannierNLQG.run(
            band_test_config(
                joinpath(directory, "mp_conflict"),
                BAND_SYNTHETIC_TB;
                real_space_operator_bundle_file = bundle,
                mp_grid = (2, 1, 1),
            ),
        )
        minimum_distance = WannierNLQG.run(
            band_test_config(
                joinpath(directory, "minimum_distance"),
                BAND_SYNTHETIC_TB;
                real_space_replica_policy = "minimum_distance",
                mp_grid = (1, 1, 1),
            ),
        )
        @test read(text_result.outputs[1]) == read(minimum_distance.outputs[1])
        @test occursin(
            r"replica_transformed_this_run\s*= true",
            read(minimum_distance.metadata_path, String),
        )
        hdf5_minimum_distance = WannierNLQG.run(
            band_test_config(
                joinpath(directory, "hdf5_minimum_distance"),
                BAND_SYNTHETIC_TB;
                real_space_operator_bundle_file = bundle,
                real_space_replica_policy = "minimum_distance",
                mp_grid = (1, 1, 1),
            ),
        )
        @test read(text_result.outputs[1]) == read(hdf5_minimum_distance.outputs[1])
        @test occursin(
            r"replica_transformed_this_run\s*= true",
            read(hdf5_minimum_distance.metadata_path, String),
        )

        model = BAND_IO.read_wannier_tb(BAND_SYNTHETIC_TB)
        materialized_sha = repeat("d", 64)
        materialized_bundle = write_band_test_bundle(
            bundle_directory,
            BAND_SYNTHETIC_TB;
            name = "materialized_tb.h5",
            geometry = band_test_bundle_geometry(
                model;
                real_space_replica_policy = "minimum_distance",
                minimum_distance_materialized = true,
                replica_mapping_sha256 = materialized_sha,
            ),
        )
        materialized = WannierNLQG.run(
            band_test_config(
                joinpath(directory, "materialized"),
                BAND_SYNTHETIC_TB;
                real_space_operator_bundle_file = materialized_bundle,
            ),
        )
        materialized_metadata = read(materialized.metadata_path, String)
        @test occursin(r"effective_replica_policy\s*= minimum_distance", materialized_metadata)
        @test occursin(r"replica_transformed_this_run\s*= false", materialized_metadata)
        @test occursin(materialized_sha, materialized_metadata)
        @test read(text_result.outputs[1]) == read(materialized.outputs[1])
        @test_throws ArgumentError WannierNLQG.run(
            band_test_config(
                joinpath(directory, "cannot_reverse"),
                BAND_SYNTHETIC_TB;
                real_space_operator_bundle_file = materialized_bundle,
                real_space_replica_policy = "input",
            ),
        )
    end
end

if BAND_STRUCTURE_TEST_MODE in ("full-shard", "mpi-only")
    # Launch the public KPath/Band API with deterministic native-library threading.
    function kpath_band_parallel_command(directory; threads, ranks = nothing)
        probe = joinpath(@__DIR__, "support", "kpath_band_parallel_runner.jl")
        julia =
            `$(Base.julia_cmd()) --compiled-modules=no --startup-file=no --threads=$(threads) --project=$(ROOT) $(probe) $(directory)`
        command = ranks === nothing ? julia : `$(MPI_EXECUTABLE) -n $(ranks) $(julia)`
        return addenv(
            command,
            "WANNIERNLQG_USE_MPI" => ranks === nothing ? "0" : "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "OMP_NUM_THREADS" => "1",
            "MKL_NUM_THREADS" => "1",
            "VECLIB_MAXIMUM_THREADS" => "1",
        )
    end

    @testset "KPath/Band 1/2-thread and MPI byte determinism" begin
        mktempdir() do directory
            cases = if BAND_STRUCTURE_TEST_MODE == "mpi-only"
                NamedTuple[
                    (label = "threads1", threads = 1, ranks = nothing),
                    (label = "mpi1", threads = 1, ranks = 1),
                    (label = "mpi2", threads = 1, ranks = 2),
                ]
            else
                NamedTuple[
                    (label = "threads1", threads = 1, ranks = nothing),
                    (label = "threads2", threads = 2, ranks = nothing),
                ]
            end
            records = Dict{String, Any}()
            for case in cases
                output = joinpath(directory, case.label)
                mkpath(output)
                log = read(
                    kpath_band_parallel_command(output; threads = case.threads, ranks = case.ranks),
                    String,
                )
                @test occursin("KPATH_BAND_PARALLEL_PASS", log)
                records[case.label] =
                    JSON3.read(read(joinpath(output, "parallel_outputs.json"), String))
            end
            for case in cases[2:end]
                @test records[case.label] == records["threads1"]
            end
        end
    end

    @band_testset_if (BAND_STRUCTURE_TEST_MODE == "full-shard") "official Band plot postprocessor validates calculation artifacts" begin
        isdefined(Main, :BandStructurePlot) ||
            include(joinpath(ROOT, "scripts", "plot_band_structure.jl"))
        mktempdir() do directory
            result = WannierNLQG.run(band_test_config(directory, BAND_SYNTHETIC_TB))
            python = something(Sys.which("python3"), "")
            isempty(python) && error("python3 is required for the official Band postprocessor test")
            function write_plot_config(config_path, bands_path, path_json)
                payload = Dict(
                    "mode" => "single",
                    "reference" => Dict(
                        "type" => "wanniernlqg",
                        "id" => "band",
                        "label" => "Band",
                        "bands" => bands_path,
                        "path" => path_json,
                    ),
                    "output" => Dict(
                        "stem" => joinpath(directory, "band_plot"),
                        "formats" => ["pdf", "png"],
                    ),
                )
                open(config_path, "w") do io
                    JSON3.write(io, payload)
                end
                return config_path
            end
            valid_config = write_plot_config(
                joinpath(directory, "band_plot.json"),
                result.outputs[1],
                result.outputs[2],
            )
            @test Main.BandStructurePlot.main([
                "--config",
                valid_config,
                "--validate-only",
                "--python",
                python,
            ],) == 0
            @test_throws ErrorException Main.BandStructurePlot.validate_cli_contract(result.outputs)

            payload = JSON3.read(read(result.outputs[2], String), Dict{String, Any})
            payload["total_kpoints"] = 99
            corrupt = joinpath(directory, "corrupt_kpath.json")
            open(corrupt, "w") do io
                JSON3.write(io, payload)
            end
            corrupt_config = write_plot_config(
                joinpath(directory, "corrupt_band_plot.json"),
                result.outputs[1],
                corrupt,
            )
            @test_throws ProcessFailedException Main.BandStructurePlot.main([
                "--config",
                corrupt_config,
                "--validate-only",
                "--python",
                python,
            ],)

            valid_band_table = read(result.outputs[1], String)
            nonfinite_table = replace(
                valid_band_table,
                "# energy_reference_E_ref_eV = 2.50000000000000000e-01" => "# energy_reference_E_ref_eV = 1e999",
            )
            @test nonfinite_table != valid_band_table
            nonfinite = joinpath(directory, "nonfinite_bands.dat")
            write(nonfinite, nonfinite_table)
            nonfinite_config = write_plot_config(
                joinpath(directory, "nonfinite_band_plot.json"),
                nonfinite,
                result.outputs[2],
            )
            @test_throws ProcessFailedException Main.BandStructurePlot.main([
                "--config",
                nonfinite_config,
                "--validate-only",
                "--python",
                python,
            ],)
        end
    end
end
