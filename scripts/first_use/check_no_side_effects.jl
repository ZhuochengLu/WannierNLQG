using SHA, JSON3, Test
root = normpath(joinpath(@__DIR__, "..", ".."))
length(ARGS) <= 1 || error("usage: check_no_side_effects.jl [fresh_evidence_directory]")
output =
    isempty(ARGS) ? mktempdir(; prefix = "nlqg-import-evidence-", cleanup = false) :
    abspath(only(ARGS))
if !isempty(ARGS)
    ispath(output) && error("side-effect evidence directory must be fresh")
    mkdir(output)
end
control_directory = joinpath(output, "dependency_control")
mkdir(control_directory)
control_script = joinpath(@__DIR__, "capture_dependency_handles.jl")
run(
    `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$root $control_script $control_directory`,
)
control = joinpath(control_directory, "baseline.json")
const BASELINE = JSON3.read(read(control, String))
@test !BASELINE.package_loaded && BASELINE.julia == string(VERSION)
function content_inventory(directory)
    result = Dict{String, String}()
    for (parent, directories, files) in walkdir(directory)
        filter!(x -> x != ".git", directories)
        for name in files
            path = joinpath(parent, name)
            islink(path) && error("SIDE_EFFECT_CHECK_SYMLINK_UNSUPPORTED")
            result[relpath(path, directory)] = bytes2hex(open(sha256, path))
        end
    end
    return result
end
const BEFORE = content_inventory(root)
isolated_cwd = joinpath(output, "isolated_cwd")
mkdir(isolated_cwd)
cd(isolated_cwd) do
    using_time = time_ns()
    Core.eval(Main, :(using MPI))
    @test !Base.invokelatest(MPI.Initialized) && !Base.invokelatest(MPI.Finalized)
    Core.eval(Main, :(using WannierNLQG))
    @test samefile(pkgdir(WannierNLQG), root)
    @test !Base.invokelatest(MPI.Initialized) && !Base.invokelatest(MPI.Finalized)
    owners = (
        WannierNLQG,
        WannierNLQG.Wannierization,
        WannierNLQG.SymmetryFoundation,
        WannierNLQG.Symmetrization,
    )
    public_before = Dict(string(m) => string.(names(m)) for m in owners)
    states = Any[]
    for dependency in (:HDF5, :Spglib, :EzXML)
        Core.eval(Main, Expr(:using, Expr(:., dependency)))
        @test !Base.invokelatest(MPI.Initialized) && !Base.invokelatest(MPI.Finalized)
        @test isempty(readdir(isolated_cwd))
        @test content_inventory(root) == BEFORE
        @test Dict(string(m) => string.(names(m)) for m in owners) == public_before
        count = Base.invokelatest(
            HDF5.API.h5f_get_obj_count,
            HDF5.API.H5F_OBJ_ALL,
            HDF5.API.H5F_OBJ_ALL,
        )
        expected = only(filter(x -> x.imported == string(dependency), BASELINE.rows))
        counts = Dict{String, Int}()
        for (label, flag) in (
            ("file", HDF5.API.H5F_OBJ_FILE),
            ("dataset", HDF5.API.H5F_OBJ_DATASET),
            ("group", HDF5.API.H5F_OBJ_GROUP),
            ("datatype", HDF5.API.H5F_OBJ_DATATYPE),
            ("attribute", HDF5.API.H5F_OBJ_ATTR),
        )
            counts[label] =
                Base.invokelatest(HDF5.API.h5f_get_obj_count, HDF5.API.H5F_OBJ_ALL, flag)
        end
        @test counts == Dict(String(k)=>Int(v) for (k, v) in pairs(expected.counts))
        @test counts["file"] == counts["dataset"] == counts["group"] == counts["attribute"] == 0
        push!(
            states,
            (
                imported = string(dependency),
                mpi_initialized = Base.invokelatest(MPI.Initialized),
                mpi_finalized = Base.invokelatest(MPI.Finalized),
                open_hdf5_objects = count,
                package_file_content_unchanged = true,
                cwd_empty = true,
                public_names_unchanged = true,
                open_hdf5_counts = counts,
            ),
        )
    end
    # Deliberately retain one file briefly: the detector must observe it.
    leaked = Base.invokelatest(HDF5.h5open, joinpath(output, "deliberate_handle_negative.h5"), "w")
    @test Base.invokelatest(
        HDF5.API.h5f_get_obj_count,
        HDF5.API.H5F_OBJ_ALL,
        HDF5.API.H5F_OBJ_FILE,
    ) == 1
    Base.invokelatest(close, leaked)
    @test Base.invokelatest(
        HDF5.API.h5f_get_obj_count,
        HDF5.API.H5F_OBJ_ALL,
        HDF5.API.H5F_OBJ_FILE,
    ) == 0
    write(
        joinpath(output, "qualification.json"),
        JSON3.write((
            states = states,
            source_files = length(BEFORE),
            wall_seconds = (time_ns()-using_time)/1e9,
            base_and_optional_imports = true,
            deliberate_open_file_detected = true,
            deliberate_file_closed = true,
            lifecycle_orders_not_yet_qualified = true,
            build_workload_side_effects_not_yet_qualified = true,
            final_pass = false,
        )),
    )
end
println("IMPORT_FILE_CONTENT_CWD_MPI_HDF5_HANDLES_PUBLIC_NAMES_PASS ", output)
