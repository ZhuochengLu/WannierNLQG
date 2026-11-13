if !isdefined(@__MODULE__, :CurrentScientificValues)
    include(joinpath(@__DIR__, "support/CurrentScientificValues.jl"))
end
using HDF5
using LinearAlgebra
using SHA
using Serialization
using Test
isdefined(@__MODULE__, :write_bounded_vasp_fixture) ||
    include(joinpath(@__DIR__, "VASPNativeTestSupport.jl"))

const SPN_IO = WannierNLQG.IO
const SPN_W = WannierNLQG.Wannierization

@testset "Wannier SPN deterministic binary and formatted writer" begin
    data = zeros(ComplexF64, 2, 2, 3, 2)
    for kpoint in 1:2
        data[:, :, 1, kpoint] .= ComplexF64[0 1 + 0.1im; 1 - 0.1im 0]
        data[:, :, 2, kpoint] .= ComplexF64[0 -im; im 0]
        data[:, :, 3, kpoint] .= ComplexF64[1 0.2; 0.2 -1]
    end
    spn = SPN_IO.WannierSPN(2, 2, data)
    mktempdir() do directory
        binary = joinpath(directory, "synthetic.spn")
        formatted = joinpath(directory, "synthetic.spn.fmt")
        duplicate = joinpath(directory, "synthetic-duplicate.spn")
        @test SPN_IO.write_wannier_spn(binary, spn; comment = "deterministic") == binary
        @test SPN_IO.write_wannier_spn(duplicate, spn; comment = "deterministic") == duplicate
        @test read(binary) == read(duplicate)
        raw = read(binary)
        @test raw[1:4] == UInt8[0x3c, 0x00, 0x00, 0x00]
        @test raw[69:72] == UInt8[0x08, 0x00, 0x00, 0x00]
        @test raw[73:80] == UInt8[0x02, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00]
        open(binary, "r") do io
            header = SPN_IO.read_fortran_record(io)
            @test length(header) == 60
            @test startswith(String(header), "deterministic")
        end
        restored = SPN_IO.read_wannier_spn(binary)
        @test restored.data == spn.data
        SPN_IO.write_wannier_spn(formatted, spn; formatted = true)
        restored_formatted = SPN_IO.read_wannier_spn(formatted; formatted = true)
        @test restored_formatted.data == spn.data

        # Digest-only provenance lacks the current residual/source data contract.
        # Retain it as an explicit rejection fixture, not a fabricated current PASS.
        legacy = joinpath(directory, "legacy.spn.provenance.h5")
        HDF5.h5open(legacy, "w") do handle
            HDF5.attributes(handle)["schema"] = "wanniernlqg.vasp-paw-spn"
            HDF5.attributes(handle)["schema_version"] = "1.2"
            HDF5.attributes(handle)["payload_sha256"] = repeat("0", 64)
        end
        @test_throws ArgumentError SPN_W.read_vasp_paw_spn_provenance(legacy)
        invalid = copy(data)
        invalid[1, 2, 1, 1] += 0.2
        @test_throws ArgumentError SPN_IO.write_wannier_spn(
            joinpath(directory, "nonhermitian.spn"),
            SPN_IO.WannierSPN(2, 2, invalid),
        )
    end
end

@testset "VASP PAW-SPN frame-contract HDF5 serialization" begin
    extension = first(SPN_W._load_wannierization_extension!()).PAWMatrixElements
    support = first(SPN_W._load_wannierization_extension!()).WannierizationInternalSupport
    contract = Base.invokelatest(extension._identity_band_frame_contract, 2, 1)
    identity_transforms = zeros(ComplexF64, 2, 2, 1)
    identity_transforms[:, :, 1] .= Matrix{ComplexF64}(I, 2, 2)
    @test contract.transform_definition ==
          Base.invokelatest(support.band_frame_transform_definition, identity_transforms)
    mktempdir() do directory
        filename = joinpath(directory, "frame-contract.h5")
        HDF5.h5open(filename, "w") do handle
            group = HDF5.create_group(handle, "band_frame_contract")
            Base.invokelatest(support.write_band_frame_contract_attributes!, group, contract)
        end
        HDF5.h5open(filename, "r") do handle
            attributes = HDF5.attributes(handle["band_frame_contract"])
            @test String(read(attributes["schema"])) == contract.schema
            @test String(read(attributes["schema_version"])) == contract.schema_version
            @test String(read(attributes["status"])) == "PASS"
            @test String(read(attributes["transform_definition"])) == contract.transform_definition
            @test read(attributes["physical_isometry_maximum"]) == 0.0
            @test read(attributes["minimum_singular_value"]) == 1.0
        end
    end
