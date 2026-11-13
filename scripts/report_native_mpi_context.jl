# Report-only diagnostic under the package LICENSE (GNU GPL version 2).
# Measurement techniques adapted from scripts/check_mpi_context.jl in the local
# v1.1.1 source, SHA256 b884d5867395553eeef510ac7b4bff26a3c0e3437de9312e739a0cea3e9977f2.
# No expected host defaults, MPI initialization, launches, guards or PASS decision.
module NativeMpiContextReport

using MPI, HDF5, JSON3, SHA

struct NativeSymbolInfo
    filename::Ptr{UInt8}
    base::Ptr{Cvoid}
    symbol_name::Ptr{UInt8}
    symbol_address::Ptr{Cvoid}
end

function native_symbol_record(handle, name)
    pointer = MPI.Libdl.dlsym(handle, name)
    info = Ref(NativeSymbolInfo(C_NULL, C_NULL, C_NULL, C_NULL))
    ccall(:dladdr, Cint, (Ptr{Cvoid}, Ref{NativeSymbolInfo}), pointer, info) == 1 ||
        error("unresolved native symbol: " * name)
    return Dict(
        "path" => realpath(unsafe_string(info[].filename)),
        "address" => string(UInt(pointer)),
    )
end

function report_native_context(output, label, source_root)
    isabspath(output) && isabspath(source_root) || error("absolute paths required")
    isdir(dirname(output)) || error("external output parent must exist")
    (ispath(output) || islink(output)) && error("preserve prior report; use a fresh output path")
    source = realpath(source_root)
    helper_root = realpath(joinpath(@__DIR__, ".."))
    source == helper_root || error("report helper and declared source differ")
    first(splitpath(relpath(realpath(dirname(output)), source))) == ".." ||
        error("reports must be outside the source payload")
    manifest = joinpath(source, "SOURCE_MANIFEST.tsv")
    launcher_argv = MPI.mpiexec().exec
    launcher =
        realpath(isabspath(launcher_argv[1]) ? launcher_argv[1] : Sys.which(launcher_argv[1]))
    library = realpath(MPI.Libdl.dlpath(MPI.API.libmpi_handle))
    record = Dict{String, Any}(
        "schema" => "wanniernlqg.native-context-report/1",
        "scope" => "native binding observations; no scientific qualification",
        "context_label" => label,
        "source_root" => source,
        "source_manifest_sha256" => bytes2hex(sha256(read(manifest))),
        "helper_sha256" => bytes2hex(sha256(read(@__FILE__))),
        "julia_version" => string(VERSION),
        "julia_executable" => realpath(first(Base.julia_cmd().exec)),
        "base_julia_argv" => Base.julia_cmd().exec,
        "active_project" => Base.active_project(),
        "load_path" => Base.load_path(),
        "context_environment" => Dict(
            key => get(ENV, key, nothing) for
            key in ("JULIA_LOAD_PATH", "JULIA_DEPOT_PATH", "JULIA_PROJECT", "OPAL_PREFIX")
        ),
        "preferences" =>
            Base.get_preferences(Base.UUID("3da0fdf6-3ccc-4f1b-acd9-58baa6c99267")),
        "binary" => MPI.MPIPreferences.binary,
        "abi" => MPI.MPIPreferences.abi,
        "launcher" => launcher,
        "launcher_argv" => launcher_argv,
        "launcher_sha256" => bytes2hex(sha256(read(launcher))),
        "library" => library,
        "library_sha256" => bytes2hex(sha256(read(library))),
        "library_version" => MPI.Get_library_version(),
        "mpi_initialized" => MPI.Initialized(),
        "rank_environment" => Dict(
            key => get(ENV, key, nothing) for
            key in ("OMPI_COMM_WORLD_RANK", "OMPI_COMM_WORLD_SIZE", "PMIX_RANK")
        ),
        "measurement_errors" => String[],
    )
    try
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
            handles = Dict(
                "mpi" => MPI.API.libmpi_handle,
                "hdf5" => HDF5.API.libhdf5handle[],
                "hdf5_hl" => high_level_handle,
            )
            names = ("MPI_Init", "MPI_Comm_rank", "MPI_File_open")
            record["mpi_symbols"] = Dict(
                kind => Dict(name => native_symbol_record(handle, name) for name in names) for
                (kind, handle) in handles
            )
            loaded = MPI.Libdl.dllist()
            mpi_name = r"^libmpi(?:\.\d+)*(?:\.dylib|\.so(?:\.\d+)*)$"
            record["loaded_mpi_libraries"] =
                sort!(unique(realpath.(filter(path -> occursin(mpi_name, basename(path)), loaded))))
            record["loaded_hdf5_libraries"] = sort!(
                unique(realpath.(filter(path -> startswith(basename(path), "libhdf5"), loaded))),
            )
        finally
            MPI.Libdl.dlclose(high_level_handle)
        end
    catch exception
        exception isa InterruptException && rethrow()
        push!(record["measurement_errors"], sprint(showerror, exception))
    end
    record["opal_prefix_after_imports"] = get(ENV, "OPAL_PREFIX", nothing)
    # Native measurement errors stay in the report; a written report is not PASS.
    open(output, "w") do stream
        write(stream, JSON3.write(record))
    end
    return record
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 3 || error("usage: report_native_mpi_context.jl OUTPUT LABEL SOURCE_ROOT")
    NativeMpiContextReport.report_native_context(ARGS[1], ARGS[2], ARGS[3])
    println("NATIVE_CONTEXT_REPORT_WRITTEN")
end
