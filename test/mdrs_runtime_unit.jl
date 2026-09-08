using SHA
using LinearAlgebra
using Printf
using JSON3

const MDRS_IO = WannierNLQG.IO
const MDRS_ME = WannierNLQG.MatrixElements
const MDRS_RUNTIME = WannierNLQG.Runtime

# Write a minimal official-format ordered one-orbital wsvec fixture.
# Wannier90 `ws_write_vec` emits a dated header, then fixed-width records in
# irpt -> iw -> jw order. These fixtures intentionally bind that source shape;
# they are not evidence that the locally crashing wannier90.x generated a file.
function write_mdrs_wsvec(path; bad_key = false, duplicate = false, trailing = false)
    fixed(values...) = join(lpad.(string.(values), 5))
    open(path, "w") do io
        println(io, "written on 03Sep2026 at 15:04:05 use_ws_distance=.true.")
        println(io, bad_key ? fixed(0, 0, 0, 1, 2) : fixed(0, 0, 0, 1, 1))
        println(io, fixed(1))
        println(io, fixed(0, 0, 0))
        println(io, fixed(1, 0, 0, 1, 1))
        println(io, fixed(2))
        println(io, fixed(-2, 0, 0))
        println(io, duplicate ? fixed(-2, 0, 0) : fixed(0, 0, 0))
        trailing && println(io, "unexpected")
    end
    return path
end

# Write the complete ordered two-orbital map matching the `(2, 1, 1)` fixture grid.
function write_mdrs_runtime_wsvec(path)
    fixed(values...) = join(lpad.(string.(values), 5))
    open(path, "w") do io
        println(io, "written on 03Sep2026 at 15:04:05 use_ws_distance=.true.")
        for r_vector in ((0, 0, 0), (1, 0, 0)), left in 1:2, right in 1:2
            println(io, fixed(r_vector..., left, right))
            if r_vector == (0, 0, 0)
                println(io, fixed(1))
                println(io, fixed(0, 0, 0))
            else
                println(io, fixed(2))
                println(io, fixed(-2, 0, 0))
                println(io, fixed(0, 0, 0))
            end
        end
    end
    return path
end

# Construct the narrow context required by cold-path replica planning tests.
function mdrs_test_context(directory)
    demand = MDRS_RUNTIME.OperatorDemandPlan(
        MDRS_CORE.RealSpaceOperatorKind[
            MDRS_CORE.REAL_SPACE_HAMILTONIAN,
            MDRS_CORE.REAL_SPACE_POSITION,
        ],
        Dict(
            MDRS_CORE.REAL_SPACE_HAMILTONIAN => [(Int8(0), Int8(0))],
            MDRS_CORE.REAL_SPACE_POSITION => [(Int8(axis), Int8(0)) for axis in 1:3],
        ),
        false,
    )
    return MDRS_RUNTIME.RunContext(
        MDRS_RUNTIME.NormalizedTaskSpec[],
        directory,
        "",
        "",
        :legacy,
        nothing,
        nothing,
        1,
        demand,
        "mdrs",
        joinpath(directory, "metadata.txt"),
        joinpath(directory, "progress.out"),
        joinpath(directory, "progress.jsonl"),
        nothing,
    )
end

const MDRS_CORE = WannierNLQG.Core

# Build one serialized two-record model whose second residue has an exact tie.
function mdrs_test_model()
    r_vectors = [0 1; 0 0; 0 0]
    return MDRS_CORE.TightBindingModel(
        Matrix{Float64}(I, 3, 3),
        1,
        2,
        [2, 4],
        r_vectors,
        reshape(ComplexF64[2.0, 4.0], 1, 1, 2),
        zeros(ComplexF64, 1, 1, 3, 2),
    )
end

# Write an exact two-band model with N_R > 1 and a tied boundary residue.
function write_mdrs_runtime_tb(path)
    r_vectors = ((0, 0, 0), (1, 0, 0))
    open(path, "w") do io
        println(io, "WannierNLQG MDRS runtime fixture")
        println(io, "1.0 0.0 0.0")
        println(io, "0.0 1.0 0.0")
        println(io, "0.0 0.0 1.0")
        println(io, 2)
        println(io, 2)
        println(io, "2 4")
        for (r_index, r_vector) in enumerate(r_vectors)
            println(io)
            println(io, join(r_vector, " "))
            for column in 1:2, row in 1:2
                value = if r_index == 1
                    row == column ? (row == 1 ? -2.0 : 2.0) : 0.0
                else
                    row == column ? (row == 1 ? 4.0 : -4.0) : 2.0
                end
                @printf(io, "%d %d %.17e 0.0\n", row, column, value)
            end
        end
        for (r_index, r_vector) in enumerate(r_vectors)
            println(io)
            println(io, join(r_vector, " "))
            for column in 1:2, row in 1:2
                values = if r_index == 1
                    row == column ? (0.5, 0.0, 0.0) : (0.0, 0.0, 0.0)
                else
                    sign = row == column ? (row == 1 ? 1.0 : -1.0) : 0.5
                    (2.0 * sign, sign, 0.5 * sign)
                end
                @printf(io, "%d %d %.17e 0.0 %.17e 0.0 %.17e 0.0\n", row, column, values...,)
            end
        end
    end
    return path
end

# Exact binary-valued oracle after N_R and pair-degeneracy materialization.
function mdrs_expected_prepared_arrays()
    hamiltonian = zeros(ComplexF64, 2, 2, 3)
    hamiltonian[:, :, 1] .= ComplexF64[0.5 0.25; 0.25 -0.5]
    hamiltonian[:, :, 2] .= ComplexF64[-1.0 0.0; 0.0 1.0]
    hamiltonian[:, :, 3] .= hamiltonian[:, :, 1]
    position = zeros(ComplexF64, 2, 2, 3, 3)
    position[:, :, 1, 1] .= ComplexF64[0.25 0.125; 0.125 -0.25]
    position[:, :, 2, 1] .= ComplexF64[0.125 0.0625; 0.0625 -0.125]
    position[:, :, 3, 1] .= ComplexF64[0.0625 0.03125; 0.03125 -0.0625]
    position[:, :, 1, 2] .= ComplexF64[0.25 0.0; 0.0 0.25]
    position[:, :, :, 3] .= position[:, :, :, 1]
    return hamiltonian, position
end

