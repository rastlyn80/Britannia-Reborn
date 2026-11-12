# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-dark-horse-terrain.gd"

const Skeletal := preload("res://Presentation/SourceSkeletalHorseVisual.gd")


func run() -> void:
	Skeletal.configure_skeletal(true)
	var actor := spawn(Skeletal.Body, 0.)
	for clip: String in ["Idle", "Walk", "Run", "Attack", "Attack2", "Hit", "Fidget",
			"Fidget2", "Eat", "Death", DarkHorse.Breath]:
		if not sample_source_bounds(actor, clip):
			return
	for clip: String in ["SkeletalCombatIdle", "SkeletalSideFall", "Death2", "SkeletalRearStrike",
			"SkeletalRearCast", "SkeletalForelegGuard", "SkeletalQuietNod", "SkeletalHighFidget", "SkeletalAlert"]:
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
		for facing: float in [0., PI * .25, -PI * .5]:
			if not sample_live_support(board, normal, Skeletal.Body, facing):
				return
			if not sample_fall(board, normal, Skeletal.Body, facing, 0):
				return
			if not sample_fitted_support(board, normal, facing):
				return
			for variant in 2:
				if not sample_fitted_fall(board, normal, facing, variant):
					return
	var edge := spawn(Skeletal.Body, 0.)
	edge.position.x = 7.
	if edge.fall.floor_under(edge).has("collider"):
		fail("the tested board must have a finite edge")
		return
	print("SKELETAL MOUNT TERRAIN: ", samples, " source and fall poses, ", gait_samples, " living supported poses, ",
		handoffs, " transfers, minimum ", corrected_minimum, " m, max transfer ", pose_error, " m")
	quit()


func sample_fitted_support(board: StaticBody3D, normal: Vector3, facing: float) -> bool:
	var actor := spawn(Skeletal.Body, facing) as Skeletal
	var rig := actor.skeleton
	var skin := Ground.skin_points(actor.contact.surface, rig)
	for test: Array in [[0, 0], [2, 0], [4, 0], [5, 0], [5, 1], [8, 0], [11, 0], [14, 0], [15, 0]]:
		var request := {"protocol": "new", "body": Skeletal.Body, "type": test[0], "variation": test[1]}
		if not actor.receive_enhanced_action(request, 0x40):
			return fail("a declared living Enhanced action was rejected")
		actor.animator.advance(.16)
		for frame in 17:
			var phase := float(frame) / 16.
			actor.animator.seek(actor.animator.current_animation_length * phase, true)
			actor._physics_process(1.)
			actor.animator.seek(actor.animator.current_animation_length * phase, true)
			if actor.fall.floor_under(actor).get("collider") != board:
				return fail("the fitted living action did not sample the test plane")
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
			if not is_finite(gap) or gap < .0015 or actor.live_shift.length() > .25:
				return fail("fitted clip %s has invalid ground support at phase %.3f (%.6f m)" %
					[actor.current_clip, phase, gap])
			corrected_minimum = minf(corrected_minimum, gap)
			gait_samples += 1
	actor.free()
	return true


func sample_fitted_fall(board: StaticBody3D, normal: Vector3, facing: float, variant: int) -> bool:
	var source := spawn(Skeletal.Body, facing) as Skeletal
	var target := spawn(Skeletal.Body, facing) as Skeletal
	var request := {"protocol": "new", "body": Skeletal.Body, "type": 3, "variation": variant}
	if not source.receive_enhanced_action(request, 0) or source.enhanced_side_fall != (variant == 0):
		return fail("each registered fall must select its fitted clip")
	var plane := source.fall.plane
	if plane.get("collider") != board or plane.normal.distance_to(normal) > .001:
		return fail("the fitted fall did not pick the test plane")
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
		return fail("the handoff changed the fitted collapse")
	for bone in source.skeleton.get_bone_count():
		var before := source.skeleton.to_global(source.skeleton.get_bone_global_pose(bone).origin)
		var after := target.skeleton.to_global(target.skeleton.get_bone_global_pose(bone).origin)
		pose_error = maxf(pose_error, before.distance_to(after))
	if pose_error > .003:
		return fail("the fitted fall handoff displaced an original joint")
	target.animator.seek(length, true)
	if not floor_ok(target, plane, true):
		return false
	handoffs += 1
	source.free()
	target.free()
	return true
