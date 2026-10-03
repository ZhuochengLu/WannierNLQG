#!/usr/bin/env python3
"""Self-contained seconds-only engineering smoke. No Julia/MPI scientific execution."""
import sys
sys.dont_write_bytecode=True
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import time
sys.path.insert(0,str(Path(__file__).resolve().parent))
import runner
import adapters
import integration
from identity import alive

HERE=Path(__file__).resolve().parent
PACKAGE=HERE.parents[2]
ENTRY=PACKAGE/'scripts/development_runner.py'

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output-dir',required=True)
    args=parser.parse_args();out=Path(args.output_dir).resolve()
    if out==PACKAGE or PACKAGE in out.parents:raise ValueError('evidence must be outside source')
    out.mkdir(parents=True,exist_ok=False);checks=[]
    def record(name,ok,detail=None):
        checks.append(dict(test=name,passed=bool(ok),detail=detail));runner.atomic(out/'results.json',checks);assert ok,(name,detail)
    def save(name,obj):
        p=out/name;runner.atomic(p,obj);return str(p)
    def cli(argv,name):
        cmd=[sys.executable,'-B',str(ENTRY),*argv];p=subprocess.run(cmd,cwd=PACKAGE,capture_output=True,text=True)
        save(name+'.cli.json',dict(argv=cmd,cwd=str(PACKAGE),return_code=p.returncode,stdout=p.stdout,stderr=p.stderr));return p
    def finished(run):
        for _ in range(160):
            if (run/'receipt.json').exists():return runner.reconcile(run)
            time.sleep(.1)
        raise AssertionError('task did not finish')
    env=save('env.json',dict(PATH='/usr/bin:/bin',PYTHONDONTWRITEBYTECODE='1'))
    def common(kind,name,cpu):
        return [kind,'--run-id',name,'--runs-root',str(out/'runs'),'--request-out',str(out/(name+'.request.json')),
                '--env-json',env,'--timeout','12','--rss-gib','1','--cpu-budget',str(cpu)]
    fake=out/'fake_julia.py';fake.write_text('#!'+str(Path(sys.executable).resolve())+'\n'+'''import os,time
mode=os.environ['WANNIERNLQG_TEST_MODE'];task=os.environ['WANNIERNLQG_TEST_TASK_ID'];shard=os.environ.get('WANNIERNLQG_TEST_SHARD','none')
print(f'OWNED_GROUP={os.getpgrp()}',flush=True);time.sleep(.06)
print(f'[test-suite:complete] mode={mode} shard={shard} elapsed_s=0.06')
print('Testing WannierNLQG tests passed')
print('WANNIERNLQG_TEST_TASK_COMPLETE:'+task)
''');fake.chmod(0o755)
    p=cli(common('full','full',17)+['--julia',str(fake),'--jobs','1'],'full_submit');record('full_submit',p.returncode==0,p.stderr)
    run=out/'runs/full';r=finished(run);p=cli(['qualify',str(run)],'full_qualify');q=json.loads(p.stdout)
    record('full_typed_pass',p.returncode==0 and q['status']=='PASS',q)
    summary=runner.read(run/'execute/suite/summary.json');owner=runner.read(run/'execute/owner.json')
    record('seven_owned_children',len(summary['tasks'])==7 and summary['owned_group'] and all('OWNED_GROUP='+str(owner['task']['pgid']) in Path(x['log']).read_text() for x in summary['tasks']))
    before={p.relative_to(run).as_posix():runner.digest(p) for p in (run/'execute').rglob('*') if p.is_file()}
    p=cli(['submit',str(out/'full.request.json'),'--root',str(out/'runs')],'full_duplicate');record('duplicate_idempotent',p.returncode==0 and runner.read(run/'execute/owner.json')==owner)
    (run/'receipt.json').rename(run/'original-receipt.json');p=cli(['reconcile',str(run)],'full_reconcile');record('receipt_reconstructed',p.returncode==0 and json.loads(p.stdout)['state']=='EXECUTED')
    p=cli(['resume',str(run)],'full_resume');after={p.relative_to(run).as_posix():runner.digest(p) for p in (run/'execute').rglob('*') if p.is_file()}
    record('resume_no_reexecution',p.returncode==0 and before==after)
    backend={n:False for n in sorted(adapters.BACKEND_NAMES)}
    manifest=str(PACKAGE/'SOURCE_MANIFEST.tsv');msha=runner.digest(manifest)
    for kind in ('mpi','cold','source_audit','mpi_bad','source_bad'):
        family='mpi' if kind=='mpi_bad' else 'source_audit' if kind=='source_bad' else kind
        dest=out/'runs'/kind/'execute';outputs={};contract=dict(kind=family,source_manifest=manifest,source_manifest_sha256=msha)
        if family=='mpi':
            native='native.dat';reference=out/(kind+'-reference.dat');reference.write_text('1 2 3\n');outputs[native]=dict(format='text',value='1 2 3\n')
            for rank in range(2):
                row=dict(rank=rank,path='simulated_kpath',package_root=str(PACKAGE),gc_on=True,workload_enabled=True,
                    extension_state_before=backend,mpi_initialized_before=False,julia_threads=1,blas_threads=1,fftw_threads=1,
                    mpi_library='SIMULATION_MPI',julia_version='SIMULATION',task_labels=['simulated_task'],first_start_ns=1,first_end_ns=2,
                    first_outputs=[str(dest/native)],first=dict(compile_time=.51 if kind=='mpi_bad' and rank==1 else .01*(rank+1),recompile_time=.001,wall=.1,time=.1,gc_time=0,allocated_bytes=0))
                outputs[f'rank_{rank}.json']=dict(format='json',value=row)
            contract.update(rank_files=['rank_0.json','rank_1.json'],rank_count=2,package_root=str(PACKAGE),path='simulated_kpath',compile_limit_seconds=.5,
                mpi_library_contains=['SIMULATION_MPI'],julia_version='SIMULATION',task_labels=['simulated_task'],science_pairs=[dict(actual=native,reference=str(reference),format='bytes')],output_inventory={'0':[native],'1':[native]})
        elif family=='cold':
            call=dict(target='simulation',success=True,gc_on_at_target=True,extension_state_before=backend,compile_time=.01,recompile_time=.001,time=.1,gc_time=0,
                return_summary=dict(type='Vector{Float64}',all_finite=True,numeric_leaf_count=1,leaves=[dict(path='value',payload='3ff0000000000000')]),semantic_return={'value':1})
            receipt=dict(simulation_only=True,gc_on=True,fixture_passed=True,package_root=str(PACKAGE),expected_package_root=str(PACKAGE),target='simulation',first_calls=[call])
            reference=save('cold-reference.json',receipt);outputs['cold.json']=dict(format='json',value=receipt)
            contract.update(package_root=str(PACKAGE),receipt='cold.json',reference=reference,contract=dict(required_absent_backends=sorted(backend),excluded_return_fields=[],native_kind='reader',compile_limit_seconds=.5,compare_semantic_return=True,ignored_json_top_level_metadata=[]),science_pairs=[dict(actual='cold.json',reference=reference,format='native_return')])
        else:
            inputs=integration.package_inputs(PACKAGE);source=runner.digest(PACKAGE/'src/WannierNLQG.jl')
            payload=adapters.source_payload(adapters.Evidence(out,{'stages':[dict(name='execute',inputs=inputs,outputs=[])]},'execute'),dict(source_manifest=manifest,source_root=str(PACKAGE)))
            cert=save(kind+'-certificate.json',dict(simulation_only=True,candidate_source_sha256=source,candidate_payload_sha256=payload));certsha=runner.digest(cert)
            text='owner\tordinal\tstatus\tsource_sha256\tsource_equivalence_certificate_sha256\n'+''.join(f'src/WannierNLQG.jl\t{i}\tTRACED\t{source}\t{certsha}\n' for i in (1,2))
            counts=dict(retained=2,legacy_retained=1,additional_retained=1,additional_actual_type_sources=1)
            for label in ('preflight','write','check'):
                row=dict(new_chain_preflight_pass=True,current_source_sha256=source,certificate_sha256=certsha,mode=label,independent_check=label=='check',unowned=1 if kind=='source_bad' and label=='check' else 0,provenance_sha256=hashlib.sha256(text.encode()).hexdigest(),**counts)
                outputs[label+'.json']=dict(format='json',value=row)
            outputs.update({'write.tsv':dict(format='text',value=text),'check.tsv':dict(format='text',value=text)})
            contract.update(preflight='preflight.json',write='write.json',check='check.json',write_tsv='write.tsv',check_tsv='check.tsv',source_root=str(PACKAGE),source_sha256=source,certificate_file=cert,certificate_sha256=certsha,expected_counts=counts)
        plan=save(kind+'-plan.json',dict(simulation_only=True,outputs=outputs));argv=save(kind+'-argv.json',[str(Path(sys.executable).resolve()),str(HERE/'fixture_task.py'),plan,str(dest)])
        outputs_file=save(kind+'-outputs.json',list(outputs));qual=save(kind+'-qualification.json',contract)
        args=common(family.replace('_','-'),kind,2)+['--argv-json',argv,'--cwd',str(out),'--outputs-json',outputs_file,'--qualification-json',qual,'--input',plan]
        p=cli(args,kind+'_submit');record(kind+'_submit',p.returncode==0,p.stderr);r=finished(out/'runs'/kind)
        p=cli(['qualify',str(out/'runs'/kind)],kind+'_qualify');q=json.loads(p.stdout);wanted='FAIL' if kind.endswith('_bad') else 'PASS';record(kind+'_typed_'+wanted,p.returncode==0 and q['status']==wanted,q)
    # Direct bundled-core engineering negatives, never fake scientific PASS.
    def generic(name,code,timeout=3):
        exe=str(Path(sys.executable).resolve());s=dict(schema=runner.SCHEMA,run_id=name,adapter='generic',process_contract='foreground_owned_group',limits=dict(disk_floor_bytes=10*1024**3,rss_kib=1024**2,timeout_seconds=timeout,sample_seconds=.05,rss_over_samples=3,host_swapouts_guard=True),stages=[dict(name='one',argv=[exe,'-c',code],cwd=str(out),env={'PATH':'/usr/bin:/bin'},inputs={exe:runner.digest(exe)},outputs=[])])
        save(name+'-request.json',s);runner.submit(s,out/'runs');return out/'runs'/name
    d=generic('nonzero','import sys;sys.exit(7)');r=finished(d);record('nonzero_actual_7',r['state']=='RUN_FAILED' and r['stages'][0]['return_code']==7)
    d=generic('timeout','import time;time.sleep(2)',.2);r=finished(d);record('timeout_actual_exit',r['state']=='RESOURCE_LIMIT' and r['stages'][0]['return_code'] is not None)
    (run/'execute/exit.json').rename(run/'execute/exit-held-by-smoke.json');p=cli(['status',str(run)],'missing_exit');record('missing_exit_unknown',p.returncode==0 and json.loads(p.stdout)['state']=='UNKNOWN')
    before_resume=runner.digest(run/'execute/stdout.log');p=cli(['resume',str(run)],'missing_exit_resume');record('unknown_resume_no_rerun',p.returncode==0 and json.loads(p.stdout)['state']=='UNKNOWN' and runner.digest(run/'execute/stdout.log')==before_resume)
    (run/'execute/exit-held-by-smoke.json').rename(run/'execute/exit.json')
    record('no_bytecode_in_package',not list(PACKAGE.rglob('*.pyc')) and not list(PACKAGE.rglob('__pycache__')))
    record('owned_full_root_finished',not alive(owner['task']))
    save('SUMMARY.json',dict(status='PASS',checks=len(checks),scope='Python engineering simulation only; no Julia/MPI/scientific acceptance',package=str(PACKAGE),entry=str(ENTRY),core=str(runner.HERE),kernel_containment='UNKNOWN',scientific='NOT_EVALUATED'))
    print(json.dumps(dict(status='PASS',checks=len(checks),evidence=str(out)),indent=2))

if __name__=='__main__':main()
