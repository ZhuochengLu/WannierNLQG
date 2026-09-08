using Test
using JSON3
using LinearAlgebra
using SHA
using HDF5

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const FIXTURES = joinpath(@__DIR__, "fixtures")
const PYTHON = something(Sys.which("python3"), "")
isempty(PYTHON) && error("python3 is required for visualization focused tests")

@testset "publication environment and dependency failures" begin
    probe = joinpath(ROOT, "scripts", "visualization", "check_environment.py")
    negatives = joinpath(@__DIR__, "environment_unit.py")
    @test success(Base.run(ignorestatus(`$(PYTHON) $(probe)`)))
    @test success(Base.run(ignorestatus(`$(PYTHON) $(negatives)`)))
end

function process_exitcode(command)
    process = Base.run(pipeline(command, stdout = devnull, stderr = devnull); wait = false)
    wait(process)
    return process.exitcode
end

function png_dimensions(path::AbstractString)
    bytes = read(path)
    length(bytes) >= 24 || error("PNG is too short")
    bytes[1:8] == UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a] ||
        error("invalid PNG signature")
    decode(offset) =
        (Int(bytes[offset]) << 24) | (Int(bytes[offset + 1]) << 16) |
        (Int(bytes[offset + 2]) << 8) | Int(bytes[offset + 3])
    return decode(17), decode(21)
end

include(joinpath(ROOT, "scripts", "plot_band_structure.jl"))

