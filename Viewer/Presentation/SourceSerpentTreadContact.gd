# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceWingSlopeClearance.gd"

const Chains := [
	["bip01 neck", "bip01 neck1", "bip01 neck2", "bip01 neck3"],
	["bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3"],
]


func bind(skin: Dictionary) -> void:
	var rig := get_skeleton()
	for chain: Array in Chains:
		var joints := PackedInt32Array()
		for name: String in chain:
			joints.append(rig.find_bone(name))
		assert(not joints.has(-1))
		var affected := {}
		for bone in rig.get_bone_count():
			var ancestor := bone
			while ancestor >= 0 and ancestor != joints[0]:
				ancestor = rig.get_bone_parent(ancestor)
			if ancestor >= 0:
				affected[bone] = true
		wings.append({"joints": joints, "skin": [select_vertices(skin, affected)]})
