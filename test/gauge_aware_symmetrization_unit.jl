if !isdefined(Main, :BandPublicSchemaTestSupport)
    include(joinpath(@__DIR__, "BandPublicSchemaTestSupport.jl"))
end

using LinearAlgebra
using SHA
using Test
import JSON3

const GAUGE_SYMMETRIZATION = WannierNLQG.Symmetrization
const GAUGE_IO = WannierNLQG.IO

function deterministic_unitary(angle, phase)
    return ComplexF64[
        cos(angle) -sin(angle) * cis(phase)
        sin(angle) * cis(-phase) cos(angle)
    ]
end

function gauge_aware_fixture()
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        false,
    )
    theta_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        true,
    )
    kpoints = [0.25 0.0 0.0; 0.75 0.0 0.0]
    gauges = zeros(ComplexF64, 2, 2, 2)
    gauges[:, :, 1] .= deterministic_unitary(0.31, 0.27)
    gauges[:, :, 2] .= deterministic_unitary(-0.22, 0.49)
    sewing = zeros(ComplexF64, 2, 2, 2, 2)
    for source in 1:2
        sewing[:, :, 1, source] .= Matrix{ComplexF64}(I, 2, 2)
    end
    sewing[:, :, 2, 1] .= gauges[:, :, 2] * transpose(gauges[:, :, 1])
    sewing[:, :, 2, 2] .= gauges[:, :, 1] * transpose(gauges[:, :, 2])
    reciprocal_shifts = zeros(Int, 3, 2, 2)
    reciprocal_shifts[1, 2, :] .= -1
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.2",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (2, 1, 1),
        kpoints,
        zeros(2, 2),
        [identity_operation, theta_operation],
        [1 2; 2 1],
        reciprocal_shifts,
        sewing,
        ones(Int, 2, 2),
        [1],
        ones(Int, 2),
        [1, 2],
    )
    chk = GAUGE_IO.WannierCHK(
        2,
        2,
        2,
        (2, 1, 1),
        kpoints,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        zeros(2, 3),
        gauges,
    )
    return (; representation, chk)
end

@testset "k-point bijection and mixed-source provenance" begin
    extension, _ = GAUGE_SYMMETRIZATION._load_symmetrization_extension!()
    source = [0.0 0.0 0.0; 0.5 0.0 0.0]
    target = [0.5 0.0 0.0; 1.0 0.0 0.0]
    @test Base.invokelatest(extension._match_gauge_aware_kpoints, source, target) == [2, 1]
    ambiguous = [0.0 0.0 0.0; 1.0 0.0 0.0]
    @test_throws ArgumentError Base.invokelatest(
        extension._match_gauge_aware_kpoints,
        source,
        ambiguous,
    )

    fixture = gauge_aware_fixture()
    merge!(fixture.representation.input_sha256, Dict("POSCAR" => "p", "WAVECAR" => "w"))
    hashes = Dict(
        "poscar" => "p",
        "wavecar" => "w",
        "source_win" => "win",
        "target_win" => "win",
        "source_eig" => "e",
        "target_eig" => "e",
        "source_mmn" => "mmn",
        "target_mmn" => "mmn",
    )
    eig = GAUGE_IO.WannierEIG(2, 2, zeros(2, 2))
    attached = Base.invokelatest(
        extension._validate_and_attach_gauge_aware_eig!,
        fixture.representation,
        eig,
        "e",
    )
    @test attached.passed && attached.augmented && attached.maximum_error == 0.0
    @test Base.invokelatest(extension._matching_gauge_aware_wannier_inputs, hashes)
    @test Base.invokelatest(
        extension._matching_gauge_aware_representation_inputs,
        hashes,
        fixture.representation,
    )
    hashes["target_mmn"] = "mixed"
    @test !Base.invokelatest(extension._matching_gauge_aware_wannier_inputs, hashes)
    hashes["target_mmn"] = "mmn"
    hashes["wavecar"] = "mixed"
    @test !Base.invokelatest(
        extension._matching_gauge_aware_representation_inputs,
        hashes,
        fixture.representation,
    )
end

