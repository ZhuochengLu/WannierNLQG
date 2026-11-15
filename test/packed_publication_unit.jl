module PackedPublicationUnit
using Test, WannierNLQG, HDF5, LinearAlgebra
const DataIO=WannierNLQG.IO
const C=WannierNLQG.Core
include("OperatorBundleTestSupport.jl")
@testset "Mathematical model publication is atomic, current-only and receipt-free" begin
    mktempdir() do directory
        tb=joinpath(directory, "source.dat")
        source=joinpath(@__DIR__, "..", "examples/fixtures/synthetic_runtime/synthetic_tb.dat")
        cp(source, tb)
        model=DataIO.read_wannier_tb(tb)
        ops=Dict(
            C.REAL_SPACE_HAMILTONIAN=>C.RealSpaceOperator(
                C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
                model.r_vectors,
                model.hamiltonian_r,
            ),
            C.REAL_SPACE_POSITION=>C.RealSpaceOperator(
                C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_POSITION, 1, -1, 1),
                model.r_vectors,
                model.position_r,
            ),
        )
        geometry=test_operator_bundle_geometry(model.lattice, model.r_degeneracies, ops)
        path=joinpath(directory, "model.h5")
        DataIO.write_real_space_operator_bundle(
            path,
            model.lattice,
            model.r_degeneracies,
            ops;
            geometry,
        )
        @test !isfile(path*".commit.toml")
        @test DataIO.read_real_space_operator_bundle_manifest(path).schema_version=="3.0"
        HDF5.h5open(path, "r") do h
            @test !haskey(h, "paired_tb_source")
            @test !haskey(attributes(h), "publication_identity")
        end
        @test_throws ArgumentError DataIO.write_real_space_operator_bundle(
            path,
            model.lattice,
            model.r_degeneracies,
            ops;
            geometry,
        )
        source_values=read(tb)
        @test_throws ArgumentError DataIO.write_real_space_operator_bundle(
            tb,
            model.lattice,
            model.r_degeneracies,
            ops;
            geometry,
            paired_tb_file = tb,
            overwrite = true,
        )
        @test read(tb)==source_values
        write(path*".commit.toml", "not a receipt")
        for copied in (path, joinpath(directory, "copy.h5"))
            copied==path || cp(path, copied)
            actual=DataIO.read_real_space_operator_bundle(copied)
            @test actual.lattice==model.lattice && actual.degeneracies==model.r_degeneracies
            @test actual.operators[C.REAL_SPACE_HAMILTONIAN].data==model.hamiltonian_r
            @test actual.operators[C.REAL_SPACE_POSITION].data==model.position_r
            DataIO.adopt_real_space_operator_bundle(copied)
            @test !isfile(copied*".commit.toml") ||
                  read(copied*".commit.toml", String)=="not a receipt"
        end
        for bad in (:offset, :nonfinite)
            target=joinpath(directory, "bad-$bad.h5");
            cp(path, target)
            HDF5.h5open(target, "r+") do h
                bad==:offset ? (h["index/offset_elements"][1]=UInt64(1)) :
                (h["payload/complex128"][1]=ComplexF64(NaN))
            end
            # A manifest checks index/definitions; actual payload readers reject NaN.
            if bad==:offset
                @test_throws ArgumentError DataIO.read_real_space_operator_bundle_manifest(target)
            end
            @test_throws ArgumentError DataIO.read_real_space_operator_bundle(target)
        end
    end
end
end
