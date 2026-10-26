extends MultiMeshInstance3D
# Keep instance placement in CPU-owned exported arrays. The headless conversion
# renderer does not retain MultiMesh.set_instance_transform() data for saving.
@export var source_mesh: Mesh
@export var instance_data := PackedFloat32Array()
@export var baked_bounds := AABB()

static func encode(transforms: Array) -> PackedFloat32Array:
 var result:=PackedFloat32Array()
 for t in transforms:
  result.append_array(PackedFloat32Array([
   t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x,
   t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y,
   t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z]))
 return result

func _ready() -> void:
 if DisplayServer.get_name()=="headless":return
 multimesh=MultiMesh.new()
 multimesh.transform_format=MultiMesh.TRANSFORM_3D
 multimesh.mesh=source_mesh
 multimesh.instance_count=instance_data.size()/12
 multimesh.custom_aabb=baked_bounds
 multimesh.buffer=instance_data
