extends RefCounted
# Merge opaque, stationary draw surfaces after physical collision is built.
# Native signs keep their nodes; wind, water and transparent surfaces stay live.
var batches: Dictionary = {}
var materials: Dictionary = {}
var meshes: Array = []
func collect(node: Node3D, parent: Transform3D) -> void:
 if node.get_meta("kind","") in ["tree","sign","water"]: return
 var transform := parent*node.transform
 if node is MeshInstance3D and node.mesh:
  for i in node.mesh.get_surface_count():
   var material: Material = node.get_active_material(i)
   if material is StandardMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return
   if material is ShaderMaterial and ("Nature" in material.shader.resource_path or "Water" in material.shader.resource_path): return
  for i in node.mesh.get_surface_count():
   var material: Material = node.get_active_material(i)
   var key := material.get_instance_id() if material else 0
   if not batches.has(key):
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    batches[key] = tool
    materials[key] = material
   batches[key].append_from(node.mesh,i,transform)
  meshes.append(node)
 for child in node.get_children():
  if child is Node3D: collect(child,transform)
func apply(root: Node3D) -> void:
 # Terrain is already one draw surface. Preserve physics nodes and sign roots.
 for child in root.get_children():
  if child is Node3D and not child is MeshInstance3D and not child is PhysicsBody3D:
   collect(child,Transform3D.IDENTITY)
 for key in batches:
  var mesh: ArrayMesh = batches[key].commit()
  if mesh == null: continue
  var instance := MeshInstance3D.new()
  instance.name = "BatchedStatic"
  instance.mesh = mesh
  instance.material_override = materials[key]
  root.add_child(instance)
 # The merged meshes now own these render surfaces; retain source anchors for
 # provenance and native sign suppression, not duplicate coplanar renderers.
 for node in meshes:
  node.mesh = null
 root.set_meta("draw_batches",batches.size())
