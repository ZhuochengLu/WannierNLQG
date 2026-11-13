@testset "Source first-factor reuse retains canonical output and capability lifetime" begin
    let E=WannierNLQG.MatrixElements, C=WannierNLQG.Core, n=64, rng=MersenneTwister(233)
        bits(a)=reinterpret(UInt64, vec(a))
        seed=randn(rng, ComplexF64, n, n);
        h0=(seed+seed')/100+Diagonal(collect(range(-2.0, 2.0; length = n)))
        dx=Matrix(Diagonal(ComplexF64.(collect(range(0.01, 0.03; length = n)))))
        dy=zeros(ComplexF64, n, n)
        for j in 1:(n - 1)
            ;
            dy[j, j + 1]=0.01+0.005im;
            dy[j + 1, j]=conj(dy[j, j + 1]);
        end
        parameters=(h0, dx, dy)
        hamiltonian(k, p)=p[1]+(k[1]+k[1]^2/2)*p[2]+k[2]*p[3]
        derivative(k, p)=cat((1+k[1])*p[2], p[3], zeros(ComplexF64, n, n); dims = 3)
        input=AnalyticKInput(
            hamiltonian = hamiltonian,
            derivatives = (derivative, nothing, nothing),
            parameters = parameters,
            num_orbitals = n,
            lattice = Matrix{Float64}(I, 3, 3)*(2pi),
            basis = :fixed_orthonormal,
            periodic = false,
            derivative_method = :explicit,
            source_file = @__FILE__,
            evaluation_bounds = ((-2.0, -2.0, -2.0), (2.0, 2.0, 2.0)),
        )
        model=C.AnalyticKModel(input)
        for source_required in (false, true)
            plan=E.compile_matrix_plan(
                E.MatrixElementRequest(E.HAMILTONIAN_DERIVATIVES; spatial_dimension = 2);
                source_gauge_required = source_required,
            )
            ws=E.MatrixElementWorkspace(n, 0, plan);
            E.prepare_real_space!(ws, model)
            @test length(ws.scratch.hamiltonian.source_nonzero_indices)==n
            independent=E.MatrixElementWorkspace(n, 0, plan)
            @test ws.scratch.hamiltonian.source_nonzero_indices !==
                  independent.scratch.hamiltonian.source_nonzero_indices
            previous_generation=ws.data.generation
            for point in ([0.0, 0.0, 0.0], [0.001, -0.002, 0.0], [-1.0, 0.0, 0.0], [0.0, 0.0, 0.0])
                fill!(ws.scratch.hamiltonian.source_nonzero_indices, typemax(Int))
                data=E.compute_kpoint!(ws, model, point)
                @test data.generation>previous_generation
                previous_generation=data.generation
                @test E._has_capability(data.computed_mask, E.HAMILTONIAN_DERIVATIVES)
                gradients=derivative(point, parameters);
                expected=zeros(ComplexF64, n, n);
                temporary=similar(expected)
                for direction in 1:2
                    E.transform_to_hamiltonian_gauge!(
                        expected,
                        data.spectrum,
                        view(gradients,:,:,direction),
                        temporary,
                    )
                    @test bits(data.hamiltonian.derivatives[:, :, direction])==bits(expected)
                    if source_required
                        E._transform_source_gauge!(
                            expected,
                            data.spectrum.source_eigenvectors_adjoint,
                            view(gradients,:,:,direction),
                            data.spectrum.source_eigenvectors,
                            temporary,
                        )
                        @test bits(
                            data.hamiltonian.source_gauge_derivatives[:, :, direction],
                        )==bits(expected)
                    end
                end
                count_before=ws.counts.capability_computations[E.HAMILTONIAN_DERIVATIVES]
                canonical=copy(data.hamiltonian.derivatives)
                E.compute_remaining!(ws, model)
                @test ws.counts.capability_computations[E.HAMILTONIAN_DERIVATIVES]==count_before
                @test bits(data.hamiltonian.derivatives)==bits(canonical)
            end
        end
    end
end
