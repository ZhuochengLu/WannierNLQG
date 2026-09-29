"""Offline gates for the human-reviewed Draft Release generator."""

from __future__ import annotations

import hashlib
import importlib.util
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/generate_release_draft.py"
SPEC = importlib.util.spec_from_file_location("generate_release_draft", SCRIPT)
assert SPEC and SPEC.loader
draft = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(draft)


class FakeAPI:
    repository = "example/WannierNLQG"

    def __init__(self, responses):
        self.responses = responses
        self.calls = []

    def request(self, method, path, payload=None):
        self.calls.append((method, path, payload))
        return self.responses[path]


class ReleaseDraftTests(unittest.TestCase):
    def test_initial_release_uses_no_fabricated_predecessor(self):
        self.assertIsNone(draft.previous_release([], "v1.0.0", "a" * 40))
        body = draft.render_body(
            draft.ROOT.joinpath(".github/RELEASE_NOTE_TEMPLATE.md").read_text(),
            "v1.0.0",
            [],
        )
        self.assertEqual(body.count("### Changes"), 1)
        self.assertNotIn("since v", body)
        self.assertNotRegex(body, draft.PROHIBITED_BODY)

    def test_previous_published_ancestor_and_existing_release_protection(self):
        records = [
            {"tag_name": "v1.0.0", "published_at": "2026-09-08", "draft": False, "prerelease": False},
            {"tag_name": "v1.0.1", "published_at": "2026-09-11", "draft": False, "prerelease": False},
            {"tag_name": "v1.0.2", "published_at": None, "draft": True, "prerelease": False},
        ]
        targets = {"v1.0.0": "a" * 40, "v1.0.1": "b" * 40}
        with mock.patch.object(draft, "tag_target", side_effect=targets.__getitem__), mock.patch.object(
            draft.subprocess,
            "run",
            return_value=SimpleNamespace(returncode=0),
        ):
            self.assertEqual(draft.previous_release(records, "v1.1.0", "c" * 40), "v1.0.1")
            with self.assertRaisesRegex(draft.DraftError, "already exists"):
                draft.previous_release(records, "v1.0.2", "c" * 40)
            with self.assertRaisesRegex(draft.DraftError, "already exists"):
                draft.previous_release(records, "v1.0.1", "c" * 40)
        with mock.patch.object(draft, "tag_target", side_effect=draft.DraftError("missing tag")):
            with self.assertRaisesRegex(draft.DraftError, "missing tag"):
                draft.previous_release(records, "v1.1.0", "c" * 40)

    def test_no_prs_remains_an_empty_evidence_list(self):
        api = FakeAPI({"/commits/" + "a" * 40 + "/pulls?per_page=100": []})
        self.assertEqual(draft.associated_prs(api, [("a" * 40, "First change")]), [])

    def test_tag_version_must_match_package_version(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            (root / "Project.toml").write_text('name = "WannierNLQG"\nversion = "1.2.0"\n')
            draft.verify_package_version("v1.2.0", root)
            with self.assertRaisesRegex(draft.DraftError, "differs"):
                draft.verify_package_version("v1.2.1", root)

    def test_exact_ci_is_required(self):
        good = {
            "head_sha": "a" * 40,
            "head_branch": "main",
            "event": "push",
            "status": "completed",
            "conclusion": "success",
        }
        api = FakeAPI({"/actions/runs/101": good})
        self.assertEqual(draft.check_ci_run(api, "101", "a" * 40), good)
        api.responses["/actions/runs/101"] = {**good, "conclusion": "failure"}
        with self.assertRaisesRegex(draft.DraftError, "does not match"):
            draft.check_ci_run(api, "101", "a" * 40)
        with self.assertRaisesRegex(draft.DraftError, "not passed"):
            draft.check_ci_run(api, "", "a" * 40)

    def test_source_checksums_and_manifest_fail_closed(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            (root / "example.txt").write_text("source\n")
            digest = hashlib.sha256(b"source\n").hexdigest()
            (root / "SHA256SUMS").write_text(f"{digest}  example.txt\n")
            (root / "SOURCE_MANIFEST.tsv").write_text(
                f"type\tbytes\tsha256\tpath\nfile\t7\t{digest}\texample.txt\n"
            )
            self.assertEqual(draft.verify_source_inventory(root), 1)
            (root / "example.txt").write_text("changed\n")
            with self.assertRaisesRegex(draft.DraftError, "checksum mismatch"):
                draft.verify_source_inventory(root)
            (root / "SHA256SUMS").unlink()
            with self.assertRaisesRegex(draft.DraftError, "missing"):
                draft.verify_source_inventory(root)

    def test_changelog_fills_changes_without_scientific_or_checksum_claims(self):
        source = (
            "# Changelog\n\n## 1.2.0 — Feature\n\n- Add a method.\n"
            "- Record SHA-256 checks.\n"
            f"- Record checksum {'a' * 64}.\n\n## 1.1.0\n- Earlier work.\n"
        )
        changes = draft.changelog_changes("v1.2.0", source)
        self.assertEqual(changes, ["Add a method."])
        body = draft.render_body(
            draft.ROOT.joinpath(".github/RELEASE_NOTE_TEMPLATE.md").read_text(),
            "v1.2.0",
            changes,
        )
        self.assertIn("- Add a method.", body)
        self.assertNotRegex(body, draft.PROHIBITED_BODY)
        self.assertIn("TODO (developer)", body)


if __name__ == "__main__":
    unittest.main()