# Parse one whitespace-delimited Runtime output and report zero-safe diagnostics.
function mdrs_output_metrics(candidate_path, reference_path; scale_floor = 1.0e-14)
    read_rows(path) = [
        parse.(Float64, split(strip(line))) for
        line in readlines(path) if !isempty(strip(line)) && !startswith(strip(line), '#')
    ]
    candidate_rows = read_rows(candidate_path)
    reference_rows = read_rows(reference_path)
    length(candidate_rows) == length(reference_rows) || error("MDRS output row counts differ")
    all(
        length(candidate_rows[index]) == length(reference_rows[index]) for
        index in eachindex(candidate_rows)
    ) || error("MDRS output column counts differ")
    candidate = reduce(vcat, (permutedims(row) for row in candidate_rows))
    reference = reduce(vcat, (permutedims(row) for row in reference_rows))
    errors = candidate .- reference
    absolute_errors = abs.(errors)
    return (
        max_abs = maximum(absolute_errors; init = 0.0),
        max_rel = maximum(absolute_errors ./ max.(abs.(reference), scale_floor); init = 0.0),
        relative_l2 = norm(errors) / max(norm(reference), scale_floor),
        nan_inf = count(value -> !isfinite(value), candidate),
        scale_floor,
    )
end

function mdrs_runtime_config(output_root, model_file, task, backend; kwargs...)
    mixed = backend == "mixed" ? (NKdiv = (1, 1), NKFFT = (2, 2)) : NamedTuple()
    parameters = merge(
        (
            tasks = [task],
            model_file = model_file,
            output_root = output_root,
            system_name = "mdrs_runtime",
            k_mesh = (2, 2),
            fourier_backend = backend,
            photon_energies = [0.2],
            fermi_energy = 0.0,
            real_space_replica_policy = "minimum_distance",
            mp_grid = (2, 1, 1),
            progress_enabled = false,
        ),
        mixed,
        (; kwargs...),
    )
    return WannierNLQG.Runtime.EffectiveTaskConfig(; parameters...)
end

