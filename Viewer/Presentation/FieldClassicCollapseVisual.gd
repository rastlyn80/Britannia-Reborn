extends "res://Presentation/CreatureVisual.gd"
## Preserve the last sampled ground plane during an explicit quadruped collapse.

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var collapse_plane: Dictionary = {}
var collapse_skin: Dictionary = {}
var collapse_shift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(settle_collapse)

func receive_action(request: Dictionary) -> bool:
	var hit: Dictionary = contact.contacts.values()[0] if not contact.contacts.is_empty() else collapse_plane
	if not super.receive_action(request):
		return false
	if dead:
		collapse_plane = hit if not hit.is_empty() else {"position": global_position, "normal": Vector3.UP}
		if collapse_skin.is_empty():
			var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			collapse_skin = Ground.skin_points(mesh, skeleton)
	else:
		collapse_plane = {}
	return true

func settle_collapse() -> void:
	model.position -= collapse_shift
	collapse_shift = Vector3.ZERO
	if not dead or collapse_plane.is_empty():
		return
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(collapse_skin, skeleton, skeleton.global_transform,
		collapse_plane.position, collapse_plane.normal)
	var shift := 0.002 - gap
	if shift < 0.0:
		var phase := animator.current_animation_position / animator.current_animation_length
		shift *= smoothstep(0.75, 1.0, phase)
	var prior := model.position
	model.global_position += collapse_plane.normal * shift
	collapse_shift = model.position - prior
