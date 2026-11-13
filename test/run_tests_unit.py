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
# Establish fixture session only after exec/imports have stabilized literal argv.
# Keep this exact fake alive for two bounded sampler intervals before its actual exit.
# This is fixture runtime, never ownership grace, receipt admission or a guard change.
# The explicit C path is already a session leader and retains its original fork->setsid->exec.
if os.getsid(0) != os.getpid():
    os.setsid()
task = os.environ['WANNIERNLQG_TEST_TASK_ID']
directory = pathlib.Path(os.environ['WANNIERNLQG_TEST_OUTPUT_ROOT']).parent
(directory / 'environment.json').write_text(json.dumps(dict(os.environ)))
(directory / 'started').write_text(str(time.monotonic()))
if os.environ.get('FAKE_INTERRUPT'):
    signal.signal(signal.SIGTERM, lambda *_: (directory / 'parent.stubborn').write_text('ignoring term'))
    child_code = "import os, signal, time, pathlib; signal.signal(signal.SIGTERM, lambda *_: (pathlib.Path(" + repr(str(directory / 'child.stopped')) + ").write_text('stopped'), os._exit(0))); pathlib.Path(" + repr(str(directory / 'child.ready')) + ").write_text('ready'); time.sleep(60)"
    child = subprocess.Popen([sys.executable, '-c', child_code])
    (directory / 'child.pid').write_text(str(child.pid))
    time.sleep(60)
time.sleep(2.0)
(directory / 'ended').write_text(str(time.monotonic()))
mode = os.environ['WANNIERNLQG_TEST_MODE']
shard = os.environ.get('WANNIERNLQG_TEST_SHARD', 'none')
if os.environ.get('FAKE_MISSING') != task:
    print(f'[test-suite:complete] mode={mode} shard={shard} elapsed_s=2.0')
if os.environ.get('FAKE_WRAPPER_MISSING') != task:
    print('WANNIERNLQG_TEST_TASK_COMPLETE:' + task)
