isdefined(@__MODULE__, :InternalSolverFixture) ||
    include(joinpath(@__DIR__, "support", "InternalSolverFixture.jl"))
using EzXML
using HDF5
using JSON3
using LinearAlgebra
using Spglib
using Test
using TOML
using WannierNLQG

const TARGET_PERSISTENCE_WANNIERIZATION = WannierNLQG.Wannierization
const TARGET_PERSISTENCE_SYMMETRIZATION = WannierNLQG.Symmetrization
const TARGET_PERSISTENCE_IO = WannierNLQG.IO
const TARGET_PERSISTENCE_CORE = WannierNLQG.Core
const TARGET_PERSISTENCE_EXTENSION =
    first(TARGET_PERSISTENCE_WANNIERIZATION._load_wannierization_extension!()).PAWMatrixElements

# Explicitly relocated legacy-authority negatives exercise the complete decoder
# during adoption. Mutation negatives below instead register the valid private
# copy before changing it; re-adoption would acknowledge a different input.
function target_persistence_adopt_and_read_checkpoint(path)
    TARGET_PERSISTENCE_WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(path)
    return TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(path)
end
function target_persistence_adopt_and_read_bundle(path)
    TARGET_PERSISTENCE_IO.adopt_real_space_operator_bundle(path)
    return TARGET_PERSISTENCE_IO.read_real_space_operator_bundle_manifest(path)
end

# An adopted copy subsequently modified must fail at the publication lifetime
# boundary. This does not claim that a content hash or math decoder was tested.
function target_persistence_expect_changed_publication(path)
    exception = try
        TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(path)
        nothing
    catch exception
        exception
    end
    @test exception isa ArgumentError
    @test occursin("SCIENTIFIC_FILE_PUBLICATION_CHANGED_OR_INVALID", sprint(showerror, exception))
end

# Invoke the actual public consumer and assert its exact scoped failure layer.
function target_persistence_expect_argument_error(action, expected)
    exception = try
        action()
        nothing
    catch exception
        exception
    end
    @test exception isa ArgumentError
    @test occursin(expected, sprint(showerror, exception))
end

# The existing one-band fixture has E=-1 eV and both windows [-2,0] eV.
# With one band there is no partial degeneracy block; these are its actual masks.
function target_persistence_contract(; freeze::Bool = true)
    energies = reshape([-1.0], 1, 1)
    outer = (-2.0 .<= energies) .& (energies .<= 0.0)
    frozen_max_ev = freeze ? 0.0 : -1.5
    frozen = (-2.0 .<= energies) .& (energies .<= frozen_max_ev)
    scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        outer,
        frozen;
        content_authentication = false,
    )
    return TARGET_PERSISTENCE_WANNIERIZATION.TargetSubspaceQualificationContract(
        scope;
        outer_min_ev = -2.0,
        outer_max_ev = 0.0,
        frozen_min_ev = -2.0,
        frozen_max_ev,
        num_wannier = 1,
    )
end

# Construct a complete public identity representation with the current target contract.
function target_persistence_representation(; authority::String = "native_dft", freeze::Bool = true)
    contract = target_persistence_contract(; freeze)
    operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    return WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.0",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        zeros(1, 3),
        reshape([-1.0], 1, 1),
        [operation],
        ones(Int, 1, 1),
        zeros(Int, 3, 1, 1),
        ones(ComplexF64, 1, 1, 1, 1),
        ones(Int, 1, 1),
        [1],
        [1],
        [1];
        conventions = Dict(
            "fourier" => "H(k)=sum_R exp(+2pi*i*k.R) H(R)",
            "authoritative_hamiltonian" => authority,
            "authoritative_hamiltonian_sha256" => repeat("1", 64),
            "qualification_scope" => "target_subspace",
            "target_authority" => "outer_window",
            "parent_audit_policy" => "audit_only",
            "target_subspace_contract_definition" => contract.contract_definition,
            # Actual one-band EIG/window masks, not a qualification credential.
            "outer_mask_definition" => contract.qualification_scope.outer_mask_definition,
            "frozen_mask_definition" => contract.qualification_scope.frozen_mask_definition,
            "content_authentication" => "NOT_PERFORMED",
            "target_leakage_semantics" =>
                TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_SEMANTICS,
            "target_leakage_formula_definition" =>
                TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_FORMULA_DEFINITION,
            "target_leakage_threshold" => "5.0e-6",
            "auxiliary_parent_qualification" => "audit_only",
            "requested_wannierization_mode" => "symmetry_adapted",
            "effective_wannierization_mode" => "symmetry_adapted",
            "representation_source" => "provided",
            "symmetry_constraints_applied" => "false",
        ),
        input_sha256 = Dict("fixture" => repeat("0", 64)),
    )
end

