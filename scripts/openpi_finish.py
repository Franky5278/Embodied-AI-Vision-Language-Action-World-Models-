from pathlib import Path
import os,subprocess,time,signal
R=Path('/root/autodl-tmp/embodied');C=R/'scripts/codex_session_20261026';S=R/'results/codex_session_20261026'
p=C/'openpi_eval.py';s=p.read_text();(C/'openpi_eval_before_close_fix.py').write_text(s)
s=s.replace('            env.close()\n\n    # Log final results','        env.close()\n\n        # Log final results')
compile(s,str(p),'exec');p.write_text(s)
env=dict(os.environ,MUJOCO_GL='egl',VK_ICD_FILENAMES='/etc/vulkan/icd.d/nvidia_icd.json',PYTHONUNBUFFERED='1')
try:
    for suite in ['libero_spatial','libero_object','libero_goal','libero_10','brightness_07']:
        name='openpi_'+suite;d=S/name;d.mkdir(exist_ok=True)
        cmd=[str(R/'envs/openpi-libero-client/bin/python'),str(p),'--host','127.0.0.1','--port','8123','--task-suite-name','libero_spatial' if suite=='brightness_07' else suite,'--num-trials-per-task','3','--seed','42','--video-out-path',str(d/'videos')]
        if suite=='brightness_07':cmd+=['--brightness','0.7']
        with (S/(name+'_completion.log')).open('a') as f:
            proc=subprocess.Popen(cmd,cwd=R/'repos/openpi',env=env,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
            try:rc=proc.wait(timeout=360)
            except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGTERM);rc=124
        (d/'completion_exit_code.txt').write_text(str(rc))
        print(name,rc,flush=True)
finally:
    os.kill(43579,signal.SIGCONT)
