extends SceneTree
const Prepared = preload("res://Presentation/PreparedDistrict.gd")
const Compact = preload("res://Presentation/CompactDistrict.gd")
const Rules = preload("res://Presentation/RegionalBake.gd")
var directory := "res://../outputs/britain"
var signature := ""
var output := ""
# Published file name -> the file actually written, when a running client held
# the published one open (live reload after a developer Commit).
var alternates: Dictionary = {}

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
# Shared model library (docs/COMPACT_STREAMING.md): every sizeable mesh is
# saved once per prepared cache under models/<content hash>.res and districts
# reference it, instead of each district embedding its own copy.
const LIBRARY_MIN_VERTICES := 300
var library_paths: Dictionary = {}
var window := Rect2i()
var dataset_origin := Vector2(-1,-1)
var window_offset := Vector3.ZERO
var finalize := false
func share_meshes(node: Node) -> void:
 var all: Array = [node]
 all.append_array(node.find_children("*","",true,false))
 for n in all:
  if n is MeshInstance3D and n.mesh: n.mesh = shared(n.mesh)
  elif n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh: n.multimesh.mesh = shared(n.multimesh.mesh)
  if n.get("source_mesh") is Mesh: n.source_mesh = shared(n.source_mesh)
# A material by content (materials are rebuilt per district, so their object
# identity would give every district its own copy of the same model).
static func material_key(material: Material) -> String:
 if material == null: return "none"
 if not material.resource_path.is_empty() and not "::" in material.resource_path: return material.resource_path
 var parts: Array = [material.get_class()]
 for property in material.get_property_list():
  if not (int(property.usage) & PROPERTY_USAGE_STORAGE): continue
  var value: Variant = material.get(property.name)
  if value is Resource: value = value.resource_path if not value.resource_path.is_empty() else value.get_class()
  parts.append(str(property.name)+"="+str(value))
 if material is ShaderMaterial and material.shader:
  for uniform in material.shader.get_shader_uniform_list():
   var value: Variant = material.get_shader_parameter(uniform.name)
   if value is Resource: value = value.resource_path if not value.resource_path.is_empty() else value.get_class()
   parts.append(str(uniform.name)+"="+str(value))
 return "|".join(parts).sha256_text()
func shared(mesh: Mesh) -> Mesh:
 if not mesh is ArrayMesh: return mesh
 var path: String = mesh.resource_path
 if not path.is_empty() and not "::" in path: return mesh
 if preload("res://Presentation/DistrictBatch.gd").vertex_count(mesh) < LIBRARY_MIN_VERTICES: return mesh
 var digest := HashingContext.new()
 digest.start(HashingContext.HASH_SHA256)
 for i in mesh.get_surface_count():
  digest.update(var_to_bytes(mesh.surface_get_arrays(i)))
  digest.update(material_key(mesh.surface_get_material(i)).to_utf8_buffer())
 var folder := output.path_join("models")
 DirAccess.make_dir_recursive_absolute(folder)
 var target := folder.path_join(digest.finish().hex_encode().left(24)+".res")
 # One object per library model: later copies get that object (taking over a
 # path would strip it from the earlier holder, which then embeds a copy).
 if library_paths.has(target): return library_paths[target]
 if FileAccess.file_exists(target):
  var stored: Mesh = ResourceLoader.load(target,"",ResourceLoader.CACHE_MODE_REUSE)
  if stored:
   library_paths[target] = stored
   return stored
 # Written under a temporary name and renamed, so parallel window bakes
 # never read a half-written model.
 var temporary := "%s.%d.tmp.res" % [target.get_basename(),OS.get_process_id()]
 var saved := ResourceSaver.save(mesh,temporary,ResourceSaver.FLAG_COMPRESS)
 if saved != OK:
  push_warning("Model library save failed (%s) for a %d-surface mesh" % [error_string(saved),mesh.get_surface_count()])
  return mesh
 if DirAccess.rename_absolute(temporary,target) != OK: DirAccess.remove_absolute(temporary)
 mesh.take_over_path(target)
 library_paths[target] = mesh
 return mesh
