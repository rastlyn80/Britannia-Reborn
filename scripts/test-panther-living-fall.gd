# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Cougar := preload("res://Presentation/SourceLivingCougarVisual.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Snapshots := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const StepHeight := .22
const Living := [["Fidget", .25], ["Fidget", .833333], ["Walk", .5], ["Hit", .25]]
var enhanced := "--enhanced" in OS.get_cmdline_user_args()
var transfers := 0
var frames := 0
var greatest_jump := 0.0
var minimum_gap := INF
var highest_final_gap := 0.0


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	var lower := box(Vector3(6, .2, 6))
	var upper := box(Vector3(4, .2, 6))
	upper.position = Vector3(2, StepHeight - .1, 0)
	for normal: Vector3 in [Vector3.UP, Vector3(.17, 1, -.10).normalized(), Vector3.ZERO]:
		var split := normal == Vector3.ZERO
		var up := Vector3.UP if split else normal
		var center := Vector3(-2, 0, 0) if split else Vector3.ZERO
		lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), center - .1 * up)
		(lower.get_child(0).shape as BoxShape3D).size.x = 4.0 if split else 6.0
		upper.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for x: float in ([-.14, .14] if split else [0.0]):
			for yaw: float in [0.0, PI * .5, PI * 1.5]:
				for start: Array in Living:
					replay(x, yaw, normal, start[0], start[1])
				for clip: String in ["Death", "Death2"]:
					replay(x, yaw, normal, clip, .32)
	assert(transfers == 72 and frames == transfers * 25)
	assert(greatest_jump < .001 and minimum_gap >= .0019 and highest_final_gap < .0021)
	print("PANTHER FALL: ", transfers, " transfers, ", frames, " poses, maximum initial jump ", greatest_jump,
		" m, minimum gap ", minimum_gap, " m, largest final gap ", highest_final_gap, " m")
	lower.queue_free()
	upper.queue_free()
	await process_frame
	quit()


func box(size: Vector3) -> StaticBody3D:
	var result := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	result.add_child(collision)
	root.add_child(result)
	return result


func actor_at(x: float, yaw: float) -> Node3D:
	var actor := Cougar.new()
	actor.entry = Registry.entry(214)
	actor.position = Vector3(x, StepHeight if x > 0.0 else 0.0, 0)
	actor.rotation.y = yaw
	root.add_child(actor)
	actor.apply_identity(214, 0x901)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func replay(x: float, yaw: float, normal: Vector3, start: String, phase: float) -> void:
	var source := actor_at(x, yaw)
	var split := normal == Vector3.ZERO
	if start in ["Death", "Death2"]:
		source._physics_process(1.0 / 60.0)
		assert(source.receive_action({"protocol": "classic", "action": 12 if start == "Death" else 8}))
		assert(source.current_clip == start)
	else:
		source.current_clip = start
		source.animator.play(start, 0)
	source.animator.advance(0.0)
	source.animator.seek(source.animator.current_animation_length * phase, true)
	if not source.dead:
		source._physics_process(1.0 / 60.0)
		source.contact._process_modification_with_delta(1.0 / 60.0)
		source.contact.modification_processed.emit()
	source.skeleton.force_update_all_bone_transforms()
	var transition := actor_at(x, yaw)
	transition.dead = true
	transition.contact.enabled = false
	var duration: float = transition.begin_death_from(source)
	var expected := start if source.dead else "Death"
	assert(transition.current_clip == expected and duration > 0.0)
	var jump := maximum_joint_delta(source.skeleton, transition.skeleton)
	if jump > greatest_jump:
		greatest_jump = jump
		print("PANTHER FALL NEW MAX ", start, " ", phase, " at ", [x, yaw, str(normal)], " = ", jump)
	var beginning: float = transition.animator.current_animation_position
	for frame in 25:
		var time := lerpf(beginning, transition.animator.current_animation_length, frame / 24.0)
		transition.animator.seek(time, true)
		transition.skeleton.force_update_all_bone_transforms()
		var gap := floor_gap(transition.skin[0], transition.skeleton, normal)
		assert(is_finite(gap))
		minimum_gap = minf(minimum_gap, gap)
		if frame == 24:
			highest_final_gap = maxf(highest_final_gap, gap)
		frames += 1
	var captured := Snapshots.capture(transition, transition.corpse_snapshot_floor())
	assert(not captured.is_empty() and captured.body == 214)
	var frozen := captured.scene.instantiate() as Node3D
	assert(frozen.get_meta("native_hue") == 0x901 and frozen.get_meta("death_clip") == expected)
	frozen.free()
	source.free()
	transition.free()
	transfers += 1


func maximum_joint_delta(before: Skeleton3D, after: Skeleton3D) -> float:
	before.force_update_all_bone_transforms()
	after.force_update_all_bone_transforms()
	var maximum := 0.0
	for index in before.get_bone_count():
		var prior := before.to_global(before.get_bone_global_pose(index).origin)
		var current := after.to_global(after.get_bone_global_pose(index).origin)
		maximum = maxf(maximum, prior.distance_to(current))
	return maximum


func floor_gap(skin: Dictionary, rig: Skeleton3D, normal: Vector3) -> float:
	if normal != Vector3.ZERO:
		return Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
	var matrices: Array[Transform3D] = []
	for index in skin.bones.size():
		matrices.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[index]) * skin.bind_poses[index])
	var minimum := INF
	for surface: Dictionary in skin.surfaces:
		for vertex in surface.points.size():
			var point := Vector3.ZERO
			for influence in surface.stride:
				var slot: int = vertex * surface.stride + influence
				var weight: float = surface.weights[slot]
				if weight > 0.0:
					point += matrices[surface.bindings[slot]] * surface.points[vertex] * weight
			minimum = minf(minimum, point.y - (StepHeight if point.x > 0.0 else 0.0))
	return minimum
