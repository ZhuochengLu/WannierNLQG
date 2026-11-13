#!/usr/bin/env python3
"""Export one exact internal revision into a fresh, history-free public source tree."""
import sys
sys.dont_write_bytecode = True
import argparse
import ast
import csv
import hashlib
import importlib.util
import json
import posixpath
import re
import subprocess
from urllib.parse import unquote
from pathlib import Path

GENERATED = {'SOURCE_MANIFEST.tsv', 'SHA256SUMS', 'PUBLIC_FEATURES.md'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def files(root):
    """Inventory payload bytes only; reject links, caches and credentials rather than following them."""
    result = {}
    for path in sorted(root.rglob('*')):
        name = path.relative_to(root).as_posix()
        if name.split('/')[0] == '.git':
            continue
        if path.is_symlink():
            raise ValueError('source symlink: ' + name)
        if path.is_file() and name not in GENERATED:
            if '__pycache__' in path.parts or path.suffix in ('.pyc', '.pyo'):
                raise ValueError('source cache: ' + name)
            result[name] = path.read_bytes()
    return result


def classify(payload, policy):
    """Private membership wins; every other path needs an explicit public owner."""
    if policy['schema'] != 'wanniernlqg.source-distribution/1':
        raise ValueError('unsupported classification schema')
    public, private = set(), set()
    for feature in policy['features'].values():
        if type(feature['public']) is not bool:
            raise ValueError('public classification must be a Boolean')
        (public if feature['public'] else private).update(feature['paths'])
    for name, feature in policy['features'].items():
        if feature['public']:
            for dependency in feature.get('dependencies', []):
                target = policy['features'].get(dependency)
                if target is not None and not target['public']:
                    raise ValueError(f'public feature {name} depends on private feature {dependency}')
    for name in public | private:
        path = Path(name)
        if path.is_absolute() or '..' in path.parts or name != path.as_posix():
            raise ValueError('classification path invalid: ' + name)
    unknown = set(payload) - public - private
    missing = (public | private) - set(payload)
    if unknown or missing:
        raise ValueError(f'unclassified={sorted(unknown)} missing={sorted(missing)}')
    return public - private, private


def project(payload, policy):
    """Apply reviewed exact attachment edits; ambiguous or changed boundaries stop export."""
    allowed, denied = classify(payload, policy)
    if 'scripts/source_distribution.json' not in allowed:
        raise ValueError('distribution authority must remain explicitly public')
    result = {name: payload[name] for name in sorted(allowed)}
    forbidden = []
    for feature in policy['features'].values():
        if feature['public']:
            continue
        forbidden.extend(feature.get('forbidden_public_symbols', []))
        for name, edits in feature.get('projections', {}).items():
            if name not in result:
                continue
            content = result[name].decode()
            for edit in edits:
                if content.count(edit['internal']) != 1:
                    raise ValueError('private attachment drift: ' + name)
                content = content.replace(edit['internal'], edit['public'], 1)
            result[name] = content.encode()
    # This authority describes its own private feature rules; the public copy
    # contains only derived public classifications, never private fragments.
    public_policy = dict(policy)
    public_policy.update(variant='public', features={name: dict(feature)
        for name, feature in policy['features'].items() if feature['public']})
    for feature in public_policy['features'].values():
        feature['paths'] = sorted(set(feature['paths']) - denied)
    result['scripts/source_distribution.json'] = (json.dumps(public_policy, indent=2) + '\n').encode()
    audit_fixture_manifests(result)
    audit_closure(result, denied, forbidden)
    return result, denied


def audit_fixture_manifests(payload):
    """Bind the distributable fixture bytes after all private attachments are removed."""
    prefix = 'test/fixtures/first_use_portable/'
    manifest_name = prefix + 'manifest.json'
    if manifest_name not in payload:
        return
    manifest = json.loads(payload[manifest_name])
    seen = set()
    for item in manifest['files']:
        name = item['file']
        path = Path(name)
        if path.is_absolute() or '..' in path.parts or name in seen:
            raise ValueError('invalid projected fixture member: ' + name)
        seen.add(name)
        data = payload.get(prefix + name)
        if data is None or len(data) != item['bytes'] or sha(data) != item['sha256']:
            raise ValueError('projected fixture binding mismatch: ' + name)


def audit_closure(payload, denied, forbidden):
    """Reject retained private symbols and literal package references across all text surfaces."""
    private_modules = {Path(name).stem for name in denied if name.endswith('.py')}
    public_modules = {Path(name).stem for name in payload if name.endswith('.py')}
    for name, data in payload.items():
        if name == 'scripts/source_distribution.json':
            continue
        try:
            text = data.decode('utf-8')
        except UnicodeDecodeError:
            continue
        if name.endswith('.py'):
            try:
                tree = ast.parse(text, filename=name)
            except SyntaxError as exc:
                raise ValueError('invalid public Python source: ' + name) from exc
            for node in ast.walk(tree):
                modules = ([alias.name for alias in node.names] if isinstance(node, ast.Import)
                           else [node.module] if isinstance(node, ast.ImportFrom) and node.module
                           else [])
                if (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                        and node.func.attr == 'import_module' and node.args
                        and isinstance(node.args[0], ast.Constant)
                        and isinstance(node.args[0].value, str)):
                    modules.append(node.args[0].value)
                for module in modules:
                    leaf = module.rsplit('.', 1)[-1]
                    local_path = module.replace('.', '/') + '.py'
                    if (local_path in denied and local_path not in payload or
                            leaf in private_modules and leaf not in public_modules):
                        raise ValueError('public import of private Python module ' + module + ': ' + name)
        if name.endswith('.md'):
            for target in re.findall(r'\[[^\]]*\]\(([^)\s]+)\)', text):
                target = target.strip('<>')
                if re.match(r'^[A-Za-z][A-Za-z0-9+.-]*:', target):
                    continue
                relative = unquote(target.split('#', 1)[0].split('?', 1)[0])
                resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), relative))
                if relative and resolved in denied:
                    raise ValueError('public document links to denied file ' + resolved + ': ' + name)
        for symbol in forbidden:
            if re.search(r'\b' + re.escape(symbol) + r'\b', text):
                raise ValueError(f'public dependency on private symbol {symbol}: {name}')
        quoted = re.findall(r'[\"\']([^\"\'\n]+)[\"\']', text)
        # An exact retained package path is not a reference to a private file
        # with the same basename (for example docs/DEVELOPMENT.md).
        unresolved_leaves = {Path(value).name for value in quoted if value not in payload and
                             posixpath.normpath(posixpath.join(posixpath.dirname(name), value)) not in payload}
        for path in denied:
            # Check full package paths and unique leaf references. Tiny generic
            # basenames (README.md) are not private dependency identities.
            leaf = Path(path).name
            if path in text or (leaf not in ('README.md',) and len(leaf) > 12 and
                               Path(leaf).suffix in ('.jl', '.py', '.md') and
                               leaf in unresolved_leaves):
                raise ValueError(f'public dependency on denied file {path}: {name}')
        if name.endswith('.jl'):
            direct = re.findall(r'\binclude\(\s*"([^"\n]+)"\s*\)', text)
            joined = re.findall(r'\binclude\(\s*joinpath\(\s*@__DIR__\s*,\s*((?:"[^"\n]+"\s*,?\s*)+)\)\s*\)', text)
            direct += [posixpath.join(*re.findall(r'"([^"\n]+)"', args)) for args in joined]
            for reference in direct:
                target = posixpath.normpath(posixpath.join(posixpath.dirname(name), reference))
                if target not in payload:
                    raise ValueError(f'unresolved public include {reference}: {name}')


