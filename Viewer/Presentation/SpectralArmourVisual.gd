extends "res://Presentation/SourcePreservingCreatureVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")

var alternate_death_plane: Dictionary = {}

func receive_action(request: Dictionary) -> bool:
	var previous_plane := alternate_death_plane
	var hit: Dictionary = contact.contacts.get(0, previous_plane)
	if not super.receive_action(request):
		return false
	alternate_death_plane = hit if current_clip == "Death2" else {}
	return true

func apply_variant_entry() -> void:
	super.apply_variant_entry()
	if pose_entry.active or current_clip != "Death2" or alternate_death_plane.is_empty():
		return
	var normal: Vector3 = alternate_death_plane.normal
	var gap := Ground.minimum_plane_gap(control_skin, skeleton, skeleton.global_transform,
		alternate_death_plane.position, normal)
	if gap < 0.002:
		var before := model.position
		model.global_position += normal * (0.002 - gap)
		clearance_lift = model.position - before
