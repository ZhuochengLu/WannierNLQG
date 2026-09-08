"""Concrete spectrum observable evaluated by the shared KPath driver."""
struct BandStructureKPathKernel
    matrix_plan::MatrixElementPlan
    energy_reference_eV::Float64
    hermiticity_tolerance::Float64
end

# Compile the matrix-element dependency closure for one BandStructure task.
function BandStructureKPathKernel(cfg::EffectiveTaskConfig)
    matrix_plan = compile_matrix_plan(
        MatrixElementRequest(
            SPECTRUM;
            spatial_dimension = 3,
            denominator_regularization = cfg.denominator_regularization,
            degeneracy_threshold = cfg.degeneracy_threshold,
        );
        source_gauge_required = false,
        wannier_center_convention = normalize_wannier_center_convention(
            cfg.wannier_center_convention,
        ),
    )
    return BandStructureKPathKernel(matrix_plan, cfg.fermi_energy, cfg.band_hermiticity_tolerance)
end

# BandStructure emits one energy column for each orbital.
_kpath_result_width(::BandStructureKPathKernel, model) = model.num_orbitals

# Allocate and initialize one thread-local spectrum workspace.
function _prepare_kpath_worker(kernel::BandStructureKPathKernel, model)
    workspace = MatrixElementWorkspace(model, kernel.matrix_plan)
    prepare_real_space!(workspace, model)
    return workspace
end

# Evaluate one Hermiticity-checked spectrum and write energies relative to the declared reference.
function _evaluate_kpath_point!(
    destination,
    kernel::BandStructureKPathKernel,
    workspace,
    model,
    kpoint,
)
    checked = compute_checked_spectrum!(
        workspace,
        model,
        kpoint;
        hermiticity_tolerance = kernel.hermiticity_tolerance,
    )
    destination .= checked.spectrum.energies .- kernel.energy_reference_eV
    return checked.hermiticity_residual
end
