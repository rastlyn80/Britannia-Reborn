# SPDX-License-Identifier: GPL-3.0-or-later
extends "check-minotaur-scout-clearance.gd"

const Fit := preload("bake-moloch-enhanced.gd")
const CoreJoints := ["bip01 ", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 spine3"]


func run() -> void:
	var reports := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Fit.Destination + "%d-%s.scn" % [Fit.Body, treatment]
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var surface := PosedSurface.new(mesh, rig)
		var core := core_triangles(surface, rig, CoreJoints)
		assert(not core.is_empty())
		player.play("Idle")
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var claws := []
		for arms: Array in [Fit.Left, Fit.Right]:
			for offset in [0, 3]:
				var hand := rig.find_bone(arms[offset + 2])
				claws.append({"hand": hand, "forearm": rig.find_bone(arms[offset + 1]),
					"tip": claw_tip(surface, rig, hand)})
		var feet := PackedInt32Array()
		for point in surface.positions.size():
			for influence in surface.stride:
				var slot: int = point * surface.stride + influence
				if surface.weights[slot] > .65 and rig.get_bone_name(surface.bones[surface.joints[slot]]).ends_with(" foot"):
					feet.append(point)
					break
		assert(not feet.is_empty())
		var clips := {}
		for clip: String in Fit.Clips.values() + [Fit.PeaceWalk]:
			var measures := sample_motion(player, rig, surface, core, claws, feet, clip)
			measures.merge(arm_spacing(player, rig, claws, clip))
			clips[clip] = measures
			print("MOLOCH CLEARANCE ", treatment, "/", clip, " ", measures)
		reports[treatment] = {"clips": clips, "scene_sha256": FileAccess.get_sha256(path)}
		model.free()
	var file := FileAccess.open(Fit.Destination + "dense-clearance-receipt.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"sample_rate": Rate, "treatments": reports}, "\t"))
	file.close()
	quit()


func arm_spacing(player: AnimationPlayer, rig: Skeleton3D, claws: Array, clip: String) -> Dictionary:
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var closest := INF
	for sample in 121:
		player.seek(player.current_animation_length * sample / 120.0, true)
		rig.force_update_all_bone_transforms()
		for side in [0, 2]:
			var upper: Dictionary = claws[side]
			var lower: Dictionary = claws[side + 1]
			var points := Geometry3D.get_closest_points_between_segments(joint_position(rig, upper.forearm),
				joint_position(rig, upper.hand), joint_position(rig, lower.forearm), joint_position(rig, lower.hand))
			closest = minf(closest, points[0].distance_to(points[1]))
	return {"same_side_forearm_center_distance": closest}
