using Test

@testset "Borrowed position components use the existing Mixed pack" begin
    n, nr, nb = 2, 5, 3
    bins = Int[1, 3, 2, 1, 3]
    factors = ComplexF64[1 + 2im, -0.5im, 0, 2 - im, -1]
    for borrowed in (false, true)
        owners = [
            reshape(ComplexF64[complex(c + i / 10, -i / 7) for i in 1:(4 * 4 * 6)], 4, 4, 6) for
            c in 1:3
        ]
        components =
            borrowed ? [view(a, 2:3, 2:3, 1:nr) for a in owners] :
            [copy(view(a, 2:3, 2:3, 1:nr)) for a in owners]
        source = WannierNLQG.IO.PackedCartesianOperator(
            1,
            Dict((c,) => components[c] for c in 1:3),
            (n, n, nr),
        )
        saved = [copy(a) for a in components]
        for selected in ([1, 2, 3], [3, 1], [2], Int[])
            nv = n*n*length(selected)
            indices =
                selected == [1, 2, 3] ? nothing :
                Int[v+n*n*(a-1) for a in selected for v in 1:(n * n)]
            actual = fill(ComplexF64(9), nb, nv)
            oracle = zeros(ComplexF64, nb, nv)
            scratch = zeros(ComplexF64, nv, nb)
            WannierNLQG.MatrixElements._mixed_contiguous_zero_pack!(
                oracle,
                reshape(source, :, nr),
                bins,
                factors,
                indices,
                scratch,
            )
            @test WannierNLQG.MatrixElements._mixed_contiguous_position_pack!(
                actual,
                source,
                bins,
                factors,
                indices,
                scratch,
            ) === actual
            @test isequal(actual, oracle)
            direct = zeros(ComplexF64, nb, nv)
            for r in 1:nr, (c, d) in enumerate(selected), j in 1:n, i in 1:n
                direct[bins[r], i + n * (j - 1) + n * n * (c - 1)] +=
                    factors[r]*components[d][i, j, r]
            end
            @test isequal(actual, direct)
        end
        @test all(isequal(a, b) for (a, b) in zip(components, saved))
        output = fill(ComplexF64(7), nb, n*n)
        original_output = copy(output)
        scratch = zeros(ComplexF64, n*n, nb)
        partial = WannierNLQG.IO.PackedCartesianOperator(1, Dict((1,) => components[1]), (n, n, nr))
        @test_throws ArgumentError WannierNLQG.MatrixElements._mixed_contiguous_position_pack!(
            output,
            partial,
            bins,
            factors,
            collect(5:8),
            scratch,
        )
        @test isequal(output, original_output)
        @test_throws BoundsError WannierNLQG.MatrixElements._mixed_contiguous_position_pack!(
            output,
            source,
            Int[0, 3, 2, 1, 3],
            factors,
            collect(1:4),
            scratch,
        )
        @test isequal(output, original_output)
        @test_throws ArgumentError WannierNLQG.MatrixElements._mixed_contiguous_position_pack!(
            output,
            source,
            bins,
            factors,
            Int[1, 2, 4, 3],
            scratch,
        )
        @test isequal(output, original_output)
        @test_throws DimensionMismatch WannierNLQG.MatrixElements._mixed_contiguous_position_pack!(
            output,
            source,
            bins,
            factors,
            Int[1, 2],
            scratch,
        )
        @test isequal(output, original_output)
        alias_output = reshape(components[1], nr, n*n)
        @test_throws ArgumentError WannierNLQG.MatrixElements._mixed_contiguous_position_pack!(
            alias_output,
            source,
            bins,
            factors,
            collect(5:8),
            zeros(ComplexF64, n*n, nr),
        )
        @test all(isequal(a, b) for (a, b) in zip(components, saved))
        @test_throws ArgumentError WannierNLQG.MatrixElements._mixed_contiguous_position_pack!(
            output,
            source,
            bins,
            factors,
            collect(1:4),
            reshape(output, n*n, nb),
        )
        @test isequal(output, original_output)
    end
end
