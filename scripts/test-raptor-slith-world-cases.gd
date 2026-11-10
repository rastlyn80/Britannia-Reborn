# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Raptor := ["Head", "Tail4", "BackFoot.L"]
const Slith := ["bip01 head", "bip01 tail2", "bip01 r foot"]
const Cases := [
	{"body": 730, "type": 5, "variant": 1, "clip": "RaptorForwardStalk", "phase": .34, "hue": 0x8035,
		"joints": Raptor, "recolour": true},
	{"body": 730, "type": 15, "clip": "RaptorUncoil", "phase": .28, "hue": 0x455, "joints": Raptor},
	{"body": 730, "type": 11, "variant": 2, "clip": "RaptorRearAndSnap", "phase": .52, "hue": 0x489,
		"joints": Raptor},
	{"body": 734, "type": 5, "variant": 1, "clip": "SlithCrestWarning", "phase": .35, "hue": 476,
		"joints": Slith, "recolour": true},
	{"body": 734, "type": 5, "variant": 1, "flags": 0, "clip": "SlithNoseSweep", "phase": .38, "hue": 0x455,
		"joints": Slith},
	{"body": 734, "type": 15, "clip": "SlithTailUncoil", "phase": .20, "hue": 0x8035, "joints": Slith},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x2540, Cases)
