module NonorthogonalLocalizedUnit
using Test, LinearAlgebra, WannierNLQG
using WannierNLQG.Core: NonorthogonalLocalizedModel, NonorthogonalLocalizedInput
using WannierNLQG.MatrixElements

@testset "Retained original compiler capture is inactive" begin end

"""Exact polynomial change of localized basis for a two-band embedded chain."""
function localized_chain(; moving = true, constant = Matrix{ComplexF64}(I, 2, 2), origin = 0.0)
    lattice = Matrix{Float64}(I, 3, 3)
    h_blocks = Dict(
        0 => ComplexF64[0.4 0.8; 0.8 -0.4],
        1 => ComplexF64[0 0.5; 0 0],
        -1 => ComplexF64[0 0; 0.5 0],
    )
    x_blocks = Dict(0 => constant)
    moving && (x_blocks[1] = ComplexF64[0 0.15; 0 0] * constant)
    tau = Diagonal([0.1 + origin, 0.35 + origin])
    zero_matrix() = zeros(ComplexF64, 2, 2)
    h = Dict{Int, Matrix{ComplexF64}}();
    s = empty(h);
    r = empty(h)
    for (p, xp) in x_blocks, (q, xq) in x_blocks
        translation = q - p
        get!(zero_matrix, s, translation) .+= xp' * xq
        # B = X'*tau*X+i*X'*dX, r = B-i*dS; coefficient is -p, not +q.
        get!(zero_matrix, r, translation) .+= xp' * tau * xq - p * xp' * xq
        for (cell, hopping) in h_blocks
            get!(zero_matrix, h, translation + cell) .+= xp' * hopping * xq
        end
    end
    translations = collect(minimum(keys(h)):maximum(keys(h)))
    rv = zeros(Int, 3, length(translations));
    rv[1, :] = translations
    hr = zeros(ComplexF64, 2, 2, length(translations));
    sr = similar(hr);
    fill!(sr, 0)
    position = zeros(ComplexF64, 2, 2, 3, length(translations))
    for (i, cell) in enumerate(translations)
        hr[:, :, i] = get(h, cell, zero_matrix())
        sr[:, :, i] = get(s, cell, zero_matrix())
        position[:, :, 1, i] = get(r, cell, zero_matrix())
    end
    return NonorthogonalLocalizedModel(
        lattice = lattice,
        r_vectors = rv,
        hamiltonian_r = hr,
        overlap_r = sr,
        position_r = position,
    )
end

"""Independent physical embedded eigenstates; no production derivative kernel is used."""
function physical_eigenstates(k_cartesian)
    h = ComplexF64[0.4 0.8 + 0.5cis(k_cartesian); 0.8 + 0.5cis(-k_cartesian) -0.4]
    frame = eigen(Hermitian(h)).vectors
    return Diagonal(exp.(-im * k_cartesian .* [0.1, 0.35])) * frame
end

"""Align physical, orthonormal wavefunctions across k; S(k0) alone is not a cross-k overlap."""
function align_physical_columns!(frame, reference)
    for band in axes(frame, 2)
        overlap = dot(reference[:, band], frame[:, band])
        abs(overlap) > 0.5 || error("finite-difference band overlap is too small")
        frame[:, band] .*= conj(overlap) / abs(overlap)
    end
    return frame
end

function geometry_workspace(model)
    request = MatrixElementRequest(
        SPECTRUM,
        BERRY_CONNECTION,
        INTERNAL_CONNECTION_DERIVATIVES,
        HAMILTONIAN_SECOND_DERIVATIVES,
        VELOCITY_VERTICES;
        spatial_dimension = 3,
        denominator_regularization = 0.0,
        degeneracy_threshold = 1e-4,
    )
    workspace =
        MatrixElementWorkspace(model, compile_matrix_plan(request; source_gauge_required = false))
    prepare_real_space!(workspace, model)
    return workspace
end

@testset "Localized input owns an exact copy without a second projection" begin
    source = localized_chain(; moving = false)
    adopted = NonorthogonalLocalizedInput(source)
    @test adopted.model !== source
    @test adopted.model.hamiltonian_r == source.hamiltonian_r
    @test adopted.model.overlap_r == source.overlap_r
    @test adopted.model.position_r == source.position_r
    @test adopted.model.raw_hamiltonian_r == source.raw_hamiltonian_r
    @test adopted.model.representation_diagnostics == source.representation_diagnostics
    workspace = geometry_workspace(source)
    compute_kpoint!(workspace, source, [0.125, 0.0, 0.0])
    expected = copy(adopted.model.hamiltonian_r)
    source.hamiltonian_r[1] += 1
    @test adopted.model.hamiltonian_r == expected
    WannierNLQG.Core.invalidate_scientific_data!(source)
    @test_throws ArgumentError WannierNLQG.Core.scientific_data_generation(source)
    @test_throws ArgumentError compute_kpoint!(workspace, source, [0.125, 0.0, 0.0])
    @test !isempty(WannierNLQG.Core.scientific_data_generation(adopted))
end

@testset "Nonorthogonal localized generalized spectrum and geometry" begin
    for moving in (false, true),
        constant in (Matrix{ComplexF64}(I, 2, 2), ComplexF64[1.2 0.3im; 0.1 0.9])

        model = localized_chain(; moving = moving, constant = constant)
        workspace = geometry_workspace(model)
        for kx in (0.037, 0.219, 0.481)
            k = [kx, 0.17, 0.23]
            data = compute_kpoint!(workspace, model, k)
            expected = sqrt(0.4^2 + abs2(0.8 + 0.5cis(2pi * kx)))
            @test data.spectrum.energies ≈ [-expected, expected] atol = 2e-13 rtol = 2e-13
            diagnostic = nonorthogonal_metric_diagnostics(workspace)
            @test diagnostic.normalized_eigen_residual < 1e-13
            @test diagnostic.metric_normalization_residual < 1e-12
            matrices = nonorthogonal_operator_matrices(model, k)
            @test data.position.wannier_connection_derivatives ≈
                  matrices.position_derivatives + im * matrices.overlap_second_derivatives atol =
                1e-13
            @test data.spectrum.eigenvectors' * matrices.overlap * data.spectrum.eigenvectors ≈ I atol =
                1e-12
            @test data.berry_connection[:, :, 1] ≈ data.berry_connection[:, :, 1]' atol = 1e-12
            @test maximum(abs, diag(data.berry_connection[:, :, 1])) < 1e-12
            # Independently differentiated closed-form band energy, in Cartesian k units.
            derivative = -0.8 * 0.5 * sin(2pi * kx) / expected
            @test real(data.velocity_vertices[2, 2, 1]) ≈ derivative atol = 1e-12
            @test abs(data.berry_connection[1, 2, 2]) < 1e-13
            @test all(isfinite, data.position.generalized_derivatives)
        end
    end
    model = localized_chain()
    prototype = geometry_workspace(model)
    shifted_offset = KPointOffset((1, 0, 0), 0)
    batch = KPointBatchWorkspace(model, prototype.plan, [KPointOffset(), shifted_offset])
    @test nonorthogonal_metric_diagnostics(batch.matrix_elements).status == :not_evaluated
    compute_kpoint!(batch.matrix_elements, model, [0.037, 0.0, 0.0])
    central_diagnostic = nonorthogonal_metric_diagnostics(batch.matrix_elements)
    shifted_data = matrix_data!(batch, shifted_offset)
    compute_kpoint!(shifted_data, batch.matrix_elements, model, [0.219, 0.0, 0.0])
    @test nonorthogonal_metric_diagnostics(batch.matrix_elements) == central_diagnostic
    @test nonorthogonal_metric_diagnostics(shifted_data, batch.matrix_elements).kpoint ==
          [0.219, 0.0, 0.0]
    compute_kpoint!(batch.matrix_elements, model, [0.037, 0.0, 0.0])
    @test nonorthogonal_metric_diagnostics(batch.matrix_elements) == central_diagnostic
    @test_throws ArgumentError matrix_data!(batch, KPointOffset((0, 1, 0), 0))
    # Finite raw asymmetry is retained separately from the consistent effective solve.
    asymmetric_metric = reshape(ComplexF64[1.0 8e-9; 0.0 1.0], 2, 2, 1)
    projected_model = NonorthogonalLocalizedModel(
        lattice = Matrix{Float64}(I, 3, 3),
        r_vectors = zeros(Int, 3, 1),
        hamiltonian_r = reshape(ComplexF64[-1 0; 0 1], 2, 2, 1),
        overlap_r = asymmetric_metric,
        position_r = nothing,
        representation_tolerance = 1e-6,
    )
    spectrum_plan=compile_matrix_plan(MatrixElementRequest(SPECTRUM); source_gauge_required = false)
    projected_workspace=MatrixElementWorkspace(projected_model, spectrum_plan)
    for attempt in 1:2
        spectrum=compute_spectrum!(projected_workspace, projected_model, [0.0, 0.0, 0.0])
        @test all(isfinite, spectrum.energies)
        @test projected_workspace.counts.diagonalizations == 1
        diagnostic=nonorthogonal_metric_diagnostics(projected_workspace)
        @test diagnostic.status == :evaluated
        @test diagnostic.effective_metric_normalization_residual < 1e-12
        @test diagnostic.original_metric_projection_effect > 1e-10
        @test projected_model.raw_overlap_r == asymmetric_metric
    end
    projected_position = NonorthogonalLocalizedModel(
        lattice = model.lattice,
        r_vectors = model.r_vectors,
        hamiltonian_r = model.hamiltonian_r,
        overlap_r = model.overlap_r,
        position_r = zeros(size(model.position_r)),
    )
    @test projected_position.raw_position_r == zeros(size(model.position_r))
    projected_matrices=nonorthogonal_operator_matrices(projected_position, [0.1, 0.0, 0.0])
    @test projected_matrices.position+im*projected_matrices.overlap_derivatives ≈
          permutedims(conj(projected_matrices.position), (2, 1, 3)) atol=1e-13
    bad = copy(model.overlap_r);
    bad[:, :, :] .*= -1
    negative = NonorthogonalLocalizedModel(
        lattice = model.lattice,
        r_vectors = model.r_vectors,
        hamiltonian_r = model.hamiltonian_r,
        overlap_r = bad,
        position_r = -model.position_r,
    )
    @test_throws ArgumentError compute_spectrum!(
        geometry_workspace(negative),
        negative,
        [0.1, 0, 0],
    )
    @test_throws ArgumentError compute_spectrum!(geometry_workspace(model), model, [NaN, 0, 0])
    request = MatrixElementRequest(BERRY_CONNECTION; denominator_regularization = 0.01)
    regularized_workspace =
        MatrixElementWorkspace(model, compile_matrix_plan(request; source_gauge_required = false))
    @test all(
        isfinite,
        compute_kpoint!(regularized_workspace, model, [0.1, 0.0, 0.0]).berry_connection,
    )
    request = MatrixElementRequest(SPIN; denominator_regularization = 0.0)
    @test_throws ArgumentError MatrixElementWorkspace(
        model,
        compile_matrix_plan(request; source_gauge_required = false),
    )
