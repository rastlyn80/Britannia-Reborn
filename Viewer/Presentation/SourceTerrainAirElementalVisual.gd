# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/AirActionsVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")


class WindSupport extends Terrain:
	# Cloud billow moves vertices by up to 25 mm. The rigid dust does not billow.
	const CloudClearance := .028
	var cloud: MeshInstance3D
	var dust: MeshInstance3D
	var dust_points := PackedVector3Array()


	func prepare(visual: Node3D) -> void:
		actor = visual
		extent = Vector2(.74, .74)
		cloud = actor.model.find_child("CloudBody", true, false) as MeshInstance3D
		dust = actor.model.find_child("Dust", true, false) as MeshInstance3D
		assert(cloud != null and dust != null)
		skin = Ground.skin_points(cloud, actor.skeleton)
		for surface in dust.mesh.get_surface_count():
			dust_points.append_array(dust.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])


	func visible_gap() -> float:
		var gap := INF
		var rig: Skeleton3D = actor.skeleton
		if cloud.visible:
			rig.force_update_all_bone_transforms()
			gap = (step_gap(rig) - CloudClearance if split else Ground.minimum_plane_gap(
				skin, rig, rig.global_transform, plane.position, plane.normal))
		if not dust.visible:
			return gap
		var space := rig.get_world_3d().direct_space_state
		var height: float = plane.position.y
		var normal: Vector3 = plane.normal
		for vertex: Vector3 in dust_points:
			var point := dust.to_global(vertex)
			if split:
				step_query.from = Vector3(point.x, height + .65, point.z)
				step_query.to = Vector3(point.x, height - .65, point.z)
				var hit := space.intersect_ray(step_query)
				if not hit.is_empty() and hit.normal.y > .75:
					gap = minf(gap, point.y - float(hit.position.y))
			else:
				gap = minf(gap, normal.dot(point - Vector3(plane.position)))
		return gap


	func settle_live(_allowed_depth := 0.0) -> void:
		if actor.dead or plane.is_empty():
			return
		release_live()
		var gap := visible_gap()
		if is_finite(gap):
			live_lift = maxf(0.0, (.003 - gap) / (1.0 if split else float(plane.normal.y)))
			actor.model.global_position.y += live_lift


	func settle(visual: Node3D) -> void:
		visual.model.position -= shift
		shift = Vector3.ZERO
		if not visual.dead or plane.is_empty() or visual.animator.current_animation_length <= 0.0:
			return
		var time: float = visual.animator.current_animation_position
		if not blend_pose.is_empty():
			var weight := clampf((time - blend_start) / blend_length, 0.0, 1.0)
			if weight < 1.0:
				for bone in blend_pose.size():
					visual.skeleton.set_bone_pose(bone, blend_pose[bone].interpolate_with(visual.skeleton.get_bone_pose(bone), weight))
			else:
				blend_pose.clear()
		var gap := visible_gap()
		if not is_finite(gap):
			return
		var lift := .002 - gap
		if lift < 0.0:
			lift *= smoothstep(.75, 1.0, time / visual.animator.current_animation_length)
		var prior: Vector3 = visual.model.position
		visual.model.global_position.y += lift / (1.0 if split else float(plane.normal.y))
		shift = visual.model.position - prior


	func snapshot_floor(visual: Node3D) -> float:
		var floor_y := INF
		for point: Vector3 in dust_points:
			floor_y = minf(floor_y, visual.to_local(dust.to_global(point)).y)
		return floor_y


var terrain := WindSupport.new()
var beginning_fall := false
var entry_phase := NAN


func _ready() -> void:
	super._ready()
	terrain.prepare(self)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)


func update_wind_pose() -> void:
	if terrain.actor != null and not beginning_fall:
		if dead:
			terrain.settle(self)
		else:
			terrain.settle_live()
	super.update_wind_pose()
	if beginning_fall or not is_finite(entry_phase):
		return
	var progress := clampf((animator.current_animation_position - terrain.blend_start) /
		maxf(.001, terrain.blend_length), 0., 1.)
	if progress >= 1.0:
		entry_phase = NAN
		return
	wind_phase = lerp_angle(entry_phase, wind_phase, smoothstep(0.0, 1.0, progress))
	for mesh: MeshInstance3D in [terrain.cloud, terrain.dust]:
		for surface in mesh.mesh.get_surface_count():
			mesh.get_active_material(surface).set_shader_parameter("phase", wind_phase)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", "Fidget2", "WindScatter"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		terrain.remember_floor(self, terrain.plane if not terrain.plane.is_empty() else terrain.floor_under(self))
		terrain.live_lift = 0.0
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	model.global_transform = source.model.global_transform
	dead = true
	contact.enabled = false
	terrain.split = source.terrain.split
	beginning_fall = true
	var duration := terrain.begin_from_display(self, source, source.terrain, source.animator.assigned_animation, false)
	beginning_fall = false
	if not source.dead:
		terrain.blend_length = minf(.16, duration)
		for bone in source.skeleton.get_bone_count():
			terrain.blend_pose.append(source.skeleton.get_bone_pose(bone))
		entry_phase = source.wind_phase
	update_wind_pose()
	return duration


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
