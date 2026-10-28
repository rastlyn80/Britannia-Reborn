extends RefCounted
# Merge opaque, stationary draw surfaces after physical collision is built.
# Native signs keep their nodes; wind, water and transparent surfaces stay live.
var batches: Dictionary = {}
var materials: Dictionary = {}
var meshes: Array = []
var distant: Dictionary = {}
# Live developer editing: which merged vertex range came from which static.
# Keys are "x:y:z:id:k" (k = rank among identical records in build order).
var counts: Dictionary = {}
var ranges: Dictionary = {}
var occurrences: Dictionary = {}
var info: Dictionary = {}
# Joined architecture and native/special surfaces are not live-editable per
# static (DevEdit/); other statics keep their original batched positions so a
# live hide/restore never needs a GPU readback.
const LIVE_EDIT_EXCLUDED := ["wall","window","corner","gable","trim","beam","arch","archway","pier","pillar","post","floor","landing","stairs","roof","door","fence","chimney","canopy","counter","carpet","decal","sign","water","effect","invisible"]
static func live_editable(kind: String, state: String) -> bool:
 return state == "replacement" and not kind in LIVE_EDIT_EXCLUDED
func source_keys(root: Node3D) -> void:
 for child in root.get_children():
  if not child.has_meta("source_xyz"):continue
  var xyz: Vector3i=child.get_meta("source_xyz")
  var base:="%d:%d:%d:%d" % [xyz.x,xyz.y,xyz.z,int(child.get_meta("source_id",0))]
  var key:=base+":"+str(int(occurrences.get(base,0)))
  occurrences[base]=int(occurrences.get(base,0))+1
  child.set_meta("source_key",key)
  info[key]="%s|%s|%d" % [child.get_meta("kind",""),child.get_meta("source_state",""),1 if child.get_meta("solid",false) else 0]
func collect(node: Node3D, parent: Transform3D, far: bool = false, source: String = "") -> void:
 if node.has_meta("source_key"): source = node.get_meta("source_key")
 if node.has_meta("kind"): far = node.get_meta("kind") in ["wall","window","corner","gable","trim","beam","arch","pillar","post","floor","landing","stairs","roof","door","fence","asset"]
 if node.get_meta("kind","") in ["tree","sign","water"]: return
 var transform := parent*node.transform
 if node is MeshInstance3D and node.mesh:
  for i in node.mesh.get_surface_count():
   var material: Material = node.get_active_material(i)
   if material is StandardMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return
   if material is ShaderMaterial and ("Nature" in material.shader.resource_path or "Water" in material.shader.resource_path): return
  for i in node.mesh.get_surface_count():
   var material: Material = node.get_active_material(i)
   var key := str(material.get_instance_id() if material else 0)+":"+str(far)
   if not batches.has(key):
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    batches[key] = tool
    materials[key] = material
    distant[key] = far
   batches[key].append_from(node.mesh,i,transform)
   var count: int = node.mesh.surface_get_array_len(i) if node.mesh is ArrayMesh else (node.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
   if not source.is_empty():
    if not ranges.has(source): ranges[source] = []
    ranges[source].append([key,int(counts.get(key,0)),count])
   counts[key] = int(counts.get(key,0))+count
  meshes.append(node)
 for child in node.get_children():
  if child is Node3D: collect(child,transform,far,source)
func apply(root: Node3D) -> void:
 # Terrain is already one draw surface. Preserve physics nodes and sign roots.
 source_keys(root)
 for child in root.get_children():
  if child is Node3D and not child is MeshInstance3D and not child is PhysicsBody3D:
   collect(child,Transform3D.IDENTITY)
 var names: Dictionary = {}
 var serial := 0
 for key in batches:
  var mesh: ArrayMesh = batches[key].commit()
  if mesh == null: continue
  var instance := MeshInstance3D.new()
  instance.name = "BatchedStatic_%d" % serial
  serial += 1
  # A count mismatch means the merge reordered vertices; never map ranges then.
  if mesh.get_surface_count() == 1 and mesh.surface_get_array_len(0) == int(counts.get(key,-1)): names[key] = instance.name
  instance.set_meta("distant",distant[key])
  instance.mesh = mesh
  instance.material_override = materials[key]
  root.add_child(instance)
 # The merged meshes now own these render surfaces; retain source anchors for
 # provenance and native sign suppression, not duplicate coplanar renderers.
 for node in meshes:
  node.mesh = null
 root.set_meta("draw_batches",batches.size())
 var map: Dictionary = {}
 for source in ranges:
  for entry in ranges[source]:
   if not names.has(entry[0]): continue
   if not map.has(source): map[source] = []
   map[source].append([names[entry[0]],0,entry[1],entry[2]])
 root.set_meta("source_map",map)
 root.set_meta("source_info",info)
 var batch_vertices: Dictionary = {}
 for child in root.get_children():
  if child is MeshInstance3D and str(child.name).begins_with("BatchedStatic_"): batch_vertices[str(child.name)] = child
 var positions: Dictionary = {}
 for source in map:
  var parts: PackedStringArray = str(info.get(source,"")).split("|")
  if parts.size() < 2 or not live_editable(parts[0],parts[1]): continue
  var list: Array = []
  for entry in map[source]:
   var node: MeshInstance3D = batch_vertices[entry[0]]
   if not node.has_meta("_vertices"): node.set_meta("_vertices",node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
   list.append((node.get_meta("_vertices") as PackedVector3Array).slice(entry[2],entry[2]+entry[3]))
  positions[source] = list
 for node in batch_vertices.values(): node.remove_meta("_vertices")
 root.set_meta("source_positions",positions)
