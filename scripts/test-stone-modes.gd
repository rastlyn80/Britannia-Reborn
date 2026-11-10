# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const SLOPES := [Vector3.ZERO, Vector3(.13, 0., 0.), Vector3(0., 0., -.13)]
const MODES := {22: "StonePeaceWalk", 23: "StoneKneelRise", 24: "Run", 25: "ReadyStance",
	26: "StonePeaceGesture", 27: "StoneWarGesture", 28: "StoneStanceRise"}
var poses := 0
var least := INF
var routes := 0
var knee_range := INF

func _initialize() -> void:
	create_timer(55.).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var row := Registry.entry(705)
	var original: Dictionary = row.stone_mode_predecessor
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[705] = {"serial": 705, "body": 705}
	for treatment: String in row.assets:
		var previous := (load(original.assets[treatment]) as PackedScene).instantiate()
		var old := previous.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var actor := Registry.create(705)
		actor.treatment = treatment
		root.add_child(actor)
		actor.apply_identity(705, 0)
		for clip: String in old.get_animation_list():
			if clip == "Run": continue
			assert(same_animation(old.get_animation(clip), actor.animator.get_animation(clip)), str([treatment, clip]))
		previous.free()
		for group: int in MODES:
			actor.dead = false
			assert(actor.receive_action(decode(game, group, false)) and actor.current_clip == MODES[group])
			routes += 1
		for kind: String in row.new_action_categories:
			actor.dead = false
			assert(actor.receive_action(decode(game, int(kind), true)) and actor.current_clip == row.new_action_categories[kind])
			routes += 1
		actor.action_remaining = 0.
		actor.set_native_combat_flags(0)
		actor.play_gait(false, 0.)
		assert(actor.current_clip == "ReadyStance")
		actor.play_gait(true, 2.0)
		assert(actor.current_clip == "StonePeaceWalk")
		actor.play_gait(true, 5.0)
		assert(actor.current_clip == "Run")
		actor.set_native_combat_flags(0x40)
		assert(actor.current_clip == "StoneStanceRise")
		actor.action_remaining = 0.
		actor.play_gait(false, 0.)
		assert(actor.current_clip == "Idle")
		actor.play_gait(true, 2.0)
		assert(actor.current_clip == "Walk")
		actor.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for treatment: String in row.assets:
			sample(plane, treatment)
		plane.free()
		await physics_frame
	game.free()
	assert(routes == 39 and poses == 1575)
	print("STONE MODE CLIENT: ", routes, " decoded actions, ", poses, " terrain poses, ", knee_range, " m kneel excursion")
	quit()

func sample(plane: StaticBody3D, treatment: String) -> void:
	var actor := Registry.create(705)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(705, 0)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var anchor := actor.global_transform
	var normal := plane.global_basis.y.normalized()
	for clip: String in MODES.values():
		player.stop()
		actor.current_clip = clip
		player.play(clip, 0.)
		player.advance(0.)
		var minimum_hip := INF
		var maximum_hip := -INF
		for index in 25:
			player.seek(player.current_animation_length * index / 24., true)
			actor._physics_process(1. / 60.)
			actor.contact._process_modification_with_delta(1. / 60.)
			rig.force_update_all_bone_transforms()
			actor.contact.modification_processed.emit()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			assert(is_finite(gap) and gap >= -.004 and actor.global_transform == anchor, str([treatment, clip, index, gap]))
			least = minf(least, gap)
			var hip := rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 pelvis")).origin).y
			minimum_hip = minf(minimum_hip, hip)
			maximum_hip = maxf(maximum_hip, hip)
			poses += 1
		if clip == "StoneKneelRise":
			knee_range = minf(knee_range, maximum_hip - minimum_hip)
			assert(knee_range > .12, str([treatment, minimum_hip, maximum_hip]))
	actor.free()

func same_animation(first: Animation, second: Animation) -> bool:
	if first == null or second == null or first.length != second.length or first.get_track_count() != second.get_track_count():
		return false
	for track in first.get_track_count():
		if first.track_get_path(track) != second.track_get_path(track) or first.track_get_key_count(track) != second.track_get_key_count(track):
			return false
		for key in first.track_get_key_count(track):
			if first.track_get_key_time(track, key) != second.track_get_key_time(track, key) or first.track_get_key_value(track, key) != second.track_get_key_value(track, key):
				return false
	return true

func decode(game: Node, action: int, newer: bool) -> Dictionary:
	var packet := PackedByteArray([0xe2 if newer else 0x6e, 0, 0, 2, 193])
	packet.append_array(PackedByteArray([0, action, 0, 0, 0] if newer else [0, action, 0, 7, 0, 1, 1, 0, 0]))
	game._handle(packet)
	return game.last_mobile_actions[705]

func support(tilt: Vector3) -> StaticBody3D:
	var plane := StaticBody3D.new()
	root.add_child(plane)
	plane.rotation = tilt
	var box := BoxShape3D.new()
	box.size = Vector3(8., .1, 8.)
	var collider := CollisionShape3D.new()
	collider.shape = box
	collider.position.y = -.05
	plane.add_child(collider)
	await physics_frame
	await physics_frame
	return plane
