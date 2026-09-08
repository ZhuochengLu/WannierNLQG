using HDF5
using Test
using WannierNLQG

const OperatorBundleCore = WannierNLQG.Core
const OperatorBundleIO = WannierNLQG.IO
const OperatorBundleRuntime = WannierNLQG.Runtime

function test_operator_bundle_frame_contract(;
    source_band_gauge = "native_dft_eigenstate",
    target_band_gauge = "symmetrized_dft_hamiltonian",
    transform_sha256 = repeat("5", 64),
    contract_sha256 = repeat("6", 64),
    gauge_artifact_sha256 = repeat("4", 64),
)
    return Dict{String, Any}(
        "schema" => "WannierNLQG.band_frame_transform_contract",
        "schema_version" => "1.0",
        "status" => "PASS",
        "legacy" => false,
        "source_band_gauge" => source_band_gauge,
        "target_band_gauge" => target_band_gauge,
        "transform_sha256" => transform_sha256,
        "contract_sha256" => contract_sha256,
        "gauge_artifact_sha256" => gauge_artifact_sha256,
        "metric_kind" => "paw_generalized_overlap",
        "physical_isometry_maximum" => 2.0e-10,
        "physical_isometry_tolerance" => 1.0e-8,
        "replay_maximum" => 3.0e-10,
        "replay_tolerance" => 1.0e-8,
        "euclidean_nonunitarity_maximum" => 2.0e-6,
        "minimum_singular_value" => 0.999999,
        "maximum_condition_number" => 1.000002,
    )
end

function test_pair_wigner_seitz_provenance(names; residuals = nothing)
    values =
        residuals === nothing ?
        Dict(String(name) => 1.0e-12 * index for (index, name) in enumerate(names)) :
        Dict{String, Float64}(String(name) => Float64(value) for (name, value) in residuals)
    return Dict{String, Any}(
        "operator_profile_assembly_algorithm_version" => "focused-pair-wigner-seitz-v1",
        "pair_wigner_seitz_roundtrip_policy" => "PAIR_DEPENDENT_MINIMUM_DISTANCE_UNIT_DEGENERACY",
        "pair_wigner_seitz_roundtrip_tolerance" => 1.0e-8,
        "pair_wigner_seitz_roundtrip_residuals" => values,
    )
end

function write_hamiltonian_position_bundle(directory, model_file)
    model = OperatorBundleIO.read_wannier_tb(model_file)
    operators =
        Dict{OperatorBundleCore.RealSpaceOperatorKind, OperatorBundleCore.RealSpaceOperator}(
            OperatorBundleCore.REAL_SPACE_HAMILTONIAN => OperatorBundleCore.RealSpaceOperator(
                OperatorBundleCore.RealSpaceOperatorSymmetrySpec(
                    OperatorBundleCore.REAL_SPACE_HAMILTONIAN,
                    0,
                    1,
                    1,
                ),
                model.r_vectors,
                model.hamiltonian_r,
            ),
            OperatorBundleCore.REAL_SPACE_POSITION => OperatorBundleCore.RealSpaceOperator(
                OperatorBundleCore.RealSpaceOperatorSymmetrySpec(
                    OperatorBundleCore.REAL_SPACE_POSITION,
                    1,
                    -1,
                    1,
                ),
                model.r_vectors,
                model.position_r,
            ),
        )
    bundle_file = joinpath(directory, "wannierNLQG_tb.h5")
    OperatorBundleIO.write_real_space_operator_bundle(
        bundle_file,
        model.lattice,
        model.r_degeneracies,
        operators;
        profile = :hamiltonian_position,
        paired_tb_sha256 = OperatorBundleRuntime.checksum_file(model_file),
        geometry = test_operator_bundle_geometry(model.lattice, model.r_degeneracies, operators),
    )
    return bundle_file
end

