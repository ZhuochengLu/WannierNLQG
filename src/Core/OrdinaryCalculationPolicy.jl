"""Reject the removed construction mode before input preparation or solving."""
function validate_ordinary_construction_policy(policy::Symbol)
    policy == :strict && throw(
        ArgumentError(
            "construction_policy=:strict is an invalid parameter: strict Wannierization " *
            "construction was removed. Remove construction_policy to use ordinary " *
            "calculation with reported residuals, convergence and warnings.",
        ),
    )
    policy == :standard || throw(
        ArgumentError(
            "construction_policy is invalid; ordinary calculation is the only construction behavior",
        ),
    )
    return nothing
end
