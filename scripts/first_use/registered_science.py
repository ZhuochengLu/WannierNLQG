"""Exact native run(cfg) scientific tables with explicit writer layout rules."""
import hashlib
import math
import json
from pathlib import Path
import struct


TASK_KEYS = (
    'schema', 'quantity', 'method', 'temperature_K', 'fermi_energies_count',
    'fermi_energies_sha256', 'release_tree_sha256', 'model_sha256',
    'input_identity_sha256', 'gamma_intra_ev', 'gamma_inter_ev', 'fs_kind',
    'eta_fs_ev', 'mpi_size', 'julia_threads_per_rank', 'qualification_status',
    'input_semantics', 'operator_inventory', 'target_contract_sha256',
    'authoritative_hamiltonian_sha256', 'band_frame_contract_sha256',
    'operator_selection_sha256',
)


def spectral_source_digest(root):
    """Mirror IO.spectral_response_source_digest, distinct from raw source identity."""
    root = Path(root).resolve()
    paths = sorted(p.relative_to(root).as_posix() for name in ('src', 'ext')
                   for p in (root/name).rglob('*.jl') if p.is_file())
    if not paths: raise ValueError('REGISTERED_SPECTRAL_SOURCE_MISSING')
    stream = ''.join(relative+'\0'+hashlib.sha256((root/relative).read_bytes()).hexdigest()+'\n'
                     for relative in paths).encode()
    return hashlib.sha256(stream).hexdigest()


def metadata_attestation(path, release_tree, spectral_source):
    """Check the official ordered task digest before relocating producer metadata."""
    lines = Path(path).read_text().splitlines()
    fields = {}
    for line in lines:
        key, separator, value = line.partition(' = ')
        if not separator or key in fields: raise ValueError('REGISTERED_METADATA_FIELD_INVALID')
        fields[key] = value
    def string(key):
        value = json.loads(fields[key])
        if not isinstance(value, str): raise ValueError('REGISTERED_METADATA_STRING_INVALID')
        return value
    if spectral_source is None or string('source_sha256') != spectral_source:
        raise ValueError('REGISTERED_SPECTRAL_SOURCE_ATTESTATION_CHANGED')
    task = string('task_sha256')
    common = None
    if task != 'NOT_APPLICABLE':
        common = {key:string(key) for key in TASK_KEYS}
        if common['release_tree_sha256'] != release_tree:
            raise ValueError('REGISTERED_METADATA_PRODUCER_CHANGED')
        computed = hashlib.sha256(''.join(key+'='+common[key]+'\0' for key in TASK_KEYS).encode()).hexdigest()
        if task != computed: raise ValueError('REGISTERED_TASK_DIGEST_ATTESTATION_CHANGED')
    elif string('release_tree_sha256') != 'NOT_APPLICABLE':
        raise ValueError('REGISTERED_METADATA_NOT_APPLICABLE_CHANGED')
    result = []
    for line in lines:
        key = line.partition(' = ')[0]
        if key == 'source_sha256': line = 'source_sha256 = "<attested-source>"'
        elif common is not None and key == 'task_sha256': line = 'task_sha256 = "<attested-task>"'
        elif common is not None and key == 'release_tree_sha256': line = 'release_tree_sha256 = "<attested-producer>"'
        result.append(line)
    return result, common, task


