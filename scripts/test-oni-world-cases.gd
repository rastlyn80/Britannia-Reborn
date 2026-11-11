# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Visual := preload("res://Presentation/SourceEnhancedOniVisual.gd")
const Replay := preload("test-enhanced-corpse-gesture-cases.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Body := 241
const Id := 0x2ef1
const Dye := 0x8035
const Joints := ["bip01 head", "bip01 l hand", "bip01 r hand", "bip01 spine2"]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var report := {"checks": 0, "body": Body, "falls": {}}
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
			assert(actor.current_clip == "OniQuietRest")
			world.game._handle(driver.mobile_packet(at, 0x40, serial, Body, 0))
			assert(actor.current_clip == "OniLowReady")
			world.game._handle(driver.action_packet(5, serial, parity))
			assert(actor.current_clip == ("OniNearWatch" if parity == 0 else "OniOverheadGesture"))
			world.game._handle(driver.action_packet(11, serial, parity))
			assert(actor.current_clip == Visual.Fire)
			actor.animator.advance(.18)
			actor.animator.seek(.58 * actor.animator.current_animation_length, true)
			assert(actor.flame != null and actor.flame.visible)
			report.checks += 5
		else:
			world.game._handle(Replay.attack_packet(serial))
			assert(actor.current_clip == "Attack")
			report.checks += 1
		world.game._handle(driver.action_packet(3, serial, parity))
		var expected := "Death2" if enhanced and parity == 1 else "Death"
		assert(actor.current_clip == expected)
		var shown: Array[Vector3] = []
		if enhanced:
			assert(not actor.flame.visible)
			actor.animator.advance(.18)
			actor.animator.seek(.43 * actor.animator.current_animation_length, true)
			actor.skeleton.force_update_all_bone_transforms()
			for joint: String in Joints:
				shown.append(Replay.point(actor, joint))
			report.checks += 1
		world.game._handle(driver.corpse_packet(at, corpse, Body, 0))
		var packet := PackedByteArray([0xaf])
		packet.append_array(Wire.uint_be(serial, 4))
		packet.append_array(Wire.uint_be(corpse, 4))
		packet.append_array(Wire.uint_be(0, 4))
		world.game._handle(packet)
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
			assert(jump < .0025, "Oni corpse transition moved a joint %.6f m" % jump)
			report.checks += 1
		await driver.create_timer(float(state.remaining) + .15).timeout
		var frozen: Node3D = holder.get_node("CorpseVisual")
		assert(holder.visible and frozen.get_meta("native_hue") == 0)
		assert(frozen.get_meta("death_clip") == expected)
		assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
		assert(frozen.find_child("OniCastFlame", true, false) == null)
		report.checks += 4
		if enhanced:
			var placement := frozen.global_transform
			var bounds: AABB = frozen.get_meta("corpse_bounds")
			world.game._handle(driver.corpse_packet(at, corpse, Body, Dye))
			var dyed: Node3D = world.world_items.nodes[corpse].get_node("CorpseVisual")
			assert(dyed.get_meta("native_hue") == Dye and dyed.get_meta("death_clip") == expected)
			assert(dyed.global_transform.is_equal_approx(placement) and dyed.get_meta("corpse_bounds") == bounds)
			report.checks += 2
		report.falls[expected] = jump
	return report
