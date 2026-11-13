using PrecompileTools: @setup_workload, @compile_workload
using LinearAlgebra
import WannierNLQG, MPI

# One native one-band, three-k-point pipeline covers the shared source/PAW
# preparation and distinct Galerkin Hamiltonian, spin-Hamiltonian and two-link
# operator trees. Reuse real generated spin/overlap artifacts in their public
# consumers. This is compiler coverage, not an independent scientific oracle.
# All new files, bounded preparation caches and checkpoints live in mktempdir.
@setup_workload let
    assets = normpath(
        joinpath(
            @__DIR__,
            "..",
            "..",
            "test",
            "fixtures",
            "first_use_portable",
            "assets",
            "native_directory_2",
        ),
    )
    directory = mktempdir()
    try
        @compile_workload begin
            WannierNLQG._first_use_require_serial()
            w = WannierNLQG.Wannierization
            iow = WannierNLQG.IO
            source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
                joinpath(assets, "fixture.save");
                include_time_reversal = false,
            )
            topology = joinpath(assets, "fixture.nnkp")
            spin = w.generate_qe_paw_spn(
                source,
                topology;
                output_spn_file = joinpath(directory, "native.spn"),
                provenance_json = joinpath(directory, "native.spn.json"),
                max_cached_wavefunction_kpoints = 2,
            )
            @assert spin.passed
            overlaps = w.generate_qe_paw_matrix_elements(
                source,
                topology;
                artifact_dir = joinpath(directory, "overlaps"),
                require_oracle = false,
            )
            @assert all(isfinite, overlaps.mmn.data) && all(isfinite, overlaps.amn.data)
            eig = joinpath(directory, "native.eig")
            iow.write_wannier_eig(eig, iow.WannierEIG(1, 3, reshape([1.0, 2.0, 3.0], 1, 3)))
            for (generate, suffix) in (
                (w.generate_wannier_uhu, "uHu"),
                (w.generate_wannier_shu, "sHu"),
                (w.generate_wannier_siu, "sIu"),
            )
                result = generate(
                    w.WannierHamiltonianOperatorGenerationConfig(
                        source = source,
                        topology_file = topology,
                        eig_file = eig,
                        output_file = joinpath(directory, "native." * suffix),
                        spn_file = joinpath(directory, "native.spn"),
                        spn_provenance_file = joinpath(directory, "native.spn.json"),
                        max_cached_wavefunction_kpoints = 2,
                    ),
                )
                @assert result.passed && result.artifact_published
                @assert isfile(result.output_file) && isfile(result.provenance_json)
            end
            uiu_config = w.WannierUIUGenerationConfig(
                source = source,
                topology_file = topology,
                output_file = joinpath(directory, "native.uIu"),
                oracle_mmn_file = overlaps.artifacts["mmn"],
                max_cached_wavefunction_kpoints = 2,
            )
            uiu = w.generate_wannier_uiu(uiu_config)
            @assert uiu.passed && uiu.resumed_from_kpoint == 0
            nonzero = Ref(false)
            iow.foreach_wannier_uiu_block(uiu_config.output_file) do block, args...
                @assert all(isfinite, block)
                nonzero[] |= any(!iszero, block)
            end
            @assert nonzero[]
            # Public physical AMN uses the shipped one-k norm-conserving source.
            # The PAW source above is not silently treated as Euclidean overlap.
            nc_source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
                joinpath(dirname(assets), "group_8", "fixture.save");
                include_time_reversal = false,
            )
            basis = WannierNLQG.WannierProjection.WannierProjectionBasis(
                [
                    WannierNLQG.WannierProjection.WannierProjectionBlock(
                        "X",
                        "s",
                        zeros(3, 1),
                        reshape([1], 1, 1),
                        reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
                        false,
                    ),
                ],
                1,
                false,
            )
            amn = w.generate_wannier_amn(nc_source, basis)
            @assert all(isfinite, amn.data) && any(!iszero, amn.data)
            @assert !MPI.Initialized()
            @assert WannierNLQG.Runtime.ACTIVE_PROGRESS[] === nothing
        end
    finally
        rm(directory; recursive = true)
    end
end
