#!/usr/bin/env julia

using HDF5
using JSON3
using SHA
using WannierNLQG

const ROOT = normpath(joinpath(@__DIR__, ".."))
const EXAMPLE_ROOT = joinpath(ROOT, "examples", "symmetrization")
const FIXTURE_ROOT = joinpath(EXAMPLE_ROOT, "fixture")
const INPUT_ROOT = joinpath(FIXTURE_ROOT, "inputs")
const EXAMPLES = (
    "mesh.jl",
    "symmetrize_tb.jl",
    "symmetrize_derivatives.jl",
    "symmetrize_spin_only.jl",
    "symmetrize_spin_velocity.jl",
    "symmetrize_combined.jl",
)

function gate_check(condition::Bool, message::AbstractString)
    condition || error("symmetrization example gate failed: $(message)")
    return nothing
end

function file_sha256(path::AbstractString)
    return open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end
end

function check_fixture()
    checksum_path = joinpath(FIXTURE_ROOT, "SHA256SUMS")
    gate_check(isfile(checksum_path), "fixture SHA256SUMS is missing")
    total_bytes = 0
    checked = String[]
    for line in eachline(checksum_path)
        digest, relative = split(line; limit = 2)
        relative = strip(relative)
        path = joinpath(FIXTURE_ROOT, relative)
        gate_check(isfile(path), "fixture input $(relative) is missing")
        gate_check(file_sha256(path) == digest, "fixture digest differs for $(relative)")
        total_bytes += filesize(path)
        push!(checked, relative)
    end
    gate_check(length(checked) == 6, "expected six fixture inputs")
    gate_check(total_bytes < 5_000_000, "fixture inputs exceed 5 MB")
    return nothing
end

function check_json(path::AbstractString, expected_profile::String, expected_operator_count::Int)
    gate_check(isfile(path), "missing report $(path)")
    payload = JSON3.read(read(path, String), Dict{String, Any})
    gate_check(payload["schema"] == "wanniernlqg.symmetrization-report", "wrong JSON schema")
    gate_check(payload["schema_version"] == "1.0", "wrong JSON schema version")
    gate_check(payload["status"] == "PASS", "report status is not PASS")
    gate_check(payload["operator_profile"] == expected_profile, "wrong operator profile")
    gate_check(
        length(payload["operator_inventory"]) == expected_operator_count,
        "unexpected operator inventory size in $(path)",
    )
    gate_check(
        length(payload["validation"]) == expected_operator_count,
        "unexpected validation operator count in $(path)",
    )
    return nothing
end

function check_hdf5(
    path::AbstractString,
    expected_profile::Symbol,
    expected_operator_count::Int,
    expected_production_eligible::Bool,
)
    gate_check(isfile(path), "missing operator bundle $(path)")
    HDF5.h5open(path, "r") do handle
        attributes = HDF5.attributes(handle)
        gate_check(
            read(attributes["schema"]) == "wanniernlqg.real-space-operators",
            "wrong HDF5 schema",
        )
        schema_version = String(read(attributes["schema_version"]))
        gate_check(
            schema_version in (
                "5.0",
                "5.1",
                "5.2",
                "5.3",
                "5.4",
                "5.5",
                "5.6",
                "5.7",
                "5.8",
                "5.9",
                WannierNLQG.IO.OPERATOR_BUNDLE_SCHEMA_VERSION,
            ),
            "unsupported HDF5 schema version $(schema_version)",
        )
        gate_check(
            Symbol(read(attributes["operator_profile"])) == expected_profile,
            "wrong HDF5 profile",
        )
        gate_check(read(attributes["operator_count"]) == expected_operator_count, "wrong count")
        gate_check(
            read(attributes["symmetrization_status"]) == "applied",
            "symmetrization status is not applied",
        )
        gate_check(haskey(handle, "geometry"), "geometry lifecycle group is missing")
        gate_check(
            read(attributes["wannier_center_policy"]) == "symmetrize",
            "wrong Wannier-center policy",
        )
        gate_check(
            read(attributes["real_space_replica_policy"]) == "minimum_distance",
            "wrong replica policy",
        )
        gate_check(
            read(attributes["production_eligible"]) == expected_production_eligible,
            "unexpected production eligibility",
        )
        if expected_profile == :hamiltonian_position_spin
            gate_check(
                !read(attributes["spin_family_production_eligible"]),
                "unqualified spin example must remain diagnostic-only",
            )
        end
        gate_check(haskey(handle, "payload/complex128"), "packed payload is missing")
    end
    manifest = WannierNLQG.IO.read_real_space_operator_bundle_manifest(path)
    gate_check(manifest.profile == expected_profile, "strict reader profile mismatch")
    gate_check(
        length(manifest.inventory) == expected_operator_count,
        "strict reader count mismatch",
    )
    return nothing
end

check_fixture()
gate_check(
    all(name -> isfile(joinpath(EXAMPLE_ROOT, name)), EXAMPLES),
    "one or more runnable examples are missing",
)

mktempdir() do output_root
    command =
        `$(Base.julia_cmd()) --startup-file=no --project=$(ROOT) $(joinpath(EXAMPLE_ROOT, "run_all.jl"))`
    Base.run(addenv(command, "WANNIERNLQG_SYMMETRIZATION_OUTPUT_ROOT" => output_root))

    profiles = (
        ("tb_only", "hamiltonian_position", 2, true),
        ("derivative", "derivative", 7, true),
        ("spin_only", "hamiltonian_position_spin", 3, false),
    )
    for (directory, profile, count, production_eligible) in profiles
        check_json(joinpath(output_root, directory, "symmetrization.json"), profile, count)
        check_hdf5(
            joinpath(output_root, directory, "wannierNLQG_tb.h5"),
            Symbol(profile),
            count,
            production_eligible,
        )
        checksum_file = joinpath(output_root, directory, "SHA256SUMS")
        gate_check(isfile(checksum_file), "missing SHA256SUMS for $(directory)")
        gate_check(length(readlines(checksum_file)) == 3, "wrong checksum count for $(directory)")
        gate_check(
            isempty(
                filter(
                    name -> occursin("cache", lowercase(name)),
                    readdir(joinpath(output_root, directory)),
                ),
            ),
            "deprecated cache artifact was generated for $(directory)",
        )
    end
    for directory in ("spin_velocity", "combined")
        for filename in ("symmetrization.json", "wannierNLQG_tb.h5", "synthetic_sym_tb.dat")
            gate_check(
                !ispath(joinpath(output_root, directory, filename)),
                "legacy full example unexpectedly published $(directory)/$(filename)",
            )
        end
    end
end

println("symmetrization example gate passed")
