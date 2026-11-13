"""Generate one independent response-symmetry JSON artifact."""
write_response_symmetry_artifact(arguments...; keywords...) =
    _call_symmetrization_extension(:write_response_symmetry_artifact, arguments...; keywords...)

"""Qualify a response-symmetry artifact against its Wannier gauge."""
qualify_response_symmetry_wannier_frame(arguments...; keywords...) = _call_symmetrization_extension(
    :qualify_response_symmetry_wannier_frame,
    arguments...;
    keywords...,
)

"""Screen a WIN mesh and return a deterministic symmetry-closed recommendation."""
screen_wannier_mesh(config::MeshScreenConfig) =
    _call_symmetrization_extension(:screen_wannier_mesh, config)

"""Symmetrize the complete operator profile selected by the configuration."""
symmetrize_wannier_operators(config::SymmetrizationConfig) =
    _call_symmetrization_extension(:symmetrize_wannier_operators, config)

"""Validate projection text options without group averaging or output reservation."""
validate_text_input_config(config::SymmetrizationConfig) =
    _call_symmetrization_extension(:_validate_symmetrization_options, config)

"""Resolve one supported magnetic provider against the actual owned atom order."""
projection_magnetic_moments(
    config::MagneticMomentConfig,
    structure::SymmetryFoundation.CrystalStructure,
) = _call_symmetrization_extension(:_owned_projection_magnetic_moments, config, structure)
