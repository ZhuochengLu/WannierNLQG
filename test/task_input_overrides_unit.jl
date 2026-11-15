module TaskInputOverridesUnit
using Test, WannierNLQG, LinearAlgebra, TOML
const R=WannierNLQG.Runtime
const F=WannierNLQG.IO
include(joinpath(@__DIR__, "../examples/ExampleSupport.jl"))
function document(directory)
    Dict{String, Any}(
        "model"=>Dict(
            "source"=>"wannier",
            "model_file"=>joinpath(
                @__DIR__,
                "../examples/fixtures/synthetic_runtime/synthetic_tb.dat",
            ),
        ),
        "response"=>Dict{String, Any}(
            "photon_energies_ev"=>[0.25, 0.5],
            "fermi_energy_ev"=>0.0,
            "temperature_k"=>0.0,
            "sampling"=>Dict("kind"=>"bz_mesh", "k_mesh"=>[1, 1, 1], "spatial_dimension"=>3),
            "execution"=>Dict("fourier_backend"=>"direct"),
            "tasks" => Dict{String, Any}(
                "sc" => Dict{String, Any}("kind"=>"SC", "method"=>"Conventional"),
            ),
        ),
        "output"=>Dict("output_root"=>directory, "progress_enabled"=>false),
    )
end
@testset "Whole local axes and actual shared scalar/scan consumers" begin
    mktempdir() do directory
        d=document(directory);
        r=d["response"]
        bad=deepcopy(d);
        bad["response"]["temperature_k"]=-1.0;
        bad["response"]["tasks"]["sc"]["temperature_k"]=300.0
        @test_throws ArgumentError resolve_task_input(bad)
        r["fermi_energies_ev"]=[-0.2, 0.0, 0.2]
        r["relaxation"]=Dict("gamma_intra_ev"=>0.02, "gamma_inter_ev"=>0.03)
        r["tasks"]["lt"] = Dict("kind"=>"LT", "method"=>"Conventional", "temperature_k"=>300.0)
        # Each layer has one axis. The optical scalar is task-local while the
        # shared vector supplies the static response.
        @test_throws ArgumentError resolve_task_input(d)
        delete!(r, "fermi_energy_ev")
        r["tasks"]["sc"]["fermi_energy_ev"]=0.0
        x=resolve_task_input(d)
        @test only(task for task in x.config.tasks if task.id=="sc").physics.fermi_energy==0.0
        @test only(task for task in x.config.tasks if task.id=="lt").physics.fermi_energies==[
            -0.2,
            0.0,
            0.2,
        ]
        @test !haskey(x.effective["response"]["tasks"]["sc"], "fermi_energies_ev")
        r["tasks"]["sc"]["fermi_energies_ev"]=[0.0]
        @test_throws ArgumentError resolve_task_input(d)
        delete!(r["tasks"]["sc"], "fermi_energies_ev")
        r["tasks"]["lt"]["fermi_energy_ev"]=0.0
        x=resolve_task_input(d)
        @test only(task for task in x.config.tasks if task.id=="lt").physics.fermi_energies==[0.0]
        r["tasks"]["lt"]["fermi_energies_ev"]=[0.1]
        @test_throws ArgumentError resolve_task_input(d)
        delete!(r["tasks"]["lt"], "fermi_energies_ev")
        delete!(r["tasks"]["lt"], "fermi_energy_ev")
        delete!(r["tasks"], "lt")
        @test_throws ArgumentError resolve_task_input(d)
        delete!(r, "fermi_energies_ev");
        delete!(r, "relaxation")
        delete!(r, "photon_energies_ev")
        merge!(
            r,
            Dict(
                "photon_energy_min_ev"=>0.0,
                "photon_energy_max_ev"=>1.0,
                "photon_energy_step_ev"=>0.3,
            ),
        )
        task=r["tasks"]["sc"]
        merge!(
            task,
            Dict(
                "photon_energy_min_ev"=>1.0,
                "photon_energy_max_ev"=>2.0,
                "photon_energy_num_points"=>3,
            ),
        )
        x=resolve_task_input(d)
        @test x.config.tasks[1].physics.photon_energies==[1.0, 1.5, 2.0]
        @test x.provenance["response.tasks.sc.photon_energies_ev"]["source"]=="DERIVED"
        @test x.provenance["response.tasks.sc.photon_energy_num_points"]["source"]=="USER"
        delete!(task, "photon_energy_min_ev")
        @test_throws ArgumentError resolve_task_input(d)
        task["photon_energy_min_ev"]=1.0
        delete!(r, "photon_energy_min_ev")
        @test_throws ArgumentError resolve_task_input(d)
    end
