using MPI, JSON3, SHA, Test
@test !MPI.Initialized() && !MPI.Finalized()
output = only(ARGS)
rows = Any[]
for dependency in (:HDF5, :Spglib, :EzXML)
    Core.eval(Main, Expr(:using, Expr(:., dependency)))
    counts = Dict{String, Int}()
    for (label, flag) in (
        ("file", HDF5.API.H5F_OBJ_FILE),
        ("dataset", HDF5.API.H5F_OBJ_DATASET),
        ("group", HDF5.API.H5F_OBJ_GROUP),
        ("datatype", HDF5.API.H5F_OBJ_DATATYPE),
        ("attribute", HDF5.API.H5F_OBJ_ATTR),
    )
        counts[label] = Base.invokelatest(HDF5.API.h5f_get_obj_count, HDF5.API.H5F_OBJ_ALL, flag)
    end
    @test counts["file"] == counts["dataset"] == counts["group"] == counts["attribute"] == 0
    @test !isdefined(Main, :WannierNLQG)
    push!(rows, (imported = string(dependency), counts = counts))
end
write(
    joinpath(output, "baseline.json"),
    JSON3.write((package_loaded = false, julia = string(VERSION), rows = rows)),
)
println("DEPENDENCY_ONLY_HDF5_OBJECT_COUNTS_CAPTURED")
