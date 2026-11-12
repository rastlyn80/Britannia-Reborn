# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CatActionsVisual.gd"

const Contact := preload("res://Presentation/CatStepContact.gd")
const TerrainSampler := preload("res://Presentation/CougarTerrainFall.gd")
const Clearance := preload("res://Presentation/CatTerrainClearance.gd")
const Probes := [Vector3(-.20, 0, -.34), Vector3(.20, 0, -.34),
	Vector3(-.20, 0, .34), Vector3(.20, 0, .34)]
const Directions := [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK,
	Vector3(.7071, 0, .7071), Vector3(.7071, 0, -.7071),
	Vector3(-.7071, 0, .7071), Vector3(-.7071, 0, -.7071)]
const LowGestures := ["Eat", "CatStretch", "Fidget", "Fidget2", "CatQuietStand", "CatTailRecoil"]
const IdleGestures := ["CatStretch", "Fidget", "Fidget2", "CatListening", "CatQuietStand"]
const Gaits := ["Walk", "Run", "Gallop"]
var terrain := Clearance.new()
var fall := TerrainSampler.new()
var plane := {}
var split_floor := {}
var support_lift := 0.0
var previous_lift := 0.0
var displayed_lift := 0.0
var prior_origin := Vector3.INF
var frame_delta := 1.0 / 60.0
var lower_tread_offset := Vector3.ZERO
var ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)
var starting_fall := false


func _ready() -> void:
	super._ready()
	var mesh: MeshInstance3D = contact.surface
	contact.free()
	contact = Contact.new()
	skeleton.add_child(contact)
	contact.configure(mesh, true)
	assert(contact.stride == 8 and contact.feet.size() == 4)
	terrain.skin = Ground.skin_points(mesh, skeleton)
	contact.terrain = terrain
	fall.skin = terrain.skin
	animator.mixer_applied.connect(release_support)
	animator.mixer_applied.connect(settle_fall)
	contact.modification_processed.connect(settle_support)


func _physics_process(delta: float) -> void:
	if dead:
		return
	frame_delta = delta
	previous_lift = displayed_lift
	if prior_origin.is_finite() and prior_origin.distance_to(global_position) < .35:
		previous_lift += prior_origin.y - global_position.y
	prior_origin = global_position
	model.global_position -= lower_tread_offset
	release_support()
	plane = {}
	split_floor = {}
	contact.split = false
	terrain.riser = {}
	if not contact.enabled:
		lower_tread_offset = Vector3.ZERO
		return
	if gesture_ground != null:
		gesture_ground.release(self)
	contact.sample(get_world_3d().direct_space_state, global_position)
	var center := ground_under(global_position)
	if center.is_empty() or center.normal.y < .8:
		lower_tread_offset = Vector3.ZERO
		return
	var normal: Vector3 = center.normal
	if current_clip in Gaits:
		terrain.riser = find_riser(center)
		if not terrain.riser.is_empty():
			split_floor = center
	for hit: Dictionary in contact.contacts.values():
		if different_surface(center, hit):
			split_floor = center
			break
	if split_floor.is_empty():
		for probe: Vector3 in Probes:
			var hit := ground_under(to_global(probe))
			if not hit.is_empty() and hit.normal.y > .8 and different_surface(center, hit):
				split_floor = center
				break
	if split_floor.is_empty():
		plane = center
	else:
		contact.split = true
		normal = step_normal(normal)
	var up := (global_basis.inverse() * normal).normalized()
	var basis := Basis(Quaternion(Vector3.UP, up)) * source_model_basis
	model.basis = model.basis.orthonormalized().slerp(basis, 1.0 - exp(-12.0 * delta)).scaled_local(model.scale)
	var target := Vector3.ZERO
	if contact.split:
		var retreat := retreat_from_riser()
		target = retreat if current_clip in LowGestures else retreat.limit_length(.075)
	lower_tread_offset = lower_tread_offset.move_toward(target, 1.8 * delta)
	model.global_position += lower_tread_offset
	contact.sample(get_world_3d().direct_space_state, global_position)


func ground_under(point: Vector3) -> Dictionary:
	ray.from = point + Vector3.UP * .45
	ray.to = point - Vector3.UP * .45
	return get_world_3d().direct_space_state.intersect_ray(ray)


func different_surface(a: Dictionary, b: Dictionary) -> bool:
	var normal: Vector3 = a.normal
	return normal.dot(b.normal) < .995 or absf(normal.dot(b.position - a.position)) > .012


