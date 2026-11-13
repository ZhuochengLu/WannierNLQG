import MPI
const BUILD_HDF5_MPI_PRESENT = Base.get_extension(HDF5, :MPIExt)!==nothing
using PrecompileTools: @setup_workload, @compile_workload

# Exercise the immutable shipped micro fixture through the current mathematical reader.
@setup_workload let
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        fixture = normpath(
            joinpath(
                @__DIR__,
                "..",
                "..",
                "examples",
                "fixtures",
                "synthetic_runtime",
                "synthetic_operators.h5",
            ),
        )
        workspace = mktempdir()
        try
            @compile_workload begin
                adopt_real_space_operator_bundle(fixture)
                manifest = read_real_space_operator_bundle_manifest(fixture)
                read_real_space_operator_bundle(fixture)
                requested = Dict{RealSpaceOperatorKind, Vector{NTuple{2, Int8}}}()
                for entry in manifest.entries
                    push!(
                        get!(() -> NTuple{2, Int8}[], requested, entry.kind),
                        entry.component_indices,
                    )
                end
                read_operator_bundle_components(fixture, requested; prefer_mmap = false)
                # The mapped arrays remain local to this workload; no handle or mapping is stored globally.
                read_operator_bundle_components(fixture, requested; prefer_mmap = true)
            end
        finally
            rm(workspace; recursive = true)
        end
    end
end
# Portable signatures above use the current public interfaces.
# Historical compiler captures below await same-source 1.2 qualification.
