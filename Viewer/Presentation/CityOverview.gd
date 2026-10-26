extends RefCounted
# Distant, explicitly simplified city massing. Exact source anchors/elevations;
# close inspection continues to use the shared detailed reconstruction.
static func shape(source: Dictionary,metadata: Dictionary) -> Dictionary:
 var name_text := str(metadata.get("name","")).to_lower()
 if "roof" in name_text or "shingle" in name_text:
  return {"kind":"roof","size":Vector3(1.02,0.12,1.02),"color":Color("716557")}
 if "wall" in name_text or name_text=="window" or name_text=="archway":
  return {"kind":"wall","size":Vector3(0.98,maxf(0.1,float(metadata.get("height",0))*0.2),0.98),"color":Color("c4baa2")}
 if "tree" in name_text or "sapling" in name_text:
  return {"kind":"tree","size":Vector3(1,1,1),"color":Color("38694a")}
 return {}
func build(data: RefCounted,material: ShaderMaterial,trees_only: bool=false) -> Node3D:
 var root := Node3D.new()
 root.name="SimplifiedCityMassing"
 var batches := {"roof":[],"wall":[],"tree":[]}
 for entry in data.manifest.chunks:
  var source: Dictionary=data.chunk(Vector2i(int(entry.x),int(entry.y)))
  for tile in source.get("statics",[]):
   var plan:=shape(tile,data.manifest.staticData.get(str(int(tile.id)),{}))
   if not plan.is_empty() and (not trees_only or plan.kind=="tree"): batches[plan.kind].append({"tile":tile,"plan":plan})
 if trees_only:
  root.free()
  return tree_forest(batches.tree)
 var total:=0
 for kind in batches:
  var records: Array=batches[kind]
  if records.is_empty(): continue
  var instance:=MultiMeshInstance3D.new()
  instance.multimesh=MultiMesh.new()
  instance.multimesh.transform_format=MultiMesh.TRANSFORM_3D
  instance.multimesh.use_colors=true
  if kind=="tree":
   var cone:=CylinderMesh.new()
   cone.top_radius=0.15;cone.bottom_radius=1.5;cone.height=5;cone.radial_segments=6
   instance.multimesh.mesh=cone
  else: instance.multimesh.mesh=BoxMesh.new()
  instance.multimesh.instance_count=records.size()
  for i in records.size():
   var record: Dictionary=records[i]
   var size: Vector3=record.plan.size
   var origin:=Vector3(record.tile.x+0.5,float(record.tile.z)*0.2+size.y/2,record.tile.y+0.5)
   if kind=="tree": origin.y+=2.0
   instance.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(size),origin))
   instance.multimesh.set_instance_color(i,record.plan.color.srgb_to_linear())
  instance.material_override=material
  root.add_child(instance)
  total+=records.size()
 root.set_meta("features",total)
 print("CITY MASSING: ",total," simplified architectural/tree records")
 return root

func collect_meshes(node:Node3D,parent:Transform3D,out:Array)->void:
 var transform:=parent*node.transform
 if node is MeshInstance3D:out.append({"node":node,"transform":transform})
 for child in node.get_children():
  if child is Node3D:collect_meshes(child,transform,out)
func tree_forest(records:Array)->Node3D:
 var root:=Node3D.new();root.name="CityAssetForest"
 var recon:=preload("res://Presentation/Reconstruction.gd").new()
 recon.source_origin=Vector2.ZERO
 var model:Node3D=recon.fitted("Nature/CommonTree_3.gltf",Vector3(3.2,5.8,3.2))
 var parts:Array=[];collect_meshes(model,Transform3D.IDENTITY,parts)
 var masks:Array=[]
 var sources:Dictionary={}
 for record in records:
  var key:=preload("res://Presentation/RegionalContext.gd").owner(record.tile)
  if not sources.has(key):sources[key]=[]
  sources[key].append(record.tile)
 for part in parts:
  var mesh:Mesh=part.node.mesh.duplicate()
  for surface in mesh.get_surface_count():
   var original:Material=part.node.get_active_material(surface)
   var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/FarCity.gdshader")
   var texture:Texture2D
   var tint:=Color.WHITE
   if original is ShaderMaterial:
    var value:Variant=original.get_shader_parameter("source_texture")
    if value is Texture2D:texture=value
    value=original.get_shader_parameter("tint")
    if value is Color:tint=value
   elif original is StandardMaterial3D:texture=original.albedo_texture;tint=original.albedo_color
   material.set_shader_parameter("surface_albedo",texture)
   material.set_shader_parameter("has_texture",texture!=null)
   material.set_shader_parameter("local_uv",true)
   material.set_shader_parameter("palette",tint)
   mesh.surface_set_material(surface,material)
   masks.append(material)
  for key in sources:
   var trees:Array=sources[key]
   var node:=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new()
   node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
   node.multimesh.use_custom_data=true
   node.multimesh.mesh=mesh
   node.multimesh.instance_count=trees.size()
   node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   node.lod_bias=0.15
   for i in trees.size():
    var tile:Dictionary=trees[i]
    var transform:=Transform3D(Basis(Vector3.UP,fmod(float(int(tile.x)*17+int(tile.y)*31),TAU)),Vector3(tile.x+0.5,float(tile.z)*0.2,tile.y+0.5))
    node.multimesh.set_instance_transform(i,transform*part.transform)
    node.multimesh.set_instance_custom_data(i,Color(key.x,key.y,0,0))
   root.add_child(node)
 model.free()
 root.set_meta("mask_materials",masks)
 print("CITY ASSET FOREST: ",records.size()," source trees / ",sources.size()," bounded instance batches")
 return root
