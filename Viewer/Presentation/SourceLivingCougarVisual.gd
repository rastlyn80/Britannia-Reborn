# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceLivingBearVisual.gd"

const BendTurns := [-.12, .12, -.24, .24, -.40, .40, -.55, .55]
const Fall := preload("CougarTerrainFall.gd")
const Compass := [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK,
	Vector3(.7071, 0, .7071), Vector3(.7071, 0, -.7071),
	Vector3(-.7071, 0, .7071), Vector3(-.7071, 0, -.7071)]
var tail: Array[int] = []
var tail_skin: Array[Dictionary] = []
var head_chain: Array[int] = []
var head_skin: Array[Dictionary] = []
var hind_skins := {}
var crouch_offset := Vector3.ZERO
var prior_crouch := Vector3.ZERO
var prior_lift := 0.0
var displayed_lift := 0.0
var step_delta := 1.0 / 60.0
var fall := Fall.new()
var setting_fall := false


func _ready() -> void:
	super._ready()
	for index in skeleton.get_bone_count():
		if skeleton.get_bone_name(index).begins_with("bip01 tail"):
			tail.append(index)
	assert(tail.size() >= 3)
	tail_skin.append(limb_points(skin[0], tail))
	for name: String in ["bip01 neck", "bip01 head"]:
		var joint := skeleton.find_bone(name)
		assert(joint >= 0)
		head_chain.append(joint)
	head_skin.append(limb_points(skin[0], head_chain))
	for foot: Dictionary in contact.feet:
		if not skeleton.get_bone_name(foot.a).ends_with(" thigh"):
			continue
		var hind: Array[int] = [int(foot.a), int(foot.b)]
		var samples: Array[Dictionary] = []
		samples.append(limb_points(skin[0], hind))
		hind_skins[foot.c] = samples
	contact.support_appendages = clear_limbs
	animator.mixer_applied.connect(settle_fall)


func _physics_process(delta: float) -> void:
	if dead:
		return
	step_delta = delta
	prior_crouch = crouch_offset
	prior_lift = displayed_lift
	model.global_position -= crouch_offset
	crouch_offset = Vector3.ZERO
	super._physics_process(delta)
	if split_floor.is_empty() and not prior_crouch.is_zero_approx():
		ease_crouch(Vector3.ZERO)
		contact.sample(get_world_3d().direct_space_state, global_position)


func tilt_away_from_step() -> void:
	ease_crouch(crouch_target() if current_clip == "Fidget" else Vector3.ZERO)
	super.tilt_away_from_step()


func ease_crouch(target: Vector3) -> void:
	crouch_offset = prior_crouch.move_toward(target, 2.4 * step_delta)
	model.global_position += crouch_offset


func crouch_target() -> Vector3:
	var center: Vector3 = split_floor.position
	var lower_radius := 0.0
	# Start moving away before the low part of the idle crosses the upper tread.
	for radius: float in [.08, .14, .22, .32]:
		var direction := Vector3.ZERO
		for offset: Vector3 in Compass:
			if upper_tread_at(center + offset * radius):
				direction += offset
		if direction.length_squared() > .01:
			direction = direction.normalized()
			var upper_radius := radius
			for attempt in 4:
				var probe := (lower_radius + upper_radius) * .5
				if upper_tread_at(center + direction * probe):
					upper_radius = probe
				else:
					lower_radius = probe
			return -direction * clampf(.36 - upper_radius, 0.0, .30)
		lower_radius = radius
	return Vector3.ZERO


func upper_tread_at(point: Vector3) -> bool:
	var hit := ground_under(point)
	return not hit.is_empty() and float(hit.position.y) > float(split_floor.position.y) + .06


func settle_support() -> void:
	super.settle_support()
	if dead or (split_floor.is_empty() and support_plane.is_empty()):
		displayed_lift = 0.0
		return
	var eased := move_toward(prior_lift, support_lift, 1.6 * step_delta)
	var retained := maxf(eased - support_lift, 0.0)
	support_lift += retained
	model.global_position.y += retained
	displayed_lift = support_lift


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead and not split_floor.is_empty():
		collapse_plane = {}
		fall.split = true
		fall.remember_floor(self, split_floor)
	return true


