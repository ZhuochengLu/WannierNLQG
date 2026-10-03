"""Bounded provenance shards with exact canonical byte reconstruction."""
import argparse
import hashlib
import json
from pathlib import Path

MAX_PART_BYTES = 4 * 1024**2

def validate_origins(rows, metadata):
    if metadata['schema_version'] == 1:
        if any(len(row) != 11 for row in rows):
            raise ValueError('PROVENANCE_COLUMN_SCHEMA_MISMATCH')
        return
    if metadata['schema_version'] != 2 or any(len(row) != 13 for row in rows):
        raise ValueError('PROVENANCE_COLUMN_SCHEMA_MISMATCH')
    allowed = set(metadata['raw_origin_source_sha256'])
    actual = {source for row in rows for source in row[11].split(',')}
    if actual != allowed or any(len(value) != 64 or any(c not in '0123456789abcdef' for c in value) for value in actual):
        raise ValueError('PROVENANCE_RAW_ORIGIN_IDENTITY_MISMATCH')
    certificate = metadata['source_equivalence_certificate_sha256']
    if any(row[12] != certificate for row in rows):
        raise ValueError('PROVENANCE_EQUIVALENCE_CERTIFICATE_MISMATCH')
    if actual - {metadata['source_src_ext_sha256']} and len(certificate) != 64:
        raise ValueError('PROVENANCE_EQUIVALENCE_CERTIFICATE_REQUIRED')
SCHEMA = 'wanniernlqg.first-use-provenance-shards'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def safe_file(root, name):
    path = Path(name)
    if path.is_absolute() or any(p in ('.', '..') for p in path.parts) or len(path.parts) != 1:
        raise ValueError('PROVENANCE_INVALID_PART_PATH')
    target = root / path
    if target.is_symlink():
        raise ValueError('PROVENANCE_SYMLINK_FORBIDDEN')
    return target


def reconstruct(directory):
    root = Path(directory)
    if root.is_symlink():
        raise ValueError('PROVENANCE_SYMLINK_FORBIDDEN')
    metadata = json.loads(safe_file(root, 'index.json').read_text())
    if metadata['schema'] != SCHEMA or metadata['schema_version'] not in (1, 2):
        raise ValueError('PROVENANCE_SCHEMA_MISMATCH')
    if not metadata['parts'] or len({p['file'] for p in metadata['parts']}) != len(metadata['parts']):
        raise ValueError('PROVENANCE_DUPLICATE_OR_MISSING_PART')
    header = None
    bodies = []
    total_rows = 0
    for record in metadata['parts']:
        data = safe_file(root, record['file']).read_bytes()
        if len(data) != record['bytes'] or len(data) > MAX_PART_BYTES or digest(data) != record['sha256']:
            raise ValueError('PROVENANCE_PART_IDENTITY_MISMATCH')
        lines = data.splitlines(keepends=True)
        if not lines or not lines[-1].endswith(b'\n'):
            raise ValueError('PROVENANCE_PART_INCOMPLETE')
        if header is None:
            header = lines[0]
        if lines[0] != header or len(lines) - 1 != record['rows']:
            raise ValueError('PROVENANCE_HEADER_OR_ROW_COUNT_MISMATCH')
        bodies.extend(lines[1:])
        total_rows += record['rows']
    canonical = header + b''.join(bodies)
    if total_rows != metadata['retained_rows'] or len(canonical) != metadata['canonical_bytes'] or digest(canonical) != metadata['canonical_sha256']:
        raise ValueError('PROVENANCE_CANONICAL_IDENTITY_MISMATCH')
    rows = [line.decode().rstrip('\n').split('\t') for line in bodies]
    validate_origins(rows, metadata)
    if any(not row[4] for row in rows):
        raise ValueError('PROVENANCE_UNOWNED_OR_INVALID_ROW')
    if len({(r[0], r[1]) for r in rows}) != len(rows):
        raise ValueError('PROVENANCE_DUPLICATE_DECLARATION')
    if any(r[8] != metadata['source_src_ext_sha256'] or r[9] != metadata['julia'] or r[10] != metadata['manifest_sha256'] for r in rows):
        raise ValueError('PROVENANCE_SOURCE_IDENTITY_MISMATCH')
    return canonical, metadata


