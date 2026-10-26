"""Build a separate, explicitly custom faucet candidate without changing raw URDF."""
from pathlib import Path
import sys, json, hashlib, xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'vendor'))
import numpy as np
import trimesh
import coacd
from scipy.spatial.transform import Rotation

asset = ROOT / 'asset_candidates' / '148'
tree = ET.parse(asset / 'mobility.urdf')
robot = tree.getroot()
out = asset / 'cvx_objs'
out.mkdir(exist_ok=True)
coacd.set_log_level('warn')
records = []
for link in robot.findall('link'):
    collisions = link.findall('collision')
    if not collisions:
        continue
    meshes = []
    for collision in collisions:
        node = collision.find('geometry/mesh')
        mesh = trimesh.load(asset / node.get('filename'), force='mesh', process=False)
        mesh.apply_scale(np.fromstring(node.get('scale', '1 1 1'), sep=' '))
        origin = collision.find('origin')
        transform = np.eye(4)
        if origin is not None:
            transform[:3,:3] = Rotation.from_euler('xyz', np.fromstring(origin.get('rpy','0 0 0'), sep=' ')).as_matrix()
            transform[:3,3] = np.fromstring(origin.get('xyz','0 0 0'), sep=' ')
        mesh.apply_transform(transform)
        meshes.append(mesh)
    merged = trimesh.util.concatenate(meshes)
    merged.export(out / (link.get('name') + '_source.obj'))
    print('Decomposing', link.get('name'), len(merged.faces), flush=True)
    parts = coacd.run_coacd(coacd.Mesh(merged.vertices, merged.faces), threshold=0.05,
        resolution=2000, mcts_iterations=150, seed=0)
    assert parts, 'No convex parts generated'
    for collision in collisions:
        link.remove(collision)
    for index, (vertices, faces) in enumerate(parts):
        hull = trimesh.Trimesh(vertices, faces, process=True).convex_hull
        assert hull.is_convex and np.isfinite(hull.vertices).all()
        filename = f'cvx_objs/{link.get("name")}_{index:03d}.obj'
        hull.export(asset / filename)
        col = ET.SubElement(link, 'collision')
        geometry = ET.SubElement(col, 'geometry')
        ET.SubElement(geometry, 'mesh', filename=filename)
    records.append({'link':link.get('name'), 'input_faces':len(merged.faces), 'convex_parts':len(parts)})
tree.write(asset / 'mobility_cvx.urdf', encoding='utf-8', xml_declaration=True)
metadata = {'148': {'bbox':json.loads((asset/'bounding_box.json').read_text()),
    'semantics':[line.split() for line in (asset/'semantics.txt').read_text().splitlines() if line.strip()]}}
(ROOT/'faucet_148_metadata.json').write_text(json.dumps(metadata, indent=2))
manifest = {'protocol':'custom fixed raw PartNet-Mobility Faucet 148; not legacy model 5050',
    'collision_method':'CoACD 1.0.14, threshold 0.05, resolution 2000, MCTS iterations 150, seed 0',
    'links':records, 'simulator_validated':False, 'checkpoint_validated':False,
    'gpu_evaluation_performed':False,
    'files':{str(p.relative_to(asset)):hashlib.sha256(p.read_bytes()).hexdigest()
        for p in [asset/'mobility_cvx.urdf',*sorted(out.glob('*.obj'))]}}
(ROOT/'faucet_148_preflight.json').write_text(json.dumps(manifest, indent=2))
print(json.dumps(manifest, indent=2))
