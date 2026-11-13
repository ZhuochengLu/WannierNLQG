module NonorthogonalSpinConventionUnit
using Test, LinearAlgebra, WannierNLQG
const C = WannierNLQG.Core
const M = WannierNLQG.MatrixElements
const IOModel = WannierNLQG.IO

"""Copy a synthetic model with explicit representation metadata and centers."""
function with_metadata(model; kwargs...)
    return C.NonorthogonalLocalizedModel(;
        lattice = model.lattice,
        r_vectors = model.r_vectors,
        hamiltonian_r = model.raw_hamiltonian_r,
        overlap_r = model.raw_overlap_r,
        position_r = model.raw_position_r,
        kwargs...,
    )
end

"""Two genuinely distinct spin blocks, retaining one common metric and position."""
function spin_chain(; ordering = :blocked, mixing = false, representation = :collinear)
    scalar = Main.NonorthogonalLocalizedUnit.localized_chain()
    n, nr = scalar.num_orbitals, scalar.num_r_vectors
    h = zeros(ComplexF64, 2n, 2n, nr);
    s = similar(h);
    fill!(s, 0)
    r = zeros(ComplexF64, 2n, 2n, 3, nr)
    centers = zeros(Float64, 3, 2n)
    for (channel, indices) in enumerate((1:n, (n + 1):2n))
        h[indices, indices, :] =
            scalar.hamiltonian_r + (channel == 1 ? 0.2 : -0.3) * scalar.overlap_r
        s[indices, indices, :] = scalar.overlap_r
        r[indices, indices, :, :] = scalar.position_r
        centers[1, indices] = [0.1, 0.35]
    end
    if mixing
        home = findfirst(i -> all(iszero, scalar.r_vectors[:, i]), 1:nr)
        h[1:n, (n + 1):2n, home] = ComplexF64[0.07 0.03im; 0.02 -0.06]
        h[(n + 1):2n, 1:n, home] = h[1:n, (n + 1):2n, home]'
    end
    permutation = ordering == :blocked ? collect(1:2n) : [1, 3, 2, 4]
    return C.NonorthogonalLocalizedModel(
        lattice = scalar.lattice,
        r_vectors = scalar.r_vectors,
        hamiltonian_r = h[permutation, permutation, :],
        overlap_r = s[permutation, permutation, :],
        position_r = r[permutation, permutation, :, :],
        spin_representation = representation,
        magnetic_state = :collinear,
        spin_ordering = ordering,
        orbital_centers_cartesian = centers[:, permutation],
    )
end

include(joinpath(@__DIR__, "NativeDefinitionTestSupport.jl"))
using .NativeDefinitionTestSupport: native_definition_bytes

@testset "Explicit spin admission, counts, order and block spectrum" begin
    scalar = Main.NonorthogonalLocalizedUnit.localized_chain()
    @test scalar.spin_representation == :spinless
    @test scalar.num_spatial_orbitals == scalar.num_orbitals
    @test_throws ArgumentError with_metadata(scalar; spin_orbit_coupling = true)
    @test_throws ArgumentError C.NonorthogonalLocalizedInput(
        scalar;
        wannier_center_convention = "Convention_I",
    )
    @test_throws ArgumentError spin_chain(; mixing = true)
    k = [0.173, 0.0, 0.0]
    eigenvalues = eigvals(
        Hermitian(M.nonorthogonal_operator_matrices(scalar, k).hamiltonian),
        Hermitian(M.nonorthogonal_operator_matrices(scalar, k).overlap),
    )
    for ordering in (:blocked, :interleaved)
        model = spin_chain(; ordering)
        @test model.num_orbitals == 4
        @test model.num_spatial_orbitals == 2
        for convention in (C.CONVENTION_I, C.CONVENTION_II)
            plan = M.compile_matrix_plan(
                M.MatrixElementRequest(M.SPECTRUM);
                source_gauge_required = false,
                wannier_center_convention = convention,
            )
            workspace = M.MatrixElementWorkspace(model, plan)
            spectrum = M.compute_spectrum!(workspace, model, k)
            @test spectrum.energies ≈ sort(vcat(eigenvalues .+ 0.2, eigenvalues .- 0.3)) atol =
                2e-13
            @test M.nonorthogonal_metric_diagnostics(workspace).effective_normalized_eigen_residual <
                  1e-13
            spinor = with_metadata(
                model;
                spin_representation = :spinor,
                magnetic_state = :collinear,
                spin_ordering = ordering,
                orbital_centers_cartesian = model.orbital_centers_cartesian,
            )
            other = M.compute_spectrum!(M.MatrixElementWorkspace(spinor, plan), spinor, k)
            @test other.energies ≈ spectrum.energies atol = 2e-13
            @test native_definition_bytes(C.NonorthogonalLocalizedInput(model)) !=
                  native_definition_bytes(C.NonorthogonalLocalizedInput(spinor))
        end
    end
    for (magnetic, soc) in
        ((:nonmagnetic, true), (:collinear, true), (:noncollinear, false), (:noncollinear, true))
        base = spin_chain(; mixing = true, representation = :spinor)
        model = with_metadata(
            base;
            spin_representation = :spinor,
            magnetic_state = magnetic,
            spin_orbit_coupling = soc,
            orbital_centers_cartesian = base.orbital_centers_cartesian,
        )
        @test model.magnetic_state == magnetic
        @test model.spin_orbit_coupling == soc
    end
