"""Generate one independent response-symmetry JSON artifact."""
write_response_symmetry_artifact(arguments...; keywords...) =
    _call_symmetrization_extension(:write_response_symmetry_artifact, arguments...; keywords...)

"""Qualify a response-symmetry artifact against its Wannier90 gauge."""
qualify_response_symmetry_wannier90(arguments...; keywords...) =
    _call_symmetrization_extension(:qualify_response_symmetry_wannier90, arguments...; keywords...)

"""Screen a WIN mesh and return a deterministic symmetry-closed recommendation."""
screen_wannier_mesh(config::MeshScreenConfig) =
    _call_symmetrization_extension(:screen_wannier_mesh, config)

"""Symmetrize the complete operator profile selected by the configuration."""
symmetrize_wannier_operators(config::SymmetrizationConfig) =
    _call_symmetrization_extension(:symmetrize_wannier_operators, config)

"""Symmetrize an existing Wannier90 model in its stored composite gauge."""
symmetrize_existing_wannier_model(config::GaugeAwareSymmetrizationConfig) =
    _call_symmetrization_extension(:symmetrize_existing_wannier_model, config)
