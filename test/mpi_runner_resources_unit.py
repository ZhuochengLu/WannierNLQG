"""Small synthetic identity/resource-parser checks; no MPI or science run."""
from pathlib import Path
import importlib.util
import json
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("mpi_runner_resources", ROOT / ".github/scripts/mpi_runner_resources.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class ResourceObservationTests(unittest.TestCase):
    def stat(self, rss="7"):
        fields = ["R", "9"] + ["0"] * 20
        fields[19], fields[20], fields[21] = "123", "4096", rss
        return "17 (julia worker) " + " ".join(fields)

    def test_stat_identity_and_units(self):
        self.assertEqual(M.parse_stat(self.stat()), dict(pid=17, comm="julia worker", ppid=9,
                         start_ticks=123, rss_kib=28))

    def test_page_size_is_explicit(self):
        self.assertEqual(M.parse_stat(self.stat(), 16384)["rss_kib"], 112)

    def test_invalid_stat_rejected(self):
        with self.assertRaises(ValueError):
            M.parse_stat("invalid")
        with self.assertRaises(ValueError):
            M.parse_stat(self.stat("-1"))

    def test_only_descendants_included(self):
        records = {10: dict(pid=10, ppid=1, start_ticks=50),
                   11: dict(pid=11, ppid=10, start_ticks=51),
                   12: dict(pid=12, ppid=11, start_ticks=52),
                   13: dict(pid=13, ppid=1, start_ticks=53)}
        self.assertEqual([row["pid"] for row in M.descendants(records, 10, 50)], [10, 11, 12])

    def test_owner_reuse_or_disappearance_stops_observation(self):
        records = {10: dict(pid=10, ppid=1, start_ticks=99)}
        self.assertEqual(M.descendants(records, 10, 50), [])
        self.assertEqual(M.descendants({}, 10, 50), [])

    def test_counter_reads_are_bounded_and_failure_is_explicit(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / "counter"
            p.write_text("max\n")
            self.assertEqual(M.text_counter(p), dict(value="max", error=None))
            p.write_text("x" * 4097)
            self.assertEqual(M.text_counter(p), dict(value=None, error="ValueError"))
            self.assertEqual(M.text_counter(Path(directory) / "missing")["error"], "FileNotFoundError")

    def test_meminfo_is_allowlisted(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / "meminfo"
            p.write_text("MemTotal: 1000 kB\nMemAvailable: 700 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\nOther: 99 kB\n")
            self.assertEqual(M.meminfo(p), dict(MemTotal=1000, MemAvailable=700, SwapTotal=0, SwapFree=0))

    def test_background_owner_and_foreground_exit_are_preserved(self):
        shell = shutil.which("bash")
        self.assertIsNotNone(shell)
        code = "import json,os,sys;print(json.dumps(dict(owner=int(sys.argv[1]),parent=os.getppid())))"
        for expected_exit in (0, 7):
            with self.subTest(expected_exit=expected_exit):
                script = ("mpi_observer_owner_pid=$$\n" + shlex.quote(sys.executable) +
                          " -B -c " + shlex.quote(code) + ' "$mpi_observer_owner_pid" &\n' +
                          "sleep 1\nexit " + str(expected_exit) + "\n")
                result = subprocess.run([shell, "-c", script], capture_output=True,
                                        text=True, timeout=5)
                self.assertEqual(result.returncode, expected_exit)
                identity = json.loads(result.stdout)
                self.assertEqual(identity["owner"], identity["parent"])


if __name__ == "__main__":
    unittest.main()
