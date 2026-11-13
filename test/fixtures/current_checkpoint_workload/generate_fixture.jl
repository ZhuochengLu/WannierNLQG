# Explicit maintainer operation. Uses the existing documented tiny input recipe;
# never relabels an old wire or claims historical optimizer continuation.
using WannierNLQG, HDF5, JSON3, LinearAlgebra, Test
isdefined(@__MODULE__, :ArchivedCheckpointMathTestSupport) ||
    include(joinpath(Base.pkgdir(WannierNLQG), "test", "ArchivedCheckpointMathTestSupport.jl"))

# Rebuild a fixture record without changing arrays or unspecified fields.
fixture_replace_fields(value; kwargs...) = typeof(value)(
    (get(kwargs, name, getfield(value, name)) for name in fieldnames(typeof(value)))...,
)

function generate_current_checkpoint_fixture(destination::AbstractString)
    ispath(destination) && error("Choose a new output directory; existing data is preserved")
    root=Base.pkgdir(WannierNLQG)
    legacy_dir=joinpath(root, "test", "fixtures", "first_use_portable", "assets", "frozen_solver")
    legacy_asset=joinpath(legacy_dir, "synthetic.current.wannierization.h5")
    before=read(legacy_asset)
    w=WannierNLQG.Wannierization
    extension=first(w._load_wannierization_extension!())
    decoder=extension.SolverCheckpoint
    legacy_result=ArchivedCheckpointMathTestSupport.read_archived_checkpoint_math(
        legacy_asset,
        joinpath(root, "test", "fixtures", "checkpoint_numeric_reference.bin"),
    )
    fixture=synthetic_wannierization_fixture()
    # Compare the actual source arrays/topology before running the existing tiny
    # recipe. An arbitrary replacement model cannot silently become this asset.
    mmn=WannierNLQG.IO.read_wannier_mmn(joinpath(legacy_dir, "synthetic.mmn"))
    eig=WannierNLQG.IO.read_wannier_eig(joinpath(legacy_dir, "synthetic.eig"))
    @test mmn.data==fixture.mmn.data
    @test mmn.neighbors==fixture.mmn.neighbors
    @test mmn.reciprocal_shifts==fixture.mmn.reciprocal_shifts
    @test eig.data==fixture.eig.data
    HDF5.h5open(joinpath(legacy_dir, "synthetic.band-representation.h5"), "r") do h
        @test read(h["geometry/real_lattice"])==fixture.representation.real_lattice
        @test permutedims(
            read(h["geometry/kpoints_fractional"]),
        )==fixture.representation.kpoints_fractional
        @test BitMatrix(read(h["qualification_scope/outer_mask"]) .!= 0)==trues(2, 2)
        @test BitMatrix(
            read(h["qualification_scope/frozen_mask"]) .!= 0,
        )==BitMatrix([true true; false false])
    end
    mkdir(destination)
    config=modified_wannierization_config(
        fixture.config;
        win_file = joinpath(legacy_dir, "synthetic.win"),
        eig_file = joinpath(legacy_dir, "synthetic.eig"),
        mmn_file = joinpath(legacy_dir, "synthetic.mmn"),
        checkpoint_hdf5 = joinpath(destination, "solved.wannierization.h5"),
    )
    result=w.construct_wannier_functions(config)
    @test result.restart_state!==nothing
    @test all(isfinite, result.v_matrix)
    # A new random-initialized calculation need not repeat a historical AMN
    # phase or saved spread. The independent physical toy has identity MMN,
    # fixed first-band projectors, zero centers and zero spread (unit lattice).
    # 64 eps is a small-matrix rounding bound, not a changed production gate.
    for k in axes(result.v_matrix, 3)
        frame=result.v_matrix[:, :, k]
        @test maximum(abs, frame*frame'-ComplexF64[1 0; 0 0])<=64eps(Float64)
    end
    @test maximum(abs, result.wannier_centers_cartesian)<=64eps(Float64)
    @test maximum(abs, result.spreads_angstrom2)<=64eps(Float64)
    # This is a portable accepted-state reader fixture. Do not retain local
    # scientific-input lifetimes or certify continuation after those inputs move.
    restart=fixture_replace_fields(result.restart_state; input_definition = nothing)
    summary=copy(result.input_summary)
    summary["restart_eligible"]="false"
    summary["restart_input_definition_status"]="NOT_RECORDED"
    summary["global_production_eligible"]="false"
    portable=fixture_replace_fields(result; restart_state = restart, input_summary = summary)
    target=joinpath(destination, "synthetic.wannierization.h5")
    decoder.write_wannierization_checkpoint_hdf5(target, portable)
    current=w.read_wannierization_checkpoint_hdf5(target)
    @test current.v_matrix==result.v_matrix
    @test current.wannier_centers_cartesian==result.wannier_centers_cartesian
    @test current.spreads_angstrom2==result.spreads_angstrom2
    @test current.input_summary["restart_eligible"]=="false"
    @test current.input_summary["restart_input_definition_status"]=="NOT_RECORDED"
    @test all(
        key->haskey(current.input_summary, key),
        (
            "disentanglement_outer_mask_definition",
            "disentanglement_frozen_mask_definition",
            "target_subspace_contract_definition",
            "target_leakage_formula_definition",
        ),
    )
    @test read(legacy_asset)==before
    provenance=Dict(
        "schema"=>"wanniernlqg.current-checkpoint-workload/2",
        "historical_input"=>relpath(legacy_asset, root),
        "historical_wire"=>"1.4",
        "current_wire"=>decoder.WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION,
        "generation"=>"Actual current solve of existing two-band/two-k fixture with actual source EIG/MMN equality and archived numerical-prefix and direct HDF mathematical comparisons",
        "qualification"=>"Reader/TB/spread workload; no optimizer continuation or physical qualification",
        "original_fixture_unchanged"=>true,
        "private_receipt_shipped"=>false,
        "solver_status"=>string(result.status),
    )
    write(joinpath(destination, "PROVENANCE.json"), JSON3.write(provenance))
    return target
end

if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==1 || error("Usage: generate_fixture.jl NEW_OUTPUT_DIRECTORY")
    isdefined(@__MODULE__, :synthetic_wannierization_fixture) ||
        include(joinpath(Base.pkgdir(WannierNLQG), "test", "WannierizationFixtureSupport.jl"))
    generate_current_checkpoint_fixture(abspath(only(ARGS)))
end
