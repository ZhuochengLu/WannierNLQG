# Preserve direct and nested Test totals across supported Julia versions.
function test_count_totals(counts)
    if counts isa Tuple
        length(counts) == 9 || throw(ArgumentError("Unsupported Test counter tuple"))
        p, f, e, b, cp, cf, ce, cb, duration = counts
    else
        fields = (
            :passes,
            :fails,
            :errors,
            :broken,
            :cumulative_passes,
            :cumulative_fails,
            :cumulative_errors,
            :cumulative_broken,
        )
        all(name -> hasproperty(counts, name), fields) ||
            throw(ArgumentError("Unsupported Test counter fields"))
        p, f, e, b = counts.passes, counts.fails, counts.errors, counts.broken
        cp, cf = counts.cumulative_passes, counts.cumulative_fails
        ce, cb = counts.cumulative_errors, counts.cumulative_broken
    end
    values = (p, f, e, b, cp, cf, ce, cb)
    all(x -> x isa Integer && !(x isa Bool) && x >= 0, values) ||
        throw(ArgumentError("Invalid Test counter values"))
    return (; passed = p + cp, failed = f + cf, errored = e + ce, broken = b + cb)
end

# Calling the Test API remains once per completed test set, as before.
test_result_totals(result::Test.AbstractTestSet) = test_count_totals(Test.get_test_counts(result))
