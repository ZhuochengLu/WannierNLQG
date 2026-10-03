#!/usr/bin/env python3
"""Verify fresh-process ABBA first-use records and native science output."""

import argparse
import json
import math
from pathlib import Path
import struct


def exact_json(value):
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError("nonfinite JSON science value")
        return {"float64_bits": struct.pack(">d", value).hex()}
    if isinstance(value, dict):
        return {key: exact_json(item) for key, item in value.items()}
    if isinstance(value, list):
        return [exact_json(item) for item in value]
    return value


def science_payload(path):
    if path.suffix == ".json":
        return exact_json(json.loads(path.read_text()))
    rows = []
    for line in path.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        values = [float(word) for word in line.split()]
        if not all(math.isfinite(value) for value in values):
            raise ValueError(f"nonfinite science output: {path}")
        rows.append([struct.pack(">d", value).hex() for value in values])
    if not rows:
        raise ValueError(f"empty science output: {path}")
    return rows


def outputs(directory):
    first = directory / "first"
    result = {}
    for file in first.rglob("*"):
        if file.is_file() and file.suffix in (".dat", ".json"):
            result[str(file.relative_to(first))] = science_payload(file)
    if not result:
        raise ValueError(f"no native science output: {directory}")
    return result


def rank_records(directory, size):
    records = []
    for rank in range(size):
        path = directory / f"rank_{rank}.json"
        records.append(json.loads(path.read_text()))
    return records


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--registry", type=Path, required=True)
    parser.add_argument("--campaign", type=Path, required=True)
    parser.add_argument("--ranks", type=int, choices=(1, 12), required=True)
    parser.add_argument("--cases", help="comma-separated subset for a pilot audit")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    registry = json.loads(args.registry.read_text())
    if len(registry) != 52 or len({row["id"] for row in registry}) != 52:
        raise ValueError("expected exactly 52 registered paths")
    selected = set(args.cases.split(",")) if args.cases else None
    if selected and selected - {row["id"] for row in registry}:
        raise ValueError("unknown registered path ID")
    if args.output.exists():
        raise FileExistsError(args.output)
    summary = []
    for row in registry:
        if selected and row["id"] not in selected:
            continue
        root = args.campaign / row["id"]
        attempts = [root / f"{index}_{arm}" for index, arm in enumerate("ABBA", start=1)]
        records = [rank_records(path, args.ranks) for path in attempts]
        payloads = [outputs(path) for path in attempts]
        science_equal = payloads[0] == payloads[1] == payloads[2] == payloads[3]
        labels_equal = len({tuple(item[0]["task_labels"]) for item in records}) == 1
        correct_path = all(
            all(record["path"] == row["example"] for record in group) for group in records
        )
        compile_maxima = [max(rank["first"]["compile_time"] for rank in group) for group in records]
        recomp_maxima = [max(rank["first"]["recompile_time"] for rank in group) for group in records]
        task_spans = [
            max(rank["first"]["wall"] for rank in group) for group in records
        ]
        attempt_records = [json.loads((path / "attempt.json").read_text()) for path in attempts]
        complete = all(
            record["exit_code"] == 0 and record["ranks_written"] == args.ranks
            for record in attempt_records
        )
        passed = (
            complete
            and science_equal
            and labels_equal
            and correct_path
            and compile_maxima[1] <= 0.5
            and compile_maxima[2] <= 0.5
        )
        summary.append(
            {
                "id": row["id"],
                "pass": passed,
                "science_equal": science_equal,
                "labels_equal": labels_equal,
                "path_equal": correct_path,
                "complete": complete,
                "first_compile_max_seconds_ABBA": compile_maxima,
                "first_recompile_max_seconds_ABBA": recomp_maxima,
                "first_task_wall_max_seconds_ABBA": task_spans,
                "whole_process_wall_seconds_ABBA": [
                    item["process_wall_seconds"] for item in attempt_records
                ],
                "science_files": len(payloads[0]),
            }
        )
    args.output.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"verified {sum(item['pass'] for item in summary)}/{len(summary)} paths")
    if not all(item["pass"] for item in summary):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
