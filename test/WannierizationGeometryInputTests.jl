using Test, LinearAlgebra
@testset "G1 normalized geometry rectangular independent input" begin
    w=WannierNLQG.Wannierization;
    sf=WannierNLQG.SymmetryFoundation;
    wp=WannierNLQG.WannierProjection
    @test w.WANNIERIZATION_CONFIG_LEAF_FIELDS == (
        :construction_policy,
        :wannierization_mode,
        :source,
        :sewing_backend,
        :wavefunction_gauge_backend,
        :authoritative_hamiltonian,
        :wavefunction_gauge_hdf5,
        :win_file,
        :eig_file,
        :mmn_file,
        :amn_file,
        :matrix_elements,
        :projection_basis,
        :band_representation,
        :band_representation_hdf5,
        :outer_min_ev,
        :outer_max_ev,
        :frozen_min_ev,
        :frozen_max_ev,
        :frozen_states,
        :num_wannier,
        :symmetry_tolerance,
        :degeneracy_tolerance_ev,
        :representation_tolerance,
        :empirical_covariance_budget,
        :target_center_matching_tolerance,
        :compatibility_policy,
        :preparation_execution,
        :geometry,
        :operation_indices,
        :smv_fletcher_reeves_two_stage_audit_thresholds,
        :smv_fletcher_reeves_two_stage_audit_manifest,
        :initialization,
        :z_mix_ratio,
        :u_mix_ratio,
        :stage_controls,
        :acceleration,
        :numerical_thresholds,
        :initialization_backend,
        :paw_scdm_input_hdf5,
        :multi_start,
        :little_group_tolerance,
        :little_group_max_iterations,
        :symmetrize_z,
        :parallel,
        :random_seed,
        :restart_hdf5,
        :checkpoint_hdf5,
        :num_dump_cycles,
        :recovery,
        :storage,
        :reference_root,
        :num_print_cycles,
        :detailed_progress,
        :iteration_observer,
        :model_file,
        :band_representation_output_hdf5,
        :tb_output_formats,
        :write_model_tb,
        :profile,
        :operator_tasks,
        :spn_file,
        :spn_provenance_file,
        :uiu_file,
        :uhu_file,
        :siu_file,
        :shu_file,
        :uiu_provenance_json,
        :uhu_provenance_json,
        :siu_provenance_json,
        :shu_provenance_json,
        :spn_formatted,
        :operator_files_formatted,
        :operator_closure_tolerance,
        :spin_family_covariance_tolerance,
        :spin_family_idempotence_tolerance,
        :final_tb_symmetry_report_enabled,
    )
    @test length(unique(w.WANNIERIZATION_CONFIG_LEAF_FIELDS)) == 77
    @test w.WannierizationCheckpointConfig().storage == :embedded
    @test w.WannierizationCheckpointConfig().reference_root === nothing
    @test w.WannierizationCheckpointConfig(nothing, nothing, 100, :continue).storage == :embedded
    @test :geometry in w.WANNIERIZATION_INPUT_CONFIG_FIELDS
    structure=sf.CrystalStructure(Matrix{Float64}(I, 3, 3), ["X"], zeros(3, 1))
    points=[0.0 0.0 0.0; 1/3 0.0 0.0; 2/3 0.0 0.0]
    geometry=w.WannierizationGeometry(structure, (3, 1, 1), points)
    basis=wp.build_wannier_projection_basis(["X:s"]; structure)
    @test geometry.kpoints_fractional == points
    @test geometry.kpoints_fractional !== points
    @test geometry.structure.lattice !== structure.lattice
    @test geometry.structure.species !== structure.species
    @test geometry.structure.positions_fractional !== structure.positions_fractional
    original_points = copy(points)
    points[1, 1] = 0.125
    @test geometry.kpoints_fractional == original_points
    points .= original_points
    definition=w.wannierization_geometry_definition(geometry)
    @test definition == w.wannierization_geometry_definition(
        w.WannierizationGeometry(structure, (3, 1, 1), points),
    )
    @test_throws ArgumentError w.WannierizationGeometry(structure, (3, 1, 1), zeros(2, 3))
    @test_throws ArgumentError w.WannierizationGeometry(structure, (4, 1, 1), points)
    mktempdir() do dir
        eig=joinpath(dir, "tiny.eig");
        write(eig, "1 1 -1.0\n2 1 1.0\n1 2 0.5\n2 2 1.5\n1 3 -0.8\n2 3 0.9\n")
        win=joinpath(dir, "legacy.win")
        write(
            win,
            "num_wann=1\nmp_grid=3 1 1\nbegin unit_cell_cart\n1 0 0\n0 1 0\n0 0 1\nend unit_cell_cart\nbegin kpoints\n0 0 0\n0.3333333333333333 0 0\n0.6666666666666666 0 0\nend kpoints\n",
        )
        shared=(
            wannierization_mode = :ordinary,
            eig_file = eig,
            projection_basis = basis,
            num_wannier = 1,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = -0.5,
            compatibility_policy = :off,
        )
        positional = w.BandRepresentationPreparationConfig(; shared..., win_file = win)
        old_values = Tuple(
            getfield(positional, field) for
            field in fieldnames(typeof(positional)) if field != :geometry
        )
        @test w.BandRepresentationPreparationConfig(old_values...).geometry === nothing
        legacy=w.prepare_band_representation(
            w.BandRepresentationPreparationConfig(; shared..., win_file = win),
        )
        rm(win)
        actual=w.prepare_band_representation(
            w.BandRepresentationPreparationConfig(; shared..., geometry),
        )
        a=actual.representation;
        b=legacy.representation
        for field in fieldnames(typeof(a))
            field in (:conventions, :input_sha256) && continue
            av=getfield(a, field);
            bv=getfield(b, field)
            if av isa AbstractArray && eltype(av) <: Number
                @test isequal(av, bv)
            end
        end
        expected_energies = [-1.0 0.5 -0.8; 1.0 1.5 0.9]
        expected_outer = trues(2, 3)
        expected_frozen = Bool[true false true; false false false]
        @test a.energies_ev == expected_energies
        @test !haskey(a.input_sha256, "GEOMETRY")
        @test a.real_lattice == geometry.structure.lattice
        @test a.kpoints_fractional == geometry.kpoints_fractional
        @test w.wannierization_geometry_definition(geometry) == definition
        @test !haskey(a.input_sha256, "WIN")
        @test a.conventions["kpoint_authority"] == "normalized_full_BZ"
        @test !haskey(a.conventions, "normalized_geometry_sha256")
        @test a.conventions["normalized_geometry_contract"] == "1"
        artifact = joinpath(dir, "normalized.h5")
        saved=w.prepare_band_representation(
            w.BandRepresentationPreparationConfig(; shared..., geometry, output_hdf5 = artifact),
        )
        restored=sf.read_band_representation_hdf5(artifact; content_authentication = false)
        HDF5.h5open(artifact, "r") do handle
            # HDF5.jl reverses dimensions at its C boundary. The actual Julia
            # read is band,kpoint; disk axis metadata is kpoint,band.
            @test String(HDF5.read_attribute(handle["bands/energies_ev"], "axis_order")) ==
                  "kpoint,band"
            @test size(read(handle["bands/energies_ev"])) == (2, 3)
            @test read(handle["bands/energies_ev"]) == expected_energies
            @test size(read(handle["qualification_scope/frozen_mask"])) == (2, 3)
            @test Bool.(read(handle["qualification_scope/outer_mask"])) == expected_outer
            @test Bool.(read(handle["qualification_scope/frozen_mask"])) == expected_frozen
            @test any(expected_frozen) && !all(expected_frozen)
        end
        @test !haskey(restored.input_sha256, "GEOMETRY")
        @test !haskey(restored.conventions, "normalized_geometry_sha256")
        @test restored.real_lattice == a.real_lattice
        @test restored.reciprocal_lattice == a.reciprocal_lattice
        @test restored.energies_ev == a.energies_ev
        @test isequal(restored.kpoints_fractional, a.kpoints_fractional)
        @test isequal(restored.sewing_matrices, a.sewing_matrices)
        @test !isfile(win)
        @test_throws ArgumentError w.prepare_band_representation(
            w.BandRepresentationPreparationConfig(; shared..., geometry, win_file = win),
        )
        @test_throws ArgumentError w.prepare_band_representation(
            w.BandRepresentationPreparationConfig(; shared...),
        )
    end
end
