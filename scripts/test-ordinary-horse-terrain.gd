# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Horse := preload("res://Presentation/HorseVisual.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")

var poses := 0
var minimum_gap := INF
var maximum_rest_error := 0.
var maximum_seam := 0.


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	Horse.enhanced_ordinary_horses = true
	var board := StaticBody3D.new()
	board.collision_layer = 1
	root.add_child(board)
	var surface := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10., .1, 10.)
	surface.shape = shape
	board.add_child(surface)
	for normal: Vector3 in [Vector3.UP, Vector3(.23, 1., .18).normalized(), Vector3(-.18, 1., -.27).normalized()]:
		board.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), -.05 * normal)
		await physics_frame
		await physics_frame
		for body in Horse.Motion.BODIES:
			for angle in [0., PI / 3., -PI / 2.]:
				if not test_horse(board, normal, body, angle):
					return
	var outside := make_actor(226, 0.)
	outside.position.x = 6.5
	if outside.fall.floor_under(outside).has("collider"):
		fail("support ray outside finite board")
		return
	print("ORDINARY HORSE TERRAIN: ", poses, " skin poses, minimum gap ", minimum_gap,
		" m, maximum rest error ", maximum_rest_error, " m, maximum handoff ", maximum_seam, " m")
	quit()


func make_actor(body: int, angle: float) -> Horse:
	var actor := Horse.new()
	root.add_child(actor)
	actor.apply_identity(body, 0)
	actor.rotation.y = angle
	actor.set_physics_process(false)
	actor.set_process(false)
	return actor


func test_horse(board: StaticBody3D, normal: Vector3, body: int, angle: float) -> bool:
	for variation in [0, 1]:
		var source := make_actor(body, angle)
		var target := make_actor(body, angle)
		var action := {"protocol": "new", "type": 3, "body": body, "variation": variation}
		if not source.receive_enhanced_action(action, 0x40) or source.fall.plane.get("collider") != board \
				or source.fall.plane.normal.distance_to(normal) > .001:
			return fail("missing physical board support")
		source.animator.advance(0.)
		var length := source.animator.current_animation_length
		for i in 13:
			source.animator.seek(length * float(i) / 12., true)
			if not verify_floor(source, i == 12):
				return false
		source.animator.seek(length * .42, true)
		var duration := target.begin_native_fall(source)
		if duration <= 0. or target.current_clip != source.current_clip:
			return fail("fall handoff changed selection")
		for bone in source.skeleton.get_bone_count():
			var original := source.skeleton.to_global(source.skeleton.get_bone_global_pose(bone).origin)
			var current := target.skeleton.to_global(target.skeleton.get_bone_global_pose(bone).origin)
			maximum_seam = maxf(maximum_seam, original.distance_to(current))
		if maximum_seam > .0001:
			return fail("fall seam moved a bone")
		for i in 9:
			target.animator.seek(length * lerpf(.42, 1., float(i) / 8.), true)
			if not verify_floor(target, i == 8):
				return false
		source.free()
		target.free()
	return true


func verify_floor(horse: Horse, held: bool) -> bool:
	var plane := horse.fall.plane
	var gap := Ground.minimum_plane_gap(horse.fall.skin, horse.skeleton, horse.skeleton.global_transform,
		plane.position, plane.normal)
	if not is_finite(gap) or gap < .0018:
		return fail("skin cuts into support plane: %f" % gap)
	minimum_gap = minf(minimum_gap, gap)
	if held:
		maximum_rest_error = maxf(maximum_rest_error, absf(gap - .002))
		if maximum_rest_error > .0001:
			return fail("frozen fall does not settle to support")
	poses += 1
	return true


func fail(message: String) -> bool:
	printerr("ORDINARY HORSE TERRAIN FAIL: ", message)
	quit(1)
	return false
