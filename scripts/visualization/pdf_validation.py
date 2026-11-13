"""Validate Matplotlib's native TeX PDF before publishing it.

This intentionally supports the classic-object PDF emitted by this renderer.
Unknown font/content encodings fail with a specific error instead of passing.
No raster substitution, dependency installation, or process guard is implemented.
"""
from __future__ import annotations

import hashlib
import importlib.metadata
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zlib


class PDFValidationError(RuntimeError):
    pass


def file_identity(path):
    path = Path(path).resolve()
    return {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "bytes": path.stat().st_size}


def execution_identity():
    import matplotlib
    return {"python": sys.executable, "python_version": sys.version,
            "matplotlib_version": matplotlib.__version__,
            "matplotlib_path": str(Path(matplotlib.__file__).resolve()),
            "backend_source": file_identity(Path(matplotlib.__file__).parent / "_type1font.py")}


def verify_dependency_lock():
    requirements = Path(__file__).with_name("requirements.txt")
    versions = {}
    for line in requirements.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        name, expected = line.strip().split("==", 1)
        distribution = importlib.metadata.distribution(name)
        actual = distribution.version
        if actual != expected:
            raise PDFValidationError(f"publication dependency {name}={actual}; required {expected}; select the pinned --python interpreter")
        versions[name] = {"version": actual, "metadata_path": str(distribution._path)}
    execution = execution_identity()
    distribution = importlib.metadata.distribution("matplotlib")
    expected_module = Path(distribution.locate_file("matplotlib")).resolve()
    actual_module = Path(execution["matplotlib_path"]).parent.resolve()
    if execution["matplotlib_version"] != versions["matplotlib"]["version"] or actual_module != expected_module:
        raise PDFValidationError("Matplotlib metadata/import identity mismatch; check selected interpreter and PYTHONPATH")
    return {"requirements": file_identity(requirements), "packages": versions,
            "execution": execution_identity()}


def _literal_bytes(token):
    source = token[1:-1]
    result = bytearray()
    index = 0
    escapes = {ord('n'): 10, ord('r'): 13, ord('t'): 9, ord('b'): 8, ord('f'): 12}
    while index < len(source):
        value = source[index]
        index += 1
        if value != 92:
            result.append(value)
            continue
        if index == len(source):
            raise PDFValidationError("incomplete PDF literal escape")
        value = source[index]
        index += 1
        if 48 <= value <= 55:
            digits = bytearray([value])
            while index < len(source) and len(digits) < 3 and 48 <= source[index] <= 55:
                digits.append(source[index]); index += 1
            result.append(int(digits, 8))
        elif value == 13:
            if index < len(source) and source[index] == 10:
                index += 1
        elif value != 10:
            result.append(escapes.get(value, value))
    return bytes(result)


def _classic_object_bodies(data):
    """Use the renderer's classic xref offsets, never tokens in binary streams."""
    end = re.search(rb'startxref\s+(\d+)\s+%%EOF\s*$', data)
    if not data.startswith(b'%PDF-') or end is None:
        raise PDFValidationError("unsupported PDF structure; expected classic Matplotlib objects")
    xref = int(end[1])
    section, separator, trailer = data[xref:end.start()].partition(b'trailer')
    lines = section.splitlines()
    header = re.fullmatch(rb'0 (\d+)', lines[1]) if len(lines) > 1 else None
    if not separator or lines[0:1] != [b'xref'] or header is None:
        raise PDFValidationError("unsupported PDF cross-reference table")
    count = int(header[1])
    if count < 2 or len(lines) != count + 2 or re.search(rb'/(?:Prev|XRefStm|Encrypt)\b', trailer):
        raise PDFValidationError("unsupported PDF cross-reference inventory or trailer")
    offsets = {}
    for number, line in enumerate(lines[2:]):
        entry = re.fullmatch(rb'(\d{10}) (\d{5}) ([nf])\s*', line)
        if entry is None:
            raise PDFValidationError("malformed PDF cross-reference entry")
        offset, generation, state = int(entry[1]), int(entry[2]), entry[3]
        if number == 0 and (state != b'f' or generation != 65535):
            raise PDFValidationError("invalid PDF free-object entry")
        if state == b'n':
            if number == 0 or generation != 0 or not 0 < offset < xref or offset in offsets:
                raise PDFValidationError("unsupported PDF object identity or offset")
            offsets[offset] = number
    positions = sorted(offsets)
    bodies = {}
    for index, offset in enumerate(positions):
        number = offsets[offset]
        limit = positions[index + 1] if index + 1 < len(positions) else xref
        header = re.match(str(number).encode() + rb' 0 obj\s+', data[offset:limit])
        if header is None:
            raise PDFValidationError("PDF object does not match its cross-reference entry")
        body = data[offset + header.end():limit].rstrip()
        if not body.endswith(b'endobj'):
            raise PDFValidationError("PDF object boundary is unresolved")
        bodies[number] = body[:-6].rstrip()
    if not bodies:
        raise PDFValidationError("PDF has no readable objects")
    return bodies


