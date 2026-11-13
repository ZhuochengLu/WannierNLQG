const WP=ESKernel.WorkspacePlanning

@testset "Checked workspace and exact ownership" begin
    @test WP.checked_array_bytes(ComplexF64, (2, 3, 4)) == 384
    @test WP.checked_array_bytes(ComplexF64, (2, 0, 4)) == 0
    @test WP.checked_sum_bytes((32, 48, 16)) == 96
    @test WP.checked_sum_bytes(()) == 0
    @test_throws OverflowError WP.checked_array_bytes(ComplexF64, (typemax(Int), 2))
    @test_throws OverflowError WP.checked_sum_bytes((typemax(Int), 1))
    @test_throws ArgumentError WP.checked_array_bytes(ComplexF64, (true, 3))
    @test_throws ArgumentError WP.checked_array_bytes(Any, (2, 3))
    @test_throws ArgumentError WP.checked_sum_bytes((32, -1))
    envelope=WP.workspace_envelope((32, 48), (16,); limit_bytes = 96)
    @test envelope.total_bytes == 96 && !envelope.native_bytes_known
    @test_throws ArgumentError WP.workspace_envelope((32, 48), (17,); limit_bytes = 96)
    @test WP.batch_capacity(10, 16, 32, 96) == 4
    @test WP.batch_capacity(10, 16, 32, 16) == 0
    @test_throws ArgumentError WP.batch_capacity(10, -1, 32, 96)

    for n in (0, 1, 2, 7, 12), p in (1, 2, 3, 5)
        contiguous=[WP.contiguous_range(n, r, p) for r in 0:(p - 1)]
        cyclic=[WP.cyclic_range(n, r, p) for r in 0:(p - 1)]
        @test collect(Iterators.flatten(contiguous)) == collect(1:n)
        @test sort(collect(Iterators.flatten(cyclic))) == collect(1:n)
        @test all(length(contiguous[r + 1])==WP.partition_count(n, r, p) for r in 0:(p - 1))
        @test all(
            collect(contiguous[r + 1])==collect((fld(n * r, p) + 1):fld(n * (r + 1), p)) for
            r in 0:(p - 1)
        )
    end
    @test isempty(WP.contiguous_range(2, 0, 5))
    @test collect(WP.contiguous_range(2, 4, 5)) == [2]
    @test_throws ArgumentError WP.contiguous_range(1, 1, 1)
    @test_throws ArgumentError WP.cyclic_range(1, 0, 0)
end
