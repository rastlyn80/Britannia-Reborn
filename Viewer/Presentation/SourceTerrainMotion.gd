# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceFlyingCreatureTerrain.gd"

var starting_fall := false


static func combine_skins(parts: Array[Dictionary]) -> Dictionary:
	var result := {"bones": PackedInt32Array(), "bind_poses": [], "surfaces": []}
	for part: Dictionary in parts:
		var offset: int = result.bones.size()
		result.bones.append_array(part.bones)
		result.bind_poses.append_array(part.bind_poses)
		for surface: Dictionary in part.surfaces:
			var copy := surface.duplicate()
			var bindings: PackedInt32Array = surface.bindings.duplicate()
			for index in bindings.size():
				bindings[index] += offset
			copy.bindings = bindings
			result.surfaces.append(copy)
	return result


func settle(visual: Node3D) -> void:
	if not starting_fall:
		super.settle(visual)


func enter_from_display(visual: Node3D, source: Node3D) -> float:
	var displayed_rig: Skeleton3D = source.skeleton
	var displayed_space := displayed_rig.global_transform
	var continuing: bool = source.dead and source.current_clip in FALLS
	var previous: RefCounted = source.terrain
	visual.global_transform = source.global_transform
	visual.model.global_transform = source.model.global_transform
	split = previous.split
	starting_fall = true
	var duration := begin_from_display(visual, source, previous, source.current_clip, false)
	starting_fall = false
	if not continuing:
		blend_length = minf(.15, duration)
		for bone in displayed_rig.get_bone_count():
			blend_pose.append(displayed_rig.get_bone_pose(bone))
	if not blend_pose.is_empty():
		var rig: Skeleton3D = visual.skeleton
		var correction := rig.global_transform.affine_inverse() * displayed_space
		for bone in rig.get_bone_count():
			if rig.get_bone_parent(bone) < 0:
				blend_pose[bone] = correction * blend_pose[bone]
	settle(visual)
	return duration
