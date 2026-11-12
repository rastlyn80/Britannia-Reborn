# SPDX-License-Identifier: GPL-3.0-or-later
extends "test-source-canines-terrain.gd"

const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const Killed := 0x2010
const Corpse := 0x40010028
const Hue := 0x8035

var transfers := 0
var max_jump := 0.0
var min_gap := INF
var max_frozen_gap := 0.0
var fall_samples := 0


class Arena extends Node3D:
	var avatars := {}


func run() -> void:
	var lower := board(Vector3(4, .2, 8))
	var upper := board(Vector3(4, .2, 8))
	upper.position = Vector3(2, Step - .1, 0)
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	assert(load("res://Presentation/SourceStepQuadrupedProfile.gd").enable())
	for terrain: String in ["flat", "slope", "step"]:
		var split := terrain == "step"
		var normal := Vector3(.13, 1.0, -.10).normalized() if terrain == "slope" else Vector3.UP
		var center := Vector3(-2, 0, 0) if split else Vector3.ZERO
		lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), center - .1 * normal)
		(lower.get_child(0).shape as BoxShape3D).size.x = 4.0 if split else 8.0
		upper.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for body: int in Forms:
			for x: float in ([-.20, .17] if split else [0.0]):
				for yaw: float in [PI * .5, PI * 1.5]:
					var clips := ["Walk", "Run", "Attack", "Death2"]
					if body == 98 or enhanced:
						clips.append("Gesture")
					for clip: String in clips:
						replay(body, x, yaw, clip, normal, split)
	print("STEP QUADRUPED FALL: ", transfers, " decoded transfers, ", fall_samples, " full-skin poses, first jump ",
		max_jump, ", minimum gap ", min_gap, ", maximum frozen gap ", max_frozen_gap, ", Enhanced ", enhanced)
	quit(0 if transfers == (80 if enhanced else 72) and fall_samples == transfers * 17 else 1)


func replay(body: int, x: float, yaw: float, clip: String, normal: Vector3, split: bool) -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var arena := Arena.new()
	root.add_child(arena)
	var items := Items.new()
	arena.add_child(items)
	items.add_child(items.hint)
	items.session = game
	var deaths := Deaths.new()
	arena.add_child(deaths)
	deaths.configure(arena, game, items)
	deaths.set_process(false)
	var avatar := Avatar.new()
	arena.add_child(avatar)
	avatar.position = Vector3(x, Step if split and x > 0.0 else 0.0, 0)
	avatar.rotation.y = yaw
	var source := Registry.create(body)
	avatar.horse_visual = source
	avatar.add_child(source)
	source.apply_identity(body, Hue)
	source.set_process(false)
	source.set_physics_process(false)
	source.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	arena.avatars[Killed] = avatar
	game.entities[Killed] = {"serial": Killed, "body": body, "hue": Hue, "direction": 4}
	source._physics_process(Tick)
	if clip == "Death2":
		var action := PackedByteArray([0x6e])
		action.append_array(Wire.uint_be(Killed, 4))
		action.append_array(PackedByteArray([0, 12, 0, 10, 0, 1, 1, 0, 0]))
		game._handle(action)
		assert(source.receive_action(game.last_mobile_actions[Killed]) and source.dead)
	elif clip == "Gesture":
		if body == 98:
			assert(source.receive_action(source.BreathPacket) and source.current_clip == source.Breath)
		else:
			var action: Array = Gestures[body][2]
			assert(Dispatch.dispatch(avatar, {"protocol": "new", "body": body, "type": action[0],
				"subaction": 0, "variation": action[1]}, true, 0x40))
			assert(source.current_clip == action[2])
	else:
		source.current_clip = clip
		source.animator.play(clip, 0.0)
	source.animator.advance(.13 if clip == "Gesture" else 0.0)
	var launch: float = 1.3 if clip == "Gesture" and body == 98 else source.animator.current_animation_length * .38
	source.animator.seek(launch, true)
	if not source.dead:
		source.contact._process_modification_with_delta(Tick)
		source.contact.modification_processed.emit()
	source.skeleton.force_update_all_bone_transforms()
	var expected_pose := world_joints(source.skeleton)
	var expected_time: float = source.animator.current_animation_position if source.dead else 0.0
	# The packet can select a retained alternate fall or the body's only source fall.
	var expected_clip: String = source.current_clip if clip == "Death2" else "Death"
	var holder := Node3D.new()
	items.add_child(holder)
	items.nodes[Corpse] = holder
	assert(items._equine_corpse(holder, {"id": 0x2006, "amount": body, "hue": Hue, "direction": 4}, Corpse))
	var packet := PackedByteArray([0xaf])
	packet.append_array(Wire.uint_be(Killed, 4))
	packet.append_array(Wire.uint_be(Corpse, 4))
	packet.append_array(Wire.uint_be(0, 4))
	game._handle(packet)
	assert(deaths.active.has(Killed) and not avatar.visible and not holder.visible)
	var visual: Node3D = deaths.active[Killed].visual
	var player: AnimationPlayer = visual.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(visual.current_clip == expected_clip and absf(player.current_animation_position - expected_time) < .001,
		"Fall changed the source route for body %d: %s -> %s" % [body, expected_clip, visual.current_clip])
	assert(visual.contact.death.split == split)
	var details := "%d %s x%.2f yaw%.3f %s" % [body, clip, x, yaw, normal]
	var actual_pose := world_joints(visual.skeleton)
	for index in actual_pose.size():
		var jump := actual_pose[index].distance_to(expected_pose[index])
		assert(jump < .001, "Discontinuous first fall pose %f %s" % [jump, details])
		max_jump = maxf(max_jump, jump)
	for index in 17:
		player.seek(lerpf(expected_time, player.current_animation_length, index / 16.0), true)
		visual.skeleton.force_update_all_bone_transforms()
		var gap := INF
		for part: MeshInstance3D in visual.contact.surfaces:
			if part.is_visible_in_tree():
				gap = minf(gap, skin_gap(visual.contact.surfaces[part], visual.skeleton, normal, split))
		assert(is_finite(gap) and gap >= -.001, "Fall intersected terrain: %f %s" % [gap, details])
		min_gap = minf(min_gap, gap)
		fall_samples += 1
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(Killed, 4))
	game._handle(removal)
	arena.avatars.erase(Killed)
	avatar.free()
	deaths._process(float(deaths.active[Killed].remaining) + .1)
	assert(holder.visible and items.corpse_snapshots.has(Corpse))
	var frozen := holder.get_node("CorpseVisual") as Node3D
	assert(frozen.get_meta("corpse_body") == body and frozen.get_meta("native_hue") == Hue)
	assert(frozen.get_meta("static_cadaver") and frozen.get_meta("death_clip") == expected_clip)
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	var frozen_gap := INF
	for mesh: MeshInstance3D in frozen.get_children():
		for surface in mesh.mesh.get_surface_count():
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var position := mesh.to_global(point)
				var depth := ground_gap(position, normal, split)
				frozen_gap = minf(frozen_gap, depth)
	assert(absf(frozen_gap - .002) < .001, "Frozen body did not settle: %f %s" % [frozen_gap, details])
	max_frozen_gap = maxf(max_frozen_gap, frozen_gap)
	arena.free()
	game.free()
	transfers += 1


func world_joints(rig: Skeleton3D) -> PackedVector3Array:
	rig.force_update_all_bone_transforms()
	var positions := PackedVector3Array()
	for bone in rig.get_bone_count():
		positions.append(rig.to_global(rig.get_bone_global_pose(bone).origin))
	return positions
