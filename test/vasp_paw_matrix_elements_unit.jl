using LinearAlgebra
using SHA
using Test

const PAW_WANNIERIZATION = WannierNLQG.Wannierization
const PAW_SYMMETRIZATION = WannierNLQG.Symmetrization
const PAW_IO = WannierNLQG.IO

# Keep this focused module runnable without executing the full wannierization suite.
if !isdefined(Main, :synthetic_vasp_wannierization_fixture)
    function synthetic_vasp_wannierization_fixture()
        projection_block = WannierNLQG.WannierProjection.WannierProjectionBlock(
            "X",
            "s",
            zeros(3, 1),
            reshape([1], 1, 1),
            reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
            false,
        )
        basis = WannierNLQG.WannierProjection.WannierProjectionBasis([projection_block], 1, false)
        config = PAW_WANNIERIZATION.SymmetryAdaptedWannierizationConfig(
            input = PAW_WANNIERIZATION.WannierizationInputConfig(
                wannierization_mode = :ordinary,
                win_file = "synthetic.win",
                eig_file = "synthetic.eig",
                mmn_file = "synthetic.mmn",
                projection_basis = basis,
                num_wannier = 1,
                outer_min_ev = -2.0,
                outer_max_ev = 2.0,
                frozen_min_ev = -2.0,
                frozen_max_ev = -0.5,
            ),
            solver = PAW_WANNIERIZATION.WannierizationSolverConfig(initialization = :random),
            checkpoint = PAW_WANNIERIZATION.WannierizationCheckpointConfig(),
            runtime = PAW_WANNIERIZATION.WannierizationRuntimeConfig(),
            output = PAW_WANNIERIZATION.WannierizationOutputConfig(),
        )
        return (; basis, config)
    end
end

if !isdefined(Main, :modified_vasp_wannierization_config)
    function modified_vasp_wannierization_config(config; keywords...)
        replacements = NamedTuple(keywords)
        unknown = setdiff(keys(replacements), PAW_WANNIERIZATION.WANNIERIZATION_CONFIG_LEAF_FIELDS)
        isempty(unknown) || throw(ArgumentError("unknown Wannierization config fields: $(unknown)"))
        select(fields) = begin
            selected = Tuple(name for name in keys(replacements) if name in fields)
            NamedTuple{selected}(Tuple(getfield(replacements, name) for name in selected))
        end
        return PAW_WANNIERIZATION._replace_wannierization_config(
            config;
            input = select(PAW_WANNIERIZATION.WANNIERIZATION_INPUT_CONFIG_FIELDS),
            solver = select(PAW_WANNIERIZATION.WANNIERIZATION_SOLVER_CONFIG_FIELDS),
            checkpoint = select(PAW_WANNIERIZATION.WANNIERIZATION_CHECKPOINT_CONFIG_FIELDS),
            runtime = select(PAW_WANNIERIZATION.WANNIERIZATION_RUNTIME_CONFIG_FIELDS),
            output = select(PAW_WANNIERIZATION.WANNIERIZATION_OUTPUT_CONFIG_FIELDS),
        )
    end
end

function synthetic_potcar_block(element::AbstractString; q0::Float64 = 0.01)
    reciprocal = join(fill("0.1", 100), " ")
    return """
PAW_PBE $(element) 01Jan2000
2.0 tail
Non local Part
0 0 0
Reciprocal Space Part
$(reciprocal)
Real Space Part
0.1 0.1 0.1
PAW radial sets
augmentation charges (non sperical)
$(q0)
uccopancies in atom
grid
0.1 0.2 0.4
aepotential
pseudo wavefunction
0.10 0.20 0.30
ae wavefunction
0.12 0.22 0.32
End of Dataset
"""
end

