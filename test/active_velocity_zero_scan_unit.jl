@testset "Exact zero scan reuse preserves scalar products and call lifetime" begin
    let E=WannierNLQG.MatrixElements, rng=MersenneTwister(231)
        bits(a)=reinterpret(UInt64, vec(a))
        for n in (1, 4, 63, 64, 65, 129), layout in (:dense, :strided)
            left_storage=randn(rng, ComplexF64, 2n, 2n)
            right_storage=zeros(ComplexF64, 2n, 2n)
            left=layout==:dense ? copy(left_storage[1:n, 1:n]) : view(left_storage, 1:2:2n, 1:2:2n)
            right=layout==:dense ? zeros(ComplexF64, n, n) : view(right_storage, 1:2:2n, 1:2:2n)
            actual=zeros(ComplexF64, n, n);
            expected=similar(actual)
            indices=fill(typemax(Int), n)
            # Consecutive calls mutate density, indices and finite/nonfinite state.
            for mode in (
                :zero,
                :sparse,
                :half,
                :dense,
                :negative_zero,
                :tiny,
                :nan_left,
                :inf_left,
                :nan_right,
                :changed_sparse,
            )
                fill!(right, ComplexF64(0, 0));
                left[1, 1]=ComplexF64(0.25, -0.125)
                for column in 1:n, intermediate in 1:n
                    active =
                        mode==:dense || (
                            mode==:half ? isodd(intermediate) :
                            mode==:changed_sparse ? mod(intermediate+column, 5)==0 :
                            mode in (:sparse, :tiny, :nan_left, :inf_left, :nan_right) ?
                            intermediate==mod1(column+1, n) : false
                        )
                    if active
                        right[
                            intermediate,
                            column,
                        ]=mode==:tiny ? ComplexF64(1e-300, -1e-300) :
                          ComplexF64(intermediate/n, -column/n)
                    elseif mode==:negative_zero
                        right[intermediate, column]=ComplexF64(-0.0, -0.0)
                    end
                end
                mode==:nan_left && (left[1, 1]=ComplexF64(NaN, 0))
                mode==:inf_left && (left[1, 1]=ComplexF64(Inf, 0))
                mode==:nan_right && (right[end, 1]=ComplexF64(NaN, 0))
                fill!(indices, typemax(Int));
                fill!(actual, ComplexF64(NaN))
                E._source_gauge_product!(expected, left, right)
                E.source_gauge_first_product!(actual, left, right, indices)
                @test bits(actual)==bits(expected)
            end
        end
        n=129;
        left=randn(rng, ComplexF64, n, n);
        right=zeros(ComplexF64, n, n)
        for column in 1:n
            ;
            right[mod1(column+2, n), column]=1+2im;
        end
        actual=similar(right);
        indices=zeros(Int, n)
        E.source_gauge_first_product!(actual, left, right, indices)
        @test (@allocated E.source_gauge_first_product!(actual, left, right, indices))==0
        @test length(E.ActiveVelocityInsertionWorkspace(n).nonzero_indices)==n
    end
end