end
@testset "q modes replace whole groups and invalid shared modes still fail" begin
    shared=Dict{String, Any}(
        "photon_momentum_enhancement"=>1.0,
        "photon_momentum_direction"=>[1.0, 0.0, 0.0],
    )
    records=Dict{String, Dict{String, Any}}()
    fixed=Dict{String, Any}("photon_momentum_A_inverse"=>[0.001, 0.0, 0.0])
    values, derived=R._task_input_momentum_source(fixed, shared, "task", records)
    @test !derived && Set(keys(values))==Set(["photon_momentum_A_inverse"])
    paired=Dict{String, Any}("photon_momenta_A_inverse"=>[[0.001, 0.0, 0.0], [0.002, 0.0, 0.0]])
    values, derived=R._task_input_momentum_source(paired, fixed, "task", records)
    @test !derived && !haskey(values, "photon_momentum_A_inverse")
    values, derived=R._task_input_momentum_source(shared, paired, "task", records)
    @test derived && !haskey(values, "photon_momenta_A_inverse")
    @test_throws ArgumentError R._task_input_momentum_source(
        Dict("photon_momentum_direction"=>[1.0, 0.0, 0.0]),
        shared,
        "task",
        records,
    )
    bad=merge(shared, fixed)
    @test_throws ArgumentError R._task_input_momentum_source(bad, Dict(), "response", records)
end
@testset "Column nodes and HDF5-only Band lattice" begin
    mktempdir() do directory
        d=document(directory);
        r=d["response"]
        delete!(r, "photon_energies_ev");
        delete!(r, "temperature_k")
        r["tasks"]=Dict{String, Any}("band"=>Dict("kind"=>"Band"))
        nodes=Dict(
            "label"=>["G", "X", "G", "outside"],
            "fractional_coordinates"=>[
                [0.0, 0.0, 0.0],
                [0.5, 0.0, 0.0],
                [0.0, 0.0, 0.0],
                [1.25, 0.0, 0.0],
            ],
        )
        r["sampling"]=Dict{String, Any}(
            "kind"=>"k_path",
            "spatial_dimension"=>3,
            "nodes"=>nodes,
            "kpoints_per_segment"=>3,
        )
        x=resolve_task_input(d)
        @test first.(x.config.sampling.nodes)==["G", "X", "G", "outside"]
        @test last(x.config.sampling.nodes)[2]==(1.25, 0.0, 0.0)
        old=deepcopy(d);
        old["response"]["sampling"]["nodes"]=[
            Dict("label"=>"G", "fractional_coordinates"=>[0.0, 0.0, 0.0]),
        ]
        @test_throws ArgumentError resolve_task_input(old)
        for malformed in [
            Dict("label"=>["G"], "fractional_coordinates"=>[[false, 0.0, 0.0]]),
            Dict("label"=>[""], "fractional_coordinates"=>[[0.0, 0.0, 0.0]]),
            Dict("label"=>["G", "X"], "fractional_coordinates"=>[[0.0, 0.0, 0.0]]),
        ]
            bad=deepcopy(d);
            bad["response"]["sampling"]["nodes"]=malformed
            @test_throws ArgumentError resolve_task_input(bad)
        end
        bundle=ExampleSupport.synthetic_operator_bundle_file()
        d["model"]=Dict("source"=>"wannier", "real_space_operator_bundle_file"=>bundle)
        for count in (3, nothing)
            sampling=r["sampling"]
            count===nothing ? delete!(sampling, "kpoints_per_segment") :
            (sampling["kpoints_per_segment"]=count)
            x=resolve_task_input(d)
            @test isempty(x.pending) && x.config.sampling isa KPath
            @test R._task_input_band_lattice(
                x.config.model,
            )==F.read_real_space_operator_bundle_manifest(bundle).lattice
        end
        lattice=F.read_real_space_operator_bundle_manifest(bundle).lattice
        r["sampling"]=Dict{String, Any}(
            "kind"=>"k_path",
            "spatial_dimension"=>3,
            "structure"=>Dict(
                "lattice_angstrom"=>[collect(row) for row in eachrow(lattice)],
                "species"=>["X"],
                "positions_fractional"=>[[0.0, 0.0, 0.0]],
            ),
        )
        for count in (3, nothing)
            count===nothing ? delete!(r["sampling"], "kpoints_per_segment") :
            (r["sampling"]["kpoints_per_segment"]=count)
            path=joinpath(directory, "automatic-packed-band.toml")
            F.write_task_input_file(path, d)
            x=read_task_input(path)
            @test isempty(x.pending) && x.config.sampling isa KPath
            @test x.config.sampling.provenance["path_origin"]=="AUTOMATIC_STRUCTURE_PATH"
        end
    end
