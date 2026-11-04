extends RefCounted
## Preserve a visible pose as a native death becomes a terrain-supported corpse.

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const FALLS := ["Death", "Death2", "AirDeath"]
const FLIGHT := ["Fly", "TakeOff", "Land"]
var plane: Dictionary = {}
var skin: Dictionary = {}
var shift := Vector3.ZERO
var blend_pose: Array[Transform3D] = []
var blend_start := 0.0
var blend_length := 0.0

func accept_action(actor: Node3D) -> void:
	if actor.current_clip in FALLS:
		actor.dead = true
		actor.contact.enabled = false
		remember_floor(actor, floor_under(actor))
	else:
		plane = {}
		blend_pose.clear()

func begin_from(actor: Node3D, source: Node3D, previous: RefCounted) -> float:
	var continuing: bool = source.dead and source.current_clip in FALLS
	var airborne: bool = source.current_clip in FLIGHT and actor.animator.has_animation("AirDeath")
	actor.model.position -= previous.shift
	actor.current_clip = source.current_clip if continuing else ("AirDeath" if airborne else "Death")
	remember_floor(actor, previous.plane if previous.plane.has("collider") else floor_under(source))
	var time: float = source.animator.current_animation_position if continuing else 0.0
	var speed: float = absf(source.animator.get_playing_speed()) if continuing else 1.0
	if is_zero_approx(speed):
		speed = 1.0
	actor.animator.play(actor.current_clip, 0.0, speed)
	actor.animator.advance(0.0)
	actor.animator.seek(time, true)
	if continuing or airborne:
		blend_start = time
		blend_length = minf((0.08 if continuing else 0.12) * speed, actor.animator.current_animation_length - time)
		if blend_length > 0.0:
			for bone in source.skeleton.get_bone_count():
				blend_pose.append(source.skeleton.get_bone_pose(bone))
			settle(actor)
	actor.action_remaining = maxf(0.0, actor.animator.current_animation_length - time) / speed
	return actor.action_remaining

func floor_under(actor: Node3D) -> Dictionary:
	var origin := actor.global_position
	var ray := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.7, origin - Vector3.UP * 3.0, 1)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit if not hit.is_empty() and hit.normal.y > 0.75 else {"position": origin, "normal": Vector3.UP}

func remember_floor(actor: Node3D, support: Dictionary) -> void:
	plane = support
	if skin.is_empty():
		var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		skin = Ground.skin_points(mesh, actor.skeleton)

func settle(actor: Node3D) -> void:
	actor.model.position -= shift
	shift = Vector3.ZERO
	if not actor.dead or plane.is_empty() or actor.animator.current_animation_length <= 0.0:
		return
	if not blend_pose.is_empty():
		var weight := clampf((actor.animator.current_animation_position - blend_start) / blend_length, 0.0, 1.0)
		if weight < 1.0:
			for bone in blend_pose.size():
				actor.skeleton.set_bone_pose(bone, blend_pose[bone].interpolate_with(actor.skeleton.get_bone_pose(bone), weight))
		else:
			blend_pose.clear()
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.position, plane.normal)
	var lift := 0.002 - gap
	if lift < 0.0:
		var phase: float = actor.animator.current_animation_position / actor.animator.current_animation_length
		lift *= smoothstep(0.75, 1.0, phase)
	var before: Vector3 = actor.model.position
	actor.model.global_position += Vector3.UP * lift / float(plane.normal.y)
	shift = actor.model.position - before

func snapshot_floor(actor: Node3D) -> float:
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	return Ground.minimum_plane_gap(skin, rig, actor.global_transform.affine_inverse() * rig.global_transform,
		Vector3.ZERO, Vector3.UP)
