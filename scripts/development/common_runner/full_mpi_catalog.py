#!/usr/bin/env python3
"""Build the explicit Full MPI argv catalogue; no scientific job or global preference edit."""
import argparse,json,sys,subprocess
from pathlib import Path
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE if (HERE/'runner.py').exists() else HERE/'core'))
import runner,mpi_ownership
CONTEXT_FILES = ('parent-context.json', 'sandbox-context.json', 'ranks/rank_0.json', 'ranks/rank_1.json')
CONTEXT_KEYS = ('binary', 'abi', 'launcher', 'launcher_sha256', 'library', 'library_sha256', 'preferences',
                'hdf5', 'hdf5_sha256', 'hdf5_hl', 'hdf5_hl_sha256', 'hdf5_version',
                'hdf5_parallel', 'hdf5_preferences', 'loaded_mpi_libraries', 'loaded_hdf5_libraries')


def coherent_hdf5(record):
    """Reject mixed objects and compare symbol addresses only within each process."""
    if record['hdf5_parallel'] is not True or record['opal_prefix'] is not None:
        raise ValueError('parallel coherent HDF5 without runtime prefix required')
    if record['loaded_mpi_libraries'] != [record['library']] or set(record['loaded_hdf5_libraries']) != {record['hdf5'], record['hdf5_hl']}:
        raise ValueError('mixed or missing MPI/HDF5 objects')
    symbols = record['mpi_symbols']
    names = {'MPI_Init', 'MPI_Comm_rank', 'MPI_File_open'}
    if set(symbols) != {'mpi', 'hdf5', 'hdf5_hl'} or any(set(handle) != names for handle in symbols.values()):
        raise ValueError('MPI symbol handles incomplete')
    for handle in symbols.values():
        for name, symbol in handle.items():
            if set(symbol) != {'path', 'address'} or symbol['path'] != record['library'] or not str(symbol['address']).isdigit() or int(symbol['address']) == 0 or symbol['address'] != symbols['mpi'][name]['address']:
                raise ValueError('HDF5 MPI symbol binding mismatch')


def hdf5_inputs(context):
    """Inspect HDF5 separately without relaxing the MPI core's link closure."""
    hdf = context['hdf5']; hl = context['hdf5_hl']
    result = subprocess.run(['/usr/bin/otool', '-L', hl], capture_output=True, text=True)
    if result.returncode:
        raise ValueError('HDF5 high-level dependency inspection failed')
    seeds = {hdf}
    for line in result.stdout.splitlines()[1:]:
        reference = line.strip().split(' (', 1)[0]
        if reference.startswith(('/usr/lib/', '/System/Library/')):
            continue
        if reference.startswith('@rpath/'):
            sibling = Path(hl).parent / reference.removeprefix('@rpath/')
            if not sibling.is_file() or str(sibling.resolve()) != hdf:
                raise ValueError('unproved HDF5 high-level rpath binding')
            continue
        if not Path(reference).is_absolute():
            raise ValueError('unsupported HDF5 dependency install name')
        path = str(Path(reference).resolve(strict=True))
        if path != hl:
            seeds.add(path)
    closure = seeds | mpi_ownership.runtime_closure(seeds) | {hl}
    return {path: runner.digest(path) for path in closure}


def matched_contexts(contexts):
    """Require agreement of measured root, actual Pkg.test sandbox and both ranks."""
    if set(contexts) != set(CONTEXT_FILES):
        raise ValueError('four measured MPI contexts required')
    context = contexts[CONTEXT_FILES[0]]
    if context['binary'] != 'system' or context['abi'] != 'OpenMPI':
        raise ValueError('local ownership requires measured system OpenMPI')
    for record in contexts.values():
        if any(record[key] != context[key] for key in CONTEXT_KEYS):
            raise ValueError('MPI context mismatch')
        if record['launcher_argv'] != [context['launcher']]:
            raise ValueError('MPI launcher arguments unsupported')
        coherent_hdf5(record)
        for kind in ('launcher', 'library', 'hdf5', 'hdf5_hl'):
            path = Path(record[kind])
            if not path.is_absolute() or str(path.resolve()) != str(path) or runner.digest(path) != record[kind + '_sha256']:
                raise ValueError('measured MPI runtime identity changed')
    return context


def measured_preflight(package, run_directory, base):
    """Read sealed engineering evidence; do not launch, reconcile receipts or grant science PASS."""
    import integration
    run_directory = Path(run_directory).resolve()
    spec = runner.verify(run_directory)
    # reconcile() here is the core's read-only evidence reducer; no receipt write occurs.
    receipt = runner.reconcile(run_directory)
    if receipt['state'] != 'EXECUTED' or receipt['resource_status'] != 'PASS' or len(spec['stages']) != 1:
        raise ValueError('completed resource-qualified MPI preflight required')
    stage = spec['stages'][0]
    if stage['name'] != 'execute' or spec['process_contract'] != 'foreground_owned_mpi' or not set(CONTEXT_FILES).issubset(stage['outputs']):
        raise ValueError('explicit owned MPI preflight required')
    for path, sha in integration.package_inputs(package).items():
        if stage['inputs'].get(path) != sha:
            raise ValueError('preflight source binding mismatch')
    load_path = stage['env'].get('JULIA_LOAD_PATH', '').split(':')
    if len(load_path) != 3 or load_path[0] != '@' or load_path[-1] != '@stdlib' or not Path(load_path[1]).is_absolute():
        raise ValueError('explicit private preference context required')
    for name in ('Project.toml', 'LocalPreferences.toml'):
        path = str(Path(load_path[1], name).resolve())
        if stage['inputs'].get(path) != runner.digest(path):
            raise ValueError('private preference input is not pinned')
    folder = run_directory / 'execute'
    terminal = runner.read(folder / 'mpi_terminal.json')
    if terminal['actual_root_exit'] != 0 or terminal['cleanup_status'] != 'PASS' or terminal['remaining_owned']:
        raise ValueError('MPI preflight cleanup incomplete')
    contexts = {name: runner.read(folder / name) for name in CONTEXT_FILES}
    context = matched_contexts(contexts)
    native_inputs = hdf5_inputs(context)
    if any(stage['inputs'].get(path) != sha for path, sha in native_inputs.items()):
        raise ValueError('HDF5 native dependency closure is not pinned by preflight')
    observed = contexts['sandbox-context.json']['base_julia_argv']
    observed[0] = str(Path(observed[0]).resolve())
    if base is not None and base != observed:
        raise ValueError('catalog flags differ from measured Pkg.test parent')
    if stage['mpi_ownership']['launcher'] != dict(path=context['launcher'], sha256=context['launcher_sha256']):
        raise ValueError('observed launcher differs from ownership policy')
    return dict(context, runtime=stage['mpi_ownership']['runtime'], hdf5_inputs=native_inputs, base_julia_argv=observed,
                context_environment={key: stage['env'].get(key) for key in ('JULIA_LOAD_PATH', 'JULIA_DEPOT_PATH')})


