"""Verify exact release inventory and its producer tree digest without importing Julia."""
import csv
import hashlib
from pathlib import Path


def verify_release(root):
    root=Path(root).resolve();manifest=root/'SOURCE_MANIFEST.tsv';entries=list(csv.DictReader(manifest.open(),delimiter='\t'))
    paths=[x['path'] for x in entries]
    expected_sums=''.join(row['sha256']+'  '+row['path']+'\n' for row in entries)
    if (root/'SHA256SUMS').read_text()!=expected_sums:raise ValueError('RELEASE_SHA256SUMS_CHANGED')
    if paths!=sorted(set(paths)) or any(x['type']!='file' for x in entries):raise ValueError('RELEASE_MANIFEST_ORDER_OR_TYPE_CHANGED')
    actual=[]
    for path in root.rglob('*'):
        relative=path.relative_to(root)
        if relative.parts[0]=='.git':continue
        if path.is_symlink():raise ValueError('RELEASE_SYMLINK')
        if '__pycache__' in relative.parts or path.suffix in ('.pyc','.pyo'):raise ValueError('RELEASE_BYTECODE_ARTIFACT')
        if path.is_file() and str(relative) not in ('SOURCE_MANIFEST.tsv','SHA256SUMS'):actual.append(relative.as_posix())
    if sorted(actual)!=paths:raise ValueError('RELEASE_MANIFEST_INVENTORY_CHANGED')
    digest=hashlib.sha256()
    for row in entries:
        relative=Path(row['path'])
        if relative.is_absolute() or any(x in ('','..','.') for x in relative.parts):raise ValueError('RELEASE_MANIFEST_PATH_INVALID')
        path=root/relative;data=path.read_bytes()
        if len(data)!=int(row['bytes']) or hashlib.sha256(data).hexdigest()!=row['sha256']:raise ValueError('RELEASE_MANIFEST_FILE_CHANGED: '+row['path'])
        digest.update(row['path'].encode());digest.update(b'\0');digest.update(data)
    return dict(release_tree_sha256=digest.hexdigest(),files=len(entries),source_manifest_sha256=hashlib.sha256(manifest.read_bytes()).hexdigest())
