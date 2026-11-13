using PrecompileTools: @setup_workload, @compile_workload

# A completed, tiny schema-1.0 artifact enters the public reader and writer in
# their three-trigger owner. It uses no Wannierization, MPI or serialized Julia
# state. Round-trip arrays stay exact; output belongs only to mktempdir.
@setup_workload let
    @assert Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt) === @__MODULE__
    sf = WannierNLQG.SymmetryFoundation
    input = normpath(
        joinpath(
            @__DIR__,
            "..",
            "..",
            "test",
            "fixtures",
            "first_use_portable",
            "assets",
            "additional_1",
            "frozen_reader_input.h5",
        ),
    )
    mktempdir() do directory
        @compile_workload begin
            representation = sf.read_band_representation_hdf5(input)
            @assert representation.schema_version == "1.0"
            @assert all(isfinite, representation.sewing_matrices)
            output = joinpath(directory, "tiny.band-representation.h5")
            @assert sf.write_band_representation_hdf5(output, representation) == abspath(output)
            restored = sf.read_band_representation_hdf5(output)
            @assert isequal(restored.sewing_matrices, representation.sewing_matrices)
            @assert isequal(restored.energies_ev, representation.energies_ev)
            sf.build_band_product_table(restored.operations, restored.spinor)
            validation = sf.validate_band_representation(
                restored;
                absolute_tolerance = 1.0e-8,
                oracle_excess_tolerance = 1.0e-8,
                require_oracle = false,
            )
            @assert validation.passed && all(isfinite, validation.maximum_group_law_residuals)
            summary = joinpath(directory, "tiny.band-summary.json")
            sf.write_band_representation_summary(summary, restored, validation; overwrite = false)
            @assert isfile(summary)
        end
    end
end
