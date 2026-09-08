using Test
using LinearAlgebra
using HDF5
using WannierNLQG

@testset "diagnostic projection centers preserve discrete symmetry" begin
    projection = WannierNLQG.WannierProjection
    operation_type = WannierNLQG.SymmetryFoundation.SymmetryOperation
    identity_rotation = Matrix{Int}(I, 3, 3)
    operations = [
        operation_type(identity_rotation, zeros(3), Float64.(identity_rotation)),
        operation_type(-identity_rotation, zeros(3), -Float64.(identity_rotation)),
    ]
    exact = [0.2 0.8; 0.0 0.0; 0.0 0.0]
    perturbed = copy(exact)
    perturbed[1, 2] += 1.0e-7
    frozen = copy(perturbed)
    records = NamedTuple[]
    @test_throws ArgumentError projection._map_projection_centers(
        perturbed,
        operations,
        1.0e-8;
        construction_policy = :strict,
    )
    indices, shifts = projection._map_projection_centers(
        perturbed,
        operations,
        1.0e-8;
        construction_policy = :diagnostic,
        mapping_diagnostics = records,
    )
    @test indices == [1 2; 2 1]
    @test shifts[:, :, 2] == [-1 -1; 0 0; 0 0]
    @test perturbed == frozen
    @test_throws ArgumentError projection._map_projection_centers(
        reshape([0.25, 0.0, 0.0], 3, 1),
        operations,
        1.0e-8;
        construction_policy = :diagnostic,
    )
    singleton_records = NamedTuple[]
    projection._map_projection_centers(
        zeros(3, 1),
        operations,
        1.0e-8;
        construction_policy = :diagnostic,
        mapping_diagnostics = singleton_records,
    )
    @test all(record -> record.margin === nothing, singleton_records)
    @test count(record -> record.result == "FAIL", records) == 2
    @test all(record -> record.threshold == 1.0e-8, records)
    @test all(record -> record.margin > 0.0, records)
    @test any(record -> record.action == "CONTINUE_DIAGNOSTIC", records)
    @test projection._map_projection_centers(
        exact,
        operations,
        1.0e-8;
        construction_policy = :diagnostic,
    ) == projection._map_projection_centers(
        exact,
        operations,
        1.0e-8;
        construction_policy = :strict,
    )
    ambiguous = [0.0 0.5; 0.0 0.0; 0.0 0.0]
    quarter = [operation_type(identity_rotation, [0.25, 0.0, 0.0], Float64.(identity_rotation))]
    @test_throws ArgumentError projection._map_projection_centers(
        ambiguous,
        quarter,
        1.0e-8;
        construction_policy = :diagnostic,
    )
    @test_throws ArgumentError projection._map_projection_centers(
        fill(NaN, 3, 1),
        operations,
        1.0e-8;
        construction_policy = :diagnostic,
    )
    invalid_shifts = copy(shifts)
    invalid_shifts[1, 1, 2] += 1
    @test_throws ArgumentError projection._validate_projection_center_group_mapping(
        operations,
        indices,
        invalid_shifts,
        1.0e-8,
    )
end

isdefined(Main, :QEPAWMatrixElementsTestSupport) ||
    include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
using .QEPAWMatrixElementsTestSupport

