using Test, LinearAlgebra, WannierNLQG, HDF5, MPI, EzXML
const SPIN_FD_IO = WannierNLQG.IO
const SPIN_FD_ME = WannierNLQG.MatrixElements
const SPIN_FD_EXPORT = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).OperatorExport

@testset "canonical spin-link finite difference" begin
    lattice = Matrix{Float64}(I, 3, 3)
    frame = reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1)
    centers = [0.23 0.17 0.08; 0.41 0.09 0.12]
    chk =
        SPIN_FD_IO.WannierCHK(2, 2, 1, (1, 1, 1), zeros(1, 3), lattice, 2pi*lattice, centers, frame)
    shifts = Int[1 0 0; -1 0 0; 0 1 0; 0 -1 0; 0 0 1; 0 0 -1]
    vectors = 0.4 .* shifts
    stencil = SPIN_FD_ME.FiniteDifferenceStencil(
        fill(1/(2*0.4^2), 6),
        shifts,
        vectors,
        ones(Int, 6, 1),
        reshape(permutedims(shifts), 3, 6, 1),
        reshape(collect(1:6), 6, 1),
    )
    spin = zeros(ComplexF64, 2, 2, 3, 1)
    for s in 1:3, n in 1:2
        spin[n, n, s, 1] = (-1)^n*s/3
    end
    energies = [-2.0, 3.0]
    for weighted in [false, true]
        central = copy(spin)
        weighted && (central .*= reshape(energies, 1, 2, 1, 1))
        function reader(callback, path; kwargs...)
            for b in 1:6, s in 1:3
                link = central[:, :, s, 1]*Diagonal(cis.(-centers*vectors[b, :]))
                callback(link, 1, b, s, nothing)
            end
        end
        actual, audit = SPIN_FD_EXPORT._spin_link_position_q(
            reader,
            "fixture",
            chk,
            stencil,
            central;
            formatted = false,
            label = "canonical fixture",
        )
        expected = zeros(ComplexF64, 2, 2, 3, 3, 1)
        for a in 1:3, s in 1:3, n in 1:2
            expected[n, n, a, s, 1] = central[n, n, s, 1]*sin(0.4*centers[n, a])/0.4
        end
        @test isapprox(actual, expected; atol = 2e-12, rtol = 2e-12)
        @test audit["frame"] == "canonical_periodic_link_finite_difference"
        @test maximum(
            abs,
            actual-reshape(central, 2, 2, 1, 3, 1) .* reshape(centers, 1, 2, 3, 1, 1),
        ) > 1e-6
        # Metadata-only guiding-centre changes must not alter the fixed link derivative.
        changed = SPIN_FD_IO.WannierCHK(
            2,
            2,
            1,
            (1, 1, 1),
            zeros(1, 3),
            lattice,
            2pi*lattice,
            centers .+ 0.31,
            frame,
        )
        back, _ = SPIN_FD_EXPORT._spin_link_position_q(
            reader,
            "fixture",
            changed,
            stencil,
            central;
            formatted = false,
            label = "same-link fixture",
        )
        @test actual == back
        @test all(isfinite, actual)
    end
end
