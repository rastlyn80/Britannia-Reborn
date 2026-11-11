# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Mounts := preload("res://Presentation/MountVisual.gd")
const Magical := preload("res://Presentation/SourceMagicalEquine.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")

var samples := 0
var handoffs := 0
var pose_error := 0.
var flat_min := INF
var slope_min := INF


func _initialize() -> void:
	create_timer(90.).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	Magical.configure(true)
	for body: int in Magical.Forms:
		var actor := spawn(body, 0.)
		if not actor.fitted:
			fail("the complete fitted candidate must be available")
			return
		var groups := ["Walk", "Run", "Idle", "CombatWalk", "CombatIdle"]
		for action: String in Magical.EnhancedGroups[body].values():
			if not action in groups:
				groups.append(action)
		if body == 132:
			groups.append_array(["HoverGather", "MountedIdle", "MountedWalk", "MountedRun"])
		for clip: String in groups:
			if not sample_flat(actor, clip):
				return
		var side := sample_endpoint(actor, "Death")
		var back := sample_endpoint(actor, "Death2")
		if not side.is_finite() or not back.is_finite() or side.distance_to(back) < .16:
			fail("the two fall endpoints need distinct head positions")
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
		for body: int in Magical.Forms:
			for facing: float in [0., PI * .25, -PI * .5]:
				for variant in 2:
					if not sample_fall(board, normal, body, facing, variant):
						return
	var edge := spawn(122, 0.)
	edge.position.x = 7.
	if edge.fall.floor_under(edge).has("collider"):
		fail("the tested board must have a finite edge")
		return
	print("MAGICAL EQUINE TERRAIN: ", samples, " skin poses, ", handoffs,
		" fall handoffs, flat minimum ", flat_min, " m, slope minimum ", slope_min,
		" m, max handoff ", pose_error, " m")
	quit()


func spawn(body: int, facing: float) -> Magical:
	var actor := Mounts.create(body) as Magical
	root.add_child(actor)
	actor.apply_identity(body, 0)
	actor.rotation.y = facing
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.enabled = false
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func sample_flat(actor: Magical, clip: String) -> bool:
	if not actor.animator.has_animation(clip):
		return fail("missing registered " + clip)
	actor.animator.stop()
	actor.skeleton.reset_bone_poses()
	actor.animator.play(clip, 0.)
	actor.animator.advance(0.)
	var length := actor.animator.current_animation_length
	for frame in 33:
		actor.animator.seek(length * float(frame) / 32., true)
		actor.skeleton.force_update_all_bone_transforms()
		var bounds := Geometry.deformed_bounds(actor.contact.surface, actor.skeleton)
		var hovering := clip == "HoverGather"
		if (not bounds.is_finite() or bounds.get_longest_axis_size() < 1.4 or bounds.position.y < -.006
				or (hovering and bounds.position.y < .10)):
			return fail("body %d %s frame %d has invalid bounds %s" % [actor.native_body, clip, frame, bounds])
		flat_min = minf(flat_min, bounds.position.y)
		samples += 1
	return true


func sample_endpoint(actor: Magical, clip: String) -> Vector3:
	actor.animator.play(clip, 0.)
	actor.animator.advance(0.)
	actor.animator.seek(actor.animator.current_animation_length, true)
	var joint := actor.skeleton.find_bone("bip01 head")
	return actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(joint).origin)


func sample_fall(board: StaticBody3D, normal: Vector3, body: int, facing: float, variant: int) -> bool:
	var source := spawn(body, facing)
	var target := spawn(body, facing)
	var action := {"protocol": "new", "body": body, "type": 3, "variation": variant, "subaction": 0}
	if not source.receive_enhanced_action(action, 0):
		return fail("the fitted fall rejected its registered selector")
	var plane: Dictionary = source.fall.plane
	if plane.get("collider") != board or plane.normal.distance_to(normal) > .001:
		return fail("the fitted fall did not pick the actual terrain")
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


func floor_ok(actor: Magical, plane: Dictionary, settled: bool) -> bool:
	var rig := actor.skeleton
	var distance := Ground.minimum_plane_gap(actor.fall.skin, rig, rig.global_transform, plane.position, plane.normal)
	if not is_finite(distance) or distance < -.0005 or (settled and absf(distance - .002) > .0005):
		return fail("body %d %s has invalid support at %.6f m" % [actor.native_body, actor.current_clip, distance])
	slope_min = minf(slope_min, distance)
	samples += 1
	return true


func fail(message: String) -> bool:
	printerr("MAGICAL EQUINE TERRAIN FAIL: ", message)
	quit(1)
	return false
