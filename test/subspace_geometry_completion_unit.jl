using Test, LinearAlgebra, Random, WannierNLQG

@testset "Subspace Sylvester position contract" begin
    M = WannierNLQG.MatrixElements
    rng = MersenneTwister(915)
    energy = [0.0, 0.0, 2.0, 2.0]
    vertex = zeros(ComplexF64, 4, 4, 3)
    for a in 1:3
        v = randn(rng, ComplexF64, 4, 4)
        vertex[:, :, a] = v + v'
    end
    blocks = M.spectral_subspace_blocks(energy)
    @test blocks == [1:2, 3:4]
    r = zeros(ComplexF64, 4, 4, 3)
    M.solve_subspace_position!(r, energy, vertex, blocks)
    for a in 1:3
        @test 2r[3:4, 1:2, a] ≈ -im*vertex[3:4, 1:2, a] atol=1e-14
        @test r[:, :, a] ≈ r[:, :, a]' atol=1e-14
    end
    ua = Matrix(qr(randn(rng, ComplexF64, 2, 2)).Q)
    ub = Matrix(qr(randn(rng, ComplexF64, 2, 2)).Q)
    u = zeros(ComplexF64, 4, 4);
    u[1:2, 1:2] = ua;
    u[3:4, 3:4] = ub
    rotated = similar(vertex)
    for a in 1:3
        rotated[:, :, a] = u'*vertex[:, :, a]*u
    end
    rr = zero(r);
    M.solve_subspace_position!(rr, energy, rotated, blocks)
    for a in 1:3
        @test rr[:, :, a] ≈ u'*r[:, :, a]*u atol=1e-13
    end
    @test_throws ArgumentError M.solve_subspace_position!(r, energy, vertex, [1:1, 2:4])
    @test_throws ArgumentError M.solve_subspace_position!(r, energy, vertex, [1:2, 2:4])
    @test_throws ArgumentError M.solve_subspace_position!(r, energy, vertex, [1:2])
    @test_throws ErrorException M.spectral_subspace_blocks([0.0, 1e-12, 2.0])
    @test M.spectral_subspace_blocks([0.0, 1e-8, 2.0]) == [1:1, 2:2, 3:3]
end

# Minimal complete endpoint/operator data for the response-only trace entrypoint.
function photon_drag_active_scope_fixture(
    valence_energies,
    conduction_energies;
    valence_tolerance = 1e-10,
    conduction_tolerance = 1e-10,
)
    count = length(valence_energies)
    @assert length(conduction_energies) == count
    valence_velocity = zeros(ComplexF64, count, count, 1)
    conduction_velocity = zeros(ComplexF64, count, count, 1)
    overlap = Matrix{ComplexF64}(I, count, count)
    valence = (;
        spectrum = (; energies = copy(valence_energies)),
        spectral_gap_tolerance = valence_tolerance,
        source_gauge_hamiltonian_derivatives = valence_velocity,
    )
    conduction = (;
        spectrum = (; energies = copy(conduction_energies)),
        spectral_gap_tolerance = conduction_tolerance,
        source_gauge_hamiltonian_derivatives = conduction_velocity,
    )
    return (; valence, conduction, valence_velocity, conduction_velocity, overlap, count)
end

# Call the actual response kernel with fresh caller-owned outputs and fixed operators.
function photon_drag_active_scope_complete(fixture; mask = nothing)
    count = fixture.count
    kernel = fill(ComplexF64(7, 2), count, count, 1, 1, 1)
    forward = zeros(ComplexF64, count, count, 1)
    backward = similar(forward)
    fill!(backward, 0)
    result = WannierNLQG.Responses.complete_photon_drag_injection_degenerate_blocks!(
        kernel,
        forward,
        backward,
        fixture.overlap,
        fixture.overlap',
        fixture.valence,
        fixture.conduction,
        fixture.valence_velocity,
        fixture.conduction_velocity,
        count,
        1;
        active_pair_mask = mask,
    )
    @test result === kernel
    return (; kernel, forward, backward)
end

# Deliberately wrong band axes, requiring rejection before Boolean mask reduction.
struct PhotonDragShiftedMask <: AbstractMatrix{Bool}
    count::Int
end
Base.size(mask::PhotonDragShiftedMask) = (mask.count, mask.count)
Base.axes(mask::PhotonDragShiftedMask) = (0:(mask.count - 1), 0:(mask.count - 1))
Base.getindex(::PhotonDragShiftedMask, ::Int, ::Int) = false

