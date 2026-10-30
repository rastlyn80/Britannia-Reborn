"""Matched-cloth workwear; no body triangles, transferred weights or pose pushes.

Run in the pinned Blender. Inputs and generated art remain local; the manifest
traces the CC0 clothing foundation and materials through their existing notices.
"""
import bpy, json, hashlib, sys
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector

ROOT=Path(__file__).resolve().parents[1]
FEMALE='--female' in sys.argv
ART=ROOT/('Viewer/local-art/free-equipment-female' if FEMALE else 'Viewer/local-art/free-equipment')
OUT=ART/'coverage';TMP=ROOT/'work/human-workwear';TMP.mkdir(parents=True,exist_ok=True)
PINS=json.loads((ROOT/'scripts/human-workwear-inputs.json').read_text(encoding='utf-8'))
for name,digest in PINS['files'].items():
 assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def load(path):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));return set(bpy.data.objects)-before
base=load(ART/'equipment-base.glb');rig=next(o for o in base if o.type=='ARMATURE')
rig.animation_data_clear()
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
sources={}
for key,file in [('shirt','expansion/shirt.glb'),('plate','coverage/plate_torso.glb')]:
 objects=load(ART/file);ob=next(o for o in objects if o.type=='MESH' and o.name.startswith(('Extra_','Free_')))
 src_rig=next(o for o in objects if o.type=='ARMATURE')
 assert set(b.name for b in src_rig.data.bones)==set(b.name for b in rig.data.bones)
 transform=src_rig.matrix_world.inverted()@ob.matrix_world
 assert all(abs(transform[i][j]-(1 if i==j else 0))<1e-5 for i in range(4) for j in range(4))
 sources[key]=ob
 for extra in objects:
  if extra!=ob:bpy.data.objects.remove(extra,do_unlink=True)
r=rig.data.bones['head'].head_local.z/1.5793484
linen=bpy.data.images.load(str(ROOT/'Viewer/Art/MedievalKit/textures/Linen_Color.jpg'))
lw,lh=linen.size;lp=np.array(linen.pixels[:],dtype=np.float32).reshape(lh,lw,4)
normal=bpy.data.images.load(str(ROOT/'Viewer/Art/MedievalKit/textures/Fabric045_2K-JPG_NormalGL.jpg'));normal.colorspace_settings.name='Non-Color'
N=1024
z0,z1=.48,1.55;x0,x1=-.36,.36
u,v=np.meshgrid((np.arange(N)+.5)/N,(np.arange(N)+.5)/N)
x=x0+u*(x1-x0);z=z0+v*(z1-z0)

def stencil(key,component,armoured):
 # A single continuous loop around shoulder/torso. The rigid plate version
 # closes above the articulated faulds; their overlap is not a cloth surface.
 if armoured:
  centre=.235-(z-1.10)*1.085
  return (np.abs(x-centre)<.040)&(z>1.06)&(z<1.53)
 centre=.16-(z-1.015)*.735
 return (np.abs(x-centre)<.040)&(z>1.005)&(z<1.48)

def material(key,component,armoured):
 mask=stencil(key,component,armoured)
 # An authored, binary edge stencil on actual skinned cloth. Linen retains its
 # physical weave; the narrow lighter hem is a stitched edge, not specular trim.
 rgba=lp[((v*5*lh).astype(int)%lh),((u*3*lw).astype(int)%lw)].copy()
 rgba[:,:,:3]*=.85
 eroded=mask.copy()
 for dy,dx in [(-3,0),(3,0),(0,-3),(0,3)]:eroded&=np.roll(mask,(dy,dx),(0,1))
 edge=mask&~eroded;rgba[edge,:3]*=.72
 rgba[:,:,3]=mask
 image=bpy.data.images.new('Workwear '+key+' '+component,N,N,alpha=True)
 image.pixels.foreach_set(rgba.ravel());image.filepath_raw=str(TMP/(('female-' if FEMALE else 'male-')+key+'-'+component+'.png'));image.file_format='PNG';image.save()
 mat=bpy.data.materials.new('Workwear_'+key+'_'+component);mat.use_nodes=True;mat.use_backface_culling=False
 mat.surface_render_method='DITHERED';nodes=mat.node_tree.nodes;links=mat.node_tree.links;s=nodes.get('Principled BSDF')
 s.inputs['Roughness'].default_value=.93;s.inputs['Specular IOR Level'].default_value=.2
 t=nodes.new('ShaderNodeTexImage');t.image=image;colour_texture=t;links.new(t.outputs['Color'],s.inputs['Base Color'])
 t=nodes.new('ShaderNodeTexImage');t.image=normal
 nm=nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.18;links.new(t.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],s.inputs['Normal'])
 # Explicit glTF alpha MASK (Blender 5 uses a threshold math node).
 threshold=nodes.new('ShaderNodeMath');threshold.operation='GREATER_THAN';threshold.inputs[1].default_value=.5;links.new(colour_texture.outputs['Alpha'],threshold.inputs[0]);links.new(threshold.outputs[0],s.inputs['Alpha'])
 return mat

