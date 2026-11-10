# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Joints := ["bip01 head", "bip01 l hand", "bip01 r hand"]
const Cases := [
	{"body": 73, "type": 15, "clip": "StoneHarpyFoldedLaunch", "phase": .43, "flags": 68,
		"hue": 0x8035, "joints": Joints},
	{"body": 73, "type": 5, "clip": "StoneHarpyNarrowWatch", "phase": .39, "hue": 0x455, "joints": Joints},
	{"body": 73, "type": 14, "clip": "StoneHarpyFoldAndSweep", "phase": .18, "hue": 0x489, "joints": Joints},
	{"body": 776, "type": 11, "clip": "HordeMinionOverheadLunge", "phase": .62, "hue": 0x8035, "joints": Joints},
	{"body": 776, "type": 5, "clip": "HordeMinionGraspingGuard", "phase": .39, "hue": 0x455, "joints": Joints},
	{"body": 776, "type": 5, "clip": "HordeMinionUneasyWatch", "phase": .61, "flags": 0,
		"hue": 0x489, "joints": Joints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x23B0, Cases)
