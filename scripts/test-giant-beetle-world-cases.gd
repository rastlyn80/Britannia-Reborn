# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Visual := preload("res://Presentation/SourceEnhancedGiantBeetleVisual.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Body := 791
const First := 0x2ef4
const Dye := 0x8035
const Joints := ["bip01 head", "bip01 pelvis", "dummy02", "hindwing_0", "hindwing_1"]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var report := {"checks": 0, "body": Body, "falls": {}}
	for parity in 2:
		var serial := First + parity
		var corpse := 0x40000000 + serial
		world.game._handle(driver.mobile_packet(at, 0, serial, Body, 0))
		var avatar: Node3D = world.avatars[serial]
		var actor: Node3D = avatar.horse_visual
		assert((actor is Visual) == enhanced and actor.native_body == Body and actor.native_hue == 0)
		report.checks += 1
		if enhanced:
			actor.play_gait(true, 1.8)
			assert(actor.current_clip == Visual.PeaceGaits[1])
			actor.play_gait(false, 0.0)
			world.game._handle(driver.mobile_packet(at, 64, serial, Body, 0))
			assert(actor.current_clip == Visual.Raise)
			actor.action_remaining = 0.0
			actor.play_gait(true, 1.8)
			assert(actor.current_clip == Visual.CombatGaits[1])
			world.game._handle(driver.action_packet(5, serial, parity))
			assert(actor.current_clip == ("BeetleWingedFlare" if parity == 0 else "BeetleWingedDisplay"))
			report.checks += 4
		else:
			actor.play_gait(true, 1.8)
			assert(actor.current_clip == "Walk")
			report.checks += 1
		world.game._handle(driver.action_packet(3, serial, parity))
		var expected := "Death2" if enhanced and parity == 0 else "Death"
		assert(actor.current_clip == expected and actor.dead)
		var shown := PackedVector3Array()
		if enhanced:
			actor.animator.advance(.18)
			actor.animator.seek(.43 * actor.animator.current_animation_length, true)
			actor.skeleton.force_update_all_bone_transforms()
			shown = landmarks(actor)
		report.checks += 1
		world.game._handle(driver.corpse_packet(at, corpse, Body, 0))
		var packet := PackedByteArray([0xaf])
		packet.append_array(Wire.uint_be(serial, 4))
		packet.append_array(Wire.uint_be(corpse, 4))
		packet.append_array(Wire.uint_be(0, 4))
		world.game._handle(packet)
		var state: Dictionary = world.creature_deaths.active[serial]
		var visual: Node3D = state.visual
		var holder: Node3D = world.world_items.nodes[corpse]
		assert(visual.current_clip == expected and not holder.visible)
		report.checks += 2
		var jump := 0.0
		if enhanced:
			var entered := landmarks(visual)
			for index in Joints.size():
				jump = maxf(jump, shown[index].distance_to(entered[index]))
			assert(jump < .0025, "Giant Beetle corpse transition moved a joint %.6f m" % jump)
			report.checks += 1
		await driver.create_timer(float(state.remaining) + .15).timeout
		var frozen: Node3D = holder.get_node("CorpseVisual")
		assert(holder.visible and frozen.get_meta("native_hue") == 0 and frozen.get_meta("death_clip") == expected)
		assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
		report.checks += 2
		if enhanced:
			assert(frozen.get_child_count() == 3 and frozen.has_node("HindwingMembranes") and frozen.has_node("UnderCarapace"))
			var placement := frozen.global_transform
			var bounds: AABB = frozen.get_meta("corpse_bounds")
			world.game._handle(driver.corpse_packet(at, corpse, Body, Dye))
			var dyed: Node3D = world.world_items.nodes[corpse].get_node("CorpseVisual")
			assert(dyed.get_meta("native_hue") == Dye and dyed.get_meta("death_clip") == expected)
			assert(dyed.global_transform.is_equal_approx(placement) and dyed.get_meta("corpse_bounds") == bounds)
			report.checks += 3
		report.falls[expected] = jump
	return report


static func landmarks(actor: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	for label: String in Joints:
		points.append(actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(label)).origin))
	return points