end

@testset "Native Convention I affine operators and analytic jets" begin
    original = Main.NonorthogonalLocalizedUnit.localized_chain()
    centers = [0.1 0.35; -0.2 0.07; 0.04 0.13]
    model = with_metadata(original; orbital_centers_cartesian = centers)
    k = [0.137, 0.219, -0.041]
    ii = M.nonorthogonal_operator_matrices(model, k)
    native = M.nonorthogonal_operator_matrices(model, k; convention = C.CONVENTION_I)
    kcart = 2pi * (model.lattice \ k)
    u = Diagonal(cis.(vec(kcart' * centers)))
    @test native.hamiltonian ≈ u' * ii.hamiltonian * u atol = 2e-14
    @test native.overlap ≈ u' * ii.overlap * u atol = 2e-14
    for a in 1:3
        tau = Diagonal(centers[a, :])
        @test native.position[:, :, a] ≈ u' * (ii.position[:, :, a] - tau * ii.overlap) * u atol =
            2e-14
        @test native.position[:, :, a] + im * native.overlap_derivatives[:, :, a] ≈
              native.position[:, :, a]' atol = 2e-14
        step = 2e-5
        dk = model.lattice[:, a] .* (step / 2pi)
        plus = M.nonorthogonal_operator_matrices(model, k + dk; convention = C.CONVENTION_I)
        minus = M.nonorthogonal_operator_matrices(model, k - dk; convention = C.CONVENTION_I)
        @test (plus.hamiltonian - minus.hamiltonian) / (2step) ≈
              native.hamiltonian_derivatives[:, :, a] atol = 2e-9
        @test (plus.overlap - minus.overlap) / (2step) ≈ native.overlap_derivatives[:, :, a] atol =
            2e-9
        for b in 1:3
            @test (plus.hamiltonian_derivatives[:, :, b] - minus.hamiltonian_derivatives[:, :, b]) /
                  (2step) ≈ native.hamiltonian_second_derivatives[:, :, b, a] atol = 2e-9
            @test (plus.overlap_derivatives[:, :, b] - minus.overlap_derivatives[:, :, b]) /
                  (2step) ≈ native.overlap_second_derivatives[:, :, b, a] atol = 2e-9
            @test (plus.position[:, :, b] - minus.position[:, :, b]) / (2step) ≈
                  native.position_derivatives[:, :, b, a] atol = 2e-9
        end
    end
    workspace = Main.NonorthogonalLocalizedUnit.geometry_workspace(model)
    spectrum = M.compute_spectrum!(workspace, model, k)
    aligned_i = (energies = spectrum.energies, eigenvectors = u' * spectrum.eigenvectors)
    for eta in (0.0, 0.001, 0.15)
        gi = M._nonorthogonal_geometry(
            model,
            k,
            aligned_i,
            1e-4;
            denominator_regularization = eta,
            convention = C.CONVENTION_I,
        )
        gii = M._nonorthogonal_geometry(model, k, spectrum, 1e-4; denominator_regularization = eta)
        @test gi.velocity_vertices ≈ gii.velocity_vertices atol = 2e-13
        for a in 1:3
            q =
                spectrum.eigenvectors' *
                ii.overlap *
                Diagonal(centers[a, :]) *
                spectrum.eigenvectors
            for l in 1:2, m in 1:2
                l == m && continue
                delta = spectrum.energies[m] - spectrum.energies[l]
                expected = -eta^2 / (delta^2 + eta^2) * (q[l, m] + conj(q[m, l])) / 2
                @test gi.berry_connection[l, m, a] - gii.berry_connection[l, m, a] ≈ expected atol =
                    2e-13
            end
        end
    end
end

"""Write format-v3 spin records with unequal +/-R mixing; synthetic, not material data."""
function write_spin_records(path, spin; byte_order = :little)
    write_values(stream, values) =
        if byte_order == :little
            write(stream, values)
        elseif eltype(values) == Float64
            write(stream, bswap.(reinterpret(UInt64, vec(values))))
        else
            write(stream, bswap.(vec(values)))
        end
    real_h =
        ([0.02, 0.005, 0.005], [-0.03, 0.008, 0.008], [0.006, 0.007, 0.009], [0.004, 0.012, 0.014])
    imaginary_h = ([0.0, 0.003, -0.003], [0.0, -0.002, 0.002], [0.002, 0.001, 0.003])
    overlap = [1.2, 0.05, 0.05]
    open(path, "w") do stream
        write_values(stream, Int32[1, spin + 12, 0, 0, 0, 2, 1])
        write_values(stream, [0.0 0.0 0.0; 0.0 2.0 -2.0; 0.0 0.0 0.0; 0.0 0.0 0.0])
        write_values(stream, Int32[0 1 2; 0 1 -1; 0 0 0; 0 0 0])
        write_values(stream, Int32[1]) # Spatial orbital count.
        write_values(stream, Int32[2]) # Two translated neighbors plus home.
        write_values(stream, Int32[1, 1, 1])
        write_values(stream, Int32[0, 1, 2])
        write_values(stream, vcat(zeros(1, 3), Matrix(Diagonal([2.0, 3.0, 4.0]))))
        write_values(stream, vcat(zeros(1, 3), Matrix(Diagonal([pi, 2pi / 3, pi / 2]))))
        write_values(stream, [0.0, 0.2, -0.1, 0.3])
        for index in 1:(spin + 1)
            write_values(stream, real_h[index])
        end
        if spin == 3
            for values in imaginary_h
                write_values(stream, values)
            end
        end
        write_values(stream, overlap)
        for axis in 1:3
            write_values(stream, axis == 1 ? [0.1, 0.05, -0.05] : zeros(3))
        end
        for _ in 1:(3 + spin + 1 + 2) # Momentum, all real density, two imaginary density.
            write_values(stream, zeros(3))
        end
        write_values(stream, Int32[2])
        write_values(stream, vcat([-0.25, 300.0], zeros(8)))
        write_values(stream, Int32[0])
    end
    return real_h, imaginary_h, overlap
end

@testset "OpenMX spin record assembly and negative-cell adjoint" begin
    mktempdir() do directory
        for spin in (1, 3), byte_order in (:little, :big)
            path = joinpath(directory, "synthetic-spin$(spin)-$(byte_order).scfout")
            real_h, imaginary_h, overlap = write_spin_records(path, spin; byte_order)
            @test_throws ArgumentError IOModel.read_openmx_localized_input(
                path;
                format_version = "scfout_v3",
                byte_order,
            )
            cases =
                spin == 1 ? ((:collinear, false),) :
                (
                    (:nonmagnetic, true),
                    (:collinear, true),
                    (:noncollinear, false),
                    (:noncollinear, true),
                )
            for (magnetic, soc) in cases
                input = IOModel.read_openmx_localized_input(
                    path;
                    format_version = "scfout_v3",
                    byte_order,
                    magnetic_state = magnetic,
                    spin_orbit_coupling = soc,
                    wannier_center_convention = "Convention_I",
                )
                model = input.model
                @test model.num_orbitals == 2
                @test model.num_spatial_orbitals == 1
                @test input.parameters.explicit_state_multiplicity == 1
                @test input.parameters.chemical_potential_hartree == -0.25
                @test input.parameters.electronic_temperature_record == 300.0
                for (persisted, cell) in enumerate((0, 1, -1))
                    index = findfirst(i -> model.r_vectors[1, i] == cell, 1:3)
                    partner = findfirst(i -> model.r_vectors[1, i] == -cell, 1:3)
                    @test model.raw_overlap_r[1, 1, index] == overlap[persisted]
                    if spin == 3
                        expected =
                            (
                                real_h[3][persisted] +
                                im * (real_h[4][persisted] + imaginary_h[3][persisted])
                            ) * 27.211399
                        @test model.raw_hamiltonian_r[1, 2, index] ≈ expected atol = 1e-15
                        @test model.raw_hamiltonian_r[2, 1, partner] ≈ conj(expected) atol = 1e-15
                        @test model.raw_hamiltonian_r[1, 1, index] ≈
                              (real_h[1][persisted] + im * imaginary_h[1][persisted]) * 27.211399 atol =
                            1e-15
                    else
                        @test model.raw_hamiltonian_r[1, 2, index] == 0
                        @test model.raw_hamiltonian_r[2, 2, index] ≈
                              real_h[2][persisted] * 27.211399 atol = 1e-15
                    end
                end
            end
        end
    end
end

@testset "Localized native FFT/Mixed sources, geometry and bounded cache" begin
    scalar = with_metadata(
        Main.NonorthogonalLocalizedUnit.localized_chain();
        orbital_centers_cartesian = [0.1 0.35; 0.02 -0.04; 0.03 0.07],
    )
    models = (
        scalar,
        spin_chain(),
        spin_chain(; ordering = :interleaved),
        spin_chain(; mixing = true, representation = :spinor),
        spin_chain(; ordering = :interleaved, mixing = true, representation = :spinor),
    )
    request = M.MatrixElementRequest(
        M.SPECTRUM,
        M.BERRY_CONNECTION,
        M.INTERNAL_CONNECTION_DERIVATIVES,
        M.HAMILTONIAN_SECOND_DERIVATIVES,
        M.VELOCITY_VERTICES,
        M.WANNIER_CURVATURE;
        spatial_dimension = 3,
        denominator_regularization = 0.001,
    )
    for model in models,
        convention in (C.CONVENTION_I, C.CONVENTION_II),
        mesh in ((4,), (3, 4), (3, 4, 2))

        plan = M.compile_matrix_plan(
            request;
            source_gauge_required = false,
            wannier_center_convention = convention,
        )
        direct = M.MatrixElementWorkspace(model, plan)
        for divisions in (ntuple(a->1, length(mesh)), ntuple(a->a==1 ? mesh[1] : 1, length(mesh)))
            workspace = M.MatrixElementWorkspace(model, plan)
            M.prepare_real_space!(workspace, model)
            grid, _ = M.mixed_fourier_grid(model, mesh; nkdiv = divisions)
            origin = [0.071, 0.137, 0.033]
            grid = M.MixedFourierGrid(
                grid.mesh,
                grid.nkdiv,
                grid.nkfft,
                grid.factor_source,
                grid.r_grid,
                origin,
                grid.directions,
            )
            M.enable_mixed_fourier!(workspace, model, grid; memory_limit_bytes = 65536)
            point =
                origin + [
                    1/grid.mesh[1],
                    grid.mesh[2]>1 ? 1/grid.mesh[2] : 0,
                    grid.mesh[3]>1 ? 1/grid.mesh[3] : 0,
                ]
            expected = M.nonorthogonal_operator_matrices(model, point; convention)
            actual = M._workspace_nonorthogonal_operators(workspace, model, point)
            for name in keys(expected)
                @test getproperty(actual, name) ≈ getproperty(expected, name) atol=2e-11 rtol=2e-11
            end
            wanted = M.compute_kpoint!(direct, model, point)
            got = M.compute_kpoint!(workspace, model, point)
            @test got.spectrum.energies ≈ wanted.spectrum.energies atol=2e-12 rtol=2e-12
            alignment = wanted.spectrum.eigenvectors' * expected.overlap * got.spectrum.eigenvectors
            phases = Diagonal(conj.(diag(alignment)) ./ abs.(diag(alignment)))
            for (left, right) in (
                (got.berry_connection, wanted.berry_connection),
                (got.velocity_vertices, wanted.velocity_vertices),
                (got.position.generalized_derivatives, wanted.position.generalized_derivatives),
            )
                aligned = similar(left)
                for index in CartesianIndices(size(left)[3:end])
                    aligned[:, :, Tuple(index)...] = phases' * left[:, :, Tuple(index)...] * phases
                end
                @test aligned ≈ right atol=2e-10 rtol=2e-10
            end
            stats = M.mixed_fourier_stats(workspace)
            @test stats.fft_calls>0
            @test stats.allocated_bytes<=stats.memory_limit_bytes
            @test :nao_ddS in stats.groups
            @test_throws ArgumentError M._workspace_nonorthogonal_operators(
                workspace,
                model,
                point+[0.001, 0, 0],
            )
            @test_throws ArgumentError M.enable_mixed_fourier!(
                workspace,
                model,
                M.MixedFourierGrid(
                    grid.mesh,
                    grid.nkdiv,
                    grid.nkfft,
                    grid.factor_source,
                    grid.r_grid,
                    origin,
                    [1.0 1.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0],
                ),
            )
            M.disable_mixed_fourier!(workspace)
        end
    end
    runtime = WannierNLQG.Runtime
    @test runtime.progress_total_k((5,))==5
    @test runtime.progress_k_mesh_label((5,))=="5"
    @test runtime.validate_k_mesh_for_calculation((5,), :integral, 3)===nothing
    @test_throws ErrorException runtime.validate_k_mesh_for_calculation((5,), :kslice, 3)
    @test_throws ErrorException runtime.validate_fourier_factor("NKdiv", (1, 2), (5,))
end
end
