# Exercise only bounded, in-memory public representation/configuration constructors.
# No solver, backend loader, file, MPI call, or persistent workspace is created.
@compile_workload let
    if FIRST_USE_WORKLOAD_ENABLED
        scope = SymmetryFoundation.BandRepresentationQualificationScope(trues(1, 1), trues(1, 1))
        contract = Wannierization.TargetSubspaceQualificationContract(
            scope;
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = 0.0,
            num_wannier = 1,
        )
        operation = SymmetryFoundation.SymmetryOperation(
            Matrix{Int}(LinearAlgebra.I, 3, 3),
            zeros(3),
            Matrix{Float64}(LinearAlgebra.I, 3, 3),
        )
        representation = SymmetryFoundation.BandRepresentation(
            "1.17",
            :synthetic,
            false,
            Matrix{Float64}(LinearAlgebra.I, 3, 3),
            2.0pi .* Matrix{Float64}(LinearAlgebra.I, 3, 3),
            (1, 1, 1),
            zeros(1, 3),
            reshape([-1.0], 1, 1),
            [operation],
            ones(Int, 1, 1),
            zeros(Int, 3, 1, 1),
            ones(ComplexF64, 1, 1, 1, 1),
            ones(Int, 1, 1),
            [1],
            [1],
            [1];
            conventions = Dict(
                "target_subspace_contract_sha256" => contract.contract_sha256,
                "outer_mask_sha256" => scope.outer_mask_sha256,
                "frozen_mask_sha256" => scope.frozen_mask_sha256,
            ),
            input_sha256 = Dict("TARGET_SUBSPACE_CONTRACT_SHA256" => contract.contract_sha256),
        )
        spec = WannierProjection.ProjectionSpec(
            selector = "X",
            orbital_sets = "s",
            positions = zeros(3, 1),
        )
        candidate = Wannierization.ProjectionCandidateSpec(
            id = "X:s",
            specs = [spec],
            fixed_multiplicity = 1,
            max_multiplicity = 1,
        )
        config = Wannierization.ProjectionRepresentationSearchConfig(
            band_representation = representation,
            target_subspace_contract = contract,
            candidates = [candidate],
        )
        @assert !MPI.Initialized()
    end
end
