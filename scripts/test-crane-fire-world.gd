# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Fit := preload("test-crane-fire-enhanced.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Cases := [
	[254, 11, 0, "CraneWingThrust", .43, 0x8035, false],
	[254, 5, 1, "CraneWingBeat", .56, 0x455, false],
	[15, 15, 0, "FireKindleAndRise", .12, 0x8035, false],
	[15, 8, 0, "FireCrownAlert", .62, 0x455, false],
	[15, 15, 0, "FireTransientIgnition", .19, 0x8035, true],
	[15, 15, 0, "FireTransientUnpublished", .17, 0x455, true],
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var rows := {}
	var checks := 0
	for info: Array in Cases:
		var evidence := await witness(driver, world, at, enhanced, info, rows.size())
		assert(not evidence.is_empty())
		rows[info[3]] = evidence
		checks += 6 + (2 if enhanced else 0)
	return {"rows": rows, "checks": checks}


static func witness(driver, world: Node, at: Vector2i, enhanced: bool, info: Array, index: int) -> Dictionary:
	var body: int = info[0]
	var serial := 0x1980 + index
	var corpse := 0x40000000 + serial
	var hue: int = info[5]
	var transient: bool = info[6]
	var published: bool = info[3] != "FireTransientUnpublished"
	world.game._handle(driver.mobile_packet(at, 64, serial, body, hue))
	var source: Node3D = world.avatars[serial].horse_visual
	assert(source.native_body == body and source.native_hue == hue)
	var before: Array[Vector3] = []
	var labels := ["bip01 head", "l_wing_bone01", "bip01 l foot"] if body == 254 else ["Head", "hand_l", "hand_r"]
	if enhanced:
		world.game._handle(driver.action_packet(info[1], serial, info[2]))
		assert(source.current_clip == ("FireKindleAndRise" if transient else info[3]))
		for i in 10:
			source.animator.advance(.016)
		source.animator.seek(source.animator.current_animation_length * info[4], true)
		source._physics_process(1.0 / 60.0)
		source.contact.modification_processed.emit()
		for label: String in labels:
			before.append(Fit.bone(source, label))
	var corpse_first := index % 2 == 0
	if published and corpse_first:
		world.game._handle(driver.corpse_packet(at, corpse, body, hue))
	var death := PackedByteArray([0xaf])
	death.append_array(Wire.uint_be(serial, 4))
	death.append_array(Wire.uint_be(corpse, 4))
	death.append_array(Wire.uint_be(0, 4))
	world.game._handle(death)
	if published and not corpse_first:
		world.game._handle(driver.corpse_packet(at, corpse, body, hue))
	var state: Dictionary = world.creature_deaths.active[serial]
	var fallen: Node3D = state.visual
	var fall_clip := "Death"
	assert(fallen.current_clip == fall_clip and fallen.native_hue == hue)
	var jump := 0.0
	for i in before.size():
		jump = maxf(jump, before[i].distance_to(Fit.bone(fallen, labels[i])))
	if enhanced:
		assert(jump < .002, "%s falls with jump %f" % [info[3], jump])
	if published:
		assert(not world.world_items.nodes[corpse].visible)
	if transient:
		var remove := PackedByteArray([0x1d])
		remove.append_array(Wire.uint_be(corpse, 4))
		world.game._handle(remove)
		var remove_mobile := PackedByteArray([0x1d])
		remove_mobile.append_array(Wire.uint_be(serial, 4))
		world.game._handle(remove_mobile)
		assert(world.creature_deaths.active.has(serial) and is_instance_valid(fallen))
		await driver.create_timer(float(state.remaining) + .15).timeout
		assert(not world.world_items.nodes.has(corpse) and not world.creature_deaths.active.has(serial))
		var cached: bool = world.world_items.corpse_snapshots.has(corpse)
		assert(not cached and not world.creature_deaths.held_corpses.has(corpse))
		return {"body": body, "hue": hue, "jump": jump, "corpse": corpse, "fall": fall_clip,
			"retained_removed_corpse": cached}
	var holder: Node3D = world.world_items.nodes[corpse]
	await driver.create_timer(float(state.remaining) + .15).timeout
	assert(holder.visible and world.world_items.corpse_snapshots.has(corpse) == enhanced)
	var frozen: Node3D = holder.get_node("CorpseVisual")
	assert(frozen.get_meta("native_hue") == hue and frozen.get_meta("death_clip") == fall_clip)
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	return {"body": body, "hue": hue, "jump": jump, "corpse": corpse, "fall": fall_clip}
