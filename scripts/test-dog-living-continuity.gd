# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const StepHeight := .22
var movement := {}
var frames := 0


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	assert(preload("res://Presentation/SourceDogLivingTerrainProfile.gd").enable())
	floor_box(-2, 0)
	floor_box(2, StepHeight)
	await physics_frame
	await physics_frame
	for clip: String in ["Fidget", "Hit", "Walk", "Run", "HoundBowSnap", "HoundScentCheck"]:
		for x: float in [-.30, -.14, -.07, .07, .14]:
			for yaw: float in [0, PI * .5, PI * 1.5]:
				sample(clip, x, yaw)
	assert(frames == 5070)
	for record: Dictionary in movement.values():
		assert(record.get("largest_frame_jump_m", 0.0) < .061 and record.get("max_lift_m", 0.0) < .09)
	print("DOG STEP CONTINUITY: ", frames, " poses ", movement)
	quit()


func floor_box(x: float, y: float) -> void:
	var board := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, .2, 6)
	collision.shape = shape
	board.position = Vector3(x, y - .1, 0)
	board.add_child(collision)
	root.add_child(board)


func sample(clip: String, x: float, yaw: float) -> void:
	var actor := Registry.create(217)
	actor.position = Vector3(x, StepHeight if x > 0 else 0, 0)
	actor.rotation.y = yaw
	root.add_child(actor)
	actor.apply_identity(217, 0)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.current_clip = clip
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor.animator.play(clip, 0)
	actor.animator.advance(0.0)
	var anchor := actor.global_transform
	var previous := Vector3.ZERO
	var samples: int = int(ceil(actor.animator.current_animation_length * 60.0))
	var record: Dictionary = movement.get(clip, {})
	for index in samples + 1:
		var phase := index / float(samples)
		actor.animator.seek(actor.animator.current_animation_length * phase, true)
		actor._physics_process(1.0 / 60.0)
		actor.contact._process_modification_with_delta(1.0 / 60.0)
		actor.contact.modification_processed.emit()
		var correction: Vector3 = actor.crouch_offset + Vector3.UP * actor.support_lift
		if index > 0 and correction.distance_to(previous) > float(record.get("largest_frame_jump_m", 0.0)):
			record.merge({"largest_frame_jump_m": correction.distance_to(previous),
				"phase": phase, "x": x, "yaw": yaw, "prior": str(previous), "next": str(correction)}, true)
		record["max_offset_m"] = maxf(float(record.get("max_offset_m", 0.0)), actor.crouch_offset.length())
		if actor.support_lift > float(record.get("max_lift_m", 0.0)):
			record["max_lift_m"] = actor.support_lift
			var displayed: Vector3 = actor.model.global_position
			actor.model.global_position.y -= actor.support_lift
			var hit: Dictionary = actor.contact.step_conflict(actor.global_position.y, actor.query, actor.skin)
			var closest := joint_at(actor.skeleton, hit.point) if hit.has("point") else ""
			actor.model.global_position = displayed
			record["lift_case"] = {"x": x, "yaw": yaw, "phase": phase, "point": str(hit.get("point")), "joint_nearby": closest}
		assert(actor.global_transform == anchor)
		previous = correction
		frames += 1
	movement[clip] = record
	actor.free()


func joint_at(rig: Skeleton3D, point: Vector3) -> String:
	var distance := INF
	var nearest := ""
	for index in rig.get_bone_count():
		var current := point.distance_to(rig.to_global(rig.get_bone_global_pose(index).origin))
		if current < distance:
			distance = current
			nearest = rig.get_bone_name(index)
	return nearest
