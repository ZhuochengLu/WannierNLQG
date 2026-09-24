if !isdefined(@__MODULE__, :WANNIERIZATION_FIXTURE_SUPPORT_LOADED)
    include(joinpath(@__DIR__, "WannierizationFixtureSupport.jl"))
end

@testset "ordinary posthoc exported TB qualification" begin
    mktempdir() do directory
        fixture = synthetic_wannierization_fixture()
        win = joinpath(directory, "ordinary.win")
        eig = joinpath(directory, "ordinary.eig")
        mmn = joinpath(directory, "ordinary.mmn")
        write(
            win,
            """
 num_wann = 1
 mp_grid = 2 1 1
 begin unit_cell_cart
 ang
 1 0 0
 0 2 0
 0 0 3
 end unit_cell_cart
 begin atoms_frac
 X 0 0 0
 end atoms_frac
 begin projections
 X:s
 end projections
 begin kpoints
 0 0 0
 0.5 0 0
 end kpoints
 """,
        )
        open(eig, "w") do io
            for k in 1:2, b in 1:2
                println(io, b, " ", k, " ", fixture.eig.data[b, k])
            end
        end
        WANNIER_IO.write_wannier_mmn(mmn, fixture.mmn)
        config = modified_wannierization_config(
            fixture.config;
            construction_policy = :standard,
            wannierization_mode = :ordinary,
            win_file = win,
            eig_file = eig,
            mmn_file = mmn,
            band_representation = nothing,
            algorithm_profile = :custom,
            localize = false,
            max_iterations = 3,
            convergence_window = 10,
            tb_output_formats = (:packed_hdf5,),
            write_wannier90_tb = false,
        )
        results = []
        for enabled in (false, true)
            cfg=modified_wannierization_config(
                config;
                final_tb_symmetry_report_enabled = enabled,
                checkpoint_hdf5 = joinpath(directory, string(enabled)*".wannierization.h5"),
            )
            result=WANNIERIZATION.construct_symmetry_adapted_wannier_functions(cfg)
            push!(results, result)
        end
        off, on=results
        exporter = first(WANNIERIZATION._load_wannierization_extension!()).OperatorExport
        @testset "Standard numerical export checks preserve integrity" begin
            for code in (
                "HAMILTONIAN_HERMITICITY",
                "POSITION_HERMITICITY",
                "HAMILTONIAN_FOURIER_ROUNDTRIP",
                "POSITION_FOURIER_ROUNDTRIP",
                "TEXT_HAMILTONIAN_ROUNDTRIP",
                "TEXT_POSITION_ROUNDTRIP",
                "WANNIER_CENTER_ROUNDTRIP",
            )
                records = Dict{String, Any}[]
                @test exporter._export_numerical_check!(records, :standard, code, 1.0, 1.0e-10)
                @test only(records)["message"] == "NUMERICAL_WARNING"
                @test only(records)["context"]["value"] == 1.0
                @test_throws ArgumentError exporter._export_numerical_check!(
                    records,
                    :strict,
                    code,
                    1.0,
                    1.0e-10,
                )
                @test_throws ArgumentError exporter._export_numerical_check!(
                    records,
                    :standard,
                    code,
                    NaN,
                    1.0e-10,
                )
                @test_throws ArgumentError exporter._export_numerical_check!(
                    records,
                    :standard,
                    code,
                    Inf,
                    1.0e-10,
                )
            end
            summary = copy(off.input_summary)
            summary["hard_gate_frozen"] = "0.5"
            changed = exporter.updated_wannierization_result(off; input_summary = summary)
            @test exporter._accepted_state_tb_export_gate(changed, config).allowed
            prepared, quality, before, after, repaired =
                exporter._prepare_wannierization_tb_state(changed, config)
            @test prepared === changed
            @test quality == "NUMERICAL_WARNING"
            @test before == after
            @test !repaired
            summary["hard_gate_frozen"] = "Inf"
            changed = exporter.updated_wannierization_result(off; input_summary = summary)
            @test !exporter._accepted_state_tb_export_gate(changed, config).allowed
            @test_throws ArgumentError exporter._prepare_wannierization_tb_state(changed, config)
            @test_throws ErrorException exporter._real_space_hermiticity_error(
                zeros(ComplexF64, 1, 1, 2),
                zeros(Int, 3, 2),
            )
            @test_throws ErrorException exporter._real_space_hermiticity_error(
                zeros(ComplexF64, 1, 1, 1),
                reshape([1, 0, 0], 3, 1),
            )
        end
        @show on.tb_symmetry_qualification.reason
        @show [(m.name, m.status, m.reason) for m in on.tb_symmetry_qualification.metrics]
        out_text = read(on.artifacts.wannierization_log, String)
        @test occursin("identity_sewing_unitarity_residual", out_text)
        @test !occursin("[SOLVER PROJECTOR COVARIANCE]", out_text)
        @test !occursin("[REPRESENTATION AND GROUP-LAW DIAGNOSTICS]", out_text)
        @test !occursin("projector_covariance_error", out_text)
        @test !occursin("little_group_residual", out_text)
        @test occursin("FINAL TB SYMMETRY QUALIFICATION", out_text)
        @test !occursin(
            "FINAL TB SYMMETRY QUALIFICATION",
            read(off.artifacts.wannierization_log, String),
        )
        report = exporter._ordinary_accepted_state_report(on, config)
        @test parse(Float64, report["ordinary_accepted_frame_isometry_residual"]) >= 0.0
        @test parse(Float64, report["ordinary_accepted_projector_idempotence_residual"]) >= 0.0
        @test report["ordinary_physical_band_sewing_status"] == "NOT_RUN"
        @test !isempty(report["ordinary_physical_band_sewing_reason"])
        @test isempty(exporter._ordinary_accepted_state_report(on, fixture.config))
        absent = exporter._ordinary_accepted_state_report(
            (v_matrix = zeros(ComplexF64, 0, 0, 0),),
            config,
        )
        @test absent["ordinary_accepted_frame_diagnostic_status"] == "NOT_RUN"
        @test !haskey(absent, "ordinary_accepted_frame_isometry_residual")
        restored = WANNIERIZATION.read_wannierization_checkpoint_hdf5(on.checkpoint_file)
        @test exporter._ordinary_accepted_state_report(restored, config) == report
        @test on.input_summary["ordinary_accepted_frame_diagnostic_source"] ==
              "ACCEPTED_V_MATRIX_RECOMPUTED"
        @test occursin("ordinary_accepted_projector_idempotence_residual", out_text)
        @test !occursin("ordinary_physical_band_sewing_status", out_text)
        @test on.v_matrix == off.v_matrix
        @test on.spreads_angstrom2 == off.spreads_angstrom2
        @test on.status == off.status
        @test length(on.tb_symmetry_qualification.metrics)==8
        @test all(m->m.status in ("PASS", "FAIL"), on.tb_symmetry_qualification.metrics)
        @test on.tb_symmetry_qualification.overall in ("PASS", "FAIL")
        @test on.artifacts.packed_hdf5 !== nothing
        if on.artifacts.packed_hdf5 !== nothing && off.artifacts.packed_hdf5 !== nothing
            a=WANNIER_IO.read_real_space_operator_bundle(on.artifacts.packed_hdf5)
            b=WANNIER_IO.read_real_space_operator_bundle(off.artifacts.packed_hdf5)
            @test a.manifest.scientific_content_sha256 == b.manifest.scientific_content_sha256
            @test a.lattice == b.lattice
            @test a.degeneracies == b.degeneracies
            for kind in keys(a.operators)
                @test a.operators[kind].data == b.operators[kind].data
                @test a.operators[kind].r_vectors == b.operators[kind].r_vectors
            end
            extension = first(WANNIERIZATION._load_wannierization_extension!())
            mesh = Base.invokelatest(
                extension.SolverCheckpoint.identity_band_representation,
                config,
                fixture.basis,
                fixture.eig,
            )
            contract = extension.SolverCheckpoint._no_symmetry_compatibility_contract(mesh, 1.0e-8)
            @test contract.maximum_required_block_unitarity_residual == 0.0
            @test only(contract.diagnostics).context["physical_representation_status"] == "NOT_RUN"
            @test occursin(
                "overlaps",
                only(contract.diagnostics).context["physical_representation_reason"],
            )
            rep_path = joinpath(directory, "identity-report.h5")
            public_mesh = diagnostic_public_band_representation(mesh)
            public_contract =
                extension.SolverCheckpoint._no_symmetry_compatibility_contract(public_mesh, 1.0e-8)
            WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
                rep_path,
                public_mesh;
                validation = public_contract,
            )
            HDF5.h5open(rep_path, "r") do handle
                attrs = HDF5.attributes(handle["compatibility"])
                @test read(attrs["maximum_required_block_unitarity_residual"]) == 0.0
                @test read(attrs["physical_representation_status"]) == "NOT_RUN"
                @test occursin("overlaps", read(attrs["physical_representation_reason"]))
                @test read(attrs["measurement_scope"]) == "IDENTITY_BOOKKEEPING_ONLY"
            end
            legacy_report =
                exporter._ordinary_accepted_state_report(on, config; representation = mesh)
            @test legacy_report["ordinary_identity_sewing_unitarity_residual"] == "0.0"
            @test legacy_report["ordinary_identity_sewing_measurement_scope"] ==
                  "IDENTITY_BOOKKEEPING_ONLY"
            mesh_before = copy(mesh.sewing_matrices)
            perturbed = deepcopy(mesh)
            perturbed.sewing_matrices[1, 1, 1, 1] = 1.1
            measured =
                extension.SolverCheckpoint._no_symmetry_compatibility_contract(perturbed, 1.0e-8)
            @test measured.maximum_required_block_unitarity_residual ≈ 0.21
            @test mesh.sewing_matrices == mesh_before
            @test measured.assessment_status == contract.assessment_status
            @test occursin("NOT_RUN", JSON3.write(only(measured.diagnostics).context))
            raw = IOBuffer()
            exporter._write_tb_report(raw, on.tb_symmetry_qualification; measured_only = true)
            @test !occursin("N/A", String(take!(raw)))
            context = Base.invokelatest(
                extension.WorkflowOrchestration._ordinary_posthoc_qualification_context,
                config,
                mesh,
            )
            # Perturb independent copies only; qualify with the same posthoc context.
            geometry = Dict(
                "wannier_center_policy" => "keep_input",
                "real_space_replica_policy" => "input",
                "production_eligible" => false,
                "minimum_distance_materialized" => false,
                "mp_grid" => [2, 1, 1],
                "wannier_center_tolerance" => 1.0e-8,
                "wigner_seitz_tolerance" => 1.0e-5,
                "wigner_seitz_search_size" => 3,
                "raw_wannier_centers_cartesian" => zeros(1, 3),
                "raw_wannier_centers_fractional" => zeros(1, 3),
                "final_wannier_centers_cartesian" => zeros(1, 3),
                "final_wannier_centers_fractional" => zeros(1, 3),
                "center_alignment_lattice_shifts" => zeros(Int, 1, 3),
                "replica_mapping_sha256" => repeat("0", 64),
            )
            for (kind, metric) in (
                (WannierNLQG.Core.REAL_SPACE_HAMILTONIAN, "hamiltonian_covariance_relative_max"),
                (
                    WannierNLQG.Core.REAL_SPACE_POSITION,
                    "centerless_position_covariance_relative_max",
                ),
            )
                copied = deepcopy(a.operators)
                op = copied[kind]
                r = findfirst(j -> any(!iszero, op.r_vectors[:, j]), axes(op.r_vectors, 2))
                @test r !== nothing
                if r !== nothing
                    if kind == WannierNLQG.Core.REAL_SPACE_HAMILTONIAN
                        op.data[1, 1, r] += 0.1
                    else
                        op.data[1, 1, 1, r] += 0.1
                    end
                    broken = joinpath(directory, string(kind)*"-broken.h5")
                    WANNIER_IO.write_real_space_operator_bundle(
                        broken,
                        a.lattice,
                        a.degeneracies,
                        copied;
                        profile = :hamiltonian_position,
                        geometry,
                        eligibility = Dict(
                            "authoritative_hamiltonian_sha256"=>context.representation.conventions["authoritative_hamiltonian_sha256"],
                        ),
                    )
                    q=WANNIERIZATION.qualify_exported_wannierization_tb(
                        broken,
                        context.representation,
                        context.plan;
                        hamiltonian_covariance_threshold = config.input.representation_tolerance,
                        persist_hdf5 = false,
                    )
                    @test only(filter(m->m.name==metric, q.metrics)).status=="FAIL"
                end
            end
            before = bytes2hex(sha256(read(on.artifacts.packed_hdf5)))
            repeat_qualification = WANNIERIZATION.qualify_exported_wannierization_tb(
                on.artifacts.packed_hdf5,
                context.representation,
                context.plan;
                hamiltonian_covariance_threshold = config.input.representation_tolerance,
                persist_hdf5 = false,
            )
            @test repeat_qualification.payload_sha256 == on.tb_symmetry_qualification.payload_sha256
            @test bytes2hex(sha256(read(on.artifacts.packed_hdf5))) == before
            child = joinpath(directory, "readback.jl")
            write(
                child,
                """
   using WannierNLQG, SHA
   W=WannierNLQG.Wannierization
   b=WannierNLQG.IO.read_real_space_operator_bundle(ARGS[1])
   @assert b.manifest.scientific_content_sha256 == ARGS[2]
   @assert bytes2hex(sha256(read(ARGS[1]))) == ARGS[3]
   restored = W.read_wannierization_checkpoint_hdf5(ARGS[4])
   @assert restored.input_summary["ordinary_physical_band_sewing_status"] == "NOT_RUN"
   @assert occursin("overlaps", restored.input_summary["ordinary_physical_band_sewing_reason"])
   println("FRESH_PROCESS_READBACK_EXACT")
   """,
            )
            output = read(
                `$(Base.julia_cmd()) --project=$(dirname(Base.active_project())) $child $(on.artifacts.packed_hdf5) $(a.manifest.scientific_content_sha256) $before $(on.checkpoint_file)`,
                String,
            )
            @test occursin("FRESH_PROCESS_READBACK_EXACT", output)
        end
        # An invalid crystal description is encountered only after ordinary solve/export.
        write(win, replace(read(win, String), "X 0 0 0"=>"X broken 0 0"))
        bad=WANNIERIZATION.construct_symmetry_adapted_wannier_functions(
            modified_wannierization_config(
                config;
                final_tb_symmetry_report_enabled = true,
                checkpoint_hdf5 = joinpath(directory, "bad.wannierization.h5"),
            ),
        )
        @test bad.v_matrix == off.v_matrix
        @test bad.tb_symmetry_qualification.overall=="INCOMPLETE"
        @test occursin("ORDINARY_POSTHOC", bad.tb_symmetry_qualification.reason)
        raw = IOBuffer()
        exporter._write_tb_report(raw, bad.tb_symmetry_qualification; measured_only = true)
        @test !occursin("N/A", String(take!(raw)))
        @test any(m -> m.value === nothing, bad.tb_symmetry_qualification.metrics)
        @test occursin(
            "INCOMPLETE",
            JSON3.write(
                Dict(
                    "status" => bad.tb_symmetry_qualification.overall,
                    "reason" => bad.tb_symmetry_qualification.reason,
                ),
            ),
        )
    end
end
