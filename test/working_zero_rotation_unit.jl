@testset "Working-frame zero rotations retain full BLAS fallback semantics" begin
    E=WannierNLQG.MatrixElements
    C=WannierNLQG.Core
    for n in (1, 4, 63, 64, 65, 129)
        frame=ComplexF64[(sin(row+2column)+im*cos(2row-column))/(2n) for row in 1:n, column in 1:n]
        nonfinite=copy(frame);
        nonfinite[1, 1]=ComplexF64(Inf, 0.0)
        not_a_number=copy(frame);
        not_a_number[end, end]=ComplexF64(NaN, 0.0)
        huge=fill(ComplexF64(1e308, -1e308), n, n)
        signed_zero=ComplexF64[
            ComplexF64(isodd(row) ? -0.0 : 0.0, isodd(column) ? -0.0 : 0.0) for
            row in 1:n, column in 1:n
        ]
        dense=ComplexF64[sin(row+column)+im*cos(row-column) for row in 1:n, column in 1:n]
        for (vectors, adjoint_vectors, input) in (
            (frame, Matrix(frame'), zeros(ComplexF64, n, n)),
            (frame, Matrix(frame'), signed_zero),
            (frame, Matrix(frame'), dense),
            (nonfinite, Matrix(frame'), zeros(ComplexF64, n, n)),
            (frame, Matrix(nonfinite'), zeros(ComplexF64, n, n)),
            (not_a_number, Matrix(frame'), zeros(ComplexF64, n, n)),
            (huge, Matrix(huge'), zeros(ComplexF64, n, n)),
        )
            spectrum=C.KPointSpectrum(n);
            spectrum.eigenvectors.=vectors;
            spectrum.eigenvectors_adjoint.=adjoint_vectors
            expected_tmp=zeros(ComplexF64, n, n);
            expected=zeros(ComplexF64, n, n)
            mul!(expected_tmp, adjoint_vectors, input);
            mul!(expected, expected_tmp, vectors)
            temporary=fill(ComplexF64(NaN, NaN), n, n);
            actual=similar(temporary)
            E.transform_to_hamiltonian_gauge!(actual, spectrum, input, temporary)
            @test isequal(actual, expected)
            @test isequal(temporary, expected_tmp)
            if all(isfinite, expected)
                @test reinterpret(UInt64, vec(actual))==reinterpret(UInt64, vec(expected))
                @test reinterpret(UInt64, vec(temporary))==reinterpret(UInt64, vec(expected_tmp))
            else
                @test any(!isfinite, actual)
            end
            parent=fill(ComplexF64(NaN, NaN), 2n, 2n);
            scratch=similar(parent);
            fill!(scratch, ComplexF64(NaN, NaN))
            output_view=@view parent[1:2:2n, 1:2:2n];
            scratch_view=@view scratch[1:2:2n, 1:2:2n]
            reference_parent=similar(parent);
            reference_scratch=similar(parent)
            expected_view=@view reference_parent[1:2:2n, 1:2:2n]
            expected_scratch_view=@view reference_scratch[1:2:2n, 1:2:2n]
            mul!(expected_scratch_view, adjoint_vectors, input)
            mul!(expected_view, expected_scratch_view, vectors)
            E.transform_to_hamiltonian_gauge!(output_view, spectrum, input, scratch_view)
            @test isequal(output_view, expected_view)
            @test isequal(scratch_view, expected_scratch_view)
            @test all(isnan, parent[2:2:2n, :]) && all(isnan, parent[:, 2:2:2n])
            # Padded BLAS-compatible outputs still have first stride1.
            padded=fill(ComplexF64(NaN, NaN), 2n, 2n);
            padded_scratch=similar(padded)
            po=@view padded[1:n, 1:2:2n];
            pt=@view padded_scratch[1:n, 1:2:2n]
            reference_padded=similar(padded);
            reference_padded_scratch=similar(padded)
            ro=@view reference_padded[1:n, 1:2:2n];
            rt=@view reference_padded_scratch[1:n, 1:2:2n]
            mul!(rt, adjoint_vectors, input);
            mul!(ro, rt, vectors)
            E.transform_to_hamiltonian_gauge!(po, spectrum, input, pt)
            @test isequal(po, ro) && isequal(pt, rt)
            # Non-unit-stride input must preserve the original mixed generic/BLAS chain.
            input_parent=zeros(ComplexF64, 2n, 2n);
            input_view=@view input_parent[1:2:2n, 1:2:2n];
            input_view.=input
            input_ref_tmp=similar(expected_tmp);
            input_ref=similar(expected)
            mul!(input_ref_tmp, adjoint_vectors, input_view);
            mul!(input_ref, input_ref_tmp, vectors)
            E.transform_to_hamiltonian_gauge!(actual, spectrum, input_view, temporary)
            @test isequal(actual, input_ref) && isequal(temporary, input_ref_tmp)
        end
    end
end
