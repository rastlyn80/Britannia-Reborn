extends "bake-acid-elemental-enhanced.gd"

const Geometry := preload("res://Presentation/SkinGeometry.gd")


func run() -> void:
	var evidence := {}
	for treatment: String in Profile.registered_assets(Registry.entry(158)):
		var path := Destination + "158-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_child("Body", true, false) as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var rows := {}
		for clip: String in Clips.values():
			player.stop()
			player.play(clip, 0.0)
			player.advance(0.0)
			var heights: Array[float] = []
			var clearance := INF
			var travel := AABB()
			for sample in 161:
				player.seek(player.current_animation_length * sample / 160.0, true)
				rig.force_update_all_bone_transforms()
				clearance = minf(clearance, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
				var box := Geometry.deformed_bounds(mesh, rig)
				assert(box.position.is_finite() and box.has_volume())
				heights.append(box.size.y)
				var hand := rig.to_global(rig.get_bone_global_pose(rig.find_bone("cp_grasp_rhand")).origin)
				if sample == 0:
					travel.position = hand
				travel = travel.expand(hand)
			assert(clearance > .003, "%s/%s clearance %.7f" % [treatment, clip, clearance])
			if clip == Clips[23]:
				assert(heights[0] > .04 and heights[0] < .15 and heights[-1] > 1.8)
			assert(travel.size.length() > .2)
			rows[clip] = {"height_begin": heights[0], "height_end": heights[-1], "minimum_floor": clearance,
				"hand_travel": travel.size.length(), "samples": 161}
			print("ACID ELEMENTAL ", treatment, " ", clip, " ", rows[clip])
		evidence[treatment] = {"asset_sha256": FileAccess.get_sha256(path), "clips": rows}
		model.free()
	var file := FileAccess.open(Destination + "acid-first-pose-receipt.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	quit()