function write_mdrs_materialized_bundle(path, model_file)
    model = MDRS_IO.read_wannier_tb(model_file)
    directory = dirname(path)
    ctx = mdrs_test_context(directory)
    components =
        Dict{MDRS_CORE.RealSpaceOperatorKind, Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}}(
            MDRS_CORE.REAL_SPACE_HAMILTONIAN => Dict((Int8(0), Int8(0)) => model.hamiltonian_r),
            MDRS_CORE.REAL_SPACE_POSITION => Dict(
                (Int8(axis), Int8(0)) => @view(model.position_r[:, :, axis, :]) for axis in 1:3
            ),
        )
    prepared = MDRS_RUNTIME.prepare_runtime_components(
        WannierNLQG.Runtime.EffectiveTaskConfig(;
            tasks = [("SC", "Conventional", "Integral")],
            fourier_backend = "direct",
            real_space_replica_policy = "minimum_distance",
            mp_grid = (2, 1, 1),
        ),
        ctx,
        components,
        model,
        nothing,
    )
    position =
        zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3, size(prepared.r_vectors, 2))
    for axis in 1:3
        position[:, :, axis, :] .=
            prepared.components[MDRS_CORE.REAL_SPACE_POSITION][(Int8(axis), Int8(0))]
    end
    operators = Dict(
        MDRS_CORE.REAL_SPACE_HAMILTONIAN => MDRS_CORE.RealSpaceOperator(
            MDRS_CORE.RealSpaceOperatorSymmetrySpec(MDRS_CORE.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
            prepared.r_vectors,
            prepared.components[MDRS_CORE.REAL_SPACE_HAMILTONIAN][(Int8(0), Int8(0))],
        ),
        MDRS_CORE.REAL_SPACE_POSITION => MDRS_CORE.RealSpaceOperator(
            MDRS_CORE.RealSpaceOperatorSymmetrySpec(MDRS_CORE.REAL_SPACE_POSITION, 1, -1, 1),
            prepared.r_vectors,
            position,
        ),
    )
    centers = repeat([0.25 0.0 0.0], model.num_orbitals, 1)
    geometry = Dict(
        "wannier_center_policy" => "symmetrize",
        "real_space_replica_policy" => "minimum_distance",
        "production_eligible" => true,
        "minimum_distance_materialized" => true,
        "mp_grid" => [2, 1, 1],
        "wannier_center_tolerance" => 1.0e-8,
        "wigner_seitz_tolerance" => 1.0e-5,
        "wigner_seitz_search_size" => 3,
        "raw_wannier_centers_cartesian" => centers,
        "raw_wannier_centers_fractional" => centers,
        "final_wannier_centers_cartesian" => centers,
        "final_wannier_centers_fractional" => centers,
        "center_alignment_lattice_shifts" => zeros(Int, size(centers)),
        "replica_mapping_sha256" => prepared.summary.mapping_sha256,
    )
    MDRS_IO.write_real_space_operator_bundle(
        path,
        model.lattice,
        prepared.degeneracies,
        operators;
        profile = :hamiltonian_position,
        paired_tb_sha256 = MDRS_RUNTIME.checksum_file(model_file),
        geometry = geometry,
    )
    return path
end

# A deliberately non-materialized full-profile packet exercises every registry
# kind before the HDF5 loader applies one shared minimum-distance map.
function write_mdrs_full_bundle(path, model_file)
    model = MDRS_IO.read_wannier_tb(model_file)
    ranks = Dict(
        MDRS_CORE.REAL_SPACE_HAMILTONIAN => 0,
        MDRS_CORE.REAL_SPACE_POSITION => 1,
        MDRS_CORE.REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION => 1,
        MDRS_CORE.REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP => 1,
        MDRS_CORE.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR => 2,
        MDRS_CORE.REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP => 1,
        MDRS_CORE.REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP => 2,
        MDRS_CORE.REAL_SPACE_SPIN => 1,
        MDRS_CORE.REAL_SPACE_SPIN_TIMES_HAMILTONIAN => 1,
        MDRS_CORE.REAL_SPACE_SPIN_TIMES_POSITION => 2,
        MDRS_CORE.REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION => 2,
    )
    operators = Dict{MDRS_CORE.RealSpaceOperatorKind, Any}()
    for kind in MDRS_CORE.REAL_SPACE_OPERATOR_REGISTRY
        rank = ranks[kind]
        shape = (model.num_orbitals, model.num_orbitals, ntuple(_ -> 3, rank)..., 2)
        values = zeros(ComplexF64, shape)
        kind == MDRS_CORE.REAL_SPACE_HAMILTONIAN && (values .= model.hamiltonian_r)
        kind == MDRS_CORE.REAL_SPACE_POSITION && (values .= model.position_r)
        operators[kind] = MDRS_CORE.RealSpaceOperator(
            MDRS_CORE.RealSpaceOperatorSymmetrySpec(kind, rank, 1, 1),
            model.r_vectors,
            values,
        )
    end
    centers = repeat([0.25 0.0 0.0], model.num_orbitals, 1)
    MDRS_IO.write_real_space_operator_bundle(
        path,
        model.lattice,
        model.r_degeneracies,
        operators;
        profile = :full,
        paired_tb_sha256 = MDRS_RUNTIME.checksum_file(model_file),
        geometry = Dict(
            "wannier_center_policy" => "symmetrize",
            "real_space_replica_policy" => "input",
            "production_eligible" => false,
            "minimum_distance_materialized" => false,
            "mp_grid" => [2, 1, 1],
            "wannier_center_tolerance" => 1.0e-8,
            "wigner_seitz_tolerance" => 1.0e-5,
            "wigner_seitz_search_size" => 3,
            "raw_wannier_centers_cartesian" => centers,
            "raw_wannier_centers_fractional" => centers,
            "final_wannier_centers_cartesian" => centers,
            "final_wannier_centers_fractional" => centers,
            "center_alignment_lattice_shifts" => zeros(Int, size(centers)),
            "replica_mapping_sha256" => repeat("0", 64),
        ),
        provenance = Dict(
            name => repeat(string(index, base = 16), 64) for (index, name) in enumerate((
                "SPN_sha256",
                "uIu_sha256",
                "uHu_sha256",
                "sIu_sha256",
                "sHu_sha256",
                "uIu_provenance_sha256",
                "uHu_provenance_sha256",
                "sIu_provenance_sha256",
                "sHu_provenance_sha256",
            ))
        ) |>
                     provenance -> merge(
            provenance,
            Dict(
                "uiu_generation_algorithm_version" => "mdrs-fixture-v1",
                "uHu_generation_algorithm_version" => "mdrs-fixture-v1",
                "sIu_generation_algorithm_version" => "mdrs-fixture-v1",
                "sHu_generation_algorithm_version" => "mdrs-fixture-v1",
                "authoritative_hamiltonian" => "native_dft",
                "authoritative_hamiltonian_digest" => repeat("a", 64),
                "derivative_overlap_source" => "wannier90_uIu",
                "derivative_overlap_completeness" => "full_hilbert_space",
                "derivative_overlap_source_sha256" => repeat("2", 64),
                "derivative_overlap_algorithm_version" =>
                    MDRS_IO.FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION,
                "operator_profile_assembly_algorithm_version" => "mdrs-fixture-v1",
                "pair_wigner_seitz_roundtrip_policy" => "PAIR_DEPENDENT_MINIMUM_DISTANCE_UNIT_DEGENERACY",
                "pair_wigner_seitz_roundtrip_tolerance" => 1.0e-12,
                "pair_wigner_seitz_roundtrip_residuals" => Dict(
                    MDRS_CORE.real_space_operator_name(kind) => 0.0 for kind in (
                        MDRS_CORE.REAL_SPACE_SPIN,
                        MDRS_CORE.REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
                        MDRS_CORE.REAL_SPACE_SPIN_TIMES_POSITION,
                        MDRS_CORE.REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
                    )
                ),
                "uIu_input_sha256" => Dict("fixture" => repeat("b", 64)),
                "uHu_input_sha256" => Dict("fixture" => repeat("c", 64)),
                "sIu_input_sha256" => Dict("fixture" => repeat("d", 64)),
                "sHu_input_sha256" => Dict("fixture" => repeat("e", 64)),
                "authoritative_hamiltonian_input_sha256" => Dict("fixture" => repeat("f", 64)),
            ),
        ),
        eligibility = Dict(
            "production_eligible" => false,
            "authoritative_hamiltonian" => "native_dft",
            "authoritative_hamiltonian_sha256" => repeat("a", 64),
        ),
    )
    return path
end

@testset "strict Wannier90 wsvec reader" begin
    mktempdir() do directory
        r_vectors = [0 1; 0 0; 0 0]
        path = write_mdrs_wsvec(joinpath(directory, "case_wsvec.dat"))
        parsed = MDRS_IO.read_wannier_wsvec(path, 1, r_vectors)
        @test parsed.path == abspath(path)
        @test parsed.file_sha256 == bytes2hex(SHA.sha256(read(path)))
        @test parsed.translations[1, 1, 1] == [(0, 0, 0)]
        @test parsed.translations[1, 1, 2] == [(-2, 0, 0), (0, 0, 0)]

        @test_throws ArgumentError MDRS_IO.read_wannier_wsvec(
            joinpath(directory, "missing.dat"),
            1,
            r_vectors,
        )

        @test_throws ArgumentError MDRS_IO.read_wannier_wsvec(
            write_mdrs_wsvec(joinpath(directory, "bad_key.dat"); bad_key = true),
            1,
            r_vectors,
        )
        @test_throws ArgumentError MDRS_IO.read_wannier_wsvec(
            write_mdrs_wsvec(joinpath(directory, "duplicate.dat"); duplicate = true),
            1,
            r_vectors,
        )
        @test_throws ArgumentError MDRS_IO.read_wannier_wsvec(
            write_mdrs_wsvec(joinpath(directory, "trailing.dat"); trailing = true),
            1,
            r_vectors,
        )
        write(joinpath(directory, "wrong_header.dat"), "no policy\n")
        @test_throws ArgumentError MDRS_IO.read_wannier_wsvec(
            joinpath(directory, "wrong_header.dat"),
            1,
            r_vectors,
        )
        fixed(values...) = join(lpad.(string.(values), 5))
        header = "written on 03Sep2026 at 15:04:05 use_ws_distance=.true."
        for (name, lines) in (
            ("truncated_key.dat", [header]),
            ("truncated_count.dat", [header, fixed(0, 0, 0, 1, 1)]),
            ("truncated_image.dat", [header, fixed(0, 0, 0, 1, 1), fixed(2), fixed(0, 0, 0)]),
            ("nonpositive_count.dat", [header, fixed(0, 0, 0, 1, 1), fixed(0)]),
            ("wrong_r_order.dat", [header, fixed(1, 0, 0, 1, 1), fixed(1), fixed(0, 0, 0)]),
            ("incomplete.dat", [header, fixed(0, 0, 0, 1, 1), fixed(1), fixed(0, 0, 0)]),
        )
            variant = joinpath(directory, name)
            open(variant, "w") do io
                foreach(line -> println(io, line), lines)
            end
            @test_throws ArgumentError MDRS_IO.read_wannier_wsvec(variant, 1, r_vectors)
        end
    end
end

@testset "input replica mapping digest stays canonical without map materialization" begin
    r_vectors = [0 -2 1; 1 0 -3; 0 4 -1]
    degeneracies = [2, 3, 5]
    materialized = MDRS_ME.input_real_space_replica_map(r_vectors, degeneracies, 2)
    digest = MDRS_ME.input_real_space_replica_mapping_sha256(r_vectors, degeneracies, 2)
    @test digest == materialized.mapping_sha256
    @test digest == "513a105d379eee992ed84d9c21e161208eb28fc81e97800b6f783c829ed29daf"
    @test MDRS_ME.input_real_space_replica_mapping_sha256(r_vectors, degeneracies, 1) != digest
    @test MDRS_ME.input_real_space_replica_mapping_sha256(copy(r_vectors), [2, 3, 7], 2) != digest
    changed_r_vectors = copy(r_vectors)
    changed_r_vectors[1, 2] -= 1
    @test MDRS_ME.input_real_space_replica_mapping_sha256(changed_r_vectors, degeneracies, 2) !=
          digest
    @test_throws ArgumentError MDRS_ME.input_real_space_replica_mapping_sha256(
        zeros(Int, 2, 1),
        [1],
        1,
    )
    @test_throws ArgumentError MDRS_ME.input_real_space_replica_mapping_sha256(
        zeros(Int, 3, 1),
        [0],
        1,
    )
    @test_throws ArgumentError MDRS_ME.input_real_space_replica_mapping_sha256(
        zeros(Int, 3, 1),
        [1],
        0,
    )
end

@testset "runtime replica lifecycle truth table and canonical identity" begin
    mktempdir() do directory
        model = mdrs_test_model()
        ctx = mdrs_test_context(directory)
        wsvec = write_mdrs_wsvec(joinpath(directory, "case_wsvec.dat"))
        base = (tasks = [("Band", "Conventional", "K-path")], fourier_backend = "direct")

        automatic_input = MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(; base...),
            ctx,
            model,
            nothing,
        )
        @test automatic_input.effective_policy == :input
        @test automatic_input.source == :input
        @test automatic_input.input_materialized === false
        @test automatic_input.map === nothing
        @test automatic_input.mapping_sha256 == MDRS_ME.input_real_space_replica_map(
            model.r_vectors,
            model.r_degeneracies,
            model.num_orbitals,
        ).mapping_sha256

        automatic_grid = MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(; base..., mp_grid = (2, 1, 1)),
            ctx,
            model,
            nothing,
        )
        @test automatic_grid.effective_policy == :minimum_distance
        @test automatic_grid.source == :recomputed

        automatic_wsvec = MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(; base..., wsvec_file = wsvec),
            ctx,
            model,
            nothing,
        )
        @test automatic_wsvec.source == :wsvec
        @test automatic_wsvec.map.mapping_sha256 == automatic_grid.map.mapping_sha256

        cross_checked = MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(;
                base...,
                wsvec_file = wsvec,
                mp_grid = (2, 1, 1),
            ),
            ctx,
            model,
            nothing,
        )
        @test cross_checked.map.images == automatic_grid.map.images
        @test_throws ArgumentError MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(;
                base...,
                wsvec_file = wsvec,
                mp_grid = (3, 1, 1),
            ),
            ctx,
            model,
            nothing,
        )

        for config in (
            WannierNLQG.Runtime.EffectiveTaskConfig(;
                base...,
                real_space_replica_policy = "input",
                wsvec_file = wsvec,
            ),
            WannierNLQG.Runtime.EffectiveTaskConfig(;
                base...,
                real_space_replica_policy = "input",
                mp_grid = (2, 1, 1),
            ),
            WannierNLQG.Runtime.EffectiveTaskConfig(;
                base...,
                real_space_replica_policy = "input",
                wigner_seitz_tolerance = 1.0e-6,
            ),
            WannierNLQG.Runtime.EffectiveTaskConfig(;
                base...,
                real_space_replica_policy = "input",
                wigner_seitz_search_size = 4,
            ),
        )
            @test_throws ArgumentError MDRS_RUNTIME.build_runtime_replica_plan(
                config,
                ctx,
                model,
                nothing,
            )
        end

        manifest_input = (
            schema_version = "6.3",
            real_space_replica_policy = :input,
            minimum_distance_materialized = false,
            mp_grid = (2, 1, 1),
            wigner_seitz_tolerance = 1.0e-5,
            wigner_seitz_search_size = 3,
            replica_mapping_sha256 = repeat("a", 64),
        )
        inherited = MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(; base...),
            ctx,
            model,
            manifest_input,
        )
        @test inherited.effective_policy == :input
        @test inherited.mp_grid == (2, 1, 1)

        legacy_manifest =
            merge(manifest_input, (schema_version = "5.9", minimum_distance_materialized = false))
        legacy = MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(; base...),
            ctx,
            model,
            legacy_manifest,
        )
        @test legacy.effective_policy == :input
        @test legacy.source == :legacy_input
        @test legacy.input_materialized === nothing

        materialized_manifest = merge(
            manifest_input,
            (real_space_replica_policy = :minimum_distance, minimum_distance_materialized = true),
        )
        materialized = MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(; base...),
            ctx,
            model,
            materialized_manifest,
        )
        @test materialized.source == :materialized_bundle
        @test materialized.input_materialized === true
        @test_throws ArgumentError MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(; base..., real_space_replica_policy = "input"),
            ctx,
            model,
            materialized_manifest,
        )
        @test_throws ArgumentError MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(; base..., wsvec_file = wsvec),
            ctx,
            model,
            materialized_manifest,
        )
        @test_throws ArgumentError MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(; base..., wigner_seitz_tolerance = 2.0e-5),
            ctx,
            model,
            materialized_manifest,
        )
        @test_throws ArgumentError MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(; base..., wigner_seitz_search_size = 4),
            ctx,
            model,
            materialized_manifest,
        )
        @test_throws ArgumentError MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(;
                base...,
                real_space_replica_policy = "minimum_distance",
                mp_grid = (2, 1, 1),
            ),
            ctx,
            model,
            legacy_manifest,
        )
        @test_throws ArgumentError MDRS_RUNTIME.build_runtime_replica_plan(
            WannierNLQG.Runtime.EffectiveTaskConfig(; base..., mp_grid = (3, 1, 1)),
            ctx,
            model,
            materialized_manifest,
        )

        canonical_translations = Array{Vector{NTuple{3, Int}}, 3}(undef, 1, 1, 2)
        canonical_translations[1, 1, 1] = [(0, 0, 0)]
        canonical_translations[1, 1, 2] = [(-2, 0, 0), (0, 0, 0)]
        changed_n_r = MDRS_ME.real_space_replica_map_from_wsvec(
            model.r_vectors,
            [2, 5],
            canonical_translations,
        )
        changed_r_translations = Array{Vector{NTuple{3, Int}}, 3}(undef, 1, 1, 2)
        changed_r_translations[1, 1, 1] = [(0, 0, 0)]
        changed_r_translations[1, 1, 2] = [(-4, 0, 0), (-2, 0, 0)]
        changed_r = MDRS_ME.real_space_replica_map_from_wsvec(
            [0 3; 0 0; 0 0],
            model.r_degeneracies,
            changed_r_translations,
        )
        @test changed_n_r.mapping_sha256 != automatic_grid.map.mapping_sha256
        @test changed_r.mapping_sha256 != automatic_grid.map.mapping_sha256
    end
