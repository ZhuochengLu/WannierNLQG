using Test
module ScanFixture
module IO
using Printf
include("../src/IO/SpinReaders.jl")
include("../src/IO/WannierUIU.jl")
include("../src/IO/WannierHamiltonianOperatorFiles.jl")
include("../src/IO/ScientificSourceFiles.jl")
end
source = read(
    joinpath(@__DIR__, "..", "ext", "WannierNLQGWannierizationExt", "OperatorProfileAssembly.jl"),
    String,
)
start = findfirst("function _scan_completed_operator_pair", source)
stop = findnext("\nend\n\n\"\"\"Validate existing", source, first(start))
eval(Meta.parse(source[first(start):(first(stop) + 3)]))
Base.@kwdef struct OperatorTask
    quantity::Symbol
end
replace_wannierization_config(config; output) = config
function _preflight_wannierization_operator_profile(config, eig, mmn, target; native_source_files)
    native_source_files == Dict("WAVECAR" => "matched") ||
        throw(ArgumentError("SCIENTIFIC_SOURCE_COLLECTION_MISMATCH"))
    return Dict("status" => "PASS")
end
start2 = findfirst("function _validate_completed_operator_pair", source)
stop2 = findnext("\nend\n\n\"\"\"", source, first(start2))
eval(Meta.parse(source[first(start2):(first(stop2) + 3)]))
start3 = findfirst("function _validate_completed_operator_set", source)
stop3 = findnext("\nend\n\n\"\"\"", source, first(start3))
eval(Meta.parse(source[first(start3):(first(stop3) + 3)]))
end

@testset "complete operator scan" begin
    mktempdir() do dir
        ui = joinpath(dir, "test.uIu")
        hu = joinpath(dir, "test.uHu")
        i = ScanFixture.IO
        i.write_wannier_uiu(ui, i.WannierUIUHeader("uiu", 2, 1, 1), (_...) -> ComplexF64[1 2; 3 4])
        i.write_wannier_uhu(hu, i.WannierUHUHeader("uhu", 2, 1, 1), (_...) -> ComplexF64[4 3; 2 1])
        dims = (; num_bands = 2, num_kpts = 1, num_neighbors = 1)
        @test ScanFixture._scan_completed_operator_pair(ui, hu, dims, false) === nothing
        up = joinpath(dir, "uiu.json");
        hp = joinpath(dir, "uhu.json")
        write(up, "fixture");
        write(hp, "fixture")
        config = (;
            output = (;
                uiu_file = ui,
                uhu_file = hu,
                uiu_provenance_json = up,
                uhu_provenance_json = hp,
                operator_files_formatted = false,
            )
        )
        @test ScanFixture._validate_completed_operator_pair(
            config,
            nothing,
            dims,
            nothing,
            Dict("WAVECAR" => "matched"),
        ) === nothing
        @test_throws ArgumentError ScanFixture._validate_completed_operator_pair(
            config,
            nothing,
            dims,
            nothing,
            Dict("WAVECAR" => "changed"),
        )
        @test_throws Exception ScanFixture._scan_completed_operator_pair(
            ui,
            hu,
            (; dims..., num_kpts = 2),
            false,
        )
        data = read(ui)
        open(ui, "w") do io
            ;
            write(io, data[1:(end - 1)]);
        end
        @test_throws Exception ScanFixture._scan_completed_operator_pair(ui, hu, dims, false)
        write(ui, data)
        open(ui, "r+") do io
            i._read_wannier_uiu_header(io, ui)
            seek(io, position(io) + 4)
            write(io, NaN)
        end
        @test_throws ArgumentError ScanFixture._scan_completed_operator_pair(ui, hu, dims, false)
        write(ui, data)
        hdata = read(hu)
        open(hu, "r+") do io
            i._read_wannier_operator_header(io, hu, "uHu", i.WannierUHUHeader; formatted = false)
            seek(io, position(io) + 4)
            write(io, NaN)
        end
        @test_throws ArgumentError ScanFixture._scan_completed_operator_pair(ui, hu, dims, false)
        write(hu, hdata)
        si = joinpath(dir, "test.sIu");
        sh = joinpath(dir, "test.sHu")
        i.write_wannier_siu(si, i.WannierSIUHeader("siu", 2, 1, 1), (_...) -> ComplexF64[1 2; 3 4])
        i.write_wannier_shu(sh, i.WannierSHUHeader("shu", 2, 1, 1), (_...) -> ComplexF64[4 3; 2 1])
        sp = joinpath(dir, "spn.h5");
        sip = joinpath(dir, "siu.json");
        shp = joinpath(dir, "shu.json")
        for path in (sp, sip, shp)
            ;
            write(path, "fixture");
        end
        fullconfig = (;
            output = (;
                uiu_file = ui,
                uhu_file = hu,
                siu_file = si,
                shu_file = sh,
                spn_provenance_file = sp,
                uiu_provenance_json = up,
                uhu_provenance_json = hp,
                siu_provenance_json = sip,
                shu_provenance_json = shp,
                operator_files_formatted = false,
            )
        )
        @test ScanFixture._validate_completed_operator_set(
            fullconfig,
            nothing,
            dims,
            nothing,
            Dict("WAVECAR" => "matched"),
        ) == Dict("status" => "PASS")
        @test_throws ArgumentError ScanFixture._validate_completed_operator_set(
            fullconfig,
            nothing,
            dims,
            nothing,
            Dict("WAVECAR" => "changed"),
        )
        open(sh, "r+") do io
            i._read_wannier_operator_header(io, sh, "sHu", i.WannierSHUHeader; formatted = false)
            seek(io, position(io) + 4)
            write(io, NaN)
        end
        @test_throws ArgumentError ScanFixture._validate_completed_operator_set(
            fullconfig,
            nothing,
            dims,
            nothing,
            Dict("WAVECAR" => "matched"),
        )
    end
end
