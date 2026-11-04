extends "res://Presentation/ChickenVisual.gd"
## Continue either hen fall over the sampled terrain plane and into the cadaver.

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const DISTINCT_CLIPS := ["RearStrike", "Death2"]
var collapse_plane: Dictionary = {}
var collapse_skin: Array[Dictionary] = []
var collapse_shift := Vector3.ZERO
var motion_root: Node3D
var entry_pose: Array[Transform3D] = []
var entry_root := Vector3.ZERO
var entry_start := 0.0
var entry_span := 0.0

func _ready() -> void:
	super._ready()
	if not animator.has_animation(DISTINCT_CLIPS[0]):
		var path: String = entry.additional_animation_library
		assert(path == "res://Art/Creatures/Chicken/distinct-actions.res")
		var additional := load(path) as AnimationLibrary
		var target := animator.get_animation_library("").duplicate(true) as AnimationLibrary
		animator.remove_animation_library("")
		animator.add_animation_library("", target)
		for clip: String in DISTINCT_CLIPS:
			assert(target.add_animation(clip, additional.get_animation(clip).duplicate(true)) == OK)
		play(current_clip, 0.0)
	motion_root = animator.get_node(animator.root_node).get_node("AuthoredChickenMotion")
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
	remember_support(source.support_plane())
	var elapsed: float = source.animator.current_animation_position if continuing else 0.0
	var speed: float = absf(source.animator.get_playing_speed()) if continuing else 1.0
	if is_zero_approx(speed):
		speed = 1.0
	animator.play(current_clip, 0.0, speed)
	animator.advance(0.0)
	animator.seek(elapsed, true)
	if continuing:
		entry_start = elapsed
		entry_span = minf(0.08 * speed, animator.current_animation_length - elapsed)
		if entry_span > 0.0:
			entry_root = source.motion_root.position
			for bone in source.skeleton.get_bone_count():
				entry_pose.append(source.skeleton.get_bone_pose(bone))
			settle_collapse()
	action_remaining = maxf(0.0, animator.current_animation_length - elapsed) / speed
	return action_remaining

func support_plane() -> Dictionary:
	if collapse_plane.has("collider"):
		return collapse_plane
	var origin := global_position
	var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.35, origin - Vector3.UP * 0.65, 1)
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
	for skin in collapse_skin:
		gap = minf(gap, Ground.minimum_plane_gap(skin, skeleton, space, origin, normal))
	return gap

func settle_collapse() -> void:
	model.position -= collapse_shift
	collapse_shift = Vector3.ZERO
	if not dead or collapse_plane.is_empty() or animator.current_animation_length <= 0.0:
		return
	if not entry_pose.is_empty():
		var weight := clampf((animator.current_animation_position - entry_start) / entry_span, 0.0, 1.0)
		if weight < 1.0:
			motion_root.position = entry_root.lerp(motion_root.position, weight)
			for bone in entry_pose.size():
				skeleton.set_bone_pose(bone, entry_pose[bone].interpolate_with(skeleton.get_bone_pose(bone), weight))
		else:
			entry_pose.clear()
	var normal: Vector3 = collapse_plane.normal
	var correction := 0.0025 - skin_gap(skeleton.global_transform, collapse_plane.position, normal)
	if correction < 0.0:
		var phase := animator.current_animation_position / animator.current_animation_length
		correction *= smoothstep(0.76, 1.0, phase)
	var previous := model.position
	model.global_position += Vector3.UP * correction / normal.y
	collapse_shift = model.position - previous
	update_landmarks()

func corpse_snapshot_floor() -> float:
	return skin_gap(global_transform.affine_inverse() * skeleton.global_transform, Vector3.ZERO, Vector3.UP)
