using Test, TOML, SHA, LinearAlgebra
@testset "Native SAWF explicit Seitz selection" begin
    w=WannierNLQG.Wannierization;
    r=WannierNLQG.Runtime;
    sf=WannierNLQG.SymmetryFoundation
    doc=TOML.parsefile(joinpath(spec["saved_fixture"], "records", "effective_config.toml"))
    doc["mode"]="symmetry_adapted";
    doc["source"]["include_time_reversal"]=true
    doc["symmetry"]=Dict{String, Any}("include_time_reversal"=>true, "symmetry_tolerance"=>1e-5)
    doc["output"]["checkpoint_hdf5"]=joinpath(out, "selected.wannierization.h5")
    doc["output"]["native_matrix_directory"]=joinpath(out, "native-matrices")
    function resolve(d, label)
        path=joinpath(out, label*".toml");
        open(io->TOML.print(io, d), path, "w")
        return r.read_task_input(path)
    end
    unselected=resolve(doc, "unselected")
    ext=Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
    select_operations(
        args...,
    )=Base.invokelatest(ext.RepresentationPreparation.select_detected_operations, args...)
    original=unselected.config.input
    @test length(w.WANNIERIZATION_CONFIG_LEAF_FIELDS)==79
    @test length(unique(w.WANNIERIZATION_CONFIG_LEAF_FIELDS))==79
    @test w.WannierizationInputConfig(
        (getfield(original, name) for name in fieldnames(typeof(original))[1:29])...,
    ).operation_indices===nothing

    meta=w.native_qe_wannier_metadata(unselected.config.input.source)
    inventory=sf.detect_magnetic_symmetry_inventory(
        meta.structure;
        include_time_reversal = true,
        symmetry_tolerance = 1e-5,
    )
    identity_geometry(
        op,
    )=op.rotation_fractional==Matrix{Int}(I, 3, 3) &&
      maximum(abs, op.translation_fractional; init = 0.0)<1e-12
    identity=only(findall(op->identity_geometry(op)&&!op.antiunitary, inventory.operations))
    tr=only(findall(op->identity_geometry(op)&&op.antiunitary, inventory.operations))
    selected=[tr, identity] # Deliberately preserve noncanonical caller order.
    choice=select_operations(inventory, selected)
    @test choice.operations==inventory.operations[selected]
    @test choice.inventory===nothing
    @test choice.conventions["operation_selection_parent_indices"]==join(selected, ',')
    @test choice.conventions["operation_selection_unitary_count"]=="1"
    @test choice.conventions["operation_selection_antiunitary_count"]=="1"
    @test select_operations(inventory, nothing).inventory===inventory
    @test_throws ArgumentError select_operations(inventory, Int[])
    @test_throws ArgumentError select_operations(inventory, [identity, identity])
    @test_throws ArgumentError select_operations(inventory, [0])
    @test_throws ArgumentError select_operations(inventory, [length(inventory.operations)+1])
    @test_throws ArgumentError select_operations(inventory, [tr])
    for invalid in (Int[], [identity, identity], [true], [0], [1.5])
        bad=deepcopy(doc);
        bad["symmetry"]["operation_indices"]=invalid
        @test_throws ArgumentError resolve(bad, "invalid")
    end
    doc["symmetry"]["operation_indices"]=selected
    input=resolve(doc, "selected")
    @test input.config.input.operation_indices==selected
    result=r.run_task_input(input; record_directory = joinpath(out, "records"))
    for d in result.diagnostics
        ;
        println("SELECTION_DIAGNOSTIC=", d);
    end
    @test !any(d->d.severity==:error, result.diagnostics)
    @test result.artifacts.packed_hdf5!==nothing
    @test result.input_summary["operation_selection_parent_indices"]==join(selected, ',')
    @test result.input_summary["operation_selection_classification"]=="unclassified_subgroup"
    @test resolve(
        TOML.parsefile(joinpath(out, "records", "effective_config.toml")),
        "effective",
    ).config.input.operation_indices==selected
    # Actual representation persistence: parent classification must not be
    # reconstructed on a different operation inventory.
    cfg=input.config.input
    options=Dict{Symbol, Any}(
        name=>getfield(cfg, name) for
        name in fieldnames(w.BandRepresentationPreparationConfig) if hasfield(typeof(cfg), name)
    )
    options[:output_hdf5]=joinpath(out, "selected.band.h5")
    prepared=w.prepare_band_representation(w.BandRepresentationPreparationConfig(; options...))
    @test prepared.inventory===nothing
    representation=prepared.representation
    @test length(representation.operations)==2
    @test representation.operations[1].antiunitary
    @test all(representation.kpoint_map .== 1) # Equal Gamma actions are legitimate.
    @test all(1 .<= representation.full_to_operation .<= 2)
    restored=sf.read_band_representation_hdf5(options[:output_hdf5]; content_authentication = false)
    @test restored.conventions["operation_selection_operations"]==representation.conventions["operation_selection_operations"]
    @test restored.kpoint_map==representation.kpoint_map
    @test restored.sewing_matrices==representation.sewing_matrices
    checkpoint=input.config.checkpoint.checkpoint_hdf5
    digest=bytes2hex(sha256(read(checkpoint)))
    resumedoc=deepcopy(doc);
    resumedoc["solver"]["initialization"]="restart"
    resumedoc["checkpoint"]=Dict("restart_hdf5"=>checkpoint)
    resumedoc["output"]["checkpoint_hdf5"]=joinpath(out, "resumed.wannierization.h5")
    resumed=r.run_task_input(
        resolve(resumedoc, "resumed");
        record_directory = joinpath(out, "resumed-records"),
    )
    @test !any(d->d.severity==:error, resumed.diagnostics)
    @test isequal(resumed.v_matrix, result.v_matrix)
    changed=deepcopy(resumedoc);
    changed["symmetry"]["operation_indices"]=[identity]
    changed["output"]["checkpoint_hdf5"]=joinpath(out, "changed.wannierization.h5")
    rejected=r.run_task_input(
        resolve(changed, "changed");
        record_directory = joinpath(out, "changed-records"),
    )
    @test any(d->d.severity==:error, rejected.diagnostics)
    @test rejected.artifacts.packed_hdf5===nothing
    @test bytes2hex(sha256(read(checkpoint)))==digest
end
