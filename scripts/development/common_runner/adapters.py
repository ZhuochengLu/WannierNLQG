"""Foreground execution adapters; scientific gates never inferred from root exit0.
Full/source formats from frozen acceptance 20261002; cold reuses comparison_contract.
Registered MPI parses actual per-rank raw measurements and declared native files.
"""
import json, math, re, csv
import hashlib
from pathlib import Path
import runner
from comparison_contract import BACKEND_NAMES, compare_first_call
KINDS=('full','mpi','cold','source_audit')
FULL_TASKS=('fast','interfaces-and-symmetry','wannier-core','scientific-contracts','thread-determinism','star-gauge-thread','mpi-only')
RESOURCE_LIMITS=dict(timeout_seconds=180,rss_kib=42*1024**2,disk_floor_bytes=10*1024**3,
                     sample_seconds=1,rss_over_samples=3,host_swapouts_guard=True,cpu_budget=1,reserve_bytes=0)


def request(kind,run_id,stages,limits,acceptance=None,qualification=None):
    if kind not in KINDS: raise ValueError('unknown task family')
    result=dict(schema=runner.SCHEMA,adapter=kind,run_id=run_id,stages=stages,limits=limits,
                process_contract='foreground_owned_group',acceptance=acceptance or {},qualification=qualification or {})
    runner.validate(result);return result


class Evidence:
    """Files may only be declared captured outputs or pinned immutable inputs."""
    def __init__(self,run,spec,stage):self.run=Path(run).resolve();self.spec=spec;self.stage=stage
    def path(self,token,*,reference=False):
        if not isinstance(token,str): raise ValueError('evidence file token must be string')
        if reference and not Path(token).is_absolute():raise ValueError('reference must be an absolute pinned immutable input')
        if Path(token).is_absolute():
            p=Path(token)
            if not any(s['inputs'].get(token)==runner.digest(p) for s in self.spec['stages']): raise ValueError('unbound external evidence')
            if not reference: raise ValueError('actual evidence must be captured stage output')
            return p
        stage,name=token.split(':',1) if ':' in token else (self.stage,token)
        s=next((s for s in self.spec['stages'] if s['name']==stage),None)
        if s is None or not runner.relative_output(name) or name not in ['stdout.log','stderr.log',*s.get('outputs',[])]:
            raise ValueError('undeclared evidence '+token)
        p=self.run/stage/name
        if not p.resolve().is_relative_to((self.run/stage).resolve()):raise ValueError('output symlink escapes owned stage')
        return p
    def json(self,token,**kw):return json.loads(self.path(token,**kw).read_text())


def file_tokens(q):
    kind=q['kind']
    if kind=='full':return [q['summary'],*q['logs'].values()]
    if kind=='mpi':return [*q['rank_files'],*[p['actual'] for p in q['science_pairs']]]
    if kind=='cold':return [q['receipt'],*[p['actual'] for p in q.get('science_pairs',[])]]
    return [q[k] for k in ('preflight','write','check','write_tsv','check_tsv')]


