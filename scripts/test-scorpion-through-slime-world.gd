# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Fit := preload("test-scorpion-through-slime-enhanced.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Cases := [
	[48, 15, 0, "ScorpionTailRise", .43, true, 0x8035],
	[48, 11, 0, "ScorpionScissorStrike", .43, true, 0x455],
	[242, 11, 0, "DeathwatchCrossShear", .43, true, 0x8035],
	[242, 5, 1, "DeathwatchAbdomenCurl", .43, true, 0x455],
	[13, 15, 0, "AirVortexFormation", .11, true, 0x4001],
	[13, 15, 0, "AirVortexFormation", .57, false, 0x4001],
	[51, 11, 0, "SlimeCrestLash", .34, true, 0x8035],
]

static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var rows := {}
	var checks := 0
	for info: Array in Cases:
		var case := await witness(driver, world, at, enhanced, info, rows.size())
		assert(not case.is_empty())
		rows["%s:%.2f" % [info[3], info[4]]] = case
		checks += (6 if info[5] else 4) + (2 if enhanced else 0)
	return {"rows": rows, "checks": checks}

static func witness(driver, world: Node, at: Vector2i, enhanced: bool, info: Array, index: int) -> Dictionary:
	var body: int = info[0]
	var serial := 0x1500 + index
	var persistent: bool = info[5]
	var corpse := 0x40000000 + serial if persistent else 0
	var hue: int = info[6]
	var joint := "Head" if body == 13 else "bip01 head" if body == 51 else "bip01 neck"
	world.game._handle(driver.mobile_packet(at, 64, serial, body, hue))
	var source: Node3D = world.avatars[serial].horse_visual
	assert(source.native_body == body and source.native_hue == hue)
	var before := Vector3.ZERO
	if enhanced:
		world.game._handle(driver.action_packet(info[1], serial, info[2]))
		assert(source.current_clip == info[3])
		for i in 10:
			source.animator.advance(.016)
		source.animator.seek(source.animator.current_animation_length * info[4], true)
		source._physics_process(1.0 / 60.0)
		source.contact.modification_processed.emit()
		before = Fit.bone(source, joint)
	var before_death := index % 2 == 0
	if persistent and before_death:
		world.game._handle(driver.corpse_packet(at, corpse, body, hue))
	var death := PackedByteArray([0xaf])
	death.append_array(Wire.uint_be(serial, 4))
	death.append_array(Wire.uint_be(corpse, 4))
	death.append_array(Wire.uint_be(0, 4))
	world.game._handle(death)
	if persistent and not before_death:
		world.game._handle(driver.corpse_packet(at, corpse, body, hue))
	var state: Dictionary = world.creature_deaths.active[serial]
	var fallen: Node3D = state.visual
	assert(fallen.current_clip == "Death" and fallen.native_hue == hue)
	var jump := 0.0
	if enhanced:
		jump = before.distance_to(Fit.bone(fallen, joint))
		assert(jump < .002, "%s falls with jump %f" % [info[3], jump])
	if not persistent:
		assert(not world.creature_deaths.held_corpses.has(0))
		await driver.create_timer(float(state.remaining) + .15).timeout
		assert(not world.creature_deaths.active.has(serial) and not world.world_items.corpse_snapshots.has(0))
		return {"hue": hue, "jump": jump, "corpse": 0, "body": body}
	var holder: Node3D = world.world_items.nodes[corpse]
	assert(not holder.visible)
	await driver.create_timer(float(state.remaining) + .15).timeout
	var grounded_air: bool = body == 13 and source.get_script().resource_path == "res://Presentation/SourceTerrainAirElementalVisual.gd"
	assert(holder.visible and world.world_items.corpse_snapshots.has(corpse) == (enhanced or body in [48, 242] or grounded_air))
	var frozen: Node3D = holder.get_node("CorpseVisual")
	assert(frozen.get_meta("native_hue") == hue and frozen.get_meta("death_clip") == "Death")
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	return {"hue": hue, "jump": jump, "corpse": corpse, "body": body}
