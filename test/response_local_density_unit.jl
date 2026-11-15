module ResponseLocalDensityUnit
using Test, LinearAlgebra, WannierNLQG
const C = WannierNLQG.Core
const R = WannierNLQG.Runtime
const CALLS = Ref(0)
root_owner() = R.mpi_is_root_process()
function read_rows(path)
    return [
        parse.(Float64, split(line)) for
        line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
    ]
end
function input_model()
    base = Main.spectral_test_model()
    centers = hcat([real.(diag(base.position_r[:, :, axis, 1])) for axis in 1:3]...)'
    return RealSpaceTBInput(
        lattice = base.lattice,
        r_vectors = base.r_vectors,
        hamiltonian_r = base.hamiltonian_r,
        orbital_positions = centers,
        position_model = :point_orbitals,
    )
end
function config(model, quantity, sampling; method = "Conventional", backend = "direct")
    physics =
        quantity == "AHC" ? IntrinsicHallParameters(fermi_energies = [0.0]) :
        quantity == "OM" ?
        OrbitalMagnetizationParameters(
            fermi_energies = [-0.8],
            temperature = 300.0,
            input_semantics = :defined_finite_model,
        ) :
        BerryMultipoleParameters(
            fermi_energies = [-0.8],
            temperature = 300.0,
            relaxation_time_fs = 7.0,
            integral_form = quantity == "BCDC" ? :fermi_surface : :fermi_sea,
        )
    component =
        quantity == "AHC" ? (1, 2) :
        quantity == "OM" ? (3,) : quantity == "BCDC" ? (2, 3, 1) : (2, 3, 3, 1)
    slice = sampling isa KSlice
    observable =
        slice ?
        KSliceSelection(component = TensorComponent(component...), bands = BandSelection()) :
        quantity in ("BCDC", "BCQC") ? TensorComponents(TensorComponent(component...)) :
        FullTensor()
    TaskConfig(
        model = model,
        sampling = sampling,
        tasks = [
            TaskSpec(
                id = "density",
                quantity = R.canonical_quantity_name(R.normalize_quantity(quantity)),
                method = method,
                physics = physics,
                observable = observable,
            ),
        ],
        execution = ExecutionOptions(
            fourier_backend = backend,
            NKFFT = lowercase(backend) == "mixed" ? sampling.k_mesh : nothing,
        ),
        output = OutputOptions(
            output_root = mktempdir(),
            progress_enabled = false,
            response_output_digits = 17,
        ),
    )
end
function compute(configuration)
    CALLS[] += 1
    return WannierNLQG.run(configuration)
end
function plane(z; mesh = (3, 3))
    KSlice(
        k_mesh = mesh,
        spatial_dimension = 3,
        origin = (0.0, 0.0, z),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0, 0.0),
    )
end
function local_values(result, quantity)
    path =
        quantity in ("BCDC", "BCQC") ?
        only(filter(p -> endswith(p, "_conductivity.dat"), result.outputs)) :
        only(filter(p -> endswith(p, "_total.dat"), result.outputs))
    rows = read_rows(path)
    return quantity in ("BCDC", "BCQC") ? [last(row) + 0im for row in rows] :
           [row[4] + im * row[5] for row in rows]
end
function integral_value(result, quantity)
    path =
        quantity in ("BCDC", "BCQC") ?
        only(filter(p -> endswith(p, "_conductivity.dat"), result.outputs)) :
        only(filter(p -> endswith(p, "_total.dat"), result.outputs))
    row = only(read_rows(path))
    return quantity in ("BCDC", "BCQC") ? last(row) + 0im :
           quantity == "AHC" ? row[4] + im * row[5] : row[6] + im * row[7]
end

@testset "Declared local densities reconstruct bulk and sheet measures once" begin
    input = input_model()
    volume = abs(det(input.model.lattice)) * 1e-30
    area = norm(cross(input.model.lattice[1, :], input.model.lattice[2, :])) * 1e-20
    for quantity in ("AHC", "BCDC", "BCQC", "OM")
        integrated =
            compute(config(input, quantity, BZMesh(k_mesh = (3, 3, 3), spatial_dimension = 3)))
        densities = ComplexF64[]
        first_values = ComplexF64[]
        for iz in 0:2
            sampled = compute(config(input, quantity, plane(iz / 3)))
            if root_owner()
                values = local_values(sampled, quantity)
                iz == 0 && append!(first_values, values)
                append!(densities, values)
            end
        end
        refined = compute(config(input, quantity, plane(0.0; mesh = (6, 6))))
        if root_owner()
            expected = integral_value(integrated, quantity)
            reconstructed = sum(densities) / length(densities) / (quantity == "OM" ? 1.0 : volume)
            @test reconstructed ≈ expected rtol = 2e-12 atol = 1e-28
            fine = reshape(local_values(refined, quantity), 6, 6)
            @test vec(fine[1:2:end, 1:2:end]) ≈ first_values rtol = 2e-12 atol = 1e-60
            @test length(densities) == 27
        end
        if quantity in ("BCDC", "BCQC")
            sheet = compute(config(input, quantity, BZMesh(k_mesh = (3, 3), spatial_dimension = 3)))
            if root_owner()
                @test sum(first_values) / length(first_values) / area ≈
                      integral_value(sheet, quantity) rtol = 2e-12 atol = 1e-28
                path = only(filter(p -> endswith(p, "_conductivity.dat"), sheet.outputs))
                @test occursin(quantity == "BCDC" ? "A*m/V^2" : "A*m^2/V^3", read(path, String))
            end
        end
    end
end

@testset "AHC local matrix/projector and Direct/Mixed consumers" begin
    # The existing closed file fixture exercises the regular-grid Fourier port.
    base = Main.spectral_test_model()
    path = joinpath(mktempdir(), "closed.dat")
    WannierNLQG.IO.write_wannier_tb(path, base)
    values = Dict{Tuple{String, String}, Vector{ComplexF64}}()
    for method in ("Conventional", "Projector"), backend in ("direct", "mixed")
        result = compute(config(ModelInput(model_file = path), "AHC", plane(0.0); method, backend))
        root_owner() && (values[(method, backend)] = local_values(result, "AHC"))
    end
    if root_owner()
        reference = values[("Conventional", "direct")]
        for value in Base.values(values)
            @test value ≈ reference rtol = 2e-11 atol = 1e-28
        end
    end
end
end
