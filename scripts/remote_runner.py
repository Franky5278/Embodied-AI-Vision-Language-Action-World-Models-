import os, sys, time, json, subprocess, threading, signal
from pathlib import Path
R=Path('/root/autodl-tmp/embodied'); C=R/'scripts/codex_session_20261026'; S=R/'results/codex_session_20261026'
S.mkdir(exist_ok=True)
DEADLINE=time.monotonic()+4*3600
os.environ.update(MUJOCO_GL='egl',PYOPENGL_PLATFORM='egl',WANDB_MODE='disabled',TOKENIZERS_PARALLELISM='false',HF_HUB_OFFLINE='1',TRANSFORMERS_OFFLINE='1',MS2_ASSET_DIR=str(R/'maniskill_assets'),HF_HOME=str(R/'hf_cache'),TORCH_HOME=str(R/'torch_cache'),PYTHONUNBUFFERED='1',XLA_PYTHON_CLIENT_PREALLOCATE='false')
os.environ['VK_ICD_FILENAMES']='/etc/vulkan/icd.d/nvidia_icd.json'
status=[]; stop_telemetry=threading.Event()
def telemetry():
    with (S/'gpu.csv').open('w') as f:
        f.write('timestamp,memory_used_mib,util_gpu_pct,power_w\n')
        while not stop_telemetry.wait(5):
            subprocess.run(['nvidia-smi','--query-gpu=timestamp,memory.used,utilization.gpu,power.draw','--format=csv,noheader,nounits'],stdout=f,stderr=subprocess.DEVNULL); f.flush()
threading.Thread(target=telemetry,daemon=True).start()
def stage(name,cmd,cwd=R,timeout=2400,env=None):
    if DEADLINE-time.monotonic()<120: return False
    d=S/name; d.mkdir(exist_ok=True)
    if (d/'exit_code.txt').exists() and (d/'exit_code.txt').read_text().strip()=='0': return True
    (d/'command.json').write_text(json.dumps({'argv':cmd,'cwd':str(cwd)},indent=2))
    start=time.time(); print('START',name,flush=True)
    with (d/'console.log').open('a') as f:
        p=subprocess.Popen(cmd,cwd=cwd,stdout=f,stderr=subprocess.STDOUT,start_new_session=True,env=dict(os.environ,**(env or {})))
        try: rc=p.wait(timeout=min(timeout,max(1,DEADLINE-time.monotonic()-60)))
        except subprocess.TimeoutExpired:
            os.killpg(p.pid,signal.SIGTERM)
            try: p.wait(15)
            except subprocess.TimeoutExpired: os.killpg(p.pid,signal.SIGKILL)
            rc=124
    (d/'exit_code.txt').write_text(str(rc)); row=dict(stage=name,exit_code=rc,duration_sec=round(time.time()-start,2));status.append(row);(S/'status.json').write_text(json.dumps(status,indent=2));print('END',row,flush=True)
    return rc==0
def td(task,mpc=True,episodes=3):
    name='tdmpc2_'+task+('' if mpc else '_actor_only');d=S/name;d.mkdir(exist_ok=True)
    checkpoint=R/f'models/tdmpc2/compat_20261026/{task}-1.pt'
    if not checkpoint.exists():checkpoint=R/f'models/tdmpc2/{task}-1.pt'
    return stage(name,[str(R/'envs/tdmpc2/bin/python'),str(C/'tdmpc2_eval.py'),'task='+task,'model_size=5','checkpoint='+str(checkpoint),'eval_episodes='+str(episodes),'save_video=true','seed=42','compile=false','mpc='+str(mpc).lower(),'enable_wandb=false','hydra.run.dir='+str(d)],cwd=R/'repos/tdmpc2/tdmpc2',timeout=1200,env={'PYTHONPATH':str(R/'repos/tdmpc2/tdmpc2'),'EXPERIMENT_METRICS':str(d/'episodes.jsonl'),'EXPERIMENT_VIDEO_DIR':str(d)})
