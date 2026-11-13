"""Reject retired Geometric Loop QHC expert calls before mutating any workspace.

The diagnostic symbol remains for explicit failure of existing callers. Other
Geometric Loop responses keep their independent implementations.
"""
function compute_geometric_loop_quantum_hermitian_connection_kernel!(args...; kwargs...)
    throw(
        ArgumentError(
            "GEOMETRIC_LOOP_QHC_UNSUPPORTED: Quantum Hermitian Connection with Geometric Loop is not supported in WannierNLQG 1.2. Select a supported QHC method explicitly.",
        ),
    )
end