end

@testset "Independent physical finite differences and shared shift assembly" begin
    constant = ComplexF64[1.2 0.3im; 0.1 0.9]
    model = localized_chain(; constant = constant)
    workspace = geometry_workspace(model)
    kx = 0.219;
    k = [kx, 0.0, 0.0];
    cartesian = 2pi * kx
    data = compute_kpoint!(workspace, model, k)
    x = (Matrix{ComplexF64}(I, 2, 2) + ComplexF64[0 0.15cis(cartesian); 0 0]) * constant
    physical = Diagonal(exp.(-im * cartesian .* [0.1, 0.35])) * x * data.spectrum.eigenvectors
    center = align_physical_columns!(physical_eigenstates(cartesian), physical)
    @test center ≈ physical atol = 2e-13
    connection_errors = Float64[];
    derivative_errors = Float64[]
    fd_connection = zeros(ComplexF64, 2, 2);
    fd_derivative = similar(fd_connection)
    for step in (2e-3, 1e-3, 5e-4)
        plus = align_physical_columns!(physical_eigenstates(cartesian + step), center)
        minus = align_physical_columns!(physical_eigenstates(cartesian - step), center)
        derivative = (plus - minus) / (2step)
        second = (plus - 2center + minus) / step^2
        fd_connection .= im * center' * derivative
        fd_derivative .= im * (derivative' * derivative + center' * second)
        push!(connection_errors, abs(fd_connection[1, 2] - data.berry_connection[1, 2, 1]))
        push!(
            derivative_errors,
            abs(fd_derivative[1, 2] - data.position.generalized_derivatives[1, 2, 1, 1]),
        )
    end
    @test connection_errors[3] < 1e-6
    @test derivative_errors[3] < 5e-6
    @test connection_errors[2] < 0.35connection_errors[1]
    @test connection_errors[3] < 0.35connection_errors[2]
    @test derivative_errors[2] < 0.35derivative_errors[1]
    @test derivative_errors[3] < 0.35derivative_errors[2]
    kernel = zeros(ComplexF64, 2, 2, 3, 3, 3)
    generalized = zeros(ComplexF64, 2, 2, 3, 3)
    WannierNLQG.Responses.compute_conventional_shift_current_kernel!(
        kernel,
        generalized,
        data,
        1,
        2,
        2,
        3,
    )
    expected =
        -im *
        (fd_derivative[1, 2] * fd_connection[2, 1] - fd_derivative[2, 1] * fd_connection[1, 2])
    @test kernel[1, 2, 1, 1, 1] ≈ expected atol = 5e-6
    # Origin translation changes r by c*S but cannot change the physical response.
    translated = localized_chain(; constant = constant, origin = 2.3)
    translated_data = compute_kpoint!(geometry_workspace(translated), translated, k)
    translated_kernel = similar(kernel)
    WannierNLQG.Responses.compute_conventional_shift_current_kernel!(
        translated_kernel,
        generalized,
        translated_data,
        1,
        2,
        2,
        3,
    )
    @test translated_kernel ≈ kernel atol = 1e-11 rtol = 1e-11
    # Identity metric reaches the unchanged orthogonal backend through its own workspace.
    identity = localized_chain(; moving = false)
    orthogonal = WannierNLQG.Core.TightBindingModel(
        identity.lattice,
        2,
        identity.num_r_vectors,
        ones(Int, identity.num_r_vectors),
        identity.r_vectors,
        identity.hamiltonian_r,
        identity.position_r,
    )
    # The legacy all-entry inverse denominator has a 0/0 diagonal at eta=0.
    # A declared 1e-12 eV eta leaves separated off-diagonal denominators unchanged
    # at double precision; physical transition masks exclude diagonal pairs.
    reference_request = MatrixElementRequest(
        SPECTRUM,
        BERRY_CONNECTION,
        INTERNAL_CONNECTION_DERIVATIVES,
        HAMILTONIAN_SECOND_DERIVATIVES,
        VELOCITY_VERTICES;
        spatial_dimension = 3,
        denominator_regularization = 1e-12,
    )
    reference_plan = compile_matrix_plan(reference_request; source_gauge_required = false)
    orthogonal_workspace = MatrixElementWorkspace(orthogonal, reference_plan)
    prepare_real_space!(orthogonal_workspace, orthogonal)
    orthogonal_data = compute_kpoint!(orthogonal_workspace, orthogonal, k)
    identity_data = compute_kpoint!(geometry_workspace(identity), identity, k)
    orthogonal_kernel = similar(kernel);
    identity_kernel = similar(kernel)
    transition_mask = Bool[false true; true false]
    WannierNLQG.Responses.compute_conventional_shift_current_kernel!(
        orthogonal_kernel,
        generalized,
        orthogonal_data,
        1,
        2,
        2,
        3;
        active_pair_mask = transition_mask,
    )
    WannierNLQG.Responses.compute_conventional_shift_current_kernel!(
        identity_kernel,
        generalized,
        identity_data,
        1,
        2,
        2,
        3;
        active_pair_mask = transition_mask,
    )
    @test identity_kernel ≈ orthogonal_kernel atol = 1e-11 rtol = 1e-11
end
"""Independent analytic source matrices of the physical moving-basis chain."""
function closed_chain_jet(t, constant)
    w = (Matrix{ComplexF64}(I, 2, 2)+ComplexF64[0 0.15cis(t); 0 0])*constant
    wa = ComplexF64[0 0.15im*cis(t); 0 0]*constant
    h = ComplexF64[0.4 0.8+0.5cis(t); 0.8+0.5cis(-t) -0.4]
    ha = ComplexF64[0 0.5im*cis(t); -0.5im*cis(-t) 0]
    tau = Diagonal([0.1, 0.35])
    return (
        w = w,
        h = h,
        ha = ha,
        H_a = wa'*h*w+w'*ha*w+w'*h*wa,
        S_a = wa'*w+w'*wa,
        B = w'*tau*w+im*w'*wa,
        physical_velocity = ha+im*(h*tau-tau*h),
    )
end

"""Finite difference of the prescribed scalar jet, rather than exact eigenderivatives."""
function prescribed_jet_connection(t, coefficients, energies, eta, constant)
    source=closed_chain_jet(t, constant)
    h=coefficients'*source.H_a*coefficients
    g=coefficients'*source.S_a*coefficients
    b=coefficients'*source.B*coefficients
    tangent=zeros(ComplexF64, 2, 2)
    for n in 1:2, m in 1:2
        if n==m
            tangent[n, n]=-g[n, n]/2+im*real(b[n, n])
        else
            delta=energies[m]-energies[n]
            tangent[
                n,
                m,
            ]=-g[n, m]/2+(h[n, m]-(energies[n]+energies[m])*g[n, m]/2) * delta/(delta^2+eta^2)
        end
    end
    return (A = im*tangent+b, D = tangent, energy_first = real.(diag(h)-energies .* diag(g)))
end