end

@testset "center-aware pair map covers non-origin centers and exact ties" begin
    r_vectors = [0 1; 0 0; 0 0]
    centers = [0.125 0.0 0.0; 0.375 0.0 0.0]
    map = MDRS_ME.minimum_distance_real_space_replica_map(
        r_vectors,
        [1, 1],
        Matrix{Float64}(I, 3, 3),
        (2, 1, 1),
        centers;
        tolerance = 1.0e-12,
        search_size = 3,
    )
    @test map.images[1, 1, 2] == [(-1, 0, 0), (1, 0, 0)]
    @test map.images[2, 2, 2] == [(-1, 0, 0), (1, 0, 0)]
    @test map.images[1, 2, 2] == [(-1, 0, 0)]
    @test map.images[2, 1, 2] == [(1, 0, 0)]
end

@testset "one canonical map materializes every demanded operator family" begin
    mktempdir() do directory
        model = mdrs_test_model()
        ctx = mdrs_test_context(directory)
        components = Dict{
            MDRS_CORE.RealSpaceOperatorKind,
            Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}},
        }()
        for (index, kind) in enumerate(MDRS_CORE.REAL_SPACE_OPERATOR_REGISTRY)
            component = (Int8(mod(index - 1, 3) + 1), Int8(mod(index, 3) + 1))
            components[kind] =
                Dict(component => reshape(ComplexF64[2.0 * index, 4.0 * index], 1, 1, 2))
        end
        prepared = MDRS_RUNTIME.prepare_runtime_components(
            WannierNLQG.Runtime.EffectiveTaskConfig(;
                tasks = [("Band", "Conventional", "K-path")],
                fourier_backend = "direct",
                mp_grid = (2, 1, 1),
            ),
            ctx,
            components,
            model,
            nothing,
        )
        @test sort!(collect(keys(prepared.components)); by = Int) ==
              collect(MDRS_CORE.REAL_SPACE_OPERATOR_REGISTRY)
        @test prepared.r_vectors == [-1 0 1; 0 0 0; 0 0 0]
        @test prepared.degeneracies == ones(Int, 3)
        for (index, kind) in enumerate(MDRS_CORE.REAL_SPACE_OPERATOR_REGISTRY)
            only_component = only(values(prepared.components[kind]))
            @test size(only_component) == (1, 1, 3)
            @test vec(only_component) == ComplexF64[0.5 * index, 1.0 * index, 0.5 * index]
        end
        @test prepared.summary.mapping_sha256 == prepared.plan.map.mapping_sha256
        @test prepared.summary.scalar_degeneracy_applied
        @test prepared.summary.pair_degeneracy_applied

        prepared_position = zeros(ComplexF64, 1, 1, 3, size(prepared.r_vectors, 2))
        prepared_model = MDRS_CORE.TightBindingModel(
            model.lattice,
            model.num_orbitals,
            size(prepared.r_vectors, 2),
            prepared.degeneracies,
            prepared.r_vectors,
            zeros(ComplexF64, 1, 1, size(prepared.r_vectors, 2)),
            prepared_position,
        )
        spectrum_plan = MDRS_ME.compile_matrix_plan(MDRS_ME.MatrixElementRequest(MDRS_ME.SPECTRUM))
        workspace = MDRS_ME.MatrixElementWorkspace(prepared_model, spectrum_plan)
        MDRS_ME.prepare_real_space!(workspace, prepared_model)
        @test workspace.prepared
        @test length(workspace.scratch.fourier_factors) == size(prepared.r_vectors, 2) == 3
    end