server=None
try:
    (S/'protocol.json').write_text(json.dumps(dict(seed=42,vla_suites=['libero_spatial','libero_object','libero_goal','libero_10'],tasks=[0,1],episodes_per_task=3,smolvla='Reuse mini_benchmark_001: verified 24 episodes, 17 successes, 353s. No rerun.',budget_hours=4,extra_experiments=['OpenPI brightness 0.7 on spatial tasks 0/1','TD-MPC2 actor-only on lift-cube'],training=False),indent=2))
    subprocess.run(['nvidia-smi'],stdout=(S/'hardware.txt').open('w'))
    for task in ['lift-cube','pick-cube','stack-cube','pick-ycb','turn-faucet']:
        if task=='turn-faucet' and (S/'tdmpc2_turn-faucet/exit_code.txt').exists():
            print('SKIP known incompatible faucet asset; previous error retained',flush=True)
            continue
        td(task)
    stage('openvla',['bash',str(C/'openvla.sh')],timeout=4800)
    stage('vla_jepa',['bash',str(C/'vla_jepa.sh')],timeout=4200)
    serverlog=(S/'openpi_server.log').open('a')
    server=subprocess.Popen([str(R/'envs/openpi-server/bin/python'),'scripts/serve_policy.py','--env','LIBERO','--port','8123','policy:checkpoint','--policy.config=pi05_libero','--policy.dir='+str(R/'models/openpi/pi05_libero')],cwd=R/'repos/openpi',stdout=serverlog,stderr=subprocess.STDOUT,start_new_session=True)
    import socket
    ready=False
    for _ in range(300):
        if server.poll() is not None: break
        try:
            with socket.create_connection(('127.0.0.1',8123),timeout=1): ready=True;break
        except OSError: time.sleep(2)
    if ready:
        for suite in ['libero_spatial','libero_object','libero_goal','libero_10']:
            d=S/('openpi_'+suite)
            stage('openpi_'+suite,[str(R/'envs/openpi-libero-client/bin/python'),str(C/'openpi_eval.py'),'--host','127.0.0.1','--port','8123','--task-suite-name',suite,'--num-trials-per-task','3','--seed','42','--video-out-path',str(d/'videos')],timeout=1800,env={'PYTHONPATH':str(R/'repos/openpi/third_party/libero')})
        if DEADLINE-time.monotonic()>1200:
            d=S/'openpi_brightness_07'
            stage('openpi_brightness_07',[str(R/'envs/openpi-libero-client/bin/python'),str(C/'openpi_eval.py'),'--host','127.0.0.1','--port','8123','--task-suite-name','libero_spatial','--num-trials-per-task','3','--seed','42','--brightness','0.7','--video-out-path',str(d/'videos')],timeout=1200,env={'PYTHONPATH':str(R/'repos/openpi/third_party/libero')})
    if server.poll() is None: os.killpg(server.pid,signal.SIGTERM);server.wait(timeout=30)
    server=None
    if DEADLINE-time.monotonic()>600: td('lift-cube',False)
except BaseException as e:
    (S/'runner_error.txt').write_text(repr(e));raise
finally:
    if server is not None and server.poll() is None:
        try: os.killpg(server.pid,signal.SIGTERM)
        except ProcessLookupError: pass
    stop_telemetry.set()
    (S/'GPU_FINISHED').write_text(time.strftime('%Y-%m-%dT%H:%M:%S%z'))
    # Local controller downloads and acknowledges; shutdown still occurs if it is offline.
    print('GPU_FINISHED; waiting at most 10 minutes for verified local download',flush=True)
    for _ in range(120):
        if (S/'DOWNLOAD_VERIFIED').exists(): break
        time.sleep(5)
    (S/'SHUTDOWN_REQUESTED').write_text(time.strftime('%Y-%m-%dT%H:%M:%S%z'))
    subprocess.run(['bash','/usr/bin/shutdown'])
