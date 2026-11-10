# SPDX-License-Identifier: GPL-3.0-or-later
extends "bake-cyclops-titan-enhanced.gd"

const Clearance := preload("res://../scripts/bone-knight-cyclops-clearance.gd")
const InspectionRate := 600.0


func run() -> void:
	var report := {}
	var failed := false
	for treatment: String in Profile.registered_assets(Registry.entry(75)):
		var path := Destination + "75-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var body := model.find_child("Body", true, false) as MeshInstance3D
		var mallet := model.find_child("CyclopsMallet", true, false) as MeshInstance3D
		var skin := Ground.skin_points(mallet, rig)
		var fit := Clearance.new(body, rig)
		var clips := {}
		for clip: String in Clips[75].values():
			var proof := check_mallet(player, rig, skin, fit, clip)
			failed = failed or proof.crossings > 0 or proof.floor < .004 or proof.grip > .00001 or proof.tip_step > .04
			clips[clip] = proof
		report[treatment] = {"sha256": FileAccess.get_sha256(path), "clips": clips}
		model.free()
	var output := FileAccess.open(Destination + "mallet-clearance.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"inspection_rate": InspectionRate, "failed": failed, "treatments": report}, "\t"))
	output.close()
	quit(int(failed))


func check_mallet(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, fit: Clearance, clip: String) -> Dictionary:
	var grip := rig.find_bone("cp_grasp_rhand")
	var joint := rig.find_bone("cyclopsmallet")
	assert(rig.get_bone_parent(joint) == grip)
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var duration := player.current_animation_length
	var intervals := ceili(duration * InspectionRate)
	var proof := {"samples": intervals + 1, "crossings": 0, "floor": INF, "grip": 0.0, "tip_step": 0.0, "tip_phase": 0.0}
	var previous := Vector3.ZERO
	for sample in intervals + 1:
		player.seek(duration * sample / intervals, true)
		rig.force_update_all_bone_transforms()
		var mallet := rig.global_transform * rig.get_bone_global_pose(joint)
		fit.update_pose()
		proof.crossings += int(fit.crosses_prop(mallet, "CyclopsMallet", .008))
		proof.floor = minf(proof.floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		proof.grip = maxf(proof.grip, mallet.origin.distance_to(rig.to_global(rig.get_bone_global_pose(grip).origin)))
		var tip := mallet * Vector3(.033, .66, -.07)
		if sample > 0 and tip.distance_to(previous) > proof.tip_step:
			proof.tip_step = tip.distance_to(previous)
			proof.tip_phase = float(sample) / intervals
		previous = tip
	print("CYCLOPS MALLET ", clip, " ", proof)
	return proof