function run_shift_current_source(directory, model_file, bundle_file, backend)
    mixed = backend == "mixed" ? (NKdiv = (1, 1), NKFFT = (2, 2)) : NamedTuple()
    config = WannierNLQG.Runtime.EffectiveTaskConfig(;
        tasks = [("SC", "Conventional", "Integral")],
        model_file,
        real_space_operator_bundle_file = bundle_file,
        output_root = directory,
        system_name = "operator_bundle_runtime",
        k_mesh = (2, 2),
        fourier_backend = backend,
        mixed...,
        photon_energies = [0.2],
        fermi_energy = -2.5,
        progress_enabled = false,
    )
    return WannierNLQG.run(config)
end

function run_shift_current_kslice_source(directory, model_file, bundle_file)
    config = WannierNLQG.Runtime.EffectiveTaskConfig(
        tasks = [("SCK", "Conventional", "K-slice")],
        model_file = model_file,
        real_space_operator_bundle_file = bundle_file,
        output_root = directory,
        system_name = "operator_bundle_runtime_kslice",
        k_mesh = (2, 2),
        fourier_backend = "direct",
        photon_energies = [0.2],
        fermi_energy = -2.5,
        tensor_indices = (1, 1, 1),
        band_selection = (2, 1),
        kslice_origin = (0.0, 0.0, 0.0),
        kslice_vector_1 = (1.0, 0.0, 0.0),
        kslice_vector_2 = (0.0, 1.0, 0.0),
        progress_enabled = false,
    )
    return WannierNLQG.run(config)
end

