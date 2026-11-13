"""Cartesian lattice and centers of either native input."""
function point_orbital_geometry(input::AnalyticKInput)
    input.basis == :point_orbitals ||
        throw(ArgumentError("point-orbital symmetry requires actual point-orbital positions"))
    return (input.lattice, input.orbital_positions)
end
"""Extract native hopping centers from the home-cell diagonal position matrix."""
point_orbital_geometry(input::RealSpaceTBInput) =
    (input.model.lattice, extract_wannier_centers(input.model))

"""Derivative jet of a native Hamiltonian in the input Convention-II frame."""
function native_hamiltonian_jet(input::RealSpaceTBInput, k, order)
    model=input.model
    n=model.num_orbitals
    result=zeros(ComplexF64, n, n, ntuple(_->3, order)...)
    for r in 1:model.num_r_vectors
        displacement=transpose(model.lattice)*model.r_vectors[:, r]
        phase=exp(im*sum(displacement .* k))
        for index in CartesianIndices(ntuple(_->3, order))
            factor=phase*prod((im*displacement[a] for a in Tuple(index)); init = 1.0+0im)
            view(result,:,:,(Tuple(index)...)) .+= factor .* model.hamiltonian_r[:, :, r]
        end
    end
    return result
end
"""Use declared analytic derivatives without a surrogate Fourier model."""
native_hamiltonian_jet(
    input::AnalyticKInput,
    k,
    order,
)=analytic_hamiltonian_derivative(input, k, order)