def _objects(path):
    bodies = _classic_object_bodies(Path(path).read_bytes())
    objects = {}
    for number, body in bodies.items():
        stream = re.search(rb'\bstream\r?\n', body)
        dictionary = body if stream is None else body[:stream.start()]
        if re.search(rb'/Type\s*/ObjStm\b', dictionary):
            raise PDFValidationError("unsupported PDF object stream")
        raw = None
        if stream is not None:
            # /Length counts encoded bytes. An optional CR in an endstream regex
            # can consume a valid final compressed byte before an LF separator.
            length = re.search(rb'/Length\s+(?:(\d+)\s+(\d+)\s+R|(\d+))(?=\s|/|>)', dictionary)
            if length is None:
                raise PDFValidationError("PDF stream has no supported Length")
            if length[1] is not None:
                value = bodies.get(int(length[1]))
                if int(length[2]) != 0 or value is None or re.fullmatch(rb'\d+', value.strip()) is None:
                    raise PDFValidationError("PDF stream Length reference is unresolved")
                size = int(value)
            else:
                size = int(length[3])
            boundary = stream.end() + size
            if boundary > len(body) or re.fullmatch(rb'(?:\r\n|\n|\r)?endstream\s*', body[boundary:]) is None:
                raise PDFValidationError("PDF stream Length disagrees with its boundary")
            raw = body[stream.end():boundary]
            filters = re.findall(rb'/Filter\s+(/[-A-Za-z0-9_]+|\[[^\]]*\])', dictionary)
            if b'/Filter' in dictionary and (len(filters) != 1 or
                    not (filters[0] == b'/FlateDecode' or re.fullmatch(rb'\[\s*/FlateDecode\s*\]', filters[0]))):
                raise PDFValidationError("unsupported PDF stream filter")
            if filters:
                try:
                    decoder = zlib.decompressobj()
                    raw = decoder.decompress(raw) + decoder.flush()
                    if not decoder.eof or decoder.unused_data or decoder.unconsumed_tail:
                        raise PDFValidationError(f"cannot decode PDF stream {number!r}: incomplete or trailing encoded bytes")
                except zlib.error as error:
                    raise PDFValidationError(f"cannot decode PDF stream {number!r}") from error
        objects[number] = (dictionary, raw)
    return objects


