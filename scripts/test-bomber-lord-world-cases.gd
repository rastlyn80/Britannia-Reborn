# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Joints := ["bip01 head", "cp_grasp_rhand", "bip01 r foot"]
const Cases := [
	{"body": 182, "type": 15, "clip": "OrcBomberUnfold", "phase": .25, "hue": 0x8035, "joints": Joints,
		"recolour": true},
	{"body": 182, "type": 11, "variant": 2, "clip": "OrcBomberCastAndDip", "phase": .44,
		"hue": 0x455, "joints": Joints},
	{"body": 182, "type": 5, "variant": 1, "clip": "OrcBomberHighFeint", "phase": .31,
		"hue": 0x489, "joints": Joints},
	{"body": 83, "type": 11, "variant": 2, "clip": "OgreLordDownwardClub", "phase": .47, "hue": 0x8035,
		"joints": Joints, "hidden": ["OgreLordBoneClub"], "recolour": true},
	{"body": 83, "type": 5, "variant": 1, "clip": "OgreLordOverheadGuard", "phase": .21, "hue": 0x455,
		"joints": Joints, "hidden": ["OgreLordBoneClub"]},
	{"body": 83, "type": 8, "clip": "OgreLordClubLift", "phase": .77, "hue": 0x489,
		"joints": Joints, "hidden": ["OgreLordBoneClub"]},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x24A0, Cases)

