# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Mage := preload("res://Presentation/SourceEnhancedMeerMageVisual.gd")
const Effects := preload("res://Presentation/SourceEnhancedMeerMageEffects.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const First := 0x2ef7
const Body := 770
const Dye := 0x8035


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var report := {"checks": 0, "body": Body, "falls": {}}
	var phase: String = world.game.phase
	for parity in 2:
		var serial := First + parity
		var corpse := 0x40000000 + serial
		world.game._handle(driver.mobile_packet(at, 64, serial, Body, 0))
		var avatar: Node3D = world.avatars[serial]
		var actor: Node3D = avatar.horse_visual
		avatar.rotation.y = PI - float(int(world.game.entities[serial].direction) & 7) * PI / 4.0
		assert((actor is Mage) == enhanced and actor.native_body == Body and actor.native_hue == 0)
		report.checks += 1
		actor.play_gait(true, 1.8)
		assert(actor.current_clip == (Mage.Walk if enhanced else "Walk"))
		actor.play_gait(true, 5.5)
		assert(actor.current_clip == "Run")
		report.checks += 2
		world.game._handle(driver.action_packet(5, serial, parity))
		var fidget: String = ["MeerMageHipCheck", Mage.Stand][parity] if enhanced else ["Fidget", "MeerMageLook"][parity]
		assert(actor.current_clip == fidget)
		report.checks += 1
		if enhanced:
			world.game.phase = "world"
			world.game._handle(notice(serial, 0, 1071931))
			assert(actor.current_clip == "Cast")
			world.game._handle(swarm(serial))
			assert(avatar.has_node(Effects.CloudName))
			world.game._handle(notice(serial, 2, Effects.Dispersed))
			world.game.phase = phase
			await driver.process_frame
			assert(not avatar.has_node(Effects.CloudName))
			report.checks += 3
		var selected := "Death" if parity == 0 else "Death2"
		world.game._handle(driver.action_packet(3, serial, parity) if enhanced else classic_fall(serial, parity + 2))
		assert(actor.current_clip == selected and actor.dead)
		actor.animator.advance(.18)
		actor.animator.seek(.43 * actor.animator.current_animation_length, true)
		actor.skeleton.force_update_all_bone_transforms()
		var displayed := head(actor)
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
		assert(visual.current_clip == selected and not holder.visible)
		var jump := displayed.distance_to(head(visual))
		assert(jump < .0025, "Meer Mage displayed fall moved %.6f m" % jump)
		report.checks += 3
		await driver.create_timer(float(state.remaining) + .15).timeout
		var frozen: Node3D = holder.get_node("CorpseVisual")
		assert(holder.visible and frozen.get_meta("death_clip") == selected)
		assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
		var placement := frozen.global_transform
		var bounds: AABB = frozen.get_meta("corpse_bounds")
		world.game._handle(driver.corpse_packet(at, corpse, Body, Dye))
		var dyed: Node3D = world.world_items.nodes[corpse].get_node("CorpseVisual")
		assert(dyed.get_meta("native_hue") == Dye and dyed.get_meta("death_clip") == selected)
		assert(dyed.global_transform.is_equal_approx(placement) and dyed.get_meta("corpse_bounds") == bounds)
		report.checks += 4
		report.falls[selected] = jump
	return report


static func head(actor: Node3D) -> Vector3:
	return actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("bip01 head")).origin)


static func notice(serial: int, kind: int, cliloc: int) -> PackedByteArray:
	var bytes := PackedByteArray([0xc1, 0, 50])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(Wire.uint_be(Body, 2))
	bytes.append(kind)
	bytes.resize(14)
	bytes.append_array(Wire.uint_be(cliloc, 4))
	bytes.resize(50)
	return bytes


static func swarm(serial: int) -> PackedByteArray:
	var bytes := PackedByteArray([0xc0, 3])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(Wire.uint_be(0, 4))
	bytes.append_array(Wire.uint_be(Effects.Graphic, 2))
	bytes.resize(36)
	bytes[22] = 10
	bytes[23] = 180
	return bytes


static func classic_fall(serial: int, group: int) -> PackedByteArray:
	var bytes := PackedByteArray([0x6e])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(Wire.uint_be(group, 2))
	bytes.append_array(PackedByteArray([0, 6, 0, 1, 1, 0, 0]))
	return bytes
