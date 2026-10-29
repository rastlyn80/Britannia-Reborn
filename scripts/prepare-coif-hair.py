"""Small depth-tested coif tail derivatives of the accepted CC0 fitted hair."""
import bpy,json,hashlib
from pathlib import Path
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[1]
for female in [False,True]:
 art=ROOT/('Viewer/local-art/free-equipment-female' if female else 'Viewer/local-art/free-equipment');report=json.loads((art/'expansion/provenance.json').read_text())
 for style in ['long','ponytail']:
  for variant in ['covered','covered_cloak']:
   source=art/'expansion'/('hair_'+style+'_'+variant+'.glb');bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(source))
   rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');ob=next(o for o in bpy.data.objects if o.type=='MESH');T=rig.matrix_world.inverted()@ob.matrix_world;head=rig.data.bones['head'].head_local.z
   for vertex in ob.data.vertices:
    p=T@vertex.co;amount=max(0.,min(1.,(head+.055-p.z)/.08))
    if p.y>-.015:p.y+=.022*amount
    vertex.co=T.inverted()@p
   name='hair_'+style+'_'+variant+'_coif';ob.name='Extra_'+name
   bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);ob.select_set(True);bpy.context.view_layer.objects.active=rig
   path=art/'expansion'/(name+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_morph=False,export_tangents=True)
   report['parts'][name]={'source_part':source.stem,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'licence':'CC0-1.0','recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'max_back_clearance_m':.022,'scope':'Posterior tails below ear level only; original scalp trim, UV/alpha and skin bindings retained.'}
 (art/'expansion/provenance.json').write_text(json.dumps(report,indent=2));print('COIF HAIR READY',female)
