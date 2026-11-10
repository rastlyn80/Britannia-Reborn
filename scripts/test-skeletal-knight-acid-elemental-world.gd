# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("test-enhanced-corpse-gesture-cases.gd")
const Knight := ["bip01 head", "scimitar", "woodenshield"]
const Acid := ["bip01 head", "bip01 r hand", "bip01 l foot"]
const Props := ["Scimitar", "WoodenShield"]
const Cases := [
	{"body": 147, "type": 15, "clip": "SkeletalKnightShieldRise", "phase": .25, "hue": 0x8035, "joints": Knight, "visible": Props},
	{"body": 147, "type": 8, "clip": "SkeletalKnightSwordAlert", "phase": .64, "hue": 0x455, "joints": Knight, "visible": Props},
	{"body": 158, "type": 15, "clip": "AcidElementalCondense", "phase": .23, "hue": 0x8035, "joints": Acid},
	{"body": 158, "type": 8, "clip": "AcidElementalSpatterGuard", "phase": .62, "hue": 0x455, "joints": Acid},
	{"body": 158, "type": 15, "clip": "AcidElementalCondense", "label": "AcidElementalInterruptedRise",
		"phase": .15, "hue": 0x455, "joints": Acid, "interrupt": true},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x1cf0, Cases)