def validate_qualification(spec):
    if spec.get('qualification') and (spec['limits'].get('host_swapouts_guard') is not True or spec['limits'].get('rss_over_samples')!=3):
        raise ValueError('typed Wannier adapters require host Swapouts guard and three consecutive RSS samples')
    expected={
      'full':{'kind','summary','logs','source_root','source_manifest','source_manifest_sha256','jobs_effective','cpu_budget'},
      'mpi':{'kind','rank_files','rank_count','package_root','source_manifest','source_manifest_sha256','path','compile_limit_seconds','mpi_library_contains','julia_version','task_labels','science_pairs','output_inventory'},
      'cold':{'kind','receipt','reference','contract','package_root','source_manifest','source_manifest_sha256','science_pairs'},
      'source_audit':{'kind','preflight','write','check','write_tsv','check_tsv','source_root','source_manifest','source_manifest_sha256','source_sha256','certificate_file','certificate_sha256','expected_counts'}}
    for stage,q in spec.get('qualification',{}).items():
        if stage not in [s['name'] for s in spec['stages']] or q.get('kind')!=spec['adapter']:raise ValueError('qualification stage/family mismatch')
        if set(q)!=expected[q['kind']]:raise ValueError('missing/unknown adapter contract fields')
        ev=Evidence(Path('/not-created'),spec,stage)
        for token in file_tokens(q):
            if Path(token).is_absolute():raise ValueError('actual qualification file must be captured output')
            st,name=token.split(':',1) if ':' in token else (stage,token)
            s=next((s for s in spec['stages'] if s['name']==st),None)
            if s is None or not runner.relative_output(name) or name not in ['stdout.log','stderr.log',*s.get('outputs',[])]:raise ValueError('unbound adapter output '+token)
        for token in ([q['reference']] if q['kind']=='cold' else [])+[p['reference'] for p in q.get('science_pairs',[])]:ev.path(token,reference=True)
        for pair in q.get('science_pairs',[]):
            if set(pair)!={'actual','reference','format'} or pair['format'] not in ('bytes','json','native_return'):raise ValueError('unsupported native evidence contract')
            if pair['format']=='native_return' and q['kind']!='cold':raise ValueError('native_return projection is only supported for generic cold measurements')
        if q['kind'] in KINDS:
            ev.path(q['source_manifest'],reference=True)
            if runner.digest(q['source_manifest'])!=q['source_manifest_sha256']:raise ValueError('source manifest identity mismatch')
        if q['kind']=='mpi':
            if type(q['rank_count']) is not int or q['rank_count']<1 or len(q['rank_files'])!=q['rank_count'] or len(set(q['rank_files']))!=q['rank_count']:raise ValueError('rank inventory mismatch')
            if not q['science_pairs'] or set(q['output_inventory'])!={str(r) for r in range(q['rank_count'])}:raise ValueError('native/rank output inventory required')
            paired={p['actual'] for p in q['science_pairs']}
            if any(not files or not set(files)<=paired for files in q['output_inventory'].values()):raise ValueError('every rank native output must have an exact reference pair')
            if not q['mpi_library_contains'] or not q['task_labels'] or not q['julia_version']:raise ValueError('explicit MPI/Julia/label identities required')
            if spec['limits'].get('cpu_budget',1)<q['rank_count']:raise ValueError('MPI rank count exceeds declared CPU budget')
        if q['kind']=='full' and q['cpu_budget']!=spec['limits'].get('cpu_budget',1):raise ValueError('Full scheduler/core CPU budgets disagree')
        if q['kind']=='cold':
            if not q['science_pairs']:raise ValueError('mandatory native science comparison missing')
            first=q['science_pairs'][0]
            if first!={'actual':q['receipt'],'reference':q['reference'],'format':'native_return'}:
                raise ValueError('cold native return must link the actual receipt to its sealed reference')
            c=q['contract']
            required={'required_absent_backends','excluded_return_fields','native_kind','compile_limit_seconds','compare_semantic_return','ignored_json_top_level_metadata'}
            if not required<=set(c) or set(c)-required-{'ignored_hdf5_metadata_fields'}:raise ValueError('cold comparison contract incomplete/unknown')
            if c['native_kind'] not in ('reader','writer'):raise ValueError('unsupported cold native kind')
            if type(c['compare_semantic_return']) is not bool:raise ValueError('semantic comparison policy must be boolean')
        if q['kind']=='source_audit':
            ev.path(q['certificate_file'],reference=True)
            if runner.digest(q['certificate_file'])!=q['certificate_sha256']:raise ValueError('certificate identity mismatch')
            if set(q['expected_counts'])!={'retained','legacy_retained','additional_retained','additional_actual_type_sources'}:raise ValueError('source count contract incomplete')
        limit=q['contract']['compile_limit_seconds'] if q['kind']=='cold' else q.get('compile_limit_seconds')
        if limit is not None and (type(limit) not in (int,float) or not math.isfinite(limit) or limit<=0):raise ValueError('finite compile threshold required')


def source_identity(ev,q):
    manifest=ev.path(q['source_manifest'],reference=True)
    root=Path(q.get('source_root',q.get('package_root'))).resolve()
    if manifest.resolve()!=root/'SOURCE_MANIFEST.tsv' or runner.digest(manifest)!=q['source_manifest_sha256']:return False
    rows=list(csv.DictReader(manifest.open(),delimiter='\t'))
    paths=[r['path'] for r in rows]
    if paths!=sorted(set(paths)):return False
    for r in rows:
        if not runner.relative_output(r['path']) or r['type']!='file':return False
        p=root/r['path']
        if p.is_symlink() or not p.is_file() or p.stat().st_size!=int(r['bytes']) or runner.digest(p)!=r['sha256']:return False
    actual={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and '.git' not in p.relative_to(root).parts}
    return actual==set(paths)|{'SOURCE_MANIFEST.tsv','SHA256SUMS'} and (root/'SHA256SUMS').read_text()==''.join(r['sha256']+'  '+r['path']+'\n' for r in rows)


