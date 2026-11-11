# SPDX-License-Identifier: GPL-3.0-or-later
extends "../minotaur-scout-enhanced/check-minotaur-scout-clearance.gd"

const Fit := preload("bake-gargoyle-destroyer-enhanced.gd")
const Torso := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2"]


func run() -> void:
	for body in [Fit.Destroyer, Fit.Enforcer]:
		check_body(body)
	quit()


func check_body(body: int) -> void:
	var reports := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Fit.destination(body) + "%d-%s.scn" % [body, treatment]
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var surface := PosedSurface.new(mesh, rig)
		var core := core_triangles(surface, rig, Torso)
		assert(not core.is_empty())
		player.play("Idle")
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var claws := []
		for side: String in ["l", "r"]:
			var hand := rig.find_bone("bip01 %s hand" % side)
			claws.append({"hand": hand, "forearm": rig.find_bone("bip01 %s forearm" % side),
				"tip": claw_tip(surface, rig, hand)})
		var feet := PackedInt32Array()
		for point in surface.positions.size():
			var ground_weight := 0.0
			for influence in surface.stride:
				var slot: int = point * surface.stride + influence
				if surface.weights[slot] <= 0.0:
					continue
				var joint := rig.get_bone_name(surface.bones[surface.joints[slot]])
				if joint.ends_with(" foot") or " toe" in joint:
					ground_weight += surface.weights[slot]
			if ground_weight > .65:
				feet.append(point)
		assert(not feet.is_empty())
		var clips := {}
		for clip: String in Fit.review_clips(body).values():
			clips[clip] = sample_motion(player, rig, surface, core, claws, feet, clip)
			print("GARGOYLE CLEARANCE ", body, "/", treatment, "/", clip, " ", clips[clip])
		reports[treatment] = {"clips": clips, "scene_sha256": FileAccess.get_sha256(path)}
		model.free()
	var file := FileAccess.open(Fit.destination(body) + "dense-clearance-receipt.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"sample_rate": Rate, "treatments": reports}, "\t"))
	file.close()
