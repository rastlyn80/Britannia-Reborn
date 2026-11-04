extends "res://Presentation/SourceGroundedGestureVisual.gd"
## Keep the original airborne fall separate from either ground collapse.

const Timing := preload("res://Presentation/HumanActions.gd")
const AIR_COLLAPSE := "AirDeath"
const AIRBORNE := ["Fly", "TakeOff", "Land", AIR_COLLAPSE]
var collapse_plane: Dictionary = {}
var collapse_skin: Dictionary = {}
var collapse_shift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(settle_collapse)

func receive_action(request: Dictionary) -> bool:
	var explicit_air := str(request.get("protocol", "")) == "classic" and int(request.get("action", -1)) == 21
	if explicit_air:
		var length := animator.get_animation(AIR_COLLAPSE).length
		start_collapse(AIR_COLLAPSE, support_plane(self))
		action_remaining = Timing.duration(request, length)
		animator.play(AIR_COLLAPSE, 0.12, length / action_remaining)
		animator.seek(0.0, false)
		set_meta("native_action", request.duplicate(true))
		return true
	if not super.receive_action(request):
		return false
	if dead:
		remember_plane(support_plane(self))
	else:
		release_collapse_shift()
		collapse_plane = {}
	return true

func begin_death_from(source: Node3D) -> float:
	var continuing: bool = bool(source.dead) and source.current_clip in ["Death", "Death2", AIR_COLLAPSE]
	var clip: String = source.current_clip if continuing else (AIR_COLLAPSE if source.current_clip in AIRBORNE else "Death")
	var elapsed := float(source.animator.current_animation_position) if continuing else 0.0
	if continuing:
		# The transition copies the displayed model transform, including the previous lift.
		model.position -= source.collapse_shift
	start_collapse(clip, support_plane(source))
	var duration := animator.get_animation(clip).length
	play(clip, 0.0 if continuing else 0.08)
	if continuing:
		animator.advance(0.0)
		animator.seek(minf(elapsed, duration), true)
	action_remaining = maxf(0.0, duration - elapsed)
	return action_remaining

func start_collapse(clip: String, plane: Dictionary) -> void:
	release_gesture_lift()
	current_clip = clip
	dead = true
	contact.enabled = false
	animator.speed_scale = 1.0
	remember_plane(plane)

func support_plane(source: Node3D) -> Dictionary:
	if not source.contact.contacts.is_empty():
		return source.contact.contacts.values()[0]
	if not source.collapse_plane.is_empty():
		return source.collapse_plane
	var origin := source.global_position
	var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.7, origin - Vector3.UP * 3.0, 1)
	var hit := source.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.y > 0.75:
		return hit
	return {"position": origin, "normal": Vector3.UP}

func remember_plane(plane: Dictionary) -> void:
	collapse_plane = plane
	if collapse_skin.is_empty():
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		collapse_skin = Ground.skin_points(mesh, skeleton)

func release_collapse_shift() -> void:
	model.position -= collapse_shift
	collapse_shift = Vector3.ZERO

func settle_collapse() -> void:
	release_collapse_shift()
	if not dead or collapse_plane.is_empty() or animator.current_animation_length <= 0.0:
		return
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(collapse_skin, skeleton, skeleton.global_transform,
		collapse_plane.position, collapse_plane.normal)
	var correction := 0.003 - gap
	if correction < 0.0:
		var phase := animator.current_animation_position / animator.current_animation_length
		correction *= smoothstep(0.78, 1.0, phase)
	var old := model.position
	model.global_position += Vector3.UP * correction / float(collapse_plane.normal.y)
	collapse_shift = model.position - old

func corpse_snapshot_floor() -> float:
	skeleton.force_update_all_bone_transforms()
	var local_rig := global_transform.affine_inverse() * skeleton.global_transform
	return Ground.minimum_plane_gap(collapse_skin, skeleton, local_rig, Vector3.ZERO, Vector3.UP)
