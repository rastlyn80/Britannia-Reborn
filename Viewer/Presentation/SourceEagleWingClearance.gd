# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceArmedLizardContact.gd"

var wings: Array[Dictionary] = []


func bind(skin: Dictionary) -> void:
	var rig := get_skeleton()
	for side: String in ["l", "r"]:
		var joints := PackedInt32Array()
		for part: String in ["upperarm", "forearm", "hand"]:
			joints.append(rig.find_bone("bip01 %s %s" % [side, part]))
		assert(not joints.has(-1))
		var descendants := {}
		for bone in rig.get_bone_count():
			var ancestor := bone
			while ancestor >= 0 and ancestor != joints[0]:
				ancestor = rig.get_bone_parent(ancestor)
			if ancestor >= 0:
				descendants[bone] = true
		wings.append({"joints": joints, "skin": [select_vertices(skin, descendants)]})


func select_vertices(source: Dictionary, descendants: Dictionary) -> Dictionary:
	var surfaces: Array[Dictionary] = []
	for original: Dictionary in source.surfaces:
		var points := PackedVector3Array()
		var bindings := PackedInt32Array()
		var weights := PackedFloat32Array()
		var stride: int = original.stride
		for index: int in original.points.size():
			var first := index * stride
			var wing_weight := 0.0
			for slot in range(first, first + stride):
				if descendants.has(source.bones[original.bindings[slot]]):
					wing_weight += original.weights[slot]
			if wing_weight < .45:
				continue
			points.append(original.points[index])
			for slot in range(first, first + stride):
				bindings.append(original.bindings[slot])
				weights.append(original.weights[slot])
		surfaces.append({"points": points, "bindings": bindings, "weights": weights, "stride": stride})
	return {"bones": source.bones, "bind_poses": source.bind_poses, "surfaces": surfaces}


func clear_treads(height: float) -> void:
	var rig := get_skeleton()
	for wing: Dictionary in wings:
		var skin: Array[Dictionary] = []
		skin.assign(wing.skin)
		for iteration in 3:
			for joint: int in wing.joints:
				var conflict := step_conflict(height, floor_query, skin)
				if float(conflict.get("lift", 0.0)) <= .008:
					break
				var center := rig.to_global(rig.get_bone_global_pose(joint).origin)
				var axis := (Vector3(conflict.point) - center).cross(conflict.normal)
				var lever := axis.length()
				if lever <= .08:
					continue
				var parent := rig.get_bone_parent(joint)
				var basis := rig.get_bone_global_pose(parent).basis
				var local_axis := (basis.inverse() * rig.global_basis.inverse() * axis).normalized()
				var angle := minf(.095, float(conflict.lift) / lever)
				var turn := Quaternion(local_axis, angle)
				rig.set_bone_pose_rotation(joint, (turn * rig.get_bone_pose_rotation(joint)).normalized())
				rig.force_update_all_bone_transforms()
