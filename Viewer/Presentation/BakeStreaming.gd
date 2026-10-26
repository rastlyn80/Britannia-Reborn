extends SceneTree
const Prepared = preload("res://Presentation/PreparedDistrict.gd")
const Compact = preload("res://Presentation/CompactDistrict.gd")
const Rules = preload("res://Presentation/RegionalBake.gd")
var directory := "res://../outputs/britain"
var signature := ""
var output := ""

static func dependency_signature(path: String, visited: Dictionary) -> String:
 if visited.has(path):return ""
 visited[path]=true
 var signature:=path+FileAccess.get_sha256(path)
 # Follow source-owned rule/shader dependencies, including collision builders.
 # New shared-rule edits must invalidate old geometry without a hand-maintained
 # list silently omitting a newly introduced helper.
 var pattern:=RegEx.new()
 pattern.compile('res://Presentation/[A-Za-z0-9_./-]+\\.(?:gdshader|gd|json)')
 for hit in pattern.search_all(FileAccess.get_file_as_string(path)):
  var dependency:=hit.get_string()
  if FileAccess.file_exists(dependency):signature+=dependency_signature(dependency,visited)
 return signature

func _initialize() -> void: call_deferred("run")
func save_scene(node: Node3D, path: String, data: Resource = null) -> void:
 Compact.own(node,node)
 var packed := PackedScene.new()
 assert(packed.pack(node)==OK)
 if data==null: data=Prepared.new()
 data.scene=packed
 for child in node.get_children():
  child.owner=null
  Compact.own(child,child)
  var part:=PackedScene.new()
  assert(part.pack(child)==OK)
  data.parts.append(part)
  node.remove_child(child)
  child.free()
 var empty:=PackedScene.new()
 assert(empty.pack(node)==OK)
 data.root_scene=empty
 var temporary := path.get_basename()+".pending.res"
 assert(ResourceSaver.save(data,temporary,ResourceSaver.FLAG_COMPRESS)==OK,"Prepared resource save failed")
 assert(DirAccess.rename_absolute(temporary,path)==OK,"Prepared resource installation failed")

func far_material(original: Material, frame: Vector2) -> ShaderMaterial:
 var material := ShaderMaterial.new()
 material.shader=preload("res://Presentation/FarCity.gdshader")
 var color:=Color("aa9f88")
 var texture: Texture2D
 var scale:=Vector2.ONE
 if original is ShaderMaterial:
  for field in ["palette","roof_color","base_color"]:
   var value: Variant=original.get_shader_parameter(field)
   if value is Color: color=value;break
  var value: Variant=original.get_shader_parameter("surface_albedo")
  if value is Texture2D: texture=value
  value=original.get_shader_parameter("surface_scale")
  if value is Vector2: scale=value
 elif original is StandardMaterial3D:
  color=original.albedo_color
  texture=original.albedo_texture
 material.set_shader_parameter("palette",color)
 material.set_shader_parameter("surface_albedo",texture)
 material.set_shader_parameter("surface_scale",scale)
 material.set_shader_parameter("has_texture",texture!=null)
 material.set_shader_parameter("source_origin",frame)
 return material

func make_far(near: Node3D, sources: Array, frame: Vector2, catalog: Dictionary) -> Node3D:
 var result := Node3D.new()
 for node in near.get_children():
  if not node is MeshInstance3D or not node.get_meta("distant",false): continue
  var mesh := MeshInstance3D.new()
  mesh.mesh=node.mesh
  mesh.transform=node.transform
  mesh.material_override=far_material(node.material_override,frame)
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  result.add_child(mesh)
 var trees: Array=[]
 for source in sources:
  if catalog.get(str(int(source.id)),{}).get("kind","")=="tree": trees.append({"tile":source})
 if not trees.is_empty():
  var recon:=preload("res://Presentation/Reconstruction.gd").new()
  var model: Node3D=recon.fitted("Nature/CommonTree_3.gltf",Vector3(3.2,5.8,3.2))
  var parts: Array=[]
  preload("res://Presentation/CityOverview.gd").new().collect_meshes(model,Transform3D.IDENTITY,parts)
  for part in parts:
   var instance:=preload("res://Presentation/InstancedPatch.gd").new()
   instance.source_mesh=part.node.mesh
   var original: Material=part.node.get_active_material(0)
   var material:=far_material(original,frame)
   material.set_shader_parameter("local_uv",true)
   if original is ShaderMaterial:
    material.set_shader_parameter("surface_albedo",original.get_shader_parameter("source_texture"))
    material.set_shader_parameter("has_texture",true)
    material.set_shader_parameter("palette",original.get_shader_parameter("tint"))
   instance.material_override=material
   instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   instance.lod_bias=0.15
   var transforms: Array=[]
   for record in trees:
    var tile: Dictionary=record.tile
    transforms.append(Transform3D(Basis(Vector3.UP,fmod(float(int(tile.x)*17+int(tile.y)*31),TAU)),Vector3(tile.x-frame.x+0.5,float(tile.z)*0.2,tile.y-frame.y+0.5))*part.transform)
   instance.instance_data=preload("res://Presentation/InstancedPatch.gd").encode(transforms)
   var box: AABB=transforms[0]*instance.source_mesh.get_aabb()
   for transform in transforms:box=box.merge(transform*instance.source_mesh.get_aabb())
   instance.baked_bounds=box.grow(0.25)
   result.add_child(instance)
  model.free()
 return result

