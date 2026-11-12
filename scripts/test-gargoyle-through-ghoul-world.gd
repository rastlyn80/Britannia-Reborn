# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Fit := preload("res://../scripts/test-gargoyle-through-ghoul-enhanced.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Cases := [[4, .10], [4, .58], [31, .58], [74, .10], [74, .58], [153, .58]]
const Rise := {4: "GargoyleWingRise", 31: "HeadlessGatherRise", 74: "ImpUnfurl", 153: "GhoulKneelingRise"}

static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var rows := {}
	var checks := 0
	for info: Array in Cases:
		var case := await witness(driver, world, at, enhanced, info[0], info[1], rows.size())
		assert(not case.is_empty())
		rows["%d:%.2f" % info] = case
		checks += 7 + 2 * case.routes.size() + (2 if enhanced else 0) + (2 if enhanced and info[0] == 31 else 0)
	return {"rows": rows, "checks": checks}

static func witness(driver, world: Node, at: Vector2i, enhanced: bool, body: int, phase: float, index: int) -> Dictionary:
	var serial := 0x1300 + index
	var corpse := 0x40000000 + serial
	var hue := 0x8035 if body in [4, 74] else 0x455
	var routes := []
	world.game._handle(driver.mobile_packet(at, 64, serial, body, hue))
	var source: Node3D = world.avatars[serial].horse_visual
	assert(source.native_body == body and source.native_hue == hue)
	if body in [4, 74]:
		var expected := ["WingDip", "WingDip", "WingDip", "WingDip"] if body == 4 else ["Fidget2", "Fidget2", "Fidget2", "Fidget2"]
		if enhanced:
			expected = ["GargoyleWingWatch", "GargoyleWingFeint", "GargoyleWingWatch", "GargoyleWingWatch"] if body == 4 else \
				["ImpQuietHover", "ImpGlideFeint", "ImpQuietHover", "ImpGlideFeint"]
		for flags: int in [0, 64, 4, 68]:
			world.game._handle(driver.mobile_packet(at, flags, serial, body, hue))
			assert(world.game.entities[serial].flags == flags)
			world.game._handle(driver.action_packet(5, serial, 1))
			assert(source.current_clip == expected[routes.size()])
			routes.append(source.current_clip)
	var before := Vector3.ZERO
	if enhanced:
		world.game._handle(driver.action_packet(15, serial, 0))
		assert(source.current_clip == Rise[body])
		source.animator.advance(.15)
		source.animator.seek(source.animator.current_animation_length * phase, true)
		source._physics_process(1.0 / 60.0)
		source.contact.modification_processed.emit()
		before = Fit.bone(source, "bip01 neck")
		if body == 31:
			assert(source.chain.visible)
	var item := driver.corpse_packet(at, corpse, body, hue) as PackedByteArray
	if body in [31, 153]:
		world.game._handle(item)
	var death := PackedByteArray([0xaf])
	death.append_array(Wire.uint_be(serial, 4))
	death.append_array(Wire.uint_be(corpse, 4))
	death.append_array(Wire.uint_be(0, 4))
	world.game._handle(death)
	if body in [4, 74]:
		world.game._handle(item)
	var holder: Node3D = world.world_items.nodes[corpse]
	var state: Dictionary = world.creature_deaths.active[serial]
	var fallen: Node3D = state.visual
	var clip := "AirDeath" if enhanced and body == 4 and phase > .5 else "Death"
	assert(not holder.visible and fallen.current_clip == clip and fallen.native_hue == hue)
	var jump := 0.0
	if enhanced:
		jump = before.distance_to(Fit.bone(fallen, "bip01 neck"))
		assert(jump < .002, "%d %.2f falls with jump %f" % [body, phase, jump])
		if body == 31:
			assert(not fallen.chain.visible)
	await driver.create_timer(float(state.remaining) + .15).timeout
	assert(holder.visible)
	var frozen: Node3D = holder.get_node("CorpseVisual")
	assert(frozen.get_meta("native_hue") == hue and frozen.get_meta("death_clip") == clip)
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	assert(frozen.find_children("*", "MultiMeshInstance3D", true, false).is_empty())
	var retained: bool = world.world_items.corpse_snapshots.has(corpse)
	var grounded_ghoul: bool = body == 153 and source.get_script().resource_path.ends_with("/SourceTerrainGhoulVisual.gd")
	assert(retained == (enhanced or body != 153 or grounded_ghoul))
	return {"hue": hue, "jump": jump, "corpse": corpse, "retained": retained, "clip": clip, "routes": routes}