func step_normal(fallback: Vector3) -> Vector3:
	if contact.contacts.size() != 4:
		return fallback
	var rear_left: Vector3 = contact.contacts[0].position
	var front_left: Vector3 = contact.contacts[1].position
	var rear_right: Vector3 = contact.contacts[2].position
	var front_right: Vector3 = contact.contacts[3].position
	var length := (front_left + front_right) - (rear_left + rear_right)
	var width := (front_right + rear_right) - (front_left + rear_left)
	var normal := length.cross(width).normalized()
	if normal.y < 0.0:
		normal = -normal
	if normal.y < .6:
		return fallback
	var tilt := fallback.angle_to(normal)
	return fallback.slerp(normal, minf(1.0, .30 / tilt)) if tilt > .001 else fallback


func retreat_from_riser() -> Vector3:
	var center: Vector3 = split_floor.position
	for distance: float in [.08, .14, .22, .32]:
		var upper := Vector3.ZERO
		for direction: Vector3 in Directions:
			var hit := ground_under(center + direction * distance)
			if not hit.is_empty() and float(hit.position.y) > center.y + .055:
				upper += direction
		if upper.length_squared() > .01:
			return -upper.normalized() * clampf(.38 - distance, 0.0, .25)
	return Vector3.ZERO


func find_riser(center: Dictionary) -> Dictionary:
	if center.normal.y < .97:
		return {}
	var origin: Vector3 = center.position
	for distance: float in [.12, .22, .34, .46, .60]:
		var facing := Vector3.ZERO
		var opposite := {}
		for direction: Vector3 in Directions:
			var hit := ground_under(origin + direction * distance)
			if hit.is_empty() or hit.collider == center.collider or hit.normal.dot(center.normal) < .995:
				continue
			var height: float = center.normal.dot(hit.position - origin)
			if absf(height) <= .055 or absf(height) >= .30:
				continue
			if opposite.is_empty():
				opposite = hit
			if hit.collider == opposite.collider:
				facing += direction
		if opposite.is_empty() or facing.length_squared() <= .01:
			continue
		facing = facing.normalized()
		var near := 0.0
		var far := distance
		var other := ground_under(origin + facing * far)
		if other.is_empty() or other.collider != opposite.collider:
			continue
		for iteration in 6:
			var halfway := (near + far) * .5
			var hit := ground_under(origin + facing * halfway)
			if not hit.is_empty() and hit.collider == opposite.collider:
				far = halfway
			else:
				near = halfway
		var uphill: bool = other.position.y > origin.y
		return {"lower": center if uphill else other, "upper": other if uphill else center,
			"direction": facing if uphill else -facing, "edge": origin + facing * ((near + far) * .5)}
	return {}


func release_support() -> void:
	model.global_position.y -= support_lift
	support_lift = 0.0


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in IdleGestures:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func settle_support() -> void:
	if dead:
		return
	release_support()
	skeleton.force_update_all_bone_transforms()
	if not split_floor.is_empty():
		terrain.plane = split_floor
		support_lift = maxf(0.0, .0015 - terrain.step_gap(skeleton))
	elif not plane.is_empty():
		var normal: Vector3 = plane.normal
		var gap := Ground.minimum_plane_gap(terrain.skin, skeleton, skeleton.global_transform, plane.position, normal)
		support_lift = maxf(0.0, (.002 - gap) / normal.y)
	support_lift = maxf(support_lift, previous_lift - 2.1 * frame_delta)
	displayed_lift = support_lift
	model.global_position.y += support_lift


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		collapse_plane = {}
		fall.split = not split_floor.is_empty()
		var support := split_floor if fall.split else plane
		fall.remember_floor(self, support if not support.is_empty() else fall.floor_under(self))
		# Preserve the displayed model transform as the basis of this collapse.
		support_lift = 0.0
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	model.transform = source.model.transform
	var previous := TerrainSampler.new()
	previous.plane = source.fall.plane if source.dead else source.plane
	fall.split = source.fall.split
	if not source.split_floor.is_empty():
		previous.plane = source.split_floor
		fall.split = true
	starting_fall = true
	var duration := fall.begin_from_display(self, source, previous, source.animator.assigned_animation, false)
	if not source.dead:
		fall.blend_length = minf(.12, duration)
		if fall.blend_length > 0.0:
			for joint in source.skeleton.get_bone_count():
				fall.blend_pose.append(source.skeleton.get_bone_pose(joint))
		fall.settle(self)
	starting_fall = false
	return duration


func settle_fall() -> void:
	if not starting_fall and not fall.plane.is_empty():
		fall.settle(self)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fall.plane.is_empty() else fall.snapshot_floor(self)
