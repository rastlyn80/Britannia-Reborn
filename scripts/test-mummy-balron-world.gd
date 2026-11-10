# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("test-enhanced-corpse-gesture-cases.gd")
const Mummy := ["bip01 head", "bip01 r hand", "bip01 l foot"]
const Balron := ["bip01 head", "daemon l wing03", "daemon r wing03", "bip01 r foot"]
const Cases := [
	{"body": 154, "type": 15, "clip": "MummyCrouchedRise", "phase": .37, "hue": 0x8035, "joints": Mummy},
	{"body": 154, "type": 8, "clip": "MummyRaisedArmsAlert", "phase": .67, "hue": 0x515, "joints": Mummy},
	{"body": 154, "type": 11, "variant": 2, "clip": "MummyOverheadRecoil", "phase": .29, "hue": 0x455, "joints": Mummy},
	{"body": 40, "type": 15, "clip": "BalronWingCocoonRise", "phase": .27, "hue": 0x8035, "joints": Balron},
	{"body": 40, "type": 5, "clip": "BalronWingWatch", "phase": .45, "hue": 0x455, "joints": Balron},
	{"body": 40, "type": 5, "variant": 1, "clip": "BalronWingbeatRecoil", "phase": .47, "hue": 0x489, "joints": Balron},
	{"body": 40, "type": 8, "clip": "BalronWideThreat", "phase": .44, "hue": 0x455, "joints": Balron},
	{"body": 40, "type": 5, "variant": 1, "flags": 4, "clip": "BalronWingbeatRecoil", "label": "BalronAirborneFallback",
		"phase": .51, "hue": 0x8035, "joints": Balron},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x1d50, Cases)
