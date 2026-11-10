# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("test-enhanced-corpse-gesture-cases.gd")
const Elemental := ["bip01 head", "bip01 r hand", "bip01 l foot"]
const Spider := ["bone01", "bone02", "bone22", "bone18"]
const Cases := [
	{"body": 162, "type": 15, "clip": "PoisonElementalCrouchedRise", "phase": .44, "hue": 0x8035, "joints": Elemental},
	{"body": 162, "type": 8, "clip": "PoisonElementalRaisedKneeGuard", "phase": .62, "hue": 0x455, "joints": Elemental},
	{"body": 11, "type": 15, "clip": "DreadSpiderSilkEmergence", "phase": .37, "hue": 0x455, "joints": Spider,
		"hidden": ["DreadSilkOpening"]},
	{"body": 11, "type": 5, "clip": "DreadSpiderQuietTwitch", "phase": .32, "hue": 0x8035, "joints": Spider},
	{"body": 11, "type": 5, "variant": 1, "clip": "DreadSpiderRockBack", "phase": .52, "hue": 0x489, "joints": Spider},
	{"body": 11, "type": 8, "clip": "DreadSpiderAbdomenAlert", "phase": .51, "hue": 0x455, "joints": Spider},
	{"body": 11, "type": 11, "clip": "DreadSpiderFrontExtend", "phase": .54, "hue": 0x8035, "joints": Spider},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x1d30, Cases)
