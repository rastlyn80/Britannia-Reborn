# SPDX-License-Identifier: GPL-3.0-or-later
extends "test-source-occurrence-terrain.gd"

const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const Killed := 0x2010
const Corpse := 0x40010028
const Hue := 0x8035
const Begins := {
	208: ["Idle", "Walk", "Run", "Attack", "RearStrike", "Fidget", "SourcePecking2", "Death", "Death2"],
	52: ["Idle", "Walk", "Run", "Attack", "Hit", "Fidget", "Eat", "Death", "DeathFallback"],
	138: ["Idle", "Walk", "Run", "Attack", "Attack2", "Attack3", "Fidget", "Death", "DeathFallback"],
	6: ["Idle", "Walk", "Run", "Fly", "Land", "Fidget", "Death", "Death2"],
	779: ["Idle", "Walk", "Run", "Attack", "Attack2", "RootGuard", "Uncurl", "Death", "Death2"],
	31: ["Idle", "Walk", "Run", "Attack", "ShoulderHunch", "LowSwing", "Death", "Death2"],
	29: ["Idle", "Walk", "Run", "Attack", "Hit", "Stomp", "Death", "DeathFallback"],
	153: ["Idle", "Walk", "Run", "Attack", "Attack2", "Cast", "Death", "DeathFallback"],
	1: ["Idle", "Walk", "Run", "Attack", "Fidget", "Death", "Death2"],
	3: ["Idle", "Walk", "Run", "Attack", "Fidget", "Death", "Death2"],
	8: ["Idle", "Attack", "InwardHook", "DoubleLash", "EmergeEarly", "EmergeLate", "Death", "Death2"],
	30: ["Idle", "Wingbeat", "Fly", "Land", "Death", "Death2", "AirDeath"],
	39: ["Idle", "Attack", "Fly", "Death2", "AirDeath"],
	47: ["Idle", "Attack", "BranchRake", "TrunkBend", "CrownShake", "Death", "Death2"],
}
const EnhancedBegins := {
	208: ["ChickenLowAlert", "ChickenQuickPeck", "ChickenSettledWatch"],
	6: ["BirdGlance", "BirdQuietSettle"],
	779: ["BoglingSprout", "BoglingBranchAlert"],
	31: ["HeadlessCrookedAlert", "HeadlessGatherRise"],
	29: ["GorillaForearmGuard", "GorillaLowWatch", "GorillaChestBeat", "GorillaArmsWarning", "GorillaOverheadDrop", "GorillaLowBreath"],
	153: ["GhoulCrookedReach", "GhoulKneelingRise"],
	1: ["OgreTurningSweep", "OgreCrouchRise", "OgreLookDown"],
	3: ["ZombieSlumpedWatch", "ZombieLurchSwipe", "ZombieGraveRise"],
	8: ["CorpserTripleSweep", "CorpserRaisedTendrils"],
	30: ["HarpyFoldedGlance", "HarpyBank", "HarpyDoubleWingbeat", "HarpyGlideSettle"],
	39: ["MongbatAscentEarly", "MongbatUnfoldAndRise", "MongbatDivingSwoop"],
}
const ClassicFalls := {
	208: {"Death": 8, "Death2": 12},
	52: {"Death": 8, "DeathFallback": 12},
	138: {"Death": 2, "DeathFallback": 3},
	6: {"Death": 8, "Death2": 12}, 779: {"Death": 2, "Death2": 3},
	31: {"Death": 3, "Death2": 2},
	29: {"Death": 8, "DeathFallback": 12}, 153: {"Death": 2, "DeathFallback": 3},
	1: {"Death": 2, "Death2": 3}, 3: {"Death": 3, "Death2": 2}, 8: {"Death": 3, "Death2": 2},
	30: {"Death": 2, "Death2": 3, "AirDeath": 21}, 39: {"Death2": 3, "AirDeath": 21},
	47: {"Death": 2, "Death2": 3}}
const StartPoses := {"MongbatAscentEarly": "MongbatUnfoldAndRise", "EmergeEarly": "Emerge", "EmergeLate": "Emerge"}
const StartPhases := {"MongbatAscentEarly": .06, "MongbatUnfoldAndRise": .72, "EmergeEarly": .22, "EmergeLate": .91}
var body := 0
var transfers := 0
var minimum_gap := INF
var maximum_jump := 0.0
var largest_frozen_gap := 0.0


class Arena extends Node3D:
	var avatars := {}


class Avatar extends Node3D:
	var horse_visual: Node3D


