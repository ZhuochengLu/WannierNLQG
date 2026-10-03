using MPI, JSON3, SHA
expected = JSON3.read(read(ARGS[1], String))
launcher_argv = MPI.mpiexec().exec
launcher = realpath(isabspath(launcher_argv[1]) ? launcher_argv[1] : Sys.which(launcher_argv[1]))
library = realpath(MPI.API.Libdl.dlpath(MPI.API.libmpi_handle))
record = Dict(
    "load_path"=>Base.load_path(),
    "base_julia_argv"=>Base.julia_cmd().exec,
    "preferences"=>Base.get_preferences(Base.UUID("3da0fdf6-3ccc-4f1b-acd9-58baa6c99267")),
    "binary"=>MPI.MPIPreferences.binary,
    "abi"=>MPI.MPIPreferences.abi,
    "launcher"=>launcher,
    "launcher_argv"=>launcher_argv,
    "launcher_sha256"=>bytes2hex(sha256(read(launcher))),
    "library"=>library,
    "library_sha256"=>bytes2hex(sha256(read(library))),
    "library_version"=>MPI.Get_library_version(),
)
write(ARGS[2], JSON3.write(record))
for key in ("binary", "abi", "launcher", "launcher_sha256", "library", "library_sha256")
    record[key] == expected[key] || error("MPI_CONTEXT_MISMATCH: " * key)
end
length(launcher_argv) == 1 || error("MPI_CONTEXT_MISMATCH: launcher arguments")
all(x->occursin(x, record["library_version"]), expected["library_version_contains"]) ||
    error("MPI_CONTEXT_MISMATCH: version")

# HDF5 can load a second MPI object after the initial MPI preference check.
# Inspect its actual handles; expected host bindings remain external inputs.
using HDF5

struct MpiContextDlInfo
    filename::Ptr{UInt8}
    base::Ptr{Cvoid}
    symbol_name::Ptr{UInt8}
    symbol_address::Ptr{Cvoid}
end

function mpi_context_symbol(handle, name)
    pointer = MPI.Libdl.dlsym(handle, name)
    info = Ref(MpiContextDlInfo(C_NULL, C_NULL, C_NULL, C_NULL))
    ccall(:dladdr, Cint, (Ptr{Cvoid}, Ref{MpiContextDlInfo}), pointer, info) == 1 ||
        error("MPI_CONTEXT_MISMATCH: unresolved symbol")
    return Dict("path"=>realpath(unsafe_string(info[].filename)), "address"=>string(UInt(pointer)))
end

high_level_handle = MPI.Libdl.dlopen(HDF5.API.libhdf5_hl)
try
    record["hdf5"] = realpath(MPI.Libdl.dlpath(HDF5.API.libhdf5handle[]))
    record["hdf5_hl"] = realpath(MPI.Libdl.dlpath(high_level_handle))
    for kind in ("hdf5", "hdf5_hl")
        record[kind * "_sha256"] = bytes2hex(sha256(read(record[kind])))
    end
    record["hdf5_preferences"] =
        Base.get_preferences(Base.UUID("f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f"))
    record["hdf5_parallel"] = HDF5.has_parallel()
    major, minor, patch = Ref{Cuint}(), Ref{Cuint}(), Ref{Cuint}()
    HDF5.API.h5_get_libversion(major, minor, patch)
    record["hdf5_version"] = string(VersionNumber(major[], minor[], patch[]))
    loaded = MPI.Libdl.dllist()
    mpi_name = r"^libmpi(?:\.\d+)*(?:\.dylib|\.so(?:\.\d+)*)$"
    record["loaded_mpi_libraries"] =
        sort!(unique(realpath.(filter(path->occursin(mpi_name, basename(path)), loaded))))
    record["loaded_hdf5_libraries"] =
        sort!(unique(realpath.(filter(path->startswith(basename(path), "libhdf5"), loaded))))
    record["opal_prefix"] = get(ENV, "OPAL_PREFIX", nothing)
    handles = Dict(
        "mpi"=>MPI.API.libmpi_handle,
        "hdf5"=>HDF5.API.libhdf5handle[],
        "hdf5_hl"=>high_level_handle,
    )
    names = ("MPI_Init", "MPI_Comm_rank", "MPI_File_open")
    record["mpi_symbols"] = Dict(
        kind=>Dict(name=>mpi_context_symbol(handle, name) for name in names) for
        (kind, handle) in handles
    )
    write(ARGS[2], JSON3.write(record))
    for key in ("hdf5", "hdf5_sha256", "hdf5_hl", "hdf5_hl_sha256", "hdf5_version")
        record[key] == expected[key] || error("MPI_CONTEXT_MISMATCH: " * key)
    end
    record["hdf5_parallel"] || error("MPI_CONTEXT_MISMATCH: serial HDF5")
    record["loaded_mpi_libraries"] == [library] || error("MPI_CONTEXT_MISMATCH: mixed MPI objects")
    Set(record["loaded_hdf5_libraries"]) == Set([record["hdf5"], record["hdf5_hl"]]) ||
        error("MPI_CONTEXT_MISMATCH: mixed HDF5 objects")
    record["opal_prefix"] === nothing || error("MPI_CONTEXT_MISMATCH: OPAL prefix")
    for symbols in values(record["mpi_symbols"]), name in names
        symbol = symbols[name]
        symbol["path"] == library &&
        symbol["address"] == record["mpi_symbols"]["mpi"][name]["address"] ||
            error("MPI_CONTEXT_MISMATCH: HDF5 MPI symbol binding")
    end
finally
    MPI.Libdl.dlclose(high_level_handle)
end
println("MPI_CONTEXT_MATCH")
