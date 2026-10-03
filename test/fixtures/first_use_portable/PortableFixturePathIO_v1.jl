module PortableFixturePathIO
using Serialization
export FixturePathIO
"""Tool-owned stream; maps declared path strings without altering scientific data."""
struct FixturePathIO{I <: IO} <: IO
    stream::I
    paths::Dict{String, String}
end
Base.unsafe_write(io::FixturePathIO, p::Ptr{UInt8}, n::UInt)=Base.unsafe_write(io.stream, p, n)
Base.unsafe_read(io::FixturePathIO, p::Ptr{UInt8}, n::UInt)=Base.unsafe_read(io.stream, p, n)
Base.write(io::FixturePathIO, value::UInt8)=write(io.stream, value)
Base.read(io::FixturePathIO, ::Type{UInt8})=read(io.stream, UInt8)
Base.eof(io::FixturePathIO)=eof(io.stream)
Base.position(io::FixturePathIO)=position(io.stream)
Base.isopen(io::FixturePathIO)=isopen(io.stream)
Base.isreadable(io::FixturePathIO)=isreadable(io.stream)
Base.iswritable(io::FixturePathIO)=iswritable(io.stream)
Base.flush(io::FixturePathIO)=flush(io.stream)
Base.seek(io::FixturePathIO, p)=seek(io.stream, p)
Base.seekstart(io::FixturePathIO)=seekstart(io.stream)
# Both methods specialize on our own IO type. No existing serializer behavior
# is changed, and the standard serializer handles references and raw arrays.
function Serialization.serialize(s::Serialization.Serializer{<:FixturePathIO}, value::String)
    mapped=get(s.io.paths, value, value)
    return invoke(
        Serialization.serialize,
        Tuple{Serialization.AbstractSerializer, String},
        s,
        mapped,
    )
end
function Serialization.deserialize_string(s::Serialization.Serializer{<:FixturePathIO}, length::Int)
    value=invoke(
        Serialization.deserialize_string,
        Tuple{Serialization.AbstractSerializer, Int},
        s,
        length,
    )
    return get(s.io.paths, value, value)
end
end
