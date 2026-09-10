#!/usr/bin/env python3
"""Run complete package-test suites in isolated, resource-budgeted processes.

The root project owns Pkg.test; Julia constructs the test dependency environment.
No JULIA_LOAD_PATH override or MPI-driver opt-in is introduced. Resource usage is
wait4 child usage (including reaped descendants), not sampled aggregate tree RSS.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SHARDS = (
    "interfaces-and-symmetry",
    "wannier-core",
    "scientific-contracts",
    "thread-determinism",
    "star-gauge-thread",
)
TASK_CPU_SLOTS = {
    "fast": 3, "interfaces-and-symmetry": 5, "wannier-core": 2,
    "scientific-contracts": 3, "thread-determinism": 5, "star-gauge-thread": 5,
    "mpi-only": 17,
}  # Maximum probe threads/ranks plus the serial parent.
NESTED_ENV = "WANNIERNLQG_TEST_SCHEDULER_ACTIVE"
COMPLETE_PREFIX = "WANNIERNLQG_TEST_TASK_COMPLETE:"


@dataclass(frozen=True)
class Task:
    """One complete, non-overlapping package-test selection."""

    name: str
    mode: str
    shard: str | None = None


def suite_tasks(suite: str) -> list[Task]:
    """Expand Full into Fast, every Full-only shard, and independent MPI."""
    tasks = [Task("fast", "fast")]
    if suite == "full":
        tasks.extend(Task(name, "full-shard", name) for name in SHARDS)
        tasks.append(Task("mpi-only", "mpi-only"))
    elif suite != "fast":
        raise ValueError(f"Unknown suite: {suite}")
    return tasks


def task_cpu_slots(task: Task, jobs: int) -> int:
    """Charge both Fast readiness children unless serial fallback is requested."""
    return 2 if task.mode == "fast" and jobs == 1 else TASK_CPU_SLOTS[task.name]


def julia_command(julia: str, task: Task) -> list[str]:
    """Print a task-specific completion receipt only after Pkg.test returns."""
    marker = COMPLETE_PREFIX + task.name
    expression = f'using Pkg; Pkg.test(); println({json.dumps(marker)})'
    return [julia, "--startup-file=no", "--threads=1", f"--project={ROOT}", "-e", expression]


def task_environment(task: Task, directory: Path, readiness_jobs: int = 1) -> dict[str, str]:
    """Keep child temp/output paths private and numerical workers bounded."""
    env = dict(os.environ)
    for key in (
        "WANNIERNLQG_TEST_LEVEL",
        "WANNIERNLQG_TEST_MPI",
        "WANNIERNLQG_TEST_SHARD",
        "WANNIERNLQG_USE_MPI",
    ):
        env.pop(key, None)
    env.update(
        {
            NESTED_ENV: "1",
            "WANNIERNLQG_TEST_MODE": task.mode,
            "WANNIERNLQG_TEST_TASK_ID": task.name,
            "WANNIERNLQG_READINESS_JOBS": str(readiness_jobs if task.mode == "fast" else 1),
            "WANNIERNLQG_TEST_OUTPUT_ROOT": str(directory / "output"),
            "TMPDIR": str(directory / "tmp"),
            "JULIA_NUM_THREADS": "1",
            "JULIA_NUM_PRECOMPILE_TASKS": "1",
            "OMP_NUM_THREADS": "1",
            "MKL_NUM_THREADS": "1",
            "OPENBLAS_NUM_THREADS": "1",
            "VECLIB_MAXIMUM_THREADS": "1",
            "PYTHONDONTWRITEBYTECODE": "1",
        }
    )
    if task.shard:
        env["WANNIERNLQG_TEST_SHARD"] = task.shard
    return env


def resource_record(usage: Any) -> dict[str, float | int | str]:
    """Normalize POSIX wait4 accounting without claiming summed tree peak RSS."""
    return {
        "cpu_seconds": usage.ru_utime + usage.ru_stime,
        "peak_rss_bytes": int(usage.ru_maxrss * (1 if sys.platform == "darwin" else 1024)),
        "resource_accounting": "wait4 child usage; peak RSS is not aggregate process-tree RSS",
    }


def run_suite(tasks: list[Task], julia: str, output: Path, jobs: int, cpu_budget: int) -> dict[str, Any]:
    """Defer signals to safe points and protect cleanup from repeated signals."""
    interruption = [False]

    def request_interrupt(*_: Any) -> None:
        interruption[0] = True

    previous = {number: signal.signal(number, request_interrupt) for number in (signal.SIGINT, signal.SIGTERM)}
    try:
        return _run_suite(tasks, julia, output, jobs, cpu_budget, interruption)
    finally:
        for number, handler in previous.items():
            signal.signal(number, handler)


def _run_suite(tasks: list[Task], julia: str, output: Path, jobs: int, cpu_budget: int, interruption: list[bool]) -> dict[str, Any]:
    """Schedule bounded independent jobs, draining all outcomes even after failure."""
    if jobs < 1 or cpu_budget < 2:
        raise ValueError("jobs must be positive; cpu-budget must be at least 2")
    if any(task_cpu_slots(task, jobs) > cpu_budget for task in tasks):
        raise ValueError("CPU budget cannot accommodate the largest task (Full MPI requires 17 slots)")
    if len({task.name for task in tasks}) != len(tasks):
        raise ValueError("Duplicate test task")
    output = output.expanduser().resolve()
    if output == ROOT or ROOT in output.parents:
        raise ValueError("Test output must be outside the source tree")
    output.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    pending = list(tasks)
    active: dict[int, dict[str, Any]] = {}
    results: dict[str, dict[str, Any]] = {}
    interrupted = False
    limit = jobs

    def collect(pid: int, status: int, usage: Any) -> None:
        entry = active.pop(pid)
        entry["process"].returncode = os.waitstatus_to_exitcode(status)
        entry["log_handle"].close()
        content = entry["log_path"].read_bytes()
        marker = (COMPLETE_PREFIX + entry["task"].name).encode()
        internal = f"[test-suite:complete] mode={entry['task'].mode} shard={entry['task'].shard or 'none'} elapsed_s=".encode()
        complete = marker in content.splitlines() and any(line.startswith(internal) for line in content.splitlines())
        exit_code = entry["process"].returncode
        results[entry["task"].name] = {
            "task": entry["task"].name,
            "cpu_slots": task_cpu_slots(entry["task"], jobs),
            "budget_overcommit": task_cpu_slots(entry["task"], jobs) > cpu_budget,
            "status": "INTERRUPTED" if interrupted else ("PASS" if exit_code == 0 and complete else "FAIL"),
            "exit_code": exit_code,
            "completion_marker": complete,
            "started_offset_seconds": entry["started"] - started,
            "finished_offset_seconds": time.monotonic() - started,
            "wall_seconds": time.monotonic() - entry["started"],
            "log": str(entry["log_path"]),
            "log_sha256": hashlib.sha256(content).hexdigest(),
            "command": entry["command"],
            **resource_record(usage),
        }

    try:
        while pending or active:
            if interruption[0]:
                raise KeyboardInterrupt
            while pending and len(active) < limit:
                used_slots = sum(task_cpu_slots(item["task"], jobs) for item in active.values())
                eligible = next((index for index, item in enumerate(pending)
                                 if item.mode != "mpi-only" and used_slots + task_cpu_slots(item, jobs) <= cpu_budget), None)
                if eligible is None:
                    if not active and pending[0].mode == "mpi-only":
                        eligible = 0
                    else:
                        break
                task = pending[eligible]
                if active and (task.mode == "mpi-only" or any(item["task"].mode == "mpi-only" for item in active.values())):
                    break
                pending.pop(eligible)
                directory = output / task.name
                (directory / "tmp").mkdir(parents=True)
                (directory / "output").mkdir()
                log_path = directory / "test.log"
                handle = log_path.open("wb")
                command = julia_command(julia, task)
                launch_started = time.monotonic()
                try:
                    process = subprocess.Popen(
                        command, cwd=ROOT, env=task_environment(task, directory, 1 if jobs == 1 else 2),
                        stdout=handle, stderr=subprocess.STDOUT, start_new_session=True,
                    )
                except OSError as error:
                    handle.write(str(error).encode())
                    handle.close()
                    results[task.name] = {
                        "task": task.name, "status": "INVALID_ENVIRONMENT", "exit_code": None,
                        "completion_marker": False, "wall_seconds": time.monotonic() - launch_started,
                        "started_offset_seconds": launch_started - started,
                        "finished_offset_seconds": time.monotonic() - started,
                        "cpu_seconds": None, "peak_rss_bytes": None, "command": command,
                        "log": str(log_path), "log_sha256": hashlib.sha256(log_path.read_bytes()).hexdigest(),
                    }
                    continue
                active[process.pid] = {
                    "process": process, "task": task, "started": launch_started,
                    "log_handle": handle, "log_path": log_path, "command": command,
                }
                if task.mode == "mpi-only":
                    break
            if interruption[0]:
                raise KeyboardInterrupt
            for pid in list(active):
                waited, status, usage = os.wait4(pid, os.WNOHANG)
                if waited:
                    collect(pid, status, usage)
            if active:
                time.sleep(0.05)
    except KeyboardInterrupt:
        interrupted = True
        interrupted_groups = list(active)
        for pid in interrupted_groups:
            try:
                os.killpg(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        deadline = time.monotonic() + 3
        while active and time.monotonic() < deadline:
            for pid in list(active):
                waited, status, usage = os.wait4(pid, os.WNOHANG)
                if waited:
                    collect(pid, status, usage)
            if active:
                time.sleep(0.05)
        for pid in interrupted_groups:
            try:
                os.killpg(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        for pid in list(active):
            waited, status, usage = os.wait4(pid, 0)
            collect(waited, status, usage)
    for task in pending:
        results[task.name] = {"task": task.name, "status": "NOT_RUN", "reason": "scheduler interrupted"}
    summary = {
        "schema": "wanniernlqg.test-scheduler/1.0", "root": str(ROOT),
        "status": "PASS" if len(results) == len(tasks) and all(row["status"] == "PASS" for row in results.values()) else ("INTERRUPTED" if interrupted else "FAIL"),
        "jobs_requested": jobs, "jobs_effective": limit, "cpu_budget": cpu_budget,
        "cpu_slots_per_task": {task.name: task_cpu_slots(task, jobs) for task in tasks}, "mpi_exclusive": True,
        "wall_seconds": time.monotonic() - started,
        "cpu_seconds": sum(row.get("cpu_seconds") or 0 for row in results.values()),
        "peak_rss_bytes": max((row.get("peak_rss_bytes") or 0 for row in results.values()), default=0),
        "resource_accounting": "wait4 CPU sum and maximum child high-water RSS; not aggregate tree peak RSS",
        "tasks": [results[task.name] for task in tasks],
    }
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    return summary


def main(argv: list[str] | None = None) -> int:
    """Validate local scheduling options and preserve a complete run receipt."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suite", choices=("fast", "full"))
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--cpu-budget", type=int, default=min(8, os.cpu_count() or 1))
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--julia", default="julia")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    if os.environ.get(NESTED_ENV):
        parser.error("Nested test scheduling is prohibited")
    minimum = (2 if args.jobs == 1 else 3) if args.suite == "fast" else 17
    if args.jobs < 1 or args.cpu_budget < minimum:
        parser.error(f"--jobs must be positive and --cpu-budget at least {minimum} for {args.suite}")
    if args.cpu_budget > (os.cpu_count() or 1):
        parser.error("--cpu-budget exceeds available logical CPUs")
    tasks = suite_tasks(args.suite)
    if args.dry_run:
        print(json.dumps({"suite": args.suite, "jobs_effective": args.jobs, "cpu_slots_per_task": {task.name: task_cpu_slots(task, args.jobs) for task in tasks}, "mpi_exclusive": True, "tasks": [{"task": task.name, "command": julia_command(args.julia, task)} for task in tasks]}, indent=2))
        return 0
    output = args.output_dir
    if output is None:
        output = Path(tempfile.mkdtemp(prefix="wanniernlqg-test-run-")) / "results"
    output = output.expanduser().resolve()
    if output.exists():
        parser.error("--output-dir must be a new directory to preserve earlier evidence")
    summary = run_suite(tasks, args.julia, output, args.jobs, args.cpu_budget)
    print(f"{summary['status']}: {output / 'summary.json'}")
    return 0 if summary["status"] == "PASS" else (130 if summary["status"] == "INTERRUPTED" else 1)


if __name__ == "__main__":
    raise SystemExit(main())
