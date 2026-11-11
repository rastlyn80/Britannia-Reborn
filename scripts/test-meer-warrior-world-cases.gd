# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Classic := preload("res://Presentation/NativeMobileActions.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Body := 771
const Joints := ["bip01 head", "bip01 l hand", "bip01 r hand", "bip01 r foot"]
const Cases := [
	{"body": Body, "type": 0, "variant": 1, "clip": "MeerWarriorRisingStrike", "phase": .46,
		"hue": 0x8035, "joints": Joints, "recolour": true},
	{"body": Body, "type": 0, "variant": 2, "clip": "MeerWarriorPivotingBackhand", "phase": .54,
		"hue": 53, "joints": Joints},
	{"body": Body, "type": 5, "variant": 1, "flags": 0, "clip": "MeerWarriorHipCheck",
		"phase": .48, "hue": 0x455, "joints": Joints},
]
const AttackCases := [
	[0, 2, "MeerWarriorPivotingBackhand"], [1, 2, "MeerWarriorSweepingJab"],
	[37, 2, "MeerWarriorPivotingBackhand"], [0x101, 1, "MeerWarriorSweepingJab"],
	[0xffff, 1, "MeerWarriorRisingStrike"], [0x1ff, 1, "MeerWarriorRisingStrike"],
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var checks := 0
	for flags: int in [0, 64]:
		var serial := 0x25d8 + flags
		world.game._handle(driver.mobile_packet(at, flags, serial, Body, 0x8035))
		var avatar: Node3D = world.avatars[serial]
		var visual: Node3D = avatar.horse_visual
		for case: Array in AttackCases:
			var wire := attack_packet(serial, case[0], case[1])
			var expected: String = case[2]
			if not enhanced:
				var parsed := {"serial": serial, "body": Body, "protocol": "new", "type": 0,
					"subaction": case[0], "variation": case[1], "action": 0, "frames": case[0], "delay": case[1]}
				assert(Classic.dispatch(avatar, parsed))
				expected = visual.current_clip
			world.game._handle(wire)
			assert(visual.current_clip == expected and visual.native_hue == 0x8035)
			checks += 1
	var report := await Replay.run(driver, world, at, enhanced, 0x25d0, Cases)
	report.checks += checks
	return report


static func attack_packet(serial: int, subaction: int, variation: int) -> PackedByteArray:
	var bytes := PackedByteArray([0xe2])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(PackedByteArray([0, 0]))
	bytes.append_array(Wire.uint_be(subaction, 2))
	bytes.append(variation)
	return bytes