@testset "Injection exact-block guard follows complete active external blocks" begin
    M = WannierNLQG.MatrixElements
    near = [0.0, 1e-12, 1.0, 2.0]
    separated = [-3.0, -2.0, -1.0, 0.0]
    fixture = photon_drag_active_scope_fixture(near, separated)
    @test_throws ErrorException M.spectral_subspace_blocks(near)
    @test_throws ErrorException photon_drag_active_scope_complete(fixture)
    @test_throws ErrorException photon_drag_active_scope_complete(fixture; mask = trues(4, 4))
    untouched = photon_drag_active_scope_complete(fixture; mask = falses(4, 4))
    @test untouched.kernel == fill(ComplexF64(7, 2), 4, 4, 1, 1, 1)
    @test fixture.valence.spectrum.energies == near
    # An active far block does not certify either inactive near-boundary block.
    far_mask = falses(4, 4)
    far_mask[4, 4] = true
    @test photon_drag_active_scope_complete(fixture; mask = far_mask).kernel == untouched.kernel
    # Guard each side independently, before the all-singleton early return.
    for band in (1, 2)
        valence_mask = falses(4, 4)
        valence_mask[band, 4] = true
        @test_throws ErrorException photon_drag_active_scope_complete(fixture; mask = valence_mask)
        conduction_fixture = photon_drag_active_scope_fixture(separated, near)
        conduction_mask = falses(4, 4)
        conduction_mask[4, band] = true
        @test_throws ErrorException photon_drag_active_scope_complete(
            conduction_fixture;
            mask = conduction_mask,
        )
    end
    # The boundary member itself is inactive; a later member activates its entire exact block.
    later_member = [0.0, 1e-12, 1e-12, 1e-12, 1.0]
    other = [-3.0, -2.0, -1.0, 1.0, 3.0]
    later_mask = falses(5, 5)
    later_mask[4, 5] = true
    @test_throws ErrorException photon_drag_active_scope_complete(
        photon_drag_active_scope_fixture(later_member, other);
        mask = later_mask,
    )
    @test_throws ErrorException photon_drag_active_scope_complete(
        photon_drag_active_scope_fixture(other, later_member);
        mask = permutedims(later_mask),
    )
    # The original strict > boundary and its tolerance are unchanged.
    for gap in (prevfloat(1e-10), 1e-10)
        boundary = photon_drag_active_scope_fixture([0.0, gap, 1.0, 2.0], separated)
        @test_throws ErrorException photon_drag_active_scope_complete(boundary; mask = trues(4, 4))
    end
    above = photon_drag_active_scope_fixture([0.0, nextfloat(1e-10), 1.0, 2.0], separated)
    @test photon_drag_active_scope_complete(above; mask = trues(4, 4)).kernel == untouched.kernel
    for bad in (zeros(4, 4), ones(Int, 4, 4), falses(4), true, missing)
        @test_throws ArgumentError photon_drag_active_scope_complete(fixture; mask = bad)
    end
    for bad in (falses(3, 4), falses(4, 5), PhotonDragShiftedMask(4))
        @test_throws DimensionMismatch photon_drag_active_scope_complete(fixture; mask = bad)
    end
    for tolerance in (-1.0, Inf, NaN)
        @test_throws ArgumentError photon_drag_active_scope_complete(
            photon_drag_active_scope_fixture(near, separated; valence_tolerance = tolerance);
            mask = falses(4, 4),
        )
        @test_throws ArgumentError photon_drag_active_scope_complete(
            photon_drag_active_scope_fixture(separated, near; conduction_tolerance = tolerance);
            mask = falses(4, 4),
        )
    end
    for bad_energies in ([0.0, 2.0, 1.0, 3.0], [0.0, NaN, 1.0, 2.0])
        @test_throws ArgumentError photon_drag_active_scope_complete(
            photon_drag_active_scope_fixture(bad_energies, separated);
            mask = falses(4, 4),
        )
    end
    @test_throws ErrorException M.spectral_subspace_blocks(near) # Shared policy is still strict.
end

