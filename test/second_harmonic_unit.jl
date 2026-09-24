using Test, LinearAlgebra
using WannierNLQG

# Minimal reader for the frozen numeric fixture/output tables, without optional packages.
function shg_numeric_table(path; comments = true)
    rows=[
        parse.(Float64, split(line)) for
        line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
    ]
    return permutedims(reduce(hcat, rows))
end

@testset "Second harmonic response contracts" begin
    response = WannierNLQG.Responses
    matrices = WannierNLQG.MatrixElements
    root = dirname(@__DIR__)
    theory_text = read(joinpath(root, "theory", "SecondHarmonicGeneration.md"), String)
    @test startswith(theory_text, "# Second-harmonic generation\n")
    @test !occursin("Wannier90", theory_text)
    @test !occursin("wannier90", theory_text)
    @test occursin("6. P. Garcia-Goiricelaya", theory_text)
    @test !occursin(r"(?m)^7\. ", theory_text)
    model_path = joinpath(root, "examples", "fixtures", "synthetic_runtime", "synthetic_tb.dat")
    model = WannierNLQG.IO.read_wannier_tb(model_path)
    plan = matrices.compile_matrix_plan(
        matrices.MatrixElementRequest(
            matrices.BERRY_CONNECTION,
            matrices.INTERNAL_CONNECTION_DERIVATIVES,
            matrices.HAMILTONIAN_SECOND_DERIVATIVES,
        ),
    )
    workspace = matrices.MatrixElementWorkspace(model, plan)
    matrices.prepare_real_space!(workspace, model)
    data = matrices.compute_kpoint!(workspace, model, [0.17, 0.23, 0.31])
    frequencies = [0.0, 0.1, 0.73, 1.7]
    components = response.SECOND_HARMONIC_COMPONENTS
    output = zeros(ComplexF64, length(frequencies), 18, 7, 2)
    options = (;
        fermi_energy = 0.0,
        temperature = 0.0,
        broadening = 0.025,
        low_frequency_broadening = 0.025,
        gaussian = true,
        intermediate_regularization = 0.04,
        eta_correction = true,
        degeneracy_threshold = 0.002,
    )
    response.second_harmonic_response!(output, data, frequencies, components; options...)
    for bands in (2, 3, 4),
        point in ([0.17, 0.23, 0.31], [0.0, 0.0, 0.0]),
        gaussian in (true, false),
        correction in (true, false)

        matrices.compute_kpoint!(workspace, model, point)
        selected=bands==2 ? (2:3) : (1:bands)
        selected_data=(;
            spectrum = (; energies = data.spectrum.energies[selected]),
            internal_connection = data.internal_connection[selected, selected, :],
            hamiltonian_derivatives = data.hamiltonian_derivatives[selected, selected, :],
            internal_connection_derivatives = data.internal_connection_derivatives[
                selected,
                selected,
                :,
                :,
            ],
            hamiltonian_second_derivatives = data.hamiltonian_second_derivatives[
                selected,
                selected,
                :,
                :,
            ],
        )
        response.second_harmonic_response!(
            output,
            selected_data,
            frequencies,
            components;
            merge(options, (; gaussian, eta_correction = correction))...,
        )
        name=(bands==4 ? "" : string(bands)*"band_") *
             (iszero(point) ? "gamma" : "generic") *
             "_" *
             (gaussian ? "gaussian" : "lorentzian") *
             "_" *
             (correction ? "corrected" : "uncorrected") *
             ".dat"
        reference=shg_numeric_table(
            joinpath(@__DIR__, "fixtures/second_harmonic", name);
            comments = true,
        )
        expected=reshape(reference[:, 1] .+ im .* reference[:, 2], length(frequencies), 18, 2)
        @test dropdims(sum(output; dims = 3); dims = 3) ≈ expected atol=1e-10 rtol=1e-8
    end
    matrices.compute_kpoint!(workspace, model, [0.17, 0.23, 0.31])
    response.second_harmonic_response!(output, data, frequencies, components; options...)
    @test all(isfinite, output)
    @test iszero(output[:, :, 6:7, :])
    swapped = similar(output)
    response.second_harmonic_response!(
        swapped,
        data,
        frequencies,
        [(a, c, b) for (a, b, c) in components];
        options...,
    )
    @test swapped ≈ output atol=1e-10 rtol=1e-8
    for temperature in (0.0, 1e-7)
        response.second_harmonic_response!(
            swapped,
            data,
            frequencies,
            components;
            merge(options, (; temperature))...,
        )
        @test swapped == output
    end
    metallic_options=merge(
        options,
        (; temperature = 300.0, fermi_energy = data.spectrum.energies[2]),
    )
    response.second_harmonic_response!(swapped, data, frequencies, components; metallic_options...)
    @test any(!iszero, swapped[:, :, 7, :])
    @test any(!iszero, swapped[:, :, 6, :])
    for (i, (a, b, c)) in enumerate(components)
        a == b == c || continue
        @test iszero(swapped[:, i, 6, :])
    end
    @test response.second_harmonic_delta(0.0, 0.025, true) ≈ 1/(sqrt(pi)*0.025)
    @test response.second_harmonic_delta(0.0, 0.025, false) ≈ 1/(pi*0.025)
    mktempdir() do directory
        function configuration(
            sampling;
            output = :both,
            quantity = :both,
            numerics = SHGNumerics(),
            energy = [0.1],
            execution = ExecutionOptions(fourier_backend = "Direct"),
        )
            task = TaskSpec(
                id = "shg",
                quantity = "SHG",
                method = "Conventional",
                physics = SHGParameters(
                    photon_energies = energy,
                    fermi_energy = 0.0,
                    temperature = 0.0,
                    output = output,
                    response = quantity,
                ),
                numerics = numerics,
                observable = sampling isa KSlice ?
                             KSliceSelection(
                    component = TensorComponent(1, 1, 1),
                    bands = AllBands(),
                ) : FullTensor(),
            )
            return TaskConfig(
                model = ModelInput(model_file = model_path, real_space_replica_policy = "input"),
                sampling = sampling,
                tasks = [task],
                execution = execution,
                output = OutputOptions(
                    output_root = joinpath(directory, string(time_ns())),
                    progress_enabled = false,
                ),
            )
        end
        mesh=BZMesh(k_mesh = (2, 2, 1), spatial_dimension = 3)
        slice=KSlice(
            k_mesh = (2, 2),
            spatial_dimension = 3,
            origin = (0.0, 0.0, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        )
        integral=WannierNLQG.run(configuration(mesh))
        sliced=WannierNLQG.run(configuration(slice))
        @test all(
            result.qualification.execution_eligible &&
            result.qualification.qualification_status=="DIAGNOSTIC_ONLY" &&
            !result.qualification.production_eligible for result in (integral, sliced)
        )
        @test length(integral.outputs)==36
        @test length(sliced.outputs)==2
        for quantity in ("chi", "sigma")
            full=shg_numeric_table(
                only(filter(p->endswith(p, "$(quantity)_xxx.dat"), integral.outputs));
                comments = true,
            )
            plane=shg_numeric_table(
                only(filter(p->endswith(p, "$(quantity)_xxx.dat"), sliced.outputs));
                comments = true,
            )
            @test vec(sum(plane[:, 5:end]; dims = 1))/4 ≈ vec(full[:, 2:end]) atol=1e-10 rtol=1e-8
            @test full[1, 2]+im*full[1, 3] ≈ sum(full[1, 4:2:end] .+ im .* full[1, 5:2:end]) atol=1e-10 rtol=1e-8
        end
        skew = KSlice(
            k_mesh = (9, 8),
            spatial_dimension = 3,
            origin = (0.13, -0.07, 0.11),
            vector_1 = (1.0, 1.0, 0.0),
            vector_2 = (0.0, 1.0, 1.0),
        )
        skew_direct = WannierNLQG.run(configuration(skew; energy = [0.7]))
        skew_mixed = WannierNLQG.run(
            configuration(
                skew;
                energy = [0.7],
                execution = ExecutionOptions(
                    fourier_backend = "Mixed",
                    NKdiv = (3, 2),
                    NKFFT = (3, 4),
                ),
            ),
        )
        for (direct_path, mixed_path) in zip(skew_direct.outputs, skew_mixed.outputs)
            @test shg_numeric_table(direct_path) ≈ shg_numeric_table(mixed_path) atol=1e-10 rtol=1e-8
        end
        for selection in (:total, :terms), quantity in (:susceptibility, :conductivity)
            result=WannierNLQG.run(configuration(slice; output = selection, quantity = quantity))
            @test length(result.outputs)==1
            values=shg_numeric_table(only(result.outputs); comments = true)
            @test size(values, 2)==(selection==:total ? 6 : 18)
        end
        for numerics in (
            SHGNumerics(broadening = -1.0),
            SHGNumerics(low_frequency_broadening = 0.0),
            SHGNumerics(broadening_type = "invalid"),
        )
            @test_throws ArgumentError WannierNLQG.Runtime.compile_task_configs(
                configuration(mesh; numerics),
            )
        end
        @test_throws ArgumentError WannierNLQG.Runtime.compile_task_configs(
            configuration(mesh; output = :invalid),
        )
        @test_throws ArgumentError WannierNLQG.Runtime.compile_task_configs(
            configuration(mesh; energy = [-0.1]),
        )
    end
end

@testset "Independent finite-temperature velocity-curvature contraction" begin
    response = WannierNLQG.Responses
    # Hermitian manufactured matrices with nonzero couplings to every model band.
    # The reference uses the covariant Wannier curvature and position products,
    # independently of the differentiated-eigenvector implementation.
    for bands in (2, 3, 4)
        energies = [-0.8, 0.0, 1.1, 2.3][1:bands]
        connection = zeros(ComplexF64, bands, bands, 3)
        velocity = similar(connection)
        derivatives = zeros(ComplexF64, bands, bands, 3, 3)
        second = similar(derivatives)
        for a in 1:3, n in 1:bands, m in 1:bands
            connection[n, m, a] = cos(n+m+a)/7 + im*sin(n-m)*a/11
            velocity[n, m, a] = sin(n+m+2a)/5 + im*sin(n-m)*a/13
            for b in 1:3
                derivatives[n, m, a, b] = cos(n+m+2a+b)/17 + im*sin(n-m)*a*b/19
                second[n, m, a, b] = cos(n+m+a+b)/23 + im*sin(n-m)*a*b/29
            end
        end
        bare = zeros(ComplexF64, bands, bands, 3)
        for n in 1:bands, m in 1:bands, a in 1:3
            n == m && continue
            bare[n, m, a] = velocity[n, m, a]/(energies[m]-energies[n])
        end
        data=(;
            spectrum = (; energies),
            internal_connection = connection,
            hamiltonian_derivatives = velocity,
            internal_connection_derivatives = derivatives,
            hamiltonian_second_derivatives = second,
        )
        position=connection+im*bare
        curvature=zeros(Float64, bands, 3, 3)
        for a in 1:3, c in 1:3
            covariant=derivatives[
                :,
                :,
                c,
                a,
            ]-derivatives[
                :,
                :,
                a,
                c,
            ]-im*(connection[:, :, a]*connection[:, :, c]-connection[:, :, c]*connection[:, :, a])
            for n in 1:bands
                curvature[
                    n,
                    a,
                    c,
                ]=real(
                    covariant[n, n],
                )-2imag(sum(position[n, m, a]*position[m, n, c] for m in 1:bands))
            end
        end
        levi(a, b, c)=((a-b)*(b-c)*(c-a))÷2
        kt=8.617333262145e-5*300.0
        fp=-exp(-0.5*(0.007/kt)^2)/(kt*sqrt(2pi)) # Only band 2 is inside the 5 kBT window.
        fpp=0.007/kt^2*fp
        omega=[curvature[2, 2, 3], curvature[2, 3, 1], curvature[2, 1, 2]]
        @test abs(omega[3]) > 1e-5
        for gaussian in (true, false)
            frequencies=[0.0, 0.03, 0.7]
            out=zeros(ComplexF64, 3, 18, 7, 2)
            response.second_harmonic_one_band!(
                out,
                data,
                frequencies,
                response.SECOND_HARMONIC_COMPONENTS,
                bare;
                fermi_energy = 0.007,
                temperature = 300.0,
                low_frequency_broadening = 0.025,
                gaussian,
                eta = 0.04,
                degeneracy_threshold = 0.002,
            )
            for (index, (a, b, c)) in enumerate(response.SECOND_HARMONIC_COMPONENTS)
                bcd=fp*sum(
                    (
                        real(velocity[2, 2, b])*levi(a, c, d)+real(velocity[2, 2, c])*levi(a, b, d)
                    )*omega[d] for d in 1:3
                )
                hess=real(
                    second[2, 2, b, c],
                )+sum(
                    2real(
                        velocity[2, m, b]*velocity[m, 2, c],
                    )*(energies[2]-energies[m])/((energies[2]-energies[m])^2+0.04^2) for
                    m in 1:bands if m!=2
                )
                sc=fp*real(velocity[2, 2, a])*hess+fpp*prod(
                    real(velocity[2, 2, d]) for d in (a, b, c)
                )
                for (f, w) in enumerate(frequencies)
                    low=w/(w^2+0.025^2)
                    delta=gaussian ? exp(-(w/0.025)^2)/(sqrt(pi)*0.025) : 0.025/(pi*(w^2+0.025^2))
                    kernel=low-im*delta
                    @test out[f, index, 6, 1] ≈ -bcd*kernel*low/4 atol=1e-10 rtol=1e-8
                    @test out[f, index, 6, 2] ≈ im*bcd*kernel/2 atol=1e-10 rtol=1e-8
                    @test out[f, index, 7, 1] ≈ -im*sc*kernel*low^2/4 atol=1e-10 rtol=1e-8
                    @test out[f, index, 7, 2] ≈ -sc*kernel*low/2 atol=1e-10 rtol=1e-8
                end
                a==b==c && @test iszero(out[:, index, 6, :])
            end
            # xyy must select Omega_z with the positive Levi-Civita sign.
            expected_xyy=2fp*real(velocity[2, 2, 2])*omega[3]
            @test abs(expected_xyy)>1e-5
            @test out[3, 2, 6, 2] ≈
                  im*expected_xyy*(
                0.7/(
                    0.7^2+0.025^2
                )-im*(gaussian ? exp(-(0.7/0.025)^2)/(sqrt(pi)*0.025) : 0.025/(pi*(0.7^2+0.025^2)))
            )/2 atol=1e-10 rtol=1e-8
        end
    end
end
