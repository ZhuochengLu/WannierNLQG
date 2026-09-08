"""Replace one file only after a complete temporary HDF5 close."""
function atomic_hdf5_write(writer::Function, filename::AbstractString)
    path = abspath(filename)
    mkpath(dirname(path))
    temporary, io = mktemp(dirname(path); cleanup = false)
    close(io)
    completed = false
    try
        writer(temporary)
        mv(temporary, path; force = true)
        completed = true
    finally
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return path
end

"""Write deterministic string dictionaries as sorted attributes."""
function write_string_dictionary(parent, values::Dict{String, String})
    for key in sort!(collect(keys(values)))
        HDF5.attributes(parent)[key] = values[key]
    end
    return nothing
end

"""Read every string attribute from one group."""
function read_string_dictionary(parent)
    output = Dict{String, String}()
    for key in keys(HDF5.attributes(parent))
        output[String(key)] = String(read(HDF5.attributes(parent)[key]))
    end
    return output
end

"""Write common generator metadata outside scientific arrays."""
function write_generation_environment(parent)
    attributes = HDF5.attributes(parent)
    attributes["generated_at_utc"] = string(now(UTC))
    attributes["julia_version"] = string(VERSION)
    attributes["wanniernlqg_version"] = string(Base.pkgversion(WannierNLQG))
    attributes["hdf5_jl_version"] = string(Base.pkgversion(HDF5))
    attributes["ezxml_version"] = string(Base.pkgversion(EzXML))
    attributes["threads"] = Threads.nthreads()
    return nothing
end

"""Read one required HDF5 identity attribute."""
function required_attribute(parent, name::AbstractString)
    haskey(HDF5.attributes(parent), name) ||
        throw(ArgumentError("HDF5 object is missing attribute $(name)"))
    return read(HDF5.attributes(parent)[name])
end

"""Reject retired authority identities before any persisted upgrade path."""
validate_persisted_authority_key(authority::AbstractString) =
    SymmetryFoundation.validate_authoritative_hamiltonian_key(authority)