records={}
for key in ['body_sash']:
 for armoured in [False,True]:
  name=key+('_armour' if armoured else '')
  verts=[];faces=[];weights=[];uvs=[];mi=[];mats=[];origins=[];source_faces=[]
  parts=[('plate' if armoured else 'shirt','front'),('plate' if armoured else 'shirt','back')]
  for source,component in parts:
   ob=sources[source];material_index=len(mats);mats.append(material(key,component,armoured));used={}
   # Retain source triangles and weights verbatim, including shoulder blends.
   # Alpha stencils trim the outline without synthesizing differently skinned
   # intersection vertices along that outline.
   for poly in ob.data.polygons:
    points=[ob.data.vertices[i].co for i in poly.vertices];centre=sum(points,points[0]*0)/len(points)
    if max(p.z/r for p in points)<.98:continue
    if min(p.z/r for p in points)> 1.51:continue
    if min(abs(p.x/r) for p in points)>.31:continue
    # Clothing hems and manufactured plates contain inner surfaces.
    # Copy the outside only; a duplicated inner wall is not an outer overlay.
    if source=='plate' and ob.data.materials[poly.material_index].name.startswith('Armour_Lining'):continue
    if key=='body_sash' and armoured and not all(sum(g.weight for g in ob.data.vertices[i].groups if ob.vertex_groups[g.group].name=='spine_03')>.999 for i in poly.vertices):continue
    radial=Vector((centre.x,centre.y+.02*r,0))
    if radial.length>.01 and poly.normal.dot(radial.normalized())<.08 and not (centre.z/r>1.42 and poly.normal.z>.35):continue
    front=centre.y<-.02*r
    if component=='front' and not front:continue
    if component=='back' and front:continue
    indices=[]
    for i in poly.vertices:
     if i not in used:
      vertex=ob.data.vertices[i];p=vertex.co.copy()
      # Offset along the shared vertex normal; tiny outward Y bias prevents
      # facing reversals on deep folds, without ballooning the garment.
      direction=Vector((p.x*.2,(-.10 if front else .10)*r,0))
      if p.z/r>1.42:direction.z=max(0.,vertex.normal.z)*.06*r
      offset=direction.normalized()*(.028 if source=='plate' else .020)*r
      used[i]=len(verts);verts.append(p+offset)
      weights.append({ob.vertex_groups[g.group].name:g.weight for g in vertex.groups})
      uvs.append(((p.x/r-x0)/(x1-x0),(p.z/r-z0)/(z1-z0)))
      origins.append([source,i,component])
     indices.append(used[i])
    faces.append(indices);mi.append(material_index);source_faces.append([source,poly.index])
  data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update();out=bpy.data.objects.new('Extra_'+name,data);bpy.context.collection.objects.link(out)
  for mat in mats:data.materials.append(mat)
  uv=data.uv_layers.new(name='UVMap')
  for poly,index in zip(data.polygons,mi):
   poly.material_index=index;poly.use_smooth=True
   for li in poly.loop_indices:uv.data[li].uv=uvs[data.loops[li].vertex_index]
  for bone in sorted({n for w in weights for n in w}):out.vertex_groups.new(name=bone)
  for i,w in enumerate(weights):
   for bone,weight in w.items():out.vertex_groups[bone].add([i],weight,'REPLACE')
  mod=out.modifiers.new('Matched original cloth weights','ARMATURE');mod.object=rig;out.parent=rig;out.matrix_parent_inverse=Matrix.Identity(4);out.matrix_basis=Matrix.Identity(4)
  bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);out.select_set(True);bpy.context.view_layer.objects.active=rig
  path=OUT/(name+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_morph=False,export_tangents=True)
  records[name]={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'vertices':len(verts),'polygons':len(faces),'kind':'workwear','source':'Matched pinned CC0 shirt topology; original alpha stencil and offsets; armour-fit uses existing original rigid plate topology','recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
  (TMP/(('female-' if FEMALE else 'male-')+name+'-topology.json')).write_text(json.dumps({'export_scale':rig.matrix_world.to_scale().x,'positions':[list(v) for v in verts],'source_positions':[list(sources[src].data.vertices[i].co) for src,i,component in origins],'vertices':origins,'weights':weights,'uvs':uvs,'faces':faces,'material_indices':mi,'source_faces':source_faces}))
  bpy.data.objects.remove(out,do_unlink=True)
evidence=json.loads((OUT/'provenance.json').read_text(encoding='utf-8'));evidence['parts'].update(records);(OUT/'provenance.json').write_text(json.dumps(evidence,indent=2))
print('WORKWEAR READY',FEMALE,len(records))