@testset "Hamiltonian-only public workflow publishes HR and HOLD" begin
    fixture_root = joinpath(@__DIR__, "..", "examples", "symmetrization", "fixture", "inputs")
    mktempdir() do directory
        poscar = joinpath(directory, "POSCAR")
        wavecar = joinpath(directory, "WAVECAR")
        write(poscar, "synthetic POSCAR provenance\n")
        write(wavecar, "synthetic WAVECAR provenance\n")
        eig_file = joinpath(fixture_root, "synthetic.eig")
        digest(path) =
            open(path, "r") do io
                bytes2hex(SHA.sha256(io))
            end
        identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
            Matrix{Int}(I, 3, 3),
            zeros(3),
            Matrix{Float64}(I, 3, 3),
            false,
        )
        theta_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
            Matrix{Int}(I, 3, 3),
            zeros(3),
            Matrix{Float64}(I, 3, 3),
            true,
        )
        representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
            "1.2",
            :synthetic,
            false,
            Matrix{Float64}(I, 3, 3),
            2.0pi .* Matrix{Float64}(I, 3, 3),
            (1, 1, 1),
            zeros(1, 3),
            reshape([0.5], 1, 1),
            [identity_operation, theta_operation],
            reshape([1, 1], 2, 1),
            zeros(Int, 3, 2, 1),
            ones(ComplexF64, 1, 1, 2, 1),
            ones(Int, 1, 1),
            [1],
            [1],
            [1];
            input_sha256 = Dict(
                "POSCAR" => digest(poscar),
                "WAVECAR" => digest(wavecar),
                "EIG" => digest(eig_file),
            ),
        )
        prepared = BandPublicSchemaTestSupport.prepare_public_band_fixture(
            representation;
            directory,
            eig_file,
            projection_basis = BandPublicSchemaTestSupport.single_site_s_basis(),
        )
        representation = prepared.representation
        representation_file = joinpath(directory, "representation.h5")
        WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
            representation_file,
            representation,
        )
        output_root = joinpath(directory, "output")
        result = GAUGE_SYMMETRIZATION.symmetrize_existing_wannier_model(
            GAUGE_SYMMETRIZATION.GaugeAwareSymmetrizationConfig(
                representation_hdf5_file = representation_file,
                poscar_file = poscar,
                wavecar_file = wavecar,
                source_win_file = joinpath(fixture_root, "synthetic.win"),
                source_eig_file = eig_file,
                source_mmn_file = joinpath(fixture_root, "synthetic.mmn"),
                win_file = joinpath(fixture_root, "synthetic.win"),
                eig_file = eig_file,
                mmn_file = joinpath(fixture_root, "synthetic.mmn"),
                chk_file = joinpath(fixture_root, "synthetic.chk"),
                tb_file = joinpath(fixture_root, "synthetic_tb.dat"),
                output_root = output_root,
                require_oracle = false,
                complete_position = false,
            ),
        )
        @test result.status == GAUGE_SYMMETRIZATION.HOLD_POSITION_PENDING
        @test JSON3.read(read(result.artifacts["validation_json"], String))["schema_version"] ==
              "1.0"
        @test isfile(result.artifacts["c00_hr"])
        @test !isfile(joinpath(output_root, "outputs", "C00", "wannier90_sym_tb.dat"))
        @test GAUGE_IO.read_wannier_hr(result.artifacts["c00_hr"]).num_orbitals == 1

        full_output_root = joinpath(directory, "full-output")
        full_result = GAUGE_SYMMETRIZATION.symmetrize_existing_wannier_model(
            GAUGE_SYMMETRIZATION.GaugeAwareSymmetrizationConfig(
                representation_hdf5_file = representation_file,
                poscar_file = poscar,
                wavecar_file = wavecar,
                source_win_file = joinpath(fixture_root, "synthetic.win"),
                source_eig_file = eig_file,
                source_mmn_file = joinpath(fixture_root, "synthetic.mmn"),
                win_file = joinpath(fixture_root, "synthetic.win"),
                eig_file = eig_file,
                mmn_file = joinpath(fixture_root, "synthetic.mmn"),
                chk_file = joinpath(fixture_root, "synthetic.chk"),
                tb_file = joinpath(fixture_root, "synthetic_tb.dat"),
                output_root = full_output_root,
                require_oracle = false,
                complete_position = true,
                materialization_variants = (:C00, :C01, :C10, :C11),
            ),
        )
        @test full_result.status == GAUGE_SYMMETRIZATION.PASS
        @test isfile(full_result.artifacts["c00_tb"])
        @test isfile(full_result.artifacts["c11_tb"])
        @test isfile(full_result.artifacts["c01_tb"])
        @test isfile(full_result.artifacts["c10_tb"])
        @test isfile(full_result.artifacts["c00_operator_bundle_hdf5"])
        @test isfile(full_result.artifacts["c11_operator_bundle_hdf5"])
        @test isfile(full_result.artifacts["c01_operator_bundle_hdf5"])
        @test isfile(full_result.artifacts["c10_operator_bundle_hdf5"])
        @test all(
            variant -> isfile(full_result.artifacts["$(lowercase(String(variant)))_hr"]),
            (:C00, :C01, :C10, :C11),
        )
        @test all(event -> event.passed, full_result.threshold_events)
        @test GAUGE_IO.read_real_space_operator_bundle_manifest(
            full_result.artifacts["c00_operator_bundle_hdf5"],
        ).production_eligible
        c00 = GAUGE_IO.read_wannier_tb(full_result.artifacts["c00_tb"])
        c01 = GAUGE_IO.read_wannier_tb(full_result.artifacts["c01_tb"])
        c10 = GAUGE_IO.read_wannier_tb(full_result.artifacts["c10_tb"])
        c11 = GAUGE_IO.read_wannier_tb(full_result.artifacts["c11_tb"])
        @test c00.r_vectors == c10.r_vectors
        @test c00.r_degeneracies == c10.r_degeneracies
        @test c00.hamiltonian_r == c10.hamiltonian_r
        @test c01.r_vectors == c11.r_vectors
        @test c01.r_degeneracies == c11.r_degeneracies
        @test c01.hamiltonian_r == c11.hamiltonian_r
        c01_manifest = GAUGE_IO.read_real_space_operator_bundle_manifest(
            full_result.artifacts["c01_operator_bundle_hdf5"],
        )
        c10_manifest = GAUGE_IO.read_real_space_operator_bundle_manifest(
            full_result.artifacts["c10_operator_bundle_hdf5"],
        )
        @test c01_manifest.wannier_center_policy == :keep_input
        @test c01_manifest.real_space_replica_policy == :minimum_distance
        @test c10_manifest.wannier_center_policy == :symmetrize
        @test c10_manifest.real_space_replica_policy == :input

        warning_representation = deepcopy(representation)
        warning_representation.sewing_matrices[1, 1, 1, 1] = 1.001 + 0.0im
        warning_representation_file = joinpath(directory, "warning-representation.h5")
        WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
            warning_representation_file,
            warning_representation,
        )
        warning_output_root = joinpath(directory, "warning-output")
        warning_config = GAUGE_SYMMETRIZATION.GaugeAwareSymmetrizationConfig(
            representation_hdf5_file = warning_representation_file,
            poscar_file = poscar,
            wavecar_file = wavecar,
            source_win_file = joinpath(fixture_root, "synthetic.win"),
            source_eig_file = eig_file,
            source_mmn_file = joinpath(fixture_root, "synthetic.mmn"),
            win_file = joinpath(fixture_root, "synthetic.win"),
            eig_file = eig_file,
            mmn_file = joinpath(fixture_root, "synthetic.mmn"),
            chk_file = joinpath(fixture_root, "synthetic.chk"),
            tb_file = joinpath(fixture_root, "synthetic_tb.dat"),
            output_root = warning_output_root,
            require_oracle = false,
            complete_position = true,
            threshold_policy = :record_and_continue,
        )
        warning_result = GAUGE_SYMMETRIZATION.symmetrize_existing_wannier_model(warning_config)
        @test warning_result.status == GAUGE_SYMMETRIZATION.PASS_WITH_WARNINGS
        @test any(event -> !event.passed, warning_result.threshold_events)
        @test isfile(warning_result.artifacts["c00_tb"])
        @test isfile(warning_result.artifacts["c11_tb"])
        @test !haskey(warning_result.artifacts, "c01_tb")
        @test !haskey(warning_result.artifacts, "c10_tb")
        @test isfile(warning_result.artifacts["c00_operator_bundle_hdf5"])
        @test GAUGE_IO.read_real_space_operator_bundle_manifest(
            warning_result.artifacts["c00_operator_bundle_hdf5"],
        ).production_eligible

        strict_output_root = joinpath(directory, "strict-output")
        strict_result = GAUGE_SYMMETRIZATION.symmetrize_existing_wannier_model(
            GAUGE_SYMMETRIZATION.GaugeAwareSymmetrizationConfig(
                representation_hdf5_file = warning_representation_file,
                poscar_file = poscar,
                wavecar_file = wavecar,
                source_win_file = joinpath(fixture_root, "synthetic.win"),
                source_eig_file = eig_file,
                source_mmn_file = joinpath(fixture_root, "synthetic.mmn"),
                win_file = joinpath(fixture_root, "synthetic.win"),
                eig_file = eig_file,
                mmn_file = joinpath(fixture_root, "synthetic.mmn"),
                chk_file = joinpath(fixture_root, "synthetic.chk"),
                tb_file = joinpath(fixture_root, "synthetic_tb.dat"),
                output_root = strict_output_root,
                require_oracle = false,
                complete_position = true,
                threshold_policy = :fail_stop,
            ),
        )
        @test strict_result.status == GAUGE_SYMMETRIZATION.FAILED_BAND_REPRESENTATION
        @test any(event -> !event.passed, strict_result.threshold_events)
        @test !isfile(joinpath(strict_output_root, "outputs", "C00", "wannier90_sym_tb.dat"))

        base_config = GAUGE_SYMMETRIZATION.GaugeAwareSymmetrizationConfig(
            representation_hdf5_file = representation_file,
            poscar_file = poscar,
            wavecar_file = wavecar,
            source_win_file = joinpath(fixture_root, "synthetic.win"),
            source_eig_file = eig_file,
            source_mmn_file = joinpath(fixture_root, "synthetic.mmn"),
            win_file = joinpath(fixture_root, "synthetic.win"),
            eig_file = eig_file,
            mmn_file = joinpath(fixture_root, "synthetic.mmn"),
            chk_file = joinpath(fixture_root, "synthetic.chk"),
            tb_file = joinpath(fixture_root, "synthetic_tb.dat"),
            output_root = joinpath(directory, "invalid-variants"),
            require_oracle = false,
            materialization_variants = (:C00, :C00),
        )
        @test_throws ArgumentError Base.invokelatest(
            GAUGE_SYMMETRIZATION._load_symmetrization_extension!()[1]._validate_gauge_aware_config,
            base_config,
        )
    end
