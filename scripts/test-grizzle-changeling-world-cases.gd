# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const GrizzleJoints := ["bip01 head", "bip01 l foot", "bip01 r hand"]
const ChangelingJoints := ["bip01 head", "bip01 l foot", "bone_wingright"]
const Cases := [
	{"body": 259, "type": 11, "variant": 2, "clip": "GrizzleAntlerGuard", "phase": .34, "hue": 0x8035,
		"joints": GrizzleJoints, "recolour": true},
	{"body": 259, "type": 15, "clip": "GrizzleUncurl", "phase": .24, "hue": 0x455,
		"joints": GrizzleJoints},
	{"body": 259, "type": 5, "clip": "GrizzleFurCheck", "phase": .46, "flags": 0, "hue": 0x489,
		"joints": GrizzleJoints},
	{"body": 264, "type": 11, "variant": 2, "clip": "ChangelingWingDrop", "phase": .61, "hue": 0x8035,
		"joints": ChangelingJoints},
	{"body": 264, "type": 15, "clip": "ChangelingWingRise", "phase": .72, "hue": 0x455,
		"joints": ChangelingJoints},
	{"body": 264, "type": 5, "variant": 1, "clip": "ChangelingWingFlourish", "phase": .44, "hue": 0x489,
		"joints": ChangelingJoints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x2400, Cases)