# Provide the minimum auditable geometry contract for a one-orbital R=0 bundle.
function target_persistence_geometry()
    centers = zeros(1, 3)
    return Dict(
        "wannier_center_policy" => "symmetrize",
        "real_space_replica_policy" => "input",
        "production_eligible" => false,
        "minimum_distance_materialized" => false,
        "mp_grid" => [1, 1, 1],
        "wannier_center_tolerance" => 1.0e-8,
        "wigner_seitz_tolerance" => 1.0e-5,
        "wigner_seitz_search_size" => 3,
        "raw_wannier_centers_cartesian" => centers,
        "raw_wannier_centers_fractional" => centers,
        "final_wannier_centers_cartesian" => centers,
        "final_wannier_centers_fractional" => centers,
        "center_alignment_lattice_shifts" => zeros(Int, 1, 3),
        "replica_mapping_reference" => repeat("0", 64),
    )
end

# Build a minimal one-k-point state to exercise the schema-2.28 checkpoint boundary.
function target_persistence_solver_fixture()
    representation = target_persistence_representation()
    block = WannierNLQG.WannierProjection.WannierProjectionBlock(
        "X",
        "s",
        zeros(3, 1),
        reshape([1], 1, 1),
        reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
        false,
    )
    basis = WannierNLQG.WannierProjection.WannierProjectionBasis([block], 1, false)
    plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        representation.operations,
        ones(ComplexF64, 1, 1, 1),
        zeros(Int, 3, 1, 1),
    )
    eig = TARGET_PERSISTENCE_IO.WannierEIG(1, 1, reshape([-1.0], 1, 1))
    reciprocal_shifts = zeros(Int, 3, 6, 1)
    reciprocal_shifts[:, :, 1] .= [1 -1 0 0 0 0; 0 0 1 -1 0 0; 0 0 0 0 1 -1]
    mmn = TARGET_PERSISTENCE_IO.WannierMMN(
        1,
        1,
        6,
        ones(ComplexF64, 1, 1, 6, 1),
        ones(Int, 6, 1),
        reciprocal_shifts,
    )
    config = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationConfig(
        input = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationInputConfig(
            wannierization_mode = :symmetry_adapted,
            win_file = "synthetic.win",
            eig_file = "synthetic.eig",
            mmn_file = "synthetic.mmn",
            projection_basis = basis,
            band_representation = representation,
            num_wannier = 1,
            outer_min_ev = -2.0,
            outer_max_ev = 0.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = 0.0,
        ),
        solver = InternalSolverFixture.solver_config(
            initialization = :random,
            stage_controls = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 2,
                num_iter = 0,
                dis_conv_tol = 1e-10,
                dis_conv_window = 1,
            ),
            random_seed = 0x1234,
        ),
        checkpoint = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationCheckpointConfig(),
        runtime = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationRuntimeConfig(),
        output = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationOutputConfig(),
    )
    return (; representation, plan, eig, mmn, config)
end

@testset "Actual target masks are bound before publication" begin
    sf = WannierNLQG.SymmetryFoundation
    mktempdir() do directory
        for freeze in (false, true)
            representation = target_persistence_representation(; freeze)
            scope = target_persistence_contract(; freeze).qualification_scope
            path = joinpath(directory, "mask-$(freeze).h5")
            sf.write_band_representation_hdf5(
                path,
                representation;
                content_authentication = false,
                qualification_scope = scope,
            )
            restored = sf.read_band_representation_hdf5(path; content_authentication = false)
            HDF5.h5open(path, "r") do handle
                @test read(handle["qualification_scope/outer_mask"]) == reshape(UInt8[1], 1, 1)
                @test read(handle["qualification_scope/frozen_mask"]) ==
                      reshape(UInt8[freeze ? 1 : 0], 1, 1)
                @test size(read(handle["qualification_scope/frozen_mask"])) == (1, 1)
                @test eltype(read(handle["qualification_scope/frozen_mask"])) == UInt8
                @test String(
                    HDF5.read_attribute(handle["qualification_scope/frozen_mask"], "axis_order"),
                ) == "band,kpoint"
            end
            @test restored.energies_ev == representation.energies_ev
        end
        representation = target_persistence_representation()
        for (name, keywords) in (
            ("omitted", (;)),
            (
                "contradictory",
                (;
                    qualification_outer_mask = trues(1, 1),
                    qualification_frozen_mask = falses(1, 1),
                ),
            ),
            (
                "dimensions",
                (;
                    qualification_outer_mask = trues(2, 1),
                    qualification_frozen_mask = falses(2, 1),
                ),
            ),
            (
                "escape",
                (;
                    qualification_outer_mask = falses(1, 1),
                    qualification_frozen_mask = trues(1, 1),
                ),
            ),
        )
            path = joinpath(directory, name * ".h5")
            @test_throws ArgumentError sf.write_band_representation_hdf5(
                path,
                representation;
                content_authentication = false,
                keywords...,
            )
            @test !isfile(path)
        end
    end
end

