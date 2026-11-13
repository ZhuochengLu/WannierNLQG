# Equal-rate Lorentz SHG research and coherent cell images

This explicitly selected expert research path is user-authorized and nondefault.
The compatibility `second_harmonic_response!`, Runtime defaults, Gaussian and seven-term output stay unchanged.

`Responses.SameRateLorentzSHGPolicy(width, fermi_energy, occupied_count)` declares one positive energy damping in both causal propagators and one complete, fixed, gapped T=0 occupied subspace. Use `same_rate_lorentz_shg_geometry` followed by `same_rate_lorentz_shg_response!`. This candidate is currently an explicit expert API, not a newly accepted TOML prescription.

The kernel differentiates the insulating projector by cross-gap divided differences. Equal-occupation and exactly degenerate nodes never require an internal energy inverse. Covariant Hamiltonian jets use raw H/A derivatives, so cell-image and constant degenerate-block transformations act consistently. The complete intermediate band sum is retained. Static eta and the compatibility finite-width regrouping do not enter this path.

The three explicit reduced quantities are relaxation polarization, Hamiltonian current, and polarization current. For exp(-i omega t), J_H=(Gamma-2i omega)P while J_P=-2i omega P in energy units. P is inferred under that declared scalar relaxation model; it is not an independently evaluated periodic position trace. Raw results use positive unit charge; a physical electron result needs the explicit negative q^3 prefactor and matching eV/volume conversions. The research path does not qualify finite-temperature metals, nonorthogonal inputs, physical lifetimes, Gaussian causal broadening or missing-band corrections.

`MatrixElements.relabel_wannier_cell_images(model, q)` explicitly uses integer3xN shifts: R'=R+q_left-q_right, with the matching Cartesian position constant at R=0. It preserves the complete shifted nonzero support and normalizes replica weights.

`MatrixElements.lattice_ws_reinterpolate_hr(model, chk, target; cell_shifts=q)` first makes that common image choice, separates known home position constants, maps unknown homogeneous H/r using the existing q-to-R helper and the actual CHK coordinates, then inserts constants analytically at R=0. It rejects unresolved transverse support instead of flattening it through a coarse plane. The result is an H/r-only diagnostic conversion: off-grid interpolation intentionally changes and it does not claim that the other nine operator classes were converted. The input, old048 and formal pair model are preserved.

The new regression is registered once in ordinary Fast through SCIENTIFIC_REPAIR_FAST_TEST_FILES. It covers independent orbital-basis density matrices, negative-frequency reality, currents/polarization, both center conventions, exact degenerate blocks, cell-image forward/inverse behavior, transverse finite differences, analytic affine split and invalid inputs. Frozen compatibility SHG tests remain part of the focused validation. Fast registration is not an actual full Fast/Full/MPI result.