@testset "Packed HDF5 Runtime demand and dual-input parity" begin
    mktempdir() do directory
        model_file = TEST_MODEL_FILE
        bundle_file = write_hamiltonian_position_bundle(directory, model_file)
        manifest = OperatorBundleIO.read_real_space_operator_bundle_manifest(bundle_file)
        @test manifest.schema_version == "1.0"
        HDF5.h5open(bundle_file, "r") do handle
            @test String(read(HDF5.attributes(handle)["wanniernlqg_version"])) ==
                  string(Base.pkgversion(WannierNLQG))
        end
        internal_predecessor_file = joinpath(directory, "wannierNLQG_tb_internal_v2.4.0.h5")
        cp(bundle_file, internal_predecessor_file)
        HDF5.h5open(internal_predecessor_file, "r+") do handle
            root_attributes = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "wanniernlqg_version")
            root_attributes["wanniernlqg_version"] = "2.4.0"
        end
        @test OperatorBundleIO.read_real_space_operator_bundle_manifest(
            internal_predecessor_file,
        ).schema_version == "1.0"
        @test manifest.band_frame_contract_status == "NOT_APPLICABLE"
        @test manifest.spin_family_qualification == "NOT_APPLICABLE"
        @test !manifest.spin_family_production_eligible
        @test manifest.finite_band_galerkin_qualification == "NOT_APPLICABLE"
        @test !manifest.finite_band_galerkin_production_eligible
        @test length(manifest.operator_qualification_sha256) == 64
        @test manifest.qualification_scope == "full_parent"
        @test manifest.target_leakage_semantics == "NOT_APPLICABLE"
        @test manifest.target_leakage_formula_sha256 == "NOT_RECORDED"
        @test manifest.target_leakage_threshold === nothing

        tampered_qualification = joinpath(directory, "tampered-qualification.h5")
        cp(bundle_file, tampered_qualification)
        HDF5.h5open(tampered_qualification, "r+") do handle
            spin = handle["qualification/families/spin"]
            HDF5.delete_attribute(spin, "reason")
            HDF5.attributes(spin)["reason"] = "TAMPERED"
        end
        @test_throws ArgumentError OperatorBundleIO.read_real_space_operator_bundle_manifest(
            tampered_qualification,
        )

        bundle_extension, _ = OperatorBundleIO._load_operator_bundle_extension!()
        legacy_scientific_digest = Base.invokelatest(
            bundle_extension._scientific_content_digest,
            manifest.profile,
            manifest.inventory,
            manifest.lattice,
            manifest.r_vectors,
            manifest.degeneracies,
            getfield.(manifest.entries, :component_sha256),
            manifest.paired_tb_sha256,
            "5.9",
            manifest.geometry_content_sha256,
            manifest.authoritative_hamiltonian,
            manifest.authoritative_hamiltonian_sha256,
            manifest.energy_shift_qualification,
            manifest.maximum_energy_shift_audit_reference_ev,
            manifest.rms_energy_shift_audit_reference_ev,
            manifest.target_energy_shift_audit_status,
            manifest.symmetrized_parent_energy_shift_audit_status,
            manifest.residual_gate_phase,
            manifest.raw_preflight_diagnostic_status,
            manifest.native_difference_qualification,
            manifest.native_difference_audit_status,
            manifest.qualification_scope,
            manifest.target_anchor,
            manifest.target_complement_completion,
            manifest.target_complement_max_element_ev,
            manifest.auxiliary_parent_qualification,
            manifest.symmetrized_target_subspace_status,
            manifest.auxiliary_parent_audit_status,
            manifest.target_scope_production_eligible,
            manifest.parent_audit_policy,
            manifest.outer_mask_sha256,
            manifest.frozen_mask_sha256,
            manifest.target_subspace_contract_sha256,
            manifest.target_leakage_semantics,
            manifest.target_leakage_formula_sha256,
            manifest.target_leakage_threshold,
            manifest.derivative_overlap_source,
            manifest.derivative_overlap_completeness,
            something(manifest.derivative_overlap_source_sha256, "not_provided"),
            manifest.derivative_overlap_algorithm_version,
            manifest.target_authority,
        )
        legacy_full_parent_bundle = joinpath(directory, "legacy-full-parent-5.9.h5")
        cp(bundle_file, legacy_full_parent_bundle)
        HDF5.h5open(legacy_full_parent_bundle, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "5.9"
            HDF5.delete_attribute(handle, "scientific_content_sha256")
            HDF5.attributes(handle)["scientific_content_sha256"] = legacy_scientific_digest
            compatibility = handle["compatibility"]
            HDF5.delete_attribute(compatibility, "minimum_reader_schema")
            HDF5.attributes(compatibility)["minimum_reader_schema"] = "5.9"
        end
        legacy_manifest =
            OperatorBundleIO.read_real_space_operator_bundle_manifest(legacy_full_parent_bundle)
        @test legacy_manifest.schema_version == "5.9"
        @test legacy_manifest.qualification_scope == "full_parent"
        @test legacy_manifest.target_leakage_semantics == "LEGACY_AMPLITUDE_LEAKAGE_CONTRACT"
        @test legacy_manifest.target_leakage_formula_sha256 == "NOT_RECORDED"
        @test legacy_manifest.target_leakage_threshold === nothing
        legacy_runtime = run_shift_current_source(
            joinpath(directory, "legacy_schema_runtime"),
            model_file,
            legacy_full_parent_bundle,
            "direct",
        )
        legacy_runtime_metadata = read(legacy_runtime.metadata_path, String)
        @test occursin(r"source\s*= legacy_input", legacy_runtime_metadata)
        @test occursin(r"input_minimum_distance_materialized\s*= nothing", legacy_runtime_metadata)

        requested = Dict(
            OperatorBundleCore.REAL_SPACE_HAMILTONIAN => [(Int8(0), Int8(0))],
            OperatorBundleCore.REAL_SPACE_POSITION => [(Int8(1), Int8(0))],
        )
        buffered = OperatorBundleIO.read_operator_bundle_components(
            bundle_file,
            requested;
            prefer_mmap = false,
        )
        @test buffered.read_mode == :buffered
        @test Set(keys(buffered.components)) == Set(keys(requested))

        for backend in ("direct", "mixed", "auto")
            legacy = run_shift_current_source(
                joinpath(directory, "legacy_$(backend)"),
                model_file,
                nothing,
                backend,
            )
            packed = run_shift_current_source(
                joinpath(directory, "packed_$(backend)"),
                model_file,
                bundle_file,
                backend,
            )
            @test length(legacy.outputs) == length(packed.outputs) == 1
            @test read(only(legacy.outputs)) == read(only(packed.outputs))
        end

        legacy_kslice = run_shift_current_kslice_source(
            joinpath(directory, "legacy_kslice"),
            model_file,
            nothing,
        )
        packed_kslice = run_shift_current_kslice_source(
            joinpath(directory, "packed_kslice"),
            model_file,
            bundle_file,
        )
        @test length(legacy_kslice.outputs) == length(packed_kslice.outputs)
        @test read.(legacy_kslice.outputs) == read.(packed_kslice.outputs)

        insufficient = WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("ISC", "Conventional", "Integral")],
            model_file = model_file,
            real_space_operator_bundle_file = bundle_file,
            output_root = joinpath(directory, "insufficient"),
            k_mesh = (2, 2),
            fourier_backend = "direct",
            photon_energies = [0.2],
            tensor_indices = (1, 1, 1, 1),
            progress_enabled = false,
        )
        insufficient_error = try
            WannierNLQG.run(insufficient)
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test insufficient_error !== nothing
        @test occursin("spin_times_hamiltonian", something(insufficient_error, ""))
        @test occursin(
            "Current bundle profile: hamiltonian_position",
            something(insufficient_error, ""),
        )

        mixed_sources = WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("SC", "Conventional", "Integral")],
            model_file = model_file,
            real_space_operator_bundle_file = bundle_file,
            seedname = "forbidden",
            output_root = joinpath(directory, "mixed_sources"),
            k_mesh = (2, 2),
            fourier_backend = "direct",
            progress_enabled = false,
        )
        @test_throws ErrorException WannierNLQG.run(mixed_sources)

        mismatched_tb = joinpath(directory, "mismatched_tb.dat")
        cp(model_file, mismatched_tb)
        open(mismatched_tb, "a") do io
            println(io, "digest mismatch fixture")
        end
        digest_mismatch = WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("SC", "Conventional", "Integral")],
            model_file = mismatched_tb,
            real_space_operator_bundle_file = bundle_file,
            output_root = joinpath(directory, "digest_mismatch"),
            k_mesh = (2, 2),
            fourier_backend = "direct",
            progress_enabled = false,
        )
        @test_throws ErrorException WannierNLQG.run(digest_mismatch)
        @test manifest.paired_tb_sha256 == OperatorBundleRuntime.checksum_file(model_file)
    end