@testset "VASP PAW typed sources and fail-stop contracts" begin
    extension = first(PAW_WANNIERIZATION._load_wannierization_extension!()).PAWMatrixElements
    public_method = only(methods(extension.generate_vasp_paw_matrix_elements))
    @test public_method.nargs == 4
    @test Base.kwarg_decl(public_method) == [
        :output_mmn_file,
        :output_amn_file,
        :provenance_hdf5,
        :output_solver_amn_file,
        :oracle_mmn_file,
        :oracle_amn_file,
        :thresholds,
        :require_oracle,
    ]

    external = PAW_WANNIERIZATION.ExternalWannier90Matrices("x.mmn", "x.amn")
    @test external.mmn_file == "x.mmn"
    @test external.amn_file == "x.amn"
    @test_throws ArgumentError PAW_WANNIERIZATION.ExternalWannier90Matrices("", "x.amn")

    native = PAW_WANNIERIZATION.NativeVASPPAWMatrices("x.mmn"; artifact_dir = "artifacts")
    @test native.require_oracle
    @test native.thresholds.mmn_max_absolute == 1.0e-5
    @test_throws ArgumentError PAW_WANNIERIZATION.VASPPAWParityThresholds(amn_rms = 0.0)

    fixture = synthetic_vasp_wannierization_fixture()
    missing_amn = modified_vasp_wannierization_config(
        fixture.config;
        source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource("POSCAR", "WAVECAR"),
        initialization = :amn,
        amn_file = nothing,
        matrix_elements = nothing,
    )
    error_value = try
        PAW_WANNIERIZATION._validate_wannierization_config(missing_amn)
        nothing
    catch exception
        exception
    end
    @test error_value isa ArgumentError
    @test occursin("VASP_PAW_AMN_REQUIRED", sprint(showerror, error_value))

    external_config = modified_vasp_wannierization_config(
        fixture.config;
        initialization = :amn,
        amn_file = "x.amn",
        mmn_file = "x.mmn",
        matrix_elements = external,
    )
    @test PAW_WANNIERIZATION._validate_wannierization_config(external_config) === nothing
    @test_throws ArgumentError PAW_WANNIERIZATION._validate_wannierization_config(
        modified_vasp_wannierization_config(external_config; mmn_file = "different.mmn"),
    )

    mktempdir() do directory
        native_config = modified_vasp_wannierization_config(
            fixture.config;
            source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
                "POSCAR",
                "WAVECAR";
                potcar_file = "POTCAR",
                outcar_file = "OUTCAR",
            ),
            initialization = :amn,
            matrix_elements = PAW_WANNIERIZATION.NativeVASPPAWMatrices(
                "x.mmn";
                artifact_dir = directory,
            ),
        )
        @test PAW_WANNIERIZATION._validate_wannierization_config(native_config) === nothing
        missing_outcar = modified_vasp_wannierization_config(
            native_config;
            source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
                "POSCAR",
                "WAVECAR";
                potcar_file = "POTCAR",
            ),
        )
        outcar_error = try
            PAW_WANNIERIZATION._validate_wannierization_config(missing_outcar)
            nothing
        catch exception
            exception
        end
        @test outcar_error isa ArgumentError
        @test occursin("VASP_PAW_OUTCAR_REQUIRED", sprint(showerror, outcar_error))
    end
end

