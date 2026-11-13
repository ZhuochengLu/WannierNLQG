"""Tiny classic-PDF byte fixtures; no plotting dependencies or scientific claims."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import tempfile
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "scripts/visualization/pdf_validation.py"
spec = importlib.util.spec_from_file_location("pdf_stream_validator", VALIDATOR)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


def fixture(payload, *, encoded=True, indirect=False, declared=None, separator=b"\n",
            filter_name=b"FlateDecode", length_body=None, trailer=b""):
    length = len(payload) if declared is None else declared
    token = b"5 0 R" if indirect else str(length).encode()
    body = b"<< /Length " + token
    if encoded:
        body += b" /Filter /" + filter_name
    body += b" >>\nstream\n" + payload + separator + b"endstream"
    objects = [b"<< /Type /Catalog /Pages 2 0 R >>",
               b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
               b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] /Resources << >> /Contents 4 0 R >>",
               body]
    if indirect:
        objects.append(str(length).encode() if length_body is None else length_body)
    data = bytearray(b"%PDF-1.4\n")
    offsets = []
    for number, content in enumerate(objects, 1):
        offsets.append(len(data))
        data.extend(str(number).encode() + b" 0 obj\n" + content + b"\nendobj\n")
    xref = len(data)
    data.extend(b"xref\n0 " + str(len(objects) + 1).encode() + b"\n0000000000 65535 f \n")
    for offset in offsets:
        data.extend(f"{offset:010d} 00000 n \n".encode())
    data.extend(b"trailer\n<< /Root 1 0 R /Size " + str(len(objects) + 1).encode() +
                b" " + trailer + b" >>\nstartxref\n" + str(xref).encode() + b"\n%%EOF\n")
    return bytes(data), offsets


class StreamTests(unittest.TestCase):
    def parse(self, data):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "stream.pdf"
            path.write_bytes(data)
            return validator._objects(path)

    def test_encoded_final_cr_is_data_not_separator(self):
        encoded = zlib.compress(b"\x0c")
        self.assertEqual(encoded[-1:], b"\r")
        self.assertEqual(self.parse(fixture(encoded)[0])[4][1], b"\x0c")

    def test_indirect_encoded_length(self):
        self.assertEqual(self.parse(fixture(zlib.compress(b"BT ET"), indirect=True)[0])[4][1], b"BT ET")

    def test_plain_final_cr_and_both_separators(self):
        for separator in (b"\n", b"\r\n"):
            with self.subTest(separator=separator):
                self.assertEqual(self.parse(fixture(b"BT ET\r", encoded=False, separator=separator)[0])[4][1], b"BT ET\r")

    def test_binary_pdf_tokens_do_not_define_object_boundaries(self):
        decoded = b"endobj\n17 0 obj\nstream\nendstream\n/Type /ObjStm"
        encoded = zlib.compress(decoded, level=0)
        objects = self.parse(fixture(encoded)[0])
        self.assertEqual(set(objects), {1, 2, 3, 4})
        self.assertEqual(objects[4][1], decoded)

    def test_wrong_short_long_missing_or_negative_length_rejected(self):
        encoded = zlib.compress(b"BT ET")
        for length in (len(encoded) - 1, len(encoded) + 1, -1):
            with self.subTest(length=length), self.assertRaises(validator.PDFValidationError):
                self.parse(fixture(encoded, declared=length)[0])
        data = fixture(encoded)[0].replace(b"/Length", b"/Lengtx")
        with self.assertRaises(validator.PDFValidationError):
            self.parse(data)

    def test_noninteger_or_missing_indirect_length_rejected(self):
        for value in (b"true", b"<< /Length 5 >>"):
            with self.subTest(value=value), self.assertRaises(validator.PDFValidationError):
                self.parse(fixture(zlib.compress(b"BT ET"), indirect=True, length_body=value)[0])
        data = fixture(zlib.compress(b"BT ET"), indirect=True)[0].replace(b"/Length 5 0 R", b"/Length 9 0 R")
        with self.assertRaises(validator.PDFValidationError):
            self.parse(data)

    def test_corrupt_compressed_bytes_still_rejected(self):
        encoded = bytearray(zlib.compress(b"BT ET"))
        encoded[-1] ^= 1
        with self.assertRaisesRegex(validator.PDFValidationError, "cannot decode"):
            self.parse(fixture(bytes(encoded))[0])

    def test_unknown_filter_rejected(self):
        with self.assertRaisesRegex(validator.PDFValidationError, "unsupported PDF stream filter"):
            self.parse(fixture(b"BT ET", filter_name=b"LZWDecode")[0])

    def test_declared_filter_not_overridden_by_another_dictionary_key(self):
        with self.assertRaisesRegex(validator.PDFValidationError, "unsupported PDF stream filter"):
            self.parse(fixture(zlib.compress(b"BT ET"), filter_name=b"LZWDecode /Other /FlateDecode")[0])

    def test_trailing_encoded_bytes_rejected(self):
        with self.assertRaisesRegex(validator.PDFValidationError, "cannot decode"):
            self.parse(fixture(zlib.compress(b"BT ET") + b"\n")[0])

    def test_mismatched_xref_object_offset_rejected(self):
        data, offsets = fixture(zlib.compress(b"BT ET"))
        data = data.replace(f"{offsets[3]:010d} 00000 n".encode(),
                            f"{offsets[3] + 1:010d} 00000 n".encode())
        with self.assertRaises(validator.PDFValidationError):
            self.parse(data)

    def test_incremental_encrypted_and_hybrid_files_rejected(self):
        for entry in (b"/Prev 1", b"/Encrypt 1 0 R", b"/XRefStm 1"):
            with self.subTest(entry=entry), self.assertRaises(validator.PDFValidationError):
                self.parse(fixture(zlib.compress(b"BT ET"), trailer=entry)[0])

    def test_missing_xref_and_nonzero_generation_rejected(self):
        data = fixture(zlib.compress(b"BT ET"))[0]
        for broken in (data.replace(b"startxref", b"startxxxx"),
                       data.replace(b"00000 n", b"00001 n", 1)):
            with self.subTest(), self.assertRaises(validator.PDFValidationError):
                self.parse(broken)


def run_tests(output=None):
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(StreamTests))
    record = {"scope": "PDF_PARSER_TOOLING_ONLY_NOT_SCIENCE", "status": "PASS" if result.wasSuccessful() else "FAIL",
              "tests": result.testsRun, "failures": len(result.failures), "errors": len(result.errors),
              "validator_sha256": hashlib.sha256(VALIDATOR.read_bytes()).hexdigest(),
              "test_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    if output is not None:
        Path(output).mkdir(parents=True, exist_ok=True)
        (Path(output) / "pdf-stream-result.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record))
    return result.wasSuccessful()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    raise SystemExit(0 if run_tests(parser.parse_args().output) else 1)
