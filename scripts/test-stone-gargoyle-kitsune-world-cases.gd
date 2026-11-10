# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const StoneJoints := ["bip01 head", "cp_grasp_rhand", "gargoyle l wing4"]
const KitsuneJoints := ["bip01 head", "bip01 tailnub", "l_tailbone01", "m_tailbone01"]
const Cases := [
	{"body": 67, "type": 11, "clip": "StoneGargoyleRisingRake", "phase": .28, "hue": 0x8035, "joints": StoneJoints},
	{"body": 67, "type": 15, "clip": "StoneGargoyleUnbrace", "phase": .17, "hue": 0x455, "joints": StoneJoints},
	{"body": 67, "type": 5, "variant": 1, "clip": "StoneGargoyleStaggeredFeint", "phase": .57,
		"hue": 0x489, "joints": StoneJoints},
	{"body": 246, "type": 0, "variant": 5, "clip": "BakeKitsuneLowSnap", "phase": .38, "hue": 0x8035,
		"joints": KitsuneJoints},
	{"body": 246, "type": 2, "variant": 1, "clip": "BakeKitsuneSkiddingRecoil", "phase": .55,
		"hue": 0x455, "joints": KitsuneJoints},
	{"body": 246, "type": 5, "variant": 1, "clip": "BakeKitsuneThreeTailFeint", "phase": .61,
		"hue": 0x489, "joints": KitsuneJoints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x23C0, Cases)