end

@testset "Band Integral and K-slice prepare before Direct or Mixed planning" begin
    mktempdir() do directory
        model_file = write_mdrs_runtime_tb(joinpath(directory, "runtime_tb.dat"))
        wsvec_file = write_mdrs_runtime_wsvec(joinpath(directory, "runtime_wsvec.dat"))

        input_cfg = mdrs_runtime_config(
            joinpath(directory, "input_source_identity"),
            model_file,
            ("SC", "Conventional", "Integral"),
            "direct";
            real_space_replica_policy = "input",
            mp_grid = nothing,
        )
        input_specs = MDRS_RUNTIME.validate_config(input_cfg)
        input_ctx = MDRS_RUNTIME.prepare_run_context(input_cfg, input_specs)
        loaded_input = MDRS_RUNTIME.load_runtime_model_and_sources(input_ctx, input_cfg)
        @test loaded_input.model.hamiltonian_r isa Array{ComplexF64, 3}
        @test loaded_input.model.position_r isa Array{ComplexF64, 4}
        @test loaded_input.replica_summary.effective_policy == :input
        @test !loaded_input.replica_summary.transformed_this_run
        MDRS_RUNTIME.release_runtime_storage!(loaded_input)

        oracle_cfg = mdrs_runtime_config(
            joinpath(directory, "prepared_oracle"),
            model_file,
            ("SC", "Conventional", "Integral"),
            "direct",
        )
        oracle_specs = MDRS_RUNTIME.validate_config(oracle_cfg)
        oracle_ctx = MDRS_RUNTIME.prepare_run_context(oracle_cfg, oracle_specs)
        loaded_oracle = MDRS_RUNTIME.load_runtime_model_and_sources(oracle_ctx, oracle_cfg)
        expected_hamiltonian, expected_position = mdrs_expected_prepared_arrays()
        @test loaded_oracle.model.r_vectors == [-1 0 1; 0 0 0; 0 0 0]
        @test loaded_oracle.model.r_degeneracies == ones(Int, 3)
        @test loaded_oracle.model.hamiltonian_r == expected_hamiltonian
        @test loaded_oracle.model.position_r == expected_position
        @test loaded_oracle.replica_summary.input_num_r_vectors == 2
        @test loaded_oracle.replica_summary.output_num_r_vectors == 3
        @test loaded_oracle.replica_summary.scalar_degeneracy_applied
        @test loaded_oracle.replica_summary.pair_degeneracy_applied
        MDRS_RUNTIME.release_runtime_storage!(loaded_oracle)

        input_band = WannierNLQG.run(
            mdrs_runtime_config(
                joinpath(directory, "band_input"),
                model_file,
                ("Band", "Conventional", "K-path"),
                "direct";
                real_space_replica_policy = "input",
                mp_grid = nothing,
                kpath_nodes = [("Γ", (0.0, 0.0, 0.0)), ("X", (0.5, 0.0, 0.0))],
                kpoints_per_segment = [2],
            ),
        )
        mdrs_band = WannierNLQG.run(
            mdrs_runtime_config(
                joinpath(directory, "band_mdrs"),
                model_file,
                ("Band", "Conventional", "K-path"),
                "direct";
                kpath_nodes = [("Γ", (0.0, 0.0, 0.0)), ("X", (0.5, 0.0, 0.0))],
                kpoints_per_segment = [2],
            ),
        )
        wsvec_band = WannierNLQG.run(
            mdrs_runtime_config(
                joinpath(directory, "band_wsvec"),
                model_file,
                ("Band", "Conventional", "K-path"),
                "direct";
                wsvec_file,
                mp_grid = nothing,
                kpath_nodes = [("Γ", (0.0, 0.0, 0.0)), ("X", (0.5, 0.0, 0.0))],
                kpoints_per_segment = [2],
            ),
        )
        input_band_rows = filter(
            line -> !isempty(strip(line)) && !startswith(strip(line), '#'),
            readlines(input_band.outputs[1]),
        )
        mdrs_band_rows = filter(
            line -> !isempty(strip(line)) && !startswith(strip(line), '#'),
            readlines(mdrs_band.outputs[1]),
        )
        @test input_band_rows == mdrs_band_rows
        @test read(wsvec_band.outputs[1]) == read(mdrs_band.outputs[1])

        direct_integral = WannierNLQG.run(
            mdrs_runtime_config(
                joinpath(directory, "integral_direct"),
                model_file,
                ("SC", "Conventional", "Integral"),
                "direct",
            ),
        )
        mixed_integral = WannierNLQG.run(
            mdrs_runtime_config(
                joinpath(directory, "integral_mixed"),
                model_file,
                ("SC", "Conventional", "Integral"),
                "mixed",
            ),
        )
        wsvec_integral = WannierNLQG.run(
            mdrs_runtime_config(
                joinpath(directory, "integral_wsvec"),
                model_file,
                ("SC", "Conventional", "Integral"),
                "direct";
                wsvec_file,
                mp_grid = nothing,
                progress_enabled = true,
            ),
        )
        @test read(direct_integral.outputs[1]) == read(mixed_integral.outputs[1])
        @test read(direct_integral.outputs[1]) == read(wsvec_integral.outputs[1])

        input_kslice = WannierNLQG.run(
            mdrs_runtime_config(
                joinpath(directory, "kslice_input"),
                model_file,
                ("BCK", "Conventional", "K-slice"),
                "direct";
                real_space_replica_policy = "input",
                mp_grid = nothing,
                tensor_indices = (1, 2),
                band_selection = (1, 2),
            ),
        )
        mdrs_kslice = WannierNLQG.run(
            mdrs_runtime_config(
                joinpath(directory, "kslice_mdrs"),
                model_file,
                ("BCK", "Conventional", "K-slice"),
                "direct";
                tensor_indices = (1, 2),
                band_selection = (1, 2),
            ),
        )
        wsvec_kslice = WannierNLQG.run(
            mdrs_runtime_config(
                joinpath(directory, "kslice_wsvec"),
                model_file,
                ("BCK", "Conventional", "K-slice"),
                "direct";
                wsvec_file,
                mp_grid = nothing,
                tensor_indices = (1, 2),
                band_selection = (1, 2),
            ),
        )
        mixed_kslice = WannierNLQG.run(
            mdrs_runtime_config(
                joinpath(directory, "kslice_mixed"),
                model_file,
                ("BCK", "Conventional", "K-slice"),
                "mixed";
                tensor_indices = (1, 2),
                band_selection = (1, 2),
            ),
        )
        input_kslice_metrics = mdrs_output_metrics(input_kslice.outputs[1], mdrs_kslice.outputs[1])
        @info "input/MDRS K-slice q-grid metrics" input_kslice_metrics
        @test input_kslice_metrics.max_abs <= 256eps(Float64)
        @test input_kslice_metrics.nan_inf == 0
        @test read(wsvec_kslice.outputs[1]) == read(mdrs_kslice.outputs[1])
        mixed_kslice_metrics = mdrs_output_metrics(mixed_kslice.outputs[1], mdrs_kslice.outputs[1])
        @info "Mixed/Direct MDRS K-slice metrics" mixed_kslice_metrics
        @test mixed_kslice_metrics.max_abs <= 256eps(Float64)
        @test mixed_kslice_metrics.nan_inf == 0

        for result in (
            mdrs_band,
            wsvec_band,
            direct_integral,
            mixed_integral,
            wsvec_integral,
            mdrs_kslice,
            wsvec_kslice,
            mixed_kslice,
        )
            metadata = read(result.metadata_path, String)
            @test occursin("[Replica]", metadata)
            @test occursin(r"effective_num_r_vectors\s*= 3", metadata)
            @test occursin(r"replica_transformed_this_run\s*= true", metadata)
        end
        @test occursin(r"backend\s*= direct", read(direct_integral.metadata_path, String))
        @test occursin(r"backend\s*= mixed", read(mixed_integral.metadata_path, String))
        @test occursin(r"backend\s*= mixed", read(mixed_kslice.metadata_path, String))
        for result in (wsvec_band, wsvec_integral, wsvec_kslice)
            metadata = read(result.metadata_path, String)
            @test occursin(r"source\s*= wsvec", metadata)
            @test occursin(r"wsvec_sha256\s*= [0-9a-f]{64}", metadata)
        end

        events =
            JSON3.read.(filter(!isempty, strip.(readlines(wsvec_integral.progress_jsonl_path))))
        done_events = filter(event -> String(event.event) == "run_done", events)
        @test length(done_events) == 1
        replica = only(done_events).replica_summary
        @test Set(String.(keys(replica))) == Set([
            "schema",
            "requested_policy",
            "effective_policy",
            "source",
            "mapping_sha256",
            "mapping_digest_scheme",
            "wsvec_file",
            "wsvec_sha256",
            "mp_grid",
            "wigner_seitz_tolerance",
            "wigner_seitz_search_size",
            "input_minimum_distance_materialized",
            "output_minimum_distance_materialized",
            "replica_transformed_this_run",
            "input_num_r_vectors",
            "effective_num_r_vectors",
            "scalar_degeneracy_applied",
            "pair_degeneracy_applied",
        ])
        @test String(replica.source) == "wsvec"
        @test length(String(replica.mapping_sha256)) == 64
        @test length(String(replica.wsvec_sha256)) == 64
        human_progress = read(wsvec_integral.progress_out_path, String)
        @test occursin("mp_grid=nothing", human_progress)
        @test occursin("mapping scheme=", human_progress)
        @test occursin("wsvec=", human_progress)
        @test occursin("wsvec sha256=", human_progress)
        @test occursin("normalization scalar=", human_progress)
        @test occursin("pair=", human_progress)
        @test occursin("transformed=true", human_progress)
    end
