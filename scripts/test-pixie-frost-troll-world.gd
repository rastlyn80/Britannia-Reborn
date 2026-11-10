# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("test-enhanced-corpse-gesture-cases.gd")
const Wings := ["bip01 head", "pixie l wing3", "pixie r wing3"]
const Troll := ["bip01 head", "bip01 r hand", "bip01 l hand"]
const Cases := [
	{"body": 128, "type": 15, "clip": "PixieLightRise", "phase": .46, "hue": 0x8035, "joints": Wings, "hidden": ["PixieEmergence"]},
	{"body": 128, "type": 5, "variant": 1, "clip": "PixieBankedHover", "phase": .38, "hue": 0x455, "joints": Wings},
	{"body": 128, "type": 8, "clip": "PixieWingAlert", "phase": .51, "hue": 0x489, "joints": Wings},
	{"body": 55, "type": 11, "clip": "FrostTrollOpenPalm", "phase": .56, "hue": 0x455, "joints": Troll,
		"hidden": ["FrostClub"], "recolour": true},
	{"body": 55, "type": 15, "clip": "FrostTrollCrouchedRise", "phase": .30, "hue": 0x8035, "joints": Troll, "hidden": ["FrostClub"]},
	{"body": 55, "type": 5, "variant": 1, "clip": "FrostTrollStaggerGuard", "phase": .22, "hue": 0x455, "joints": Troll,
		"hidden": ["FrostClub"]},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x1d10, Cases)
