extends "res://Presentation/SourcePreservingCreatureVisual.gd"
## Keep the original sword in the exact displayed pose when the corpse freezes.

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var sword_skin: Dictionary

func _ready() -> void:
	super._ready()
	var sword := model.find_child("RatmanSword", true, false) as MeshInstance3D
	sword_skin = Ground.skin_points(sword, skeleton)

func corpse_snapshot_floor() -> float:
	if not pose_entry.active:
		return INF
	skeleton.force_update_all_bone_transforms()
	var local := global_transform.affine_inverse() * skeleton.global_transform
	var lowest := INF
	for skin: Dictionary in [pose_entry.skin, sword_skin]:
		lowest = minf(lowest, Ground.minimum_plane_gap(skin, skeleton, local, Vector3.ZERO, Vector3.UP))
	return lowest
