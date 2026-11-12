# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceRatmanArcherVisual.gd"

const Footing := preload("res://Presentation/SourceRatmanStepContact.gd")

var fall_bow_start := Basis.IDENTITY
var fall_bow_draw := Vector3.ZERO
var preserve_fall_bow := false


func _ready() -> void:
	super._ready()
	animator.mixer_applied.disconnect(sync_bow)
	Footing.attach(self)
	animator.mixer_applied.connect(sync_bow)
	contact.modification_processed.connect(finish_supported_bow)
	aim.modification_processed.connect(contact.remember_display)


func play_gait(moving: bool, speed: float) -> void:
	contact.resume_gait(moving)
	super.play_gait(moving, speed)

func receive_action(request: Dictionary) -> bool:
	var accepted := super.receive_action(request)
	if accepted and dead:
		collapse_plane = {}
		contact.prepare_death()
	return accepted


func sync_bow() -> void:
	if dead and is_instance_valid(bow) and bow.visible and not contact.death.plane.is_empty():
		sync_falling_bow()
	else:
		super.sync_bow()


func corpse_snapshot_floor() -> float:
	if contact.death.plane.is_empty():
		return super.corpse_snapshot_floor()
	var body_floor: float = contact.death.snapshot_floor(self)
	if is_instance_valid(bow) and bow.visible:
		return minf(body_floor, bow_gap(global_position, Vector3.UP, bow.global_transform))
	return body_floor


func begin_death_from(source: Node3D) -> float:
	preserve_fall_bow = is_instance_valid(bow) and bow.visible and is_instance_valid(source.bow) and source.bow.visible
	if preserve_fall_bow:
		fall_bow_start = source.bow.global_basis.orthonormalized()
		fall_bow_draw = source.draw_offset
	var duration: float = contact.death.enter(self, source)
	sync_bow()
	return duration


func finish_supported_bow() -> void:
	sync_supported_bow()
	contact.remember_display()


func sync_falling_bow() -> void:
	var fall = contact.death
	if fall.setting_up:
		return
	var time := animator.current_animation_position
	var phase := clampf((time - fall.blend_start) / maxf(.001, fall.blend_length), 0.0, 1.0)
	var normal: Vector3 = fall.plane.normal
	var across := global_basis.x.slide(normal).normalized()
	var along := normal.cross(across)
	var basis := Basis(across, along, normal)
	if preserve_fall_bow and phase < 1.0:
		basis = fall_bow_start.slerp(basis, smoothstep(0.0, 1.0, phase))
	place_bow(basis, fall_bow_draw * (1.0 - phase))
	var gap := falling_bow_gap()
	if gap < Clearance and phase > 0.0:
		var grip := grasp(left_grasp)
		var lowest := gap
		var best := basis
		for angle: float in [.20, -.20, .42, -.42, .72, -.72]:
			var trial := basis.rotated(normal, angle * phase)
			var fit := trial.scaled_local(Vector3.ONE * BowScale)
			bow.global_transform = Transform3D(fit, grip - fit * Grip)
			var available := falling_bow_gap()
			if available > lowest:
				best = trial
				lowest = available
			if available >= Clearance:
				break
		place_bow(best, fall_bow_draw * (1.0 - phase))
		gap = lowest
	if gap < .002:
		var lift := (.002 - gap) / normal.y
		var before := model.position
		model.global_position.y += lift
		fall.shift += model.position - before
		bow.global_position.y += lift


func falling_bow_gap() -> float:
	var fall = contact.death
	if not fall.split:
		return bow_gap(fall.plane.position, fall.plane.normal, bow.global_transform)
	var lowest := INF
	var height: float = fall.plane.position.y
	var space := get_world_3d().direct_space_state
	for vertex: Vector3 in bow.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var point := bow.to_global(vertex)
		var hit: Dictionary = contact.cast_floor(space, Vector3(point.x, height, point.z))
		if not hit.is_empty() and hit.normal.y >= .8:
			lowest = minf(lowest, hit.normal.dot(point - hit.position))
	return lowest


func sync_supported_bow() -> void:
	sync_bow()
	if dead or not bow_release_available() or aim.elapsed < BowAim.RecoveryTime or contact.ground.is_empty():
		return
	var basis := bow.global_basis.orthonormalized()
	var gap := carried_bow_gap(bow.global_transform)
	if gap >= Clearance:
		return
	var flat := basis.y.slide(Vector3.UP).normalized()
	var target := Basis(basis.x, flat, basis.x.cross(flat))
	var grip := grasp(left_grasp)
	var best := basis
	for tilt: float in [.25, .50, .75, 1.0]:
		var candidate := basis.slerp(target, tilt)
		var fit := candidate.scaled_local(Vector3.ONE * BowScale)
		var clearance := carried_bow_gap(Transform3D(fit, grip - fit * Grip))
		if clearance >= Clearance:
			place_bow(candidate, Vector3.ZERO)
			return
		if clearance > gap:
			gap = clearance
			best = candidate
	var wrist := skeleton.to_global(skeleton.get_bone_global_pose(aim.left[2]).origin)
	var knuckles := (grip - wrist).normalized()
	var pole := global_basis.x - Vector3.UP * .35
	var lifted := grip + Vector3.UP * minf(.24, Clearance - gap)
	BowAim.ArmFit.place_arm(skeleton, aim.left, lifted, knuckles, pole, 1.0, 1.0)
	place_bow(best, Vector3.ZERO)


func carried_bow_gap(pose: Transform3D) -> float:
	if not contact.use_local_planes:
		return bow_gap(contact.ground.position, contact.ground.normal, pose)
	var space := get_world_3d().direct_space_state
	var lowest := INF
	for vertex: Vector3 in rest_arrays[Mesh.ARRAY_VERTEX]:
		var point := pose * vertex
		if point.y >= float(contact.ground.position.y) + .65:
			continue
		var hit: Dictionary = contact.cast_floor(space, Vector3(point.x, contact.ground.position.y, point.z))
		if not hit.is_empty() and hit.normal.y >= .8:
			lowest = minf(lowest, hit.normal.dot(point - hit.position))
	return lowest
