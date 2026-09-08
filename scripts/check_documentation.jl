using Test

const ROOT = normpath(joinpath(@__DIR__, ".."))
const PUBLIC_TEXT_EXTENSIONS =
    Set([".cff", ".jl", ".json", ".md", ".py", ".toml", ".txt", ".yml", ".yaml"])
const REMOVED_PUBLIC_DOCUMENTS = (
    "USER_GUIDE_CN.md",
    "docs/USER_GUIDE.md",
    "docs/SYMMETRIZATION_CN.md",
    "docs/WANNIERIZATION_CN.md",
    "docs/MAGNETIC_SAWF_DATA.md",
    "docs/ROLLBACK.md",
    "docs/MIGRATION_MAP.md",
    "docs/SYMMETRY_FOUNDATION_WANNIER_PROJECTION_MIGRATION.md",
    "docs/PUBLIC_RELEASE_CHECKLIST.md",
)
const FORBIDDEN_PUBLIC_MARKERS = (
    r"/Users/",
    r"Code/wannierNLQG-data",
    r"WANNIERNLQG_DATA_ROOT",
    r"WANNIERNLQG_TEST_LEVEL\s*=\s*public",
    r"TEST_LEVEL\s*[:=]\s*public"i,
    r"check_public_mpi_smoke\.jl",
    r"public_release_unit\.jl",
)

function public_text_files()
    files = String[]
    for (directory, subdirectories, names) in walkdir(ROOT)
        filter!(name -> name != ".git", subdirectories)
        for name in names
            path = joinpath(directory, name)
            lowercase(splitext(name)[2]) in PUBLIC_TEXT_EXTENSIONS || continue
            push!(files, path)
        end
    end
    return sort!(files)
end

function prose_without_fences(text::AbstractString)
    lines = split(replace(text, "\r\n" => "\n"), '\n'; keepempty = true)
    output = String[]
    in_fence = false
    fence_marker = ""
    for line in lines
        stripped = lstrip(line)
        if startswith(stripped, "```") || startswith(stripped, "~~~")
            marker = first(stripped, 3)
            if !in_fence
                in_fence = true
                fence_marker = marker
            elseif startswith(stripped, fence_marker)
                in_fence = false
                fence_marker = ""
            end
            push!(output, "")
        elseif in_fence
            push!(output, "")
        else
            push!(output, line)
        end
    end
    in_fence && error("unclosed Markdown code fence")
    return join(output, "\n")
end

function github_anchor_inventory(text::AbstractString)
    anchors = Set{String}()
    counts = Dict{String, Int}()
    for line in split(prose_without_fences(text), '\n')
        match_result = match(r"^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$", line)
        isnothing(match_result) && continue
        heading = lowercase(match_result.captures[1])
        heading = replace(heading, r"<[^>]+>" => "")
        heading = replace(heading, r"[`*_~]" => "")
        heading = replace(heading, r"[^\p{L}\p{N}\s-]" => "")
        heading = replace(strip(heading), r"\s+" => "-")
        heading = replace(heading, r"-+" => "-")
        count = get(counts, heading, 0)
        counts[heading] = count + 1
        push!(anchors, count == 0 ? heading : "$(heading)-$(count)")
    end
    return anchors
end

function percent_decode(value::AbstractString)
    bytes = UInt8[]
    index = firstindex(value)
    while index <= lastindex(value)
        if value[index] == '%' && index + 2 <= lastindex(value)
            encoded = value[(index + 1):(index + 2)]
            if occursin(r"^[0-9A-Fa-f]{2}$", encoded)
                push!(bytes, parse(UInt8, encoded; base = 16))
                index += 3
                continue
            end
        end
        append!(bytes, codeunits(string(value[index])))
        index = nextind(value, index)
    end
    return String(bytes)
end

function exact_case_path_exists(path::AbstractString; root::AbstractString = ROOT)
    absolute = isabspath(path) ? normpath(path) : normpath(joinpath(root, path))
    ispath(absolute) || return false
    relative = relpath(absolute, root)
    startswith(relative, "..") && return false
    current = root
    for part in splitpath(relative)
        part == "." && continue
        part in readdir(current) || return false
        current = joinpath(current, part)
    end
    return true
end

function validate_markdown_link(
    source::AbstractString,
    raw_target::AbstractString;
    root::AbstractString = ROOT,
)
    target = strip(raw_target)
    startswith(target, "<") && endswith(target, ">") && (target = target[2:(end - 1)])
    isempty(target) && return
    startswith(target, "?") && return
    occursin(r"^[A-Za-z][A-Za-z0-9+.-]*:", target) && return
    target = first(split(target, '?'; limit = 2))
    pieces = split(target, '#'; limit = 2)
    decoded_path = percent_decode(pieces[1])
    resolved = isempty(decoded_path) ? source : normpath(joinpath(dirname(source), decoded_path))
    exact_case_path_exists(resolved; root = root) ||
        error("broken or case-mismatched local link in $(relpath(source, root)): $(raw_target)")
    if length(pieces) == 2 &&
       !isempty(pieces[2]) &&
       isfile(resolved) &&
       lowercase(splitext(resolved)[2]) == ".md"
        anchor = percent_decode(pieces[2])
        anchor in github_anchor_inventory(read(resolved, String)) ||
            error("missing Markdown anchor in $(relpath(source, root)): $(raw_target)")
    end