def source_payload(ev,q):
    root=Path(q.get('source_root',q.get('package_root'))).resolve();h=hashlib.sha256()
    for r in csv.DictReader(ev.path(q['source_manifest'],reference=True).open(),delimiter='\t'):
        if not runner.relative_output(r['path']):raise ValueError('invalid source inventory path')
        h.update(r['path'].encode());h.update(b'\0');h.update((root/r['path']).read_bytes())
    return h.hexdigest()


def native_pairs(ev,pairs):
    checks={}
    for i,p in enumerate(pairs):
        a=ev.path(p['actual']);b=ev.path(p['reference'],reference=True)
        if a.resolve()==b.resolve():raise ValueError('actual/reference self-comparison prohibited')
        if p['format']=='bytes':same=a.read_bytes()==b.read_bytes()
        elif p['format']=='json':same=json.loads(a.read_text())==json.loads(b.read_text())
        elif p['format']=='native_return':
            ar=json.loads(a.read_text())['first_calls'];br=json.loads(b.read_text())['first_calls']
            if len(ar)!=1 or len(br)!=1:raise ValueError('native return projection requires exactly one first call')
            same=ar[0]['return_summary']==br[0]['return_summary'] and ar[0]['semantic_return']==br[0]['semantic_return']
        else:raise ValueError('unsupported native comparison format')
        checks[f'native_exact_{i}']=same
    return checks


def parse_full(ev,q):
    summary=ev.json(q['summary']);rows=summary['tasks'];checks={
      'schema':summary['schema']=='wanniernlqg.test-scheduler/1.0','summary_status':summary['status']=='PASS',
      'source_root':summary['root']==q['source_root'],'source_identity':source_identity(ev,q),
      'seven_exact_tasks':len(rows)==7 and {r['task'] for r in rows}==set(FULL_TASKS),
      'declared_log_inventory':set(q['logs'])==set(FULL_TASKS),
      'jobs':summary['jobs_effective']==q['jobs_effective'],'cpu_budget':summary['cpu_budget']==q['cpu_budget'],
      'mpi_exclusive':summary['mpi_exclusive'] is True}
    for r in rows:
        task=r['task']
        if task not in q['logs']:checks['unexpected_task']=False;continue
        log=ev.path(q['logs'][task]);text=log.read_text()
        mode='fast' if task=='fast' else 'mpi-only' if task=='mpi-only' else 'full-shard'
        shard='none' if task in ('fast','mpi-only') else task
        checks[task+'_exit0']=type(r['exit_code']) is int and r['exit_code']==0
        checks[task+'_status']=r['status']=='PASS' and r['completion_marker'] is True
        checks[task+'_log_locator']=Path(r['log']).resolve()==log.resolve()
        checks[task+'_hash']=runner.digest(log)==r['log_sha256']
        checks[task+'_outer_marker']=bool(re.search(r'^WANNIERNLQG_TEST_TASK_COMPLETE:'+re.escape(task)+r'\s*$',text,re.M))
        checks[task+'_internal_marker']=bool(re.search(r'^\[test-suite:complete\] mode='+re.escape(mode)+' shard='+re.escape(shard)+r' elapsed_s=[0-9.]+',text,re.M))
        checks[task+'_pkg_marker']='Testing WannierNLQG tests passed' in text
    return checks,{}


