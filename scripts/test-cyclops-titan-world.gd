# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const CyclopsJoints := ["bip01 head", "cp_grasp_rhand", "cyclopsmallet"]
const TitanJoints := ["bip01 head", "cp_grasp_rhand", "cp_grasp_lhand"]
const Mallet := ["CyclopsMallet"]
const Cases := [
	{"body": 75, "type": 5, "clip": "CyclopsPalmGlance", "phase": .44, "hue": 0x8035, "joints": CyclopsJoints, "visible": Mallet},
	{"body": 75, "type": 5, "variant": 1, "clip": "CyclopsRaisedMallet", "phase": .58, "hue": 0x455, "joints": CyclopsJoints, "visible": Mallet},
	{"body": 75, "type": 8, "clip": "CyclopsForwardGuard", "phase": .55, "hue": 0x489, "joints": CyclopsJoints, "visible": Mallet},
	{"body": 75, "type": 11, "clip": "CyclopsOverheadMallet", "phase": .65, "hue": 0x8035, "joints": CyclopsJoints, "visible": Mallet},
	{"body": 75, "type": 15, "clip": "CyclopsRiseWithMallet", "phase": .25, "hue": 0x455, "joints": CyclopsJoints, "visible": Mallet},
	{"body": 76, "type": 5, "clip": "TitanShoulderShift", "phase": .43, "hue": 0x8035, "joints": TitanJoints},
	{"body": 76, "type": 5, "variant": 1, "clip": "TitanRaisedFists", "phase": .63, "hue": 0x455, "joints": TitanJoints},
	{"body": 76, "type": 8, "clip": "TitanShoulderAlert", "phase": .69, "hue": 0x489, "joints": TitanJoints},
	{"body": 76, "type": 11, "clip": "TitanOverheadHammerfist", "phase": .50, "hue": 0x8035, "joints": TitanJoints},
	{"body": 76, "type": 15, "clip": "TitanWideRise", "phase": .20, "hue": 0x455, "joints": TitanJoints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x1de0, Cases)
