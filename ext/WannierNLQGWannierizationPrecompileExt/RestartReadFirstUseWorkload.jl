# Exercise only existing tiny read-only schema fixtures through their owner.
# All HDF5 handles close inside the readers; no MPI or scientific solve runs here.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let filename = joinpath(
                @__DIR__,
                "..",
                "..",
                "test",
                "fixtures",
                "first_use",
                "band_preparation_1_0.h5",
            )
            representation = WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(filename)
            WannierNLQG.SymmetryFoundation.read_band_representation_preparation_hdf5(
                filename,
                representation,
            )
        end
    end
end
