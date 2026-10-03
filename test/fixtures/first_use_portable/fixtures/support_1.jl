using HDF5
include(Main.FirstUsePortableSupport.input("fixtures/support_4.jl"))
using .QEPAWMatrixElementsTestSupport

"""Build two orthogonal spinor bands with a nonzero native energy gap."""
function two_band_paw_audit_source(directory; metric_kind::Symbol)
    fixture = write_qe_paw_fixture(directory; metric_kind, spinor = true, spinorbit = false)
    schema = joinpath(fixture.save_directory, "data-file-schema.xml")
    original = read(schema, String)
    occursin("<nbnd>1</nbnd>", original) || error("QE_FIXTURE_BAND_COUNT_CHANGED")
    occursin("<eigenvalues>-0.25</eigenvalues>", original) || error("QE_FIXTURE_ENERGY_CHANGED")
    updated = replace(original, "<nbnd>1</nbnd>" => "<nbnd>2</nbnd>")
    updated = replace(
        updated,
        "<eigenvalues>-0.25</eigenvalues>" => "<eigenvalues>-0.0005 0.0005</eigenvalues>",
    )
    write(schema, updated)
    wavefunction = joinpath(fixture.save_directory, "wfc1.hdf5")
    rm(wavefunction)
    HDF5.h5open(wavefunction, "w") do handle
        attributes = HDF5.attributes(handle)
        attributes["igwx"] = 1
        attributes["nbnd"] = 2
        attributes["npol"] = 2
        attributes["xk"] = [0.0, 0.0, 0.0]
        attributes["scale_factor"] = 1.0
        handle["MillerIndices"] = zeros(Int, 3, 1)
        miller = HDF5.attributes(handle["MillerIndices"])
        miller["bg1"] = [1.0, 0.0, 0.0]
        miller["bg2"] = [0.0, 1.0, 0.0]
        miller["bg3"] = [0.0, 0.0, 1.0]
        # QE stores real and imaginary parts of the two spin components.
        handle["evc"] = [1.0 0.0; 0.0 0.0; 0.0 1.0; 0.0 0.0]
    end
    return WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
        fixture.save_directory;
        band_range = 1:1,
        include_time_reversal = false,
    )
end
