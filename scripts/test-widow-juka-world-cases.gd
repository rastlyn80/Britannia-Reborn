# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Widow := ["bone01", "bone02", "bone22", "bone34"]
const Juka := ["bip01 head", "bip01 l hand", "bip01 r foot"]
const Cases := [
	{"body": 157, "type": 15, "clip": "GiantBlackWidowUnfold", "phase": .17, "hue": 0x8035,
		"joints": Widow, "recolour": true},
	{"body": 157, "type": 15, "clip": "GiantBlackWidowUnfold", "label": "Interrupted Unfold",
		"phase": .29, "interrupt": true, "hue": 0x455, "joints": Widow},
	{"body": 157, "type": 11, "variant": 2, "clip": "GiantBlackWidowLegReach", "phase": .44,
		"hue": 0x489, "joints": Widow},
	{"body": 157, "type": 5, "variant": 1, "clip": "GiantBlackWidowRearBrace", "phase": .58,
		"hue": 0x8035, "joints": Widow},
	{"body": 765, "type": 15, "clip": "JukaMageUnbow", "phase": .28,
		"hue": 0x8035, "joints": Juka, "recolour": true},
	{"body": 765, "type": 8, "clip": "JukaMageStepReady", "phase": .79, "hue": 0x455, "joints": Juka},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x2480, Cases)

