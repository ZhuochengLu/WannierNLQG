@testset "Independent generator writer schema versions" begin
    extension =
        first(WannierNLQG.Wannierization._load_wannierization_extension!()).PAWMatrixElements
    for symbol in (
        :VASP_PAW_SPN_SCHEMA_VERSION,
        :QE_PAW_SPN_SCHEMA_VERSION,
        :VASP_PAW_MATRIX_ELEMENT_SCHEMA_VERSION,
        :WANNIER_UIU_GENERATION_SCHEMA_VERSION,
    )
        @test getfield(extension, symbol) == "1.0"
    end
    operator_export =
        first(WannierNLQG.Wannierization._load_wannierization_extension!()).OperatorExport
    @test operator_export.WANNIER_HAMILTONIAN_OPERATOR_GENERATION_SCHEMA_VERSION == "1.0"
    @test extension.PAW_BLOCK_PARTITION_AUDIT_SCHEMA_VERSION == "1.0"
end
