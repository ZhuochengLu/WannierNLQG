using WannierNLQG, Test
isdefined(@__MODULE__, :spectral_test_model) ||
    include(joinpath(@__DIR__, "SpectralResponseTestSupport.jl"))
model=joinpath(mktempdir(), "closed_tb.dat")
WannierNLQG.IO.write_wannier_tb(model, spectral_test_model())
@testset "Twelve spectral task combinations" begin
    records=Dict{Tuple, Dict{String, Matrix{Float64}}}()
    named_records=Dict{Tuple, Dict{String, Matrix{Float64}}}()
    for backend in ("Direct", "Mixed"),
        convention in ("Convention_I", "Convention_II"),
        slice in (false, true),
        q in ("linear_transport", "linear_optical_response", "orbital_magnetization"),
        method in ("Conventional", "Projector")

        sampling=slice ?
                 KSlice(
            k_mesh = (2, 2),
            spatial_dimension = 3,
            origin = (0.0, 0.0, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        ) : BZMesh(k_mesh = (2, 2, 2))
        rates=SeparateRelaxation(gamma_intra_ev = 0.04, gamma_inter_ev = 0.05)
        physics=q=="orbital_magnetization" ?
                OrbitalMagnetizationParameters(
            fermi_energies = Float64[0.13],
            temperature = 300.0,
            input_semantics = :defined_finite_model,
        ) :
                q=="linear_transport" ?
                LinearTransportParameters(
            fermi_energies = Float64[0.13],
            temperature = 300.0,
            relaxation = rates,
        ) :
                LinearOpticalResponseParameters(
            fermi_energy = 0.13,
            temperature = 300.0,
            relaxation = rates,
            photon_energies = [0.0, 0.2],
        )
        observable=slice ?
                   KSliceSelection(
            component = q=="orbital_magnetization" ? TensorComponent(3) : TensorComponent(1, 2),
            bands = AllBands(),
        ) : FullTensor()
        id=q*"_"*lowercase(method)*(slice ? "_slice" : "_integral")
        cfg=TaskConfig(
            model = ModelInput(model_file = model, wannier_center_convention = convention),
            sampling = sampling,
            execution = ExecutionOptions(
                fourier_backend = backend,
                NKFFT = backend=="Mixed" ? (slice ? (2, 2) : (2, 2, 2)) : nothing,
            ),
            output = OutputOptions(
                output_root = joinpath(mktempdir(), id),
                progress_enabled = false,
            ),
            tasks = [
                TaskSpec(
                    id = id,
                    quantity = q,
                    method = method,
                    physics = physics,
                    observable = observable,
                ),
            ],
        )
        result=WannierNLQG.run(cfg)
        @test !isempty(result.outputs)
        @test result.qualification.execution_eligible
        @test result.qualification.qualification_status=="DIAGNOSTIC_ONLY"
        @test !result.qualification.production_eligible
        @test result.qualification.quality_review_recommended
        @test "LEGACY_INPUT_QUALIFICATION_NOT_RECORDED" in result.qualification.reasons
        @test occursin("[Qualification]", read(result.metadata_path, String))
        tables=Dict(
            basename(path)=>spectral_test_table(path) for
            path in result.outputs if endswith(path, ".dat")
        )
        named_records[(backend, convention, slice, method, q)]=tables
        if q=="linear_optical_response"
            metadata=only(
                filter(path -> endswith(path, "spectral_response_metadata.txt"), result.outputs),
            )
            @test occursin(
                "terms = (\"drude\", \"quantum_metric\", \"berry_curvature\", \"total\")",
                read(metadata, String),
            )
            for term in ("drude", "quantum_metric", "berry_curvature", "total")
                suffix=slice ? "_integrand" : ""
                @test haskey(
                    tables,
                    "linear_optical_response_$(term)"*(slice ? "_E00001" : "")*".dat",
                )
                term=="total" && !slice && continue
                @test haskey(tables, "model_dielectric_increment_$(term)$(suffix)_E00002.dat")
            end
            !slice && @test haskey(tables, "model_dielectric_tensor_E00002.dat")
        end
        key=(slice, q)
        if haskey(records, key)
            @test keys(tables)==keys(records[key])
            for name in keys(tables)
                @test isapprox(tables[name], records[key][name]; rtol = 2e-11, atol = 1e-28)
            end
        else
            records[key]=tables
        end
    end
    for backend in ("Direct", "Mixed"),
        convention in ("Convention_I", "Convention_II"),
        slice in (false, true),
        method in ("Conventional", "Projector")

        dc=named_records[(backend, convention, slice, method, "linear_transport")]
        optical=named_records[(backend, convention, slice, method, "linear_optical_response")]
        columns=slice ? (4:5) : (2:19)
        for term in ("drude", "quantum_metric", "berry_curvature", "total")
            dc_table=dc["linear_transport_$(term).dat"]
            optical_table=optical["linear_optical_response_$(term)" * (slice ? "_E00001" : "") * ".dat"]
            !slice && @test iszero(optical_table[1, 1])
            @test isapprox(
                slice ? optical_table[:, columns] : optical_table[1:1, columns],
                dc_table[:, columns];
                rtol = 2e-10,
                atol = 2e-8,
            )
            if slice || term!="total"
                positive=slice ? optical["linear_optical_response_$(term)_E00002.dat"] :
                         optical_table[2:2, :]
                suffix=slice ? "_integrand" : ""
                dielectric=optical["model_dielectric_increment_$(term)$(suffix)_E00002.dat"]
                factor=im/(
                    WannierNLQG.Responses.RESPONSE_EPSILON0*0.2 /
                    WannierNLQG.Responses.RESPONSE_HBAR_EVS
                )
                for column in first(columns):2:(last(columns) - 1)
                    conductivity=complex.(positive[:, column], positive[:, column + 1])
                    increment=complex.(dielectric[:, column], dielectric[:, column + 1])
                    @test isapprox(increment, factor .* conductivity; rtol = 2e-10, atol = 2e-8)
                end
            end
        end
    end
end

@testset "Response parameter rejection" begin
    makecfg(
        physics;
        numerics = nothing,
        quantity = "linear_transport",
        sampling = BZMesh(k_mesh = (2, 2, 2)),
    )=TaskConfig(
        model = ModelInput(model_file = model),
        sampling = sampling,
        execution = ExecutionOptions(fourier_backend = "Direct"),
        tasks = [
            TaskSpec(
                id = "reject",
                quantity = quantity,
                method = "Conventional",
                physics = physics,
                numerics = numerics,
            ),
        ],
    )
    rates=SeparateRelaxation(gamma_intra_ev = 0.04, gamma_inter_ev = 0.05)
    @test_throws ArgumentError WannierNLQG.Runtime.compile_task_configs(
        makecfg(
            LinearTransportParameters(
                fermi_energies = Float64[0.0],
                temperature = 0.0,
                relaxation = rates,
            ),
        ),
    )
    @test_throws ArgumentError WannierNLQG.Runtime.compile_task_configs(
        makecfg(
            LinearTransportParameters(
                fermi_energies = Float64[0.0],
                temperature = 300.0,
                relaxation = rates,
            );
            numerics = LinearResponseNumerics(
                fermi_surface = FermiSurfaceBroadening(kind = :gaussian, eta_fs_ev = 0.02),
            ),
        ),
    )
    @test_throws ArgumentError WannierNLQG.Runtime.compile_task_configs(
        makecfg(
            LinearTransportParameters(
                fermi_energies = Float64[0.0],
                temperature = 300.0,
                relaxation = SeparateRelaxation(gamma_intra_ev = 0.0, gamma_inter_ev = 0.1),
            ),
        ),
    )
    @test_throws ErrorException WannierNLQG.Runtime.compile_task_configs(
        makecfg(
            LinearTransportParameters(
                fermi_energies = Float64[0.0],
                temperature = 300.0,
                relaxation = rates,
            );
            sampling = BZMesh(k_mesh = (2, 2)),
        ),
    )
end
