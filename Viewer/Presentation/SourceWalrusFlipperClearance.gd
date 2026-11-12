# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceWingSlopeClearance.gd"


func bind(skin: Dictionary) -> void:
	var rig := get_skeleton()
	for side: String in ["l", "r"]:
		for chain: Array in [["upperarm", "forearm", "hand"], ["thigh", "calf", "foot"]]:
			var joints := PackedInt32Array()
			for label: String in chain:
				joints.append(rig.find_bone("bip01 %s %s" % [side, label]))
			assert(not joints.has(-1))
			var descendants := {}
			for bone in rig.get_bone_count():
				var ancestor := bone
				while ancestor >= 0 and ancestor != joints[0]:
					ancestor = rig.get_bone_parent(ancestor)
				if ancestor >= 0:
					descendants[bone] = true
			wings.append({"joints": joints, "skin": [select_vertices(skin, descendants)]})
