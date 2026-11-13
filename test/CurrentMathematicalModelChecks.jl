module CurrentMathematicalModelChecks
using Test, WannierNLQG, HDF5, LinearAlgebra
const C=WannierNLQG.Core
const IOModel=WannierNLQG.IO
root=mktempdir()
r=zeros(Int, 3, 1);
lat=Matrix{Float64}(I, 3, 3)
h=reshape(ComplexF64[1, 0, 0, 2], 2, 2, 1);
pos=zeros(ComplexF64, 2, 2, 3, 1)
pos[1, 1, 1, 1]=0.25;
pos[2, 2, 2, 1]=0.5
ops=Dict(
    C.REAL_SPACE_HAMILTONIAN=>C.RealSpaceOperator(
        C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
        r,
        h,
    ),
    C.REAL_SPACE_POSITION=>C.RealSpaceOperator(
        C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_POSITION, 1, -1, 1),
        r,
        pos,
    ),
)
geometry=Dict(
    "real_space_replica_policy"=>"input",
    "minimum_distance_materialized"=>false,
    "wannier_center_policy"=>"keep_input",
    "wigner_seitz_tolerance"=>1e-5,
    "wigner_seitz_search_size"=>3,
    "replica_mapping_reference"=>"input_R_support",
    "mp_grid"=>[1, 1, 1],
)
@testset "Current necessary-only HDF5 and exact matrix round trip" begin
    file=joinpath(root, "model.h5")
    IOModel.write_real_space_operator_bundle(
        file,
        lat,
        [1],
        ops;
        profile = :hamiltonian_position,
        geometry,
        overwrite = true,
    )
    @test !isfile(file*".commit.toml")
    h5open(file, "r") do f
        @test Set(
            keys(f),
        )==Set(["model", "payload", "index", "operators", "geometry", "definitions"])
        @test !any(k->occursin("qualification", k)||occursin("sha256", k), keys(attributes(f)))
        @test read(attributes(f)["schema_version"])=="3.0"
    end
    x=IOModel.read_real_space_operator_bundle(file)
    @test x.operators[C.REAL_SPACE_HAMILTONIAN].data==h
    @test x.operators[C.REAL_SPACE_POSITION].data==pos
    @test x.manifest.wannier_centers_cartesian==[0.25 0 0; 0 0.5 0]
    @test x.manifest.production_eligible==false
    @test isempty(x.manifest.operator_qualification["operators"])
    @test_throws ArgumentError IOModel.write_real_space_operator_bundle(
        file,
        lat,
        [1],
        ops;
        profile = :hamiltonian_position,
        geometry,
    )
    wrong=joinpath(root, "legacy.h5")
    h5open(wrong, "w") do f
        attributes(f)["schema"]=IOModel.OPERATOR_BUNDLE_SCHEMA;
        attributes(f)["schema_version"]="1.3"
    end
    @test_throws ArgumentError IOModel.read_real_space_operator_bundle_manifest(wrong)
    broken=copy(ops);
    bad=copy(h)
    broken[C.REAL_SPACE_HAMILTONIAN]=C.RealSpaceOperator(
        C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
        r,
        bad,
    )
    broken[C.REAL_SPACE_HAMILTONIAN].data[1]=NaN
    @test_throws ArgumentError IOModel.write_real_space_operator_bundle(
        joinpath(root, "bad.h5"),
        lat,
        [1],
        broken;
        profile = :hamiltonian_position,
        geometry,
    )
end
println("MODEL_STORAGE_TESTS_COMPLETE")

end
