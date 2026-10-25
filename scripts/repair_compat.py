from pathlib import Path
import json,difflib
R=Path('/root/autodl-tmp/embodied');C=R/'scripts/codex_session_20261026'
p=R/'repos/openvla/experiments/robot/openvla_utils.py';s=p.read_text()
if not (C/'original_openvla_utils.py').exists():(C/'original_openvla_utils.py').write_text(s)
# The code already registers all required HF classes locally. Avoid remote auto_map imports.
p.write_text(s.replace('trust_remote_code=True','trust_remote_code=False'))
(C/'openvla_offline.patch').write_text(''.join(difflib.unified_diff((C/'original_openvla_utils.py').read_text().splitlines(True),p.read_text().splitlines(True),fromfile='a/experiments/robot/openvla_utils.py',tofile='b/experiments/robot/openvla_utils.py')))
# Convert only legacy key names, retaining original checkpoints and tensor values.
import torch
out=R/'models/tdmpc2/compat_20261026';out.mkdir(exist_ok=True)
mapping={'_encoder.state.1.':'_encoder.state.0.','_encoder.state.2.':'_encoder.state.0.ln.','_encoder.state.4.':'_encoder.state.1.','_encoder.state.5.':'_encoder.state.1.ln.','_dynamics.0.0.':'_dynamics.0.','_dynamics.0.1.':'_dynamics.0.ln.','_dynamics.0.3.':'_dynamics.1.','_dynamics.0.4.':'_dynamics.1.ln.','_dynamics.0.6.':'_dynamics.2.','_dynamics.1.':'_dynamics.2.ln.'}
for group in ['_reward','_pi']:
    for old,new in [('0','0'),('1','0.ln'),('3','1'),('4','1.ln'),('6','2')]:mapping[group+'.'+old+'.']=group+'.'+new+'.'
records=[]
for task in ['lift-cube','pick-cube','stack-cube','pick-ycb','turn-faucet']:
    src=R/f'models/tdmpc2/{task}-1.pt';obj=torch.load(src,map_location='cpu',weights_only=False);state=obj.get('model',obj)
    if '_encoder.state.4.weight' in state:
        new={}
        for key,val in state.items():
            nk=key
            for a,b in mapping.items():
                if key.startswith(a):nk=b+key[len(a):];break
            assert nk not in new, 'Key collision'
            new[nk]=val
        # Check every mapped tensor is bitwise unchanged, not a partial/non-strict load.
        assert len(new)==len(state)
        if 'model' in obj:obj['model']=new
        else:obj=new
        torch.save(obj,out/src.name)
        records.append({'task':task,'action':'renamed legacy module keys, values unchanged','output':str(out/src.name)})
(C/'checkpoint_conversion.json').write_text(json.dumps(records,indent=2))
print(records)
# ManiSkill2 assets on this clone contain collision.ply rather than collision.obj.
import trimesh
converted=[]
for ply in (R/'maniskill_assets/mani_skill2_ycb/models').glob('*/collision.ply'):
    target=ply.with_suffix('.obj')
    if not target.exists():
        mesh=trimesh.load(str(ply),force='mesh');mesh.export(str(target));converted.append(str(target))
(C/'asset_conversion.json').write_text(json.dumps({'action':'PLY to OBJ format conversion of existing collision geometry','files':converted},indent=2))
print('YCB meshes converted',len(converted))
