"""Extract home-cell Wannier centers from the model position matrices."""
function extract_wannier_centers(model::TightBindingModel)
    wannier_centers = zeros(Float64, 3, model.num_orbitals)
    found_home_cell = false
    @inbounds for r_vector_index in 1:model.num_r_vectors
        if all(iszero, @view model.r_vectors[:, r_vector_index])
            for orbital_index in 1:model.num_orbitals
                for direction in 1:3
                    wannier_centers[direction, orbital_index] = real(
                        model.position_r[orbital_index, orbital_index, direction, r_vector_index],
                    )
                end
            end
            found_home_cell = true
            break
        end
    end
    found_home_cell || error("Could not find home-cell position matrix in model data.")
    return wannier_centers
end
