#!/usr/bin/env python3
"""Exercise scheduler contracts using executable fake Julia processes."""

import contextlib
import importlib.util
import io
import json
import os
import re
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "run_tests.py"
SPEC = importlib.util.spec_from_file_location("test_scheduler", SCRIPT)
runner = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = runner
SPEC.loader.exec_module(runner)

FAKE = r'''#!/usr/bin/env python3
import json, os, pathlib, signal, subprocess, sys, time
task = os.environ['WANNIERNLQG_TEST_TASK_ID']
directory = pathlib.Path(os.environ['TMPDIR']).parent
(directory / 'environment.json').write_text(json.dumps(dict(os.environ)))
(directory / 'started').write_text(str(time.monotonic()))
if os.environ.get('FAKE_INTERRUPT'):
    signal.signal(signal.SIGTERM, lambda *_: (directory / 'parent.stubborn').write_text('ignoring term'))
    child_code = "import os, signal, time, pathlib; signal.signal(signal.SIGTERM, lambda *_: (pathlib.Path(" + repr(str(directory / 'child.stopped')) + ").write_text('stopped'), os._exit(0))); pathlib.Path(" + repr(str(directory / 'child.ready')) + ").write_text('ready'); time.sleep(60)"
    child = subprocess.Popen([sys.executable, '-c', child_code])
    (directory / 'child.pid').write_text(str(child.pid))
    time.sleep(60)
time.sleep(0.15)
(directory / 'ended').write_text(str(time.monotonic()))
mode = os.environ['WANNIERNLQG_TEST_MODE']
shard = os.environ.get('WANNIERNLQG_TEST_SHARD', 'none')
if os.environ.get('FAKE_MISSING') != task:
    print(f'[test-suite:complete] mode={mode} shard={shard} elapsed_s=0.15')
if os.environ.get('FAKE_WRAPPER_MISSING') != task:
    print('WANNIERNLQG_TEST_TASK_COMPLETE:' + task)
sys.exit(7 if os.environ.get('FAKE_FAIL') == task else 0)
'''