@testset "VASP projection center, spin-axis, and normalization contracts" begin
    extension = first(PAW_WANNIERIZATION._load_wannierization_extension!()).PAWMatrixElements
    @test Base.invokelatest(extension._vasp_projection_wrapped_center, [0.75, 0.25, 0.5]) ==
          ((-0.25, 0.25, -0.5), (-1, 0, -1))
    z_rotation = Base.invokelatest(extension._vasp_projection_spinor_rotation, [0.0, 0.0, 1.0])
    @test z_rotation == Matrix{ComplexF64}(I, 2, 2)
    diagonal_rotation =
        Base.invokelatest(extension._vasp_projection_spinor_rotation, [1.0, 1.0, 1.0])
    expected_rotation = ComplexF64[
        0.8204732385702833-0.33985114297998736im -0.4247082002778669+0.17591989660616117im
        0.4247082002778669+0.17591989660616117im 0.8204732385702833+0.33985114297998736im
    ]
    @test diagonal_rotation ≈ expected_rotation atol = 2.0e-15 rtol = 0.0

    trials = [reshape(ComplexF64[2.0], 1, 1), reshape(ComplexF64[1.0im], 1, 1)]
    trial_projectors = [reshape(ComplexF64[0.5], 1, 1), reshape(ComplexF64[0.25im], 1, 1)]
    factors, pseudo_norms, augmentation_norms, residuals = Base.invokelatest(
        extension._paw_normalize_trial_orbitals!,
        trials,
        trial_projectors,
        reshape([0.2], 1, 1),
    )
    @test pseudo_norms[1] == 5.0
    @test augmentation_norms[1] ≈ 0.0625 atol = 2.0e-16 rtol = 0.0
    @test factors[1] ≈ inv(sqrt(5.0625)) atol = 2.0e-16 rtol = 0.0
    @test residuals[1] <= 2.0e-16
    normalized =
        sum(sum(abs2, matrix) for matrix in trials) + sum(
            real(dot(vec(matrix), reshape([0.2], 1, 1) * vec(matrix))) for
            matrix in trial_projectors
        )
    @test normalized ≈ 1.0 atol = 5.0e-16 rtol = 0.0
    zero_norm_error = try
        Base.invokelatest(
            extension._paw_normalize_trial_orbitals!,
            [zeros(ComplexF64, 1, 1)],
            [zeros(ComplexF64, 1, 1)],
            zeros(1, 1),
        )
        nothing
    catch exception
        exception
    end
    @test zero_norm_error isa ArgumentError
    @test occursin("VASP_PAW_TRIAL_NORMALIZATION_FAILED", sprint(showerror, zero_norm_error))

    mktempdir() do directory
        outcar = joinpath(directory, "OUTCAR")
        write(
            outcar,
            """
 vasp.6.3.0 20Jan22 (build synthetic) complex
 NKPTS =      1   k-points in BZ     NBANDS=      1
 ENCUT  =  100.000 eV
 direct lattice vectors                 reciprocal lattice vectors
     1.000000000 0.000000000 0.000000000   1.0 0.0 0.0
     0.000000000 1.000000000 0.000000000   0.0 1.0 0.0
     0.000000000 0.000000000 1.000000000   0.0 0.0 1.0
 LOCPROJ orbitals
  n l m za pos proj_x proj_z spin spin_qaxis
  1 0 1 1.890 -0.250 0.250 -0.500 1.000 0.000 0.000 0.000 0.000 1.000 1 1.000 1.000 1.000
  1 0 1 1.890 -0.250 0.250 -0.500 1.000 0.000 0.000 0.000 0.000 1.000 2 1.000 1.000 1.000
 Computing AMN
 """,
        )
        structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
            Matrix{Float64}(I, 3, 3),
            ["X"],
            reshape([0.75, 0.25, 0.5], 3, 1),
        )
        point = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            [0.25, 0.0, 0.0],
            reshape([0, 0, 0], 1, 3),
            reshape(ComplexF64[1.0, 0.0], 1, 1, 2),
            [-1.0];
            normalize_coefficients = false,
        )
        native = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
            :vasp,
            structure,
            2.0pi .* Matrix{Float64}(I, 3, 3),
            (1, 1, 1),
            true,
            [point],
            Dict("fixture" => repeat("0", 64)),
            Dict("coefficient_normalization" => "vasp_raw"),
        )
        block = WannierNLQG.WannierProjection.WannierProjectionBlock(
            "X",
            "s",
            reshape([0.75, 0.25, 0.5], 3, 1),
            reshape([1, 2], 2, 1),
            reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
            true,
        )
        basis = WannierNLQG.WannierProjection.WannierProjectionBasis([block], 2, true)
        source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            "POSCAR",
            "WAVECAR";
            outcar_file = outcar,
        )
        contract =
            Base.invokelatest(extension._build_vasp_projection_contract, source, native, basis)
        @test contract.vasp_version == v"6.3.0"
        @test contract.entries[1].center_fractional == (-0.25, 0.25, -0.5)
        @test contract.entries[1].center_integer_translation == (-1, 0, -1)
        @test contract.entries[2].spin_index == 2
        unwrapped = Base.invokelatest(extension._paw_trial_matrices, point, native, basis)
        wrapped = Base.invokelatest(
            extension._paw_trial_matrices,
            point,
            native,
            basis,
            contract;
            use_wrapped_centers = true,
        )
        @test wrapped[1][1, 1] / unwrapped[1][1, 1] ≈ cis(2.0pi * 0.25) atol = 2.0e-15 rtol = 0.0

        outcar_text = read(outcar, String)
        ambiguous_axis = joinpath(directory, "OUTCAR.ambiguous-axis")
        write(ambiguous_axis, replace(outcar_text, "1.000 1.000 1.000" => "1.000 1.000 0.999"))
        axis_source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            "POSCAR",
            "WAVECAR";
            outcar_file = ambiguous_axis,
        )
        axis_error = try
            Base.invokelatest(extension._build_vasp_projection_contract, axis_source, native, basis)
            nothing
        catch exception
            exception
        end
        @test axis_error isa ArgumentError
        @test occursin("VASP_PAW_PROJECTION_AXIS_PRECISION_REQUIRED", sprint(showerror, axis_error))

        wrong_order = joinpath(directory, "OUTCAR.wrong-order")
        write(
            wrong_order,
            replace(outcar_text, "1 0 1 1.890 -0.250" => "1 0 2 1.890 -0.250"; count = 1),
        )
        order_source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            "POSCAR",
            "WAVECAR";
            outcar_file = wrong_order,
        )
        order_error = try
            Base.invokelatest(extension._build_vasp_projection_contract, order_source, native, basis)
            nothing
        catch exception
            exception
        end
        @test order_error isa ArgumentError
        @test occursin("VASP_PAW_PROJECTION_CONTRACT_MISMATCH", sprint(showerror, order_error))

        unsupported_radial = joinpath(directory, "OUTCAR.unsupported-radial")
        write(unsupported_radial, replace(outcar_text, "1.890" => "1.500"))
        radial_source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            "POSCAR",
            "WAVECAR";
            outcar_file = unsupported_radial,
        )
        radial_error = try
            Base.invokelatest(extension._build_vasp_projection_contract, radial_source, native, basis)
            nothing
        catch exception
            exception
        end
        @test radial_error isa ArgumentError
        @test occursin("VASP_PAW_PROJECTION_RADIAL_UNSUPPORTED", sprint(showerror, radial_error))
    end
end

