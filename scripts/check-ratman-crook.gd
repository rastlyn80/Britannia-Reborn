# SPDX-License-Identifier: GPL-3.0-or-later
extends "bake-ratman-mage-enhanced.gd"

const InspectionRate := 720.0


func run() -> void:
	var evidence := {}
	var failed := false
	for treatment: String in Profile.registered_assets(Registry.entry(143)):
		var path := Destination + "143-%s.scn" % treatment
		var actor := (load(path) as PackedScene).instantiate()
		root.add_child(actor)
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var body := actor.find_child("Body", true, false) as MeshInstance3D
		var crook := actor.find_child("RatmanCrook", true, false) as MeshInstance3D
		var fit := CrookClearance.new(body, rig)
		var props := {}
		for clip: String in Clips.values() + ["Death"]:
			var result := sample_clip(player, rig, crook, fit, clip)
			if result.crossings != 0 or result.floor < .010 or result.grip > .00001 or result.tip_step >= .065:
				failed = true
			props[clip] = result
		evidence[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "clips": props}
		actor.free()
	var file := FileAccess.open(Destination + "crook-clearance.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"inspection_rate": InspectionRate, "treatments": evidence, "failed": failed}, "\t"))
	file.close()
	quit(1 if failed else 0)


func sample_clip(player: AnimationPlayer, rig: Skeleton3D, crook: MeshInstance3D, fit: CrookClearance, clip: String) -> Dictionary:
	var grip := rig.find_bone("cp_grasp_rhand")
	var joint := rig.find_bone(StaffBone)
	assert(rig.get_bone_parent(joint) == grip)
	var points: PackedVector3Array = crook.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var tip := (Vector3(0, .70, -.13) - GripOrigin) * ShaftScale
	var sections := crook_sections()
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var duration := player.current_animation_length
	var intervals := ceili(duration * InspectionRate)
	var result := {"samples": intervals + 1, "crossings": 0, "floor": INF, "grip": 0.0, "tip_step": 0.0, "tip_phase": 0.0}
	var previous := Vector3.ZERO
	for i in intervals + 1:
		var phase := float(i) / intervals
		player.seek(duration * phase, true)
		rig.force_update_all_bone_transforms()
		var pose := rig.global_transform * rig.get_bone_global_pose(joint)
		fit.update_pose()
		result.crossings += int(fit.hits(pose, sections, 0.0))
		result.grip = maxf(result.grip, pose.origin.distance_to(rig.to_global(rig.get_bone_global_pose(grip).origin)))
		for point: Vector3 in points:
			result.floor = minf(result.floor, (pose * point).y)
		var world_tip := pose * tip
		if i > 0 and previous.distance_to(world_tip) > result.tip_step:
			result.tip_step = previous.distance_to(world_tip)
			result.tip_phase = phase
		previous = world_tip
	print("RATMAN CROOK CLEARANCE ", clip, " ", result)
	return result