def validate_native_pdf(path):
    from matplotlib._type1font import Type1Font
    objects = _objects(path)
    aliases = {}
    for dictionary, _ in objects.values():
        for alias, number in re.findall(rb'/(F[-A-Za-z0-9_]*)\s+(\d+) 0 R', dictionary):
            aliases[alias.decode()] = int(number)
    literal = rb'\((?:\\.|[^\\()])*\)'
    tokens = re.compile(rb'/(?P<font>F[-A-Za-z0-9_]*)\s+[-+\d.]+\s+Tf|(?P<single>'+literal+rb')\s*Tj|\[(?P<array>(?:'+literal+rb'|[-+\d.\s])*)\]\s*TJ', re.S)
    usages = {}
    content_ids = set()
    for dictionary, _ in objects.values():
        for number in re.findall(rb'/Contents\s+(\d+) 0 R', dictionary):
            content_ids.add(int(number))
        arrays = re.findall(rb'/Contents\s*\[(.*?)\]', dictionary, re.S)
        for array in arrays:
            content_ids.update(int(number) for number in re.findall(rb'(\d+) 0 R', array))
    if not content_ids:
        raise PDFValidationError("PDF page content is unresolved")
    for number in content_ids:
        dictionary, raw = objects[number]
        if raw is None or b'BT' not in raw or b'/Subtype /Image' in dictionary:
            continue
        active = None
        for match in tokens.finditer(raw):
            if match['font'] is not None:
                active = match['font'].decode()
            else:
                if active is None or active not in aliases:
                    raise PDFValidationError("text references an unresolved PDF font")
                strings = [match['single']] if match['single'] is not None else re.findall(literal, match['array'], re.S)
                for token in strings:
                    usages.setdefault(active, set()).update(_literal_bytes(token))
    if not usages:
        raise PDFValidationError("native vector text required; a whole-page image/empty text PDF cannot pass")
    checked = []
    for alias, codes in usages.items():
        dictionary, _ = objects[aliases[alias]]
        if b'/Subtype /Type1' not in dictionary:
            # Non-TeX TrueType/CID text is outside the Type1 minus contract.
            continue
        descriptor = re.search(rb'/FontDescriptor (\d+) 0 R', dictionary)
        if descriptor is None:
            raise PDFValidationError(f"{alias}: embedded Type1 descriptor is required")
        descriptor_dict, _ = objects[int(descriptor[1])]
        font_file = re.search(rb'/FontFile (\d+) 0 R', descriptor_dict)
        if font_file is None:
            raise PDFValidationError(f"{alias}: embedded Type1 font file is required")
        font_dict, font_data = objects[int(font_file[1])]
        lengths = [int(re.search(fr'/Length{i}\s+(\d+)'.encode(), font_dict)[1]) for i in (1, 2, 3)]
        if font_data is None or sum(lengths) != len(font_data):
            raise PDFValidationError(f"{alias}: inconsistent Type1 font lengths")
        first, second, _ = lengths
        font = Type1Font((font_data[:first], font_data[first:first+second], font_data[first+second:]))
        encoding = font.prop['Encoding']
        glyphs = font.prop['CharStrings']
        differences = re.search(rb'/Differences\s*\[(.*?)\]', dictionary, re.S)
        if differences is None:
            raise PDFValidationError(f"{alias}: explicit Type1 PDF encoding required")
        pdf_encoding = {}
        code = None
        for token in re.findall(rb'\d+|/[A-Za-z0-9_.-]+', differences[1]):
            if token.startswith(b'/'):
                if code is None:
                    raise PDFValidationError(f"{alias}: malformed Encoding differences")
                pdf_encoding[code] = token[1:].decode(); code += 1
            else:
                code = int(token)
        charset_match = re.search(rb'/CharSet\s*('+literal+rb')', descriptor_dict, re.S)
        charset = set(re.findall(rb'/([^/\s]+)', _literal_bytes(charset_match[1]))) if charset_match else set()
        for code in sorted(codes):
            glyph = encoding.get(code)
            if glyph is None or glyph == '.notdef' or glyph not in glyphs:
                raise PDFValidationError(f"{alias}: used Type1 code {code} is missing or .notdef (possible mathematical minus loss)")
            if pdf_encoding.get(code) != glyph or glyph.encode() not in charset:
                raise PDFValidationError(f"{alias}: Encoding/CharSet/CharStrings disagree for code {code}, glyph {glyph}")
        checked.append({"alias": alias, "font_name": font.prop['FontName'],
                        "used_codes": sorted(codes), "used_glyphs": {str(code): encoding[code] for code in sorted(codes)},
                        "encoding0": encoding.get(0), "charset": sorted(value.decode() for value in charset)})
    return {"status": "PASS", "artifact_class": "native_vector", "pdf": file_identity(path),
            "type1_fonts": checked, "text_font_count": len(usages), "execution": execution_identity(),
            "validator": file_identity(__file__), "scope": "Used Type1 glyph Encoding/CharSet/CharStrings, native text structure; pixel checks separate"}


def _record_digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'),
                                     allow_nan=False).encode()).hexdigest()