@testset "VASP raw-to-SAWF AMN gauge adapter" begin
    extension = first(PAW_WANNIERIZATION._load_wannierization_extension!()).PAWMatrixElements
    positions = [0.75 0.25; 0.25 0.25; 0.50 -0.25]
    indices = [1 3; 2 4]
    local_bases = repeat(reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1), 1, 1, 2)
    block = WannierNLQG.WannierProjection.WannierProjectionBlock(
        "X",
        "s",
        positions,
        indices,
        local_bases,
        true,
    )
    basis = WannierNLQG.WannierProjection.WannierProjectionBasis([block], 4, true)
    rows = Base.invokelatest(extension._vasp_projection_basis_rows, basis)
    diagonal_axis = (inv(sqrt(3.0)), inv(sqrt(3.0)), inv(sqrt(3.0)))
    function entry(wannier)
        row = rows[wannier]
        axis = wannier <= 2 ? diagonal_axis : (0.0, 0.0, 1.0)
        return Base.invokelatest(
            extension.VASPProjectionEntry,
            row.principal_quantum_number,
            row.angular_momentum,
            row.magnetic_index,
            inv(extension.VASP_PROJECTION_BOHR_ANGSTROM),
            row.center_fractional,
            row.center_integer_translation,
            row.local_x_cartesian,
            row.local_z_cartesian,
            row.spin_index,
            axis,
            row.wannier_index,
        )
    end
    # Deliberately permute LOCPROJ rows; the adapter is keyed by wannier_index.
    contract = Base.invokelatest(
        extension.VASPProjectionContract,
        v"6.3.0",
        150.0,
        :vasp_log_simpson_spline,
        [entry(3), entry(1), entry(4), entry(2)],
    )
    kpoints = [0.0 0.0 0.0; 0.25 0.125 0.0; 0.5 0.25 0.0]
    target = zeros(ComplexF64, 6, 4, 3)
    for kpoint in axes(target, 3)
        target[1:4, :, kpoint] .= Matrix{ComplexF64}(I, 4, 4)
        target[5, :, kpoint] .=
            ComplexF64[0.1 + 0.02im, -0.2im, 0.3 - 0.1im, -0.15 + 0.04im] .* kpoint
        target[6, :, kpoint] .= ComplexF64[-0.08im, 0.12 + 0.03im, -0.05, 0.22im] .* kpoint
    end
    ordered_entries = [entry(wannier) for wannier in 1:4]
    function column_transform(kpoint; phase_sign = 1.0, adjoint_spin = true)
        phases = ComplexF64[
            cis(
                phase_sign *
                2.0pi *
                dot(@view(kpoints[kpoint, :]), collect(item.center_integer_translation)),
            ) for item in ordered_entries
        ]
        transform = Matrix(Diagonal(phases))
        for pair in ([1, 2], [3, 4])
            rotation = Base.invokelatest(
                extension._vasp_projection_spinor_rotation,
                ordered_entries[first(pair)].spin_quantization_axis,
            )
            spin_transform = adjoint_spin ? rotation' : rotation
            transform[pair, pair] .= Diagonal(phases[pair]) * spin_transform
        end
        return transform
    end
    raw_data = similar(target)
    for kpoint in axes(raw_data, 3)
        transform = column_transform(kpoint)
        raw_data[:, :, kpoint] .= target[:, :, kpoint] * transform'
    end
    raw = PAW_IO.WannierAMN(6, 3, 4, raw_data)
    raw_before = copy(raw.data)
    solver, diagnostics = Base.invokelatest(
        extension._canonicalize_vasp_amn_for_wannierization,
        raw,
        kpoints,
        basis,
        contract,
    )
    @test raw.data == raw_before
    @test solver.data ≈ target atol = 4.0e-15 rtol = 0.0
    @test diagnostics.maximum_unitarity_residual <= 1.0e-15
    @test diagnostics.maximum_roundtrip_absolute <= 4.0e-15
    @test diagnostics.maximum_projector_absolute <= 4.0e-15
    @test diagnostics.spinor_pair_count == 2
    @test diagnostics.nonzero_translation_count == 2
    wrong_phase = maximum(
        maximum(
            abs,
            raw.data[:, :, kpoint] * column_transform(kpoint; phase_sign = -1.0) -
            target[:, :, kpoint],
        ) for kpoint in axes(raw.data, 3)
    )
    wrong_spin = maximum(
        maximum(
            abs,
            raw.data[:, :, kpoint] * column_transform(kpoint; adjoint_spin = false) -
            target[:, :, kpoint],
        ) for kpoint in axes(raw.data, 3)
    )
    @test wrong_phase > 0.1
    @test wrong_spin > 0.1

    malformed_entries = copy(contract.entries)
    down = entry(2)
    malformed_entries[findfirst(item -> item.wannier_index == 2, malformed_entries)] =
        Base.invokelatest(
            extension.VASPProjectionEntry,
            down.principal_quantum_number,
            down.angular_momentum,
            down.magnetic_index,
            down.radial_scale_inverse_angstrom,
            down.center_fractional,
            (0, 0, 0),
            down.local_x_cartesian,
            down.local_z_cartesian,
            down.spin_index,
            down.spin_quantization_axis,
            down.wannier_index,
        )
    malformed_contract = Base.invokelatest(
        extension.VASPProjectionContract,
        v"6.3.0",
        150.0,
        :vasp_log_simpson_spline,
        malformed_entries,
    )
    malformed_error = try
        Base.invokelatest(
            extension._canonicalize_vasp_amn_for_wannierization,
            raw,
            kpoints,
            basis,
            malformed_contract,
        )
        nothing
    catch exception
        exception
    end
    @test malformed_error isa ArgumentError
    @test occursin("VASP_PAW_SOLVER_GAUGE_ADAPTER_FAILED", sprint(showerror, malformed_error))

    scalar_block = WannierNLQG.WannierProjection.WannierProjectionBlock(
        "X",
        "s",
        reshape([0.25, 0.25, -0.25], 3, 1),
        reshape([1], 1, 1),
        reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
        false,
    )
    scalar_basis = WannierNLQG.WannierProjection.WannierProjectionBasis([scalar_block], 1, false)
    scalar_row = only(Base.invokelatest(extension._vasp_projection_basis_rows, scalar_basis))
    scalar_entry = Base.invokelatest(
        extension.VASPProjectionEntry,
        scalar_row.principal_quantum_number,
        scalar_row.angular_momentum,
        scalar_row.magnetic_index,
        inv(extension.VASP_PROJECTION_BOHR_ANGSTROM),
        scalar_row.center_fractional,
        scalar_row.center_integer_translation,
        scalar_row.local_x_cartesian,
        scalar_row.local_z_cartesian,
        scalar_row.spin_index,
        (0.0, 0.0, 1.0),
        scalar_row.wannier_index,
    )
    scalar_contract = Base.invokelatest(
        extension.VASPProjectionContract,
        v"6.3.0",
        150.0,
        :vasp_log_simpson_spline,
        [scalar_entry],
    )
    scalar_raw = PAW_IO.WannierAMN(2, 1, 1, reshape(ComplexF64[0.4 + 0.2im, -0.1im], 2, 1, 1))
    scalar_solver, scalar_diagnostics = Base.invokelatest(
        extension._canonicalize_vasp_amn_for_wannierization,
        scalar_raw,
        zeros(1, 3),
        scalar_basis,
        scalar_contract,
    )
    @test scalar_solver.data == scalar_raw.data
    @test scalar_diagnostics.maximum_raw_solver_absolute == 0.0
    @test scalar_diagnostics.spinor_pair_count == 0
