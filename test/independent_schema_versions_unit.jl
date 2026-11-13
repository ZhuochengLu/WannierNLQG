@testset "Independent generator writer schema versions" begin
    extension =
        first(WannierNLQG.Wannierization._load_wannierization_extension!()).PAWMatrixElements
    # Current mathematical-only formats use version 2.0. Historical decoding
    # and explicit migration are tested separately with archived assets.
    @test extension.VASP_PAW_SPN_SCHEMA_VERSION == "2.0"
    @test extension.QE_PAW_SPN_SCHEMA_VERSION == "2.0"
    @test extension.QE_PAW_MATRIX_ELEMENT_SCHEMA_VERSION == "2.0"
    @test extension.WANNIER_UIU_GENERATION_SCHEMA_VERSION == "2.0"
    @test extension.VASP_PAW_MATRIX_ELEMENT_SCHEMA_VERSION == "2.0"
    operator_export =
        first(WannierNLQG.Wannierization._load_wannierization_extension!()).OperatorExport
    @test operator_export.WANNIER_HAMILTONIAN_OPERATOR_GENERATION_SCHEMA_VERSION == "2.0"
    @test extension.PAW_BLOCK_PARTITION_AUDIT_SCHEMA_VERSION == "2.0"
end