def _renderer_arguments(name, pdf, preview, dpi):
    if name == 'poppler':
        return ['-r', str(dpi), '-singlefile', '-png', str(pdf), str(preview.with_suffix(''))]
    if name == 'ghostscript':
        return ['-q', '-dSAFER', '-dBATCH', '-dNOPAUSE', '-sDEVICE=png16m',
                f'-r{dpi}', '-dTextAlphaBits=4', '-dGraphicsAlphaBits=4',
                f'-sOutputFile={preview}', str(pdf)]
    raise PDFValidationError(f'unsupported PDF renderer: {name}')


def _renderer_configuration(name, dpi):
    return {'schema': 'wanniernlqg.pdf-readback-config/1', 'renderer': name,
            'dpi': dpi, 'arguments': _renderer_arguments(name, Path('SOURCE_PDF'), Path('PREVIEW.png'), dpi)}


def readback_binding(record):
    """Content binding independent of temporary/published path relocation."""
    return _record_digest({'source_pdf_sha256': record['source_pdf']['sha256'],
        'preview_sha256': record['preview']['sha256'], 'preview_bytes': record['preview']['bytes'],
        'tool_sha256': record['tool']['sha256'], 'tool_version': record['version']['text'],
        'configuration': record['configuration']})


def validate_readback_records(pdf, records, *, published_pdf=None):
    """Check each actual preview and its source/config/tool/version binding."""
    source = file_identity(pdf)
    command_pdf = Path(published_pdf or pdf).resolve()
    if set(records) != {'poppler', 'ghostscript'}:
        raise PDFValidationError('PDF proof requires both named renderer readbacks')
    try:
        for name, record in records.items():
            if record['exit'] != 0 or record['source_pdf']['sha256'] != source['sha256']:
                raise PDFValidationError(f'{name}: PDF source/exit identity mismatch')
            actual_preview = file_identity(record['preview']['path'])
            if any(actual_preview[key] != record['preview'][key] for key in ('sha256', 'bytes')):
                raise PDFValidationError(f'{name}: actual preview identity mismatch')
            actual_tool = file_identity(record['tool']['path'])
            if actual_tool['sha256'] != record['tool']['sha256']:
                raise PDFValidationError(f'{name}: renderer tool identity mismatch')
            version = record['version']
            if version['exit'] != 0 or not version['text'].strip() or Path(version['command'][0]).resolve() != Path(actual_tool['path']):
                raise PDFValidationError(f'{name}: renderer version identity missing')
            dpi = record['configuration']['dpi']
            if not isinstance(dpi, int) or dpi <= 0 or record['configuration'] != _renderer_configuration(name, dpi):
                raise PDFValidationError(f'{name}: renderer configuration mismatch')
            if record['configuration_sha256'] != _record_digest(record['configuration']):
                raise PDFValidationError(f'{name}: renderer configuration digest mismatch')
            if record['binding_sha256'] != readback_binding(record):
                raise PDFValidationError(f'{name}: preview/config/version binding mismatch')
            if Path(record['command'][0]).resolve() != Path(actual_tool['path']) or record['command'][1:] != _renderer_arguments(name, command_pdf, Path(actual_preview['path']), dpi):
                raise PDFValidationError(f'{name}: renderer invocation mismatch')
    except (KeyError, TypeError, OSError) as error:
        raise PDFValidationError(f'incomplete PDF readback identity: {error}') from error
    return {'status': 'PASS', 'scope': 'Actual preview SHA/bytes, PDF source SHA, renderer tool SHA/version and exact configuration/invocation'}