# Size report for one saved scene (--size-report): estimated bytes by what
# they are, so the cache can be kept within its budget.
func size_report(node: Node, data: Resource, path: String) -> void:
 var bytes := {}
 var all: Array = [node]
 all.append_array(node.find_children("*","",true,false))
 for n in all:
  var meshes: Array = []
  if n is MeshInstance3D and n.mesh: meshes.append(n.mesh)
  if n.get("source_mesh") is Mesh: meshes.append(n.source_mesh)
  for mesh in meshes:
   var shared_mesh: bool = not mesh.resource_path.is_empty() and not "::" in mesh.resource_path
   var amount := 0
   if mesh is ArrayMesh:
    for i in mesh.get_surface_count(): amount += var_to_bytes(mesh.surface_get_arrays(i)).size()
   var key := ("shared mesh ref " if shared_mesh else "embedded mesh ")+str(n.get_meta("kind",n.get_class()))+(" "+str(n.name).left(12) if str(n.name).begins_with("Batched") or str(n.name).begins_with("Terrain") else "")
   bytes[key] = int(bytes.get(key,0))+(0 if shared_mesh else amount)
   if not shared_mesh and amount > 200000: print("SIZE-BIG ",n.get_class()," ",n.name," mesh ",mesh.get_class()," path '",mesh.resource_path,"' surfaces ",mesh.get_surface_count()," bytes ",amount," kind ",n.get_meta("kind",""))
  if n.has_meta("deferred_faces"): bytes["collision faces"] = int(bytes.get("collision faces",0))+(n.get_meta("deferred_faces") as PackedVector3Array).size()*12
  if n.get("instance_data") is PackedByteArray: bytes["instance data"] = int(bytes.get("instance data",0))+n.instance_data.size()
 if data:
  for field in ["source_map","source_info","source_positions"]:
   var value: Variant = data.get(field)
   if value != null: bytes["meta "+field] = var_to_bytes(value).size()
 var keys: Array = bytes.keys()
 keys.sort_custom(func(a, b): return int(bytes[a]) > int(bytes[b]))
 var text := path.get_file()+":"
 for key in keys.slice(0,8): text += " | %s %.2f MB" % [key,int(bytes[key])/1e6]
 print("SIZE ",text)
func save_scene(node: Node3D, path: String, data: Resource = null) -> bool:
 share_meshes(node)
 if "--size-report" in OS.get_cmdline_user_args(): size_report(node,data,path)
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
 if ResourceSaver.save(data,temporary,ResourceSaver.FLAG_COMPRESS)!=OK:
  push_error("Prepared resource save failed: "+path);return false
 if DirAccess.rename_absolute(temporary,path)==OK:
  alternates.erase(path.get_file())
  return true
 # A running client keeps its resident districts open, so Windows refuses the
 # replacement. Install under a versioned name that the index points to; the
 # running clients reload it without restarting.
 var versioned := "%s_v%d.res" % [path.get_basename(),Time.get_unix_time_from_system()]
 if DirAccess.rename_absolute(temporary,versioned)!=OK:
  push_error("Prepared resource installation failed: "+path);return false
 alternates[path.get_file()]=versioned.get_file()
 print("STREAM BAKE: ",path.get_file()," is in use; installed as ",versioned.get_file())
 return true

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

var catalog_names: Dictionary={}
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
  var local_trees:=preload("res://Presentation/LocalTrees.gd")
  if local_trees.available():
   # Owner-licensed trees: per-variant coarse surfaces, same placement as near.
   # Keyed "variant|species" so tinted seasonal leaves batch apart.
   var by_variant: Dictionary={}
   for record in trees:
    var tile: Dictionary=record.tile
    var tree_name:=str(catalog_names.get(str(int(tile.id)),"tree"))
    var season:=local_trees.seasonal(int(tile.id),"")
    if season!="":tree_name=season
    var variant:=local_trees.pick(tree_name,int(tile.x),int(tile.y))
    if variant.is_empty():continue
    var key:=variant+"|"+(tree_name if local_trees.TINTS.has(tree_name) else "")
    if not by_variant.has(key):by_variant[key]=[]
    by_variant[key].append(Transform3D(Basis.IDENTITY,Vector3(tile.x-frame.x+0.5,float(tile.z)*0.2,tile.y-frame.y+0.5))*local_trees.placement(tree_name,variant,int(tile.x),int(tile.y)))
   for key in by_variant:
    var variant:=str(key).get_slice("|",0)
    for part in local_trees.far_surfaces(variant):
     var far_tree:=preload("res://Presentation/InstancedPatch.gd").new()
     far_tree.source_mesh=part.mesh
     far_tree.material_override=local_trees.material(variant,part.leaves,"trees",local_trees.TINTS.get(str(key).get_slice("|",1),Color.WHITE))
     far_tree.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
     far_tree.instance_data=preload("res://Presentation/InstancedPatch.gd").encode(by_variant[key])
     var bounds: AABB=by_variant[key][0]*part.mesh.get_aabb()
     for transform in by_variant[key]:bounds=bounds.merge(transform*part.mesh.get_aabb())
     far_tree.baked_bounds=bounds.grow(0.25)
     result.add_child(far_tree)
   return result
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
  if not save_scene(root,output.path_join("macro_%d_%d.res" % [at.x,at.y])):root.free();return []
  root.free()
  entries.append([at.x,at.y])
 return entries

