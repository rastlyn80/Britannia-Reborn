# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Rune := ["bip01 head", "bone01", "bip01 l hand"]
const Dopple := ["bip01 head", "bip01 l hand", "bip01 r foot"]
const Emergence := ["DopplegangerVeil", "DopplegangerSeal"]
const Cases := [
	{"body": 244, "type": 2, "clip": "RuneBeetlePeaceWatch", "phase": .25, "hue": 0x8035,
		"joints": Rune, "recolour": true},
	{"body": 244, "type": 5, "variant": 1, "clip": "RuneBeetleScarletCrest", "phase": .31,
		"hue": 0x455, "joints": Rune},
	{"body": 244, "type": 8, "clip": "RuneBeetleGuardAlert", "phase": .53, "hue": 0x489, "joints": Rune},
	{"body": 777, "type": 15, "clip": "DopplegangerFormRise", "phase": .17, "hue": 0x8035,
		"joints": Dopple, "hidden": Emergence, "recolour": true},
	{"body": 777, "type": 15, "clip": "DopplegangerFormRise", "label": "Interrupted Form Rise",
		"phase": .33, "interrupt": true, "hue": 0x455, "joints": Dopple, "hidden": Emergence},
	{"body": 777, "type": 11, "variant": 2, "clip": "DopplegangerCrossedSweep", "phase": .44,
		"hue": 0x489, "joints": Dopple, "hidden": Emergence},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x24C0, Cases)

