using Test, LinearAlgebra, Random, Serialization

isdefined(@__MODULE__, :optical472_model) ||
    include(joinpath(@__DIR__, "support", "OpticalMomentumReferenceSupport.jl"))

@testset "Independent first-order Wannier optical link and complete velocity" begin
    E=WannierNLQG.MatrixElements;
    C=WannierNLQG.Core
    model, centers=optical472_model();
    n=model.num_orbitals
    k=[0.17, -0.13, 0.09];
    q=[0.015, -0.023, 0.011]
    dq=model.lattice*q/(2pi)
    h, a, dh=optical472_reference(model, k)
    @test norm(a[:, :, 1]-Diagonal(diag(a[:, :, 1])))>0.03
    @test norm(a-optical472_reference(model, k+[0.07, 0, 0])[2])>1e-3
    for convention in (C.CONVENTION_I, C.CONVENTION_II)
        plan=E.compile_matrix_plan(
            E.MatrixElementRequest(
                E.HAMILTONIAN_DERIVATIVES,
                E.INTERNAL_CONNECTION;
                spatial_dimension = 3,
            );
            source_gauge_required = true,
            wannier_center_convention = convention,
        )
        ws=E.MatrixElementWorkspace(n, model.num_r_vectors, plan);
        E.prepare_real_space!(ws, model)
        data=[E.KPointMatrixData(n, model.num_r_vectors, plan) for _ in 1:3]
        l, r, c=data
        out=zeros(ComplexF64, n, n);
        rev=similar(out);
        buf=similar(out);
        tmp=similar(out)
        for scale in (1.0, -1.0, 0.5, 0.0)
            momentum=scale*q
            E.compute_kpoint!(l, ws, model, k+scale*dq/2)
            E.compute_kpoint!(r, ws, model, k-scale*dq/2)
            E.compute_kpoint!(c, ws, model, k)
            E.compute_optical_momentum_overlap!(
                out,
                l,
                r,
                c,
                model,
                plan,
                centers,
                momentum,
                buf,
                tmp,
            )
            f=Matrix{ComplexF64}(I, n, n)+im*sum(momentum[d]*a[:, :, d] for d in 1:3)
            if convention==C.CONVENTION_I
                dl=Diagonal(exp.(2pi*im*(centers'*l.kpoint)))
                dr=Diagonal(exp.(2pi*im*(centers'*r.kpoint)))
                f=dl'*f*dr
            end
            expected=l.spectrum.source_eigenvectors'*f*r.spectrum.source_eigenvectors
            @test out ≈ expected atol=3e-14 rtol=3e-14
            E.compute_optical_momentum_overlap!(
                rev,
                r,
                l,
                c,
                model,
                plan,
                centers,
                -momentum,
                buf,
                tmp,
            )
            @test rev ≈ out' atol=3e-14 rtol=3e-14
            # A finite-position representation supplies an independent exact overlap exp(iqX).
            # Its O(q^2) remainder tests the input order; it is NOT the production strategy.
            if convention==C.CONVENTION_II && scale>0
                x=sum(momentum[d]*a[:, :, d] for d in 1:3)
                error=norm(exp(im*x)-(I+im*x))
                errorhalf=norm(exp(im*x/2)-(I+im*x/2))
                @test 3.99 < error/errorhalf < 4.01
            end
        end
        # Full physical velocity in each source frame, independently from H,A,dH.
        E.compute_kpoint!(c, ws, model, k)
        u=c.spectrum.source_eigenvectors
        d=convention==C.CONVENTION_I ? Diagonal(exp.(2pi*im*(centers'*k))) : I
        actual=E.physical_velocity_vertices(c; source_gauge = true)
        for axis in 1:3
            v=dh[:, :, axis]+im*(h*a[:, :, axis]-a[:, :, axis]*h)
            @test actual[:, :, axis] ≈ u'*d'*v*d*u atol=5e-13 rtol=5e-13
        end
        E.compute_kpoint!(l, ws, model, k+dq/2);
        E.compute_kpoint!(r, ws, model, k-dq/2)
        @test_throws ArgumentError E.compute_optical_momentum_overlap!(
            out,
            l,
            r,
            c,
            model,
            plan,
            centers,
            -q,
            buf,
            tmp,
        )
        @test_throws ArgumentError E.compute_optical_momentum_overlap!(
            out,
            l,
            r,
            c,
            model,
            plan,
            centers,
            q,
            out,
            tmp,
        )
        # Algebraic frame covariance, independent of the eigenvalue labels. Actual degeneracy is tested below.
        rotation=Matrix{ComplexF64}(I, n, n);
        rotation[1:2, 1:2]=[1 im; im 1]/sqrt(2)
        E.compute_optical_momentum_overlap!(out, l, r, c, model, plan, centers, q, buf, tmp)
        original=copy(out)
        l.spectrum.source_eigenvectors .= l.spectrum.source_eigenvectors*rotation
        l.spectrum.source_eigenvectors_adjoint .= l.spectrum.source_eigenvectors'
        r.spectrum.source_eigenvectors .= r.spectrum.source_eigenvectors*rotation
        r.spectrum.source_eigenvectors_adjoint .= r.spectrum.source_eigenvectors'
        E.compute_optical_momentum_overlap!(out, l, r, c, model, plan, centers, q, buf, tmp)
        @test out ≈ rotation'*original*rotation atol=5e-14 rtol=5e-14
    end
end

@testset "PDSC q links at three centers retain auxiliary p transport" begin
    E=WannierNLQG.MatrixElements;
    R=WannierNLQG.Responses;
    C=WannierNLQG.Core
    model, centers=optical472_model();
    n=3
    k=[0.17, -0.13, 0.09];
    q=[0.015, -0.023, 0.011];
    dq=model.lattice*q/(2pi)
    fd=model.lattice*Matrix{Float64}(I, 3, 3)*0.001/(2pi)
    for convention in (C.CONVENTION_I, C.CONVENTION_II)
        plan=E.compile_matrix_plan(
            E.MatrixElementRequest(
                E.HAMILTONIAN_DERIVATIVES,
                E.INTERNAL_CONNECTION;
                spatial_dimension = 3,
            );
            source_gauge_required = true,
            wannier_center_convention = convention,
        )
        elements=E.MatrixElementWorkspace(n, model.num_r_vectors, plan)
        ws=R.make_geometric_loop_response_workspace(
            n,
            model.num_r_vectors,
            3,
            2;
            matrix_elements = elements,
        )
        E.prepare_real_space!(ws.scratch, model)
        for (data, point) in
            ((ws.valence_central_data, k-dq/2), (ws.conduction_central_data, k+dq/2))
            E.compute_kpoint!(
                data,
                ws.scratch,
                model,
                point;
                denominator_regularization = 0.001,
                spatial_dimension = 3,
            )
        end
        R.compute_geometric_loop_shift_current_kernel!(
            ws,
            k,
            dq,
            fd,
            centers,
            0.001,
            0.001,
            3,
            model,
            1,
            n;
            use_full_velocity_vertices = true,
            optical_q_cartesian = q,
        )
        for (link, left, right, midpoint, momentum) in (
            (ws.central_overlap_4, ws.conduction_central_data, ws.valence_central_data, k, q),
            (
                ws.forward_overlap_2,
                ws.valence_forward_data,
                ws.conduction_forward_data,
                k+fd[:, 3],
                -q,
            ),
            (
                ws.backward_overlap_2,
                ws.valence_backward_data,
                ws.conduction_backward_data,
                k-fd[:, 3],
                -q,
            ),
        )
            raw=optical472_reference(model, midpoint)[2]
            f=Matrix{ComplexF64}(I, n, n)+im*sum(momentum[d]*raw[:, :, d] for d in 1:3)
            if convention==C.CONVENTION_I
                f=Diagonal(exp.(-2pi*im*(centers'*left.common.kpoint)))*f*Diagonal(
                    exp.(2pi*im*(centers'*right.common.kpoint)),
                )
            end
            @test link ≈ left.spectrum.source_eigenvectors'*f*right.spectrum.source_eigenvectors atol=4e-14 rtol=4e-14
        end
        # The named PDSC expert default is the same complete route as Runtime, never bare/center-only.
        reference_kernel = copy(ws.response_kernel)
        R.compute_geometric_loop_photon_drag_shift_current_kernel!(
            ws,
            k,
            dq,
            fd,
            centers,
            0.001,
            0.001,
            3,
            model,
            1,
            n;
            optical_q_cartesian = q,
        )
        @test ws.response_kernel == reference_kernel
        @test_throws ArgumentError R.compute_geometric_loop_photon_drag_shift_current_kernel!(
            ws,
            k,
            dq,
            fd,
            centers,
            0.001,
            0.001,
            3,
            model,
            1,
            n;
            optical_q_cartesian = q,
            use_full_velocity_vertices = false,
        )
        # Last stencil is axis3. The p-link still uses the original center connector, not raw A.
        lv=ws.valence_central_data;
        rv=ws.valence_forward_data
        f=convention==C.CONVENTION_II ?
          Diagonal(exp.(2pi*im*(centers'*(lv.common.kpoint-rv.common.kpoint)))) : I
        @test ws.forward_overlap_1 ≈
              lv.spectrum.source_eigenvectors'*f*rv.spectrum.source_eigenvectors atol=4e-14 rtol=4e-14
        @test all(isfinite, ws.response_kernel)
    end
end

@testset "PDIC scalar/BLAS and PDSC shifted covariant derivative independent operator oracle" begin
    E=WannierNLQG.MatrixElements;
    R=WannierNLQG.Responses;
    C=WannierNLQG.Core
    model, centers=optical472_model();
    k=[0.17, -0.13, 0.09];
    q=[0.015, -0.023, 0.011]
    dq=model.lattice*q/(2pi);
    step=0.001;
    fd=model.lattice*Matrix{Float64}(I, 3, 3)*step/(2pi)
    for convention in (C.CONVENTION_I, C.CONVENTION_II)
        plan=E.compile_matrix_plan(
            E.MatrixElementRequest(
                E.HAMILTONIAN_DERIVATIVES,
                E.INTERNAL_CONNECTION;
                spatial_dimension = 3,
            );
            source_gauge_required = true,
            wannier_center_convention = convention,
        )
        elements=E.MatrixElementWorkspace(3, 3, plan)
        ws=R.make_geometric_loop_response_workspace(3, 3, 3, 2; matrix_elements = elements)
        E.prepare_real_space!(ws.scratch, model)
        for (data, point) in
            ((ws.valence_central_data, k-dq/2), (ws.conduction_central_data, k+dq/2))
            E.compute_kpoint!(
                data,
                ws.scratch,
                model,
                point;
                denominator_regularization = 0.001,
                spatial_dimension = 3,
            )
        end
        lv=ws.valence_central_data;
        rc=ws.conduction_central_data
        mvc=optical472_band_link_reference(model, centers, convention, lv, rc, k, -q)
        mcv=optical472_band_link_reference(model, centers, convention, rc, lv, k, q)
        vv=cat(
            (optical472_velocity_reference(model, centers, convention, lv, d) for d in 1:3)...;
            dims = 3,
        )
        vc=cat(
            (optical472_velocity_reference(model, centers, convention, rc, d) for d in 1:3)...;
            dims = 3,
        )
        expected=zeros(ComplexF64, 3, 3, 3, 3, 3)
        for a in 1:3, b in 1:3, c in 1:3, n in 1:3, m in 1:3
            forward=0.5*(vv[:, :, c]*mvc+mvc*vc[:, :, c])
            backward=0.5*(vc[:, :, b]*mcv+mcv*vv[:, :, b])
            expected[n, m, a, b, c]=(vc[m, m, a]-vv[n, n, a])*forward[n, m]*backward[m, n]
        end
        for strategy in (:scalar, :blas)
            actual=similar(expected);
            forward=zeros(ComplexF64, 3, 3, 3);
            backward=similar(forward)
            R.compute_photon_drag_injection_current_kernel!(
                actual,
                forward,
                backward,
                copy(mvc),
                copy(mcv),
                lv.common,
                rc.common,
                copy(lv.common.kpoint),
                copy(rc.common.kpoint),
                centers,
                convention==C.CONVENTION_II,
                1,
                3,
                1,
                3,
                3,
                3;
                _pdic_matrix_strategy = strategy,
                _optical_overlaps_prepared = true,
                _matrix_scratch_1 = zeros(ComplexF64, 3, 3),
                _matrix_scratch_2 = zeros(ComplexF64, 3, 3),
                valence_velocity_vertices = vv,
                conduction_velocity_vertices = vc,
            )
            @test actual ≈ expected atol=5e-14 rtol=5e-13
        end
        @test_throws ArgumentError R.compute_photon_drag_injection_current_kernel!(
            similar(expected),
            zeros(ComplexF64, 3, 3, 3),
            zeros(ComplexF64, 3, 3, 3),
            copy(mvc),
            copy(mcv),
            lv.common,
            rc.common,
            copy(lv.common.kpoint),
            copy(rc.common.kpoint),
            centers,
            false,
            1,
            3,
            1,
            3,
            3,
            3;
            valence_velocity_vertices = vv,
            conduction_velocity_vertices = vc,
        )
        R.compute_geometric_loop_shift_current_kernel!(
            ws,
            k,
            dq,
            fd,
            centers,
            0.001,
            step,
            3,
            model,
            1,
            3;
            use_full_velocity_vertices = true,
            optical_q_cartesian = q,
        )
        values=ComplexF64[]
        for (v, c, midpoint, p1, p3) in (
            (
                ws.valence_forward_data,
                ws.conduction_forward_data,
                k+fd[:, 3],
                ws.forward_overlap_1,
                ws.forward_overlap_3,
            ),
            (
                ws.valence_backward_data,
                ws.conduction_backward_data,
                k-fd[:, 3],
                ws.backward_overlap_1,
                ws.backward_overlap_3,
            ),
        )
            m=optical472_band_link_reference(model, centers, convention, v, c, midpoint, -q)
            j=optical472_velocity_reference(
                model,
                centers,
                convention,
                v,
                2,
            )*m+m*optical472_velocity_reference(model, centers, convention, c, 2)
            # Independent original p-frame connector, projected only after full J construction.
            f1=convention==C.CONVENTION_II ?
               Diagonal(exp.(2pi*im*(centers'*(lv.common.kpoint-v.common.kpoint)))) : I
            f3=convention==C.CONVENTION_II ?
               Diagonal(exp.(2pi*im*(centers'*(c.common.kpoint-rc.common.kpoint)))) : I
            l1=lv.spectrum.source_eigenvectors'*f1*v.spectrum.source_eigenvectors
            l3=c.spectrum.source_eigenvectors'*f3*rc.spectrum.source_eigenvectors
            push!(values, l1[1, 1]*j[1, 2]*l3[2, 2])
        end
        function residual_connection(data)
            _, a, _=optical472_reference(model, data.common.kpoint)
            raw=a[:, :, 3]-Diagonal((model.lattice' * centers)[3, :])
            d=convention==C.CONVENTION_I ? Diagonal(exp.(2pi*im*(centers'*data.common.kpoint))) : I
            u=data.spectrum.source_eigenvectors
            u'*d'*raw*d*u
        end
        av=residual_connection(lv);
        ac=residual_connection(rc)
        j0=vv[:, :, 2]*mvc+mvc*vc[:, :, 2]
        expected_derivative=(values[1]-values[2])/(2step)-im*av[1, 1]*j0[1, 2]+im*j0[1, 2]*ac[2, 2]
        R.prepare_geometric_loop_covariant_derivative_block!(ws, 3, 1, 2, (2,), step)
        # The independent link oracle is accurate to 3e-14; centered division by 1e-3 sets this bound.
        @test ws.covariant_insertion_derivatives[1, 2, 2] ≈ expected_derivative atol=3e-11 rtol=3e-11
        @test ws.valence_source_external_connection[:, :, 3] ≈ av atol=3e-14 rtol=3e-14
        @test ws.conduction_source_external_connection[:, :, 3] ≈ ac atol=3e-14 rtol=3e-14
    end
end

@testset "Explicit native point contract and missing raw-A direction" begin
    E=WannierNLQG.MatrixElements;
    C=WannierNLQG.Core
    model, centers=optical472_model()
    native=RealSpaceTBInput(
        lattice = model.lattice,
        r_vectors = model.r_vectors,
        hamiltonian_r = model.hamiltonian_r,
        orbital_positions = model.lattice'*centers,
        source_file = @__FILE__
    )
    @test E.optical_momentum_basis(model)==:wannier
    @test E.optical_momentum_basis(native.model)==:point_orbitals
    buffer = IOBuffer()
    serialize(buffer, native)
    seekstart(buffer)
    restored = deserialize(buffer)
    @test E.optical_momentum_basis(restored.model) == :point_orbitals
    @test restored.model.hamiltonian_r == native.model.hamiltonian_r
    @test !Base.mightalias(restored.model.hamiltonian_r, native.model.hamiltonian_r)
    k=[0.17, -0.13, 0.09];
    q=[0.015, 0.0, 0.0];
    dq=model.lattice*q/(2pi)
    directions=E.require_matrix_element_axes(
        E.MatrixElementDirectionRequirements(3),
        E.INTERNAL_CONNECTION,
        (2,),
    )
    plan=E.compile_matrix_plan(
        E.MatrixElementRequest(E.INTERNAL_CONNECTION; spatial_dimension = 3),
        directions;
        source_gauge_required = true,
        wannier_center_convention = C.CONVENTION_II,
    )
    ws=E.MatrixElementWorkspace(3, 3, plan);
    E.prepare_real_space!(ws, model)
    l, r, c=[E.KPointMatrixData(3, 3, plan) for _ in 1:3]
    for (data, point) in ((l, k+dq/2), (r, k-dq/2), (c, k))
        E.compute_kpoint!(data, ws, model, point)
    end
    @test_throws ArgumentError E.compute_optical_momentum_overlap!(
        zeros(ComplexF64, 3, 3),
        l,
        r,
        c,
        model,
        plan,
        centers,
        q,
        zeros(ComplexF64, 3, 3),
        zeros(ComplexF64, 3, 3),
    )
end

@testset "Actual degenerate blocks retain optical-link and velocity covariance" begin
    C=WannierNLQG.Core;
    E=WannierNLQG.MatrixElements;
    rng=MersenneTwister(472)
    n=4;
    lattice=Matrix{Float64}(I, 3, 3)*3
    h=reshape(Matrix(Diagonal(ComplexF64[-0.7, -0.7, 0.4, 0.4])), n, n, 1)
    ar=zeros(ComplexF64, n, n, 3, 1)
    for d in 1:3
        x=randn(rng, ComplexF64, n, n)*0.05;
        ar[:, :, d, 1]=(x+x')/2
    end
    centers=(lattice')\[real(ar[i, i, d, 1]) for d in 1:3, i in 1:n]
    model=C.TightBindingModel(lattice, n, 1, [1], zeros(Int, 3, 1), h, ar)
    q=[0.012, -0.008, 0.004];
    dq=lattice*q/(2pi);
    k=[0.1, 0.2, -0.1]
    for convention in (C.CONVENTION_I, C.CONVENTION_II)
        plan=E.compile_matrix_plan(
            E.MatrixElementRequest(
                E.HAMILTONIAN_DERIVATIVES,
                E.INTERNAL_CONNECTION;
                spatial_dimension = 3,
            );
            source_gauge_required = true,
            wannier_center_convention = convention,
        )
        ws=E.MatrixElementWorkspace(n, 1, plan);
        E.prepare_real_space!(ws, model)
        l, r, c=[E.KPointMatrixData(n, 1, plan) for _ in 1:3]
        for (data, point) in ((l, k+dq/2), (r, k-dq/2), (c, k))
            E.compute_kpoint!(data, ws, model, point)
            @test maximum(abs.(diff(data.spectrum.energies)[[1, 3]])) < 3e-15
        end
        out=zeros(ComplexF64, n, n);
        buf=similar(out);
        tmp=similar(out)
        E.compute_optical_momentum_overlap!(out, l, r, c, model, plan, centers, q, buf, tmp)
        original=copy(out);
        velocity=E.physical_velocity_vertices(l; source_gauge = true)
        ul=Matrix{ComplexF64}(I, n, n);
        ur=copy(ul)
        for indices in (1:2, 3:4)
            ul[indices, indices]=Matrix(qr(randn(rng, ComplexF64, 2, 2)).Q)
            ur[indices, indices]=Matrix(qr(randn(rng, ComplexF64, 2, 2)).Q)
        end
        for (data, u) in ((l, ul), (r, ur))
            data.spectrum.source_eigenvectors .= data.spectrum.source_eigenvectors*u
            data.spectrum.source_eigenvectors_adjoint .= data.spectrum.source_eigenvectors'
            data.hamiltonian.source_gauge_derivatives .= 0
        end
        E.compute_optical_momentum_overlap!(out, l, r, c, model, plan, centers, q, buf, tmp)
        @test out ≈ ul'*original*ur atol=5e-14 rtol=5e-14
        rotated_velocity=E.physical_velocity_vertices(l; source_gauge = true)
        for d in 1:3
            @test rotated_velocity[:, :, d] ≈ ul'*velocity[:, :, d]*ul atol=5e-14 rtol=5e-14
        end
    end
end

@testset "Optical q preparation extends Cartesian axes without changing response pairs" begin
    E = WannierNLQG.MatrixElements
    requirements = E.MatrixElementDirectionRequirements(2)
    requirements = E.require_matrix_element_axes(requirements, E.HAMILTONIAN_DERIVATIVES, (2,))
    requirements =
        E.require_matrix_element_pairs(requirements, E.INTERNAL_CONNECTION_DERIVATIVES, ((2, 1),))
    requirements = E.require_matrix_element_pairs(requirements, E.SPIN_VELOCITY, ((2, 3),))
    extended = E.extend_matrix_element_directions(requirements, 3)
    old_plan = (; spatial_dimension = 2, direction_requirements = requirements)
    new_plan = (; spatial_dimension = 3, direction_requirements = extended)
    @test extended.spatial_dimension == 3
    for kind in (E.INTERNAL_CONNECTION_DERIVATIVES, E.SPIN_VELOCITY)
        for a in 1:2, b in 1:(kind == E.SPIN_VELOCITY ? 3 : 2)
            @test E.matrix_element_pair_required(old_plan, kind, a, b) ==
                  E.matrix_element_pair_required(new_plan, kind, a, b)
        end
    end
    @test !E.matrix_element_pair_required(new_plan, E.INTERNAL_CONNECTION_DERIVATIVES, 3, 1)
    @test E.matrix_element_axis_required(new_plan, E.HAMILTONIAN_DERIVATIVES, 2)
    @test !E.matrix_element_axis_required(new_plan, E.HAMILTONIAN_DERIVATIVES, 3)
    @test_throws ArgumentError E.extend_matrix_element_directions(requirements, 1)
end
