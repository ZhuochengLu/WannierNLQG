"""Stable Julia computation identity, separate from a whole release manifest."""
import hashlib
from pathlib import Path


def source_digest(root):
    root = Path(root)
    digest = hashlib.sha256()
    for parent in ('src', 'ext'):
        paths = sorted((root / parent).rglob('*.jl'))
        for path in paths:
            relative = path.relative_to(root).as_posix()
            digest.update(relative.encode())
            digest.update(b'\0')
            digest.update(path.read_bytes())
    return digest.hexdigest()
