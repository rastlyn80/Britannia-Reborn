# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Classic := preload("res://Presentation/NativeMobileActions.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Body := 165
const Joints := ["EnergyRoot", "Ray0", "Ray2", "Ray5"]
const Cases := [
	{"body": Body, "type": 0, "variant": 1, "clip": "ShadowWispArc", "phase": .58,
		"hue": 0x8035, "joints": Joints},
	{"body": Body, "type": 4, "clip": "ShadowWispRecoil", "phase": .41,
		"hue": 0x901, "joints": Joints},
	{"body": Body, "type": 15, "flags": 0, "clip": "ShadowWispKindle",
		"phase": .32, "hue": 0, "joints": Joints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var checks := 0
	for flags: int in [0, 64]:
		var serial := 0x29a8 + flags
		world.game._handle(driver.mobile_packet(at, flags, serial, Body, 0x901))
		var avatar: Node3D = world.avatars[serial]
		var visual: Node3D = avatar.horse_visual
		for case: Array in [[0, 0x101, 3, "ShadowWispArc"], [0, 0xffff, 7, "ShadowWispArc"],
				[4, 0, 2, "ShadowWispRecoil"], [15, 0, 1, "ShadowWispKindle"]]:
			var expected: String = case[3]
			var wire := packet(serial, case[0], case[1], case[2])
			if not enhanced:
				var parsed := {"serial": serial, "body": Body, "protocol": "new", "type": case[0],
					"subaction": case[1], "variation": case[2], "action": case[0], "frames": case[1], "delay": case[2]}
				Classic.dispatch(avatar, parsed)
				expected = visual.current_clip
			world.game._handle(wire)
			assert(visual.current_clip == expected and visual.native_hue == 0x901)
			checks += 1
	var report := await Replay.run(driver, world, at, enhanced, 0x29a0, Cases)
	report.checks += checks
	if enhanced:
		for row: Dictionary in report.rows.values():
			var corpse: Node3D = world.world_items.nodes[row.corpse].get_node("CorpseVisual")
			assert(corpse.find_children("*", "MultiMeshInstance3D", true, false).is_empty())
			report.checks += 1
	return report


static func packet(serial: int, type: int, subaction: int, variation: int) -> PackedByteArray:
	var bytes := PackedByteArray([0xe2])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(Wire.uint_be(type, 2))
	bytes.append_array(Wire.uint_be(subaction, 2))
	bytes.append(variation)
	return bytes
