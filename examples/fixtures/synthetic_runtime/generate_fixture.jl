#!/usr/bin/env julia

using LinearAlgebra
using Printf
using SHA
using WannierNLQG

const FIXTURE_ROOT = @__DIR__
const NUM_ORBITALS = 4
const R_VECTORS = ((0, 0, 0), (1, 0, 0))
const R_DEGENERACIES = [2, 4]
const CENTERS = repeat([0.25 0.0 0.0], NUM_ORBITALS, 1)

function write_tb(path::AbstractString)
    open(path, "w") do io
        println(io, "WannierNLQG four-orbital synthetic runtime fixture")
        println(io, "1.0 0.0 0.0")
        println(io, "0.0 1.0 0.0")
        println(io, "0.0 0.0 1.0")
        println(io, NUM_ORBITALS)
        println(io, length(R_VECTORS))
        println(io, join(R_DEGENERACIES, " "))
        for (r_index, r_vector) in enumerate(R_VECTORS)
            println(io)
            println(io, join(r_vector, " "))
            for column in 1:NUM_ORBITALS, row in 1:NUM_ORBITALS
                value = if r_index == 1
                    row == column ? (-2.5 + 1.5 * (row - 1)) : 0.05 * (row + column)
                else
                    row == column ? 0.4 * (-1)^row : 0.04 * (row + column)
                end
                @printf(io, "%d %d %.17e 0.0\n", row, column, value)
            end
        end
        for (r_index, r_vector) in enumerate(R_VECTORS)
            println(io)
            println(io, join(r_vector, " "))
            for column in 1:NUM_ORBITALS, row in 1:NUM_ORBITALS
                scale = r_index == 1 ? 0.02 * (row + column) : 0.01 * (row + column)
                values = if r_index == 1 && row == column
                    (0.5, 0.0, 0.0)
                else
                    (scale, 0.5 * scale, 0.25 * scale)
                end
                @printf(io, "%d %d %.17e 0.0 %.17e 0.0 %.17e 0.0\n", row, column, values...,)
            end
        end
    end
    return path
end

function write_wsvec(path::AbstractString)
    fixed(values...) = join(lpad.(string.(values), 5))
    open(path, "w") do io
        println(io, "WannierNLQG synthetic use_ws_distance=.true.")
        for r_vector in R_VECTORS, left in 1:NUM_ORBITALS, right in 1:NUM_ORBITALS
            println(io, fixed(r_vector..., left, right))
            if r_vector == (0, 0, 0)
                println(io, fixed(1))
                println(io, fixed(0, 0, 0))
            else
                println(io, fixed(2))
                println(io, fixed(-2, 0, 0))
                println(io, fixed(0, 0, 0))
            end
        end
    end
    return path
end

