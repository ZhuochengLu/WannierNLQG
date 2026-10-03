using Test

# Reduced from response_symmetry_unit.jl's valid POSCAR/INCAR artifact path.
mktempdir() do directory
    poscar = joinpath(directory, "POSCAR.vasp")
    write(
        poscar,
        """two-atom VASP response fixture
1.0
3 0 0
0 3 0
0 0 3
X Y
1 1
Direct
0 0 0
0.5 0.5 0.5
""",
    )
    incar = joinpath(directory, "INCAR")
    write(incar, "LNONCOLLINEAR = T\nLSORBIT = T\nSAXIS = 1 0 0\nMAGMOM = 2*0 1 3*0\n")
    model = joinpath(directory, "model.dat")
    write(model, "VASP response artifact model fixture\n")
    output = joinpath(directory, "response.json")
    result = WannierNLQG.Symmetrization.write_response_symmetry_artifact(
        output;
        structure_file = poscar,
        structure_format = :poscar,
        model_file = model,
        vasp_magnetic_input_file = incar,
    )
    @test result == output
    @test isfile(output)
    payload = JSON3.read(read(output, String), Dict{String, Any})
    @test payload["qualification"]["seal"]["sealed"] == false
    @test payload["provenance"]["model"]["sha256"] == bytes2hex(SHA.sha256(read(model)))
end