@testset "diagnostic PAW capsule readback retains quality and integrity" begin
    W = WannierNLQG.Wannierization
    extension = first(W._load_wannierization_extension!()).PAWMatrixElements
    mktempdir() do directory
        fixture = write_qe_paw_fixture(directory)
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            band_range = 1:1,
            include_time_reversal = false,
        )
        config = W.SymmetryCovariantWavefunctionPreparationConfig(
            source = source,
            wavefunction_gauge_backend = W.StarCovariantPAWGauge(
                buffer_policy = W.ClosureDrivenBandBuffer(max_extra_bands = 0),
            ),
            construction_policy = :diagnostic,
            output_hdf5 = joinpath(directory, "diagnostic.h5"),
            target_band_count = 1,
        )
        result = W.prepare_symmetry_covariant_wavefunctions(config)
        @test result.status == :DIAGNOSTIC_ONLY
        path = joinpath(directory, "diagnostic.diagnostic-only.h5")
        @test isfile(path)
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            path;
            construction_policy = :strict,
        )
        restored = Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            path;
            construction_policy = :diagnostic,
            source,
        )
        @test restored.status == :DIAGNOSTIC_ONLY
        @test restored.payload.source_metadata["construction_policy"] == "diagnostic"
        @test something(restored.band_frame_contract).status == "PASS"
        HDF5.h5open(path, "r") do handle
            @test !read(HDF5.attributes(handle)["production_eligible"])
        end
        maxima, contexts = Dict{String, Float64}(), Dict{String, String}()
        @test !Base.invokelatest(
            extension._star_construction_quality_gate!,
            config,
            maxima,
            contexts,
            "synthetic_covariance",
            2.0e-7,
            1.0e-7,
        )
        @test maxima["construction_synthetic_covariance_failed"] == 1.0
        @test maxima["construction_synthetic_covariance_threshold"] == 1.0e-7
        @test contexts["construction_synthetic_covariance_failed"] == "CONTINUE_DIAGNOSTIC"
        @test Base.invokelatest(
            extension._star_construction_quality_gate!,
            config,
            maxima,
            contexts,
            "synthetic_covariance",
            1.0e-8,
            1.0e-7,
        )
        @test maxima["construction_synthetic_covariance_failed"] == 1.0
        @test maxima["construction_synthetic_covariance_value"] == 2.0e-7
        @test contexts["construction_synthetic_covariance_failed"] == "CONTINUE_DIAGNOSTIC"
        @test_throws ArgumentError Base.invokelatest(
            extension._star_construction_quality_gate!,
            config,
            maxima,
            contexts,
            "synthetic_covariance",
            NaN,
            1.0e-7,
        )
        # Seal synthetic failed quality evidence into an otherwise valid capsule,
        # then exercise the public preparation/persistence chain in a fresh read.
        merge!(restored.payload.maxima, maxima)
        merge!(restored.payload.maximum_contexts, contexts)
        quality_path = joinpath(directory, "failed-quality.h5")
        Base.invokelatest(
            extension._write_star_covariant_paw_gauge_hdf5,
            quality_path,
            restored.payload;
            status = :DIAGNOSTIC_ONLY,
            root_cause = :SYNTHETIC_QUALITY_FAILURE,
            diagnostics = String[],
        )
        P = WannierNLQG.WannierProjection
        block = P.WannierProjectionBlock(
            "X",
            "s",
            zeros(3, 1),
            reshape([1], 1, 1),
            reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
            false,
        )
        basis = P.WannierProjectionBasis([block], 1, false)
        win = joinpath(directory, "diagnostic.win")
        write(win, "num_wann = 1\n")
        representation_path = joinpath(directory, "diagnostic-representation.h5")
        prepared = W.prepare_band_representation(
            W.BandRepresentationPreparationConfig(
                source = source,
                sewing_backend = W.AugmentationAwareSewing(),
                wavefunction_gauge_backend = config.wavefunction_gauge_backend,
                wavefunction_gauge_hdf5 = quality_path,
                win_file = win,
                eig_file = splitext(path)[1] * ".eig",
                projection_basis = basis,
                output_hdf5 = representation_path,
                outer_min_ev = -18.0,
                outer_max_ev = 3.5,
                frozen_min_ev = -18.0,
                frozen_max_ev = 0.5,
                num_wannier = 1,
            ),
        )
        @test prepared.status in (:PASS, :PASS_WITH_WARNINGS)
        @test any(
            diagnostic -> diagnostic.code == :GAUGE_QUALITY_DIAGNOSTIC_CONTINUE,
            prepared.diagnostics,
        )
        representation =
            WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(representation_path)
        @test representation.conventions["construction_policy"] == "diagnostic"
        @test representation.conventions["production_eligible"] == "false"
        @test representation.conventions["diagnostic_only"] == "true"
        @test occursin(
            "construction_synthetic_covariance_failed",
            representation.conventions["construction_gauge_metrics_json"],
        )
        WI = WannierNLQG.IO
        # Full six-link synthetic topology makes the one-band capsule exportable.
        mmn_path = joinpath(directory, "authority.mmn")
        amn_path = joinpath(directory, "authority.amn")
        shifts = reshape([1 -1 0 0 0 0; 0 0 1 -1 0 0; 0 0 0 0 1 -1], 3, 6, 1)
        WI.write_wannier_mmn(
            mmn_path,
            WI.WannierMMN(1, 1, 6, ones(ComplexF64, 1, 1, 6, 1), ones(Int, 6, 1), shifts),
        )
        WI.write_wannier_amn(amn_path, WI.WannierAMN(1, 1, 1, ones(ComplexF64, 1, 1, 1)))
        authority_input = W.WannierizationInputConfig(
            construction_policy = :diagnostic,
            source = source,
            sewing_backend = W.AugmentationAwareSewing(),
            wavefunction_gauge_backend = config.wavefunction_gauge_backend,
            wavefunction_gauge_hdf5 = quality_path,
            authoritative_hamiltonian = W.NativeDFTHamiltonian(),
            win_file = win,
            eig_file = splitext(path)[1] * ".eig",
            mmn_file = mmn_path,
            amn_file = amn_path,
            matrix_elements = W.ExternalWannier90Matrices(mmn_path, amn_path),
            projection_basis = basis,
            band_representation_hdf5 = representation_path,
            outer_min_ev = -18.0,
            outer_max_ev = 3.5,
            frozen_min_ev = -18.0,
            frozen_max_ev = 0.5,
            num_wannier = 1,
        )
        authority_config = W.SymmetryAdaptedWannierizationConfig(
            input = authority_input,
            solver = W.WannierizationSolverConfig(max_iterations = 2),
            checkpoint = W.WannierizationCheckpointConfig(
                checkpoint_hdf5 = joinpath(directory, "native-authority.wannierization.h5"),
            ),
            output = W.WannierizationOutputConfig(
                tb_output_formats = (:packed_hdf5, :wannier90_tb),
                write_wannier90_tb = true,
                profile = :hamiltonian_position,
            ),
        )
        operator = first(W._load_wannierization_extension!()).OperatorExport
        single_residues = Base.invokelatest(operator._mp_residue_vectors, (1, 1, 1))
        @test single_residues isa Matrix{Int}
        @test single_residues == zeros(Int, 3, 1)
        multiple_residues = Base.invokelatest(operator._mp_residue_vectors, (2, 2, 1))
        @test multiple_residues isa Matrix{Int}
        @test multiple_residues == [0 1 0 1; 0 0 1 1; 0 0 0 0]
        for (grid, kpoints, expected) in (
            ((1, 1, 1), zeros(1, 3), zeros(Int, 3, 1)),
            ((2, 1, 1), [0.0 0.0 0.0; 0.5 0.0 0.0], [-1 0 1; 0 0 0; 0 0 0]),
        )
            count = prod(grid)
            support_chk = WI.WannierCHK(
                1,
                1,
                count,
                grid,
                kpoints,
                Matrix{Float64}(I, 3, 3),
                2pi .* Matrix{Float64}(I, 3, 3),
                zeros(1, 3),
                ones(ComplexF64, 1, 1, count),
            )
            support = Base.invokelatest(
                operator._pair_wigner_seitz_support,
                support_chk;
                wigner_seitz_tolerance = 1.0e-5,
                search_size = 3,
            )
            @test support isa Matrix{Int}
            @test support == expected
        end
        eig = WI.read_wannier_eig(authority_input.eig_file)
        authority =
            Base.invokelatest(operator.authoritative_band_hamiltonian, authority_config, eig)
        @test all(isfinite, authority.matrices_ev)
        @test_throws ArgumentError Base.invokelatest(
            operator._native_completed_authoritative_band_hamiltonian,
            source,
            quality_path,
            eig;
            construction_policy = :strict,
        )
        exported = W.construct_symmetry_adapted_wannier_functions(authority_config)
        @test exported.input_summary["has_accepted_state"] == "true"
        @test exported.input_summary["production_eligible"] == "false"
        if exported.artifacts.packed_hdf5 === nothing
            @info "Native authority export diagnostics" status=exported.status gate=get(
                exported.input_summary,
                "diagnostic_export_gate_reason",
                "ABSENT",
            ) diagnostics=join((string(d.code)*": "*d.message for d in exported.diagnostics), "\n")
        end
        @test exported.artifacts.packed_hdf5 !== nothing
        @test exported.artifacts.wannier90_tb !== nothing
        if exported.artifacts.packed_hdf5 !== nothing
            HDF5.h5open(exported.artifacts.packed_hdf5, "r") do handle
                @test !read(HDF5.attributes(handle)["production_eligible"])
            end
        end
        if exported.artifacts.wannier90_tb !== nothing
            @test WI.read_wannier_tb_num_orbitals(exported.artifacts.wannier90_tb) == 1
        end
        HDF5.h5open(path, "r+") do handle
            HDF5.delete_attribute(handle, "band_frame_replay_maximum")
            HDF5.attributes(handle)["band_frame_replay_maximum"] = "9.0e-9"
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            path;
            construction_policy = :diagnostic,
            source,
        )
    end
