const FB = ESKernel.FFTBuffers

# An independent unnormalized one-axis discrete transform for small analytic fixtures.
function direct_axis_transform(values, inverse)
    n, columns=size(values)
    sign = inverse ? 1 : -1
    ComplexF64[
        sum(values[j, c]*cis(sign*2pi*(j-1)*(k-1)/n) for j in 1:n) for k in 1:n, c in 1:columns
    ]
end

@testset "Borrowed local FFT buffers" begin
    original = ComplexF64[complex(i+2j, i-j) for i in 1:5, j in 1:3]
    for execution in (Val(:mul), Val(:multiply)), direction in (:forward, :backward)
        buffer = copy(original)
        workspace=FB.LocalComplexFFTPlan(buffer, (1,); direction, num_threads = 1, execution)
        result=FB.execute_fft!(workspace)
        @test result === buffer
        @test buffer ≈ direct_axis_transform(original, direction===:backward) atol=2e-12
        @test FB.buffer_bytes(workspace) == 5*3*sizeof(ComplexF64)
        # Repeated calls overwrite the same borrowed storage, with no stale input.
        fill!(buffer, 0)
        buffer[1, :] .= 1
        @test FB.execute_fft!(workspace) == ones(ComplexF64, 5, 3)
    end

    # The full transform normalization is owned explicitly by the caller.
    buffer=reshape(ComplexF64.(1:24), (3, 4, 2))
    saved=copy(buffer)
    forward=FB.LocalComplexFFTPlan(buffer, (1, 2, 3); direction = :forward, num_threads = 1)
    backward=FB.LocalComplexFFTPlan(buffer, (1, 2, 3); direction = :backward, num_threads = 1)
    FB.execute_fft!(forward);
    FB.execute_fft!(backward)
    @test buffer ≈ length(buffer) .* saved atol=1e-11

    # Preserve both native invocation forms exactly for the same planned layout.
    for execution in (Val(:mul), Val(:multiply))
        baseline=copy(saved);
        candidate=copy(saved)
        native=FFTW.plan_bfft!(baseline, (1, 2, 3); flags = FFTW.ESTIMATE, num_threads = 1)
        shared=FB.LocalComplexFFTPlan(
            candidate,
            (1, 2, 3);
            direction = :backward,
            flags = FFTW.ESTIMATE,
            num_threads = 1,
            execution,
        )
        execution===Val(:mul) ? mul!(baseline, native, baseline) : native*baseline
        @test FB.execute_fft!(shared) == baseline
    end

    empty_owner=zeros(ComplexF64, 5, 0)
    empty_plan=FB.LocalComplexFFTPlan(empty_owner, (1,); direction = :forward, num_threads = 1)
    @test empty_plan.plan === nothing
    @test FB.execute_fft!(empty_plan) === empty_owner
    @test FB.buffer_bytes(empty_plan) == 0
    @test_throws ArgumentError FB.LocalComplexFFTPlan(copy(saved), (1, 1); direction = :forward)
    @test_throws ArgumentError FB.LocalComplexFFTPlan(copy(saved), (4,); direction = :forward)
    @test_throws ArgumentError FB.LocalComplexFFTPlan(copy(saved), (1,); direction = :inverse)
    @test_throws ArgumentError FB.LocalComplexFFTPlan(
        copy(saved),
        (1,);
        direction = :forward,
        num_threads = 0,
    )
end
