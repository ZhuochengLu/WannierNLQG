import MPI
const BUILD_HDF5_MPI_PRESENT = Base.get_extension(HDF5, :MPIExt)!==nothing
using PrecompileTools: @compile_workload

# Exercise only the shipped read-only micro fixture. No MPI, writes, or persistent handles.
@compile_workload let
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
        manifest = read_real_space_operator_bundle_manifest(fixture)
        read_real_space_operator_bundle(fixture)
        requested = Dict{RealSpaceOperatorKind, Vector{NTuple{2, Int8}}}()
        for entry in manifest.entries
            push!(get!(() -> NTuple{2, Int8}[], requested, entry.kind), entry.component_indices)
        end
        read_operator_bundle_components(fixture, requested; prefer_mmap = false)
        # The mapped arrays remain local to this workload; no handle or mapping is stored globally.
        read_operator_bundle_components(fixture, requested; prefer_mmap = true)
    end
end
# Generated from actual first run(cfg), effective nonzero Pauli input, MPI root.
# Julia 1.11.2; parent source: f96005337864e6e95656ead666fe9210cab0d0c0b7abd7bd7d3b3ce36feccd18
# Trace SHA256: de6061d42c9213b334adc7e828940240023d27ae160dd5d73ccd874ef71964a1
# Compilation only; no I/O, MPI initialization, task execution, or global runtime state.

# Foreign HDF5 entries require a package-owned inference backedge.
function _operator_bundle_first_use_call(function_value::F, arguments::Vararg{Any, N}) where {F, N}
    return Base.@noinline function_value(arguments...)
end
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        precompile(
            Tuple{
                typeof(HDF5._generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{51, 0}},
                Nothing,
            },
        )
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5._generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{51, 0}},
                Nothing,
            },
        )
        precompile(
            Tuple{
                typeof(HDF5._generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{17, 0}},
                Nothing,
            },
        )
        precompile(
            Tuple{
                typeof(_operator_bundle_first_use_call),
                typeof(HDF5._generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{17, 0}},
                Nothing,
            },
        )
        @assert !MPI.Initialized()
    end
end

include("TBQualificationReaderCoverage.jl")
