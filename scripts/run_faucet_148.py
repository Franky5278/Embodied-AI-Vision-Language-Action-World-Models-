"""Isolated custom-148 evaluation. Run with the existing remote tdmpc2 Python."""
import os,sys,json,runpy
from pathlib import Path
ROOT=Path('/root/autodl-tmp/embodied')
HERE=Path(__file__).resolve().parent
import torch
assert torch.cuda.is_available(), 'GPU unavailable: do not start evaluation in no-GPU mode'
import gym
original_make=gym.make
def custom_make(env_id,*args,**kwargs):
    if env_id=='TurnFaucet-v0':
        kwargs.update(model_ids=['148'],asset_root=str(HERE/'asset_candidates'),
                      model_json=str(HERE/'faucet_148_metadata.json'))
        env=original_make(env_id,*args,**kwargs)
        raw=env.unwrapped
        observation=env.reset(seed=42)
        assert raw.model_id=='148'
        assert raw.target_joint.type=='revolute'
        assert raw.target_link.name=='link_0'
        manifest={'protocol':'custom fixed Faucet 148, distinct from legacy 5050',
            'observation_shape':list(env.observation_space.shape),
            'action_shape':list(env.action_space.shape),
            'reset_observation_shape':list(observation.shape),
            'model_id':raw.model_id,'target_joint_type':raw.target_joint.type,
            'target_link':raw.target_link.name,'scale':float(raw.model_scale)}
        Path(os.environ['EXPERIMENT_VIDEO_DIR'],'simulator_preflight.json').write_text(json.dumps(manifest,indent=2))
        print('CUSTOM_FAUCET_SIMULATOR_PREFLIGHT',json.dumps(manifest),flush=True)
        return env
    return original_make(env_id,*args,**kwargs)
gym.make=custom_make
sys.path.insert(0,str(ROOT/'repos/tdmpc2/tdmpc2'))
runpy.run_path(str(HERE/'tdmpc2_eval.py'),run_name='__main__')