function write_bundle(path::AbstractString, tb_path::AbstractString)
    core = WannierNLQG.Core
    model = WannierNLQG.IO.read_wannier_tb(tb_path)
    ranks = Dict(
        core.REAL_SPACE_HAMILTONIAN => 0,
        core.REAL_SPACE_POSITION => 1,
        core.REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION => 1,
        core.REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP => 1,
        core.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR => 2,
        core.REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP => 1,
        core.REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP => 2,
        core.REAL_SPACE_SPIN => 1,
        core.REAL_SPACE_SPIN_TIMES_HAMILTONIAN => 1,
        core.REAL_SPACE_SPIN_TIMES_POSITION => 2,
        core.REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION => 2,
    )
    operators = Dict{core.RealSpaceOperatorKind, Any}()
    for kind in core.REAL_SPACE_OPERATOR_REGISTRY
        rank = ranks[kind]
        shape = (NUM_ORBITALS, NUM_ORBITALS, ntuple(_ -> 3, rank)..., length(R_VECTORS))
        values = zeros(ComplexF64, shape)
        kind == core.REAL_SPACE_HAMILTONIAN && (values .= model.hamiltonian_r)
        kind == core.REAL_SPACE_POSITION && (values .= model.position_r)
        if kind == core.REAL_SPACE_SPIN
            for axis in 1:3, orbital in 1:NUM_ORBITALS
                values[orbital, orbital, axis, 1] = axis == 3 ? (-1.0)^orbital : 0.1 * axis
            end
        end
        operators[kind] = core.RealSpaceOperator(
            core.RealSpaceOperatorSymmetrySpec(kind, rank, 1, 1),
            model.r_vectors,
            values,
        )
    end
    provenance = Dict{String, Any}(
        name => repeat(string(index, base = 16), 64) for (index, name) in enumerate((
            "SPN_sha256",
            "uIu_sha256",
            "uHu_sha256",
            "sIu_sha256",
            "sHu_sha256",
            "uIu_provenance_sha256",
            "uHu_provenance_sha256",
            "sIu_provenance_sha256",
            "sHu_provenance_sha256",
        ))
    )
    merge!(
        provenance,
        Dict(
            "uiu_generation_algorithm_version" => "synthetic-runtime-fixture-v1",
            "uHu_generation_algorithm_version" => "synthetic-runtime-fixture-v1",
            "sIu_generation_algorithm_version" => "synthetic-runtime-fixture-v1",
            "sHu_generation_algorithm_version" => "synthetic-runtime-fixture-v1",
            "authoritative_hamiltonian" => "native_dft",
            "authoritative_hamiltonian_digest" => repeat("a", 64),
            "derivative_overlap_source" => "wannier90_uIu",
            "derivative_overlap_completeness" => "full_hilbert_space",
            "derivative_overlap_source_sha256" => repeat("2", 64),
            "derivative_overlap_algorithm_version" =>
                WannierNLQG.IO.FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION,
            "operator_profile_assembly_algorithm_version" => "synthetic-runtime-fixture-v1",
            "pair_wigner_seitz_roundtrip_policy" => "PAIR_DEPENDENT_MINIMUM_DISTANCE_UNIT_DEGENERACY",
            "pair_wigner_seitz_roundtrip_tolerance" => 1.0e-12,
            "pair_wigner_seitz_roundtrip_residuals" => Dict(
                core.real_space_operator_name(kind) => 0.0 for kind in (
                    core.REAL_SPACE_SPIN,
                    core.REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
                    core.REAL_SPACE_SPIN_TIMES_POSITION,
                    core.REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
                )
            ),
            "uIu_input_sha256" => Dict("fixture" => repeat("b", 64)),
            "uHu_input_sha256" => Dict("fixture" => repeat("c", 64)),
            "sIu_input_sha256" => Dict("fixture" => repeat("d", 64)),
            "sHu_input_sha256" => Dict("fixture" => repeat("e", 64)),
            "authoritative_hamiltonian_input_sha256" => Dict("fixture" => repeat("f", 64)),
        ),
    )
    WannierNLQG.IO.write_real_space_operator_bundle(
        path,
        model.lattice,
        model.r_degeneracies,
        operators;
        profile = :full,
        overwrite = true,
        paired_tb_sha256 = bytes2hex(sha256(read(tb_path))),
        geometry = Dict(
            "wannier_center_policy" => "symmetrize",
            "real_space_replica_policy" => "input",
            "production_eligible" => false,
            "minimum_distance_materialized" => false,
            "mp_grid" => [2, 1, 1],
            "wannier_center_tolerance" => 1.0e-8,
            "wigner_seitz_tolerance" => 1.0e-5,
            "wigner_seitz_search_size" => 3,
            "raw_wannier_centers_cartesian" => CENTERS,
            "raw_wannier_centers_fractional" => CENTERS,
            "final_wannier_centers_cartesian" => CENTERS,
            "final_wannier_centers_fractional" => CENTERS,
            "center_alignment_lattice_shifts" => zeros(Int, size(CENTERS)),
            "replica_mapping_sha256" => repeat("0", 64),
        ),
        provenance = provenance,
        eligibility = Dict(
            "production_eligible" => false,
            "authoritative_hamiltonian" => "native_dft",
            "authoritative_hamiltonian_sha256" => repeat("a", 64),
        ),
    )
    return path
end

function write_checksums(paths)
    open(joinpath(FIXTURE_ROOT, "SHA256SUMS"), "w") do io
        for path in sort(collect(paths))
            println(io, bytes2hex(sha256(read(path))), "  ", basename(path))
        end
    end
end

tb_path = write_tb(joinpath(FIXTURE_ROOT, "synthetic_tb.dat"))
wsvec_path = write_wsvec(joinpath(FIXTURE_ROOT, "synthetic_wsvec.dat"))
bundle_path = write_bundle(joinpath(FIXTURE_ROOT, "synthetic_operators.h5"), tb_path)
write_checksums((tb_path, wsvec_path, bundle_path))
