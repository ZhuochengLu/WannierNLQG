"""Independent accepted-step limits and objective-change stopping controls.

Z compares relative changes; U compares absolute total-spread changes in Å².
The first accepted value has no predecessor and cannot increment a window.
A zero Z reference is stable only against another exact zero. U windows <= 1
disable early stopping. Numerical admissibility checks remain independent.
"""
struct WannierizationStageControls
    dis_num_iter::Int
    dis_conv_tol::Float64
    dis_conv_window::Int
    num_iter::Int
    conv_tol::Float64
    conv_window::Int
    function WannierizationStageControls(;
        dis_num_iter = 200,
        dis_conv_tol = 1e-10,
        dis_conv_window = 3,
        num_iter = 500,
        conv_tol = 1e-10,
        conv_window = 3,
    )
        for (name, value) in (
            (:dis_num_iter, dis_num_iter),
            (:num_iter, num_iter),
            (:dis_conv_window, dis_conv_window),
            (:conv_window, conv_window),
        )
            value isa Integer && !(value isa Bool) ||
                throw(ArgumentError("$name must be an integer"))
        end
        dis_num_iter >= 0 && num_iter >= 0 ||
            throw(ArgumentError("stage iteration limits must be nonnegative"))
        dis_conv_window > 0 || throw(ArgumentError("dis_conv_window must be positive"))
        all(x -> x isa Real && !(x isa Bool) && isfinite(x) && x >= 0, (dis_conv_tol, conv_tol)) ||
            throw(ArgumentError("stage tolerances must be finite and nonnegative"))
        new(dis_num_iter, dis_conv_tol, dis_conv_window, num_iter, conv_tol, conv_window)
    end
end

# Recompute consecutive acceptance from retained objective history, including a
# changed threshold on restart. No missing predecessor is invented.
function wannier_stage_stability(values, tolerance; relative::Bool)
    count = 0
    for index in length(values):-1:2
        previous, current = values[index - 1], values[index]
        isfinite(previous) && isfinite(current) || break
        change =
            relative ?
            (
                iszero(previous) ? (iszero(current) ? 0.0 : Inf) :
                abs(current-previous)/abs(previous)
            ) : abs(current-previous)
        change <= tolerance || break
        count += 1
    end
    return count
end
