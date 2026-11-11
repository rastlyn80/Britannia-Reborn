# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Visual := preload("res://Presentation/SourceEnhancedOrcBruteVisual.gd")
const Replay := preload("test-enhanced-corpse-gesture-cases.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Body := 189
const Lord := 138
const Id := 0x2ebd
const Dye := 0x8035
const Joints := ["bip_01 head", "bip_01 l hand", "bip_01 r hand", "bip_01 spine2"]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var report := {"checks": 0, "body": Body, "falls": {}, "lord": Lord}
	for parity in 2:
		var serial := Id + parity
		var corpse := 0x40000000 + serial
		world.game._handle(driver.mobile_packet(at, 0, serial, Body, 0))
		var avatar: Node3D = world.avatars[serial]
		var actor: Node3D = avatar.horse_visual
		assert((actor is Visual) == enhanced and actor.native_body == Body and actor.native_hue == 0)
		report.checks += 1
		if enhanced:
			actor.play_gait(false, 0.0)
			assert(actor.current_clip == "BruteQuietRest")
			world.game._handle(driver.mobile_packet(at, 0x40, serial, Body, 0))
			assert(actor.current_clip == "BruteLowReady")
			world.game._handle(driver.action_packet(0, serial, parity))
			assert(actor.current_clip == ("BruteDoubleHammer" if parity == 0 else "BruteTurningSweep"))
			report.checks += 3
		else:
			world.game._handle(Replay.attack_packet(serial))
			assert(actor.current_clip == "Attack")
			report.checks += 1
		world.game._handle(driver.action_packet(3, serial, parity))
		var expected := "Death2" if enhanced and parity == 1 else "Death"
		assert(actor.current_clip == expected)
		var shown: Array[Vector3] = []
		if enhanced:
			actor.animator.advance(.16)
			actor.animator.seek(.43 * actor.animator.current_animation_length, true)
			actor.skeleton.force_update_all_bone_transforms()
			for joint: String in Joints:
				shown.append(Replay.point(actor, joint))
		world.game._handle(driver.corpse_packet(at, corpse, Body, 0))
		world.game._handle(death_packet(serial, corpse))
		var state: Dictionary = world.creature_deaths.active[serial]
		var visual: Node3D = state.visual
		assert(visual.current_clip == expected)
		var holder: Node3D = world.world_items.nodes[corpse]
		assert(not holder.visible)
		report.checks += 3
		var jump := 0.0
		if enhanced:
			for index in Joints.size():
				jump = maxf(jump, shown[index].distance_to(Replay.point(visual, Joints[index])))
			assert(jump < .0025, "Orc Brute corpse transition moved a joint %.6f m" % jump)
			report.checks += 1
		await driver.create_timer(float(state.remaining) + .15).timeout
		var static_corpse: Node3D = holder.get_node("CorpseVisual")
		assert(holder.visible and static_corpse.get_meta("native_hue") == 0)
		assert(static_corpse.get_meta("death_clip") == expected)
		assert(static_corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		assert((static_corpse.find_child("BruteSpines", false, false) != null) == enhanced)
		report.checks += 4
		if enhanced:
			var placement := static_corpse.global_transform
			var bounds: AABB = static_corpse.get_meta("corpse_bounds")
			world.game._handle(driver.corpse_packet(at, corpse, Body, Dye))
			var dyed: Node3D = world.world_items.nodes[corpse].get_node("CorpseVisual")
			assert(dyed.get_meta("native_hue") == Dye and dyed.get_meta("death_clip") == expected)
			assert(dyed.global_transform.is_equal_approx(placement) and dyed.get_meta("corpse_bounds") == bounds)
			assert(dyed.find_child("BruteSpines", false, false) != null)
			report.checks += 3
		report.falls[expected] = jump
	var summoned := Id + 16
	var ephemeral := 0x40000000 + summoned
	world.game._handle(driver.mobile_packet(at, 64, summoned, Lord, 0))
	var lord: Node3D = world.avatars[summoned].horse_visual
	assert(lord.native_body == Lord and not lord is Visual and lord.model.find_child("BruteSpines", true, false) == null)
	world.game._handle(death_packet(summoned, ephemeral))
	var summoned_fall: Dictionary = world.creature_deaths.active[summoned]
	driver.remove_fixture(world.game, ephemeral)
	await driver.create_timer(float(summoned_fall.remaining) + .15).timeout
	assert(not world.world_items.nodes.has(ephemeral) and not world.game.world_items.has(ephemeral))
	report.checks += 2
	return report


static func death_packet(serial: int, corpse: int) -> PackedByteArray:
	var packet := PackedByteArray([0xaf])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(Wire.uint_be(corpse, 4))
	packet.append_array(Wire.uint_be(0, 4))
	return packet
