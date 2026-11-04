extends "res://Presentation/RabbitVisual.gd"
## Preserve the licensed rabbit's skin and paw support while holding a collapse.

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const DISTINCT_CLIPS := ["RabbitLunge", "RabbitEarCheck", "Death2"]
var collapse_plane: Dictionary = {}
var collapse_skin: Array[Dictionary] = []
var collapse_shift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	if not animator.has_animation(DISTINCT_CLIPS[0]):
		var path: String = entry.additional_animation_library
		assert(path == "res://Art/Creatures/Rabbit/distinct-actions.res")
		var additional := load(path) as AnimationLibrary
		var target := animator.get_animation_library("")
		for clip: String in DISTINCT_CLIPS:
			assert(target.add_animation(clip, additional.get_animation(clip).duplicate(true)) == OK)
	animator.mixer_applied.connect(settle_collapse)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		remember_support(support_plane())
	else:
		collapse_plane = {}
	return true

func begin_death_from(source: Node3D) -> float:
	var continuing: bool = source.dead and source.current_clip in ["Death", "Death2"]
	model.position -= source.collapse_shift
	current_clip = source.current_clip if continuing else "Death"
	dead = true
	contact.enabled = false
	remember_support(source.support_plane())
	animator.speed_scale = 1.0
	play(current_clip, 0.0)
	animator.advance(0.0)
	var elapsed: float = source.animator.current_animation_position if continuing else 0.0
	animator.seek(elapsed, true)
	action_remaining = maxf(0.0, animator.current_animation_length - elapsed)
	return action_remaining

func support_plane() -> Dictionary:
	if not collapse_plane.is_empty():
		return collapse_plane
	if not contact.contacts.is_empty():
		return contact.contacts.values()[0]
	var origin := global_position
	var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.3, origin - Vector3.UP * 0.7, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit if not hit.is_empty() and hit.normal.y > 0.75 else {"position": origin, "normal": Vector3.UP}

func remember_support(plane: Dictionary) -> void:
	collapse_plane = plane
	if collapse_skin.is_empty():
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			collapse_skin.append(Ground.skin_points(mesh, skeleton))

func skin_gap(space: Transform3D, origin: Vector3, normal: Vector3) -> float:
	skeleton.force_update_all_bone_transforms()
	var gap := INF
	for skin: Dictionary in collapse_skin:
		gap = minf(gap, Ground.minimum_plane_gap(skin, skeleton, space, origin, normal))
	return gap

func settle_collapse() -> void:
	model.position -= collapse_shift
	collapse_shift = Vector3.ZERO
	if not dead or collapse_plane.is_empty():
		return
	var normal: Vector3 = collapse_plane.normal
	var correction := 0.0025 - skin_gap(skeleton.global_transform, collapse_plane.position, normal)
	if correction < 0.0:
		var phase := animator.current_animation_position / animator.current_animation_length
		correction *= smoothstep(0.76, 1.0, phase)
	var previous := model.position
	model.global_position += Vector3.UP * correction / normal.y
	collapse_shift = model.position - previous

func corpse_snapshot_floor() -> float:
	return skin_gap(global_transform.affine_inverse() * skeleton.global_transform, Vector3.ZERO, Vector3.UP)