end

@testset "diagnostic preparation keeps finite buffer and formal actions" begin
    W = WannierNLQG.Wannierization
    S = WannierNLQG.SymmetryFoundation
    extension = first(W._load_wannierization_extension!()).PAWMatrixElements
    raw = ComplexF64[1.0 1.0e-3; 1.0e-3 1.0]
    buffer = W.ClosureDrivenBandBuffer(max_extra_bands = 0)
    @test_throws ArgumentError Base.invokelatest(
        extension._star_select_buffer,
        [raw],
        [0.0, 0.2],
        1:1,
        buffer,
        1.0e-7,
    )
    selected, leakage = Base.invokelatest(
        extension._star_select_buffer,
        [raw],
        [0.0, 0.2],
        1:1,
        buffer,
        1.0e-7;
        construction_policy = :diagnostic,
    )
    @test selected == 1:1
    @test leakage ≈ 1.0e-3

    rotation = Matrix{Int}(I, 3, 3)
    operations = [
        S.SymmetryOperation(rotation, zeros(3), Float64.(rotation)),
        S.SymmetryOperation(-rotation, zeros(3), -Float64.(rotation)),
    ]
    structure = S.CrystalStructure(Float64.(rotation), ["X"], zeros(3, 1))
    point = S.PlaneWaveKPoint(zeros(3), zeros(Int, 1, 3), ones(ComplexF64, 1, 1, 1), [0.0])
    native = S.NativeWavefunctionData(
        :fixture,
        structure,
        2pi .* Float64.(rotation),
        (1, 1, 1),
        false,
        [point],
        Dict{String, String}(),
    )
    actions = Dict((1, 1) => ones(ComplexF64, 1, 1), (1, 2) => fill(cis(1.0e-4), 1, 1))
    kwargs =
        (raw_group_tolerance = 1.0e-8, formal_tolerance = 1.0e-12, correction_tolerance = 1.0e-8)
    @test_throws ArgumentError Base.invokelatest(
        extension._star_project_formal_target_actions,
        actions,
        native,
        [1],
        operations,
        ones(Int, 2, 1);
        kwargs...,
    )
    formal = Base.invokelatest(
        extension._star_project_formal_target_actions,
        actions,
        native,
        [1],
        operations,
        ones(Int, 2, 1);
        kwargs...,
        construction_policy = :diagnostic,
    )
    @test formal.initial.maximum > kwargs.raw_group_tolerance
    @test formal.correction > kwargs.correction_tolerance
    @test all(matrix -> all(isfinite, matrix), values(formal.actions))
    @test formal.residual.maximum <= kwargs.formal_tolerance
    cycle = [0 1 0; 0 0 1; 1 0 0]
    cyclic_operations = [
        S.SymmetryOperation(power, zeros(3), Float64.(power)) for
        power in (rotation, cycle, cycle * cycle)
    ]
    cyclic_actions = Dict(
        (1, 1) => ones(ComplexF64, 1, 1),
        (1, 2) => fill(cis(0.07), 1, 1),
        (1, 3) => fill(cis(0.02), 1, 1),
    )
    retained = Base.invokelatest(
        extension._star_project_formal_target_actions,
        cyclic_actions,
        native,
        [1],
        cyclic_operations,
        ones(Int, 3, 1);
        raw_group_tolerance = 1.0e-8,
        formal_tolerance = 1.0e-30,
        correction_tolerance = 1.0e-8,
        max_iterations = 1,
        construction_policy = :diagnostic,
    )
    actual = Base.invokelatest(
        extension._star_target_action_group_residual,
        retained.actions,
        native,
        [1],
        cyclic_operations,
        ones(Int, 3, 1),
        retained.product_table,
    )
    @test retained.iterations == 1
    @test retained.residual.maximum == actual.maximum
    @test all(matrix -> all(isfinite, matrix), values(retained.actions))
    actions[(1, 2)][1, 1] = NaN
    @test_throws ArgumentError Base.invokelatest(
        extension._star_project_formal_target_actions,
        actions,
        native,
        [1],
        operations,
        ones(Int, 2, 1);
        kwargs...,
        construction_policy = :diagnostic,
    )
