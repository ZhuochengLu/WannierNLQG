"""Independent local normalized frame, evaluated off-center without source-jet formulas."""
function cutoff_test_local_frame(model, k, vectors, shift)
    f=nonorthogonal_operator_matrices(model, k+model.lattice*shift/(2pi))
    metric=vectors'*f.overlap*vectors
    decomposition=eigen(Hermitian(metric))
    values=decomposition.values
    u=decomposition.vectors
    p=u*Diagonal(inv.(sqrt.(values)))*u'
    h=vectors'*f.hamiltonian*vectors
    connections=[];
    gradients=[]
    for a in 1:3
        ds=u'*(vectors'*f.overlap_derivatives[:, :, a]*vectors)*u
        # Frechet divided differences use sums of positive square roots; repeated
        # metric eigenvalues are regular, without eigenvector derivatives.
        dp=u*[
            -ds[i, j]/(sqrt(values[i])*sqrt(values[j])*(sqrt(values[i])+sqrt(values[j]))) for
            i in eachindex(values), j in eachindex(values)
        ]*u'
        push!(
            connections,
            p*(
                vectors'*(f.position[:, :, a]+im*f.overlap_derivatives[:, :, a])*vectors
            )*p+im*p*metric*dp,
        )
        push!(gradients, dp*h*p+p*(vectors'*f.hamiltonian_derivatives[:, :, a]*vectors)*p+p*h*dp)
    end
    return (; hamiltonian = p*h*p, connections, gradients)
end

"""Request cutoff optics independently of the larger SHG response capability set."""
function cutoff_test_workspace(model, eta; dimension = 3)
    req=MatrixElementRequest(
        OPTICAL_CUTOFF_VERTICES,
        VELOCITY_VERTICES,
        WANNIER_CURVATURE;
        spatial_dimension = dimension,
        denominator_regularization = eta,
    )
    requirements=WannierNLQG.MatrixElements.MatrixElementDirectionRequirements(dimension)
    plan=compile_matrix_plan(req, requirements; source_gauge_required = false)
    workspace=MatrixElementWorkspace(model, plan)
    prepare_real_space!(workspace, model)
    return workspace
end

"""Run the normal seven-term kernel; no alternate contraction implementation is injected."""
function cutoff_test_shg(data, eta_sum)
    result=zeros(ComplexF64, 2, 18, 7, 2)
    WannierNLQG.Responses.second_harmonic_response!(
        result,
        data,
        [0.1, 0.3],
        WannierNLQG.Responses.SECOND_HARMONIC_COMPONENTS;
        fermi_energy = 0.0,
        temperature = 300.0,
        broadening = 0.025,
        low_frequency_broadening = 0.025,
        gaussian = false,
        intermediate_regularization = eta_sum,
        eta_correction = false,
        degeneracy_threshold = 0.002,
    )
    return result
end

@testset "Optional normalized cutoff optical capability" begin
    m=ComplexF64[1.2 0.3im; 0.1 0.9]
    k=[0.19, 0.31, 0.0]
    model=localized_dirac_plane(; moving = true, constant = m)
    old_req=MatrixElementRequest(
        BERRY_CONNECTION,
        INTERNAL_CONNECTION_DERIVATIVES,
        HAMILTONIAN_SECOND_DERIVATIVES,
        VELOCITY_VERTICES,
        WANNIER_CURVATURE;
        denominator_regularization = 0.001,
    )
    legacy=MatrixElementWorkspace(
        model,
        compile_matrix_plan(old_req; source_gauge_required = false),
    )
    @test legacy.data.position.optical_cutoff===nothing
    old=compute_kpoint!(legacy, model, k)
    retained=optical_position_vertices(old, 0.017, false)
    @test retained[1]===retained[2]===old.berry_connection
    @test retained[3]===old.position.generalized_derivatives
    @test_throws ArgumentError cutoff_optical_position_vertices(old, 0.017, false)
    ws=cutoff_test_workspace(model, 0.001)
    @test has_capability(ws.plan, INTERNAL_CONNECTION_DERIVATIVES)
    @test has_capability(ws.plan, HAMILTONIAN_SECOND_DERIVATIVES)
    @test_throws ArgumentError cutoff_optical_position_vertices(ws.data, 0.017, false)
    data=compute_kpoint!(ws, model, k)
    vertices=cutoff_optical_position_vertices(data, 0.017, false)
    for i in 1:4
        @test optical_position_vertices(data, 0.017, false)[i]==retained[i]
    end
    @test data.position.energy_second_derivatives==old.position.energy_second_derivatives
    @test data.velocity_vertices==old.velocity_vertices
    @test data.internal_connection_derivatives==old.internal_connection_derivatives
    @test_throws ArgumentError cutoff_optical_position_vertices(data, 0.017, true)
    for eta_sum in (0.0, -1.0, Inf, NaN)
        @test_throws ArgumentError cutoff_optical_position_vertices(data, eta_sum, false)
    end
    @test all(vertices[i]==cutoff_optical_position_vertices(data, 0.039, false)[i] for i in 1:4)
    @test vertices[2]===data.berry_connection
    for a in 1:3, n in 1:2, l in 1:2
        n==l && continue
        @test vertices[2][n, l, a]≈data.berry_connection[n, l, a] atol=2e-12 rtol=2e-12
    end
    jet=data.position.optical_cutoff.source
    c=data.spectrum.eigenvectors
    center=cutoff_test_local_frame(model, k, c, zeros(3))
    @test jet.internal_connection≈cat(center.connections...; dims = 3) atol=2e-12 rtol=2e-12
    @test jet.hamiltonian_derivatives≈cat(center.gradients...; dims = 3) atol=2e-12 rtol=2e-12
    # Independent real-frame finite differences, rather than reusing the new
    # source Taylor identities as an expected-value implementation.
    errors_a=Float64[];
    errors_h=Float64[]
    for step in (1e-3, 5e-4)
        ea=0.0;
        eh=0.0
        for b in 1:2
            shift=zeros(3);
            shift[b]=step
            plus=cutoff_test_local_frame(model, k, c, shift)
            minus=cutoff_test_local_frame(model, k, c, -shift)
            for a in 1:2
                ea=max(
                    ea,
                    maximum(
                        abs,
                        (
                            plus.connections[a]-minus.connections[a]
                        )/(2step)-jet.internal_connection_derivatives[:, :, a, b],
                    ),
                )
                eh=max(
                    eh,
                    maximum(
                        abs,
                        (
                            plus.gradients[a]-minus.gradients[a]
                        )/(2step)-jet.hamiltonian_second_derivatives[:, :, a, b],
                    ),
                )
            end
        end
        push!(errors_a, ea);
        push!(errors_h, eh)
    end
    @test errors_a[2]<2e-6
    @test errors_h[2]<2e-6
    @test errors_a[2]<0.4errors_a[1]+2e-10
    @test errors_h[2]<0.4errors_h[1]+2e-10
    @test maximum(abs, jet.internal_connection[:, :, 1]-jet.internal_connection[:, :, 1]')<2e-12
    # Changing the response width does not overwrite geometry; a new geometry
    # width changes r_eta/Gcut, while the bare r0/D0 stay unchanged.
    other=cutoff_test_workspace(model, 0.05);
    d2=compute_kpoint!(other, model, k)
    v2=cutoff_optical_position_vertices(d2, 0.017, false)
    @test vertices[1]==v2[1]
    @test vertices[4]==v2[4]
    @test maximum(abs, vertices[2]-v2[2])>1e-7
    # With only two bands, endpoint-subtracted commutators have no remaining
    # intermediate state: Gcut is eta-independent even though r_eta changes.
    @test vertices[3]≈v2[3] atol=2e-12 rtol=2e-12
    @test cutoff_test_shg(data, 0.017)!=cutoff_test_shg(data, 0.039) ||
          all(iszero, cutoff_test_shg(data, 0.017)[:, :, 3, :]) # two-band case has no three-band term
    generation=data.generation
    before=copy(jet.internal_connection)
    compute_spectrum!(ws, model, k+[0.01, 0, 0])
    @test data.generation!=generation
    @test_throws ArgumentError cutoff_optical_position_vertices(data, 0.017, false)
    compute_remaining!(ws, model)
    @test jet.internal_connection!=before
    @test all(isfinite, cutoff_optical_position_vertices(data, 0.017, false)[3])
    saved=deepcopy(jet.internal_connection_derivatives)
    count=ws.counts.capability_computations[OPTICAL_CUTOFF_VERTICES]
    compute_remaining!(ws, model)
    @test jet.internal_connection_derivatives==saved
    @test ws.counts.capability_computations[OPTICAL_CUTOFF_VERTICES]==count
    # Numerical eta can change inside the existing capability layout; its
    # dependent bit is invalidated and the next access uses the new stamp.
    ws.plan=cutoff_test_workspace(model, 0.05).plan
    compute_remaining!(ws, model)
    @test data.position.optical_cutoff.geometric_regularization_ev==0.05
    @test cutoff_optical_position_vertices(data, 0.017, false)[2]===data.berry_connection
    # Optical tensors retain three Cartesian axes even for one/two-dimensional
    # sampling. Reject partial spatial layouts before allocating an inconsistent
    # tuple (the retained metric r_eta would otherwise have fewer axes).
    for dimension in (1, 2)
        @test_throws ArgumentError cutoff_test_workspace(model, 0.001; dimension)
    end
    @test_throws ArgumentError cutoff_test_workspace(model, 0.0)
end

@testset "Cutoff optics S=I seven terms and constant metric equivalence" begin
    base=metric_optical_doublet_model(Matrix{ComplexF64}(I, 4, 4))
    h=copy(base.hamiltonian_r);
    h[:, :, 1]=Diagonal([-0.3, -0.1, 0.0, 0.004])
    orth=WannierNLQG.Core.TightBindingModel(
        base.lattice,
        4,
        base.num_r_vectors,
        ones(Int, base.num_r_vectors),
        base.r_vectors,
        h,
        base.position_r,
    )
    transform=ComplexF64[1.2 0.1im 0.05 0; 0 0.9 0.1 0.03im; 0 0 1.1 0.08; 0 0 0 0.85]
    transformed=metric_optical_doublet_model(transform)
    metric=NonorthogonalLocalizedModel(
        lattice = base.lattice,
        r_vectors = base.r_vectors,
        hamiltonian_r = h,
        overlap_r = base.overlap_r,
        position_r = base.position_r,
    )
    constant_h=similar(h)
    for i in axes(h, 3)
        constant_h[:, :, i]=transform'*h[:, :, i]*transform
    end
    constant=NonorthogonalLocalizedModel(
        lattice = base.lattice,
        r_vectors = base.r_vectors,
        hamiltonian_r = constant_h,
        overlap_r = transformed.overlap_r,
        position_r = transformed.position_r,
    )
    for eta in (0.001, 0.05)
        ows=cutoff_test_workspace(orth, eta);
        od=compute_kpoint!(ows, orth, zeros(3))
        md=compute_kpoint!(cutoff_test_workspace(metric, eta), metric, zeros(3))
        cd=compute_kpoint!(cutoff_test_workspace(constant, eta), constant, zeros(3))
        @test WannierNLQG.MatrixElements._has_capability(od.computed_mask, OPTICAL_CUTOFF_VERTICES)
        expected=cutoff_test_shg(od, eta)
        @test cutoff_test_shg(md, eta)≈expected atol=2e-10 rtol=2e-12
        @test cutoff_test_shg(cd, eta)≈expected atol=2e-10 rtol=2e-12
        for i in (1, 3, 4)
            @test cutoff_optical_position_vertices(
                md,
                eta,
                false,
            )[i]==optical_position_vertices(od, eta, false)[i]
        end
        # The reused metric r_eta keeps its existing zero point diagonal.
        # SHG only consumes its off-diagonal links; Gcut independently uses
        # the full source Abar diagonal, already compared above.
        metric_regular=cutoff_optical_position_vertices(md, eta, false)[2]
        orthogonal_regular=optical_position_vertices(od, eta, false)[2]
        for a in 1:3, n in 1:4, m in 1:4
            n==m && continue
            @test metric_regular[n, m, a]==orthogonal_regular[n, m, a]
        end
        first=cutoff_optical_position_vertices(md, 0.017, false)
        second=cutoff_optical_position_vertices(md, 0.039, false)
        @test first==second
        a=cutoff_test_shg(md, 0.017);
        b=cutoff_test_shg(md, 0.039)
        for term in (1, 2, 4, 5, 6, 7)
            @test a[:, :, term, :]==b[:, :, term, :]
        end
        @test a[:, :, 3, :]!=b[:, :, 3, :]
        # An active outer-pair mask must not prune regular intermediate dipoles.
        mask=falses(4, 4);
        mask[1, 3]=true
        selected=cutoff_optical_position_vertices(md, eta, false; active_pairs = mask)
        @test selected[1]==first[1] && selected[2]==first[2]
        @test selected[3][1, 3, :, :]==first[3][1, 3, :, :]
        @test all(iszero, selected[3][3, 1, :, :])
    end
end

@testset "Normal metric SHG requests optional cutoff optics" begin
    model=metric_optical_doublet_model(Matrix{ComplexF64}(I, 4, 4))
    base=metric_optical_test_config(model)
    task=TaskSpec(
        id = "metric_shg_cutoff",
        quantity = "SHG",
        method = "Conventional",
        physics = SHGParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 300.0),
        numerics = Numerics(
            denominator_regularization = 0.001,
            intermediate_regularization = 0.017,
            eta_correction = false,
        ),
        observable = KSliceSelection(component = TensorComponent(1, 1, 1), bands = BandSelection()),
    )
    cfg=TaskConfig(
        model = base.model,
        sampling = base.sampling,
        tasks = [task],
        execution = base.execution,
        output = base.output,
    )
    compiled=only(WannierNLQG.Runtime.compile_task_configs(cfg))
    @test compiled.denominator_regularization==0.001
    @test compiled.shg_intermediate_regularization==0.017
    result=WannierNLQG.run(cfg)
    @test !isempty(result.outputs) && all(isfile, result.outputs)
    metadata=read(
        joinpath(dirname(result.metadata_path), "metric_shg_cutoff", "metadata.txt"),
        String,
    )
    @test occursin("metric_optical_r0_r_eta_Gcut", metadata)
    @test occursin("retained_metric_BCD_and_Hessian", metadata)
end

@testset "Cutoff source cache binds the workspace convention" begin
    source=localized_dirac_plane(; moving = true)
    centers=zeros(3, 2);
    centers[:, 2]=[0.1, 0.2, 0.0]
    model=NonorthogonalLocalizedModel(
        lattice = source.lattice,
        r_vectors = source.r_vectors,
        hamiltonian_r = source.hamiltonian_r,
        overlap_r = source.overlap_r,
        position_r = source.position_r,
        orbital_centers_cartesian = centers,
    )
    request=MatrixElementRequest(OPTICAL_CUTOFF_VERTICES; denominator_regularization = 0.001)
    ws=MatrixElementWorkspace(
        model,
        compile_matrix_plan(
            request;
            source_gauge_required = false,
            wannier_center_convention = WannierNLQG.Core.CONVENTION_I,
        ),
    )
    data=compute_kpoint!(ws, model, [0.19, 0.31, 0.0])
    @test all(isfinite, cutoff_optical_position_vertices(data, 0.017, false)[3])
    ws.plan=compile_matrix_plan(
        request;
        source_gauge_required = false,
        wannier_center_convention = WannierNLQG.Core.CONVENTION_II,
    )
    @test_throws ArgumentError compute_remaining!(ws, model)
end