def write_shards(canonical, destination):
    lines = canonical.splitlines(keepends=True)
    if not lines or any(not line.endswith(b'\n') for line in lines):
        raise ValueError('PROVENANCE_INCOMPLETE_CANONICAL_INPUT')
    rows = [line.decode().rstrip('\n').split('\t') for line in lines[1:]]
    if not rows or len({len(r) for r in rows}) != 1 or len(rows[0]) not in (11, 13) or any(not r[4] for r in rows):
        raise ValueError('PROVENANCE_UNOWNED_OR_INVALID_ROW')
    identities = {(r[8], r[9], r[10]) for r in rows}
    if len(identities) != 1:
        raise ValueError('PROVENANCE_MIXED_SOURCE_IDENTITIES')
    source, julia, manifest = identities.pop()
    root = Path(destination)
    root.mkdir(parents=True, exist_ok=False)
    header = lines[0]
    chunks = []
    current = [header]
    size = len(header)
    for line in lines[1:]:
        if len(header) + len(line) > MAX_PART_BYTES:
            raise ValueError('PROVENANCE_ROW_OVERSIZED')
        if size + len(line) > MAX_PART_BYTES:
            chunks.append(b''.join(current))
            current = [header]
            size = len(header)
        current.append(line)
        size += len(line)
    chunks.append(b''.join(current))
    parts = []
    for number, data in enumerate(chunks, 1):
        name = f'part-{number:03}.tsv'
        (root / name).write_bytes(data)
        parts.append(dict(file=name, sha256=digest(data), bytes=len(data), rows=len(data.splitlines())-1))
    metadata = dict(schema=SCHEMA, schema_version=1 if len(rows[0]) == 11 else 2, source_src_ext_sha256=source, julia=julia,
                    manifest_sha256=manifest, canonical_sha256=digest(canonical), canonical_bytes=len(canonical),
                    retained_rows=len(rows), unowned=0, parts=parts, exact_reconstruction=True,
                    independent_audit_check_pending=True, final_pass=False)
    if metadata['schema_version'] == 2:
        certificates = {r[12] for r in rows}
        if len(certificates) != 1:
            raise ValueError('PROVENANCE_MIXED_EQUIVALENCE_CERTIFICATES')
        metadata.update(raw_origin_source_sha256=sorted({source for row in rows for source in row[11].split(',')}),
                        source_equivalence_certificate_sha256=certificates.pop())
        validate_origins(rows, metadata)
    (root / 'index.json').write_text(json.dumps(metadata, indent=2) + '\n')
    restored, _ = reconstruct(root)
    if restored != canonical:
        raise ValueError('PROVENANCE_RECONSTRUCTION_MISMATCH')
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='mode', required=True)
    check = sub.add_parser('check')
    check.add_argument('directory', type=Path)
    check.add_argument('--canonical', type=Path)
    pack = sub.add_parser('write')
    pack.add_argument('canonical', type=Path)
    pack.add_argument('destination', type=Path)
    unpack = sub.add_parser('restore')
    unpack.add_argument('directory', type=Path)
    unpack.add_argument('output', type=Path)
    args = parser.parse_args()
    if args.mode == 'write':
        metadata = write_shards(args.canonical.read_bytes(), args.destination)
    else:
        canonical, metadata = reconstruct(args.directory)
        if args.mode == 'check' and args.canonical and args.canonical.read_bytes() != canonical:
            raise ValueError('PROVENANCE_INDEPENDENT_CANONICAL_MISMATCH')
        if args.mode == 'restore':
            with args.output.open('xb') as stream:
                stream.write(canonical)
    print(json.dumps(dict(retained_rows=metadata['retained_rows'], canonical_sha256=metadata['canonical_sha256'], source_src_ext_sha256=metadata['source_src_ext_sha256'])))


if __name__ == '__main__':
    main()
