using Test, LinearAlgebra
@testset "Bounded response route preserves canonical lane inputs" begin
    R=WannierNLQG.Runtime;
    M=WannierNLQG.MatrixElements
    for (divs, fft) in [
            ((1, 1, 1), (1, 1, 1)),
            ((1, 1, 1), (3, 3, 3)),
            ((3, 2, 1), (2, 2, 2)),
            ((4, 4, 4), (3, 3, 3)),
        ],
        ranks in (1, 2, 4, 7)

        mesh=divs .* fft;
        points=prod(mesh);
        width=3
        grid=M.MixedFourierGrid(
            mesh,
            divs,
            fft,
            :explicit,
            zeros(Int, 3, 1),
            zeros(3),
            Matrix{Float64}(I, 3, 3),
        )
        routes=[
            R._spectral_block_route_plan(grid, points, width, r, ranks, 10^8) for r in 0:(ranks - 1)
        ]
        @test all(!isnothing, routes)
        @test sort!(
            reduce(vcat, [x.local_indices for x in routes]; init = Int[]),
        )==collect(1:points)
        for src in 1:ranks
            route=routes[src]
            for i in route.local_indices
                value=reshape([sin(i+e/7) for e in 1:width], width, 1, 1, 1)
                R._spectral_route_record!(route, i, value, 1:width, [(1, 1)], (:total,))
            end
            @test all(route.written)
            @test_throws ErrorException R._spectral_route_record!(
                route,
                isempty(route.local_indices) ? 1 : first(route.local_indices),
                zeros(width, 1, 1, 1),
                1:width,
                [(1, 1)],
                (:total,),
            )
        end
        # Independent local transport reference: concatenate each receiver's
        # source segments, preserving actualMPI sender order. No collective here.
        for dst in 1:ranks
            receive=Float64[]
            for src in 1:ranks
                offset=sum(routes[src].sendcounts[1:(dst - 1)])
                n=routes[src].sendcounts[dst]
                @test n==routes[dst].recvcounts[src]
                append!(receive, view(routes[src].sendvalues, (offset + 1):(offset + n)))
            end
            @test length(receive)==length(routes[dst].recvvalues)
            for i in routes[dst].recvpoints, e in 1:width
                @test isequal(receive[(routes[dst].recvslots[i] - 1) * width + e], sin(i+e/7))
            end
            @test isnothing(R._spectral_block_route_plan(grid, points, width, dst-1, ranks, 1))
        end
    end
    ctx=R.MPIExecutionContext(false, false)
    send=Float64[1, -0.0, 3];
    receive=zeros(3)
    @test R.mpi_context_exchange_responses!(ctx, send, [3], receive, [3], nothing)===receive
    @test isequal(send, receive)
    @test isempty(R.mpi_context_exchange_responses!(ctx, Float64[], [0], Float64[], [0], nothing))
    for (sc, rc) in [([2], [3]), ([-1], [3]), ([3], [2]), ([typemax(Int)], [3])]
        saved=copy(receive)
        @test_throws ArgumentError R.mpi_context_exchange_responses!(
            ctx,
            send,
            sc,
            receive,
            rc,
            nothing,
        )
        @test isequal(receive, saved)
    end
    @test_throws ArgumentError R.mpi_context_exchange_responses!(ctx, send, [3], send, [3], nothing)
    @test_throws ArgumentError R.mpi_context_exchange_responses!(
        ctx,
        send,
        [1, 2],
        receive,
        [1, 2],
        nothing,
    )
end
