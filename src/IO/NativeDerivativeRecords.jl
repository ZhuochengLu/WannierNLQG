"""Persist actual per-order use; convergence estimates are not certified derivative errors."""
function write_native_derivative_records(path, records)
    open(path, "w") do io
        println(
            io,
            "# native derivative diagnostics; scope=shared_run; errors=convergence_estimates",
        )
        println(
            io,
            "order\tsource\tevaluations\tstatus\th\th_over_2\th_over_4\tadopted_h\tcoarse_error\tfine_error\tworst_k",
        )
        for order in 1:3
            if !haskey(records, order)
                println(io, order, "\tNOT_EVALUATED\t0\tNOT_EVALUATED\tNA\tNA\tNA\tNA\tNA\tNA\tNA")
                continue
            end
            row=records[order]
            if row.source=="FINITE_DIFFERENCE"
                println(
                    io,
                    join(
                        (
                            order,
                            row.source,
                            row.count,
                            row.passed ? "PASS" : "FAIL",
                            row.step,
                            row.step/2,
                            row.step/4,
                            row.step/4,
                            row.coarse_error,
                            row.fine_error,
                            repr(row.point),
                        ),
                        "\t",
                    ),
                )
            else
                println(
                    io,
                    join(
                        (
                            order,
                            row.source,
                            row.count,
                            "EVALUATED",
                            "NA",
                            "NA",
                            "NA",
                            "NA",
                            "NOT_EVALUATED",
                            "NOT_EVALUATED",
                            repr(row.point),
                        ),
                        "\t",
                    ),
                )
            end
        end
        println(
            io,
            "# FD criterion: e2 <= 1e-8 + 1e-5*maxabs(fine), and (e2 <= 0.6*e1 or e1 <= tolerance)",
        )
    end
    return String(path)
end
