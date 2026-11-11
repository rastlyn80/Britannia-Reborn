# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/check-grizzle-changeling-clearance.gd"

const Fit := preload("bake-frenzied-ostard-enhanced.gd")
const OstardTorso := ["bip01 pelvis", "bip01 spine", "bip01 spine1"]


func run() -> void:
	var report := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Fit.Destination + "218-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var surface := PosedSurface.new(mesh, rig)
		var torso := core_triangles(surface, rig, OstardTorso)
		assert(not torso.is_empty())
		player.play("Idle")
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var head := rig.find_bone("bip01 head")
		var tail := rig.find_bone("bip01 tail1")
		var neck := rig.find_bone("bip01 neck2")
		var tips := [tip_vertex(surface, head, 1.0), tip_vertex(surface, tail, -1.0)]
		assert(mini(tips[0], tips[1]) >= 0 and neck >= 0)
		var clips := {}
		for clip: String in Fit.Gestures.values() + Fit.Gaits.values().map(func(row: Array): return row[1]):
			clips[clip] = sample_motion(player, rig, surface, torso, [neck, head, tail], tips, clip)
			print("FRENZIED OSTARD CLEARANCE ", treatment, "/", clip, " ", clips[clip])
		report[treatment] = {"clips": clips, "scene_sha256": FileAccess.get_sha256(path)}
		model.free()
	var file := FileAccess.open(Fit.Destination + "dense-clearance-receipt.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"sample_rate": Rate, "treatments": report}, "\t"))
	file.close()
	quit()


func tip_vertex(surface: RefCounted, joint: int, sign_z: float) -> int:
	var chosen := -1
	var farthest := -INF
	for vertex in surface.positions.size():
		var weight := 0.0
		for influence in surface.stride:
			var slot: int = vertex * surface.stride + influence
			if surface.bones[surface.joints[slot]] == joint:
				weight += surface.weights[slot]
		var point: Vector3 = surface.deformed[vertex]
		if weight >= .7 and point.z * sign_z > farthest:
			chosen = vertex
			farthest = point.z * sign_z
	return chosen


func sample_motion(player: AnimationPlayer, rig: Skeleton3D, surface: RefCounted, torso: PackedInt32Array,
		joints: Array, tips: Array, clip: String) -> Dictionary:
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var crossings := 0
	var lowest := INF
	var crest_y := Vector2(INF, -INF)
	for sample in intervals + 1:
		player.seek(player.current_animation_length * sample / intervals, true)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var head := joint_position(rig, joints[1])
		var beak: Vector3 = surface.deformed[tips[0]]
		if (crosses(surface, torso, joint_position(rig, joints[0]), head)
				or crosses(surface, torso, head, beak)
				or crosses(surface, torso, joint_position(rig, joints[2]), surface.deformed[tips[1]])):
			crossings += 1
		crest_y = Vector2(minf(crest_y.x, beak.y), maxf(crest_y.y, beak.y))
		for point: Vector3 in surface.deformed:
			lowest = minf(lowest, point.y)
	return {"samples": intervals + 1, "crossings": crossings, "raw_minimum_ground": lowest,
		"beak_height_range_m": crest_y.y - crest_y.x}
