"""CPU structural checks and geometry preview; does not claim simulator validation."""
from pathlib import Path
import sys,json,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'vendor'))
import numpy as np
import trimesh
from scipy.spatial.transform import Rotation
asset=ROOT/'asset_candidates/148'
model=ET.parse(asset/'mobility_cvx.urdf').getroot()
joints=model.findall('joint')
def origin(node):
    result=np.eye(4)
    if node is not None:
        result[:3,:3]=Rotation.from_euler('xyz',np.fromstring(node.get('rpy','0 0 0'),sep=' ')).as_matrix()
        result[:3,3]=np.fromstring(node.get('xyz','0 0 0'),sep=' ')
    return result
poses={'base':np.eye(4)}
while len(poses)<len(model.findall('link')):
    count=len(poses)
    for joint in joints:
        parent=joint.find('parent').get('link');child=joint.find('child').get('link')
        if parent in poses:
            poses[child]=poses[parent]@origin(joint.find('origin'))
    assert len(poses)>count,'Disconnected or cyclic kinematic tree'
collision_checks=[]
visuals=[]
for link in model.findall('link'):
    for node in link.findall('collision'):
        path=(asset/node.find('geometry/mesh').get('filename')).resolve()
        assert path.is_relative_to(asset.resolve()) and path.is_file()
        mesh=trimesh.load(path,force='mesh')
        assert mesh.is_convex and mesh.is_watertight and mesh.volume>0
        collision_checks.append({'path':str(path.relative_to(asset)), 'vertices':len(mesh.vertices),'convex':True})
    for node in link.findall('visual'):
        mesh=trimesh.load(asset/node.find('geometry/mesh').get('filename'),force='mesh')
        mesh.apply_transform(poses[link.get('name')]@origin(node.find('origin')))
        visuals.append((link.get('name'),mesh))
bounds=trimesh.util.concatenate([m for _,m in visuals]).bounds
raw_bbox=json.loads((asset/'bounding_box.json').read_text())
metadata=json.loads((ROOT/'faucet_148_metadata.json').read_text())
# Use actual zero-configuration URDF geometry bounds, in the articulation root frame.
# The supplied raw bounding_box.json uses a different coordinate convention.
metadata['148']['bbox']={'min':bounds[0].tolist(),'max':bounds[1].tolist()}
(ROOT/'faucet_148_metadata.json').write_text(json.dumps(metadata,indent=2))
active=[j for j in joints if j.get('type')!='fixed']
assert len(active)==1 and active[0].get('type')=='revolute'
assert active[0].find('child').get('link')=='link_0'
limits=active[0].find('limit')
assert float(limits.get('lower'))<float(limits.get('upper'))
result={'cpu_checks_passed':True,'convex_collisions':len(collision_checks),
 'active_joint':active[0].get('name'),'switch_link':'link_0',
 'joint_limits':[float(limits.get('lower')),float(limits.get('upper'))],
 'zero_qpos_root_frame_bbox':bounds.tolist(),'raw_archive_bbox':raw_bbox,
 'normalized_max_extent_m':0.3,'simulator_validated':False,'checkpoint_validated':False,
 'gpu_evaluation_performed':False,'collisions':collision_checks}
(ROOT/'faucet_148_cpu_checks.json').write_text(json.dumps(result,indent=2))
try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from mpl_toolkits.mplot3d.art3d import Poly3DCollection
    fig=plt.figure(figsize=(8,7));ax=fig.add_subplot(projection='3d')
    for name,mesh in visuals:
        ax.add_collection3d(Poly3DCollection(mesh.triangles,facecolor='#ed9437' if name=='link_0' else '#729bbd',edgecolor='none',alpha=0.95))
    joint=active[0];jp=poses[joint.find('parent').get('link')]@origin(joint.find('origin'))
    axis=jp[:3,:3]@np.fromstring(joint.find('axis').get('xyz'),sep=' ')
    ax.quiver(*jp[:3,3],*axis,length=float(np.ptp(bounds,axis=0).max())*0.3,color='#d22f3f',linewidth=3)
    ax.auto_scale_xyz(*bounds.T);ax.set_box_aspect(np.maximum(np.ptp(bounds,axis=0),0.01))
    ax.set(xlabel='X',ylabel='Y',zlabel='Z',title='Raw Faucet 148: orange switch and red joint axis\nCPU geometry preview; simulator evaluation pending')
    fig.tight_layout();fig.savefig(ROOT/'faucet_148_geometry.png',dpi=170);plt.close(fig)
except ImportError:
    result['preview']='matplotlib unavailable'
print(json.dumps({k:v for k,v in result.items() if k!='collisions'},indent=2))