class SchedulerTests(unittest.TestCase):
    """Bound concurrency, preserve coverage, and reject incomplete outcomes."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary.name).resolve()
        self.julia = self.directory / "fake-julia"
        self.julia.write_text(FAKE)
        self.julia.chmod(0o755)
        self.output = self.directory / "results"

    def tearDown(self):
        self.temporary.cleanup()

    def execute(self, tasks=None, budget=17, jobs=2):
        return runner.run_suite(tasks or runner.suite_tasks("full"), str(self.julia), self.output, jobs, budget)

    def test_inventory_matches_julia_contract_and_output_is_external(self):
        contract = (SCRIPT.parents[1] / "test" / "CITestPlan.jl").read_text()
        section = contract.split("const FULL_TEST_SHARDS =", 1)[1].split("const FULL_VISUALIZATION_SHARD", 1)[0]
        names = tuple(value for value in re.findall(r'"([^"\n]+)"', section) if not value.endswith(".jl"))
        self.assertEqual(runner.SHARDS, names)
        self.assertEqual([task.mode for task in runner.suite_tasks("full")], ["fast"] + ["full-shard"] * len(names) + ["mpi-only"])
        with self.assertRaises(ValueError):
            runner.run_suite(runner.suite_tasks("fast"), str(self.julia), runner.ROOT / "forbidden-output", 2, 8)

    def test_coverage_isolation_and_mpi_exclusivity(self):
        result = self.execute()
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(len(result["tasks"]), 7)
        self.assertEqual(len({row["task"] for row in result["tasks"]}), 7)
        intervals = {}
        for row in result["tasks"]:
            directory = self.output / row["task"]
            env = json.loads((directory / "environment.json").read_text())
            self.assertEqual(env["TMPDIR"], str(directory / "tmp"))
            self.assertEqual(env["WANNIERNLQG_TEST_OUTPUT_ROOT"], str(directory / "output"))
            self.assertEqual(env["OPENBLAS_NUM_THREADS"], "1")
            self.assertEqual(env["JULIA_NUM_PRECOMPILE_TASKS"], "1")
            self.assertEqual(env["WANNIERNLQG_READINESS_JOBS"], "2" if row["task"] == "fast" else "1")
            self.assertNotIn("WANNIERNLQG_USE_MPI", env)
            self.assertTrue(row["completion_marker"])
            self.assertEqual(len(row["log_sha256"]), 64)
            self.assertGreater(row["peak_rss_bytes"], 0)
            self.assertGreaterEqual(row["finished_offset_seconds"], row["started_offset_seconds"])
            intervals[row["task"]] = tuple(float((directory / name).read_text()) for name in ("started", "ended"))
        mpi_start, _ = intervals.pop("mpi-only")
        self.assertTrue(all(end <= mpi_start for _, end in intervals.values()))

    def test_serial_fallback_budgets_one_readiness_child(self):
        result = self.execute(runner.suite_tasks("fast"), budget=2, jobs=1)
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["tasks"][0]["cpu_slots"], 2)
        env = json.loads((self.output / "fast" / "environment.json").read_text())
        self.assertEqual(env["WANNIERNLQG_READINESS_JOBS"], "1")
        self.assertEqual(runner.task_cpu_slots(runner.Task("fast", "fast"), 2), 3)
        with self.assertRaises(ValueError):
            runner.run_suite(runner.suite_tasks("fast"), str(self.julia), self.directory / "insufficient", 2, 2)

    def test_budget_allows_small_jobs_but_serializes_large_jobs(self):
        tasks = [runner.Task(name, "full-shard", name) for name in ("thread-determinism", "star-gauge-thread", "wannier-core")]
        result = self.execute(tasks, budget=8, jobs=3)
        self.assertEqual(result["status"], "PASS")
        events = []
        for task in tasks:
            directory = self.output / task.name
            start, end = (float((directory / name).read_text()) for name in ("started", "ended"))
            events.extend([(start, runner.TASK_CPU_SLOTS[task.name]), (end, -runner.TASK_CPU_SLOTS[task.name])])
        used, peak = 0, 0
        for _, delta in sorted(events):
            used += delta
            peak = max(peak, used)
            self.assertLessEqual(used, 8)
        self.assertEqual(peak, 7)

    def test_failure_and_missing_receipts_are_not_pass(self):
        with patch.dict(os.environ, {"FAKE_FAIL": "fast", "FAKE_MISSING": "wannier-core", "FAKE_WRAPPER_MISSING": "scientific-contracts"}):
            result = self.execute()
        rows = {row["task"]: row for row in result["tasks"]}
        self.assertEqual(result["status"], "FAIL")
        self.assertEqual(rows["fast"]["exit_code"], 7)
        self.assertEqual(rows["wannier-core"]["status"], "FAIL")
        self.assertEqual(rows["scientific-contracts"]["status"], "FAIL")
        self.assertEqual(rows["mpi-only"]["status"], "PASS")

    def test_missing_executable_and_duplicate_inventory(self):
        result = runner.run_suite(runner.suite_tasks("fast"), str(self.directory / "absent"), self.output, 2, 8)
        self.assertEqual(result["tasks"][0]["status"], "INVALID_ENVIRONMENT")
        with self.assertRaises(ValueError):
            runner.run_suite([runner.Task("fast", "fast")] * 2, str(self.julia), self.directory / "duplicate", 2, 8)

    def test_nested_execution_and_insufficient_budget_fail_before_launch(self):
        with patch.dict(os.environ, {runner.NESTED_ENV: "1"}), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                runner.main(["fast", "--dry-run"])
        with self.assertRaises(ValueError):
            self.execute(budget=8)
        self.assertFalse(self.output.exists())

    def test_interrupt_stops_process_group_and_retains_receipt(self):
        env = dict(os.environ, FAKE_INTERRUPT="1")
        env.pop(runner.NESTED_ENV, None)
        process = subprocess.Popen([sys.executable, str(SCRIPT), "fast", "--jobs", "1", "--cpu-budget", "2", "--julia", str(self.julia), "--output-dir", str(self.output)], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            child_path = self.output / "fast" / "child.pid"
            deadline = time.monotonic() + 10
            while not (self.output / "fast" / "child.ready").exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(child_path.exists())
            process.send_signal(signal.SIGTERM)
            deadline = time.monotonic() + 2
            while not (self.output / "fast" / "parent.stubborn").exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue((self.output / "fast" / "parent.stubborn").exists())
            process.send_signal(signal.SIGINT)
            time.sleep(0.05)
            process.send_signal(signal.SIGTERM)
            process.communicate(timeout=10)
            self.assertEqual(process.returncode, 130)
            result = json.loads((self.output / "summary.json").read_text())
            self.assertEqual(result["status"], "INTERRUPTED")
            self.assertEqual(result["tasks"][0]["status"], "INTERRUPTED")
            self.assertTrue((self.output / "fast" / "child.stopped").exists())
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()


if __name__ == "__main__":
    unittest.main()