end

@testset "actual CHK-gauge sewing and antiunitary projection" begin
    extension, _ = GAUGE_SYMMETRIZATION._load_symmetrization_extension!()
    fixture = gauge_aware_fixture()
    actual = Base.invokelatest(
        extension._build_actual_wannier_sewing,
        fixture.representation,
        fixture.chk,
        [1, 2],
    )
    @test actual.maximum_semiunitarity <= 1.0e-14
    @test actual.maximum_closure <= 1.0e-14
    @test actual.maximum_unitarity <= 1.0e-14
    @test maximum(actual.maximum_group_law_residuals) <= 1.0e-14
    for source in 1:2, operation in 1:2
        @test actual.sewing[:, :, operation, source] ≈ Matrix{ComplexF64}(I, 2, 2)
    end

    raw = zeros(ComplexF64, 2, 2, 2)
    raw[:, :, 1] .= ComplexF64[1.0 0.2im; -0.2im 2.0]
    raw[:, :, 2] .= ComplexF64[1.4 0.1 + 0.3im; 0.1 - 0.3im 1.7]
    projected = Base.invokelatest(
        extension._project_gauge_aware_hamiltonian,
        raw,
        actual.sewing,
        actual.operation_map,
        fixture.representation.operations,
    )
    repeated = Base.invokelatest(
        extension._project_gauge_aware_hamiltonian,
        projected,
        actual.sewing,
        actual.operation_map,
        fixture.representation.operations,
    )
    @test repeated ≈ projected atol = 1.0e-14 rtol = 0.0
    unitary, antiunitary = Base.invokelatest(
        extension._hamiltonian_covariance_residuals,
        projected,
        actual.sewing,
        actual.operation_map,
        fixture.representation.operations,
    )
    @test unitary <= 1.0e-14
    @test antiunitary <= 1.0e-14

    transformed_gauges = copy(fixture.chk.v_matrix)
    transformed_gauges[:, :, 1] *= deterministic_unitary(0.17, -0.2)
    transformed_gauges[:, :, 2] *= deterministic_unitary(-0.29, 0.4)
    transformed_chk = GAUGE_IO.WannierCHK(
        2,
        2,
        2,
        (2, 1, 1),
        fixture.chk.kpt_red,
        fixture.chk.real_lattice,
        fixture.chk.recip_lattice,
        fixture.chk.wannier_centers_cart,
        transformed_gauges,
    )
    transformed_actual = Base.invokelatest(
        extension._build_actual_wannier_sewing,
        fixture.representation,
        transformed_chk,
        [1, 2],
    )
    @test transformed_actual.maximum_closure <= 1.0e-14
    @test transformed_actual.maximum_unitarity <= 1.0e-14
