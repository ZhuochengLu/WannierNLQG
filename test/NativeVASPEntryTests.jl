using Test, LinearAlgebra, HDF5, TOML
include("VASPNativeTestSupport.jl")
@testset "Owned VASP topology and native normalized solver entry" begin
    w=WannierNLQG.Wannierization;
    r=WannierNLQG.Runtime
    let directory=mktempdir(out; prefix = "vasp-entry-", cleanup = false)
        poscar, wavecar, _ = write_bounded_vasp_fixture(directory, 2, ComplexF64)
        potcar = joinpath(directory, "POTCAR")
        write(
            potcar,
            replace(synthetic_potcar_block("X"; q0 = 0.0), "0.12 0.22 0.32" => "0.10 0.20 0.30"),
        )
        open(wavecar, "r+") do stream
            for k in 1:2, band in 1:2
                coefficients = zeros(ComplexF64, 2k)
                coefficients[1 + (band - 1) * k] = 1
                seek(stream, 512 * (2 + (k - 1) * 3 + band))
                write(stream, coefficients)
            end
        end
        incar = joinpath(directory, "INCAR")
        write(incar, "LNONCOLLINEAR = .TRUE.\nSAXIS = 0 0 1\n")
        outcar = joinpath(directory, "OUTCAR")
        write(
            outcar,
            """
 vasp.6.3.0 synthetic
 NKPTS = 2 k-points in BZ NBANDS= 2
 ENCUT = 5.000 eV
 direct lattice vectors                 reciprocal lattice vectors
 5.0 0.0 0.0 0.2 0.0 0.0
 0.0 5.0 0.0 0.0 0.2 0.0
 0.0 0.0 5.0 0.0 0.0 0.2
 LOCPROJ orbitals
 1 0 1 1.890 0 0 0 1 0 0 0 0 1 1 0 0 1
 1 0 1 1.890 0 0 0 1 0 0 0 0 1 2 0 0 1
 Computing AMN
""",
        )

        doc=Dict{String, Any}(
            "workflow"=>"wannierization",
            "mode"=>"ordinary",
            "source"=>Dict(
                "kind"=>"vasp",
                "poscar_file"=>poscar,
                "wavecar_file"=>wavecar,
                "potcar_file"=>potcar,
                "incar_file"=>incar,
                "outcar_file"=>outcar,
                "spinor"=>true,
                "spin_basis_saxis"=>[0.0, 0.0, 1.0],
                "include_time_reversal"=>false,
            ),
            "kmesh"=>Dict{String, Any}("dimensions"=>[2, 1, 1]),
            "basis"=>Dict{String, Any}("projections"=>["X:s"], "spinor"=>true),
            "solver"=>Dict("initialization"=>"amn", "dis_num_iter"=>0, "num_iter"=>0),
            "output"=>Dict(
                "checkpoint_hdf5"=>"native.wannierization.h5",
                "num_print_cycles"=>0,
                "num_dump_cycles"=>0,
            ),
        )
        path=joinpath(directory, "native.toml");
        open(io->TOML.print(io, doc), path, "w")
        resolved=r.read_task_input(path);
        input=resolved.config.input
        @test input.win_file === nothing
        @test input.matrix_elements.topology_mmn_file === nothing
        @test !isfile(input.eig_file)
        @test input.geometry.kpoints_fractional == [0.0 0.0 0.0; 0.5 0.0 0.0]
        original=input.matrix_elements.topology
        copy_provider=w.NativeVASPPAWMatrices(original; artifact_dir = joinpath(directory, "copy"))
        @test copy_provider.topology !== original
        @test copy_provider.topology.neighbors !== original.neighbors
        @test copy_provider.topology.source_sha256 == original.source_sha256
        old_provider=w.NativeVASPPAWMatrices("old.mmn"; artifact_dir = "old")
        @test old_provider.topology === nothing && old_provider.require_oracle
        @test_throws ArgumentError r.resolve_workflow_input(
            merge(deepcopy(doc), Dict("matrices"=>Dict("eig_file"=>"fake")));
            base_dir = directory,
        )
        missing=deepcopy(doc);
        delete!(missing, "kmesh")
        @test_throws ArgumentError r.resolve_workflow_input(missing; base_dir = directory)
        wrong=deepcopy(doc);
        wrong["kmesh"]["points_fractional"]=[[0.5, 0.0, 0.0], [0.0, 0.0, 0.0]]
        @test_throws ArgumentError r.resolve_workflow_input(wrong; base_dir = directory)
        result=r.run_task_input(resolved; record_directory = joinpath(directory, "records"))
        println("VASP_ENTRY_STATUS=", result.status)
        for d in result.diagnostics
            ;
            println("VASP_ENTRY_DIAGNOSTIC=", d);
        end
        @test result.status ∉ (w.INVALID_INPUT, w.IO_FAILURE, w.LOCALIZATION_FAILED)
        @test !isempty(result.v_matrix)
        @test isfile(resolved.config.checkpoint.checkpoint_hdf5)
        @test isfile(input.eig_file)
        @test WannierNLQG.IO.read_wannier_eig(input.eig_file).data == [-1.0 -1.0; 1.0 1.0]
        @testset "File-topology VASP external EIG is checked against raw WAVECAR" begin
            provider = w.NativeVASPPAWMatrices(
                "topology.mmn";
                artifact_dir = joinpath(directory, "file-topology"),
                require_oracle = false,
            )
            hybrid_input =
                (; matrix_elements = provider, source = input.source, eig_file = input.eig_file)
            @test !w.uses_generated_native_eigenvalues(hybrid_input)
            @test w.uses_native_operator_generation(hybrid_input)
            @test length(w.native_operator_artifact_paths(hybrid_input, :full, ())) == 10
            extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
            check_eig =
                extension.resolve_wannierization_entrypoint(:_validate_file_topology_vasp_eig)
            fixture = (; input = hybrid_input)
            matrices = (; mmn = (; num_bands = 2, num_kpts = 2))
            @test check_eig(fixture, matrices) === nothing
            changed = joinpath(directory, "different.eig")
            eig = WannierNLQG.IO.read_wannier_eig(input.eig_file)
            different = copy(eig.data)
            different[1, 1] += 0.1
            WannierNLQG.IO.write_wannier_eig(changed, WannierNLQG.IO.WannierEIG(2, 2, different))
            bad = (; input = merge(hybrid_input, (; eig_file = changed)))
            @test_throws ArgumentError check_eig(bad, matrices)
        end
        @test isempty(filter(f->endswith(f, ".win"), readdir(directory)))
        replay=r.read_task_input(joinpath(directory, "records", "effective_config.toml"))
        @test replay.config.input.source.wavecar_file == wavecar
        @test replay.config.input.matrix_elements.topology.source_sha256 == original.source_sha256
        @test !any(d->d.code==:TB_EXPORT_FAILED, result.diagnostics)
    end
end