func macros(data: RefCounted, frame: Vector2) -> Array:
 var mesh: ArrayMesh=preload("res://Presentation/AtlasGeometry.gd").build(data)
 var arrays:=mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
 var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var batches: Dictionary={}
 for i in range(0,indices.size(),3):
  var a:=vertices[indices[i]]
  var b:=vertices[indices[i+1]]
  var c:=vertices[indices[i+2]]
  var at:=Vector2i(floori(minf(a.x,minf(b.x,c.x))/256)*256,floori(minf(a.z,minf(b.z,c.z))/256)*256)
  if not batches.has(at):
   var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);batches[at]=tool
  for j in 3:
   var index:=indices[i+j]
   batches[at].set_normal(normals[index])
   batches[at].set_color(colors[index])
   batches[at].add_vertex(vertices[index]-Vector3(frame.x,0,frame.y))
 var entries: Array=[]
 for at in batches:
  var root:=Node3D.new()
  var node:=MeshInstance3D.new()
  node.mesh=batches[at].commit()
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/AtlasGround.gdshader")
  material.set_shader_parameter("source_origin",frame)
  node.material_override=material
  root.add_child(node)
  save_scene(root,output.path_join("macro_%d_%d.res" % [at.x,at.y]))
  root.free()
  entries.append([at.x,at.y])
 return entries

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--dataset="): directory=arg.substr(10)
 directory=ProjectSettings.globalize_path(directory)
 # A bake with a missing (e.g. not yet imported) surface would be stamped as
 # current and silently keep blank materials; refuse it instead.
 var surfaces: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Art/Surfaces/manifest.json"))
 for entry in surfaces.sets:
  for map in entry.maps:
   if not ResourceLoader.exists("res://Art/Surfaces/"+str(map.file)):
    push_error("Surface texture is not imported: "+str(map.file)+". Run the Godot import (scripts/verify.ps1) first.");quit(1);return
 signature=Rules.fingerprint(directory)
 signature+=dependency_signature("res://Presentation/BakeStreaming.gd",{})
 signature=signature.sha256_text()
 output=directory.path_join("prepared")
 DirAccess.make_dir_recursive_absolute(output)
 var index_path:=output.path_join("index.json")
 if FileAccess.file_exists(index_path):
  var previous: Variant=JSON.parse_string(FileAccess.get_file_as_string(index_path))
  if previous is Dictionary and previous.get("signature","")==signature:
   var complete:=true
   for at in previous.chunks:
    for prefix in ["near","far"]:
     if not FileAccess.file_exists(output.path_join("%s_%d_%d.res" % [prefix,at[0],at[1]])): complete=false
   for at in previous.macros:
    if not FileAccess.file_exists(output.path_join("macro_%d_%d.res" % [at[0],at[1]])):complete=false
   if complete: print("STREAM BAKE: current");quit();return
 # A published index is the commit marker; never mix resources from two bakes.
 if FileAccess.file_exists(index_path): DirAccess.rename_absolute(index_path,index_path+".previous")
 var data:=preload("res://Presentation/AtlasData.gd").new()
 if not data.open(directory.path_join("atlas.json")): push_error("Missing owned atlas data");quit(1);return
 if data.manifest.chunks.size()>128:
  push_error("Runtime streaming is bounded, but offline joined-topology planning is currently limited to 128 chunks. Prepare a city dataset; full-facet offline partitioning remains pending.");quit(1);return
 var plan:=preload("res://Presentation/RegionalContext.gd").new()
 plan.prepare(data)
 var frame:=Vector2(plan.world.originX,plan.world.originY)
 plan.reconstruction.source_origin=frame
 preload("res://Presentation/SurfaceLibrary.gd").source_origin=frame
 plan.terrain_material.set_shader_parameter("source_origin",frame)
 var entries: Array=[]
 for entry in data.manifest.chunks:
  var at:=Vector2i(entry.x,entry.y)
  var tag:="%d_%d" % [at.x,at.y]
  var stamp:=output.path_join(tag+".stamp")
  if not FileAccess.file_exists(stamp) or FileAccess.get_file_as_string(stamp)!=signature:
   var near: Node3D=await plan.build_chunk(at,self,true)
   near.position=Vector3.ZERO
   var source: Dictionary=data.chunk(at)
   var far:=make_far(near,source.statics,frame,plan.reconstruction.catalog)
   save_scene(far,output.path_join("far_"+tag+".res"))
   far.free()
   Compact.new().apply(near)
   var resource:=Prepared.new();resource.origin=at
   for tile in source.terrain: resource.land.append_array(PackedInt32Array([tile.id,tile.z]))
   for tile in source.statics: resource.statics.append_array(PackedInt32Array([tile.id,(int(tile.x)-at.x)|((int(tile.y)-at.y)<<6),tile.z,tile.hue]))
   save_scene(near,output.path_join("near_"+tag+".res"),resource)
   print("STREAM BAKE: ",at," / ",resource.parts.size()," compact parts / ",near.get_meta("collision_triangles",0)," collision triangles")
   near.free()
   var marker:=FileAccess.open(stamp,FileAccess.WRITE);marker.store_string(signature);marker.close()
  entries.append([at.x,at.y])
  await process_frame
 var manifest: Dictionary=data.manifest
 var index: Dictionary={"schema":1,"signature":signature,"facet":1,"originX":manifest.originX,"originY":manifest.originY,"width":manifest.width,"height":manifest.height,"landData":manifest.landData,"staticData":manifest.staticData,"catalog":plan.reconstruction.catalog,"chunks":entries,"macros":macros(data,frame)}
 var file:=FileAccess.open(index_path+".pending",FileAccess.WRITE);file.store_string(JSON.stringify(index));file.close()
 assert(DirAccess.rename_absolute(index_path+".pending",index_path)==OK)
 print("STREAM BAKE COMPLETE: ",entries.size()," independent districts; shared source topology / compact scenes / collision / regional horizons")
 quit()
