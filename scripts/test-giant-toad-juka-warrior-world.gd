# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Toad := ["bip01 head", "bip01 ponytail13", "bip01 r hand"]
const Juka := ["bip01 head", "bip01 r hand", "bip01 l foot"]
const Cases := [
	{"body": 80, "type": 5, "clip": "GiantToadTongueSnap", "phase": .28, "hue": 0x8035, "joints": Toad},
	{"body": 80, "type": 2, "clip": "GiantToadQuietBreath", "phase": .34, "hue": 0x455, "joints": Toad},
	{"body": 764, "type": 15, "clip": "JukaWarriorCrouchedRise", "phase": .37, "hue": 0x489, "joints": Juka},
	{"body": 764, "type": 8, "clip": "JukaWarriorGuardKick", "phase": .83, "hue": 0x455, "joints": Juka},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x1d70, Cases)
