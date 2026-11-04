extends "res://Presentation/SourcePreservingCreatureVisual.gd"
## Explicit death packets retain the last support plane after stance contact ends.

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var collapse_plane: Dictionary = {}
var collapse_skin: Dictionary = {}

func receive_action(request: Dictionary) -> bool:
	var hit: Dictionary = contact.contacts.values()[0] if not contact.contacts.is_empty() else collapse_plane
	if not super.receive_action(request):
		return false
	if dead:
		collapse_plane = hit if not hit.is_empty() else {"position": global_position, "normal": Vector3.UP}
		if collapse_skin.is_empty():
			var surface := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			collapse_skin = Ground.skin_points(surface, skeleton)
	else:
		collapse_plane = {}
	return true

func apply_variant_entry() -> void:
	super.apply_variant_entry()
	if pose_entry.active or not dead or collapse_plane.is_empty():
		return
	var normal: Vector3 = collapse_plane.normal
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(collapse_skin, skeleton, skeleton.global_transform,
		collapse_plane.position, normal)
	var phase := animator.current_animation_position / animator.current_animation_length
	var lift := 0.002 - gap
	if lift < 0.0:
		lift *= smoothstep(0.76, 1.0, phase)
	if not is_zero_approx(lift):
		var prior := model.position
		model.global_position += normal * lift
		clearance_lift = model.position - prior