def verify_commit_payload(root, commit):
    """Bind every payload byte, including ignored files and generated manifests, to HEAD blobs."""
    records = subprocess.check_output(['git', '-C', str(root), 'ls-tree', '-r', '-z', commit])
    expected = {}
    for record in records.split(b'\0'):
        if not record:
            continue
        metadata, name = record.split(b'\t', 1)
        mode, kind, digest = metadata.split()
        if kind != b'blob' or mode not in (b'100644', b'100755'):
            raise ValueError('unsupported Git payload entry')
        expected[name.decode()] = digest.decode()
    actual = files(root)
    for name in GENERATED:
        if (root / name).is_file():
            actual[name] = (root / name).read_bytes()
    if set(expected) != set(actual):
        raise ValueError('internal commit payload inventory differs from working bytes')
    for name, data in actual.items():
        digest = hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest()
        if digest != expected[name]:
            raise ValueError('internal commit payload bytes changed: ' + name)


def write_manifests(root):
    """Use the existing release inventory format and exact SHA256SUMS ordering."""
    payload = files(root)
    rows = ['type\tbytes\tsha256\tpath\n']
    sums = []
    # Human list is generated from the same classification and included in the
    # actual source digest, even though it is not a hand-maintained policy input.
    if (root / 'PUBLIC_FEATURES.md').is_file():
        payload['PUBLIC_FEATURES.md'] = (root / 'PUBLIC_FEATURES.md').read_bytes()
    for name, data in sorted(payload.items()):
        rows.append(f'file\t{len(data)}\t{sha(data)}\t{name}\n')
        sums.append(f'{sha(data)}  {name}\n')
    (root / 'SOURCE_MANIFEST.tsv').write_text(''.join(rows))
    (root / 'SHA256SUMS').write_text(''.join(sums))


