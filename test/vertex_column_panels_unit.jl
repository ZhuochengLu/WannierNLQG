using Test, LinearAlgebra, Random
function named_panel_allocation(output, left, right, overlap, indices)
    WannierNLQG.MatrixElements.active_velocity_selected_columns!(
        output,
        left,
        right,
        overlap,
        indices,
    )
    return @allocated WannierNLQG.MatrixElements.active_velocity_selected_columns!(
        output,
        left,
        right,
        overlap,
        indices,
    )
end
@testset "Ordered complete-band insertion output-column panels" begin
    E=WannierNLQG.MatrixElements;
    rng=MersenneTwister(240)
    bits(x)=reinterpret(UInt64, vec(x))
    for n in (64, 128, 132, 256, 260, 516)
        for indices in ([1], [n], [1, 2, 3, 4], [65, 66], [1, n], collect(1:n), [2, 1])
            maximum(indices)<=n || continue
            for mode in (:dense, :signedzero, :nonfinite)
                left=randn(rng, ComplexF64, n, n);
                right=randn(rng, ComplexF64, n, n);
                overlap=randn(rng, ComplexF64, n, n)
                if mode==:signedzero
                    left[1:5:end].=ComplexF64(-0.0, 0.0);
                    right[1:5:end].=ComplexF64(0.0, -0.0)
                elseif mode==:nonfinite
                    left[1, 1]=ComplexF64(Inf, NaN);
                    overlap[end, end]=ComplexF64(NaN, Inf)
                end
                expected=zeros(ComplexF64, n, n);
                actual=fill(ComplexF64(NaN, NaN), n, n)
                E.active_velocity_insertion_direction!(expected, left, right, overlap)
                E.active_velocity_selected_columns!(actual, left, right, overlap, indices)
                @test bits(actual[:, indices])==bits(expected[:, indices])
                # Change every operand on the next call; previous panels are not validity.
                left.=randn(rng, ComplexF64, n, n);
                right.=randn(rng, ComplexF64, n, n);
                overlap.=randn(rng, ComplexF64, n, n)
                fill!(actual, ComplexF64(NaN, NaN));
                next_indices=[n]
                E.active_velocity_insertion_direction!(expected, left, right, overlap)
                E.active_velocity_selected_columns!(actual, left, right, overlap, next_indices)
                @test bits(actual[:, next_indices])==bits(expected[:, next_indices])
                if n>=128 && rem(n, 4)==0
                    last_panel=64*div(n-1, 64)+1
                    @test all(isnan, real.(actual[:, 1:(last_panel - 1)]))
                end
            end
        end
    end
    n=516;
    left=randn(rng, ComplexF64, n, n);
    right=randn(rng, ComplexF64, n, n);
    overlap=randn(rng, ComplexF64, n, n);
    output=similar(left)
    for count in (1, 4, 16)
        @test named_panel_allocation(output, left, right, overlap, collect(257:(256 + count)))==0
    end
end
