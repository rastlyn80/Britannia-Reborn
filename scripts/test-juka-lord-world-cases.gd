# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Joints := ["bip01 head", "cp_grasp_lhand", "bip01 r foot"]
const Cases := [
	{"body": 766, "type": 15, "clip": "JukaLordStandFromCrouch", "phase": .26,
		"hue": 0x8035, "joints": Joints, "recolour": true},
	{"body": 766, "type": 5, "variant": 1, "clip": "JukaLordForwardWatch", "phase": .43,
		"hue": 0x455, "joints": Joints},
	{"body": 766, "type": 5, "variant": 1, "flags": 0, "clip": "JukaLordHandSignal", "phase": .42,
		"hue": 0x489, "joints": Joints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x2550, Cases)
