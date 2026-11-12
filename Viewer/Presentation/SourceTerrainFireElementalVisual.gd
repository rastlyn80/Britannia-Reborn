# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/FireActionsVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")


class FlameSupport extends Terrain:
	# Flame ripple has a measured 80 mm envelope. Ash has no vertex ripple.
	const FlameClearance := .08
	var flame: MeshInstance3D
	var ash: MeshInstance3D
	var ash_points := PackedVector3Array()
	var setting_up := false
	var holding_first := false


	func prepare(visual: Node3D) -> void:
		actor = visual
		extent = Vector2(.74, .74)
		flame = actor.model.find_child("FireBody", true, false) as MeshInstance3D
		ash = actor.model.find_child("Ash", true, false) as MeshInstance3D
		assert(flame != null and ash != null)
		skin = Ground.skin_points(flame, actor.skeleton)
		for surface in ash.mesh.get_surface_count():
			ash_points.append_array(ash.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])


	func visible_gap() -> float:
		var gap := INF
		var rig: Skeleton3D = actor.skeleton
		if flame.visible:
			rig.force_update_all_bone_transforms()
			gap = (ribbon_step_gap(rig) if split else Ground.minimum_plane_gap(
				skin, rig, rig.global_transform, plane.position, plane.normal))
		if not ash.visible:
			return gap
		var space := rig.get_world_3d().direct_space_state
		var height: float = plane.position.y
		var normal: Vector3 = plane.normal
		for vertex: Vector3 in ash_points:
			var point := ash.to_global(vertex)
			if split:
				step_query.from = Vector3(point.x, height + .65, point.z)
				step_query.to = Vector3(point.x, height - .65, point.z)
				var hit := space.intersect_ray(step_query)
				if not hit.is_empty() and hit.normal.y > .75:
					gap = minf(gap, point.y - float(hit.position.y))
			else:
				gap = minf(gap, normal.dot(point - Vector3(plane.position)))
		return gap


	func ribbon_step_gap(rig: Skeleton3D) -> float:
		var matrices: Array[Transform3D] = []
		for index in skin.bones.size():
			matrices.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[index]) * skin.bind_poses[index])
		var space := rig.get_world_3d().direct_space_state
		var height: float = plane.position.y
		var minimum := INF
		for surface: Dictionary in skin.surfaces:
			for vertex in surface.points.size():
				var point := Vector3.ZERO
				for influence in surface.stride:
					var slot: int = vertex * surface.stride + influence
					var weight: float = surface.weights[slot]
					if weight > 0.0:
						point += (matrices[surface.bindings[slot]] * surface.points[vertex]) * weight
				if is_finite(minimum) and point.y - FlameClearance - minimum > height + .65:
					continue
				# The ripple can cross a tread edge even when the CPU vertex
				# lies just outside it. Test its surrounding support footprint.
				for offset: Vector3 in [Vector3.ZERO, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
					var sample := point + offset * FlameClearance
					step_query.from = Vector3(sample.x, height + .65, sample.z)
					step_query.to = Vector3(sample.x, height - .65, sample.z)
					var hit := space.intersect_ray(step_query)
					if not hit.is_empty() and hit.normal.y > .75:
						minimum = minf(minimum, point.y - FlameClearance - float(hit.position.y))
		return minimum


	func settle_live(_allowed_depth := 0.0) -> void:
		if actor.dead or plane.is_empty():
			return
		release_live()
		var gap := visible_gap()
		if is_finite(gap):
			live_lift = maxf(0.0, (.003 - gap) / (1.0 if split else float(plane.normal.y)))
			actor.model.global_position.y += live_lift


	func settle(visual: Node3D) -> void:
		if setting_up:
			return
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
				# The first pose is already supported on the terrain. The death
				# clip can initially expose a different surface than the rise.
				if holding_first and weight <= .0001:
					return
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
		for point: Vector3 in ash_points:
			floor_y = minf(floor_y, visual.to_local(ash.to_global(point)).y)
		return floor_y


var terrain := FlameSupport.new()
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


func update_fire_pose() -> void:
	if terrain.actor != null and not beginning_fall:
		if dead:
			terrain.settle(self)
		else:
			terrain.settle_live()
	super.update_fire_pose()
	if beginning_fall or not is_finite(entry_phase):
		return
	var progress := clampf((animator.current_animation_position - terrain.blend_start) /
		maxf(.001, terrain.blend_length), 0., 1.)
	if progress >= 1.0:
		entry_phase = NAN
		return
	fire_phase = lerp_angle(entry_phase, fire_phase, smoothstep(0.0, 1.0, progress))
	for mesh: MeshInstance3D in [terrain.flame, terrain.ash]:
		for surface in mesh.mesh.get_surface_count():
			mesh.get_active_material(surface).set_shader_parameter("phase", fire_phase)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", "Fidget2", "FlareSpread"]:
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
	var displayed_space: Transform3D = source.skeleton.global_transform
	var previous_clip: String = source.animator.assigned_animation
	var continuing: bool = source.dead and previous_clip in terrain.FALLS
	global_transform = source.global_transform
	model.global_transform = source.model.global_transform
	dead = true
	contact.enabled = false
	terrain.split = source.terrain.split
	beginning_fall = true
	terrain.setting_up = not continuing
	terrain.holding_first = not continuing
	var duration := terrain.begin_from_display(self, source, source.terrain, previous_clip, false)
	terrain.setting_up = false
	beginning_fall = false
	if not source.dead:
		terrain.blend_length = minf(.16, duration)
		for bone in source.skeleton.get_bone_count():
			terrain.blend_pose.append(source.skeleton.get_bone_pose(bone))
	if not continuing and not terrain.blend_pose.is_empty():
		var correction := skeleton.global_transform.affine_inverse() * displayed_space
		for bone in skeleton.get_bone_count():
			if skeleton.get_bone_parent(bone) < 0:
				terrain.blend_pose[bone] = correction * terrain.blend_pose[bone]
		entry_phase = source.fire_phase
	update_fire_pose()
	return duration


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