"""Infer cell shifts for each nonzero representation entry, without changing centers."""
function point_orbital_symmetry_geometry(input, operation)
    lattice, centers=point_orbital_geometry(input)
    # Cartesian columns equal lattice' times fractional columns.
    rotation=transpose(lattice)*operation.rotation_fractional/transpose(lattice)
    isapprox(rotation' * rotation, Matrix{Float64}(I, 3, 3); atol = 1e-11, rtol = 1e-9) ||
        throw(ArgumentError("symmetry rotation is not Cartesian orthogonal"))
    n=size(centers, 2)
    size(operation.representation)==(n, n) ||
        throw(DimensionMismatch("symmetry representation dimension"))
    fractional=transpose(lattice)\centers
    shifts=zeros(Float64, n, n, 3)
    for j in 1:n, i in 1:n
        abs(operation.representation[i, j]) <= 1e-14 && continue
        displacement=operation.rotation_fractional*fractional[
            :,
            j,
        ]+operation.translation_fractional-fractional[:, i]
        integer=round.(Int, displacement)
        maximum(abs, displacement-integer)<=1e-10 ||
            throw(ArgumentError("symmetry representation violates orbital-center mapping"))
        shifts[i, j, :].=transpose(lattice)*integer
    end
    return (rotation = rotation, shifts = shifts)
end

"""Bloch representation derivatives with respect to the original Cartesian k."""
function point_orbital_sewing(operation, geometry, k, axes = ())
    transform=(operation.antiunitary ? -1 : 1)*geometry.rotation
    target=transform*k
    n=size(operation.representation, 1)
    result=similar(operation.representation)
    for j in 1:n, i in 1:n
        shift=geometry.shifts[i, j, :]
        result[
            i,
            j,
        ]=operation.representation[i, j] *
          exp(-im*sum(target .* shift)) *
          prod((-im*sum(transform[:, a] .* shift) for a in axes); init = 1.0+0im)
    end
    return result
end

"""Check space-group closure modulo translations and projective spin phases."""
function validate_point_orbital_group(input, operations)
    isempty(operations) && throw(ArgumentError("empty point-orbital symmetry group"))
    geometries=[point_orbital_symmetry_geometry(input, op) for op in operations]
    identity=Matrix{Int}(I, 3, 3)
    any(
        op->op.rotation_fractional==identity &&
            !op.antiunitary &&
            maximum(abs, op.translation_fractional-round.(op.translation_fractional))<1e-10,
        operations,
    ) || throw(ArgumentError("symmetry group lacks identity"))
    for (ia, a) in enumerate(operations), (ib, b) in enumerate(operations)
        rotation=a.rotation_fractional*b.rotation_fractional
        translation=a.rotation_fractional*b.translation_fractional+a.translation_fractional
        anti=xor(a.antiunitary, b.antiunitary)
        matches=findall(
            op->op.rotation_fractional==rotation &&
                op.antiunitary==anti &&
                maximum(
                    abs,
                    (
                        translation-op.translation_fractional
                    )-round.(translation-op.translation_fractional),
                )<1e-10,
            operations,
        )
        length(matches)==1 || throw(
            ArgumentError("symmetry group is not uniquely closed modulo lattice translations"),
        )
        ic=only(matches)
        for k in ([0.0, 0.0, 0.0], [0.173, 0.237, 0.319])
            kb=(b.antiunitary ? -1 : 1)*geometries[ib].rotation*k
            ub=point_orbital_sewing(b, geometries[ib], k)
            product=point_orbital_sewing(a, geometries[ia], kb)*(a.antiunitary ? conj.(ub) : ub)
            reference=point_orbital_sewing(operations[ic], geometries[ic], k)
            phase=sum(conj.(reference) .* product)/size(reference, 1)
            isapprox(abs(phase), 1; atol = 1e-10, rtol = 1e-8) &&
            isapprox(product, phase*reference; atol = 1e-10, rtol = 1e-8) ||
                throw(ArgumentError("orbital representations do not close projectively"))
        end
    end
    return geometries
end

"""Validate H and derivative covariance on actual requested points; never infer a symmetry."""
function validate_point_orbital_covariance(input, operations, points; max_order = 2)
    geometries=validate_point_orbital_group(input, operations)
    maximum_residual=0.0
    for k in points, (operation, geometry) in zip(operations, geometries)
        transform=(operation.antiunitary ? -1 : 1)*geometry.rotation
        target=transform*k
        source_jets=[native_hamiltonian_jet(input, k, order) for order in 0:max_order]
        target_jets=[native_hamiltonian_jet(input, target, order) for order in 0:max_order]
        for order in 0:max_order, index in CartesianIndices(ntuple(_->3, order))
            axes=Tuple(index)
            left=zeros(ComplexF64, size(source_jets[1]))
            for transformed in CartesianIndices(ntuple(_->3, order))
                weight=prod((transform[transformed[j], axes[j]] for j in 1:order); init = 1.0)
                left .+= weight .* view(target_jets[order + 1],:,:,(Tuple(transformed)...))
            end
            right=zeros(ComplexF64, size(left))
            for assignment in Iterators.product(ntuple(_->1:3, order)...)
                ua=Tuple(axes[j] for j in 1:order if assignment[j]==1)
                ha=Tuple(axes[j] for j in 1:order if assignment[j]==2)
                va=Tuple(axes[j] for j in 1:order if assignment[j]==3)
                h=view(source_jets[length(ha) + 1],:,:,(ha...))
                right .+=
                    point_orbital_sewing(operation, geometry, k, ua) *
                    (operation.antiunitary ? conj.(h) : h) *
                    point_orbital_sewing(operation, geometry, k, va)'
            end
            residual=maximum(abs, left-right)
            maximum_residual=max(maximum_residual, residual)
            isapprox(left, right; atol = 1e-10, rtol = 1e-8) || throw(
                ArgumentError(
                    "native Hamiltonian derivative covariance failed at order $order, k=$k, residual=$residual",
                ),
            )
        end
        if haskey(input.operators, :spin)
            sewing=point_orbital_sewing(operation, geometry, k)
            axial=(operation.antiunitary ? -1 : 1)*det(geometry.rotation)*geometry.rotation
            spin=input.operators.spin
            for a in 1:3
                left=sewing*(operation.antiunitary ? conj.(spin[:, :, a]) : spin[:, :, a])*sewing'
                right=sum(axial[b, a]*spin[:, :, b] for b in 1:3)
                isapprox(left, right; atol = 1e-10, rtol = 1e-8) ||
                    throw(ArgumentError("native local-spin covariance failed"))
            end
        end
    end
    return (status = "PASS", maximum_absolute_residual = maximum_residual, max_order = max_order)
end
