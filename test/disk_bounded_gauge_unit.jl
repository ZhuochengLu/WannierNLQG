module DiskBoundedGaugeUnitTests

using WannierNLQG, HDF5, Test, LinearAlgebra, SHA
include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
using .QEPAWMatrixElementsTestSupport
const DW = WannierNLQG.Wannierization
const DP = first(DW._load_wannierization_extension!()).PAWMatrixElements
const DI = WannierNLQG.IO
function run_disk_bounded_test(directory)
    @testset "QE contract 1.11 bounded readback" begin
        fixture = write_qe_paw_fixture(
            joinpath(directory, "input");
            metric_kind = :norm_conserving,
            spinor = false,
            spinorbit = false,
        )
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            band_range = 1:1,
            include_time_reversal = false,
        )
        file = joinpath(directory, "gauge.h5")
        prepared = DW.prepare_symmetry_covariant_wavefunctions(
            DW.SymmetryCovariantWavefunctionPreparationConfig(
                construction_policy = :standard,
                source = source,
                wavefunction_gauge_backend = DW.StarCovariantPAWGauge(
                    buffer_policy = DW.ClosureDrivenBandBuffer(max_extra_bands = 0),
                ),
                output_hdf5 = file,
                target_band_count = 1,
            ),
        )
        @test prepared.status in (:PASS, :STANDARD)
        file = something(prepared.output_hdf5)
        oracle = DI.with_preparation_storage(joinpath(directory, "oracle")) do
            task_local_storage(:qe_disk_bounded_gauge, false) do
                DP._read_star_covariant_paw_gauge_hdf5_impl(
                    file;
                    construction_policy = :standard,
                    source = source,
                )
            end
        end
        bounded = DI.with_preparation_storage(joinpath(directory, "bounded")) do
            DP._read_star_covariant_paw_gauge_hdf5(
                file;
                construction_policy = :standard,
                source = source,
            )
        end
        @test DP._qe_bounded_contract(file)
        @test bounded.diagnostics == oracle.diagnostics
        @test DP._star_payload_sha256(bounded.payload) == DP._star_payload_sha256(oracle.payload)
        @test DP._star_metric_sha256(bounded.payload.metric) ==
              DP._star_metric_sha256(oracle.payload.metric)
        for k in [1, 1, 1]
            @test isequal(
                bounded.payload.native.kpoints[k].coefficients,
                oracle.payload.native.kpoints[k].coefficients,
            )
            @test isequal(
                bounded.payload.metric.projector_bases[k],
                oracle.payload.metric.projector_bases[k],
            )
        end
        @test !any(
            occursin("frames-", d) ||
            occursin("projector-bases-", d) ||
            occursin("sealed-representatives-", d) for
            (d, _, _) in walkdir(joinpath(directory, "bounded"))
        )
        old_matrices = DI.with_preparation_storage(joinpath(directory, "matrix-oracle")) do
            DP._generate_symmetry_completed_qe_paw_matrix_elements_impl(
                source,
                file,
                fixture.nnkp_file;
                artifact_dir = joinpath(directory, "matrix-oracle-output"),
                qualification_mode = :standard,
            )
        end
        new_matrices = DI.with_preparation_storage(joinpath(directory, "matrix-bounded")) do
            DP.generate_symmetry_completed_qe_paw_matrix_elements(
                source,
                file,
                fixture.nnkp_file;
                artifact_dir = joinpath(directory, "matrix-bounded-output"),
                qualification_mode = :standard,
            )
        end
        @test isequal(old_matrices.mmn.data, new_matrices.mmn.data)
        @test isequal(old_matrices.amn.data, new_matrices.amn.data)
        @test old_matrices.diagnostics == new_matrices.diagnostics
        for spinorbit in (false, true)
            lane = joinpath(directory, "paw-" * string(spinorbit))
            pawfixture = write_qe_paw_fixture(
                lane;
                metric_kind = :paw,
                num_kpoints = 3,
                spinor = spinorbit,
                spinorbit = spinorbit,
            )
            pawsource = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
                pawfixture.save_directory;
                include_time_reversal = false,
            )
            dense = DP._read_augmentation_aware_native_source(pawsource)
            metric, residual, worst = DP._strict_sewing_metric(pawsource, dense)
            lazy, lm, lr, lw = task_local_storage(:qe_disk_bounded_gauge, true) do
                n=DP._read_augmentation_aware_native_source(pawsource)
                m, r, w=DP._strict_sewing_metric(pawsource, n)
                (n, m, r, w)
            end
            @test residual == lr && worst == lw
            @test DP._star_metric_sha256(metric) == DP._star_metric_sha256(lm)
            @test isequal(metric.projectors[1], lm.projectors[1])
            @test isequal(metric.projector_bases[1], lm.projector_bases[1])
            nnkp=DP.read_wannier_nnkp(pawfixture.nnkp_file)
            amn,
            diag=DP._qe_generate_amn(
                dense,
                nnkp,
                metric.projectors,
                metric.projector_bases,
                metric.upf_data,
                metric.plan,
                metric.spinorbit,
            )
            la,
            ld=DP._qe_generate_amn(
                lazy,
                nnkp,
                lm.projectors,
                lm.projector_bases,
                lm.upf_data,
                lm.plan,
                lm.spinorbit,
            )
            @test isequal(amn.data, la.data) && isequal(diag, ld)
            mmn,
            diag=DP._qe_generate_mmn(
                dense,
                nnkp,
                metric.projectors,
                metric.upf_data,
                metric.plan,
                metric.spinorbit,
            )
            lmdata,
            ld=DP._qe_generate_mmn(lazy, nnkp, lm.projectors, lm.upf_data, lm.plan, lm.spinorbit)
            @test isequal(mmn.data, lmdata.data) && isequal(diag, ld)
            for k in (3, 1, 2, 3, 3)
                @test isequal(metric.projector_bases[k], lm.projector_bases[k])
                @test isequal(metric.projectors[k], lm.projectors[k])
            end
            rotations = reshape(ComplexF64[cis(0.1*k) for k in 1:3], 1, 1, 3)
            energies = reduce(hcat, (point.energies_ev for point in dense.kpoints))
            old_replay = DP._star_replay_local_completed_frame(dense, metric, rotations, energies)
            new_replay = task_local_storage(:qe_disk_bounded_gauge, true) do
                DP._star_replay_local_completed_frame(lazy, lm, rotations, energies)
            end
            A = DP._SymmetrizedDFTHamiltonianAuditPayload
            fields = map(fieldtypes(A)) do T
                Nothing <: T ? nothing : zeros(eltype(T), ntuple(_ -> 0, ndims(T)))
            end
            fields = collect(fields)
            fields[2] = energies
            fields[3] = rotations
            audit = A(fields...)
            old_parent = DP._star_completed_parent_native(dense, audit)
            new_parent = task_local_storage(:qe_disk_bounded_gauge, true) do
                DP._star_completed_parent_native(lazy, audit)
            end
            for k in (3, 1, 2, 3, 3)
                @test isequal(old_replay.points[k].coefficients, new_replay.points[k].coefficients)
                @test isequal(
                    old_parent.kpoints[k].coefficients,
                    new_parent.kpoints[k].coefficients,
                )
            end
            # Mutation is detected on a cached basis hit, not only a new source load.
            sourcepath=DP.qe_wavefunction_file(pawsource, 1)
            open(sourcepath, "a") do io
                write(io, UInt8(0))
            end
            @test_throws ArgumentError lm.projector_bases[1]
        end
        # Standalone guarded provider: non-monotonic access, cache hits and mutation.
        path=joinpath(directory, "guard.bin");
        write(path, "one")
        guard=DP._qe_stat_guard(path)
        values=DI.preparation_source_vector(k -> fill(ComplexF64(k), 2, 2), Matrix{ComplexF64}, 3)
        guarded=DP._qe_guarded(values, guard)
        for k in (3, 1, 2, 3, 3)
            @test guarded[k] == fill(ComplexF64(k), 2, 2)
        end
        write(path, "changed")
        @test_throws ArgumentError guarded[3]
        # HDF5 producer handle is already closed; late payload hashing still succeeds.
        @test length(DP._star_payload_sha256(bounded.payload)) == 64
        HDF5.h5open(file, "r+") do h
            HDF5.attributes(h)["test_mutation"]="changed"
        end
        @test_throws ArgumentError DP._star_payload_sha256(bounded.payload)
    end

    println("SMALL_FIXTURE_PEAK_RSS_BYTES=", Sys.maxrss())
    println(
        "SMALL_FIXTURE_RETAINED_BYTES=",
        sum(stat(joinpath(d, n)).size for (d, _, files) in walkdir(directory) for n in files),
    )
end

if haskey(ENV, "DISK_BOUNDED_TEST_ATTEMPT")
    run_disk_bounded_test(ENV["DISK_BOUNDED_TEST_ATTEMPT"])
else
    mktempdir(run_disk_bounded_test)
end

end # module DiskBoundedGaugeUnitTests
