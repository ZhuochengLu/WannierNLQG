using Test
using WannierNLQG

const OPERATOR_IO = WannierNLQG.IO

function operator_protocol_block(ik::Int, second::Int, third::Int, num_bands::Int)
    block = Matrix{ComplexF64}(undef, num_bands, num_bands)
    for row in 1:num_bands, column in 1:num_bands
        value = 1000ik + 100second + 10third + 2row + column
        block[row, column] = ComplexF64(value, row - 2column)
    end
    return block
end

function collect_operator_blocks(foreach_block, filename; formatted::Bool)
    order = NTuple{3, Int}[]
    blocks = Matrix{ComplexF64}[]
    header = foreach_block(filename; formatted) do block, first, second, third, _
        push!(order, (first, second, third))
        push!(blocks, block)
    end
    return header, order, blocks
end

function big_endian_bytes(values::Vector{Int32})
    output = UInt8[]
    for value in values
        append!(output, reinterpret(UInt8, [bswap(reinterpret(UInt32, value))]))
    end
    return output
end

function big_endian_bytes(values::Vector{ComplexF64})
    output = UInt8[]
    for value in values, part in (real(value), imag(value))
        word = reinterpret(UInt64, part)
        append!(output, reinterpret(UInt8, [bswap(word)]))
    end
    return output
end

function write_big_endian_record(io, payload::Vector{UInt8})
    marker = reinterpret(UInt8, [bswap(UInt32(length(payload)))])
    write(io, marker)
    write(io, payload)
    write(io, marker)
    return nothing
end

@testset "Wannier Hamiltonian-operator protocol round trips" begin
    mktempdir() do directory
        for formatted in (false, true)
            suffix = formatted ? ".fmt" : ""
            uiu_header = OPERATOR_IO.WannierUIUHeader("uIu protocol test", 2, 2, 2)
            uhu_header = OPERATOR_IO.WannierUHUHeader("uHu protocol test", 2, 2, 2)
            shu_header = OPERATOR_IO.WannierSHUHeader("sHu protocol test", 2, 2, 2)
            siu_header = OPERATOR_IO.WannierSIUHeader("sIu protocol test", 2, 2, 2)

            for (label, header, writer, reader, foreach_block, spin_neighbor) in (
                (
                    "uIu",
                    uiu_header,
                    OPERATOR_IO.write_wannier_uiu,
                    OPERATOR_IO.read_wannier_uiu_header,
                    OPERATOR_IO.foreach_wannier_uiu_block,
                    false,
                ),
                (
                    "uHu",
                    uhu_header,
                    OPERATOR_IO.write_wannier_uhu,
                    OPERATOR_IO.read_wannier_uhu_header,
                    OPERATOR_IO.foreach_wannier_uhu_block,
                    false,
                ),
                (
                    "sHu",
                    shu_header,
                    OPERATOR_IO.write_wannier_shu,
                    OPERATOR_IO.read_wannier_shu_header,
                    OPERATOR_IO.foreach_wannier_shu_block,
                    true,
                ),
                (
                    "sIu",
                    siu_header,
                    OPERATOR_IO.write_wannier_siu,
                    OPERATOR_IO.read_wannier_siu_header,
                    OPERATOR_IO.foreach_wannier_siu_block,
                    true,
                ),
            )
                filename = joinpath(directory, label * suffix)
                writer(filename, header; formatted) do first, second, third, _
                    operator_protocol_block(first, second, third, header.num_bands)
                end
                observed_header = reader(filename; formatted)
                @test observed_header.comment == header.comment
                @test (
                    observed_header.num_bands,
                    observed_header.num_kpts,
                    observed_header.num_neighbors,
                ) == (2, 2, 2)
                streamed_header, order, blocks =
                    collect_operator_blocks(foreach_block, filename; formatted)
                expected_order =
                    spin_neighbor ? [(ik, nn, ispol) for ik in 1:2 for nn in 1:2 for ispol in 1:3] :
                    [(ik, nn2, nn1) for ik in 1:2 for nn2 in 1:2 for nn1 in 1:2]
                @test order == expected_order
                @test all(
                    blocks[index] == operator_protocol_block(order[index]..., 2) for
                    index in eachindex(order)
                )
                @test streamed_header.comment == header.comment
                @test_throws ArgumentError foreach_block(
                    (_...) -> nothing,
                    filename;
                    formatted,
                    expected_num_bands = 3,
                )
            end
        end
    end
