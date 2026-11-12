# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEagleWingClearance.gd"


func bind(skin: Dictionary) -> void:
	var rig := get_skeleton()
	var joints := PackedInt32Array()
	for index in range(1, 7):
		joints.append(rig.find_bone("tail_%d" % index))
	assert(not joints.has(-1))
	var affected := {}
	for bone in joints:
		affected[bone] = true
	wings.append({"joints": joints, "skin": [select_vertices(skin, affected)]})
