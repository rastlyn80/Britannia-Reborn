# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Fit := preload("test-daemon-wyvern-enhanced.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Cases := [
	[9, 5, 1, "DaemonWingRebuff", .28, 0x8035, 68],
	[9, 15, 0, "DaemonFoldedRise", .18, 0x455, 64],
	[62, 11, 0, "WyvernNeckThrust", .48, 0x8035, 68],
	[62, 15, 0, "WyvernWingRise", .20, 0x455, 64],
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
	var serial := 0x1bd0 + index
	var corpse := 0x40000000 + serial
	var hue: int = info[5]
	var flags: int = info[6]
	var airborne := (flags & 4) != 0
	world.game._handle(driver.mobile_packet(at, flags, serial, body, hue))
	var source: Node3D = world.avatars[serial].horse_visual
	assert(source.native_body == body and source.native_hue == hue)
	var before: Array[Vector3] = []
	var labels := ["bip01 head", "bip01 tail1", "daemon l wing03", "daemon r wing03"] if body == 9 \
		else ["bip01 head", "bip01 tail4", "box04", "box03"]
	if airborne:
		source.current_clip = "Fly"
		source.play("Fly", 0.0)
		source.animator.advance(.19)
	if enhanced:
		world.game._handle(driver.action_packet(info[1], serial, info[2]))
		assert(source.current_clip == info[3] and source.airborne_fit == airborne)
		for i in 10:
			source.animator.advance(.016)
		source.animator.seek(source.animator.current_animation_length * info[4], true)
		source.rotate_y(.3)
		source._physics_process(1.0 / 60.0)
		source.contact.modification_processed.emit()
		for label: String in labels:
			before.append(Fit.bone(source, label))
	var corpse_first := index % 2 == 0
	if corpse_first:
		world.game._handle(driver.corpse_packet(at, corpse, body, hue))
	var death := PackedByteArray([0xaf])
	death.append_array(Wire.uint_be(serial, 4))
	death.append_array(Wire.uint_be(corpse, 4))
	death.append_array(Wire.uint_be(0, 4))
	world.game._handle(death)
	if not corpse_first:
		world.game._handle(driver.corpse_packet(at, corpse, body, hue))
	var state: Dictionary = world.creature_deaths.active[serial]
	var fallen: Node3D = state.visual
	var fall_clip := "AirDeath" if airborne else "Death"
	assert(fallen.current_clip == fall_clip and fallen.native_hue == hue)
	var jump := 0.0
	for i in before.size():
		jump = maxf(jump, before[i].distance_to(Fit.bone(fallen, labels[i])))
	if enhanced:
		assert(jump < .002, "%s falls with jump %f" % [info[3], jump])
	var holder: Node3D = world.world_items.nodes[corpse]
	assert(not holder.visible)
	await driver.create_timer(float(state.remaining) + .15).timeout
	assert(holder.visible and world.world_items.corpse_snapshots.has(corpse), "%d corpse visibility or snapshot" % body)
	var frozen: Node3D = holder.get_node("CorpseVisual")
	assert(frozen.get_meta("native_hue") == hue and frozen.get_meta("death_clip") == fall_clip)
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	return {"body": body, "hue": hue, "jump": jump, "corpse": corpse, "fall": fall_clip}