end

@testset "VASP PAW-SPN pseudo plus nonzero-Q oracle" begin
    extension = first(SPN_W._load_wannierization_extension!()).PAWMatrixElements
    coefficients = zeros(ComplexF64, 2, 1, 2)
    coefficients[1, 1, 1] = 1.0
    coefficients[2, 1, 2] = 1.0
    point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        reshape([0, 0, 0], 1, 3),
        coefficients,
        [-1.0, 1.0];
        normalize_coefficients = false,
    )
    projectors = zeros(ComplexF64, 2, 1, 2)
    projectors[1, 1, 1] = 0.2
    projectors[2, 1, 2] = 0.3
    pseudo, augmentation =
        Base.invokelatest(extension._vasp_paw_spn_kpoint, point, projectors, reshape([0.5], 1, 1))
    pauli = (ComplexF64[0 1; 1 0], ComplexF64[0 -im; im 0], ComplexF64[1 0; 0 -1])
    @test all(pseudo[:, :, component] == pauli[component] for component in 1:3)
    @test augmentation[:, :, 1] ≈ ComplexF64[0 0.03; 0.03 0] atol = 1.0e-16 rtol = 0.0
    @test augmentation[:, :, 2] ≈ ComplexF64[0 -0.03im; 0.03im 0] atol = 1.0e-16 rtol = 0.0
    @test augmentation[:, :, 3] ≈ ComplexF64[0.02 0; 0 -0.045] atol = 1.0e-16 rtol = 0.0
    _, augmentation_nc =
        Base.invokelatest(extension._vasp_paw_spn_kpoint, point, projectors, zeros(1, 1))
    @test iszero(augmentation_nc)
    mktempdir() do directory
        oracle = [
            Base.invokelatest(
                extension._vasp_paw_spn_kpoint,
                point,
                projectors * k,
                reshape([0.5], 1, 1),
            ) for k in 1:7
        ]
        expected_pseudo = cat((pair[1] for pair in oracle)...; dims = 4)
        expected_augmentation = cat((pair[2] for pair in oracle)...; dims = 4)
        for workers in (1, 2, 4)
            execution = SPN_W.WavefunctionPreparationExecutionConfig(
                mode = :streaming_threads,
                max_workers = workers,
                checkpoint_directory = joinpath(directory, string(workers)),
            )
            left = zeros(ComplexF64, size(expected_pseudo))
            right = similar(left)
            loads = Ref(0)
            loader = k -> (loads[] += 1; (point, projectors * k, reshape([0.5], 1, 1)))
            Base.invokelatest(
                extension._vasp_spn_blocks!,
                left,
                right,
                loader,
                "spin-fixture";
                execution,
            )
            @test loads[] == 7
            @test left == expected_pseudo
            @test right == expected_augmentation
            fill!(left, 0);
            fill!(right, 0)
            Base.invokelatest(
                extension._vasp_spn_blocks!,
                left,
                right,
                loader,
                "spin-fixture";
                execution,
            )
            @test left == expected_pseudo
            @test right == expected_augmentation
            damaged = joinpath(execution.checkpoint_directory, "vasp-spn", "block-3.bin")
            open(damaged, "a") do stream
                write(stream, UInt8(0))
            end
            loads[] = 0
            Base.invokelatest(
                extension._vasp_spn_blocks!,
                left,
                right,
                loader,
                "spin-fixture";
                execution,
            )
            @test loads[] == 7
            @test left == expected_pseudo && right == expected_augmentation
        end
    end

    scalar_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        reshape([0, 0, 0], 1, 3),
        ones(ComplexF64, 1, 1, 1),
        [0.0];
        normalize_coefficients = false,
    )
    @test_throws ArgumentError Base.invokelatest(
        extension._vasp_paw_spn_kpoint,
        scalar_point,
        ones(ComplexF64, 1, 1, 1),
        zeros(1, 1),
    )