end

@testset "Wannier operator protocol big-endian and corruption rejection" begin
    mktempdir() do directory
        filename = joinpath(directory, "big-endian.uHu")
        physical = ComplexF64[1 + 2im 3 + 4im; 5 + 6im 7 + 8im]
        open(filename, "w") do io
            write_big_endian_record(io, collect(codeunits(rpad("big endian", 60))))
            write_big_endian_record(io, big_endian_bytes(Int32[2, 1, 1]))
            upstream_raw = vec(copy(transpose(physical)))
            write_big_endian_record(io, big_endian_bytes(upstream_raw))
        end
        observed = Matrix{ComplexF64}[]
        OPERATOR_IO.foreach_wannier_uhu_block(filename) do block, _, _, _, _
            push!(observed, block)
        end
        @test observed == [physical]

        trailing = joinpath(directory, "trailing.uHu")
        cp(filename, trailing)
        open(trailing, "a") do io
            write(io, UInt8(0xff))
        end
        @test_throws ArgumentError OPERATOR_IO.foreach_wannier_uhu_block(
            (_...) -> nothing,
            trailing,
        )

        truncated = joinpath(directory, "truncated.uHu")
        bytes = read(filename)
        write(truncated, bytes[1:(end - 3)])
        @test_throws Exception OPERATOR_IO.foreach_wannier_uhu_block((_...) -> nothing, truncated)

        mismatched = joinpath(directory, "marker-mismatch.uHu")
        cp(filename, mismatched)
        open(mismatched, "r+") do io
            seekend(io)
            seek(io, position(io) - 1)
            write(io, UInt8(0x00))
        end
        @test_throws Exception OPERATOR_IO.foreach_wannier_uhu_block((_...) -> nothing, mismatched)

        malformed = joinpath(directory, "malformed.sIu.fmt")
        write(malformed, "formatted\n1 1 1\nNaN 0.0\n")
        @test_throws ArgumentError OPERATOR_IO.foreach_wannier_siu_block(
            (_...) -> nothing,
            malformed;
            formatted = true,
        )

        invalid_header = joinpath(directory, "invalid.uIu.fmt")
        write(invalid_header, "formatted\n1 zero 1\n")
        @test_throws ArgumentError OPERATOR_IO.read_wannier_uiu_header(
            invalid_header;
            formatted = true,
        )
    end
end

@testset "Wannier operator writers publish atomically" begin
    mktempdir() do directory
        output = joinpath(directory, "failed.sHu")
        header = OPERATOR_IO.WannierSHUHeader("atomic failure", 2, 1, 1)
        @test_throws ErrorException OPERATOR_IO.write_wannier_shu(output, header) do args...
            args[3] == 2 && error("synthetic block-provider failure")
            return zeros(ComplexF64, 2, 2)
        end
        @test !isfile(output)
        @test isempty(filter(name -> occursin("failed.sHu", name), readdir(directory)))

        @test_throws ArgumentError OPERATOR_IO.WannierUHUHeader("invalid", 0, 1, 1)
        @test_throws ArgumentError OPERATOR_IO.write_wannier_uhu(
            joinpath(directory, "bad-block.uHu"),
            OPERATOR_IO.WannierUHUHeader("bad block", 2, 1, 1),
        ) do _...
            zeros(ComplexF64, 1, 1)
        end
        @test !isfile(joinpath(directory, "bad-block.uHu"))
    end
end