end

@testset "VASP PAW outer-target qualification and parent audit" begin
    extension = first(PAW_WANNIERIZATION._load_wannierization_extension!()).PAWMatrixElements
    workflow = first(PAW_WANNIERIZATION._load_wannierization_extension!()).WorkflowOrchestration
    outer = BitMatrix([true true; true false; false true])
    frozen = falses(3, 2)
    scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(outer, frozen)
    Base.invokelatest(extension._validate_vasp_paw_qualification_scope, scope, 3, 2, 2)

    overlap = Matrix{ComplexF64}(I, 3, 3)
    overlap[3, 3] = 1.25
    target_norm, target_worst =
        Base.invokelatest(extension._paw_scoped_identity_residual, overlap, outer[:, 1])
    parent_norm, parent_worst =
        Base.invokelatest(extension._paw_scoped_identity_residual, overlap, trues(3))
    @test target_norm == 0.0
    @test target_worst == (0, 0)
    @test parent_norm == 0.25
    @test parent_worst == (3, 3)
    parent_nonfinite_overlap = copy(overlap)
    parent_nonfinite_overlap[3, 3] = NaN
    @test first(
        Base.invokelatest(
            extension._paw_scoped_identity_residual,
            parent_nonfinite_overlap,
            outer[:, 1],
        ),
    ) == 0.0
    @test isnan(
        first(
            Base.invokelatest(
                extension._paw_scoped_identity_residual,
                parent_nonfinite_overlap,
                trues(3),
            ),
        ),
    )
    target_nonfinite_overlap = copy(overlap)
    target_nonfinite_overlap[1, 1] = Inf
    @test isinf(
        first(
            Base.invokelatest(
                extension._paw_scoped_identity_residual,
                target_nonfinite_overlap,
                outer[:, 1],
            ),
        ),
    )

    neighbors = reshape([2, 1], 1, 2)
    shifts = zeros(Int, 3, 1, 2)
    generated_mmn_data = reshape(
        ComplexF64[
            complex(0.1 * left + 0.01 * right + kpoint) for
            left in 1:3, right in 1:3, neighbor in 1:1, kpoint in 1:2
        ],
        3,
        3,
        1,
        2,
    )
    oracle_mmn_data = copy(generated_mmn_data)
    # These entries lie outside source/target outer masks on their respective links.
    oracle_mmn_data[3, 2, 1, 1] += 1.0e-3
    oracle_mmn_data[2, 3, 1, 2] -= 2.0e-3im
    generated_mmn = PAW_IO.WannierMMN(3, 2, 1, generated_mmn_data, neighbors, shifts)
    oracle_mmn = PAW_IO.WannierMMN(3, 2, 1, oracle_mmn_data, neighbors, shifts)

    generated_amn_data = zeros(ComplexF64, 3, 2, 2)
    generated_amn_data[:, :, 1] .= ComplexF64[1 0; 0 1; 0.2 -0.1im]
    generated_amn_data[:, :, 2] .= ComplexF64[1 0; -0.3im 0.4; 0 1]
    oracle_amn_data = copy(generated_amn_data)
    oracle_amn_data[3, 1, 1] += 1.0e-3
    oracle_amn_data[2, 2, 2] -= 2.0e-3im
    generated_amn = PAW_IO.WannierAMN(3, 2, 2, generated_amn_data)
    oracle_amn = PAW_IO.WannierAMN(3, 2, 2, oracle_amn_data)

    mktempdir() do directory
        oracle_mmn_file = joinpath(directory, "oracle.mmn")
        PAW_IO.write_wannier_mmn(oracle_mmn_file, oracle_mmn)
        target_mmn = Base.invokelatest(
            extension._paw_mmn_streaming_parity,
            generated_mmn,
            oracle_mmn_file,
            outer,
        )
        parent_mmn =
            Base.invokelatest(extension._paw_mmn_streaming_parity, generated_mmn, oracle_mmn_file)
        target_amn =
            Base.invokelatest(extension._paw_amn_scoped_parity, generated_amn, oracle_amn, outer)
        parent_amn =
            Base.invokelatest(extension._paw_array_parity, generated_amn.data, oracle_amn.data)
        target_angle, target_projector, target_rank, _ =
            Base.invokelatest(extension._paw_amn_subspace_metrics, generated_amn, oracle_amn, outer)
        thresholds = PAW_WANNIERIZATION.VASPPAWParityThresholds()
        qualification = Base.invokelatest(
            extension._paw_target_qualification,
            0.0,
            target_norm,
            target_mmn,
            target_amn,
            target_angle,
            target_projector,
            target_rank,
            2,
            true,
            thresholds;
            require_oracle = true,
        )
        parent_status = Base.invokelatest(
            extension._paw_parent_audit_status,
            parent_norm,
            parent_mmn,
            parent_amn,
            0.0,
            0.0,
            2,
            2,
            true,
            thresholds,
        )
        @test target_mmn.max_absolute == 0.0
        @test parent_mmn.max_absolute == 2.0e-3
        @test target_amn.max_absolute == 0.0
        @test parent_amn.max_absolute == 2.0e-3
        @test target_rank == 2
        @test qualification.passed
        @test qualification.target_finite_pass
        @test parent_status == :AUDIT_EXCEEDED

        parent_nonfinite_mmn_data = copy(generated_mmn_data)
        parent_nonfinite_mmn_data[3, 2, 1, 1] = NaN
        parent_nonfinite_mmn_data[2, 3, 1, 2] = Inf
        parent_nonfinite_mmn =
            PAW_IO.WannierMMN(3, 2, 1, parent_nonfinite_mmn_data, neighbors, shifts)
        parent_nonfinite_amn_data = copy(generated_amn_data)
        parent_nonfinite_amn = PAW_IO.WannierAMN(3, 2, 2, parent_nonfinite_amn_data)
        parent_nonfinite_amn.data[3, 1, 1] = NaN
        parent_nonfinite_amn.data[2, 2, 2] = Inf
        parent_tail_target_mmn = Base.invokelatest(
            extension._paw_mmn_streaming_parity,
            parent_nonfinite_mmn,
            oracle_mmn_file,
            outer,
        )
        parent_tail_parent_mmn = Base.invokelatest(
            extension._paw_mmn_streaming_parity,
            parent_nonfinite_mmn,
            oracle_mmn_file,
        )
        parent_tail_target_amn = Base.invokelatest(
            extension._paw_amn_scoped_parity,
            parent_nonfinite_amn,
            generated_amn,
            outer,
        )
        parent_tail_parent_amn = Base.invokelatest(
            extension._paw_array_parity,
            parent_nonfinite_amn.data,
            generated_amn.data,
        )
        parent_tail_angle, parent_tail_projector, parent_tail_rank, _ = Base.invokelatest(
            extension._paw_amn_subspace_metrics,
            parent_nonfinite_amn,
            generated_amn,
            outer,
        )
        parent_audit_metrics = Base.invokelatest(
            extension._paw_amn_parent_audit_metrics,
            parent_nonfinite_amn,
            generated_amn,
        )
        parent_tail_target_finite =
            Base.invokelatest(extension._paw_mmn_target_finite, parent_nonfinite_mmn, outer) &&
            Base.invokelatest(extension._paw_amn_target_finite, parent_nonfinite_amn, outer)
        parent_tail_qualification = Base.invokelatest(
            extension._paw_target_qualification,
            0.0,
            0.0,
            parent_tail_target_mmn,
            parent_tail_target_amn,
            parent_tail_angle,
            parent_tail_projector,
            parent_tail_rank,
            2,
            parent_tail_target_finite,
            thresholds;
            require_oracle = true,
        )
        parent_tail_status = Base.invokelatest(
            extension._paw_parent_audit_status,
            NaN,
            parent_tail_parent_mmn,
            parent_tail_parent_amn,
            parent_audit_metrics[1],
            parent_audit_metrics[2],
            parent_audit_metrics[3],
            2,
            false,
            thresholds,
        )
        @test parent_tail_target_mmn.finite
        @test !parent_tail_parent_mmn.finite
        @test parent_tail_target_amn.finite
        @test !parent_tail_parent_amn.finite
        @test parent_tail_target_finite
        @test isnan(parent_audit_metrics[1]) &&
              isnan(parent_audit_metrics[2]) &&
              isnan(parent_audit_metrics[4])
        @test parent_tail_qualification.passed
        @test parent_tail_status == :AUDIT_EXCEEDED

        target_nonfinite_mmn_data = copy(generated_mmn_data)
        target_nonfinite_mmn_data[1, 1, 1, 1] = NaN
        target_nonfinite_mmn =
            PAW_IO.WannierMMN(3, 2, 1, target_nonfinite_mmn_data, neighbors, shifts)
        target_nonfinite_amn_data = copy(generated_amn_data)
        target_nonfinite_amn = PAW_IO.WannierAMN(3, 2, 2, target_nonfinite_amn_data)
        target_nonfinite_amn.data[1, 1, 1] = Inf
        @test !Base.invokelatest(extension._paw_mmn_target_finite, target_nonfinite_mmn, outer)
        @test !Base.invokelatest(extension._paw_amn_target_finite, target_nonfinite_amn, outer)
        @test !Base.invokelatest(
            extension._paw_target_qualification,
            0.0,
            0.0,
            target_mmn,
            target_amn,
            target_angle,
            target_projector,
            target_rank,
            2,
            false,
            thresholds;
            require_oracle = true,
        ).passed
        qualified_result = PAW_WANNIERIZATION.VASPPAWMatrixElementResult(
            generated_mmn,
            generated_amn,
            generated_amn,
            nothing,
            target_mmn,
            target_amn,
            target_angle,
            target_projector,
            0.0,
            target_norm,
            true,
            ["parent_audit_status=AUDIT_EXCEEDED"],
            Dict{String, String}(),
            Dict{String, String}(),
        )
        @test Base.invokelatest(
            workflow._require_native_vasp_paw_qualification,
            qualified_result,
            thresholds,
        ) === nothing

        target_oracle_data = copy(generated_mmn_data)
        target_oracle_data[1, 1, 1, 1] += 1.0e-3
        target_oracle = PAW_IO.WannierMMN(3, 2, 1, target_oracle_data, neighbors, shifts)
        target_oracle_file = joinpath(directory, "target-failure.mmn")
        PAW_IO.write_wannier_mmn(target_oracle_file, target_oracle)
        failed_target_mmn = Base.invokelatest(
            extension._paw_mmn_streaming_parity,
            generated_mmn,
            target_oracle_file,
            outer,
        )
        failed_qualification = Base.invokelatest(
            extension._paw_target_qualification,
            0.0,
            0.0,
            failed_target_mmn,
            target_amn,
            target_angle,
            target_projector,
            target_rank,
            2,
            true,
            thresholds;
            require_oracle = true,
        )
        @test failed_target_mmn.max_absolute ≈ 1.0e-3 atol = 2.0e-16 rtol = 0.0
        @test !failed_qualification.mmn_pass
        @test !failed_qualification.passed
        failed_result = PAW_WANNIERIZATION.VASPPAWMatrixElementResult(
            generated_mmn,
            generated_amn,
            generated_amn,
            nothing,
            failed_target_mmn,
            target_amn,
            target_angle,
            target_projector,
            0.0,
            0.0,
            false,
            ["VASP_PAW_MMN_PARITY_FAILED"],
            Dict{String, String}(),
            Dict{String, String}(),
        )
        target_failure = try
            Base.invokelatest(
                workflow._require_native_vasp_paw_qualification,
                failed_result,
                thresholds,
            )
            nothing
        catch exception
            exception
        end
        @test target_failure isa ArgumentError
        @test occursin("VASP_PAW_MMN_PARITY_FAILED", sprint(showerror, target_failure))
        @test !Base.invokelatest(
            extension._paw_target_qualification,
            0.0,
            0.0,
            target_mmn,
            target_amn,
            target_angle,
            target_projector,
            target_rank,
            2,
            false,
            thresholds;
            require_oracle = true,
        ).passed
    end

    bad_digest_scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        outer,
        frozen;
        outer_mask_sha256 = repeat("0", 64),
    )
    @test_throws ArgumentError Base.invokelatest(
        extension._validate_vasp_paw_qualification_scope,
        bad_digest_scope,
        3,
        2,
        2,
    )
    rank_deficient_outer = copy(outer)
    rank_deficient_outer[:, 1] .= (true, false, false)
    rank_deficient_scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        rank_deficient_outer,
        frozen,
    )
    @test_throws ArgumentError Base.invokelatest(
        extension._validate_vasp_paw_qualification_scope,
        rank_deficient_scope,
        3,
        2,
        2,
    )

    fixture = synthetic_vasp_wannierization_fixture()
    mktempdir() do directory
        eig_file = joinpath(directory, "closed.eig")
        win_file = joinpath(directory, "closed.win")
        write(win_file, "num_wann = 2\n")
        energies = [-0.001 -0.002; 0.005 0.004; 2.0 2.0]
        PAW_IO.write_wannier_eig(eig_file, PAW_IO.WannierEIG(3, 2, energies))
        config = modified_vasp_wannierization_config(
            fixture.config;
            eig_file,
            win_file,
            outer_min_ev = -1.0,
            outer_max_ev = 0.0,
            frozen_min_ev = Inf,
            frozen_max_ev = -Inf,
            degeneracy_tolerance_ev = 0.01,
        )
        contract = Base.invokelatest(workflow._native_vasp_paw_qualification_contract, config)
        @test contract.scope.outer_mask == BitMatrix([true true; true true; false false])
        @test !any(contract.scope.frozen_mask)
        @test contract.metadata["target_authority"] == "outer_window"
        @test contract.metadata["window_closure"] == "complete_degeneracy_blocks"
        @test contract.input_sha256["EIG"] == bytes2hex(SHA.sha256(read(eig_file)))
    end
