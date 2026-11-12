# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedLichVisual.gd"

const Footing := preload("res://Presentation/SourceSkeletonGround.gd")
const IdleGestures := ["Fidget", "Fidget2", "LichStaffShift"]
var staff_blend_start := 0.0
var staff_lift := 0.0
var staff_points := PackedVector3Array()


func _ready() -> void:
	super._ready()
	Footing.attach(self)
	animator.mixer_applied.disconnect(settle_collapse)
	animator.mixer_applied.disconnect(settle_fitted_fall)
	animator.mixer_applied.connect(release_staff_lift)
	animator.mixer_applied.connect(settle_staff)
	contact.modification_processed.connect(settle_held_staff)
	contact.modification_processed.connect(update_ribbon)
	if staff != null:
		cache_staff_points()


func _physics_process(_delta: float) -> void:
	if not dead:
		release_staff_lift()
		contact.sample(get_world_3d().direct_space_state, global_position)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in IdleGestures:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		contact.prepare_death()
		collapse_plane = contact.death.plane
	else:
		contact.enabled = true
	return true


func cache_staff_points() -> void:
	var seen := {}
	for mesh: MeshInstance3D in staff_meshes():
		var relative := staff.global_transform.affine_inverse() * mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var vertex := relative * point
				if not seen.has(vertex):
					seen[vertex] = true
					staff_points.append(vertex)


func release_staff_lift() -> void:
	if staff_lift > 0.0:
		model.global_position.y -= staff_lift
		staff.global_position.y -= staff_lift
		staff_lift = 0.0


func settle_held_staff() -> void:
	update_grip()
	if dead or staff == null or not contact.use_local_planes:
		return
	var gap := actual_staff_gap()
	if is_finite(gap) and gap < .003:
		# Any remainder comes from a limited arm reach. Raise the body and
		# held staff together so the closed grip stays on the same socket.
		staff_lift = .003 - gap
		model.global_position.y += staff_lift
		staff.global_position.y += staff_lift
		contact.remember_display()
		update_landmarks()


func begin_death_from(source: Node3D) -> float:
	if staff != null and source.staff != null:
		staff_entry = source.staff.global_transform
		staff_blend_start = source.animator.current_animation_position if source.dead else 0.0
		staff_entry_length = .15
	var duration: float = contact.death.enter(self, source)
	collapse_plane = contact.death.plane
	collapse_skin = contact.death.skin
	settle_staff()
	return duration


func settle_staff() -> void:
	if not dead or staff == null or contact.death.setting_up or contact.death.plane.is_empty():
		return
	var elapsed := animator.current_animation_position - staff_blend_start
	if elapsed <= .001 and staff_entry_length > 0.0:
		staff.global_transform = staff_entry
		update_landmarks()
		return
	# The body blend already includes the displayed hand and finger rotations.
	# Settling the prop must leave that inherited hand pose alone.
	staff.global_transform = staff_socket_transform()
	rest_staff()
	if elapsed < staff_entry_length:
		staff.global_transform = staff_entry.interpolate_with(staff.global_transform,
			smoothstep(0.0, staff_entry_length, elapsed))
	if elapsed > .001:
		var gap := actual_staff_gap()
		if is_finite(gap) and gap < .003:
			staff.global_position.y += .003 - gap
	update_landmarks()


func actual_staff_gap() -> float:
	var space := get_world_3d().direct_space_state
	var low := INF
	for local: Vector3 in staff_points:
		var point := staff.to_global(local)
		if point.y - low > global_position.y + .65:
			continue
		var support: Dictionary = contact.hit_at(space, point, global_position.y)
		if not support.is_empty():
			low = minf(low, point.y - float(support.position.y))
	return low


func staff_gap(candidate: Transform3D, normal: Vector3) -> float:
	if not contact is Footing or not contact.use_local_planes:
		return super.staff_gap(candidate, normal)
	var low := tread_staff_gap(candidate)
	return low if is_finite(low) else super.staff_gap(candidate, normal)


func tread_staff_gap(candidate: Transform3D) -> float:
	var space := get_world_3d().direct_space_state
	var low := INF
	var box := staff_local_bounds
	# Sample along the pole as well as its ends. A step can lie between
	# the ends of a diagonal staff even when the visible tip clears it.
	for x: float in [box.position.x, box.end.x]:
		for z: float in [box.position.z, box.end.z]:
			var prior_support := INF
			var prior_point := INF
			for index in 9:
				var local := Vector3(x, lerpf(box.position.y, box.end.y, index / 8.0), z)
				var point := candidate * local
				var support: Dictionary = contact.hit_at(space, point, global_position.y)
				if support.is_empty():
					prior_support = INF
					continue
				var height: float = support.position.y
				low = minf(low, point.y - height)
				if is_finite(prior_support) and absf(height - prior_support) > .018:
					low = minf(low, minf(point.y, prior_point) - maxf(height, prior_support))
				prior_support = height
				prior_point = point.y
	return low
