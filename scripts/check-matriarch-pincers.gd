# SPDX-License-Identifier: GPL-3.0-or-later
extends "check-grizzle-changeling-clearance.gd"

const Matriarch := preload("bake-terathan-matriarch-enhanced.gd")
const TrunkBones := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head"]


func run() -> void:
	var report := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Matriarch.Destination + "72-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_child("Body", true, false) as MeshInstance3D
		var surface := PosedSurface.new(mesh, rig)
		var triangles := core_triangles(surface, rig, TrunkBones)
		assert(not triangles.is_empty())
		var arms := []
		for side: String in ["l", "r"]:
			var bones := PackedInt32Array([
				rig.find_bone("bip01 %s forearm" % side),
				rig.find_bone("bip01 %s hand" % side),
				rig.find_bone("cp_grasp_%shand" % side)])
			assert(not bones.has(-1))
			arms.append(bones)
		var clips := {}
		for clip: String in Matriarch.Clips.values():
			clips[clip] = check_clip(player, rig, surface, triangles, arms, clip)
			print("TERATHAN MATRIARCH PINCERS ", treatment, "/", clip, ": ", clips[clip])
		report[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "core_triangles": triangles.size(), "clips": clips}
		model.free()
	var receipt := FileAccess.open(Matriarch.Destination + "matriarch-pincer-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "treatments": report}, "\t"))
	receipt.close()
	quit()


func check_clip(player: AnimationPlayer, rig: Skeleton3D, surface: RefCounted, triangles: PackedInt32Array,
		arms: Array, clip: String) -> Dictionary:
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var crossings := 0
	var first := -1.0
	var minimum_gap := INF
	var pincer_distance := INF
	for sample in intervals + 1:
		var phase := float(sample) / intervals
		player.seek(player.current_animation_length * phase, true)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var floor := INF
		for point: Vector3 in surface.deformed:
			floor = minf(floor, point.y)
		minimum_gap = minf(minimum_gap, floor)
		var collided := false
		var pincers := []
		for arm: PackedInt32Array in arms:
			var elbow := joint_position(rig, arm[0])
			var wrist := joint_position(rig, arm[1])
			var grasp := joint_position(rig, arm[2])
			collided = crosses(surface, triangles, elbow, wrist) or crosses(surface, triangles, wrist, grasp) or collided
			pincers.append([wrist, grasp])
		var pair := Geometry3D.get_closest_points_between_segments(pincers[0][0], pincers[0][1], pincers[1][0], pincers[1][1])
		pincer_distance = minf(pincer_distance, pair[0].distance_to(pair[1]))
		if collided:
			crossings += 1
			if first < 0.0:
				first = phase
	return {"samples": intervals + 1, "crossings": crossings, "first_crossing": first,
		"minimum_floor_gap": minimum_gap, "minimum_pincer_distance": pincer_distance}