end
@testset "Expanded axes precede existing paired momentum resolution" begin
    mktempdir() do directory
        d=document(directory);
        r=d["response"];
        delete!(r, "photon_energies_ev")
        merge!(
            r,
            Dict(
                "photon_energy_min_ev"=>0.25,
                "photon_energy_max_ev"=>0.5,
                "photon_energy_num_points"=>3,
            ),
        )
        row=r["tasks"]["sc"];
        row["kind"]="photon_drag_injection_current";
        delete!(row, "method")
        row["photon_momentum_enhancement"]=3.0
        row["photon_momentum_direction"]=[0.0, -2.0, 0.0]
        x=resolve_task_input(d; base_dir = directory)
        @test x.config.tasks[1].physics.photon_energies==[0.25, 0.375, 0.5]
        @test x.config.tasks[1].physics.photon_momenta==[
            (0.0, -3 * e/1973.269804, 0.0) for e in [0.25, 0.375, 0.5]
        ]
        delete!(row, "photon_momentum_enhancement")
        row["photon_momentum_table_file"]="q.csv"
        write(joinpath(directory, "q.csv"), "energy_ev,q_A_inverse\n0.25,0.001\n0.5,0.003\n")
        x=resolve_task_input(d; base_dir = directory)
        @test x.config.tasks[1].physics.photon_momenta==[
            (0.0, -q, 0.0) for q in [0.001, 0.002, 0.003]
        ]
    end
end

@testset "Overridden shared CSV still has its own format validation" begin
    mktempdir() do directory
        d=document(directory);
        r=d["response"];
        row=r["tasks"]["sc"]
        row["kind"]="photon_drag_injection_current";
        delete!(row, "method")
        row["photon_momentum_A_inverse"]=[0.001, 0.0, 0.0]
        r["photon_momentum_table_file"]="shared.csv"
        r["photon_momentum_direction"]=[1.0, 0.0, 0.0]
        file=joinpath(directory, "shared.csv")
        write(file, "wrong,header\n0.25,0.001\n")
        @test_throws ArgumentError resolve_task_input(d; base_dir = directory)
        write(file, "energy_ev,q_A_inverse\n0.25,0.001\n0.5,0.003\n")
        x=resolve_task_input(d; base_dir = directory)
        @test x.config.tasks[1].physics.photon_momentum==(0.001, 0.0, 0.0)
    end
end

