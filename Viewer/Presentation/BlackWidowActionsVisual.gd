extends "res://Presentation/DreadSpiderActionsVisual.gd"

func support_gesture() -> void:
	restore_gesture_model()
	if dead or current_clip not in ["LowBrace", "AbdomenSignal"]:
		return
	var hit: Dictionary = fall.floor_under(self)
	if not hit.has("collider"):
		return
	gesture_model = model.transform
	gesture_adjusted = true
	var normal: Vector3 = hit.normal
	var local_normal := (global_basis.inverse() * normal).normalized()
	model.basis = Basis(Quaternion(Vector3.UP, local_normal)) * gesture_model.basis
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(gesture_skin, skeleton, skeleton.global_transform, hit.position, normal)
	model.global_position.y += (CLEARANCE - gap) / normal.y
