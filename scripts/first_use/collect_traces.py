#!/usr/bin/env python3
"""Collect one untouched Julia trace per registered path and MPI rank.

Use a separate diagnostic source with PrecompileTools workloads disabled. The
trace includes import and runner compilation; it is evidence, not a speed sample.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

sys.dont_write_bytecode = True
# Source collection is independent of the final measurement controller.
MIN_FREE_BYTES = 10 * 1024**3
SINGLE_PROCESS_LIMIT = 180


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def collect(project, runner, wrapper, example, destination, depot, ranks):
    destination.mkdir(parents=True, exist_ok=False)
    if shutil.disk_usage(destination).free < MIN_FREE_BYTES:
        raise RuntimeError("less than 10 GiB of free disk")
    from expert_campaign import quiet
    quiet(destination, example)

    trace_dir = destination / "trace"
    trace_dir.mkdir()
    env = os.environ.copy()
    env.update(
        JULIA_DEPOT_PATH=os.pathsep.join([str(depot), *json.loads(os.environ.get("FIRSTUSE_READONLY_DEPOTS", "[]")), str(Path.home() / ".julia")]),
        JULIA_NUM_THREADS="1",
        OPENBLAS_NUM_THREADS="1",
        OMP_NUM_THREADS="1",
        VECLIB_MAXIMUM_THREADS="1",
        MKL_NUM_THREADS="1",
        WNLQG_TRACE_DIR=str(trace_dir),
    )
    command = ["/bin/sh", str(wrapper), str(project), str(runner), example, str(destination / "output")]
    if ranks > 1:
        command = [shutil.which("mpiexec") or "mpiexec", "-n", str(ranks), *command]
    env.update(FIRSTUSE_COLLECT_INFERENCE="1", JULIA_PKG_PRECOMPILE_AUTO="0", JULIA_NUM_PRECOMPILE_TASKS="1")
    from guarded_process import run
    resource = run(command, env, destination, SINGLE_PROCESS_LIMIT)
    return_code = resource["return_code"]
    stopped = resource["stop_reason"]
    traces = sorted(trace_dir.glob("rank_*.jl"))
    record = {
        "command": command,
        "project_sha256": sha256(project / "Project.toml"),
        "manifest_sha256": sha256(project / "Manifest.toml"),
        "runner_sha256": sha256(runner),
        "wrapper_sha256": sha256(wrapper),
        "example_sha256": (
            sha256(project / "examples" / "tasks" / example)
            if (project / "examples" / "tasks" / example).is_file()
            else None
        ),
        "source_manifest_sha256": sha256(project / "SOURCE_MANIFEST.tsv"),
        "return_code": return_code,
        "stop_reason": stopped,
        "wall_seconds": resource["wall_seconds"],
        "ranks_expected": ranks,
        "traces": {path.name: sha256(path) for path in traces},
        "max_tree_rss_kib": resource["max_tree_rss_kib"],
    }
    (destination / "receipt.json").write_text(json.dumps(record, indent=2) + "\n")
    return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--registry", type=Path, required=True)
    parser.add_argument("--depot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--ranks", type=int, choices=(1, 12), required=True)
    parser.add_argument("--readonly-depot", type=Path, action="append", default=[])
    parser.add_argument("--cases", help="comma-separated registered path IDs")
    args = parser.parse_args()
    project = args.project.resolve()
    candidate = args.candidate.resolve()
    output = args.output.resolve()
    runner = candidate / "scripts/first_use/run_case.jl"
    wrapper = candidate / "scripts/first_use/trace_rank.sh"
    rows = json.loads(args.registry.read_text())
    if len(rows) != 52 or len({row["id"] for row in rows}) != 52:
        raise RuntimeError("registry is not the frozen 52-path table")
    selected = set(args.cases.split(",")) if args.cases else None
    if selected and selected - {row["id"] for row in rows}:
        raise RuntimeError("unknown path ID")
    output.mkdir(parents=True, exist_ok=False)
    from source_identity import source_digest
    from fixture_bundle import verify
    if source_digest(project) != source_digest(candidate):
        raise ValueError("TRACE_COMPUTATION_SOURCE_MISMATCH")
    preference = project / "LocalPreferences.toml"
    if not preference.is_file() or "precompile_workloads = false" not in preference.read_text():
        raise ValueError("TRACE_WORKLOAD_OFF_PROJECT_REQUIRED")
    os.environ["FIRSTUSE_READONLY_DEPOTS"] = json.dumps([str(p.resolve()) for p in args.readonly_depot])
    receipts = []
    index = []
    for row in rows:
        if selected and row["id"] not in selected:
            continue
        destination = output / row["id"]
        receipt = collect(
            project, runner, wrapper, row["example"], destination, args.depot.resolve(), args.ranks
        )
        receipts.append({"id": row["id"], "example": row["example"], **receipt})
        (output / "receipts.json").write_text(json.dumps(receipts, indent=2) + "\n")
        if receipt["return_code"] != 0 or len(receipt["traces"]) != args.ranks:
            raise RuntimeError(f"trace failed; preserved at {destination}")
        rank_rows = []
        for rank in range(args.ranks):
            record = json.loads((destination / f"output/rank_{rank}.json").read_text())
            if record["workload_enabled"]:
                raise ValueError("TRACE_WORKLOAD_WAS_ACTIVE")
            raw = (destination / f"trace/rank_{rank}.jl").read_bytes()
            before, after = record["first_call_trace_bytes_before"], record["first_call_trace_bytes_after"]
            if not isinstance(before, int) or not isinstance(after, int) or not 0 <= before <= after <= len(raw):
                raise ValueError("TRACE_INVALID_PUBLIC_INTERVAL")
            target = destination / f"first_call_rank_{rank}.jl"
            target.write_bytes(raw[before:after])
            inference = destination / f"output/inference_rank_{rank}/inference_timings.json"
            actual = destination / f"output/inference_rank_{rank}/actual_all_inference_types.jls"
            rank_rows.append(dict(rank=rank,target_trace=str(target.relative_to(output)),target_trace_sha256=sha256(target),
                inference=str(inference.relative_to(output)),inference_sha256=sha256(inference),
                actual_types=str(actual.relative_to(output)),actual_types_sha256=sha256(actual),inference_collected=True))
        index.append(dict(id=row["id"],source_src_ext_sha256=source_digest(project),manifest_sha256=sha256(project/"Manifest.toml"),
              source_manifest_sha256=sha256(project/"SOURCE_MANIFEST.tsv"),runner_sha256=sha256(runner),ranks=rank_rows))
        (output / "index_partial.json").write_text(json.dumps(index,indent=2)+"\n")
    (output / "index.json").write_text(json.dumps(index,indent=2)+"\n")
    print(f"collected {len(receipts)} path traces in {output}")


if __name__ == "__main__":
    main()
