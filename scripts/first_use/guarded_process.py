#!/usr/bin/env python3
"""Monitor only an owned child group; retain failure logs and never orphan it.
Actual swap-used is unavailable under the sandbox. Stop on ANY increase in the
host Swapouts counter, stronger/conservative traffic guard; do not call it used swap.
"""
import json,os,signal,shutil,subprocess,time
from pathlib import Path
import process_resources as native

def stop_owned(child):
 if child.poll() is not None:return
 try:os.killpg(child.pid,signal.SIGTERM)
 except ProcessLookupError:return
 try:child.wait(timeout=10)
 except subprocess.TimeoutExpired:
  try:os.killpg(child.pid,signal.SIGKILL)
  except ProcessLookupError:pass
  child.wait()

def run(command,env,directory,timeout_seconds=180):
 directory=Path(directory)
 if shutil.disk_usage(directory).free<10*1024**3:raise RuntimeError("free disk below 10 GiB before start")
 initial=native.swapout_pages();samples=[];over=0;stop=None;error=None;start=time.monotonic()
 (directory/"resource_sampler.json").write_text(json.dumps({"rss":"libproc taskinfo owned descendant tree","actual_swap_used":"MISSING: kernel EPERM","swap_guard":"stop on any new host Swapouts page","initial_swapouts_pages":initial,"limit_seconds":timeout_seconds},indent=2)+"\n")
 with (directory/"stdout.log").open("w") as out,(directory/"stderr.log").open("w") as err:
  child=subprocess.Popen(command,env=env,stdout=out,stderr=err,start_new_session=True)
  (directory/"owned_process.json").write_text(json.dumps({"pid":child.pid,"process_group":child.pid,"command":command})+"\n")
  try:
   while child.poll() is None:
    rss=native.tree_rss_kib(child.pid);swap=native.swapout_pages();elapsed=time.monotonic()-start
    samples.append({"elapsed_seconds":elapsed,"tree_rss_kib":rss,"rss_kib":rss,"swapouts_pages":swap,"swap_used_mib":None})
    over=over+1 if rss>42*1024*1024 else 0
    if over>=3:stop="rss_over_42_gib_three_samples"
    elif swap>initial:stop="host_swapouts_increased_conservative_stop"
    elif shutil.disk_usage(directory).free<10*1024**3:stop="free_disk_below_10_gib"
    elif elapsed>timeout_seconds:stop="process_timeout"
    if stop:break
    time.sleep(1)
  except BaseException as exc:
   stop="resource_sampler_exception";error=repr(exc)
  finally:
   if stop:stop_owned(child)
  rc=child.wait()
 result={"return_code":rc,"stop_reason":stop,"monitor_error":error,"wall_seconds":time.monotonic()-start,"max_tree_rss_kib":max((s["tree_rss_kib"] for s in samples),default=0)}
 (directory/"resources.jsonl").write_text("".join(json.dumps(s)+"\n" for s in samples))
 (directory/"guard_receipt.json").write_text(json.dumps(result,indent=2)+"\n")
 return result
