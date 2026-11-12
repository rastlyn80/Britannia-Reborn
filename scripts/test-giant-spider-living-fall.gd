# SPDX-License-Identifier: GPL-3.0-or-later
extends "test-giant-spider-living-crossing.gd"

const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const Killed := 0x2010
const Corpse := 0x40010028
const Body := 28
const Hue := 0x8035

var transfers := 0
var max_jump := 0.0
var min_gap := INF
var max_frozen_gap := 0.0


class Arena extends Node3D:
	var avatars := {}


class Avatar extends Node3D:
	var horse_visual: Node3D


func run() -> void:
	lower = floor_board(4.0, -2.0, 0.0)
	upper = floor_board(4.0, 2.0, Height)
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	assert(load("res://Presentation/SourceGiantSpiderTerrainProfile.gd").enable())
	var row := Registry.entry(Body)
	for board: String in ["flat", "slope", "step"]:
		var split := board == "step"
		var normal := Vector3(.13, 1.0, -.10).normalized() if board == "slope" else Vector3.UP
		var center := Vector3(-2, 0, 0) if split else Vector3.ZERO
		lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), center - .1 * normal)
		(lower.get_child(0).shape as BoxShape3D).size.x = 4.0 if split else 8.0
		upper.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for treatment: String in row.assets:
			for x: float in ([-.20, .17] if split else [0.0]):
				for yaw: float in [PI * .5, PI * 1.5]:
					for clip: String in ["Walk", "Run", "Death2"]:
						replay(treatment, x, yaw, clip, normal, split)
	print("GIANT SPIDER FALL: ", transfers, " decoded transfers, ", samples, " full-skin poses, first jump ",
		max_jump, ", minimum gap ", min_gap, ", maximum frozen gap ", max_frozen_gap, ", Enhanced ", enhanced)
	quit(0 if transfers == 72 and samples == 1224 else 1)


func replay(treatment: String, x: float, yaw: float, clip: String, normal: Vector3, split: bool) -> void:
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
	avatar.position = Vector3(x, Height if split and x > 0.0 else 0.0, 0)
	avatar.rotation.y = yaw
	var source := Registry.create(Body)
	avatar.horse_visual = source
	source.treatment = treatment
	avatar.add_child(source)
	source.apply_identity(Body, Hue)
	source.set_process(false)
	source.set_physics_process(false)
	source.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	arena.avatars[Killed] = avatar
	game.entities[Killed] = {"serial": Killed, "body": Body, "hue": Hue, "direction": 4}
	source._physics_process(Tick)
	if clip == "Death2":
		var action := PackedByteArray([0x6e])
		action.append_array(Wire.uint_be(Killed, 4))
		action.append_array(PackedByteArray([0, 3, 0, 10, 0, 1, 1, 0, 0]))
		game._handle(action)
		assert(source.receive_action(game.last_mobile_actions[Killed]) and source.dead)
	else:
		source.current_clip = clip
		source.animator.play(clip, 0.0)
	source.animator.advance(0.0)
	source.animator.seek(source.animator.current_animation_length * .38, true)
	if not source.dead:
		source.contact._process_modification_with_delta(Tick)
		source.contact.modification_processed.emit()
	source.skeleton.force_update_all_bone_transforms()
	var expected_pose := world_joints(source.skeleton)
	var expected_time: float = source.animator.current_animation_position if source.dead else 0.0
	var holder := Node3D.new()
	items.add_child(holder)
	items.nodes[Corpse] = holder
	assert(items._equine_corpse(holder, {"id": 0x2006, "amount": Body, "hue": Hue, "direction": 4}, Corpse))
	var packet := PackedByteArray([0xaf])
	packet.append_array(Wire.uint_be(Killed, 4))
	packet.append_array(Wire.uint_be(Corpse, 4))
	packet.append_array(Wire.uint_be(0, 4))
	game._handle(packet)
	assert(deaths.active.has(Killed) and not avatar.visible and not holder.visible)
	var visual: Node3D = deaths.active[Killed].visual
	var player: AnimationPlayer = visual.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var expected_clip := "Death2" if clip == "Death2" else "Death"
	assert(visual.current_clip == expected_clip and absf(player.current_animation_position - expected_time) < .001)
	assert(visual.contact.death.split == split)
	var details := "%s %s x%.2f yaw%.3f %s" % [treatment, clip, x, yaw, normal]
	var actual_pose := world_joints(visual.skeleton)
	for index in actual_pose.size():
		var jump := actual_pose[index].distance_to(expected_pose[index])
		assert(jump < .001, "Discontinuous first fall pose %f %s" % [jump, details])
		max_jump = maxf(max_jump, jump)
	for index in 17:
		player.seek(lerpf(expected_time, player.current_animation_length, index / 16.0), true)
		visual.skeleton.force_update_all_bone_transforms()
		var gap := minimum_gap(visual.contact.skin, visual.skeleton, normal, split)
		assert(is_finite(gap) and gap >= -.001, "Spider fall intersected terrain: %f %s" % [gap, details])
		min_gap = minf(min_gap, gap)
		samples += 1
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(Killed, 4))
	game._handle(removal)
	arena.avatars.erase(Killed)
	avatar.free()
	deaths._process(float(deaths.active[Killed].remaining) + .1)
	assert(holder.visible and items.corpse_snapshots.has(Corpse))
	var frozen := holder.get_node("CorpseVisual") as Node3D
	assert(frozen.get_meta("corpse_body") == Body and frozen.get_meta("native_hue") == Hue)
	assert(frozen.get_meta("static_cadaver") and frozen.get_meta("death_clip") == expected_clip)
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	var frozen_gap := INF
	for mesh: MeshInstance3D in frozen.get_children():
		for surface in mesh.mesh.get_surface_count():
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var position := mesh.to_global(point)
				var depth := position.y - (Height if position.x >= 0.0 else 0.0) if split else normal.dot(position)
				frozen_gap = minf(frozen_gap, depth)
	assert(absf(frozen_gap - .002) < .001, "Frozen spider did not settle: %f %s" % [frozen_gap, details])
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
