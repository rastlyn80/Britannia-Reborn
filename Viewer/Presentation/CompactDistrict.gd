extends RefCounted
# Runs only during conversion. Retain native sign anchors and physical bodies;
# replace repeated draw surfaces with instanced meshes and remove empty nodes.
var groups: Dictionary = {}
var originals: Array = []
var signatures: Dictionary = {}

func collect(node: Node3D, parent: Transform3D) -> void:
 if node.get_meta("kind","")=="sign" or node is PhysicsBody3D: return
 var transform := parent*node.transform
 if node is MeshInstance3D and node.mesh and not node.has_meta("distant"):
  var identity: int = node.mesh.get_instance_id()
  if not signatures.has(identity):
   var bytes := PackedByteArray()
   for i in node.mesh.get_surface_count(): bytes.append_array(var_to_bytes(node.mesh.surface_get_arrays(i)))
   var digest:=HashingContext.new()
   digest.start(HashingContext.HASH_SHA256)
   digest.update(bytes)
   signatures[identity] = digest.finish().hex_encode()
  var key: String = signatures[identity]+str(node.cast_shadow)
  # Detail levels are chosen per instanced batch; keep vegetation batches to
  # 16 m cells so distant trees in a district do not render at full detail.
  if node.has_meta("lod_cell"):key+="@"+str(Vector2i(floori(transform.origin.x/16.0),floori(transform.origin.z/16.0)))
  var materials: Array = []
  for i in node.mesh.get_surface_count():
   var material: Material = node.get_active_material(i)
   materials.append(material)
   key += ":"+str(material.get_instance_id() if material else 0)
  if not groups.has(key): groups[key]={"mesh":node.mesh,"materials":materials,"shadow":node.cast_shadow,"transforms":[],"nodes":[]}
  groups[key].transforms.append(transform)
  groups[key].nodes.append(node)
  originals.append(node)
 for child in node.get_children():
  if child is Node3D: collect(child,transform)

func prune(node: Node, root: Node) -> void:
 if node.get_meta("kind","")=="sign" or node is PhysicsBody3D: return
 for child in node.get_children(): prune(child,root)
 if node==root: return
 if node is MeshInstance3D and node.mesh!=null: return
 if node is MultiMeshInstance3D or node is CollisionShape3D: return
 if node.get_child_count()==0 and node is Node3D: node.free()

func apply(root: Node3D) -> void:
 for child in root.get_children():
  if child is Node3D: collect(child,Transform3D.IDENTITY)
 for group in groups.values():
  if group.transforms.size()==1:
   var node: MeshInstance3D=group.nodes[0]
   if node.get_parent()!=root:
    node.owner=null
    node.reparent(root,false)
   node.transform=group.transforms[0]
   originals.erase(node)
   continue
  var instance:=preload("res://Presentation/InstancedPatch.gd").new()
  var mesh: Mesh=group.mesh
  if mesh.get_surface_count()==1:
   instance.material_override=group.materials[0]
  else:
   mesh=mesh.duplicate()
   for i in mesh.get_surface_count():mesh.surface_set_material(i,group.materials[i])
  instance.source_mesh=mesh
  instance.instance_data=preload("res://Presentation/InstancedPatch.gd").encode(group.transforms)
  var box: AABB=group.transforms[0]*mesh.get_aabb()
  for transform in group.transforms:box=box.merge(transform*mesh.get_aabb())
  instance.baked_bounds=box.grow(0.25)
  instance.cast_shadow=group.shadow
  root.add_child(instance)
 for node in originals:node.mesh=null
 prune(root,root)
 defer_collision(root)

# Concave shapes created by a loader thread are built on the main thread in one
# burst (~0.8 us per triangle). Store bounded triangle slices as plain data; the
# runtime materializes them within its frame budget before movement is allowed.
const DEFERRED_FACES := 2000
static func defer_collision(root: Node) -> void:
 for node in root.find_children("*","CollisionShape3D",true,false):
  var shape: Shape3D=node.shape
  if not shape is ConcavePolygonShape3D:continue
  var faces: PackedVector3Array=shape.get_faces()
  var slice:=DEFERRED_FACES*3
  for start in range(0,faces.size(),slice):
   var target: CollisionShape3D=node
   if start>0:
    target=CollisionShape3D.new()
    target.transform=node.transform
    node.get_parent().add_child(target)
   target.shape=null
   target.set_meta("deferred_faces",faces.slice(start,mini(start+slice,faces.size())))
   target.set_meta("backface_collision",shape.backface_collision)

static func materialize(shape_node: CollisionShape3D) -> void:
 var shape:=ConcavePolygonShape3D.new()
 shape.backface_collision=shape_node.get_meta("backface_collision",true)
 shape.set_faces(shape_node.get_meta("deferred_faces"))
 shape_node.remove_meta("deferred_faces")
 shape_node.shape=shape

static func own(node: Node, root: Node) -> void:
 for child in node.get_children():
  child.owner=root
  own(child,root)
