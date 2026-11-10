# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const IceJoints := ["bip01 head", "cp_grasp_rhand", "bip01 r foot"]
const TerathanJoints := ["bip01 head", "cp_grasp_rhand", "bone29"]


static func cases() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{"body": 161, "type": 8, "clip": "IceElementalSpreadAlert", "phase": .64, "hue": 0x8035,
			"joints": IceJoints, "visible": ["IceCrystalShell"], "recolour": true},
		{"body": 161, "type": 15, "clip": "IceElementalCrossedRise", "phase": .21, "hue": 0x455,
			"joints": IceJoints, "visible": ["IceCrystalShell"]},
	]
	for body: int in [71, 70]:
		var family := "TerathanDrone" if body == 71 else "TerathanWarrior"
		for info: Array in [[5, 0, "LowWatch", .48, 0x8035], [5, 1, "LowPincerBrace", .60, 0x455],
				[8, 0, "ForwardAlert", .55, 0x489], [11, 0, "RaisedPincers", .43, 0x8035], [15, 0, "Unfold", .24, 0x455]]:
			result.append({"body": body, "type": info[0], "variant": info[1], "clip": family + info[2],
				"phase": info[3], "hue": info[4], "joints": TerathanJoints})
	return result


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	return await Replay.run(driver, world, at, enhanced, 0x1e10, cases())