def table(case, path, *, release_tree=None, common=None, task_digest=None):
    path=Path(path); text=path.read_text(); lines=text.splitlines()
    matrix=[[float(v) for v in line.split()] for line in lines if line.strip() and not line.lstrip().startswith('#')]
    if not matrix or len({len(row) for row in matrix})!=1:
        raise ValueError('REGISTERED_NATIVE_TABLE_SHAPE_INVALID')
    if not all(math.isfinite(v) for row in matrix for v in row):
        raise ValueError('REGISTERED_NATIVE_NONFINITE')
    if text.startswith('#### WannierNLQG response tensor'):
        skip=2
        if (len(matrix[0])-2)%2:raise ValueError('REGISTERED_LEGACY_COMPLEX_LAYOUT_CHANGED')
    elif text.startswith('#### WannierNLQG band structure'):
        skip=4
        if case['calculation']!='kpath':raise ValueError('REGISTERED_BAND_LAYOUT_CHANGED')
    elif text.startswith('# SHG '):
        skip=4 if case['calculation']=='kslice' else 1
        if (len(matrix[0])-skip)%2:raise ValueError('REGISTERED_SHG_COMPLEX_LAYOUT_CHANGED')
    elif any(line.startswith('# ') and any(v.endswith('_real') for v in line[2:].split()) for line in lines):
        columns=next(line[2:].split() for line in lines if line.startswith('# ') and any(v.endswith('_real') for v in line[2:].split()))
        skip=next(i for i,v in enumerate(columns) if v.endswith('_real'))
        if skip!=(3 if case['calculation']=='kslice' else 1) or len(columns)!=len(matrix[0]):
            raise ValueError('REGISTERED_VECTOR_LAYOUT_CHANGED')
    elif not text.startswith('#') and case['calculation']=='kslice':
        skip=0
        if len(matrix)!=4 or len(matrix[0])!=4:raise ValueError('REGISTERED_SLICE_LAYOUT_CHANGED')
    else:
        raise ValueError('REGISTERED_UNKNOWN_NATIVE_LAYOUT')
    values=[v for row in matrix for v in row[skip:]]
    if not values:raise ValueError('REGISTERED_NO_SCIENTIFIC_VALUES')
    headers=[]
    actual_headers={}
    for line in lines:
        if not line.startswith('#'):continue
        if line.startswith('# ') and '=' in line[2:]:
            key,value=line[2:].split('=',1)
            if key in actual_headers:raise ValueError('REGISTERED_HEADER_DUPLICATE')
            actual_headers[key]=value
        if line.startswith('# task_sha256='):
            if task_digest is None or line.split('=',1)[1]!=task_digest:raise ValueError('REGISTERED_TABLE_TASK_DIGEST_CHANGED')
            line='# task_sha256=<attested-task>'
        if line.startswith('# release_tree_sha256='):
            observed=line.split('=',1)[1]
            if release_tree is None or observed!=release_tree:raise ValueError('REGISTERED_RELEASE_TREE_ATTESTATION_CHANGED')
            line='# release_tree_sha256=<attested-producer>'
        headers.append(line)
    if 'task_sha256' in actual_headers:
        if common is None or any(actual_headers.get(key)!=common[key] for key in TASK_KEYS):
            raise ValueError('REGISTERED_TABLE_METADATA_COUPLING_CHANGED')
    return dict(shape=[len(matrix),len(matrix[0])],native_float_bits=[struct.pack('>d',v).hex() for row in matrix for v in row],
                science_skip_columns=skip,scientific_value_count=len(values),nonzero_scientific_values=sum(v!=0 for v in values),
                scientific_max_abs=max(abs(v) for v in values),headers=headers)


def outputs(case, receipt, directory, *, release_tree, spectral_source=None, stage="first"):
    directory=Path(directory).resolve(); first=directory/stage; result={}
    attestations={}
    for name in receipt['first_outputs']:
        path=Path(name).resolve()
        if path.suffix=='.txt':
            if first not in path.parents:raise ValueError('REGISTERED_OUTPUT_OUTSIDE_FIRST_DIRECTORY')
            attestations[path.parent]=metadata_attestation(path,release_tree,spectral_source)
    for name in receipt['first_outputs']:
        path=Path(name).resolve()
        if first not in path.parents:raise ValueError('REGISTERED_OUTPUT_OUTSIDE_FIRST_DIRECTORY')
        relative=path.relative_to(first).as_posix()
        if relative in result:raise ValueError('REGISTERED_OUTPUT_DUPLICATE')
        if path.suffix=='.dat':
            attestation=attestations.get(path.parent,(None,None,None))
            result[relative]=table(case,path,release_tree=release_tree,common=attestation[1],task_digest=attestation[2])
        elif path.suffix=='.txt':
            result[relative]=dict(metadata_lines=attestations[path.parent][0])
        elif path.suffix=='.json' and case['calculation']=='kpath' and case['quantity']=='band_structure':
            value=json.loads(path.read_text())
            if value.get('schema')!='wanniernlqg.kpath':raise ValueError('REGISTERED_KPATH_SCHEMA_CHANGED')
            result[relative]=dict(json_science=exact_json(value))
        else:raise ValueError('REGISTERED_OUTPUT_FORMAT_UNDECLARED')
    tables=[x for x in result.values() if 'native_float_bits' in x]
    if not tables:raise ValueError('REGISTERED_NATIVE_OUTPUT_MISSING')
    return result


def exact_json(value):
    if isinstance(value,float):
        if not math.isfinite(value):raise ValueError('REGISTERED_JSON_NONFINITE')
        return {'float64_bits':struct.pack('>d',value).hex()}
    if isinstance(value,dict):return {k:exact_json(v) for k,v in value.items()}
    if isinstance(value,list):return [exact_json(v) for v in value]
    return value


def rank_output_inventory(records, directory):
    """Preserve original root-only writer behavior and every rank's ordered outputs."""
    first=(Path(directory)/'first').resolve()
    result=[]
    for record in records:
        names=[]
        for name in record['first_outputs']:
            path=Path(name).resolve()
            if first not in path.parents:raise ValueError('REGISTERED_RANK_OUTPUT_OUTSIDE_FIRST')
            names.append(path.relative_to(first).as_posix())
        if len(set(names))!=len(names):raise ValueError('REGISTERED_DUPLICATE_RANK_OUTPUT')
        result.append(names)
    return result
