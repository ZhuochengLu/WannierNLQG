"""Worker-owned Jerk geometry in eV/Angstrom Cartesian coordinates.

Only regularized optical dipoles, band gradients/Hessians and diagnostics are
stored. No G, velocity, occupation, volume or quadrature object is constructed.
All retained bands still enter the common regularized Hessian preparation.
"""
struct JerkCurrentGeometry
    dipoles::Array{ComplexF64, 3}
    gradients::Matrix{Float64}
    hessians::Array{Float64, 3}
    diagnostics::Vector{Int}
    gap_diagnostics::Vector{Float64}
end

# Allocate only consumed fields once per Jerk worker.
"""Allocate the worker-private dipoles, gradients, Hessians and derivative scratch consumed by Jerk preparation."""
JerkCurrentGeometry(
    count::Integer,
)=JerkCurrentGeometry(
    zeros(ComplexF64, count, count, 3),
    zeros(count, 3),
    zeros(count, 3, 3),
    zeros(Int, 1),
    [Inf, 0.0],
)

# Fill the original ordered regularized Jerk dipoles without changing arithmetic.
function _fill_jerk_current_dipoles!(dipoles, data, regularization)
    energies=data.spectrum.energies
    derivatives=data.hamiltonian_derivatives
    connection=data.internal_connection
    for n in eachindex(energies), m in eachindex(energies), a in 1:3
        gap=energies[n]-energies[m]
        dipoles[
            n,
            m,
            a,
        ]=n==m ? 0 : connection[n, m, a]-im*derivatives[n, m, a]*gap/(gap^2+regularization^2)
    end
    return dipoles
end

"""
Worker-local geometry for jerk and THG in eV/Angstrom Cartesian coordinates.

Dipoles use (bra,ket,axis); derivatives add a final derivative axis. Hessians use
(band,axis,axis). Literal expert storage contains G/iG; combined THG storage
instead contains finite R/complete Q, with no full G tensor. No occupation model,
charge, lifetime, volume or quadrature factor is computed here. General degenerate-subspace dynamics is not represented by this type.
"""
struct ThirdOrderGeometry{D, S, R, Q}
    dipoles::Array{ComplexF64, 3}
    dipole_derivatives::D
    finite_literature_derivatives::R
    literature_derivative_numerators::Q
    velocities::Array{ComplexF64, 3}
    velocity_derivatives::Array{ComplexF64, 4}
    ratios::Array{ComplexF64, 3}
    ratio_derivatives::S
    gradients::Matrix{Float64}
    hessians::Array{Float64, 3}
    bare::Array{ComplexF64, 3}
    regular::Array{ComplexF64, 3}
    regular_dipoles::Array{ComplexF64, 3}
    commutator_a::Matrix{ComplexF64}
    commutator_h::Matrix{ComplexF64}
    diagnostics::Vector{Int}
    gap_diagnostics::Vector{Float64}
end

# Allocate geometry once per worker, independently of mesh and frequency counts.
ThirdOrderGeometry(count::Integer) = ThirdOrderGeometry(count, Val(:literal))
"""Allocate band geometry with explicit literal G storage or combined finite-R/complete-Q storage; reject unknown storage roles."""
function ThirdOrderGeometry(count::Integer, ::Val{Storage}) where {Storage}
    Storage in (:literal, :combined) ||
        throw(ArgumentError("unknown third-order derivative storage role"))
    literal = Storage == :literal
    vertex()=zeros(ComplexF64, count, count, 3)
    derivative()=zeros(ComplexF64, count, count, 3, 3)
    return ThirdOrderGeometry(
        vertex(),
        literal ? derivative() : nothing,
        literal ? nothing : derivative(),
        literal ? nothing : derivative(),
        vertex(),
        derivative(),
        vertex(),
        literal ? derivative() : nothing,
        zeros(count, 3),
        zeros(count, 3, 3),
        vertex(),
        vertex(),
        vertex(),
        zeros(ComplexF64, count, count),
        zeros(ComplexF64, count, count),
        zeros(Int, 1),
        [Inf, 0.0],
    )
end