@testset "Target-subspace persistence schemas and tamper rejection" begin
    parent_extension = first(TARGET_PERSISTENCE_WANNIERIZATION._load_wannierization_extension!())
    solver = parent_extension.SolverCheckpoint
    support = parent_extension.WannierizationInternalSupport
    @test solver.WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION == "3.0"
    @test WannierNLQG.SymmetryFoundation.band_representation_schema_version() == "1.0"
    @test TARGET_PERSISTENCE_IO.OPERATOR_BUNDLE_SCHEMA_VERSION == "3.0"
    @test TARGET_PERSISTENCE_WANNIERIZATION.TB_SYMMETRY_QUALIFICATION_SCHEMA_VERSION == "2.0"

    mktempdir() do directory
        representation = target_persistence_representation()
        representation_file = joinpath(directory, "target-representation.h5")
        WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
            representation_file,
            representation;
            content_authentication = false,
            qualification_scope = target_persistence_contract().qualification_scope,
        )
        restored = WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
            representation_file;
            content_authentication = false,
        )
        @test restored.schema_version == "1.0"
        @test restored.conventions["authoritative_hamiltonian"] == "native_dft"
        @test restored.conventions["qualification_scope"] == "target_subspace"
        @test restored.conventions["target_subspace_contract_definition"] ==
              target_persistence_contract().contract_definition
        @test restored.conventions["target_leakage_semantics"] ==
              TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_SEMANTICS
        @test restored.conventions["target_leakage_formula_definition"] ==
              TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_FORMULA_DEFINITION
        @test parse(Float64, restored.conventions["target_leakage_threshold"]) == 5.0e-6

        symmetrized_representation =
            target_persistence_representation(authority = "symmetrized_dft_hamiltonian")
        symmetrized_representation_file =
            joinpath(directory, "symmetrized-target-representation.h5")
        WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
            symmetrized_representation_file,
            symmetrized_representation;
            content_authentication = false,
            qualification_scope = target_persistence_contract().qualification_scope,
        )
        restored_symmetrized = WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
            symmetrized_representation_file;
            content_authentication = false,
        )
        @test restored_symmetrized.conventions["authoritative_hamiltonian"] ==
              "symmetrized_dft_hamiltonian"
        @test restored_symmetrized.conventions["target_subspace_contract_definition"] ==
              target_persistence_contract().contract_definition
        metadata = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.read_band_representation_preparation_hdf5,
            representation_file,
            restored;
            content_authentication = false,
        )
        @test metadata.qualification_scope.outer_mask_definition ==
              target_persistence_contract().qualification_scope.outer_mask_definition
        @test metadata.qualification_scope.frozen_mask_definition ==
              target_persistence_contract().qualification_scope.frozen_mask_definition

        # Missing definition and changed mathematical values are distinct cases.
        @testset "T3 missing definition" begin
            missing_definition = joinpath(directory, "missing-outer-definition.h5")
            cp(representation_file, missing_definition);
            chmod(missing_definition, 0o600)
            HDF5.h5open(missing_definition, "r+") do handle
                conventions = handle["conventions"]
                @test haskey(HDF5.attributes(conventions), "outer_mask_definition")
                @test read(handle["qualification_scope/outer_mask"]) == reshape(UInt8[1], 1, 1)
                HDF5.delete_attribute(conventions, "outer_mask_definition")
                @test !haskey(HDF5.attributes(conventions), "outer_mask_definition")
                @test read(handle["qualification_scope/outer_mask"]) == reshape(UInt8[1], 1, 1)
            end
            target_persistence_expect_argument_error(
                () -> WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
                    missing_definition;
                    content_authentication = false,
                ),
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: outer mask actual values differ",
            )
        end

        @testset "T3 actual mask mutation" begin
            tampered_representation = joinpath(directory, "target-representation-tampered.h5")
            cp(representation_file, tampered_representation);
            chmod(tampered_representation, 0o600)
            HDF5.h5open(tampered_representation, "r+") do handle
                scope = handle["qualification_scope"]
                @test read(scope["frozen_mask"]) == reshape(UInt8[1], 1, 1)
                scope["frozen_mask"][1, 1] = UInt8(0)
                @test read(scope["frozen_mask"]) == reshape(UInt8[0], 1, 1)
                @test haskey(HDF5.attributes(handle["conventions"]), "frozen_mask_definition")
            end
            target_persistence_expect_argument_error(
                () -> WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
                    tampered_representation;
                    content_authentication = false,
                ),
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: frozen mask actual values differ",
            )
        end

        legacy_weight_representation = joinpath(directory, "legacy-weight-target-representation.h5")
        cp(representation_file, legacy_weight_representation)
        chmod(legacy_weight_representation, 0o600)
        HDF5.h5open(legacy_weight_representation, "r+") do handle
            @test haskey(HDF5.attributes(handle), "schema_version")
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "1.16"
        end
        legacy_weight_representation_error = try
            WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
                legacy_weight_representation;
                content_authentication = false,
            )
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin(
            "unsupported band-representation schema",
            something(legacy_weight_representation_error, ""),
        )

        @testset "T5 exact formula rejection" begin
            tampered_formula_representation =
                joinpath(directory, "target-representation-formula-tampered.h5")
            cp(representation_file, tampered_formula_representation)
            chmod(tampered_formula_representation, 0o600)
            HDF5.h5open(tampered_formula_representation, "r+") do handle
                conventions = handle["conventions"]
                @test haskey(HDF5.attributes(conventions), "target_leakage_formula_definition")
                @test String(
                    HDF5.read_attribute(conventions, "target_leakage_formula_definition"),
                ) == TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_FORMULA_DEFINITION
                HDF5.delete_attribute(conventions, "target_leakage_formula_definition")
                HDF5.attributes(conventions)["target_leakage_formula_definition"] = repeat("d", 64)
                @test String(
                    HDF5.read_attribute(conventions, "target_leakage_formula_definition"),
                ) == repeat("d", 64)
            end
            target_persistence_expect_argument_error(
                () -> WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
                    tampered_formula_representation;
                    content_authentication = false,
                ),
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: target leakage formula differs",
            )
        end

        legacy_representation = joinpath(directory, "legacy-authority-representation.h5")
        cp(representation_file, legacy_representation)
        chmod(legacy_representation, 0o600)
        HDF5.h5open(legacy_representation, "r+") do handle
            attributes = HDF5.attributes(handle["conventions"])
            @test haskey(HDF5.attributes(handle["conventions"]), "authoritative_hamiltonian")
            HDF5.delete_attribute(handle["conventions"], "authoritative_hamiltonian")
            attributes["authoritative_hamiltonian"] = "symmetrized_target_subspace_candidate"
        end
        legacy_error = try
            WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
                legacy_representation;
                content_authentication = false,
            )
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin("UNSUPPORTED_LEGACY_AUTHORITY", something(legacy_error, ""))

        solver_fixture = target_persistence_solver_fixture()
        solver_result = TARGET_PERSISTENCE_WANNIERIZATION._solve_symmetry_adapted_wannierization(
            solver_fixture.config,
            solver_fixture.representation,
            solver_fixture.eig,
            solver_fixture.mmn,
            solver_fixture.plan,
        )
        checkpoint_summary = Dict{String, String}(solver_result.input_summary)
        checkpoint_summary["construction_policy"] = "standard"
        push!(
            solver_result.diagnostics,
            TARGET_PERSISTENCE_WANNIERIZATION.WannierizationDiagnostic(
                :SYNTHETIC_QUALITY_GATE,
                :warning,
                "Retained original quality failure";
                context = Dict(
                    "gate_result" => "FAIL",
                    "action" => "CONTINUE_STANDARD",
                    "stage" => "preparation",
                    "value" => "6.81e-8",
                    "threshold" => "1.0e-10",
                ),
            ),
        )
        # This fixture adds a warning after the solver terminal snapshot.
        # Rebuild that snapshot through the actual terminal helper; persistence
        # preserves supplied summary values rather than recalculating diagnostics.
        @test solver_result.input_summary["quality_review_status"] == "NO_REPORTED_WARNING"
        terminal_helper =
            first(TARGET_PERSISTENCE_WANNIERIZATION._load_wannierization_extension!()).SolverCheckpoint._record_terminal_state!
        Base.invokelatest(
            terminal_helper,
            checkpoint_summary,
            solver_result.status,
            solver_result.diagnostics,
            solver_result.history,
            parse(Int, checkpoint_summary["last_attempted_iteration"]),
            parse(Int, checkpoint_summary["last_accepted_iteration"]),
        )
        @test checkpoint_summary["quality_review_status"] == "RECOMMENDED"
        @test checkpoint_summary["construction_quality_failed"] == "true"
        checkpoint_summary["authoritative_hamiltonian"] = "native_dft"
        checkpoint_summary["authoritative_hamiltonian_sha256"] = repeat("1", 64)
        checkpoint_summary["qualification_scope"] = "target_subspace"
        checkpoint_summary["target_authority"] = "outer_window"
        checkpoint_summary["parent_audit_policy"] = "audit_only"
        checkpoint_summary["disentanglement_outer_mask_definition"] =
            target_persistence_contract().qualification_scope.outer_mask_definition
        checkpoint_summary["disentanglement_frozen_mask_definition"] =
            target_persistence_contract().qualification_scope.frozen_mask_definition
        checkpoint_summary["target_subspace_contract_definition"] =
            target_persistence_contract().contract_definition
        # One-band actual EIG/window: P=1, IBZ=[1], outer=frozen=true.
        # Preserve accepted F including its phase; compare against its input snapshot.
        raw_state = something(solver_result.restart_state)
        @test size(raw_state.frames) == (1, 1, 1)
        expected_fixed_projector = ones(ComplexF64, 1, 1, 1)
        expected_fixed_frame = copy(raw_state.frames)
        @test expected_fixed_frame[:, :, 1] * expected_fixed_frame[:, :, 1]' ≈
              expected_fixed_projector[:, :, 1] atol=1e-12 rtol=0
        @test solver_fixture.representation.irreducible_indices == [1]
        @test solver_fixture.eig.data == reshape([-1.0], 1, 1)
        # No fictional checkpoint IBZ/mask datasets: verify the paired actual
        # representation and the checkpoint's complete mask definitions.
        HDF5.h5open(representation_file, "r") do handle
            @test read(handle["stars/irreducible_indices"]) == [1]
            @test read(handle["qualification_scope/outer_mask"]) == reshape(UInt8[1], 1, 1)
            @test read(handle["qualification_scope/frozen_mask"]) == reshape(UInt8[1], 1, 1)
        end
        state_values = Tuple(
            name == :fixed_subspace_projectors ? expected_fixed_projector :
            name == :fixed_subspace_frames ? expected_fixed_frame : getfield(raw_state, name)
            for name in fieldnames(typeof(raw_state))
        )
        checkpoint_state =
            TARGET_PERSISTENCE_WANNIERIZATION.WannierizationRestartState(state_values...)
        checkpoint_result = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationResult(
            solver_result.status,
            solver_result.v_matrix,
            solver_result.wannier_centers_cartesian,
            solver_result.spreads_angstrom2,
            solver_result.history,
            solver_result.diagnostics,
            checkpoint_summary,
            solver_result.wannier_chk,
            nothing,
            checkpoint_state,
            solver_result.artifacts,
        )
        checkpoint_file = joinpath(directory, "target-checkpoint.h5")
        TARGET_PERSISTENCE_WANNIERIZATION.write_wannierization_checkpoint_hdf5(
            checkpoint_file,
            checkpoint_result,
        )
        restored_checkpoint =
            TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(checkpoint_file)
        @testset "T7 fixed-state payload and independent values" begin
            restored_state = something(restored_checkpoint.restart_state)
            @test restored_state.fixed_subspace_projectors == expected_fixed_projector
            @test restored_state.fixed_subspace_frames == expected_fixed_frame
            @test restored_state.included_bands == reshape([true], 1, 1)
            HDF5.h5open(checkpoint_file, "r") do handle
                @test Bool(read(handle["restart_state/has_fixed_subspace"]))
                @test read(handle["restart_state/fixed_subspace_projectors"]) ==
                      expected_fixed_projector
                @test read(handle["restart_state/fixed_subspace_frames"]) == expected_fixed_frame
            end
        end

        @testset "T7 fixed-state decoder rejection" begin
            bad_fixed_state = joinpath(directory, "fixed-projector-decoder-failure.h5")
            cp(checkpoint_file, bad_fixed_state);
            chmod(bad_fixed_state, 0o600)
            HDF5.h5open(bad_fixed_state, "r+") do handle
                @test read(handle["restart_state/fixed_subspace_projectors"]) ==
                      expected_fixed_projector
                handle["restart_state/fixed_subspace_projectors"][1, 1, 1] = 0.0 + 0.0im
                @test read(handle["restart_state/fixed_subspace_projectors"]) ==
                      zeros(ComplexF64, 1, 1, 1)
                @test read(handle["restart_state/fixed_subspace_frames"]) == expected_fixed_frame
            end
            @test !isfile(bad_fixed_state * ".commit.toml")
            target_persistence_expect_argument_error(
                () -> TARGET_PERSISTENCE_WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(
                    bad_fixed_state,
                ),
                "checkpoint fixed-subspace projector gate failed",
            )
            @test !isfile(bad_fixed_state * ".commit.toml")
        end

        @test restored_checkpoint.input_summary["checkpoint_schema_version"] == "3.0"
        @test restored_checkpoint.input_summary["construction_policy"] == "standard"
        @test restored_checkpoint.input_summary["construction_policy_contract"] ==
              "ordinary_construction_v2"
        @test restored_checkpoint.input_summary["quality_review_status"] == "RECOMMENDED"
        @test restored_checkpoint.input_summary["quality_review_status"] ==
              checkpoint_summary["quality_review_status"]
        @test restored_checkpoint.input_summary["construction_quality_failed"] == "true"
        @test last(restored_checkpoint.diagnostics).context["gate_result"] == "FAIL"
        @test last(restored_checkpoint.diagnostics).context["action"] == "CONTINUE_STANDARD"
        HDF5.h5open(checkpoint_file, "r") do handle
            @test !HDF5.read_attribute(handle, "production_eligible")
        end
        # These adopted-copy mutations test immutable publication lifetimes,
        # not content hashes or credential-based mathematical acceptance.
        for (label, key, value) in (
            ("policy", "construction_policy", "strict"),
            ("review", "quality_review_status", "APPROVED"),
        )
            tampered = joinpath(directory, "construction-$(label)-tampered.h5")
            cp(checkpoint_file, tampered)
            TARGET_PERSISTENCE_WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(tampered)
            chmod(tampered, 0o600)
            HDF5.h5open(tampered, "r+") do handle
                group = handle["input_summary"]
                @test haskey(HDF5.attributes(group), key)
                HDF5.delete_attribute(group, key)
                HDF5.attributes(group)[key] = value
            end
            target_persistence_expect_changed_publication(tampered)
        end
        stripped = joinpath(directory, "construction-contract-stripped.h5")
        cp(checkpoint_file, stripped)
        TARGET_PERSISTENCE_WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(stripped)
        chmod(stripped, 0o600)
        HDF5.h5open(stripped, "r+") do handle
            group = handle["input_summary"]
            for key in
                ("construction_policy_contract", "construction_policy", "quality_review_status")
                @test haskey(HDF5.attributes(group), key)
                HDF5.delete_attribute(group, key)
            end
        end
        target_persistence_expect_changed_publication(stripped)
        @testset "T10 semantically selected FAIL diagnostic" begin
            tampered = joinpath(directory, "construction-diagnostic-tampered.h5")
            cp(checkpoint_file, tampered)
            TARGET_PERSISTENCE_WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(tampered)
            chmod(tampered, 0o600)
            HDF5.h5open(tampered, "r+") do handle
                group = handle["diagnostics"]
                matches = [
                    String(name) for name in keys(group) if
                    String(HDF5.read_attribute(group[name], "code")) == "SYNTHETIC_QUALITY_GATE"
                ]
                @test length(matches) == 1
                key = only(matches)
                @test String(HDF5.read_attribute(group[key], "gate_result")) == "FAIL"
                @test String(HDF5.read_attribute(group[key], "action")) == "CONTINUE_STANDARD"
                @test haskey(HDF5.attributes(group[key]), "gate_result")
                HDF5.delete_attribute(group[key], "gate_result")
                HDF5.attributes(group[key])["gate_result"] = "PASS"
                @test String(HDF5.read_attribute(group[key], "gate_result")) == "PASS"
                @test String(HDF5.read_attribute(group[key], "code")) == "SYNTHETIC_QUALITY_GATE"
                @test String(HDF5.read_attribute(group[key], "action")) == "CONTINUE_STANDARD"
            end
            target_persistence_expect_changed_publication(tampered)
        end

        @test restored_checkpoint.input_summary["authoritative_hamiltonian"] == "native_dft"
        @test restored_checkpoint.input_summary["qualification_scope"] == "target_subspace"
        @test restored_checkpoint.input_summary["disentanglement_outer_mask_definition"] ==
              target_persistence_contract().qualification_scope.outer_mask_definition
        @test restored_checkpoint.input_summary["disentanglement_frozen_mask_definition"] ==
              target_persistence_contract().qualification_scope.frozen_mask_definition
        @test restored_checkpoint.input_summary["target_subspace_contract_definition"] ==
              target_persistence_contract().contract_definition
        @test restored_checkpoint.input_summary["target_leakage_semantics"] ==
              TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_SEMANTICS
        @test restored_checkpoint.input_summary["target_leakage_formula_definition"] ==
              TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_FORMULA_DEFINITION
        @test parse(Float64, restored_checkpoint.input_summary["target_leakage_threshold"]) ==
              5.0e-6

        symmetrized_checkpoint_summary = copy(checkpoint_summary)
        symmetrized_checkpoint_summary["authoritative_hamiltonian"] = "symmetrized_dft_hamiltonian"
        symmetrized_checkpoint_summary["auxiliary_parent_qualification"] = "audit_only"
        symmetrized_checkpoint_result = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationResult(
            solver_result.status,
            solver_result.v_matrix,
            solver_result.wannier_centers_cartesian,
            solver_result.spreads_angstrom2,
            solver_result.history,
            solver_result.diagnostics,
            symmetrized_checkpoint_summary,
            solver_result.wannier_chk,
            nothing,
            solver_result.restart_state,
            solver_result.artifacts,
        )
        symmetrized_checkpoint_file = joinpath(directory, "symmetrized-target-checkpoint.h5")
        TARGET_PERSISTENCE_WANNIERIZATION.write_wannierization_checkpoint_hdf5(
            symmetrized_checkpoint_file,
            symmetrized_checkpoint_result,
        )
        restored_symmetrized_checkpoint =
            TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
                symmetrized_checkpoint_file,
            )
        @test restored_symmetrized_checkpoint.input_summary["authoritative_hamiltonian"] ==
              "symmetrized_dft_hamiltonian"
        @test restored_symmetrized_checkpoint.input_summary["target_authority"] == "outer_window"

        @testset "T12 lifetime and independent decoder" begin
            tampered_checkpoint = joinpath(directory, "target-checkpoint-tampered.h5")
            cp(checkpoint_file, tampered_checkpoint)
            TARGET_PERSISTENCE_WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(
                tampered_checkpoint,
            )
            chmod(tampered_checkpoint, 0o600)
            HDF5.h5open(tampered_checkpoint, "r+") do handle
                @test haskey(HDF5.attributes(handle), "target_subspace_contract_definition")
                HDF5.delete_attribute(handle, "target_subspace_contract_definition")
                HDF5.attributes(handle)["target_subspace_contract_definition"] = "invalid-complete-target"
            end
            target_persistence_expect_changed_publication(tampered_checkpoint)
            decoder_path = tampered_checkpoint * ".decoder.h5"
            cp(tampered_checkpoint, decoder_path)
            @test !isfile(decoder_path * ".commit.toml")
            HDF5.h5open(checkpoint_file, "r") do original
                HDF5.h5open(decoder_path, "r") do changed
                    @test HDF5.read_attribute(changed, "publication_identity") ==
                          HDF5.read_attribute(original, "publication_identity")
                    @test read(changed["solution/v_matrix"]) == read(original["solution/v_matrix"])
                end
            end
            target_persistence_expect_argument_error(
                () -> TARGET_PERSISTENCE_WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(
                    decoder_path,
                ),
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: checkpoint target_subspace_contract_definition differs",
            )
            @test !isfile(decoder_path * ".commit.toml")
        end

        @testset "T12I identity-only rejection" begin
            identity_only = joinpath(directory, "checkpoint-identity-only.h5")
            cp(checkpoint_file, identity_only)
            TARGET_PERSISTENCE_WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(identity_only)
            unchanged_payload = read(identity_only)
            identity_receipt = identity_only * ".commit.toml"
            receipt = TOML.parsefile(identity_receipt)
            receipt["publication_identity"] = "intentional-different-publication"
            open(identity_receipt, "w") do stream
                TOML.print(stream, receipt)
            end
            @test read(identity_only) == unchanged_payload
            target_persistence_expect_argument_error(
                () -> TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
                    identity_only,
                ),
                "CHECKPOINT_PUBLICATION_DECLARATION_MISMATCH",
            )
        end

        @testset "T13 lifetime and independent decoder" begin
            tampered_leakage_semantics =
                joinpath(directory, "target-checkpoint-semantics-tampered.h5")
            cp(checkpoint_file, tampered_leakage_semantics)
            TARGET_PERSISTENCE_WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(
                tampered_leakage_semantics,
            )
            chmod(tampered_leakage_semantics, 0o600)
            HDF5.h5open(tampered_leakage_semantics, "r+") do handle
                @test haskey(HDF5.attributes(handle), "target_leakage_semantics")
                HDF5.delete_attribute(handle, "target_leakage_semantics")
                HDF5.attributes(handle)["target_leakage_semantics"] = "legacy_amplitude"
            end
            target_persistence_expect_changed_publication(tampered_leakage_semantics)
            decoder_path = tampered_leakage_semantics * ".decoder.h5"
            cp(tampered_leakage_semantics, decoder_path)
            @test !isfile(decoder_path * ".commit.toml")
            HDF5.h5open(checkpoint_file, "r") do original
                HDF5.h5open(decoder_path, "r") do changed
                    @test HDF5.read_attribute(changed, "publication_identity") ==
                          HDF5.read_attribute(original, "publication_identity")
                    @test read(changed["solution/v_matrix"]) == read(original["solution/v_matrix"])
                end
            end
            target_persistence_expect_argument_error(
                () -> TARGET_PERSISTENCE_WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(
                    decoder_path,
                ),
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: checkpoint target_leakage_semantics differs",
            )
            @test !isfile(decoder_path * ".commit.toml")
        end

        legacy_weight_checkpoint = joinpath(directory, "legacy-weight-target-checkpoint.h5")
        cp(checkpoint_file, legacy_weight_checkpoint)
        chmod(legacy_weight_checkpoint, 0o600)
        HDF5.h5open(legacy_weight_checkpoint, "r+") do handle
            @test haskey(HDF5.attributes(handle), "schema_version")
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "2.27"
        end
        legacy_weight_checkpoint_error = try
            target_persistence_adopt_and_read_checkpoint(legacy_weight_checkpoint)
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin(
            "CHECKPOINT_SCHEMA_UNSUPPORTED",
            something(legacy_weight_checkpoint_error, ""),
        )

        legacy_checkpoint = joinpath(directory, "legacy-authority-checkpoint.h5")
        cp(checkpoint_file, legacy_checkpoint)
        chmod(legacy_checkpoint, 0o600)
        HDF5.h5open(legacy_checkpoint, "r+") do handle
            input_group = handle["input_summary"]
            @test haskey(HDF5.attributes(input_group), "authoritative_hamiltonian")
            HDF5.delete_attribute(input_group, "authoritative_hamiltonian")
            HDF5.attributes(input_group)["authoritative_hamiltonian"] = "symmetrized_target_subspace_candidate"
        end
        legacy_checkpoint_error = try
            target_persistence_adopt_and_read_checkpoint(legacy_checkpoint)
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin("UNSUPPORTED_LEGACY_AUTHORITY", something(legacy_checkpoint_error, ""))
        @test !isfile(legacy_checkpoint * ".commit.toml")

        qualification = TARGET_PERSISTENCE_WANNIERIZATION.TBSymmetryQualification(
            "NOT_RUN",
            "SYNTHETIC_TARGET_PERSISTENCE",
            TARGET_PERSISTENCE_WANNIERIZATION.TBSymmetryMetric[];
            authoritative_hamiltonian = "native_dft",
            authoritative_hamiltonian_sha256 = repeat("1", 64),
        )
        qualification_file = joinpath(directory, "tb-qualification.h5")
        HDF5.h5open(qualification_file, "w") do handle
            Base.invokelatest(support.write_tb_symmetry_qualification_group, handle, qualification)
        end
        restored_qualification = HDF5.h5open(qualification_file, "r") do handle
            Base.invokelatest(support.read_tb_symmetry_qualification_group, handle)
        end
        @test restored_qualification.schema_version == "2.0"
        @test getfield.(restored_qualification.metrics, :value) ==
              getfield.(qualification.metrics, :value)

        legacy_qualification = joinpath(directory, "legacy-authority-tb-qualification.h5")
        cp(qualification_file, legacy_qualification)
        chmod(legacy_qualification, 0o600)
        HDF5.h5open(legacy_qualification, "r+") do handle
            group = handle["tb_symmetry_qualification"]
            @test haskey(HDF5.attributes(group), "authoritative_hamiltonian")
            HDF5.delete_attribute(group, "authoritative_hamiltonian")
            HDF5.attributes(group)["authoritative_hamiltonian"] = "symmetrized_hamiltonian_candidate"
        end
        legacy_qualification_error = HDF5.h5open(legacy_qualification, "r") do handle
            try
                Base.invokelatest(support.read_tb_symmetry_qualification_group, handle)
                nothing
            catch exception
                sprint(showerror, exception)
            end
        end
        @test occursin("UNSUPPORTED_LEGACY_AUTHORITY", something(legacy_qualification_error, ""))

        r_vectors = zeros(Int, 3, 1)
        operators = Dict(
            TARGET_PERSISTENCE_CORE.REAL_SPACE_HAMILTONIAN =>
                TARGET_PERSISTENCE_CORE.RealSpaceOperator(
                    TARGET_PERSISTENCE_CORE.RealSpaceOperatorSymmetrySpec(
                        TARGET_PERSISTENCE_CORE.REAL_SPACE_HAMILTONIAN,
                        0,
                        1,
                        1,
                    ),
                    r_vectors,
                    zeros(ComplexF64, 1, 1, 1),
                ),
            TARGET_PERSISTENCE_CORE.REAL_SPACE_POSITION =>
                TARGET_PERSISTENCE_CORE.RealSpaceOperator(
                    TARGET_PERSISTENCE_CORE.RealSpaceOperatorSymmetrySpec(
                        TARGET_PERSISTENCE_CORE.REAL_SPACE_POSITION,
                        1,
                        -1,
                        1,
                    ),
                    r_vectors,
                    zeros(ComplexF64, 1, 1, 3, 1),
                ),
        )

        target_semantics=Dict{String, Any}(
            "qualification_scope"=>"target_subspace",
            "target_anchor"=>"completed_symmetrized_target",
            "target_leakage_semantics"=>TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_SEMANTICS,
            "target_leakage_formula_definition"=>TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_FORMULA_DEFINITION,
            "target_leakage_threshold"=>5.0e-6,
            "production_eligible"=>false,
        )
        bundle_file=joinpath(directory, "target-operators.h5")
        TARGET_PERSISTENCE_IO.write_real_space_operator_bundle(
            bundle_file,
            Matrix{Float64}(I, 3, 3),
            [1],
            operators;
            geometry = target_persistence_geometry(),
            eligibility = target_semantics,
            provenance = Dict("authoritative_hamiltonian"=>"symmetrized_dft_hamiltonian"),
        )
        manifest=TARGET_PERSISTENCE_IO.read_real_space_operator_bundle_manifest(bundle_file)
        @test manifest.schema_version=="3.0"
        @test manifest.qualification_scope=="target_subspace"
        @test manifest.target_anchor=="completed_symmetrized_target"
        @test manifest.target_leakage_semantics==target_semantics["target_leakage_semantics"]
        @test manifest.target_leakage_formula_sha256==target_semantics["target_leakage_formula_definition"]
        @test manifest.target_leakage_threshold==5.0e-6
        @test manifest.authoritative_hamiltonian=="symmetrized_dft_hamiltonian"
        @test !manifest.production_eligible
        HDF5.h5open(bundle_file, "r") do h
            @test !haskey(h, "qualification")
            @test HDF5.read_attribute(h["definitions"], "symmetry_scope")=="target_subspace"
            @test !haskey(HDF5.attributes(h), "outer_mask_sha256")
        end
        for kind in keys(operators)
            @test TARGET_PERSISTENCE_IO.read_real_space_operator_bundle(
                bundle_file,
            ).operators[kind].data==operators[kind].data
        end
        @testset "T19 fresh model units decoder" begin
            # Current model3.0 adoption is its mathematical manifest reader and
            # intentionally has no publication-receipt contract (unlike checkpoint).
            fresh_units = joinpath(directory, "bad-units-fresh-decoder.h5")
            @test !ispath(fresh_units)
            cp(bundle_file, fresh_units);
            chmod(fresh_units, 0o600)
            @test !isfile(fresh_units * ".commit.toml")
            HDF5.h5open(fresh_units, "r+") do h
                @test String(HDF5.read_attribute(h, "schema_version")) == "3.0"
                @test String(HDF5.read_attribute(h, "energy_unit")) == "eV"
                HDF5.delete_attribute(h, "energy_unit")
                HDF5.attributes(h)["energy_unit"] = "unknown"
                @test String(HDF5.read_attribute(h, "energy_unit")) == "unknown"
            end
            target_persistence_expect_argument_error(
                () -> TARGET_PERSISTENCE_IO.adopt_real_space_operator_bundle(fresh_units),
                "unsupported mathematical definition: energy_unit",
            )
            @test !isfile(fresh_units * ".commit.toml")
        end
    end
end