func begin_death_from(source: Node3D) -> float:
	model.transform = source.model.transform
	var previous := Fall.new()
	previous.plane = source.fall.plane if source.dead and not source.fall.plane.is_empty() else source.support_plane
	fall.split = source.fall.split
	if not source.split_floor.is_empty():
		previous.plane = source.split_floor
		fall.split = true
	setting_fall = true
	var duration := fall.begin_from_source(self, source, previous, false)
	setting_fall = false
	return duration


func settle_fall() -> void:
	if not setting_fall and not fall.plane.is_empty():
		fall.settle(self)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fall.plane.is_empty() else fall.snapshot_floor(self)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["FelineStretch", "FelineSniff"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func limb_points(source: Dictionary, joints_to_measure: Array[int]) -> Dictionary:
	var surfaces: Array[Dictionary] = []
	for surface: Dictionary in source.surfaces:
		var points := PackedVector3Array()
		var bindings := PackedInt32Array()
		var weights := PackedFloat32Array()
		var stride: int = surface.stride
		for vertex in surface.points.size():
			var offset: int = vertex * stride
			var weight := 0.0
			for influence in stride:
				if source.bones[surface.bindings[offset + influence]] in joints_to_measure:
					weight += surface.weights[offset + influence]
			if weight < .5:
				continue
			points.append(surface.points[vertex])
			for influence in stride:
				bindings.append(surface.bindings[offset + influence])
				weights.append(surface.weights[offset + influence])
		surfaces.append({"points": points, "bindings": bindings, "weights": weights, "stride": stride})
	return {"bones": source.bones, "bind_poses": source.bind_poses, "surfaces": surfaces}


func clear_limbs() -> void:
	var floor_height: float = split_floor.position.y
	for foot: Dictionary in contact.feet:
		if not hind_skins.has(foot.c):
			continue
		var samples: Array[Dictionary] = hind_skins[foot.c]
		var conflict: Dictionary = contact.step_conflict(floor_height, query, samples)
		if float(conflict.get("lift", 0.0)) > .018:
			turn_knee(foot, samples, floor_height, conflict.lift)
	clear_appendage(tail, tail_skin, floor_height)
	clear_appendage(head_chain, head_skin, floor_height)


func turn_knee(foot: Dictionary, samples: Array[Dictionary], floor_height: float, lift: float) -> void:
	var hip := skeleton.get_bone_global_pose(foot.a)
	var knee := skeleton.get_bone_global_pose(foot.b)
	var hock := skeleton.get_bone_global_pose(foot.c)
	var axis := (hock.origin - hip.origin).normalized()
	var leg := knee.origin - hip.origin
	if axis.is_zero_approx() or leg.cross(axis).length_squared() < .000001:
		return
	var best := 0.0
	for angle: float in BendTurns:
		set_knee(foot, hip, knee, hock, hip.origin + leg.rotated(axis, angle))
		var conflict: Dictionary = contact.step_conflict(floor_height, query, samples)
		var remaining := float(conflict.get("lift", 0.0))
		if remaining < lift - .001:
			lift = remaining
			best = angle
		if lift <= .006:
			break
	set_knee(foot, hip, knee, hock, hip.origin + leg.rotated(axis, best))


func set_knee(foot: Dictionary, hip: Transform3D, knee: Transform3D, hock: Transform3D, target: Vector3) -> void:
	skeleton.set_bone_global_pose(foot.a, hip)
	skeleton.set_bone_global_pose(foot.b, knee)
	skeleton.set_bone_global_pose(foot.c, hock)
	contact.aim(foot.a, foot.b, target)
	contact.aim(foot.b, foot.c, hock.origin)
	skeleton.set_bone_global_pose(foot.c, hock)


func clear_appendage(chain: Array[int], samples: Array[Dictionary], floor_height: float) -> void:
	for attempt in 3:
		for joint: int in chain:
			var conflict: Dictionary = contact.step_conflict(floor_height, query, samples)
			if conflict.is_empty():
				return
			contact.rotate_toward_surface(joint, conflict.point, conflict.normal, conflict.lift)
