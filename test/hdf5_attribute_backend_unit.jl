using HDF5, JSON3

@testset "Explicit HDF5 backend preserves attribute values and caller ownership" begin
    mktempdir() do directory
        filename = joinpath(directory, "attributes.h5")
        h5open(filename, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["integer"] = 17
            attributes["float"] = 0.125
            attributes["vector"] = [2, 3, 5]
            attributes["text"] = "Wannier δ"
            attributes["empty"] = ""
            attributes["texts"] = ["alpha", "beta"]
        end
        function compare_attributes(handle)
            for name in keys(HDF5.attributes(handle))
                attribute = HDF5.attributes(handle)[name]
                try
                    expected = read(attribute)
                    actual = WannierNLQG.IO.read_hdf5_attribute_value(attribute, HDF5)
                    @test isequal(actual, expected)
                    @test typeof(actual) == typeof(expected)
                    @test isequal(read(attribute), expected)
                    @test isequal(WannierNLQG.IO.read_hdf5_attribute_value(attribute), actual)
                finally
                    close(attribute)
                end
            end
        end
        h5open(compare_attributes, filename, "r")
        # The actual current checkpoint supplies its fixed-width identity strings.
        checkpoint = joinpath(
            @__DIR__,
            "fixtures",
            "nohash_checkpoint_workload",
            "synthetic.wannierization.h5",
        )
        h5open(compare_attributes, checkpoint, "r")
    end
end
