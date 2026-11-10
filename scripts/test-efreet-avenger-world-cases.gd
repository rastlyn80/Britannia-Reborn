# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const EfreetJoints := ["bip01 head", "bip01 l foot", "bip01 r hand"]
const AvengerJoints := ["bip01 head", "cp_grasp_lhand", "cp_grasp_rhand"]
const Props := ["EfreetFlyingCarpet", "EfreetArrivalLamp", "ArrivalWisp0"]
const Cases := [
	{"body": 131, "type": 15, "clip": "EfreetLampArrival", "phase": .20, "hue": 0x8035,
		"joints": EfreetJoints, "hidden": Props},
	{"body": 131, "type": 15, "clip": "EfreetLampArrival", "label": "InterruptedEfreetLampArrival",
		"phase": .31, "hue": 0x455, "joints": EfreetJoints, "hidden": Props, "interrupt": true},
	{"body": 131, "type": 5, "variant": 1, "clip": "EfreetCarpetSalute", "phase": .44, "hue": 0x489,
		"joints": EfreetJoints, "hidden": Props, "recolour": true},
	{"body": 152, "type": 11, "variant": 2, "clip": "AvengerCrossedPincers", "phase": .25,
		"hue": 0x8035, "joints": AvengerJoints},
	{"body": 152, "type": 15, "clip": "AvengerUnfold", "phase": .49, "hue": 0x455, "joints": AvengerJoints},
	{"body": 152, "type": 5, "clip": "AvengerPincerWatch", "phase": .44, "flags": 0,
		"hue": 0x489, "joints": AvengerJoints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x23E0, Cases)