end

@testset "nonclosed target subspace is a hard failure" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGSymmetrizationExt)
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        false,
    )
    c2_rotation = Diagonal(Int[-1, -1, 1]) |> Matrix
    c2_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        c2_rotation,
        zeros(3),
        Matrix{Float64}(c2_rotation),
        false,
    )
    swap = ComplexF64[0 0 1; 0 1 0; 1 0 0]
    sewing = zeros(ComplexF64, 3, 3, 2, 1)
    sewing[:, :, 1, 1] .= Matrix{ComplexF64}(I, 3, 3)
    sewing[:, :, 2, 1] .= swap
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.2",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        zeros(1, 3),
        zeros(3, 1),
        [identity_operation, c2_operation],
        ones(Int, 2, 1),
        zeros(Int, 3, 2, 1),
        sewing,
        ones(Int, 3, 1),
        [1],
        [1],
        [1],
    )
    gauge = reshape(ComplexF64[1, 0, 0, 0, 1, 0], 3, 2, 1)
    chk = GAUGE_IO.WannierCHK(
        3,
        2,
        1,
        (1, 1, 1),
        zeros(1, 3),
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        zeros(2, 3),
        gauge,
    )
    actual = Base.invokelatest(extension._build_actual_wannier_sewing, representation, chk, [1])
    @test actual.maximum_closure > 0.9
    @test actual.maximum_unitarity > 0.9
