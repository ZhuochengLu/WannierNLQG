module StarPolicyPersistenceContracts
using Test, HDF5, LinearAlgebra, WannierNLQG
const STAR_POLICY_W = WannierNLQG.Wannierization
const STAR_POLICY_EXTENSION = let extension=first(STAR_POLICY_W._load_wannierization_extension!())
    Base.invokelatest(getproperty, extension, :PAWMatrixElements)
end

isdefined(@__MODULE__, :BandPublicSchemaTestSupport) ||
    include(joinpath(@__DIR__, "BandPublicSchemaTestSupport.jl"))

# Read a single test attribute under a fully closed public HDF5 lifetime.
function read_star_policy_attribute(path, group_name, key)
    return HDF5.h5open(path, "r") do file
        group=file[group_name]
        try
            haskey(HDF5.attributes(group), key) || return nothing
            attribute=HDF5.attributes(group)[key]
            try
                return String(read(attribute))
            finally
                close(attribute)
            end
        finally
            close(group)
        end
    end
end

# Derive the actual complete policy values from the same supported policy objects.
function star_policy_test_values(kind, policy)
    metadata=Base.invokelatest(
        kind==:block ? STAR_POLICY_EXTENSION._star_block_partition_policy_metadata :
        STAR_POLICY_EXTENSION._star_hamiltonian_correction_metadata,
        policy,
    )
    definition=Base.invokelatest(
        STAR_POLICY_EXTENSION._star_block_partition_policy_definition,
        metadata,
    )
    key=kind==:block ? "block_partition_policy_definition" :
        "discrete_hamiltonian_correction_definition"
    return metadata, key, definition
end

@testset "current star policy complete-value public reader contract" begin
    foundation=WannierNLQG.SymmetryFoundation
    mktempdir() do directory
        prepared=BandPublicSchemaTestSupport.prepare_public_band_fixture(
            BandPublicSchemaTestSupport.raw_time_reversal_representation_fixture();
            directory = joinpath(directory, "prepared"),
            projection_basis = BandPublicSchemaTestSupport.single_site_s_basis(spinor = true),
            construction_policy = :standard,
            compatibility_policy = :warn,
        )
        # Synthetic identity-gauge persistence contracts only: these labels and
        # reads establish no native PAW/material qualification or certificate.
        for (case_index, (kind, policy)) in enumerate((
            (:block, STAR_POLICY_W.FixedGapPAWBlockPartition()),
            (:block, STAR_POLICY_W.AdaptiveEvidencePAWBlockPartition()),
            (:block, STAR_POLICY_W.HamiltonianWeightedPAWBlockPartition()),
            (:correction, STAR_POLICY_W.NoDiscreteHamiltonianCorrection()),
            (:correction, STAR_POLICY_W.FarBandCovarianceCorrection()),
        ))
            @testset "$(kind) $(nameof(typeof(policy)))" begin
                representation=deepcopy(prepared.representation)
                conventions=representation.conventions
                conventions["wavefunction_gauge_backend"]="star_covariant_paw"
                conventions["quality_review_recommended"]=get(
                    conventions,
                    "quality_review_recommended",
                    "false",
                )
                conventions["production_eligible"]="false"
                for (other_kind, selected) in (
                    (:block, kind==:block ? policy : STAR_POLICY_W.FixedGapPAWBlockPartition()),
                    (
                        :correction,
                        kind==:correction ? policy :
                        STAR_POLICY_W.NoDiscreteHamiltonianCorrection(),
                    ),
                )
                    values, definition_key, complete=star_policy_test_values(other_kind, selected)
                    merge!(conventions, values)
                    conventions[definition_key]=complete
                end
                metadata, key, definition=star_policy_test_values(kind, policy)
                policy_key=kind==:block ? "block_partition_policy" :
                           "discrete_hamiltonian_correction"
                parameter=first(sort!(filter(k->k!=policy_key, collect(keys(metadata)))))
                parameter_value=metadata[parameter]
                valid=joinpath(directory, "policy-$(case_index).h5")
                written=foundation.write_band_representation_hdf5(
                    valid,
                    representation;
                    content_authentication = false,
                    inventory = prepared.inventory,
                    qualification_scope = prepared.qualification_scope,
                    raw_diagnostics = prepared.raw_diagnostics,
                    requested_policy = prepared.requested_compatibility_policy,
                    effective_policy = prepared.effective_compatibility_policy,
                    symmetry_tolerance_status = prepared.symmetry_tolerance_status,
                )
                @test written==valid
                restored=foundation.read_band_representation_hdf5(
                    valid;
                    content_authentication = false,
                )
                @test restored.conventions[key]==definition
                @test restored.energies_ev==prepared.representation.energies_ev
                @test restored.sewing_matrices==prepared.representation.sewing_matrices
                for (fault, expected_error) in (
                    (:missing_definition, "gauge policy complete definition differs"),
                    (:mirror_definition, "gauge policy complete definition differs"),
                    (:same_changed_parameter, "gauge policy complete definition differs"),
                    (
                        :missing_parameter,
                        "gauge policy is missing mathematical parameter $(parameter)",
                    ),
                    (
                        :one_changed_parameter,
                        "gauge policy mathematical parameter differs: $(parameter)",
                    ),
                )
                    @testset "$(fault)" begin
                        damaged=joinpath(directory, "policy-$(case_index)-$(fault).h5")
                        cp(valid, damaged)
                        chmod(damaged, 0o600)
                        changed_key=fault in (:missing_definition, :mirror_definition) ? key :
                                    parameter
                        targets=fault==:missing_definition ? ("conventions",) :
                                fault in (:mirror_definition, :one_changed_parameter) ?
                                ("wavefunction_gauge",) : ("conventions", "wavefunction_gauge")
                        original_value=changed_key==key ? definition : parameter_value
                        for target in targets
                            @test read_star_policy_attribute(
                                damaged,
                                target,
                                changed_key,
                            )==original_value
                        end
                        HDF5.h5open(damaged, "r+") do file
                            for target in targets
                                group=file[target]
                                try
                                    HDF5.delete_attribute(group, changed_key)
                                    if !(fault in (:missing_definition, :missing_parameter))
                                        HDF5.attributes(group)[changed_key]=original_value*"-changed"
                                    end
                                finally
                                    close(group)
                                end
                            end
                        end
                        for target in targets
                            expected=fault in (:missing_definition, :missing_parameter) ? nothing :
                                     original_value*"-changed"
                            @test read_star_policy_attribute(damaged, target, changed_key)==expected
                        end
                        rejected=try
                            foundation.read_band_representation_hdf5(
                                damaged;
                                content_authentication = false,
                            )
                            nothing
                        catch error
                            error
                        end
                        @test rejected isa ArgumentError
                        @test rejected!==nothing &&
                              occursin(expected_error, sprint(showerror, rejected))
                    end
                end
            end
        end
    end
end

end