@testset "Explicit values survive override validation" begin
    mktempdir() do directory
        d=document(directory)
        r=d["response"]
        t=r["tasks"]["sc"]
        # Serialize and parse real TOML, then follow the ordinary resolution API.
        function resolve_text(x)
            file=joinpath(directory, "input.toml")
            open(io -> TOML.print(io, x), file; write = true)
            resolve_task_input(TOML.parsefile(file))
        end
        for (shared, local_value, accepted) in
            ((-1.0, 0.06, false), (-1.0, nothing, false), (0.04, 0.06, true), (0.04, -1.0, false))
            x=deepcopy(d)
            x["response"]["numerics"]=Dict("broadening"=>shared)
            if local_value !== nothing
                x["response"]["tasks"]["sc"]["numerics"]=Dict("broadening"=>local_value)
            end
            if accepted
                result=resolve_text(x)
                @test result.effective["response"]["tasks"]["sc"]["numerics"]["broadening"]==local_value
                record=result.provenance["response.tasks.sc.numerics.broadening"]
                @test record["origin"]=="response.tasks.sc.numerics.broadening"
                @test record["value"]==local_value
            else
                @test_throws ArgumentError resolve_text(x)
            end
        end
        valid=Dict{String, Any}(
            "broadening"=>0.04,
            "broadening_type"=>"Gaussian",
            "transition_window_factor"=>-1.0,
            "denominator_regularization"=>0.0,
            "degeneracy_threshold"=>0.0,
            "finite_difference_step"=>0.001,
            "derivative_backend"=>"analytic",
            "band_window_size"=>-1,
            "low_frequency_broadening"=>0.02,
            "intermediate_regularization"=>0.0,
            "eta_correction"=>false,
            "hermiticity_tolerance"=>0.001,
            "gap_tolerance"=>0.0,
            "fs_kind"=>"gaussian",
            "eta_fs_ev"=>0.02,
            "prescription"=>"distribution_broadening",
            "occupation_derivative_mode"=>"fermi_dirac",
        )
        @test length(valid)==length(R.NUMERICS_PARAMETER_NAMES)
        @test isnothing(R._task_input_explicit_numerics(valid, "response.numerics"))
        for key in keys(valid)
            @test_throws ArgumentError R._task_input_explicit_numerics(
                Dict(key=>[1]),
                "response.numerics",
            )
            invalid=key=="eta_correction" ? 1 :
                    valid[key] isa String ? "unknown" : key=="transition_window_factor" ? Inf : -2
            @test_throws ArgumentError R._task_input_explicit_numerics(
                Dict(key=>invalid),
                "response.numerics",
            )
        end
        for bad in ("wrong", true, -1.0)
            x=deepcopy(d);
            x["response"]["numerics"]=Dict("broadening"=>bad)
            x["response"]["tasks"]["sc"]["numerics"]=Dict("broadening"=>0.06)
            @test_throws ArgumentError resolve_text(x)
        end
        # Basic zero is not a universal positive-eta restriction; the effective
        # SC configuration below has a legal positive local eta.
        r["numerics"]=Dict("denominator_regularization"=>0.0)
        t["numerics"]=Dict("denominator_regularization"=>0.001)
        @test resolve_text(d).config !== nothing
        for window in (-1.0, 0.0, 5.0)
            r["numerics"]=Dict("transition_window_factor"=>window, "broadening_type"=>"Lorentzian")
            t["numerics"]=Dict("transition_window_factor"=>0.0)
            @test resolve_text(d).config !== nothing
        end
        # Existing physical and momentum checks must still reject hidden bad input.
        for (key, bad, good) in (
            ("temperature_k", -1.0, 300.0),
            ("fermi_energy_ev", "bad", 0.0),
            ("photon_energies_ev", [true], [0.4]),
        )
            x=deepcopy(d);
            x["response"][key]=bad;
            x["response"]["tasks"]["sc"][key]=good
            @test_throws ArgumentError resolve_text(x)
        end
        @test_throws ArgumentError R._task_input_keys(Dict("sheet_axes"=>[1, 1]), (), "response")
        @test_throws ArgumentError R._task_input_explicit_selectors(
            Dict("projection"=>"unknown"),
            "response",
        )
        x=deepcopy(d);
        x["response"]["numerics"]=Dict("finite_difference_step"=>0.001)
        x["response"]["tasks"]["sc"]["numerics"]=Dict("derivative_backend"=>"analytic")
        @test_throws ArgumentError resolve_text(x) # applicability remains effective-task owned
    end
end

end
