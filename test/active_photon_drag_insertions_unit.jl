@testset "Active external columns retain full finite intermediates, dimension=$dimension" for dimension in
                                                                                              (2, 3)
    E = WannierNLQG.MatrixElements
    R = WannierNLQG.Runtime
    response = WannierNLQG.Responses
    C = WannierNLQG.Core
    n = 64
    energies = vcat(
        collect(range(-6.0, -3.0; length = 30)),
        [-0.02005, -0.02, 0.025, 0.02505],
        collect(range(3.0, 6.0; length = 30)),
    )
    dx = ComplexF64[0.012sin(i+2j) + 0.009im*cos(2i-j) for i in 1:n, j in 1:n]
    dy = ComplexF64[0.011cos(2i+j) + 0.008im*sin(i-2j) for i in 1:n, j in 1:n]
    dx = (dx+dx')/2;
    dy = (dy+dy')/2
    dz = ComplexF64[0.013sin(3i-j) + 0.007im*cos(i+3j) for i in 1:n, j in 1:n]
    dz = dimension == 3 ? (dz+dz')/2 : zeros(ComplexF64, n, n)
    gradient = cat(dx, dy, dz; dims = 3)
    parameters = (Matrix(Diagonal(ComplexF64.(energies))), gradient)
    hamiltonian(k, p) = p[1] + k[1]*p[2][:, :, 1] + k[2]*p[2][:, :, 2] + k[3]*p[2][:, :, 3]
    derivative(k, p) = p[2]
    function make_input(; operators = NamedTuple(), automatic = false, basis = :fixed_orthonormal)
        AnalyticKInput(
            hamiltonian = hamiltonian,
            parameters = parameters,
            derivatives = (automatic ? nothing : derivative, nothing, nothing),
            num_orbitals = n,
            orbital_positions = basis==:point_orbitals ? zeros(3, n) : nothing,
            lattice = Matrix{Float64}(I, 3, 3)*2,
            basis = basis,
            periodic = false,
            derivative_method = automatic ? :automatic : :explicit,
            operators = operators,
            source_file = @__FILE__,
            evaluation_bounds = ((-1.0, -1.0, -1.0), (1.0, 1.0, 1.0)),
        )
    end
    input=make_input();
    model=C.AnalyticKModel(input);
    centers=zeros(3, n)
    @test E.supports_active_velocity_insertions(model, centers, 2)
    @test E.supports_active_velocity_insertions(model, centers, 3)
    @test !E.supports_active_velocity_insertions(model, centers, 4)
    @test !E.supports_active_velocity_insertions(model, ones(3, n), 2)
    @test !E.supports_active_velocity_insertions(
        C.AnalyticKModel(make_input(automatic = true)),
        centers,
        2,
    )
    zero_position(k, p)=zeros(ComplexF64, n, n, 3)
    @test_throws ArgumentError make_input(operators = (position = zero_position,))
    @test !E.supports_active_velocity_insertions(
        C.AnalyticKModel(make_input(basis = :point_orbitals)),
        centers,
        2,
    )
    sampling=dimension == 3 ?
             KRegion(
        origin = (-0.0005, -0.0005, -0.0005),
        vector_1 = (0.001, 0.0, 0.0),
        vector_2 = (0.0, 0.001, 0.0),
        vector_3 = (0.0, 0.0, 0.001),
        k_mesh = (1, 1, 1),
    ) :
             KRegion(
        origin = (-0.0005, -0.0005),
        vector_1 = (0.001, 0.0),
        vector_2 = (0.0, 0.001),
        k_mesh = (1, 1),
    )
    numerics=Numerics(
        broadening = 0.002,
        broadening_type = "Gaussian",
        denominator_regularization = 0.001,
        degeneracy_threshold = 0.0002,
        finite_difference_step = 0.001,
    )
    qcart=[0.0, 1e-4, dimension == 3 ? 7e-5 : 0.0];
    reciprocal=transpose(C.reciprocal_lattice(model.lattice))
    fd=Matrix{Float64}(reciprocal\(Matrix{Float64}(I, 3, 3)*0.001))
    task=TaskSpec(
        id = "active",
        quantity = "PDSC",
        method = "Geometric_Loop",
        physics = FiniteQOpticalParameters(
            photon_energies = [0.045, 0.046],
            photon_momentum = Tuple(qcart),
            fermi_energy = 0.0,
            temperature = 0.0,
        ),
        numerics = numerics,
        observable = FullTensor(),
    )
    cfg=only(
        R.compile_task_configs(
            TaskConfig(
                model = input,
                sampling = sampling,
                tasks = [task],
                execution = ExecutionOptions(fourier_backend = "direct"),
            ),
        ),
    )
    plan=R.bundle_matrix_element_plan(R.normalize_task_specs(cfg), cfg)
    elements=E.MatrixElementWorkspace(n, 0, plan)
    screen=R.make_photon_drag_transition_screen_workspace(
        n,
        0,
        length(cfg.photon_energies);
        matrix_elements = elements,
    )
    @assert size(screen.delta) == (length(cfg.photon_energies), n, n)
    ws=response.make_geometric_loop_response_workspace(
        n,
        0,
        dimension,
        2;
        matrix_elements = elements,
        valence_central_common = screen.valence_data,
        conduction_central_common = screen.conduction_data,
    )
    @test size(ws.central_third_insertions, 3) == dimension
    E.prepare_real_space!(elements, model);
    E.prepare_real_space!(ws.scratch, model)
    # Poison every partial output. Consecutive points/signs/components rebuild the workset.
    previous=nothing
    cases = [
        ([0.0, 0.0, 0.0], 1, nothing),
        ([0.0003, -0.0002, 0.0], -1, [2, 1, 2]),
        ([0.0, 0.0, 0.0], 1, nothing),
    ]
    if dimension == 3
        append!(
            cases,
            [
                ([0.0003, -0.0002, 0.0001], isodd(a+b+c) ? -1 : 1, [a, b, c]) for a in 1:3 for
                b in 1:3 for c in 1:3 if 3 in (a, b, c)
            ],
        )
        push!(cases, ([0.0, 0.0, 0.0], 1, nothing))
    end
    for (point, sign, component) in cases
        k=Vector{Float64}(reciprocal\point);
        q=Vector{Float64}(reciprocal\(sign*qcart))
        R._prepare_photon_drag_transition_screen!(screen, k, q, cfg, model, n)
        @test screen.active
        for field in (
            :forward_overlap_1,
            :forward_overlap_3,
            :backward_overlap_1,
            :backward_overlap_3,
            :central_second_insertions,
            :central_third_insertions,
            :forward_third_insertions,
            :backward_third_insertions,
        )
            fill!(getproperty(ws, field), ComplexF64(NaN, NaN))
        end
        @test R._geometric_loop_prepare_current_kernel_from_photon_drag_transition_screen!(
            ws,
            k,
            screen,
            q,
            fd,
            centers,
            cfg,
            model,
            n,
            dimension,
            50;
            tensor_indices = component,
        )[1]
        @test ws.active_insertions.valence_bands == [31, 32]
        @test ws.active_insertions.conduction_bands == [33, 34]
        candidate=copy(ws.response_kernel)
        # Existing dense implementation, identical eigenframes and physical model.
        for data in (ws.valence_central_data, ws.conduction_central_data)
            E.compute_kpoint!(
                data,
                ws.scratch,
                model,
                copy(data.common.kpoint);
                denominator_regularization = 0.001,
                spatial_dimension = dimension,
            )
        end
        response.compute_geometric_loop_shift_current_kernel!(
            ws,
            k,
            q,
            fd,
            centers,
            0.001,
            0.001,
            dimension,
            model,
            1,
            n;
            tensor_indices = component,
            use_full_velocity_vertices = true,
        )
        reference=copy(ws.response_kernel)
        mask=screen.active_pair_mask
        # Kernel and contracted response have distinct, unchanged mixed gates.
        for indices in (
            component===nothing ? Iterators.product(1:dimension, 1:dimension, 1:dimension) :
            (Tuple(component),)
        )
            a, b, c=indices;
            actual=candidate[:, :, a, b, c][mask];
            expected=reference[:, :, a, b, c][mask]
            @test maximum(abs.(actual-expected) ./ (1e-10 .+ 1e-8 .* abs.(expected))) <= 1
        end
        actual=zeros(ComplexF64, 2, dimension, dimension, dimension);
        expected=zeros(ComplexF64, size(actual)) # This API adds into caller-owned accumulators.
        masked_reference=copy(reference)
        for m in 1:n, v in 1:n
            mask[v, m] || (masked_reference[v, m, :, :, :] .= 0)
        end
        weights=reshape(screen.weighted_occupation_differences, 1, n, n)
        if component===nothing
            response.accumulate_geometric_loop_shift_current_response!(
                actual,
                candidate,
                weights,
                screen.delta,
                ones(2),
                1.0,
                n,
                dimension,
            )
            response.accumulate_geometric_loop_shift_current_response!(
                expected,
                masked_reference,
                weights,
                screen.delta,
                ones(2),
                1.0,
                n,
                dimension,
            )
            @test maximum(abs.(actual-expected) ./ (1e-10 .+ 1e-8 .* abs.(expected))) <= 1
            if previous===nothing
                previous=copy(candidate)
            else
                @test isequal(candidate, previous)
            end
        end
    end
    # Compare paired source-factor reuse against separate ordered preparations.
    # Poison all scratch and vary selections/directions to expose stale reuse.
    for (left_indices, right_indices, directions) in (
        ([31, 32], [33, 34], (1, dimension)),
        ([2, 5, 9], [40], (dimension,)),
        ([1], [63, 64], (1,)),
    )
        separate_forward=zeros(ComplexF64, n, n, 3);
        separate_reverse=similar(separate_forward)
        paired_forward=similar(separate_forward);
        paired_reverse=similar(separate_forward)
        fill!(separate_reverse, ComplexF64(NaN, NaN));
        fill!(paired_forward, ComplexF64(NaN, NaN));
        fill!(paired_reverse, ComplexF64(NaN, NaN))
        scratch=E.ActiveVelocityInsertionWorkspace(n)
        left=ws.valence_central_data.common;
        right=ws.conduction_central_data.common
        E.active_velocity_insertions!(
            separate_forward,
            left,
            right,
            left_indices,
            right_indices,
            directions,
            gradient,
            gradient,
            scratch,
        )
        E.active_velocity_insertions!(
            separate_reverse,
            right,
            left,
            right_indices,
            left_indices,
            directions,
            gradient,
            gradient,
            scratch,
        )
        for buffer in scratch.buffers
            ;
            fill!(buffer, ComplexF64(NaN, NaN));
        end
        E.active_velocity_paired_insertions!(
            paired_forward,
            paired_reverse,
            left,
            right,
            left_indices,
            right_indices,
            directions,
            gradient,
            gradient,
            scratch,
            zeros(ComplexF64, n, n),
        )
        for direction in directions
            @test isequal(
                paired_forward[left_indices, right_indices, direction],
                separate_forward[left_indices, right_indices, direction],
            )
            @test isequal(
                paired_reverse[right_indices, left_indices, direction],
                separate_reverse[right_indices, left_indices, direction],
            )
        end
    end
    # A legal explicit callback may return real matrices. Match the existing
    # ComplexF64 matrix-element storage conversion before the source rotation.
    raw_real=real.(gradient[:, :, 1]);
    spectrum=ws.valence_central_data.spectrum
    reference_velocity=zeros(ComplexF64, n, n);
    temporary=zeros(ComplexF64, n, n)
    E._transform_source_gauge!(
        reference_velocity,
        spectrum.source_eigenvectors_adjoint,
        ComplexF64.(raw_real),
        spectrum.source_eigenvectors,
        temporary,
    )
    actual_velocity=similar(reference_velocity);
    raw_buffer=similar(reference_velocity)
    for selected_rows in (true, false)
        E.selected_source_velocity!(
            actual_velocity,
            raw_real,
            spectrum,
            temporary,
            [31, 32],
            selected_rows,
            raw_buffer,
            zeros(Int, n),
        )
        @test selected_rows ?
              isequal(actual_velocity[[31, 32], :], reference_velocity[[31, 32], :]) :
              isequal(actual_velocity[:, [31, 32]], reference_velocity[:, [31, 32]])
    end
    allocation_counts=Int[]
    for count in (1, 4, 16)
        indices=collect(1:count)
        E.active_velocity_insertions!(
            ws.central_third_insertions,
            ws.valence_central_data.common,
            ws.conduction_central_data.common,
            indices,
            indices,
            (1, dimension),
            gradient,
            gradient,
            ws.active_insertions,
        )
        allocated=@allocated E.active_velocity_insertions!(
            ws.central_third_insertions,
            ws.valence_central_data.common,
            ws.conduction_central_data.common,
            indices,
            indices,
            (1, dimension),
            gradient,
            gradient,
            ws.active_insertions,
        )
        push!(allocation_counts, allocated)
    end
    @test allocation_counts[1] == allocation_counts[2] == allocation_counts[3]
    println("ACTIVE_INSERTION_ALLOCATIONS_1_4_16:", allocation_counts)
    # Dense demand explicitly selects the existing full-work preparation.
    @test !response.prepare_active_geometric_bands!(ws, trues(n, n), 1, n)
    mktempdir() do directory
        function payload(result)
            paths=sort(filter(p->endswith(p, ".dat"), result.outputs))
            @test !isempty(paths)
            [
                reduce(
                    vcat,
                    permutedims.([
                        parse.(Float64, split(line)) for line in eachline(p) if
                        !isempty(strip(line)) && !startswith(strip(line), "#")
                    ]),
                ) for p in paths
            ]
        end
        function tasks(paired)
            physics=paired ?
                    FiniteQOpticalParameters(
                photon_energies = [0.045, 0.046],
                photon_momenta = [Tuple(qcart), Tuple(-qcart)],
                fermi_energy = 0.0,
                temperature = 0.0,
            ) :
                    FiniteQOpticalParameters(
                photon_energies = [0.045, 0.046],
                photon_momentum = Tuple(qcart),
                fermi_energy = 0.0,
                temperature = 0.0,
            )
            [
                TaskSpec(
                    id = "inj",
                    quantity = "PDIC",
                    method = "Conventional",
                    physics = physics,
                    numerics = Numerics(
                        broadening = 0.002,
                        broadening_type = "Gaussian",
                        denominator_regularization = 0.001,
                        degeneracy_threshold = 0.0002,
                    ),
                    observable = FullTensor(),
                ),
                TaskSpec(
                    id = "shift",
                    quantity = "PDSC",
                    method = "Geometric_Loop",
                    physics = physics,
                    numerics = numerics,
                    observable = FullTensor(),
                ),
            ]
        end
        serial=0
        function execute(selected; input_model = input)
            serial+=1
            WannierNLQG.run(
                TaskConfig(
                    model = input_model,
                    sampling = sampling,
                    tasks = selected,
                    execution = ExecutionOptions(fourier_backend = "direct"),
                    output = OutputOptions(
                        output_root = joinpath(directory, string(serial)),
                        system_name = "active",
                        progress_enabled = false,
                        response_output_digits = 17,
                    ),
                ),
            )
        end
        for paired in (false, true)
            cache_values=Any[]
            for budget in ("0", "4096", "16777216")
                withenv("WANNIERNLQG_PHOTON_PATH_CACHE_BYTES"=>budget) do
                    selected=tasks(paired);
                    both=execute(selected)
                    separated=[payload(execute([task])) for task in selected]
                    @test [payload(item) for item in both.task_results] == separated
                    @test all(all(all(isfinite, table) for table in family) for family in separated)
                    push!(cache_values, separated)
                end
            end
            @test cache_values[1] == cache_values[2] == cache_values[3]
        end
        # K-slice uses the same non-prefix component and full group band selection.
        sliced_sampling=KSlice(
            k_mesh = (1, 1),
            spatial_dimension = dimension,
            origin = (0.0, 0.0, 0.0),
            vector_1 = (0.001, 0.0, 0.0),
            vector_2 = (0.0, 0.001, 0.0),
        )
        slice_task=TaskSpec(
            id = "slice",
            quantity = "PDSCK",
            method = "Geometric_Loop",
            physics = FiniteQOpticalParameters(
                photon_energies = [0.045],
                photon_momentum = Tuple(qcart),
                fermi_energy = 0.0,
                temperature = 0.0,
            ),
            numerics = numerics,
            observable = KSliceSelection(
                component = dimension == 3 ? TensorComponent(3, 2, 3) : TensorComponent(2, 1, 2),
                bands = BandSelection(),
            ),
        )
        slice_results=Any[]
        for (label, input_model) in
            (("active", input), ("fallback", make_input(basis = :point_orbitals)))
            result=WannierNLQG.run(
                TaskConfig(
                    model = input_model,
                    sampling = sliced_sampling,
                    tasks = [slice_task],
                    execution = ExecutionOptions(fourier_backend = "direct"),
                    output = OutputOptions(
                        output_root = joinpath(directory, "slice_"*label),
                        system_name = "active",
                        progress_enabled = false,
                        response_output_digits = 17,
                    ),
                ),
            )
            push!(slice_results, payload(result))
        end
        for (a, b) in zip(slice_results...)
            @test size(a)==size(b)
            @test maximum(abs.(a-b) ./ (1e-10 .+ 1e-8 .* abs.(b)))<=1
        end
        # Full actual public fallback with explicitly declared zero position callback.
        optimized=payload(execute([tasks(false)[2]]))
        fallback=payload(
            execute([tasks(false)[2]]; input_model = make_input(basis = :point_orbitals)),
        )
        @test length(optimized)==length(fallback)
        for (a, b) in zip(optimized, fallback)
            @test size(a)==size(b)
            @test maximum(abs.(a-b) ./ (1e-10 .+ 1e-8 .* abs.(b)))<=1
        end
    end
    include("shifted_link_columns_unit.jl")
    include("vertex_column_panels_unit.jl")
    include("working_zero_rotation_unit.jl")
    include("active_velocity_zero_scan_unit.jl")
    include("source_gradient_zero_scan_unit.jl")
end
