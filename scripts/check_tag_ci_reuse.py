#!/usr/bin/env python3
"""Fail-closed validation that a tag target already passed the complete main CI."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


EXPECTED_JOB_NAMES = {
    "fast (ubuntu-latest, Julia 1.10)",
    "fast (ubuntu-latest, Julia current)",
    "fast (macos-latest, Julia 1.10)",
    "fast (macos-latest, Julia current)",
    "full-shard (interfaces-and-symmetry)",
    "full-shard (wannier-core)",
    "full-shard (scientific-contracts)",
    "full-shard (thread-determinism)",
    "full-shard (star-gauge-thread)",
    "mpi-only",
    "ci-required",
}


class ContractError(RuntimeError):
    pass


def _load_json(path: str) -> dict[str, Any]:
    with Path(path).open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ContractError(f"JSON fixture must contain an object: {path}")
    return value


def _api_json(url: str, token: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "wanniernlqg-tag-ci-reuse-gate",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        value = json.load(response)
    if not isinstance(value, dict):
        raise ContractError(f"GitHub API returned a non-object payload: {url}")
    return value


def _eligible_run(run: dict[str, Any], sha: str, current_run_id: int | None) -> bool:
    return (
        run.get("head_sha") == sha
        and run.get("head_branch") == "main"
        and run.get("event") == "push"
        and run.get("status") == "completed"
        and run.get("conclusion") == "success"
        and isinstance(run.get("id"), int)
        and run.get("id") != current_run_id
    )


def _validate_jobs(payload: dict[str, Any]) -> None:
    jobs = payload.get("jobs")
    if not isinstance(jobs, list):
        raise ContractError("jobs payload lacks a jobs array")

    by_name: dict[str, list[dict[str, Any]]] = {}
    for raw_job in jobs:
        if not isinstance(raw_job, dict) or not isinstance(raw_job.get("name"), str):
            raise ContractError("jobs payload contains an invalid job record")
        by_name.setdefault(raw_job["name"], []).append(raw_job)

    actual_names = set(by_name)
    missing = sorted(EXPECTED_JOB_NAMES - actual_names)
    extra = sorted(actual_names - EXPECTED_JOB_NAMES)
    if missing or extra:
        raise ContractError(f"CI job inventory mismatch: missing={missing}, extra={extra}")

    duplicates = sorted(name for name, entries in by_name.items() if len(entries) != 1)
    if duplicates:
        raise ContractError(f"CI job inventory contains duplicates: {duplicates}")

    rejected = []
    for name in sorted(EXPECTED_JOB_NAMES):
        job = by_name[name][0]
        if job.get("status") != "completed" or job.get("conclusion") != "success":
            rejected.append(
                f"{name}:status={job.get('status')!r},conclusion={job.get('conclusion')!r}"
            )
    if rejected:
        raise ContractError("required CI jobs are not exact success: " + "; ".join(rejected))


def _candidate_runs(payload: dict[str, Any], sha: str, current_run_id: int | None):
    runs = payload.get("workflow_runs")
    if not isinstance(runs, list):
        raise ContractError("workflow-runs payload lacks a workflow_runs array")
    eligible = [run for run in runs if isinstance(run, dict) and _eligible_run(run, sha, current_run_id)]
    return sorted(eligible, key=lambda run: (str(run.get("created_at", "")), int(run["id"])), reverse=True)


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--workflow", default="ci.yml")
    parser.add_argument("--current-run-id", type=int)
    parser.add_argument("--runs-json")
    parser.add_argument("--jobs-json")
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.sha):
        raise ContractError("--sha must be a lowercase 40-character commit SHA")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository):
        raise ContractError("--repository must be OWNER/REPOSITORY")
    if bool(args.runs_json) != bool(args.jobs_json):
        raise ContractError("--runs-json and --jobs-json must be provided together")

    if args.runs_json:
        runs_payload = _load_json(args.runs_json)
        jobs_fixture = _load_json(args.jobs_json)
        candidates = _candidate_runs(runs_payload, args.sha, args.current_run_id)
        if len(candidates) != 1:
            raise ContractError(f"offline fixture must contain exactly one eligible run; found {len(candidates)}")
        _validate_jobs(jobs_fixture)
        selected = candidates[0]
    else:
        token = os.environ.get("GITHUB_TOKEN", "")
        if not token:
            raise ContractError("GITHUB_TOKEN is required for live tag validation")
        api_url = os.environ.get("GITHUB_API_URL", "https://api.github.com").rstrip("/")
        query = urllib.parse.urlencode(
            {"head_sha": args.sha, "event": "push", "status": "success", "per_page": "100"}
        )
        runs_url = (
            f"{api_url}/repos/{args.repository}/actions/workflows/"
            f"{urllib.parse.quote(args.workflow, safe='')}/runs?{query}"
        )
        runs_payload = _api_json(runs_url, token)
        candidates = _candidate_runs(runs_payload, args.sha, args.current_run_id)
        if not candidates:
            raise ContractError("no completed successful main push CI exists for the exact tag target SHA")

        selected = None
        failures = []
        for candidate in candidates:
            run_id = int(candidate["id"])
            jobs_url = f"{api_url}/repos/{args.repository}/actions/runs/{run_id}/jobs?filter=all&per_page=100"
            try:
                _validate_jobs(_api_json(jobs_url, token))
                selected = candidate
                break
            except ContractError as error:
                failures.append(f"run {run_id}: {error}")
        if selected is None:
            raise ContractError("no exact successful CI job set found: " + " | ".join(failures))

    print(
        "TAG_CI_REUSE_PASS "
        f"sha={args.sha} source_run_id={selected['id']} source_branch=main "
        f"required_jobs={len(EXPECTED_JOB_NAMES)}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ContractError, OSError, ValueError, json.JSONDecodeError) as error:
        print(f"TAG_CI_REUSE_FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