end

@testset "Packed HDF5 materialized lifecycle is inherited and fail-closed" begin
    mktempdir() do directory
        model_file = write_mdrs_runtime_tb(joinpath(directory, "runtime_tb.dat"))
        bundle_file =
            write_mdrs_materialized_bundle(joinpath(directory, "materialized.h5"), model_file)
        inherited = WannierNLQG.run(
            mdrs_runtime_config(
                joinpath(directory, "inherited"),
                model_file,
                ("SC", "Conventional", "Integral"),
                "direct";
                real_space_operator_bundle_file = bundle_file,
                real_space_replica_policy = "auto",
                mp_grid = nothing,
            ),
        )
        metadata = read(inherited.metadata_path, String)
        @test occursin(r"source\s*= materialized_bundle", metadata)
        @test occursin(r"input_minimum_distance_materialized\s*= true", metadata)
        @test occursin(r"replica_transformed_this_run\s*= false", metadata)
        @test_throws ArgumentError WannierNLQG.run(
            mdrs_runtime_config(
                joinpath(directory, "reverse"),
                model_file,
                ("SC", "Conventional", "Integral"),
                "direct";
                real_space_operator_bundle_file = bundle_file,
                real_space_replica_policy = "input",
                mp_grid = nothing,
            ),
        )
        @test_throws ArgumentError WannierNLQG.run(
            mdrs_runtime_config(
                joinpath(directory, "conflict"),
                model_file,
                ("SC", "Conventional", "Integral"),
                "direct";
                real_space_operator_bundle_file = bundle_file,
                real_space_replica_policy = "auto",
                mp_grid = (3, 1, 1),
            ),
        )
    end
