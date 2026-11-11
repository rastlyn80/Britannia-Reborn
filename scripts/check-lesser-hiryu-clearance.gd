# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/check-grizzle-changeling-clearance.gd"

const Fit := preload("bake-lesser-hiryu-enhanced.gd")
const HiryuTorso := ["bip01 pelvis", "bip01 spine"]
const Wings := ["l_wing_bone01", "r_wing_bone01"]
const Tail := "bip01 tail2"


func run() -> void:
	var report := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Fit.Destination + "%d-%s.scn" % [Fit.Body, treatment]
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var surface := PosedSurface.new(mesh, rig)
		var core := core_triangles(surface, rig, HiryuTorso)
		assert(not core.is_empty())
		player.play("Idle")
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var probes := []
		for name: String in Wings + [Tail]:
			var joint := rig.find_bone(name)
			assert(joint >= 0)
			probes.append({"joint": joint, "tip": tip_vertex(surface, rig, joint)})
		var clips := {}
		for clip: String in Fit.Gestures.values() + Fit.Gaits.values().map(func(row: Array): return row[1]):
			clips[clip] = sample_motion(player, rig, surface, core, probes, clip)
			print("HIRYU CLEARANCE ", treatment, "/", clip, " ", clips[clip])
		report[treatment] = {"clips": clips, "scene_sha256": FileAccess.get_sha256(path)}
		model.free()
	var file := FileAccess.open(Fit.Destination + "dense-clearance-receipt.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"sample_rate": Rate, "treatments": report}, "\t"))
	file.close()
	quit()


func tip_vertex(surface: RefCounted, rig: Skeleton3D, joint: int) -> int:
	var start := joint_position(rig, joint)
	var best := -1
	var distance := 0.0
	for vertex in surface.positions.size():
		var weight := 0.0
		for influence in surface.stride:
			var slot: int = vertex * surface.stride + influence
			if surface.bones[surface.joints[slot]] == joint:
				weight += surface.weights[slot]
		if weight >= .65:
			var reach := start.distance_squared_to(surface.deformed[vertex])
			if reach > distance:
				distance = reach
				best = vertex
	assert(best >= 0 and distance > .001, rig.get_bone_name(joint))
	return best


func sample_motion(player: AnimationPlayer, rig: Skeleton3D, surface: RefCounted, core: PackedInt32Array,
		probes: Array, clip: String) -> Dictionary:
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var crossings := 0
	var ground_gap := INF
	for sample in intervals + 1:
		player.seek(player.current_animation_length * sample / intervals, true)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		for probe: Dictionary in probes:
			if crosses(surface, core, joint_position(rig, probe.joint), surface.deformed[probe.tip]):
				crossings += 1
		for point: Vector3 in surface.deformed:
			ground_gap = minf(ground_gap, point.y)
	return {"samples": intervals + 1, "crossings": crossings, "raw_minimum_ground": ground_gap}
