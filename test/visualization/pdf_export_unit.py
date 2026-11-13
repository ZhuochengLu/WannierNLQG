"""Portable publication-export regressions with locally generated fixtures.

Missing TeX/renderer dependencies fail by default. Explicit standalone skips are
recorded as SKIP_DEPENDENCY_UNAVAILABLE and never count as a test PASS.
"""
from pathlib import Path
import argparse
import importlib.metadata
import json
import shutil
import subprocess
import sys
import unittest
from unittest.mock import patch
import zlib

ROOT = Path(__file__).resolve().parents[2]


def dependency_paths():
    paths = {name: shutil.which(name) for name in
             ("latex", "pdflatex", "dvipng", "kpsewhich", "pdftoppm")}
    paths["ghostscript"] = shutil.which("gs-noX11") or shutil.which("gs")
    missing = [name for name, value in paths.items() if value is None]
    if missing:
        return paths, missing
    font = subprocess.run([paths["kpsewhich"], "txsys.pfb"], capture_output=True,
                          text=True, check=False)
    value = font.stdout.strip()
    if font.returncode or not value or not Path(value).is_file():
        missing.append("newtx txsys.pfb")
    else:
        paths["txsys.pfb"] = str(Path(value).resolve())
    return paths, missing


def raster_fixture(path):
    """Minimum Flate RGB image-only PDF, independent of material data."""
    pixels = zlib.compress(bytes([240, 240, 240] * 4))
    content = b"q 64 0 0 64 0 0 cm /Im0 Do Q\n"
    objects = [b"<< /Type /Catalog /Pages 2 0 R >>",
               b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
               b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 64 64] "
               b"/Resources << /XObject << /Im0 5 0 R >> >> /Contents 4 0 R >>",
               b"<< /Length " + str(len(content)).encode() + b" >>\nstream\n" + content + b"endstream",
               b"<< /Type /XObject /Subtype /Image /Width 2 /Height 2 "
               b"/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode "
               b"/Length " + str(len(pixels)).encode() + b" >>\nstream\n" + pixels + b"\nendstream"]
    data = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for number, body in enumerate(objects, 1):
        offsets.append(len(data))
        data.extend(str(number).encode() + b" 0 obj\n" + body + b"\nendobj\n")
    xref = len(data)
    data.extend(b"xref\n0 6\n0000000000 65535 f \n")
    for offset in offsets[1:]:
        data.extend(f"{offset:010d} 00000 n \n".encode())
    data.extend(f"trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode())
    path.write_bytes(data)


def run_tests(output, paths):
    sys.path.insert(0, str(ROOT / "scripts"))
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib._type1font import Type1Font
    from visualization.style import apply_style, resolve_style
    from visualization.common import save_figure_atomic, VisualizationError
    from visualization.pdf_validation import (validate_native_pdf,
        PDFValidationError, verify_dependency_lock, execution_identity)

    lock = verify_dependency_lock()
    apply_style(resolve_style({"figsize": [3.2, 2.4], "dpi": 180}))
    fig = plt.figure(figsize=(3.2, 2.4))
    ax = fig.add_axes([.22, .22, .65, .55])
    ax.plot([-1, 1], [-1, 1])
    ax.axhline(0, linestyle="--")  # Regression for graphics-array tokenization.
    ax.set_xlabel(r"$k\;[\mathrm{\AA^{-1}}]$")
    ax.set_ylabel(r"$10^{-3}\;E-E_{\mathrm{VBM}}$")
    fig.text(.84, .9, r"$-$", fontsize=18, ha="center", va="center")
    good = output / "generated-good.pdf"
    bad = output / "generated-missing-code-zero.pdf"
    raster = output / "generated-image-only.pdf"
    try:
        save_figure_atomic(fig, good.with_suffix(""), 180, ["pdf", "png"])
        original_subset = Type1Font.subset

        def omit_code_zero(font, characters, *args, **kwargs):
            # Test-only fault injection. No library or installed font is changed.
            return original_subset(font, {c for c in characters if c != 0}, *args, **kwargs)

        with patch.object(Type1Font, "subset", omit_code_zero):
            fig.savefig(bad, format="pdf", dpi=180)
    finally:
        plt.close(fig)
    raster_fixture(raster)

    class ExportTests(unittest.TestCase):
        def test_code_zero_subset_retains_math_minus_and_notdef(self):
            font = Type1Font(paths["txsys.pfb"])
            subset = font.subset([0, 185, 186], "TESTXX+")
            self.assertEqual(font.prop["Encoding"][0], "minus")
            self.assertEqual(subset.prop["Encoding"][0], "minus")
            self.assertTrue({"minus", ".notdef"} <= set(subset.prop["CharStrings"]))

        def test_missing_used_code_zero_is_rejected(self):
            with self.assertRaisesRegex(PDFValidationError, "code 0"):
                validate_native_pdf(bad)

        def test_whole_page_raster_cannot_pass_as_native_vector(self):
            with self.assertRaisesRegex(PDFValidationError, "whole-page image"):
                validate_native_pdf(raster)

        def test_bad_glyph_preserves_previous_primary_and_proof(self):
            dest = output / "retained-primary"
            dest.with_suffix(".pdf").write_bytes(good.read_bytes())
            proof = dest.with_suffix(".pdf.qa.json")
            proof.write_text("previous proof")
            original = dest.with_suffix(".pdf").read_bytes()

            class BadFigure:
                def savefig(self, path, **kwargs):
                    Path(path).write_bytes(bad.read_bytes())

            with self.assertRaisesRegex(VisualizationError, "primary unchanged"):
                save_figure_atomic(BadFigure(), dest, 180, ["pdf"])
            self.assertEqual(original, dest.with_suffix(".pdf").read_bytes())
            self.assertEqual(proof.read_text(), "previous proof")
            failures = list((output / "diagnostics/retained-primary").rglob("retained-primary.pdf"))
            self.assertEqual(len(failures), 1)
            self.assertEqual(failures[0].read_bytes(), bad.read_bytes())

        def test_generated_native_encoding_matches_actual_glyphs(self):
            report = validate_native_pdf(good)
            self.assertEqual(report["status"], "PASS")
            self.assertTrue(any(row["used_glyphs"].get("0") == "minus"
                                for row in report["type1_fonts"]))

        def test_metadata_and_actual_import_match_dependency_lock(self):
            record = verify_dependency_lock()
            self.assertEqual(record["packages"]["matplotlib"]["version"], "3.11.1")
            self.assertEqual(record["execution"]["matplotlib_version"], "3.11.1")
            actual = Path(record["execution"]["matplotlib_path"]).parent.resolve()
            expected = Path(importlib.metadata.distribution("matplotlib").locate_file("matplotlib")).resolve()
            self.assertEqual(actual, expected)

    result = unittest.TextTestRunner(verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(ExportTests))
    record = {"status": "PASS" if result.wasSuccessful() else "FAIL",
              "tests": result.testsRun, "failures": len(result.failures),
              "errors": len(result.errors), "dependencies": paths,
              "execution": execution_identity(), "dependency_lock": lock,
              "fixture_scope": "generated tiny native TeX PDF; test-only omitted code0; generated image-only PDF",
              "material_or_prior_run_dependencies": False,
              "scientific_qualification": "NOT_EVALUATED"}
    (output / "unit-result.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({"status": record["status"], "tests": result.testsRun,
                      "output": str(output)}))
    return 0 if result.wasSuccessful() else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--allow-missing-tex", action="store_true",
                        help="Standalone only: record SKIP instead of FAIL when required TeX/renderers are absent")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    from pdf_stream_unit import run_tests as run_stream_tests
    if not run_stream_tests(output):
        return 1
    paths, missing = dependency_paths()
    if missing:
        status = "SKIP_DEPENDENCY_UNAVAILABLE" if args.allow_missing_tex else "FAIL_DEPENDENCY_UNAVAILABLE"
        record = {"status": status, "missing": missing, "dependencies": paths,
                  "tests": 0, "python": sys.executable, "scientific_qualification": "NOT_EVALUATED"}
        (output / "unit-result.json").write_text(json.dumps(record, indent=2) + "\n")
        print(json.dumps(record))
        return 0 if args.allow_missing_tex else 1
    return run_tests(output, paths)


if __name__ == "__main__":
    raise SystemExit(main())
