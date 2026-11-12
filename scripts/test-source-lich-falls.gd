# SPDX-License-Identifier: GPL-3.0-or-later
extends "test-source-lich-terrain.gd"

const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const Killed := 0x2010
const Corpse := 0x40010028
const Hue := 0x8035
const Starts := ["Idle", "Walk", "Run", "Attack", "Cast", "Pillage", "Hit", "Death", "Death2"]
const EnhancedStarts := Optional
var transfers := 0
var minimum_gap := INF
var maximum_jump := 0.0
var largest_frozen_gap := 0.0


class Arena extends Node3D:
	var avatars := {}


class FallAvatar extends Node3D:
	var horse_visual: Node3D


func run() -> void:
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	assert(preload("res://Presentation/SourceOccurrenceTerrainProfile.gd").enable().has(24))
	var lower := floor_box()
	var upper := floor_box()
	upper.position = Vector3(6, Step - .1, 0)
	(upper.get_child(0).shape as BoxShape3D).size = Vector3(12, .2, 16)
	for support: String in ["flat", "slope", "step"]:
		var split := support == "step"
		var normal := Vector3(.13, 1.0, -.10).normalized() if support == "slope" else Vector3.UP
		var center := Vector3(-6, 0, 0) if split else Vector3.ZERO
		lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), center - .1 * normal)
		(lower.get_child(0).shape as BoxShape3D).size = Vector3(12 if split else 24, .2, 16)
		upper.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for x: float in ([-.20, .17] if split else [0.0]):
			for heading: float in [PI * .5, PI * 1.5]:
				for clip: String in (Starts + EnhancedStarts if enhanced else Starts):
					if not replay(x, heading, clip, normal, split):
						quit(1)
						return
	print("LICH FALL: ", transfers, " decoded handoffs, ", transfers * 17, " full-skin samples, first pose jump ",
		maximum_jump, ", minimum gap ", minimum_gap, ", largest final gap ", largest_frozen_gap, ", Enhanced ", enhanced)
	quit(0 if transfers == (88 if enhanced else 72) else 1)


func replay(x: float, heading: float, clip: String, normal: Vector3, split: bool) -> bool:
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
	var avatar := FallAvatar.new()
	arena.add_child(avatar)
	avatar.position = Vector3(x, Step if split and x > 0.0 else 0.0, 0)
	avatar.rotation.y = heading
	var source := Registry.create(24)
	avatar.horse_visual = source
	avatar.add_child(source)
	source.apply_identity(24, Hue)
	source.set_process(false)
	source.set_physics_process(false)
	source.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	arena.avatars[Killed] = avatar
	game.entities[Killed] = {"serial": Killed, "body": 24, "hue": Hue, "direction": 4}
	var continuing := clip in ["Death", "Death2"]
	source._physics_process(1.0 / 60.0)
	if continuing:
		var action := PackedByteArray([0x6e])
		action.append_array(Wire.uint_be(Killed, 4))
		action.append_array(PackedByteArray([0, 2 if clip == "Death" else 3, 0, 10, 0, 1, 1, 0, 0]))
		game._handle(action)
		assert(source.receive_action(game.last_mobile_actions[Killed]) and source.dead)
	else:
		source.current_clip = clip
		source.animator.play(source.current_clip, 0.0)
	source.animator.advance(.13 if source.dead else 0.0)
	var phase := .43
	source.animator.seek(source.animator.current_animation_length * phase, true)
	if not source.dead:
		source._physics_process(1.0 / 60.0)
	if not source.dead:
		source.contact._process_modification_with_delta(1.0 / 60.0)
		source.contact.modification_processed.emit()
	var original_pose := world_joints(source.skeleton)
	var original_staff: Transform3D = source.staff.global_transform
	var time: float = source.animator.current_animation_position if source.dead else 0.0
	var holder := Node3D.new()
	items.add_child(holder)
	items.nodes[Corpse] = holder
	assert(items._equine_corpse(holder, {"id": 0x2006, "amount": 24, "hue": Hue, "direction": 4}, Corpse))
	var packet := PackedByteArray([0xaf])
	packet.append_array(Wire.uint_be(Killed, 4))
	packet.append_array(Wire.uint_be(Corpse, 4))
	packet.append_array(Wire.uint_be(0, 4))
	game._handle(packet)
	assert(deaths.active.has(Killed) and not avatar.visible and not holder.visible)
	var visual: Node3D = deaths.active[Killed].visual
	var player: AnimationPlayer = visual.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var expected: String = source.current_clip if continuing else "Death"
	var details := "%s x%.2f heading%.3f %s" % [clip, x, heading, normal]
	assert(visual.current_clip == expected and absf(player.current_animation_position - time) < .001,
		"%s expected %s %.4fs, got %s %.4fs" % [details, expected, time, visual.current_clip, player.current_animation_position])
	var first_pose := world_joints(visual.skeleton)
	assert(visual.staff.global_transform.is_equal_approx(original_staff), "Staff jumped at the first displayed fall pose: " + details)
	for index in first_pose.size():
		var difference := first_pose[index].distance_to(original_pose[index])
		assert(difference < .001, "Discontinuous first fall pose %f %s" % [difference, details])
		maximum_jump = maxf(maximum_jump, difference)
	for index in 17:
		player.seek(lerpf(time, player.current_animation_length, index / 16.0), true)
		var rig: Skeleton3D = visual.skeleton
		rig.force_update_all_bone_transforms()
		var skin: Dictionary = visual.contact.death.skin
		var gap := step_gap(skin, rig) if split else Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
		var body_gap := gap
		for mesh: MeshInstance3D in visual.staff_meshes():
			gap = minf(gap, staff_gap(mesh, split, normal))
		assert(is_finite(gap) and gap >= -.001, "Body or staff penetrates terrain: %f (body %f), frame %d %s" % [gap, body_gap, index, details])
		minimum_gap = minf(minimum_gap, gap)
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(Killed, 4))
	game._handle(removal)
	arena.avatars.erase(Killed)
	avatar.free()
	deaths._process(float(deaths.active[Killed].remaining) + .1)
	assert(holder.visible and items.corpse_snapshots.has(Corpse))
	var frozen := holder.get_node("CorpseVisual") as Node3D
	assert(frozen.get_meta("corpse_body") == 24 and frozen.get_meta("native_hue") == Hue)
	assert(frozen.get_meta("static_cadaver") and frozen.get_meta("death_clip") == expected)
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	var frozen_gap := INF
	for mesh: MeshInstance3D in frozen.get_children():
		for surface in mesh.mesh.get_surface_count():
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var position := mesh.to_global(point)
				var depth := position.y - (Step if position.x >= 0 else 0.0) if split else normal.dot(position)
				frozen_gap = minf(frozen_gap, depth)
	assert(absf(frozen_gap - .002) < .001, "Frozen Lich did not settle: %f %s" % [frozen_gap, details])
	largest_frozen_gap = maxf(largest_frozen_gap, frozen_gap)
	arena.free()
	game.free()
	transfers += 1
	return true


func world_joints(rig: Skeleton3D) -> PackedVector3Array:
	rig.force_update_all_bone_transforms()
	var positions := PackedVector3Array()
	for bone in rig.get_bone_count():
		positions.append(rig.to_global(rig.get_bone_global_pose(bone).origin))
	return positions