end

@testset "VASP PAW-SPN public preflight fails closed" begin
    @test_throws ArgumentError SPN_W.VASPPAWSPNThresholds(hermiticity_max_absolute = 0.0)
    missing_potcar = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
        "POSCAR",
        "WAVECAR";
        band_range = 1:2,
        spinor = true,
        spin_basis_saxis = (0.0, 0.0, 1.0),
    )
    @test_throws ArgumentError SPN_W.generate_vasp_paw_spn(
        missing_potcar;
        output_spn_file = "x.spn",
        provenance_hdf5 = "x.h5",
        spin_channel = 1,
    )
    cutoff_source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
        "POSCAR",
        "WAVECAR";
        potcar_file = "POTCAR",
        band_range = 1:2,
        spinor = true,
        spin_basis_saxis = (0.0, 0.0, 1.0),
        representation_cutoff_ev = 100.0,
    )
    @test_throws ArgumentError SPN_W.generate_vasp_paw_spn(
        cutoff_source;
        output_spn_file = "x.spn",
        provenance_hdf5 = "x.h5",
        spin_channel = 1,
    )
    @test_throws UndefKeywordError SPN_W.generate_vasp_paw_spn(
        cutoff_source;
        output_spn_file = "x.spn",
        provenance_hdf5 = "x.h5",
    )
    @test_throws ArgumentError SPN_W.generate_vasp_paw_spn(
        cutoff_source;
        output_spn_file = "x.spn",
        provenance_hdf5 = "x.h5",
        spin_channel = 2,
    )
end

