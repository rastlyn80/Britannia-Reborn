# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-dark-horse-terrain.gd"

const OriginalHorse := preload("res://Presentation/SourceWarHorseVisual.gd")


func run() -> void:
	OriginalHorse.configure_war_horses(true)
	for body: int in OriginalHorse.FormsByBody:
		var actor := spawn(body, 0.)
		for clip: String in actor.animator.get_animation_list():
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
		for body: int in [117, 118, 291]:
			for facing: float in [0., PI * .25, -PI * .5]:
				if not sample_original_support(board, normal, body, facing) or not sample_fall(board, normal, body, facing, 0):
					return
				if body in [118, 291]:
					for variant in 2:
						if not sample_original_fall(board, normal, body, facing, variant):
							return
	var edge := spawn(291, 0.)
	edge.position.x = 7.
	if edge.fall.floor_under(edge).has("collider"):
		fail("the tested terrain must have a finite edge")
		return
	print("ORIGINAL WAR HORSE TERRAIN: ", samples, " source and fall poses, ", gait_samples,
		" supported poses, ", handoffs, " transfers, minimum ", corrected_minimum, " m, max transfer ", pose_error, " m")
	quit()


func spawn(body: int, facing: float) -> Magical:
	if body != OriginalHorse.EtherealBody:
		return super.spawn(body, facing)
	var actor := Mounts.create(body, OriginalHorse.EtherealItem) as Magical
	root.add_child(actor)
	actor.apply_identity(body, 0x4001, OriginalHorse.EtherealItem)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.enabled = false
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func sample_original_support(board: StaticBody3D, normal: Vector3, body: int, facing: float) -> bool:
	var actor := spawn(body, facing) as OriginalHorse
	var rig := actor.skeleton
	var skin := Ground.skin_points(actor.contact.surface, rig)
	for clip: String in actor.animator.get_animation_list():
		if clip in ["Death", "Death2", "HorseSideFall", "LieDown", "RESET"]:
			continue
		actor.animator.stop()
		rig.reset_bone_poses()
		actor.animator.play(clip, 0.)
		actor.animator.advance(0.)
		for frame in 13:
			var phase := float(frame) / 12.
			actor.animator.seek(actor.animator.current_animation_length * phase, true)
			actor.contact.enabled = true
			actor._physics_process(1.)
			actor.animator.seek(actor.animator.current_animation_length * phase, true)
			if actor.fall.floor_under(actor).get("collider") != board:
				return fail("the original skin did not sample the finite test board")
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
			if not is_finite(gap) or gap < .0015 or actor.live_shift.length() > .28:
				return fail("body %d clip %s phase %.3f has invalid support %.6f m" % [body, clip, phase, gap])
			corrected_minimum = minf(corrected_minimum, gap)
			gait_samples += 1
	actor.free()
	return true


func sample_original_fall(board: StaticBody3D, normal: Vector3, body: int, facing: float, variant: int) -> bool:
	var source := spawn(body, facing) as OriginalHorse
	var target := spawn(body, facing) as OriginalHorse
	var action := {"protocol": "new", "body": body, "type": 3, "variation": variant}
	if not source.receive_enhanced_action(action, 0) or source.enhanced_side_fall != (variant == 0):
		return fail("each Enhanced death must select its own fitted fall")
	var plane := source.fall.plane
	if plane.get("collider") != board or plane.normal.distance_to(normal) > .001:
		return fail("the fitted fall did not sample the test board")
	source.animator.advance(.16)
	var length := source.animator.current_animation_length
	for frame in 25:
		source.animator.seek(length * float(frame) / 24., true)
		if not floor_ok(source, plane, frame == 24):
			return false
	source.animator.seek(length * .42, true)
	target.model.transform = source.model.transform
	target.global_transform = source.global_transform
	if target.begin_source_death(source) <= 0. or target.current_clip != source.current_clip:
		return fail("the transfer changed the selected fitted fall")
	for bone in source.skeleton.get_bone_count():
		var before := source.skeleton.to_global(source.skeleton.get_bone_global_pose(bone).origin)
		var after := target.skeleton.to_global(target.skeleton.get_bone_global_pose(bone).origin)
		pose_error = maxf(pose_error, before.distance_to(after))
	if pose_error > .003:
		return fail("fall transfer displaced an original joint")
	target.animator.seek(length, true)
	if not floor_ok(target, plane, true):
		return false
	handoffs += 1
	source.free()
	target.free()
	return true
