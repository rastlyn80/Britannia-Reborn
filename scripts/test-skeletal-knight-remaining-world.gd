# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Knight := ["bip01 head", "scimitar", "woodenshield"]
const Props := ["Scimitar", "WoodenShield"]
const Cases := [
	{"body": 147, "type": 2, "clip": "SkeletalKnightShieldFlinch", "phase": .34, "hue": 0x8035, "joints": Knight, "visible": Props},
	{"body": 147, "type": 5, "clip": "SkeletalKnightBladeCheck", "phase": .53, "hue": 0x455, "joints": Knight, "visible": Props},
	{"body": 147, "type": 5, "variant": 1, "clip": "SkeletalKnightWideStagger", "phase": .48, "hue": 0x489, "joints": Knight, "visible": Props},
	{"body": 147, "type": 11, "clip": "SkeletalKnightOverheadSweep", "phase": .36, "hue": 0x8035, "joints": Knight, "visible": Props},
	{"body": 147, "type": 14, "clip": "SkeletalKnightLowBrace", "phase": .71, "hue": 0x455, "joints": Knight, "visible": Props},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x1d80, Cases)
