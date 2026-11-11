# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Cattle := preload("res://Presentation/SourceEnhancedBovineVisual.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")

var poses := 0
var handoffs := 0
var minimum_gap := INF
var maximum_rest_error := 0.
var maximum_handoff := 0.


func _initialize() -> void:
	create_timer(100.).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	if not Cattle.enable():
		fail("prepared cattle assets are unavailable")
		return
	var board := StaticBody3D.new()
	board.collision_layer = 1
	root.add_child(board)
	var top := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(12., .10, 12.)
	top.shape = shape
	board.add_child(top)
	for normal: Vector3 in [Vector3.UP, Vector3(.20, 1., .17).normalized(), Vector3(-.21, 1., -.29).normalized()]:
		board.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), -.05 * normal)
		await physics_frame
		await physics_frame
		for body: int in Cattle.Bodies:
			for treatment: String in Cattle.Treatments:
				for angle: float in [0., PI * .25, PI * -.5]:
					if not sample(board, normal, body, treatment, angle):
						return
	var unsupported := make_actor(216, "modern", 0.)
	unsupported.position.x = 8.
	if unsupported.support_plane().has("collider"):
		fail("support ray outside the finite platform")
		return
	print("CATTLE TERRAIN: ", poses, " full-skin poses, ", handoffs, " handoffs, min gap ", minimum_gap,
		" m, maximum settled error ", maximum_rest_error, " m, maximum joint displacement ", maximum_handoff, " m")
	quit()


func make_actor(body: int, treatment: String, angle: float) -> Cattle:
	var actor := Cattle.new()
	actor.kind = Cattle.Bodies[body]
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0)
	actor.rotation.y = angle
	actor.set_physics_process(false)
	actor.set_process(false)
	return actor


func sample(board: StaticBody3D, normal: Vector3, body: int, treatment: String, angle: float) -> bool:
	var source := make_actor(body, treatment, angle)
	var target := make_actor(body, treatment, angle)
	var action := {"protocol": "new", "type": 3, "body": body, "variation": 0}
	if not source.receive_enhanced_action(action, 0x40) or source.fitted_fall.plane.get("collider") != board \
			or source.fitted_fall.plane.normal.distance_to(normal) > .001:
		return fail("missing native support plane")
	source.animator.advance(0.)
	var length := source.animator.current_animation_length
	for index in 25:
		source.animator.seek(length * float(index) / 24., true)
		if not floor_ok(source, index == 24):
			return false
	source.animator.seek(length * .44, true)
	var remaining := target.begin_death_from(source)
	if remaining <= 0. or target.current_clip != Cattle.FittedFall:
		return fail("handoff did not continue the displayed fall")
	for bone in source.skeleton.get_bone_count():
		var before := source.skeleton.to_global(source.skeleton.get_bone_global_pose(bone).origin)
		var after := target.skeleton.to_global(target.skeleton.get_bone_global_pose(bone).origin)
		maximum_handoff = maxf(maximum_handoff, before.distance_to(after))
	if maximum_handoff > .0001:
		return fail("fall handoff moves a displayed joint %.6f m" % maximum_handoff)
	for index in 13:
		target.animator.seek(length * lerpf(.44, 1., float(index) / 12.), true)
		if not floor_ok(target, index == 12):
			return false
	source.free()
	target.free()
	handoffs += 1
	return true


func floor_ok(actor: Cattle, final: bool) -> bool:
	var plane := actor.fitted_fall.plane
	var gap := Ground.minimum_plane_gap(actor.fitted_fall.skin, actor.skeleton, actor.skeleton.global_transform,
		plane.position, plane.normal)
	if not is_finite(gap) or gap < .0018:
		return fail("invalid supported fall clearance %.8f m" % gap)
	minimum_gap = minf(minimum_gap, gap)
	if final:
		maximum_rest_error = maxf(maximum_rest_error, absf(gap - .002))
		if maximum_rest_error > .0001:
			return fail("static corpse does not reach the supporting surface")
	poses += 1
	return true


func fail(reason: String) -> bool:
	printerr("CATTLE TERRAIN FAIL: ", reason)
	quit(1)
	return false