def parse_mpi(ev,q):
    rows=[ev.json(f) for f in q['rank_files']];checks={'source_identity':source_identity(ev,q)};compiles=[];recompiles=[]
    for rank,r in enumerate(rows):
        timer=r['first'];state=r['extension_state_before'];ct=timer['compile_time'];rt=timer['recompile_time']
        expected_outputs=[str(ev.path(f).resolve()) for f in q['output_inventory'][str(rank)]]
        rank_checks=dict(rank=type(r['rank']) is int and r['rank']==rank,path=r['path']==q['path'],package=r['package_root']==q['package_root'],
          gc=r['gc_on'] is True,workload=r['workload_enabled'] is True,backend_inventory=set(state)==set(BACKEND_NAMES),
          backend_cold=all(v is False for v in state.values()),mpi_cold=r['mpi_initialized_before'] is False,
          threads=all(type(r[k]) is int and r[k]==1 for k in ('julia_threads','blas_threads','fftw_threads')),
          library=all(part in r['mpi_library'] for part in q['mpi_library_contains']),julia=r['julia_version']==q['julia_version'],
          labels=r['task_labels']==q['task_labels'],compile=type(ct) in (int,float) and math.isfinite(ct) and 0<=ct<=q['compile_limit_seconds'],
          recompile=type(rt) in (int,float) and math.isfinite(rt) and 0<=rt<=ct,
          output_inventory=r['first_outputs']==expected_outputs,
          timer_interval=type(r['first_start_ns']) is int and type(r['first_end_ns']) is int and 0<r['first_start_ns']<r['first_end_ns'],
          wall=type(timer['wall']) in (int,float) and math.isfinite(timer['wall']) and timer['wall']>0,
          time=type(timer['time']) in (int,float) and math.isfinite(timer['time']) and timer['time']>0,
          gc_time=type(timer['gc_time']) in (int,float) and math.isfinite(timer['gc_time']) and 0<=timer['gc_time']<=timer['time'],
          allocated_bytes=type(timer['allocated_bytes']) is int and timer['allocated_bytes']>=0)
        checks.update({f'rank_{rank}_{k}':v for k,v in rank_checks.items()});compiles.append(ct);recompiles.append(rt)
    checks.update(native_pairs(ev,q['science_pairs']))
    return checks,dict(rank_observations=len(rows),max_rank_compile_time=max(compiles),max_rank_recompile_time=max(recompiles))


def parse_cold(ev,q):
    actual=ev.json(q['receipt']);reference=ev.json(q['reference'],reference=True)
    if len(actual['first_calls'])!=1 or len(reference['first_calls'])!=1:raise ValueError('only generic single-first-call cold schema supported')
    a=actual['first_calls'][0];b=reference['first_calls'][0];c=q['contract']
    if c['native_kind']=='writer' and (a.get('native_readback') is None or b.get('native_readback') is None):raise ValueError('writer native report missing')
    for report,ref in ((a.get('native_readback'),False),(b.get('native_readback'),True)):
        if report is not None:
            artifact=report['artifact']
            if ref:ev.path(artifact,reference=True)
            else:
                p=Path(artifact).resolve();tokens=[str(ev.path(t).resolve()) for t in file_tokens(q)]
                if str(p) not in tokens:raise ValueError('unbound native artifact')
    checks=compare_first_call(a,b,c,gc_on=actual['gc_on'] is True and a['gc_on_at_target'] is True)
    checks.update(fixture=actual['fixture_passed'] is True,package=actual['package_root']==q['package_root'],
        expected_package=actual['expected_package_root']==q['package_root'],target=actual['target']==reference['target']==a['target']==b['target'],
        source_identity=source_identity(ev,q),return_type=a['return_summary']['type']==b['return_summary']['type'],
        all_finite=a['return_summary']['all_finite'] is True,
        numeric_leaf_count=a['return_summary']['numeric_leaf_count']==b['return_summary']['numeric_leaf_count'],
        gc_timer=type(a['gc_time']) in (int,float) and math.isfinite(a['gc_time']) and 0<=a['gc_time']<=a['time'])
    checks.update(native_pairs(ev,q['science_pairs']))
    return checks,dict(compile_time=a['compile_time'],recompile_time=a['recompile_time'],gc_time=a['gc_time'])


