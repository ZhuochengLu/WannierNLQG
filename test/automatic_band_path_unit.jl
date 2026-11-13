module AutomaticBandPathTests
using Test, WannierNLQG, LinearAlgebra, JSON3, Spglib
const R = WannierNLQG.Runtime
const S = WannierNLQG.SymmetryFoundation
const ROOT = Base.pkgdir(WannierNLQG)
# Load the real CLI at module initialization, before compiled fixture closures.
const AUTOMATIC_BAND_CLI = Module(:AutomaticBandCLI)
Base.include(AUTOMATIC_BAND_CLI, joinpath(ROOT, "scripts", "wanniernlqg.jl"))

function path_plan(path, lattice)
    cfg = R.EffectiveTaskConfig(;
        tasks = [("Band", "K-path")],
        fourier_backend = "direct",
        kpath_nodes = path.nodes,
        kpoints_per_segment = path.kpoints_per_segment,
        kpath_branches = path.branches,
        kpath_provenance = path.provenance,
    )
    R.validate_kpath_config(cfg)
    return R.make_kpath_plan(cfg, lattice)
end

@testset "automatic crystal paths and actual reciprocal mapping" begin
    primitive = [0.0 2.715 2.715; 2.715 0.0 2.715; 2.715 2.715 0.0]
    diamond = S.CrystalStructure(primitive, ["Si", "Si"], [0.0 0.25; 0.0 0.25; 0.0 0.25])
    path = automatic_kpath(diamond)
    @test path.provenance["structural_space_group_number"] == 227
    @test path.provenance["convention"] == "HPKOT/SeeK-path"
    @test length(path.branches) == 2
    @test !path.provenance["inverted_branches_added"]
    @test path.provenance["time_reversal"] == "UNKNOWN"
    plan = path_plan(path, primitive)
    @test all(isfinite, plan.kpoints)
    @test size(plan.kpoints, 1) ==
          sum(path.kpoints_per_segment) - length(path.kpoints_per_segment) + length(path.branches)
    @test plan.cumulative_distances[first(plan.branches[2])] ==
          plan.cumulative_distances[last(plan.branches[1])]
    @test all(count -> count >= 2, path.kpoints_per_segment)
    # Independent row-lattice reciprocal relation: k_cart dot a_i = 2pi*k_i.
    reciprocal = 2pi * inv(primitive)'
    for (label, coordinate) in path.nodes
        cartesian = reciprocal' * collect(coordinate)
        @test primitive * cartesian ≈ 2pi .* collect(coordinate) atol = 1.0e-12
    end
    change = [1.0 1.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0]
    altered = S.CrystalStructure(
        change * primitive,
        diamond.species,
        inv(change') * diamond.positions_fractional,
    )
    alternate = automatic_kpath(altered)
    @test first.(alternate.nodes) == first.(path.nodes)
    for ((_, original), (_, transformed)) in zip(path.nodes, alternate.nodes)
        @test reciprocal' * collect(original) ≈ (2pi * inv(altered.lattice)) * collect(transformed) atol =
            1.0e-10
    end
    broken_time =
        S.CrystalStructure(Matrix{Float64}(I, 3, 3), ["A", "B"], [0.0 0.17; 0.0 0.23; 0.0 0.31])
    unknown = automatic_kpath(broken_time)
    @test unknown.provenance["inverted_branches_added"]
    @test !automatic_kpath(broken_time; time_reversal = true).provenance["inverted_branches_added"]
    magnetic = S.CrystalStructure(
        Matrix{Float64}(I, 3, 3),
        ["Fe"],
        zeros(3, 1);
        magnetic_moments_cartesian = reshape([0.0, 0.0, 2.2], 3, 1),
    )
    @test_throws ArgumentError automatic_kpath(magnetic; time_reversal = true)
    @test automatic_kpath(magnetic; time_reversal = false).provenance["unitary_inversion_in_supplied_structure"]
    @test_throws ArgumentError automatic_kpath(diamond; periodic_axes = (1, 1))
    @test_throws ArgumentError path_plan(path, Matrix{Float64}(I, 3, 3))
    rounded_lattice = primitive .+ 3.0e-8 .* Matrix{Float64}(I, 3, 3)
    remapped = automatic_kpath(diamond; model_lattice = rounded_lattice)
    @test remapped.provenance["structure_to_model_lattice_max_abs_angstrom"] > 0
    for ((_, original), (_, transformed)) in zip(path.nodes, remapped.nodes)
        @test reciprocal' * collect(original) ≈ (2pi * inv(rounded_lattice)) * collect(transformed) atol =
            1.0e-10
    end
    @test_throws ArgumentError automatic_kpath(diamond; model_lattice = Matrix{Float64}(I, 3, 3))
end

@testset "Spglib primitive lattice conversion preserves basis columns and ownership" begin
    lattice = [2.7 0.0 0.0; 0.4 3.1 0.0; 0.2 0.6 4.3]
    structure = S.CrystalStructure(lattice, ["X"], zeros(3, 1))
    dataset = Spglib.get_dataset(Spglib.Cell(transpose(lattice), [zeros(3)], [1]), 1.0e-5)
    expected = hcat(collect.(Spglib.basisvectors(dataset.primitive_lattice))...)
    @test !issymmetric(expected)
    extension, _ = S._load_symmetry_foundation_extension!()
    actual = Base.invokelatest(extension.standardize_crystal_band_cell, structure)
    @test actual.primitive_lattice isa Matrix{Float64}
    @test actual.primitive_lattice == expected
    actual.primitive_lattice[1, 1] += 1.0
    repeated = Base.invokelatest(extension.standardize_crystal_band_cell, structure)
    @test repeated.primitive_lattice == expected
    @test structure.lattice == lattice
end

@testset "2D explicit periodic plane and moderate Cartesian sampling" begin
    lattice = [3.0 0.0 0.0; -1.5 1.5sqrt(3.0) 0.0; 0.0 0.0 30.0]
    crystal = S.CrystalStructure(lattice, ["X"], zeros(3, 1))
    path = automatic_kpath(crystal; periodic_axes = (1, 2))
    @test path.spatial_dimension == 2
    @test path.provenance["plane_bravais_type"] == "hexagonal"
    @test path.provenance["plane_group_number"] == "NOT_CLASSIFIED"
    @test first.(path.nodes) == ["Γ", "M", "K", "Γ"]
    @test all(node -> abs(last(node)[3]) <= 1.0e-14, path.nodes)
    plan = path_plan(path, lattice)
    @test maximum(diff(plan.cumulative_distances)) <= 1.0 / 50 + 1.0e-12
    @test maximum(path.kpoints_per_segment) > minimum(path.kpoints_per_segment)
    @test size(plan.kpoints, 1) < 250
    # A nonstandard unimodular in-plane cell has the same primitive area and catalogue.
    shear = [1.0 2.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0]
    changed = S.CrystalStructure(shear * lattice, ["X"], zeros(3, 1))
    changed_path = automatic_kpath(changed; periodic_axes = (1, 2))
    @test changed_path.provenance["plane_bravais_type"] == "hexagonal"
    @test first.(changed_path.nodes) == first.(path.nodes)
    @test norm((2pi * inv(changed.lattice)) * collect(last(changed_path.nodes[2]))) ≈
          norm((2pi * inv(lattice)) * collect(last(path.nodes[2]))) atol = 1.0e-10
    # A genuine two-site plane supercell is reduced by its species-preserving translation.
    rectangular_supercell =
        S.CrystalStructure(Diagonal([2.0, 1.0, 10.0]), ["X", "X"], [0.0 0.5; 0.0 0.0; 0.0 0.0])
    primitive_path = automatic_kpath(rectangular_supercell; periodic_axes = (1, 2))
    @test primitive_path.provenance["plane_bravais_type"] == "square"
    @test norm(
        (2pi * inv(rectangular_supercell.lattice)) * collect(last(primitive_path.nodes[2])),
    ) ≈ sqrt(2)*pi

    explicit = automatic_kpath(crystal; periodic_axes = (1, 2), kpoints_per_segment = [7, 9, 11])
    @test explicit.kpoints_per_segment == [7, 9, 11]
    manual = KPath(;
        nodes = [
            ("a", (0.0, 0.0, 0.0)),
            ("b", (0.5, 0.0, 0.0)),
            ("c", (0.0, 0.0, 0.0)),
            ("d", (0.0, 0.5, 0.0)),
        ],
        branches = [1:2, 3:4],
        kpoints_per_segment = [3, 4],
    )
    @test path_plan(manual, lattice).node_indices == [1, 3, 4, 7]
    @test_throws ArgumentError KPath(;
        nodes = manual.nodes,
        branches = [1:2, 2:4],
        kpoints_per_segment = [3, 4, 5],
    )
end

function band_document(directory, structure)
    return Dict{String, Any}(
        "model" => Dict("source" => "julia", "identity" => "independent analytic spectrum"),
        "response" => Dict{String, Any}(
            "energy_zero" => "analytic Hamiltonian eV",
            "fermi_energy_ev" => 0.0,
            "sampling" => Dict{String, Any}(
                "kind" => "k_path",
                "structure" => Dict(
                    "lattice_angstrom" => [collect(row) for row in eachrow(structure.lattice)],
                    "species" => structure.species,
                    "positions_fractional" => [
                        collect(row) for row in eachcol(structure.positions_fractional)
                    ],
                ),
            ),
            "execution" => Dict("fourier_backend" => "direct"),
            "tasks" => Dict{String, Any}("bands" => Dict("kind" => "Band")),
        ),
        "output" => Dict("output_root" => directory, "progress_enabled" => false),
    )
end

@testset "text omission, explicit overrides and real public spectrum" begin
    mktempdir() do directory
        lattice = Matrix{Float64}(I, 3, 3)
        structure = S.CrystalStructure(lattice, ["X"], zeros(3, 1))
        hamiltonian(k, parameters) = [cos(k[1]) 0.2; 0.2 -cos(k[1])]
        model = AnalyticKInput(;
            hamiltonian,
            num_orbitals = 2,
            lattice,
            orbital_positions = zeros(3, 2),
            source_file = @__FILE__
        )
        document = band_document(directory, structure)
        resolved = resolve_task_input(document; model)
        @test isempty(resolved.pending)
        @test resolved.config.sampling isa KPath
        omitted_kind = deepcopy(document)
        delete!(omitted_kind["response"]["sampling"], "kind")
        @test resolve_task_input(omitted_kind; model).config.sampling.nodes ==
              resolved.config.sampling.nodes
        @test resolved.provenance["response.sampling.nodes"]["source"] == "DERIVED"
        @test resolved.provenance["response.sampling.kpoints_per_segment"]["source"] == "DEFAULT"
        explicit = deepcopy(document)
        explicit["response"]["sampling"]["kpoints_per_segment"] = 3
        counted = resolve_task_input(explicit; model)
        @test all(==(3), counted.config.sampling.kpoints_per_segment)
        manual = deepcopy(document)
        manual["response"]["sampling"] = Dict{String, Any}(
            "kind" => "k_path",
            "nodes" => Dict(
                "label"=>["custom-a", "custom-b"],
                "fractional_coordinates"=>[[0.0, 0.0, 0.0], [0.125, 0.0, 0.0]],
            ),
        )
        default_counts = resolve_task_input(manual; model)
        @test first.(default_counts.config.sampling.nodes) == ["custom-a", "custom-b"]
        manual["response"]["sampling"]["kpoints_per_segment"] = [5]
        hand = resolve_task_input(manual; model)
        @test hand.config.sampling.kpoints_per_segment == [5]
        result = WannierNLQG.run(hand.config)
        data = only(filter(path -> endswith(path, "_bands.dat"), result.outputs))
        table = reduce(
            vcat,
            [
                permutedims(parse.(Float64, split(line))) for
                line in eachline(data) if !isempty(strip(line)) && !startswith(strip(line), "#")
            ],
        )
        @test size(table) == (5, 6)
        for row in eachrow(table)
            @test row[5:6] ≈ eigvals(Hermitian(hamiltonian(2pi .* row[2:4], nothing))) atol =
                1.0e-13
        end
        sidecar = JSON3.read(
            read(only(filter(path -> endswith(path, "_kpath.json"), result.outputs)), String),
        )
        @test sidecar.schema_version == "2.0"
        @test length(sidecar.connected_branches) == 1
        missing = deepcopy(document)
        delete!(missing["response"]["sampling"], "structure")
        @test "response.sampling.structure_file" in resolve_task_input(missing; model).pending
        two = deepcopy(document)
        two["response"]["sampling"]["spatial_dimension"] = 2
        @test_throws ArgumentError resolve_task_input(two; model)
        @test_throws ArgumentError resolve_task_input(
            merge(
                document,
                Dict(
                    "response" => merge(
                        document["response"],
                        Dict(
                            "sampling" =>
                                Dict("kind" => "k_path", "structure_file" => "missing-POSCAR"),
                        ),
                    ),
                ),
            );
            model,
        )
    end
end

@testset "file input, public record writer and exact resolved replay" begin
    mktempdir() do directory
        structure = S.CrystalStructure(Matrix{Float64}(I, 3, 3), ["X"], zeros(3, 1))
        document = band_document(joinpath(directory, "calculation"), structure)
        hamiltonian = zeros(ComplexF64, 2, 2, 3)
        hamiltonian[:, :, 1] = [0.2 0.1; 0.1 -0.2]
        hamiltonian[:, :, 2] = [0.3 0.0; 0.0 -0.15]
        hamiltonian[:, :, 3] = hamiltonian[:, :, 2]'
        tiny = WannierNLQG.Core.TightBindingModel(
            Matrix{Float64}(I, 3, 3),
            2,
            3,
            ones(Int, 3),
            [0 1 -1; 0 0 0; 0 0 0],
            hamiltonian,
            zeros(ComplexF64, 2, 2, 3, 3),
        )
        model_file = joinpath(directory, "hermitian_tb.dat")
        WannierNLQG.IO.write_wannier_tb(model_file, tiny)
        document["model"] = Dict(
            "source" => "wannier",
            "model_file" => model_file,
            "real_space_replica_policy" => "input",
        )
        delete!(document["response"]["sampling"], "kind")
        document["response"]["sampling"]["kpoints_per_segment"] = 3
        input = joinpath(directory, "bands.toml")
        WannierNLQG.IO.write_task_input_file(input, document)
        resolved = read_task_input(input)
        @test isempty(resolved.pending)
        @test haskey(resolved.metadata, "band_path_provenance")
        records = joinpath(directory, "records")
        result = run_task_input(resolved; record_directory = records)
        data = only(filter(path -> endswith(path, "_bands.dat"), result.outputs))
        before = read(data)
        effective = read_task_input(joinpath(records, "effective_config.toml"))
        @test isempty(effective.pending)
        @test effective.config.sampling.nodes == resolved.config.sampling.nodes
        @test effective.config.sampling.branches == resolved.config.sampling.branches
        @test effective.config.sampling.kpoints_per_segment ==
              resolved.config.sampling.kpoints_per_segment
        replay_document = deepcopy(effective.original)
        replay_document["output"]["output_root"] = joinpath(directory, "replay-calculation")
        replay = resolve_task_input(replay_document)
        replay_result =
            run_task_input(replay; record_directory = joinpath(directory, "replay-records"))
        replay_data = only(filter(path -> endswith(path, "_bands.dat"), replay_result.outputs))
        @test read(replay_data) == before
        # Exercise the actual user CLI implementation, including its TOML read.
        @test Base.invokelatest(AUTOMATIC_BAND_CLI.task_input_cli, ["check", input]) == 0
    end
end

@testset "Automatic Band cache hint preserves resolver authority" begin
    hint = WannierNLQG.Runtime._task_input_uses_automatic_band_path
    document = Dict(
        "response" => Dict(
            "sampling" => Dict{String, Any}("structure_file" => "POSCAR"),
            "tasks" => Dict("bands" => Dict{String, Any}("kind" => "Band")),
        ),
    )
    @test hint(document)
    alias = deepcopy(document)
    alias["response"]["tasks"]["bands"]["kind"] = "band_structure"
    @test hint(alias)
    manual = deepcopy(document)
    manual["response"]["sampling"]["nodes"] = []
    @test !hint(manual)
    response = deepcopy(document)
    response["response"]["tasks"]["bands"]["kind"] = "shift_current"
    @test !hint(response)
    malformed = deepcopy(document)
    malformed["response"]["tasks"]["bands"]["kind"] = 7
    @test !hint(malformed)
    @test !hint(Dict("response" => nothing))
    @test !hint(Dict("response" => Dict("tasks" => [])))
    @test !hint(
        Dict(
            "response" => Dict(
                "sampling" => Dict(),
                "tasks" => Dict("bands" => Dict{String, Any}("kind" => "Band")),
            ),
        ),
    )
end

end
