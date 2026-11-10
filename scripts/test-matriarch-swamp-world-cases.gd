# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Matriarch := ["bip01 head", "cp_grasp_lhand", "cp_grasp_rhand", "bone29"]
const Dragon := ["bip01 head", "bip01 spine1", "bip01 l hand", "wing_r15"]
const Cases := [
	{"body": 72, "type": 15, "clip": "TerathanMatriarchRearRise", "phase": .35,
		"hue": 0x8035, "joints": Matriarch, "recolour": true},
	{"body": 72, "type": 5, "variant": 1, "clip": "TerathanMatriarchPincerThreat", "phase": .64,
		"hue": 0x455, "joints": Matriarch},
	{"body": 72, "type": 8, "clip": "TerathanMatriarchSideAlert", "phase": .42,
		"hue": 0x489, "joints": Matriarch},
	{"body": 794, "type": 15, "clip": "SwampDragonUnfold", "phase": .19,
		"hue": 0x851, "joints": Dragon},
	{"body": 794, "type": 14, "clip": "SwampDragonWingFlare", "phase": .39,
		"hue": 0x8035, "joints": Dragon},
	{"body": 794, "type": 5, "variant": 2, "flags": 0, "clip": "SwampDragonHeadCheck", "phase": .54,
		"hue": 0x455, "joints": Dragon},
	{"body": 799, "type": 11, "variant": 2, "clip": "BardedSwampDragonBraceLunge", "phase": .67,
		"hue": 0x8035, "joints": Dragon, "recolour": true},
	{"body": 799, "type": 1, "clip": "BardedSwampDragonLowSweep", "phase": .48,
		"hue": 0x455, "joints": Dragon},
	{"body": 799, "type": 5, "variant": 1, "clip": "BardedSwampDragonTailShake", "phase": .29,
		"hue": 0x489, "joints": Dragon},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x2460, Cases)