@testset "D_eta physical identities and differentiated scalar prescription" begin
    constant=ComplexF64[1.2 0.3im; 0.1 0.9]
    model=localized_chain(; constant)
    k=[0.219, 0.0, 0.0];
    t=2pi*k[1]
    for eta in (0.0005, 0.001, 0.002, 0.05)
        request=MatrixElementRequest(
            SPECTRUM,
            BERRY_CONNECTION,
            INTERNAL_CONNECTION_DERIVATIVES,
            HAMILTONIAN_SECOND_DERIVATIVES,
            VELOCITY_VERTICES;
            denominator_regularization = eta,
        )
        workspace=MatrixElementWorkspace(
            model,
            compile_matrix_plan(request; source_gauge_required = false),
        )
        data=compute_kpoint!(workspace, model, k)
        c=data.spectrum.eigenvectors;
        e=data.spectrum.energies
        source=closed_chain_jet(t, constant);
        u=source.w*c
        expected_velocity=u'*source.physical_velocity*u
        @test data.velocity_vertices[:, :, 1] ≈ expected_velocity atol=2e-12 rtol=2e-12
        @test data.velocity_vertices[:, :, 1] ≈ data.velocity_vertices[:, :, 1]' atol=2e-12
        g=c'*source.S_a*c;
        h=c'*source.H_a*c
        d=data.gauge_correction[:, :, 1]
        @test d+d'+g ≈ zeros(ComplexF64, 2, 2) atol=2e-12
        @test data.berry_connection[:, :, 1] ≈ data.berry_connection[:, :, 1]' atol=2e-12
        @test data.position.energy_derivatives[:, 1] ≈ real.(diag(expected_velocity)) atol=2e-12
        for n in 1:2, m in 1:2
            n==m && continue
            delta=e[m]-e[n]
            numerator=h[n, m]-(e[n]+e[m])*g[n, m]/2
            defect=im*(e[n]-e[m])*data.berry_connection[n, m, 1]-expected_velocity[n, m]
            @test defect ≈ -numerator*eta^2/(delta^2+eta^2) atol=2e-12 rtol=2e-9
        end
        injection=zeros(ComplexF64, 2, 2, 3, 3, 3)
        WannierNLQG.Responses.compute_injection_current_kernel!(injection, data, 1, 2, 3)
        independent_A=prescribed_jet_connection(t, c, e, eta, constant).A
        expected=(real(expected_velocity[2, 2])-real(expected_velocity[1, 1])) *
                 independent_A[1, 2] *
                 independent_A[2, 1]
        @test injection[1, 2, 1, 1, 1] ≈ expected atol=2e-12 rtol=2e-12
        compact=similar(injection)
        WannierNLQG.Responses.compute_injection_current_kernel!(
            compact,
            data,
            1,
            2,
            3;
            active_pairs_nmajor = [(1, 2)],
            active_pair_count = 1,
            tensor_indices = [1, 1, 1],
        )
        @test compact[1, 2, 1, 1, 1] == injection[1, 2, 1, 1, 1]
        derivative_errors=Float64[];
        hessian_errors=Float64[]
        slopes=data.position.energy_derivatives[:, 1]
        for step in (4e-4, 2e-4, 1e-4)
            plus=prescribed_jet_connection(t+step, c*exp(step*d), e+step*slopes, eta, constant)
            minus=prescribed_jet_connection(t-step, c*exp(-step*d), e-step*slopes, eta, constant)
            derivative=(plus.A-minus.A)/(2step)
            hessian=(plus.energy_first-minus.energy_first)/(2step)
            push!(
                derivative_errors,
                abs(derivative[1, 2]-data.position.generalized_derivatives[1, 2, 1, 1]),
            )
            push!(
                hessian_errors,
                maximum(abs, hessian-data.position.energy_second_derivatives[:, 1, 1]),
            )
        end
        @test derivative_errors[end] < 1e-7
        @test hessian_errors[end] < 1e-7
        @test derivative_errors[end] < 0.4derivative_errors[1]
        @test hessian_errors[end] < 0.4hessian_errors[1]
        diagnostics=nonorthogonal_metric_diagnostics(workspace).scalar_geometry
        @test diagnostics.denominator_regularization_ev == eta
        @test diagnostics.approximation == :finite_eta_scalar_tangent
        @test diagnostics.diagonal_tangent_derivatives == :not_supplied
        @test diagnostics.physical_velocity_hermiticity_residual_ev_angstrom < 2e-12
    end
end

@testset "Zero and arbitrarily small gaps have explicit scalar semantics" begin
    # H(k_cart)=sin(k_cart)*sigma_z; S=I, r=0. The crossing is exactly at k=0.
    rv=zeros(Int, 3, 3);
    rv[1, :]=[-1, 0, 1]
    h=zeros(ComplexF64, 2, 2, 3);
    h[:, :, 1]=im*Diagonal([1.0, -1.0])/2;
    h[:, :, 3]=-h[:, :, 1]
    s=zeros(ComplexF64, 2, 2, 3);
    s[:, :, 2]=Matrix{ComplexF64}(I, 2, 2)
    crossing=NonorthogonalLocalizedModel(
        lattice = Matrix{Float64}(I, 3, 3),
        r_vectors = rv,
        hamiltonian_r = h,
        overlap_r = s,
        position_r = zeros(ComplexF64, 2, 2, 3, 3),
    )
    for eta in (0.0005, 0.001, 0.002)
        request=MatrixElementRequest(
            BERRY_CONNECTION,
            INTERNAL_CONNECTION_DERIVATIVES,
            VELOCITY_VERTICES;
            denominator_regularization = eta,
        )
        workspace=MatrixElementWorkspace(
            crossing,
            compile_matrix_plan(request; source_gauge_required = false),
        )
        data=compute_kpoint!(workspace, crossing, zeros(3))
        @test all(isfinite, data.berry_connection)
        @test all(isfinite, data.position.generalized_derivatives)
        @test nonorthogonal_metric_diagnostics(workspace).scalar_geometry.exact_degenerate_ordered_pairs ==
              2
    end
    exact_plan=compile_matrix_plan(
        MatrixElementRequest(BERRY_CONNECTION; denominator_regularization = 0.0);
        source_gauge_required = false,
    )
    exact_workspace=MatrixElementWorkspace(crossing, exact_plan)
    @test all(isfinite, compute_spectrum!(exact_workspace, crossing, zeros(3)).energies)
    @test_throws ArgumentError compute_remaining!(exact_workspace, crossing)
    # An actual nonzero 1e-8 eV gap does not trigger a blanket threshold rejection.
    near=compute_kpoint!(exact_workspace, crossing, [1e-8/(4pi), 0.0, 0.0])
    @test all(isfinite, near.berry_connection)
    @test nonorthogonal_metric_diagnostics(exact_workspace).scalar_geometry.minimum_gap_ev < 1e-4
    rotation=ComplexF64[1 1; -1 1]/sqrt(2)
    identity_frame=(energies = zeros(2), eigenvectors = Matrix{ComplexF64}(I, 2, 2))
    rotated_frame=(energies = zeros(2), eigenvectors = rotation)
    first_geometry=WannierNLQG.MatrixElements._nonorthogonal_geometry(
        crossing,
        zeros(3),
        identity_frame,
        1e-4;
        denominator_regularization = 0.001,
    )
    rotated_geometry=WannierNLQG.MatrixElements._nonorthogonal_geometry(
        crossing,
        zeros(3),
        rotated_frame,
        1e-4;
        denominator_regularization = 0.001,
    )
    @test first_geometry.energy_derivatives[:, 1] ≈ [1.0, -1.0] atol=1e-13
    @test rotated_geometry.energy_derivatives[:, 1] ≈ zeros(2) atol=1e-13
    @test sum(first_geometry.energy_derivatives[:, 1]) ≈
          sum(rotated_geometry.energy_derivatives[:, 1]) atol=1e-13
    @test rotated_geometry.diagnostics.degenerate_frame_prescription ==
          :metric_normalized_solver_frame_Rayleigh_slopes
end
"""Two-dimensional noncommuting, moving localized frame for an exactly flat connection."""
function localized_flat_plane(; constant = Matrix{ComplexF64}(I, 2, 2))
    x=Dict(
        (0, 0)=>constant,
        (1, 0)=>ComplexF64[0 0.15; 0 0]*constant,
        (0, 1)=>ComplexF64[0 0; 0.12 0]*constant,
    )
    h=Dict{Tuple{Int, Int}, Matrix{ComplexF64}}();
    s=empty(h)
    r=[empty(h) for a in 1:3];
    z()=zeros(ComplexF64, 2, 2)
    for (p, xp) in x, (q, xq) in x
        cell=(q[1]-p[1], q[2]-p[2])
        get!(z, h, cell) .+= xp'*Diagonal([-1.0, 1.0])*xq
        get!(z, s, cell) .+= xp'*xq
        for a in 1:2
            get!(z, r[a], cell) .+= -p[a]*xp'*xq
        end
    end
    cells=sort!(collect(keys(h)));
    rv=zeros(Int, 3, length(cells))
    hr=zeros(ComplexF64, 2, 2, length(cells));
    sr=similar(hr)
    pr=zeros(ComplexF64, 2, 2, 3, length(cells))
    for (i, cell) in enumerate(cells)
        rv[1:2, i]=collect(cell);
        hr[:, :, i]=h[cell];
        sr[:, :, i]=s[cell]
        for a in 1:2
            ;
            pr[:, :, a, i]=r[a][cell];
        end
    end
    return NonorthogonalLocalizedModel(
        lattice = Matrix{Float64}(I, 3, 3),
        r_vectors = rv,
        hamiltonian_r = hr,
        overlap_r = sr,
        position_r = pr,
    )
end