func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var enhanced := "--enhanced-creature-actions" in arguments
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	for argument: String in arguments:
		if argument.begins_with("--body="):
			body = int(argument.trim_prefix("--body="))
	if not body in Profile.enable():
		quit(1)
		return
	var starts: Array = Begins[body]
	if enhanced:
		var fitted: String = "res://local-art/creatures/enhanced-creature-actions/%d-modern.scn" % body
		if body not in [6, 208, 779] or Registry.asset_path(Registry.entry(body)) == fitted:
			starts = starts + EnhancedBegins.get(body, [])
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
	print("OCCURRENCE FALL: ", body, " ", transfers, " decoded handoffs, ", transfers * 17, " full-skin samples, first pose jump ",
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
	var source := Registry.create(body)
	avatar.horse_visual = source
	avatar.add_child(source)
	source.apply_identity(body, Hue)
	source.set_process(false)
	source.set_physics_process(false)
	source.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	arena.avatars[Killed] = avatar
	game.entities[Killed] = {"serial": Killed, "body": body, "hue": Hue, "direction": 4}
	var continuing: bool = ClassicFalls[body].has(clip)
	source.contact.enabled = clip not in Flight or (body == 30 and clip == "Land")
	if clip.begins_with("Mongbat") and clip != "MongbatAscentEarly":
		source.contact.enabled = false
	source._physics_process(1.0 / 60.0)
	if continuing:
		var action := PackedByteArray([0x6e])
		action.append_array(Wire.uint_be(Killed, 4))
		action.append_array(PackedByteArray([0, int(ClassicFalls[body][clip]), 0, 10, 0, 1, 1, 0, 0]))
		game._handle(action)
		assert(source.receive_action(game.last_mobile_actions[Killed]) and source.dead)
	else:
		source.current_clip = StartPoses.get(clip, clip)
		source.animator.play(source.current_clip, 0.0)
	source.animator.advance(.13 if source.dead else 0.0)
	var phase: float = StartPhases.get(clip, .38)
	source.animator.seek(source.animator.current_animation_length * phase, true)
	if not source.dead:
		source._physics_process(1.0 / 60.0)
		source.contact._process_modification_with_delta(1.0 / 60.0)
		source.contact.modification_processed.emit()
	var original_pose := world_joints(source.skeleton)
	var airborne := takes_air_fall(source, clip)
	var time: float = source.animator.current_animation_position if source.dead else 0.0
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
	var expected := clip.trim_suffix("Fallback") if continuing else ("AirDeath" if airborne else "Death")
	var details := "%s x%.2f heading%.3f %s" % [clip, x, heading, normal]
	assert(visual.current_clip == expected and absf(player.current_animation_position - time) < .001,
		"%s expected %s %.4fs, got %s %.4fs" % [details, expected, time, visual.current_clip, player.current_animation_position])
	var first_pose := world_joints(visual.skeleton)
	for index in first_pose.size():
		var difference := first_pose[index].distance_to(original_pose[index])
		assert(difference < .001, "Discontinuous first fall pose %f %s" % [difference, details])
		maximum_jump = maxf(maximum_jump, difference)
	var emerging := clip == "ZombieGraveRise" or clip.begins_with("Emerge")
	var fall := fall_controller(visual, emerging)
	for index in 17:
		player.seek(lerpf(time, player.current_animation_length, index / 16.0), true)
		var rig: Skeleton3D = visual.skeleton
		rig.force_update_all_bone_transforms()
		var skin: Dictionary = fall.skin
		var gap := step_gap(skin, rig) if split else Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
		var permitted_depth: bool = emerging and player.current_animation_position < fall.blend_length
		assert(is_finite(gap) and (gap >= -.001 or permitted_depth), "Fall penetrates terrain: %f %s" % [gap, details])
		if not permitted_depth:
			minimum_gap = minf(minimum_gap, gap)
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(Killed, 4))
	game._handle(removal)
	arena.avatars.erase(Killed)
	avatar.free()
	deaths._process(float(deaths.active[Killed].remaining) + .1)
	assert(holder.visible and items.corpse_snapshots.has(Corpse))
	var frozen := holder.get_node("CorpseVisual") as Node3D
	assert(frozen.get_meta("corpse_body") == body and frozen.get_meta("native_hue") == Hue)
	assert(frozen.get_meta("static_cadaver") and frozen.get_meta("death_clip") == expected)
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	if body == 138:
		assert(frozen.find_children("*", "MeshInstance3D", true, false).size() == 2)
	var frozen_gap := INF
	for mesh: MeshInstance3D in frozen.get_children():
		for surface in mesh.mesh.get_surface_count():
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var position := mesh.to_global(point)
				var depth := position.y - (Step if position.x >= 0 else 0.0) if split else normal.dot(position)
				frozen_gap = minf(frozen_gap, depth)
	assert(absf(frozen_gap - .002) < .001, "Frozen corpse did not settle: %f %s" % [frozen_gap, details])
	largest_frozen_gap = maxf(largest_frozen_gap, frozen_gap)
	arena.free()
	game.free()
	transfers += 1
	return true


func takes_air_fall(source: Node3D, clip: String) -> bool:
	if body == 6:
		return false
	if body == 30 and clip in HarpyAerial:
		var pelvis: int = source.skeleton.find_bone("bip01 pelvis")
		var height: float = (source.skeleton.to_global(source.skeleton.get_bone_global_pose(pelvis).origin)
			- source.global_position).dot(source.global_basis.y.normalized())
		return height > 1.26
	return clip in ["Fly", "Land", "AirDeath", "MongbatUnfoldAndRise", "MongbatDivingSwoop"]


func fall_controller(visual: Node3D, emerging: bool) -> RefCounted:
	if body == 3 and emerging:
		return visual.grave_fall
	if body in [1, 3, 29, 30, 31, 138, 153]:
		return visual.contact.death
	return visual.terrain


func world_joints(rig: Skeleton3D) -> PackedVector3Array:
	rig.force_update_all_bone_transforms()
	var positions := PackedVector3Array()
	for bone in rig.get_bone_count():
		positions.append(rig.to_global(rig.get_bone_global_pose(bone).origin))
	return positions
