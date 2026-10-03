module QEPAWMatrixElementsTestSupport

using HDF5
using SHA
using WannierNLQG

export copy_qe_paw_oracles
export qe_paw_fixture_lanes
export qe_paw_output_digest
export write_qe_paw_fixture
export write_qe_paw_oracle_provenance

const BOHR_TO_ANGSTROM = 0.529177210903

"""Ordered generated lanes; these are engineering fixtures, not QE physics oracles."""
function qe_paw_fixture_lanes()
    return [
        (label = "nc-scalar", metric_kind = :norm_conserving, spinor = false, spinorbit = false),
        (label = "uspp-scalar", metric_kind = :ultrasoft, spinor = false, spinorbit = false),
        (label = "paw-scalar", metric_kind = :paw, spinor = false, spinorbit = false),
        (label = "paw-noncollinear", metric_kind = :paw, spinor = true, spinorbit = false),
        (label = "paw-fully-relativistic", metric_kind = :paw, spinor = true, spinorbit = true),
    ]
end

function _metric_attributes(metric_kind::Symbol)
    metric_kind == :norm_conserving &&
        return "is_paw=\"false\" is_ultrasoft=\"false\" pseudo_type=\"NC\""
    metric_kind == :paw && return "is_paw=\"true\" is_ultrasoft=\"false\" pseudo_type=\"PAW\""
    metric_kind == :ultrasoft &&
        return "is_paw=\"false\" is_ultrasoft=\"true\" pseudo_type=\"USPP\""
    throw(ArgumentError("unsupported QE PAW fixture metric kind $(metric_kind)"))
end

function _upf_text(metric_kind::Symbol, spinorbit::Bool)
    metric_attributes = _metric_attributes(metric_kind)
    spinorbit &&
        metric_kind != :paw &&
        throw(ArgumentError("synthetic spin-orbit fixture must use PAW data"))
    relativistic_attributes =
        spinorbit ? "has_so=\"true\" relativistic=\"full\"" :
        "has_so=\"false\" relativistic=\"scalar\""
    beta_attributes =
        spinorbit ? "angular_momentum=\"0\" tot_ang_mom=\"0.5\"" : "angular_momentum=\"0\""
    augmentation = if metric_kind == :norm_conserving
        ""
    else
        """
        <PP_AUGMENTATION q_with_l="true" nqlc="1" nqf="0" cutoff_r_index="3" cutoff_r="1.0">
          <PP_Q>0.0</PP_Q>
          <PP_QIJL.1.1.0>0.0 0.0 0.0</PP_QIJL.1.1.0>
        </PP_AUGMENTATION>
        """
    end
    return """
    <UPF version="2.0.1">
      <PP_HEADER element="X" $(metric_attributes) $(relativistic_attributes)/>
      <PP_MESH>
        <PP_R>0.0 0.5 1.0</PP_R>
        <PP_RAB>0.5 0.5 0.5</PP_RAB>
      </PP_MESH>
      <PP_NONLOCAL>
        <PP_BETA.1 $(beta_attributes)>0.0 0.0 0.0</PP_BETA.1>
        <PP_DIJ>0.0</PP_DIJ>
        $(augmentation)
      </PP_NONLOCAL>
    </UPF>
    """
end

function _nnkp_text(spinor::Bool, num_kpoints::Int)
    lattice = 2.0 * BOHR_TO_ANGSTROM
    reciprocal = 2.0 * pi / lattice
    projection_section = spinor ? "spinor_projections" : "projections"
    spin_row = spinor ? "\n      1 0.0 0.0 1.0" : ""
    kpoint_rows =
        join(["      $((index - 1) / num_kpoints) 0.0 0.0" for index in 1:num_kpoints], '\n')
    neighbor_rows = join(["      $(index) $(index) 0 0 0" for index in 1:num_kpoints], '\n')
    return """
    Synthetic NNKP for native QE matrix-element tests

    begin real_lattice
      $(repr(lattice)) 0.0 0.0
      0.0 $(repr(lattice)) 0.0
      0.0 0.0 $(repr(lattice))
    end real_lattice

    begin recip_lattice
      $(repr(reciprocal)) 0.0 0.0
      0.0 $(repr(reciprocal)) 0.0
      0.0 0.0 $(repr(reciprocal))
    end recip_lattice

    begin kpoints
      $(num_kpoints)
$(kpoint_rows)
    end kpoints

    begin $(projection_section)
      1
      0.0 0.0 0.0 0 1 1
      0.0 0.0 1.0 1.0 0.0 0.0 1.0$(spin_row)
    end $(projection_section)

    begin nnkpts
      1
$(neighbor_rows)
    end nnkpts

    begin exclude_bands
      0
    end exclude_bands
    """
