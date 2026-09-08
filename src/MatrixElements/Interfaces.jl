"""
Prepare k-independent real-space derivative buffers selected by the matrix plan.

Wrapper workspaces delegate to their shared interpolation workspace and retain slot ownership and Wannier-center convention.

Concrete methods are defined next to the workspace they prepare.
"""
function prepare_real_space! end

"""
Compute the capabilities compiled into a matrix-element workspace at one k point.

Concrete methods are defined next to their data and workspace types.
"""
function compute_kpoint! end

"""Transform one operator matrix from Wannier gauge to Hamiltonian gauge."""
function transform_to_hamiltonian_gauge! end