@testset "Injection inactive-boundary scope preserves full intermediate trace bits" begin
    # Active valence1:2 / conduction3:4 blocks are exact multiplets. Bands5/6
    # have an inactive unresolved boundary but band5 contributes to both vertices.
    near = [-2.0, -2.0, 1.0, 2.0, 4.0, 4.0 + 1e-12]
    separated = [-3.0, -2.0, 2.0, 2.0, 5.0, 6.0]
    fixture = photon_drag_active_scope_fixture(near, separated)
    fixture.valence_velocity[1, 5, 1] = fixture.valence_velocity[5, 1, 1] = 2
    fixture.valence_velocity[2, 5, 1] = fixture.valence_velocity[5, 2, 1] = 1
    fixture.conduction_velocity[3, 3, 1] = 3
    fixture.conduction_velocity[4, 4, 1] = 4
    fixture.overlap[:, [3, 5]] = fixture.overlap[:, [5, 3]]
    mask = falses(6, 6)
    mask[1:2, 3:4] .= true
    @test_throws ErrorException photon_drag_active_scope_complete(fixture)
    actual = photon_drag_active_scope_complete(fixture; mask)
    @test actual.kernel[1:2, 3:4, 1, 1, 1] == fill(ComplexF64(15 / 16), 2, 2)
    # Preserve every exact block but resolve only the unused boundary for the
    # strict reference. Energies are absent from the original trace arithmetic.
    reference = deepcopy(fixture)
    reference.valence.spectrum.energies[6] = 4.0 + 1e-8
    expected = photon_drag_active_scope_complete(reference; mask)
    for key in (:kernel, :forward, :backward)
        @test reinterpret(UInt64, vec(getproperty(actual, key))) ==
              reinterpret(UInt64, vec(getproperty(expected, key)))
    end
    # On the original defined domain, no-mask and all-active return identical bits.
    strict = photon_drag_active_scope_complete(reference)
    all_active = photon_drag_active_scope_complete(reference; mask = trues(6, 6))
    for key in (:kernel, :forward, :backward)
        @test reinterpret(UInt64, vec(getproperty(strict, key))) ==
              reinterpret(UInt64, vec(getproperty(all_active, key)))
    end
    # An incorrect truncation of the inactive intermediate must be detectable.
    truncated = deepcopy(fixture)
    truncated.valence_velocity[1:2, 5, 1] .= 0
    truncated.valence_velocity[5, 1:2, 1] .= 0
    wrong = photon_drag_active_scope_complete(truncated; mask)
    @test wrong.kernel[1, 3, 1, 1, 1] != actual.kernel[1, 3, 1, 1, 1]
    # Activating either side of the unresolved full-spectrum boundary rejects.
    for band in (5, 6)
        changed = copy(mask)
        changed[band, 3] = true
        @test_throws ErrorException photon_drag_active_scope_complete(fixture; mask = changed)
    end
end

@testset "Moving one-band frame: external metric and derivatives" begin
    M = WannierNLQG.MatrixElements;
    C = WannierNLQG.Core;
    R = WannierNLQG.Responses
    # u(k)=(cos(sin(k)),sin(sin(k))) has A=0 and g_xx=cos(k)^2.
    # lattice=1 Å; fractional k maps to Cartesian 2πk.
    rv = [0 2 -2; 0 0 0; 0 0 0]
    h = zeros(ComplexF64, 1, 1, 3);
    h[1, 1, 1]=1
    a = zeros(ComplexF64, 1, 1, 3, 3)
    model = C.TightBindingModel(Matrix{Float64}(I, 3, 3), 1, 3, ones(Int, 3), rv, h, a)
    f = zeros(ComplexF64, 1, 1, 3, 3, 3)
    f[1, 1, 1, 1, :] .= [0.5, 0.25, 0.25]
    sources = M.MatrixElementSources(; derivative_overlap = M.DerivativeOverlapRealSpaceData(f))
    plan = M.compile_matrix_plan(M.MatrixElementRequest(M.BERRY_CONNECTION))
    workspace = M.MatrixElementWorkspace(model, plan, sources)
    M.prepare_real_space!(workspace, model)
    data=workspace.data
    data.metric_completion_required=true
    k=[0.073, 0, 0];
    x=2pi*k[1]
    M.compute_kpoint!(workspace, model, k)
    @test R.quantum_metric_group_sum_component(data, [1], [1, 1], 1) ≈ cos(x)^2 atol=1e-13
    @test R.quantum_metric_group_sum_component(data, [1], [1, 1], 1; contribution = :internal) == 0
    @test R.quantum_metric_band_sum_component(data, [1, 1], 1, [0.4]) ≈ 0.4cos(x)^2 atol=1e-13
    gws=R.make_conventional_quantum_geometry_workspace(1, 3, 3, 1; matrix_elements = workspace)
    errors=Float64[]
    for step in (0.02, 0.01, 0.005)
        vectors=C.finite_difference_step_matrix(model, step)
        d=R.quantum_metric_dipole_component!(
            gws,
            model,
            k,
            vectors,
            [1],
            [1, 1, 1],
            step,
            0.001,
            1,
            3,
        )
        q=R.quantum_metric_quadrupole_component!(
            gws,
            model,
            k,
            vectors,
            [1],
            [1, 1, 1, 1],
            step,
            0.001,
            1,
            3,
        )
        @test real(d) ≈ -sin(2x) atol=4step^2
        @test real(q) ≈ -2cos(2x) atol=4step^2
        push!(errors, abs(real(d)+sin(2x)))
    end
    @test errors[2] < errors[1]/3
    @test errors[3] < errors[2]/3
    bare=M.MatrixElementWorkspace(model, plan);
    M.prepare_real_space!(bare, model);
    M.compute_kpoint!(bare, model, k)
    @test_throws ErrorException R.quantum_metric_group_sum_component(bare.data, [1], [1, 1], 1)
    old=copy(data.berry_connection)
    M.subspace_connection(data)
    @test data.berry_connection == old