end

"""Write a one-k, one-band, full-G-order QE engineering fixture."""
function write_qe_paw_fixture(
    directory::AbstractString;
    metric_kind::Symbol = :norm_conserving,
    spinor::Bool = false,
    spinorbit::Bool = false,
    num_kpoints::Int = 1,
)
    spinorbit &&
        !spinor &&
        throw(ArgumentError("synthetic spin-orbit fixture requires spinor coefficients"))
    num_kpoints > 0 || throw(ArgumentError("synthetic fixture requires at least one k-point"))
    save_directory = joinpath(directory, "fixture.save")
    mkpath(save_directory)
    write(joinpath(save_directory, "X.UPF"), _upf_text(metric_kind, spinorbit))
    write(
        joinpath(save_directory, "data-file-schema.xml"),
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
              <noncolin>$(spinor)</noncolin>
              <spinorbit>$(spinorbit)</spinorbit>
              <lsda>false</lsda>
              <nbnd>1</nbnd>
              $(join([
                  "<ks_energies><k_point>$((index - 1) / num_kpoints) 0.0 0.0</k_point><eigenvalues>-0.25</eigenvalues></ks_energies>" for
                  index in 1:num_kpoints
              ], '\n'))
            </band_structure>
          </output>
        </espresso>
        """,
    )
    for index in 1:num_kpoints
        HDF5.h5open(joinpath(save_directory, "wfc$(index).hdf5"), "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["igwx"] = 1
            attributes["nbnd"] = 1
            attributes["npol"] = spinor ? 2 : 1
            fractional = (index - 1) / num_kpoints
            canonical_fractional = fractional > 0.5 ? fractional - 1.0 : fractional
            attributes["xk"] = [canonical_fractional, 0.0, 0.0]
            attributes["scale_factor"] = 1.0
            handle["MillerIndices"] = zeros(Int, 3, 1)
            miller_attributes = HDF5.attributes(handle["MillerIndices"])
            miller_attributes["bg1"] = [1.0, 0.0, 0.0]
            miller_attributes["bg2"] = [0.0, 1.0, 0.0]
            miller_attributes["bg3"] = [0.0, 0.0, 1.0]
            handle["evc"] = reshape(spinor ? [1.0, 0.0, 0.0, 0.0] : [1.0, 0.0], :, 1)
        end
    end
    nnkp_file = joinpath(directory, "fixture.nnkp")
    write(nnkp_file, _nnkp_text(spinor, num_kpoints))
    return (save_directory = abspath(save_directory), nnkp_file = abspath(nnkp_file))
end

"""Copy diagnostic matrices into an isolated black-box-oracle directory."""
function copy_qe_paw_oracles(result, oracle_directory::AbstractString)
    mkpath(oracle_directory)
    mmn = joinpath(oracle_directory, "oracle.mmn")
    amn = joinpath(oracle_directory, "oracle.amn")
    cp(result.artifacts["mmn"], mmn; force = true)
    cp(result.artifacts["amn"], amn; force = true)
    return (mmn = mmn, amn = amn)
end

"""Bind oracle matrices to all authoritative QE/NNKP source hashes."""
function write_qe_paw_oracle_provenance(
    oracle_directory::AbstractString,
    input_sha256::Dict{String, String},
)
    filename = joinpath(oracle_directory, "oracle_qe_paw.provenance.h5")
    HDF5.h5open(filename, "w") do handle
        attributes = HDF5.attributes(handle)
        attributes["schema"] = "WannierNLQG.qe_paw_oracle_provenance"
        attributes["schema_version"] = "1.0"
        hashes = HDF5.create_group(handle, "input_sha256")
        for key in sort!(collect(keys(input_sha256)))
            startswith(key, "ORACLE_") && continue
            HDF5.attributes(hashes)[key] = input_sha256[key]
        end
    end
    return filename
end

"""Canonical matrix/result digest used by fresh-process thread tests."""
function qe_paw_output_digest(result)
    buffer = IOBuffer()
    for key in ("mmn", "amn")
        write(buffer, read(result.artifacts[key]))
    end
    write(buffer, reinterpret(UInt8, vec(result.mmn.data)))
    write(buffer, reinterpret(UInt8, vec(result.amn.data)))
    write(buffer, reinterpret(UInt8, [result.generalized_norm_max_absolute]))
    write(buffer, string(result.passed), '\n')
    for diagnostic in result.diagnostics
        write(buffer, diagnostic, '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

end
