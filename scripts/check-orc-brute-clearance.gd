# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/check-minotaur-scout-clearance.gd"

const BruteFit := preload("bake-orc-brute-enhanced.gd")
const BruteTorso := ["bip_01 pelvis", "bip_01 spine", "bip_01 spine1", "bip_01 spine2", "bip_01 spine3"]


func run() -> void:
	var reports := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := BruteFit.Destination + "silhouette/189-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var surface := PosedSurface.new(mesh, rig)
		var core := core_triangles(surface, rig, BruteTorso)
		assert(not core.is_empty())
		player.play("Idle")
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var claws := []
		for side: String in ["l", "r"]:
			var hand := rig.find_bone("bip_01 %s hand" % side)
			claws.append({"hand": hand, "forearm": rig.find_bone("bip_01 %s forearm" % side),
				"tip": claw_tip(surface, rig, hand)})
		var feet := PackedInt32Array()
		for point in surface.positions.size():
			var influence: int = point * surface.stride
			var joint := rig.get_bone_name(surface.bones[surface.joints[influence]])
			if joint.ends_with(" foot") and surface.weights[influence] > .70:
				feet.append(point)
		assert(not feet.is_empty())
		var clips := {}
		for clip: String in BruteFit.Clips.values() + [BruteFit.PeaceWalk]:
			clips[clip] = sample_motion(player, rig, surface, core, claws, feet, clip)
			print("ORC BRUTE CLEARANCE ", treatment, "/", clip, " ", clips[clip])
		reports[treatment] = {"clips": clips, "scene_sha256": FileAccess.get_sha256(path)}
		model.free()
	var file := FileAccess.open(BruteFit.Destination + "dense-clearance-receipt.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"sample_rate": Rate, "treatments": reports}, "\t"))
	file.close()
	quit()


func sample_motion(player: AnimationPlayer, rig: Skeleton3D, surface: RefCounted, core: PackedInt32Array,
		claws: Array, feet: PackedInt32Array, clip: String) -> Dictionary:
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var crossings := 0
	var witness := {}
	var max_foot_gap := 0.0
	for sample in intervals + 1:
		player.seek(player.current_animation_length * sample / intervals, true)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var lowest := INF
		for point: Vector3 in surface.deformed:
			lowest = minf(lowest, point.y)
		var stance := INF
		for index: int in feet:
			stance = minf(stance, surface.deformed[index].y)
		max_foot_gap = maxf(max_foot_gap, stance - lowest + .003)
		for side in claws.size():
			var claw: Dictionary = claws[side]
			var hand := joint_position(rig, claw.hand)
			var middle := crosses(surface, core, joint_position(rig, claw.forearm), hand)
			var fingers := crosses(surface, core, hand, surface.deformed[claw.tip])
			if middle or fingers:
				crossings += 1
				var name := "%d/%s" % [side, "arm" if middle else "hand"]
				if not witness.has(name):
					witness[name] = [float(sample) / intervals, float(sample) / intervals]
				witness[name][1] = float(sample) / intervals
				break
	return {"samples": intervals + 1, "crossings": crossings, "crossing_phases": witness, "maximum_supported_foot_gap": max_foot_gap}
