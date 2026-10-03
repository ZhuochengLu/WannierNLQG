# Read-only source/method/layout descriptors; not a speed or physics sample.
using WannierNLQG, JSON3, SHA
length(ARGS)==1||error("output required")
ispath(ARGS[1])&&error("output exists")
root=pkgdir(WannierNLQG);
module_owner=WannierNLQG.Runtime
hashbytes(data)=bytes2hex(sha256(data))
normalize_generated_names(s)=replace(s, r"#[0-9]+#(?=[A-Za-z_])"=>"#G#")
runtime_stream=IOBuffer()
for path in sort!(
    filter(
        p->endswith(p, ".jl"),
        [
            joinpath(dir, name) for (dir, _, files) in walkdir(joinpath(root, "src", "Runtime")) for
            name in files
        ],
    ),
)
    write(runtime_stream, relpath(path, root), UInt8(0), read(path))
end
runtime_source_sha256=hashbytes(take!(runtime_stream))
julia_source_root=normpath(joinpath(Sys.BINDIR, "..", "share", "julia"))
rows=Any[]
for name in sort!(names(module_owner; all = true); by = string)
    occursin("#", string(name))||continue
    isdefined(module_owner, name)||continue
    value=getfield(module_owner, name)
    value isa Type||continue
    body=Base.unwrap_unionall(value)
    body isa DataType||continue
    body<:Function||continue
    parentmodule(body)===module_owner||continue
    mt=body.name.mt;
    mt===nothing&&continue
    methods_data=Any[]
    for method in Base.MethodList(mt)
        method.module===module_owner||continue
        file=String(method.file)
        absolute=isabspath(file) ? file : normpath(joinpath(root, file))
        if !isfile(absolute)
            located=Base.find_source_file(file)
            located===nothing || (absolute=located)
        end
        isfile(absolute)||continue
        relative=relpath(absolute, root)
        if startswith(relative, "..")
            startswith(relpath(absolute, julia_source_root), "..")&&continue
            relative="JULIA_SOURCE/"*relpath(absolute, julia_source_root)
        end
        code=try
            sprint(show, Base.uncompressed_ast(method))
        catch
            ;
            "UNAVAILABLE"
        end
        push!(
            methods_data,
            (
                source_file = relative,
                source_file_sha256 = hashbytes(read(absolute)),
                source_line = Int(method.line),
                argument_count = Int(method.nargs),
                varargs = method.isva,
                normalized_ir_sha256 = code=="UNAVAILABLE" ? nothing :
                                       hashbytes(
                    codeunits(normalize_generated_names(replace(code, root => "PACKAGE_ROOT"))),
                ),
            ),
        )
    end
    isempty(methods_data)&&continue
    fields=normalize_generated_names.(string.(fieldnames(body)))
    field_types=normalize_generated_names.(string.(fieldtypes(body)))
    key=(
        runtime_source_sha256 = runtime_source_sha256,
        methods = methods_data,
        fields = fields,
        field_types = field_types,
    )
    push!(
        rows,
        (
            binding = string(name),
            wrapper_type = string(value),
            stable_method_layout_key = hashbytes(codeunits(JSON3.write(key))),
            proof = key,
        ),
    )
end
write(
    ARGS[1],
    JSON3.write((
        source = root,
        julia = string(VERSION),
        module_owner = string(module_owner),
        rows = rows,
        scope = "descriptor only: migration also requires a real new-source trace and unique match; no signature deleted or changed",
    )),
)
println("generated Runtime binding descriptors: ", length(rows))