end

@testset "Wannier MMN writer and topology-only reader" begin
    data = reshape(ComplexF64[1 + 2im, 3 + 4im, 5 + 6im, 7 + 8im], 2, 2, 1, 1)
    neighbors = reshape([1], 1, 1)
    shifts = reshape([1, -2, 3], 3, 1, 1)
    mmn = PAW_IO.WannierMMN(2, 1, 1, data, neighbors, shifts)
    mktempdir() do directory
        path = joinpath(directory, "roundtrip.mmn")
        PAW_IO.write_wannier_mmn(path, mmn)
        topology = PAW_IO.read_wannier_mmn_topology(path)
        reread = PAW_IO.read_wannier_mmn(path)
        @test topology.num_bands == 2
        @test topology.neighbors == neighbors
        @test topology.reciprocal_shifts == shifts
        @test reread.data == data
    end
end

@testset "Synthetic POTCAR, harmonic, radial, and raw-coefficient gates" begin
    extension = first(PAW_WANNIERIZATION._load_wannierization_extension!()).PAWMatrixElements
    preparation =
        first(PAW_WANNIERIZATION._load_wannierization_extension!()).RepresentationPreparation
    lattice = Matrix{Float64}(I, 3, 3)
    structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        lattice,
        ["X", "Y"],
        [0.0 0.5; 0.0 0.5; 0.0 0.5],
    )
    mktempdir() do directory
        potcar = joinpath(directory, "POTCAR.synthetic")
        write(
            potcar,
            synthetic_potcar_block("X"; q0 = 0.02) * synthetic_potcar_block("Y"; q0 = 0.03),
        )
        paw = Base.invokelatest(preparation._read_vasp_paw_system, potcar, structure)
        @test paw.dataset_order == ["X", "Y"]
        @test paw.num_channels == 2
        @test paw.q0_augmentation ≈ Diagonal([0.02, 0.03])
        first_atom = paw.atoms[1]
        bzero = Base.invokelatest(
            extension._paw_finite_b_atomic_matrix,
            paw.datasets["X"],
            first_atom.channels,
            zeros(3),
        )
        @test bzero == reshape(ComplexF64[0.02], 1, 1)
        @test Base.invokelatest(extension._paw_real_gaunt, 0, 1, 0, 1, 0, 1) ≈ inv(sqrt(4.0pi)) atol =
            2.0e-14 rtol = 0.0

        reversed = WannierNLQG.SymmetryFoundation.CrystalStructure(
            lattice,
            ["Y", "X"],
            structure.positions_fractional,
        )
        mismatch = try
            Base.invokelatest(preparation._read_vasp_paw_system, potcar, reversed)
            nothing
        catch exception
            exception
        end
        @test mismatch isa ArgumentError
        @test occursin("VASP_PAW_ELEMENT_ORDER_MISMATCH", sprint(showerror, mismatch))

        truncated = joinpath(directory, "POTCAR.truncated")
        write(truncated, "PAW_PBE X 01Jan2000\nEnd of Dataset\n")
        @test_throws ArgumentError Base.invokelatest(
            preparation._read_vasp_paw_system,
            truncated,
            WannierNLQG.SymmetryFoundation.CrystalStructure(lattice, ["X"], zeros(3, 1)),
        )

        point = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            zeros(3),
            reshape([0, 0, 0], 1, 3),
            reshape(ComplexF64[1.0], 1, 1, 1),
            [-1.0],
        )
        normalized_native = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
            :vasp,
            WannierNLQG.SymmetryFoundation.CrystalStructure(lattice, ["X"], zeros(3, 1)),
            2.0pi .* lattice,
            (1, 1, 1),
            false,
            [point],
            Dict("fixture" => repeat("0", 64)),
            Dict("coefficient_normalization" => "euclidean_per_band"),
        )
        one_element_potcar = joinpath(directory, "POTCAR.one-element.synthetic")
        write(one_element_potcar, synthetic_potcar_block("X"; q0 = 0.02))
        one_atom_paw = Base.invokelatest(
            preparation._read_vasp_paw_system,
            one_element_potcar,
            WannierNLQG.SymmetryFoundation.CrystalStructure(lattice, ["X"], zeros(3, 1)),
        )
        normalization_error = try
            Base.invokelatest(extension._paw_projectors, normalized_native, one_atom_paw)
            nothing
        catch exception
            exception
        end
        @test normalization_error isa ArgumentError
        @test occursin("VASP_PAW_RAW_COEFFICIENTS_REQUIRED", sprint(showerror, normalization_error))
    end
end

@testset "Public VASP pseudo AMN generation is disabled" begin
    fixture = synthetic_vasp_wannierization_fixture()
    source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
        "missing.POSCAR",
        "missing.WAVECAR";
        potcar_file = "missing.POTCAR",
    )
    failure = try
        PAW_WANNIERIZATION.generate_wannier_amn(source, fixture.basis)
        nothing
    catch exception
        exception
    end
    @test failure isa ArgumentError
    @test occursin("VASP_PAW_AMN_REQUIRED", sprint(showerror, failure))
end
