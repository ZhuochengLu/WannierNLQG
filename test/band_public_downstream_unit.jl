using HDF5
using LinearAlgebra
using Test
using WannierNLQG

if !isdefined(@__MODULE__, :WANNIERIZATION_FIXTURE_SUPPORT_LOADED)
    include(joinpath(@__DIR__, "WannierizationFixtureSupport.jl"))
end

# Recreate a complete internal contract solely to compare its unchanged downstream semantics.
function band_downstream_contract_copy(
    representation,
    version;
    conventions = representation.conventions,
)
    return WannierNLQG.SymmetryFoundation.BandRepresentation(
        version,
        representation.source_code,
        representation.spinor,
        representation.real_lattice,
        representation.reciprocal_lattice,
        representation.mp_grid,
        representation.kpoints_fractional,
        representation.energies_ev,
        representation.operations,
        representation.kpoint_map,
        representation.reciprocal_shifts,
        representation.sewing_matrices,
        representation.band_block_labels,
        representation.irreducible_indices,
        representation.full_to_irreducible,
        representation.full_to_operation;
        conventions,
        input_sha256 = representation.input_sha256,
    )
end

@testset "Public Band 1.0 preparation and downstream qualification" begin
    fixture = synthetic_wannierization_fixture()
    wf = WannierNLQG.Wannierization
    foundation = WannierNLQG.SymmetryFoundation
    extension = first(wf._load_wannierization_extension!())
    workflow = extension.WorkflowOrchestration
    solver = extension.SolverCheckpoint
    # The old incomplete synthetic object must not acquire identity eligibility from its number.
    @test !Base.invokelatest(
        extension.RepresentationPreparation._configured_identity_group_fast_path,
        fixture.config,
    )
    @test_throws ArgumentError Base.invokelatest(
        workflow._completed_public_band_representation,
        fixture.representation,
    )
    legacy_result = wf._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            fixture.config;
            max_iterations = 2,
            localize = false,
            algorithm_profile = :custom,
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test legacy_result.input_summary["compatibility_policy_effective"] == "strict"
    mktempdir() do directory
        win_file = joinpath(directory, "public.win")
        write(
            win_file,
            """
num_wann = 1
mp_grid = 2 1 1
begin unit_cell_cart
1 0 0
0 1 0
0 0 1
end unit_cell_cart
begin kpoints
0 0 0
0.5 0 0
end kpoints
""",
        )
        eig_file = joinpath(directory, "public.eig")
        open(eig_file, "w") do io
            for kpoint in 1:2, band in 1:2
                println(io, band, " ", kpoint, " ", fixture.eig.data[band, kpoint])
            end
        end
        for mode in (:ordinary, :symmetry_adapted)
            filename = joinpath(directory, "$(mode).h5")
            config = wf.BandRepresentationPreparationConfig(
                construction_policy = :strict,
                wannierization_mode = mode,
                win_file = win_file,
                eig_file = eig_file,
                projection_basis = fixture.basis,
                band_representation = mode == :ordinary ? nothing : fixture.representation,
                output_hdf5 = filename,
                num_wannier = 1,
                outer_min_ev = -2.0,
                outer_max_ev = 2.0,
                frozen_min_ev = -2.0,
                frozen_max_ev = -0.5,
                compatibility_policy = :off,
            )
            prepared = wf.prepare_band_representation(config)
            restored = foundation.read_band_representation_hdf5(filename)
            @test prepared.representation.schema_version == "1.0"
            @test restored.schema_version == "1.0"
            @test restored.conventions == prepared.representation.conventions
            @test restored.input_sha256 == prepared.representation.input_sha256
            for field in fieldnames(typeof(restored))
                if field == :operations
                    @test length(restored.operations) == length(prepared.representation.operations)
                    for (left, right) in
                        zip(restored.operations, prepared.representation.operations)
                        for operation_field in fieldnames(typeof(left))
                            @test isequal(
                                getfield(left, operation_field),
                                getfield(right, operation_field),
                            )
                        end
                    end
                else
                    @test isequal(
                        getfield(restored, field),
                        getfield(prepared.representation, field),
                    )
                end
            end
            reread = wf.prepare_band_representation(
                wf.BandRepresentationPreparationConfig(
                    construction_policy = :strict,
                    wannierization_mode = mode,
                    win_file = win_file,
                    eig_file = eig_file,
                    projection_basis = fixture.basis,
                    band_representation_hdf5 = filename,
                    num_wannier = 1,
                    outer_min_ev = -2.0,
                    outer_max_ev = 2.0,
                    frozen_min_ev = -2.0,
                    frozen_max_ev = -0.5,
                    compatibility_policy = :off,
                ),
            )
            @test reread.representation.schema_version == "1.0"
            @test reread.effective_compatibility_policy == prepared.effective_compatibility_policy
            @test reread.representation.conventions["pre_unified_schema_version"] ==
                  prepared.representation.conventions["pre_unified_schema_version"]
            @test reread.representation.sewing_matrices == prepared.representation.sewing_matrices
            # Public 1.0 without optional historical provenance is still a complete input.
            for origin in (nothing, "1.0", "1.1")
                conventions = Dict(restored.conventions)
                if origin === nothing
                    delete!(conventions, "pre_unified_schema_version")
                else
                    conventions["pre_unified_schema_version"] = origin
                end
                supplied_public = band_downstream_contract_copy(restored, "1.0"; conventions)
                source_file = joinpath(directory, "$(mode)-origin-$(origin).h5")
                foundation.write_band_representation_hdf5(
                    source_file,
                    supplied_public;
                    qualification_scope = prepared.qualification_scope,
                    raw_diagnostics = prepared.raw_diagnostics,
                )
                supplied_config = wf.BandRepresentationPreparationConfig(
                    construction_policy = :strict,
                    wannierization_mode = mode,
                    win_file = win_file,
                    eig_file = eig_file,
                    projection_basis = fixture.basis,
                    band_representation = mode == :ordinary ? nothing : supplied_public,
                    band_representation_hdf5 = mode == :ordinary ? source_file : nothing,
                    num_wannier = 1,
                    outer_min_ev = -2.0,
                    outer_max_ev = 2.0,
                    frozen_min_ev = -2.0,
                    frozen_max_ev = -0.5,
                    compatibility_policy = :warn,
                )
                supplied_prepared = wf.prepare_band_representation(supplied_config)
                @test supplied_prepared.effective_compatibility_policy ==
                      (origin === nothing ? :warn : :strict)
                # Optional provenance absence must survive a completed write/read/prepare cycle.
                roundtrip_file = joinpath(directory, "$(mode)-prepared-origin-$(origin).h5")
                foundation.write_band_representation_hdf5(
                    roundtrip_file,
                    supplied_prepared.representation;
                    qualification_scope = supplied_prepared.qualification_scope,
                    raw_diagnostics = supplied_prepared.raw_diagnostics,
                )
                roundtrip_representation = foundation.read_band_representation_hdf5(roundtrip_file)
                for value in (supplied_prepared.representation, roundtrip_representation)
                    @test value.schema_version == "1.0"
                    @test isequal(
                        get(value.conventions, "pre_unified_schema_version", nothing),
                        origin,
                    )
                end
                repeated_prepared = wf.prepare_band_representation(
                    wf.BandRepresentationPreparationConfig(
                        construction_policy = :strict,
                        wannierization_mode = mode,
                        win_file = win_file,
                        eig_file = eig_file,
                        projection_basis = fixture.basis,
                        band_representation_hdf5 = roundtrip_file,
                        num_wannier = 1,
                        outer_min_ev = -2.0,
                        outer_max_ev = 2.0,
                        frozen_min_ev = -2.0,
                        frozen_max_ev = -0.5,
                        compatibility_policy = :warn,
                    ),
                )
                @test repeated_prepared.effective_compatibility_policy ==
                      supplied_prepared.effective_compatibility_policy
                @test isequal(
                    get(
                        repeated_prepared.representation.conventions,
                        "pre_unified_schema_version",
                        nothing,
                    ),
                    origin,
                )
                @test repeated_prepared.representation.sewing_matrices ==
                      supplied_prepared.representation.sewing_matrices
            end
            # Binding a raw legacy fixture must not itself erase its uncertain origin.
            @test prepared.effective_compatibility_policy ==
                  (mode == :symmetry_adapted ? :strict : :off)
            @test reread.effective_compatibility_policy ==
                  (mode == :symmetry_adapted ? :strict : :off)
            internal_version = mode == :ordinary ? "1.16" : "1.17"
            internal = band_downstream_contract_copy(prepared.representation, internal_version)
            @test Base.invokelatest(solver._representation_target_subspace_contract, internal) ==
                  Base.invokelatest(solver._representation_target_subspace_contract, restored)
            run_config = modified_wannierization_config(
                fixture.config;
                construction_policy = :strict,
                wannierization_mode = mode,
                band_representation = mode == :ordinary ? nothing : restored,
                band_representation_hdf5 = mode == :ordinary ? filename : nothing,
                win_file = win_file,
                max_iterations = 2,
                localize = false,
                algorithm_profile = :custom,
            )
            internal_config = modified_wannierization_config(
                run_config;
                band_representation = mode == :ordinary ? nothing : internal,
            )
            @test wf._effective_wannierization_algorithms(run_config) ==
                  wf._effective_wannierization_algorithms(internal_config)
            public_result = wf._solve_symmetry_adapted_wannierization(
                run_config,
                restored,
                fixture.eig,
                fixture.mmn,
                fixture.plan,
            )
            internal_result = wf._solve_symmetry_adapted_wannierization(
                internal_config,
                internal,
                fixture.eig,
                fixture.mmn,
                fixture.plan,
            )
            @test internal_result.input_summary["compatibility_policy_requested"] == "warn"
            @test public_result.input_summary["compatibility_policy_requested"] == "warn"
            @test internal_result.input_summary["compatibility_policy_effective"] == "warn"
            @test public_result.input_summary["compatibility_policy_effective"] == "warn"
            public_summary = copy(public_result.input_summary)
            public_summary["schema_version"] = internal_version
            @test public_summary == internal_result.input_summary
            @test public_result.status == internal_result.status
            @test public_result.v_matrix == internal_result.v_matrix
            @test public_result.spreads_angstrom2 == internal_result.spreads_angstrom2
            @test public_result.history == internal_result.history
            @test maximum(abs, public_result.v_matrix - internal_result.v_matrix; init = 0.0) == 0.0
            # A supplied failed compatibility report exercises policy, not numerical perturbations.
            failed_report = wf.RepresentationCompatibilityReport(
                (
                    field == :passed ? false : getfield(prepared.compatibility_report, field)
                    for field in fieldnames(wf.RepresentationCompatibilityReport)
                )...,
            )
            for policy in (:off, :warn, :strict)
                outcomes = wf.WannierizationResult[]
                for (base_config, representation) in
                    ((run_config, restored), (internal_config, internal))
                    policy_config =
                        modified_wannierization_config(base_config; compatibility_policy = policy)
                    outcome = wf._solve_symmetry_adapted_wannierization(
                        policy_config,
                        representation,
                        fixture.eig,
                        fixture.mmn,
                        fixture.plan;
                        compatibility_report = failed_report,
                    )
                    push!(outcomes, outcome)
                    @test outcome.input_summary["compatibility_policy_effective"] == String(policy)
                    if policy == :strict
                        @test outcome.status == wf.REPRESENTATION_INCOMPATIBLE
                        @test outcome.input_summary["failure_class"] == "REPRESENTATION_A"
                    else
                        @test any(
                            diagnostic -> diagnostic.code == :REPRESENTATION_POLICY_CONTINUATION,
                            outcome.diagnostics,
                        )
                    end
                end
                @test outcomes[1].status == outcomes[2].status
                @test outcomes[1].v_matrix == outcomes[2].v_matrix
            end
            # Complete-looking malformed public inputs must throw, not fall back to legacy policy.
            for (key, value) in (
                ("authoritative_hamiltonian", "invalid"),
                ("effective_wannierization_mode", "invalid"),
            )
                damaged = Dict(restored.conventions)
                damaged[key] = value
                invalid = band_downstream_contract_copy(restored, "1.0"; conventions = damaged)
                @test_throws ArgumentError wf._solve_symmetry_adapted_wannierization(
                    run_config,
                    invalid,
                    fixture.eig,
                    fixture.mmn,
                    fixture.plan,
                )
                if mode == :symmetry_adapted
                    @test_throws ArgumentError wf.prepare_band_representation(
                        wf.BandRepresentationPreparationConfig(
                            construction_policy = :strict,
                            wannierization_mode = mode,
                            win_file = win_file,
                            eig_file = eig_file,
                            projection_basis = fixture.basis,
                            band_representation = invalid,
                            num_wannier = 1,
                            outer_min_ev = -2.0,
                            outer_max_ev = 2.0,
                            frozen_min_ev = -2.0,
                            frozen_max_ev = -0.5,
                            compatibility_policy = :off,
                        ),
                    )
                end
            end
            if mode == :symmetry_adapted
                for key in (
                    "target_leakage_semantics",
                    "target_leakage_formula_sha256",
                    "target_leakage_threshold",
                )
                    damaged = Dict(restored.conventions)
                    damaged[key] = "invalid"
                    for version in ("1.0", "1.17")
                        candidate =
                            band_downstream_contract_copy(restored, version; conventions = damaged)
                        @test_throws ArgumentError Base.invokelatest(
                            solver._representation_target_subspace_contract,
                            candidate,
                        )
                        if version == "1.0"
                            @test_throws ArgumentError wf._solve_symmetry_adapted_wannierization(
                                run_config,
                                candidate,
                                fixture.eig,
                                fixture.mmn,
                                fixture.plan,
                            )
                        end
                    end
                end
            end
        end
        # Reuse the exact real identity bands; add the closed spinless {E, Theta} group
        # for the antiunitary case. Neither case asserts a material-level qualification.
        for (magnetic, antiunitary) in ((true, false), (false, true))
            operations = copy(fixture.representation.operations)
            if antiunitary
                push!(
                    operations,
                    foundation.SymmetryOperation(
                        Matrix{Int}(I, 3, 3),
                        zeros(3),
                        Matrix{Float64}(I, 3, 3),
                        true,
                    ),
                )
            end
            count_operations = length(operations)
            shifts = zeros(Int, 3, count_operations, 2)
            antiunitary && (shifts[1, 2, 2] = -1)
            raw = foundation.BandRepresentation(
                "1.4",
                fixture.representation.source_code,
                false,
                fixture.representation.real_lattice,
                fixture.representation.reciprocal_lattice,
                fixture.representation.mp_grid,
                fixture.representation.kpoints_fractional,
                fixture.representation.energies_ev,
                operations,
                repeat(fixture.representation.kpoint_map, count_operations, 1),
                shifts,
                repeat(fixture.representation.sewing_matrices, 1, 1, count_operations, 1),
                fixture.representation.band_block_labels,
                fixture.representation.irreducible_indices,
                fixture.representation.full_to_irreducible,
                fixture.representation.full_to_operation;
                conventions = Dict("magnetic_structure" => string(magnetic)),
                input_sha256 = fixture.representation.input_sha256,
            )
            plan = foundation.WannierSymmetryPlan(
                operations,
                ones(ComplexF64, 1, 1, count_operations),
                zeros(Int, 3, 1, count_operations),
            )
            raw_config = modified_wannierization_config(
                fixture.config;
                band_representation = raw,
                max_iterations = 2,
                localize = false,
                algorithm_profile = :custom,
            )
            with_mode =
                Base.invokelatest(workflow._representation_with_mode_contract, raw, raw_config)
            scope = foundation.BandRepresentationQualificationScope(
                trues(2, 2),
                BitMatrix([true true; false false]),
            )
            internal = Base.invokelatest(
                workflow._representation_with_target_subspace_contract,
                with_mode,
                raw_config,
                scope,
            )
            complete = Base.invokelatest(workflow._completed_public_band_representation, internal)
            compatibility = wf.validate_band_representation_compatibility(
                complete,
                plan;
                tolerance = fixture.config.input.representation_tolerance,
            )
            @test compatibility.passed
            for representation in (internal, complete), requested in (:off, :warn)
                config = modified_wannierization_config(
                    raw_config;
                    band_representation = representation,
                    compatibility_policy = requested,
                )
                outcome = wf._solve_symmetry_adapted_wannierization(
                    config,
                    representation,
                    fixture.eig,
                    fixture.mmn,
                    plan,
                )
                @test outcome.input_summary["compatibility_policy_effective"] == "strict"
                @test Base.invokelatest(
                    workflow._effective_compatibility_policy,
                    requested,
                    representation,
                    nothing;
                    public_origin_fallback_validated = false,
                ) == :strict
            end
        end
        diagnostic_file = joinpath(directory, "diagnostic.h5")
        diagnostic = diagnostic_public_band_representation(fixture.representation)
        foundation.write_band_representation_hdf5(diagnostic_file, diagnostic)
        @test foundation.read_band_representation_hdf5(diagnostic_file).schema_version == "1.0"
        HDF5.h5open(diagnostic_file, "r") do handle
            @test String(read(HDF5.attributes(handle["compatibility"])["assessment_status"])) ==
                  "REPRESENTATION_UNDETERMINED"
        end
    end
end
