# SPDX-License-Identifier: GPL-3.0-or-later
extends "test-cat-living-terrain.gd"

const Snapshots := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Living := [["Idle", .25], ["Walk", .50], ["Run", .25], ["CatStretch", .32]]
var transfers := 0
var maximum_jump := 0.0
var minimum_gap := INF
var largest_final_gap := 0.0
var worst_pose := {}


func run() -> void:
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	var lower := board(Vector3(6.0, .2, 6.0))
	var upper := board(Vector3(4.0, .2, 6.0))
	upper.position = Vector3(2.0, Height - .1, 0.0)
	for normal: Vector3 in [Vector3.UP, Vector3(.17, 1.0, -.10).normalized(), Vector3.ZERO]:
		var split := normal == Vector3.ZERO
		var up := Vector3.UP if split else normal
		var center := Vector3(-2.0, 0.0, 0.0) if split else Vector3.ZERO
		lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), center - .1 * up)
		(lower.get_child(0).shape as BoxShape3D).size.x = 4.0 if split else 6.0
		upper.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for x: float in ([-.14, .14] if split else [0.0]):
			for yaw: float in [0.0, PI * .5, PI * 1.5]:
				for action: Array in Living:
					replay(x, yaw, normal, action[0], action[1])
				if enhanced:
					replay(x, yaw, normal, "CatRearAndSwipe", .58)
				for clip: String in ["Death", "Death2"]:
					replay(x, yaw, normal, clip, .32)
	var report := {"transfers": transfers, "poses": poses, "initial_jump_m": maximum_jump,
		"minimum_gap_m": minimum_gap, "final_gap_m": largest_final_gap, "worst_pose": worst_pose}
	print("CAT FALL TRANSFERS: ", report)
	var ok := transfers == (84 if enhanced else 72) and poses == transfers * 25
	ok = ok and maximum_jump < .001 and minimum_gap >= .0014 and largest_final_gap < .0021
	lower.queue_free()
	upper.queue_free()
	await process_frame
	quit(0 if ok else 1)


func actor_at(x: float, yaw: float) -> Node3D:
	var actor := Candidate.new()
	actor.entry = Registry.entry(201)
	actor.position = Vector3(x, Height if x > 0.0 else 0.0, 0.0)
	actor.rotation.y = yaw
	root.add_child(actor)
	actor.apply_identity(201, 0x650)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func replay(x: float, yaw: float, normal: Vector3, clip: String, phase: float) -> void:
	var source := actor_at(x, yaw)
	if clip in ["Death", "Death2"]:
		source._physics_process(1.0 / 60.0)
		assert(source.receive_action({"protocol": "classic", "action": 12 if clip == "Death" else 8}))
		assert(source.current_clip == clip)
	else:
		source.current_clip = clip
		source.animator.play(clip, 0.0)
	source.animator.advance(0.0)
	source.animator.seek(source.animator.current_animation_length * phase, true)
	if not source.dead:
		source._physics_process(1.0 / 60.0)
		source.contact._process_modification_with_delta(1.0 / 60.0)
		source.contact.modification_processed.emit()
	var target := actor_at(x, yaw)
	target.dead = true
	target.contact.enabled = false
	var duration: float = target.begin_death_from(source)
	var expected := clip if source.dead else "Death"
	assert(target.current_clip == expected and duration > 0.0)
	var jump := greatest_joint_delta(source.skeleton, target.skeleton)
	if jump > maximum_jump:
		maximum_jump = jump
		worst_pose = {"clip": clip, "phase": phase, "x": x, "yaw": yaw, "normal": str(normal)}
	var beginning: float = target.animator.current_animation_position
	var skin: Dictionary = target.fall.skin
	for frame in 25:
		var time := lerpf(beginning, target.animator.current_animation_length, frame / 24.0)
		target.animator.seek(time, true)
		target.skeleton.force_update_all_bone_transforms()
		var gap := step_gap(skin, target.skeleton) if normal == Vector3.ZERO else Ground.minimum_plane_gap(
			skin, target.skeleton, target.skeleton.global_transform, Vector3.ZERO, normal)
		assert(is_finite(gap))
		minimum_gap = minf(minimum_gap, gap)
		if frame == 24:
			largest_final_gap = maxf(largest_final_gap, gap)
		poses += 1
	var captured := Snapshots.capture(target, target.corpse_snapshot_floor())
	assert(not captured.is_empty() and captured.body == 201)
	var frozen := captured.scene.instantiate() as Node3D
	assert(frozen.get_meta("native_hue") == 0x650 and frozen.get_meta("death_clip") == expected)
	frozen.free()
	source.free()
	target.free()
	transfers += 1


func greatest_joint_delta(before: Skeleton3D, after: Skeleton3D) -> float:
	before.force_update_all_bone_transforms()
	after.force_update_all_bone_transforms()
	var largest := 0.0
	for index in before.get_bone_count():
		var prior := before.to_global(before.get_bone_global_pose(index).origin)
		var current := after.to_global(after.get_bone_global_pose(index).origin)
		largest = maxf(largest, prior.distance_to(current))
	return largest
