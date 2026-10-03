# Post-measurement official coupled digest validation and exact field readback.
using WannierNLQG, Spglib, HDF5, EzXML, JSON3, SHA, Test
plan, output = ARGS
backend = first(WannierNLQG.Wannierization._load_wannierization_extension!())
paw = getproperty(backend, :PAWMatrixElements)
rows = Any[]
for item in JSON3.read(read(plan, String))
    file = String(item.file)
    digest = bytes2hex(open(sha256, file))
    @test digest == String(item.sha256)
    if item.kind == "vasp_spn"
        value = Base.invokelatest(
            getproperty(backend, :read_vasp_paw_spn_provenance),
            file;
            verify_spn = false,
        )
        @test value.num_bands > 0
    elseif item.kind == "star_gauge"
        value = Base.invokelatest(
            getproperty(paw, :_read_star_covariant_paw_gauge_hdf5),
            file;
            require_pass = false,
        )
        @test value !== nothing
    else
        error("Unknown native integrity kind")
    end
    fields = Any[]
    h5open(file, "r") do handle
        for field in item.digest_fields
            field_path = String(field.hdf5_field)
            object_path, attribute = split(field_path, "@"; limit = 2)
            object_path = rstrip(object_path, '/')
            object = isempty(object_path) ? handle : handle[object_path]
            text = String(read(HDF5.attributes(object)[attribute]))
            @test length(text) == 64 && all(isxdigit, text)
            push!(fields, (field = field.report_field, value = text))
            object === handle || close(object)
        end
    end
    @test bytes2hex(open(sha256, file)) == digest
    push!(
        rows,
        (
            kind = item.kind,
            side = item.side,
            artifact_sha256 = digest,
            official_digest_and_readback = true,
            verified_digest_fields = fields,
        ),
    )
end
write(
    output,
    JSON3.write((rows = rows, checks = length(rows), timing_sample = false, final_pass = false)),
)
println("NATIVE_COUPLED_DIGEST_AND_FIELD_READBACK_PASS")