end

@testset "non-materialized Packed full profile shares one MDRS map" begin
    mktempdir() do directory
        model_file = write_mdrs_runtime_tb(joinpath(directory, "runtime_tb.dat"))
        bundle = write_mdrs_full_bundle(joinpath(directory, "full.h5"), model_file)
        rank_one = NTuple{2, Int8}[(Int8(axis), Int8(0)) for axis in 1:3]
        rank_two = NTuple{2, Int8}[(Int8(a), Int8(b)) for a in 1:3 for b in 1:3]
        ranks = Dict(
            MDRS_CORE.REAL_SPACE_HAMILTONIAN => 0,
            MDRS_CORE.REAL_SPACE_POSITION => 1,
            MDRS_CORE.REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION => 1,
            MDRS_CORE.REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP => 1,
            MDRS_CORE.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR => 2,
            MDRS_CORE.REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP => 1,
            MDRS_CORE.REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP => 2,
            MDRS_CORE.REAL_SPACE_SPIN => 1,
            MDRS_CORE.REAL_SPACE_SPIN_TIMES_HAMILTONIAN => 1,
            MDRS_CORE.REAL_SPACE_SPIN_TIMES_POSITION => 2,
            MDRS_CORE.REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION => 2,
        )
        demand = MDRS_RUNTIME.OperatorDemandPlan(
            collect(MDRS_CORE.REAL_SPACE_OPERATOR_REGISTRY),
            Dict(
                kind => (
                    ranks[kind] == 0 ? [(Int8(0), Int8(0))] :
                    ranks[kind] == 1 ? rank_one : rank_two
                ) for kind in MDRS_CORE.REAL_SPACE_OPERATOR_REGISTRY
            ),
            true,
        )
        ctx0 = mdrs_test_context(directory)
        ctx = MDRS_RUNTIME.RunContext(
            ctx0.specs,
            ctx0.run_dir,
            ctx0.model_file,
            ctx0.model_sha256,
            ctx0.model_input_mode,
            bundle,
            ctx0.paired_tb_validation_file,
            ctx0.num_orbitals,
            demand,
            ctx0.system_name,
            ctx0.metadata_path,
            ctx0.progress_out_path,
            ctx0.progress_jsonl_path,
            ctx0.seed_inputs,
        )
        loaded = MDRS_IO.read_operator_bundle_components(
            bundle,
            demand.required_components;
            prefer_mmap = false,
        )
        prepared = MDRS_RUNTIME._prepare_hdf5_component_load(
            loaded,
            ctx,
            WannierNLQG.Runtime.EffectiveTaskConfig(
                tasks = [("SC", "Conventional", "Integral")],
                fourier_backend = "direct",
                real_space_replica_policy = "minimum_distance",
                mp_grid = (2, 1, 1),
            ),
        )
        @test prepared.replica_summary.input_materialized === false
        @test prepared.replica_summary.transformed_this_run === true
        @test all(
            size(values, 3) == size(prepared.runtime_r_vectors, 2) for
            entries in values(prepared.components) for values in values(entries)
        )
        @test Set(keys(prepared.components)) == Set(MDRS_CORE.REAL_SPACE_OPERATOR_REGISTRY)
    end
end