sys.exit(7 if os.environ.get('FAKE_FAIL') == task else 0)
'''


INTERRUPT_WORKER_ENV = "WANNIERNLQG_CI_INTERRUPT_WORKER"


def interrupt_worker_arguments(raw, argv, environ):
    """Admit only this test's literal private fake fixture, before any launch."""
    directory = Path(raw)
    if argv != [str(Path(__file__).resolve())]:
        raise ValueError("unsupported interrupt worker selector")
    if not directory.is_absolute() or directory.resolve() != directory:
        raise ValueError("interrupt fixture must be an absolute non-symlink directory")
    stat = directory.stat()
    fake, output = directory / "fake-julia", directory / "results"
    if (stat.st_uid != os.getuid() or stat.st_mode & 0o077
            or environ.get("FAKE_INTERRUPT") != "1"
            or not fake.is_file() or fake.is_symlink()
            or fake.read_bytes() != FAKE.encode()
            or output.exists() or output.is_symlink()):
        raise ValueError("interrupt fixture owner/bytes/environment/output mismatch")
    return ["fast", "--jobs", "1", "--cpu-budget", "2", "--julia",
            str(fake), "--output-dir", str(output)]


def fixture_interpreter():
    """Use the installed interpreter binary rather than its macOS launcher."""
    interpreter = Path(sys.executable).resolve()
    app = interpreter.parent.parent / "Resources/Python.app/Contents/MacOS/Python"
    if sys.platform == "darwin" and app.is_file():
        interpreter = app.resolve()
    return str(interpreter)


@contextlib.contextmanager
def literal_fake_launch(fake):
    """Launch the real test fixture through its fixed interpreter, without env."""
    fake = Path(fake)
    if not fake.is_file() or fake.is_symlink() or fake.read_bytes() != FAKE.encode():
        raise ValueError("unregistered fake fixture")
    interpreter = fixture_interpreter()
    commands = {tuple(runner.julia_command(str(fake), task))
                for profile in runner.PROFILES for task in runner.suite_tasks("full", profile)}
    actual_popen = subprocess.Popen
    def launch(command, *arguments, **keywords):
        if isinstance(command, (list, tuple)) and tuple(command) in commands:
            actual = [str(interpreter), *command]
            with (fake.parent / "actual_launch_argv.jsonl").open("a") as log:
                log.write(json.dumps({"logical": command, "actual": actual}) + "\n")
            if keywords.get("start_new_session") is not True:
                raise ValueError("literal fake must own its fixture session")
            # Exact private fake starts its own session after interpreter startup.
            # Production scheduler launch, wait4, signal/killpg and receipts are unchanged.
            keywords["start_new_session"] = False
            return actual_popen(actual, *arguments, **keywords)
        return actual_popen(command, *arguments, **keywords)
    with patch.object(runner.subprocess, "Popen", side_effect=launch):
        yield


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
        with literal_fake_launch(self.julia):
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
            temporary = Path(env["TMPDIR"])
            self.assertTrue(temporary.is_dir())
            self.assertNotIn(" ", str(temporary))
            self.assertEqual(env["WANNIERNLQG_TEST_OUTPUT_ROOT"], str(directory / "output"))
            self.assertEqual(env["OPENBLAS_NUM_THREADS"], "1")
            self.assertEqual(env["JULIA_NUM_PRECOMPILE_TASKS"], "1")
            self.assertEqual(env["JULIA_NUM_GC_THREADS"], "1,0")
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

    def test_bounded11_profile_preserves_inventory_budget_and_exclusivity(self):
        tasks = runner.suite_tasks('full', 'bounded11')
        result = self.execute(tasks, budget=12, jobs=2)
        self.assertEqual(result['status'], 'PASS')
        self.assertEqual(len(result['tasks']), 7)
        self.assertEqual(result['mpi_profile'], 'bounded11')
        self.assertEqual(result['cpu_slots_per_task']['mpi-only'], 12)
        self.assertEqual(result['mpi_untested_scope']['rank_scales'], [16])
        intervals = {}
        for row in result['tasks']:
            self.assertLessEqual(row['cpu_slots'], 12)
            self.assertFalse(row['budget_overcommit'])
            directory = self.output / row['task']
            env = json.loads((directory / 'environment.json').read_text())
            self.assertEqual(env['WANNIERNLQG_TEST_MPI_PROFILE'], 'bounded11')
            intervals[row['task']] = tuple(float((directory / name).read_text())
                                          for name in ('started', 'ended'))
        mpi_start, _ = intervals.pop('mpi-only')
        self.assertTrue(all(end <= mpi_start for _, end in intervals.values()))
        with self.assertRaises(ValueError):
            runner.run_suite(tasks, str(self.julia), self.directory / 'profile-low', 2, 11)
        with self.assertRaises(ValueError):
            runner.run_suite([tasks[0], runner.Task('wannier-core', 'full-shard', 'wannier-core')],
                             str(self.julia), self.directory / 'mixed-profile', 2, 12)
        self.assertEqual(runner.task_cpu_slots(runner.Task('mpi-only', 'mpi-only'), 2), 17)
    def test_failure_and_missing_receipts_are_not_pass(self):
        with patch.dict(os.environ, {"FAKE_FAIL": "fast", "FAKE_MISSING": "wannier-core", "FAKE_WRAPPER_MISSING": "scientific-contracts"}):
            result = self.execute()
        rows = {row["task"]: row for row in result["tasks"]}
        self.assertEqual(result["status"], "FAIL")
        self.assertEqual(rows["fast"]["exit_code"], 7)
        self.assertEqual(rows["wannier-core"]["status"], "FAIL")
        self.assertEqual(rows["scientific-contracts"]["status"], "FAIL")
        self.assertEqual(rows["mpi-only"]["status"], "PASS")

    def test_air3_keeps_seven_tasks_and_accounts_for_every_concurrent_slot(self):
        # These executable fixtures test scheduling only, not scientific PASS.
        tasks = runner.suite_tasks('full', 'air3')
        result = self.execute(tasks, budget=5, jobs=2)
        self.assertEqual(result['status'], 'PASS')
        self.assertEqual(len(result['tasks']), 7)
        self.assertEqual(result['mpi_profile'], 'air3')
        self.assertEqual(result['mpi_rank_plan']['wannierization'], [1, 2, 3])
        self.assertEqual(result['mpi_rank_plan']['adaptive'], [1, 2, 3])
        self.assertEqual(result['cpu_slots_per_task']['mpi-only'], 4)
        self.assertEqual(result['mpi_untested_scope']['rank_scales'], [4, 8, 11, 12, 16])
        intervals, events = {}, []
        for row in result['tasks']:
            self.assertFalse(row['budget_overcommit'])
            self.assertLessEqual(row['cpu_slots'], 5)
            directory = self.output / row['task']
            env = json.loads((directory / 'environment.json').read_text())
            self.assertEqual(env['WANNIERNLQG_TEST_MPI_PROFILE'], 'air3')
            start, end = (float((directory / name).read_text()) for name in ('started', 'ended'))
            intervals[row['task']] = (start, end)
            events.extend([(start, row['cpu_slots']), (end, -row['cpu_slots'])])
        used = 0
        for _, delta in sorted(events):
            used += delta
            self.assertLessEqual(used, 5)
        mpi_start, _ = intervals.pop('mpi-only')
        self.assertTrue(all(end <= mpi_start for _, end in intervals.values()))
        with self.assertRaises(ValueError):
            runner.run_suite(tasks, str(self.julia), self.directory / 'air-full-low', 2, 4)
        with self.assertRaises(ValueError):
            runner.run_suite(runner.suite_tasks('mpi-only', 'air3'), str(self.julia),
                             self.directory / 'air-mpi-low', 2, 3)

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

    def test_interrupt_worker_rejects_unregistered_inputs_before_launch(self):
        argv = [str(Path(__file__).resolve())]
        env = {"FAKE_INTERRUPT": "1"}
        self.assertEqual(interrupt_worker_arguments(str(self.directory), argv, env)[0], "fast")
        for arguments, environment in ((argv + ["foreign"], env), (argv, {}),
                                       (argv, {"FAKE_INTERRUPT": "0"})):
            with self.assertRaises(ValueError):
                interrupt_worker_arguments(str(self.directory), arguments, environment)
        alias = self.directory / "alias"
        alias.symlink_to(self.directory, target_is_directory=True)
        with self.assertRaises(ValueError):
            interrupt_worker_arguments(str(alias), argv, env)
        alias.unlink()
        self.directory.chmod(0o755)
        try:
            with self.assertRaises(ValueError):
                interrupt_worker_arguments(str(self.directory), argv, env)
        finally:
            self.directory.chmod(0o700)
        self.julia.write_text(FAKE + "# altered\n")
        with self.assertRaises(ValueError):
            interrupt_worker_arguments(str(self.directory), argv, env)
        self.julia.write_text(FAKE)
        self.output.mkdir()
        with self.assertRaises(ValueError):
            interrupt_worker_arguments(str(self.directory), argv, env)

    def test_interrupt_stops_process_group_and_retains_receipt(self):
        env = dict(os.environ, FAKE_INTERRUPT="1")
        env[INTERRUPT_WORKER_ENV] = str(self.directory)
        env.pop(runner.NESTED_ENV, None)
        # Re-enter the pinned test driver without changing its selector. The
        # worker calls the same scheduler CLI; its fake child remains provable
        # by the existing exact-driver ownership contract.
        process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()),
                                    *sys.argv[1:]], env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            child_path = self.output / "fast" / "child.pid"
            deadline = time.monotonic() + 10
            while not (self.output / "fast" / "child.ready").exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(child_path.exists())
            self.assertTrue((self.output / "fast" / "child.ready").exists())
            # Keep the private interrupt child live for a bounded observation interval.
            # This is fixture timing, not ownership admission grace or a guard retry.
            time.sleep(2.0)
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


class DevelopmentSelections(unittest.TestCase):
    """Complete items, partial coverage, unchanged failed attempts and fresh recovery."""
    def test_selection_is_explicit_canonical_and_rejects_ambiguous_requests(self):
        self.assertEqual([t.name for t in runner.suite_tasks('full','air3',['wannier-core','fast'])], ['fast','wannier-core'])
        self.assertEqual(len(runner.suite_tasks('full','air3')),7)
        for suite,selection in [('full',[]),('full',['fast','fast']),('full',['unknown']),('fast',['fast']),('mpi-only',['mpi-only'])]:
            with self.subTest(suite=suite,selection=selection), self.assertRaises(ValueError):
                runner.suite_tasks(suite,'air3',selection)

    def test_failed_selection_recovery_uses_new_output_and_retains_failure(self):
        with tempfile.TemporaryDirectory() as raw:
            root=Path(raw).resolve();fake=root/'fake-julia';fake.write_text(FAKE);fake.chmod(0o755)
            def execute(name,fail=False):
                args=['full','--mpi-profile','air3','--task','wannier-core','--jobs','2','--cpu-budget','2','--julia',str(fake),'--output-dir',str(root/name)]
                with patch.dict(os.environ,{'FAKE_FAIL':'wannier-core' if fail else ''}), literal_fake_launch(fake),contextlib.redirect_stdout(io.StringIO()):
                    return runner.main(args)
            self.assertEqual(execute('failed',True),1)
            original=(root/'failed/summary.json').read_bytes()
            self.assertEqual(execute('recovery'),0)
            summary=json.loads((root/'recovery/summary.json').read_text())
            self.assertEqual(summary['selected_tasks'],['wannier-core'])
            self.assertEqual(summary['coverage_scope'],'PARTIAL_ENGINEERING_COVERAGE')
            self.assertEqual((root/'failed/summary.json').read_bytes(),original)
            with contextlib.redirect_stderr(io.StringIO()),self.assertRaises(SystemExit):execute('failed')


class ActualSchedulerResult(unittest.TextTestResult):
    """Record actual unittest invocations, separately from declared inventory."""
    def startTest(self, test):
        if not hasattr(self, 'actual_test_names'):
            self.actual_test_names = []
        self.actual_test_names.append(test._testMethodName)
        super().startTest(test)


def write_actual_scheduler_result(result):
    """Write only this task's requested private result; never package output."""
    names = sorted(unittest.defaultTestLoader.getTestCaseNames(SchedulerTests))
    actual = getattr(result, 'actual_test_names', [])
    value = dict(schema='wanniernlqg.ci-scheduler-actual-result/1',
                 declared_names=names, actual_names=actual, testsRun=result.testsRun,
                 failures=[test._testMethodName for test, _ in result.failures],
                 errors=[test._testMethodName for test, _ in result.errors],
                 skipped=[test._testMethodName for test, _ in result.skipped],
                 unexpected_successes=[test._testMethodName for test in result.unexpectedSuccesses],
                 expected_failures=[test._testMethodName for test, _ in result.expectedFailures],
                 successful=result.wasSuccessful())
    target = os.environ.get('WANNIERNLQG_CI_OWNERSHIP_OUTPUT')
    if target:
        directory = Path(target)
        if not directory.is_absolute() or directory.resolve() != directory or not directory.is_dir():
            raise ValueError('scheduler result requires an existing exact private output directory')
        (directory / 'scheduler_actual_result.json').write_text(json.dumps(value, indent=2) + '\n')
    return value


if __name__ == "__main__":
    worker = os.environ.pop(INTERRUPT_WORKER_ENV, None)
    if worker is not None:
        arguments = interrupt_worker_arguments(worker, sys.argv, os.environ)
        with literal_fake_launch(Path(worker) / "fake-julia"):
            raise SystemExit(runner.main(arguments))
    # Ordinary Julia tests execute the complete public scheduler class.
    program = unittest.main(defaultTest="SchedulerTests",
                            testRunner=unittest.TextTestRunner(resultclass=ActualSchedulerResult),
                            exit=False)
    if len(sys.argv) == 1:
        write_actual_scheduler_result(program.result)
    raise SystemExit(0 if program.result.wasSuccessful() else 1)