@testset "VASP public SPN binary source and fresh block resume" begin
    mktempdir() do directory
        poscar, wavecar, _ = write_bounded_vasp_fixture(directory, 2, ComplexF64)
        potcar = joinpath(directory, "POTCAR")
        # Match the existing native-resolver fixture: identical AE/pseudo waves
        # imply q=0, and orthonormal spinors give the exact Pauli matrices. This
        # is a native publication/readback fixture, not a nonzero-Q PAW oracle;
        # that independent oracle is retained in the preceding testset.
        write(
            potcar,
            replace(synthetic_potcar_block("X"; q0 = 0.0), "0.12 0.22 0.32" => "0.10 0.20 0.30"),
        )
        open(wavecar, "r+") do stream
            for kpoint in 1:2, band in 1:2
                coefficients = zeros(ComplexF64, 2kpoint)
                coefficients[1 + (band - 1) * kpoint] = 1
                seek(stream, 512 * (2 + (kpoint - 1) * 3 + band))
                write(stream, coefficients)
            end
        end
        source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            poscar,
            wavecar;
            potcar_file = potcar,
            band_range = 1:2,
            spinor = true,
            spin_basis_saxis = (0.0, 0.0, 1.0),
            include_time_reversal = false,
        )
        execution = SPN_W.WavefunctionPreparationExecutionConfig(
            mode = :streaming_threads,
            max_workers = 4,
            checkpoint_directory = joinpath(directory, "checkpoint"),
        )
        output = joinpath(directory, "native.spn")
        provenance = joinpath(directory, "native.spn.h5")
        generated = SPN_W.generate_vasp_paw_spn(
            source;
            output_spn_file = output,
            provenance_hdf5 = provenance,
            spin_channel = 1,
            execution,
        )
        @test generated.radial_q_max_absolute == 0.0
        @test generated.generalized_norm_max_absolute == 0.0
        @test generated.hermiticity_max_absolute == 0.0
        @test generated.diagonal_imaginary_max_absolute == 0.0
        pauli = (ComplexF64[0 1; 1 0], ComplexF64[0 -im; im 0], ComplexF64[1 0; 0 -1])
        published_spin = SPN_IO.read_wannier_spn(output).data
        @test size(published_spin) == (2, 2, 3, 2)
        for kpoint in 1:2, component in 1:3
            @test published_spin[:, :, component, kpoint] == pauli[component]
        end
        verified = SPN_W.read_vasp_paw_spn_provenance(provenance)
        # Every numerical residual remains mandatory even when byte reference
        # verification is disabled. Use independent copies and reopen after the
        # mutation so an old attribute handle cannot mask a failed write.
        limits = SPN_W.VASPPAWSPNThresholds()
        for field in (
            :radial_q_max_absolute,
            :generalized_norm_max_absolute,
            :hermiticity_max_absolute,
            :diagonal_imaginary_max_absolute,
        )
            key = String(field)
            bad_value = 2 * getfield(limits, field)
            bad_path = joinpath(directory, "invalid-" * key * ".h5")
            cp(provenance, bad_path)
            HDF5.h5open(bad_path, "r+") do handle
                @test read(HDF5.attributes(handle)[key]) == 0.0
                HDF5.delete_attribute(handle, key)
                HDF5.attributes(handle)[key] = bad_value
            end
            HDF5.h5open(bad_path, "r") do handle
                @test read(HDF5.attributes(handle)[key]) == bad_value
            end
            for verify_spn in (true, false)
                failure = try
                    SPN_W.read_vasp_paw_spn_provenance(bad_path; verify_spn)
                    nothing
                catch exception
                    exception
                end
                @test failure isa ArgumentError
                @test failure isa ArgumentError &&
                      occursin("SPN_RESIDUAL_EXCEEDED: " * key, sprint(showerror, failure))
            end
        end
        HDF5.h5open(provenance, "r") do handle
            for field in (
                :radial_q_max_absolute,
                :generalized_norm_max_absolute,
                :hermiticity_max_absolute,
                :diagonal_imaginary_max_absolute,
            )
                @test read(HDF5.attributes(handle)[String(field)]) == 0.0
            end
        end
        @test verified.content_authentication == "NOT_PERFORMED"
        @test verified.num_bands == 2
        @test verified.num_kpoints == SPN_IO.read_wannier_spn(output).num_kpts
        probe = joinpath(@__DIR__, "VASPPawSPNProvenanceFreshReadProbe.jl")
        fresh = read(
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) $(probe) $(provenance)`,
            String,
        )
        @test occursin("VASP_PAW_SPN_FRESH_READ_PASS", fresh)
        tampered = joinpath(directory, "native-spn-tampered.h5")
        cp(provenance, tampered)
        HDF5.h5open(tampered, "r+") do handle
            HDF5.delete_attribute(handle, "band_frame_contract_definition")
        end
        @test_throws ArgumentError SPN_W.read_vasp_paw_spn_provenance(tampered; verify_spn = false)
        original = SPN_IO.read_wannier_spn(output).data
        digest = bytes2hex(open(SHA.sha256, output))
        input = joinpath(directory, "resume.bin")
        open(input, "w") do stream
            Serialization.serialize(stream, (; source, execution, output, provenance, digest))
        end
        script = joinpath(directory, "resume.jl")
        write(
            script,
            raw"""
using WannierNLQG, Serialization, SHA
WannierNLQG.Wannierization._load_wannierization_extension!()
# Current publication owns fresh point blocks. This is a full native recompute,
# not adoption of the removed digest-only compact publication receipt.
input = open(Serialization.deserialize, ARGS[1])
WannierNLQG.Wannierization.generate_vasp_paw_spn(input.source;
    output_spn_file = input.output, provenance_hdf5 = input.provenance,
    spin_channel = 1, execution = input.execution)
@assert bytes2hex(open(SHA.sha256, input.output)) == input.digest
println("PUBLIC_VASP_SPN_FRESH_PUBLICATION_PASS ", input.digest)
""",
        )
        resumed = read(
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) $(script) $(input)`,
            String,
        )
        print(resumed)
        @test occursin("PUBLIC_VASP_SPN_FRESH_PUBLICATION_PASS", resumed)
        @test SPN_IO.read_wannier_spn(output).data == original
        @test bytes2hex(open(SHA.sha256, output)) == digest
    end
