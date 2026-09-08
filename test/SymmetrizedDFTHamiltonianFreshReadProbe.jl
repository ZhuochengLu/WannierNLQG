using EzXML
using HDF5
using JSON3
using LinearAlgebra
using SHA
using Spglib
using WannierNLQG

length(ARGS) in (2, 3) || error("expected GAUGE_HDF5 REPRESENTATION_HDF5 [QE_SAVE_DIR]")
gauge_path, representation_path = abspath.(ARGS[1:2])
save_directory = length(ARGS) == 3 ? abspath(ARGS[3]) : nothing
W = WannierNLQG.Wannierization
extension = first(W._load_wannierization_extension!()).PAWMatrixElements
target_band_range = HDF5.h5open(gauge_path, "r") do handle
    attributes = HDF5.attributes(handle)
    String(read(attributes["source_code"])) == "qe" ||
        error("fresh-read probe expects QE source")
    @assert String(read(attributes["nonrepresentative_frame_storage"])) ==
            "local_native_source_plus_completed_rotation"
    @assert !haskey(handle, "sealed_completed_frame_corrections")
    Int(read(attributes["target_band_start"])):Int(read(attributes["target_band_stop"]))
end
source = if save_directory === nothing
    nothing
else
    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
        something(save_directory);
        band_range = target_band_range,
        include_time_reversal = false,
    )
end
gauge = Base.invokelatest(extension._read_star_covariant_paw_gauge_hdf5, gauge_path; source)
representation = WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(representation_path)
authority = get(representation.conventions, "authoritative_hamiltonian", "")
expected_schema = "1.0"
representation.schema_version == expected_schema ||
    error("fresh read lost representation schema $(expected_schema)")
representation.conventions["native_difference_qualification"] == "audit_only" ||
    error("fresh read lost audit-only native-difference authority")
authority == "symmetrized_dft_hamiltonian" || error("fresh read lost symmetrized authority")
get(representation.conventions, "global_production_eligible", "true") == "false" ||
    error("fresh read promoted global production")
gauge.payload.source_metadata["authoritative_hamiltonian"] == authority ||
    error("fresh read lost gauge authority")
gauge.payload.symmetrized_hamiltonian_audit === nothing &&
    error("fresh read lost symmetrized Hamiltonian audit")
gauge.payload.source_metadata["energy_shift_qualification"] == "audit_only" ||
    error("fresh read lost audit-only energy-shift semantics")
representation.conventions["qualification_scope"] == "target_subspace" ||
    error("fresh read lost target qualification scope")
representation.conventions["target_anchor"] == "completed_symmetrized_target" ||
    error("fresh read lost target anchor")
gauge.payload.source_metadata["auxiliary_parent_qualification"] == "audit_only" ||
    error("fresh read promoted the auxiliary parent")
digest = bytes2hex(SHA.sha256(vcat(read(gauge_path), read(representation_path))))
println("SYMMETRIZED_DFT_HAMILTONIAN_FRESH_READ_DIGEST=$(digest)")
payload_sha256 = Base.invokelatest(extension._star_payload_sha256, gauge.payload)
println("SYMMETRIZED_DFT_HAMILTONIAN_FRESH_READ_PAYLOAD_SHA256=$(payload_sha256)")