"""
Output-first SHG/THG optical vertex construction with the shared combined I0 rule.

Endpoint and intermediate-state rules, finite-eta correction and axis order are
identical to `optical_position_vertices`. Reuses O(N_b^2) scratch matrices.
"""
function third_order_optical_vertices!(geometry::ThirdOrderGeometry, data, eta, eta_correction)
    geometry.dipole_derivatives === nothing &&
        throw(ArgumentError("literal optical vertices require literal derivative storage"))
    optical_position_vertices!(
        geometry.bare,
        geometry.regular,
        geometry.dipoles,
        geometry.regular_dipoles,
        geometry.dipole_derivatives,
        geometry.commutator_a,
        geometry.commutator_h,
        data,
        eta,
        eta_correction,
    )
    return geometry
end

"""Prepare E/h/Hessian band fields before occupation derivatives.

No A, r or G is read. Optical fields remain unprepared until the matching endpoint
is supplied to the literal wrapper or combined preparation. The matrix width is
finite and positive; independent spectral/projector denominators are unchanged.
"""
function prepare_third_order_band_geometry!(
    geometry::Union{ThirdOrderGeometry, JerkCurrentGeometry},
    data;
    regularization = 0.001,
)
    isfinite(regularization) && regularization > 0 ||
        throw(ArgumentError("third-order matrix width must be finite and positive"))
    energies=data.spectrum.energies
    count=length(energies)
    gradients=geometry.gradients
    hessians=geometry.hessians
    b=data.hamiltonian_derivatives
    c=data.hamiltonian_second_derivatives
    fill!(geometry.diagnostics, 0)
    geometry.gap_diagnostics .= (Inf, 0.0)
    for n in 1:count, a in 1:3
        gradients[n, a]=real(b[n, n, a])
        for d in 1:3
            value=real(c[n, n, a, d])
            for l in 1:count
                l==n && continue
                gap=energies[n]-energies[l]
                inverse=gap/(gap^2+regularization^2)
                value += 2real(b[n, l, a]*b[l, n, d])*inverse
            end
            hessians[n, a, d]=value
        end
    end
    for n in 1:count, m in 1:count
        n==m && continue
        gap=energies[n]-energies[m]
        geometry.gap_diagnostics[1]=min(geometry.gap_diagnostics[1], abs(gap))
        abs(gap)<1e-12 && (geometry.diagnostics[1]+=1)
    end
    return geometry
end

"""Fill regularized Jerk dipoles, velocity vertices and derivatives from the prepared band geometry in the original loop order."""
function _finish_third_order_jerk_geometry!(geometry, data, regularization)
    energies=data.spectrum.energies
    count=length(energies)
    gradients=geometry.gradients
    hessians=geometry.hessians
    b=data.hamiltonian_derivatives
    connection=data.internal_connection
    _fill_jerk_current_dipoles!(geometry.dipoles, data, regularization)
    for n in 1:count, m in 1:count, a in 1:3
        gap=energies[n]-energies[m]
        geometry.ratios[n, m, a]=n==m ? 0 : im*geometry.dipoles[n, m, a]
        geometry.velocities[n, m, a]=n==m ? gradients[n, a] : b[n, m, a]+im*gap*connection[n, m, a]
        for d in 1:3
            geometry.ratio_derivatives[
                n,
                m,
                a,
                d,
            ]=n==m ? 0 : im*geometry.dipole_derivatives[n, m, a, d]
            geometry.velocity_derivatives[
                n,
                m,
                a,
                d,
            ]=n==m ? hessians[n, a, d] :
              im*(
                (
                    gradients[n, d]-gradients[m, d]
                )*geometry.dipoles[n, m, a]+gap*geometry.dipole_derivatives[n, m, a, d]
            )
        end
    end
    return geometry
end

