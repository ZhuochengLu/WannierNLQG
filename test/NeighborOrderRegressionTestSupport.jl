# STAGED ONLY: include from the existing operator_task_selection_unit.jl after write release.
# Synthetic Gram/energy construction follows diagnostic synthetic_neighbor_permutation.jl.
using Test, WannierNLQG, LinearAlgebra, Random

function neighbor_order_regression_tests(directory)
    io90 = WannierNLQG.IO
    extension = first(WannierNLQG.Wannierization._load_wannierization_extension!()).OperatorExport
    rng = MersenneTwister(928)
    nk, nb, nn = 2, 2, 3
    x = [randn(rng, ComplexF64, 4, nb) for a in 1:nn, k in 1:nk]
    energy = [Matrix(Hermitian(randn(rng, ComplexF64, 4, 4))) for k in 1:nk]
    gauges = zeros(ComplexF64, nb, nb, nk)
    gauges[:, :, 1] .= Matrix{ComplexF64}(I, nb, nb)
    gauges[:, :, 2] .= ComplexF64[1 im; im 1] ./ sqrt(2)
    centers = [0.12 -0.08 0.04; -0.07 0.09 0.11]
    chk = io90.WannierCHK(
        nb,
        nb,
        nk,
        (2, 1, 1),
        [0.0 0.0 0.0; 0.5 0.0 0.0],
        Matrix{Float64}(I, 3, 3),
        2pi*Matrix{Float64}(I, 3, 3),
        centers,
        gauges,
    )
    base = (
        weights = [0.7, 0.4, 0.9],
        neighbors = [1 2; 2 1; 1 2],
        displacement_cartesian = [1.0 0.2 0.3; 0.1 1.0 0.4; 0.5 0.2 1.0],
        overlap_order = repeat(reshape(1:nn, nn, 1), 1, nk),
    )
    # Independent canonical contraction. No source-order map is used by this oracle.
    function oracle(weighted)
        output = zeros(ComplexF64, nb, nb, 3, 3, nk)
        for k in 1:nk, a in 1:nn, b in 1:nn
            direct = weighted ? x[a, k]'*energy[k]*x[b, k] : x[a, k]'*x[b, k]
            wa = @view gauges[:, :, base.neighbors[a, k]]
            wb = @view gauges[:, :, base.neighbors[b, k]]
            left = @view base.displacement_cartesian[a, :]
            right = @view base.displacement_cartesian[b, :]
            block = (wa'*direct*wb) .* (cis.(-centers*left) .* transpose(cis.(centers*right)))
            for alpha in 1:3, beta in 1:3
                output[:, :, alpha, beta, k] .+=
                    base.weights[a]*base.weights[b]*left[alpha]*right[beta] .* block
            end
        end
        if !weighted
            for k in 1:nk, beta in 1:3, alpha in 1:beta
                output[:, :, beta, alpha, k] .= copy(adjoint(output[:, :, alpha, beta, k]))
            end
        end
        output
    end
    expected_f, expected_c = oracle(false), oracle(true)
    @test maximum(abs, expected_f) > 1e-3
    @test maximum(abs, expected_c) > 1e-3
    # B and spin links remain nonzero and exercise their established one-index map.
    links = randn(rng, ComplexF64, nb, nb, nn, nk)
    spin_links = randn(rng, ComplexF64, nb, nb, nn, 3, nk)
    band_energy = cat(ComplexF64[-0.9 0.2im; -0.2im 1.1], ComplexF64[-0.7 0.1; 0.1 1.3]; dims = 3)
    authority = (matrices_ev = band_energy,)
    central = zeros(ComplexF64, nb, nb, 3, nk)
    b_reference = nothing
    spin_reference = Dict{Symbol, Any}()
    cases = (
        ("identity", [1 1; 2 2; 3 3]),
        ("same_nontrivial", [3 3; 1 1; 2 2]),
        ("per_k", [3 2; 1 3; 2 1]),
    )
    for formatted in (false, true), (label, source_to_internal) in cases
        @testset "neighbor order $label formatted=$formatted" begin
            internal_to_source = hcat((invperm(source_to_internal[:, k]) for k in 1:nk)...)
            stencil = merge(base, (overlap_order = internal_to_source,))
            stem = joinpath(directory, label*"-"*string(formatted))
            uiu, uhu = stem*".uIu", stem*".uHu"
            io90.write_wannier_uiu(
                uiu,
                io90.WannierUIUHeader("nonzero Gram", nb, nk, nn),
                (k, b, a, h)->x[source_to_internal[a, k], k]'*x[source_to_internal[b, k], k];
                formatted,
            )
            io90.write_wannier_uhu(
                uhu,
                io90.WannierUHUHeader("nonzero energy", nb, nk, nn),
                (
                    k,
                    b,
                    a,
                    h,
                )->x[source_to_internal[a, k], k]'*energy[k]*x[source_to_internal[b, k], k];
                formatted,
            )
            f = Base.invokelatest(
                extension._construct_exact_full_derivative_overlap_tensor_q,
                chk,
                stencil,
                centers,
                uiu;
                formatted,
            )
            c, audit = Base.invokelatest(
                extension._authoritative_weighted_tensor_q,
                chk,
                stencil,
                centers,
                uhu;
                formatted,
            )
            @test isapprox(f, expected_f; atol = 2e-12, rtol = 2e-12)
            @test isapprox(c, expected_c; atol = 2e-12, rtol = 2e-12)
            # Sensitivity controls: a map applied on only either index must fail.
            if label != "identity"
                for wrong_side in (:first, :second)
                    bad = zeros(ComplexF64, size(expected_c))
                    for k in 1:nk, a in 1:nn, b in 1:nn
                        aa = wrong_side == :first ? source_to_internal[a, k] : a
                        bb = wrong_side == :second ? source_to_internal[b, k] : b
                        block =
                            gauges[:, :, base.neighbors[a, k]]' *
                            (x[aa, k]'*energy[k]*x[bb, k]) *
                            gauges[:, :, base.neighbors[b, k]]
                        left, right =
                            base.displacement_cartesian[a, :], base.displacement_cartesian[b, :]
                        block .*= cis.(-centers*left) .* transpose(cis.(centers*right))
                        for alpha in 1:3, beta in 1:3
                            bad[:, :, alpha, beta, k] .+=
                                base.weights[a]*base.weights[b]*left[alpha]*right[beta] .* block
                        end
                    end
                    @test maximum(abs, bad-expected_c)>1e-3
                end
            end
            mmn_data = similar(links)
            for k in 1:nk, a in 1:nn
                mmn_data[:, :, a, k] .= links[:, :, source_to_internal[a, k], k]
            end
            mmn=(data = mmn_data,)
            b = Base.invokelatest(
                extension._authoritative_hamiltonian_weighted_connection_q,
                chk,
                mmn,
                stencil,
                centers,
                authority,
            )
            b_reference === nothing && (b_reference=copy(b))
            @test maximum(abs, b)>1e-3
            @test isapprox(b, b_reference; atol = 2e-12, rtol = 2e-12)
            for (kind, writer, reader, header) in (
                (
                    :sIu,
                    io90.write_wannier_siu,
                    io90.foreach_wannier_siu_block,
                    io90.WannierSIUHeader,
                ),
                (
                    :sHu,
                    io90.write_wannier_shu,
                    io90.foreach_wannier_shu_block,
                    io90.WannierSHUHeader,
                ),
            )
                path=stem*"."*String(kind)
                writer(
                    path,
                    header("nonzero spin links", nb, nk, nn),
                    (k, a, axis, h)->spin_links[:, :, source_to_internal[a, k], axis, k];
                    formatted,
                )
                spin,
                _=Base.invokelatest(
                    extension._spin_link_position_q,
                    reader,
                    path,
                    chk,
                    stencil,
                    central;
                    formatted,
                    label = String(kind),
                )
                get!(spin_reference, kind, copy(spin))
                @test maximum(abs, spin)>1e-3
                @test isapprox(spin, spin_reference[kind]; atol = 2e-12, rtol = 2e-12)
            end
            if label=="identity"
                for badmap in (
                    [1 1; 1 2; 3 3],
                    [0 1; 2 2; 3 3],
                    [4 1; 2 2; 3 3],
                    reshape([1, 2, 3], 3, 1),
                    [1 1; 2 2],
                    Float64[1 1; 2.5 2; 3 3],
                )
                    invalid=merge(base, (overlap_order = badmap,))
                    for constructor in (
                        ()->Base.invokelatest(
                            extension._construct_exact_full_derivative_overlap_tensor_q,
                            chk,
                            invalid,
                            centers,
                            uiu;
                            formatted,
                        ),
                        ()->Base.invokelatest(
                            extension._authoritative_weighted_tensor_q,
                            chk,
                            invalid,
                            centers,
                            uhu;
                            formatted,
                        ),
                    )
                        err=try
                            constructor();
                            nothing
                        catch caught
                            ;
                            caught
                        end
                        @test err isa ArgumentError
                        @test occursin(
                            r"(?i)(neighbor|permutation|overlap.order|mapping)",
                            sprint(showerror, err),
                        )
                    end
                end
            end
        end
    end
end
