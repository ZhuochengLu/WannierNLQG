using LinearAlgebra
using MPI
using SHA
using WannierNLQG

const W = WannierNLQG.Wannierization
const S = WannierNLQG.Symmetrization
const IOW = WannierNLQG.IO

MPI.Init()
identity = WannierNLQG.SymmetryFoundation.SymmetryOperation(
    Matrix{Int}(I, 3, 3),
    zeros(3),
    Matrix{Float64}(I, 3, 3),
)
energies = [-1.0 -1.0; 1.0 1.0]
representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
    "1.0",
    :synthetic,
    false,
    Matrix{Float64}(I, 3, 3),
    2.0pi .* Matrix{Float64}(I, 3, 3),
    (2, 1, 1),
    [0.0 0.0 0.0; 0.5 0.0 0.0],
    energies,
    [identity],
    reshape([1, 2], 1, 2),
    zeros(Int, 3, 1, 2),
    reshape(repeat(Matrix{ComplexF64}(I, 2, 2), 1, 1, 2), 2, 2, 1, 2),
    [1 1; 2 2],
    [1, 2],
    [1, 2],
    [1, 1];
    conventions = Dict("fourier" => "H(k)=sum_R exp(+2pi*i*k.R) H(R)"),
    input_sha256 = Dict("fixture" => repeat("0", 64)),
)
data = zeros(ComplexF64, 2, 2, 2, 2)
for kpoint in 1:2, neighbor in 1:2
    data[:, :, neighbor, kpoint] .= ComplexF64[1.0 0.2im; -0.1im 0.8]
end
mmn = IOW.WannierMMN(2, 2, 2, data, [2 1; 1 2], zeros(Int, 3, 2, 2))
frames = [ComplexF64[1.0; 0.0;;], ComplexF64[0.0; 1.0;;]]
z = W._raw_z_field(
    representation,
    mmn,
    [0.4, 0.6],
    [[1, 2], [1, 2]],
    frames,
    :mpi;
    full_bz = true,
    storage_backend = :contiguous,
)
buffer = IOBuffer()
for matrix in z
    write(buffer, reinterpret(UInt8, vec(matrix)))
end
digest = bytes2hex(SHA.sha256(take!(buffer)))
serial = W._raw_z_field(
    representation,
    mmn,
    [0.4, 0.6],
    [[1, 2], [1, 2]],
    frames,
    :serial;
    full_bz = true,
    storage_backend = :legacy_vector,
)
legacy_residual = maximum(maximum(abs, z[kpoint] - serial[kpoint]) for kpoint in eachindex(z))
legacy_residual <= 1.0e-12 ||
    error("MPI raw-Z result differs from the legacy serial oracle: $(legacy_residual)")
if MPI.Comm_rank(MPI.COMM_WORLD) == 0
    println("WANNIERIZATION_RAW_Z_MPI_DIGEST=$(digest)")
    println("WANNIERIZATION_RAW_Z_LEGACY_MAX_ABS=$(legacy_residual)")
end
MPI.Barrier(MPI.COMM_WORLD)
MPI.Finalize()
