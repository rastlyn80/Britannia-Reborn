# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Body := 305
const Joints := ["bip01 head", "bip01 l hand", "bip01 neck3", "bip01 r foot"]
const Cases := [
	{"body": Body, "type": 11, "variant": 2, "clip": "GoreFiendRaisedClaws", "phase": .46,
		"hue": 0x8035, "joints": Joints, "recolour": true},
	{"body": Body, "type": 15, "clip": "GoreFiendUncoil", "phase": .28, "hue": 53, "joints": Joints},
	{"body": Body, "type": 5, "variant": 1, "flags": 0, "clip": "GoreFiendScentDip",
		"phase": .48, "hue": 0x455, "joints": Joints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x25b8, Cases)