end

@testset "schema-6.0 spin-family legacy qualification is diagnostic-only" begin
    mktempdir() do directory
        model = OperatorBundleIO.read_wannier_tb(TEST_MODEL_FILE)
        specs = Dict(
            OperatorBundleCore.REAL_SPACE_HAMILTONIAN =>
                OperatorBundleCore.RealSpaceOperatorSymmetrySpec(
                    OperatorBundleCore.REAL_SPACE_HAMILTONIAN,
                    0,
                    1,
                    1,
                ),
            OperatorBundleCore.REAL_SPACE_POSITION =>
                OperatorBundleCore.RealSpaceOperatorSymmetrySpec(
                    OperatorBundleCore.REAL_SPACE_POSITION,
                    1,
                    -1,
                    1,
                ),
            OperatorBundleCore.REAL_SPACE_SPIN =>
                OperatorBundleCore.RealSpaceOperatorSymmetrySpec(
                    OperatorBundleCore.REAL_SPACE_SPIN,
                    1,
                    1,
                    -1,
                ),
        )
        operators = Dict(
            OperatorBundleCore.REAL_SPACE_HAMILTONIAN => OperatorBundleCore.RealSpaceOperator(
                specs[OperatorBundleCore.REAL_SPACE_HAMILTONIAN],
                model.r_vectors,
                model.hamiltonian_r,
            ),
            OperatorBundleCore.REAL_SPACE_POSITION => OperatorBundleCore.RealSpaceOperator(
                specs[OperatorBundleCore.REAL_SPACE_POSITION],
                model.r_vectors,
                model.position_r,
            ),
            OperatorBundleCore.REAL_SPACE_SPIN => OperatorBundleCore.RealSpaceOperator(
                specs[OperatorBundleCore.REAL_SPACE_SPIN],
                model.r_vectors,
                zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3, model.num_r_vectors),
            ),
        )
        geometry = test_operator_bundle_geometry(model.lattice, model.r_degeneracies, operators)
        geometry["production_eligible"] = false
        current = joinpath(directory, "spin-schema-6.3.h5")
        OperatorBundleIO.write_real_space_operator_bundle(
            current,
            model.lattice,
            model.r_degeneracies,
            operators;
            profile = :hamiltonian_position_spin,
            geometry,
            provenance = test_pair_wigner_seitz_provenance(("spin",)),
        )
        current_manifest = OperatorBundleIO.read_real_space_operator_bundle_manifest(current)
        @test current_manifest.spin_family_qualification == "FAIL"
        @test current_manifest.diagnostic_only
        current_spin_record = current_manifest.operator_qualification["operators"]["spin"]
        current_pair_transform = current_spin_record["pair_wigner_seitz_transform"]
        @test current_pair_transform["algorithm"] == "WannierNLQG.PairWignerSeitzSpinQToRTransform"
        @test current_pair_transform["algorithm_version"] == "focused-pair-wigner-seitz-v1"
        @test current_pair_transform["policy"] == "PAIR_DEPENDENT_MINIMUM_DISTANCE_UNIT_DEGENERACY"
        @test current_pair_transform["residual"] == 1.0e-12
        @test current_pair_transform["tolerance"] == 1.0e-8
        @test current_pair_transform["status"] == "PASS"
        current_pair_family =
            current_manifest.operator_qualification["families"]["spin"]["pair_wigner_seitz_transform"]
        @test current_pair_family["maximum_residual"] == 1.0e-12
        @test current_pair_family["worst_operator"] == "spin"
        @test current_pair_family["status"] == "PASS"

        changed_pair = joinpath(directory, "spin-schema-6.3-changed-pair-residual.h5")
        OperatorBundleIO.write_real_space_operator_bundle(
            changed_pair,
            model.lattice,
            model.r_degeneracies,
            operators;
            profile = :hamiltonian_position_spin,
            geometry,
            provenance = test_pair_wigner_seitz_provenance(
                ("spin",);
                residuals = Dict("spin" => 2.0e-12),
            ),
        )
        changed_pair_manifest =
            OperatorBundleIO.read_real_space_operator_bundle_manifest(changed_pair)
        @test getfield.(changed_pair_manifest.entries, :component_sha256) ==
              getfield.(current_manifest.entries, :component_sha256)
        @test changed_pair_manifest.operator_qualification_sha256 !=
              current_manifest.operator_qualification_sha256
        @test changed_pair_manifest.scientific_content_sha256 !=
              current_manifest.scientific_content_sha256

        missing_pair = joinpath(directory, "spin-schema-6.3-missing-pair-contract.h5")
        missing_pair_error = try
            OperatorBundleIO.write_real_space_operator_bundle(
                missing_pair,
                model.lattice,
                model.r_degeneracies,
                operators;
                profile = :hamiltonian_position_spin,
                geometry,
            )
            nothing
        catch exception
            exception
        end
        @test missing_pair_error isa ArgumentError
        @test occursin(
            "SPIN_PAIR_WIGNER_SEITZ_CONTRACT_NOT_RECORDED",
            sprint(showerror, missing_pair_error),
        )
        @test !isfile(missing_pair)

        failed_pair = joinpath(directory, "spin-schema-6.3-failed-pair-roundtrip.h5")
        failed_pair_error = try
            OperatorBundleIO.write_real_space_operator_bundle(
                failed_pair,
                model.lattice,
                model.r_degeneracies,
                operators;
                profile = :hamiltonian_position_spin,
                geometry,
                provenance = test_pair_wigner_seitz_provenance(
                    ("spin",);
                    residuals = Dict("spin" => 2.0e-8),
                ),
            )
            nothing
        catch exception
            exception
        end
        @test failed_pair_error isa ArgumentError
        @test occursin(
            "SPIN_PAIR_WIGNER_SEITZ_ROUNDTRIP_FAILED",
            sprint(showerror, failed_pair_error),
        )
        @test !isfile(failed_pair)

        tampered_pair = joinpath(directory, "spin-schema-6.3-tampered-pair-contract.h5")
        cp(current, tampered_pair)
        HDF5.h5open(tampered_pair, "r+") do handle
            transform = handle["qualification/operators/spin/pair_wigner_seitz_transform"]
            HDF5.delete_attribute(transform, "residual")
            HDF5.attributes(transform)["residual"] = 5.0e-12
        end
        @test_throws ArgumentError OperatorBundleIO.read_real_space_operator_bundle_manifest(
            tampered_pair,
        )

        extension, _ = OperatorBundleIO._load_operator_bundle_extension!()
        numerical_qualification = deepcopy(current_manifest.operator_qualification)
        spin_record = numerical_qualification["operators"]["spin"]
        frame_contract = test_operator_bundle_frame_contract()
        merge!(
            spin_record,
            Dict(
                "source_status" => "PASS",
                "gauge_status" => "PASS",
                "source_provenance_sha256" => repeat("1", 64),
                "source_artifact_sha256" => repeat("2", 64),
                "source_input_sha256" => Dict("SPN" => repeat("3", 64)),
                "source_band_gauge" => "native_dft_eigenstate",
                "target_band_gauge" => "symmetrized_dft_hamiltonian",
                "gauge_artifact_sha256" => repeat("4", 64),
                "band_gauge_rotation_sha256" => repeat("5", 64),
                "band_gauge_rotation_semantics" => "legacy_alias_of_band_frame_transform_sha256",
                "band_frame_transform_sha256" => repeat("5", 64),
                "band_frame_contract_sha256" => repeat("6", 64),
                "band_frame_contract" => frame_contract,
                "symmetry_projection" => "APPLIED",
                "covariance_before" => 1.0e-3,
                "covariance_after" => 1.0e-7,
                "covariance_tolerance" => 1.0e-8,
                "idempotence_residual" => 1.0e-12,
                "idempotence_tolerance" => 1.0e-9,
                "qualification" => "FAIL",
                "reason" => "NUMERICAL_SYMMETRY_QUALIFICATION_FAILED",
            ),
        )
        digest_payload = Dict{String, Any}(
            key => value for (key, value) in spin_record if key != "payload_sha256"
        )
        spin_record["payload_sha256"] =
            Base.invokelatest(extension._operator_qualification_digest, digest_payload)
        spin_family = numerical_qualification["families"]["spin"]
        spin_family["route"] = "symmetrized_sawf"
        spin_family["overall"] = "FAIL"
        spin_family["reason"] = "NUMERICAL_SYMMETRY_QUALIFICATION_FAILED"
        spin_family["production_eligible"] = false
        numerical = joinpath(directory, "spin-schema-6.3-numerical-fail.h5")
        OperatorBundleIO.write_real_space_operator_bundle(
            numerical,
            model.lattice,
            model.r_degeneracies,
            operators;
            profile = :hamiltonian_position_spin,
            geometry,
            provenance = merge(
                test_pair_wigner_seitz_provenance(("spin",)),
                Dict(
                    "operator_qualification" => numerical_qualification,
                    "band_frame_contract" => frame_contract,
                ),
            ),
        )
        @test isfile(numerical)
        numerical_manifest = OperatorBundleIO.read_real_space_operator_bundle_manifest(numerical)
        @test numerical_manifest.spin_family_qualification == "FAIL"
        @test numerical_manifest.spin_family_qualification_reason ==
              "NUMERICAL_SYMMETRY_QUALIFICATION_FAILED"
        @test !numerical_manifest.production_eligible
        @test numerical_manifest.diagnostic_only
        @test numerical_manifest.band_frame_contract_status == "PASS"
        @test numerical_manifest.band_frame_transform_sha256 == repeat("5", 64)
        @test numerical_manifest.band_frame_physical_isometry_maximum == 2.0e-10
        @test numerical_manifest.band_frame_euclidean_nonunitarity_maximum == 2.0e-6
        numerical_pair =
            numerical_manifest.operator_qualification["operators"]["spin"]["pair_wigner_seitz_transform"]
        @test numerical_pair["residual"] == 1.0e-12
        @test numerical_pair["status"] == "PASS"
        numerical_pair_family =
            numerical_manifest.operator_qualification["families"]["spin"]["pair_wigner_seitz_transform"]
        @test numerical_pair_family["maximum_residual"] == numerical_pair["residual"]
        @test numerical_pair_family["worst_operator"] == "spin"

        legacy_61_digest = Base.invokelatest(
            extension._scientific_content_digest,
            numerical_manifest.profile,
            numerical_manifest.inventory,
            numerical_manifest.lattice,
            numerical_manifest.r_vectors,
            numerical_manifest.degeneracies,
            getfield.(numerical_manifest.entries, :component_sha256),
            numerical_manifest.paired_tb_sha256,
            "6.1",
            numerical_manifest.geometry_content_sha256,
            numerical_manifest.authoritative_hamiltonian,
            numerical_manifest.authoritative_hamiltonian_sha256,
            numerical_manifest.energy_shift_qualification,
            numerical_manifest.maximum_energy_shift_audit_reference_ev,
            numerical_manifest.rms_energy_shift_audit_reference_ev,
            numerical_manifest.target_energy_shift_audit_status,
            numerical_manifest.symmetrized_parent_energy_shift_audit_status,
            numerical_manifest.residual_gate_phase,
            numerical_manifest.raw_preflight_diagnostic_status,
            numerical_manifest.native_difference_qualification,
            numerical_manifest.native_difference_audit_status,
            numerical_manifest.qualification_scope,
            numerical_manifest.target_anchor,
            numerical_manifest.target_complement_completion,
            numerical_manifest.target_complement_max_element_ev,
            numerical_manifest.auxiliary_parent_qualification,
            numerical_manifest.symmetrized_target_subspace_status,
            numerical_manifest.auxiliary_parent_audit_status,
            numerical_manifest.target_scope_production_eligible,
            numerical_manifest.parent_audit_policy,
            numerical_manifest.outer_mask_sha256,
            numerical_manifest.frozen_mask_sha256,
            numerical_manifest.target_subspace_contract_sha256,
            numerical_manifest.target_leakage_semantics,
            numerical_manifest.target_leakage_formula_sha256,
            numerical_manifest.target_leakage_threshold,
            numerical_manifest.derivative_overlap_source,
            numerical_manifest.derivative_overlap_completeness,
            something(numerical_manifest.derivative_overlap_source_sha256, "not_provided"),
            numerical_manifest.derivative_overlap_algorithm_version,
            numerical_manifest.target_authority,
            numerical_manifest.operator_qualification_sha256,
        )
        legacy_61 = joinpath(directory, "spin-schema-6.1-nontrivial-frame.h5")
        cp(numerical, legacy_61)
        HDF5.h5open(legacy_61, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "6.1"
            HDF5.delete_attribute(handle, "scientific_content_sha256")
            HDF5.attributes(handle)["scientific_content_sha256"] = legacy_61_digest
        end
        legacy_61_manifest = OperatorBundleIO.read_real_space_operator_bundle_manifest(legacy_61)
        @test legacy_61_manifest.schema_version == "6.1"
        @test legacy_61_manifest.spin_family_qualification == "LEGACY_NOT_RECORDED"
        @test legacy_61_manifest.spin_family_qualification_reason ==
              "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED"
        @test legacy_61_manifest.band_frame_contract_status ==
              "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED"
        @test !legacy_61_manifest.spin_family_production_eligible

        spin_config = WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("ZIBCK", "Conventional", "K-slice")],
            real_space_operator_bundle_file = numerical,
            output_root = joinpath(directory, "spin-warning"),
            k_mesh = (2, 2),
            fourier_backend = "direct",
            tensor_indices = (1, 1),
            band_selection = (2, 1),
            progress_enabled = false,
        )
        spin_specs = OperatorBundleRuntime.normalize_task_specs(spin_config)
        spin_context = OperatorBundleRuntime.prepare_run_context(spin_config, spin_specs)
        spin_log = joinpath(directory, "spin-warning.log")
        spin_sources = open(spin_log, "w") do stream
            redirect_stdout(stream) do
                OperatorBundleRuntime.load_runtime_model_and_sources(spin_context, spin_config)
            end
        end
        OperatorBundleRuntime.release_runtime_storage!(spin_sources)
        @test occursin(
            "requested spin-family operators are DIAGNOSTIC_ONLY",
            read(spin_log, String),
        )
        @test occursin("reason=NUMERICAL_SYMMETRY_QUALIFICATION_FAILED", read(spin_log, String))
        charge_config = WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("SC", "Conventional", "Integral")],
            real_space_operator_bundle_file = numerical,
            output_root = joinpath(directory, "charge-warning"),
            k_mesh = (2, 2),
            fourier_backend = "direct",
            progress_enabled = false,
        )
        charge_specs = OperatorBundleRuntime.normalize_task_specs(charge_config)
        charge_context = OperatorBundleRuntime.prepare_run_context(charge_config, charge_specs)
        charge_log = joinpath(directory, "charge-warning.log")
        charge_sources = open(charge_log, "w") do stream
            redirect_stdout(stream) do
                OperatorBundleRuntime.load_runtime_model_and_sources(charge_context, charge_config)
            end
        end
        OperatorBundleRuntime.release_runtime_storage!(charge_sources)
        @test !occursin(
            "requested spin-family operators are DIAGNOSTIC_ONLY",
            read(charge_log, String),
        )

        legacy_digest = Base.invokelatest(
            extension._scientific_content_digest,
            current_manifest.profile,
            current_manifest.inventory,
            current_manifest.lattice,
            current_manifest.r_vectors,
            current_manifest.degeneracies,
            getfield.(current_manifest.entries, :component_sha256),
            current_manifest.paired_tb_sha256,
            "6.0",
            current_manifest.geometry_content_sha256,
            current_manifest.authoritative_hamiltonian,
            current_manifest.authoritative_hamiltonian_sha256,
            current_manifest.energy_shift_qualification,
            current_manifest.maximum_energy_shift_audit_reference_ev,
            current_manifest.rms_energy_shift_audit_reference_ev,
            current_manifest.target_energy_shift_audit_status,
            current_manifest.symmetrized_parent_energy_shift_audit_status,
            current_manifest.residual_gate_phase,
            current_manifest.raw_preflight_diagnostic_status,
            current_manifest.native_difference_qualification,
            current_manifest.native_difference_audit_status,
            current_manifest.qualification_scope,
            current_manifest.target_anchor,
            current_manifest.target_complement_completion,
            current_manifest.target_complement_max_element_ev,
            current_manifest.auxiliary_parent_qualification,
            current_manifest.symmetrized_target_subspace_status,
            current_manifest.auxiliary_parent_audit_status,
            current_manifest.target_scope_production_eligible,
            current_manifest.parent_audit_policy,
            current_manifest.outer_mask_sha256,
            current_manifest.frozen_mask_sha256,
            current_manifest.target_subspace_contract_sha256,
            current_manifest.target_leakage_semantics,
            current_manifest.target_leakage_formula_sha256,
            current_manifest.target_leakage_threshold,
            current_manifest.derivative_overlap_source,
            current_manifest.derivative_overlap_completeness,
            something(current_manifest.derivative_overlap_source_sha256, "not_provided"),
            current_manifest.derivative_overlap_algorithm_version,
            current_manifest.target_authority,
        )
        legacy = joinpath(directory, "spin-schema-6.0.h5")
        cp(current, legacy)
        HDF5.h5open(legacy, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "6.0"
            HDF5.delete_attribute(handle, "scientific_content_sha256")
            HDF5.attributes(handle)["scientific_content_sha256"] = legacy_digest
        end
        manifest = OperatorBundleIO.read_real_space_operator_bundle_manifest(legacy)
        @test manifest.schema_version == "6.0"
        @test manifest.spin_family_qualification == "LEGACY_NOT_RECORDED"
        @test manifest.spin_family_qualification_reason ==
              "SCHEMA_6_0_SPIN_QUALIFICATION_NOT_RECORDED"
        @test !manifest.spin_family_production_eligible
        @test !manifest.production_eligible
        @test !manifest.scoped_production_eligible
        @test manifest.diagnostic_only
    end
end
