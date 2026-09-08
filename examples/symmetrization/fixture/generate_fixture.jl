#!/usr/bin/env julia

using HDF5
using JSON3
using LinearAlgebra
using SHA
using Spglib
using WannierNLQG

const FIXTURE_ROOT = @__DIR__
const INPUT_ROOT = joinpath(FIXTURE_ROOT, "inputs")
const SEED = joinpath(INPUT_ROOT, "synthetic")

function write_record(io::Base.IO, payload::Vector{UInt8})
    marker = Int32(length(payload))
    write(io, marker)
    write(io, payload)
    write(io, marker)
    return nothing
end

function write_record(io::Base.IO, values::AbstractVector{T}) where {T}
    write_record(io, collect(reinterpret(UInt8, collect(values))))
    return nothing
end

function write_synthetic_chk(path::AbstractString, stencil)
    real_lattice = Matrix{Float64}(I, 3, 3)
    reciprocal_lattice = 2.0pi * real_lattice
    open(path, "w") do io
        write_record(io, Vector{UInt8}(codeunits("WannierNLQG synthetic validation fixture")))
        write_record(io, Int32[1])
        write_record(io, Int32[0])
        write_record(io, Int32[])
        write_record(io, vec(real_lattice))
        write_record(io, vec(reciprocal_lattice))
        write_record(io, Int32[1])
        write_record(io, Int32[1, 1, 1])
        write_record(io, Float64[0.0, 0.0, 0.0])
        write_record(io, Int32[length(stencil.weights)])
        write_record(io, Int32[1])
        write_record(io, Vector{UInt8}(codeunits("synthetic checkpoint")))
        write_record(io, Int32[0])
        write_record(io, ComplexF64[1.0 + 0.0im])
        write_record(io, zeros(ComplexF64, length(stencil.weights)))
        write_record(io, zeros(Float64, 3))
        write_record(io, Float64[0.0])
    end
    return path
end

function write_synthetic_spn(path::AbstractString)
    open(path, "w") do io
        write_record(io, Vector{UInt8}(codeunits("WannierNLQG synthetic validation fixture")))
        write_record(io, Int32[1, 1])
        write_record(io, ComplexF64[0.1, 0.2, 0.3])
    end
    return path
end

function write_synthetic_mmn(path::AbstractString, stencil)
    open(path, "w") do io
        println(io, "WannierNLQG synthetic validation fixture")
        println(io, "1 1 $(length(stencil.weights))")
        for neighbour in eachindex(stencil.weights)
            shift = @view stencil.reciprocal_shifts[:, neighbour, 1]
            println(io, "1 1 $(shift[1]) $(shift[2]) $(shift[3])")
            println(io, "1.0 0.0")
        end
    end
    return path
end

function file_sha256(path::AbstractString)
    return open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end
end

mkpath(INPUT_ROOT)
write(
    SEED * ".win",
    """
    num_wann = 1
    num_bands = 1
    spinors = false
    mp_grid = 1 1 1

    begin unit_cell_cart
    ang
    1.0 0.0 0.0
    0.0 1.0 0.0
    0.0 0.0 1.0
    end unit_cell_cart

    begin atoms_frac
    X 0.0 0.0 0.0
    end atoms_frac

    begin projections
    X:s
    end projections
    """,
)

checkpoint = WannierNLQG.IO.WannierCHK(
    1,
    1,
    1,
    (1, 1, 1),
    zeros(1, 3),
    Matrix{Float64}(I, 3, 3),
    2.0pi * Matrix{Float64}(I, 3, 3),
    zeros(1, 3),
    ones(ComplexF64, 1, 1, 1),
)
stencil = WannierNLQG.MatrixElements.build_finite_difference_stencil(checkpoint)

extension = Base.get_extension(WannierNLQG, :WannierNLQGSymmetrizationExt)
extension === nothing && error("symmetrization extension failed to activate")
model = WannierNLQG.Core.TightBindingModel(
    Matrix{Float64}(I, 3, 3),
    1,
    1,
    [1],
    zeros(Int, 3, 1),
    reshape(ComplexF64[0.5], 1, 1, 1),
    zeros(ComplexF64, 1, 1, 3, 1),
)
extension.write_wannier_tb(
    SEED * "_tb.dat",
    model;
    comment = "WannierNLQG synthetic validation fixture",
    overwrite = true,
)
write_synthetic_chk(SEED * ".chk", stencil)
write(SEED * ".eig", "1 1 0.5\n")
write_synthetic_mmn(SEED * ".mmn", stencil)
write_synthetic_spn(SEED * ".spn")

names = (
    "synthetic.win",
    "synthetic_tb.dat",
    "synthetic.chk",
    "synthetic.eig",
    "synthetic.mmn",
    "synthetic.spn",
)
open(joinpath(FIXTURE_ROOT, "SHA256SUMS"), "w") do io
    for name in names
        println(io, file_sha256(joinpath(INPUT_ROOT, name)), "  inputs/", name)
    end
end
println("generated $(length(names)) synthetic fixture files in $(INPUT_ROOT)")
