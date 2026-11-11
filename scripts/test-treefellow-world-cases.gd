# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const TreeVisual := preload("res://Presentation/SourceEnhancedTreefellowVisual.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const First := 0x2efa
const Body := 301
const Dye := 0x8035


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var report := {"checks": 0, "body": Body, "falls": {}, "corpse_heights": []}
	for parity in 2:
		var serial := First + parity
		var corpse := 0x40000000 + serial
		world.game._handle(driver.mobile_packet(at, 0, serial, Body, 0))
		var avatar: Node3D = world.avatars[serial]
		var actor: Node3D = avatar.horse_visual
		avatar.rotation.y = PI - float(int(world.game.entities[serial].direction) & 7) * PI / 4.0
		assert((actor is TreeVisual) == enhanced and actor.native_body == Body and actor.native_hue == 0)
		actor.play_gait(true, 1.8)
		assert(actor.current_clip == (TreeVisual.QuietWalk if enhanced else "Walk"))
		world.game._handle(driver.mobile_packet(at, 64, serial, Body, 0))
		if enhanced:
			assert(actor.current_clip == TreeVisual.Ready)
			actor.action_remaining = 0.0
			report.checks += 1
		actor.play_gait(true, 1.8)
		assert(actor.current_clip == "Walk")
		world.game._handle(driver.action_packet(5, serial, parity))
		var fidget: String = ["TreefellowWoodlandWatch", "TreefellowCanopyLift"][parity] if enhanced else ["Fidget", "TreefellowLook"][parity]
		assert(actor.current_clip == fidget)
		report.checks += 4
		var selected := "Death2" if enhanced and parity == 1 else "Death"
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
		var jump := 0.0
		if enhanced:
			jump = displayed.distance_to(head(visual))
			assert(jump < .0025, "Treefellow displayed fall moved %.6f m" % jump)
			report.checks += 1
		report.checks += 2
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
		if enhanced:
			var mesh := dyed.get_child(0) as MeshInstance3D
			var material := mesh.get_active_material(0) as ShaderMaterial
			assert(material.shader == TreeVisual.Bark and material.get_shader_parameter("partial_hue"))
			report.checks += 1
		report.checks += 4
		report.falls[selected] = jump
		report.corpse_heights.append(bounds.size.y)
	if enhanced:
		assert(report.corpse_heights[1] > report.corpse_heights[0] * 1.45)
		report.checks += 1
	return report


static func head(actor: Node3D) -> Vector3:
	return actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("bip01 head")).origin)


static func classic_fall(serial: int, group: int) -> PackedByteArray:
	var bytes := PackedByteArray([0x6e])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(Wire.uint_be(group, 2))
	bytes.append_array(PackedByteArray([0, 6, 0, 1, 1, 0, 0]))
	return bytes
