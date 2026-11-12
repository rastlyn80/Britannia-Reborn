# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-magical-equine-terrain.gd"

const DarkHorse := preload("res://Presentation/SourceDarkHorseVisual.gd")
var gait_samples := 0
var raw_minimum := INF
var corrected_minimum := INF


func run() -> void:
	DarkHorse.configure_sources(true)
	for body: int in DarkHorse.NativeItems:
		var actor := spawn(body, 0.)
		for clip: String in ["Idle", "Walk", "Run", "Attack", "Hit", "Fidget", "Death", DarkHorse.Breath]:
			if not sample_source_bounds(actor, clip):
				return
		actor.free()

	var board := StaticBody3D.new()
	root.add_child(board)
	var surface := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10., .1, 10.)
	surface.shape = shape
	board.add_child(surface)
	for normal: Vector3 in [Vector3.UP, Vector3(.20, 1., .19).normalized(), Vector3(-.23, 1., -.27).normalized()]:
		board.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), -.05 * normal)
		await physics_frame
		await physics_frame
		for body: int in DarkHorse.NativeItems:
			for facing: float in [0., PI * .25, -PI * .5]:
				if not sample_live_support(board, normal, body, facing):
					return
				if not sample_fall(board, normal, body, facing, 0):
					return
	var edge := spawn(116, 0.)
	edge.position.x = 7.
	if edge.fall.floor_under(edge).has("collider"):
		fail("the tested board must have a finite edge")
		return
	print("DARK HORSE TERRAIN: ", samples, " source/fall skin poses, ", gait_samples, " supported action poses, ",
		handoffs, " fall handoffs, source floor minimum ", flat_min, " m, live raw/corrected ",
		raw_minimum, "/", corrected_minimum, " m, fall minimum ", slope_min, " m, max handoff ", pose_error, " m")
	quit()


func sample_source_bounds(actor: Magical, clip: String) -> bool:
	if not actor.animator.has_animation(clip):
		return fail("missing source clip " + clip)
	actor.animator.stop()
	actor.skeleton.reset_bone_poses()
	actor.animator.play(clip, 0.)
	actor.animator.advance(0.)
	var length := actor.animator.current_animation_length
	for frame in 33:
		actor.animator.seek(length * float(frame) / 32., true)
		actor.skeleton.force_update_all_bone_transforms()
		var bounds := Geometry.deformed_bounds(actor.contact.surface, actor.skeleton)
		if not bounds.is_finite() or bounds.get_longest_axis_size() < 1.4:
			return fail("body %d %s has invalid original skin bounds" % [actor.native_body, clip])
		flat_min = minf(flat_min, bounds.position.y)
		samples += 1
	return true


func sample_live_support(board: StaticBody3D, normal: Vector3, body: int, facing: float) -> bool:
	var actor := spawn(body, facing)
	var rig := actor.skeleton
	var skin := Ground.skin_points(actor.contact.surface, rig)
	for clip: String in ["Idle", "Walk", "Run", DarkHorse.Breath]:
		actor.animator.stop()
		rig.reset_bone_poses()
		actor.animator.play(clip, 0.)
		actor.animator.advance(0.)
		for frame in 9:
			actor.animator.seek(actor.animator.current_animation_length * float(frame) / 8., true)
			actor.contact.enabled = true
			actor._physics_process(1.)
			actor._physics_process(1.)
			rig.force_update_all_bone_transforms()
			var contacts: Dictionary = actor.contact.contacts
			if contacts.size() != 4 or not contacts.values().all(
					func(hit: Dictionary): return hit.collider == board and hit.normal.distance_to(normal) < .001):
				return fail("the four hoof rays must use the tested terrain")
			actor.animator.seek(actor.animator.current_animation_length * float(frame) / 8., true)
			rig.force_update_all_bone_transforms()
			var corrected := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
			var raw := corrected - normal.dot(actor.global_basis * actor.live_shift)
			if not is_finite(corrected) or corrected < .0015 or actor.live_shift.length() > .19:
				return fail("body %d %s frame %d on %s has a corrected gap of %.6f m (raw %.6f m)" %
					[body, clip, frame, normal, corrected, raw])
			raw_minimum = minf(raw_minimum, raw)
			corrected_minimum = minf(corrected_minimum, corrected)
			gait_samples += 1
	actor.free()
	return true


func sample_fall(board: StaticBody3D, normal: Vector3, body: int, facing: float, _variant: int) -> bool:
	var source := spawn(body, facing)
	var target := spawn(body, facing)
	var action := {"protocol": "classic", "action": 8, "frames": 5, "repeat_count": 1,
		"repeat": false, "reverse": false, "delay": 0}
	if not source.receive_action(action) or source.current_clip != "Death":
		return fail("the Classic fall did not select the preserved original collapse")
	var plane: Dictionary = source.fall.plane
	if plane.get("collider") != board or plane.normal.distance_to(normal) > .001:
		return fail("the original collapse did not pick the actual terrain")
	source.animator.advance(0.)
	var length := source.animator.current_animation_length
	for frame in 25:
		source.animator.seek(length * float(frame) / 24., true)
		if not floor_ok(source, plane, frame == 24):
			return false
	source.animator.seek(length * .42, true)
	target.model.transform = source.model.transform
	target.global_transform = source.global_transform
	if target.begin_source_death(source) <= 0. or target.current_clip != source.current_clip:
		return fail("the handoff changed the active fall")
	for bone in source.skeleton.get_bone_count():
		var original := source.skeleton.to_global(source.skeleton.get_bone_global_pose(bone).origin)
		var continued := target.skeleton.to_global(target.skeleton.get_bone_global_pose(bone).origin)
		pose_error = maxf(pose_error, original.distance_to(continued))
	if pose_error > .003:
		return fail("the actual fall handoff displaced a source joint")
	target.animator.seek(length, true)
	if not floor_ok(target, plane, true):
		return false
	handoffs += 1
	source.free()
	target.free()
	return true
