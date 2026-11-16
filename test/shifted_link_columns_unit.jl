using Test, Random, LinearAlgebra, JSON3
if !isdefined(@__MODULE__, :PanelGemmComparisonSupport)
    include(joinpath(@__DIR__, "PanelGemmComparisonSupport.jl"))
end
module FrozenLink243
using LinearAlgebra
using WannierNLQG
const GeometricLoopMatrixData=WannierNLQG.MatrixElements.GeometricLoopMatrixData
const IdentityConventionFrameConnector=WannierNLQG.MatrixElements.IdentityConventionFrameConnector
const WannierCenterConventionFrameConnector=WannierNLQG.MatrixElements.WannierCenterConventionFrameConnector
function compute_convention_covariant_overlap!(
    output::AbstractMatrix{ComplexF64},
    left::GeometricLoopMatrixData,
    right::GeometricLoopMatrixData,
    ::IdentityConventionFrameConnector,
    wannier_centers_fractional::AbstractMatrix{<:Real},
    frame_phase_factors::AbstractVector{ComplexF64},
    frame_rotated_eigenvectors::AbstractMatrix{ComplexF64},
)
    return mul!(
        output,
        left.spectrum.source_eigenvectors_adjoint,
        right.spectrum.source_eigenvectors,
    )
end
function compute_convention_covariant_overlap!(
    output::AbstractMatrix{ComplexF64},
    left::GeometricLoopMatrixData,
    right::GeometricLoopMatrixData,
    ::WannierCenterConventionFrameConnector,
    wannier_centers_fractional::AbstractMatrix{<:Real},
    frame_phase_factors::AbstractVector{ComplexF64},
    frame_rotated_eigenvectors::AbstractMatrix{ComplexF64},
)
    num_orbitals = left.num_orbitals
    right.num_orbitals == num_orbitals || error("Loop overlap orbital counts do not match.")
    size(output) == (num_orbitals, num_orbitals) ||
        throw(DimensionMismatch("Loop overlap output has the wrong shape."))
    size(wannier_centers_fractional) == (3, num_orbitals) || throw(
        DimensionMismatch(
            "wannier_centers_fractional must have size (3, $(num_orbitals)); " *
            "got $(size(wannier_centers_fractional)).",
        ),
    )
    length(frame_phase_factors) == num_orbitals ||
        throw(DimensionMismatch("Convention frame phase buffer has incompatible length."))
    size(frame_rotated_eigenvectors) == (num_orbitals, num_orbitals) ||
        throw(DimensionMismatch("Convention frame eigenvector buffer has incompatible size."))
    delta_k_1 = left.common.kpoint[1] - right.common.kpoint[1]
    delta_k_2 = left.common.kpoint[2] - right.common.kpoint[2]
    delta_k_3 = left.common.kpoint[3] - right.common.kpoint[3]
    @inbounds for orbital in 1:num_orbitals
        phase_argument =
            delta_k_1 * wannier_centers_fractional[1, orbital] +
            delta_k_2 * wannier_centers_fractional[2, orbital] +
            delta_k_3 * wannier_centers_fractional[3, orbital]
        frame_phase_factors[orbital] = cis(2.0 * pi * phase_argument)
    end
    @inbounds for column in 1:num_orbitals, orbital in 1:num_orbitals
        frame_rotated_eigenvectors[orbital, column] =
            frame_phase_factors[orbital] * right.spectrum.source_eigenvectors[orbital, column]
    end
    return mul!(output, left.spectrum.source_eigenvectors_adjoint, frame_rotated_eigenvectors)
end
end

function named_link_allocation(output, left, right, connector, centers, phase, rotated, indices)
    WannierNLQG.MatrixElements.compute_convention_covariant_overlap!(
        output,
        left,
        right,
        connector,
        centers,
        phase,
        rotated;
        output_columns = indices,
    )
    return @allocated WannierNLQG.MatrixElements.compute_convention_covariant_overlap!(
        output,
        left,
        right,
        connector,
        centers,
        phase,
        rotated;
        output_columns = indices,
    )