def human_list(policy):
    lines = ['# Public source features\n', '\nDerived from scripts/source_distribution.json.\n']
    for name, feature in policy['features'].items():
        if feature['public']:
            lines += [f'\n## {name}\n\n{feature["purpose"]}\n',
                      '\nDependencies: ' + ', '.join(feature['dependencies']) + '.\n']
    return ''.join(lines)


def export(root, output):
    """Require a committed, verified input and a new destination; never publish or overwrite."""
    if output.exists() or root == output or root in output.parents:
        raise ValueError('fresh destination outside package required')
    status = subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain'], text=True)
    if status:
        raise ValueError('internal commit has uncommitted files')
    commit = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
    verify_commit_payload(root, commit)
    spec = importlib.util.spec_from_file_location('release_inventory', root / 'scripts/test_support/release_inventory.py')
    inventory = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(inventory)
    original = inventory.verify_release(root)
    policy = json.loads((root / 'scripts/source_distribution.json').read_text())
    projected, denied = project(files(root), policy)
    output.mkdir(parents=True)
    for name, data in projected.items():
        path = output / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    (output / 'PUBLIC_FEATURES.md').write_text(human_list(policy))
    write_manifests(output)
    delivered = inventory.verify_release(output)
    return dict(schema='wanniernlqg.public-source-export/1', internal_commit=commit,
        input_identity=original, classification_sha256=sha((root / 'scripts/source_distribution.json').read_bytes()),
        public_identity=delivered, output=str(output), denied_files=len(denied),
        public_version=policy['software_version'], git_history_exported=False, publication=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path)
    parser.add_argument('--audit', action='store_true')
    args = parser.parse_args()
    root = args.source.resolve()
    try:
        if args.audit:
            policy = json.loads((root / 'scripts/source_distribution.json').read_text())
            projected, denied = project(files(root), policy)
            print(json.dumps(dict(state='STATIC_DISTRIBUTION_PASS', public_files=len(projected), denied_files=len(denied))))
        elif args.output:
            print(json.dumps(export(root, args.output.resolve()), indent=2))
        else:
            parser.error('--audit or --output required')
    except (ValueError, KeyError, subprocess.CalledProcessError) as exc:
        print(json.dumps(dict(state='REJECTED', error=str(exc))), file=sys.stderr)
        raise SystemExit(2)
