extends "bake-skeletal-knight-enhanced.gd"


func run() -> void:
	var bodies := {}
	var failures := 0
	for treatment: String in Profile.registered_assets(Registry.entry(147)):
		var path := Destination + "147-%s.scn" % treatment
		var actor := (load(path) as PackedScene).instantiate()
		root.add_child(actor)
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var mesh := actor.find_child("Body", true, false) as MeshInstance3D
		var clearance := BladeClearance.new(mesh, rig)
		var clips := {}
		for clip: String in [Rise, Alert, "Death"]:
			player.stop()
			player.play(clip, 0.0)
			player.advance(0.0)
			var items := {}
			for name: String in ["Scimitar", "WoodenShield"]:
				var prop := actor.find_child(name, true, false) as MeshInstance3D
				var skin := Ground.skin_points(prop, rig)
				var joint := rig.find_bone(name.to_lower())
				var parent := rig.get_bone_parent(joint)
				var floor := INF
				var grip_error := 0.0
				var crossings := 0
				var crossing_phases: Array[float] = []
				var travel_step := 0.0
				var prior := Vector3.ZERO
				var intervals := ceili(player.current_animation_length * 480.0)
				for index in intervals + 1:
					player.seek(player.current_animation_length * index / intervals, true)
					rig.force_update_all_bone_transforms()
					var pose := rig.global_transform * rig.get_bone_global_pose(joint)
					var grip := rig.to_global(rig.get_bone_global_pose(parent).origin)
					assert(pose.is_finite())
					clearance.update_pose()
					if clearance.crosses_prop(pose, name):
						crossings += 1
						if crossing_phases.size() < 12:
							crossing_phases.append(float(index) / intervals)
					floor = minf(floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
					grip_error = maxf(grip_error, pose.origin.distance_to(grip))
					if index > 0:
						travel_step = maxf(travel_step, pose.origin.distance_to(prior))
					prior = pose.origin
				var falling_shield := clip == "Death" and name == "WoodenShield"
				if crossings or floor < .001 or (not falling_shield and grip_error > .00001) or travel_step > .055:
					failures += 1
				items[name] = {"samples": intervals + 1, "crossings": crossings, "floor": floor,
					"grip_error": grip_error, "largest_step": travel_step, "crossing_phases": crossing_phases}
			clips[clip] = items
			print("SKELETAL KNIGHT PROPS ", treatment, " ", clip, " ", items)
		bodies[treatment] = {"sha256": FileAccess.get_sha256(path), "clips": clips}
		actor.free()
	var file := FileAccess.open(Destination + "skeletal-knight-prop-receipt.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"treatments": bodies, "failures": failures}, "\t"))
	file.close()
	quit(1 if failures else 0)