def render_pdf_previews(path, output_directory, dpi=180):
    path = Path(path).resolve()
    directory = Path(output_directory).resolve()
    directory.mkdir(parents=True, exist_ok=True)
    if not isinstance(dpi, int) or dpi <= 0:
        raise PDFValidationError('PDF readback dpi must be a positive integer')
    poppler = shutil.which('pdftoppm')
    ghostscript = shutil.which('gs-noX11') or shutil.which('gs')
    if not poppler or not ghostscript:
        raise PDFValidationError('PDF validation requires pdftoppm and Ghostscript')
    report = {}
    for name, tool, version_args in [('poppler', poppler, ['-v']), ('ghostscript', ghostscript, ['--version'])]:
        version_command = [tool, *version_args]
        version = subprocess.run(version_command, capture_output=True, text=True, check=False)
        (directory/f'{name}.version.stdout.log').write_text(version.stdout)
        (directory/f'{name}.version.stderr.log').write_text(version.stderr)
        version_text = (version.stdout + version.stderr).strip()
        if version.returncode or not version_text:
            raise PDFValidationError(f'{name} version query failed: exit {version.returncode}')
        preview = directory/f'{name}.png'
        command = [tool, *_renderer_arguments(name, path, preview, dpi)]
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        (directory/f'{name}.stdout.log').write_text(result.stdout)
        (directory/f'{name}.stderr.log').write_text(result.stderr)
        if result.returncode:
            raise PDFValidationError(f'{name} PDF readback failed: exit {result.returncode}')
        record = {'command': command, 'exit': result.returncode, 'tool': file_identity(tool),
                  'version': {'command': version_command, 'exit': version.returncode, 'text': version_text},
                  'source_pdf': file_identity(path), 'preview': file_identity(preview),
                  'configuration': _renderer_configuration(name, dpi)}
        record['configuration_sha256'] = _record_digest(record['configuration'])
        record['binding_sha256'] = readback_binding(record)
        report[name] = record
    validate_readback_records(path, report)
    return report


def validate_minus_probe(pdf, reference_png, output_directory, center_fraction, dpi=180):
    """Isolated $-$ ROI, independently rasterized from DVI for the PNG oracle.

    Fixed predeclared ROI excludes adjacent digits; a surviving digit cannot pass.
    The structural check rejects a whole-page raster masquerading as native PDF.
    """
    import numpy as np
    from PIL import Image
    structural = validate_native_pdf(pdf)
    if not any(row['used_glyphs'].get('0') == 'minus' for row in structural['type1_fonts']):
        raise PDFValidationError('minus fixture did not exercise Type1 code 0 minus')
    rendered = render_pdf_previews(pdf, output_directory, dpi)
    def ink_report(path):
        rgb = np.asarray(Image.open(path).convert('RGB'))
        height, width = rgb.shape[:2]
        x, y = center_fraction
        cx, cy = x*width, (1-y)*height
        # 0.25 x 0.18 inches around the isolated glyph; excludes all other text.
        half_w, half_h = 0.125*dpi, 0.09*dpi
        box = (round(cx-half_w), round(cy-half_h), round(cx+half_w), round(cy+half_h))
        tile = rgb[box[1]:box[3], box[0]:box[2]]
        mask = np.any(tile < 230, axis=2)
        ys, xs = np.nonzero(mask)
        if len(xs) < 8:
            raise PDFValidationError(f'{path}: isolated mathematical minus ROI is empty')
        extent = [int(xs.max()-xs.min()+1), int(ys.max()-ys.min()+1)]
        if extent[0] < 2*extent[1]:
            raise PDFValidationError(f'{path}: minus ROI lacks the expected horizontal stroke')
        target = Path(output_directory)/(Path(path).stem+'-minus-roi.png')
        Image.fromarray(tile).save(target)
        return {'box_pixels':box,'ink_pixels':int(mask.sum()),'extent_pixels':extent,'roi':file_identity(target)}
    reference = ink_report(reference_png)
    for name, record in rendered.items():
        record['minus_roi'] = ink_report(record['preview']['path'])
        ratio = record['minus_roi']['ink_pixels']/reference['ink_pixels']
        if not 0.4 <= ratio <= 2.5:
            raise PDFValidationError(f'{name}: minus ROI ink ratio {ratio} outside declared [0.4,2.5]')
        record['minus_roi']['independent_png_ink_ratio'] = ratio
    report = {'status':'PASS','native_pdf':structural,'reference_png':file_identity(reference_png),
              'reference_minus_roi':reference,'renderers':rendered,
              'thresholds':{'minimum_ink_pixels':8,'stroke_width_height_ratio_minimum':2,'ink_ratio_range':[0.4,2.5]},
              'whole_label_ink_acceptance':False,'raster_pdf_substitution':False}
    (Path(output_directory)/'minus-probe.json').write_text(json.dumps(report,indent=2)+'\n')
    return report
