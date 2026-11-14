"""Best-effort Linux CI observation; never signal or change the test process.

Read only process identities/RSS, host memory and cgroup counters. No command
arguments or environment are collected. RSS sums include shared mappings and
are not physical memory usage; cgroup counters may include setup and services.
"""
from pathlib import Path
import argparse
import datetime
import json
import os
import sys
import time


def parse_stat(text, page_bytes=4096):
    left, right = text.index("("), text.rindex(")")
    fields = text[right + 1:].split()
    rss_pages = int(fields[21])
    if rss_pages < 0:
        raise ValueError("negative RSS")
    return dict(pid=int(text[:left]), comm=text[left + 1:right],
                ppid=int(fields[1]), start_ticks=int(fields[19]),
                rss_kib=rss_pages * page_bytes // 1024)


def descendants(records, owner_pid, owner_start):
    owner = records.get(owner_pid)
    if owner is None or owner["start_ticks"] != owner_start:
        return []
    selected = {owner_pid}
    while True:
        more = {pid for pid, row in records.items() if row["ppid"] in selected}
        if more <= selected:
            return [records[pid] for pid in sorted(selected)]
        selected.update(more)


def text_counter(path):
    try:
        with Path(path).open() as stream:
            value = stream.read(4097)
        if len(value) > 4096:
            raise ValueError("counter exceeds bound")
        return dict(value=value.strip(), error=None)
    except (OSError, ValueError) as error:
        return dict(value=None, error=type(error).__name__)


def meminfo(path):
    allowed = {"MemTotal", "MemAvailable", "SwapTotal", "SwapFree"}
    result = {key: None for key in sorted(allowed)}
    for line in Path(path).read_text().splitlines():
        key, _, rest = line.partition(":")
        if key in allowed:
            fields = rest.split()
            if len(fields) == 2 and fields[1] == "kB":
                result[key] = int(fields[0])
    return result


def process_records():
    result = {}
    page_bytes = os.sysconf("SC_PAGE_SIZE")
    for entry in Path("/proc").iterdir():
        if entry.name.isdecimal():
            try:
                row = parse_stat((entry / "stat").read_text(), page_bytes)
                result[row["pid"]] = row
            except (OSError, ValueError, IndexError):
                pass  # Processes can disappear during this non-atomic read.
    return result


def cgroup_counters(owner_pid):
    root = Path("/sys/fs/cgroup")
    resolved = False
    try:
        lines = Path(f"/proc/{owner_pid}/cgroup").read_text().splitlines()
        relative = next(line.split(":", 2)[2] for line in lines if line.startswith("0::"))
        candidate = root / relative.lstrip("/")
        if ".." not in candidate.parts and candidate.is_dir():
            root = candidate
            resolved = True
    except (OSError, StopIteration, IndexError):
        pass
    return dict(location=str(root), owner_membership_resolved=resolved,
                scope="owner cgroup when resolved, else mount-root fallback; may include setup/services",
                counters={name: text_counter(root / name) for name in
                          ["memory.max", "memory.current", "memory.peak", "memory.events", "cpu.max"]})


def emit(value):
    value["utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    print("[mpi-runner-resources] " + json.dumps(value, sort_keys=True), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner-pid", type=int, required=True)
    parser.add_argument("--interval", type=float, default=30)
    parser.add_argument("--max-seconds", type=float, default=7200)
    args = parser.parse_args()
    if args.owner_pid <= 0 or args.interval <= 0 or args.max_seconds <= 0:
        parser.error("positive identity and observation bounds required")
    if sys.platform != "linux":
        emit(dict(kind="unsupported_platform", platform=sys.platform))
        return 0
    try:
        owner = parse_stat(Path(f"/proc/{args.owner_pid}/stat").read_text())
    except (OSError, ValueError, IndexError):
        emit(dict(kind="observer_done", reason="original owner absent"))
        return 0
    end = time.monotonic() + args.max_seconds
    next_sample = 0.0
    while time.monotonic() < end:
        try:
            current = parse_stat(Path(f"/proc/{args.owner_pid}/stat").read_text())
        except (OSError, ValueError, IndexError):
            current = None
        if current is None or current["start_ticks"] != owner["start_ticks"]:
            emit(dict(kind="observer_done", reason="original owner gone or reused"))
            return 0
        now = time.monotonic()
        if now >= next_sample:
            try:
                members = descendants(process_records(), args.owner_pid, owner["start_ticks"])
                if not members:
                    return 0
                emit(dict(kind="sample", owner_pid=args.owner_pid,
                          owner_start_ticks=owner["start_ticks"], atomic_snapshot=False,
                          logical_cpu_count=os.cpu_count(),
                          observer_affinity_cpu_count=len(os.sched_getaffinity(0)),
                          host_meminfo_kib=meminfo("/proc/meminfo"),
                          cgroup=cgroup_counters(args.owner_pid),
                          sum_process_rss_kib_including_shared_pages=sum(row["rss_kib"] for row in members),
                          rss_is_physical_memory=False, processes=members))
            except (OSError, ValueError) as error:
                emit(dict(kind="sample_unavailable", error=type(error).__name__))
            next_sample = now + args.interval
        time.sleep(1)
    emit(dict(kind="observer_done", reason="observation bound reached; tests not stopped"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