func bake_preview(folder: String, districts: Array) -> void:
 var started:=Time.get_ticks_msec()
 DirAccess.make_dir_recursive_absolute(folder)
 var manual:=preload("res://Presentation/ManualOverrides.gd").new()
 manual.load_from(directory)
 var data:=preload("res://Presentation/AtlasData.gd").new()
 if not data.open(directory.path_join("atlas.json")): push_error("Missing owned atlas data");quit(1);return
 var known:={}
 for entry in data.manifest.chunks:known[Vector2i(entry.x,entry.y)]=true
 var plan:=preload("res://Presentation/RegionalContext.gd").new()
 plan.overrides=manual
 plan.prepare(data)
 var frame:=Vector2(plan.world.originX,plan.world.originY)
 for key in data.manifest.staticData:catalog_names[key]=str(data.manifest.staticData[key].get("name","tree"))
 plan.reconstruction.source_origin=frame
 preload("res://Presentation/SurfaceLibrary.gd").source_origin=frame
 plan.terrain_material.set_shader_parameter("source_origin",frame)
 var baked: Array=[]
 for at in districts:
  if not known.has(at):push_warning("Not a district of this dataset: "+str(at));continue
  if not await bake_district(plan,data,frame,at,folder):quit(1);return
  baked.append([at.x,at.y])
  await process_frame
 var report:={"districts":baked,"seconds":(Time.get_ticks_msec()-started)/1000.0,"mode":"modern" if preload("res://Presentation/GraphicsMode.gd").modern() else "classic"}
 var file:=FileAccess.open(folder.path_join("baked.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
 print("STREAM BAKE PREVIEW: %d district(s) in %.0f s" % [baked.size(),report.seconds])
 quit()

# One district's near (compact, collision) and far scenes into folder.
func bake_district(plan, data, frame: Vector2, at: Vector2i, folder: String) -> bool:
 var tag:="%d_%d" % [at.x,at.y]
 var near: Node3D=await plan.build_chunk(at,self,true)
 near.position=Vector3.ZERO
 var source: Dictionary=data.chunk(at)
 var far:=make_far(near,source.statics,frame,plan.reconstruction.catalog)
 # A window plans in its own bounds, so its geometry is relative to the
 # window corner; shift both scenes into the dataset's frame.
 if window_offset != Vector3.ZERO:
  for scene_root in [near,far]:
   for child in scene_root.get_children():
    if child is Node3D: child.position += window_offset
 var far_saved:=save_scene(far,folder.path_join("far_"+tag+".res"))
 far.free()
 if not far_saved:near.free();return false
 Compact.new().apply(near)
 var resource:=Prepared.new();resource.origin=at
 resource.source_map=near.get_meta("source_map",{})
 resource.source_info=near.get_meta("source_info",{})
 resource.source_positions=near.get_meta("source_positions",{})
 for tile in source.terrain: resource.land.append_array(PackedInt32Array([tile.id,tile.z]))
 for tile in source.statics: resource.statics.append_array(PackedInt32Array([tile.id,(int(tile.x)-at.x)|((int(tile.y)-at.y)<<6),tile.z,tile.hue]))
 if not save_scene(near,folder.path_join("near_"+tag+".res"),resource):near.free();return false
 print("STREAM BAKE: ",at," / ",resource.parts.size()," compact parts / ",near.get_meta("collision_triangles",0)," collision triangles")
 near.free()
 return true

func run() -> void:
 # Code-fix preview: --preview-output=<folder> --districts=x,y;x,y bakes only
 # those districts into the folder with this project's (patched) code and
 # leaves the published cache and its index untouched.
 var preview_output:=""
 var preview_list: Array=[]
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--dataset="): directory=arg.substr(10)
  if arg.begins_with("--preview-output="): preview_output=arg.substr(17)
  if arg.begins_with("--districts="):
   for pair in arg.substr(12).split(";",false):
    var xy:=pair.split(",")
    if xy.size()==2:preview_list.append(Vector2i(int(xy[0]),int(xy[1])))
  # Out-of-core facet bake (scripts/bake-facet.ps1): --window=x,y,w,h in
  # tiles bakes only the districts inside it, planning them with a one
  # district ring of context, and publishes nothing; --finalize then writes
  # the horizon and the index once every district is current.
  if arg.begins_with("--window="):
   var v:=arg.substr(9).split(",")
   if v.size()==4: window=Rect2i(int(v[0]),int(v[1]),int(v[2]),int(v[3]))
  if arg=="--finalize": finalize=true
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
 signature+=FileAccess.get_sha256("res://local-art/water/catalog.json") if FileAccess.file_exists("res://local-art/water/catalog.json") else "no-water"
 # Optional local (owner-licensed) art changes the baked scenes too.
 signature+=preload("res://Presentation/LocalTrees.gd").signature()
 signature+=preload("res://Presentation/LocalPlants.gd").signature()
 signature+=preload("res://Presentation/LocalProps.gd").signature()
 signature+=preload("res://Presentation/LocalLibrary.gd").signature()
 signature+="modern-britain" if preload("res://Presentation/GraphicsMode.gd").modern() else "classic-britain"
 signature=signature.sha256_text()
 output=preload("res://Presentation/GraphicsMode.gd").prepared(directory)
 if not preview_output.is_empty():
  await bake_preview(preview_output,preview_list)
  return
 DirAccess.make_dir_recursive_absolute(output)
 var index_path:=output.path_join("index.json")
 # Committed developer edits: only districts they touch are rebaked.
 var manual:=preload("res://Presentation/ManualOverrides.gd").new()
 manual.load_from(directory)
 if FileAccess.file_exists(index_path):
  var previous: Variant=JSON.parse_string(FileAccess.get_file_as_string(index_path))
  if previous is Dictionary: alternates=previous.get("files",{})
  if previous is Dictionary and previous.get("signature","")==signature and previous.get("overrides","")==manual.digest():
   var complete:=true
   for at in previous.chunks:
    for prefix in ["near","far"]:
     if not FileAccess.file_exists(output.path_join("%s_%d_%d.res" % [prefix,at[0],at[1]])): complete=false
   for at in previous.macros:
    if not FileAccess.file_exists(output.path_join("macro_%d_%d.res" % [at[0],at[1]])):complete=false
   if complete: print("STREAM BAKE: current");quit();return
 # A published index is the commit marker; never mix resources from two bakes.
 if FileAccess.file_exists(index_path) and window.size == Vector2i.ZERO: DirAccess.rename_absolute(index_path,index_path+".previous")
 var data:=preload("res://Presentation/AtlasData.gd").new()
 if not data.open(directory.path_join("atlas.json")): push_error("Missing owned atlas data");quit(1);return
 var all_chunks: Array = data.manifest.chunks
 # Which districts need baking (stamp out of date); in a window, only its own.
 var pending: Array = []
 for entry in all_chunks:
  var at:=Vector2i(entry.x,entry.y)
  if window.size != Vector2i.ZERO and not window.has_point(at): continue
  var tag:="%d_%d" % [at.x,at.y]
  var expected:=signature+":"+manual.chunk_digest(at)
  var stamp:=output.path_join(tag+".stamp")
  if not FileAccess.file_exists(stamp) or FileAccess.get_file_as_string(stamp).trim_suffix(":")!=expected.trim_suffix(":"): pending.append(entry)
 # A window plans only its districts and a one-district ring of context, in
 # the dataset's own frame, so joined walls and roofs meet across windows.
 if window.size != Vector2i.ZERO:
  var ring:=window.grow(64)
  var inside: Array = []
  var context: Array = []
  for entry in all_chunks:
   var at:=Vector2i(entry.x,entry.y)
   if window.has_point(at): inside.append(entry)
   elif ring.has_point(at): context.append(entry)
  data.manifest = data.manifest.duplicate()
  data.manifest.chunks = inside
  data.manifest.contextChunks = context
  dataset_origin = Vector2(int(data.manifest.originX),int(data.manifest.originY))
  data.manifest.originX = window.position.x
  data.manifest.originY = window.position.y
  data.manifest.width = window.size.x
  data.manifest.height = window.size.y
 # Joined-topology planning holds the planned region in memory (about 4-5 GB
 # at 400 districts); larger regions are baked in windows.
 if data.manifest.chunks.size()>512:
  push_error("Offline joined-topology planning is limited to 512 districts; bake a facet in windows (scripts/bake-facet.ps1).");quit(1);return
 var plan:=preload("res://Presentation/RegionalContext.gd").new()
 plan.overrides=manual
 # Nothing out of date (a finalize run, or a repeat): no planning at all.
 if not pending.is_empty(): plan.prepare(data)
 else: plan.world={"originX":int(data.manifest.originX),"originY":int(data.manifest.originY)}
 print("STREAM BAKE MEMORY: planning peak %.2f GB" % (OS.get_static_memory_peak_usage()/1073741824.0))
 var frame:=Vector2(plan.world.originX,plan.world.originY)
 # Windows plan in their own bounds but place everything in the dataset frame.
 if dataset_origin.x >= 0:
  window_offset = Vector3(plan.world.originX-dataset_origin.x,0,plan.world.originY-dataset_origin.y)
  frame = dataset_origin
 for key in data.manifest.staticData:catalog_names[key]=str(data.manifest.staticData[key].get("name","tree"))
 plan.reconstruction.source_origin=frame
 preload("res://Presentation/SurfaceLibrary.gd").source_origin=frame
 # (No terrain material when nothing needed planning.)
 if plan.terrain_material: plan.terrain_material.set_shader_parameter("source_origin",frame)
 var entries: Array=[]
 var stamps: Dictionary={}
 var rebuilt:=0
 for entry in data.manifest.chunks:
  var at:=Vector2i(entry.x,entry.y)
  var tag:="%d_%d" % [at.x,at.y]
  var stamp:=output.path_join(tag+".stamp")
  var expected:=signature+":"+manual.chunk_digest(at)
  stamps[tag]=expected.sha256_text().left(16)
  if not FileAccess.file_exists(stamp) or FileAccess.get_file_as_string(stamp).trim_suffix(":")!=expected.trim_suffix(":"):
   if pending.is_empty(): push_error("District %s is out of date; bake its window first." % tag);quit(1);return
   rebuilt+=1
   if not await bake_district(plan,data,frame,at,output):quit(1);return
   var marker:=FileAccess.open(stamp,FileAccess.WRITE);marker.store_string(expected);marker.close()
  entries.append([at.x,at.y])
  await process_frame
 # A window run stops here; --finalize publishes once all windows are done.
 if window.size != Vector2i.ZERO:
  # Each window's rule catalog is kept for the index (finalize merges them).
  if not pending.is_empty():
   DirAccess.make_dir_recursive_absolute(output.path_join("catalogs"))
   var part:=FileAccess.open(output.path_join("catalogs/%d_%d.json" % [window.position.x,window.position.y]),FileAccess.WRITE)
   part.store_string(JSON.stringify(plan.reconstruction.catalog));part.close()
  print("STREAM BAKE WINDOW: %s rebuilt %d / %d districts; memory peak %.2f GB" % [window,rebuilt,entries.size(),OS.get_static_memory_peak_usage()/1073741824.0])
  quit();return
 if finalize:
  data.manifest.chunks = all_chunks
  var catalogs:=output.path_join("catalogs")
  for name in DirAccess.get_files_at(catalogs):
   var part: Variant=JSON.parse_string(FileAccess.get_file_as_string(catalogs.path_join(name)))
   if part is Dictionary:
    for key in part:
     if not plan.reconstruction.catalog.has(key): plan.reconstruction.catalog[key]=part[key]
 var manifest: Dictionary=data.manifest
 var macro_entries:=macros(data,frame)
 if macro_entries.is_empty():push_error("Regional horizon bake failed; prepared index not published");quit(1);return
 var index: Dictionary={"schema":1,"signature":signature,"facet":1,"originX":manifest.originX,"originY":manifest.originY,"width":manifest.width,"height":manifest.height,"landData":manifest.landData,"staticData":manifest.staticData,"catalog":plan.reconstruction.catalog,"chunks":entries,"macros":macro_entries,"stamps":stamps,"overrides":manual.digest(),"files":alternates}
 var file:=FileAccess.open(index_path+".pending",FileAccess.WRITE);file.store_string(JSON.stringify(index));file.close()
 assert(DirAccess.rename_absolute(index_path+".pending",index_path)==OK)
 print("STREAM BAKE REBUILT: ",rebuilt," district(s)")
 print("STREAM BAKE COMPLETE: ",entries.size()," independent districts; shared source topology / compact scenes / collision / regional horizons; memory peak %.2f GB" % (OS.get_static_memory_peak_usage()/1073741824.0))
 quit()
