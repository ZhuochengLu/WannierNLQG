"""Verify or rehydrate an immutable first-use fixture bundle at any location.

This regenerates the declared transport payload, not scientific solver inputs.
New scientific inputs require a new source capture and qualification.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def checked_path(root, value):
    relative = Path(value)
    if relative.is_absolute() or not relative.parts or any(x in ('.', '..') for x in relative.parts):
        raise ValueError('FIXTURE_PATH_ESCAPE')
    current = Path(root)
    if current.is_symlink():
        raise ValueError('FIXTURE_SYMLINK_FORBIDDEN')
    for part in relative.parts:
        current /= part
        if current.is_symlink():
            raise ValueError('FIXTURE_SYMLINK_FORBIDDEN')
    return current


def verify(root):
    root = Path(root)
    manifest = json.loads(checked_path(root, 'manifest.json').read_text())
    if manifest['schema'] != 'wanniernlqg.first-use-fixture-payload' or manifest['schema_version'] != '1':
        raise ValueError('FIXTURE_SCHEMA_MISMATCH')
    files = manifest['files']
    if len({x['file'] for x in files}) != len(files):
        raise ValueError('FIXTURE_DUPLICATE_FILE')
    for row in files:
        path = checked_path(root, row['file'])
        data = path.read_bytes()
        if len(data) != row['bytes'] or hashlib.sha256(data).hexdigest() != row['sha256']:
            raise ValueError('FIXTURE_FILE_IDENTITY_MISMATCH')
    observed = {str(p.relative_to(root)) for p in root.rglob('*') if p.is_file() and p.name != 'manifest.json'}
    if observed != {x['file'] for x in files}:
        raise ValueError('FIXTURE_UNDECLARED_OR_MISSING_FILE')
    declared = {x['file']: x for x in files}
    for row in manifest['arguments']:
        if row['file'] not in declared or declared[row['file']]['sha256'] != row['sha256']:
            raise ValueError('FIXTURE_ARGUMENT_IDENTITY_MISMATCH')
    for row in manifest['paths'].values():
        if row['role'] not in ('input', 'output'):
            raise ValueError('FIXTURE_ROLE_INVALID')
        path = checked_path(root, row['relative'])
        if row['role'] == 'input' and not path.exists():
            raise ValueError('FIXTURE_INPUT_MISSING')
    for row in manifest['expert_entries']:
        if row['fixture'] not in declared:
            raise ValueError('FIXTURE_ENTRY_NOT_DECLARED')
    return manifest


def rehydrate(source, destination):
    source = Path(source)
    destination = Path(destination)
    manifest = verify(source)
    destination.mkdir(parents=True, exist_ok=False)
    for row in manifest['files']:
        target = checked_path(destination, row['file'])
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(checked_path(source, row['file']), target)
    shutil.copy2(source / 'manifest.json', destination / 'manifest.json')
    if verify(destination) != manifest:
        raise ValueError('FIXTURE_REHYDRATION_MISMATCH')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('check', 'restore'))
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path, nargs='?')
    args = parser.parse_args()
    if args.mode == 'restore':
        if args.destination is None:
            parser.error('restore requires a fresh destination')
        manifest = rehydrate(args.source, args.destination)
    else:
        manifest = verify(args.source)
    print(json.dumps(dict(files=len(manifest['files']), arguments=len(manifest['arguments']), expert_entries=len(manifest['expert_entries']), scientific_regeneration=False)))


if __name__ == '__main__':
    main()