function ambient_workspace(model; eta = 0.0)
    req=MatrixElementRequest(
        SPECTRUM,
        BERRY_CONNECTION,
        WANNIER_CURVATURE;
        spatial_dimension = 3,
        denominator_regularization = eta,
    )
    return MatrixElementWorkspace(model, compile_matrix_plan(req; source_gauge_required = false))
end

@testset "Metric ambient curvature uses two moving directions and lowering" begin
    k=[0.19, 0.31, 0.07]
    for m in (Matrix{ComplexF64}(I, 2, 2), ComplexF64[1.2 0.3im; 0.1 0.9])
        model=localized_flat_plane(; constant = m);
        workspace=ambient_workspace(model)
        data=compute_kpoint!(workspace, model, k)
        matrices=nonorthogonal_operator_matrices(model, k)
        beta=[
            matrices.overlap\(matrices.position[:, :, a]+im*matrices.overlap_derivatives[:, :, a])
            for a in 1:3
        ]
        @test norm(beta[1]*beta[2]-beta[2]*beta[1]) > 0.01
        @test maximum(abs, data.wannier_curvature) < 2e-13
        @test maximum(abs, data.hamiltonian_curvature) < 2e-13
        @test maximum(abs, data.berry_connection) < 2e-13
        @test nonorthogonal_metric_diagnostics(workspace).ambient_curvature.hermiticity_residual_angstrom2 <
              2e-13
        @test nonorthogonal_metric_diagnostics(workspace).ambient_curvature.antisymmetry_residual_angstrom2 <
              2e-13
    end
    # A nonflat ambient connection: its diagonal term is essential to full band curvature.
    for metric in (Matrix{ComplexF64}(I, 2, 2), ComplexF64[1 0.2; 0.2 1.1])
        root=Matrix(sqrt(Hermitian(metric)))
        tx=ComplexF64[0 0.2; 0.2 0];
        ty=ComplexF64[0 -0.3im; 0.3im 0]
        r=zeros(ComplexF64, 2, 2, 3, 1);
        r[:, :, 1, 1]=root*tx*root;
        r[:, :, 2, 1]=root*ty*root
        model=NonorthogonalLocalizedModel(
            lattice = Matrix{Float64}(I, 3, 3),
            r_vectors = zeros(Int, 3, 1),
            hamiltonian_r = reshape(root*Diagonal([-1.0, 1.0])*root, 2, 2, 1),
            overlap_r = reshape(metric, 2, 2, 1),
            position_r = r,
        )
        workspace=ambient_workspace(model);
        data=compute_kpoint!(workspace, model, k)
        lower=root*(-im*(tx*ty-ty*tx))*root
        c=data.spectrum.eigenvectors
        @test data.wannier_curvature[:, :, 1, 2] ≈ lower atol=2e-13
        @test data.hamiltonian_curvature[:, :, 1, 2] ≈ c'*lower*c atol=2e-13
        @test maximum(abs, data.hamiltonian_curvature[:, :, 1, 2]) > 0.1
        @test data.hamiltonian_curvature[:, :, 1, 2] ≈ -data.hamiltonian_curvature[:, :, 2, 1] atol=2e-13
        @test data.hamiltonian_curvature[:, :, 1, 2] ≈ data.hamiltonian_curvature[:, :, 1, 2]' atol=2e-13
        for n in 1:2
            @test abs(WannierNLQG.Responses.berry_curvature_component(data, n, [1, 2], Int64(2))) <
                  2e-13
        end
    end
end
"""Independent closed-chain scalar jet SHG contraction for the 111 component.

Uses analytic physical source matrices and centered differences of the declared
D_eta connection, not production derivatives or response helpers. No BZ or charge prefactor.
"""
function independent_chain_shg(
    t,
    c,
    e,
    eta,
    m;
    frequency = 0.73,
    width = 0.08,
    temperature = 0.0,
    fermi = 0.0,
)
    jet=prescribed_jet_connection(t, c, e, eta, m);
    d=jet.D
    source=closed_chain_jet(t, m);
    g=c'*source.S_a*c;
    h=c'*source.H_a*c
    slope=real.(diag(h)-e .* diag(g));
    step=2e-5
    cp=c*exp(step*d);
    cm=c*exp(-step*d)
    plus=prescribed_jet_connection(t+step, cp, e+step*slope, eta, m)
    minus=prescribed_jet_connection(t-step, cm, e-step*slope, eta, m)
    derivative=(plus.A-minus.A)/(2step)
    hp=cp'*closed_chain_jet(t+step, m).H_a*cp;
    sp=cp'*closed_chain_jet(t+step, m).S_a*cp
    hm=cm'*closed_chain_jet(t-step, m).H_a*cm;
    sm=cm'*closed_chain_jet(t-step, m).S_a*cm
    slope_p=real.(diag(hp)-(e+step*slope) .* diag(sp))
    slope_m=real.(diag(hm)-(e-step*slope) .* diag(sm));
    hessian=(slope_p-slope_m)/(2step)
    pv(x)=x/(x*x+width*width);
    delta(x)=exp(-(x/width)^2)/(sqrt(pi)*width)
    resonance(x)=pv(x)+im*pi*delta(x)
    occupation(
        x,
    )=temperature<=1e-7 ? (x<=fermi ? 1.0 : 0.0) :
      inv(1+exp((x-fermi)/(8.617333262145e-5*temperature)))
    result=zeros(ComplexF64, 7, 2);
    a=jet.A;
    low=pv(frequency)
    for n in 1:2, m in 1:2
        n==m && continue
        f=occupation(e[n])-occupation(e[m]);
        gap=e[m]-e[n]
        # Tensor symmetry contributes both incident-field permutations.
        p1=2a[n, m]*derivative[m, n];
        p2=2derivative[n, m]*a[m, n]
        p3=2a[n, m]*a[m, n]*(slope[m]-slope[n])/gap
        p5=2(slope[n]-slope[m])*a[n, m]*a[m, n]
        d1=resonance(gap-frequency);
        d2=resonance(gap-2frequency)
        result[1, 1]+=im*f/(2gap)*(2p1*d2+p2*d1+(p1+p2)*low)
        result[2, 1]+=im*f/(2gap)*p3*(d1-4d2-low)
        result[4, 1]-=im*f/(4gap)*p2*(d1+low)
        result[5, 1]-=im*f/8*p5*d1*low^2
        result[1, 2]+=f*(p1*d2+p2*d1)
        result[2, 2]+=f*p3*(d1-2d2)
        result[4, 2]-=f/2*p2*d1
        result[5, 2]-=f/4*p5*d1*low
    end
    if temperature>1e-7
        kt=8.617333262145e-5*temperature
        kernel=low-im*delta(frequency)
        for n in 1:2
            offset=e[n]-fermi;
            abs(offset)>5kt && continue
            f1=-exp(-0.5(offset/kt)^2)/(kt*sqrt(2pi));
            f2=-offset/kt^2*f1
            semi=f2*slope[n]^3+f1*slope[n]*hessian[n]
            result[7, 1]-=im/4*semi*kernel*low^2
            result[7, 2]-=semi/2*kernel*low
        end
    end
    return result
end

@testset "Retained metric expert jet and optional SHG optical prescription" begin
    t=2pi*0.219;
    m=ComplexF64[1.2 0.3im; 0.1 0.9];
    model=localized_chain(; constant = m)
    for eta in (0.0, 0.001, 0.05)
        req=MatrixElementRequest(
            SPECTRUM,
            BERRY_CONNECTION,
            INTERNAL_CONNECTION_DERIVATIVES,
            HAMILTONIAN_SECOND_DERIVATIVES,
            VELOCITY_VERTICES,
            WANNIER_CURVATURE,
            (eta>0 ? (OPTICAL_CUTOFF_VERTICES,) : ())...;
            spatial_dimension = 3,
            denominator_regularization = eta,
        )
        workspace=MatrixElementWorkspace(
            model,
            compile_matrix_plan(req; source_gauge_required = false),
        )
        data=compute_kpoint!(workspace, model, [0.219, 0.0, 0.0]);
        if iszero(eta)
            @test_throws ArgumentError WannierNLQG.MatrixElements.optical_position_vertices(
                data,
                0.04,
                false,
            )
            continue
        end
        c=data.spectrum.eigenvectors;
        e=data.spectrum.energies
        dipole,
        regular,
        derivative,
        bare=WannierNLQG.MatrixElements.optical_position_vertices(data, 0.04, false)
        @test dipole === data.berry_connection
        @test regular === data.berry_connection
        @test derivative === data.position.generalized_derivatives
        @test_throws ArgumentError WannierNLQG.MatrixElements.optical_position_vertices(
            data,
            0.04,
            true,
        )
        @test WannierNLQG.Responses._second_harmonic_velocity(data) === data.velocity_vertices
        @test WannierNLQG.Responses._second_harmonic_hessian(data, 1, 1, 1, 0.04) ==
              data.position.energy_second_derivatives[1, 1, 1]
        for temperature in (0.0, 300.0)
            fermi=temperature==0 ? 0.0 : e[1]
            output=zeros(ComplexF64, 1, 1, 7, 2)
            WannierNLQG.Responses.second_harmonic_response!(
                output,
                data,
                [0.73],
                [(1, 1, 1)];
                fermi_energy = fermi,
                temperature,
                broadening = 0.08,
                low_frequency_broadening = 0.08,
                gaussian = true,
                intermediate_regularization = 0.04,
                eta_correction = false,
                degeneracy_threshold = 1e-4,
            )
            expected=independent_chain_shg(t, c, e, eta, m; temperature, fermi)
            # The old independent D_eta oracle still constrains the retained
            # semiclassical Hessian; the new optical terms have separate oracles.
            @test output[1, 1, 7, :] ≈ expected[7, :] atol=2e-8 rtol=2e-7
            @test all(isfinite, output)
            @test iszero(output[1, 1, 6, :])
        end
    end
