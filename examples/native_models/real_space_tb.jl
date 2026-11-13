include(joinpath(@__DIR__, "NativeExampleSupport.jl"))

"""Construct a Rice-Mele hopping model with explicit point-orbital positions."""
function build_model()
    h=zeros(ComplexF64, 2, 2, 3)
    h[:, :, 1]=[0.3 1.0; 1.0 -0.3]
    h[2, 1, 2]=0.7
    h[:, :, 3]=h[:, :, 2]'
    return RealSpaceTBInput(
        lattice = Matrix{Float64}(I, 3, 3),
        r_vectors = [0 1 -1; 0 0 0; 0 0 0],
        hamiltonian_r = h,
        orbital_positions = [0.0 0.3; 0.0 0.0; 0.0 0.0],
        position_model = :point_orbitals,
        source_file = @__FILE__
    )
end

"""Return configuration without running; use smoke=true for a two-point check."""
function build_config(; smoke = false, output_root = joinpath(tempdir(), "native-tb-demo"))
    return shift_config(
        build_model(),
        BZMesh(k_mesh = (smoke ? 2 : 101, 1), spatial_dimension = 2),
        output_root,
    )
end

if abspath(PROGRAM_FILE)==abspath(@__FILE__)
    WannierNLQG.run(build_config(smoke = "--smoke" in ARGS))
end
