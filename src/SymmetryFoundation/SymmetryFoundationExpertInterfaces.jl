"""Detect ordered unitary and antiunitary crystal operations."""
detect_symmetry_operations(arguments...; keywords...) =
    _call_symmetry_foundation_extension(:detect_symmetry_operations, arguments...; keywords...)

"""Detect the classified magnetic-space-group inventory for one structure."""
detect_magnetic_symmetry_inventory(arguments...; keywords...) = _call_symmetry_foundation_extension(
    :detect_magnetic_symmetry_inventory,
    arguments...;
    keywords...,
)

"""Detect TB-workflow operations with the frozen 2026-08-16 compatibility contract."""
detect_tb_compatibility_symmetry_operations(arguments...; keywords...) =
    _call_symmetry_foundation_extension(
        :detect_tb_compatibility_symmetry_operations,
        arguments...;
        keywords...,
    )

"""Return the active symmetry-detection backend identity for provenance only."""
symmetry_detection_backend_provenance() =
    _call_symmetry_foundation_extension(:symmetry_detection_backend_provenance)

"""Build the cold-path response-symmetry group classification and generators."""
response_symmetry_group_report(payload::AbstractDict; strict::Bool = true) =
    _call_symmetry_foundation_extension(:response_symmetry_group_report, payload; strict)

"""Return the current BandRepresentation writer schema without exposing the extension."""
band_representation_schema_version() =
    _call_symmetry_foundation_extension(:band_representation_schema_version)

"""Read and validate one public schema-1.0 band-representation HDF5 artifact."""
read_band_representation_hdf5(filename::AbstractString) =
    _call_symmetry_foundation_extension(:read_band_representation_hdf5, filename)

"""Read shared representation-preparation metadata for expert workflow preflight."""
function read_band_representation_preparation_hdf5(
    filename::AbstractString,
    representation::BandRepresentation,
)
    return _call_symmetry_foundation_extension(
        :read_band_representation_preparation_hdf5,
        filename,
        representation,
    )
end

"""Build the validated antiunitary-aware operation product table."""
function build_band_product_table(arguments...; keywords...)
    return _call_symmetry_foundation_extension(:build_band_product_table, arguments...; keywords...)
end

"""Attach one explicit qualification window to a band representation."""
function configure_band_qualification_window!(arguments...; keywords...)
    return _call_symmetry_foundation_extension(
        :configure_band_qualification_window!,
        arguments...;
        keywords...,
    )
end

"""Validate one band representation against absolute and optional oracle gates."""
function validate_band_representation(arguments...; keywords...)
    return _call_symmetry_foundation_extension(
        :validate_band_representation,
        arguments...;
        keywords...,
    )
end

"""Write the deterministic JSON summary paired with a band representation."""
function write_band_representation_summary(arguments...; keywords...)
    return _call_symmetry_foundation_extension(
        :write_band_representation_summary,
        arguments...;
        keywords...,
    )
end

"""Atomically persist one public schema-1.0 band-representation HDF5 artifact."""
function write_band_representation_hdf5(
    filename::AbstractString,
    representation::BandRepresentation;
    keywords...,
)
    return _call_symmetry_foundation_extension(
        :write_band_representation_hdf5,
        filename,
        representation;
        keywords...,
    )
end

"""Persist one representation after validating the supplied contract evidence."""
function write_band_representation_hdf5(
    filename::AbstractString,
    representation::BandRepresentation,
    validation;
    keywords...,
)
    return _call_symmetry_foundation_extension(
        :write_band_representation_hdf5,
        filename,
        representation;
        validation,
        keywords...,
    )
end

"""Generate and persist a native VASP band representation."""
generate_vasp_band_representation(config::VASPBandRepresentationConfig) =
    _call_symmetry_foundation_extension(:generate_vasp_band_representation, config)
"""
Validate the complete public BandRepresentation storage contract without changing
arrays or assigning scientific qualification. This is a sibling-layer integration port.
"""
validate_public_band_representation_contract(representation::BandRepresentation) =
    _call_symmetry_foundation_extension(
        :_band_validate_public_representation_contract,
        representation,
    )

"""Validate the recorded requested/effective mode and identity constraints for sibling workflows."""
validate_unified_representation_mode_contract(representation::BandRepresentation) =
    _validate_unified_representation_mode_contract(representation)
