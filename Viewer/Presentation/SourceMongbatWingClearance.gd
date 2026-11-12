# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceWingSlopeClearance.gd"


func bind(skin: Dictionary) -> void:
	var rig := get_skeleton()
	for side: String in ["l", "r"]:
		var prefix := "mongbat %s wing" % side
		var joint := rig.find_bone(prefix + "main1")
		assert(joint >= 0)
		var wing_bones := {}
		for bone in rig.get_bone_count():
			if rig.get_bone_name(bone).begins_with(prefix):
				wing_bones[bone] = true
		wings.append({"joints": PackedInt32Array([joint]), "skin": [select_vertices(skin, wing_bones)]})
