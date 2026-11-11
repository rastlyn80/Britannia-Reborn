# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Visual := preload("res://Presentation/SourceEnhancedMolochVisual.gd")
const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Body := 785
const Id := 0x2e85
const Corpse := 0x40000000 + Id
const Dye := 0x8035
const Joints := ["bip01 head", "bip01 l hand", "bip01 r hand", "mesh03", "mesh12"]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	world.game._handle(driver.mobile_packet(at, 64, Id, Body, 0))
	var avatar: Node3D = world.avatars[Id]
	var visual: Node3D = avatar.horse_visual
	assert(visual.native_body == Body and visual.native_hue == 0 and (visual is Visual) == enhanced)
	var checks := 2
	if enhanced:
		visual.play_gait(false, 0.0)
		assert(visual.current_clip == "MolochCombatRest")
		world.game._handle(driver.action_packet(0, Id, 0))
		assert(visual.current_clip == "MolochLeftHammer")
		world.game._handle(driver.action_packet(0, Id, 1))
		assert(visual.current_clip == "MolochRightHammer")
		checks += 3
	else:
		world.game._handle(Replay.attack_packet(Id))
		assert(visual.current_clip == "Attack")
		checks += 1
	world.game._handle(driver.action_packet(3, Id, 1))
	var expected := "Death2" if enhanced else "Death"
	var displayed: Array[Vector3] = []
	if enhanced:
		assert(visual.current_clip == expected)
		visual.animator.advance(.18)
		visual.animator.seek(.40, true)
		visual.skeleton.force_update_all_bone_transforms()
		for joint: String in Joints:
			displayed.append(Replay.point(visual, joint))
		checks += 1
	world.game._handle(driver.corpse_packet(at, Corpse, Body, 0))
	var packet := PackedByteArray([0xaf])
	packet.append_array(Wire.uint_be(Id, 4))
	packet.append_array(Wire.uint_be(Corpse, 4))
	packet.append_array(Wire.uint_be(0, 4))
	world.game._handle(packet)
	var state: Dictionary = world.creature_deaths.active[Id]
	var fallen: Node3D = state.visual
	assert(fallen.current_clip == expected and fallen.native_body == Body)
	var holder: Node3D = world.world_items.nodes[Corpse]
	assert(not holder.visible)
	checks += 2
	var jump := 0.0
	if enhanced:
		for index in Joints.size():
			jump = maxf(jump, displayed[index].distance_to(Replay.point(fallen, Joints[index])))
		assert(jump < .0025, "Moloch alternate collapse moved a joint %.6f m" % jump)
		checks += 1
	await driver.create_timer(float(state.remaining) + .15).timeout
	assert(holder.visible)
	var frozen: Node3D = holder.get_node("CorpseVisual")
	assert(frozen.get_meta("death_clip") == expected and frozen.get_meta("native_hue") == 0)
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	checks += 3
	if enhanced:
		assert(world.world_items.corpse_snapshots.has(Corpse))
		var initial := frozen.global_transform
		var bounds: AABB = frozen.get_meta("corpse_bounds")
		world.game._handle(driver.corpse_packet(at, Corpse, Body, Dye))
		var dyed: Node3D = world.world_items.nodes[Corpse].get_node("CorpseVisual")
		assert(dyed.get_meta("death_clip") == "Death2" and dyed.get_meta("native_hue") == Dye)
		assert(dyed.global_transform.is_equal_approx(initial) and dyed.get_meta("corpse_bounds") == bounds)
		checks += 3
	return {"checks": checks, "body": Body, "corpse": Corpse, "fall": expected, "jump": jump}
