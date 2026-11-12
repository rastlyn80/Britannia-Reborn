# SPDX-License-Identifier: GPL-3.0-or-later
extends "test-source-hover-clearance.gd"

const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const Killed := 0x2010
const Corpse := 0x40010028
const Hue := 0x8035
const Starts := ["Idle", "Walk", "Run", "Attack", "ElementalOverhead", "Cast3", "EmberFlinch", "FlameGuard", "FlareSpread", "Death", "Death2"]
var transfers := 0
var minimum_gap := INF
var maximum_jump := 0.0
var largest_frozen_gap := 0.0


class Arena extends Node3D:
	var avatars := {}


class Avatar extends Node3D:
	var horse_visual: Node3D


func run() -> void:
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	if not 15 in Profile.enable():
		push_error("The verified Fire Elemental renderer is unavailable.")
		quit(1)
		return
	var fitted := enhanced and Registry.asset_path(Registry.entry(15)).ends_with("/15-modern.scn")
	var starts := Starts + (["FireCrownAlert", "FireKindleAndRise"] if fitted else [])
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
				for clip: String in starts:
					if not replay(x, heading, clip, normal, split):
						quit(1)
						return
	print("FIRE ELEMENTAL FALL: ", transfers, " decoded handoffs, ", transfers * 17, " full-skin samples, first pose jump ",
		maximum_jump, ", minimum gap ", minimum_gap, ", largest final gap ", largest_frozen_gap, ", Enhanced ", enhanced)
	quit(0 if transfers == starts.size() * 8 else 1)


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
	var avatar := Avatar.new()
	arena.add_child(avatar)
	avatar.position = Vector3(x, Step if split and x > 0.0 else 0.0, 0)
	avatar.rotation.y = heading
	var source := Registry.create(15)
	avatar.horse_visual = source
	avatar.add_child(source)
	source.apply_identity(15, Hue)
	source.set_process(false)
	source.set_physics_process(false)
	source.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	arena.avatars[Killed] = avatar
	game.entities[Killed] = {"serial": Killed, "body": 15, "hue": Hue, "direction": 4}
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
	if clip == "FireKindleAndRise":
		phase = .12 if heading < PI else (.19 if split else .43)
	source.animator.seek(source.animator.current_animation_length * phase, true)
	if not source.dead:
		source._physics_process(1.0 / 60.0)
	var original_pose := world_joints(source.skeleton)
	var original_phase: float = source.fire_phase
	var original_visibility := [source.terrain.flame.visible, source.terrain.ash.visible]
	var time: float = source.animator.current_animation_position if source.dead else 0.0
	var holder := Node3D.new()
	items.add_child(holder)
	items.nodes[Corpse] = holder
	assert(items._equine_corpse(holder, {"id": 0x2006, "amount": 15, "hue": Hue, "direction": 4}, Corpse))
	var packet := PackedByteArray([0xaf])
	packet.append_array(Wire.uint_be(Killed, 4))
	packet.append_array(Wire.uint_be(Corpse, 4))
	packet.append_array(Wire.uint_be(0, 4))
	game._handle(packet)
	assert(deaths.active.has(Killed) and not avatar.visible and not holder.visible)
	var visual: Node3D = deaths.active[Killed].visual
	var player: AnimationPlayer = visual.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var expected := clip if continuing else "Death"
	var details := "%s x%.2f heading%.3f %s" % [clip, x, heading, normal]
	assert(visual.current_clip == expected and absf(player.current_animation_position - time) < .001,
		"%s expected %s %.4fs, got %s %.4fs" % [details, expected, time, visual.current_clip, player.current_animation_position])
	assert(absf(angle_difference(original_phase, visual.fire_phase)) < .001,
		"The first displayed shader phase must continue with the skin: " + details)
	assert([visual.terrain.flame.visible, visual.terrain.ash.visible] == original_visibility,
		"Flame and dust visibility must continue across the first frame.")
	var first_pose := world_joints(visual.skeleton)
	for index in first_pose.size():
		var difference := first_pose[index].distance_to(original_pose[index])
		assert(difference < .001, "Discontinuous first fall pose %f %s" % [difference, details])
		maximum_jump = maxf(maximum_jump, difference)
	for index in 17:
		player.seek(lerpf(time, player.current_animation_length, index / 16.0), true)
		var rig: Skeleton3D = visual.skeleton
		rig.force_update_all_bone_transforms()
		var gap := INF
		if visual.terrain.flame.visible:
			var skin: Dictionary = visual.terrain.skin
			gap = step_gap(skin, rig) if split else Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
		if visual.terrain.ash.visible:
			gap = minf(gap, rigid_gap(visual.terrain.ash, normal, split))
		if is_finite(gap):
			assert(gap >= -.001, "Fall penetrates terrain: %f %s" % [gap, details])
			minimum_gap = minf(minimum_gap, gap)
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(Killed, 4))
	game._handle(removal)
	arena.avatars.erase(Killed)
	avatar.free()
	var end_phase: float = visual.fire_phase
	deaths._process(float(deaths.active[Killed].remaining) + .1)
	assert(holder.visible and items.corpse_snapshots.has(Corpse))
	var frozen := holder.get_node("CorpseVisual") as Node3D
	assert(frozen.get_meta("corpse_body") == 15 and frozen.get_meta("native_hue") == Hue)
	assert(frozen.get_meta("static_cadaver") and frozen.get_meta("death_clip") == expected)
	assert(frozen.get_child_count() == 1, "Only the dry-dust surface may freeze.")
	var frozen_mesh := frozen.get_child(0) as MeshInstance3D
	var frozen_material := frozen_mesh.get_active_material(0) as ShaderMaterial
	assert(absf(angle_difference(float(frozen_material.get_shader_parameter("phase")), end_phase)) < .001,
		"The dry-dust corpse retains its final shader phase.")
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	var frozen_gap := INF
	for mesh: MeshInstance3D in frozen.get_children():
		for surface in mesh.mesh.get_surface_count():
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var position := mesh.to_global(point)
				var depth := position.y - (Step if position.x >= 0 else 0.0) if split else normal.dot(position)
				frozen_gap = minf(frozen_gap, depth)
	assert(absf(frozen_gap - .002) < .001, "Frozen Fire Elemental did not settle: %f %s" % [frozen_gap, details])
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