end

@testset "input replica Fourier and HR boundaries" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGSymmetrizationExt)
    fixture = gauge_aware_fixture()
    values_q = zeros(ComplexF64, 2, 2, 2)
    values_q[:, :, 1] .= ComplexF64[1 0.2im; -0.2im 2]
    values_q[:, :, 2] .= ComplexF64[2 0.1; 0.1 3]
    r_vectors = Int[0 1; 0 0; 0 0]
    values_r, roundtrip = Base.invokelatest(
        extension._gauge_aware_q_to_input_replicas,
        values_q,
        fixture.chk,
        r_vectors,
        ones(Int, 2),
    )
    @test roundtrip <= 1.0e-14
    @test Base.invokelatest(
        extension._gauge_aware_r_to_q,
        values_r,
        r_vectors,
        ones(Int, 2),
        fixture.chk.kpt_red,
    ) ≈ values_q atol = 1.0e-14 rtol = 0.0

    mktempdir() do directory
        source = GAUGE_IO.WannierHR(2, 2, ones(Int, 2), r_vectors, values_r)
        filename = joinpath(directory, "synthetic_hr.dat")
        @test GAUGE_IO.write_wannier_hr(filename, source) == abspath(filename)
        restored = GAUGE_IO.read_wannier_hr(filename)
        @test restored.r_vectors == source.r_vectors
        @test restored.r_degeneracies == source.r_degeneracies
        @test restored.hamiltonian_r ≈ source.hamiltonian_r atol = 1.0e-13 rtol = 0.0
    end
end