end

@testset "diagnostic orbital and plan quality retain finite full-rank maps" begin
    P = WannierNLQG.WannierProjection
    S = WannierNLQG.SymmetryFoundation
    identity_rotation = Matrix{Float64}(I, 3, 3)
    near_rotation = copy(identity_rotation)
    near_rotation[1, 1] += 1.0e-6
    records = NamedTuple[]
    @test_throws ArgumentError P._base_orbital_rotation("d", near_rotation)
    orbital = P._base_orbital_rotation(
        "d",
        near_rotation;
        construction_policy = :diagnostic,
        mapping_diagnostics = records,
    )
    @test size(orbital) == (5, 5)
    @test all(isfinite, orbital)
    @test minimum(svdvals(orbital)) > 0.0
    @test any(record -> record.result == "FAIL", records)
    @test_throws ArgumentError P._orbital_rotation(
        "sp3",
        near_rotation,
        identity_rotation,
        identity_rotation,
    )
    hybrid = P._orbital_rotation(
        "sp3",
        near_rotation,
        identity_rotation,
        identity_rotation;
        construction_policy = :diagnostic,
        mapping_diagnostics = records,
    )
    @test size(hybrid) == (4, 4)
    @test any(
        record -> record.code == "ORBITAL_SUBSPACE_UNITARITY_RESIDUAL" && record.result == "FAIL",
        records,
    )
    @test P._base_orbital_rotation("d", identity_rotation) ==
          P._base_orbital_rotation("d", identity_rotation; construction_policy = :diagnostic)

    operations = [S.SymmetryOperation(Matrix{Int}(I, 3, 3), zeros(3), identity_rotation)]
    matrices = reshape(copy(hybrid), 4, 4, 1)
    shifts = zeros(Int, 3, 4, 1)
    @test_throws ArgumentError S.WannierSymmetryPlan(operations, matrices, shifts)
    plan = S.WannierSymmetryPlan(
        operations,
        matrices,
        shifts;
        construction_policy = :diagnostic,
        diagnostics = records,
    )
    @test plan.representation_matrices == matrices
    @test any(
        record ->
            record.code == "WANNIER_REPRESENTATION_UNITARITY_RESIDUAL" && record.result == "FAIL",
        records,
    )
    matrices[:, 1, 1] .= 0.0
    @test_throws ArgumentError S.WannierSymmetryPlan(
        operations,
        matrices,
        shifts;
        construction_policy = :diagnostic,
    )
    matrices[1, 1, 1] = NaN
    @test_throws ArgumentError S.WannierSymmetryPlan(
        operations,
        matrices,
        shifts;
        construction_policy = :diagnostic,
    )
