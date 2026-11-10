# SPDX-License-Identifier: GPL-3.0-or-later
extends "check-grizzle-changeling-clearance.gd"

const Assets := preload("bake-widow-juka-enhanced.gd")
const SpiderCore := ["bone01", "bone02"]
const MageCore := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head"]


func run() -> void:
	var report := {}
	for body: int in [157, 765]:
		var rows := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var path := Assets.Destination + "%d-%s.scn" % [body, treatment]
			var model := (load(path) as PackedScene).instantiate()
			root.add_child(model)
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var mesh := model.find_child("Body", true, false) as MeshInstance3D
			var surface := PosedSurface.new(mesh, rig)
			var triangles := core_triangles(surface, rig, SpiderCore if body == 157 else MageCore)
			assert(not triangles.is_empty())
			var probes := distal_probes(rig, body)
			var clips := {}
			for clip: String in (Assets.Widow if body == 157 else Assets.Mage).values():
				clips[clip] = dense_clip(player, rig, surface, triangles, probes, body, clip)
				print("WIDOW AND JUKA GEOMETRY ", body, "/", treatment, "/", clip, " ", clips[clip])
			rows[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "core_triangles": triangles.size(), "clips": clips}
			model.free()
		report[str(body)] = rows
	var receipt := FileAccess.open(Assets.Destination + "dense-clearance-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "bodies": report}, "\t"))
	receipt.close()
	quit()


func distal_probes(rig: Skeleton3D, body: int) -> Array:
	var result := []
	if body == 157:
		for pair: Array in Assets.Pairs:
			for leg: Array in pair:
				result.append([rig.find_bone(leg[1]), rig.find_bone(leg[2])])
	else:
		for side: String in ["l", "r"]:
			result.append([rig.find_bone("bip01 %s forearm" % side), rig.find_bone("bip01 %s hand" % side)])
	for segment: Array in result:
		assert(segment[0] >= 0 and segment[1] >= 0)
	return result


func dense_clip(player: AnimationPlayer, rig: Skeleton3D, surface: RefCounted, triangles: PackedInt32Array,
		probes: Array, body: int, clip: String) -> Dictionary:
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var crossings := 0
	var first := -1.0
	var clearance := INF
	var floor_minimum := INF
	var root_bone := rig.find_bone("__root")
	for sample in intervals + 1:
		var phase := float(sample) / intervals
		player.seek(player.current_animation_length * phase, true)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var segments := []
		var intersects := false
		for pair: Array in probes:
			var start := joint_position(rig, pair[0])
			var end := joint_position(rig, pair[1])
			segments.append([start, end])
			intersects = crosses(surface, triangles, start, end) or intersects
		if intersects:
			crossings += 1
			if first < 0.0:
				first = phase
		var scale := maxf(.001, rig.get_bone_pose_scale(root_bone).x)
		for i in segments.size():
			for j in range(i + 1, segments.size()):
				var a: Array = segments[i]
				var b: Array = segments[j]
				var pair := Geometry3D.get_closest_points_between_segments(a[0], a[1], b[0], b[1])
				clearance = minf(clearance, pair[0].distance_to(pair[1]) / scale)
		for point: Vector3 in surface.deformed:
			floor_minimum = minf(floor_minimum, point.y)
	return {"samples": intervals + 1, "crossings": crossings, "first_crossing": first,
		"floor_minimum": floor_minimum, "normalized_distal_clearance": clearance, "body": body}

