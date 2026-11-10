# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("test-enhanced-corpse-gesture-cases.gd")
const Iron := ["bone_head", "bip01 l hand", "bip01 r foot"]
const Dust := ["Head", "hand_l", "hand_r"]
const Cases := [
	{"body": 752, "type": 15, "clip": "IronGolemWindUp", "phase": .24, "hue": 0x8035,
		"joints": Iron, "recolour": true},
	{"body": 752, "type": 5, "variant": 1, "clip": "IronGolemHammerLift", "phase": .32,
		"hue": 0x455, "joints": Iron},
	{"body": 752, "type": 11, "variant": 2, "clip": "IronGolemPistonSweep", "phase": .49,
		"hue": 0x489, "joints": Iron},
	{"body": 790, "type": 15, "clip": "SandVortexDustRise", "phase": .22, "hue": 0x8035,
		"joints": Dust, "recolour": true},
	{"body": 790, "type": 15, "clip": "SandVortexDustRise", "label": "Interrupted Dust Rise",
		"phase": .32, "interrupt": true, "growth_state": "forming", "hue": 0x455, "joints": Dust},
	{"body": 790, "type": 8, "clip": "SandVortexReachAlert", "phase": .55,
		"hue": 0x489, "joints": Dust},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x2500, Cases)