end
@testset "native VASP full d-shell projection contract" begin
    W = WannierNLQG.Wannierization
    P = WannierNLQG.WannierProjection
    paw = first(W._load_wannierization_extension!()).PAWMatrixElements
    scale = inv(paw.VASP_PROJECTION_BOHR_ANGSTROM)
    @test [paw._vasp_projection_shell_indices("d", i) for i in 1:5] == [(2, i) for i in 1:5]
    @test_throws ArgumentError paw._vasp_projection_shell_indices("d", 6)
    @test_throws ArgumentError paw._vasp_projection_shell_indices("f", 1)
    @test_throws ArgumentError paw._build_vasp_projection_radial_spline(2, 2, scale, 400.0)
    radial = paw._build_vasp_projection_radial_spline(2, 1, scale, 400.0)
    @test radial(0.0) == 0.0
    for q in (0.5, 1.0, 3.0)
        # Exact Laplace integral of r^2 exp(-a*r) j_2(q*r), independent of quadrature.
        exact =
            8pi *
            scale^(3/2) *
            (3atan(q/scale)/q^3 - 3scale/(q^2*(scale^2+q^2)) - 2scale/(scale^2+q^2)^2)
        @test isapprox(radial(q), exact; rtol = 3e-6, atol = 1e-9)
    end
    for (shell, l, dim) in (("s", 0, 1), ("p", 1, 3), ("d", 2, 5))
        block = P.WannierProjectionBlock(
            "X",
            shell,
            zeros(3, 1),
            reshape(collect(1:dim), dim, 1),
            reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
            false,
        )
        entry = paw.VASPProjectionEntry(
            1,
            l,
            1,
            scale,
            (0.0, 0.0, 0.0),
            (0, 0, 0),
            (1.0, 0.0, 0.0),
            (0.0, 0.0, 1.0),
            1,
            (0.0, 0.0, 1.0),
            1,
        )
        contract = paw.VASPProjectionContract(v"6.4.3", 400.0, :vasp_log_simpson_spline, [entry])
        q = [0.3, 0.4, 0.5]
        r = paw._vasp_projection_radial_spline(l, 1, scale, 400.0)(norm(q))
        values = paw._vasp_projection_orbital_values(block, q, contract, entry)
        if shell == "s"
            @test values == ComplexF64[r / sqrt(4pi)]
        elseif shell == "p"
            x, y, z = q ./ norm(q)
            @test values == ComplexF64.((-im) .* r .* (sqrt(3/(4pi)) .* [z, x, y]))
        else
            @test all(isreal, values)
            @test values == paw._vasp_projection_orbital_values(block, -q, contract, entry)
            @test isapprox(sum(abs2, values), r^2*5/(4pi); rtol = 1e-14)
            axial = paw._vasp_projection_orbital_values(block, [0.0, 0.0, 1.0], contract, entry)
            @test real(axial[1]) < 0.0
            @test axial[2:5] == zeros(ComplexF64, 4)
            @test paw._vasp_projection_orbital_values(block, zeros(3), contract, entry) ==
                  zeros(ComplexF64, 5)
            rows = paw._vasp_projection_basis_rows(P.WannierProjectionBasis([block], dim, false))
            @test getproperty.(rows, :magnetic_index) == collect(1:5)
            @test all(row->row.angular_momentum==2, rows)
        end
    end