@testset "visualization shared contracts" begin
    bands = joinpath(FIXTURES, "bands.dat")
    path = joinpath(FIXTURES, "band_path.json")
    @test_throws ErrorException BandStructurePlot.validate_cli_contract([bands, path])
    @test_throws ErrorException BandStructurePlot.validate_cli_contract([
        "--bands",
        bands,
        "--path",
        path,
    ],)
    @test_throws ErrorException BandStructurePlot.validate_cli_contract(String[])
    @test BandStructurePlot.validate_cli_contract(["--help"]) === nothing
    @test process_exitcode(
        `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band-manifest removed.json`,
    ) != 0

    mktempdir() do directory
        advanced_band = joinpath(directory, "advanced_band")
        @test BandStructurePlot.main([
            "--config",
            joinpath(FIXTURES, "band_compare.json"),
            "--output",
            advanced_band,
            "--python",
            PYTHON,
        ],) == 0
        @test BandStructurePlot.main([
            "--config",
            joinpath(FIXTURES, "band_compare.json"),
            "--validate-only",
            "--python",
            PYTHON,
        ],) == 0
        @test isfile(advanced_band * ".pdf")
        @test isfile(advanced_band * ".png")
        advanced_audit = JSON3.read(read(advanced_band * ".plot.json", String))
        @test advanced_audit.comparisons[1].max_abs_ev == 0.0
        @test advanced_audit.comparisons[1].energy_shift == "none"
        @test String(advanced_audit.resolved_config.curves.reference.marker) == "o"
        @test advanced_audit.resolved_config.style.minor_ticks == false
        @test Float64(advanced_audit.resolved_config.style.major_tick_length) == 3.5
        @test advanced_audit.production_eligible == false

        unequal_config = joinpath(directory, "unequal_display_only.json")
        unequal_manifest =
            JSON3.read(read(joinpath(FIXTURES, "band_compare.json"), String), Dict{String, Any})
        unequal_manifest["comparison_audit"] = "display_only"
        unequal_manifest["reference"]["bands"] = bands
        unequal_manifest["reference"]["path"] = path
        unequal_manifest["models"][1]["bands"] = bands
        unequal_manifest["models"][1]["path"] = path
        unequal_manifest["models"][1]["band_indices_zero_based"] = [0]
        unequal_manifest["output"]["stem"] = joinpath(directory, "unequal_display_only")
        open(unequal_config, "w") do stream
            JSON3.write(stream, unequal_manifest)
        end
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(unequal_config)`,
        )
        unequal_audit =
            JSON3.read(read(joinpath(directory, "unequal_display_only.plot.json"), String))
        @test String(unequal_audit.comparisons[1].audit_mode) == "display_only"
        @test Int(unequal_audit.comparisons[1].reference_band_count) == 2
        @test Int(unequal_audit.comparisons[1].model_band_count) == 1
        @test String(unequal_audit.comparisons[1].numerical_difference) == "not_computed"

        unequal_manifest["comparison_audit"] = "equal_bandwise"
        open(unequal_config, "w") do stream
            JSON3.write(stream, unequal_manifest)
        end
        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(unequal_config) --validate-only`,
        ) != 0

        full_model_bands = joinpath(directory, "full_model_bands.dat")
        write(
            full_model_bands,
            "# energy_reference_E_ref_eV = 5.00000000000000000e+00\n" *
            "# energy_convention = ascending_eigenvalues_minus_E_ref\n" *
            "# energy_unit = eV\n" *
            "# distance_A^-1 k1_fractional k2_fractional k3_fractional band_1_minus_E_ref_eV\n" *
            "0.0 0.0 0.0 0.0 -0.9\n" *
            "0.5 0.25 0.0 0.0 -0.4\n" *
            "1.0 0.5 0.0 0.0 -0.2\n",
        )
        full_match_map = joinpath(directory, "full_match_map.csv")
        write(
            full_match_map,
            "kpoint_one_based,model_band_one_based,reference_band_one_based," *
            "reference_energy_ev,model_energy_ev,signed_error_ev," *
            "cluster_mismatch_count_at_k\n" *
            "1,1,1,-1.0,-0.9,0.1,0\n" *
            "2,1,1,-0.5,-0.4,0.1,0\n" *
            "3,1,1,-0.25,-0.2,0.05,0\n",
        )
        full_config = joinpath(directory, "full_display_with_errors.json")
        full_manifest = Dict{String, Any}(
            "mode" => "compare",
            "comparison_audit" => "full_display_sets",
            "reference" => Dict(
                "type" => "wanniernlqg",
                "id" => "dft",
                "label" => "Complete DFT display set",
                "bands" => bands,
                "path" => path,
                "fitted_band_indices_zero_based" => [0],
            ),
            "models" => [
                Dict{String, Any}(
                    "type" => "wanniernlqg",
                    "id" => "tb",
                    "label" => "Complete TB model",
                    "bands" => full_model_bands,
                    "path" => path,
                ),
            ],
            "display_window_policy" => Dict(
                "mode" => "full_model_with_reference_context",
                "padding_ev" => 0.1,
                "unfitted_reference_bands_below" => 0,
                "unfitted_reference_bands_above" => 1,
                "minimum_unmatched_reference_states_per_k" => 1,
                "maximum_unmatched_reference_states_per_k" => 1,
            ),
            "error_assessment" => Dict(
                "mode" => "precomputed_match_map",
                "maps" => [
                    Dict(
                        "model_id" => "tb",
                        "data" => full_match_map,
                        "expected_sha256" => bytes2hex(open(sha256, full_match_map)),
                        "index_base" => 1,
                        "energy_convention" => "relative_to_reference",
                        "columns" => Dict(
                            "kpoint" => "kpoint_one_based",
                            "model_band" => "model_band_one_based",
                            "reference_band" => "reference_band_one_based",
                            "reference_energy_ev" => "reference_energy_ev",
                            "model_energy_ev" => "model_energy_ev",
                            "signed_error_ev" => "signed_error_ev",
                            "cluster_mismatch_count" => "cluster_mismatch_count_at_k",
                        ),
                    ),
                ],
                "title" => "Precomputed-map error assessment",
            ),
            "output" => Dict(
                "stem" => joinpath(directory, "full_display_with_errors"),
                "formats" => ["pdf", "png"],
            ),
        )
        open(full_config, "w") do stream
            JSON3.write(stream, full_manifest)
        end
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(full_config)`,
        )
        for suffix in
            (".pdf", ".png", ".plot.json", "_errors.pdf", "_errors.png", "_errors.plot.json")
            @test isfile(joinpath(directory, "full_display_with_errors" * suffix))
        end
        full_audit =
            JSON3.read(read(joinpath(directory, "full_display_with_errors.plot.json"), String))
        @test String(full_audit.comparisons[1].mode) == "full_display_sets"
        @test Int(full_audit.comparisons[1].reference_loaded_band_count) == 2
        @test Int(full_audit.comparisons[1].model_loaded_band_count) == 1
        @test Bool(full_audit.comparisons[1].all_model_bands_fully_visible)
        @test Bool(full_audit.comparisons[1].requested_unfitted_context_fully_visible)
        @test Int(
            full_audit.comparisons[1].unmatched_reference_states_in_window.tb.minimum_per_k,
        ) == 1
        @test Int(
            full_audit.comparisons[1].unmatched_reference_states_in_window.tb.maximum_per_k,
        ) == 1
        @test collect(Int, full_audit.comparisons[1].reference_visible_band_indices_zero_based) ==
              [0, 1]
        @test isapprox(Float64(full_audit.resolved_config.energy_window[1]), -1.0; atol = 1.0e-14)
        @test isapprox(Float64(full_audit.resolved_config.energy_window[2]), 2.1; atol = 1.0e-14)
        error_audit = JSON3.read(
            read(joinpath(directory, "full_display_with_errors_errors.plot.json"), String),
        )
        @test String(error_audit.plot_kind) == "band_error_assessment"
        @test String(error_audit.comparisons[1].audit_mode) == "precomputed_match_map"
        @test Int(error_audit.comparisons[1].matched_sample_count) == 3
        @test isapprox(
            Float64(error_audit.comparisons[1].global_rms_ev),
            sqrt((0.1^2 + 0.1^2 + 0.05^2) / 3);
            atol = 1.0e-14,
        )

        clipped_manifest = deepcopy(full_manifest)
        clipped_manifest["energy_window"] = [-0.8, 1.9]
        clipped_config = joinpath(directory, "clipped_full_display.json")
        open(clipped_config, "w") do stream
            JSON3.write(stream, clipped_manifest)
        end
        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(clipped_config) --validate-only`,
        ) != 0

        selected_manifest = deepcopy(full_manifest)
        selected_manifest["models"][1]["band_indices_zero_based"] = [0]
        selected_config = joinpath(directory, "selected_full_display.json")
        open(selected_config, "w") do stream
            JSON3.write(stream, selected_manifest)
        end
        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(selected_config) --validate-only`,
        ) != 0

        tampered_map = read(full_match_map, String)
        write(
            full_match_map,
            replace(tampered_map, "3,1,1,-0.25,-0.2,0.05,0" => "3,1,1,-0.25,-0.2,0.06,0"),
        )
        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(full_config) --validate-only`,
        ) != 0

        shifted_bands = joinpath(directory, "shifted_bands.dat")
        write(
            shifted_bands,
            replace(
                read(bands, String),
                "# energy_reference_E_ref_eV = 5.00000000000000000e+00" => "# energy_reference_E_ref_eV = 5.25000000000000000e+00",
            ),
        )
        shifted_config = joinpath(directory, "shifted_config.json")
        shifted_manifest =
            JSON3.read(read(joinpath(FIXTURES, "band_compare.json"), String), Dict{String, Any})
        shifted_manifest["reference"]["bands"] = bands
        shifted_manifest["reference"]["path"] = path
        shifted_manifest["models"][1]["bands"] = shifted_bands
        shifted_manifest["models"][1]["path"] = path
        shifted_manifest["output"]["stem"] = joinpath(directory, "must_not_render")
        open(shifted_config, "w") do stream
            JSON3.write(stream, shifted_manifest)
        end
        shifted_process = Base.run(
            pipeline(
                `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(shifted_config) --validate-only`,
                stdout = devnull,
                stderr = devnull,
            );
            wait = false,
        )
        wait(shifted_process)
        @test shifted_process.exitcode != 0

        digest_mismatch_config = joinpath(directory, "digest_mismatch_config.json")
        digest_mismatch =
            JSON3.read(read(joinpath(FIXTURES, "band_compare.json"), String), Dict{String, Any})
        digest_mismatch["reference"]["bands"] = bands
        digest_mismatch["reference"]["path"] = path
        digest_mismatch["models"][1]["bands"] = bands
        digest_mismatch["models"][1]["path"] = path
        digest_mismatch["reference"]["expected_sha256"] = Dict("bands" => repeat("0", 64))
        open(digest_mismatch_config, "w") do stream
            JSON3.write(stream, digest_mismatch)
        end
        digest_process = Base.run(
            pipeline(
                `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(digest_mismatch_config) --validate-only`,
                stdout = devnull,
                stderr = devnull,
            );
            wait = false,
        )
        wait(digest_process)
        @test digest_process.exitcode != 0

        xml_process = Base.run(
            pipeline(
                `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(joinpath(FIXTURES, "xml_band_compare.json")) --validate-only`,
                stdout = devnull,
                stderr = devnull,
            );
            wait = false,
        )
        wait(xml_process)
        @test xml_process.exitcode == 0

        standard_process = Base.run(
            pipeline(
                `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(joinpath(FIXTURES, "standard_band_compare.json")) --validate-only`,
                stdout = devnull,
                stderr = devnull,
            );
            wait = false,
        )
        wait(standard_process)
        @test standard_process.exitcode == 0

        vasp_single_stem = joinpath(directory, "vasp_native_single")
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(joinpath(FIXTURES, "vasp_native_single.json")) --output $(vasp_single_stem)`,
        )
        vasp_single_audit = JSON3.read(read(vasp_single_stem * ".plot.json", String))
        @test String(vasp_single_audit.datasets[1].source_type) == "vasp_eigenval_kpoints"
        @test Int(vasp_single_audit.datasets[1].kpoint_count) == 4
        @test Int(vasp_single_audit.datasets[1].band_count) == 2
        @test Int(vasp_single_audit.resolved_config.style.dpi) == 600

        vasp_compare_stem = joinpath(directory, "vasp_native_compare")
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(joinpath(FIXTURES, "vasp_native_compare.json")) --output $(vasp_compare_stem)`,
        )
        vasp_compare_audit = JSON3.read(read(vasp_compare_stem * ".plot.json", String))
        @test vasp_compare_audit.comparisons[1].max_abs_ev == 0.0
        @test vasp_compare_audit.comparisons[1].interpolation == "none"
        @test vasp_compare_audit.comparisons[1].energy_shift == "none"

        invalid_spin = JSON3.read(
            read(joinpath(FIXTURES, "vasp_native_single.json"), String),
            Dict{String, Any},
        )
        for field in ("eigenval", "kpoints", "poscar")
            invalid_spin["reference"][field] = joinpath(FIXTURES, invalid_spin["reference"][field])
        end
        invalid_spin["reference"]["spin_channel"] = 2
        invalid_spin_path = joinpath(directory, "invalid_spin.json")
        open(invalid_spin_path, "w") do stream
            JSON3.write(stream, invalid_spin)
        end
        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(invalid_spin_path) --validate-only`,
        ) != 0

        broken_kpoints = joinpath(directory, "KPOINTS_broken")
        write(
            broken_kpoints,
            replace(
                read(joinpath(FIXTURES, "KPOINTS"), String),
                "0.5 0.0 0.0 ! X\n0.5 0.5" => "0.4 0.0 0.0 ! X\n0.5 0.5",
            ),
        )
        invalid_k = deepcopy(invalid_spin)
        invalid_k["reference"]["spin_channel"] = 1
        invalid_k["reference"]["kpoints"] = broken_kpoints
        invalid_k_path = joinpath(directory, "invalid_k.json")
        open(invalid_k_path, "w") do stream
            JSON3.write(stream, invalid_k)
        end
        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(invalid_k_path) --validate-only`,
        ) != 0

        invalid_native_digest = deepcopy(invalid_k)
        invalid_native_digest["reference"]["kpoints"] = joinpath(FIXTURES, "KPOINTS")
        invalid_native_digest["reference"]["expected_sha256"] = Dict("eigenval" => repeat("0", 64))
        invalid_native_digest_path = joinpath(directory, "invalid_native_digest.json")
        open(invalid_native_digest_path, "w") do stream
            JSON3.write(stream, invalid_native_digest)
        end
        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(invalid_native_digest_path) --validate-only`,
        ) != 0

        truncated_eigenval = joinpath(directory, "EIGENVAL_truncated")
        eigenval_lines = readlines(joinpath(FIXTURES, "EIGENVAL"))
        write(truncated_eigenval, join(eigenval_lines[1:(end - 1)], '\n') * "\n")
        truncated_native = deepcopy(invalid_k)
        truncated_native["reference"]["kpoints"] = joinpath(FIXTURES, "KPOINTS")
        truncated_native["reference"]["eigenval"] = truncated_eigenval
        truncated_native_path = joinpath(directory, "truncated_native.json")
        open(truncated_native_path, "w") do stream
            JSON3.write(stream, truncated_native)
        end
        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(truncated_native_path) --validate-only`,
        ) != 0

        cartesian_kpoints = joinpath(directory, "KPOINTS_cartesian")
        write(
            cartesian_kpoints,
            replace(read(joinpath(FIXTURES, "KPOINTS"), String), "Reciprocal" => "Cartesian"),
        )
        cartesian_vasp = deepcopy(invalid_k)
        cartesian_vasp["reference"]["kpoints"] = cartesian_kpoints
        cartesian_vasp_path = joinpath(directory, "cartesian_vasp.json")
        open(cartesian_vasp_path, "w") do stream
            JSON3.write(stream, cartesian_vasp)
        end
        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(cartesian_vasp_path) --validate-only`,
        ) == 0

        ambiguous_poscar = joinpath(directory, "POSCAR_three_scale")
        write(
            ambiguous_poscar,
            replace(
                read(joinpath(FIXTURES, "POSCAR"), String),
                "2.0\n1.0 0.0" => "2.0 2.0 2.0\n1.0 0.0",
            ),
        )
        ambiguous_vasp = deepcopy(cartesian_vasp)
        ambiguous_vasp["reference"]["poscar"] = ambiguous_poscar
        ambiguous_vasp_path = joinpath(directory, "ambiguous_vasp.json")
        open(ambiguous_vasp_path, "w") do stream
            JSON3.write(stream, ambiguous_vasp)
        end
        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) band --entry-script $(joinpath(ROOT, "scripts", "plot_band_structure.jl")) --config $(ambiguous_vasp_path) --validate-only`,
        ) != 0

        response_stem = joinpath(directory, "response")
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) response --entry-script $(joinpath(ROOT, "scripts", "plot_response_integral.jl")) --mode compare --input $(joinpath(FIXTURES, "response_a.dat")) --compare $(joinpath(FIXTURES, "response_b.dat")) --components yyy --part real --output $(response_stem)`,
        )
        response_audit = JSON3.read(read(response_stem * ".plot.json", String))
        @test String(response_audit.qualification) == "PRESENTATION_ONLY"
        @test response_audit.datasets[1].components == ["xxx", "yyy"]
        @test response_audit.datasets[1].omega_minimum_ev == 0.0
        @test response_audit.datasets[1].omega_maximum_ev == 2.0
        @test response_audit.comparisons[1].max_abs ≈ 0.1
        @test response_audit.comparisons[1].interpolation == "none"
        response_axis = only(
            filter(
                item -> String(item.name) == "response_axis_contract",
                response_audit.transforms,
            ),
        )
        @test Float64.(response_axis.final_x_window_ev) == [0.0, 2.0]
        @test String(response_axis.x_window_source) == "data_bounds"
        @test String(response_axis.xlabel_source) == "automatic"
        @test occursin("hbar", String(response_axis.xlabel))
        @test occursin("yyy", String(response_axis.panel_labels[1].ylabel))
        default_xlabel = only(response_axis.xlabel_layout.placements)
        @test String(response_axis.xlabel_layout.font_size_source) == "style.axis_font_size"
        @test String(default_xlabel.placement_scope) == "axes_panel"
        @test String(default_xlabel.target_panel) == "yyy"
        @test String(default_xlabel.position_source) == "axes.set_xlabel"
        @test Float64(default_xlabel.requested_font_size_points) == 14.0
        @test Float64(default_xlabel.rendered_font_size_points) == 14.0
        @test Float64(default_xlabel.horizontal_center_difference_canvas_pixels) <= 0.5
        @test Float64(default_xlabel.vertical_gap_canvas_pixels) >= 0.0
        @test default_xlabel.inside_figure == true
        @test response_audit.resolved_config.style.minor_ticks == false
        @test Float64(response_audit.resolved_config.style.major_tick_length) == 3.5
        default_legend = only(
            filter(
                item -> String(item.name) == "response_legend_layout",
                response_audit.transforms,
            ),
        )
        @test String(default_legend.requested_location) == "best"
        @test String(default_legend.location) == "best"
        @test String(default_legend.location_source) == "style.legend"
        @test String(default_legend.bbox_source) == "none"
        @test String(default_legend.placement_scope) == "axes_internal"
        @test String(default_legend.target_panel) == "yyy"
        @test default_legend.inside_axes == true
        @test length(default_legend.placements) == 1
        @test Int(default_legend.placements[1].legend_artist_count) == 1
        @test Int(default_legend.placements[1].curve_vertex_count) == 6
        @test Int(default_legend.placements[1].curve_vertices_inside_legend) == 0
        @test Float64(default_legend.placements[1].curve_vertex_overlap_fraction) == 0.0
        legend_bbox = Float64.(default_legend.placements[1].legend_bbox_pixels)
        target_bbox = Float64.(default_legend.placements[1].target_axes_bbox_pixels)
        @test legend_bbox[1] >= target_bbox[1] - 0.5
        @test legend_bbox[2] >= target_bbox[2] - 0.5
        @test legend_bbox[3] <= target_bbox[3] + 0.5
        @test legend_bbox[4] <= target_bbox[4] + 0.5

        response_layout_stem = joinpath(directory, "response_layout")
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) response --entry-script $(joinpath(ROOT, "scripts", "plot_response_integral.jl")) --config $(joinpath(FIXTURES, "response_layout.json")) --output $(response_layout_stem)`,
        )
        response_layout = JSON3.read(read(response_layout_stem * ".plot.json", String))
        layout_axis = only(
            filter(
                item -> String(item.name) == "response_axis_contract",
                response_layout.transforms,
            ),
        )
        layout_legend = only(
            filter(
                item -> String(item.name) == "response_legend_layout",
                response_layout.transforms,
            ),
        )
        @test Float64.(layout_axis.final_x_window_ev) == [0.0, 4.0]
        @test String(layout_axis.x_window_source) == "explicit"
        @test String(layout_axis.axis_method) == "set_xlim"
        @test String(layout_axis.ylabel_source) == "automatic"
        @test occursin("yyy", String(layout_axis.panel_labels[1].ylabel))
        @test occursin("pm/V", String(layout_axis.panel_labels[1].ylabel))
        @test occursin("2", String(layout_axis.panel_labels[1].ylabel))
        @test String(layout_legend.requested_location) == "lower right"
        @test String(layout_legend.location) == "lower right"
        @test Float64.(layout_legend.bbox_to_anchor) == [0.985, 0.02]
        @test String(layout_legend.bbox_source) == "response_config"
        @test String(layout_legend.placement_scope) == "figure_anchored"
        @test Int(layout_legend.columns) == 2
        @test layout_legend.frame == false
        @test Int(layout_legend.placements[1].legend_artist_count) == 1
        @test Float64(layout_legend.applied_margins.bottom) >= 0.18

        response_explicit_inside_stem = joinpath(directory, "response_explicit_inside")
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) response --entry-script $(joinpath(ROOT, "scripts", "plot_response_integral.jl")) --mode compare --input $(joinpath(FIXTURES, "response_a.dat")) --compare $(joinpath(FIXTURES, "response_b.dat")) --components yyy --legend-location "upper right" --output $(response_explicit_inside_stem)`,
        )
        response_explicit_inside =
            JSON3.read(read(response_explicit_inside_stem * ".plot.json", String))
        explicit_inside_legend = only(
            filter(
                item -> String(item.name) == "response_legend_layout",
                response_explicit_inside.transforms,
            ),
        )
        @test String(explicit_inside_legend.location) == "upper right"
        @test String(explicit_inside_legend.location_source) == "response_config"
        @test String(explicit_inside_legend.placement_scope) == "axes_internal"
        @test explicit_inside_legend.inside_axes == true

        response_multi_stem = joinpath(directory, "response_multi")
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) response --entry-script $(joinpath(ROOT, "scripts", "plot_response_integral.jl")) --mode compare --input $(joinpath(FIXTURES, "response_a.dat")) --compare $(joinpath(FIXTURES, "response_b.dat")) --components all --panel-columns 2 --output $(response_multi_stem)`,
        )
        response_multi = JSON3.read(read(response_multi_stem * ".plot.json", String))
        multi_legend = only(
            filter(
                item -> String(item.name) == "response_legend_layout",
                response_multi.transforms,
            ),
        )
        @test length(multi_legend.placements) == 1
        @test String(multi_legend.target_panel) == "xxx"
        @test multi_legend.inside_axes == true
        @test Int(multi_legend.placements[1].legend_artist_count) == 1
        multi_axis = only(
            filter(
                item -> String(item.name) == "response_axis_contract",
                response_multi.transforms,
            ),
        )
        multi_xlabel = only(multi_axis.xlabel_layout.placements)
        @test String(multi_xlabel.placement_scope) == "figure_shared"
        @test String(multi_xlabel.position_source) == "figure.supxlabel_visible_axes_union"
        @test String.(multi_xlabel.target_panel) == ["xxx", "yyy"]
        @test Float64(multi_xlabel.rendered_font_size_points) == 14.0
        @test Float64(multi_xlabel.horizontal_center_difference_canvas_pixels) <= 0.5
        @test multi_xlabel.inside_figure == true

        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) response --entry-script $(joinpath(ROOT, "scripts", "plot_response_integral.jl")) --mode compare --input $(joinpath(FIXTURES, "response_a.dat")) --compare $(joinpath(FIXTURES, "response_b.dat")) --components yyy --x-window 0 4 --legend-location "lower right" --legend-bbox-to-anchor 0.985 0.02 --legend-columns 2 --no-legend-frame --style minor_ticks=false --validate-only`,
        ) == 0
        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) response --entry-script $(joinpath(ROOT, "scripts", "plot_response_integral.jl")) --mode compare --input $(joinpath(FIXTURES, "response_a.dat")) --compare $(joinpath(FIXTURES, "response_b.dat")) --components yyy --legend-bbox-to-anchor 0.5 --validate-only`,
        ) != 0

        manual_layout =
            JSON3.read(read(joinpath(FIXTURES, "response_layout.json"), String), Dict{String, Any})
        for field in ("input", "compare")
            manual_layout[field] = joinpath(FIXTURES, manual_layout[field])
        end
        manual_layout["xlabel"] = "Photon energy (eV)"
        manual_layout["ylabel"] = "Manual response label"
        manual_layout["style"]["axis_font_size"] = 9.5
        manual_layout["output"]["stem"] = joinpath(directory, "response_manual_labels")
        manual_layout_path = joinpath(directory, "response_manual_labels.json")
        open(manual_layout_path, "w") do stream
            JSON3.write(stream, manual_layout)
        end
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) response --entry-script $(joinpath(ROOT, "scripts", "plot_response_integral.jl")) --config $(manual_layout_path)`,
        )
        manual_audit =
            JSON3.read(read(joinpath(directory, "response_manual_labels.plot.json"), String))
        manual_axis = only(
            filter(item -> String(item.name) == "response_axis_contract", manual_audit.transforms),
        )
        @test String(manual_axis.xlabel_source) == "manual"
        @test String(manual_axis.ylabel_source) == "manual"
        @test String(manual_axis.xlabel) == "Photon energy (eV)"
        @test String(manual_axis.panel_labels[1].ylabel) == "Manual response label"
        manual_xlabel = only(manual_axis.xlabel_layout.placements)
        @test String(manual_axis.xlabel_layout.text_source) == "manual"
        @test Float64(manual_xlabel.requested_font_size_points) == 9.5
        @test Float64(manual_xlabel.rendered_font_size_points) == 9.5
        @test Float64(manual_xlabel.horizontal_center_difference_canvas_pixels) <= 0.5

        for invalid_window in ([0.0, 0.0], [2.0, 1.0])
            invalid_layout = deepcopy(manual_layout)
            invalid_layout["x_window"] = invalid_window
            invalid_path = joinpath(
                directory,
                "invalid_x_window_$(invalid_window[1])_$(invalid_window[2]).json",
            )
            open(invalid_path, "w") do stream
                JSON3.write(stream, invalid_layout)
            end
            @test process_exitcode(
                `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) response --entry-script $(joinpath(ROOT, "scripts", "plot_response_integral.jl")) --config $(invalid_path) --validate-only`,
            ) != 0
        end
        nonfinite_path = joinpath(directory, "invalid_x_window_nonfinite.json")
        nonfinite_payload = replace(
            read(manual_layout_path, String),
            r"\"x_window\":\[[^\]]+\]" => "\"x_window\":[0.0,1e999]",
        )
        @test occursin("\"x_window\":[0.0,1e999]", nonfinite_payload)
        write(nonfinite_path, nonfinite_payload)
        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) response --entry-script $(joinpath(ROOT, "scripts", "plot_response_integral.jl")) --config $(nonfinite_path) --validate-only`,
        ) != 0

        style_probe = joinpath(directory, "minor_tick_probe.py")
        write(
            style_probe,
            """
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(r\"$(ROOT)\") / \"scripts\"))
import matplotlib
matplotlib.use(\"Agg\")
import matplotlib.pyplot as plt
from matplotlib.ticker import NullLocator
from visualization.style import resolve_style, style_axes
fig, ax = plt.subplots()
default_style = resolve_style({\"latex\": False, \"font_family\": \"DejaVu Serif\"})
assert default_style[\"minor_ticks\"] is False
assert default_style[\"major_tick_length\"] == 3.5
style_axes(ax, default_style)
assert isinstance(ax.xaxis.get_minor_locator(), NullLocator)
assert isinstance(ax.yaxis.get_minor_locator(), NullLocator)
assert all(abs(tick.tick1line.get_markersize() - 3.5) < 1.0e-12 for tick in ax.xaxis.majorTicks)
assert all(abs(tick.tick1line.get_markersize() - 3.5) < 1.0e-12 for tick in ax.yaxis.majorTicks)
plt.close(fig)
fig, ax = plt.subplots()
override_style = resolve_style({
    \"latex\": False,
    \"font_family\": \"DejaVu Serif\",
    \"minor_ticks\": True,
    \"major_tick_length\": 7.25,
})
style_axes(ax, override_style)
assert not isinstance(ax.xaxis.get_minor_locator(), NullLocator)
assert not isinstance(ax.yaxis.get_minor_locator(), NullLocator)
assert all(abs(tick.tick1line.get_markersize() - 7.25) < 1.0e-12 for tick in ax.xaxis.majorTicks)
assert all(abs(tick.tick1line.get_markersize() - 7.25) < 1.0e-12 for tick in ax.yaxis.majorTicks)
plt.close(fig)
""",
        )
        @test process_exitcode(`$(PYTHON) $(style_probe)`) == 0

        kslice_stem = joinpath(directory, "kslice")
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) kslice --entry-script $(joinpath(ROOT, "scripts", "plot_kslice.jl")) --metadata $(joinpath(FIXTURES, "metadata.txt")) --data $(joinpath(FIXTURES, "kslice_real.dat")) --imag $(joinpath(FIXTURES, "kslice_imag.dat")) --part phase --coordinate centered --periodic-centered --output $(kslice_stem)`,
        )
        kslice_audit = JSON3.read(read(kslice_stem * ".plot.json", String))
        @test String(kslice_audit.qualification) == "PRESENTATION_ONLY"
        @test kslice_audit.transforms[1].operations == ["fftshift", "transpose"]
        @test kslice_audit.transforms[1].norm == "phase"
        @test kslice_audit.resolved_config.style.minor_ticks == false
        @test Float64(kslice_audit.resolved_config.style.major_tick_length) == 3.5
        @test Float64(kslice_audit.transforms[1].colorbar_layout.y0_difference_output_pixels) <= 1.0
        @test Float64(kslice_audit.transforms[1].colorbar_layout.y1_difference_output_pixels) <= 1.0

        cartesian_orthogonal_stem = joinpath(directory, "cartesian_orthogonal")
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) kslice --entry-script $(joinpath(ROOT, "scripts", "plot_kslice.jl")) --config $(joinpath(FIXTURES, "kslice_cart_orthogonal.json")) --output $(cartesian_orthogonal_stem)`,
        )
        cartesian_orthogonal = JSON3.read(read(cartesian_orthogonal_stem * ".plot.json", String))
        @test String(cartesian_orthogonal.transforms[1].coordinate) == "cartesian"
        @test String(cartesian_orthogonal.transforms[1].cartesian_projection.projection) == "kx-ky"
        @test occursin(
            "B=2pi*A^{-T}",
            String(cartesian_orthogonal.transforms[1].cartesian_projection.coordinate_contract),
        )
        @test Float64(
            cartesian_orthogonal.transforms[1].colorbar_layout.y0_difference_output_pixels,
        ) <= 1.0
        @test Float64(
            cartesian_orthogonal.transforms[1].colorbar_layout.y1_difference_output_pixels,
        ) <= 1.0

        cartesian_skew_stem = joinpath(directory, "cartesian_skew")
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) kslice --entry-script $(joinpath(ROOT, "scripts", "plot_kslice.jl")) --config $(joinpath(FIXTURES, "kslice_cart_skew.json")) --output $(cartesian_skew_stem)`,
        )
        cartesian_skew = JSON3.read(read(cartesian_skew_stem * ".plot.json", String))
        @test String(cartesian_skew.transforms[1].cartesian_projection.projection) ==
              "intrinsic-plane"
        @test cartesian_skew.transforms[1].cartesian_projection.lattice_rows_angstrom[2][1] == 0.7
        @test length(cartesian_skew.transforms[1].cartesian_projection.projection_rows_cartesian) ==
              2

        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) kslice --entry-script $(joinpath(ROOT, "scripts", "plot_kslice.jl")) --config $(joinpath(FIXTURES, "kslice_cart_orthogonal.json")) --model-file $(joinpath(FIXTURES, "skew_tb.dat")) --validate-only`,
        ) != 0

        packed_lattice = [2.0 0.0 0.0; 0.4 2.5 0.0; 0.0 0.2 3.0]
        packed_model = joinpath(directory, "packed_model.h5")
        HDF5.h5open(packed_model, "w") do handle
            root_attributes = HDF5.attributes(handle)
            root_attributes["schema"] = "wanniernlqg.real-space-operators"
            root_attributes["schema_version"] = "5.7"
            root_attributes["scientific_content_sha256"] = repeat("a", 64)
            model_group = HDF5.create_group(handle, "model")
            model_group["lattice"] = packed_lattice
        end
        packed_metadata = joinpath(directory, "packed_metadata.txt")
        packed_sha = bytes2hex(sha256(read(packed_model)))
        write(
            packed_metadata,
            """[Run]\ncalculation = kslice\nquantity = shift_vector\nmethod = conventional\n\n""" *
            """[Input]\ncase_root = $(directory)\nmodel_file = packed_model.h5\nmodel_sha256 = $(packed_sha)\nmodel_input_mode = packed_hdf5\n\n""" *
            """[Numerics]\nk_mesh = (2, 2)\nkslice_origin = (0.0,0.0,0.0)\nkslice_vector_1 = (1.0,0.0,0.0)\nkslice_vector_2 = (0.0,1.0,0.0)\n\n""" *
            """[Outputs]\noutputs.count = 1\noutput.1 = kslice_real.dat\n""",
        )
        packed_log = IOBuffer()
        packed_process = Base.run(
            pipeline(
                `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) kslice --entry-script $(joinpath(ROOT, "scripts", "plot_kslice.jl")) --metadata $(packed_metadata) --data $(joinpath(FIXTURES, "kslice_real.dat")) --coordinate cartesian --projection intrinsic-plane --validate-only`,
                stdout = packed_log,
                stderr = packed_log,
            );
            wait = false,
        )
        wait(packed_process)
        packed_process.exitcode == 0 ||
            @error "packed K-slice validation failed" log = String(take!(packed_log))
        @test packed_process.exitcode == 0

        mixed_stem = joinpath(directory, "kslice_mixed")
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) kslice --entry-script $(joinpath(ROOT, "scripts", "plot_kslice.jl")) --config $(joinpath(FIXTURES, "kslice_mixed_grid.json")) --output $(mixed_stem)`,
        )
        mixed_audit = JSON3.read(read(mixed_stem * ".plot.json", String))
        @test String.(getproperty.(mixed_audit.transforms, :panel_id)) ==
              ["signed", "magnitude", "signed_log", "phase"]
        @test String.(getproperty.(mixed_audit.transforms, :norm)) ==
              ["diverging", "positive-log", "signed-log", "phase"]
        @test String.(getproperty.(mixed_audit.transforms, :complex_part)) ==
              ["real", "abs", "real", "phase"]
        for panel in mixed_audit.transforms
            @test String(panel.colorbar_layout.placement) == "axes_grid1_explicit_cax"
            @test Float64(panel.colorbar_layout.y0_difference_output_pixels) <= 1.0
            @test Float64(panel.colorbar_layout.y1_difference_output_pixels) <= 1.0
        end

        @test process_exitcode(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) kslice --entry-script $(joinpath(ROOT, "scripts", "plot_kslice.jl")) --mode grid --metadata $(joinpath(FIXTURES, "metadata.txt")) --validate-only`,
        ) != 0

        response_27_stem = joinpath(directory, "response_27")
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) response --entry-script $(joinpath(ROOT, "scripts", "plot_response_integral.jl")) --config $(joinpath(FIXTURES, "response_27.json")) --output $(response_27_stem)`,
        )
        response_27_audit = JSON3.read(read(response_27_stem * ".plot.json", String))
        @test Int(response_27_audit.datasets[1].component_count) == 27
        @test Int(response_27_audit.transforms[3].panels_per_page) == 18
        response_27_axis = only(
            filter(
                item -> String(item.name) == "response_axis_contract",
                response_27_audit.transforms,
            ),
        )
        @test length(response_27_axis.panel_labels) == 27
        @test occursin("c01", String(response_27_axis.panel_labels[1].title))
        @test occursin("c27", String(response_27_axis.panel_labels[27].ylabel))
        @test String(response_27_axis.ylabel_source) == "automatic"
        @test String(response_27_axis.ylabel_layout) == "page_shared"
        @test occursin("output", String(response_27_axis.shared_ylabel))
        @test length(response_27_axis.xlabel_layout.placements) == 2
        for placement in response_27_axis.xlabel_layout.placements
            @test String(placement.placement_scope) == "figure_shared"
            @test Float64(placement.rendered_font_size_points) == 14.0
            @test Float64(placement.horizontal_center_difference_canvas_pixels) <= 0.5
            @test placement.inside_figure == true
        end
        @test length(response_27_audit.outputs) == 4
        for page in 1:2
            png = response_27_stem * "_page" * lpad(string(page), 2, '0') * ".png"
            width, height = png_dimensions(png)
            @test width * height <= 32_000_000
        end

        paged_compare =
            JSON3.read(read(joinpath(FIXTURES, "response_27.json"), String), Dict{String, Any})
        paged_compare["mode"] = "compare"
        paged_compare["input"] = joinpath(FIXTURES, "response_27.dat")
        paged_compare["compare"] = joinpath(FIXTURES, "response_27.dat")
        paged_compare["label"] = "Reference"
        paged_compare["compare_label"] = "Comparison"
        paged_compare["output"]["stem"] = joinpath(directory, "response_27_compare")
        paged_compare["output"]["formats"] = ["png"]
        paged_compare_path = joinpath(directory, "response_27_compare.json")
        open(paged_compare_path, "w") do stream
            JSON3.write(stream, paged_compare)
        end
        Base.run(
            `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) response --entry-script $(joinpath(ROOT, "scripts", "plot_response_integral.jl")) --config $(paged_compare_path)`,
        )
        paged_compare_audit =
            JSON3.read(read(joinpath(directory, "response_27_compare.plot.json"), String))
        paged_legend = only(
            filter(
                item -> String(item.name) == "response_legend_layout",
                paged_compare_audit.transforms,
            ),
        )
        @test length(paged_legend.placements) == 2
        @test length(paged_legend.target_panel) == 2
        @test paged_legend.inside_axes == true
        @test all(Int(placement.legend_artist_count) == 1 for placement in paged_legend.placements)

        mismatch = joinpath(directory, "response_mismatch.dat")
        write(
            mismatch,
            replace(
                read(joinpath(FIXTURES, "response_b.dat"), String),
                "2.0000000e+00    3.1000000e+00" => "2.5000000e+00    3.1000000e+00",
            ),
        )
        process = Base.run(
            pipeline(
                `$(PYTHON) $(joinpath(ROOT, "scripts", "visualization", "cli.py")) response --entry-script $(joinpath(ROOT, "scripts", "plot_response_integral.jl")) --mode compare --input $(joinpath(FIXTURES, "response_a.dat")) --compare $(mismatch) --components yyy --validate-only`,
                stdout = devnull,
                stderr = devnull,
            );
            wait = false,
        )
        wait(process)
        @test process.exitcode != 0
    end
end
