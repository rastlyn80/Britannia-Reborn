"""Tailored split riding panels on the existing traced CC0 upper garments.

Bodices/sleeves/materials/UVs are preserved. Authored lower panels follow the
actual thigh/calf bones, leaving the horse between them. Originals are unchanged.
"""
import bpy,bmesh,json,hashlib,math
from collections import Counter
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
pins=json.loads((ROOT/'scripts/horse-riding-inputs.json').read_text())
for name,digest in pins['files'].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
for female in [False,True]:
 art=ROOT/('Viewer/local-art/free-equipment-female' if female else 'Viewer/local-art/free-equipment');out=art/'riding';out.mkdir(exist_ok=True)
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(art/'equipment-base.glb'))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');body=next(o for o in bpy.data.objects if o.name=='Body');rig.animation_data_clear()
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 T=rig.matrix_world.inverted()@body.matrix_world;points=[T@v.co for v in body.data.vertices];body.data.calc_loop_triangles()
 waist=rig.data.bones['pelvis'].head_local.z+.02;ratio=rig.data.bones['head'].head_local.z/1.5793484
 lower={v.index for v in body.data.vertices if any(body.vertex_groups[g.group].name.startswith(('thigh','calf','foot','pelvis')) and g.weight>.1 for g in v.groups) and points[v.index].z<waist+.15}
 trees={}
 for side in [-1,1]:
  faces=[tuple(t.vertices) for t in body.data.loop_triangles if all(i in lower and points[i].x*side>=-.015 for i in t.vertices)]
  trees[side]=(BVHTree.FromPolygons(points,faces,all_triangles=True),faces)
 records=[]
 for name in ['robe','skirt','kilt']:
  path=art/('runtime/part-robe.glb' if name=='robe' else 'expansion/'+name+'.glb')
  before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));added=set(bpy.data.objects)-before
  ob=next(o for o in added if o.type=='MESH' and o.name.startswith(('Free_','Extra_')))
  T=rig.matrix_world.inverted()@ob.matrix_world;coords=[T@v.co for v in ob.data.vertices];ob.parent=None;ob.matrix_world=Matrix.Identity(4)
  for v,co in zip(ob.data.vertices,coords):v.co=co
  fabric=Counter(p.material_index for p in ob.data.polygons).most_common(1)[0][0]
  bm=bmesh.new();bm.from_mesh(ob.data);groups=bm.verts.layers.deform.active
  def sleeve(v):return groups and any(ob.vertex_groups[i].name.startswith(('upperarm','lowerarm','hand','clavicle')) and w>.05 for i,w in v[groups].items())
  torso=[f for f in bm.faces if not any(sleeve(v) for v in f.verts)]
  geometry=set(torso)|{e for f in torso for e in f.edges}|{v for f in torso for v in f.verts}
  # A clean cut avoids leaving isolated original rope-belt triangles at the
  # seam. Sleeve geometry below waist height is deliberately excluded.
  bmesh.ops.bisect_plane(bm,geom=list(geometry),plane_co=(0,0,waist+.09),plane_no=(0,0,1),clear_inner=True,clear_outer=False)
  bm.to_mesh(ob.data);bm.free()
  for vertex in ob.data.vertices:
   replacements=[(g.group,g.weight) for g in vertex.groups if ob.vertex_groups[g.group].name.startswith('robe_')]
   if replacements:
    amount=sum(w for _,w in replacements)
    for index,_ in replacements:ob.vertex_groups[index].remove([vertex.index])
    pelvis=ob.vertex_groups.get('pelvis') or ob.vertex_groups.new(name='pelvis');pelvis.add([vertex.index],amount,'ADD')
  panel=bpy.data.meshes.new('Tailored_riding_panels');verts=[];faces=[];skin=[];uvs=[];steps=24
  hem=(.28 if name=='robe' else .42 if name=='skirt' else .62)*ratio
  levels=[waist+.14,waist+.015,waist-.10]+[waist-.10+(hem-(waist-.10))*i/6 for i in range(1,7)]
  for side in [-1,1]:
   start=len(verts);tree,refs=trees[side]
   for j,z in enumerate(levels):
    near=[p for i,p in enumerate(points) if i in lower and p.x*side>.015 and abs(p.z-z)<.055*ratio]
    centre=Vector((side*.11*ratio,0,z))
    if near:centre.x=(min(p.x for p in near)+max(p.x for p in near))*.5;centre.y=(min(p.y for p in near)+max(p.y for p in near))*.5
    ease=(.035+.015*j/(len(levels)-1))*ratio
    rx=max([abs(p.x-centre.x) for p in near]+[.045*ratio])+ease
    ry=max([abs(p.y-centre.y) for p in near]+[.045*ratio])+ease
    if j<2:
     # Both side panels meet as one waist, rather than two separate tubes.
     seam=[p for p in points if abs(p.z-z)<.06*ratio and abs(p.x)<.26*ratio]
     centre.x=0.;centre.y=0.
     rx=(.182 if j==0 else .205)*ratio
     ry=(.115 if j==0 else .140)*ratio
    for i in range(steps+1):
     angle=-1.69+3.38*i/steps
     fold=1.+.025*math.sin(angle*6.)*j/(len(levels)-1)
     co=centre+Vector((side*rx*math.cos(angle)*fold,ry*math.sin(angle)*fold,0));verts.append(co)
     point,normal,face,distance=tree.find_nearest(co);weights={}
     if j==1:weights={'pelvis':1.}
     else:
      ids=refs[face];factors=[1/max((points[k]-point).length,.0001)**2 for k in ids];total=sum(factors)
      for k,factor in zip(ids,factors):
       for g in body.data.vertices[k].groups:
        bone=body.vertex_groups[g.group].name;weights[bone]=weights.get(bone,0.)+g.weight*factor/total
     chosen=sorted(weights.items(),key=lambda p:-p[1])[:4];total=sum(w for _,w in chosen);skin.append({b:w/total for b,w in chosen});uvs.append((i/steps*2.,(z-hem)*3.))
   for j in range(len(levels)-1):
    for i in range(steps):
     a=start+j*(steps+1)+i;b=a+1;face=(a,b,b+steps+1,a+steps+1);faces.append(face if side>0 else tuple(reversed(face)))
  panel.from_pydata(verts,[],faces);panel.update();part=bpy.data.objects.new('Riding_panels',panel);bpy.context.collection.objects.link(part)
  # The original atlas contains belts and trim. New panel UVs need a tileable
  # traced cloth material, rather than accidentally repeating that atlas.
  cloth=bpy.data.materials.new('Riding_woven_cloth');cloth.use_nodes=True;n=cloth.node_tree.nodes;l=cloth.node_tree.links;s=n.get('Principled BSDF');s.inputs['Roughness'].default_value=.9
  tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'Viewer/Art/MedievalKit/textures/Linen_Color.jpg'),check_existing=True)
  tint=n.new('ShaderNodeMixRGB');tint.blend_type='MULTIPLY';tint.inputs[0].default_value=1.;tint.inputs[2].default_value=(.52,.38,.29,1);l.new(tex.outputs['Color'],tint.inputs[1]);l.new(tint.outputs['Color'],s.inputs['Base Color'])
  # Bake only this simple material multiplication for standard glTF export.
  import numpy as np
  source=tex.image;data=np.empty(len(source.pixels),np.float32);source.pixels.foreach_get(data);data=data.reshape(source.size[1],source.size[0],4);data[:,:,:3]*=(.52,.38,.29)
  image=bpy.data.images.new('Riding_brown_linen',source.size[0],source.size[1]);image.pixels.foreach_set(data.ravel());image.filepath_raw=str(ROOT/'work/horse-session/riding-brown-linen.png');image.file_format='PNG';image.save();tex.image=image;l.new(tex.outputs['Color'],s.inputs['Base Color'])
  panel.materials.append(cloth);uv=panel.uv_layers.new(name='UVMap')
  for polygon in panel.polygons:
   polygon.use_smooth=True
   for li in polygon.loop_indices:uv.data[li].uv=uvs[panel.loops[li].vertex_index]
  for bone in sorted({b for row in skin for b in row}):part.vertex_groups.new(name=bone)
  for i,row in enumerate(skin):
   for bone,w in row.items():part.vertex_groups[bone].add([i],w,'REPLACE')
  bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);part.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.join()
  ob.name=('Free_' if name=='robe' else 'Extra_')+'riding_'+name;ob.parent=rig;ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=Matrix.Identity(4)
  for modifier in list(ob.modifiers):ob.modifiers.remove(modifier)
  mod=ob.modifiers.new('Shared native rig','ARMATURE');mod.object=rig
  # Cloth is visible on both faces at a riding slit.
  for material in ob.data.materials:material.use_backface_culling=False
  bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);ob.select_set(True);bpy.context.view_layer.objects.active=rig
  destination=out/(name+'.glb');bpy.ops.export_scene.gltf(filepath=str(destination),export_format='GLB',use_selection=True,export_animations=False,export_morph=False,export_tangents=True)
  records.append({'part':name,'input_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'authored_panel_vertices':len(verts),'license':'CC0-1.0 source upper garment; original authored lower panels'})
  for extra in (added|{ob}) & set(bpy.data.objects):bpy.data.objects.remove(extra,do_unlink=True)
 (out/'provenance.json').write_text(json.dumps({'female':female,'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'parts':records},indent=2))
 print('RIDING CLOTHES',female,len(records),flush=True)
