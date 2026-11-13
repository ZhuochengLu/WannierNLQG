module FFTBuffers

using FFTW, LinearAlgebra

export LocalComplexFFTPlan, execute_fft!, buffer_bytes

"""One concrete local FFT plan borrowing one exact contiguous ComplexF64 buffer.

The buffer and plan are worker-owned and non-reentrant. Axes, direction and
execution dispatch are fixed during cold construction. Both directions are
unnormalized; no grid interpretation, redistribution or physical factor enters.
An empty owner retains its buffer and has plan=nothing. Native FFTW storage is
additional to the counted Julia buffer bytes. No MPI or global setting is owned.
"""
struct LocalComplexFFTPlan{A, P, X, E}
    buffer::A
    plan::P
    axes::X
    direction::Symbol
    execution::E
end

"""Bind an FFTW ESTIMATE plan to the given local buffer without changing global threads.

direction=:forward uses plan_fft!, :backward uses unnormalized plan_bfft!.
num_threads=nothing preserves FFTW's existing default; an explicit positive
integer is passed only to this plan. execution=Val(:multiply) preserves plan*A;
Val(:mul) preserves mul!(A,plan,A). The caller owns data initialization and
must not resize the array or share its workspace between simultaneous calls.
"""
function LocalComplexFFTPlan(
    buffer::Array{ComplexF64, N},
    axes::Tuple;
    direction::Symbol,
    flags = FFTW.ESTIMATE,
    num_threads = nothing,
    execution::Union{Val{:multiply}, Val{:mul}} = Val(:mul),
) where {N}
    !isempty(axes) &&
    length(unique(axes))==length(axes) &&
    all(a->a isa Integer && !(a isa Bool) && 1<=a<=N, axes) ||
        throw(ArgumentError("Distinct valid FFT axes required"))
    direction in (:forward, :backward) || throw(ArgumentError("Unknown FFT direction"))
    isnothing(num_threads) ||
        (num_threads isa Integer && !(num_threads isa Bool) && num_threads>0) ||
        throw(ArgumentError("Positive plan-local FFT thread count required"))
    plan = if isempty(buffer)
        nothing
    elseif direction === :forward
        isnothing(num_threads) ? FFTW.plan_fft!(buffer, axes; flags) :
        FFTW.plan_fft!(buffer, axes; flags, num_threads)
    else
        isnothing(num_threads) ? FFTW.plan_bfft!(buffer, axes; flags) :
        FFTW.plan_bfft!(buffer, axes; flags, num_threads)
    end
    LocalComplexFFTPlan(buffer, plan, axes, direction, execution)
end

"""Return counted Julia buffer bytes, excluding unknown native plan memory."""
buffer_bytes(workspace::LocalComplexFFTPlan) = sizeof(workspace.buffer)

"""Execute the original in-place mul! form on this workspace's exact borrowed buffer."""
function execute_fft!(workspace::LocalComplexFFTPlan{A, P, X, Val{:mul}}) where {A, P, X}
    isnothing(workspace.plan) || mul!(workspace.buffer, workspace.plan, workspace.buffer)
    workspace.buffer
end

"""Execute the original in-place plan*buffer form on this exact borrowed buffer."""
function execute_fft!(workspace::LocalComplexFFTPlan{A, P, X, Val{:multiply}}) where {A, P, X}
    isnothing(workspace.plan) || workspace.plan * workspace.buffer
    workspace.buffer
end

end
