module SyntheticRuntimeFixture

using SHA
using WannierNLQG

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const FIXTURE_ROOT = joinpath(ROOT, "examples", "fixtures", "synthetic_runtime")
const TB_FILE = joinpath(FIXTURE_ROOT, "synthetic_tb.dat")
const WSVEC_FILE = joinpath(FIXTURE_ROOT, "synthetic_wsvec.dat")
const OPERATOR_BUNDLE_FILE = joinpath(FIXTURE_ROOT, "synthetic_operators.h5")

function verify()
    for line in eachline(joinpath(FIXTURE_ROOT, "SHA256SUMS"))
        expected, relative = split(strip(line); limit = 2)
        path = joinpath(FIXTURE_ROOT, strip(relative))
        isfile(path) || error("missing synthetic runtime fixture $(path)")
        islink(path) && error("synthetic runtime fixture must not be a symbolic link: $(path)")
        bytes2hex(sha256(read(path))) == expected ||
            error("synthetic runtime fixture checksum mismatch: $(path)")
    end
    return nothing
end

function response_config(output_root, task; backend = "direct", policy = "minimum_distance")
    mixed = backend == "mixed" ? (; NKdiv = (1, 1), NKFFT = (2, 2)) : (;)
    return WannierNLQG.Runtime.EffectiveTaskConfig(;
        tasks = [task],
        case_root = ROOT,
        model_file = TB_FILE,
        real_space_operator_bundle_file = OPERATOR_BUNDLE_FILE,
        output_root = String(output_root),
        system_name = "synthetic_demo",
        k_mesh = (2, 2),
        fourier_backend = backend,
        mixed...,
        photon_energies = [0.25],
        fermi_energy = 0.0,
        broadening = 0.06,
        spatial_dimension = 2,
        tensor_indices = (2, 2, 2),
        band_selection = ([3, 4], [1, 2]),
        real_space_replica_policy = policy,
        wsvec_file = policy == "minimum_distance" ? WSVEC_FILE : nothing,
        mp_grid = policy == "minimum_distance" ? (2, 1, 1) : nothing,
        progress_enabled = false,
    )
end

end