end
"""Finite Fourier Dirac model in a constant or moving localized frame."""
function localized_dirac_plane(; moving = false, constant = Matrix{ComplexF64}(I, 2, 2))
    sx=ComplexF64[0 1; 1 0];
    sy=ComplexF64[0 -im; im 0];
    sz=ComplexF64[1 0; 0 -1]
    eye=Matrix{ComplexF64}(I, 2, 2)
    h0=Dict(
        (0, 0)=>0.2eye+1.5sz,
        (1, 0)=>(0.1eye+sz-im*sx)/2,
        (-1, 0)=>(0.1eye+sz+im*sx)/2,
        (0, 1)=>(sz-im*sy)/2,
        (0, -1)=>(sz+im*sy)/2,
    )
    x=Dict((0, 0)=>constant)
    moving &&
        (x[(1, 0)] = ComplexF64[0 0.15; 0 0]*constant; x[(0, 1)] = ComplexF64[0 0; 0.12 0]*constant)
    h=Dict{Tuple{Int, Int}, Matrix{ComplexF64}}();
    s=empty(h);
    r=[empty(h) for a in 1:3];
    z()=zeros(ComplexF64, 2, 2)
    for (p, xp) in x, (q, xq) in x
        cell=(q[1]-p[1], q[2]-p[2]);
        get!(z, s, cell) .+= xp'*xq
        for a in 1:2
            ;
            get!(z, r[a], cell) .+= -p[a]*xp'*xq;
        end
        for (v, hv) in h0
            get!(z, h, (cell[1]+v[1], cell[2]+v[2])) .+= xp'*hv*xq
        end
    end
    cells=sort!(collect(union(keys(h), keys(s))));
    rv=zeros(Int, 3, length(cells))
    hr=zeros(ComplexF64, 2, 2, length(cells));
    sr=similar(hr);
    pr=zeros(ComplexF64, 2, 2, 3, length(cells))
    for (i, cell) in enumerate(cells)
        rv[1:2, i]=collect(cell);
        hr[:, :, i]=get(h, cell, z());
        sr[:, :, i]=get(s, cell, z())
        for a in 1:2
            ;
            pr[:, :, a, i]=get(r[a], cell, z());
        end
    end
    return NonorthogonalLocalizedModel(
        lattice = Matrix{Float64}(I, 3, 3),
        r_vectors = rv,
        hamiltonian_r = hr,
        overlap_r = sr,
        position_r = pr,
    )
end

"""Independent Pauli-projector derivative Q_ab of the lower physical Dirac band."""
function dirac_projector_oracle(k)
    x, y=2pi*k[1], 2pi*k[2];
    d=[sin(x), sin(y), 1.5+cos(x)+cos(y)];
    radius=norm(d)
    pauli=(ComplexF64[0 1; 1 0], ComplexF64[0 -im; im 0], ComplexF64[1 0; 0 -1])
    eye=Matrix{ComplexF64}(I, 2, 2);
    nhat=d/radius
    lower=(eye-sum(nhat[i]*pauli[i] for i in 1:3))/2;
    upper=eye-lower
    da=([cos(x), 0.0, -sin(x)], [0.0, cos(y), -sin(y)], zeros(3))
    derivatives=[
        -sum(((da[a][i]-nhat[i]*dot(nhat, da[a]))/radius)*pauli[i] for i in 1:3)/2 for a in 1:3
    ]
    q=[tr(lower*derivatives[a]*upper*derivatives[b]) for a in 1:3, b in 1:3]
    center=0.2+0.1cos(x)
    return (energies = [center-radius, center+radius], q = q)
end

@testset "Independent Dirac interband Berry and finite-model orbital traces" begin
    k=[0.19, 0.31, 0.0];
    oracle=dirac_projector_oracle(k);
    mu=0.4
    factor=WannierNLQG.Responses.RESPONSE_CHARGE_C^2*1e-20/(
        2WannierNLQG.Responses.RESPONSE_HBAR_JS*WannierNLQG.Responses.RESPONSE_BOHR_MAGNETON
    )
    m=ComplexF64[1.2 0.3im; 0.1 0.9]
    for moving in (false, true), constant in (Matrix{ComplexF64}(I, 2, 2), m), eta in (0.0, 0.001)
        # A finite-eta tangent need not be invariant under a moving localized frame.
        moving && eta>0 && continue
        model=localized_dirac_plane(; moving, constant)
        req=MatrixElementRequest(
            SPECTRUM,
            BERRY_CONNECTION,
            VELOCITY_VERTICES,
            WANNIER_CURVATURE;
            spatial_dimension = 3,
            denominator_regularization = eta,
        )
        workspace=MatrixElementWorkspace(
            model,
            compile_matrix_plan(req; source_gauge_required = false),
        )
        data=compute_kpoint!(workspace, model, k)
        geometry=spectral_response_geometry(data)
        @test geometry isa NonorthogonalSpectralResponseGeometry
        @test geometry.denominator_regularization_ev == eta
        @test geometry.energies ≈ oracle.energies atol=2e-13
        @test geometry.connection == data.berry_connection
        @test geometry.covariant_hamiltonian == data.velocity_vertices
        @test maximum(abs, geometry.curvature) < 5e-13
        gap=oracle.energies[2]-oracle.energies[1];
        suppression=(gap^2/(gap^2+eta^2))^2
        expected_q=oracle.q*suppression
        q=[geometry.connection[1, 2, a]*geometry.connection[2, 1, b] for a in 1:3, b in 1:3]
        @test q ≈ expected_q atol=3e-13 rtol=3e-12
        @test real(WannierNLQG.Responses.berry_curvature_component(data, 1, [1, 2], Int64(2))) ≈
              -2imag(expected_q[1, 2]) atol=3e-13
        completion=finite_model_orbital_completion(2)
        f,
        g,
        weighted=WannierNLQG.Responses.OrbitalMagnetization.conventional_magnetization_traces(
            geometry,
            completion,
            1,
        )
        @test f ≈ expected_q atol=3e-13
        @test g ≈ oracle.energies[2]*expected_q atol=3e-13
        @test weighted ≈ oracle.energies[1]*expected_q atol=3e-13
        if eta == 0
            @test_throws ArgumentError WannierNLQG.Responses.orbital_magnetization_response(
                geometry,
                completion;
                fermi_energies = [mu],
                temperature = 0.0,
            )
        end
        om_eta = eta == 0 ? 0.001 : eta
        result=WannierNLQG.Responses.orbital_magnetization_response(
            geometry,
            completion;
            denominator_regularization = om_eta,
            fermi_energies = [mu],
            temperature = 0.0,
        )/factor
        om_q = oracle.q*(gap^2/(gap^2+om_eta^2))^2
        antisymmetric=imag(om_q[1, 2]-om_q[2, 1])
        sr=(oracle.energies[2]-oracle.energies[1])*antisymmetric
        cm=2(oracle.energies[1]-mu)*antisymmetric
        @test result[1, 3, :] ≈ [sr, cm, sr+cm] atol=3e-12 rtol=3e-12
        @test norm(result[1, 3, :]) > 0.01
        @test_throws ArgumentError WannierNLQG.Responses.orbital_magnetization_response(
            geometry,
            completion;
            fermi_energies = [mu],
            temperature = 0.0,
            projector = true,
        )
        @test_throws ArgumentError projector_spectral_pair(geometry, 1:1, 2:2)
        bad=OrbitalCompletion(
            copy(completion.derivative_overlap),
            copy(completion.energy_connection),
            copy(completion.energy_overlap),
        )
        bad.energy_overlap[1, 1, 1, 1]=1
        @test_throws ArgumentError WannierNLQG.Responses.orbital_magnetization_response(
            geometry,
            bad;
            fermi_energies = [mu],
            temperature = 0.0,
        )
        geometry.curvature[1, 1, 1, 2]=0.1
        @test_throws ArgumentError WannierNLQG.Responses.orbital_magnetization_response(
            geometry,
            completion;
            fermi_energies = [mu],
            temperature = 0.0,
        )
    end
end

