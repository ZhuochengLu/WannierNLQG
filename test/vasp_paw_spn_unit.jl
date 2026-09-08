using HDF5
using LinearAlgebra
using SHA
using Test

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

        extension = first(SPN_W._load_wannierization_extension!()).PAWMatrixElements
        provenance = joinpath(directory, "synthetic.spn.provenance.h5")
        HDF5.h5open(provenance, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = "wanniernlqg.vasp-paw-spn"
            attributes["schema_version"] = "1.0"
            attributes["passed"] = true
            input_group = HDF5.create_group(handle, "input_sha256")
            HDF5.attributes(input_group)["WAVECAR"] = repeat("a", 64)
            artifacts_group = HDF5.create_group(handle, "artifacts")
            HDF5.attributes(artifacts_group)["spn"] = binary
            HDF5.attributes(artifacts_group)["spn_sha256"] = bytes2hex(SHA.sha256(read(binary)))
            handle["diagnostics"] = ["synthetic=true"]
            attributes["payload_sha256"] =
                Base.invokelatest(extension._vasp_paw_spn_provenance_payload_sha256, handle)
        end
        verified = SPN_W.read_vasp_paw_spn_provenance(provenance)
        @test verified.passed
        @test verified.artifacts["spn_sha256"] == bytes2hex(SHA.sha256(read(binary)))
        probe = joinpath(@__DIR__, "VASPPawSPNProvenanceFreshReadProbe.jl")
        command =
            `$(Base.julia_cmd()) --startup-file=no --compiled-modules=no --project=$(dirname(@__DIR__)) $(probe) $(provenance)`
        fresh = read(command, String)
        @test occursin(r"VASP_PAW_SPN_FRESH_READ_DIGEST=[0-9a-f]{64}", fresh)
        HDF5.h5open(provenance, "r+") do handle
            handle["diagnostics"][1] = "tampered=true"
        end
        @test_throws ArgumentError SPN_W.read_vasp_paw_spn_provenance(
            provenance;
            verify_spn = false,
        )
        @test_throws ArgumentError SPN_IO.write_wannier_spn(
            joinpath(directory, "unicode.spn"),
            spn;
            comment = "non-ASCII-é",
        )
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
    @test contract.transform_sha256 ==
          Base.invokelatest(extension._star_array_sha256, identity_transforms)
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
            @test String(read(attributes["transform_sha256"])) == contract.transform_sha256
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
