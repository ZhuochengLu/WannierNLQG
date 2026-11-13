using PrecompileTools: @setup_workload, @compile_workload
using LinearAlgebra
import WannierNLQG, MPI

# Checkpoint and native-EIG TB construction need only the W owner. Use the
# existing deterministic two-band/two-k-point public input, without activating
# crystal detection, MPI initialization, or the cross-extension workflow.
@setup_workload let
    @assert Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt) === @__MODULE__
    input = joinpath(
        @__DIR__,
        "..",
        "..",
        "test",
        "fixtures",
        "first_use_portable",
        "assets",
        "frozen_solver",
    )
    workspace = mktempdir()
    try
        @compile_workload begin
            WannierNLQG._first_use_require_serial()
            w = WannierNLQG.Wannierization
            result = read_current_checkpoint_asset(_CURRENT_CHECKPOINT_WORKLOAD, workspace)
            eig = WannierNLQG.IO.read_wannier_eig(joinpath(input, "synthetic.eig"))
            mmn = WannierNLQG.IO.read_wannier_mmn(joinpath(input, "synthetic.mmn"))
            model = w.build_wannier_tight_binding_model(result, eig, mmn)
            @assert all(isfinite, result.v_matrix)
            @assert all(isfinite, model.hamiltonian_r) && all(isfinite, model.position_r)
            @assert !MPI.Initialized()
            @assert WannierNLQG.Runtime.ACTIVE_PROGRESS[] === nothing
        end
    finally
        rm(workspace; recursive = true)
    end
end

# Full-mesh spread evaluation is a separate public call tree from solver-local
# localization. Its callers need only W, so capture it in this four-trigger owner
# without loading the symmetry-foundation extension or running a solver.
@setup_workload let
    root = mktempdir()
    try
        @compile_workload begin
            WannierNLQG._first_use_require_serial()
            w = WannierNLQG.Wannierization
            wp = WannierNLQG.WannierProjection
            configs = tiny_wannier_workflow(root)
            plan = wp.build_wannier_symmetry_plan(
                configs.solve.input.projection_basis,
                configs.representation.operations,
            )
            input = joinpath(
                @__DIR__,
                "..",
                "..",
                "test",
                "fixtures",
                "first_use_portable",
                "assets",
                "frozen_solver",
            )
            result = read_current_checkpoint_asset(_CURRENT_CHECKPOINT_WORKLOAD, root)
            mmn = WannierNLQG.IO.read_wannier_mmn(configs.mmn)
            spread = w.evaluate_full_3d_wannier_spreads(result, configs.representation, mmn, plan)
            @assert all(isfinite, spread.spreads_angstrom2)
            @assert abs(sum(spread.omega_directional) - spread.omega_total) <= 1e-10
            # Supplied nonzero band-to-Wannier frames exercise the public array
            # overload and genuine overlap evaluation, without a mock solver.
            frames = zeros(ComplexF64, 2, 1, 2)
            frames[:, 1, 1] .= (cos(pi / 10), sin(pi / 10))
            frames[:, 1, 2] .= (cos(pi / 10), -sin(pi / 10))
            nonzero = w.evaluate_full_3d_wannier_spreads(
                frames,
                zeros(1, 3),
                configs.representation,
                mmn,
                plan,
            )
            @assert all(isfinite, nonzero.spreads_angstrom2)
            @assert abs(sum(nonzero.omega_directional) - nonzero.omega_total) <= 1e-10
            @assert !MPI.Initialized()
            @assert WannierNLQG.Runtime.ACTIVE_PROGRESS[] === nothing
        end
    finally
        rm(root; recursive = true)
    end
end

# A direct public search/materialization call needs only W. The existing tiny
# two-band/two-k-point input supplies a real one-dimensional frozen target.
# Retained embeddings are validated; no solver or sibling SF reader is needed.
@setup_workload let
    root = mktempdir()
    try
        @compile_workload begin
            WannierNLQG._first_use_require_serial()
            w = WannierNLQG.Wannierization
            sf = WannierNLQG.SymmetryFoundation
            wp = WannierNLQG.WannierProjection
            configs = tiny_wannier_workflow(root)
            representation = configs.representation
            outer = BitMatrix(
                (-2.0 .<= representation.energies_ev) .& (representation.energies_ev .<= 2.0),
            )
            frozen = BitMatrix(
                (-2.0 .<= representation.energies_ev) .& (representation.energies_ev .<= -0.5),
            )
            scope = sf.BandRepresentationQualificationScope(
                outer,
                frozen;
                content_authentication = false,
            )
            contract = w.TargetSubspaceQualificationContract(
                scope;
                outer_min_ev = -2.0,
                outer_max_ev = 2.0,
                frozen_min_ev = -2.0,
                frozen_max_ev = -0.5,
                num_wannier = 1,
            )
            representation.conventions["target_subspace_contract_definition"] =
                contract.contract_definition
            representation.conventions["outer_mask_definition"] = scope.outer_mask_definition
            representation.conventions["frozen_mask_definition"] = scope.frozen_mask_definition
            representation.input_sha256["TARGET_SUBSPACE_CONTRACT_DEFINITION"] =
                contract.contract_definition
            candidate = w.ProjectionCandidateSpec(
                id = "X:s",
                specs = [
                    wp.ProjectionSpec(selector = "X", orbital_sets = "s", positions = zeros(3, 1)),
                ],
                fixed_multiplicity = 1,
                max_multiplicity = 1,
            )
            search = w.search_projection_representations(
                w.ProjectionRepresentationSearchConfig(
                    band_representation = representation,
                    target_subspace_contract = contract,
                    candidates = [candidate],
                    validate_retained_solutions = true,
                    max_results = 2,
                    max_search_nodes = 16,
                ),
            )
            @assert search.complete && !isempty(search.solutions)
            @assert all(
                solution -> solution.validation_status == w.PROJECTION_VALIDATION_PASSED,
                search.solutions,
            )
            search_file = joinpath(root, "current-projection-search.h5")
            w.write_projection_representation_search_hdf5(search_file, search)
            restored_search = w.read_projection_representation_search_hdf5(search_file)
            @assert restored_search.complete == search.complete
            @assert length(restored_search.solutions) == length(search.solutions)
            @assert all(
                isequal(restored.coefficients, original.coefficients) for
                (restored, original) in zip(restored_search.solutions, search.solutions)
            )
            template = w.WannierizationConfig(
                input = w.WannierizationInputConfig(
                    wannierization_mode = :symmetry_adapted,
                    win_file = configs.solve.input.win_file,
                    eig_file = configs.eig,
                    mmn_file = configs.mmn,
                    band_representation = representation,
                    num_wannier = 1,
                    outer_min_ev = -2.0,
                    outer_max_ev = 2.0,
                    frozen_min_ev = -2.0,
                    frozen_max_ev = -0.5,
                ),
                solver = configs.solve.solver,
                checkpoint = configs.solve.checkpoint,
                runtime = configs.solve.runtime,
                output = configs.solve.output,
            )
            materialized = w.materialize_symmetry_adapted_wannierization_config(
                template,
                search;
                solution_index = 1,
            )
            @assert materialized.input.projection_basis.num_wannier == 1
            @assert !materialized.input.projection_basis.spinor
            @assert !MPI.Initialized()
            @assert WannierNLQG.Runtime.ACTIVE_PROGRESS[] === nothing
        end
    finally
        rm(root; recursive = true)
    end
end
