extends "bake-skeletal-knight-remaining.gd"


func run() -> void:
	var proof := {}
	var failures := 0
	for treatment: String in Profile.registered_assets(Registry.entry(147)):
		var path := Output + "147-%s.scn" % treatment
		var actor := (load(path) as PackedScene).instantiate()
		root.add_child(actor)
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var body := actor.find_child("Body", true, false) as MeshInstance3D
		var clearance := BladeClearance.new(body, rig)
		var blade := held_prop(actor, rig, "Scimitar", "r")
		var shield := held_prop(actor, rig, "WoodenShield", "l")
		var shield_node := actor.find_child("WoodenShield", true, false) as MeshInstance3D
		var faces := shield_node.mesh.get_faces()
		var clips := {}
		for clip: String in Durations:
			var result := sample_clip(player, rig, clip, clearance, blade, shield, faces)
			var crossed: bool = result.body_crossings > 0 or result.prop_crossings > 0
			var unstable: bool = result.floor < .001 or result.grip_error > .00001 or result.tip_step > .055
			if crossed or unstable:
				failures += 1
			print("SKELETAL KNIGHT FITTED PROP ", treatment, " ", clip, " ", result)
			clips[clip] = result
		proof[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "clips": clips}
		actor.free()
	var file := FileAccess.open(Output + "fitted-prop-receipt.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"treatments": proof, "failures": failures}, "\t"))
	file.close()
	quit(1 if failures else 0)


func sample_clip(player: AnimationPlayer, rig: Skeleton3D, clip: String, clearance: RefCounted,
		blade: Dictionary, shield: Dictionary, faces: PackedVector3Array) -> Dictionary:
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var duration := player.current_animation_length
	var intervals := ceili(duration * 480.0)
	var result := {"samples": intervals + 1, "body_crossings": 0, "body_contact": {}, "prop_crossings": 0,
		"floor": INF, "grip_error": 0.0, "tip_step": 0.0, "tip_step_phase": 0.0, "first_prop_contact_phase": -1.0}
	var prior_tip := Vector3.ZERO
	for sample in intervals + 1:
		var phase := float(sample) / intervals
		player.seek(duration * phase, true)
		rig.force_update_all_bone_transforms()
		clearance.update_pose()
		for prop: Dictionary in [blade, shield]:
			var pose := rig.global_transform * rig.get_bone_global_pose(prop.bone)
			var grip := rig.to_global(rig.get_bone_global_pose(prop.grip).origin)
			assert(pose.is_finite())
			result.floor = minf(result.floor, prop_floor(pose, prop.points))
			result.grip_error = maxf(result.grip_error, grip.distance_to(pose.origin))
			if clearance.crosses_prop(pose, prop.label):
				result.body_crossings += 1
				if not result.body_contact.has(prop.label):
					result.body_contact[prop.label] = [phase, phase]
				else:
					result.body_contact[prop.label][1] = phase
		var blade_pose := rig.get_bone_global_pose(blade.bone)
		var shield_space := rig.get_bone_global_pose(shield.bone).affine_inverse() * blade_pose
		if crosses_shield(shield_space, faces):
			result.prop_crossings += 1
			if result.first_prop_contact_phase < 0.0:
				result.first_prop_contact_phase = phase
		var tip := rig.to_global(blade_pose * Vector3(0.0, 1.10, .10))
		if sample > 0 and tip.distance_to(prior_tip) > result.tip_step:
			result.tip_step = tip.distance_to(prior_tip)
			result.tip_step_phase = phase
		prior_tip = tip
	return result


func crosses_shield(blade_in_shield: Transform3D, faces: PackedVector3Array) -> bool:
	for section: Array in BladeClearance.SECTIONS["Scimitar"]:
		var start: Vector3 = blade_in_shield * section[0]
		var end: Vector3 = blade_in_shield * section[1]
		for i in range(0, faces.size(), 3):
			if Geometry3D.segment_intersects_triangle(start, end, faces[i], faces[i + 1], faces[i + 2]) != null:
				return true
	return false
