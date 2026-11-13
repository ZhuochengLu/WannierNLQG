using Test

@testset "Focused scientific regressions are wired into ordinary Fast" begin
    expected = (
        "intrinsic_hall_real_occupation_unit.jl",
        "response_consumers_unit.jl",
        "response_local_density_unit.jl",
        "response_adaptive_consumers_unit.jl",
        "third_order_normalization_input_unit.jl",
        "native_low_dimensional_unit.jl",
        "native_low_dimensional_third_order_unit.jl",
        "native_low_dimensional_capabilities_unit.jl",
        "geometry_options_unit.jl",
        "conventional_kslice_band_selection_unit.jl",
        "spin_velocity_degenerate_block_unit.jl",
        "wilson_response_groups_unit.jl",
        "cell_image_causal_shg_unit.jl",
    )
    @test CITestPlan.SCIENTIFIC_REPAIR_FAST_TEST_FILES == expected
    @test CITestPlan.validate_scientific_repair_fast_coverage()
    for file in expected
        @test count(==(file), CITestPlan.FAST_TEST_FILES) == 1
        @test_throws ErrorException CITestPlan.validate_scientific_repair_fast_coverage(
            filter(!=(file), CITestPlan.FAST_TEST_FILES),
        )
        @test_throws ErrorException CITestPlan.validate_scientific_repair_fast_coverage((
            CITestPlan.FAST_TEST_FILES...,
            file,
        ),)
        source = read(joinpath(@__DIR__, file), String)
        @test !occursin(r"\bARGS\b|\bexit\s*\(", source)
        @test !occursin("GeS", source)
    end
end