end
@testset "native PAW metric validity is separate from residual quality" begin
    W = WannierNLQG.Wannierization
    WI = WannierNLQG.IO
    ext = first(W._load_wannierization_extension!())
    paw = ext.PAWMatrixElements
    workflow = ext.WorkflowOrchestration
    metric = ComplexF64[1.001 0.0; 0.0 0.999]
    retained = copy(metric)
    @test paw._paw_require_positive_band_metric(metric) === nothing
    @test metric == retained
    @test_throws ArgumentError paw._paw_require_positive_band_metric(ComplexF64[1 2; 2 1])
    @test_throws ArgumentError paw._paw_require_positive_band_metric(ComplexF64[1 0; 0 0])
    @test_throws ArgumentError paw._paw_require_positive_band_metric(ComplexF64[NaN 0; 0 1])
    @test_throws ArgumentError paw._paw_require_positive_band_metric(ComplexF64[Inf 0; 0 1])
    thresholds = W.VASPPAWParityThresholds()
    residual, _ = paw._paw_scoped_identity_residual(metric, trues(2))
    @test residual > thresholds.generalized_norm_max_absolute
    mmn = WI.WannierMMN(
        2,
        1,
        1,
        reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1, 1),
        ones(Int, 1, 1),
        zeros(Int, 3, 1, 1),
    )
    amn = WI.WannierAMN(2, 1, 2, reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1))
    for diagnostics in (
        ["VASP_PAW_GENERALIZED_NORM_QUALITY_FAILED: generalized norm gate failed"],
        ["VASP_PAW_RADIAL_Q_QUALITY_FAILED: radial Q gate failed"],
    )
        result=W.VASPPAWMatrixElementResult(
            mmn,
            amn,
            amn,
            nothing,
            nothing,
            nothing,
            0.0,
            0.0,
            1e-3,
            residual,
            false,
            diagnostics,
            Dict{String, String}(),
            Dict{String, String}(),
        )
        @test Base.invokelatest(
            workflow._require_native_vasp_paw_qualification,
            result,
            thresholds;
            construction_policy = :diagnostic,
        ) === nothing
        @test_throws ArgumentError Base.invokelatest(
            workflow._require_native_vasp_paw_qualification,
            result,
            thresholds;
            construction_policy = :strict,
        )
        rows = Base.invokelatest(workflow._native_vasp_paw_gate_diagnostics, result, thresholds)
        @test length(rows) == 10
        bymetric = Dict(row.context["metric"] => row.context for row in rows)
        @test bymetric["radial_q_max_absolute"]["gate_result"] == "FAIL"
        @test bymetric["generalized_norm_max_absolute"]["gate_result"] == "FAIL"
        @test parse(Float64, bymetric["generalized_norm_max_absolute"]["threshold"]) ==
              thresholds.generalized_norm_max_absolute
        @test all(
            bymetric[key]["gate_result"] == "NOT_AVAILABLE" for
            key in ("mmn_max_absolute", "amn_max_absolute", "amn_max_principal_angle_rad")
        )
    end
end
