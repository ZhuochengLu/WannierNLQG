"""
Qualified, non-exported integration API consumed by sibling workflow layers.

Projection implementation helpers not listed here remain private to
`WannierProjection`.
"""
const WANNIER_PROJECTION_INTEGRATION_API = (
    :WANNIER_PROJECTION_INTEGRATION_API,
    :projection_orbital_labels,
    :parse_input_boolean,
    :parse_projection_line,
    :parse_wannier_float,
    :projection_radial_transform_contract,
    :projection_basis_input_values,
    :strip_input_comment,
)

"""Return the established immutable orbital-label tuple for one supported set.

The native-input topology adapter retains the original ordering and missing-key
error. The mutable owner dictionary itself is never exposed through this port.
"""
projection_orbital_labels(orbital_set::AbstractString) = ORBITAL_LABELS[orbital_set]