end

@testset "SPN fresh block ownership preserves full tensors without compact receipts" begin
    extension=first(SPN_W._load_wannierization_extension!()).PAWMatrixElements
    pseudo=reshape(ComplexF64.(collect(1:24) ./ 7, reverse(collect(1:24)) ./ 11), 2, 2, 3, 2)
    augmentation=reverse(pseudo; dims = 1) ./ 13
    total, hermiticity, diagonal, norms=extension._vasp_paw_spn_diagnostics(pseudo, augmentation)
    for kind in (:qe, :vasp)
        mktempdir() do directory
            # Pure ownership/storage fixture: no native source or DFT generation
            # is represented by this generic wrapper test. Native public routes
            # remain exercised by the real generator tests above and QE tests.
            config=(source = nothing,)
            paths=(
                output = joinpath(directory, "spin.spn"),
                provenance = joinpath(directory, "spin.h5"),
            )
            execution=SPN_W.WavefunctionPreparationExecutionConfig(
                mode = :streaming_serial,
                max_workers = 1,
                memory_budget_bytes = 64*1024^2,
                checkpoint_directory = directory,
                resume = true,
            )
            result=kind==:qe ?
                   SPN_W.QEPAWSPNResult(
                SPN_IO.WannierSPN(2, 2, total),
                nothing,
                0.0,
                hermiticity,
                diagonal,
                false,
                "codec-fixture",
                Dict{String, String}(),
                Dict{String, String}(),
                ["codec-fixture"],
            ) :
                   SPN_W.VASPPAWSPNResult(
                SPN_IO.WannierSPN(2, 2, total),
                nothing,
                0.0,
                0.0,
                hermiticity,
                diagonal,
                false,
                ["codec-fixture"],
                norms,
                Dict{String, String}(),
                Dict{String, String}(),
            )
            roots=String[];
            calls=Ref(0)
            for _ in 1:2
                restored=extension._with_spn_publication_receipt(
                    config,
                    paths,
                    String[];
                    execution,
                ) do effective
                    calls[]+=1
                    @test effective.resume===false
                    push!(roots, effective.checkpoint_directory)
                    for k in 1:2
                        payload=kind==:qe ?
                                (total[:, :, :, k], pseudo[:, :, :, k], augmentation[:, :, :, k]) :
                                (pseudo[:, :, :, k], augmentation[:, :, :, k])
                        SPN_IO.write_preparation_checkpoint(
                            joinpath(effective.checkpoint_directory, "spin", "block-$k.bin"),
                            "actual-spin-values:$k",
                            payload,
                        )
                    end
                    extension._record_spn_publication_blocks(
                        kind,
                        effective,
                        "spin",
                        "actual-spin-values",
                        2,
                    )
                    return result
                end
                @test reinterpret(UInt8, vec(restored.spn.data))==reinterpret(UInt8, vec(total))
                @test restored.diagnostics==result.diagnostics && !restored.passed
            end
            @test calls[]==2 && roots[1]!=roots[2]
            for root in roots
                blocks=[
                    SPN_IO.read_preparation_checkpoint(
                        joinpath(root, "spin", "block-$k.bin"),
                        "actual-spin-values:$k",
                    ) for k in 1:2
                ]
                recovered=if kind==:qe
                    cat((block[1] for block in blocks)...; dims = 4)
                else
                    left=cat((block[1] for block in blocks)...; dims = 4)
                    right=cat((block[2] for block in blocks)...; dims = 4)
                    first(extension._vasp_paw_spn_diagnostics(left, right))
                end
                @test reinterpret(UInt8, vec(recovered))==reinterpret(UInt8, vec(total))
                path=joinpath(root, "spin", "block-1.bin")
                open(io->write(io, "corrupted"), path, "a")
                @test SPN_IO.read_preparation_checkpoint(path, "actual-spin-values:1")===nothing
            end
        end
    end
end
