using Test
using WannierNLQG

const PRP_CORE = WannierNLQG.Core
const PRP_IO = WannierNLQG.IO
const PRP_RUNTIME = WannierNLQG.Runtime

function projector_output_is_finite(path)
    values = Float64[]
    for token in split(read(path, String))
        parsed = tryparse(Float64, token)
        parsed === nothing || push!(values, parsed)
    end
    return !isempty(values) && all(isfinite, values)
end

function projector_test_bundle_geometry(model, operators)
    position = operators[PRP_CORE.REAL_SPACE_POSITION]
    home = only(
        findall(
            index -> all(iszero, @view(position.r_vectors[:, index])),
            axes(position.r_vectors, 2),
        ),
    )
    centers = zeros(Float64, size(position.data, 1), 3)
    for orbital in axes(centers, 1), direction in 1:3
        centers[orbital, direction] =
            real(position.data[orbital, orbital, direction, home] / model.r_degeneracies[home])
    end
    fractional = centers * inv(Matrix{Float64}(model.lattice))
    return Dict(
        "wannier_center_policy" => "symmetrize",
        "real_space_replica_policy" => "input",
        "production_eligible" => true,
        "minimum_distance_materialized" => false,
        "mp_grid" => [1, 1, 1],
        "wannier_center_tolerance" => 1.0e-8,
        "wigner_seitz_tolerance" => 1.0e-5,
        "wigner_seitz_search_size" => 3,
        "raw_wannier_centers_cartesian" => centers,
        "raw_wannier_centers_fractional" => fractional,
        "final_wannier_centers_cartesian" => centers,
        "final_wannier_centers_fractional" => fractional,
        "center_alignment_lattice_shifts" => zeros(Int, size(centers)),
        "replica_mapping_sha256" => repeat("0", 64),
    )
end

function write_exact_projector_test_bundle(directory, model_file)
    model = PRP_IO.read_wannier_tb(model_file)
    vector = zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3, model.num_r_vectors)
    tensor = zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3, 3, model.num_r_vectors)
    operators = Dict{PRP_CORE.RealSpaceOperatorKind, PRP_CORE.RealSpaceOperator}(
        PRP_CORE.REAL_SPACE_HAMILTONIAN => PRP_CORE.RealSpaceOperator(
            PRP_CORE.RealSpaceOperatorSymmetrySpec(PRP_CORE.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
            model.r_vectors,
            model.hamiltonian_r,
        ),
        PRP_CORE.REAL_SPACE_POSITION => PRP_CORE.RealSpaceOperator(
            PRP_CORE.RealSpaceOperatorSymmetrySpec(PRP_CORE.REAL_SPACE_POSITION, 1, -1, 1),
            model.r_vectors,
            model.position_r,
        ),
        PRP_CORE.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR => PRP_CORE.RealSpaceOperator(
            PRP_CORE.RealSpaceOperatorSymmetrySpec(
                PRP_CORE.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
                2,
                1,
                1,
            ),
            model.r_vectors,
            tensor,
        ),
    )
    for (kind, inversion, time_reversal) in (
        (PRP_CORE.REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION, -1, 1),
        (PRP_CORE.REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP, 1, -1),
        (PRP_CORE.REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP, 1, -1),
    )
        operators[kind] = PRP_CORE.RealSpaceOperator(
            PRP_CORE.RealSpaceOperatorSymmetrySpec(kind, 1, inversion, time_reversal),
            model.r_vectors,
            vector,
        )
    end
    operators[PRP_CORE.REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP] = PRP_CORE.RealSpaceOperator(
        PRP_CORE.RealSpaceOperatorSymmetrySpec(
            PRP_CORE.REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP,
            2,
            1,
            1,
        ),
        model.r_vectors,
        tensor,
    )
    path = joinpath(directory, "exact-projector-test-operators.h5")
    PRP_IO.write_real_space_operator_bundle(
        path,
        model.lattice,
        model.r_degeneracies,
        operators;
        profile = :derivative,
        paired_tb_sha256 = PRP_RUNTIME.checksum_file(model_file),
        provenance = Dict(
            "derivative_overlap_source" => "wannier90_uIu",
            "derivative_overlap_completeness" => "full_hilbert_space",
            "derivative_overlap_source_sha256" => repeat("a", 64),
            "derivative_overlap_algorithm_version" =>
                PRP_IO.FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION,
        ),
        geometry = projector_test_bundle_geometry(model, operators),
    )
    return path
end

function projector_path_test_config(directory, model_file, bundle_file, task, convention)
    common = (
        tasks = [task],
        model_file,
        real_space_operator_bundle_file = bundle_file,
        output_root = directory,
        system_name = "projector_registered_path",
        k_mesh = (2, 2),
        fourier_backend = "direct",
        photon_energies = [0.2],
        fermi_energy = -2.5,
        tensor_indices = (2, 2, 2),
        finite_difference_step = 1.0e-4,
        wannier_center_convention = convention,
        progress_enabled = false,
    )
    if task[1] == "SCK"
        return WannierNLQG.Runtime.EffectiveTaskConfig(; common..., band_selection = (2, 1))
    elseif task[1] == "QHCK"
        return WannierNLQG.Runtime.EffectiveTaskConfig(;
            common...,
            band_selection = ([3, 4], [1, 2]),
        )
    end
    return WannierNLQG.Runtime.EffectiveTaskConfig(; common...)
end

@testset "all registered full-covariant Projector response paths" begin
    mktempdir() do directory
        isdefined(Main, :TEST_MODEL_FILE) ||
            error("runtests.jl must bind TEST_MODEL_FILE to the repository synthetic fixture")
        model_file = Main.TEST_MODEL_FILE
        bundle_file = write_exact_projector_test_bundle(directory, model_file)
        tasks = (
            ("SC", "Projector", "Integral"),
            ("SCK", "Projector", "K-slice"),
            ("QHCK", "Projector", "K-slice"),
        )
        for convention in ("Convention_I", "Convention_II"), task in tasks
            cell = joinpath(directory, "$(task[1])_$(convention)")
            result = WannierNLQG.run(
                projector_path_test_config(cell, model_file, bundle_file, task, convention),
            )
            @test !isempty(result.outputs)
            @test all(isfile, result.outputs)
            @test all(projector_output_is_finite, result.outputs)
        end
    end
end
