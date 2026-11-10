# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const MatriarchJoints := ["bip01 head", "cp_grasp_rhand", "matriarch ceremonial staff"]
const SuccubusJoints := ["bip01 head", "box04", "box06"]
const Sceptre := ["MatriarchSceptre"]
const Cases := [
	{"body": 87, "type": 11, "clip": "MatriarchSceptreArc", "phase": .59, "hue": 0x8035,
		"joints": MatriarchJoints, "visible": Sceptre, "recolour": true},
	{"body": 87, "type": 5, "variant": 1, "clip": "MatriarchRaisedWard", "phase": .13, "hue": 0x455,
		"joints": MatriarchJoints, "visible": Sceptre},
	{"body": 87, "type": 15, "clip": "MatriarchCoiledRise", "phase": .23, "hue": 0x8035,
		"joints": MatriarchJoints, "visible": Sceptre},
	{"body": 149, "type": 15, "clip": "SuccubusWingCocoonRise", "phase": .32, "hue": 0x8035,
		"joints": SuccubusJoints},
	{"body": 149, "type": 5, "variant": 1, "clip": "SuccubusAsymmetricSpread", "phase": .69, "hue": 0x455,
		"joints": SuccubusJoints},
	{"body": 149, "type": 8, "clip": "SuccubusWingThreat", "phase": .58, "hue": 0x489,
		"joints": SuccubusJoints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var result := await Replay.run(driver, world, at, enhanced, 0x23A0, Cases)
	assert(result.rows.size() == Cases.size())
	if enhanced and "--recolour-optional-props" in OS.get_cmdline_user_args():
		var renewed: Node3D = world.world_items.nodes[result.rows.MatriarchSceptreArc.corpse]
		assert(renewed.get_node("CorpseVisual").get_meta("native_hue") == 0x489)
		var staff := renewed.find_child("MatriarchSceptre", true, false) as MeshInstance3D
		assert(staff != null and staff.get_active_material(0) != null)
	return result
