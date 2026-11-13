module ArchivedCheckpointMathTestSupport
using WannierNLQG, HDF5, Test, JSON3
function read_archived_checkpoint_math(asset, oracle)
    w=WannierNLQG.Wannierization
    solver=first(w._load_wannierization_extension!()).SolverCheckpoint
    observed=WannierNLQG.IO.with_scientific_source(realpath(asset)) do path
        solver._read_wannierization_checkpoint_from_source(path; wire_version = "1.4")
    end
    result=observed.value
    HDF5.h5open(asset, "r") do h
        @test String(read(HDF5.attributes(h)["schema_version"]))=="1.4"
        @test result.input_summary["restart_eligible"]=="false"
        @test result.input_summary["restart_input_definition_status"]=="NOT_RECORDED"
        # The old full binary includes retired certificate tokens. It is retained
        # verbatim, not an oracle for the current wire's administrative strings.
        # Independently anchor every solution/history number in its actual
        # archived numerical prefix, then compare the decoded values directly.
        stream=IOBuffer();
        write(stream, "wanniernlqg.checkpoint-definition/1:v2_29\n", string(result.status), '\n')
        for (path, value) in (
            ("solution/v_matrix", result.v_matrix),
            ("solution/wannier_centers_cartesian", result.wannier_centers_cartesian),
            ("solution/spreads_angstrom2", result.spreads_angstrom2),
        )
            raw=read(h[path]);
            @test isequal(raw, value)
            write(stream, reinterpret(UInt8, Int64[ndims(raw), size(raw)...]));
            write(stream, reinterpret(UInt8, vec(raw)))
        end
        for (path, value, cast) in (
            ("history/iteration", [x.iteration for x in result.history], Int),
            ("history/spread_total", [x.spread_total for x in result.history], Float64),
            (
                "history/spread_standard_deviation",
                [x.spread_standard_deviation for x in result.history],
                Float64,
            ),
            (
                "history/maximum_covariance_error",
                [x.maximum_covariance_error for x in result.history],
                Float64,
            ),
        )
            raw=cast.(read(h[path]));
            @test isequal(raw, cast.(value))
            write(stream, reinterpret(UInt8, Int64[length(raw)]));
            write(stream, reinterpret(UInt8, vec(raw)))
        end
        prefix=take!(stream);
        historical=read(oracle)
        @test length(historical)>length(prefix)
        @test historical[1:length(prefix)]==prefix
        if result.restart_state!==nothing
            state=result.restart_state
            for name in (
                :frames,
                :centers_cartesian,
                :spreads_angstrom2,
                :convergence_values,
                :included_bands,
            )
                @test isequal(read(h["restart_state/" * string(name)]), getfield(state, name))
            end
            for name in (
                :fixed_subspace_frames,
                :fixed_subspace_projectors,
                :localization_initial_frames,
                :z_previous,
            )
                value=getfield(state, name)
                if value!==nothing
                    @test isequal(read(h["restart_state/" * string(name)]), value)
                end
            end
        end
    end
    return result
end
# Independent numerical encoding emitted by the actual current producer, not by
# the current HDF reader. Require every component, dimension and bit pattern.
function assert_current_checkpoint_math(result, reference)
    record=JSON3.read(read(reference, String))
    @test record.schema=="wanniernlqg.current-checkpoint-numerical-reference/1"
    @test string(result.status)==record.status
    @test Set(
        String.(keys(record.values)),
    )==Set(("v_matrix", "wannier_centers_cartesian", "spreads_angstrom2"))
    for name in (:v_matrix, :wannier_centers_cartesian, :spreads_angstrom2)
        value=getfield(result, name);
        expected=record.values[String(name)]
        @test collect(size(value))==Int.(expected.shape)
        @test reinterpret(UInt8, vec(real.(value)))==reinterpret(UInt8, Float64.(expected.real))
        @test reinterpret(UInt8, vec(imag.(value)))==reinterpret(UInt8, Float64.(expected.imag))
    end
    return nothing
end

end
