using Test
using WannierNLQG

@testset "response writer precision is explicit and backward compatible" begin
    mktempdir() do root
        value = ComplexF64(1.0 / 3.0, -2.0 / 7.0)
        tensor = reshape([value], 1, 1, 1, 1)

        default_path =
            WannierNLQG.IO.write_response_tensor(0.0, [0.125], tensor, 1, root, "default.dat")
        precise_path = WannierNLQG.IO.write_response_tensor(
            0.0,
            [0.125],
            tensor,
            1,
            root,
            "precise.dat";
            digits = 15,
        )

        default_fields = split(readlines(default_path)[3])
        precise_fields = split(readlines(precise_path)[3])
        @test default_fields[3] == "3.3333333e-01"
        @test precise_fields[3] == "3.333333333333333e-01"
        @test precise_fields[4] == "-2.857142857142857e-01"
        @test_throws ArgumentError WannierNLQG.IO.write_response_tensor(
            0.0,
            [0.125],
            tensor,
            1,
            root,
            "invalid.dat";
            digits = 6,
        )
    end
end

@testset "EffectiveTaskConfig response output precision validation" begin
    valid = WannierNLQG.Runtime.EffectiveTaskConfig(
        fourier_backend = "direct",
        response_output_digits = 15,
    )
    @test WannierNLQG.Runtime.validate_config(valid)[1].calculation == :integral
    invalid = WannierNLQG.Runtime.EffectiveTaskConfig(
        fourier_backend = "direct",
        response_output_digits = 18,
    )
    @test_throws ErrorException WannierNLQG.Runtime.validate_config(invalid)
end
