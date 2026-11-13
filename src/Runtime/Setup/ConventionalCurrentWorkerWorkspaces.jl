# Cold worker-slot construction shared by Integral and K-slice consumers.
# Mathematical kernels, caller-selected demand and slot ownership remain explicit.
function _make_conventional_current_worker_workspaces(
    num_workers,
    num_orbitals,
    num_r_vectors,
    spatial_dimension,
    num_photon_energies,
    matrix_workspaces,
    central_data;
    shift_current_required::Bool,
    frequency_contraction_required::Bool,
)
    return [
        make_shift_current_conventional_workspace(
            num_orbitals,
            num_r_vectors,
            spatial_dimension,
            num_photon_energies,
            matrix_elements = matrix_workspaces[worker_id],
            central_data = central_data[worker_id],
            shift_current_required = shift_current_required,
            frequency_contraction_required = frequency_contraction_required,
        ) for worker_id in 1:num_workers
    ]
end

# Allocate private SSC slots over the same caller-owned worker matrix/data references.
function _make_conventional_shift_spin_worker_workspaces(
    num_workers,
    num_orbitals,
    num_r_vectors,
    spatial_dimension,
    num_photon_energies,
    matrix_workspaces,
    central_data;
    frequency_contraction_required::Bool,
)
    return [
        make_shift_spin_current_conventional_workspace(
            num_orbitals,
            num_r_vectors,
            spatial_dimension,
            num_photon_energies,
            matrix_elements = matrix_workspaces[worker_id],
            central_data = central_data[worker_id],
            frequency_contraction_required = frequency_contraction_required,
        ) for worker_id in 1:num_workers
    ]
end
