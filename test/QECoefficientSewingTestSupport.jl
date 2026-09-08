module QECoefficientSewingTestSupport

using HDF5

export write_qe_coefficient_sewing_fixture

# Return the UPF header flags for one synthetic overlap-metric class.
function _qe_fixture_metric_attributes(metric_kind::Symbol)
    metric_kind == :norm_conserving && return "is_paw=\"false\" is_ultrasoft=\"false\""
    metric_kind == :paw && return "is_paw=\"true\" is_ultrasoft=\"false\""
    metric_kind == :ultrasoft && return "is_paw=\"false\" is_ultrasoft=\"true\""
    throw(ArgumentError("unsupported synthetic QE metric kind $(metric_kind)"))
end

# Write a one- or two-k-point scalar QE save directory accepted by the production reader.
function write_qe_coefficient_sewing_fixture(
    directory::AbstractString,
    metric_kind::Symbol;
    num_kpoints::Int = 1,
)
    num_kpoints in (1, 2) ||
        throw(ArgumentError("synthetic QE fixture supports one or two k points"))
    mkpath(directory)
    attributes = _qe_fixture_metric_attributes(metric_kind)
    kpoint_blocks = join(
        ["<ks_energies><eigenvalues>-0.25</eigenvalues></ks_energies>" for _ in 1:num_kpoints],
        '\n',
    )
    write(joinpath(directory, "X.UPF"), "<UPF><PP_HEADER element=\"X\" $(attributes)/></UPF>\n")
    write(
        joinpath(directory, "data-file-schema.xml"),
        """
        <espresso>
          <input>
            <atomic_species>
              <species name="X"><pseudo_file>X.UPF</pseudo_file></species>
            </atomic_species>
            <atomic_structure>
              <cell>
                <a1>2.0 0.0 0.0</a1>
                <a2>0.0 2.0 0.0</a2>
                <a3>0.0 0.0 2.0</a3>
              </cell>
              <atomic_positions><atom name="X">0.0 0.0 0.0</atom></atomic_positions>
            </atomic_structure>
            <basis><ecutwfc>20.0</ecutwfc></basis>
          </input>
          <output>
            <band_structure>
              <noncolin>false</noncolin>
              <lsda>false</lsda>
              <nbnd>1</nbnd>
              $(kpoint_blocks)
            </band_structure>
          </output>
        </espresso>
        """,
    )
    for kpoint in 1:num_kpoints
        HDF5.h5open(joinpath(directory, "wfc$(kpoint).hdf5"), "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["igwx"] = 1
            attributes["nbnd"] = 1
            attributes["npol"] = 1
            attributes["xk"] = [0.5 * (kpoint - 1), 0.0, 0.0]
            attributes["scale_factor"] = 1.0
            handle["MillerIndices"] = zeros(Int, 3, 1)
            miller_attributes = HDF5.attributes(handle["MillerIndices"])
            miller_attributes["bg1"] = [1.0, 0.0, 0.0]
            miller_attributes["bg2"] = [0.0, 1.0, 0.0]
            miller_attributes["bg3"] = [0.0, 0.0, 1.0]
            handle["evc"] = reshape([2.0, 0.0], 2, 1)
        end
    end
    return abspath(directory)
end

end