def parse_source(ev,q):
    p=ev.json(q['preflight']);w=ev.json(q['write']);c=ev.json(q['check']);expected=q['expected_counts'];checks={
      'preflight':p['new_chain_preflight_pass'] is True,'source_identity':source_identity(ev,q),'write_mode':w['mode']=='write','check_mode':c['mode']=='check',
      'independent_check':c['independent_check'] is True,'write_not_independent':w['independent_check'] is False,
      'retained_partition':expected['retained']==expected['legacy_retained']+expected['additional_retained']}
    certificate=ev.json(q['certificate_file'],reference=True)
    checks['certificate_hash']=runner.digest(ev.path(q['certificate_file'],reference=True))==q['certificate_sha256']
    checks['certificate_source']=certificate['candidate_source_sha256']==q['source_sha256']
    checks['certificate_payload']=certificate['candidate_payload_sha256']==source_payload(ev,q)
    for label,r in (('preflight',p),('write',w),('check',c)):
        checks[label+'_source']=r['current_source_sha256']==q['source_sha256']
        checks[label+'_certificate']=r['certificate_sha256']==q['certificate_sha256']
    for label,r in (('write',w),('check',c)):
        for name,value in expected.items():checks[label+'_'+name]=type(r[name]) is int and r[name]==value
        checks[label+'_unowned']=type(r['unowned']) is int and r['unowned']==0
        checks[label+'_tsv_hash']=r['provenance_sha256']==runner.digest(ev.path(q[label+'_tsv']))
    checks['tsv_bytes_exact']=ev.path(q['write_tsv']).read_bytes()==ev.path(q['check_tsv']).read_bytes()
    for label in ('write','check'):
        rows=list(csv.DictReader(ev.path(q[label+'_tsv']).open(),delimiter='\t'))
        checks[label+'_tsv_retained_rows']=len(rows)==expected['retained']
        checks[label+'_tsv_owned']=all(r['owner'] and r['status']!='UNOWNED' for r in rows)
        checks[label+'_tsv_source']=all(r['source_sha256']==q['source_sha256'] for r in rows)
        checks[label+'_tsv_certificate']=all(r['source_equivalence_certificate_sha256']==q['certificate_sha256'] for r in rows)
        checks[label+'_tsv_unique_signatures']=len({(r['owner'],r['ordinal']) for r in rows})==len(rows)
    return checks,dict(retained=w['retained'],unowned=w['unowned'])


PARSERS=dict(full=parse_full,mpi=parse_mpi,cold=parse_cold,source_audit=parse_source)

def stage_gate(directory,spec,stage):
    ev=Evidence(directory,spec,stage);checks={};metrics={}
    for i,g in enumerate(spec.get('acceptance',{}).get(stage,[])):
        try:
            p=ev.path(g['file'])
            if g['kind']=='marker':ok=bool(re.search(g['pattern'],p.read_text(),re.M))
            elif g['kind']=='json':
                value=json.loads(p.read_text())
                for k in g['keys']:value=value[k]
                ok=value==g['equals']
            else:raise ValueError('unsupported generic gate')
            checks[f'completion_{i}']=ok
        except (OSError,ValueError,KeyError,IndexError):checks[f'completion_{i}']=False
    q=spec.get('qualification',{}).get(stage)
    if q:
        try:typed,metrics=PARSERS[q['kind']](ev,q);checks.update(typed)
        except (OSError,ValueError,KeyError,IndexError,TypeError) as exc:
            return dict(status='FAIL',checks=checks,error=str(exc),metrics=metrics)
    return dict(status=('PASS' if all(v is True for v in checks.values()) else 'FAIL') if checks else 'NOT_EVALUATED',checks=checks,metrics=metrics)


def qualify(directory,runtime=None):
    directory=Path(directory).resolve();spec=runner.verify(directory);runtime=runtime or runner.reconcile(directory)
    if runtime['state']!='EXECUTED':return dict(status='HOLD',execution_status=runtime['state'],adapter_status='NOT_EVALUATED')
    rows={s['name']:stage_gate(directory,spec,s['name']) for s in spec['stages']}
    gates=[r['status'] for r in rows.values() if r['status']!='NOT_EVALUATED']
    adapter='FAIL' if 'FAIL' in gates else 'PASS' if gates else 'NOT_EVALUATED'
    typed=bool(spec.get('qualification'))
    status='FAIL' if adapter=='FAIL' else ('PASS' if typed else 'ENGINEERING_PASS') if adapter=='PASS' else 'NOT_EVALUATED'
    return dict(status=status,execution_status=runtime['execution_status'],resource_status=runtime['resource_status'],adapter_status=adapter,
                completion_status=adapter,kernel_containment_status='UNKNOWN',process_contract=spec['process_contract'],stages=rows,
                scope='declared foreground execution/resource/adapter gates only; no kernel containment or independent physics/production qualification')

if __name__=='__main__':
    import sys
    print(json.dumps(qualify(sys.argv[1]),indent=2))