end

function validate_markdown(path::AbstractString; root::AbstractString = ROOT)
    text = read(path, String)
    prose = prose_without_fences(text)
    occursin(r"\\[()]|\\[\[\]]", prose) &&
        error("use dollar-delimited Markdown mathematics in $(relpath(path, root))")
    display_open = false
    inline_open = false
    for line in split(prose, '\n'; keepempty = true)
        stripped = strip(line)
        count_display = length(collect(eachmatch(r"(?<!\\)\$\$", line)))
        if count_display > 0
            stripped == "\$\$" ||
                error("display-math delimiter must be on its own line in $(relpath(path, root))")
            count_display == 1 || error("multiple display delimiters on one line")
            display_open = !display_open
            continue
        end
        display_open && continue
        count_inline = length(collect(eachmatch(r"(?<!\\)(?<!\$)\$(?!\$)", line)))
        iseven(count_inline) ||
            error("unbalanced inline mathematics in $(relpath(path, root)): $(line)")
        inline_open = xor(inline_open, isodd(count_inline))
    end
    display_open && error("unclosed display mathematics in $(relpath(path, root))")
    inline_open && error("unclosed inline mathematics in $(relpath(path, root))")
    occursin(r"\\begin\{aligned\}", prose) &&
        !occursin(r"(?s)\$\$.*?\\begin\{aligned\}.*?\\end\{aligned\}.*?\$\$", prose) &&
        error("aligned environment must be enclosed by display mathematics")
    for match_result in eachmatch(r"!?\[[^\]]*\]\(([^)]+)\)", prose)
        validate_markdown_link(path, match_result.captures[1]; root = root)
    end
end

function validate_public_text(path::AbstractString; check_markers::Bool = true)
    text = read(path, String)
    occursin(r"[\p{Han}]", text) && error("Han text is not allowed in public source files")
    if check_markers
        for marker in FORBIDDEN_PUBLIC_MARKERS
            occursin(marker, text) &&
                error("internal-only marker is not allowed in public source files")
        end
    end
    return nothing
end

@testset "documentation validator negative fixtures" begin
    mktempdir() do fixture_root
        good = joinpath(fixture_root, "Guide.md")
        write(good, "# Local heading\n\nSee [self](#local-heading).\n")
        @test isnothing(validate_markdown(good; root = fixture_root))

        bad_link = joinpath(fixture_root, "bad-link.md")
        write(bad_link, "[missing](absent.md)\n")
        @test_throws ErrorException validate_markdown(bad_link; root = fixture_root)

        wrong_case = joinpath(fixture_root, "wrong-case.md")
        write(wrong_case, "[case](guide.md)\n")
        @test_throws ErrorException validate_markdown(wrong_case; root = fixture_root)

        missing_anchor = joinpath(fixture_root, "missing-anchor.md")
        write(missing_anchor, "[anchor](Guide.md#absent)\n")
        @test_throws ErrorException validate_markdown(missing_anchor; root = fixture_root)

        for (name, contents) in (
            ("paren-math.md", raw"\(x\)"),
            ("bracket-math.md", raw"\[x\]"),
            ("inline-display.md", "text \$\$x\$\$\n"),
            ("unclosed-fence.md", "```julia\nx = 1\n"),
        )
            path = joinpath(fixture_root, name)
            write(path, contents)
            @test_throws ErrorException validate_markdown(path; root = fixture_root)
        end

        han = joinpath(fixture_root, "han.md")
        write(han, "Chinese text: " * String(Char.([0x6587, 0x6863])) * "\n")
        @test_throws ErrorException validate_public_text(han)

        internal = joinpath(fixture_root, "internal.md")
        write(internal, "Set WANNIERNLQG_DATA_ROOT before running.\n")
        @test_throws ErrorException validate_public_text(internal)
    end
end

@testset "public documentation closure" begin
    files = public_text_files()
    @test !isempty(files)
    for relative in REMOVED_PUBLIC_DOCUMENTS
        @test !ispath(joinpath(ROOT, relative))
    end
    for path in files
        @test isnothing(validate_public_text(path; check_markers = path != @__FILE__))
        lowercase(splitext(path)[2]) == ".md" && validate_markdown(path)
    end
end

println(
    "Documentation validation PASS: English public text, local-link closure, and Markdown math contracts are valid.",
)