@testset "Metric conventional spectral dispatch preserves the prepared payload" begin
    response = WannierNLQG.Responses
    transform = ComplexF64[1.2 0.3im; 0.1 0.9]
    for moving in (false, true), eta in (0.0, 0.001)
        model = localized_dirac_plane(; moving, constant = transform)
        request = MatrixElementRequest(
            SPECTRUM,
            BERRY_CONNECTION,
            VELOCITY_VERTICES,
            WANNIER_CURVATURE;
            spatial_dimension = 3,
            denominator_regularization = eta,
        )
        workspace = MatrixElementWorkspace(
            model,
            compile_matrix_plan(request; source_gauge_required = false),
        )
        data = compute_kpoint!(workspace, model, [0.19, 0.31, 0.0])
        geometry = spectral_response_geometry(data)
        @test geometry isa NonorthogonalSpectralResponseGeometry
        @test norm(geometry.eigenvectors' * geometry.eigenvectors - I) > 1e-3
        saved = (
            copy(geometry.connection),
            copy(geometry.energies),
            copy(geometry.covariant_hamiltonian),
            deepcopy(geometry.blocks),
        )
        for left in geometry.blocks, right in geometry.blocks
            left == right && continue
            expected = zeros(ComplexF64, 3, 3)
            for b in 1:3, a in 1:3, m in right, n in left
                expected[a, b] += geometry.connection[n, m, a] * geometry.connection[m, n, b]
            end
            @test conventional_spectral_pair(geometry, left, right) == expected
            @test conventional_spectral_pair(geometry, left, right) ==
                  conventional_spectral_pair(geometry.base, left, right)
            @test_throws ArgumentError projector_spectral_pair(geometry, left, right)
        end
        mu = sum(geometry.energies) / length(geometry.energies)
        gap = geometry.energies[end] - geometry.energies[1]
        for temperature in (0.0, 300.0)
            options = (
                fermi_energy = mu,
                temperature = temperature,
                gamma_intra_ev = 0.06,
                gamma_inter_ev = 0.06,
                fs_kind = temperature == 0 ? :gaussian : :none,
                eta_fs_ev = temperature == 0 ? 0.03 : 0.0,
            )
            actual = response.linear_optical_response(geometry, [0.0, gap, gap + 0.06]; options...)
            expected =
                response.linear_optical_response(geometry.base, [0.0, gap, gap + 0.06]; options...)
            @test actual == expected
            @test all(isfinite, actual)
            @test norm(actual) > 0
            @test_throws ArgumentError response.linear_optical_response(
                geometry,
                [gap];
                options...,
                projector = true,
            )
        end
        for temperature in (0.0, 300.0)
            options = (
                fermi_energies = [mu],
                temperature = temperature,
                gamma_intra_ev = 0.06,
                gamma_inter_ev = 0.06,
                fs_kind = temperature == 0 ? :gaussian : :none,
                eta_fs_ev = temperature == 0 ? 0.03 : 0.0,
            )
            actual = response.linear_transport_response(geometry; options...)
            expected = response.linear_transport_response(geometry.base; options...)
            @test actual == expected
            @test all(isfinite, actual)
            @test norm(actual) > 0
            optical = response.linear_optical_response(
                geometry,
                [0.0];
                fermi_energy = mu,
                temperature = temperature,
                gamma_intra_ev = 0.06,
                gamma_inter_ev = 0.06,
                fs_kind = temperature == 0 ? :gaussian : :none,
                eta_fs_ev = temperature == 0 ? 0.03 : 0.0,
            )
            @test real.(optical) ≈ actual rtol=2e-12 atol=1e-30
            @test_throws ArgumentError response.linear_transport_response(
                geometry;
                options...,
                projector = true,
            )
        end
        @test_throws ArgumentError WannierNLQG.MatrixElements.projector_block_velocity(
            geometry,
            first(geometry.blocks),
        )
        @test_throws ArgumentError WannierNLQG.MatrixElements.projector_block_curvature(
            geometry,
            first(geometry.blocks),
        )
        @test geometry.connection == saved[1]
        @test geometry.energies == saved[2]
        @test geometry.covariant_hamiltonian == saved[3]
        @test geometry.blocks == saved[4]
        @test geometry.denominator_regularization_ev == eta
    end
    @test_throws MethodError conventional_spectral_pair(
        (connection = zeros(ComplexF64, 2, 2, 3),),
        1:1,
        2:2,
    )
end

@testset "Metric optical and transport normal runtime entry" begin
    model = localized_dirac_plane(; moving = true, constant = ComplexF64[1.2 0.3im; 0.1 0.9])
    input = NonorthogonalLocalizedInput(model; parameters = (fixture = "metric_linear_runtime",))
    rates = SeparateRelaxation(gamma_intra_ev = 0.04, gamma_inter_ev = 0.05)
    table(path) = reduce(
        vcat,
        [
            permutedims(parse.(Float64, split(line))) for
            line in readlines(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
        ],
    )
    for slice in (false, true)
        sampling =
            slice ?
            KSlice(
                k_mesh = (2, 2),
                spatial_dimension = 3,
                origin = (0.0, 0.0, 0.0),
                vector_1 = (1.0, 0.0, 0.0),
                vector_2 = (0.0, 1.0, 0.0),
            ) : BZMesh(k_mesh = (2, 2), spatial_dimension = 3)
        observable =
            slice ? KSliceSelection(component = TensorComponent(1, 2), bands = AllBands()) :
            FullTensor()
        records = Dict{String, Dict{String, Matrix{Float64}}}()
        for quantity in ("linear_optical_response", "linear_transport")
            physics =
                quantity == "linear_transport" ?
                LinearTransportParameters(
                    fermi_energies = [0.13],
                    temperature = 300.0,
                    relaxation = rates,
                ) :
                LinearOpticalResponseParameters(
                    fermi_energy = 0.13,
                    temperature = 300.0,
                    relaxation = rates,
                    photon_energies = [0.0, 0.2],
                )
            task = TaskSpec(
                id = quantity,
                quantity = quantity,
                method = "Conventional",
                physics = physics,
                numerics = nothing,
                observable = observable,
            )
            config = TaskConfig(
                model = input,
                sampling = sampling,
                tasks = [task],
                execution = ExecutionOptions(fourier_backend = "Direct"),
                output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
            )
            rejected = TaskSpec(
                id = quantity,
                quantity = quantity,
                method = "Projector",
                physics = physics,
                observable = observable,
            )
            @test_throws ArgumentError WannierNLQG.Runtime.compile_native_task_config(
                config,
                rejected,
            )
            bad_numerics = TaskSpec(
                id = quantity,
                quantity = quantity,
                method = "Conventional",
                physics = physics,
                numerics = Numerics(denominator_regularization = 0.001),
                observable = observable,
            )
            if quantity=="linear_optical_response"
                @test WannierNLQG.Runtime.compile_native_task_config(config, bad_numerics).denominator_regularization==0.001
            else
                @test_throws ArgumentError WannierNLQG.Runtime.compile_native_task_config(
                    config,
                    bad_numerics,
                )
            end
            result = WannierNLQG.run(config)
            tables = Dict(
                basename(path) => table(path) for path in result.outputs if endswith(path, ".dat")
            )
            @test !isempty(tables)
            @test all(values(tables)) do values
                !isempty(values) && all(isfinite, values)
            end
            @test any(values(tables)) do values
                !iszero(norm(values[:, slice ? (4:5) : (2:19)]))
            end
            records[quantity] = tables
        end
        # Default optical eta is now .001 while metric dc retains eta=0.
        # Only Drude is geometry-width independent; equal-geometry total identities
        # are tested separately in linear_orbital_response_unit.
        for term in ("drude",)
            dc = records["linear_transport"]["linear_transport_$(term).dat"]
            optical =
                records["linear_optical_response"]["linear_optical_response_$(term)" * (slice ?
                                                                                        "_E00001" :
                                                                                        "") * ".dat"]
            columns = slice ? (4:5) : (2:19)
            @test (slice ? optical[:, columns] : optical[1:1, columns]) ≈ dc[:, columns] rtol=2e-10 atol=2e-8
        end
    end
end

@testset "OM complete velocity in moving nonorthogonal representations" begin
    elements=WannierNLQG.MatrixElements
    responses=WannierNLQG.Responses
    k=[0.19, 0.31, 0.0];
    values=[]
    for moving in (false, true),
        constant in (Matrix{ComplexF64}(I, 2, 2), ComplexF64[1.2 0.3im; 0.1 0.9])

        model=localized_dirac_plane(; moving, constant)
        request=elements.MatrixElementRequest(
            elements.BERRY_CONNECTION,
            elements.WANNIER_CURVATURE,
            elements.VELOCITY_VERTICES;
            denominator_regularization = 0.03,
        )
        workspace=elements.MatrixElementWorkspace(
            model,
            elements.compile_matrix_plan(request; source_gauge_required = false),
        )
        elements.prepare_real_space!(workspace, model)
        data=elements.compute_kpoint!(workspace, model, k)
        geometry=elements.spectral_response_geometry(data)
        @test maximum(abs, geometry.curvature)<1e-9
        result=responses.orbital_magnetization_response(
            geometry,
            elements.finite_model_orbital_completion(2);
            fermi_energies = [0.4],
            temperature = 0.0,
        )
        push!(values, result)
        @test all(isfinite, result)
        @test_throws ArgumentError responses.orbital_magnetization_response(
            geometry,
            elements.finite_model_orbital_completion(2);
            projector = true,
            fermi_energies = [0.4],
            temperature = 0.0,
        )
    end
    for value in values[2:end]
        @test value ≈ values[1] atol=2e-12 rtol=2e-12
    end
end

"""Four-band two-doublet model with full velocity coherence and noncommuting local positions."""
function metric_optical_doublet_model(transform)
    h0=Matrix(Diagonal([-0.2, -0.2, 0.2, 0.2]))
    hx=ComplexF64[
        0.1 0.2im 0.3 0.1im;
        -0.2im -0.1 0.2 0.1;
        0.3 0.2 0.2 0.15im;
        -0.1im 0.1 -0.15im -0.2
    ]
    hy=ComplexF64[0.2 0.1 0.15im 0.2; 0.1 -0.2 0.1 0.3; -0.15im 0.1 0.1 0.2im; 0.2 0.3 -0.2im -0.1]
    hz=zeros(ComplexF64, 4, 4)
    pa=ComplexF64[0 0.1 0.2im 0.05; 0.1 0.2 0.1 0.2; -0.2im 0.1 -0.1 0.1im; 0.05 0.2 -0.1im 0.3]
    pb=ComplexF64[0.1 0.2im 0.15 0.1; -0.2im -0.1 0.3im 0.2; 0.15 -0.3im 0.2 0.1; 0.1 0.2 0.1 0]
    positions=(pa, pb, zeros(ComplexF64, 4, 4))
    rv=zeros(Int, 3, 7)
    hr=zeros(ComplexF64, 4, 4, 7);
    sr=similar(hr);
    fill!(sr, 0)
    pr=zeros(ComplexF64, 4, 4, 3, 7)
    hr[:, :, 1]=transform'*h0*transform;
    sr[:, :, 1]=transform'*transform
    for a in 1:3
        rv[a, 2a]=1;
        rv[a, 2a + 1]=-1
        derivative=(hx, hy, hz)[a]
        hr[:, :, 2a]=transform'*derivative*transform/(2im)
        hr[:, :, 2a + 1]=-hr[:, :, 2a]
        pr[:, :, a, 1]=transform'*positions[a]*transform
    end
    NonorthogonalLocalizedModel(
        lattice = Matrix{Float64}(I, 3, 3),
        r_vectors = rv,
        hamiltonian_r = hr,
        overlap_r = sr,
        position_r = pr,
    )
end

"""Compile one normal metric optical task with ordinary defaults or explicit width."""
function metric_optical_test_config(
    model,
    numerics = Numerics();
    method = "Conventional",
    output = mktempdir(),
)
    task=TaskSpec(
        id = "metric_optics",
        quantity = "LORK",
        method = method,
        physics = LinearOpticalResponseParameters(
            photon_energies = [0.1, 0.4, 0.7],
            fermi_energy = 0.0,
            temperature = 300.0,
            relaxation = SeparateRelaxation(gamma_intra_ev = 0.06, gamma_inter_ev = 0.06),
        ),
        numerics = numerics,
        observable = KSliceSelection(component = TensorComponent(1, 2), bands = AllBands()),
    )
    TaskConfig(
        model = NonorthogonalLocalizedInput(model),
        sampling = KSlice(
            k_mesh = (1, 1),
            spatial_dimension = 3,
            origin = (0.0, 0.0, 0.0),
            vector_1 = (0.1, 0.0, 0.0),
            vector_2 = (0.0, 0.1, 0.0),
        ),
        tasks = [task],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(output_root = output, progress_enabled = false),
    )
end

@testset "Normal metric optical positive width scope and forwarding" begin
    rt=WannierNLQG.Runtime
    model=metric_optical_doublet_model(Matrix{ComplexF64}(I, 4, 4))
    cfg=metric_optical_test_config(model)
    @test only(rt.compile_task_configs(cfg)).denominator_regularization==0.001
    @test rt.task_parameter_summary(cfg, only(cfg.tasks)).numerics.denominator_regularization==0.001
    cfg2=metric_optical_test_config(model, Numerics(denominator_regularization = 0.017))
    @test only(rt.compile_task_configs(cfg2)).denominator_regularization==0.017
    for eta in (0.0, -0.001, Inf, NaN)
        bad=metric_optical_test_config(model, Numerics(denominator_regularization = eta))
        err=try
            ;
            rt.compile_task_configs(bad);
            nothing;
        catch error
            ;
            error;
        end
        @test err isa ArgumentError
        @test occursin(
            "NONORTHOGONAL_LINEAR_OPTICAL_REGULARIZATION_REQUIRED",
            sprint(showerror, err),
        )
    end
    # These are lower-level independent contracts: no global eta=0 ban.
    task=TaskSpec(
        id = "transport",
        quantity = "LT",
        method = "Conventional",
        physics = LinearTransportParameters(
            fermi_energies = [0.0],
            temperature = 300.0,
            relaxation = SeparateRelaxation(gamma_intra_ev = 0.06, gamma_inter_ev = 0.06),
        ),
    )
    @test rt._spectral_task_numerics(task, :linear_transport; nonorthogonal = true).denominator_regularization==0.0
    sc=TaskSpec(
        id = "sc",
        quantity = "SC",
        method = "Conventional",
        physics = OpticalParameters(
            photon_energies = [0.4],
            fermi_energy = 0.0,
            temperature = 300.0,
        ),
        numerics = Numerics(denominator_regularization = 0.0),
    )
    @test rt.resolved_numerical_values(sc, :shift_current; nonorthogonal = true).denominator_regularization==0.0
    @test all(
        isfinite,
        compute_spectrum!(
            MatrixElementWorkspace(
                model,
                compile_matrix_plan(
                    MatrixElementRequest(SPECTRUM; denominator_regularization = 0.0);
                    source_gauge_required = false,
                ),
            ),
            model,
            zeros(3),
        ).energies,
    )
    result=WannierNLQG.run(cfg)
    @test !isempty(result.outputs)
    @test all(isfile, result.outputs)
    child=joinpath(dirname(result.metadata_path), "metric_optics", "metadata.txt")
    @test occursin("0.001", read(child, String))
    @test_throws ArgumentError WannierNLQG.run(
        metric_optical_test_config(model; method = "Projector"),
    )
end

@testset "Finite eta metric optical blocks Drude interband Hall and orthogonal limit" begin
    elements=WannierNLQG.MatrixElements;
    response=WannierNLQG.Responses
    transform=ComplexF64[1.2 0.1im 0.05 0; 0 0.9 0.1 0.03im; 0 0 1.1 0.08; 0 0 0 0.85]
    values=[]
    options=(fermi_energy = 0.0, temperature = 300.0, gamma_intra_ev = 0.06, gamma_inter_ev = 0.06)
    for m in (Matrix{ComplexF64}(I, 4, 4), transform)
        model=metric_optical_doublet_model(m)
        request=MatrixElementRequest(
            SPECTRUM,
            BERRY_CONNECTION,
            VELOCITY_VERTICES,
            WANNIER_CURVATURE;
            denominator_regularization = 0.001,
        )
        data=compute_kpoint!(
            MatrixElementWorkspace(
                model,
                compile_matrix_plan(request; source_gauge_required = false),
            ),
            model,
            zeros(3),
        )
        g=spectral_response_geometry(data)
        @test length.(g.blocks)==[2, 2]
        @test g.denominator_regularization_ev==0.001
        value=response.linear_optical_response(g, [0.1, 0.4, 0.7]; options...)
        @test all(isfinite, value)
        @test norm(value[:, :, :, 1])>0
        @test norm(value[:, :, :, 2])>0
        @test norm(value[:, :, :, 3])>0
        push!(values, value)
        # Independent exact-block trace expressions for intraband weight and interblock Q.
        factor=response.RESPONSE_CHARGE_C^2/response.RESPONSE_HBAR_JS*1e-20
        derivative(E)=begin
            kT=response.RESPONSE_KB_EV*options.temperature;
            y=exp(-abs((E-options.fermi_energy)/kT));
            y/(kT*(1+y)^2)
        end
        drude=zeros(ComplexF64, 3, 3, 3)
        for block in g.blocks, a in 1:3, b in 1:3
            weight=factor*derivative(g.energies[first(block)])*real(
                tr(
                    g.covariant_hamiltonian[
                        block,
                        block,
                        a,
                    ]*g.covariant_hamiltonian[block, block, b],
                ),
            )
            for (j, photon) in enumerate([0.1, 0.4, 0.7])
                ;
                drude[j, a, b]+=weight/(0.06-im*photon);
            end
        end
        @test value[:, :, :, 1]≈drude atol=1e-35 rtol=2e-11
        left, right=g.blocks
        q=[tr(g.connection[left, right, a]*g.connection[right, left, b]) for a in 1:3, b in 1:3]
        @test conventional_spectral_pair(g, left, right)≈q atol=2e-14 rtol=2e-14
        u=Matrix{ComplexF64}(I, 4, 4);
        u[1:2, 1:2]=ComplexF64[1 im; im 1]/sqrt(2);
        u[3:4, 3:4]=ComplexF64[1 1; -1 1]/sqrt(2)
        conn=similar(g.connection);
        vel=similar(conn);
        curv=similar(g.curvature)
        for a in 1:3
            conn[:, :, a]=u'*g.connection[:, :, a]*u;
            vel[:, :, a]=u'*g.covariant_hamiltonian[:, :, a]*u
            for b in 1:3
                ;
                curv[:, :, a, b]=u'*g.curvature[:, :, a, b]*u;
            end
        end
        rotated=NonorthogonalSpectralResponseGeometry(
            SpectralResponseGeometry(
                copy(g.energies),
                g.eigenvectors*u,
                conn,
                vel,
                curv,
                deepcopy(g.blocks),
            ),
            0.001,
        )
        @test response.linear_optical_response(rotated, [0.1, 0.4, 0.7]; options...)≈value atol=1e-35 rtol=2e-11
    end
    @test values[2]≈values[1] atol=1e-35 rtol=2e-11
    identity_model=metric_optical_doublet_model(Matrix{ComplexF64}(I, 4, 4))
    orthogonal=WannierNLQG.Core.TightBindingModel(
        identity_model.lattice,
        4,
        identity_model.num_r_vectors,
        ones(Int, identity_model.num_r_vectors),
        identity_model.r_vectors,
        identity_model.hamiltonian_r,
        identity_model.position_r,
    )
    request=MatrixElementRequest(
        SPECTRUM,
        BERRY_CONNECTION,
        VELOCITY_VERTICES,
        WANNIER_CURVATURE;
        denominator_regularization = 0.001,
    )
    workspace=MatrixElementWorkspace(
        orthogonal,
        compile_matrix_plan(request; source_gauge_required = false),
    )
    prepare_real_space!(workspace, orthogonal)
    data=compute_kpoint!(workspace, orthogonal, zeros(3))
    @test response.linear_optical_response(
        spectral_response_geometry(data),
        [0.1, 0.4, 0.7];
        options...,
    )≈values[1] atol=1e-35 rtol=2e-11
end

"""Prepare owned ordinary/metric SHG fields with one declared positive geometry width."""
function shg_unification_data(model, eta)
    request=MatrixElementRequest(
        SPECTRUM,
        BERRY_CONNECTION,
        INTERNAL_CONNECTION_DERIVATIVES,
        HAMILTONIAN_SECOND_DERIVATIVES,
        VELOCITY_VERTICES,
        WANNIER_CURVATURE,
        (eta>0 ? (OPTICAL_CUTOFF_VERTICES,) : ())...;
        denominator_regularization = eta,
    )
    workspace=MatrixElementWorkspace(
        model,
        compile_matrix_plan(request; source_gauge_required = false),
    )
    prepare_real_space!(workspace, model)
    compute_kpoint!(workspace, model, [0.19, 0.31, 0.0])
end

@testset "SHG shared literal threshold and bare endpoint boundaries" begin
    response=WannierNLQG.Responses
    model=metric_optical_doublet_model(Matrix{ComplexF64}(I, 4, 4))
    data=shg_unification_data(model, 0.001)
    saved=copy(data.spectrum.energies)
    for gap in (0.0, 0.001, 0.002, nextfloat(0.002), 0.004)
        literal=[0.0, gap, 1.0, 2.0];
        data.spectrum.energies.=literal
        for band in 1:4
            plain=(spectrum = (energies = literal,),)
            @test response._second_harmonic_bcd_enabled(
                data,
                band,
                0.002,
            )==response._second_harmonic_bcd_enabled(plain, band, 0.002)
        end
    end
    data.spectrum.energies.=[0.0, 0.0015, 0.003, 1.0]
    @test [
        response._second_harmonic_bcd_enabled(data, n, 0.002) for n in 1:4
    ]==[false, false, false, true]
    data.spectrum.energies.=[0.0, 0.0, 1.0, 2.0]
    @test !response._second_harmonic_bcd_enabled(data, 1, 0.0)
    @test !response._second_harmonic_bcd_enabled(data, 2, 0.0)
    data.spectrum.energies.=[0.0, eps(Float64), 1.0, 2.0]
    @test response._second_harmonic_bcd_enabled(data, 1, 0.0) # no new machine-equality rule
    data.spectrum.energies.=saved
    for gap in
        (0.0, prevfloat(1e-7), 1e-7, nextfloat(1e-7), -prevfloat(1e-7), -1e-7, -nextfloat(1e-7))
        expected=abs(gap)<1e-7 ? zero(gap) : inv(gap)
        @test response._second_harmonic_endpoint_inverse(data, gap)==expected
        @test response._second_harmonic_endpoint_inverse((;), gap)==expected
        @test !response._second_harmonic_singular_pair(data, gap)
    end
    out=zeros(ComplexF64, 1, 1, 7, 2)
    for bad in (0.0, -0.001, NaN, Inf),
        which in (:broadening, :low_frequency_broadening, :intermediate_regularization)

        options=(
            fermi_energy = 0.2,
            temperature = 300.0,
            broadening = 0.025,
            low_frequency_broadening = 0.025,
            gaussian = false,
            intermediate_regularization = 0.001,
            eta_correction = false,
            degeneracy_threshold = 0.002,
        )
        options=merge(options, NamedTuple{(which,)}((bad,)))
        @test_throws ArgumentError response.second_harmonic_response!(
            out,
            data,
            [0.3],
            [(1, 2, 2)];
            options...,
        )
    end
end

@testset "Metric BCD bare curvature independent of finite eta and metric frame" begin
    k=[0.19, 0.31, 0.0];
    oracle=dirac_projector_oracle(k)
    target=-2imag(oracle.q[1, 2])
    for moving in (false, true),
        constant in (Matrix{ComplexF64}(I, 2, 2), ComplexF64[1.2 0.3im; 0.1 0.9]),
        eta in (0.001, 0.05)

        model=localized_dirac_plane(; moving, constant)
        data=shg_unification_data(model, eta)
        @test isolated_band_curvature(data, 1)[1, 2]≈target atol=2e-12 rtol=2e-12
        @test isolated_band_curvature(data, 2)[1, 2]≈-target atol=2e-12 rtol=2e-12
        @test isolated_band_curvature(data, 1)[2, 1]≈-target atol=2e-12 rtol=2e-12
        @test all(iszero, diag(isolated_band_curvature(data, 1)))
    end
end

@testset "SHG BCD identity-metric cutoff curvature and all-term accounting" begin
    response=WannierNLQG.Responses
    function at_gamma(model, eta)
        req=MatrixElementRequest(
            SPECTRUM,
            BERRY_CONNECTION,
            INTERNAL_CONNECTION_DERIVATIVES,
            HAMILTONIAN_SECOND_DERIVATIVES,
            VELOCITY_VERTICES,
            WANNIER_CURVATURE,
            (eta>0 ? (OPTICAL_CUTOFF_VERTICES,) : ())...;
            denominator_regularization = eta,
        )
        ws=MatrixElementWorkspace(model, compile_matrix_plan(req; source_gauge_required = false));
        prepare_real_space!(ws, model);
        compute_kpoint!(ws, model, zeros(3))
    end
    base=metric_optical_doublet_model(Matrix{ComplexF64}(I, 4, 4))
    for gap in (0.0, prevfloat(1e-7), 1e-7, nextfloat(1e-7), 0.001, 0.004)
        h=copy(base.hamiltonian_r);
        h[:, :, 1]=Diagonal([-0.3, -0.1, 0.0, gap])
        metric=NonorthogonalLocalizedModel(
            lattice = base.lattice,
            r_vectors = base.r_vectors,
            hamiltonian_r = h,
            overlap_r = base.overlap_r,
            position_r = base.position_r,
        )
        orthogonal=WannierNLQG.Core.TightBindingModel(
            base.lattice,
            4,
            base.num_r_vectors,
            ones(Int, base.num_r_vectors),
            base.r_vectors,
            h,
            base.position_r,
        )
        pair=[at_gamma(model, 0.001) for model in (orthogonal, metric)]
        for n in 1:4
            raw=optical_position_vertices(pair[1], 0.001, false)[4]
            @test response._second_harmonic_curvature(
                pair[2],
                n,
                nothing,
            )≈response._second_harmonic_curvature(pair[1], n, raw) atol=2e-12 rtol=2e-12
        end
        outputs=[]
        for data in pair
            value=zeros(ComplexF64, 2, 18, 7, 2)
            response.second_harmonic_response!(
                value,
                data,
                [0.1, 0.3],
                response.SECOND_HARMONIC_COMPONENTS;
                fermi_energy = 0.0,
                temperature = 300.0,
                broadening = 0.025,
                low_frequency_broadening = 0.025,
                gaussian = false,
                intermediate_regularization = 0.001,
                eta_correction = false,
                degeneracy_threshold = 0.002,
            )
            @test all(isfinite, value)
            @test size(sum(value; dims = 3))==(2, 18, 1, 2)
            push!(outputs, value)
        end
        @test outputs[2][:, :, 6, :]≈outputs[1][:, :, 6, :] atol=2e-10 rtol=2e-12
        # Other terms retain their distinct scalar prescriptions; do not assert full equality.
    end
    # Zero Hamiltonian derivatives retain finite connection contributions even at cutoff.
    h=zero(base.hamiltonian_r);
    h[:, :, 1]=Diagonal([-0.3, -0.1, 0.0, 5e-8])
    fixed=NonorthogonalLocalizedModel(
        lattice = base.lattice,
        r_vectors = base.r_vectors,
        hamiltonian_r = h,
        overlap_r = base.overlap_r,
        position_r = base.position_r,
    )
    data=at_gamma(fixed, 0.001)
    @test maximum(abs, isolated_band_curvature(data, 3))<2e-12
end

include("nonorthogonal_optical_cutoff_unit.jl")

end