# The same R/Q producer fills either literal G or compact numerator storage.
function _finish_third_order_harmonic_geometry!(geometry, data, eta, eta_correction)
    energies=data.spectrum.energies
    count=length(energies)
    combined=geometry.finite_literature_derivatives !== nothing
    if combined
        fill!(geometry.finite_literature_derivatives, 0)
        fill!(geometry.literature_derivative_numerators, 0)
    end
    function consume(n, m, a, b, finite, numerator, inverse, difference)
        energy_product=optical_derivative_combination(finite, numerator, inverse, difference)
        geometry.velocity_derivatives[
            n,
            m,
            a,
            b,
        ]=im*(
            (
                geometry.gradients[n, b]-geometry.gradients[m, b]
            )*geometry.dipoles[n, m, a]-energy_product
        )
        if combined
            geometry.finite_literature_derivatives[n, m, a, b]=finite
            geometry.literature_derivative_numerators[n, m, a, b]=numerator
        end
        return nothing
    end
    optical_position_vertices!(
        geometry.bare,
        geometry.regular,
        geometry.dipoles,
        geometry.regular_dipoles,
        geometry.dipole_derivatives,
        geometry.commutator_a,
        geometry.commutator_h,
        data,
        eta,
        eta_correction;
        consume_parts = consume,
    )
    for n in 1:count, m in 1:count, a in 1:3
        gap=energies[n]-energies[m]
        geometry.ratios[n, m, a]=n==m ? 0 : im*geometry.dipoles[n, m, a]
        geometry.velocities[
            n,
            m,
            a,
        ]=n==m ? geometry.gradients[n, a] :
          data.hamiltonian_derivatives[n, m, a]+im*gap*data.internal_connection[n, m, a]
        for b in 1:3
            if n==m
                geometry.velocity_derivatives[n, m, a, b]=geometry.hessians[n, a, b]
            end
            if !combined
                geometry.ratio_derivatives[
                    n,
                    m,
                    a,
                    b,
                ]=n==m ? 0 : im*geometry.dipole_derivatives[n, m, a, b]
            end
        end
        n==m && continue
        actual=data.hamiltonian_derivatives[n, m, a]+im*gap*data.internal_connection[n, m, a]
        geometry.gap_diagnostics[2]=max(
            geometry.gap_diagnostics[2],
            abs(actual-im*gap*geometry.dipoles[n, m, a]),
        )
    end
    return geometry
end

"""Prepare pure R/Q/DV after the matching band fields are ready.

Task-dependent FG/PG combinations are evaluated by their consumers with explicit
signed factors. No occupation-dependent result enters an endpoint/global cache.
"""
function prepare_third_order_combined_geometry!(
    geometry::ThirdOrderGeometry,
    data;
    regularization = 0.001,
    eta_correction = true,
)
    geometry.finite_literature_derivatives === nothing &&
        throw(ArgumentError("combined preparation requires combined derivative storage"))
    return _finish_third_order_harmonic_geometry!(geometry, data, regularization, eta_correction)
end

"""Prepare literal expert G/iG or the unchanged regularized Jerk geometry.

THG workers use explicit combined storage and band -> occupation -> R/Q order.
The default expert constructor retains literal G and iG fields.
"""
function prepare_third_order_geometry!(
    geometry::ThirdOrderGeometry,
    data;
    jerk = false,
    regularization = 0.001,
    eta_correction = true,
)
    geometry.dipole_derivatives === nothing &&
        throw(ArgumentError("expert preparation requires literal derivative storage"))
    prepare_third_order_band_geometry!(geometry, data; regularization)
    return jerk ? _finish_third_order_jerk_geometry!(geometry, data, regularization) :
           _finish_third_order_harmonic_geometry!(geometry, data, regularization, eta_correction)
end

"""Prepare Jerk's regularized dipoles and full-band energy derivatives.

Reuse the common E/h/Hessian producer. No optical derivative, inverse-energy
matrix, velocity or occupation-dependent array is needed by this worker role.
The literal expert overload keeps its existing derived-field preparation.
"""
function prepare_jerk_current_geometry!(geometry::JerkCurrentGeometry, data; regularization = 0.001)
    prepare_third_order_band_geometry!(geometry, data; regularization)
    _fill_jerk_current_dipoles!(geometry.dipoles, data, regularization)
    return geometry
end

# Retain the literal expert preparation through the same explicit Jerk entrance.
"""Prepare literal expert Jerk geometry through the shared explicit jerk entrance, preserving regularization and independent fixed-gap diagnostics."""
prepare_jerk_current_geometry!(geometry::ThirdOrderGeometry, data; regularization = 0.001) =
    prepare_third_order_geometry!(geometry, data; jerk = true, regularization)
