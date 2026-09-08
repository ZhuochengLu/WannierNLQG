using Test, WannierNLQG, HDF5, JSON3, EzXML, Spglib, LinearAlgebra
isdefined(Main, :QEPAWMatrixElementsTestSupport) || include("QEPAWMatrixElementsTestSupport.jl")
isdefined(Main, :BandPublicSchemaTestSupport) || include("BandPublicSchemaTestSupport.jl")

@testset "Diagnostic augmentation sewing quality and hard boundaries" begin
    w = WannierNLQG.Wannierization
    foundation = WannierNLQG.SymmetryFoundation
    extension = first(w._load_wannierization_extension!())
    paw = extension.PAWMatrixElements
    preparation = extension.RepresentationPreparation
    identity =
        foundation.SymmetryOperation(Matrix{Int}(I, 3, 3), zeros(3), Matrix{Float64}(I, 3, 3))
    mktempdir() do directory
        fixture = QEPAWMatrixElementsTestSupport.write_qe_paw_fixture(directory)
        source = foundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            include_time_reversal = false,
        )
        native = Base.invokelatest(paw._read_augmentation_aware_native_source, source)
        energies = reshape(copy(only(native.kpoints).energies_ev), 1, 1)
        build(native; policy = :diagnostic, energies = energies) = Base.invokelatest(
            preparation._build_band_representation,
            native,
            energies,
            [identity],
            1e-8;
            source,
            sewing_backend = w.AugmentationAwareSewing(),
            construction_policy = policy,
            return_diagnostics = true,
        )
        exact_strict = build(native; policy = :strict)
        exact_diagnostic = build(native)
        @test exact_strict.representation.sewing_matrices ==
              exact_diagnostic.representation.sewing_matrices
        @test all(
            row -> row["context"]["gate_result"] == "PASS",
            JSON3.read(exact_diagnostic.representation.conventions["paw_sewing_gate_records_json"]),
        )
        @test_throws ArgumentError build(native; policy = :unknown)
        # Perturb the actual native file before rereading, so source hashes bind the changed coefficients.
        h5open(joinpath(fixture.save_directory, "wfc1.hdf5"), "r+") do f
            write(f["evc"], 1.01 .* read(f["evc"]))
        end
        perturbed = Base.invokelatest(paw._read_augmentation_aware_native_source, source)
        @test_throws ArgumentError build(perturbed; policy = :strict)
        diagnostic = build(perturbed)
        gates = JSON3.read(
            diagnostic.representation.conventions["paw_sewing_gate_records_json"],
            Vector{Dict{String, Any}},
        )
        failed = filter(row -> row["context"]["gate_result"]=="FAIL", gates)
        @test !isempty(failed)
        @test any(row -> row["context"]["metric"]=="generalized_norm", failed)
        @test any(row -> row["context"]["metric"]=="raw_unitarity", failed)
        @test any(row -> row["context"]["metric"]=="normalized_polar_correction", failed)
        @test all(row -> row["context"]["action"]=="CONTINUE_DIAGNOSTIC", failed)
        @test all(
            row -> all(
                haskey(row["context"], name) for
                name in ("stage", "value", "threshold", "worst_context")
            ),
            gates,
        )
        @test diagnostic.representation.sewing_matrices ==
              exact_strict.representation.sewing_matrices
        output = joinpath(directory, "diagnostic-sewing.h5")
        prepared = BandPublicSchemaTestSupport.prepare_public_band_fixture(
            diagnostic.representation;
            directory,
            projection_basis = BandPublicSchemaTestSupport.single_site_s_basis(),
            sewing_backend = w.AugmentationAwareSewing(),
            output_hdf5 = output,
        )
        @test count(d -> d.code==:PAW_SEWING_QUALITY_CHECK, prepared.diagnostics) == length(gates)
        restored = foundation.read_band_representation_hdf5(output)
        @test restored.conventions["paw_sewing_gate_records_json"] ==
              diagnostic.representation.conventions["paw_sewing_gate_records_json"]
        @test any(
            d -> d.code==:PAW_SEWING_QUALITY_CHECK && get(d.context, "gate_result", "")=="FAIL",
            prepared.diagnostics,
        )
        # Source/EIG disagreement remains an identity failure under diagnostic policy.
        @test_throws ArgumentError build(perturbed; energies = energies .+ 1.0)
        singular = deepcopy(perturbed);
        only(singular.kpoints).coefficients .= 0
        @test_throws ArgumentError build(singular)
        nonfinite = deepcopy(perturbed);
        only(nonfinite.kpoints).coefficients .= NaN
        @test_throws ArgumentError build(nonfinite)
    end
    records = Dict{String, Any}[]
    @test_throws ArgumentError Base.invokelatest(
        paw._paw_sewing_quality_gate!,
        records,
        false,
        "quality",
        Inf,
        1e-8,
    )
    @test_throws ArgumentError Base.invokelatest(
        paw._strict_reciprocal_shift_cocycle_gate,
        1.0,
        1e-5,
    )
    @test_throws ArgumentError Base.invokelatest(paw._paw_sewing_required_polar_rank, [1.0, 0.0], 2)
    masks = [BitVector([true]), BitVector([true])]
    mapped = reshape([2, 1], 1, 2)
    @test_throws ArgumentError Base.invokelatest(
        paw._strict_validate_target_subspace_contract,
        masks,
        masks,
        [-1.0 -0.9],
        mapped,
        1e-8,
    )
    finite_mismatch = Base.invokelatest(
        paw._strict_validate_target_subspace_contract,
        masks,
        masks,
        [-1.0 -0.9],
        mapped,
        1e-8;
        enforce_thresholds = false,
    )
    @test finite_mismatch.target_energy_residual ≈ 0.1
    @test_throws ArgumentError Base.invokelatest(
        paw._strict_validate_target_subspace_contract,
        [BitVector([true]), BitVector([false])],
        masks,
        [-1.0 -0.9],
        mapped,
        1e-8;
        enforce_thresholds = false,
    )
end