@testset "MMN endpoint projection is covariant under k-dependent Wannier gauge" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGSymmetrizationExt)
    fixture = gauge_aware_fixture()
    actual = Base.invokelatest(
        extension._build_actual_wannier_sewing,
        fixture.representation,
        fixture.chk,
        [1, 2],
    )
    neighbors = Int[2 1; 2 1]
    reciprocal_shifts = zeros(Int, 3, 2, 2)
    reciprocal_shifts[1, 2, 1] = -1
    reciprocal_shifts[1, 1, 2] = 1
    raw_links = zeros(ComplexF64, 2, 2, 2, 2)
    raw_links[:, :, 1, 1] .= ComplexF64[0.9 0.1im; 0.2 0.8]
    raw_links[:, :, 2, 1] .= ComplexF64[0.7 -0.2im; 0.05 0.85]
    raw_links[:, :, 1, 2] .= ComplexF64[0.8 0.1 + 0.1im; -0.1im 0.75]
    raw_links[:, :, 2, 2] .= ComplexF64[0.88 -0.07; 0.03im 0.81]
    dft_links = similar(raw_links)
    for source in 1:2, neighbor in 1:2
        target = neighbors[neighbor, source]
        dft_links[:, :, neighbor, source] .=
            fixture.chk.v_matrix[:, :, source] *
            raw_links[:, :, neighbor, source] *
            fixture.chk.v_matrix[:, :, target]'
    end
    mmn = GAUGE_IO.WannierMMN(2, 2, 2, dft_links, neighbors, reciprocal_shifts)
    recovered_links = Base.invokelatest(extension._wannier_gauge_links, fixture.chk, mmn)
    @test recovered_links ≈ raw_links atol = 1.0e-14 rtol = 0.0
    edge_map = Base.invokelatest(
        extension._gauge_aware_edge_map,
        fixture.chk,
        mmn,
        actual.operation_map,
        fixture.representation.operations,
    )
    projected = Base.invokelatest(
        extension._project_gauge_aware_links,
        raw_links,
        mmn,
        actual.sewing,
        actual.operation_map,
        edge_map,
        fixture.representation.operations,
    )

    rotations = [deterministic_unitary(0.13, 0.21), deterministic_unitary(-0.26, -0.37)]
    transformed_gauges = copy(fixture.chk.v_matrix)
    for kpoint in 1:2
        transformed_gauges[:, :, kpoint] *= rotations[kpoint]
    end
    transformed_chk = GAUGE_IO.WannierCHK(
        2,
        2,
        2,
        (2, 1, 1),
        fixture.chk.kpt_red,
        fixture.chk.real_lattice,
        fixture.chk.recip_lattice,
        fixture.chk.wannier_centers_cart,
        transformed_gauges,
    )
    transformed_actual = Base.invokelatest(
        extension._build_actual_wannier_sewing,
        fixture.representation,
        transformed_chk,
        [1, 2],
    )
    transformed_links = similar(raw_links)
    for source in 1:2, neighbor in 1:2
        target = neighbors[neighbor, source]
        transformed_links[:, :, neighbor, source] .=
            rotations[source]' * raw_links[:, :, neighbor, source] * rotations[target]
    end
    transformed_projected = Base.invokelatest(
        extension._project_gauge_aware_links,
        transformed_links,
        mmn,
        transformed_actual.sewing,
        transformed_actual.operation_map,
        edge_map,
        fixture.representation.operations,
    )
    for source in 1:2, neighbor in 1:2
        target = neighbors[neighbor, source]
        expected = rotations[source]' * projected[:, :, neighbor, source] * rotations[target]
        @test transformed_projected[:, :, neighbor, source] ≈ expected atol = 2.0e-14 rtol = 0.0
    end
end

@testset "gauge-aware path is isolated from ideal and SAWF entrypoints" begin
    component_root = joinpath(@__DIR__, "..", "ext", "WannierNLQGSymmetrizationExt", "components")
    source = join(
        read(joinpath(component_root, path), String) for path in (
            joinpath("validation", "GaugeAwareValidation.jl"),
            joinpath("sewing", "GaugeAwareSewing.jl"),
            joinpath("projection", "GaugeAwareProjection.jl"),
            joinpath("persistence", "GaugeAwarePersistence.jl"),
            joinpath("workflow", "GaugeAwareWorkflow.jl"),
        )
    )
    for forbidden in (
        "build_wannier_projection_basis(",
        "symmetrize_wannier_operators(",
        "construct_symmetry_adapted_wannier_functions(",
    )
        @test !occursin(forbidden, source)
    end
end
