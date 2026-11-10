# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Joints := ["bip01 head", "bip01 r hand", "bip01 tail1", "legbone rf2", "legbone lr2"]
const Cases := [
	{"body": 806, "type": 11, "variant": 2, "clip": "BlackSolenWarriorRaisedClaws", "phase": .44,
		"hue": 0x453, "joints": Joints, "recolour": true},
	{"body": 806, "type": 15, "clip": "BlackSolenWarriorUnfold", "phase": .30,
		"hue": 0x8035, "joints": Joints},
	{"body": 806, "type": 5, "variant": 1, "flags": 0, "clip": "BlackSolenWarriorAntennaCheck", "phase": .42,
		"hue": 0x455, "joints": Joints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x2558, Cases)
