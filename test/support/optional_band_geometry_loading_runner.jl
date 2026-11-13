using Test, LinearAlgebra
using WannierNLQG

const BAND_GEOMETRY_PACKAGE_NAMES = Set(("Brillouin", "DirectQhull", "Qhull_jll"))
const FIXED_GRID_MEASUREMENT = Dict{String, Any}()

"""Return the optional geometry modules actually loaded in this fresh process."""
function loaded_band_geometry_names()
    return Set(
        id.name for id in keys(Base.loaded_modules) if id.name in BAND_GEOMETRY_PACKAGE_NAMES
    )
end

"""Exercise an actual fixed-grid public response before any geometry request.

The synthetic onsite model has identically zero velocity/shift response. It is
an engineering fixture, not a substitute for the full-position GeS models.
"""
function check_fixed_grid_without_geometry()
    @test isempty(loaded_band_geometry_names())
    model = RealSpaceTBInput(
        lattice = Matrix{Float64}(I, 3, 3),
        r_vectors = zeros(Int, 3, 1),
        hamiltonian_r = reshape(ComplexF64[-1 0; 0 1], 2, 2, 1),
        orbital_positions = zeros(3, 2),
        position_model = :point_orbitals,
    )
    mktempdir() do directory
        config = TaskConfig(
            model = model,
            sampling = BZMesh(k_mesh = (2, 2, 1), spatial_dimension = 3),
            tasks = [
                TaskSpec(
                    id = "fixed_grid",
                    quantity = "SC",
                    method = "Conventional",
                    physics = OpticalParameters(
                        photon_energies = [1.0, 2.0],
                        fermi_energy = 0.0,
                        temperature = 0.0,
                    ),
                    numerics = Numerics(
                        broadening = 0.06,
                        denominator_regularization = 0.001,
                        band_window_size = -1,
                    ),
                    observable = FullTensor(),
                ),
            ],
            execution = ExecutionOptions(fourier_backend = "direct"),
            output = OutputOptions(
                output_root = directory,
                system_name = "onsite",
                progress_enabled = false,
            ),
        )
        result = WannierNLQG.run(config)
        data = only(filter(path -> endswith(path, ".dat"), result.outputs))
        rows = [
            parse.(Float64, split(line)) for
            line in eachline(data) if !isempty(strip(line)) && !startswith(strip(line), "#")
        ]
        @test length(rows) == 2
        @test all(row -> length(row) == 56 && all(isfinite, row), rows)
        @test all(row -> all(iszero, row[3:end]), rows)
        merge!(
            FIXED_GRID_MEASUREMENT,
            Dict(
                "public_run" => true,
                "task_count" => length(result.task_results),
                "outputs_count" => length(result.outputs),
                "all_output_values_finite" => all(row -> all(isfinite, row), rows),
                "raw_dat" => read(data, String),
                "geometry_loaded_after_fixed_grid" => collect(loaded_band_geometry_names()),
            ),
        )
    end
    @test isempty(loaded_band_geometry_names())
end

"""Exercise both existing public geometry branches after the fixed-grid check."""
function check_geometry_on_demand()
    symmetry = WannierNLQG.SymmetryFoundation
    lattice = [0.0 2.715 2.715; 2.715 0.0 2.715; 2.715 2.715 0.0]
    crystal = symmetry.CrystalStructure(lattice, ["Si", "Si"], [0.0 0.25; 0.0 0.25; 0.0 0.25])
    path = automatic_kpath(crystal)
    @test path.provenance["structural_space_group_number"] == 227
    @test path.provenance["convention"] == "HPKOT/SeeK-path"
    @test loaded_band_geometry_names() == BAND_GEOMETRY_PACKAGE_NAMES
    plane = [3.0 0.0 0.0; -1.5 1.5sqrt(3.0) 0.0; 0.0 0.0 30.0]
    plane_crystal = symmetry.CrystalStructure(plane, ["X"], zeros(3, 1))
    plane_path = automatic_kpath(plane_crystal; periodic_axes = (1, 2))
    @test plane_path.provenance["plane_bravais_type"] == "hexagonal"
    @test first.(plane_path.nodes) == ["Γ", "M", "K", "Γ"]
    repeated = automatic_kpath(plane_crystal; periodic_axes = (1, 2))
    @test repeated.nodes == plane_path.nodes
    @test repeated.provenance == plane_path.provenance
end

"""Check the public missing-dependency error using a fresh fixture depot."""
function check_missing_geometry_dependency()
    symmetry = WannierNLQG.SymmetryFoundation
    crystal = symmetry.CrystalStructure(Matrix{Float64}(I, 3, 3), ["X"], zeros(3, 1))
    caught = try
        automatic_kpath(crystal)
        nothing
    catch exception
        exception
    end
    @test caught isa ArgumentError
    @test occursin("locked Brillouin geometry", sprint(showerror, caught))
    @test isempty(loaded_band_geometry_names())
end

@testset "optional geometry in a fresh fixed-grid consumer" begin
    check_fixed_grid_without_geometry()
    if ARGS == ["missing-geometry"]
        check_missing_geometry_dependency()
    else
        isempty(ARGS) || error("expected no arguments or missing-geometry")
        check_geometry_on_demand()
    end
end
