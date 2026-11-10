# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("test-enhanced-corpse-gesture-cases.gd")
const Warrior := ["bip01 head", "bip01 r hand", "bip01 l foot"]
const Dragon := ["bip01 head", "box08", "box03", "bip01 tail3"]
const Blade := ["YomotsuBlade"]
const Cases := [
	{"body": 245, "type": 2, "clip": "YomotsuClawRecoil", "phase": .34, "hue": 0x8035, "joints": Warrior, "hidden": Blade, "recolour": true},
	{"body": 245, "type": 5, "clip": "YomotsuKneelingWatch", "phase": .53, "hue": 0x455, "joints": Warrior, "hidden": Blade},
	{"body": 245, "type": 5, "variant": 1, "clip": "YomotsuWideClawGuard", "phase": .48, "hue": 0x489, "joints": Warrior, "hidden": Blade},
	{"body": 245, "type": 8, "clip": "YomotsuRaisedClawAlert", "phase": .65, "hue": 0x455, "joints": Warrior, "hidden": Blade},
	{"body": 245, "type": 11, "clip": "YomotsuOverheadWard", "phase": .69, "hue": 0x8035, "joints": Warrior, "hidden": Blade},
	{"body": 245, "type": 15, "clip": "YomotsuCrouchedRise", "phase": .40, "hue": 0x455, "joints": Warrior, "hidden": Blade},
	{"body": 59, "type": 5, "clip": "DragonRedRaisedWingWatch", "phase": .49, "hue": 0x455, "joints": Dragon},
	{"body": 59, "type": 5, "variant": 1, "clip": "DragonRedBankedWingRecoil", "phase": .71, "hue": 0x489, "joints": Dragon},
	{"body": 59, "type": 8, "clip": "DragonRedWideWingAlert", "phase": .55, "hue": 0x8035, "joints": Dragon},
	{"body": 59, "type": 15, "clip": "DragonRedMantleOpen", "phase": .20, "hue": 0x455, "joints": Dragon},
	{"body": 59, "type": 5, "variant": 1, "clip": "DragonRedBankedWingRecoil", "label": "DragonFlightFallback",
		"flags": 4, "phase": .46, "hue": 0x8035, "joints": Dragon},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x1d90, Cases)
