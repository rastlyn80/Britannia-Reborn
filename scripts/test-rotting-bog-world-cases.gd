# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const RottingJoints := ["bip01 head", "bip01 l foot", "bip01 r hand"]
const BogJoints := ["body", "r finger 02 b", "tail 02"]
const Cases := [
	{"body": 155, "type": 2, "variant": 1, "clip": "RottingCorpseSkullShield", "phase": .33,
		"hue": 0x8035, "joints": RottingJoints},
	{"body": 155, "type": 5, "variant": 1, "clip": "RottingCorpseRaggedFlail", "phase": .56,
		"hue": 0x480, "joints": RottingJoints},
	{"body": 155, "type": 15, "clip": "RottingCorpseUncurl", "phase": .21, "hue": 0x455,
		"joints": RottingJoints},
	{"body": 780, "type": 11, "variant": 2, "clip": "BogThingMawSnap", "phase": .70, "hue": 0x21,
		"joints": BogJoints, "hidden": ["BogThingTongue"]},
	{"body": 780, "type": 15, "clip": "BogThingSprout", "phase": .24, "hue": 0x455,
		"joints": BogJoints, "hidden": ["BogThingTongue"]},
	{"body": 780, "type": 5, "clip": "BogThingMawTaste", "phase": .51, "flags": 0, "hue": 0x8035,
		"joints": BogJoints, "hidden": ["BogThingTongue"], "recolour": true},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x23F0, Cases)
