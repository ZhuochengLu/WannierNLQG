@testset "Canonical representation builder and structural boundaries" begin
    foundation_extension_before = Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)
    wannierization_extension, _ = WANNIERIZATION._load_wannierization_extension!()
    foundation_extension = Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)
    @test foundation_extension === foundation_extension_before
    structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        2.0 .* Matrix{Float64}(I, 3, 3),
        ["X"],
        zeros(3, 1),
    )
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    coefficients = reshape(ComplexF64[1.0], 1, 1, 1)
    g_vectors = zeros(Int, 1, 3)
    energies = reshape([-1.0], 1, 1)
    wannierization_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        g_vectors,
        coefficients,
        [-1.0],
    )
    wannierization_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :synthetic,
        structure,
        pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [wannierization_point],
        Dict("fixture" => repeat("0", 64)),
    )
    symmetrization_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        g_vectors,
        coefficients,
        [-1.0],
    )
    symmetrization_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :synthetic,
        structure,
        pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [symmetrization_point],
        Dict("fixture" => repeat("0", 64)),
    )
    from_wannierization = Base.invokelatest(
        wannierization_extension.RepresentationPreparation._build_band_representation,
        wannierization_native,
        energies,
        [identity_operation],
        0.01;
        return_diagnostics = true,
    )
    from_foundation = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.build_canonical_band_representation,
        symmetrization_native,
        energies,
        [identity_operation],
        0.01,
    )
    @test from_wannierization.representation.sewing_matrices ==
          from_foundation.representation.sewing_matrices
    @test from_wannierization.representation.kpoint_map == from_foundation.representation.kpoint_map
    @test from_wannierization.representation.conventions ==
          from_foundation.representation.conventions
    @test from_wannierization.construction_diagnostics == from_foundation.construction_diagnostics

    inversion_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        -Matrix{Int}(I, 3, 3),
        zeros(3),
        -Matrix{Float64}(I, 3, 3),
    )
    truncated_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        [0 0 0; 1 0 0],
        reshape(ComplexF64[1.0, 1.0], 1, 2, 1),
        [-1.0],
    )
    truncated_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :synthetic,
        structure,
        pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [truncated_point],
        Dict("fixture" => repeat("4", 64)),
    )
    prepolar = Base.invokelatest(
        wannierization_extension.RepresentationPreparation._build_band_representation,
        truncated_native,
        energies,
        [identity_operation, inversion_operation],
        0.01;
        diagnostic_outer_masks = [trues(1)],
        diagnostic_frozen_masks = [falses(1)],
        return_diagnostics = true,
    )
    raw_full = only(
        filter(
            diagnostic ->
                get(diagnostic, "scope", "") == "full" && diagnostic["operation"] == 2,
            prepolar.construction_diagnostics,
        ),
    )
    @test raw_full["sigma_min"] ≈ 0.5 atol = 1.0e-14 rtol = 0.0
    @test raw_full["left_unitarity_residual"] ≈ 0.75 atol = 1.0e-14 rtol = 0.0
    @test abs(prepolar.representation.sewing_matrices[1, 1, 2, 1]) ≈ 1.0 atol = 1.0e-14 rtol = 0.0
    mktempdir() do directory
        prepolar_file = joinpath(directory, "prepolar-raw.h5")
        Base.invokelatest(
            WannierNLQG.SymmetryFoundation.write_band_representation_hdf5,
            prepolar_file,
            diagnostic_public_band_representation(prepolar.representation);
            overwrite = true,
            qualification_outer_mask = trues(1, 1),
            qualification_frozen_mask = falses(1, 1),
            raw_diagnostics = prepolar.construction_diagnostics,
        )
        HDF5.h5open(prepolar_file, "r") do handle
            raw_group = handle["raw_diagnostics"]
            scopes = read(raw_group["scope_code"])
            values = read(raw_group["real_values"])
            integers = read(raw_group["integer_values"])
            full_index = something(
                findfirst(
                    index -> scopes[index] == 0x01 && integers[1, index] == 2,
                    eachindex(scopes),
                ),
            )
            @test values[2, full_index] ≈ 0.5 atol = 1.0e-14 rtol = 0.0
            @test values[5, full_index] ≈ 0.75 atol = 1.0e-14 rtol = 0.0
        end
    end

    rank_deficient_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        g_vectors,
        reshape(ComplexF64[1.0, 1.0], 2, 1, 1),
        [-1.0, 1.0],
    )
    rank_deficient_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :synthetic,
        structure,
        pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [rank_deficient_point],
        Dict("fixture" => repeat("1", 64)),
    )
    rank_error = try
        Base.invokelatest(
            wannierization_extension.RepresentationPreparation._build_band_representation,
            rank_deficient_native,
            reshape([-1.0, 1.0], 2, 1),
            [identity_operation],
            0.01,
        )
        nothing
    catch exception
        exception
    end
    @test rank_error isa ArgumentError
    @test occursin("rank deficient", sprint(showerror, rank_error))

    nonfinite_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        g_vectors,
        reshape(ComplexF64[NaN], 1, 1, 1),
        [-1.0];
        normalize_coefficients = false,
    )
    nonfinite_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :synthetic,
        structure,
        pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [nonfinite_point],
        Dict("fixture" => repeat("2", 64)),
    )
    nonfinite_error = try
        Base.invokelatest(
            wannierization_extension.RepresentationPreparation._build_band_representation,
            nonfinite_native,
            energies,
            [identity_operation],
            0.01,
        )
        nothing
    catch exception
        exception
    end
    @test nonfinite_error isa ArgumentError
    @test occursin("NONFINITE_COEFFICIENT_BLOCK", sprint(showerror, nonfinite_error))

    antiunitary_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        true,
    )
    off_mesh_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        [0.25, 0.0, 0.0],
        g_vectors,
        coefficients,
        [-1.0],
    )
    off_mesh_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :synthetic,
        structure,
        pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [off_mesh_point],
        Dict("fixture" => repeat("3", 64)),
    )
    action_error = try
        Base.invokelatest(
            wannierization_extension.RepresentationPreparation._build_band_representation,
            off_mesh_native,
            energies,
            [antiunitary_operation],
            0.01,
        )
        nothing
    catch exception
        exception
    end
    @test action_error isa ArgumentError
    @test occursin("INVALID_SYMMETRY_ACTION", sprint(showerror, action_error))

    @test_throws ArgumentError WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
        "POSCAR",
        "WAVECAR";
        magnetic_moments_cartesian = zeros(2, 1),
    )
    @test_throws ArgumentError WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
        "POSCAR",
        "WAVECAR";
        magnetic_moments_cartesian = fill(NaN, 3, 1),
    )
    source_moments = reshape([0.0, 0.0, 1.0], 3, 1)
    vasp_config = WannierNLQG.SymmetryFoundation.VASPBandRepresentationConfig(
        poscar_file = "POSCAR",
        wavecar_file = "WAVECAR",
        eig_file = "wannier.eig",
        output_hdf5_file = "representation.h5",
        magnetic_moments_cartesian = source_moments,
    )
    expected_moment_digest = WannierNLQG.SymmetryFoundation.magnetic_moments_sha256(
        vasp_config.magnetic_moments_cartesian,
    )
    source_moments[3, 1] = 7.0
    @test vasp_config.magnetic_moments_cartesian == reshape([0.0, 0.0, 1.0], 3, 1)
    @test expected_moment_digest ==
          WannierNLQG.SymmetryFoundation.magnetic_moments_sha256(reshape([0.0, 0.0, 1.0], 3, 1))
    @test expected_moment_digest !=
          WannierNLQG.SymmetryFoundation.magnetic_moments_sha256(reshape([0.0, 0.0, -1.0], 3, 1))
    @test_throws ArgumentError WannierNLQG.SymmetryFoundation.VASPBandRepresentationConfig(
        poscar_file = "POSCAR",
        wavecar_file = "WAVECAR",
        eig_file = "wannier.eig",
        output_hdf5_file = "representation.h5",
        magnetic_moments_cartesian = zeros(2, 1),
    )
    mktempdir() do directory
        consistent_incar = joinpath(directory, "INCAR.consistent")
        conflicting_incar = joinpath(directory, "INCAR.conflicting")
        write(consistent_incar, "LNONCOLLINEAR = T\nLSORBIT = T\nSAXIS = 0 0 1\nMAGMOM = 0 0 1\n")
        write(conflicting_incar, "LNONCOLLINEAR = T\nLSORBIT = T\nSAXIS = 0 0 1\nMAGMOM = 0 0 -1\n")
        consistent_source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            "POSCAR",
            "WAVECAR";
            incar_file = consistent_incar,
            magnetic_moments_cartesian = vasp_config.magnetic_moments_cartesian,
        )
        conflicting_source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            "POSCAR",
            "WAVECAR";
            incar_file = conflicting_incar,
            magnetic_moments_cartesian = vasp_config.magnetic_moments_cartesian,
        )
        @test WannierNLQG.SymmetryFoundation.validate_vasp_magnetic_moment_sources(
            consistent_source,
            1,
        ) == :INCAR_CONSISTENT
        conflict = try
            WannierNLQG.SymmetryFoundation.validate_vasp_magnetic_moment_sources(conflicting_source, 1)
            nothing
        catch exception
            exception
        end
        @test conflict isa ArgumentError
        @test occursin("MAGNETIC_MOMENT_SOURCE_CONFLICT", sprint(showerror, conflict))
        @test_throws ArgumentError WannierNLQG.SymmetryFoundation.validate_vasp_magnetic_moment_sources(
            consistent_source,
            2,
        )
    end
    magnetic_structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        Matrix{Float64}(I, 3, 3),
        ["X"],
        zeros(3, 1);
        magnetic_moments_cartesian = reshape([0.0, 0.0, 1.0], 3, 1),
    )
    inventory = WannierNLQG.SymmetryFoundation.detect_magnetic_symmetry_inventory(
        magnetic_structure;
        include_time_reversal = true,
        symmetry_tolerance = 2.5e-6,
    )
    @test inventory.magnetic
    @test inventory.symmetry_tolerance == 2.5e-6
end
