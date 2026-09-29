#!/usr/bin/env python3
"""Prepare one human-reviewed Draft Release from an already qualified tag."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tomllib
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
TAG_PATTERN = re.compile(r"v[0-9]+\.[0-9]+\.[0-9]+\Z")
DIGEST_PATTERN = re.compile(r"[0-9a-f]{64}\Z")
PROHIBITED_BODY = re.compile(
    r"SHA[ -]?256|\b[0-9a-f]{64}\b|^### (?:Validation|Integrity)\s*$", re.I | re.M
)


class DraftError(RuntimeError):
    pass


class GitHubAPI:
    def __init__(self, token: str, repository: str):
        if not token:
            raise DraftError("GITHUB_TOKEN is required")
        if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
            raise DraftError("invalid owner/repository")
        self.token = token
        self.repository = repository

    def request(self, method: str, path: str, payload: dict[str, Any] | None = None) -> Any:
        url = f"https://api.github.com/repos/{self.repository}{path}"
        data = None if payload is None else json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {self.token}",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": "WannierNLQG-release-draft",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return None
            raise DraftError(f"GitHub API {method} {path} returned HTTP {error.code}") from error


def git(*arguments: str) -> str:
    command = subprocess.run(
        ["git", *arguments],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if command.returncode:
        raise DraftError(f"git {' '.join(arguments)} failed: {command.stderr.strip()}")
    return command.stdout.strip()


def tag_target(tag: str) -> str:
    if not TAG_PATTERN.fullmatch(tag):
        raise DraftError("only stable vMAJOR.MINOR.PATCH tags create a Draft Release")
    return git("rev-list", "-n", "1", f"refs/tags/{tag}")


def verify_package_version(tag: str, root: Path = ROOT) -> None:
    with (root / "Project.toml").open("rb") as project_file:
        version = tomllib.load(project_file).get("version")
    if version != tag.removeprefix("v"):
        raise DraftError(f"tag {tag} differs from Project.toml version {version}")


def verify_source_inventory(root: Path = ROOT) -> int:
    checksums = root / "SHA256SUMS"
    manifest = root / "SOURCE_MANIFEST.tsv"
    if not checksums.is_file() or not manifest.is_file():
        raise DraftError("source inventory files are missing")
    expected: dict[str, str] = {}
    for line in checksums.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if not match:
            raise DraftError("malformed SHA256SUMS entry")
        digest, relative = match.groups()
        if relative in expected or not safe_path(relative):
            raise DraftError(f"duplicate or unsafe inventory path: {relative}")
        path = root / relative
        if not path.is_file() or path.is_symlink():
            raise DraftError(f"inventory file missing or linked: {relative}")
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != digest:
            raise DraftError(f"checksum mismatch: {relative}")
        expected[relative] = digest
    rows = manifest.read_text(encoding="utf-8").splitlines()
    if not rows or rows[0] != "type\tbytes\tsha256\tpath":
        raise DraftError("source manifest header is invalid")
    seen: set[str] = set()
    for row in rows[1:]:
        columns = row.split("\t")
        if len(columns) != 4:
            raise DraftError("source manifest row is malformed")
        kind, size, digest, relative = columns
        if kind != "file" or not size.isdecimal() or not DIGEST_PATTERN.fullmatch(digest):
            raise DraftError(f"source manifest row is invalid: {relative}")
        if relative in seen or expected.get(relative) != digest:
            raise DraftError(f"source manifest mismatch: {relative}")
        if (root / relative).stat().st_size != int(size):
            raise DraftError(f"source manifest size mismatch: {relative}")
        seen.add(relative)
    if seen != set(expected):
        raise DraftError("source manifest and checksum inventory differ")
    return len(seen)


def safe_path(relative: str) -> bool:
    path = Path(relative)
    return not path.is_absolute() and bool(path.parts) and ".." not in path.parts


def published_releases(api: GitHubAPI) -> list[dict[str, Any]]:
    releases: list[dict[str, Any]] = []
    for page in range(1, 11):
        batch = api.request("GET", f"/releases?per_page=100&page={page}")
        if not isinstance(batch, list):
            raise DraftError("release inventory is unavailable")
        releases.extend(batch)
        if len(batch) < 100:
            return releases
    raise DraftError("release inventory exceeds the supported page limit")


def previous_release(releases: list[dict[str, Any]], tag: str, target: str) -> str | None:
    if any(item.get("tag_name") == tag for item in releases):
        raise DraftError(f"Release already exists for {tag}; existing Drafts are never overwritten")
    eligible: list[tuple[str, str]] = []
    for item in releases:
        other = item.get("tag_name", "")
        if item.get("draft") or item.get("prerelease") or not TAG_PATTERN.fullmatch(other):
            continue
        other_target = tag_target(other)
        ancestor = subprocess.run(
            ["git", "merge-base", "--is-ancestor", other_target, target],
            cwd=ROOT,
            check=False,
            capture_output=True,
        )
        if ancestor.returncode == 0 and other_target != target:
            eligible.append((item.get("published_at") or "", other))
    return max(eligible)[1] if eligible else None


def commit_evidence(base: str | None, tag: str) -> list[tuple[str, str]]:
    revision = f"{base}..{tag}" if base else tag
    lines = git("log", "--format=%H%x09%s", "--reverse", revision).splitlines()
    commits = [tuple(line.split("\t", 1)) for line in lines if "\t" in line]
    if len(commits) > 200:
        raise DraftError("more than 200 commits require manual release-range review")
    return commits


def associated_prs(api: GitHubAPI, commits: list[tuple[str, str]]) -> list[dict[str, Any]]:
    prs: dict[int, dict[str, Any]] = {}
    for commit, _ in commits:
        matches = api.request("GET", f"/commits/{commit}/pulls?per_page=100")
        if not isinstance(matches, list):
            raise DraftError(f"PR associations unavailable for {commit}")
        for item in matches:
            if not item.get("merged_at"):
                continue
            number = int(item["number"])
            prs[number] = item
    return [prs[number] for number in sorted(prs)]


def changelog_changes(tag: str, text: str) -> list[str]:
    version = tag.removeprefix("v")
    start = re.search(rf"(?m)^## {re.escape(version)}(?:\s|$)", text)
    if start is None:
        return []
    end = re.search(r"(?m)^## ", text[start.end() :])
    section = text[start.end() : start.end() + end.start() if end else len(text)]
    bullets: list[str] = []
    current: list[str] = []
    for line in section.splitlines():
        if line.startswith("- "):
            if current:
                bullets.append(" ".join(current))
            current = [line[2:].strip()]
        elif current and line.strip() and not line.startswith("### "):
            current.append(line.strip())
        elif current and not line.strip():
            bullets.append(" ".join(current))
            current = []
    if current:
        bullets.append(" ".join(current))
    return [bullet for bullet in bullets if not PROHIBITED_BODY.search(bullet)]


def render_body(template: str, tag: str, changes: list[str]) -> str:
    if changes:
        change_text = "\n".join(f"- {change}" for change in changes)
        change_text += "\n- **TODO (developer): Review and condense these changes before publication.**"
    else:
        change_text = "- **TODO (developer): Summarize the reviewed commits and PRs.**"
    replacements = {
        "{{VERSION}}": tag,
        "{{POSITIONING}}": "**TODO (developer): Write one sentence positioning this version.**",
        "{{CHANGES}}": change_text,
        "{{COMPATIBILITY}}": (
            "- **TODO (developer): Confirm API, inputs, output formats, reader compatibility, "
            "migration needs, and scientific limitations.**"
        ),
    }
    body = template
    for marker, value in replacements.items():
        if body.count(marker) != 1:
            raise DraftError(f"template marker must appear exactly once: {marker}")
        body = body.replace(marker, value)
    if re.search(r"{{[A-Z_]+}}", body):
        raise DraftError("unexpanded template marker")
    if PROHIBITED_BODY.search(body):
        raise DraftError("Release Note contains a forbidden section or checksum label")
    headings = re.findall(r"(?m)^#{2,3} .+$", body)
    if headings != [f"## WannierNLQG {tag}", "### Changes", "### Compatibility"]:
        raise DraftError("Release Note headings do not match the template")
    return body.rstrip() + "\n"


def check_ci_run(api: GitHubAPI, run_id: str, target: str) -> dict[str, Any]:
    if not run_id.isdecimal():
        raise DraftError("exact main CI run ID was not passed by the tag gate")
    run = api.request("GET", f"/actions/runs/{run_id}")
    if not isinstance(run, dict) or any(
        run.get(key) != value
        for key, value in (
            ("head_sha", target),
            ("head_branch", "main"),
            ("event", "push"),
            ("status", "completed"),
            ("conclusion", "success"),
        )
    ):
        raise DraftError("CI run does not match the exact successful main-push target")
    return run


def write_summary(lines: list[str]) -> None:
    destination = os.environ.get("GITHUB_STEP_SUMMARY")
    if destination:
        with open(destination, "a", encoding="utf-8") as summary:
            summary.write("\n".join(lines) + "\n")


def prepare(api: GitHubAPI, tag: str, target: str, ci_run_id: str) -> tuple[str, list[str]]:
    if tag_target(tag) != target:
        raise DraftError("tag target differs from the workflow commit")
    verify_package_version(tag)
    ci_run = check_ci_run(api, ci_run_id, target)
    releases = published_releases(api)
    base = previous_release(releases, tag, target)
    inventory_count = verify_source_inventory()
    commits = commit_evidence(base, tag)
    prs = associated_prs(api, commits)
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    changes = changelog_changes(tag, changelog)
    body = render_body((ROOT / ".github/RELEASE_NOTE_TEMPLATE.md").read_text(), tag, changes)
    compare = (
        f"https://github.com/{api.repository}/compare/{base}...{tag}"
        if base
        else f"https://github.com/{api.repository}/tree/{tag}"
    )
    summary = [
        "## Release draft preparation",
        f"- Tag: `{tag}` at `{target}`",
        f"- Previous published ancestor: `{base or 'none; initial release'}`",
        f"- Exact successful main CI: {ci_run.get('html_url', '')}",
        f"- Source inventory: {inventory_count} files verified against committed checksums and manifest",
        "- Uploaded release assets: none at Draft creation; review any assets added later",
        f"- [Compare or inspect source]({compare})",
        f"- Changelog entry: {'found' if changes else 'missing or without eligible change bullets'}",
        f"- Associated PRs: {len(prs)}",
    ]
    summary += [f"  - [#{pr['number']}: {pr.get('title', '')}]({pr['html_url']})" for pr in prs]
    summary += ["- Commit subjects:"] + [f"  - `{sha[:12]}` {subject}" for sha, subject in commits]
    return body, summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--ci-run-id", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    api = GitHubAPI(os.environ.get("GITHUB_TOKEN", ""), args.repository)
    body, summary = prepare(api, args.tag, args.sha, args.ci_run_id)
    if args.dry_run:
        print(body)
        summary.append("- Dry run: no Release created")
    else:
        result = api.request(
            "POST",
            "/releases",
            {
                "tag_name": args.tag,
                "target_commitish": args.sha,
                "name": f"WannierNLQG {args.tag}",
                "body": body,
                "draft": True,
                "prerelease": False,
                "generate_release_notes": False,
            },
        )
        if not isinstance(result, dict) or not result.get("draft"):
            raise DraftError("GitHub did not confirm Draft Release creation")
        summary.append(f"- Draft created: {result.get('html_url', '')}")
        print(f"DRAFT_RELEASE_CREATED {result.get('html_url', '')}")
    write_summary(summary)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (DraftError, OSError, ValueError, urllib.error.URLError) as error:
        write_summary(["## Release draft preparation failed", f"- {error}"])
        print(f"DRAFT_RELEASE_FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
