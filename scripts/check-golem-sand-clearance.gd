# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/check-grizzle-changeling-clearance.gd"

const Iron := preload("bake-golem-enhanced.gd")
const Sand := preload("bake-sand-vortex-enhanced.gd")
const IronCore := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 neck", "bone_head"]
const DustCore := ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head"]


func run() -> void:
	var report := {}
	for body: int in [752, 790]:
		var treatments := {}
		for treatment: String in ["original", "rounded", "modern"] if body == 752 else ["modern"]:
			var path := Iron.Destination + "%d-%s.scn" % [body, treatment]
			if body == 790 and "--revised" in OS.get_cmdline_user_args():
				path = Iron.Destination + "790-arm-clearance.scn"
			var model := (load(path) as PackedScene).instantiate()
			root.add_child(model)
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var mesh := model.find_child("Body" if body == 752 else "CloudBody", true, false) as MeshInstance3D
			var surface := PosedSurface.new(mesh, rig)
			var triangles := core_triangles(surface, rig, IronCore if body == 752 else DustCore)
			assert(not triangles.is_empty())
			var clips := {}
			for clip: String in (Iron.Clips if body == 752 else Sand.SandClips).values():
				player.stop()
				player.play(clip, 0.0)
				player.advance(0.0)
				var intervals := ceili(player.current_animation_length * Rate)
				var crossings := 0
				var floor_minimum := INF
				for sample in intervals + 1:
					player.seek(player.current_animation_length * sample / intervals, true)
					rig.force_update_all_bone_transforms()
					surface.update_pose()
					var intersection := false
					for side: String in ["l", "r"]:
						var fore := "bip01 %s forearm" % side if body == 752 else "lowerarm_" + side
						var hand := "bip01 %s hand" % side if body == 752 else "hand_" + side
						var start := joint_position(rig, rig.find_bone(fore))
						var end := joint_position(rig, rig.find_bone(hand))
						intersection = crosses(surface, triangles, start, end) or intersection
					crossings += 1 if intersection else 0
					for point: Vector3 in surface.deformed:
						assert(point.is_finite())
						floor_minimum = minf(floor_minimum, point.y)
				clips[clip] = {"samples": intervals + 1, "crossings": crossings, "floor_minimum": floor_minimum}
				print("GOLEM AND SAND VORTEX GEOMETRY ", body, "/", treatment, "/", clip, " ", clips[clip])
			treatments[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "core_triangles": triangles.size(), "clips": clips}
			model.free()
		report[str(body)] = treatments
	var receipt := FileAccess.open(Iron.Destination + "dense-clearance-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "bodies": report}, "\t"))
	receipt.close()
	quit()
