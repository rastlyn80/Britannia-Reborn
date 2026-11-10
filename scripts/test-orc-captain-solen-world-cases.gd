# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("test-enhanced-corpse-gesture-cases.gd")
const CaptainJoints := ["bip01 head", "cp_grasp_rhand", "orc captain axe"]
const SolenJoints := ["bip01 head", "legbone lf2", "legbone rr2"]
const Cases := [
	{"body": 7, "type": 15, "clip": "OrcCaptainAxeBraceRise", "phase": .20, "hue": 0x8035,
		"joints": CaptainJoints, "visible": ["OrcCaptainAxe"], "recolour": true},
	{"body": 7, "type": 8, "clip": "OrcCaptainLowAxeAlert", "phase": .84, "hue": 0x455,
		"joints": CaptainJoints, "visible": ["OrcCaptainAxe"]},
	{"body": 805, "type": 11, "variant": 2, "clip": "BlackSolenRaisedClawPair", "phase": .40, "hue": 0x453,
		"joints": SolenJoints},
	{"body": 805, "type": 15, "clip": "BlackSolenLowUnfold", "phase": .23, "hue": 0x8035, "joints": SolenJoints},
	{"body": 805, "type": 5, "variant": 1, "clip": "BlackSolenHighClawFeint", "phase": .51,
		"hue": 0x455, "joints": SolenJoints},
	{"body": 805, "type": 5, "clip": "BlackSolenAntennaWatch", "phase": .61, "flags": 0,
		"hue": 0x489, "joints": SolenJoints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x23D0, Cases)
