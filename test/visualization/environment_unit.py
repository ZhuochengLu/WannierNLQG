"""Negative tests for explicit publication dependencies; no style fallbacks."""
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from visualization.common import VisualizationError
from visualization.style import check_environment, resolve_style


class PublicationEnvironmentTests(unittest.TestCase):
    def test_missing_python_dependency_is_an_error(self):
        result = subprocess.run(
            [sys.executable, "-S", str(ROOT / "scripts/visualization/check_environment.py")],
            capture_output=True, text=True, check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Publication environment preflight failed", result.stderr)

    def test_missing_required_font_is_an_error(self):
        with patch("visualization.style.fm.findfont", side_effect=ValueError("missing")):
            with self.assertRaisesRegex(VisualizationError, "required font is unavailable"):
                check_environment(resolve_style())

    def test_missing_latex_is_an_error(self):
        with patch("visualization.style.fm.findfont", return_value="Times New Roman.ttf"):
            with patch("visualization.style.shutil.which", return_value=None):
                with self.assertRaisesRegex(VisualizationError, "requires pdflatex"):
                    check_environment(resolve_style())

    def test_missing_tex_package_is_an_error(self):
        missing = subprocess.CompletedProcess([], 1, "", "not found")
        with patch("visualization.style.fm.findfont", return_value="Times New Roman.ttf"):
            with patch("visualization.style.shutil.which", return_value="tool"):
                with patch("visualization.style.subprocess.run", return_value=missing):
                    with self.assertRaisesRegex(VisualizationError, "required LaTeX package is unavailable"):
                        check_environment(resolve_style())


if __name__ == "__main__":
    unittest.main()
