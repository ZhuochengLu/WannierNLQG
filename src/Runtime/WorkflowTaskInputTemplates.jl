"""Static ordinary-section text for the existing workflow input writer."""
const WANNIERIZATION_INPUT_TEMPLATE = """
workflow = "wannierization"
mode = "ordinary"

# Ordered rows must match the EIG/MMN/AMN input indexing.
[structure]
lattice_angstrom = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
species = ["X"]
positions_fractional = [[0.0, 0.0, 0.0]]

[kmesh]
dimensions = [1, 1, 1]
points_fractional = [[0.0, 0.0, 0.0]]

[basis]
projections = ["X:s"]

[matrices]
eig_file = "seed.eig"
mmn_file = "seed.mmn"
amn_file = "seed.amn"

[solver]
initialization = "amn"
# Independent Z/U limits and tolerances use the typed defaults when omitted.

[output]
model_file = "results/model.h5"
# checkpoint_hdf5 = "results/seed.wannierization.h5"  # optional restart artifact
profile = "hamiltonian_position"
final_tb_symmetry_report_enabled = false
detailed_progress = false
num_print_cycles = 1
num_dump_cycles = 100
"""

const NATIVE_SAWF_INPUT_TEMPLATE = """
workflow = "wannierization"
mode = "symmetry_adapted"

[source]
kind = "qe"
save_directory = "inputs/seed.save"

[kmesh]
# Must describe the complete ordered native point inventory; no completion.
dimensions = [1, 1, 1]

[basis]
# Replace X by the actual native chemical label; closure is checked, not expanded.
projections = ["X:s"]

[symmetry]
include_time_reversal = true
symmetry_tolerance = 1e-5

[solver]
initialization = "amn"

[output]
model_file = "results/model.h5"
# checkpoint_hdf5 = "results/seed.wannierization.h5"  # optional restart artifact
profile = "hamiltonian_position"
final_tb_symmetry_report_enabled = false
detailed_progress = false
num_print_cycles = 1
num_dump_cycles = 100
"""

"""Static ordinary-section text for the existing workflow input writer."""
const PROJECTION_INPUT_TEMPLATE = """
workflow = "symmetrization"
mode = "projection"

[source]
kind = "qe"
save_directory = "inputs/seed.save"

[basis]
projections = ["Si:s", "Si:p"]

[model]
tb_file = "inputs/seed_tb.dat"
wannier_center_policy = "symmetrize"
real_space_replica_policy = "minimum_distance"

[output]
tb_file = "results/seed_tb.dat"
packed_file = "results/seed.h5"
"""

"""Write the selected existing preparation workflow as ordinary TOML sections."""
function write_workflow_input_template(path, workflow, mode)
    if workflow == "mesh_screening"
        mode === nothing || throw(ArgumentError("mesh_screening does not accept mode"))
        text = """
workflow = "mesh_screening"
[source]
kind = "qe"
save_directory = "inputs/seed.save"
[mesh_screening]
dimension = 3
density_target = 55.0
search_radius = 10
[output]
report_json_file = "results/mesh.json"
"""
    elseif workflow == "wannierization"
        selected = something(mode, "ordinary")
        selected in ("ordinary", "symmetry_adapted") ||
            throw(ArgumentError("invalid Wannierization template mode"))
        text = selected == "ordinary" ? WANNIERIZATION_INPUT_TEMPLATE : NATIVE_SAWF_INPUT_TEMPLATE
    elseif workflow == "symmetrization"
        selected = something(mode, "projection")
        selected == "projection" || throw(ArgumentError("invalid symmetrization template mode"))
        text = PROJECTION_INPUT_TEMPLATE
    else
        throw(
            ArgumentError(
                "workflow must be response, wannierization, symmetrization or mesh_screening",
            ),
        )
    end
    return write_task_input_text(path, text)
end
