using WannierNLQG, Serialization, SHA, JSON3, Test
const W=WannierNLQG.Wannierization
root=joinpath(dirname(Main.RECEIPT), "fixture_output")
@test !ispath(root)
mkpath(root)
input_file=Main.FirstUsePortableSupport.input("arguments/fixture_3.jls")
@test bytes2hex(
    sha256(read(input_file)),
)=="67c93d069cb18f666bfe703b3231948ca36324f16b36ab0e1e7b9762c812ef8a"
actual = Main.FirstUsePortableSupport.deserialize_input(input_file)
@test Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)===nothing
config=only(actual.positional)
fields=fieldnames(typeof(config))
values=NamedTuple{fields}(
    Tuple(
        name===:output_json ? joinpath(root, "actual.gauge-chain.json") :
        name===:output_hdf5 ? joinpath(root, "actual.gauge-chain.h5") : getfield(config, name) for
        name in fields
    ),
)
cold_config=W.WannierGaugeChainDiagnosticConfig(; values...)
inputs=[
    cold_config.wannierization_checkpoint_hdf5,
    cold_config.eig_file,
    cold_config.mmn_file,
    cold_config.band_representation_hdf5,
]
input_hashes=Dict(p=>bytes2hex(sha256(read(p))) for p in inputs)
@test Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)===nothing
result=W.diagnose_wannier_gauge_chain(cold_config)
@test isfile(result.output_json) && isfile(result.output_hdf5)
native=Main.FirstUseExpertProbe.native_writer_readback(
    :write_band_representation_hdf5,
    result.output_hdf5,
)
write(joinpath(dirname(Main.RECEIPT), "native_gauge_chain_hdf5.json"), JSON3.write(native))
payload=JSON3.read(read(result.output_json, String), Dict{String, Any})
@test Set(
    keys(payload),
)==Set([
    "summary",
    "hdf5_sha256",
    "qualification",
    "status",
    "input_sha256",
    "schema_version",
    "schema",
])
@test payload["hdf5_sha256"]==bytes2hex(sha256(read(result.output_hdf5)))
@test payload["status"]=="PASS_DIAGNOSTIC"
@test !isempty(payload["summary"])
@test payload["summary"]["input_identity"]=="PASS"
@test !isempty(native.numeric_leaves)
@test all(leaf.finite for leaf in native.numeric_leaves)
@test any(leaf -> hasproperty(leaf, :max_abs) && leaf.max_abs>0, native.numeric_leaves)
# JSON scientific diagnostics intentionally are strings. Preserve their exact
# text, including NaN in inactive metrics. Only the raw HDF artifact checksum
# is metadata, checked above and retained in the original JSON file.
science_json=Dict(k=>v for (k, v) in payload if k!="hdf5_sha256")
write(
    joinpath(dirname(Main.RECEIPT), "native_gauge_chain_json_bits.json"),
    JSON3.write((science_semantics = science_json, excluded_artifact_metadata = ["hdf5_sha256"])),
)
for (path, digest) in input_hashes
    @test bytes2hex(sha256(read(path)))==digest
end