end

@testset "Full-space wavefunction oracle for a retained two-band model" begin
    M=WannierNLQG.MatrixElements;
    C=WannierNLQG.Core;
    R=WannierNLQG.Responses
    rv=[0 2 -2; 0 0 0; 0 0 0]
    h=zeros(ComplexF64, 2, 2, 3)
    h[:, :, 2]=[-0.5 0.5im; 0.5im 0.5];
    h[:, :, 3]=h[:, :, 2]'
    a=zeros(ComplexF64, 2, 2, 3, 3)
    f=zeros(ComplexF64, 2, 2, 3, 3, 3);
    f[1, 1, 1, 1, 1]=1
    model=C.TightBindingModel(Matrix{Float64}(I, 3, 3), 2, 3, ones(Int, 3), rv, h, a)
    sources=M.MatrixElementSources(; derivative_overlap = M.DerivativeOverlapRealSpaceData(f))
    plan=M.compile_matrix_plan(
        M.MatrixElementRequest(M.BERRY_CONNECTION; denominator_regularization = 0.0),
    )
    ws=M.MatrixElementWorkspace(model, plan, sources);
    M.prepare_real_space!(ws, model)
    ws.data.metric_completion_required=true
    for x in (0.13, 0.47, 1.12)
        M.compute_kpoint!(ws, model, [x/(2pi), 0, 0]; denominator_regularization = 0.0)
        # Full state u_1=(cos(x)^2,sin(x),sin(x)*cos(x)); direct derivative norm.
        u=[cos(x)^2, sin(x), sin(x)*cos(x)]
        du=[-sin(2x), cos(x), cos(2x)]
        oracle=dot(du, du)-abs2(dot(u, du))
        @test real(R.quantum_metric_component(ws.data, 1, [1, 1], 2)) ≈ oracle atol=2e-12
        @test real(R.quantum_metric_group_sum_component(ws.data, [1, 2], [1, 1], 2)) ≈ 1 atol=2e-12
        @test real(R.quantum_metric_band_sum_component(ws.data, [1, 1], 2, [1.0, 1.0])) ≈ 3 atol=2e-12
        strict_r=copy(M.subspace_connection(ws.data))
        strict_v=copy(M.subspace_velocity_vertices(ws.data))
        M.compute_kpoint!(ws, model, [x/(2pi), 0, 0]; denominator_regularization = 0.2)
        @test M.subspace_connection(ws.data) == strict_r
        @test M.subspace_velocity_vertices(ws.data) == strict_v
        for n in 1:2, m in 1:2
            @test strict_v[n, m, 1] ==
                  im*(ws.data.spectrum.energies[n]-ws.data.spectrum.energies[m])*strict_r[n, m, 1]
        end
    end
end

include(joinpath(@__DIR__, "support", "GeometricResponseDegeneracyFixture.jl"))
