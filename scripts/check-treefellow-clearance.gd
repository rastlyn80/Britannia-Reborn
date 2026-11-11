# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/check-meer-warrior-clearance.gd"

const TreeFit := preload("bake-treefellow-enhanced.gd")


func run() -> void:
	var results := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := TreeFit.Destination + "301-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var surface := PosedSurface.new(mesh, rig)
		var core := core_triangles(surface, rig, MeerTorso + ["bip01 spine3"])
		assert(not core.is_empty())
		player.play("Idle", 0.0)
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var arms := []
		for side: String in ["l", "r"]:
			var hand := rig.find_bone("bip01 %s hand" % side)
			arms.append({"hand": hand, "forearm": rig.find_bone("bip01 %s forearm" % side), "tip": claw_tip(surface, rig, hand)})
		var feet := PackedInt32Array()
		for point in surface.positions.size():
			var influence: int = point * surface.stride
			var joint := rig.get_bone_name(surface.bones[surface.joints[influence]])
			if (joint.ends_with(" foot") or joint.contains(" toe")) and surface.weights[influence] > .7:
				feet.append(point)
		assert(not feet.is_empty())
		var clips := {}
		for clip: String in TreeFit.Clips.values() + [TreeFit.QuietWalk]:
			var result := sample_motion(player, rig, surface, core, arms, feet, clip)
			clips[clip] = result
			print("TREEFELLOW CLEARANCE ", treatment, "/", clip, " ", result)
		results[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "clips": clips}
		model.free()
	var receipt := FileAccess.open(TreeFit.Destination + "dense-clearance-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "treatments": results}, "\t"))
	receipt.close()
	quit()
