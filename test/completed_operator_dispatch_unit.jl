using Test
module DispatchFixture
struct VASPWavefunctionSource end
struct Prep
    resume::Bool
    checkpoint_directory::Union{Nothing, String}
    mode::Symbol
end
const calls = Symbol[]
const fail_validation = Ref(false)
module Wannierization
using ..DispatchFixture: calls
validate_native_operator_artifact_paths(config) = config.paths
Base.@kwdef struct WavefunctionPreparationExecutionConfig
    resume::Bool
    checkpoint_directory::Union{Nothing, String}
    mode::Symbol
end
WannierHamiltonianOperatorGenerationConfig(; kwargs...) = (; kwargs...)
generate_qe_paw_spn(args...; kwargs...) = (push!(calls, :spn); (; passed = true))
generate_wannier_uiu(args...; kwargs...) = error("completed uIu was regenerated")
generate_wannier_uhu(args...; kwargs...) = error("completed uHu was regenerated")
generate_wannier_siu(args...; kwargs...) = (push!(calls, :siu); (; passed = true))
generate_wannier_shu(args...; kwargs...) = (push!(calls, :shu); (; passed = true))
end
_validate_file_topology_vasp_eig(args...) = nothing
native_preparation_source_files(source) = Dict("WAVECAR" => "fixture")
function validate_completed_operator_pair(args...; reuse_spn = false)
    push!(calls, reuse_spn ? :validate_pair_spn : :validate)
    fail_validation[] && throw(ArgumentError("SOURCE_MISMATCH"))
    return nothing
end
function validate_completed_operator_set(args...)
    push!(calls, :validate_all)
    fail_validation[] && throw(ArgumentError("SOURCE_MISMATCH"))
    return Dict("status" => "PASS")
end
source = read(
    joinpath(
        @__DIR__,
        "..",
        "ext",
        "WannierNLQGWannierizationExt",
        "NativeOperatorOutputGeneration.jl",
    ),
    String,
)
for name in ("_validate_native_restart_output_directory", "generate_native_operator_outputs")
    start = first(findfirst("function " * name, source))
    expr, _ = Meta.parse(source, start)
    eval(expr)
end
end

@testset "completed pair dispatch" begin
    mktempdir() do tmp
        base = realpath(tmp);
        output = joinpath(base, "output");
        mkpath(output)
        directory = joinpath(output, "native-operators");
        mkpath(directory)
        native = joinpath(base, "accepted");
        mkpath(native)
        paths = Dict(
            key => joinpath(directory, name) for (key, name) in (
                :uiu_file => "native.uIu",
                :uhu_file => "native.uHu",
                :uiu_provenance_json => "native.uIu.provenance.json",
                :uhu_provenance_json => "native.uHu.provenance.json",
            )
        )
        for path in values(paths)
            write(path, "fixture")
            endswith(path, ".json") && write(path * ".references.h5", "fixture")
        end
        merge!(
            paths,
            Dict(
                :spn_file => joinpath(directory, "native.spn"),
                :spn_provenance_file => joinpath(directory, "native.spn.json"),
                :siu_file => joinpath(directory, "native.sIu"),
                :siu_provenance_json => joinpath(directory, "native.sIu.json"),
                :shu_file => joinpath(directory, "native.sHu"),
                :shu_provenance_json => joinpath(directory, "native.sHu.json"),
            ),
        )
        prep = DispatchFixture.Prep(true, nothing, :streaming_serial)
        config = (;
            paths,
            input = (;
                preparation_execution = prep,
                matrix_elements = (; artifact_dir = native),
                source = nothing,
                eig_file = "eig",
                authoritative_hamiltonian = nothing,
                wavefunction_gauge_hdf5 = nothing,
            ),
            output = (; model_file = joinpath(output, "model.h5"), profile = :full),
            solver = (; parallel = :serial),
            checkpoint = (; reference_root = nothing),
        )
        accepted = (; restart_state = (; input_definition = (; auxiliary_sources = Dict())))
        empty!(DispatchFixture.calls)
        @test DispatchFixture.generate_native_operator_outputs(
            config,
            (; mmn = :mmn, mmn_file = "mmn"),
            :target;
            accepted_result = accepted,
            eig = :eig,
        ) === nothing
        @test DispatchFixture.calls == [:validate, :spn, :siu, :shu]
        empty!(DispatchFixture.calls)
        DispatchFixture.fail_validation[] = true
        @test_throws ArgumentError DispatchFixture.generate_native_operator_outputs(
            config,
            (; mmn = :mmn, mmn_file = "mmn"),
            :target;
            accepted_result = accepted,
            eig = :eig,
        )
        @test DispatchFixture.calls == [:validate]
        DispatchFixture.fail_validation[] = false
        for key in (:spn_file, :spn_provenance_file)
            ;
            write(paths[key], "fixture");
        end
        empty!(DispatchFixture.calls)
        @test DispatchFixture.generate_native_operator_outputs(
            config,
            (; mmn = :mmn, mmn_file = "mmn"),
            :target;
            accepted_result = accepted,
            eig = :eig,
        ) === nothing
        @test DispatchFixture.calls == [:validate_pair_spn, :siu, :shu]
        empty!(DispatchFixture.calls)
        DispatchFixture.fail_validation[] = true
        @test_throws ArgumentError DispatchFixture.generate_native_operator_outputs(
            config,
            (; mmn = :mmn, mmn_file = "mmn"),
            :target;
            accepted_result = accepted,
            eig = :eig,
        )
        @test DispatchFixture.calls == [:validate_pair_spn]
        DispatchFixture.fail_validation[] = false
        for key in (
            :spn_file,
            :spn_provenance_file,
            :siu_file,
            :shu_file,
            :siu_provenance_json,
            :shu_provenance_json,
        )
            path = paths[key]
            write(path, "fixture")
            endswith(String(key), "provenance_json") && write(path * ".references.h5", "fixture")
        end
        empty!(DispatchFixture.calls)
        @test DispatchFixture.generate_native_operator_outputs(
            config,
            (; mmn = :mmn, mmn_file = "mmn"),
            :target;
            accepted_result = accepted,
            eig = :eig,
        ) == Dict("status" => "PASS")
        @test DispatchFixture.calls == [:validate_all]
        other = joinpath(base, "new-publication");
        mkpath(other)
        external = merge(
            config,
            (; output = merge(config.output, (; model_file = joinpath(other, "model.h5")))),
        )
        before = Dict(path=>read(path) for path in values(paths))
        empty!(DispatchFixture.calls)
        @test DispatchFixture.generate_native_operator_outputs(
            external,
            (; mmn = :mmn, mmn_file = "mmn"),
            :target;
            accepted_result = accepted,
            eig = :eig,
        ) == Dict("status"=>"PASS")
        @test DispatchFixture.calls == [:validate_all]
        @test all(read(path)==bytes for (path, bytes) in before)
        rm(paths[:shu_file])
        empty!(DispatchFixture.calls)
        @test_throws ArgumentError DispatchFixture.generate_native_operator_outputs(
            external,
            (; mmn = :mmn, mmn_file = "mmn"),
            :target;
            accepted_result = accepted,
            eig = :eig,
        )
        @test isempty(DispatchFixture.calls)
        @test !isfile(paths[:shu_file])
    end
end
