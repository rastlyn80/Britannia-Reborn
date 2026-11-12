# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Mounts := preload("res://Presentation/MountVisual.gd")
const Llama := preload("res://Presentation/LlamaActions.gd")

var posed := 0
var falls := 0
var handoffs := 0
var minimum_gap := INF
var maximum_handoff := 0.0


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	Llama.configure(true)
	var original_pack := "--original-pack" in OS.get_cmdline_user_args()
	if Llama.active_library == null or Llama.active_pack != original_pack:
		fail("the prepared llama library or expected source pack is missing")
		return
	var bodies := [Llama.Body, Llama.PackBody] if original_pack else [Llama.Body]
	var board := StaticBody3D.new()
	root.add_child(board)
	var surface := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10.0, 0.1, 10.0)
	surface.shape = shape
	board.add_child(surface)
	for normal: Vector3 in [Vector3.UP, Vector3(.20, 1., .19).normalized(), Vector3(-.23, 1., -.27).normalized()]:
		board.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), -.05 * normal)
		await physics_frame
		await physics_frame
		for body: int in bodies:
			for facing in [0.0, PI / 4.0, -PI / 2.0]:
				if not sample(board, normal, body, facing, false) or not sample(board, normal, body, facing, true):
					return
				if body == Llama.Body and not sample_alerts(board, normal, facing):
					return
	var unsupported := make_actor(bodies.back(), 0.)
	unsupported.position.x = 7.0
	if unsupported.llama_actions.fall.floor_under(unsupported).has("collider"):
		fail("the platform must have a finite edge")
		return
	print("LLAMA TERRAIN: ", posed, " skin poses, ", falls, " falls, ", handoffs,
		" handoffs, minimum gap ", minimum_gap, " m, maximum joint transfer ", maximum_handoff, " m")
	unsupported.queue_free()
	board.queue_free()
	await process_frame
	quit()


func make_actor(body: int, facing: float) -> Node3D:
	var actor := Mounts.create(body)
	root.add_child(actor)
	actor.apply_identity(body, 0)
	actor.rotation.y = facing
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func sample(board: StaticBody3D, normal: Vector3, body: int, facing: float, classic: bool) -> bool:
	var source := make_actor(body, facing)
	var target := make_actor(body, facing)
	var request := {"protocol": "classic", "action": 12} if classic else {
		"protocol": "new", "type": 3, "body": body, "variation": 0}
	var accepted: bool = source.receive_action(request) if classic else source.receive_enhanced_action(request, 0)
	var plane: Dictionary = source.llama_actions.fall.plane
	if not accepted or plane.get("collider") != board or plane.normal.distance_to(normal) > .001:
		return fail("the selected fall failed to resolve the actual support plane")
	source.animator.advance(0.)
	var length: float = source.animator.current_animation_length
	for frame in 25:
		source.animator.seek(length * float(frame) / 24.0, true)
		if not supported(source, plane, frame == 24):
			return false
	source.animator.seek(length * .46, true)
	target.global_transform = source.global_transform
	target.model.transform = source.model.transform
	var remaining: float = target.llama_actions.begin_death_from(target, source)
	if remaining <= 0.0 or target.current_clip != source.current_clip:
		return fail("the handoff must continue the displayed fall")
	for bone in source.skeleton.get_bone_count():
		var from: Vector3 = source.skeleton.to_global(source.skeleton.get_bone_global_pose(bone).origin)
		var to: Vector3 = target.skeleton.to_global(target.skeleton.get_bone_global_pose(bone).origin)
		maximum_handoff = maxf(maximum_handoff, from.distance_to(to))
	if maximum_handoff > .003:
		return fail("continuing the fall displaced the visible pose by %.6f m" % maximum_handoff)
	target.animator.seek(length, true)
	if not supported(target, plane, true):
		return false
	falls += 1
	handoffs += 1
	source.free()
	target.free()
	return true


func sample_alerts(board: StaticBody3D, normal: Vector3, facing: float) -> bool:
	var actor := make_actor(Llama.Body, facing)
	for action in [0, 4, 5, 8]:
		var request := {"protocol": "new", "type": action, "body": Llama.Body, "variation": 0}
		if not actor.receive_enhanced_action(request, 0):
			return fail("missing the fitted grounded gesture")
		actor.animator.advance(0.)
		var length: float = actor.animator.current_animation_length
		for frame in 13:
			actor.animator.seek(length * float(frame) / 12.0, true)
			var plane := {"position": board.global_position + .05 * normal, "normal": normal}
			if not supported(actor, plane, false):
				return false
	actor.free()
	return true


func supported(actor: Node3D, plane: Dictionary, settled: bool) -> bool:
	var rig: Skeleton3D = actor.skeleton
	var skin: Dictionary = actor.llama_actions.fall.skin
	var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.position, plane.normal)
	if not is_finite(gap) or gap < -.0005 or (settled and absf(gap - .002) > .0005):
		return fail("%s body %d has unsupported skin at %.6f m" % [actor.current_clip, actor.native_body, gap])
	minimum_gap = minf(minimum_gap, gap)
	posed += 1
	return true


func fail(message: String) -> bool:
	printerr("LLAMA TERRAIN FAIL: ", message)
	quit(1)
	return false
