"""Independent full original-FBX skin reference; never runs candidate converter."""
import bpy,hashlib,json,math,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'work/creatures/bogling/source-reference';OUT.mkdir(exist_ok=True)
source=ROOT/'work/creatures/bogling/source/extracted/Treant Package/Treant 2/Tree02_FBX.fbx'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(source),use_image_search=False,automatic_bone_orientation=False)
scene=bpy.context.scene;rig=next(o for o in scene.objects if o.type=='ARMATURE');mesh=next(o for o in scene.objects if o.type=='MESH');fps=scene.render.fps
def points(action,frame):
 rig.animation_data.action=action;scene.frame_set(math.floor(frame),subframe=frame%1);bpy.context.view_layer.update();obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());data=obj.to_mesh();result=[obj.matrix_world@v.co for v in data.vertices];obj.to_mesh_clear();return result
actions=list(bpy.data.actions);idle=next(a for a in actions if a.name.endswith('|Idle'));base=points(idle,1);low=min(p.z for p in base);scale=1.15/(max(p.z for p in base)-low)
mapping={'Attack_1':'Attack','Attack2':'Attack2','Attack3':'Attack3','Death1':'Death','Death2':'Death2','Death3':'Death3','Idle':'Idle','River Dance':'Dance','Run':'SourceRun','Taunt':'Fidget'}
raw=bytearray();samples=[]
for action in actions:
 start,end=map(float,action.frame_range);category=mapping[action.name.split('|')[-1]]
 for step in range(17):
  phase=step/16;worlds=points(action,start+(end-start)*phase);vertices=[(p.x*scale,(p.z-low)*scale,-p.y*scale) for p in worlds];lift=max(0.,-min(p[1] for p in vertices));offset=len(raw)
  for x,y,z in vertices:raw.extend(struct.pack('<3f',x,y+lift,z))
  samples.append({'clip':category,'phase':phase,'duration':(end-start)/fps,'byte_offset':offset,'vertices':len(vertices),'ground_lift':lift})
(OUT/'skins.bin').write_bytes(raw)
report={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'binary_sha256':hashlib.sha256(raw).hexdigest(),'samples':samples,'scope':'Complete original FBX evaluated skins with all original influences, independent of candidate converter; only declared scale/Y-up and negative-floor correction.'}
(OUT/'reference.json').write_text(json.dumps(report,indent=2)+'\n');print('ORIGINAL SOURCE REFERENCE',len(samples),'complete skins',len(raw),'bytes')
