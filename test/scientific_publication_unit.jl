module ScientificPublicationUnit
using Test, WannierNLQG
const DataIO = WannierNLQG.IO
const FORMAT = "scientific-publication-fixture"
const FORMAT_VERSION = "2"

publish(path, identity; keywords...) = DataIO.write_scientific_file_publication(
    path;
    artifact_schema = FORMAT,
    artifact_version = FORMAT_VERSION,
    publication_identity = identity,
    keywords...,
)

function decoded(
    path;
    artifact_schema = FORMAT,
    artifact_version = FORMAT_VERSION,
    receipt_path = nothing,
)
    return DataIO.with_scientific_file_publication(
        path;
        artifact_schema,
        artifact_version,
        receipt_path,
    ) do filename, identity
        lines = readlines(filename)
        first(lines) == identity || throw(ArgumentError("fixture publication declaration mismatch"))
        lines[2]
    end
end

@testset "Atomic scientific publication binds one local payload and receipt lifetime" begin
    mktempdir() do directory
        path = joinpath(directory, "payload.dat")
        write(path, "publication-A\n1 2 3\n")
        @test_throws ArgumentError decoded(path)
        receipt = publish(path, "publication-A")
        @test receipt == path * ".commit.toml"
        result = decoded(path)
        @test result.value == "1 2 3"
        @test result.publication_identity == "publication-A"
        @test result.state == DataIO.scientific_file_state(path)
        @test result.receipt_state == DataIO.scientific_file_state(receipt)
        link = joinpath(directory, "linked.dat")
        symlink(path, link)
        @test decoded(link).value == result.value

        copied = joinpath(directory, "copied.dat")
        cp(path, copied)
        cp(receipt, copied * ".commit.toml")
        @test_throws ArgumentError decoded(copied)
        publish(copied, "publication-A")
        @test decoded(copied).value == "1 2 3"
        same_name = joinpath(directory, "copied-directory", basename(path))
        mkpath(dirname(same_name))
        cp(path, same_name)
        cp(receipt, same_name * ".commit.toml")
        @test_throws ArgumentError decoded(same_name)
        publish(same_name, "publication-A")
        @test decoded(same_name).value == "1 2 3"
        record = DataIO.read_task_input_file(receipt).document
        @test Set(keys(record["file_lifetime"])) ==
              Set(("schema", "bytes", "mtime_ieee", "ctime_ieee"))
        @test !haskey(record["file_lifetime"], "device") &&
              !haskey(record["file_lifetime"], "inode")

        private = joinpath(directory, "node-private", "publication.toml")
        publish(copied, "publication-A"; receipt_path = private)
        @test decoded(copied; receipt_path = private).value == "1 2 3"
        @test_throws ArgumentError publish(path, "publication-A"; receipt_path = path)
        alias = joinpath(directory, "receipt-alias.toml")
        symlink(path, alias)
        @test_throws ArgumentError publish(path, "publication-A"; receipt_path = alias)
        @test read(path, String) == "publication-A\n1 2 3\n"
        before = read(receipt)
        @test_throws ArgumentError publish(path, "")
        @test_throws ArgumentError publish(path, repeat("x", 1025))
        @test read(receipt) == before
        @test_throws ArgumentError decoded(path; artifact_version = "old")

        # The callback remains responsible for its own actual format declaration.
        publish(path, "different-publication")
        @test_throws ArgumentError decoded(path)
        publish(path, "publication-A")
        @test_throws ArgumentError DataIO.with_scientific_file_publication(
            path;
            artifact_schema = FORMAT,
            artifact_version = FORMAT_VERSION,
        ) do filename, identity
            original = read(filename, String)
            replacement = joinpath(directory, "replacement.dat")
            write(replacement, "publication-C\n9 9 9\n")
            mv(replacement, filename; force = true)
            original
        end
        @test_throws ArgumentError decoded(path)
        publish(path, "publication-C")
        @test decoded(path).value == "9 9 9"
        @test decoded(path).publication_identity == "publication-C"

        @test_throws ArgumentError DataIO.with_scientific_file_publication(
            path;
            artifact_schema = FORMAT,
            artifact_version = FORMAT_VERSION,
        ) do filename, identity
            document = DataIO.read_task_input_file(receipt).document
            DataIO.write_task_input_file(receipt, document)
            read(filename, String)
        end
        @test decoded(path).value == "9 9 9"

        # All malformed receipts fail before entering the scientific decoder.
        valid = DataIO.read_task_input_file(receipt).document
        for mutation in (
            d -> (d["schema"] = "wanniernlqg.scientific-file-publication/0"),
            d -> (d["schema"] = "wanniernlqg.scientific-file-publication/1"),
            d -> (d["file_lifetime"]["inode"] = "foreign-node-identifier"),
            d -> (d["waiver"] = true),
            d -> (d["artifact_file"] = "../payload.dat"),
            d -> (d["artifact_schema"] = "other"),
            d -> (d["artifact_version"] = "old"),
            d -> (d["file_lifetime"]["bytes"] = true),
            d -> (d["publication_identity"] = false),
        )
            invalid = deepcopy(valid)
            mutation(invalid)
            DataIO.write_task_input_file(receipt, invalid)
            entered = Ref(false)
            @test_throws ArgumentError DataIO.with_scientific_file_publication(
                path;
                artifact_schema = FORMAT,
                artifact_version = FORMAT_VERSION,
            ) do filename, identity
                entered[] = true
            end
            @test !entered[]
        end
        DataIO.write_task_input_file(receipt, valid)
        @test decoded(path).value == "9 9 9"
        absent = joinpath(directory, "absent.dat")
        @test_throws ArgumentError publish(absent, "publication-A")
        @test_throws ArgumentError decoded(absent)
        @test !isfile(absent * ".commit.toml")

        # Publication must bind the same file that the complete decoder checked.
        guarded = joinpath(directory, "validated-source.dat")
        write(guarded, "publication-D\n1 2 3\n")
        validated = DataIO.with_scientific_source(guarded) do filename
            @test readlines(filename) == ["publication-D", "1 2 3"]
        end
        publish(guarded, "publication-D"; expected_state = validated.state)
        @test decoded(guarded).value == "1 2 3"
        accepted_receipt = read(guarded * ".commit.toml")
        open(guarded, "a") do stream
            write(stream, "changed after validation\n")
        end
        @test_throws ArgumentError publish(
            guarded,
            "publication-D";
            expected_state = validated.state,
        )
        @test read(guarded * ".commit.toml") == accepted_receipt
        @test_throws ArgumentError decoded(guarded)
        private_guard = joinpath(directory, "uncommitted-private.toml")
        @test_throws ArgumentError publish(
            guarded,
            "publication-D";
            expected_state = validated.state,
            receipt_path = private_guard,
        )
        @test !isfile(private_guard)
    end
end
end
