@testset "Phased full-band overlaps retain original products and call lifetime" begin
    let E=WannierNLQG.MatrixElements, R=WannierNLQG.Responses
        function ordered_overlap_oracle!(
            overlap_1::Matrix{ComplexF64},
            overlap_2::Matrix{ComplexF64},
            valence_data::WannierNLQG.MatrixElements.KPointMatrixData,
            conduction_data::WannierNLQG.MatrixElements.KPointMatrixData,
            valence_kpoint::Vector{Float64},
            conduction_kpoint::Vector{Float64},
            wannier_centers_fractional::Matrix{Float64},
            explicit_center_phase_enabled::Bool,
            num_orbitals::Int64,
        )
            fill!(overlap_1, ComplexF64(0.0, 0.0))
            fill!(overlap_2, ComplexF64(0.0, 0.0))
            valence_to_conduction_delta_k = valence_kpoint .- conduction_kpoint
            conduction_to_valence_delta_k = conduction_kpoint .- valence_kpoint
            @inbounds for n in 1:num_orbitals
                for m in 1:num_orbitals
                    valence_to_conduction_overlap = ComplexF64(0.0, 0.0)
                    conduction_to_valence_overlap = ComplexF64(0.0, 0.0)
                    for l in 1:num_orbitals
                        if explicit_center_phase_enabled
                            phase12 =
                                valence_to_conduction_delta_k[1] *
                                wannier_centers_fractional[1, l] +
                                valence_to_conduction_delta_k[2] *
                                wannier_centers_fractional[2, l] +
                                valence_to_conduction_delta_k[3] * wannier_centers_fractional[3, l]
                            phase21 =
                                conduction_to_valence_delta_k[1] *
                                wannier_centers_fractional[1, l] +
                                conduction_to_valence_delta_k[2] *
                                wannier_centers_fractional[2, l] +
                                conduction_to_valence_delta_k[3] * wannier_centers_fractional[3, l]
                            valence_to_conduction_overlap +=
                                cis(2.0 * pi * phase12) *
                                valence_data.spectrum.source_eigenvectors_adjoint[n, l] *
                                conduction_data.spectrum.source_eigenvectors[l, m]
                            conduction_to_valence_overlap +=
                                cis(2.0 * pi * phase21) *
                                conduction_data.spectrum.source_eigenvectors_adjoint[n, l] *
                                valence_data.spectrum.source_eigenvectors[l, m]
                        else
                            valence_to_conduction_overlap +=
                                valence_data.spectrum.source_eigenvectors_adjoint[n, l] *
                                conduction_data.spectrum.source_eigenvectors[l, m]
                            conduction_to_valence_overlap +=
                                conduction_data.spectrum.source_eigenvectors_adjoint[n, l] *
                                valence_data.spectrum.source_eigenvectors[l, m]
                        end
                    end
                    overlap_1[n, m] = valence_to_conduction_overlap
                    overlap_2[n, m] = conduction_to_valence_overlap
                end
            end
            return nothing
        end
        function typed_phase_allocations(
            output_1,
            output_2,
            valence,
            conduction,
            kv,
            kc,
            centers,
            n,
            phase_1,
            phase_2,
        )
            WannierNLQG.Responses.photon_drag_compute_overlaps!(
                output_1,
                output_2,
                valence,
                conduction,
                kv,
                kc,
                centers,
                true,
                n;
                phase_scratch_1 = phase_1,
                phase_scratch_2 = phase_2,
            )
            return @allocated WannierNLQG.Responses.photon_drag_compute_overlaps!(
                output_1,
                output_2,
                valence,
                conduction,
                kv,
                kc,
                centers,
                true,
                n;
                phase_scratch_1 = phase_1,
                phase_scratch_2 = phase_2,
            )
        end
        rng=MersenneTwister(236)
        bits(a)=reinterpret(UInt64, vec(a))
        for n in (1, 4, 63, 64, 65, 66, 67, 129)
            plan=E.compile_matrix_plan(E.MatrixElementRequest(E.SPECTRUM; spatial_dimension = 2))
            valence=E.KPointMatrixData(n, 0, plan);
            conduction=E.KPointMatrixData(n, 0, plan)
            originals=[randn(rng, ComplexF64, n, n) for _ in 1:4]
            frames=(
                valence.spectrum.source_eigenvectors,
                valence.spectrum.source_eigenvectors_adjoint,
                conduction.spectrum.source_eigenvectors,
                conduction.spectrum.source_eigenvectors_adjoint,
            )
            expected_1=zeros(ComplexF64, n, n);
            expected_2=similar(expected_1)
            actual_1=similar(expected_1);
            actual_2=similar(expected_1)
            phase_1=fill(ComplexF64(NaN), n, n);
            phase_2=similar(phase_1)
            centers=randn(rng, 3, n)*0.1;
            kv=[0.001, -0.002, 0.003];
            kc=[-0.003, 0.004, 0.002]
            for mode in (:dense, :zero, :signed_zero, :tiny, :nonfinite), phased in (false, true)
                for (frame, original) in zip(frames, originals)
                    ;
                    copyto!(frame, original);
                end
                if mode==:zero
                    ;
                    for frame in frames
                        ;
                        fill!(frame, 0);
                    end
                elseif mode==:signed_zero
                    ;
                    for frame in frames
                        ;
                        fill!(frame, ComplexF64(-0.0, -0.0));
                    end
                elseif mode==:tiny
                    ;
                    for frame in frames
                        ;
                        frame .*= 1e-150;
                    end
                elseif mode==:nonfinite
                    frames[1][1, 1]=ComplexF64(NaN, 0.0);
                    frames[2][end, end]=ComplexF64(Inf, 0.0)
                end
                fill!(actual_1, ComplexF64(NaN));
                fill!(actual_2, ComplexF64(NaN))
                ordered_overlap_oracle!(
                    expected_1,
                    expected_2,
                    valence,
                    conduction,
                    kv,
                    kc,
                    centers,
                    phased,
                    n,
                )
                R.photon_drag_compute_overlaps!(
                    actual_1,
                    actual_2,
                    valence,
                    conduction,
                    kv,
                    kc,
                    centers,
                    phased,
                    n;
                    phase_scratch_1 = phase_1,
                    phase_scratch_2 = phase_2,
                )
                @test bits(actual_1)==bits(expected_1)
                @test bits(actual_2)==bits(expected_2)
                new_kv=-kv;
                new_kc=-kc;
                new_centers=centers .* 1.5
                fill!(phase_1, ComplexF64(NaN));
                fill!(phase_2, ComplexF64(NaN))
                ordered_overlap_oracle!(
                    expected_1,
                    expected_2,
                    valence,
                    conduction,
                    new_kv,
                    new_kc,
                    new_centers,
                    phased,
                    n,
                )
                R.photon_drag_compute_overlaps!(
                    actual_1,
                    actual_2,
                    valence,
                    conduction,
                    new_kv,
                    new_kc,
                    new_centers,
                    phased,
                    n;
                    phase_scratch_1 = phase_1,
                    phase_scratch_2 = phase_2,
                )
                @test bits(actual_1)==bits(expected_1)
                @test bits(actual_2)==bits(expected_2)
            end
            if n>=64
                for (frame, original) in zip(frames, originals)
                    ;
                    copyto!(frame, original);
                end
                R.photon_drag_compute_overlaps!(
                    actual_1,
                    actual_2,
                    valence,
                    conduction,
                    kv,
                    kc,
                    centers,
                    true,
                    n;
                    phase_scratch_1 = phase_1,
                    phase_scratch_2 = phase_2,
                )
                raw_capture=@allocated R.photon_drag_compute_overlaps!(
                    actual_1,
                    actual_2,
                    valence,
                    conduction,
                    kv,
                    kc,
                    centers,
                    true,
                    n;
                    phase_scratch_1 = phase_1,
                    phase_scratch_2 = phase_2,
                )
                production_alloc=typed_phase_allocations(
                    actual_1,
                    actual_2,
                    valence,
                    conduction,
                    kv,
                    kc,
                    centers,
                    n,
                    phase_1,
                    phase_2,
                )
                println(
                    "PHASE_ALLOCATION_CONTEXT_N=",
                    n,
                    " raw_capture=",
                    raw_capture,
                    " typed=",
                    production_alloc,
                )
                @test production_alloc==0
                ordered_overlap_oracle!(
                    expected_1,
                    expected_2,
                    valence,
                    conduction,
                    kv,
                    kc,
                    centers,
                    true,
                    n,
                )
                R.photon_drag_compute_overlaps!(
                    actual_1,
                    actual_2,
                    valence,
                    conduction,
                    kv,
                    kc,
                    centers,
                    true,
                    n;
                    phase_scratch_1 = phase_1,
                    phase_scratch_2 = phase_1,
                )
                @test bits(actual_1)==bits(expected_1) && bits(actual_2)==bits(expected_2)
                R.photon_drag_compute_overlaps!(
                    actual_1,
                    actual_2,
                    valence,
                    conduction,
                    kv,
                    kc,
                    centers,
                    true,
                    n;
                    phase_scratch_1 = valence.spectrum.source_eigenvectors,
                    phase_scratch_2 = phase_2,
                )
                @test bits(actual_1)==bits(expected_1) && bits(actual_2)==bits(expected_2)
                # Shared destinations and frame aliases retain the original fallback behavior.
                expected=similar(actual_1);
                actual=similar(actual_1)
                ordered_overlap_oracle!(
                    expected,
                    expected,
                    valence,
                    conduction,
                    kv,
                    kc,
                    centers,
                    true,
                    n,
                )
                R.photon_drag_compute_overlaps!(
                    actual,
                    actual,
                    valence,
                    conduction,
                    kv,
                    kc,
                    centers,
                    true,
                    n;
                    phase_scratch_1 = phase_1,
                    phase_scratch_2 = phase_2,
                )
                @test bits(actual)==bits(expected)
                vd=deepcopy(valence);
                cd=deepcopy(conduction);
                vref=deepcopy(valence);
                cref=deepcopy(conduction)
                ordered_overlap_oracle!(
                    vref.spectrum.source_eigenvectors,
                    expected_2,
                    vref,
                    cref,
                    kv,
                    kc,
                    centers,
                    true,
                    n,
                )
                R.photon_drag_compute_overlaps!(
                    vd.spectrum.source_eigenvectors,
                    actual_2,
                    vd,
                    cd,
                    kv,
                    kc,
                    centers,
                    true,
                    n;
                    phase_scratch_1 = phase_1,
                    phase_scratch_2 = phase_2,
                )
                @test bits(vd.spectrum.source_eigenvectors)==bits(vref.spectrum.source_eigenvectors)
                @test bits(actual_2)==bits(expected_2)
                for geometry in (zeros(3, n), fill(-0.0, 3, n))
                    fill!(phase_1, ComplexF64(NaN));
                    fill!(phase_2, ComplexF64(NaN))
                    ordered_overlap_oracle!(
                        expected_1,
                        expected_2,
                        valence,
                        conduction,
                        kv,
                        kc,
                        geometry,
                        true,
                        n,
                    )
                    R.photon_drag_compute_overlaps!(
                        actual_1,
                        actual_2,
                        valence,
                        conduction,
                        kv,
                        kc,
                        geometry,
                        true,
                        n;
                        phase_scratch_1 = phase_1,
                        phase_scratch_2 = phase_2,
                    )
                    @test bits(actual_1)==bits(expected_1)
                    @test bits(actual_2)==bits(expected_2)
                end
            end
        end
    end
end
