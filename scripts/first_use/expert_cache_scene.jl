# Actual cache-hit supplement. The collector copies same-source native cache
# bytes before this new process starts; this is source attribution, not speed.
using Serialization, SHA, Test
const CACHE_SCENE = ENV["FIRSTUSE_CACHE_SCENE"]
@test !any(
    Base.get_extension(WannierNLQG, n)!==nothing for n in (
        :WannierNLQGWannierizationExt,
        :WannierNLQGSymmetrizationExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGOperatorBundleExt,
    )
)
const FROZEN_INPUT = if CACHE_SCENE == "spn_data_only"
    (
        positional = (
            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
                Main.FirstUsePortableSupport.input("assets/group_23/fixture.save");
                band_range = nothing,
                spin_channel = :none,
                representation_cutoff_ev = nothing,
                include_time_reversal = false,
                magnetic_moments_cartesian = nothing,
            ),
            Main.FirstUsePortableSupport.input("assets/group_23/fixture.nnkp"),
        ),
        keyword = (
            output_spn_file = "unused",
            provenance_json = "unused",
            max_cached_wavefunction_kpoints = 2,
        ),
    )
else
    Main.FirstUsePortableSupport.deserialize_input(
        Main.FirstUsePortableSupport.input(
            CACHE_SCENE == "uiu" ? "arguments/fixture_11.jls" : "arguments/fixture_8.jls",
        ),
    )
end
const NEW_OUTPUT = joinpath(dirname(Main.RECEIPT), "native_outputs")
@test isdir(NEW_OUTPUT)
if CACHE_SCENE == "uiu"
    cfg=FROZEN_INPUT.positional[1]
    fields=NamedTuple{fieldnames(typeof(cfg))}(
        Tuple(getfield(cfg, k) for k in fieldnames(typeof(cfg))),
    )
    new_cfg=typeof(cfg)(;
        merge(
            fields,
            (
                output_file = joinpath(NEW_OUTPUT, "fixture.uIu"),
                provenance_json = joinpath(NEW_OUTPUT, "uiu.json"),
            ),
        )...,
    )
    value=WannierNLQG.Wannierization.generate_wannier_uiu(new_cfg; FROZEN_INPUT.keyword...)
    @test value.passed && value.resumed_from_kpoint==0
    blocks=Matrix{ComplexF64}[]
    WannierNLQG.IO.foreach_wannier_uiu_block(new_cfg.output_file) do block, args...
        push!(blocks, copy(block))
    end
    @test !isempty(blocks) &&
          all(b->all(isfinite, b), blocks) &&
          maximum(maximum(abs, b) for b in blocks)>0
    native=Main.FirstUseExpertProbe.numeric_summary(blocks)
else
    keywords=merge(
        (; FROZEN_INPUT.keyword...),
        (
            output_spn_file = joinpath(NEW_OUTPUT, "qe.spn"),
            provenance_json = joinpath(NEW_OUTPUT, "qe_spn.json"),
        ),
    )
    value=WannierNLQG.Wannierization.generate_qe_paw_spn(FROZEN_INPUT.positional...; keywords...)
    @test value.passed
    native=Main.FirstUseExpertProbe.numeric_summary(
        WannierNLQG.IO.read_wannier_spn(keywords.output_spn_file),
    )
    @test native.all_finite && any(x->haskey(x, :max_abs) && x.max_abs>0, native.leaves)
end
write(joinpath(dirname(Main.RECEIPT), "native_science.json"), JSON3.write(native))
progress=joinpath(NEW_OUTPUT, ".wannier_preparation", "qe", "preparation_progress.jsonl")
@test isfile(progress)
events=[JSON3.read(line) for line in readlines(progress)]
@test any(e->e.event=="CACHE_HIT", events)
write(joinpath(dirname(Main.RECEIPT), "actual_cache_hit_events.json"), JSON3.write(events))
