using Test, LinearAlgebra, HDF5
include("NativeTopologyStencilReference.jl")
include("QEPAWMatrixElementsTestSupport.jl")
using .QEPAWMatrixElementsTestSupport
const NATIVE_TOPOLOGY_IO = WannierNLQG.IO
const NATIVE_TOPOLOGY_ME = WannierNLQG.MatrixElements
@testset "owned actual-point topology reuses archived stencil mechanism" begin
    for real in (Matrix{Float64}(I, 3, 3), [2.0 0.3 0.1; 0.0 1.8 0.2; 0.1 0.0 2.1]),
        offset in (0.0, 0.25)

        reciprocal = 2pi * inv(transpose(real))
        points = [0.5+offset 0.0 0.0; offset 0.0 0.0]
        chk = NATIVE_TOPOLOGY_IO.WannierCHK(
            1,
            1,
            2,
            (2, 1, 1),
            points,
            real,
            reciprocal,
            zeros(1, 3),
            ones(ComplexF64, 1, 1, 2),
        )
        old = NativeTopologyStencilReference.build_finite_difference_stencil(chk)
        direct = NATIVE_TOPOLOGY_ME.build_finite_difference_stencil(reciprocal, (2, 1, 1), points)
        wrapped = NATIVE_TOPOLOGY_ME.build_finite_difference_stencil(chk)
        for field in fieldnames(typeof(old))
            @test isequal(getfield(old, field), getfield(direct, field))
            @test isequal(getfield(old, field), getfield(wrapped, field))
        end
        moment = zeros(3, 3)
        for b in eachindex(direct.weights)
            v=direct.displacement_cartesian[b, :]
            moment .+= direct.weights[b] .* (v*v')
            for k in axes(points, 1)
                target=direct.neighbors[b, k]
                @test isapprox(
                    reciprocal'*(points[target, :]+direct.reciprocal_shifts[:, b, k]-points[k, :]),
                    v;
                    atol = 1e-12,
                    rtol = 0,
                )
            end
        end
        @test isapprox(moment, Matrix{Float64}(I, 3, 3); atol = 1e-5, rtol = 0)
    end
    reciprocal=2pi*Matrix{Float64}(I, 3, 3)
    @test_throws Exception NATIVE_TOPOLOGY_ME.build_finite_difference_stencil(
        reciprocal,
        (2, 1, 1),
        zeros(2, 3),
    )
    @test_throws Exception NATIVE_TOPOLOGY_ME.build_finite_difference_stencil(
        reciprocal,
        (2, 1, 1),
        [0.0 0 0; 0.4 0 0],
    )
    @test_throws ArgumentError NATIVE_TOPOLOGY_ME.build_finite_difference_stencil(
        reciprocal,
        (0, 1, 1),
        zeros(1, 3),
    )
end
@testset "native owned QE topology and same-selected-source energies" begin
    mktempdir() do directory
        fixture=write_qe_paw_fixture(directory)
        source=WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            include_time_reversal = false,
        )
        file_contract=NATIVE_TOPOLOGY_IO.read_wannier_nnkp(fixture.nnkp_file)
        owned=NATIVE_TOPOLOGY_IO.owned_wannier_topology(file_contract)
        @test owned.source_sha256 != file_contract.source_sha256
        @test owned.source_sha256 == NATIVE_TOPOLOGY_IO.owned_wannier_topology(owned).source_sha256
        @test owned.kpoints_fractional !== file_contract.kpoints_fractional
        @test owned.neighbors !== file_contract.neighbors
        @test owned.projections !== file_contract.projections
        original=WannierNLQG.Wannierization.generate_qe_paw_matrix_elements(
            source,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "file"),
            require_oracle = false,
        )
        rm(fixture.nnkp_file)
        generated=WannierNLQG.Wannierization.generate_qe_paw_matrix_elements(
            source,
            owned;
            artifact_dir = joinpath(directory, "owned"),
            require_oracle = false,
        )
        @test original.passed && generated.passed
        @test isequal(original.mmn.data, generated.mmn.data)
        @test isequal(original.amn.data, generated.amn.data)
        @test isequal(original.mmn.neighbors, generated.mmn.neighbors)
        @test isequal(original.mmn.reciprocal_shifts, generated.mmn.reciprocal_shifts)
        @test original.generalized_norm_max_absolute == generated.generalized_norm_max_absolute
        @test generated.input_sha256["NNKP"] == owned.source_sha256
        @test all(isfile, values(generated.artifacts))
        native=first(WannierNLQG.Wannierization._load_wannierization_extension!()).RepresentationPreparation.read_qe_raw_wavefunctions(
            source,
        )
        eig=NATIVE_TOPOLOGY_IO.read_wannier_eig(generated.artifacts["eig"])
        @test isequal(eig.data[:, 1], native.kpoints[1].energies_ev)
        @test isequal(eig.data, NATIVE_TOPOLOGY_IO.read_wannier_eig(original.artifacts["eig"]).data)
        original_digest=owned.source_sha256
        file_contract.kpoints_fractional[1, 1]=0.25
        @test owned.kpoints_fractional[1, 1] == 0
        @test owned.source_sha256 == original_digest
        malformed=deepcopy(owned);
        malformed.neighbors[1, 1]=2
        @test_throws ArgumentError NATIVE_TOPOLOGY_IO.owned_wannier_topology(malformed)
        changed=deepcopy(owned);
        changed.reciprocal_shifts[1, 1, 1]=1
        @test NATIVE_TOPOLOGY_IO.owned_wannier_topology(changed).source_sha256 != original_digest
    end
end