end
@testset "Shifted closed-group convention link column spans" begin
    comparison_audit = PanelGemmComparisonSupport.PanelComparisonAudit()
    E=WannierNLQG.MatrixElements;
    C=WannierNLQG.Core;
    rng=MersenneTwister(243)
    bits(a)=reinterpret(UInt64, vec(a))
    for n in (64, 128, 132, 516)
        plan=E.compile_matrix_plan(E.MatrixElementRequest(E.SPECTRUM; spatial_dimension = 2))
        left=E.GeometricLoopMatrixData(E.KPointMatrixData(n, 0, plan));
        right=E.GeometricLoopMatrixData(E.KPointMatrixData(n, 0, plan))
        for convention in (C.CONVENTION_I, C.CONVENTION_II)
            connector=E.make_convention_frame_connector(convention)
            for mode in (:dense, :zero_centers, :signedzero, :nonfinite)
                left.common.kpoint .= [0.17, 0.29, 0.0];
                right.common.kpoint .= [0.23, 0.11, 0.0]
                left.spectrum.source_eigenvectors_adjoint .= randn(rng, ComplexF64, n, n)
                left.spectrum.source_eigenvectors .= randn(rng, ComplexF64, n, n)
                right.spectrum.source_eigenvectors .= randn(rng, ComplexF64, n, n)
                right.spectrum.source_eigenvectors_adjoint .= randn(rng, ComplexF64, n, n)
                centers=randn(rng, 3, n)/10
                if mode==:zero_centers
                    ;
                    centers.=0.0
                elseif mode==:signedzero
                    centers .= -0.0;
                    left.spectrum.source_eigenvectors_adjoint[1:7:end].=ComplexF64(-0.0, 0.0)
                    right.spectrum.source_eigenvectors[1:7:end].=ComplexF64(0.0, -0.0)
                elseif mode==:nonfinite
                    left.spectrum.source_eigenvectors_adjoint[1, 1]=ComplexF64(Inf, NaN)
                end
                phase=ones(ComplexF64, n);
                rotated=zeros(ComplexF64, n, n);
                expected=zeros(ComplexF64, n, n);
                actual=similar(expected)
                FrozenLink243.compute_convention_covariant_overlap!(
                    expected,
                    left,
                    right,
                    connector,
                    centers,
                    phase,
                    rotated,
                )
                for indices in
                    ([1], [n], [min(n, 256), min(n, 257)], [1, n], collect(1:n), [2, 1], Int[])
                    fill!(actual, ComplexF64(NaN, NaN));
                    fill!(phase, ComplexF64(NaN, NaN));
                    fill!(rotated, ComplexF64(NaN, NaN))
                    E.compute_convention_covariant_overlap!(
                        actual,
                        left,
                        right,
                        connector,
                        centers,
                        phase,
                        rotated;
                        output_columns = indices,
                    )
                    selected=isempty(indices) ? collect(1:n) : indices
                    factor =
                        convention == C.CONVENTION_I ? right.spectrum.source_eigenvectors : rotated
                    if PanelGemmComparisonSupport.link_panel_case(
                        actual,
                        left.spectrum.source_eigenvectors_adjoint,
                        factor,
                        indices,
                    )
                        result = PanelGemmComparisonSupport.compare_link_panels(
                            actual,
                            expected,
                            left.spectrum.source_eigenvectors_adjoint,
                            factor,
                            selected,
                        )
                        @test PanelGemmComparisonSupport.record_comparison!(
                            comparison_audit,
                            result,
                        )
                    else
                        # Default/same-shape fallback retains its exact IEEE contract.
                        @test bits(actual[:, selected])==bits(expected[:, selected])
                    end
                end
                # No-selection public entry remains complete, including nonfinite propagation.
                E.compute_convention_covariant_overlap!(
                    actual,
                    left,
                    right,
                    connector,
                    centers,
                    phase,
                    rotated,
                )
                @test bits(actual)==bits(expected)
                left.common.kpoint .+= [0.001, -0.002, 0.0];
                centers .+= 0.01
                FrozenLink243.compute_convention_covariant_overlap!(
                    expected,
                    right,
                    left,
                    connector,
                    centers,
                    phase,
                    rotated,
                )
                fill!(actual, ComplexF64(NaN, NaN));
                indices=[n]
                E.compute_convention_covariant_overlap!(
                    actual,
                    right,
                    left,
                    connector,
                    centers,
                    phase,
                    rotated;
                    output_columns = indices,
                )
                factor = convention == C.CONVENTION_I ? left.spectrum.source_eigenvectors : rotated
                if PanelGemmComparisonSupport.link_panel_case(
                    actual,
                    right.spectrum.source_eigenvectors_adjoint,
                    factor,
                    indices,
                )
                    result = PanelGemmComparisonSupport.compare_link_panels(
                        actual,
                        expected,
                        right.spectrum.source_eigenvectors_adjoint,
                        factor,
                        indices,
                    )
                    @test PanelGemmComparisonSupport.record_comparison!(comparison_audit, result)
                else
                    @test bits(actual[:, indices])==bits(expected[:, indices])
                end
                if n>=128 && mode!=:nonfinite
                    first_column=64*div(n-1, 64)+1
                    @test all(isnan, real.(actual[:, 1:(first_column - 1)]))
                end
            end
            left.spectrum.source_eigenvectors_adjoint .= randn(rng, ComplexF64, n, n)
            right.spectrum.source_eigenvectors .= randn(rng, ComplexF64, n, n)
            phase=ones(ComplexF64, n);
            rotated=zeros(ComplexF64, n, n);
            out=similar(rotated);
            centers=zeros(3, n)
            if n==516
                for count in (1, 4, 16)
                    indices=collect(257:(256 + count))
                    @test named_link_allocation(
                        out,
                        left,
                        right,
                        connector,
                        centers,
                        phase,
                        rotated,
                        indices,
                    )==0
                end
            end
        end
    end
    println(
        "PANEL_LINK_ERROR_AUDIT ",
        JSON3.write(PanelGemmComparisonSupport.comparison_report(comparison_audit)),
    )
end
