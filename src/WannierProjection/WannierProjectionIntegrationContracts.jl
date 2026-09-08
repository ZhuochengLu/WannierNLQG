"""
Qualified, non-exported integration API consumed by sibling workflow layers.

Projection implementation helpers not listed here remain private to
`WannierProjection`.
"""
const WANNIER_PROJECTION_INTEGRATION_API = (
    :WANNIER_PROJECTION_INTEGRATION_API,
    :parse_input_boolean,
    :parse_projection_line,
    :parse_wannier_float,
    :projection_radial_transform_contract,
    :strip_input_comment,
)
