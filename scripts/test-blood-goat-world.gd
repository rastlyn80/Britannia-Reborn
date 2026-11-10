# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const BloodJoints := ["bip01 head", "bip01 r hand", "bip01 l foot"]
const GoatJoints := ["bip01 head", "bip01 l hand", "bip01 r toe0"]
const Crest := ["BloodSurgeCrest"]
const Pool := ["BloodRisePool"]
const Cases := [
	{"body": 159, "type": 15, "clip": "BloodElementalPoolRise", "phase": .20, "hue": 0x8035,
		"joints": BloodJoints, "visible": Crest, "hidden": Pool, "recolour": true},
	{"body": 159, "type": 15, "clip": "BloodElementalPoolRise", "label": "BloodElementalInterruptedPoolRise",
		"phase": .17, "hue": 0x455, "joints": BloodJoints, "visible": Crest, "hidden": Pool, "interrupt": true},
	{"body": 159, "type": 8, "clip": "BloodElementalSurgeAlert", "phase": .66, "hue": 0x489,
		"joints": BloodJoints, "visible": Crest, "hidden": Pool},
	{"body": 88, "type": 2, "clip": "MountainGoatQuietStand", "phase": .37, "hue": 0x8035, "joints": GoatJoints},
	{"body": 88, "type": 5, "clip": "MountainGoatLoweredHornCheck", "phase": .55, "hue": 0x455, "joints": GoatJoints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x2390, Cases)