def validate_full_context(package, run_directory, policy, environment, julia):
    """Bind the Full request's actual preference context to the sealed preflight."""
    context = measured_preflight(package, run_directory, None)
    if str(Path(julia).resolve()) != context['base_julia_argv'][0]:
        raise ValueError('Full Julia differs from measured context')
    root_context = runner.read(Path(run_directory).resolve() / 'execute/parent-context.json')
    if any(arg.startswith('--compiled-modules=') for arg in root_context['base_julia_argv']):
        raise ValueError('native Full scheduler requires a preflight with its default compiler flags; custom compiled-modules preflight is execution-only')
    if policy['launcher'] != dict(path=context['launcher'], sha256=context['launcher_sha256']) or policy['runtime'] != context['runtime']:
        raise ValueError('Full runtime differs from measured context')
    if any(environment.get(key) != value for key, value in context['context_environment'].items()):
        raise ValueError('Full preference/depot context differs from measured context')
    return context


def main(argv=None):
    """Prepare a catalogue only from a measured same-source private MPI context."""
    p=argparse.ArgumentParser();p.add_argument('--package',required=True);p.add_argument('--base-argv-json',required=True,help='exact measured Pkg.test sandbox Base.julia_cmd().exec');p.add_argument('--tmp-root',required=True,help='owned scheduler MPI-only TMPDIR root');p.add_argument('--output',required=True);p.add_argument('--preflight-run',required=True,help='sealed same-source root/Pkg.test/MPI2 context run');p.add_argument('--runtime',required=True,help='explicit resolved local PRTE runtime; no host default');a=p.parse_args(argv)
    package=Path(a.package).resolve();base=runner.read(Path(a.base_argv_json).resolve());base[0]=str(Path(base[0]).resolve());tmp=str(Path(a.tmp_root).resolve());apps=[]
    context=measured_preflight(package,a.preflight_run,base)
    def app(script,flags,tails,ranks):
     path=package/script
     if not path.is_file():raise ValueError('missing literal Full MPI source: '+str(path))
     apps.append(dict(argv=base+flags+[str(path),*tails],ranks=ranks))
    flags=['--startup-file=no','--threads=1','--project='+str(package)];compiled=['--compiled-modules=no',*flags];variable={'path_under':tmp}
    # Julia normpath(joinpath(test_dir, '..')) retains a final separator.
    root_flags=['--startup-file=no','--threads=1','--project='+str(package)+'/'];root_compiled=['--compiled-modules=no',*root_flags]
    app('scripts/check_mpi_smoke.jl',root_flags,[],[2]);app('scripts/check_response_symmetry_mpi.jl',root_flags,['2'],[2])
    for backend in ('Direct','Mixed'):
     app('test/SpectralResponseDeterminismProbe.jl',flags,[variable,variable,backend],[1,2])
    app('test/MDRSRuntimeMpiProbe.jl',compiled,[variable],[2]);app('test/WannierizationRawZMpiProbe.jl',compiled,[],[1,2,4,8,16]);app('test/WannierizationULocalizationMpiProbe.jl',compiled,[],[1,2,4,8,16]);app('test/WannierizationWorkflowMpiProbe.jl',compiled,[variable],[2]);app('test/support/per_task_parallel_runner.jl',compiled,[variable],[1,2]);app('test/support/kpath_band_parallel_runner.jl',root_compiled,[variable],[1,2])
    launcher=context['launcher'];runtime=str(Path(a.runtime).resolve());
    if dict(path=runtime,sha256=runner.digest(runtime)) != context['runtime']: raise ValueError('PRTE runtime differs from measured preflight')
    libs=mpi_ownership.runtime_closure([launcher,runtime,context['library']]);libs.add(context['library']);pol=dict(kind='local_openmpi/1',launcher=dict(path=launcher,sha256=runner.digest(launcher)),runtime=dict(path=runtime,sha256=runner.digest(runtime)),runtime_inputs={f:runner.digest(f) for f in libs},applications=apps)
    out=Path(a.output).resolve()
    if out.exists():raise ValueError('use a fresh output path')
    runner.atomic(out,pol);print(json.dumps(dict(path=str(out),applications=len(apps),rank_counts=[1,2,4,8,16],scope='same-source measured private MPI context; engineering proof only; rederive after source/env/parent flags change')))


if __name__ == "__main__":
    main()