@testset "serialized MDRS consumes scalar and pair degeneracies once" begin
    mktempdir() do directory
        r_vectors = [0 1; 0 0; 0 0]
        parsed = MDRS_IO.read_wannier_wsvec(
            write_mdrs_wsvec(joinpath(directory, "case_wsvec.dat")),
            1,
            r_vectors,
        )
        map = MDRS_ME.real_space_replica_map_from_wsvec(r_vectors, [2, 4], parsed.translations)
        @test map.source == :wsvec
        @test map.target_r_vectors == [-1 0 1; 0 0 0; 0 0 0]
        raw = reshape(ComplexF64[2.0, 4.0], 1, 1, 2)
        materialized = MDRS_ME.materialize_replica_component(
            raw,
            [2, 4],
            map,
            MDRS_ME.SerializedWannier90ReplicaValues(),
        )
        @test_throws ArgumentError MDRS_ME.materialize_replica_component(
            raw,
            [1, 4],
            map,
            MDRS_ME.SerializedWannier90ReplicaValues(),
        )
        @test vec(materialized) == ComplexF64[0.5, 1.0, 0.5]

        # The Γ-point sum is bitwise identical for this exactly representable fixture.
        input_values = ComplexF64[]
        output_values = ComplexF64[]
        for kpoint in (0.0, 0.5)
            input_value = sum(
                raw[1, 1, index] * cispi(2 * r_vectors[1, index] * kpoint) / [2, 4][index] for
                index in axes(raw, 3)
            )
            output_value = sum(
                materialized[1, 1, index] * cispi(2 * map.target_r_vectors[1, index] * kpoint)
                for index in axes(materialized, 3)
            )
            push!(input_values, input_value)
            push!(output_values, output_value)
            @test output_value == input_value
        end
        absolute_errors = abs.(output_values .- input_values)
        relative_errors = absolute_errors ./ max.(abs.(input_values), eps(Float64))
        metrics = (
            max_abs = maximum(absolute_errors; init = 0.0),
            max_rel = maximum(relative_errors; init = 0.0),
            relative_l2 = sqrt(sum(abs2, output_values .- input_values)) /
                          max(sqrt(sum(abs2, input_values)), eps(Float64)),
            nan_inf = count(value -> !isfinite(value), output_values),
        )
        @info "MDRS exact preservation metrics" metrics
        @test metrics.max_abs == 0.0
        @test metrics.max_rel == 0.0
        @test metrics.relative_l2 == 0.0
        @test metrics.nan_inf == 0

        off_grid_k = 0.173
        off_grid_oracle = sum(
            raw[1, 1, source_index] / ([2, 4][source_index] * length(images)) *
            cispi(2 * image[1] * off_grid_k) for source_index in axes(raw, 3) for
            images in (map.images[1, 1, source_index],) for image in images
        )
        off_grid_materialized = sum(
            materialized[1, 1, target_index] *
            cispi(2 * map.target_r_vectors[1, target_index] * off_grid_k) for
            target_index in axes(materialized, 3)
        )
        @test off_grid_materialized ≈ off_grid_oracle atol = 2eps(Float64) rtol = 2eps(Float64)

        predivided = MDRS_ME.materialize_replica_component(
            reshape(ComplexF64[1.0, 1.0], 1, 1, 2),
            [2, 4],
            map,
            MDRS_ME.PredividedReplicaValues(),
        )
        @test vec(predivided) == ComplexF64[0.5, 1.0, 0.5]
    end
end

@testset "multi-orbital pair-dependent MDRS matches an independent scalar oracle" begin
    r_vectors = [0 1; 0 0; 0 0]
    degeneracies = [2, 4]
    translations = Array{Vector{NTuple{3, Int}}, 3}(undef, 2, 2, 2)
    for left in 1:2, right in 1:2
        translations[left, right, 1] = [(0, 0, 0)]
    end
    translations[1, 1, 2] = [(-2, 0, 0), (0, 0, 0)]
    translations[1, 2, 2] = [(-2, 0, 0)]
    translations[2, 1, 2] = [(0, 0, 0)]
    translations[2, 2, 2] = [(-2, 0, 0), (0, 0, 0)]
    map = MDRS_ME.real_space_replica_map_from_wsvec(r_vectors, degeneracies, translations)
    raw = Array{ComplexF64, 3}(undef, 2, 2, 2)
    raw[:, :, 1] = ComplexF64[2 4; 6 8]
    raw[:, :, 2] = ComplexF64[12 16; 20 24]
    materialized = MDRS_ME.materialize_replica_component(
        raw,
        degeneracies,
        map,
        MDRS_ME.SerializedWannier90ReplicaValues(),
    )

    function input_fourier(kpoint)
        value = zeros(ComplexF64, 2, 2)
        for source_index in axes(raw, 3)
            value .+=
                raw[:, :, source_index] .*
                (cispi(2 * r_vectors[1, source_index] * kpoint) / degeneracies[source_index])
        end
        return value
    end
    function independent_oracle(kpoint)
        value = zeros(ComplexF64, 2, 2)
        for left in 1:2, right in 1:2, source_index in axes(raw, 3)
            pair_images = translations[left, right, source_index]
            for translation in pair_images
                physical_r = r_vectors[1, source_index] + translation[1]
                value[left, right] +=
                    raw[left, right, source_index] /
                    (degeneracies[source_index] * length(pair_images)) *
                    cispi(2 * physical_r * kpoint)
            end
        end
        return value
    end
    function materialized_fourier(kpoint)
        value = zeros(ComplexF64, 2, 2)
        for target_index in axes(materialized, 3)
            value .+=
                materialized[:, :, target_index] .*
                cispi(2 * map.target_r_vectors[1, target_index] * kpoint)
        end
        return value
    end

    grid_errors = ComplexF64[]
    for kpoint in (0.0, 0.5)
        append!(grid_errors, vec(materialized_fourier(kpoint) .- input_fourier(kpoint)))
    end
    off_grid = 0.173
    oracle = independent_oracle(off_grid)
    interpolated = materialized_fourier(off_grid)
    errors = vec(interpolated .- oracle)
    reference = vec(oracle)
    absolute_errors = abs.(errors)
    relative_errors = absolute_errors ./ max.(abs.(reference), eps(Float64))
    metrics = (
        max_abs = maximum(absolute_errors; init = 0.0),
        max_rel = maximum(relative_errors; init = 0.0),
        relative_l2 = sqrt(sum(abs2, errors)) / max(sqrt(sum(abs2, reference)), eps(Float64)),
        nan_inf = count(value -> !isfinite(value), interpolated),
        q_grid_max_abs = maximum(abs, grid_errors; init = 0.0),
    )
    @info "multi-orbital MDRS scalar-oracle metrics" metrics
    @test metrics.q_grid_max_abs <= 32eps(Float64)
    @test metrics.max_abs <= 32eps(Float64)
    @test metrics.max_rel <= 32eps(Float64)
    @test metrics.relative_l2 <= 32eps(Float64)
    @test metrics.nan_inf == 0
    @test maximum(abs, interpolated .- input_fourier(off_grid); init = 0.0) > 1.0e-3
    @test length(map.images[1, 1, 2]) == 2
    @test length(map.images[1, 2, 2]) == 1
end
