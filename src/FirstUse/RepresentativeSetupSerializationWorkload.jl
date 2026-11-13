# Cover the public memory codec reached by first MPI setup broadcasts.
# Keep MPI initialization and all real communication in the admitted runtime.
@setup_workload let
    _first_use_require_serial()
    @compile_workload begin
        for value in (
            nothing,
            (ok = true, value = nothing, error = ""),
            (ok = true, value = 0, error = ""),
            (ok = true, value = "", error = ""),
        )
            buffer = Base.IOBuffer()
            Serialization.serialize(buffer, value)
            bytes = Base.take!(buffer)
            @assert !isempty(bytes)
            decoded = Serialization.deserialize(Base.IOBuffer(bytes))
            @assert isequal(decoded, value)
            @assert typeof(decoded) === typeof(value)
        end
        @assert !MPI.Initialized()
    end
end
