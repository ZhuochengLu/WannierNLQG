using WannierNLQG, JSON3
import MPI

source = realpath(only(ARGS))
@assert realpath(Base.pkgdir(WannierNLQG)) == source
@assert Threads.nthreads() == 1 && !MPI.Initialized()
include(joinpath(source, "examples", "ExampleSupport.jl"))
@assert Base.get_extension(WannierNLQG, :WannierNLQGOperatorBundleExt) === nothing
@assert isfile(ExampleSupport.synthetic_model_file())
@assert isfile(ExampleSupport.synthetic_wsvec_file())
@assert Base.get_extension(WannierNLQG, :WannierNLQGOperatorBundleExt) === nothing

const DataIO = WannierNLQG.IO
original = ExampleSupport.SYNTHETIC_OPERATOR_BUNDLE_FILE
before = DataIO.scientific_file_state(original)
@assert !isfile(original * ".commit.toml")
copied = ExampleSupport.synthetic_operator_bundle_file()
@assert copied != original
@assert isfile(copied * ".commit.toml")
copy_data = DataIO.read_real_space_operator_bundle(copied)
source_data = ExampleSupport.with_synthetic_operator_bundle() do
    DataIO.read_real_space_operator_bundle(original)
end
@assert Set(keys(copy_data.operators)) == Set(keys(source_data.operators))
@assert copy_data.lattice == source_data.lattice
@assert copy_data.degeneracies == source_data.degeneracies
@assert all(keys(copy_data.operators)) do kind
    left, right = copy_data.operators[kind], source_data.operators[kind]
    left.r_vectors == right.r_vectors &&
        size(left.data) == size(right.data) &&
        reinterpret(UInt8, vec(left.data)) == reinterpret(UInt8, vec(right.data))
end
callback_error = try
    ExampleSupport.with_synthetic_operator_bundle() do
        error("fixture callback failure")
    end
    nothing
catch exception
    exception
end
@assert callback_error isa ErrorException
@assert get(task_local_storage(), :wannier_scientific_publication_receipts, nothing) === nothing
outside_error = try
    DataIO.read_real_space_operator_bundle_manifest(original)
    nothing
catch exception
    exception
end
@assert outside_error isa ArgumentError
@assert DataIO.scientific_file_state(original) == before
@assert !isfile(original * ".commit.toml")
@assert !MPI.Initialized()
JSON3.write(
    stdout,
    (;
        source_root = source,
        threads = Threads.nthreads(),
        mpi_initialized = MPI.Initialized(),
        tb_only_kept_packed_extension_inactive = true,
        owned_copy_and_private_receipt = true,
        all_operator_bytes_equal = true,
        original_source_unchanged = true,
        scope_restored_after_error = true,
    ),
)
println()
